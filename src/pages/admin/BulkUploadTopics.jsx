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
import { Upload, CheckCircle, XCircle, Download, ChevronDown, ChevronUp, AlertCircle, ArrowRight, ArrowLeft, Info, Plus, X } from 'lucide-react';

// ─── Generate short code from course name ───
// "CA Final" → "CAFIN", "Spanish Level 1" → "SPALEV1"
// Takes first 2-3 chars of each word, uppercase, max 8 chars
function generateCode(name) {
  if (!name) return '';
  const words = name.trim().split(/\s+/);
  let code = '';
  for (const word of words) {
    // For short words (≤3 chars), take entire word; otherwise take first 3 chars
    const chunk = word.length <= 3 ? word : word.slice(0, 3);
    code += chunk.toUpperCase();
  }
  // Cap at 8 characters
  return code.slice(0, 8);
}

// ─── Title Case utility ───
function toTitleCase(str) {
  if (!str) return str;
  return str
    .trim()
    .split(/\s+/)
    .map(word => {
      // Keep common abbreviations / acronyms uppercase (AS, IT, GST, etc.)
      if (word.length <= 3 && word === word.toUpperCase() && /^[A-Z]+$/.test(word)) {
        return word;
      }
      // Keep words that are already mixed-case (e.g., "McGregor") as-is
      if (/[A-Z]/.test(word.slice(1)) && /[a-z]/.test(word)) {
        return word;
      }
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(' ');
}

// ─── Stepper step component (shared design with BulkUploadFlashcards) ───
function Step({ number, title, subtitle, isOpen, isComplete, onToggle, children }) {
  return (
    <div className={`border rounded-lg transition-colors ${isOpen ? 'border-blue-300 bg-blue-50/30' : isComplete ? 'border-green-200 bg-green-50/20' : 'border-gray-200'}`}>
      <button
        type="button"
        onClick={onToggle}
        className="w-full flex items-center gap-3 p-4 text-left cursor-pointer hover:bg-gray-50/50"
      >
        <div className={`
          w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-sm font-bold
          ${isComplete ? 'bg-green-500 text-white' : isOpen ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-600'}
        `}>
          {isComplete ? <CheckCircle className="h-5 w-5" /> : number}
        </div>

        <div className="flex-1 min-w-0">
          <p className={`font-medium ${isOpen ? 'text-blue-900' : isComplete ? 'text-green-800' : 'text-gray-700'}`}>
            {title}
          </p>
          {subtitle && !isOpen && (
            <p className="text-xs text-gray-500 truncate">{subtitle}</p>
          )}
        </div>

        {isOpen
          ? <ChevronUp className="h-4 w-4 text-gray-400 flex-shrink-0" />
          : <ChevronDown className="h-4 w-4 text-gray-400 flex-shrink-0" />
        }
      </button>

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

export default function BulkUploadTopics() {
  const { isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();
  const { user } = useAuth();
  const navigate = useNavigate();

  // Stepper
  const [openStep, setOpenStep] = useState(1);

  // Step 1: Select course & download
  const [courses, setCourses] = useState([]);
  const [selectedCourse, setSelectedCourse] = useState(null);
  const [courseStats, setCourseStats] = useState({ subjects: 0, topics: 0 });
  const [isLoadingStats, setIsLoadingStats] = useState(false);
  const [templateDownloaded, setTemplateDownloaded] = useState(false);
  const [currentEntriesDownloaded, setCurrentEntriesDownloaded] = useState(false);

  // Create New Course inline form
  const [showCreateCourse, setShowCreateCourse] = useState(false);
  const [newCourseName, setNewCourseName] = useState('');
  const [isCreatingCourse, setIsCreatingCourse] = useState(false);
  const [createCourseError, setCreateCourseError] = useState('');

  // Step 2: Select file
  const [csvFile, setCsvFile] = useState(null);

  // Step 3: Upload
  const [isUploading, setIsUploading] = useState(false);
  const [uploadResults, setUploadResults] = useState(null);
  const [errors, setErrors] = useState([]);

  // Completeness (visual only, not gates)
  const step1Complete = !!selectedCourse && templateDownloaded;
  const step2Complete = !!csvFile;

  // ─── Load courses ───
  useEffect(() => {
    if (!roleLoading && (isAdmin || isSuperAdmin)) {
      loadCourses();
    }
  }, [roleLoading, isAdmin, isSuperAdmin]);

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

  // ─── Create New Course ───
  async function handleCreateCourse() {
    const trimmedName = newCourseName.trim();
    if (!trimmedName) {
      setCreateCourseError('Course name is required');
      return;
    }

    // Title Case the name
    const titleCasedName = toTitleCase(trimmedName);

    // Case-insensitive duplicate check against loaded courses
    const duplicate = courses.find(c => c.name.toLowerCase() === titleCasedName.toLowerCase());
    if (duplicate) {
      setCreateCourseError(`"${duplicate.name}" already exists. Select it from the dropdown.`);
      return;
    }

    setIsCreatingCourse(true);
    setCreateCourseError('');

    try {
      const code = generateCode(titleCasedName);

      const { data, error } = await supabase
        .from('disciplines')
        .insert({
          name: titleCasedName,
          code: code
        })
        .select()
        .single();

      if (error) {
        // Catch DB-level unique constraint
        if (error.message.includes('duplicate') || error.message.includes('unique')) {
          setCreateCourseError(`"${titleCasedName}" already exists in the database.`);
        } else {
          setCreateCourseError(`Failed to create: ${error.message}`);
        }
        return;
      }

      // Add to list, select it, close form
      setCourses(prev => [...prev, { id: data.id, name: data.name }].sort((a, b) => a.name.localeCompare(b.name)));
      setSelectedCourse(data.id);
      setNewCourseName('');
      setShowCreateCourse(false);

      // Audit log
      try {
        await supabase.from('admin_audit_log').insert({
          action: 'create_discipline',
          admin_id: user.id,
          details: { discipline_id: data.id, name: data.name }
        });
      } catch (auditErr) {
        console.log('Audit log failed (non-critical):', auditErr);
      }
    } catch (error) {
      setCreateCourseError(`Unexpected error: ${error.message}`);
    } finally {
      setIsCreatingCourse(false);
    }
  }

  // ─── Download: Template CSV ───
  function downloadTemplate() {
    const template = '\uFEFF' + `subject,topic,description,subject_sort_order,sort_order
Grammar,Present Tense,Basic verb conjugations,1,1
Grammar,Past Tense,Past tense formation,1,2
Grammar,Future Tense,,1,3
Vocabulary,Common Phrases,Everyday expressions,2,1
Vocabulary,Food & Dining,Restaurant and food vocabulary,2,2
Vocabulary,Travel & Directions,,2,3

==================================================
HOW TO USE THIS TEMPLATE
==================================================

1. Select or create a COURSE on the Bulk Upload page
2. Fill in subject and topic names below
3. If the subject already exists, the topic is added under it
4. If the subject is new, it will be created automatically
5. Duplicate entries (subject+topic already in DB) are skipped

COLUMNS:
- subject (REQUIRED) - The subject name
- topic (REQUIRED) - The topic name
- description (optional) - Short description for the topic
- subject_sort_order (optional) - Display order for the subject (integer). Default: 0 (alphabetical)
- sort_order (optional) - Display order for the topic within its subject (integer). Default: 0 (alphabetical)

SORTING LOGIC:
- Items with sort_order = 0 (or blank) are sorted alphabetically
- Items with explicit numbers are sorted by that number first
- Example: sort_order 1, 2, 3 displays in that order; 0 falls back to alphabetical

DATA HYGIENE:
- Case is handled automatically ("taxation" maps to existing "Taxation")
- New entries are Title Cased ("income tax" becomes "Income Tax")
- Download "Current Entries" to see what already exists
- Each row needs BOTH subject and topic
`;

    const blob = new Blob([template], { type: 'text/csv;charset=utf-8' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'subject_topic_template.csv';
    a.click();
    window.URL.revokeObjectURL(url);
    setTemplateDownloaded(true);
  }

  // ─── Download: Current Entries CSV ───
  async function downloadCurrentEntries() {
    if (!selectedCourse) {
      alert('Please select a course first');
      return;
    }

    try {
      const course = courses.find(c => c.id === selectedCourse);
      if (!course) return;

      const { data: subjects, error: subError } = await supabase
        .from('subjects')
        .select('id, name, sort_order')
        .eq('discipline_id', selectedCourse)
        .order('sort_order', { ascending: true })
        .order('name', { ascending: true });

      if (subError) throw subError;

      const subjectIds = subjects?.map(s => s.id) || [];
      let topics = [];
      if (subjectIds.length > 0) {
        const { data: topicData, error: topError } = await supabase
          .from('topics')
          .select('id, name, subject_id, description, sort_order')
          .in('subject_id', subjectIds)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (topError) throw topError;
        topics = topicData || [];
      }

      let csv = '\uFEFF';
      csv += `Course: ${course.name}\n`;
      csv += 'Subject,Topic,Description,Subject Sort Order,Topic Sort Order\n';

      // Output grouped by subject order
      subjects?.forEach(subject => {
        const subjectTopics = topics.filter(t => t.subject_id === subject.id);

        if (subjectTopics.length === 0) {
          csv += `"${subject.name}","(no topics yet)","",${subject.sort_order || 0},\n`;
        } else {
          subjectTopics.forEach(topic => {
            csv += `"${subject.name}","${topic.name}","${topic.description || ''}",${subject.sort_order || 0},${topic.sort_order || 0}\n`;
          });
        }
      });

      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `current_entries_${course.name.replace(/\s+/g, '_')}.csv`;
      a.click();
      window.URL.revokeObjectURL(url);
      setCurrentEntriesDownloaded(true);
    } catch (error) {
      console.error('Error downloading current entries:', error);
      alert('Failed to download current entries. Please try again.');
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

  // ─── CSV line parser ───
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

  // ─── Parse CSV ───
  async function parseCSV(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = function (event) {
        try {
          let text = event.target.result;

          if (text.charCodeAt(0) === 0xFEFF) {
            text = text.substring(1);
          }

          const rows = [];
          const parseErrors = [];

          // Handle multi-line cells
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
            resolve({ rows: [], errors: ['CSV file is empty'] });
            return;
          }

          // Skip lines that start with "Course:" (current entries header)
          let startIdx = 0;
          if (lines[0].startsWith('Course:')) {
            startIdx = 1;
          }

          // Parse header
          const headers = parseCSVLine(lines[startIdx]).map(h => h.trim().toLowerCase().replace(/\s+/g, '_'));
          const subjectIdx = headers.indexOf('subject');
          const topicIdx = headers.indexOf('topic');
          const descIdx = headers.indexOf('description');
          const subjectSortIdx = headers.indexOf('subject_sort_order');
          const topicSortIdx = headers.indexOf('sort_order');
          // Also check alternate header names from current entries download
          const topicSortIdxAlt = headers.indexOf('topic_sort_order');

          if (subjectIdx === -1 || topicIdx === -1) {
            resolve({ rows: [], errors: ['CSV must have "subject" and "topic" columns'] });
            return;
          }

          for (let i = startIdx + 1; i < lines.length; i++) {
            const line = lines[i];

            // Skip instruction lines
            if (line.includes('====') || line.includes('HOW TO USE') ||
              line.includes('COLUMNS:') || line.includes('IMPORTANT:') ||
              line.includes('SORTING LOGIC:') || line.includes('DATA HYGIENE:') ||
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

              const subject = (values[subjectIdx] || '').trim().replace(/^["']|["']$/g, '');
              const topic = (values[topicIdx] || '').trim().replace(/^["']|["']$/g, '');
              const description = descIdx >= 0 ? (values[descIdx] || '').trim().replace(/^["']|["']$/g, '') : '';

              // Parse sort orders — accept integer or default to 0
              const rawSubjectSort = subjectSortIdx >= 0 ? (values[subjectSortIdx] || '').trim().replace(/^["']|["']$/g, '') : '';
              const subjectSortOrder = rawSubjectSort !== '' && !isNaN(rawSubjectSort) ? parseInt(rawSubjectSort, 10) : 0;

              const effectiveTopicSortIdx = topicSortIdx >= 0 ? topicSortIdx : topicSortIdxAlt;
              const rawTopicSort = effectiveTopicSortIdx >= 0 ? (values[effectiveTopicSortIdx] || '').trim().replace(/^["']|["']$/g, '') : '';
              const topicSortOrder = rawTopicSort !== '' && !isNaN(rawTopicSort) ? parseInt(rawTopicSort, 10) : 0;

              if (!subject || !topic) {
                parseErrors.push(`Row ${i + 1}: Missing subject or topic`);
                continue;
              }

              // Skip placeholder rows from current entries download
              if (topic === '(no topics yet)') {
                continue;
              }

              rows.push({ subject, topic, description, subjectSortOrder, topicSortOrder });
            } catch (error) {
              parseErrors.push(`Row ${i + 1}: ${error.message}`);
            }
          }

          resolve({ rows, errors: parseErrors });
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

  // ─── Upload subjects & topics ───
  async function uploadTopics() {
    if (!csvFile || !selectedCourse) {
      alert('Please select a course and CSV file first');
      return;
    }

    setIsUploading(true);
    setErrors([]);

    try {
      const { rows, errors: parseErrors } = await parseCSV(csvFile);

      if (parseErrors.length > 0) {
        setErrors(parseErrors);
        setIsUploading(false);
        return;
      }

      if (rows.length === 0) {
        setErrors(['No valid rows found in CSV. Ensure data rows exist below the header.']);
        setIsUploading(false);
        return;
      }

      // Fetch existing subjects for this course
      const { data: existingSubjects, error: subError } = await supabase
        .from('subjects')
        .select('id, name, sort_order')
        .eq('discipline_id', selectedCourse);

      if (subError) throw subError;

      // Fetch existing topics for these subjects
      const existingSubjectIds = existingSubjects?.map(s => s.id) || [];
      let existingTopics = [];
      if (existingSubjectIds.length > 0) {
        const { data: topicData, error: topError } = await supabase
          .from('topics')
          .select('id, name, subject_id')
          .in('subject_id', existingSubjectIds);

        if (topError) throw topError;
        existingTopics = topicData || [];
      }

      // Build lookup maps (case-insensitive)
      const subjectMap = new Map(); // lowercase name → { id, name, sort_order }
      existingSubjects?.forEach(s => {
        subjectMap.set(s.name.toLowerCase(), { id: s.id, name: s.name, sort_order: s.sort_order });
      });

      const topicSet = new Set(); // "subjectId|topicNameLower"
      existingTopics.forEach(t => {
        topicSet.add(`${t.subject_id}|${t.name.toLowerCase()}`);
      });

      let subjectsCreated = 0;
      let topicsCreated = 0;
      let skipped = 0;
      const uploadErrors = [];

      // Group rows by subject for efficient batch processing
      const groupedBySubject = new Map();
      rows.forEach(row => {
        const key = row.subject.toLowerCase();
        if (!groupedBySubject.has(key)) {
          groupedBySubject.set(key, { originalName: row.subject, subjectSortOrder: row.subjectSortOrder, topics: [] });
        }
        groupedBySubject.get(key).topics.push(row);
        // Use the first non-zero sort_order encountered for the subject
        if (row.subjectSortOrder !== 0 && groupedBySubject.get(key).subjectSortOrder === 0) {
          groupedBySubject.get(key).subjectSortOrder = row.subjectSortOrder;
        }
      });

      // Process each subject group
      for (const [subjectKey, group] of groupedBySubject) {
        let subjectRecord = subjectMap.get(subjectKey);

        // Create subject if it doesn't exist
        if (!subjectRecord) {
          const titleCasedName = toTitleCase(group.originalName);

          const { data: newSubject, error: createError } = await supabase
            .from('subjects')
            .insert({
              discipline_id: selectedCourse,
              name: titleCasedName,
              is_active: true,
              sort_order: group.subjectSortOrder || 0
            })
            .select()
            .single();

          if (createError) {
            uploadErrors.push(`Failed to create subject "${titleCasedName}": ${createError.message}`);
            continue;
          }

          subjectRecord = { id: newSubject.id, name: newSubject.name, sort_order: newSubject.sort_order };
          subjectMap.set(subjectKey, subjectRecord);
          subjectsCreated++;
        } else if (group.subjectSortOrder !== 0 && subjectRecord.sort_order === 0) {
          // Update existing subject's sort_order if CSV provides one and DB has default 0
          try {
            await supabase
              .from('subjects')
              .update({ sort_order: group.subjectSortOrder })
              .eq('id', subjectRecord.id);
            subjectRecord.sort_order = group.subjectSortOrder;
          } catch (updateErr) {
            // Non-critical: sort order update failed, continue
            console.log('Subject sort_order update failed (non-critical):', updateErr);
          }
        }

        // Process topics for this subject
        const topicsToInsert = [];

        for (const row of group.topics) {
          const topicLookupKey = `${subjectRecord.id}|${row.topic.toLowerCase()}`;

          if (topicSet.has(topicLookupKey)) {
            skipped++;
            continue;
          }

          const titleCasedTopic = toTitleCase(row.topic);

          topicsToInsert.push({
            subject_id: subjectRecord.id,
            name: titleCasedTopic,
            description: row.description || null,
            is_active: true,
            sort_order: row.topicSortOrder || 0
          });

          // Mark as existing to prevent duplicates within same CSV
          topicSet.add(topicLookupKey);
        }

        if (topicsToInsert.length > 0) {
          const { data: inserted, error: insertError } = await supabase
            .from('topics')
            .insert(topicsToInsert)
            .select();

          if (insertError) {
            uploadErrors.push(`Failed to insert topics for "${subjectRecord.name}": ${insertError.message}`);
          } else {
            topicsCreated += inserted.length;
          }
        }
      }

      if (uploadErrors.length > 0) {
        setErrors(uploadErrors);
      }

      setUploadResults({
        success: true,
        subjectsCreated,
        topicsCreated,
        skipped
      });

      // Audit log
      try {
        await supabase.from('admin_audit_log').insert({
          action: 'bulk_upload_topics',
          admin_id: user.id,
          details: {
            course_id: selectedCourse,
            course_name: courses.find(c => c.id === selectedCourse)?.name,
            filename: csvFile.name,
            subjects_created: subjectsCreated,
            topics_created: topicsCreated,
            skipped
          }
        });
      } catch (auditError) {
        console.log('Audit log failed (non-critical):', auditError);
      }

      // Reset file
      setCsvFile(null);
      const fileInput = document.getElementById('csv-upload-topics');
      if (fileInput) fileInput.value = '';

      // Refresh stats
      loadCourseStats(selectedCourse);

    } catch (error) {
      console.error('Upload error:', error);
      setErrors([`Upload failed: ${error.message}`]);
    } finally {
      setIsUploading(false);
    }
  }

  // ─── Reset ───
  function resetAll() {
    setUploadResults(null);
    setErrors([]);
    setCsvFile(null);
    setTemplateDownloaded(false);
    setCurrentEntriesDownloaded(false);
    setOpenStep(1);
    const fileInput = document.getElementById('csv-upload-topics');
    if (fileInput) fileInput.value = '';
  }

  // ─── Loading ───
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

  // ─── Access denied ───
  if (!isAdmin && !isSuperAdmin) {
    return (
      <PageContainer width="medium">
        <div className="flex items-center justify-center py-20">
          <Alert variant="destructive" className="max-w-md">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              Access Denied. This page is only accessible to Administrators.
            </AlertDescription>
          </Alert>
        </div>
      </PageContainer>
    );
  }

  // ─── Success state ───
  if (uploadResults?.success) {
    return (
      <PageContainer width="medium">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Bulk Upload Subjects & Topics</h1>
          <p className="text-sm text-gray-500 mt-1">Admin tool for populating course structure</p>
        </div>

        <Card>
          <CardContent className="p-8 text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="h-8 w-8 text-green-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-3">
              Upload Complete!
            </h2>
            <div className="space-y-1 mb-6">
              {uploadResults.subjectsCreated > 0 && (
                <p className="text-gray-600">
                  <strong>{uploadResults.subjectsCreated}</strong> new subject{uploadResults.subjectsCreated !== 1 ? 's' : ''} created
                </p>
              )}
              <p className="text-gray-600">
                <strong>{uploadResults.topicsCreated}</strong> new topic{uploadResults.topicsCreated !== 1 ? 's' : ''} created
              </p>
              {uploadResults.skipped > 0 && (
                <p className="text-sm text-gray-500">
                  {uploadResults.skipped} duplicate{uploadResults.skipped !== 1 ? 's' : ''} skipped
                </p>
              )}
            </div>

            {/* Show errors if partial success */}
            {errors.length > 0 && (
              <Alert variant="destructive" className="mb-6 text-left">
                <XCircle className="h-4 w-4" />
                <AlertDescription>
                  <div className="space-y-1">
                    {errors.map((error, index) => (
                      <p key={index}>{error}</p>
                    ))}
                  </div>
                </AlertDescription>
              </Alert>
            )}

            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <Button onClick={resetAll}>
                <Upload className="h-4 w-4 mr-2" />
                Upload More
              </Button>
              <Button variant="outline" onClick={() => navigate('/admin')}>
                <ArrowLeft className="h-4 w-4 mr-2" />
                Admin Dashboard
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
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Bulk Upload Subjects & Topics</h1>
        <p className="text-sm text-gray-500 mt-1">
          Admin tool — add subjects and topics in bulk for a course
        </p>
      </div>

      <div className="space-y-3">
        {/* ─── STEP 1: Select Course & Download ─── */}
        <Step
          number={1}
          title="Select Course & Download Files"
          subtitle={step1Complete ? `${courses.find(c => c.id === selectedCourse)?.name} — template downloaded` : 'Choose a course and get reference files'}
          isOpen={openStep === 1}
          isComplete={step1Complete}
          onToggle={() => setOpenStep(openStep === 1 ? 0 : 1)}
        >
          <div className="space-y-5">
            {/* Course selector + Create New */}
            <div>
              <Label htmlFor="course-select-topics" className="text-sm font-medium text-gray-700 mb-1 block">
                Course
              </Label>
              <p className="text-xs text-gray-500 mb-2">
                Subjects and topics will be added under this course.
              </p>

              <div className="flex items-end gap-2">
                <div className="flex-1 max-w-[280px]">
                  <Select value={selectedCourse} onValueChange={setSelectedCourse}>
                    <SelectTrigger id="course-select-topics" className="h-9">
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

                {!showCreateCourse && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => { setShowCreateCourse(true); setCreateCourseError(''); setNewCourseName(''); }}
                    className="text-blue-600 hover:text-blue-700 h-9 px-2"
                  >
                    <Plus className="h-3.5 w-3.5 mr-1" />
                    New Course
                  </Button>
                )}
              </div>

              {/* Inline Create Course form */}
              {showCreateCourse && (
                <div className="mt-3 p-3 border border-blue-200 bg-blue-50/50 rounded-md space-y-2">
                  <div className="flex items-center justify-between">
                    <Label className="text-xs font-medium text-blue-800">Create New Course</Label>
                    <button
                      type="button"
                      onClick={() => { setShowCreateCourse(false); setCreateCourseError(''); }}
                      className="text-gray-400 hover:text-gray-600"
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  </div>
                  <div className="flex gap-2">
                    <Input
                      value={newCourseName}
                      onChange={(e) => { setNewCourseName(e.target.value); setCreateCourseError(''); }}
                      placeholder="e.g., Spanish Level 1"
                      className="h-8 text-sm flex-1"
                      onKeyDown={(e) => e.key === 'Enter' && handleCreateCourse()}
                    />
                    <Button
                      size="sm"
                      onClick={handleCreateCourse}
                      disabled={isCreatingCourse || !newCourseName.trim()}
                      className="h-8"
                    >
                      {isCreatingCourse ? 'Creating...' : 'Create'}
                    </Button>
                  </div>
                  {newCourseName.trim() && newCourseName.trim() !== toTitleCase(newCourseName.trim()) && (
                    <p className="text-xs text-blue-700">
                      Will be saved as: <strong>{toTitleCase(newCourseName.trim())}</strong>
                    </p>
                  )}
                  {createCourseError && (
                    <p className="text-xs text-red-600">{createCourseError}</p>
                  )}
                </div>
              )}

              {selectedCourse && !isLoadingStats && (
                <p className="text-xs text-gray-500 mt-2">
                  Currently: {courseStats.subjects} subjects, {courseStats.topics} topics
                </p>
              )}
            </div>

            {/* Template download */}
            <div className="border-t pt-4">
              <div className="flex items-center justify-between mb-1">
                <p className="text-sm font-medium text-gray-700">Blank Template</p>
                {templateDownloaded && (
                  <span className="text-xs text-green-600 flex items-center gap-1">
                    <CheckCircle className="h-3 w-3" /> Downloaded
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-500 mb-2">CSV with columns: subject, topic, description, sort orders</p>
              <Button size="sm" variant="outline" onClick={downloadTemplate}>
                <Download className="h-3.5 w-3.5 mr-1.5" />
                Download Template
              </Button>
            </div>

            {/* Current entries download */}
            <div className="border-t pt-4">
              <div className="flex items-center justify-between mb-1">
                <p className="text-sm font-medium text-gray-700">Current Entries (Reference)</p>
                {currentEntriesDownloaded && (
                  <span className="text-xs text-green-600 flex items-center gap-1">
                    <CheckCircle className="h-3 w-3" /> Downloaded
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-500 mb-2">See what already exists to avoid duplicates</p>
              <Button
                size="sm"
                variant="outline"
                onClick={downloadCurrentEntries}
                disabled={!selectedCourse || isLoadingStats}
              >
                <Download className="h-3.5 w-3.5 mr-1.5" />
                Download Current Entries
              </Button>
            </div>

            {/* Next shortcut */}
            <div className="pt-1">
              <Button size="sm" onClick={() => setOpenStep(2)} className="gap-1.5">
                Next: Select File <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        </Step>

        {/* ─── STEP 2: Select File ─── */}
        <Step
          number={2}
          title="Select CSV File"
          subtitle={step2Complete ? csvFile.name : 'Choose your filled-in template'}
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
                  First time? <button type="button" className="font-medium underline" onClick={() => setOpenStep(1)}>Select a course and download the template</button> from Step 1 first.
                </p>
              </div>
            )}

            {/* Required columns hint */}
            <div className="bg-gray-50 border border-gray-200 rounded-md px-3 py-2">
              <p className="text-xs text-gray-600">
                <span className="font-semibold">Required columns:</span>{' '}
                <code className="text-blue-700 bg-blue-50 px-1 rounded">subject</code>,{' '}
                <code className="text-blue-700 bg-blue-50 px-1 rounded">topic</code>{' '}
                <span className="text-gray-400 ml-1">|</span>{' '}
                <span className="text-gray-500">Optional:</span>{' '}
                <code className="text-gray-500 bg-gray-100 px-1 rounded">description</code>,{' '}
                <code className="text-gray-500 bg-gray-100 px-1 rounded">subject_sort_order</code>,{' '}
                <code className="text-gray-500 bg-gray-100 px-1 rounded">sort_order</code>
              </p>
              <p className="text-xs text-gray-500 mt-1">
                Case is handled automatically. New entries are Title Cased. Duplicates are skipped.
              </p>
            </div>

            {/* File picker */}
            <div>
              <Label className="text-sm mb-1.5 block">CSV File</Label>
              <input
                id="csv-upload-topics"
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

            {/* Next shortcut */}
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
          subtitle={isUploading ? 'Uploading...' : 'Review and upload'}
          isOpen={openStep === 3}
          isComplete={false}
          onToggle={() => setOpenStep(openStep === 3 ? 0 : 3)}
        >
          <div className="space-y-4">
            {/* Guard: missing course or file */}
            {!selectedCourse || !csvFile ? (
              <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 rounded-md px-3 py-2">
                <Info className="h-3.5 w-3.5 text-amber-600 mt-0.5 flex-shrink-0" />
                <p className="text-xs text-amber-800">
                  {!selectedCourse && !csvFile
                    ? <>Select a <button type="button" className="font-medium underline" onClick={() => setOpenStep(1)}>course in Step 1</button> and <button type="button" className="font-medium underline" onClick={() => setOpenStep(2)}>pick a file in Step 2</button> first.</>
                    : !selectedCourse
                      ? <>Select a <button type="button" className="font-medium underline" onClick={() => setOpenStep(1)}>course in Step 1</button> first.</>
                      : <>No file selected. <button type="button" className="font-medium underline" onClick={() => setOpenStep(2)}>Go to Step 2</button> to pick your CSV file.</>
                  }
                </p>
              </div>
            ) : (
              <>
                {/* Summary */}
                <div className="bg-gray-50 border border-gray-200 rounded-md p-3 text-sm space-y-1">
                  <p><span className="text-gray-500">Course:</span> <span className="font-medium">{courses.find(c => c.id === selectedCourse)?.name}</span></p>
                  <p><span className="text-gray-500">File:</span> <span className="font-medium">{csvFile.name}</span></p>
                </div>

                <Button
                  onClick={uploadTopics}
                  disabled={!csvFile || !selectedCourse || isUploading}
                  className="w-full"
                  size="lg"
                >
                  {isUploading ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Processing...
                    </>
                  ) : (
                    <>
                      <Upload className="h-4 w-4 mr-2" />
                      Upload Subjects & Topics
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
                      <p key={index}>{error}</p>
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
