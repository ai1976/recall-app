import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useToast } from '@/hooks/use-toast';
import { Upload, ArrowLeft, Check, ChevronsUpDown, Plus, FileText } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';

export default function NoteUpload() {
  const navigate = useNavigate();
  const { toast } = useToast();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [file, setFile] = useState(null);
  const [filePreview, setFilePreview] = useState(null);
  const [contentType, setContentType] = useState('text');
  const [extractedText, setExtractedText] = useState('');
  const [isExtracting, setIsExtracting] = useState(false);
  const [loading, setLoading] = useState(false);

  const [subjects, setSubjects] = useState([]);
  const [selectedSubject, setSelectedSubject] = useState(null);
  const [topics, setTopics] = useState([]);
  const [selectedTopic, setSelectedTopic] = useState(null);
  const [tags, setTags] = useState('');
  const [showCustomSubject, setShowCustomSubject] = useState(false);
  const [customSubject, setCustomSubject] = useState('');
  const [showCustomTopic, setShowCustomTopic] = useState(false);
  const [customTopic, setCustomTopic] = useState('');
  const [userCourseLevel, setUserCourseLevel] = useState(null);
  const [isPublic, setIsPublic] = useState(false);

  // Combobox states
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  useEffect(() => {
    fetchUserCourseLevel();
  }, []);

  useEffect(() => {
    // Fetch subjects regardless of course level (for super_admin)
    fetchSubjects();
  }, [userCourseLevel]);

  useEffect(() => {
    if (selectedSubject && !showCustomSubject) {
      fetchTopics(selectedSubject);
    } else {
      setTopics([]);
      setSelectedTopic(null);
    }
  }, [selectedSubject, showCustomSubject]);

  const fetchUserCourseLevel = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: profile, error } = await supabase
        .from('profiles')
        .select('course_level')
        .eq('id', user.id)
        .single();

      if (error) throw error;
      setUserCourseLevel(profile?.course_level);
    } catch (error) {
      console.error('Error fetching user course level:', error);
    }
  };

  const fetchSubjects = async () => {
    try {
      let query = supabase
        .from('subjects')
        .select(`
          *,
          discipline:disciplines!inner(name, level)
        `)
        .eq('is_active', true)
        .order('order');

      // Only filter by course level if user has one (not super_admin)
      if (userCourseLevel) {
        query = query.eq('disciplines.level', userCourseLevel);
      }

      const { data, error } = await query;

      if (error) throw error;
      
      console.log('Fetched subjects:', data); // Debug log
      setSubjects(data || []);
    } catch (error) {
      console.error('Error fetching subjects:', error);
      toast({
        title: 'Error',
        description: 'Failed to load subjects',
        variant: 'destructive'
      });
    }
  };

  const fetchTopics = async (subjectId) => {
    try {
      const { data, error } = await supabase
        .from('topics')
        .select('*')
        .eq('subject_id', subjectId)
        .eq('is_active', true)
        .order('order');

      if (error) throw error;
      setTopics(data || []);
    } catch (error) {
      console.error('Error fetching topics:', error);
      toast({
        title: 'Error',
        description: 'Failed to load topics',
        variant: 'destructive'
      });
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      setFile(selectedFile);

      // Create preview for images
      if (selectedFile.type.startsWith('image/')) {
        const reader = new FileReader();
        reader.onloadend = () => {
          setFilePreview(reader.result);
        };
        reader.readAsDataURL(selectedFile);
      } else if (selectedFile.type === 'application/pdf') {
        setFilePreview('pdf');
      } else {
        setFilePreview(null);
      }

      // Auto-set title from filename if empty
      if (!title) {
        const fileName = selectedFile.name.replace(/\.[^/.]+$/, '');
        setTitle(fileName);
      }
    }
  };

  const extractTextFromImage = async () => {
    if (!file || !file.type.startsWith('image/')) {
      toast({
        title: 'Invalid file',
        description: 'Please select an image file for OCR',
        variant: 'destructive'
      });
      return;
    }

    setIsExtracting(true);

    try {
      // Use Tesseract.js for OCR (you'll need to install it)
      // For now, we'll just show a placeholder
      toast({
        title: 'OCR Feature',
        description: 'OCR extraction will be implemented with Tesseract.js',
      });
      
      // Placeholder extracted text
      setExtractedText('Extracted text will appear here...');
    } catch (error) {
      console.error('Error extracting text:', error);
      toast({
        title: 'Extraction Error',
        description: 'Failed to extract text from image',
        variant: 'destructive'
      });
    } finally {
      setIsExtracting(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // Validation
    if (!title.trim()) {
      toast({
        title: 'Title required',
        description: 'Please enter a title for your note',
        variant: 'destructive'
      });
      return;
    }

    if (!file) {
      toast({
        title: 'File required',
        description: 'Please upload a file',
        variant: 'destructive'
      });
      return;
    }

    if (!selectedSubject && !customSubject.trim()) {
      toast({
        title: 'Subject required',
        description: 'Please select a subject or enter a custom subject',
        variant: 'destructive'
      });
      return;
    }

    setLoading(true);

    try {
      const { data: { user } } = await supabase.auth.getUser();

      // Upload file to storage
      const fileExt = file.name.split('.').pop();
      const fileName = `${user.id}/${Date.now()}.${fileExt}`;

      const { error: uploadError } = await supabase.storage
        .from('note-files')
        .upload(fileName, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('note-files')
        .getPublicUrl(fileName);

      // Parse tags
      const tagsArray = tags.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0);

      // Create note record
      const noteData = {
        user_id: user.id,
        title: title.trim(),
        description: description.trim() || null,
        subject_id: selectedSubject || null,
        topic_id: selectedTopic || null,
        custom_subject: customSubject.trim() || null,
        custom_topic: customTopic.trim() || null,
        content_type: contentType,
        image_url: publicUrl,
        extracted_text: extractedText.trim() || null,
        tags: tagsArray.length > 0 ? tagsArray : null,
        is_public: isPublic
      };

      const { data: note, error: noteError } = await supabase
        .from('notes')
        .insert([noteData])
        .select()
        .single();

      if (noteError) throw noteError;

      toast({
        title: 'Success',
        description: 'Note uploaded successfully'
      });

      navigate(`/notes/${note.id}`);
    } catch (error) {
      console.error('Error uploading note:', error);
      toast({
        title: 'Error',
        description: 'Failed to upload note',
        variant: 'destructive'
      });
    } finally {
      setLoading(false);
    }
  };

  // Get selected subject name for display
  const selectedSubjectName = subjects.find(s => s.id === selectedSubject)?.name || '';
  const selectedTopicName = topics.find(t => t.id === selectedTopic)?.name || '';

  return (
    <div className="container mx-auto p-4 max-w-4xl">
      <div className="mb-6">
        <Button
          variant="ghost"
          onClick={() => navigate(-1)}
          className="mb-4"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back
        </Button>
        <h1 className="text-3xl font-bold">Upload Note</h1>
        <p className="text-muted-foreground mt-2">
          Upload your study notes as images or PDFs
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Subject & Topic - MOVED TO TOP */}
        <Card>
          <CardHeader>
            <CardTitle>Subject & Topic</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Subject Selection */}
            <div className="space-y-2">
              <Label>Subject *</Label>
              {!showCustomSubject ? (
                <Popover open={subjectOpen} onOpenChange={setSubjectOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      role="combobox"
                      aria-expanded={subjectOpen}
                      className="w-full justify-between"
                    >
                      {selectedSubject ? selectedSubjectName : "Select a subject..."}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-full p-0">
                    <Command>
                      <CommandInput placeholder="Search subject..." />
                      <CommandEmpty>No subject found.</CommandEmpty>
                      <CommandGroup className="max-h-[300px] overflow-y-auto">
                        {subjects.map((subject) => (
                          <CommandItem
                            key={subject.id}
                            value={subject.name}
                            onSelect={() => {
                              setSelectedSubject(subject.id);
                              setSubjectOpen(false);
                            }}
                          >
                            <Check
                              className={cn(
                                "mr-2 h-4 w-4",
                                selectedSubject === subject.id ? "opacity-100" : "opacity-0"
                              )}
                            />
                            {subject.name}
                          </CommandItem>
                        ))}
                        <CommandItem
                          value="custom"
                          onSelect={() => {
                            setShowCustomSubject(true);
                            setSelectedSubject(null);
                            setSubjectOpen(false);
                          }}
                        >
                          <Plus className="mr-2 h-4 w-4" />
                          Add Custom Subject
                        </CommandItem>
                      </CommandGroup>
                    </Command>
                  </PopoverContent>
                </Popover>
              ) : (
                <div className="space-y-2">
                  <Input
                    placeholder="Enter custom subject name"
                    value={customSubject}
                    onChange={(e) => setCustomSubject(e.target.value)}
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      setShowCustomSubject(false);
                      setCustomSubject('');
                    }}
                  >
                    <ArrowLeft className="mr-2 h-4 w-4" />
                    Back to subject list
                  </Button>
                </div>
              )}
            </div>

            {/* Topic Selection */}
            <div className="space-y-2">
              <Label>Topic (Optional)</Label>
              {!showCustomTopic ? (
                <Popover open={topicOpen} onOpenChange={setTopicOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      role="combobox"
                      aria-expanded={topicOpen}
                      className="w-full justify-between"
                      disabled={!selectedSubject && !customSubject}
                    >
                      {selectedTopic ? selectedTopicName : (
                        selectedSubject || customSubject ? "Select a topic..." : "Select a subject first"
                      )}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-full p-0">
                    <Command>
                      <CommandInput placeholder="Search topic..." />
                      <CommandEmpty>No topic found.</CommandEmpty>
                      <CommandGroup className="max-h-[300px] overflow-y-auto">
                        {topics.map((topic) => (
                          <CommandItem
                            key={topic.id}
                            value={topic.name}
                            onSelect={() => {
                              setSelectedTopic(topic.id);
                              setTopicOpen(false);
                            }}
                          >
                            <Check
                              className={cn(
                                "mr-2 h-4 w-4",
                                selectedTopic === topic.id ? "opacity-100" : "opacity-0"
                              )}
                            />
                            {topic.name}
                          </CommandItem>
                        ))}
                        <CommandItem
                          value="custom"
                          onSelect={() => {
                            setShowCustomTopic(true);
                            setSelectedTopic(null);
                            setTopicOpen(false);
                          }}
                        >
                          <Plus className="mr-2 h-4 w-4" />
                          Add Custom Topic
                        </CommandItem>
                      </CommandGroup>
                    </Command>
                  </PopoverContent>
                </Popover>
              ) : (
                <div className="space-y-2">
                  <Input
                    placeholder="Enter custom topic name"
                    value={customTopic}
                    onChange={(e) => setCustomTopic(e.target.value)}
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      setShowCustomTopic(false);
                      setCustomTopic('');
                    }}
                  >
                    <ArrowLeft className="mr-2 h-4 w-4" />
                    Back to topic list
                  </Button>
                </div>
              )}
            </div>

            {/* Tags */}
            <div className="space-y-2">
              <Label htmlFor="tags">Tags (Optional)</Label>
              <Input
                id="tags"
                placeholder="e.g., important, exam, revision (comma-separated)"
                value={tags}
                onChange={(e) => setTags(e.target.value)}
              />
              <p className="text-sm text-muted-foreground">
                Separate multiple tags with commas
              </p>
            </div>

            {/* Public/Private Toggle */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label htmlFor="public-toggle">Make this note public</Label>
                <button
                  type="button"
                  id="public-toggle"
                  role="switch"
                  aria-checked={isPublic}
                  onClick={() => setIsPublic(!isPublic)}
                  className={cn(
                    "relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
                    isPublic ? "bg-blue-600" : "bg-gray-300"
                  )}
                >
                  <span
                    className={cn(
                      "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                      isPublic ? "translate-x-6" : "translate-x-1"
                    )}
                  />
                </button>
              </div>
              <p className="text-sm text-muted-foreground">
                {isPublic 
                  ? "✓ Other students can view this note" 
                  : "○ Only you can see this note"}
              </p>
            </div>
            
          </CardContent>
        </Card>

        {/* File Upload */}
        <Card>
          <CardHeader>
            <CardTitle>File Upload</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="file">Select File</Label>
              <Input
                id="file"
                type="file"
                accept="image/*,application/pdf"
                onChange={handleFileChange}
              />
              <p className="text-sm text-muted-foreground">
                Supported formats: JPG, PNG, PDF (max 10MB)
              </p>
            </div>

            {/* File Preview */}
            {filePreview && (
              <div className="mt-4">
                <Label>Preview</Label>
                {filePreview === 'pdf' ? (
                  <div className="border rounded-lg p-8 flex items-center justify-center bg-muted">
                    <FileText className="h-16 w-16 text-muted-foreground" />
                    <span className="ml-4 text-lg">PDF Document</span>
                  </div>
                ) : (
                  <img
                    src={filePreview}
                    alt="Preview"
                    className="max-w-full h-auto border rounded-lg"
                  />
                )}
              </div>
            )}

            {/* OCR Button */}
            {file && file.type.startsWith('image/') && (
              <Button
                type="button"
                variant="outline"
                onClick={extractTextFromImage}
                disabled={isExtracting}
              >
                {isExtracting ? 'Extracting...' : 'Extract Text (OCR)'}
              </Button>
            )}

            {/* Extracted Text */}
            {extractedText && (
              <div className="space-y-2">
                <Label>Extracted Text</Label>
                <Textarea
                  value={extractedText}
                  onChange={(e) => setExtractedText(e.target.value)}
                  rows={6}
                  placeholder="Extracted text will appear here..."
                />
              </div>
            )}
          </CardContent>
        </Card>

        {/* Note Details */}
        <Card>
          <CardHeader>
            <CardTitle>Note Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="title">Title *</Label>
              <Input
                id="title"
                placeholder="e.g., Chapter 5 - Partnership Accounts"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description (Optional)</Label>
              <Textarea
                id="description"
                placeholder="Add any additional notes or context..."
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
              />
            </div>

            {/* Content Type */}
            <div className="space-y-2">
              <Label>Content Type</Label>
              <div className="flex gap-2">
                {['text', 'table', 'math', 'diagram', 'mixed'].map((type) => (
                  <Button
                    key={type}
                    type="button"
                    variant={contentType === type ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setContentType(type)}
                  >
                    {type.charAt(0).toUpperCase() + type.slice(1)}
                  </Button>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Submit */}
        <div className="flex gap-4">
          <Button
            type="button"
            variant="outline"
            onClick={() => navigate(-1)}
            className="flex-1"
          >
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={loading}
            className="flex-1"
          >
            <Upload className="mr-2 h-4 w-4" />
            {loading ? 'Uploading...' : 'Upload Note'}
          </Button>
        </div>
      </form>
    </div>
  );
}