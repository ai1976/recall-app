import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useToast } from '@/hooks/use-toast';
import { Save, ArrowLeft, Check, ChevronsUpDown, Plus } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';

export default function NoteEdit() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { toast } = useToast();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [contentType, setContentType] = useState('text');
  const [extractedText, setExtractedText] = useState('');

  const [userCourseLevel, setUserCourseLevel] = useState(null);
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
    fetchUserCourseLevel();
    fetchNote();
  }, [id]);

  useEffect(() => {
    if (userCourseLevel) {
      fetchSubjects();
    }
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

      // Pre-fill form with note data
      setTitle(data.title || '');
      setDescription(data.description || '');
      setContentType(data.content_type || 'text');
      setExtractedText(data.extracted_text || '');
      setIsPublic(data.is_public || false);

      // Handle tags
      if (data.tags && Array.isArray(data.tags)) {
        setTags(data.tags.join(', '));
      }

      // Handle subject/topic
      if (data.custom_subject) {
        setShowCustomSubject(true);
        setCustomSubject(data.custom_subject);
      } else if (data.subject_id) {
        setSelectedSubject(data.subject_id);
      }

      if (data.custom_topic) {
        setShowCustomTopic(true);
        setCustomTopic(data.custom_topic);
      } else if (data.topic_id) {
        setSelectedTopic(data.topic_id);
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

  const fetchSubjects = async () => {
    try {
      const { data, error } = await supabase
        .from('subjects')
        .select(`
          *,
          discipline:disciplines!inner(name, level)
        `)
        .eq('disciplines.level', userCourseLevel)
        .eq('is_active', true)
        .order('order');

      if (error) throw error;
      setSubjects(data || []);
    } catch (error) {
      console.error('Error fetching subjects:', error);
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
      // Parse tags
      const tagsArray = tags.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0);

      // Update note record
      const updateData = {
        title: title.trim(),
        description: description.trim() || null,
        subject_id: selectedSubject || null,
        topic_id: selectedTopic || null,
        custom_subject: customSubject.trim() || null,
        custom_topic: customTopic.trim() || null,
        content_type: contentType,
        extracted_text: extractedText.trim() || null,
        tags: tagsArray.length > 0 ? tagsArray : null,
        is_public: isPublic,
        updated_at: new Date().toISOString()
      };

      const { error: updateError } = await supabase
        .from('notes')
        .update(updateData)
        .eq('id', id);

      if (updateError) throw updateError;

      toast({
        title: 'Success',
        description: 'Note updated successfully'
      });

      navigate(`/notes/${id}`);
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

  // Get selected subject name for display
  const selectedSubjectName = subjects.find(s => s.id === selectedSubject)?.name || '';
  const selectedTopicName = topics.find(t => t.id === selectedTopic)?.name || '';

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
          onClick={() => navigate(`/notes/${id}`)}
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

            {/* Extracted Text */}
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

        {/* Submit */}
        <div className="flex gap-4">
          <Button
            type="button"
            variant="outline"
            onClick={() => navigate(`/notes/${id}`)}
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