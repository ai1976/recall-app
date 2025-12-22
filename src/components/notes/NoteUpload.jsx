import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue, SelectGroup } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { Upload, ArrowLeft, FileText, Image as ImageIcon, Check, ChevronsUpDown, Plus } from 'lucide-react';
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
  // eslint-disable-next-line no-unused-vars
  const [contentType, setContentType] = useState('text');
  // eslint-disable-next-line no-unused-vars
  const [extractedText, setExtractedText] = useState('');
  // eslint-disable-next-line no-unused-vars
  const [isExtracting, setIsExtracting] = useState(false);
  const [loading, setLoading] = useState(false);

  // 🆕 NEW: Target course for two-tier model
  const [targetCourse, setTargetCourse] = useState('');
  const [showCustomCourse, setShowCustomCourse] = useState(false);
  const [customCourse, setCustomCourse] = useState('');

  const [subjects, setSubjects] = useState([]);
  const [selectedSubject, setSelectedSubject] = useState(null);
  const [topics, setTopics] = useState([]);
  const [selectedTopic, setSelectedTopic] = useState(null);
  const [tags, setTags] = useState('');
  const [showCustomSubject, setShowCustomSubject] = useState(false);
  const [customSubject, setCustomSubject] = useState('');
  const [showCustomTopic, setShowCustomTopic] = useState(false);
  const [customTopic, setCustomTopic] = useState('');
  const [isPublic, setIsPublic] = useState(false);

  // Combobox states
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  useEffect(() => {
    // Fetch ALL subjects - no filtering by user's course!
    // This allows professors to create for any course, and students to help juniors
    fetchSubjects();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchSubjects = async () => {
    try {
      // 🔧 FIXED: Get ALL subjects regardless of user's course level
      const { data, error } = await supabase
        .from('subjects')
        .select('*')
        .order('name');

      if (error) throw error;
      setSubjects(data || []);
    } catch (error) {
      console.error('Error fetching subjects:', error);
      toast({
        title: 'Error',
        description: 'Failed to load subjects',
        variant: 'destructive',
      });
    }
  };

  useEffect(() => {
    if (selectedSubject) {
      fetchTopics(selectedSubject.id);
    } else {
      setTopics([]);
      setSelectedTopic(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSubject]);

  const fetchTopics = async (subjectId) => {
    try {
      const { data, error } = await supabase
        .from('topics')
        .select('*')
        .eq('subject_id', subjectId)
        .order('name');

      if (error) throw error;
      setTopics(data || []);
    } catch (error) {
      console.error('Error fetching topics:', error);
      toast({
        title: 'Error',
        description: 'Failed to load topics',
        variant: 'destructive',
      });
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files?.[0];
    if (!selectedFile) return;

    // Validate file type
    const validTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'];
    if (!validTypes.includes(selectedFile.type)) {
      toast({
        title: 'Invalid file type',
        description: 'Please upload a JPG, PNG, or PDF file',
        variant: 'destructive',
      });
      return;
    }

    // Validate file size (10MB max)
    if (selectedFile.size > 10 * 1024 * 1024) {
      toast({
        title: 'File too large',
        description: 'File size must be less than 10MB',
        variant: 'destructive',
      });
      return;
    }

    setFile(selectedFile);

    // Create preview for images
    if (selectedFile.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setFilePreview(reader.result);
      };
      reader.readAsDataURL(selectedFile);
    } else {
      setFilePreview(null);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Get current user
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // 🆕 VALIDATION: Check target course
      if (!targetCourse && !customCourse) {
        throw new Error('Please select or enter which course this note is for');
      }

      // Validation
      if (!file) {
        throw new Error('Please select a file to upload');
      }

      if (!selectedSubject && !customSubject) {
        throw new Error('Please select or enter a subject');
      }

      // Upload file to Supabase Storage
      const fileExt = file.name.split('.').pop();
      const fileName = `${user.id}/${Date.now()}.${fileExt}`;
      
      // eslint-disable-next-line no-unused-vars
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('notes')
        .upload(fileName, file);

      if (uploadError) throw uploadError;

      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('notes')
        .getPublicUrl(fileName);

      // Prepare note data
      const noteData = {
        user_id: user.id,
        contributed_by: user.id,
        target_course: customCourse || targetCourse, // 🆕 Use custom if provided
        title: title || file.name,
        description: description || null,
        subject_id: selectedSubject?.id || null,
        topic_id: selectedTopic?.id || null,
        custom_subject: customSubject || null,
        custom_topic: customTopic || null,
        image_url: publicUrl,
        content_type: contentType,
        extracted_text: extractedText || null,
        tags: tags ? tags.split(',').map(t => t.trim()).filter(Boolean) : [],
        is_public: isPublic,
      };

      // Insert note record
      const { error: insertError } = await supabase
        .from('notes')
        .insert(noteData);

      if (insertError) throw insertError;

      // Success!
      toast({
        title: 'Success!',
        description: 'Note uploaded successfully',
      });

      navigate('/dashboard');

    } catch (error) {
      console.error('Upload error:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to upload note',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <Button
        variant="ghost"
        onClick={() => navigate(-1)}
        className="mb-6"
      >
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back
      </Button>

      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold">Upload Note</h1>
          <p className="text-muted-foreground mt-2">
            Upload your study notes as images or PDFs
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          
          {/* 🆕 NEW: Course Selection Card */}
          <Card>
            <CardHeader>
              <CardTitle>Who is this note for?</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <Label htmlFor="target-course">Target Course *</Label>
                {!showCustomCourse ? (
                  <>
                    <Select value={targetCourse} onValueChange={setTargetCourse} required={!showCustomCourse}>
                      <SelectTrigger id="target-course">
                        <SelectValue placeholder="Select course..." />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectGroup>
                          <SelectItem value="CA Foundation">CA Foundation</SelectItem>
                          <SelectItem value="CA Intermediate">CA Intermediate</SelectItem>
                          <SelectItem value="CA Final">CA Final</SelectItem>
                        </SelectGroup>
                        <SelectGroup>
                          <SelectItem value="CMA Foundation">CMA Foundation</SelectItem>
                          <SelectItem value="CMA Intermediate">CMA Intermediate</SelectItem>
                          <SelectItem value="CMA Final">CMA Final</SelectItem>
                        </SelectGroup>
                        <SelectGroup>
                          <SelectItem value="CS Foundation">CS Foundation</SelectItem>
                          <SelectItem value="CS Executive">CS Executive</SelectItem>
                          <SelectItem value="CS Professional">CS Professional</SelectItem>
                        </SelectGroup>
                      </SelectContent>
                    </Select>
                    <Button
                      type="button"
                      variant="link"
                      className="h-auto p-0 text-sm"
                      onClick={() => {
                        setShowCustomCourse(true);
                        setTargetCourse('');
                      }}
                    >
                      + Add custom course
                    </Button>
                  </>
                ) : (
                  <>
                    <Input
                      value={customCourse}
                      onChange={(e) => setCustomCourse(e.target.value)}
                      placeholder="Enter custom course name (e.g., JEE Foundation, NEET)"
                      required
                    />
                    <Button
                      type="button"
                      variant="link"
                      className="h-auto p-0 text-sm"
                      onClick={() => {
                        setShowCustomCourse(false);
                        setCustomCourse('');
                      }}
                    >
                      ← Back to course list
                    </Button>
                  </>
                )}
                <p className="text-sm text-muted-foreground">
                  Select which students should see this note
                </p>
              </div>
            </CardContent>
          </Card>

          {/* Subject & Topic Card */}
          <Card>
            <CardHeader>
              <CardTitle>Subject & Topic</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              
              {/* Subject Combobox */}
              <div className="space-y-2">
                <Label>Subject *</Label>
                <Popover open={subjectOpen} onOpenChange={setSubjectOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      role="combobox"
                      aria-expanded={subjectOpen}
                      className="w-full justify-between"
                    >
                      {selectedSubject ? selectedSubject.name : "Select a subject..."}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-full p-0">
                    <Command>
                      <CommandInput placeholder="Search subjects..." />
                      <CommandEmpty>No subject found.</CommandEmpty>
                      <CommandGroup>
                        {subjects.map((subject) => (
                          <CommandItem
                            key={subject.id}
                            value={subject.name}
                            onSelect={() => {
                              setSelectedSubject(subject);
                              setSubjectOpen(false);
                              setShowCustomSubject(false);
                            }}
                          >
                            <Check
                              className={cn(
                                "mr-2 h-4 w-4",
                                selectedSubject?.id === subject.id ? "opacity-100" : "opacity-0"
                              )}
                            />
                            {subject.name}
                          </CommandItem>
                        ))}
                        <CommandItem
                          onSelect={() => {
                            setShowCustomSubject(true);
                            setSelectedSubject(null);
                            setSubjectOpen(false);
                          }}
                        >
                          <Plus className="mr-2 h-4 w-4" />
                          Add custom subject
                        </CommandItem>
                      </CommandGroup>
                    </Command>
                  </PopoverContent>
                </Popover>
              </div>

              {/* Custom Subject Input */}
              {showCustomSubject && (
                <div className="space-y-2">
                  <Label htmlFor="custom-subject">Custom Subject</Label>
                  <Input
                    id="custom-subject"
                    value={customSubject}
                    onChange={(e) => setCustomSubject(e.target.value)}
                    placeholder="Enter subject name"
                  />
                </div>
              )}

              {/* Topic Combobox */}
              <div className="space-y-2">
                <Label>Topic (Optional)</Label>
                <Popover open={topicOpen} onOpenChange={setTopicOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      role="combobox"
                      aria-expanded={topicOpen}
                      className="w-full justify-between"
                      disabled={!selectedSubject}
                    >
                      {selectedTopic ? selectedTopic.name : "Select a topic..."}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-full p-0 max-h-60 overflow-y-auto">
                    <Command>
                      <CommandInput placeholder="Search topics..." />
                      <CommandEmpty>No topic found.</CommandEmpty>
                      <CommandGroup>
                        {topics.map((topic) => (
                          <CommandItem
                            key={topic.id}
                            value={topic.name}
                            onSelect={() => {
                              setSelectedTopic(topic);
                              setTopicOpen(false);
                              setShowCustomTopic(false);
                            }}
                          >
                            <Check
                              className={cn(
                                "mr-2 h-4 w-4",
                                selectedTopic?.id === topic.id ? "opacity-100" : "opacity-0"
                              )}
                            />
                            {topic.name}
                          </CommandItem>
                        ))}
                        <CommandItem
                          onSelect={() => {
                            setShowCustomTopic(true);
                            setSelectedTopic(null);
                            setTopicOpen(false);
                          }}
                        >
                          <Plus className="mr-2 h-4 w-4" />
                          Add custom topic
                        </CommandItem>
                      </CommandGroup>
                    </Command>
                  </PopoverContent>
                </Popover>
              </div>

              {/* Custom Topic Input */}
              {showCustomTopic && (
                <div className="space-y-2">
                  <Label htmlFor="custom-topic">Custom Topic</Label>
                  <Input
                    id="custom-topic"
                    value={customTopic}
                    onChange={(e) => setCustomTopic(e.target.value)}
                    placeholder="Enter topic name"
                  />
                </div>
              )}

              {/* Tags */}
              <div className="space-y-2">
                <Label htmlFor="tags">Tags (Optional)</Label>
                <Input
                  id="tags"
                  value={tags}
                  onChange={(e) => setTags(e.target.value)}
                  placeholder="e.g., important, exam, revision (comma-separated)"
                />
                <p className="text-sm text-muted-foreground">
                  Separate multiple tags with commas
                </p>
              </div>

              {/* Public Toggle */}
              <div className="flex items-center justify-between space-x-2">
                <div className="space-y-0.5">
                  <Label htmlFor="public-toggle">Make this note public</Label>
                  <p className="text-sm text-muted-foreground">
                    {isPublic ? 'Visible to all students' : 'Only you can see this note'}
                  </p>
                </div>
                <Switch
                  id="public-toggle"
                  checked={isPublic}
                  onCheckedChange={setIsPublic}
                />
              </div>
            </CardContent>
          </Card>

          {/* File Upload Card */}
          <Card>
            <CardHeader>
              <CardTitle>File Upload</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="file-upload">Select File *</Label>
                  <div className="flex items-center justify-center w-full">
                    <label
                      htmlFor="file-upload"
                      className="flex flex-col items-center justify-center w-full h-64 border-2 border-dashed rounded-lg cursor-pointer hover:bg-accent"
                    >
                      {filePreview ? (
                        <img
                          src={filePreview}
                          alt="Preview"
                          className="max-h-56 rounded-lg"
                        />
                      ) : (
                        <div className="flex flex-col items-center justify-center pt-5 pb-6">
                          <ImageIcon className="w-12 h-12 mb-4 text-muted-foreground" />
                          <Upload className="w-8 h-8 mb-2 text-muted-foreground" />
                          <p className="mb-2 text-sm text-muted-foreground">
                            {file ? file.name : 'Click to upload or drag and drop'}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            JPG, PNG, or PDF (max 10MB)
                          </p>
                        </div>
                      )}
                      <input
                        id="file-upload"
                        type="file"
                        accept="image/jpeg,image/png,image/jpg,application/pdf"
                        onChange={handleFileChange}
                        className="hidden"
                      />
                    </label>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Note Details Card */}
          <Card>
            <CardHeader>
              <CardTitle>Note Details (Optional)</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="title">Title</Label>
                <Input
                  id="title"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Enter a descriptive title"
                />
                <p className="text-sm text-muted-foreground">
                  Leave blank to use filename
                </p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Textarea
                  id="description"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Add any additional details about this note"
                  rows={3}
                />
              </div>
            </CardContent>
          </Card>

          {/* Action Buttons */}
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
              {loading ? 'Uploading...' : 'Upload Note'}
            </Button>
          </div>
        </form>
      </div>
      </div>
    </div>
  );
}