import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Upload, CheckCircle, XCircle, AlertCircle, Download } from 'lucide-react';

export default function ProfessorTools() {
  const { isProfessor, isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();
  const { user } = useAuth();
  const [csvFile, setCsvFile] = useState(null);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadResults, setUploadResults] = useState(null);
  const [errors, setErrors] = useState([]);

  const hasAccess = true; // All authenticated users can access

  function downloadTemplate() {
    // Enhanced template with reference lists
    const template = `target_course,subject,topic,front,back,tags,difficulty
CA Intermediate,Taxation,Income Tax Basics,What is the basic exemption limit for individuals below 60 years?,₹2.5 lakhs,"#ITR,#basics",easy
CA Intermediate,Advanced Accounting,AS 1,What is AS 1?,Disclosure of Accounting Policies,"#AS,#important",
CA Foundation,Quantitative Aptitude,Percentages,What is 20% of 500?,100,,medium

==================================================
REFERENCE: VALID VALUES (Copy exactly as shown)
==================================================

COURSES (target_course):
- CA Foundation
- CA Intermediate  
- CA Final
- CMA Foundation
- CMA Intermediate
- CMA Final
- CS Foundation
- CS Executive
- CS Professional

DIFFICULTY (leave empty for default "medium"):
- easy
- medium
- hard

CA INTERMEDIATE SUBJECTS:
- Advanced Accounting
- Corporate & Other Laws
- Cost & Management Accounting
- Taxation
- Auditing & Assurance
- Enterprise Information Systems & Strategic Management

CA FOUNDATION SUBJECTS:
- Principles and Practice of Accounting
- Business Laws
- Quantitative Aptitude
- Business Economics

IMPORTANT NOTES:
✓ Required: target_course, subject, front, back
✓ Optional: topic, tags, difficulty
✓ Use EXACT spelling/capitalization from reference
✓ Empty difficulty defaults to "medium"
✓ Tags format: "#tag1,#tag2" or leave empty
✓ If subject not listed, will create custom entry
✓ For multi-line text in cells, Excel/Sheets will auto-quote them
`;

    const blob = new Blob([template], { type: 'text/csv;charset=utf-8' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'flashcard_template_with_reference.csv';
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
    
    // More robust CSV parsing that handles quoted fields with line breaks
    const lines = [];
    let currentLine = '';
    let insideQuotes = false;
    
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const nextChar = text[i + 1];
      
      if (char === '"') {
        insideQuotes = !insideQuotes;
        currentLine += char;
      } else if (char === '\n' && !insideQuotes) {
        if (currentLine.trim()) {
          lines.push(currentLine);
        }
        currentLine = '';
      } else if (char === '\r') {
        // Skip carriage returns
        continue;
      } else {
        currentLine += char;
      }
    }
    
    // Add last line if exists
    if (currentLine.trim()) {
      lines.push(currentLine);
    }
    
    if (lines.length === 0) {
      return { flashcards: [], errors: ['CSV file is empty'] };
    }
    
    // Parse header
    const headerLine = lines[0];
    const headers = parseCSVLine(headerLine);
    
    // Parse data rows
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      
      // Skip reference section lines
      if (line.includes('====') || line.includes('REFERENCE:') || 
          line.includes('COURSES') || line.includes('DIFFICULTY') ||
          line.includes('SUBJECTS') || line.includes('IMPORTANT NOTES') ||
          line.trim().startsWith('-') || line.trim().startsWith('✓')) {
        continue;
      }
      
      try {
        const values = parseCSVLine(line);
        
        if (values.length === 0 || values.every(v => !v.trim())) {
          continue; // Skip empty rows
        }
        
        const flashcard = {};
        headers.forEach((header, index) => {
          const value = values[index] || '';
          // Clean the value: remove surrounding quotes, trim
          const cleanValue = value.toString().trim().replace(/^["']|["']$/g, '');
          flashcard[header] = cleanValue;
        });
        
        // Validate ONLY required fields
        if (!flashcard.target_course || !flashcard.subject || !flashcard.front || !flashcard.back) {
          parseErrors.push(`Row ${i + 1}: Missing required fields (target_course, subject, front, back)`);
          continue;
        }
        
        // Handle difficulty - accept valid values or default to medium
        const cleanDifficulty = (flashcard.difficulty || '')
          .toString()
          .trim()
          .replace(/['"]/g, '')
          .replace(/[^\x00-\x7F]/g, '') // Remove non-ASCII characters
          .toLowerCase();
        
        if (cleanDifficulty === 'easy') {
          flashcard.difficulty = 'easy';
        } else if (cleanDifficulty === 'hard') {
          flashcard.difficulty = 'hard';
        } else {
          // Empty, 'medium', or anything else → default to medium
          flashcard.difficulty = 'medium';
        }
        
        // Handle tags field
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
        
        // Clean up line breaks in front and back text (convert to spaces)
        flashcard.front = flashcard.front.replace(/[\r\n]+/g, ' ').trim();
        flashcard.back = flashcard.back.replace(/[\r\n]+/g, ' ').trim();
        
        flashcards.push(flashcard);
      } catch (error) {
        parseErrors.push(`Row ${i + 1}: ${error.message}`);
      }
    }
    
    return { flashcards, errors: parseErrors };
  }
  
  // Helper function to parse a single CSV line (handles quoted fields)
  function parseCSVLine(line) {
    const result = [];
    let current = '';
    let insideQuotes = false;
    
    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      const nextChar = line[i + 1];
      
      if (char === '"') {
        if (insideQuotes && nextChar === '"') {
          // Escaped quote
          current += '"';
          i++; // Skip next quote
        } else {
          // Toggle quote state
          insideQuotes = !insideQuotes;
        }
      } else if (char === ',' && !insideQuotes) {
        // End of field
        result.push(current);
        current = '';
      } else {
        current += char;
      }
    }
    
    // Add last field
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
        setErrors(parseErrors);
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
          is_public: true,
          is_verified: isProfessor || isAdmin || isSuperAdmin
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

      // Try to log to audit table (ignore if it fails)
      try {
        await supabase.from('admin_audit_log').insert({
          action: 'bulk_upload_flashcards',
          admin_id: user.id,
          details: {
            count: data.length,
            filename: csvFile.name
          }
        });
      } catch (auditError) {
        console.log('Audit log failed (non-critical):', auditError);
      }

      setCsvFile(null);
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
                <p className="font-medium">Download the CSV Template</p>
                <p className="text-sm text-gray-600">
                  Includes reference list of valid courses and subjects
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="bg-blue-100 text-blue-800 rounded-full w-8 h-8 flex items-center justify-center font-bold flex-shrink-0">
                2
              </div>
              <div>
                <p className="font-medium">Fill in Your Flashcards</p>
                <p className="text-sm text-gray-600">
                  Required: target_course, subject, front, back | Optional: topic, tags, difficulty
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3">
              <div className="bg-blue-100 text-blue-800 rounded-full w-8 h-8 flex items-center justify-center font-bold flex-shrink-0">
                3
              </div>
              <div>
                <p className="font-medium">Upload the CSV File</p>
                <p className="text-sm text-gray-600">
                  Multi-line text is supported - Excel/Sheets will auto-quote cells
                </p>
              </div>
            </div>
          </div>

          <Button onClick={downloadTemplate} className="w-full sm:w-auto">
            <Download className="h-4 w-4 mr-2" />
            Download Enhanced CSV Template
          </Button>
        </CardContent>
      </Card>

      <Card className="mb-8">
        <CardHeader>
          <CardTitle>Upload Flashcards</CardTitle>
          <CardDescription>
            Select your CSV file and click upload
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
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
        </CardContent>
      </Card>

      {errors.length > 0 && (
        <Alert variant="destructive" className="mb-8">
          <XCircle className="h-4 w-4" />
          <AlertDescription>
            <p className="font-medium mb-2">Upload failed with {errors.length} error(s):</p>
            <ul className="list-disc list-inside space-y-1">
              {errors.map((error, index) => (
                <li key={index} className="text-sm">{error}</li>
              ))}
            </ul>
          </AlertDescription>
        </Alert>
      )}

      {uploadResults?.success && (
        <Alert className="mb-8 border-green-200 bg-green-50">
          <CheckCircle className="h-4 w-4 text-green-600" />
          <AlertDescription className="text-green-800">
            <p className="font-medium">
              Successfully uploaded {uploadResults.count} flashcard(s)!
            </p>
            <p className="text-sm mt-1">
              Your flashcards are now live and students can start reviewing them.
            </p>
          </AlertDescription>
        </Alert>
      )}

      <Card>
        <CardHeader>
          <CardTitle>CSV Format Guide</CardTitle>
          <CardDescription>
            Column descriptions and requirements
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3 text-sm">
            <div>
              <p className="font-medium">target_course <span className="text-red-500">*</span></p>
              <p className="text-gray-600">
                Course level (e.g., "CA Foundation", "CA Intermediate", "CA Final")
              </p>
            </div>
            <div>
              <p className="font-medium">subject <span className="text-red-500">*</span></p>
              <p className="text-gray-600">
                Subject name (e.g., "Taxation", "Advanced Accounting")
              </p>
            </div>
            <div>
              <p className="font-medium">topic</p>
              <p className="text-gray-600">
                Topic within the subject (e.g., "Income Tax Basics", "AS 1")
              </p>
            </div>
            <div>
              <p className="font-medium">front <span className="text-red-500">*</span></p>
              <p className="text-gray-600">
                Question or front side of flashcard
              </p>
            </div>
            <div>
              <p className="font-medium">back <span className="text-red-500">*</span></p>
              <p className="text-gray-600">
                Answer or back side of flashcard (multi-line text supported)
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

          <p className="text-xs text-gray-500 mt-4">
            <span className="text-red-500">*</span> Required fields
          </p>
        </CardContent>
      </Card>
    </div>
  );
}