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
import { ArrowLeft, Plus, Trash2, Image as ImageIcon, Check, ChevronsUpDown } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';

export default function FlashcardCreate() {
  const navigate = useNavigate();
  const { toast } = useToast();

  const [targetCourse, setTargetCourse] = useState('');
  const [showCustomCourse, setShowCustomCourse] = useState(false);
  const [customCourse, setCustomCourse] = useState('');
  const [allCourses, setAllCourses] = useState([]);

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
  
  const [flashcards, setFlashcards] = useState([
    { front: '', back: '', frontImage: null, backImage: null }
  ]);
  
  const [loading, setLoading] = useState(false);
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  useEffect(() => {
    fetchSubjects();
    fetchAllCourses();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchSubjects = async () => {
    try {
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

  const addFlashcard = () => {
    setFlashcards([
      ...flashcards,
      { front: '', back: '', frontImage: null, backImage: null }
    ]);
  };

  const removeFlashcard = (index) => {
    if (flashcards.length === 1) {
      toast({
        title: 'Cannot remove',
        description: 'You must have at least one flashcard',
        variant: 'destructive',
      });
      return;
    }
    setFlashcards(flashcards.filter((_, i) => i !== index));
  };

  const updateFlashcard = (index, field, value) => {
    const updated = [...flashcards];
    updated[index][field] = value;
    setFlashcards(updated);
  };

  const handleImageUpload = (index, side, file) => {
    if (!file) return;

    const reader = new FileReader();
    reader.onloadend = () => {
      updateFlashcard(index, `${side}Image`, reader.result);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      if (!targetCourse && !customCourse) {
        throw new Error('Please select or enter which course these flashcards are for');
      }

      if (!selectedSubject && !customSubject) {
        throw new Error('Please select or enter a subject');
      }

      for (let i = 0; i < flashcards.length; i++) {
        if (!flashcards[i].front.trim()) {
          throw new Error(`Flashcard ${i + 1}: Front side cannot be empty`);
        }
        if (!flashcards[i].back.trim()) {
          throw new Error(`Flashcard ${i + 1}: Back side cannot be empty`);
        }
      }

      const finalTargetCourse = customCourse || targetCourse;

      // ✅ FIX: Create a deck FIRST, then assign deck_id to flashcards
      const { data: deckData, error: deckError } = await supabase
        .from('flashcard_decks')
        .insert({
          user_id: user.id,
          subject_id: selectedSubject?.id || null,
          custom_subject: customSubject || null,
          topic_id: selectedTopic?.id || null,
          custom_topic: customTopic || null,
          target_course: finalTargetCourse,
          visibility: visibility,
          card_count: flashcards.length,
          upvote_count: 0
        })
        .select('id')
        .single();

      if (deckError) throw deckError;

      const deckId = deckData.id;

      // ✅ FIX: Now create flashcards WITH deck_id
      const flashcardsToInsert = flashcards.map(card => ({
        user_id: user.id,
        contributed_by: user.id,
        creator_id: user.id,
        content_creator_id: null,
        deck_id: deckId, // ✅ CRITICAL: Assign deck_id
        target_course: finalTargetCourse,
        subject_id: selectedSubject?.id || null,
        topic_id: selectedTopic?.id || null,
        custom_subject: customSubject || null,
        custom_topic: customTopic || null,
        front_text: card.front,
        back_text: card.back,
        front_image_url: card.frontImage || null,
        back_image_url: card.backImage || null,
        tags: tags ? tags.split(',').map(t => t.trim()).filter(Boolean) : [],
        visibility: visibility,
        is_public: visibility === 'public',
        is_verified: false,
        difficulty: 'medium',
        batch_id: crypto.randomUUID(),
        batch_description: null,
        next_review: new Date().toISOString(),
        interval: 1,
        ease_factor: 2.5,
        repetitions: 0
      }));

      const { error: insertError } = await supabase
        .from('flashcards')
        .insert(flashcardsToInsert);

      if (insertError) throw insertError;

      toast({
        title: 'Success!',
        description: `${flashcards.length} flashcard(s) created successfully`,
      });

      navigate('/dashboard');

    } catch (error) {
      console.error('Create error:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to create flashcards',
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
          <h1 className="text-3xl font-bold">Create Flashcards</h1>
          <p className="text-muted-foreground mt-2">
            Build your own flashcard collection
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          
          <Card>
            <CardHeader>
              <CardTitle>Who are these flashcards for?</CardTitle>
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
                  Select which students should see these flashcards
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

              <div className="space-y-2">
                <Label htmlFor="visibility">Who can see these flashcards?</Label>
                <Select value={visibility} onValueChange={setVisibility}>
                  <SelectTrigger id="visibility">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="private">Private (Only me)</SelectItem>
                    <SelectItem value="friends">Friends Only</SelectItem>
                    <SelectItem value="public">Public (Everyone)</SelectItem>
                  </SelectContent>
                </Select>
                <p className="text-sm text-muted-foreground">
                  {visibility === 'private' && 'Only you can see these flashcards'}
                  {visibility === 'friends' && 'Only your friends can see these flashcards'}
                  {visibility === 'public' && 'Everyone can see these flashcards'}
                </p>
              </div>
            </CardContent>
          </Card>

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
                      className="text-destructive hover:text-destructive"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                
                <div className="space-y-2">
                  <Label htmlFor={`front-${index}`}>Front</Label>
                  <Textarea
                    id={`front-${index}`}
                    value={card.front}
                    onChange={(e) => updateFlashcard(index, 'front', e.target.value)}
                    placeholder="Question or prompt"
                    rows={3}
                  />
                  
                  <div className="flex items-center gap-2">
                    <Label
                      htmlFor={`front-image-${index}`}
                      className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 border border-input rounded-lg hover:bg-accent"
                    >
                      <ImageIcon className="h-4 w-4" />
                      <span className="text-sm">Add Image</span>
                    </Label>
                    <input
                      id={`front-image-${index}`}
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleImageUpload(index, 'front', e.target.files?.[0])}
                      className="hidden"
                    />
                  </div>
                  {card.frontImage && (
                    <img src={card.frontImage} alt="Front" className="mt-2 max-h-32 rounded-lg" />
                  )}
                </div>

                <div className="space-y-2">
                  <Label htmlFor={`back-${index}`}>Back</Label>
                  <Textarea
                    id={`back-${index}`}
                    value={card.back}
                    onChange={(e) => updateFlashcard(index, 'back', e.target.value)}
                    placeholder="Answer or explanation"
                    rows={3}
                  />
                  
                  <div className="flex items-center gap-2">
                    <Label
                      htmlFor={`back-image-${index}`}
                      className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 border border-input rounded-lg hover:bg-accent"
                    >
                      <ImageIcon className="h-4 w-4" />
                      <span className="text-sm">Add Image</span>
                    </Label>
                    <input
                      id={`back-image-${index}`}
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleImageUpload(index, 'back', e.target.files?.[0])}
                      className="hidden"
                    />
                  </div>
                  {card.backImage && (
                    <img src={card.backImage} alt="Back" className="mt-2 max-h-32 rounded-lg" />
                  )}
                </div>
              </CardContent>
            </Card>
          ))}

          <Button
            type="button"
            variant="outline"
            onClick={addFlashcard}
            className="w-full border-dashed"
          >
            <Plus className="mr-2 h-4 w-4" />
            Add Another Flashcard
          </Button>

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
              {loading ? 'Creating...' : `Create ${flashcards.length} Flashcard${flashcards.length > 1 ? 's' : ''}`}
            </Button>
          </div>
        </form>

        <Card className="bg-blue-50 border-blue-200">
          <CardContent className="pt-6">
            <p className="text-sm text-blue-800">
              💡 <strong>Pro Tip:</strong> Need to create many flashcards?{' '}
              <Button
                variant="link"
                className="h-auto p-0 text-blue-600 hover:text-blue-700"
                onClick={() => navigate('/professor/tools')}
              >
                Try Bulk Upload
              </Button>
              {' '}to upload via CSV
            </p>
          </CardContent>
        </Card>
      </div>
      </div>
    </div>
  );
}
