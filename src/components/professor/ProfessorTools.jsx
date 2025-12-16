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
    const template = `subject,topic,front,back,tags,difficulty
Taxation,Income Tax Basics,What is the basic exemption limit for individuals below 60 years?,₹2.5 lakhs,"#ITR,#basics",easy
Advanced Accounting,AS 1,What is AS 1?,Disclosure of Accounting Policies,"#AS,#important",easy
Auditing,Audit Process,What are the 3 types of audit procedures?,"Inspection, Observation, Inquiry","#procedures,#basics",medium`;

    const blob = new Blob([template], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'flashcard_template.csv';
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
    const lines = text.split('\n').filter(line => line.trim());
    const headers = lines[0].split(',').map(h => h.trim());
    
    const flashcards = [];
    const parseErrors = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      if (!line.trim()) continue;

      try {
        const values = line.split(',').map(v => v.trim());
        
        const flashcard = {};
        headers.forEach((header, index) => {
          flashcard[header] = values[index] || '';
        });

        if (!flashcard.subject || !flashcard.front || !flashcard.back) {
          parseErrors.push(`Row ${i + 1}: Missing required fields (subject, front, back)`);
          continue;
        }

        if (flashcard.difficulty && 
            !['easy', 'medium', 'hard'].includes(flashcard.difficulty.toLowerCase())) {
          parseErrors.push(`Row ${i + 1}: Invalid difficulty (must be easy, medium, or hard)`);
          continue;
        }

        if (flashcard.tags) {
          flashcard.tags = flashcard.tags
            .replace(/"/g, '')
            .split(',')
            .map(t => t.trim())
            .filter(t => t);
        }

        flashcards.push(flashcard);
      } catch (error) {
        parseErrors.push(`Row ${i + 1}: ${error.message}`);
      }
    }

    return { flashcards, errors: parseErrors };
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
          t.name.toLowerCase() === card.topic.toLowerCase() &&
          (!subject || t.subject_id === subject.id)
        );

        return {
          user_id: user.id,
          contributed_by: user.id,
          target_course: 'CA Intermediate',
          subject_id: subject?.id || null,
          topic_id: topic?.id || null,
          custom_subject: subject ? null : card.subject,
          custom_topic: topic ? null : card.topic,
          front_text: card.front,
          back_text: card.back,
          tags: card.tags || [],
          difficulty: card.difficulty?.toLowerCase() || 'medium',
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

      await supabase.from('admin_audit_log').insert({
        action: 'bulk_upload_flashcards',
        admin_id: user.id,
        details: {
          count: data.length,
          filename: csvFile.name
        }
      });

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
                  Click the button below to download a sample CSV file with the correct format
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
                  Open the CSV in Excel/Google Sheets and add your flashcards. Required fields: subject, front, back
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
                  Save your file as CSV and upload it using the form below
                </p>
              </div>
            </div>
          </div>

          <Button onClick={downloadTemplate} className="w-full sm:w-auto">
            <Download className="h-4 w-4 mr-2" />
            Download CSV Template
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
                Answer or back side of flashcard
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
                Difficulty level: easy, medium, or hard
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