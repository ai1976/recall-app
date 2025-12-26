import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
import { useAuth } from '@/contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Upload, CheckCircle, XCircle, AlertCircle, Download, AlertTriangle, ArrowRight } from 'lucide-react';

export default function ProfessorTools() {
  const { isProfessor, isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [csvFile, setCsvFile] = useState(null);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadResults, setUploadResults] = useState(null);
  const [errors, setErrors] = useState([]);
  const [batchDescription, setBatchDescription] = useState('');
  
  // 🆕 NEW: Course selection state
  const [courses, setCourses] = useState([]);
  const [selectedCourse, setSelectedCourse] = useState(null);
  const [courseStats, setCourseStats] = useState({ subjects: 0, topics: 0 });
  const [isLoadingStats, setIsLoadingStats] = useState(false);

  const hasAccess = true; // All authenticated users can access

  // 🆕 NEW: Load courses on mount
  useEffect(() => {
    loadCourses();
  }, []);

  // 🆕 NEW: Load course stats when course selected
  useEffect(() => {
    if (selectedCourse) {
      loadCourseStats(selectedCourse);
    }
  }, [selectedCourse]);

  // 🆕 NEW: Fetch all courses
  async function loadCourses() {
    try {
      const { data, error } = await supabase
        .from('disciplines')
        .select('id, name')
        .order('name');

      if (error) throw error;
      setCourses(data || []);
      
      // Auto-select first course if only one exists
      if (data?.length === 1) {
        setSelectedCourse(data[0].id);
      }
    } catch (error) {
      console.error('Error loading courses:', error);
    }
  }

  // 🆕 NEW: Load stats for selected course
  async function loadCourseStats(courseId) {
    setIsLoadingStats(true);
    try {
      // Get subjects count
      const { data: subjects, error: subError } = await supabase
        .from('subjects')
        .select('id, name')
        .eq('discipline_id', courseId);

      if (subError) throw subError;

      // Get topics count for this course
      const subjectIds = subjects?.map(s => s.id) || [];
      const { data: topics, error: topError } = await supabase
        .from('topics')
        .select('id, name')
        .in('subject_id', subjectIds);

      if (topError) throw topError;

      setCourseStats({
        subjects: subjects?.length || 0,
        topics: topics?.length || 0
      });
    } catch (error) {
      console.error('Error loading course stats:', error);
      setCourseStats({ subjects: 0, topics: 0 });
    } finally {
      setIsLoadingStats(false);
    }
  }

  // 🆕 NEW: Download valid entries for selected course
  async function downloadValidEntries() {
    if (!selectedCourse) {
      alert('Please select a course first');
      return;
    }

    try {
      // Get course name
      const course = courses.find(c => c.id === selectedCourse);
      if (!course) return;

      // Get subjects for this course
      const { data: subjects, error: subError } = await supabase
        .from('subjects')
        .select('id, name')
        .eq('discipline_id', selectedCourse)
        .order('name');

      if (subError) throw subError;

      // Get topics for these subjects
      const subjectIds = subjects?.map(s => s.id) || [];
      const { data: topics, error: topError } = await supabase
        .from('topics')
        .select('id, name, subject_id')
        .in('subject_id', subjectIds)
        .order('name');

      if (topError) throw topError;

      // Build CSV content
      let csv = 'Course,Subject,Topic\n';

      // For each topic, add a row
      topics?.forEach(topic => {
        const subject = subjects.find(s => s.id === topic.subject_id);
        if (subject) {
          csv += `"${course.name}","${subject.name}","${topic.name}"\n`;
        }
      });

      // Also add subjects without topics (so professors know they exist)
      subjects?.forEach(subject => {
        const hasTopics = topics?.some(t => t.subject_id === subject.id);
        if (!hasTopics) {
          csv += `"${course.name}","${subject.name}",""\n`;
        }
      });

      // Trigger download
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `recall_valid_entries_${course.name.replace(/\s+/g, '_')}.csv`;
      a.click();
      window.URL.revokeObjectURL(url);

    } catch (error) {
      console.error('Error downloading valid entries:', error);
      alert('Failed to download valid entries. Please try again.');
    }
  }

  function downloadTemplate() {
    const template = `target_course,subject,topic,front,back,tags,difficulty
CA Intermediate,Taxation,Income Tax Basics,What is the basic exemption limit for individuals below 60 years?,₹2.5 lakhs,"#ITR,#basics",easy
CA Intermediate,Advanced Accounting,AS 1,What is AS 1?,Disclosure of Accounting Policies,"#AS,#important",medium
CA Foundation,Quantitative Aptitude,Percentages,What is 20% of 500?,100,,medium

==================================================
⚠️ IMPORTANT: READ THIS BEFORE FILLING
==================================================

BULK UPLOAD LIMITATIONS:
❌ Cannot create NEW courses/subjects/topics here
✅ Must use EXISTING entries from Valid Entries file

TO ADD NEW COURSE/SUBJECT/TOPIC:
1. Close this file
2. Go to Recall → Upload Note or Create Flashcard
3. Create ONE flashcard/note with your custom entry
4. Return to Bulk Upload page
5. Download Valid Entries again (will include your new entry)
6. Continue with bulk upload

==================================================
REFERENCE: VALID VALUES (Copy exactly as shown)
==================================================

⚠️ DO NOT GUESS SPELLINGS!
Download the "Valid Entries" file from Bulk Upload page
to see exact course/subject/topic names for your course.

DIFFICULTY (leave empty for default "medium"):
- easy
- medium
- hard

IMPORTANT NOTES:
✓ Required: target_course, subject, front, back
✓ Optional: topic, tags, difficulty
✓ Use EXACT spelling/capitalization from Valid Entries
✓ Empty difficulty defaults to "medium"
✓ Tags format: "#tag1,#tag2" or leave empty
✓ If subject/topic not in Valid Entries, create via single upload first
✓ For multi-line text in cells, Excel/Sheets will auto-quote them
✓ All flashcards are created as PRIVATE by default
✓ You can make them public later from My Flashcards page
`;

    const blob = new Blob([template], { type: 'text/csv;charset=utf-8' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'flashcard_template_with_instructions.csv';
    a.click();
    window.URL.revokeObjectURL(url);
  }

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

  function parseCSV(text) {
    const flashcards = [];
    const parseErrors = [];
    
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
      return { flashcards: [], errors: ['CSV file is empty'] };
    }
    
    const headerLine = lines[0];
    const headers = parseCSVLine(headerLine);
    
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      
      if (line.includes('====') || line.includes('REFERENCE:') || 
          line.includes('COURSES') || line.includes('DIFFICULTY') ||
          line.includes('SUBJECTS') || line.includes('IMPORTANT NOTES') ||
          line.includes('BULK UPLOAD LIMITATIONS') || line.includes('TO ADD NEW') ||
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
        
        const cleanDifficulty = (flashcard.difficulty || '')
          .toString()
          .trim()
          .replace(/['"]/g, '')
          .replace(/[^\x00-\x7F]/g, '')
          .toLowerCase();
        
        if (cleanDifficulty === 'easy') {
          flashcard.difficulty = 'easy';
        } else if (cleanDifficulty === 'hard') {
          flashcard.difficulty = 'hard';
        } else {
          flashcard.difficulty = 'medium';
        }
        
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
        
        flashcard.front = flashcard.front.replace(/[\r\n]+/g, ' ').trim();
        flashcard.back = flashcard.back.replace(/[\r\n]+/g, ' ').trim();
        
        flashcards.push(flashcard);
      } catch (error) {
        parseErrors.push(`Row ${i + 1}: ${error.message}`);
      }
    }
    
    return { flashcards, errors: parseErrors };
  }
  
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

  async function uploadFlashcards() {
    if (!csvFile) {
      alert('Please select a CSV file first');
      return;
    }

    setIsUploading(true);
    setErrors([]);

    try {
      const text = await csvFile.text();
      const { flashcards, errors: parseErrors } = parseCSV(text);

      if (parseErrors.length > 0) {
        // 🆕 NEW: Smart error messages for custom entries
        const customEntryErrors = parseErrors.filter(err => 
          err.toLowerCase().includes('not found')
        );
        
        if (customEntryErrors.length > 0) {
          setErrors([
            '⚠️ CUSTOM ENTRIES DETECTED',
            '',
            ...parseErrors,
            '',
            '💡 HOW TO FIX THIS:',
            '',
            'Option 1: Use existing entries',
            '→ Download Valid Entries file below',
            '→ Copy exact spelling from that file',
            '',
            'Option 2: Add your custom entries first',
            '→ Go to "Upload Note" or "Create Flashcard"',
            '→ Create entries for the missing items',
            '→ Return here and download Valid Entries again',
            '→ Try bulk upload again',
            '',
            '⚠️ Bulk upload cannot create new courses/subjects/topics'
          ]);
        } else {
          setErrors(parseErrors);
        }
        setIsUploading(false);
        return;
      }

      if (flashcards.length === 0) {
        setErrors(['No valid flashcards found in CSV']);
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
          is_public: false,
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

      try {
        await supabase.from('admin_audit_log').insert({
          action: 'bulk_upload_flashcards',
          admin_id: user.id,
          details: {
            count: data.length,
            filename: csvFile.name,
            batch_description: trimmedDescription
          }
        });
      } catch (auditError) {
        console.log('Audit log failed (non-critical):', auditError);
      }

      setCsvFile(null);
      setBatchDescription('');
      document.getElementById('csv-upload').value = '';

    } catch (error) {
      console.error('Upload error:', error);
      setErrors([`Upload failed: ${error.message}`]);
    } finally {
      setIsUploading(false);
    }
  }

  if (roleLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!hasAccess) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Alert variant="destructive" className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            Access Denied. Please log in to access this feature.
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 max-w-4xl">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Bulk Upload
        </h1>
        <p className="text-gray-600">
          Upload multiple flashcards at once using CSV format
        </p>
      </div>

      {/* Instructions Card */}
      <Card className="mb-8">
        <CardHeader>
          <CardTitle>How to Bulk Upload Flashcards</CardTitle>
          <CardDescription>
            Follow these steps to upload multiple flashcards at once
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-3">
            <div className="flex items-start gap-3">
              <div className="bg-blue-100 text-blue-800 rounded-full w-8 h-8 flex items-center justify-center font-bold flex-shrink-0">
                1
              </div>
              <div>
                <p className="font-medium">Download the Blank Template</p>
                <p className="text-sm text-gray-600">
                  CSV file with all required columns and helpful instructions
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="bg-blue-100 text-blue-800 rounded-full w-8 h-8 flex items-center justify-center font-bold flex-shrink-0">
                2
              </div>
              <div>
                <p className="font-medium">Download Valid Entries for Your Course</p>
                <p className="text-sm text-gray-600">
                  Complete list of courses, subjects & topics (copy exact names from here)
                </p>
                <p className="text-xs text-amber-700 mt-1">
                  ⚠️ Only these entries will work in bulk upload. Need something not listed? 
                  Add it via single upload first.
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="bg-blue-100 text-blue-800 rounded-full w-8 h-8 flex items-center justify-center font-bold flex-shrink-0">
                3
              </div>
              <div>
                <p className="font-medium">Fill Template with Your Flashcards</p>
                <p className="text-sm text-gray-600">
                  Use EXACT spelling from Valid Entries file to avoid errors
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="bg-blue-100 text-blue-800 rounded-full w-8 h-8 flex items-center justify-center font-bold flex-shrink-0">
                4
              </div>
              <div>
                <p className="font-medium">Upload the Completed CSV</p>
                <p className="text-sm text-gray-600">
                  All flashcards will be created as private (you can make them public later)
                </p>
              </div>
            </div>
          </div>

          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mt-4">
            <p className="text-sm text-blue-800">
              <strong>💡 Pro Tip:</strong> Keep both CSV files open side-by-side. 
              Copy exact Course, Subject, Topic names from Valid Entries to avoid spelling errors!
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Download Files Section */}
      <Card className="mb-8">
        <CardHeader>
          <CardTitle>Download Files</CardTitle>
          <CardDescription>
            Get the template and valid entries reference
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Template Download */}
          <div>
            <Label className="text-base font-semibold mb-2 block">
              Step 1: Download Template CSV
            </Label>
            <Button onClick={downloadTemplate} className="w-full sm:w-auto">
              <Download className="h-4 w-4 mr-2" />
              Download Template CSV
            </Button>
            <p className="text-xs text-gray-500 mt-1">
              Blank template with all required columns
            </p>
          </div>

          {/* Valid Entries Download with Course Selection */}
          <div className="border-t pt-6">
            <Label className="text-base font-semibold mb-2 block">
              Step 2: Download Valid Entries
            </Label>
            
            <div className="space-y-3">
              <div>
                <Label htmlFor="course-select" className="text-sm mb-1 block">
                  Select Course:
                </Label>
                <Select value={selectedCourse} onValueChange={setSelectedCourse}>
                  <SelectTrigger id="course-select" className="w-full sm:w-64">
                    <SelectValue placeholder="Select a course..." />
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
                onClick={downloadValidEntries}
                disabled={!selectedCourse || isLoadingStats}
                className="w-full sm:w-auto"
              >
                <Download className="h-4 w-4 mr-2" />
                Download Valid Entries
              </Button>

              {selectedCourse && courseStats.topics > 0 && (
                <p className="text-sm text-green-700">
                  ✓ {courseStats.subjects} subjects • {courseStats.topics} topics available
                </p>
              )}

              {selectedCourse && courseStats.topics === 0 && (
                <p className="text-sm text-amber-700">
                  ⚠️ No topics found for this course. Add some via Upload Note first.
                </p>
              )}
            </div>

            {/* Warning about custom entries */}
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mt-4">
              <p className="text-sm text-amber-900 font-medium mb-2">
                ⚠️ Don't see your subject or topic in the downloaded file?
              </p>
              <p className="text-sm text-amber-800 mb-3">
                You must create it first using <strong>Upload Note</strong> or <strong>Create Flashcard</strong>. 
                Once created, download this file again to see it in the list.
              </p>
              <div className="flex flex-wrap gap-2">
                <Button 
                  size="sm"
                  onClick={() => navigate('/dashboard/upload-note')}
                >
                  Upload Note
                </Button>
                <Button 
                  size="sm"
                  onClick={() => navigate('/dashboard/create-flashcard')}
                >
                  Create Flashcard
                </Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Upload Section */}
      <Card className="mb-8">
        <CardHeader>
          <CardTitle>Upload Flashcards</CardTitle>
          <CardDescription>
            Select your CSV file and click upload. All flashcards will be created as private by default.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="batch-description">
              Batch Description (Optional)
            </Label>
            <Input
              id="batch-description"
              value={batchDescription}
              onChange={(e) => setBatchDescription(e.target.value)}
              placeholder="e.g., Treasury Management - Part 1"
            />
            <p className="text-sm text-muted-foreground">
              💡 Helps organize and identify related flashcards
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              CSV File
            </label>
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
              <p className="mt-2 text-sm text-gray-600">
                Selected: {csvFile.name}
              </p>
            )}
          </div>

          <Button 
            onClick={uploadFlashcards}
            disabled={!csvFile || isUploading}
            className="w-full"
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
          
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p className="text-sm text-blue-800">
              <strong>📌 Privacy Notice:</strong> All flashcards will be created as <strong>private</strong> by default. 
              You can make them public later from the My Flashcards page.
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Error Messages */}
      {errors.length > 0 && (
        <Alert variant="destructive" className="mb-8">
          <XCircle className="h-4 w-4" />
          <AlertDescription>
            <div className="space-y-1">
              {errors.map((error, index) => (
                <p key={index} className={error.startsWith('⚠️') || error.startsWith('💡') ? 'font-medium mt-2' : ''}>
                  {error}
                </p>
              ))}
            </div>
          </AlertDescription>
        </Alert>
      )}

      {/* Success Message */}
      {uploadResults?.success && (
        <Alert className="mb-8 border-green-200 bg-green-50">
          <CheckCircle className="h-4 w-4 text-green-600" />
          <AlertDescription className="text-green-800">
            <p className="font-medium">
              Successfully uploaded {uploadResults.count} flashcard(s) as private!
            </p>
            {batchDescription && (
              <p className="text-sm mt-1">
                📦 Batch: "{batchDescription}"
              </p>
            )}
            <p className="text-sm mt-1">
              Go to My Flashcards to review and make them public if needed.
            </p>
          </AlertDescription>
        </Alert>
      )}

      {/* CSV Format Guide with Limitations */}
      <Card>
        <CardHeader>
          <CardTitle>📋 CSV Format Guide</CardTitle>
          <CardDescription>
            Column descriptions and requirements
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4 text-sm">
            <div className="bg-amber-50 border-l-4 border-amber-500 p-4">
              <p className="font-bold text-amber-900 mb-2">
                ⚠️ IMPORTANT LIMITATION
              </p>
              <p className="text-amber-800 mb-3">
                Bulk upload <strong>ONLY</strong> works with existing courses, subjects, and topics. 
                You <strong>cannot create new ones</strong> during bulk upload.
              </p>
              <p className="text-amber-800 mb-2">
                <strong>To add a new course/subject/topic:</strong>
              </p>
              <ol className="list-decimal list-inside space-y-1 text-amber-800 ml-2">
                <li>Use "Upload Note" or "Create Flashcard"</li>
                <li>Create one entry with your custom values</li>
                <li>Return here and download Updated Valid Entries</li>
                <li>Now bulk upload will work with your new entries</li>
              </ol>
            </div>

            <div className="space-y-3 pt-4">
              <div>
                <p className="font-medium">
                  target_course <span className="text-red-500">*</span>
                  <span className="text-amber-600 text-xs ml-2">⚠️ MUST match Valid Entries</span>
                </p>
                <p className="text-gray-600">
                  Course level (e.g., "CA Foundation", "CA Intermediate", "CA Final")
                </p>
                <p className="text-xs text-amber-700 mt-1">
                  ❌ Custom courses not supported in bulk upload
                </p>
              </div>

              <div>
                <p className="font-medium">
                  subject <span className="text-red-500">*</span>
                  <span className="text-amber-600 text-xs ml-2">⚠️ MUST match Valid Entries</span>
                </p>
                <p className="text-gray-600">
                  Subject name (e.g., "Taxation", "Advanced Accounting")
                </p>
                <p className="text-xs text-amber-700 mt-1">
                  ❌ Custom subjects not supported in bulk upload
                </p>
              </div>

              <div>
                <p className="font-medium">
                  topic
                  <span className="text-amber-600 text-xs ml-2">⚠️ MUST match Valid Entries if provided</span>
                </p>
                <p className="text-gray-600">
                  Topic within the subject (e.g., "Income Tax Basics", "AS 1")
                </p>
                <p className="text-xs text-amber-700 mt-1">
                  ❌ Custom topics not supported in bulk upload
                </p>
                <p className="text-xs text-blue-700 mt-1">
                  💡 Leave blank if no specific topic
                </p>
              </div>

              <div>
                <p className="font-medium">front <span className="text-red-500">*</span></p>
                <p className="text-gray-600">
                  Question or front side of flashcard (free text - no restrictions)
                </p>
              </div>

              <div>
                <p className="font-medium">back <span className="text-red-500">*</span></p>
                <p className="text-gray-600">
                  Answer or back side of flashcard (free text - multi-line supported)
                </p>
              </div>

              <div>
                <p className="font-medium">tags</p>
                <p className="text-gray-600">
                  Comma-separated tags (e.g., "#ITR,#basics,#important")
                </p>
              </div>

              <div>
                <p className="font-medium">difficulty</p>
                <p className="text-gray-600">
                  Difficulty level: easy, medium, or hard (defaults to medium if empty)
                </p>
              </div>
            </div>

            <div className="pt-4 border-t">
              <p className="text-xs text-gray-500">
                <span className="text-red-500">*</span> Required fields
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}