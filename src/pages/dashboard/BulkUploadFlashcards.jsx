import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/contexts/NavDataContext'; // Sprint 7.0: shared nav-data context, not a per-mount fetch
import { useAuth } from '@/contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import PageContainer from '@/components/layout/PageContainer';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Upload, CheckCircle, XCircle, Download, ChevronDown, ChevronUp, FileText, ArrowRight, Info } from 'lucide-react';
import {
  compactMcqOptions, deriveMcqBackText, toPointsToRemember, validateMcqOptions,
  compactMcqMultiOptions, deriveMcqMultiBackText, validateMcqMultiOptions, canonicalizeMultiAnswer,
} from '@/lib/mcq';
import { compactFitbOptions, deriveFitbBackText, validateFitbBlank, validateFitbOptions } from '@/lib/fitb';
import { MATCH_MAX_PAIRS, buildMatchOptions, deriveMatchBackText, validateMatchPairs } from '@/lib/matchTheFollowing';
import { CONCEPT_MAX_TERMS, buildConceptOptions, validateConceptTerms } from '@/lib/conceptCard';
import { GRADED_QUESTION_TYPES, VERDICT_OPTION_LABELS, THEORY_SUBTYPE_LABELS } from '@/lib/questionTypes';

const MCQ_CSV_OPTION_COLUMNS = 4;
// question_type values this CSV recognizes as of Sprint 8.6b — anything else falls back to
// 'flashcard'. test_your_understanding removed (D-10 correction, collapsed into theory+subtype).
// true_false removed (D-14, merged into correct_incorrect). case_study_mcq added (Sprint
// 7.10) — a flat CSV row shape fits it fine: each question is still one row, just with a
// shared `scenario` and `case_group` value linking it to its case's other rows (N rows stay
// N separate cards, sharing a batch_id). fitb added (Sprint 7.11) — no multi-row fan-out
// problem like case_study_mcq, so its variable-length acceptable-answers list is just a
// semicolon-delimited single cell (`fitb_answers`).
// match_the_following and concept_card added (Sprint 8.6b) — unlike case_study_mcq, these
// fan N CSV rows into ONE card (options is a single {left,right,correct} object / a single
// array of {term,definition} pairs), not N separate cards. The grouping MECHANIC (a
// uploader-chosen group-id column, unique per card, identical across every row belonging to
// it) mirrors case_group exactly — only the fan TARGET differs. Both were deferred through
// 7.8-C/7.12-C specifically to avoid an in-cell delimiter, since real content (definitions,
// ratios like "3:1", amounts like "₹2,50,000") routinely contains commas/colons that would
// silently mis-split a flat cell; one-row-per-pair avoids that problem entirely.
// mcq_multi (Sprint 8.6c) added — a flat CSV row shape fits it fine, same as mcq: each
// card is still one row, just with a delimited correct_option cell ("1;3") instead of
// a single number, normalized into the same canonical stored form (compactMcqMultiOptions
// + canonicalizeMultiAnswer) manual authoring produces.
const RECOGNIZED_QUESTION_TYPES = ['mcq', 'mcq_multi', 'correct_incorrect', 'theory', 'case_study_mcq', 'fitb', 'match_the_following', 'concept_card'];
const THEORY_SUBTYPES = Object.keys(THEORY_SUBTYPE_LABELS);
// GRADED_QUESTION_TYPES (mcq/correct_incorrect/case_study_mcq) all store a scalar
// correct_answer index; fitb also writes options/explanation the same way but has
// no scalar verdict (D-13 — the verdict is computed at grading time by normalizing
// against every options entry), so it needs its own flag rather than joining that array.
// match_the_following also has no scalar correct_answer (verdict lives in options.correct).
// mcq_multi also needs its own flag — its correct_answer is a canonicalized SET string
// ("0;2;4"), not GRADED_QUESTION_TYPES' single stringified index (see the insert-row
// assembly below, which special-cases it rather than reusing String(card.gradedCorrectIndex)).
const isCsvGradedType = (qt) => GRADED_QUESTION_TYPES.includes(qt) || qt === 'fitb' || qt === 'mcq_multi';
// Which types get their `options` column populated from card.gradedOptions at insert time.
const hasCsvOptions = (qt) => isCsvGradedType(qt) || qt === 'match_the_following' || qt === 'concept_card';
// Which types get their `explanation` column populated — concept_card is deliberately
// excluded (D-06: never graded, so no grading-rationale "Why" to show).
const hasCsvExplanation = (qt) => isCsvGradedType(qt) || qt === 'match_the_following';

// ─── Stepper step component ───
function Step({ number, title, subtitle, isOpen, isComplete, onToggle, children }) {
  return (
    <div className={`border rounded-lg transition-colors ${isOpen ? 'border-amber-300 bg-amber-50/30' : isComplete ? 'border-green-200 bg-green-50/20' : 'border-gray-200'}`}>
      <button
        type="button"
        onClick={onToggle}
        className="w-full flex items-center gap-3 p-4 text-left cursor-pointer hover:bg-gray-50/50"
      >
        {/* Step circle */}
        <div className={`
          w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold
          ${isComplete ? 'bg-green-500 text-white' : isOpen ? 'bg-[#1e1b4b] text-white' : 'bg-gray-200 text-gray-600'}
        `}>
          {isComplete ? <CheckCircle className="h-5 w-5" /> : number}
        </div>

        {/* Title + subtitle */}
        <div className="flex-1 min-w-0">
          <p className={`font-medium ${isOpen ? 'text-[#1e1b4b]' : isComplete ? 'text-green-800' : 'text-gray-700'}`}>
            {title}
          </p>
          {subtitle && !isOpen && (
            <p className="text-xs text-gray-500 truncate">{subtitle}</p>
          )}
        </div>

        {/* Chevron */}
        {isOpen
          ? <ChevronUp className="h-4 w-4 text-gray-400 flex-shrink-0" />
          : <ChevronDown className="h-4 w-4 text-gray-400 flex-shrink-0" />
        }
      </button>

      {/* Expandable content */}
      {isOpen && (
        <div className="px-4 pb-4 pt-0">
          <div className="ml-11">
            {children}
          </div>
        </div>
      )}
    </div>
  );
}

