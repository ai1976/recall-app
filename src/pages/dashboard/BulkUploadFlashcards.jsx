import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
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

// ─── Stepper step component ───
function Step({ number, title, subtitle, isOpen, isComplete, onToggle, children }) {
  return (
    <div className={`border rounded-lg transition-colors ${isOpen ? 'border-blue-300 bg-blue-50/30' : isComplete ? 'border-green-200 bg-green-50/20' : 'border-gray-200'}`}>
      <button
        type="button"
        onClick={onToggle}
        className="w-full flex items-center gap-3 p-4 text-left cursor-pointer hover:bg-gray-50/50"
      >
        {/* Step circle */}
        <div className={`
          w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold
          ${isComplete ? 'bg-green-500 text-white' : isOpen ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-600'}
        `}>
          {isComplete ? <CheckCircle className="h-5 w-5" /> : number}
        </div>

        {/* Title + subtitle */}
        <div className="flex-1 min-w-0">
          <p className={`font-medium ${isOpen ? 'text-blue-900' : isComplete ? 'text-green-800' : 'text-gray-700'}`}>
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
    const template = '\uFEFF' + `target_course,subject,topic,front,back,tags,difficulty
CA Intermediate,Taxation,Income Tax Basics,What is the basic exemption limit for individuals below 60 years?,₹2.5 lakhs,"#ITR,#basics",easy
CA Intermediate,Advanced Accounting,AS 1,What is AS 1?,Disclosure of Accounting Policies,"#AS,#important",medium
CA Foundation,Quantitative Aptitude,Percentages,What is 20% of 500?,100,,medium

==================================================
HOW TO USE THIS TEMPLATE
==================================================

1. Download the "Valid Entries" CSV from the Bulk Upload page
2. Copy EXACT course, subject & topic names from that file
3. Fill in your flashcard front/back content
4. Save as UTF-8 CSV and upload

COLUMNS:
- target_course (REQUIRED) - Must match Valid Entries exactly
- subject (REQUIRED) - Must match Valid Entries exactly
- topic (optional) - Must match Valid Entries if provided
- front (REQUIRED) - Question / front side
- back (REQUIRED) - Answer / back side
- tags (optional) - Comma-separated, e.g. "#ITR,#basics"
- difficulty (optional) - easy / medium / hard (defaults to medium)

IMPORTANT:
✓ Use EXACT spelling from Valid Entries file
✓ Special characters like ₹ are supported (save as UTF-8)
✓ Cannot create new courses/subjects/topics via bulk upload
✓ To add a new subject/topic, create one flashcard via "Create Flashcard" first
✓ Visibility is set on the upload page (private / friends / public)
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
      a.download = `recall_valid_entries_${course.name.replace(/\s+/g, '_')}.csv`;
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

              if (!flashcard.target_course || !flashcard.subject || !flashcard.front || !flashcard.back) {
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

              flashcards.push(flashcard);
            } catch (error) {
              parseErrors.push(`Row ${i + 1}: ${error.message}`);
            }
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
            'To fix: create the missing subject/topic via "Create Flashcard" first, then re-download Valid Entries and try again.'
          ]);
        } else {
          setErrors(parseErrors);
        }
        setIsUploading(false);
        return;
      }

      if (flashcards.length === 0) {
        setErrors(['No valid flashcards found in CSV. Make sure data rows exist below the header.']);
        setIsUploading(false);
        return;
      }

      const { data: subjects } = await supabase
        .from('subjects')
        .select('id, name');

      const { data: topics } = await supabase
        .from('topics')
        .select('id, name, subject_id');

      const batchId = crypto.randomUUID();
      const trimmedDescription = batchDescription.trim() || null;

      const flashcardsToInsert = flashcards.map(card => {
        const subject = subjects?.find(s =>
          s.name.toLowerCase() === card.subject.toLowerCase()
        );

        const topic = topics?.find(t =>
          t.name.toLowerCase() === (card.topic || '').toLowerCase() &&
          (!subject || t.subject_id === subject.id)
        );

        return {
          user_id: user.id,
          contributed_by: user.id,
          target_course: card.target_course,
          subject_id: subject?.id || null,
          topic_id: topic?.id || null,
          custom_subject: subject ? null : card.subject,
          custom_topic: (topic || !card.topic) ? null : card.topic,
          front_text: card.front,
          back_text: card.back,
          tags: card.tags || [],
          difficulty: card.difficulty || 'medium',
          visibility: bulkVisibility,
          is_public: bulkVisibility === 'public',
          is_verified: isProfessor || isAdmin || isSuperAdmin,
          batch_id: batchId,
          batch_description: trimmedDescription
        };
      });

      const { data, error } = await supabase
        .from('flashcards')
        .insert(flashcardsToInsert)
        .select();

      if (error) throw error;

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
      setErrors([`Upload failed: ${error.message}`]);
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
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600 mx-auto mb-3"></div>
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
          <h1 className="text-2xl font-bold text-gray-900">Bulk Upload Flashcards</h1>
          <p className="text-sm text-gray-500 mt-1">Upload multiple flashcards via CSV</p>
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
              Successfully uploaded <strong>{uploadResults.count}</strong> flashcard{uploadResults.count !== 1 ? 's' : ''}
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
                View My Flashcards
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
        <h1 className="text-2xl font-bold text-gray-900">Bulk Upload Flashcards</h1>
        <p className="text-sm text-gray-500 mt-1">Upload multiple flashcards via CSV in 3 simple steps</p>
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
                  No topics found for this course. Add some via Create Flashcard first.
                </p>
              )}
            </div>

            {/* Inline hint about missing entries */}
            <p className="text-xs text-gray-500 border-t pt-3">
              Don't see your subject/topic? Create one via{' '}
              <button type="button" className="text-blue-600 hover:underline font-medium" onClick={() => navigate('/dashboard/flashcards/new')}>
                Create Flashcard
              </button>{' '}
              or{' '}
              <button type="button" className="text-blue-600 hover:underline font-medium" onClick={() => navigate('/dashboard/notes/new')}>
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
                <code className="text-blue-700 bg-blue-50 px-1 rounded">target_course</code>,{' '}
                <code className="text-blue-700 bg-blue-50 px-1 rounded">subject</code>,{' '}
                <code className="text-blue-700 bg-blue-50 px-1 rounded">front</code>,{' '}
                <code className="text-blue-700 bg-blue-50 px-1 rounded">back</code>{' '}
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
                  file:bg-blue-50 file:text-blue-700
                  hover:file:bg-blue-100
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
          subtitle={isUploading ? 'Uploading...' : 'Review and upload flashcards'}
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
                      Upload Flashcards
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
