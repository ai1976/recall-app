import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useToast } from '@/hooks/use-toast';
import { Plus, Trash2, Upload, ArrowLeft, Check, ChevronsUpDown } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';

export default function FlashcardCreate() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const noteId = searchParams.get('noteId');
  const { toast } = useToast();

  const [note, setNote] = useState(null);
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
  const [loading, setLoading] = useState(false);
  const [isPublic, setIsPublic] = useState(false);

  // Combobox states
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  const [flashcards, setFlashcards] = useState([
    { front_text: '', front_image_url: null, back_text: '', back_image_url: null }
  ]);

  useEffect(() => {
    fetchUserCourseLevel();
    if (noteId) {
      fetchNoteDetails();
    }
  }, [noteId]);

  useEffect(() => {
    if (userCourseLevel && !noteId) {
      fetchSubjects();
    }
  }, [userCourseLevel, noteId]);

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

  const fetchNoteDetails = async () => {
    try {
      const { data, error } = await supabase
        .from('notes')
        .select(`
          *,
          subject:subjects(id, name),
          topic:topics(id, name)
        `)
        .eq('id', noteId)
        .single();

      if (error) throw error;
      setNote(data);
      // If creating from note, inherit its public status
      setIsPublic(data.is_public || false);
    } catch (error) {
      console.error('Error fetching note:', error);
      toast({
        title: 'Error',
        description: 'Failed to load note details',
        variant: 'destructive'
      });
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

  const handleImageUpload = async (file, cardIndex, side) => {
    if (!file) return null;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      const fileExt = file.name.split('.').pop();
      const fileName = `${user.id}/${Date.now()}_${side}.${fileExt}`;

      const { error: uploadError } = await supabase.storage
        .from('flashcard-images')
        .upload(fileName, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('flashcard-images')
        .getPublicUrl(fileName);

      return publicUrl;
    } catch (error) {
      console.error('Error uploading image:', error);
      toast({
        title: 'Upload Error',
        description: 'Failed to upload image',
        variant: 'destructive'
      });
      return null;
    }
  };

  const handleFrontImageChange = async (e, index) => {
    const file = e.target.files[0];
    if (file) {
      const imageUrl = await handleImageUpload(file, index, 'front');
      if (imageUrl) {
        const newFlashcards = [...flashcards];
        newFlashcards[index].front_image_url = imageUrl;
        setFlashcards(newFlashcards);
      }
    }
  };

  const handleBackImageChange = async (e, index) => {
    const file = e.target.files[0];
    if (file) {
      const imageUrl = await handleImageUpload(file, index, 'back');
      if (imageUrl) {
        const newFlashcards = [...flashcards];
        newFlashcards[index].back_image_url = imageUrl;
        setFlashcards(newFlashcards);
      }
    }
  };

  const addFlashcard = () => {
    setFlashcards([
      ...flashcards,
      { front_text: '', front_image_url: null, back_text: '', back_image_url: null }
    ]);
  };

  const removeFlashcard = (index) => {
    if (flashcards.length > 1) {
      setFlashcards(flashcards.filter((_, i) => i !== index));
    }
  };

  const updateFlashcard = (index, field, value) => {
    const newFlashcards = [...flashcards];
    newFlashcards[index][field] = value;
    setFlashcards(newFlashcards);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    // Validation
    if (!noteId && !selectedSubject && !customSubject.trim()) {
      toast({
        title: 'Subject required',
        description: 'Please select a subject or enter a custom subject',
        variant: 'destructive'
      });
      return;
    }

    const hasEmptyCards = flashcards.some(card => 
      !card.front_text.trim() && !card.front_image_url
    );

    if (hasEmptyCards) {
      toast({
        title: 'Incomplete flashcards',
        description: 'Each flashcard must have at least front text or image',
        variant: 'destructive'
      });
      return;
    }

    setLoading(true);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      // Parse tags
      const tagsArray = tags.split(',').map(tag => tag.trim()).filter(tag => tag.length > 0);

      const flashcardData = flashcards.map(card => ({
        user_id: user.id,
        note_id: noteId || null,
        subject_id: note?.subject_id || selectedSubject || null,
        topic_id: note?.topic_id || selectedTopic || null,
        custom_subject: customSubject.trim() || null,
        custom_topic: customTopic.trim() || null,
        tags: tagsArray.length > 0 ? tagsArray : null,
        front_text: card.front_text.trim(),
        front_image_url: card.front_image_url,
        back_text: card.back_text.trim(),
        back_image_url: card.back_image_url,
        is_public: isPublic
      }));

      const { error } = await supabase
        .from('flashcards')
        .insert(flashcardData);

      if (error) throw error;

      toast({
        title: 'Success',
        description: `${flashcards.length} flashcard(s) created successfully`
      });

      navigate('/flashcards');
    } catch (error) {
      console.error('Error creating flashcards:', error);
      toast({
        title: 'Error',
        description: 'Failed to create flashcards',
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
        <h1 className="text-3xl font-bold">Create Flashcards</h1>
        {note && (
          <p className="text-muted-foreground mt-2">
            From note: {note.title}
          </p>
        )}
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Subject and Topic Selection - Only show if not from a note */}
        {!noteId && (
          <Card>
            <CardHeader>
              <CardTitle>Subject & Topic</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Subject Selection */}
              <div className="space-y-2">
                <Label>Subject</Label>
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
                  <Label htmlFor="flashcard-public-toggle">Make these flashcards public</Label>
                  <button
                    type="button"
                    id="flashcard-public-toggle"
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
                    ? "✓ Other students can view these flashcards" 
                    : "○ Only you can see these flashcards"}
                </p>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Show inherited status if from note */}
        {noteId && note && (
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium">Visibility</p>
                  <p className="text-sm text-muted-foreground">
                    {isPublic 
                      ? "These flashcards will be public (inherited from parent note)" 
                      : "These flashcards will be private (inherited from parent note)"}
                  </p>
                </div>
                <div className={cn(
                  "px-3 py-1 rounded-full text-sm font-medium",
                  isPublic ? "bg-blue-100 text-blue-700" : "bg-gray-100 text-gray-700"
                )}>
                  {isPublic ? "Public" : "Private"}
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Flashcards */}
        {flashcards.map((card, index) => (
          <Card key={index}>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>Flashcard {index + 1}</CardTitle>
                {flashcards.length > 1 && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => removeFlashcard(index)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                )}
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Front */}
              <div className="space-y-2">
                <Label>Front</Label>
                <Textarea
                  placeholder="Question or prompt"
                  value={card.front_text}
                  onChange={(e) => updateFlashcard(index, 'front_text', e.target.value)}
                  rows={3}
                />
                <div className="flex items-center gap-2">
                  <Input
                    type="file"
                    accept="image/*"
                    onChange={(e) => handleFrontImageChange(e, index)}
                    className="hidden"
                    id={`front-image-${index}`}
                  />
                  <Label
                    htmlFor={`front-image-${index}`}
                    className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 bg-secondary text-secondary-foreground rounded-md hover:bg-secondary/80"
                  >
                    <Upload className="h-4 w-4" />
                    Add Image
                  </Label>
                  {card.front_image_url && (
                    <span className="text-sm text-green-600">✓ Image added</span>
                  )}
                </div>
              </div>

              {/* Back */}
              <div className="space-y-2">
                <Label>Back</Label>
                <Textarea
                  placeholder="Answer or explanation"
                  value={card.back_text}
                  onChange={(e) => updateFlashcard(index, 'back_text', e.target.value)}
                  rows={3}
                />
                <div className="flex items-center gap-2">
                  <Input
                    type="file"
                    accept="image/*"
                    onChange={(e) => handleBackImageChange(e, index)}
                    className="hidden"
                    id={`back-image-${index}`}
                  />
                  <Label
                    htmlFor={`back-image-${index}`}
                    className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 bg-secondary text-secondary-foreground rounded-md hover:bg-secondary/80"
                  >
                    <Upload className="h-4 w-4" />
                    Add Image
                  </Label>
                  {card.back_image_url && (
                    <span className="text-sm text-green-600">✓ Image added</span>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        ))}

        {/* Actions */}
        <div className="flex gap-4">
          <Button
            type="button"
            variant="outline"
            onClick={addFlashcard}
            className="flex-1"
          >
            <Plus className="mr-2 h-4 w-4" />
            Add Another Flashcard
          </Button>
          <Button
            type="submit"
            disabled={loading}
            className="flex-1"
          >
            {loading ? 'Creating...' : `Create ${flashcards.length} Flashcard(s)`}
          </Button>
        </div>
      </form>
    </div>
  );
}