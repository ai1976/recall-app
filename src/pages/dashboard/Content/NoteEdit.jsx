import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { Save, ArrowLeft, Check, ChevronsUpDown, Plus, Upload, X, FileText } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';

export default function NoteEdit() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [contentType, setContentType] = useState('text');
  const [extractedText, setExtractedText] = useState('');

  const [targetCourse, setTargetCourse] = useState('');
  const [availableCourses, setAvailableCourses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [selectedSubject, setSelectedSubject] = useState(null);
  const [topics, setTopics] = useState([]);
  const [selectedTopic, setSelectedTopic] = useState(null);
  const [tags, setTags] = useState('');
  const [showCustomSubject, setShowCustomSubject] = useState(false);
  const [customSubject, setCustomSubject] = useState('');
  const [showCustomTopic, setShowCustomTopic] = useState(false);
  const [customTopic, setCustomTopic] = useState('');
  const [visibility, setVisibility] = useState('private');

  // Combobox states
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  // Image replacement states
  const [currentImageUrl, setCurrentImageUrl] = useState('');
  const [newFile, setNewFile] = useState(null);
  const [newFilePreview, setNewFilePreview] = useState(null);
  const [isReplacingImage, setIsReplacingImage] = useState(false);

  useEffect(() => {
    fetchCourses();
    fetchNote();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

   useEffect(() => {
    if (selectedSubject && !showCustomSubject) {
      fetchTopics(selectedSubject);
    } else {
      setTopics([]);
      setSelectedTopic(null);
    }
  }, [selectedSubject, showCustomSubject]);

  const fetchCourses = async () => {
    try {
      const { data: notesData } = await supabase
        .from('notes')
        .select('target_course');

      const { data: flashcardsData } = await supabase
        .from('flashcards')
        .select('target_course');

      const { data: profilesData } = await supabase
        .from('profiles')
        .select('course_level');

      const allCourses = [
        ...(notesData?.map(n => n.target_course) || []),
        ...(flashcardsData?.map(f => f.target_course) || []),
        ...(profilesData?.map(p => p.course_level) || [])
      ].filter(Boolean);

      const uniqueCourses = [...new Set(allCourses)];
      setAvailableCourses(uniqueCourses);
    } catch (error) {
      console.error('Error fetching courses:', error);
    }
  };

  const fetchNote = async () => {
    try {
      const { data, error } = await supabase
        .from('notes')
        .select(`
          *,
          subject:subjects(id, name),
          topic:topics(id, name)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      if (!data) {
        toast({
          title: 'Error',
          description: 'Note not found',
          variant: 'destructive'
        });
        navigate('/dashboard');
        return;
      }

      // Check ownership
      if (data.user_id !== user.id) {
        toast({
          title: "Access Denied",
          description: "You can only edit your own notes",
          variant: "destructive"
        });
        navigate('/dashboard/my-notes');
        return;
      }

      // Pre-fill form with note data
      setTitle(data.title || '');
      setDescription(data.description || '');
      setContentType(data.content_type || 'text');
      setExtractedText(data.extracted_text || '');
      setTargetCourse(data.target_course || '');
      setVisibility(data.visibility || 'private');
      setCurrentImageUrl(data.image_url || '');

      // Handle tags
      if (data.tags && Array.isArray(data.tags)) {
        setTags(data.tags.join(', '));
      }

      if (data.target_course) {
        const level = data.target_course.replace(/^(CA|CMA|CS)\s+/, '');
        const subjectsData = await fetchSubjectsForCourse(level);

        console.log('Subjects fetched:', subjectsData.length);

        setTimeout(() => {
          if (data.custom_subject) {
            setShowCustomSubject(true);
            setCustomSubject(data.custom_subject);
          } else if (data.subject_id) {
            console.log('Set selected subject to:', data.subject_id);
            setSelectedSubject(data.subject_id);

            if (data.subject_id) {
              fetchTopics(data.subject_id);
            }
          }

          if (data.custom_topic) {
            setShowCustomTopic(true);
            setCustomTopic(data.custom_topic);
          } else if (data.topic_id) {
            setSelectedTopic(data.topic_id);
          }
        }, 100);
      }

    } catch (error) {
      console.error('Error fetching note:', error);
      toast({
        title: 'Error',
        description: 'Failed to load note',
        variant: 'destructive'
      });
    } finally {
      setLoading(false);
    }
  };

  const fetchSubjectsForCourse = async (course) => {
    try {
      console.log('Fetching subjects for course:', course);
      const { data, error } = await supabase
        .from('subjects')
        .select(`
          *,
          discipline:disciplines!inner(name, level)
        `)
        .eq('disciplines.level', course)
        .eq('is_active', true)
        .order('order');

      if (error) throw error;
      console.log('Query returned subjects:', data);
      setSubjects(data || []);
      return data || [];
    } catch (error) {
      console.error('Error fetching subjects:', error);
      return [];
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
    }
  };

  const handleCourseChange = async (course) => {
    setTargetCourse(course);
    setSelectedSubject(null);
    setSelectedTopic(null);
    setCustomSubject('');
    setCustomTopic('');
    setSubjects([]);
    setTopics([]);
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files?.[0];
    if (!selectedFile) return;

    const validTypes = ['image/jpeg', 'image/png', 'image/jpg', 'image/webp', 'application/pdf'];
    if (!validTypes.includes(selectedFile.type)) {
      toast({
        title: 'Invalid file type',
        description: 'Please upload a JPG, PNG, or PDF file',
        variant: 'destructive',
      });
      return;
    }

    if (selectedFile.size > 10 * 1024 * 1024) {
      toast({
        title: 'File too large',
        description: 'File size must be less than 10MB',
        variant: 'destructive',
      });
      return;
    }

    setNewFile(selectedFile);

    if (selectedFile.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setNewFilePreview(reader.result);
      };
      reader.readAsDataURL(selectedFile);
    } else {
      setNewFilePreview(null);
    }
  };

  const cancelImageReplacement = () => {
    setNewFile(null);
    setNewFilePreview(null);
    setIsReplacingImage(false);
  };

  const extractFilePathFromUrl = (url) => {
    if (!url) return null;
    try {
      const match = url.match(/\/notes\/(.+)$/);
      return match ? match[1] : null;
    } catch {
      return null;
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!title.trim()) {
      toast({
        title: 'Title required',
        description: 'Please enter a title for your note',
        variant: 'destructive'
      });
      return;
    }

    if (!targetCourse) {
      toast({
        title: 'Course required',
        description: 'Please select who this note is for',
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

    setSaving(true);

    try {
      let newImageUrl = currentImageUrl;

      if (newFile) {
        const fileExt = newFile.name.split('.').pop();
        const fileName = `${user.id}/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;

                const { error: uploadError } = await supabase.storage
          .from('notes')
          .upload(fileName, newFile);

        if (uploadError) throw uploadError;

        const { data: urlData } = supabase.storage
          .from('notes')
          .getPublicUrl(fileName);

        newImageUrl = urlData.publicUrl;

        if (currentImageUrl) {
          const oldFilePath = extractFilePathFromUrl(currentImageUrl);
          if (oldFilePath) {
            const { error: deleteError } = await supabase.storage
              .from('notes')
              .remove([oldFilePath]);

            if (deleteError) {
              console.warn('Failed to delete old file:', deleteError);
            }
          }
        }
      }

      const tagsArray = tags.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0);

      const updateData = {
        title: title.trim(),
        description: description.trim() || null,
        target_course: targetCourse,
        subject_id: selectedSubject || null,
        topic_id: selectedTopic || null,
        custom_subject: customSubject.trim() || null,
        custom_topic: customTopic.trim() || null,
        content_type: contentType,
        extracted_text: extractedText.trim() || null,
        tags: tagsArray.length > 0 ? tagsArray : null,
        visibility: visibility,
        is_public: visibility === 'public',
        image_url: newImageUrl,
        updated_at: new Date().toISOString()
      };

      const { error: updateError } = await supabase
        .from('notes')
        .update(updateData)
        .eq('id', id);

      if (updateError) throw updateError;

      toast({
        title: 'Success',
        description: newFile ? 'Note and image updated successfully' : 'Note updated successfully'
      });

      navigate(`/dashboard/notes/${id}`);
    } catch (error) {
      console.error('Error updating note:', error);
      toast({
        title: 'Error',
        description: 'Failed to update note',
        variant: 'destructive'
      });
    } finally {
      setSaving(false);
    }
  };

  const selectedSubjectName = subjects.find(s => s.id === selectedSubject)?.name || '';
  const selectedTopicName = topics.find(t => t.id === selectedTopic)?.name || '';

  const isPdf = currentImageUrl?.toLowerCase().endsWith('.pdf');
  const newFileIsPdf = newFile?.type === 'application/pdf';

  if (loading) {
    return (
      <div className="container mx-auto p-4 max-w-4xl">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-muted-foreground">Loading note...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-4 max-w-4xl">
      <div className="mb-6">
        <Button
          variant="ghost"
          onClick={() => navigate(`/dashboard/notes/${id}`)}
          className="mb-4"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Note
        </Button>
        <h1 className="text-3xl font-bold">Edit Note</h1>
        <p className="text-muted-foreground mt-2">
          Update your note details
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Image/File Section */}
        <Card>
          <CardHeader>
            <CardTitle>Note Image/PDF</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {!isReplacingImage && currentImageUrl && (
              <div className="space-y-3">
                <Label>Current File</Label>
                <div className="relative border rounded-lg overflow-hidden bg-gray-50">
                  {isPdf ? (
                    <div className="flex items-center justify-center p-8 bg-gray-100">
                      <div className="text-center">
                        <FileText className="h-16 w-16 text-red-500 mx-auto mb-2" />
                        <p className="text-sm text-gray-600">PDF Document</p>
                        <a
                          href={currentImageUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-sm text-blue-600 hover:underline"
                        >
                          View PDF
                        </a>
                      </div>
                    </div>
                  ) : (
                    <img
                      src={currentImageUrl}
                      alt="Current note"
                      className="w-full max-h-64 object-contain"
                    />
                  )}
                </div>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsReplacingImage(true)}
                  className="gap-2"
                >
                  <Upload className="h-4 w-4" />
                  Replace Image/PDF
                </Button>
              </div>
            )}

            {!isReplacingImage && !currentImageUrl && (
              <div className="space-y-3">
                <Label>No file attached</Label>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsReplacingImage(true)}
                  className="gap-2"
                >
                  <Upload className="h-4 w-4" />
                  Add Image/PDF
                </Button>
              </div>
            )}

            {isReplacingImage && (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label>Select New File</Label>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={cancelImageReplacement}
                    className="gap-1 text-gray-500"
                  >
                    <X className="h-4 w-4" />
                    Cancel
                  </Button>
                </div>

                <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 hover:border-gray-400 transition-colors">
                  <label
                    htmlFor="file-replace"
                    className="cursor-pointer flex flex-col items-center justify-center"
                  >
                    {newFilePreview ? (
                      <div className="space-y-3 w-full">
                        <img
                          src={newFilePreview}
                          alt="New file preview"
                          className="max-h-48 mx-auto object-contain rounded"
                        />
                        <p className="text-sm text-center text-gray-600">
                          {newFile?.name}
                        </p>
                      </div>
                    ) : newFile && newFileIsPdf ? (
                      <div className="text-center">
                        <FileText className="h-16 w-16 text-red-500 mx-auto mb-2" />
                        <p className="text-sm text-gray-600">{newFile.name}</p>
                        <p className="text-xs text-gray-400 mt-1">PDF Document</p>
                      </div>
                    ) : (
                      <div className="text-center">
                        <Upload className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                        <p className="text-sm font-medium text-gray-700">
                          Click to upload or drag and drop
                        </p>
                        <p className="text-xs text-gray-500 mt-1">
                          JPG, PNG, or PDF (max 10MB)
                        </p>
                      </div>
                    )}
                    <input
                      id="file-replace"
                      type="file"
                      accept=".jpg,.jpeg,.png,.webp,.pdf"
                      onChange={handleFileChange}
                      className="hidden"
                    />
                  </label>
                </div>

                {currentImageUrl && (
                  <div className="bg-gray-50 p-3 rounded-lg">
                    <p className="text-xs text-gray-500 mb-2">Current file (will be replaced):</p>
                    {isPdf ? (
                      <div className="flex items-center gap-2">
                        <FileText className="h-5 w-5 text-red-500" />
                        <span className="text-sm text-gray-600">PDF Document</span>
                      </div>
                    ) : (
                      <img
                        src={currentImageUrl}
                        alt="Current"
                        className="max-h-24 object-contain rounded"
                      />
                    )}
                  </div>
                )}
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

            {extractedText && (
              <div className="space-y-2">
                <Label htmlFor="extracted-text">Extracted Text</Label>
                <Textarea
                  id="extracted-text"
                  value={extractedText}
                  onChange={(e) => setExtractedText(e.target.value)}
                  rows={6}
                  placeholder="Extracted text..."
                />
              </div>
            )}
          </CardContent>
        </Card>

        {/* Subject & Topic */}
        <Card>
          <CardHeader>
            <CardTitle>Subject & Topic</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="course">Who is this for? *</Label>
              <Select value={targetCourse} onValueChange={handleCourseChange}>
                <SelectTrigger>
                  <SelectValue placeholder="Select target course" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="CA Foundation">CA Foundation</SelectItem>
                  <SelectItem value="CA Intermediate">CA Intermediate</SelectItem>
                  <SelectItem value="CA Final">CA Final</SelectItem>
                  <SelectItem value="CMA Foundation">CMA Foundation</SelectItem>
                  <SelectItem value="CMA Intermediate">CMA Intermediate</SelectItem>
                  <SelectItem value="CMA Final">CMA Final</SelectItem>
                  <SelectItem value="CS Foundation">CS Foundation</SelectItem>
                  <SelectItem value="CS Executive">CS Executive</SelectItem>
                  <SelectItem value="CS Professional">CS Professional</SelectItem>
                  {availableCourses
                    .filter(c => !['CA Foundation', 'CA Intermediate', 'CA Final', 'CMA Foundation', 'CMA Intermediate', 'CMA Final', 'CS Foundation', 'CS Executive', 'CS Professional'].includes(c))
                    .map(course => (
                      <SelectItem key={course} value={course}>
                        {course}
                      </SelectItem>
                    ))}
                </SelectContent>
              </Select>
            </div>

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
                      disabled={!targetCourse}
                    >
                      {selectedSubject ? selectedSubjectName : (targetCourse ? "Select a subject..." : "Select course first")}
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

            <div className="space-y-2">
              <Label htmlFor="visibility">Who can see this note?</Label>
              <Select value={visibility} onValueChange={setVisibility}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="private">Private (Only me)</SelectItem>
                  <SelectItem value="friends">Friends Only</SelectItem>
                  <SelectItem value="public">Public (Everyone)</SelectItem>
                </SelectContent>
              </Select>
              <p className="text-sm text-muted-foreground">
                {visibility === 'private' && 'Only you can see this note'}
                {visibility === 'friends' && 'Only your accepted friends can see this note'}
                {visibility === 'public' && 'Anyone can discover and view this note'}
              </p>
            </div>

          </CardContent>
        </Card>

        <div className="flex gap-4">
          <Button
            type="button"
            variant="outline"
            onClick={() => navigate(`/dashboard/notes/${id}`)}
            className="flex-1"
          >
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={saving}
            className="flex-1"
          >
            <Save className="mr-2 h-4 w-4" />
            {saving ? 'Saving...' : 'Save Changes'}
          </Button>
        </div>
      </form>
    </div>
  );
}