export default function BulkUploadFlashcards() {
  const { isProfessor, isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();
  const { user } = useAuth();
  const navigate = useNavigate();

  // Stepper state
  const [openStep, setOpenStep] = useState(1);

  // Step 1: Download files
  const [courses, setCourses] = useState([]);
  const [selectedCourse, setSelectedCourse] = useState(null);
  const [courseStats, setCourseStats] = useState({ subjects: 0, topics: 0 });
  const [isLoadingStats, setIsLoadingStats] = useState(false);
  const [templateDownloaded, setTemplateDownloaded] = useState(false);
  const [validEntriesDownloaded, setValidEntriesDownloaded] = useState(false);

  // Step 2: Prepare CSV
  const [csvFile, setCsvFile] = useState(null);
  const [batchDescription, setBatchDescription] = useState('');
  const [bulkVisibility, setBulkVisibility] = useState('public');

  // Step 3: Upload
  const [isUploading, setIsUploading] = useState(false);
  const [uploadResults, setUploadResults] = useState(null);
  const [errors, setErrors] = useState([]);

  // ─── Step completeness (visual only, not gates) ───
  const step1Complete = templateDownloaded && validEntriesDownloaded;
  const step2Complete = !!csvFile;

  // ─── Load courses on mount ───
  useEffect(() => {
    loadCourses();
  }, []);

  useEffect(() => {
    if (selectedCourse) {
      loadCourseStats(selectedCourse);
    }
  }, [selectedCourse]);

  async function loadCourses() {
    try {
      const { data, error } = await supabase
        .from('disciplines')
        .select('id, name')
        .eq('is_active', true)
        .order('order_num')
        .order('name');

      if (error) throw error;
      setCourses(data || []);

      if (data?.length === 1) {
        setSelectedCourse(data[0].id);
      }
    } catch (error) {
      console.error('Error loading courses:', error);
    }
  }

  async function loadCourseStats(courseId) {
    setIsLoadingStats(true);
    try {
      const { data: subjects, error: subError } = await supabase
        .from('subjects')
        .select('id, name')
        .eq('discipline_id', courseId);

      if (subError) throw subError;

      const subjectIds = subjects?.map(s => s.id) || [];
      let topics = [];
      if (subjectIds.length > 0) {
        const { data: topicData, error: topError } = await supabase
          .from('topics')
          .select('id, name')
          .in('subject_id', subjectIds);

        if (topError) throw topError;
        topics = topicData || [];
      }

      setCourseStats({
        subjects: subjects?.length || 0,
        topics: topics.length
      });
    } catch (error) {
      console.error('Error loading course stats:', error);
      setCourseStats({ subjects: 0, topics: 0 });
    } finally {
      setIsLoadingStats(false);
    }
  }

  // ─── Download: Template CSV ───
  function downloadTemplate() {
    const template = '\uFEFF' + `target_course,subject,topic,front,back,tags,difficulty,question_type,option_1,option_2,option_3,option_4,correct_option,explanation,subtype,scenario,case_group,fitb_answers,match_group,match_left,match_right,concept_group,concept_term,concept_definition
CA Intermediate,Taxation,Income Tax Basics,What is the difference between a direct tax and an indirect tax?,A direct tax is paid directly by the person it is levied on (e.g. income tax); an indirect tax is collected by an intermediary and passed on to the government (e.g. GST).,"#ITR,#basics",easy,,,,,,,,,,,,,,,,,
CA Intermediate,Advanced Accounting,AS 1,What is AS 1?,Disclosure of Accounting Policies,"#AS,#important",medium,,,,,,,,,,,,,,,,,
CA Foundation,Quantitative Aptitude,Percentages,What is 20% of 500?,100,,medium,,,,,,,,,,,,,,,,,
CA Intermediate,Taxation,Income Tax Basics,Which of these is a deduction under Section 80C?,,"#ITR",medium,mcq,Life insurance premium,House rent paid,Medical insurance premium,Interest on savings account,1,Life insurance premium qualifies under 80C; the others fall under different sections.,,,,,,,,,,
CA Intermediate,Taxation,Income Tax Basics,Which of these are deductions under Section 80C? (select all that apply),,"#ITR",medium,mcq_multi,Life insurance premium,House rent paid,PPF contribution,Interest on savings account,1;3,Life insurance premium and PPF both qualify under 80C; the other two fall under different sections.,,,,,,,,,,
CA Intermediate,Taxation,Income Tax Basics,Interest on savings account is fully exempt from tax regardless of amount.,,"#ITR",medium,correct_incorrect,,,,,2,Section 80TTA/80TTB provides only a limited exemption on savings account interest -- not a full exemption. Check the current threshold rather than assuming it's unlimited.,,,,,,,,,,
CA Intermediate,Advanced Accounting,AS 1,AS 1 deals with the disclosure of accounting policies.,,"#AS",easy,correct_incorrect,,,,,1,,,,,,,,,,,
CA Intermediate,Taxation,Income Tax Basics,Explain the difference between exemption and deduction under the Income Tax Act.,An exemption removes income from the tax base entirely; a deduction reduces taxable income after it's included.,"#ITR",medium,theory,,,,,,,pure_theory,,,,,,,,,
CA Foundation,Quantitative Aptitude,Percentages,Work through: a shop marks up cost by 25% then offers a 10% discount on the marked price. What's the net margin over cost?,"Net price = 1.25 x 0.9 = 1.125x cost, so a 12.5% margin over cost.",,medium,theory,,,,,,,descriptive_case_study,,,,,,,,,
CA Intermediate,Auditing,Audit Evidence,What type of audit opinion should be issued given the evidence described in the scenario?,,"#audit",medium,case_study_mcq,Unmodified opinion,Qualified opinion,Adverse opinion,Disclaimer of opinion,2,The misstatement is material but not pervasive -- a qualified opinion is appropriate.,,"During the audit of XYZ Ltd for FY 2025-26, the auditor identified an inventory valuation error understating cost of goods sold by 8% of net profit. Management declined to adjust the financial statements.",xyz-inventory-case,,,,,,,
CA Intermediate,Auditing,Audit Evidence,Which audit procedure would have been most effective in detecting this misstatement earlier?,,"#audit",medium,case_study_mcq,Analytical review of gross margin trends,Bank confirmation,Related party disclosure review,Subsequent events review,1,A gross margin trend analysis would have flagged the anomaly before year-end.,,"During the audit of XYZ Ltd for FY 2025-26, the auditor identified an inventory valuation error understating cost of goods sold by 8% of net profit. Management declined to adjust the financial statements.",xyz-inventory-case,,,,,,,
CA Intermediate,Auditing,Audit Evidence,What should the auditor do if management continues to refuse the adjustment?,,"#audit",medium,case_study_mcq,Issue an unmodified opinion anyway,Modify the opinion and describe the basis in the audit report,Withdraw from the engagement immediately,Ignore it as immaterial,2,SA 705 requires a modified opinion with a clear basis-for-qualification paragraph.,,"During the audit of XYZ Ltd for FY 2025-26, the auditor identified an inventory valuation error understating cost of goods sold by 8% of net profit. Management declined to adjust the financial statements.",xyz-inventory-case,,,,,,,
CA Intermediate,Taxation,Income Tax Basics,"Deductions for life insurance premium, PPF, and ELSS investments are available under Section ______ of the Income Tax Act.",,"#ITR",medium,fitb,,,,,,No explanation needed -- this is a direct recall fact.,,,,"80C;Section 80C;80 C",,,,,,
CA Intermediate,Taxation,Income Tax Basics,Match each deduction section to what it covers.,,"#ITR",medium,match_the_following,,,,,,No explanation needed -- straightforward recall matching.,,,,,tax-section-map,Section 80C,"Life insurance, PPF, ELSS investments",,,
CA Intermediate,Taxation,Income Tax Basics,Match each deduction section to what it covers.,,"#ITR",medium,match_the_following,,,,,,,,,,,tax-section-map,Section 80D,Medical insurance premium,,,
CA Intermediate,Taxation,Income Tax Basics,Match each deduction section to what it covers.,,"#ITR",medium,match_the_following,,,,,,,,,,,tax-section-map,Section 80TTA,Savings account interest (limited exemption),,,
CA Intermediate,Advanced Accounting,AS 1,Methods of Depreciation,Two common ways to allocate the cost of an asset over its useful life.,"#AS",medium,concept_card,,,,,,,,,,,,,,depreciation-methods,Straight Line Method,Equal depreciation expense charged each year over the asset's useful life.
CA Intermediate,Advanced Accounting,AS 1,Methods of Depreciation,Two common ways to allocate the cost of an asset over its useful life.,"#AS",medium,concept_card,,,,,,,,,,,,,,depreciation-methods,Written Down Value Method,Depreciation charged as a fixed percentage of the asset's reducing book value each year.
CA Intermediate,Advanced Accounting,AS 1,Methods of Depreciation,Two common ways to allocate the cost of an asset over its useful life.,"#AS",medium,concept_card,,,,,,,,,,,,,,depreciation-methods,Units of Production Method,Depreciation based on actual usage or output of the asset rather than time elapsed.

==================================================
HOW TO USE THIS TEMPLATE
==================================================

1. Download the "Valid Entries" CSV from the Bulk Upload page
2. Copy EXACT course, subject & topic names from that file
3. Fill in your study item front/back content
4. Save as UTF-8 CSV and upload

COLUMNS:
- target_course (REQUIRED) - Must match Valid Entries exactly
- subject (REQUIRED) - Must match Valid Entries exactly
- topic (optional) - Must match Valid Entries if provided
- front (REQUIRED) - Question / statement / front side. For match_the_following, this is the shared instructions text — repeat the EXACT SAME text on every row of the same match_group. For concept_card, this is the concept name — repeat the EXACT SAME text on every row of the same concept_group.
- back (REQUIRED for flashcard/theory/concept_card; leave blank for mcq/correct_incorrect/case_study_mcq/fitb/match_the_following — derived automatically). For concept_card, repeat the EXACT SAME summary text on every row of the same concept_group.
- tags (optional) - Comma-separated, e.g. "#ITR,#basics"
- difficulty (optional) - easy / medium / hard (defaults to medium)
- question_type (optional) - blank/"flashcard" for a plain card, "mcq" for multiple choice, "mcq_multi" for multi-select multiple choice, "correct_incorrect", "theory", "case_study_mcq", "fitb" (fill in the blank), "match_the_following", or "concept_card"
- option_1..option_4 (required for question_type=mcq/mcq_multi/case_study_mcq only) - the answer choices (2-4 filled in). Leave blank for correct_incorrect — its two options ("Correct"/"Incorrect") are filled in automatically, you only pick which one is correct.
- correct_option (required for mcq/mcq_multi/correct_incorrect/case_study_mcq) - which option number is correct: 1-4 for mcq/case_study_mcq, 1-2 for correct_incorrect ("Correct"=1, "Incorrect"=2). For mcq_multi, list every correct option number separated by semicolons, e.g. "1;3" — at least one required, order doesn't matter. Not used for fitb/match_the_following/concept_card.
- explanation (optional, mcq/mcq_multi/correct_incorrect/case_study_mcq/fitb/match_the_following only) - shown to the student after they answer. For match_the_following, only needs to be filled on one row of the group (any row left blank is ignored).
- subtype (required for question_type=theory only) - "pure_theory" or "descriptive_case_study"
- scenario (required for question_type=case_study_mcq only) - the shared case narrative. Repeat the EXACT SAME text on every row belonging to the same case.
- case_group (required for question_type=case_study_mcq only) - any label you choose (e.g. "xyz-inventory-case") linking this row to its case's other questions. Must be unique per case within this file, identical across every row in that case. Each row still becomes its own card, sharing a batch with the rest of the case.
- fitb_answers (required for question_type=fitb only) - every phrasing you'd accept as correct, separated by semicolons (e.g. "Rs 2.5 lakhs;2.5 lakhs;250000"). Quote the whole cell if any answer itself contains a comma. front must contain a blank marker (______, at least 3 underscores).
- match_group (required for question_type=match_the_following only) - any label you choose (e.g. "tax-section-map") linking this row to its card's other pairs. Unlike case_group, all rows sharing a match_group combine into ONE card — 2-8 rows per group.
- match_left / match_right (required for question_type=match_the_following only) - one left/right pair per row. The pairing is positional: this row's match_left is matched with this row's match_right.
- concept_group (required for question_type=concept_card only) - any label you choose (e.g. "depreciation-methods") linking this row to its card's other key terms. All rows sharing a concept_group combine into ONE card — 1-10 rows per group.
- concept_term / concept_definition (required for question_type=concept_card only) - one key term/definition pair per row.

IMPORTANT:
✓ Use EXACT spelling from Valid Entries file
✓ Special characters like ₹ are supported (save as UTF-8)
✓ Cannot create new courses/subjects/topics via bulk upload
✓ To add a new subject/topic, create one item via "Create Study Item" first
✓ Visibility is set on the upload page (private / friends / public)
✓ question_type=mcq/mcq_multi/correct_incorrect/case_study_mcq/fitb/match_the_following rows require a professor/admin account — student-authored rows of these types are rejected at upload. concept_card has no such restriction — anyone can bulk-upload it.
`;

    const blob = new Blob([template], { type: 'text/csv;charset=utf-8' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'flashcard_template.csv';
    a.click();
    window.URL.revokeObjectURL(url);
    setTemplateDownloaded(true);
  }

  // ─── Download: Valid Entries CSV ───
  async function downloadValidEntries() {
    if (!selectedCourse) {
      alert('Please select a course first');
      return;
    }

    try {
      const course = courses.find(c => c.id === selectedCourse);
      if (!course) return;

      const { data: subjects, error: subError } = await supabase
        .from('subjects')
        .select('id, name')
        .eq('discipline_id', selectedCourse)
        .order('name');

      if (subError) throw subError;

      const subjectIds = subjects?.map(s => s.id) || [];
      let topics = [];
      if (subjectIds.length > 0) {
        const { data: topicData, error: topError } = await supabase
          .from('topics')
          .select('id, name, subject_id')
          .in('subject_id', subjectIds)
          .order('name');

        if (topError) throw topError;
        topics = topicData || [];
      }

      let csv = '\uFEFF';
      csv += 'Course,Subject,Topic\n';

      topics.forEach(topic => {
        const subject = subjects.find(s => s.id === topic.subject_id);
        if (subject) {
          csv += `"${course.name}","${subject.name}","${topic.name}"\n`;
        }
      });

      subjects?.forEach(subject => {
        const hasTopics = topics.some(t => t.subject_id === subject.id);
        if (!hasTopics) {
          csv += `"${course.name}","${subject.name}",""\n`;
        }
      });

      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `revisop_valid_entries_${course.name.replace(/\s+/g, '_')}.csv`;
      a.click();
      window.URL.revokeObjectURL(url);
      setValidEntriesDownloaded(true);
    } catch (error) {
      console.error('Error downloading valid entries:', error);
      alert('Failed to download valid entries. Please try again.');
    }
  }

  // ─── File select ───
  function handleFileSelect(e) {
    const file = e.target.files[0];
    if (!file) return;

    if (!file.name.endsWith('.csv')) {
      alert('Please select a CSV file');
      return;
    }

    setCsvFile(file);
    setUploadResults(null);
    setErrors([]);
  }

  // ─── CSV parsing ───
  function parseCSVLine(line) {
    const result = [];
    let current = '';
    let insideQuotes = false;

    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      const nextChar = line[i + 1];

      if (char === '"') {
        if (insideQuotes && nextChar === '"') {
          current += '"';
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char === ',' && !insideQuotes) {
        result.push(current);
        current = '';
      } else {
        current += char;
      }
    }

    result.push(current);
    return result;
  }

  async function parseCSV(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = function (event) {
        try {
          let text = event.target.result;

          // Strip UTF-8 BOM
          if (text.charCodeAt(0) === 0xFEFF) {
            text = text.substring(1);
          }

          const flashcards = [];
          const parseErrors = [];
          // match_the_following / concept_card fan N CSV rows into ONE card (unlike
          // case_study_mcq, which keeps each row as its own card sharing a batch_id) —
          // accumulate rows here keyed by group id, then resolve into single flashcard
          // entries once the whole file has been read (grouped rows need not be contiguous).
          const matchGroups = new Map();
          const conceptGroups = new Map();

          // Handle multi-line cells (quoted newlines)
          const lines = [];
          let currentLine = '';
          let insideQuotes = false;

          for (let i = 0; i < text.length; i++) {
            const char = text[i];

            if (char === '"') {
              insideQuotes = !insideQuotes;
              currentLine += char;
            } else if (char === '\n' && !insideQuotes) {
              if (currentLine.trim()) {
                lines.push(currentLine);
              }
              currentLine = '';
            } else if (char === '\r') {
              continue;
            } else {
              currentLine += char;
            }
          }

          if (currentLine.trim()) {
            lines.push(currentLine);
          }

          if (lines.length === 0) {
            resolve({ flashcards: [], errors: ['CSV file is empty'] });
            return;
          }

          const headerLine = lines[0];
          const headers = parseCSVLine(headerLine);

          for (let i = 1; i < lines.length; i++) {
            const line = lines[i];

            // Skip instruction/comment lines from template
            if (line.includes('====') || line.includes('REFERENCE:') ||
              line.includes('COURSES') || line.includes('DIFFICULTY') ||
              line.includes('SUBJECTS') || line.includes('IMPORTANT NOTES') ||
              line.includes('BULK UPLOAD LIMITATIONS') || line.includes('TO ADD NEW') ||
              line.includes('HOW TO USE') || line.includes('COLUMNS:') ||
              line.includes('IMPORTANT:') ||
              line.trim().startsWith('-') || line.trim().startsWith('✓') ||
              line.trim().startsWith('❌') || line.trim().startsWith('✅') ||
              line.trim().startsWith('⚠️')) {
              continue;
            }

            try {
              const values = parseCSVLine(line);

              if (values.length === 0 || values.every(v => !v.trim())) {
                continue;
              }

              const flashcard = {};
              headers.forEach((header, index) => {
                const value = values[index] || '';
                const cleanValue = value.toString().trim().replace(/^["']|["']$/g, '');
                flashcard[header] = cleanValue;
              });

              // question_type: recognized graded/free-recall types pass through; a blank cell
              // defaults to plain flashcard; any other non-blank value is rejected outright
              // (Sprint 8.3 A1) rather than silently downgraded — a professor authoring a type
              // Bulk Upload doesn't support (e.g. match_the_following, concept_card) or making a
              // typo deserves an error, not silently-wrong content.
              const cleanQuestionType = (flashcard.question_type || '').toString().trim().toLowerCase();
              if (cleanQuestionType && !RECOGNIZED_QUESTION_TYPES.includes(cleanQuestionType)) {
                parseErrors.push(`Row ${i + 1}: question_type '${cleanQuestionType}' isn't supported for bulk upload yet — create these individually.`);
                continue;
              }
              flashcard.question_type = cleanQuestionType || 'flashcard';

              if (flashcard.question_type === 'mcq') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front)`);
                  continue;
                }
                const rawOptions = [];
                for (let n = 1; n <= MCQ_CSV_OPTION_COLUMNS; n++) {
                  rawOptions.push(flashcard[`option_${n}`] || '');
                }
                const correctColNum = parseInt((flashcard.correct_option || '').toString().trim(), 10);
                const { options: mcqOptions, correctIndex: mcqCorrectIndex } = compactMcqOptions(
                  rawOptions,
                  Number.isNaN(correctColNum) ? null : correctColNum - 1,
                );
                const mcqError = validateMcqOptions(mcqOptions, mcqCorrectIndex);
                if (mcqError) {
                  parseErrors.push(`Row ${i + 1}: ${mcqError}`);
                  continue;
                }
                flashcard.gradedOptions = mcqOptions;
                flashcard.gradedCorrectIndex = mcqCorrectIndex;
                flashcard.back = deriveMcqBackText(mcqOptions, mcqCorrectIndex);
                flashcard.explanation = toPointsToRemember(flashcard.explanation);
              } else if (flashcard.question_type === 'mcq_multi') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front)`);
                  continue;
                }
                const rawMultiOptions = [];
                for (let n = 1; n <= MCQ_CSV_OPTION_COLUMNS; n++) {
                  rawMultiOptions.push(flashcard[`option_${n}`] || '');
                }
                // correct_option is semicolon-delimited here ("1;3"), 1-based like mcq's
                // single number — converted to 0-based before compacting, same convention.
                const rawCorrectCols = (flashcard.correct_option || '').toString().split(';')
                  .map(s => parseInt(s.trim(), 10))
                  .filter(n => !Number.isNaN(n))
                  .map(n => n - 1);
                if (rawCorrectCols.some(n => n < 0 || n >= rawMultiOptions.length)) {
                  parseErrors.push(`Row ${i + 1}: correct_option contains an index outside the option range (1-${rawMultiOptions.length})`);
                  continue;
                }
                const { options: multiOptions, correctIndices: multiCorrectIndices } = compactMcqMultiOptions(
                  rawMultiOptions,
                  rawCorrectCols,
                );
                const multiError = validateMcqMultiOptions(multiOptions, multiCorrectIndices);
                if (multiError) {
                  parseErrors.push(`Row ${i + 1}: ${multiError}`);
                  continue;
                }
                flashcard.gradedOptions = multiOptions;
                flashcard.gradedCorrectAnswer = canonicalizeMultiAnswer(multiCorrectIndices);
                flashcard.back = deriveMcqMultiBackText(multiOptions, multiCorrectIndices);
                flashcard.explanation = toPointsToRemember(flashcard.explanation);
              } else if (flashcard.question_type === 'correct_incorrect') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front)`);
                  continue;
                }
                const correctColNum = parseInt((flashcard.correct_option || '').toString().trim(), 10);
                if (correctColNum !== 1 && correctColNum !== 2) {
                  parseErrors.push(`Row ${i + 1}: correct_option must be 1 or 2 for ${flashcard.question_type}`);
                  continue;
                }
                const verdictOptions = VERDICT_OPTION_LABELS[flashcard.question_type];
                const verdictCorrectIndex = correctColNum - 1;
                flashcard.gradedOptions = verdictOptions;
                flashcard.gradedCorrectIndex = verdictCorrectIndex;
                flashcard.back = deriveMcqBackText(verdictOptions, verdictCorrectIndex);
                flashcard.explanation = toPointsToRemember(flashcard.explanation);
              } else if (flashcard.question_type === 'theory') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front || !flashcard.back) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front, back)`);
                  continue;
                }
                const cleanSubtype = (flashcard.subtype || '').toString().trim().toLowerCase();
                if (!THEORY_SUBTYPES.includes(cleanSubtype)) {
                  parseErrors.push(`Row ${i + 1}: subtype must be ${THEORY_SUBTYPES.join(' or ')} for theory rows`);
                  continue;
                }
                flashcard.subtype = cleanSubtype;
              } else if (flashcard.question_type === 'case_study_mcq') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front)`);
                  continue;
                }
                if (!flashcard.scenario || !flashcard.scenario.trim()) {
                  parseErrors.push(`Row ${i + 1}: scenario is required for case_study_mcq rows`);
                  continue;
                }
                if (!flashcard.case_group || !flashcard.case_group.trim()) {
                  parseErrors.push(`Row ${i + 1}: case_group is required for case_study_mcq rows (links this row to its case's other questions)`);
                  continue;
                }
                const rawCaseOptions = [];
                for (let n = 1; n <= MCQ_CSV_OPTION_COLUMNS; n++) {
                  rawCaseOptions.push(flashcard[`option_${n}`] || '');
                }
                const caseColNum = parseInt((flashcard.correct_option || '').toString().trim(), 10);
                const { options: caseOptions, correctIndex: caseCorrectIndex } = compactMcqOptions(
                  rawCaseOptions,
                  Number.isNaN(caseColNum) ? null : caseColNum - 1,
                );
                const caseError = validateMcqOptions(caseOptions, caseCorrectIndex);
                if (caseError) {
                  parseErrors.push(`Row ${i + 1}: ${caseError}`);
                  continue;
                }
                flashcard.gradedOptions = caseOptions;
                flashcard.gradedCorrectIndex = caseCorrectIndex;
                flashcard.back = deriveMcqBackText(caseOptions, caseCorrectIndex);
                flashcard.explanation = toPointsToRemember(flashcard.explanation);
                flashcard.scenario = flashcard.scenario.trim();
                flashcard.case_group = flashcard.case_group.trim();
              } else if (flashcard.question_type === 'fitb') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front)`);
                  continue;
                }
                const blankError = validateFitbBlank(flashcard.front);
                if (blankError) {
                  parseErrors.push(`Row ${i + 1}: ${blankError}`);
                  continue;
                }
                // Semicolon-delimited within one cell — fitb's acceptable-answer count
                // varies per row, but (unlike case_study_mcq) never needs to fan out
                // across multiple CSV rows, so a flat multi-value cell is enough.
                const fitbOptions = compactFitbOptions((flashcard.fitb_answers || '').split(';'));
                const fitbError = validateFitbOptions(fitbOptions);
                if (fitbError) {
                  parseErrors.push(`Row ${i + 1}: ${fitbError}`);
                  continue;
                }
                flashcard.gradedOptions = fitbOptions;
                flashcard.gradedCorrectIndex = null;
                flashcard.back = deriveFitbBackText(fitbOptions);
                flashcard.explanation = toPointsToRemember(flashcard.explanation);
              } else if (flashcard.question_type === 'match_the_following') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front)`);
                  continue;
                }
                if (!flashcard.match_group || !flashcard.match_group.trim()) {
                  parseErrors.push(`Row ${i + 1}: match_group is required for match_the_following rows (links this row to its card's other pairs)`);
                  continue;
                }
                if (!flashcard.match_left || !flashcard.match_left.trim() || !flashcard.match_right || !flashcard.match_right.trim()) {
                  parseErrors.push(`Row ${i + 1}: match_left and match_right are both required for match_the_following rows`);
                  continue;
                }
                flashcard.match_group = flashcard.match_group.trim();
                flashcard.match_left = flashcard.match_left.trim();
                flashcard.match_right = flashcard.match_right.trim();
                flashcard.explanation = toPointsToRemember(flashcard.explanation);
              } else if (flashcard.question_type === 'concept_card') {
                if (!flashcard.target_course || !flashcard.subject || !flashcard.front || !flashcard.back) {
                  parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front, back)`);
                  continue;
                }
                if (!flashcard.concept_group || !flashcard.concept_group.trim()) {
                  parseErrors.push(`Row ${i + 1}: concept_group is required for concept_card rows (links this row to its card's other key terms)`);
                  continue;
                }
                if (!flashcard.concept_term || !flashcard.concept_term.trim() || !flashcard.concept_definition || !flashcard.concept_definition.trim()) {
                  parseErrors.push(`Row ${i + 1}: concept_term and concept_definition are both required for concept_card rows`);
                  continue;
                }
                flashcard.concept_group = flashcard.concept_group.trim();
                flashcard.concept_term = flashcard.concept_term.trim();
                flashcard.concept_definition = flashcard.concept_definition.trim();
              } else if (!flashcard.target_course || !flashcard.subject || !flashcard.front || !flashcard.back) {
                parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front, back)`);
                continue;
              }

              // Clean difficulty
              const cleanDifficulty = (flashcard.difficulty || '')
                .toString()
                .trim()
                .replace(/['"]/g, '')
                .replace(/[^\x20-\x7E]/g, '')
                .toLowerCase();

              if (cleanDifficulty === 'easy') {
                flashcard.difficulty = 'easy';
              } else if (cleanDifficulty === 'hard') {
                flashcard.difficulty = 'hard';
              } else {
                flashcard.difficulty = 'medium';
              }

              // Clean tags
              const cleanTags = (flashcard.tags || '')
                .toString()
                .trim()
                .replace(/^["']|["']$/g, '');

              if (cleanTags !== '') {
                flashcard.tags = cleanTags
                  .split(',')
                  .map(t => t.trim())
                  .filter(t => t);
              } else {
                flashcard.tags = [];
              }

              // Normalize whitespace in front/back
              flashcard.front = flashcard.front.replace(/[\r\n]+/g, ' ').trim();
              flashcard.back = flashcard.back.replace(/[\r\n]+/g, ' ').trim();

              if (flashcard.question_type === 'match_the_following') {
                if (!matchGroups.has(flashcard.match_group)) {
                  matchGroups.set(flashcard.match_group, { rows: [], meta: flashcard, firstRow: i + 1 });
                }
                const group = matchGroups.get(flashcard.match_group);
                if (
                  flashcard.target_course !== group.meta.target_course ||
                  flashcard.subject !== group.meta.subject ||
                  (flashcard.topic || '') !== (group.meta.topic || '') ||
                  flashcard.front !== group.meta.front
                ) {
                  parseErrors.push(`Row ${i + 1}: match_group '${flashcard.match_group}' has a target_course/subject/topic/front that doesn't match row ${group.firstRow} — every row in a match_group must belong to the same card`);
                  continue;
                }
                if (group.rows.length >= MATCH_MAX_PAIRS) {
                  parseErrors.push(`Row ${i + 1}: match_group '${flashcard.match_group}' has more than ${MATCH_MAX_PAIRS} pairs — that's the maximum for one card`);
                  continue;
                }
                group.rows.push({ left: flashcard.match_left, right: flashcard.match_right });
                if (flashcard.explanation && flashcard.explanation.length && !(group.meta.explanation && group.meta.explanation.length)) {
                  group.meta.explanation = flashcard.explanation;
                }
              } else if (flashcard.question_type === 'concept_card') {
                if (!conceptGroups.has(flashcard.concept_group)) {
                  conceptGroups.set(flashcard.concept_group, { rows: [], meta: flashcard, firstRow: i + 1 });
                }
                const group = conceptGroups.get(flashcard.concept_group);
                if (
                  flashcard.target_course !== group.meta.target_course ||
                  flashcard.subject !== group.meta.subject ||
                  (flashcard.topic || '') !== (group.meta.topic || '') ||
                  flashcard.front !== group.meta.front ||
                  flashcard.back !== group.meta.back
                ) {
                  parseErrors.push(`Row ${i + 1}: concept_group '${flashcard.concept_group}' has a target_course/subject/topic/front/back that doesn't match row ${group.firstRow} — every row in a concept_group must belong to the same card`);
                  continue;
                }
                if (group.rows.length >= CONCEPT_MAX_TERMS) {
                  parseErrors.push(`Row ${i + 1}: concept_group '${flashcard.concept_group}' has more than ${CONCEPT_MAX_TERMS} key terms — that's the maximum for one card`);
                  continue;
                }
                group.rows.push({ term: flashcard.concept_term, definition: flashcard.concept_definition });
              } else {
                flashcards.push(flashcard);
              }
            } catch (error) {
              parseErrors.push(`Row ${i + 1}: ${error.message}`);
            }
          }

          // ── Resolve match_the_following groups into one card per group ──
          // Positional pairing: each row's own left/right values are the correct
          // match for each other, since CSV never authors distractor right-items
          // (that needs the arbitrary-remapping UI, manual authoring only).
          for (const [groupId, group] of matchGroups) {
            const left = group.rows.map(r => r.left);
            const right = group.rows.map(r => r.right);
            const correctByIndex = left.map((_, idx) => idx);
            const matchError = validateMatchPairs(left, right, correctByIndex);
            if (matchError) {
              parseErrors.push(`match_group '${groupId}' (starting row ${group.firstRow}): ${matchError}`);
              continue;
            }
            const card = { ...group.meta };
            const options = buildMatchOptions(left, right, correctByIndex);
            card.gradedOptions = options;
            card.back = deriveMatchBackText(left, options.correct);
            card.explanation = group.meta.explanation && group.meta.explanation.length ? group.meta.explanation : null;
            flashcards.push(card);
          }

          // ── Resolve concept_card groups into one card per group ──
          for (const [groupId, group] of conceptGroups) {
            const conceptError = validateConceptTerms(group.rows);
            if (conceptError) {
              parseErrors.push(`concept_group '${groupId}' (starting row ${group.firstRow}): ${conceptError}`);
              continue;
            }
            const card = { ...group.meta };
            card.gradedOptions = buildConceptOptions(group.rows);
            flashcards.push(card);
          }

          resolve({ flashcards, errors: parseErrors });
        } catch (error) {
          reject(error);
        }
      };

      reader.onerror = function () {
        reject(new Error('Failed to read file'));
      };

      reader.readAsText(file, 'UTF-8');
    });
  }

  // ─── Upload flashcards ───
  async function uploadFlashcards() {
    if (!csvFile) {
      alert('Please select a CSV file first');
      return;
    }

    setIsUploading(true);
    setErrors([]);

    try {
      const { flashcards, errors: parseErrors } = await parseCSV(csvFile);

      if (parseErrors.length > 0) {
        const customEntryErrors = parseErrors.filter(err =>
          err.toLowerCase().includes('not found')
        );

        if (customEntryErrors.length > 0) {
          setErrors([
            'Custom entries detected — bulk upload only works with existing courses, subjects, and topics.',
            '',
            ...parseErrors,
            '',
            'To fix: create the missing subject/topic via "Create Study Item" first, then re-download Valid Entries and try again.'
          ]);
        } else {
          setErrors(parseErrors);
        }
        setIsUploading(false);
        return;
      }

      if (flashcards.length === 0) {
        setErrors(['No valid study items found in CSV. Make sure data rows exist below the header.']);
        setIsUploading(false);
        return;
      }

      const { data: subjects } = await supabase
        .from('subjects')
        .select('id, name');

      const { data: topics } = await supabase
        .from('topics')
        .select('id, name, subject_id');

      // Validate all rows — bulk upload cannot create new subjects or topics
      const validationErrors = [];
      for (let i = 0; i < flashcards.length; i++) {
        const card = flashcards[i];
        const subject = subjects?.find(s =>
          s.name.toLowerCase() === card.subject.toLowerCase()
        );
        if (!subject) {
          validationErrors.push(`Row ${i + 1}: Subject "${card.subject}" not found. Create it via "Create Study Item" first.`);
          continue;
        }
        if (card.topic) {
          const topic = topics?.find(t =>
            t.name.toLowerCase() === card.topic.toLowerCase() &&
            t.subject_id === subject.id
          );
          if (!topic) {
            validationErrors.push(`Row ${i + 1}: Topic "${card.topic}" not found under "${card.subject}". Create it via "Create Study Item" first.`);
          }
        }
      }

      if (validationErrors.length > 0) {
        setErrors([
          'Bulk upload cannot create new subjects or topics. The following rows reference entries that don\'t exist in RevisOp:',
          '',
          ...validationErrors,
          '',
          'To fix: create the missing subject/topic via "Create Study Item" first, then re-download Valid Entries and re-upload.'
        ]);
        setIsUploading(false);
        return;
      }

      const batchId = crypto.randomUUID();
      const trimmedDescription = batchDescription.trim() || null;

      // ── Build card list + collect unique deck groups for naming ──────────────
      const deckGroupMap = new Map();
      // case_study_mcq rows don't share the file-wide batchId above — each case
      // (rows sharing a case_group value) gets its OWN batch_id instead, so the
      // case's questions group together for display without merging into
      // whatever else this CSV upload also happens to contain (D-01 pattern).
      const caseGroupBatchIds = new Map();

      const flashcardsToInsert = flashcards.map(card => {
        const subject = subjects?.find(s =>
          s.name.toLowerCase() === card.subject.toLowerCase()
        );

        const topic = card.topic ? topics?.find(t =>
          t.name.toLowerCase() === card.topic.toLowerCase() &&
          t.subject_id === subject.id
        ) : null;

        // Track unique (subject_id, topic_id) combinations for post-insert naming
        const groupKey = `${subject.id}::${topic?.id ?? 'null'}`;
        if (!deckGroupMap.has(groupKey)) {
          // Use user's batch label if provided, otherwise derive from subject/topic
          const deckName = trimmedDescription
            ? trimmedDescription
            : topic
              ? `${card.subject} — ${card.topic}`
              : card.subject;
          deckGroupMap.set(groupKey, {
            subject_id: subject.id,
            topic_id: topic?.id ?? null,
            name: deckName,
          });
        }

        let rowBatchId = batchId;
        let rowScenario = null;
        if (card.question_type === 'case_study_mcq') {
          if (!caseGroupBatchIds.has(card.case_group)) {
            caseGroupBatchIds.set(card.case_group, crypto.randomUUID());
          }
          rowBatchId = caseGroupBatchIds.get(card.case_group);
          rowScenario = card.scenario;
        }

        return {
          user_id: user.id,
          contributed_by: user.id,
          target_course: card.target_course,
          subject_id: subject.id,
          topic_id: topic?.id || null,
          custom_subject: null,
          custom_topic: null,
          front_text: card.front,
          back_text: card.back,
          tags: card.tags || [],
          difficulty: card.difficulty || 'medium',
          visibility: bulkVisibility,
          is_verified: isProfessor || isAdmin || isSuperAdmin,
          batch_id: rowBatchId,
          batch_description: trimmedDescription,
          question_type: card.question_type,
          options: hasCsvOptions(card.question_type) ? card.gradedOptions : null,
          // fitb and match_the_following stay NULL here (D-13/D-10 rep. note — no single
          // scalar "the answer"), unlike mcq/correct_incorrect/case_study_mcq's stringified
          // index. mcq_multi stores the already-canonicalized SET string ("0;2;4") computed
          // above, not a single stringified index.
          correct_answer: card.question_type === 'mcq_multi'
            ? card.gradedCorrectAnswer
            : (GRADED_QUESTION_TYPES.includes(card.question_type) ? String(card.gradedCorrectIndex) : null),
          points_to_remember: null,
          explanation: hasCsvExplanation(card.question_type) ? (card.explanation || null) : null,
          subtype: card.question_type === 'theory' ? card.subtype : null,
          scenario: rowScenario,
        };
      });

      const { data, error } = await supabase
        .from('flashcards')
        .insert(flashcardsToInsert)
        .select();

      if (error) throw error;

      // ── Name any decks that the trigger just created (trigger sets name=NULL) ─
      // Only updates rows where name IS NULL — never overwrites an existing name.
      for (const group of deckGroupMap.values()) {
        let query = supabase
          .from('flashcard_decks')
          .update({ name: group.name })
          .eq('user_id', user.id)
          .is('custom_subject', null)
          .is('custom_topic', null)
          .is('name', null);

        query = group.subject_id
          ? query.eq('subject_id', group.subject_id)
          : query.is('subject_id', null);

        query = group.topic_id
          ? query.eq('topic_id', group.topic_id)
          : query.is('topic_id', null);

        await query;
      }

      setUploadResults({
        success: true,
        count: data.length,
        flashcards: data
      });

      // Audit log (non-critical)
      try {
        await supabase.from('admin_audit_log').insert({
          action: 'bulk_upload_flashcards',
          admin_id: user.id,
          details: {
            count: data.length,
            filename: csvFile.name,
            batch_description: trimmedDescription,
            visibility: bulkVisibility
          }
        });
      } catch (auditError) {
        console.log('Audit log failed (non-critical):', auditError);
      }

      // Reset form
      setCsvFile(null);
      setBatchDescription('');
      const fileInput = document.getElementById('csv-upload');
      if (fileInput) fileInput.value = '';

    } catch (error) {
      console.error('Upload error:', error);
      if (error.code === '42501') {
        setErrors([
          'Upload failed: one or more rows use a question_type (mcq, mcq_multi, correct_incorrect, case_study_mcq, fitb, match_the_following) that requires a professor/admin account.',
          'No rows were created (the whole file is uploaded as one batch) — remove those rows or upload from a professor/admin account.',
        ]);
      } else {
        setErrors([`Upload failed: ${error.message}`]);
      }
    } finally {
      setIsUploading(false);
    }
  }

  // ─── Reset for another upload ───
  function resetAll() {
    setUploadResults(null);
    setErrors([]);
    setCsvFile(null);
    setBatchDescription('');
    setBulkVisibility('public');
    setTemplateDownloaded(false);
    setValidEntriesDownloaded(false);
    setOpenStep(1);
    const fileInput = document.getElementById('csv-upload');
    if (fileInput) fileInput.value = '';
  }

  // ─── Loading state ───
  if (roleLoading) {
    return (
      <PageContainer width="medium">
        <div className="flex items-center justify-center py-20">
          <div className="text-center">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-[#1e1b4b] mx-auto mb-3"></div>
            <p className="text-gray-500 text-sm">Loading...</p>
          </div>
        </div>
      </PageContainer>
    );
  }

  // ─── Success state — replaces stepper ───
  if (uploadResults?.success) {
    return (
      <PageContainer width="medium">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Bulk Upload Study Items</h1>
          <p className="text-sm text-gray-500 mt-1">Upload multiple study items via CSV</p>
        </div>

        <Card>
          <CardContent className="p-8 text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="h-8 w-8 text-green-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">
              Upload Complete!
            </h2>
            <p className="text-gray-600 mb-1">
              Successfully uploaded <strong>{uploadResults.count}</strong> study item{uploadResults.count !== 1 ? 's' : ''}
            </p>
            {batchDescription.trim() && (
              <p className="text-sm text-gray-500 mb-1">
                Batch: {batchDescription.trim()}
              </p>
            )}
            <p className="text-sm text-gray-500 mb-6">
              Visibility: {bulkVisibility === 'private' ? 'Private' : bulkVisibility === 'friends' ? 'Friends Only' : 'Public'}
            </p>
            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <Button onClick={resetAll}>
                <Upload className="h-4 w-4 mr-2" />
                Upload More
              </Button>
              <Button variant="outline" onClick={() => navigate('/dashboard/flashcards')}>
                <FileText className="h-4 w-4 mr-2" />
                View My Study Sets
              </Button>
            </div>
          </CardContent>
        </Card>
      </PageContainer>
    );
  }

  // ─── Main stepper UI ───
  return (
    <PageContainer width="medium">
      {/* Page header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Bulk Upload Study Items</h1>
        <p className="text-sm text-gray-500 mt-1">Upload multiple study items via CSV in 3 simple steps</p>
      </div>

      <div className="space-y-3">
        {/* ─── STEP 1: Download Files ─── */}
        <Step
          number={1}
          title="Download Files"
          subtitle={step1Complete ? 'Template & valid entries downloaded' : 'Get the template and reference file'}
          isOpen={openStep === 1}
          isComplete={step1Complete}
          onToggle={() => setOpenStep(openStep === 1 ? 0 : 1)}
        >
          <div className="space-y-5">
            {/* Template download */}
            <div>
              <div className="flex items-center justify-between mb-1">
                <p className="text-sm font-medium text-gray-700">Blank Template</p>
                {templateDownloaded && (
                  <span className="text-xs text-green-600 flex items-center gap-1">
                    <CheckCircle className="h-3 w-3" /> Downloaded
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-500 mb-2">CSV with all required columns and usage instructions</p>
              <Button size="sm" variant="outline" onClick={downloadTemplate}>
                <Download className="h-3.5 w-3.5 mr-1.5" />
                Download Template
              </Button>
            </div>

            {/* Valid entries download */}
            <div className="border-t pt-4">
              <div className="flex items-center justify-between mb-1">
                <p className="text-sm font-medium text-gray-700">Valid Entries (Reference)</p>
                {validEntriesDownloaded && (
                  <span className="text-xs text-green-600 flex items-center gap-1">
                    <CheckCircle className="h-3 w-3" /> Downloaded
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-500 mb-3">
                List of all courses, subjects & topics — copy exact names from here into your template.
              </p>

              <div className="flex flex-col sm:flex-row sm:items-end gap-3">
                <div className="flex-1 sm:max-w-[220px]">
                  <Label htmlFor="course-select" className="text-xs text-gray-500 mb-1 block">Course</Label>
                  <Select value={selectedCourse} onValueChange={setSelectedCourse}>
                    <SelectTrigger id="course-select" className="h-9">
                      <SelectValue placeholder="Select course..." />
                    </SelectTrigger>
                    <SelectContent>
                      {courses.map(course => (
                        <SelectItem key={course.id} value={course.id}>
                          {course.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={downloadValidEntries}
                  disabled={!selectedCourse || isLoadingStats}
                >
                  <Download className="h-3.5 w-3.5 mr-1.5" />
                  Download Valid Entries
                </Button>
              </div>

              {selectedCourse && courseStats.subjects > 0 && (
                <p className="text-xs text-green-700 mt-2">
                  {courseStats.subjects} subjects, {courseStats.topics} topics available
                </p>
              )}

              {selectedCourse && courseStats.subjects > 0 && courseStats.topics === 0 && (
                <p className="text-xs text-amber-700 mt-2">
                  No topics found for this course. Add some via Create Study Item first.
                </p>
              )}
            </div>

            {/* Inline hint about missing entries */}
            <p className="text-xs text-gray-500 border-t pt-3">
              Don't see your subject/topic? Create one via{' '}
              <button type="button" className="text-amber-600 hover:underline font-medium" onClick={() => navigate('/dashboard/flashcards/new')}>
                Create Study Item
              </button>{' '}
              or{' '}
              <button type="button" className="text-amber-600 hover:underline font-medium" onClick={() => navigate('/dashboard/notes/new')}>
                Upload Note
              </button>{' '}
              first, then re-download Valid Entries.
            </p>

            {/* Next step shortcut */}
            <div className="pt-1">
              <Button size="sm" onClick={() => setOpenStep(2)} className="gap-1.5">
                Next: Prepare CSV <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        </Step>

        {/* ─── STEP 2: Prepare Your CSV ─── */}
        <Step
          number={2}
          title="Prepare & Select CSV"
          subtitle={step2Complete ? csvFile.name : 'Fill template, choose file & settings'}
          isOpen={openStep === 2}
          isComplete={step2Complete}
          onToggle={() => setOpenStep(openStep === 2 ? 0 : 2)}
        >
          <div className="space-y-4">
            {/* First-timer nudge */}
            {!step1Complete && (
              <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 rounded-md px-3 py-2">
                <Info className="h-3.5 w-3.5 text-amber-600 mt-0.5 flex-shrink-0" />
                <p className="text-xs text-amber-800">
                  First time? <button type="button" className="font-medium underline" onClick={() => setOpenStep(1)}>Download the template and valid entries</button> from Step 1 first.
                </p>
              </div>
            )}

            {/* Required columns hint */}
            <div className="bg-gray-50 border border-gray-200 rounded-md px-3 py-2">
              <p className="text-xs text-gray-600">
                <span className="font-semibold">Required columns:</span>{' '}
                <code className="text-amber-700 bg-amber-50 px-1 rounded">target_course</code>,{' '}
                <code className="text-amber-700 bg-amber-50 px-1 rounded">subject</code>,{' '}
                <code className="text-amber-700 bg-amber-50 px-1 rounded">front</code>,{' '}
                <code className="text-amber-700 bg-amber-50 px-1 rounded">back</code>{' '}
                <span className="text-gray-400 ml-1">|</span>{' '}
                <span className="text-gray-500">Optional:</span>{' '}
                <code className="text-gray-500 bg-gray-100 px-1 rounded">topic</code>,{' '}
                <code className="text-gray-500 bg-gray-100 px-1 rounded">tags</code>,{' '}
                <code className="text-gray-500 bg-gray-100 px-1 rounded">difficulty</code>
              </p>
            </div>

            {/* Batch description */}
            <div>
              <Label htmlFor="batch-description" className="text-sm">
                Batch Label <span className="text-gray-400 font-normal">(optional)</span>
              </Label>
              <Input
                id="batch-description"
                value={batchDescription}
                onChange={(e) => setBatchDescription(e.target.value)}
                placeholder="e.g., Treasury Management - Part 1"
                className="mt-1"
              />
            </div>

            {/* Visibility */}
            <div>
              <Label htmlFor="bulk-visibility" className="text-sm">Visibility</Label>
              <Select value={bulkVisibility} onValueChange={setBulkVisibility}>
                <SelectTrigger id="bulk-visibility" className="mt-1">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="private">Private (Only me)</SelectItem>
                  <SelectItem value="friends">Friends Only</SelectItem>
                  <SelectItem value="public">Public (Everyone)</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* File picker */}
            <div>
              <Label className="text-sm mb-1.5 block">CSV File</Label>
              <input
                id="csv-upload"
                type="file"
                accept=".csv"
                onChange={handleFileSelect}
                className="block w-full text-sm text-gray-500
                  file:mr-4 file:py-2 file:px-4
                  file:rounded-md file:border-0
                  file:text-sm file:font-semibold
                  file:bg-amber-50 file:text-amber-700
                  hover:file:bg-amber-100
                  cursor-pointer"
              />
              {csvFile && (
                <p className="mt-1.5 text-xs text-green-700 flex items-center gap-1">
                  <CheckCircle className="h-3 w-3" /> {csvFile.name}
                </p>
              )}
            </div>

            {/* Next step shortcut */}
            <div className="pt-1">
              <Button
                size="sm"
                onClick={() => setOpenStep(3)}
                disabled={!step2Complete}
                className="gap-1.5"
              >
                Next: Upload <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        </Step>

        {/* ─── STEP 3: Upload ─── */}
        <Step
          number={3}
          title="Upload"
          subtitle={isUploading ? 'Uploading...' : 'Review and upload study items'}
          isOpen={openStep === 3}
          isComplete={false}
          onToggle={() => setOpenStep(openStep === 3 ? 0 : 3)}
        >
          <div className="space-y-4">
            {/* Guard: no file selected */}
            {!csvFile ? (
              <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 rounded-md px-3 py-2">
                <Info className="h-3.5 w-3.5 text-amber-600 mt-0.5 flex-shrink-0" />
                <p className="text-xs text-amber-800">
                  No file selected. <button type="button" className="font-medium underline" onClick={() => setOpenStep(2)}>Go to Step 2</button> to pick your CSV file.
                </p>
              </div>
            ) : (
              <>
                {/* Summary */}
                <div className="bg-gray-50 border border-gray-200 rounded-md p-3 text-sm space-y-1">
                  <p><span className="text-gray-500">File:</span> <span className="font-medium">{csvFile.name}</span></p>
                  <p><span className="text-gray-500">Visibility:</span> <span className="font-medium">{bulkVisibility === 'private' ? 'Private' : bulkVisibility === 'friends' ? 'Friends Only' : 'Public'}</span></p>
                  {batchDescription.trim() && (
                    <p><span className="text-gray-500">Batch:</span> <span className="font-medium">{batchDescription.trim()}</span></p>
                  )}
                </div>

                {/* Upload button */}
                <Button
                  onClick={uploadFlashcards}
                  disabled={!csvFile || isUploading}
                  className="w-full"
                  size="lg"
                >
                  {isUploading ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Uploading...
                    </>
                  ) : (
                    <>
                      <Upload className="h-4 w-4 mr-2" />
                      Upload Study Items
                    </>
                  )}
                </Button>
              </>
            )}

            {/* Errors */}
            {errors.length > 0 && (
              <Alert variant="destructive">
                <XCircle className="h-4 w-4" />
                <AlertDescription>
                  <div className="space-y-1">
                    {errors.map((error, index) => (
                      <p key={index} className={error === '' ? 'h-1' : ''}>
                        {error}
                      </p>
                    ))}
                  </div>
                </AlertDescription>
              </Alert>
            )}
          </div>
        </Step>
      </div>
    </PageContainer>
  );
}
