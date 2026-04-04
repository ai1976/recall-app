import { useState, useEffect } from 'react';
import { useNavigate, useBlocker } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { ArrowLeft, Plus, Trash2, X, Image as ImageIcon, Check, ChevronsUpDown } from 'lucide-react';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from '@/components/ui/command';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { notifyContentCreated } from '@/lib/notifyEdge';
import imageCompression from 'browser-image-compression';

const DRAFT_KEY = 'flashcard_create_draft';

function formatDraftTime(isoString) {
  const saved = new Date(isoString);
  const diffMins = Math.floor((Date.now() - saved) / 60000);
  if (diffMins < 1) return 'just now';
  if (diffMins < 60) return `${diffMins} minute${diffMins !== 1 ? 's' : ''} ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
  return saved.toLocaleDateString();
}

export default function FlashcardCreate() {
  const navigate = useNavigate();
  const { toast } = useToast();

  const [targetCourse, setTargetCourse] = useState('');
  const [showCustomCourse, setShowCustomCourse] = useState(false);
  const [customCourse, setCustomCourse] = useState('');
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
  const [visibility, setVisibility] = useState('private');
  const [userGroups, setUserGroups] = useState([]);
  const [selectedGroupIds, setSelectedGroupIds] = useState([]);

  const [flashcards, setFlashcards] = useState([
    { front: '', back: '', frontImageUrl: null, frontImagePreview: null, backImageUrl: null, backImagePreview: null }
  ]);

  const [loading, setLoading] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(null); // { index, side } | null
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  // Draft recovery state
  const [pendingDraft, setPendingDraft] = useState(null);

  // True when the user has entered card content or added extra cards
  const isDirty = flashcards.some(c => c.front.trim() || c.back.trim()) || flashcards.length > 1;

  // Intercept in-app navigation (Back button, Cancel, browser back) when dirty
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      isDirty && currentLocation.pathname !== nextLocation.pathname
  );

  // Intercept tab close / page reload when dirty
  useEffect(() => {
    const handler = (e) => {
      if (isDirty) {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [isDirty]);

  // Autosave card content to localStorage (1s debounce)
  useEffect(() => {
    if (!isDirty) return;
    const timer = setTimeout(() => {
      try {
        localStorage.setItem(DRAFT_KEY, JSON.stringify({
          savedAt: new Date().toISOString(),
          flashcards: flashcards.map(c => ({
            front: c.front,
            back: c.back,
            frontImageUrl: c.frontImageUrl || null,
            backImageUrl: c.backImageUrl || null,
          })),
        }));
      } catch (err) {
        // Fails silently — common in Safari Private Browsing or when storage is full.
        // The navigation guard (useBlocker) still protects the user's work.
        console.warn('Could not autosave draft to localStorage:', err);
      }
    }, 1000);
    return () => clearTimeout(timer);
  }, [flashcards, isDirty]);

  // On mount: check for a saved draft and surface it
  useEffect(() => {
    const saved = localStorage.getItem(DRAFT_KEY);
    if (!saved) return;
    try {
      const parsed = JSON.parse(saved);
      if (parsed.flashcards?.some(c => c.front?.trim() || c.back?.trim())) {
        setPendingDraft(parsed);
      }
    } catch {
      localStorage.removeItem(DRAFT_KEY);
    }
  }, []);

  useEffect(() => {
    fetchDisciplines();
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
    // Reset subject & topic (and any stale custom text) when course changes
    setSelectedSubject(null);
    setSelectedTopic(null);
    setTopics([]);
    setShowCustomSubject(false);
    setCustomSubject('');
    setShowCustomTopic(false);
    setCustomTopic('');
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
      { front: '', back: '', frontImageUrl: null, frontImagePreview: null, backImageUrl: null, backImagePreview: null }
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
    const card = flashcards[index];
    if (card.frontImagePreview && card.frontImagePreview !== card.frontImageUrl) URL.revokeObjectURL(card.frontImagePreview);
    if (card.backImagePreview && card.backImagePreview !== card.backImageUrl) URL.revokeObjectURL(card.backImagePreview);
    setFlashcards(flashcards.filter((_, i) => i !== index));
  };

  const updateFlashcard = (index, field, value) => {
    const updated = [...flashcards];
    updated[index][field] = value;
    setFlashcards(updated);
  };

  const handleImageUpload = async (index, side, file) => {
    if (!file) return;
    setUploadingImage({ index, side });
    try {
      const compressionOptions = { maxSizeMB: 0.2, maxWidthOrHeight: 1200, useWebWorker: true };
      const compressedBlob = await imageCompression(file, compressionOptions);
      const ext = compressedBlob.type.split('/')[1] || 'jpg';
      const compressedFile = new File([compressedBlob], `${Date.now()}.${ext}`, { type: compressedBlob.type });

      const { data: { user } } = await supabase.auth.getUser();
      const fileName = `${user.id}/${Date.now()}-${side}-${index}.${ext}`;

      const { error: uploadError } = await supabase.storage
        .from('flashcard-images')
        .upload(fileName, compressedFile);
      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('flashcard-images')
        .getPublicUrl(fileName);

      const preview = URL.createObjectURL(compressedFile);
      const updated = [...flashcards];
      // Revoke old preview only if it's a blob URL, not a stored Supabase URL
      const oldPreview = updated[index][`${side}ImagePreview`];
      if (oldPreview && oldPreview !== updated[index][`${side}ImageUrl`]) URL.revokeObjectURL(oldPreview);
      updated[index][`${side}ImageUrl`] = publicUrl;
      updated[index][`${side}ImagePreview`] = preview;
      setFlashcards(updated);
    } catch (err) {
      console.error('Image upload failed:', err);
      toast({
        title: 'Image upload failed',
        description: err.message || 'Could not upload image. Please try again.',
        variant: 'destructive',
      });
    } finally {
      setUploadingImage(null);
    }
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

      // Derive isSystemCourse inside submit (disciplines already loaded)
      const _isSystemCourse = !showCustomCourse &&
        disciplines.some(d => d.name.toLowerCase() === (targetCourse || '').toLowerCase());

      let subjectId, customSubjectValue, topicId, customTopicValue;

      if (_isSystemCourse) {
        if (!selectedSubject) throw new Error('Please select a subject from the official syllabus');
        if (!selectedTopic)   throw new Error('Please select a topic from the official syllabus');
        subjectId          = selectedSubject.id;
        customSubjectValue = null;
        topicId            = selectedTopic.id;
        customTopicValue   = null;
      } else {
        if (!customSubject.trim()) throw new Error('Please enter a subject name');
        subjectId          = null;
        customSubjectValue = customSubject.trim();
        topicId            = null;
        customTopicValue   = customTopic.trim() || null;
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

      // Build query to find existing deck
      let existingDeckQuery = supabase
        .from('flashcard_decks')
        .select('id')
        .eq('user_id', user.id);

      // Handle NULL comparisons correctly (Supabase uses .is() for NULL)
      if (subjectId) {
        existingDeckQuery = existingDeckQuery.eq('subject_id', subjectId);
      } else {
        existingDeckQuery = existingDeckQuery.is('subject_id', null);
      }

      if (topicId) {
        existingDeckQuery = existingDeckQuery.eq('topic_id', topicId);
      } else {
        existingDeckQuery = existingDeckQuery.is('topic_id', null);
      }

      if (customSubjectValue) {
        existingDeckQuery = existingDeckQuery.eq('custom_subject', customSubjectValue);
      } else {
        existingDeckQuery = existingDeckQuery.is('custom_subject', null);
      }

      if (customTopicValue) {
        existingDeckQuery = existingDeckQuery.eq('custom_topic', customTopicValue);
      } else {
        existingDeckQuery = existingDeckQuery.is('custom_topic', null);
      }

      const { data: existingDeck, error: findError } = await existingDeckQuery.maybeSingle();

      if (findError) {
        console.error('Error checking for existing deck:', findError);
        // Continue to create new deck if lookup fails
      }

      let deckId;

      if (existingDeck) {
        // ✅ REUSE existing deck (card_count maintained by DB trigger)
        deckId = existingDeck.id;
        console.log('♻️ Reusing existing deck:', deckId);

        // Update updated_at only — card_count is auto-incremented by trigger
        await supabase
          .from('flashcard_decks')
          .update({
            updated_at: new Date().toISOString()
          })
          .eq('id', deckId);

      } else {
        // For study_groups visibility, store as 'private' in DB
        const dbVisibility = visibility === 'study_groups' ? 'private' : visibility;

        // ✅ CREATE new deck
        const { data: newDeck, error: deckError } = await supabase
          .from('flashcard_decks')
          .insert({
            user_id: user.id,
            subject_id: subjectId,
            custom_subject: customSubjectValue,
            topic_id: topicId,
            custom_topic: customTopicValue,
            target_course: finalTargetCourse,
            visibility: dbVisibility,
            card_count: 0, // auto-incremented by DB trigger on flashcard insert
            upvote_count: 0
          })
          .select('id')
          .single();

        if (deckError) throw deckError;

        deckId = newDeck.id;
        console.log('🆕 Created new deck:', deckId);
      }

      // For study_groups visibility, store as 'private' in individual cards too
      const cardVisibility = visibility === 'study_groups' ? 'private' : visibility;

      // ✅ Create flashcards WITH deck_id
      const flashcardsToInsert = flashcards.map(card => ({
        user_id: user.id,
        contributed_by: user.id,
        creator_id: user.id,
        content_creator_id: null,
        deck_id: deckId,
        target_course: finalTargetCourse,
        subject_id: subjectId,
        topic_id: topicId,
        custom_subject: customSubjectValue,
        custom_topic: customTopicValue,
        front_text: card.front,
        back_text: card.back,
        front_image_url: card.frontImageUrl || null,
        back_image_url: card.backImageUrl || null,
        tags: tags ? tags.split(',').map(t => t.trim()).filter(Boolean) : [],
        visibility: cardVisibility,
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

      // Share deck with selected study groups
      if (visibility === 'study_groups' && selectedGroupIds.length > 0 && deckId) {
        const { error: shareError } = await supabase.rpc('share_content_with_groups', {
          p_content_type: 'flashcard_deck',
          p_content_id: deckId,
          p_group_ids: selectedGroupIds,
        });
        if (shareError) console.error('Error sharing with groups:', shareError);
      }

      // Clear saved draft on successful save
      localStorage.removeItem(DRAFT_KEY);

      toast({
        title: 'Success!',
        description: visibility === 'study_groups'
          ? `${flashcards.length} flashcard(s) created and shared with ${selectedGroupIds.length} group(s)`
          : `${flashcards.length} flashcard(s) created successfully`,
      });

      // Fire-and-forget push notification — never blocks the create flow
      if (['public', 'friends'].includes(cardVisibility)) {
        notifyContentCreated({
          content_type: 'flashcard_deck',
          content_id: deckId,
          creator_id: user.id,
          title: selectedSubject?.name || customSubject || 'Study Set',
          subject_name: selectedSubject?.name || customSubject || null,
          visibility: cardVisibility,
          target_course: finalTargetCourse,
        });
      }

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

  const restoreDraft = () => {
    setFlashcards(pendingDraft.flashcards.map(c => ({
      front: c.front || '',
      back: c.back || '',
      frontImageUrl: c.frontImageUrl || null,
      frontImagePreview: c.frontImageUrl || null, // use stored Supabase URL directly as preview
      backImageUrl: c.backImageUrl || null,
      backImagePreview: c.backImageUrl || null,
    })));
    setPendingDraft(null);
    toast({
      title: 'Draft restored',
      description: `${pendingDraft.flashcards.length} item${pendingDraft.flashcards.length !== 1 ? 's' : ''} recovered from your last session`,
    });
  };

  const discardDraft = () => {
    localStorage.removeItem(DRAFT_KEY);
    setPendingDraft(null);
  };

  const isSystemCourse = !showCustomCourse &&
    disciplines.some(d => d.name.toLowerCase() === (targetCourse || '').toLowerCase());

  const unsavedCount = flashcards.filter(c => c.front.trim() || c.back.trim()).length;

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

        {/* Draft recovery banner */}
        {pendingDraft && (
          <Card className="border-amber-300 bg-amber-50">
            <CardContent className="pt-4 pb-4 flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
              <div>
                <p className="text-sm font-medium text-amber-900">
                  You have {pendingDraft.flashcards.length} unsaved item{pendingDraft.flashcards.length !== 1 ? 's' : ''} from a previous session
                </p>
                <p className="text-xs text-amber-700 mt-0.5">
                  Auto-saved {formatDraftTime(pendingDraft.savedAt)}
                </p>
              </div>
              <div className="flex gap-2 shrink-0">
                <Button size="sm" variant="outline" onClick={discardDraft} className="border-amber-300 hover:bg-amber-100">
                  Discard
                </Button>
                <Button size="sm" onClick={restoreDraft} className="bg-amber-600 hover:bg-amber-700 text-white">
                  Restore
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">

          <Card>
            <CardHeader>
              <CardTitle>Who are these flashcards for?</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <Label htmlFor="target-course">Target Course <span className="text-red-500">*</span></Label>
                {!showCustomCourse ? (
                  <>
                    <Select value={targetCourse} onValueChange={setTargetCourse} required={!showCustomCourse}>
                      <SelectTrigger id="target-course">
                        <SelectValue placeholder="Select course..." />
                      </SelectTrigger>
                      <SelectContent>
                        {disciplines.map((d) => (
                          <SelectItem key={d.id} value={d.name}>
                            {d.name}
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

              {/* Subject — FK dropdown for system courses, free text for custom courses */}
              {isSystemCourse ? (
                <div className="space-y-2">
                  <Label>Subject <span className="text-red-500">*</span></Label>
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
                        </CommandGroup>
                      </Command>
                    </PopoverContent>
                  </Popover>
                  <p className="text-xs text-muted-foreground">
                    Subject must match the official syllabus. Can't find yours?{' '}
                    <button
                      type="button"
                      className="text-blue-600 hover:underline"
                      onClick={() => { setShowCustomCourse(true); setTargetCourse(''); }}
                    >
                      Switch to custom course →
                    </button>
                  </p>
                </div>
              ) : (
                <div className="space-y-2">
                  <Label htmlFor="custom-subject">Subject <span className="text-red-500">*</span></Label>
                  <Input
                    id="custom-subject"
                    value={customSubject}
                    onChange={(e) => setCustomSubject(e.target.value)}
                    placeholder="Enter subject name"
                  />
                </div>
              )}

              {/* Topic — FK dropdown for system courses, free text for custom courses */}
              {isSystemCourse ? (
                <div className="space-y-2">
                  <Label>Topic <span className="text-red-500">*</span></Label>
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
                        </CommandGroup>
                      </Command>
                    </PopoverContent>
                  </Popover>
                </div>
              ) : (
                <div className="space-y-2">
                  <Label htmlFor="custom-topic">Topic (Optional)</Label>
                  <Input
                    id="custom-topic"
                    value={customTopic}
                    onChange={(e) => setCustomTopic(e.target.value)}
                    placeholder="Enter topic name (optional)"
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
                  {visibility === 'private' && 'Only you can see these flashcards'}
                  {visibility === 'study_groups' && 'Share with selected study groups'}
                  {visibility === 'friends' && 'Only your friends can see these flashcards'}
                  {visibility === 'public' && 'Everyone can see these flashcards'}
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
                    {uploadingImage?.index === index && uploadingImage?.side === 'front' ? (
                      <div className="inline-flex items-center gap-2 px-4 py-2 border border-input rounded-lg opacity-75 cursor-wait">
                        <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-primary" />
                        <span className="text-sm">Uploading…</span>
                      </div>
                    ) : (
                      <Label
                        htmlFor={`front-image-${index}`}
                        className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 border border-input rounded-lg hover:bg-accent"
                      >
                        <ImageIcon className="h-4 w-4" />
                        <span className="text-sm">{card.frontImageUrl ? 'Change Image' : 'Add Image'}</span>
                      </Label>
                    )}
                    <input
                      id={`front-image-${index}`}
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleImageUpload(index, 'front', e.target.files?.[0])}
                      className="hidden"
                    />
                  </div>
                  {card.frontImagePreview && (
                    <div className="relative inline-block mt-2">
                      <img src={card.frontImagePreview} alt="Front" className="max-h-32 rounded-lg" />
                      <button
                        type="button"
                        onClick={() => {
                          if (card.frontImagePreview !== card.frontImageUrl) URL.revokeObjectURL(card.frontImagePreview);
                          const updated = [...flashcards];
                          updated[index].frontImageUrl = null;
                          updated[index].frontImagePreview = null;
                          setFlashcards(updated);
                        }}
                        className="absolute -top-2 -right-2 bg-destructive text-destructive-foreground rounded-full p-0.5 shadow"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
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
                    {uploadingImage?.index === index && uploadingImage?.side === 'back' ? (
                      <div className="inline-flex items-center gap-2 px-4 py-2 border border-input rounded-lg opacity-75 cursor-wait">
                        <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-primary" />
                        <span className="text-sm">Uploading…</span>
                      </div>
                    ) : (
                      <Label
                        htmlFor={`back-image-${index}`}
                        className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 border border-input rounded-lg hover:bg-accent"
                      >
                        <ImageIcon className="h-4 w-4" />
                        <span className="text-sm">{card.backImageUrl ? 'Change Image' : 'Add Image'}</span>
                      </Label>
                    )}
                    <input
                      id={`back-image-${index}`}
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleImageUpload(index, 'back', e.target.files?.[0])}
                      className="hidden"
                    />
                  </div>
                  {card.backImagePreview && (
                    <div className="relative inline-block mt-2">
                      <img src={card.backImagePreview} alt="Back" className="max-h-32 rounded-lg" />
                      <button
                        type="button"
                        onClick={() => {
                          if (card.backImagePreview !== card.backImageUrl) URL.revokeObjectURL(card.backImagePreview);
                          const updated = [...flashcards];
                          updated[index].backImageUrl = null;
                          updated[index].backImagePreview = null;
                          setFlashcards(updated);
                        }}
                        className="absolute -top-2 -right-2 bg-destructive text-destructive-foreground rounded-full p-0.5 shadow"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
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
              💡 <strong>Pro Tip:</strong> Your items are auto-saved as you type — if you accidentally leave this page, you can restore your work when you come back. Need to create many flashcards at once?{' '}
              <Button
                variant="link"
                className="h-auto p-0 text-blue-600 hover:text-blue-700"
                onClick={() => navigate('/dashboard/bulk-upload')}
              >
                Try Bulk Upload
              </Button>
              {' '}to upload via CSV.
            </p>
          </CardContent>
        </Card>
      </div>
      </div>

      {/* Navigation guard: shown when user tries to leave with unsaved cards */}
      {blocker.state === 'blocked' && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <Card className="max-w-sm w-full shadow-xl">
            <CardHeader>
              <CardTitle>Leave without saving?</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-muted-foreground">
                You have {unsavedCount} unsaved item{unsavedCount !== 1 ? 's' : ''}.
                Your work will be lost if you leave now.
              </p>
              <div className="flex gap-3">
                <Button
                  variant="outline"
                  className="flex-1"
                  onClick={() => blocker.reset()}
                >
                  Keep editing
                </Button>
                <Button
                  variant="destructive"
                  className="flex-1"
                  onClick={() => {
                    localStorage.removeItem(DRAFT_KEY);
                    blocker.proceed();
                  }}
                >
                  Leave anyway
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
