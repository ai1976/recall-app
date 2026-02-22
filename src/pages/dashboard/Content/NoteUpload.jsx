import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { Upload, ArrowLeft, Image as ImageIcon, Check, ChevronsUpDown, Plus } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { notifyContentCreated } from '@/lib/notifyEdge';

export default function NoteUpload() {
  const navigate = useNavigate();
  const { toast } = useToast();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [file, setFile] = useState(null);
  const [filePreview, setFilePreview] = useState(null);
  const [contentType, setContentType] = useState('text');
  const [extractedText, setExtractedText] = useState('');
  const [loading, setLoading] = useState(false);
  const [visibility, setVisibility] = useState('private');
  const [userGroups, setUserGroups] = useState([]);
  const [selectedGroupIds, setSelectedGroupIds] = useState([]);

  const [targetCourse, setTargetCourse] = useState('');
  const [showCustomCourse, setShowCustomCourse] = useState(false);
  const [customCourse, setCustomCourse] = useState('');
  const [allCourses, setAllCourses] = useState([]);
  const [disciplines, setDisciplines] = useState([]);

  const [subjects, setSubjects] = useState([]);
  const [selectedSubject, setSelectedSubject] = useState(null);
  const [topics, setTopics] = useState([]);
  const [selectedTopic, setSelectedTopic] = useState(null);
  const [tags, setTags] = useState('');
  const [showCustomSubject, setShowCustomSubject] = useState(false);
  const [customSubject, setCustomSubject] = useState('');
  const [showCustomTopic, setShowCustomTopic] = useState(false);
  const [customTopic, setCustomTopic] = useState('');

  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  useEffect(() => {
    fetchDisciplines();
    fetchAllCourses();
    fetchUserGroups();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // When targetCourse changes, filter subjects by matching discipline
  useEffect(() => {
    if (targetCourse && disciplines.length > 0) {
      const matchedDiscipline = disciplines.find(
        d => d.name.toLowerCase() === targetCourse.toLowerCase()
      );
      fetchSubjects(matchedDiscipline?.id || null);
    } else if (!targetCourse && !showCustomCourse) {
      setSubjects([]);
    }
    // Reset subject & topic when course changes
    setSelectedSubject(null);
    setSelectedTopic(null);
    setTopics([]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targetCourse, disciplines]);

  const fetchUserGroups = async () => {
    try {
      const { data, error } = await supabase.rpc('get_user_groups');
      if (error) throw error;
      setUserGroups(data || []);
    } catch (error) {
      console.error('Error fetching user groups:', error);
    }
  };

  const toggleGroupSelection = (groupId) => {
    setSelectedGroupIds(prev =>
      prev.includes(groupId)
        ? prev.filter(id => id !== groupId)
        : [...prev, groupId]
    );
  };

  const fetchDisciplines = async () => {
    try {
      const { data, error } = await supabase
        .from('disciplines')
        .select('id, name')
        .eq('is_active', true)
        .order('order_num')
        .order('name');

      if (error) throw error;
      setDisciplines(data || []);
    } catch (error) {
      console.error('Error fetching disciplines:', error);
    }
  };

  const fetchSubjects = async (disciplineId) => {
    try {
      let query = supabase
        .from('subjects')
        .select('*')
        .order('name');

      if (disciplineId) {
        query = query.eq('discipline_id', disciplineId);
      }

      const { data, error } = await query;

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

  const fetchAllCourses = async () => {
    try {
      const { data: noteCourses, error: noteError } = await supabase
        .from('notes')
        .select('target_course')
        .not('target_course', 'is', null);

      const { data: flashcardCourses, error: flashError } = await supabase
        .from('flashcards')
        .select('target_course')
        .not('target_course', 'is', null);

      const { data: profileCourses, error: profileError } = await supabase
        .from('profiles')
        .select('course_level')
        .not('course_level', 'is', null);

      if (noteError) throw noteError;
      if (flashError) throw flashError;
      if (profileError) throw profileError;

      const predefinedCourses = [
        'CA Foundation',
        'CA Intermediate',
        'CA Final',
        'CMA Foundation',
        'CMA Intermediate',
        'CMA Final',
        'CS Foundation',
        'CS Executive',
        'CS Professional'
      ];

      const customFromNotes = noteCourses?.map(n => n.target_course) || [];
      const customFromFlashcards = flashcardCourses?.map(f => f.target_course) || [];
      const customFromProfiles = profileCourses?.map(p => p.course_level) || [];
      
      const allCustomCourses = [...new Set([
        ...customFromNotes, 
        ...customFromFlashcards,
        ...customFromProfiles
      ])];

      const uniqueCustomCourses = allCustomCourses.filter(
        course => !predefinedCourses.includes(course)
      );

      const mergedCourses = [...predefinedCourses, ...uniqueCustomCourses].sort();

      setAllCourses(mergedCourses);
    } catch (error) {
      console.error('Error fetching courses:', error);
      setAllCourses([
        'CA Foundation',
        'CA Intermediate',
        'CA Final',
        'CMA Foundation',
        'CMA Intermediate',
        'CMA Final',
        'CS Foundation',
        'CS Executive',
        'CS Professional'
      ]);
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

    const validTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'];
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

    setFile(selectedFile);

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
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      if (!targetCourse && !customCourse) {
        throw new Error('Please select or enter which course this note is for');
      }

      if (!file) {
        throw new Error('Please select a file to upload');
      }

      if (!selectedSubject && !customSubject) {
        throw new Error('Please select or enter a subject');
      }

      const fileExt = file.name.split('.').pop();
      const fileName = `${user.id}/${Date.now()}.${fileExt}`;
      
      const { error: uploadError } = await supabase.storage
        .from('notes')
        .upload(fileName, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('notes')
        .getPublicUrl(fileName);

      // For study_groups visibility, store as 'private' in DB (access via group shares)
      const dbVisibility = visibility === 'study_groups' ? 'private' : visibility;

      const noteData = {
        user_id: user.id,
        contributed_by: user.id,
        target_course: customCourse || targetCourse,
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
        visibility: dbVisibility,
        is_public: visibility === 'public',
      };

      const { data: insertedNote, error: insertError } = await supabase
        .from('notes')
        .insert(noteData)
        .select('id')
        .single();

      if (insertError) throw insertError;

      // Share with selected study groups
      if (visibility === 'study_groups' && selectedGroupIds.length > 0 && insertedNote) {
        const { error: shareError } = await supabase.rpc('share_content_with_groups', {
          p_content_type: 'note',
          p_content_id: insertedNote.id,
          p_group_ids: selectedGroupIds,
        });
        if (shareError) console.error('Error sharing with groups:', shareError);
      }

      toast({
        title: 'Success!',
        description: visibility === 'study_groups'
          ? `Note uploaded and shared with ${selectedGroupIds.length} group(s)`
          : 'Note uploaded successfully',
      });

      // Fire-and-forget push notification — never blocks the upload flow
      if (insertedNote && ['public', 'friends'].includes(dbVisibility)) {
        notifyContentCreated({
          content_type: 'note',
          content_id: insertedNote.id,
          creator_id: user.id,
          title: noteData.title,
          subject_name: selectedSubject?.name || customSubject || null,
          visibility: dbVisibility,
          target_course: noteData.target_course,
        });
      }

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
                        {allCourses.map((course) => (
                          <SelectItem key={course} value={course}>
                            {course}
                          </SelectItem>
                        ))}
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

          <Card>
            <CardHeader>
              <CardTitle>Subject & Topic</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              
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

              {/* Visibility Dropdown */}
              <div className="space-y-2">
                <Label htmlFor="visibility">Who can see this note?</Label>
                <Select value={visibility} onValueChange={(val) => {
                  setVisibility(val);
                  if (val !== 'study_groups') setSelectedGroupIds([]);
                }}>
                  <SelectTrigger id="visibility">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="private">Private (Only me)</SelectItem>
                    <SelectItem value="study_groups">Study Groups</SelectItem>
                    <SelectItem value="friends">Friends Only</SelectItem>
                    <SelectItem value="public">Public (Everyone)</SelectItem>
                  </SelectContent>
                </Select>
                <p className="text-sm text-muted-foreground">
                  {visibility === 'private' && 'Only you can see this note'}
                  {visibility === 'study_groups' && 'Share with selected study groups'}
                  {visibility === 'friends' && 'Only your friends can see this note'}
                  {visibility === 'public' && 'Everyone can see this note'}
                </p>
              </div>

              {/* Study Group Selection */}
              {visibility === 'study_groups' && (
                <div className="space-y-2">
                  <Label>Select Groups</Label>
                  {userGroups.length === 0 ? (
                    <p className="text-sm text-muted-foreground">
                      You are not in any study groups.{' '}
                      <button
                        type="button"
                        className="text-blue-600 hover:underline"
                        onClick={() => navigate('/dashboard/groups/new')}
                      >
                        Create one
                      </button>
                    </p>
                  ) : (
                    <div className="space-y-2 max-h-48 overflow-y-auto border rounded-lg p-2">
                      {userGroups.map((group) => (
                        <label
                          key={group.id}
                          className="flex items-center gap-3 p-2 rounded-md hover:bg-gray-50 cursor-pointer"
                        >
                          <input
                            type="checkbox"
                            checked={selectedGroupIds.includes(group.id)}
                            onChange={() => toggleGroupSelection(group.id)}
                            className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                          />
                          <div className="min-w-0">
                            <p className="text-sm font-medium text-gray-900 truncate">{group.name}</p>
                            <p className="text-xs text-gray-500">{group.member_count} members</p>
                          </div>
                        </label>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </CardContent>
          </Card>

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

              <div className="space-y-2">
                <Label>Content Type</Label>
                <div className="flex gap-2 flex-wrap">
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