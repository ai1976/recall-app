import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/contexts/NavDataContext';
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
import {
  MCQ_MIN_OPTIONS,
  MCQ_MAX_OPTIONS,
  MCQ_DEFAULT_OPTIONS,
  compactMcqOptions,
  deriveMcqBackText,
  toPointsToRemember,
  validateMcqOptions,
} from '@/lib/mcq';
import {
  MATCH_MIN_PAIRS,
  MATCH_MAX_PAIRS,
  MATCH_DEFAULT_PAIRS,
  keyForRightIndex,
  buildMatchOptions,
  deriveMatchBackText,
  validateMatchPairs,
} from '@/lib/matchTheFollowing';
import {
  CASE_MIN_QUESTIONS,
  CASE_MAX_QUESTIONS,
  CASE_DEFAULT_QUESTIONS,
  emptyCaseQuestion,
  validateCaseStudy,
} from '@/lib/caseStudyMcq';
import {
  FITB_MAX_ANSWERS,
  FITB_BLANK_PLACEHOLDER,
  compactFitbOptions,
  deriveFitbBackText,
  validateFitbBlank,
  validateFitbOptions,
} from '@/lib/fitb';
import {
  CONCEPT_MAX_TERMS,
  emptyConceptTerm,
  emptyConceptTerms,
  buildConceptOptions,
  validateConceptTerms,
} from '@/lib/conceptCard';
import { GRADED_QUESTION_TYPES, VERDICT_OPTION_LABELS, THEORY_SUBTYPE_LABELS, formatQuestionType } from '@/lib/questionTypes';

const emptyMcqOptions = () => Array.from({ length: MCQ_DEFAULT_OPTIONS }, () => '');
const emptyMatchLeft = () => Array.from({ length: MATCH_DEFAULT_PAIRS }, () => '');
const emptyMatchRight = () => Array.from({ length: MATCH_DEFAULT_PAIRS }, () => '');
const emptyMatchCorrect = () => Array.from({ length: MATCH_DEFAULT_PAIRS }, () => null);
const emptyCaseQuestions = () => Array.from({ length: CASE_DEFAULT_QUESTIONS }, () => emptyCaseQuestion(MCQ_DEFAULT_OPTIONS));
const emptyFitbOptions = () => [''];
// D-10-gated types that need a role check on draft restore (a role could have
// changed since the draft was saved) — GRADED_QUESTION_TYPES alone would miss
// match_the_following and fitb, since both render through their own StudyMode
// branch, not the shared AnswerOption list.
const isD10GatedType = (qt) => GRADED_QUESTION_TYPES.includes(qt) || qt === 'match_the_following' || qt === 'fitb';

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
  const { isProfessor, isAdmin, isSuperAdmin } = useRole();
  // D-10 (Phase 7): only professor/admin/super_admin may author verdict-bearing
  // question types (mcq, correct_incorrect et al). The question-type
  // selector itself is shown to everyone (theory/flashcard/concept_card are
  // free-recall types open to all users) — only the graded-type options within it are
  // hidden from students. This is a UX nicety only; the real boundary is the
  // flashcards_gate_verdict_types RLS policy — see docs/database/sprint7.5.
  const canAuthorGradedTypes = isProfessor || isAdmin || isSuperAdmin;

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
    {
      front: '', back: '', frontImageUrl: null, frontImagePreview: null, backImageUrl: null, backImagePreview: null,
      questionType: 'flashcard', options: emptyMcqOptions(), correctOptionIndex: null,
      matchLeft: emptyMatchLeft(), matchRight: emptyMatchRight(), matchCorrect: emptyMatchCorrect(), why: '',
      subtype: null, caseScenario: '', caseQuestions: emptyCaseQuestions(), fitbOptions: emptyFitbOptions(),
      conceptTerms: emptyConceptTerms(),
    }
  ]);

  const [loading, setLoading] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(null); // { index, side } | null
  const [subjectOpen, setSubjectOpen] = useState(false);
  const [topicOpen, setTopicOpen] = useState(false);

  // Draft recovery state
  const [pendingDraft, setPendingDraft] = useState(null);

  // Leave-confirmation dialog (replaces useBlocker — app uses <BrowserRouter>, not a data router)
  const [showLeaveDialog, setShowLeaveDialog] = useState(false);

  // True when the user has entered card content or added extra cards
  const isDirty = flashcards.some(c =>
    c.front.trim() || c.back.trim() ||
    c.caseScenario?.trim() || c.caseQuestions?.some(q => q.front.trim())
  ) || flashcards.length > 1;

  // Intercept browser back button when dirty via popstate
  useEffect(() => {
    if (!isDirty) return;
    // Push current URL so we can catch the back gesture
    window.history.pushState(null, '', window.location.pathname);
    const handlePopState = () => {
      // Push again to stay on the page, then show the dialog
      window.history.pushState(null, '', window.location.pathname);
      setShowLeaveDialog(true);
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, [isDirty]);

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
            questionType: c.questionType || 'flashcard',
            options: c.options || emptyMcqOptions(),
            correctOptionIndex: c.correctOptionIndex ?? null,
            matchLeft: c.matchLeft || emptyMatchLeft(),
            matchRight: c.matchRight || emptyMatchRight(),
            matchCorrect: c.matchCorrect || emptyMatchCorrect(),
            why: c.why || '',
            subtype: c.subtype || null,
            caseScenario: c.caseScenario || '',
            caseQuestions: c.caseQuestions || emptyCaseQuestions(),
            fitbOptions: c.fitbOptions || emptyFitbOptions(),
            conceptTerms: c.conceptTerms || emptyConceptTerms(),
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
      {
        front: '', back: '', frontImageUrl: null, frontImagePreview: null, backImageUrl: null, backImagePreview: null,
        questionType: 'flashcard', options: emptyMcqOptions(), correctOptionIndex: null,
        matchLeft: emptyMatchLeft(), matchRight: emptyMatchRight(), matchCorrect: emptyMatchCorrect(), why: '',
        subtype: null, caseScenario: '', caseQuestions: emptyCaseQuestions(), fitbOptions: emptyFitbOptions(),
        conceptTerms: emptyConceptTerms(),
      }
    ]);
  };

  // concept_card (Sprint 7.12) — key-terms list editor, mirrors updateFitbOption/
  // addFitbOption/removeFitbOption above but each row is a {term, definition} pair.
  const updateConceptTerm = (cardIndex, termIndex, field, value) => {
    const updated = [...flashcards];
    const conceptTerms = [...updated[cardIndex].conceptTerms];
    conceptTerms[termIndex] = { ...conceptTerms[termIndex], [field]: value };
    updated[cardIndex] = { ...updated[cardIndex], conceptTerms };
    setFlashcards(updated);
  };

  const addConceptTerm = (cardIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.conceptTerms.length >= CONCEPT_MAX_TERMS) return;
    updated[cardIndex] = { ...card, conceptTerms: [...card.conceptTerms, emptyConceptTerm()] };
    setFlashcards(updated);
  };

  const removeConceptTerm = (cardIndex, termIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.conceptTerms.length <= 1) return;
    updated[cardIndex] = { ...card, conceptTerms: card.conceptTerms.filter((_, i) => i !== termIndex) };
    setFlashcards(updated);
  };

  // fitb (Sprint 7.11) — acceptable-answers list editor, mirrors updateMcqOption/
  // addMcqOption/removeMcqOption above but with no "correct index" to track.
  const updateFitbOption = (cardIndex, optionIndex, value) => {
    const updated = [...flashcards];
    const fitbOptions = [...updated[cardIndex].fitbOptions];
    fitbOptions[optionIndex] = value;
    updated[cardIndex] = { ...updated[cardIndex], fitbOptions };
    setFlashcards(updated);
  };

  const addFitbOption = (cardIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.fitbOptions.length >= FITB_MAX_ANSWERS) return;
    updated[cardIndex] = { ...card, fitbOptions: [...card.fitbOptions, ''] };
    setFlashcards(updated);
  };

  const removeFitbOption = (cardIndex, optionIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.fitbOptions.length <= 1) return;
    updated[cardIndex] = { ...card, fitbOptions: card.fitbOptions.filter((_, i) => i !== optionIndex) };
    setFlashcards(updated);
  };

  const updateMcqOption = (cardIndex, optionIndex, value) => {
    const updated = [...flashcards];
    const options = [...updated[cardIndex].options];
    options[optionIndex] = value;
    updated[cardIndex] = { ...updated[cardIndex], options };
    setFlashcards(updated);
  };

  const addMcqOption = (cardIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.options.length >= MCQ_MAX_OPTIONS) return;
    updated[cardIndex] = { ...card, options: [...card.options, ''] };
    setFlashcards(updated);
  };

  const removeMcqOption = (cardIndex, optionIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.options.length <= MCQ_MIN_OPTIONS) return;
    const options = card.options.filter((_, i) => i !== optionIndex);
    let correctOptionIndex = card.correctOptionIndex;
    if (correctOptionIndex === optionIndex) correctOptionIndex = null;
    else if (correctOptionIndex > optionIndex) correctOptionIndex -= 1;
    updated[cardIndex] = { ...card, options, correctOptionIndex };
    setFlashcards(updated);
  };

  // match_the_following (Sprint 7.8) — left/right lists are edited independently
  // (unlike mcq's single options array), so removing a right item must also
  // clear or reindex any correct-mapping entries that pointed at it.
  const updateMatchItem = (cardIndex, field, itemIndex, value) => {
    const updated = [...flashcards];
    const list = [...updated[cardIndex][field]];
    list[itemIndex] = value;
    updated[cardIndex] = { ...updated[cardIndex], [field]: list };
    setFlashcards(updated);
  };

  const addMatchLeft = (cardIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.matchLeft.length >= MATCH_MAX_PAIRS) return;
    updated[cardIndex] = { ...card, matchLeft: [...card.matchLeft, ''], matchCorrect: [...card.matchCorrect, null] };
    setFlashcards(updated);
  };

  const removeMatchLeft = (cardIndex, leftIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.matchLeft.length <= MATCH_MIN_PAIRS) return;
    updated[cardIndex] = {
      ...card,
      matchLeft: card.matchLeft.filter((_, i) => i !== leftIndex),
      matchCorrect: card.matchCorrect.filter((_, i) => i !== leftIndex),
    };
    setFlashcards(updated);
  };

  const addMatchRight = (cardIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.matchRight.length >= MATCH_MAX_PAIRS) return;
    updated[cardIndex] = { ...card, matchRight: [...card.matchRight, ''] };
    setFlashcards(updated);
  };

  const removeMatchRight = (cardIndex, rightIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.matchRight.length <= MATCH_MIN_PAIRS) return;
    const matchRight = card.matchRight.filter((_, i) => i !== rightIndex);
    // Any left item mapped to the removed right item becomes unmapped; mappings
    // pointing past it shift down by one to track the new (post-removal) indices.
    const matchCorrect = card.matchCorrect.map((ri) => {
      if (ri === rightIndex) return null;
      if (ri !== null && ri !== undefined && ri > rightIndex) return ri - 1;
      return ri;
    });
    updated[cardIndex] = { ...card, matchRight, matchCorrect };
    setFlashcards(updated);
  };

  const updateMatchCorrect = (cardIndex, leftIndex, rightIndexOrNull) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    const matchCorrect = [...card.matchCorrect];
    matchCorrect[leftIndex] = rightIndexOrNull;
    updated[cardIndex] = { ...card, matchCorrect };
    setFlashcards(updated);
  };

  // case_study_mcq (Sprint 7.10) — one shared scenario + N independent
  // mcq-shaped question blocks. Each question block gets its own options
  // editor, mirroring updateMcqOption/addMcqOption/removeMcqOption above but
  // nested one level deeper (card -> caseQuestions[qIndex] -> options).
  const updateCaseScenario = (cardIndex, value) => {
    const updated = [...flashcards];
    updated[cardIndex] = { ...updated[cardIndex], caseScenario: value };
    setFlashcards(updated);
  };

  const addCaseQuestion = (cardIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.caseQuestions.length >= CASE_MAX_QUESTIONS) return;
    updated[cardIndex] = { ...card, caseQuestions: [...card.caseQuestions, emptyCaseQuestion(MCQ_DEFAULT_OPTIONS)] };
    setFlashcards(updated);
  };

  const removeCaseQuestion = (cardIndex, qIndex) => {
    const updated = [...flashcards];
    const card = updated[cardIndex];
    if (card.caseQuestions.length <= CASE_MIN_QUESTIONS) return;
    updated[cardIndex] = { ...card, caseQuestions: card.caseQuestions.filter((_, i) => i !== qIndex) };
    setFlashcards(updated);
  };

  const updateCaseQuestionField = (cardIndex, qIndex, field, value) => {
    const updated = [...flashcards];
    const questions = [...updated[cardIndex].caseQuestions];
    questions[qIndex] = { ...questions[qIndex], [field]: value };
    updated[cardIndex] = { ...updated[cardIndex], caseQuestions: questions };
    setFlashcards(updated);
  };

  const updateCaseQuestionOption = (cardIndex, qIndex, optIndex, value) => {
    const updated = [...flashcards];
    const questions = [...updated[cardIndex].caseQuestions];
    const options = [...questions[qIndex].options];
    options[optIndex] = value;
    questions[qIndex] = { ...questions[qIndex], options };
    updated[cardIndex] = { ...updated[cardIndex], caseQuestions: questions };
    setFlashcards(updated);
  };

  const addCaseQuestionOption = (cardIndex, qIndex) => {
    const updated = [...flashcards];
    const questions = [...updated[cardIndex].caseQuestions];
    const q = questions[qIndex];
    if (q.options.length >= MCQ_MAX_OPTIONS) return;
    questions[qIndex] = { ...q, options: [...q.options, ''] };
    updated[cardIndex] = { ...updated[cardIndex], caseQuestions: questions };
    setFlashcards(updated);
  };

  const removeCaseQuestionOption = (cardIndex, qIndex, optIndex) => {
    const updated = [...flashcards];
    const questions = [...updated[cardIndex].caseQuestions];
    const q = questions[qIndex];
    if (q.options.length <= MCQ_MIN_OPTIONS) return;
    const options = q.options.filter((_, i) => i !== optIndex);
    let correctOptionIndex = q.correctOptionIndex;
    if (correctOptionIndex === optIndex) correctOptionIndex = null;
    else if (correctOptionIndex > optIndex) correctOptionIndex -= 1;
    questions[qIndex] = { ...q, options, correctOptionIndex };
    updated[cardIndex] = { ...updated[cardIndex], caseQuestions: questions };
    setFlashcards(updated);
  };

  const removeFlashcard = (index) => {
    if (flashcards.length === 1) {
      toast({
        title: 'Cannot remove',
        description: 'You must have at least one item',
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
        throw new Error('Please select or enter which course these study items are for');
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
        const card = flashcards[i];
        if (card.questionType === 'case_study_mcq') {
          const caseError = validateCaseStudy(card.caseScenario, card.caseQuestions);
          if (caseError) throw new Error(`Item ${i + 1}: ${caseError}`);
          continue;
        }
        if (!card.front.trim()) {
          throw new Error(`Item ${i + 1}: Front side cannot be empty`);
        }
        if (card.questionType === 'mcq') {
          const mcqError = validateMcqOptions(card.options, card.correctOptionIndex);
          if (mcqError) throw new Error(`Item ${i + 1}: ${mcqError}`);
        } else if (card.questionType === 'correct_incorrect') {
          if (card.correctOptionIndex !== 0 && card.correctOptionIndex !== 1) {
            throw new Error(`Item ${i + 1}: Mark which side is correct`);
          }
        } else if (card.questionType === 'match_the_following') {
          const matchError = validateMatchPairs(card.matchLeft, card.matchRight, card.matchCorrect);
          if (matchError) throw new Error(`Item ${i + 1}: ${matchError}`);
        } else if (card.questionType === 'fitb') {
          const blankError = validateFitbBlank(card.front);
          if (blankError) throw new Error(`Item ${i + 1}: ${blankError}`);
          const fitbError = validateFitbOptions(card.fitbOptions);
          if (fitbError) throw new Error(`Item ${i + 1}: ${fitbError}`);
        } else if (!card.back.trim()) {
          throw new Error(`Item ${i + 1}: Back side cannot be empty`);
        } else if (card.questionType === 'theory' && card.subtype !== 'pure_theory' && card.subtype !== 'descriptive_case_study') {
          throw new Error(`Item ${i + 1}: Choose a subtype for this theory item`);
        } else if (card.questionType === 'concept_card') {
          const conceptError = validateConceptTerms(card.conceptTerms);
          if (conceptError) throw new Error(`Item ${i + 1}: ${conceptError}`);
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

      // ✅ Create flashcards WITH deck_id — case_study_mcq fans one authoring
      // block out into N independent rows sharing one batch_id (D-01 grouping
      // pattern), each its own SRS card; every other type stays a 1:1 map.
      const flashcardsToInsert = flashcards.flatMap(card => {
        if (card.questionType === 'case_study_mcq') {
          const caseBatchId = crypto.randomUUID();
          const scenarioText = card.caseScenario.trim();
          return card.caseQuestions.map(q => {
            const { options, correctIndex } = compactMcqOptions(q.options, q.correctOptionIndex);
            return {
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
              front_text: q.front,
              back_text: deriveMcqBackText(options, correctIndex),
              front_image_url: null,
              back_image_url: null,
              tags: tags ? tags.split(',').map(t => t.trim()).filter(Boolean) : [],
              visibility: cardVisibility,
              is_verified: false,
              difficulty: 'medium',
              batch_id: caseBatchId,
              batch_description: null,
              question_type: 'case_study_mcq',
              options,
              correct_answer: String(correctIndex),
              points_to_remember: null,
              explanation: toPointsToRemember(q.why),
              subtype: null,
              scenario: scenarioText,
            };
          });
        }

        const isMcq = card.questionType === 'mcq';
        const isCorrectIncorrect = card.questionType === 'correct_incorrect';
        const isMatch = card.questionType === 'match_the_following';
        const isFitb = card.questionType === 'fitb';
        const isConceptCard = card.questionType === 'concept_card';

        let rowOptions = null;
        let rowCorrectAnswer = null;
        let rowBackText = card.back;
        let rowBackImageUrl = card.backImageUrl || null;

        if (isMcq) {
          const { options, correctIndex } = compactMcqOptions(card.options, card.correctOptionIndex);
          rowOptions = options;
          rowCorrectAnswer = String(correctIndex);
          rowBackText = deriveMcqBackText(options, correctIndex);
          rowBackImageUrl = null;
        } else if (isCorrectIncorrect) {
          rowOptions = VERDICT_OPTION_LABELS[card.questionType];
          rowCorrectAnswer = String(card.correctOptionIndex);
          rowBackText = deriveMcqBackText(rowOptions, card.correctOptionIndex);
          rowBackImageUrl = null;
        } else if (isMatch) {
          const trimmedLeft = card.matchLeft.map(s => s.trim());
          const trimmedRight = card.matchRight.map(s => s.trim());
          // correct_answer stays NULL for this type — the verdict comes from
          // options.correct, not a single scalar "the answer" (see D-10 rep. note).
          rowOptions = buildMatchOptions(trimmedLeft, trimmedRight, card.matchCorrect);
          rowBackText = deriveMatchBackText(trimmedLeft, rowOptions.correct);
          rowBackImageUrl = null;
        } else if (isFitb) {
          // correct_answer stays NULL for this type too (D-13) — the verdict is
          // computed at grading time by normalizing against every options entry,
          // not read off a single stored scalar.
          const fitbOpts = compactFitbOptions(card.fitbOptions);
          rowOptions = fitbOpts;
          rowBackText = deriveFitbBackText(fitbOpts);
          rowBackImageUrl = null;
        } else if (isConceptCard) {
          // correct_answer/explanation stay NULL (D-06) — concept cards are never
          // graded. back_text (summary) is typed directly, same as a plain flashcard.
          rowOptions = buildConceptOptions(card.conceptTerms);
        }

        return [{
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
          back_text: rowBackText,
          front_image_url: card.frontImageUrl || null,
          back_image_url: rowBackImageUrl,
          tags: tags ? tags.split(',').map(t => t.trim()).filter(Boolean) : [],
          visibility: cardVisibility,
          is_verified: false,
          difficulty: 'medium',
          batch_id: crypto.randomUUID(),
          batch_description: null,
          question_type: card.questionType,
          options: rowOptions,
          correct_answer: rowCorrectAnswer,
          points_to_remember: null,
          explanation: (isMcq || isCorrectIncorrect || isMatch || isFitb) ? toPointsToRemember(card.why) : null,
          subtype: card.questionType === 'theory' ? card.subtype : null,
        }];
      });

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
          ? `${flashcardsToInsert.length} study item(s) created and shared with ${selectedGroupIds.length} group(s)`
          : `${flashcardsToInsert.length} study item(s) created successfully`,
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
        description: error.message || 'Failed to create study items',
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
      questionType: (isD10GatedType(c.questionType) && !canAuthorGradedTypes)
        ? 'flashcard'
        // A stale draft from before Sprint 7.9 could carry the now-retired
        // test_your_understanding value — fall back to its collapse target.
        : (c.questionType === 'test_your_understanding' ? 'theory' : (c.questionType || 'flashcard')),
      options: c.options || emptyMcqOptions(),
      correctOptionIndex: c.correctOptionIndex ?? null,
      matchLeft: c.matchLeft || emptyMatchLeft(),
      matchRight: c.matchRight || emptyMatchRight(),
      matchCorrect: c.matchCorrect || emptyMatchCorrect(),
      why: c.why || '',
      subtype: c.subtype || null,
      caseScenario: c.caseScenario || '',
      caseQuestions: c.caseQuestions || emptyCaseQuestions(),
      fitbOptions: c.fitbOptions || emptyFitbOptions(),
      conceptTerms: c.conceptTerms || emptyConceptTerms(),
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

  const handleBack = () => {
    if (isDirty) {
      setShowLeaveDialog(true);
    } else {
      navigate(-1);
    }
  };

  const handleLeaveConfirmed = () => {
    localStorage.removeItem(DRAFT_KEY);
    setShowLeaveDialog(false);
    navigate(-1);
  };

  const isSystemCourse = !showCustomCourse &&
    disciplines.some(d => d.name.toLowerCase() === (targetCourse || '').toLowerCase());

  const unsavedCount = flashcards.filter(c => c.front.trim() || c.back.trim() || c.caseScenario?.trim()).length;

  return (
    <div className="min-h-screen bg-gray-50 pb-[calc(3.5rem+env(safe-area-inset-bottom))] md:pb-0">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <Button
        variant="ghost"
        onClick={handleBack}
        className="mb-6"
      >
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back
      </Button>

      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold">Create Study Item</h1>
          <p className="text-muted-foreground mt-2">
            Build your own study items — flashcards, MCQs, and more
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
              <CardTitle>Who are these study items for?</CardTitle>
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
                  Select which students should see these study items
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
                      className="text-amber-600 hover:underline"
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
                <Label htmlFor="visibility">Who can see these study items?</Label>
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
                  {visibility === 'private' && 'Only you can see these study items'}
                  {visibility === 'study_groups' && 'Share with selected study groups'}
                  {visibility === 'friends' && 'Only your friends can see these study items'}
                  {visibility === 'public' && 'Everyone can see these study items'}
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
                        className="text-amber-600 hover:underline"
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
                            className="h-4 w-4 rounded border-gray-300 text-amber-600 focus:ring-amber-400"
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
                  <CardTitle>Item {index + 1} — {formatQuestionType(card.questionType)}</CardTitle>
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
                  <Label htmlFor={`question-type-${index}`}>Question Type</Label>
                  <Select
                    value={card.questionType}
                    onValueChange={(val) => {
                      const updated = [...flashcards];
                      updated[index] = {
                        ...updated[index],
                        questionType: val,
                        correctOptionIndex: null,
                        options: val === 'mcq' ? emptyMcqOptions() : updated[index].options,
                        matchLeft: val === 'match_the_following' ? emptyMatchLeft() : updated[index].matchLeft,
                        matchRight: val === 'match_the_following' ? emptyMatchRight() : updated[index].matchRight,
                        matchCorrect: val === 'match_the_following' ? emptyMatchCorrect() : updated[index].matchCorrect,
                        subtype: val === 'theory' ? updated[index].subtype : null,
                        caseScenario: val === 'case_study_mcq' ? '' : updated[index].caseScenario,
                        caseQuestions: val === 'case_study_mcq' ? emptyCaseQuestions() : updated[index].caseQuestions,
                        fitbOptions: val === 'fitb' ? emptyFitbOptions() : updated[index].fitbOptions,
                        conceptTerms: val === 'concept_card' ? emptyConceptTerms() : updated[index].conceptTerms,
                      };
                      setFlashcards(updated);
                    }}
                  >
                    <SelectTrigger id={`question-type-${index}`}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="flashcard">Flashcard</SelectItem>
                      <SelectItem value="theory">Theory</SelectItem>
                      <SelectItem value="concept_card">Concept Card</SelectItem>
                      {canAuthorGradedTypes && <SelectItem value="mcq">Multiple Choice</SelectItem>}
                      {canAuthorGradedTypes && <SelectItem value="correct_incorrect">Correct / Incorrect</SelectItem>}
                      {canAuthorGradedTypes && <SelectItem value="match_the_following">Match the following</SelectItem>}
                      {canAuthorGradedTypes && <SelectItem value="case_study_mcq">Case study MCQ</SelectItem>}
                      {canAuthorGradedTypes && <SelectItem value="fitb">Fill in the Blank</SelectItem>}
                    </SelectContent>
                  </Select>
                </div>

                {card.questionType !== 'case_study_mcq' && (
                <div className="space-y-2">
                  <Label htmlFor={`front-${index}`}>
                    {card.questionType === 'mcq' ? 'Question' : card.questionType === 'correct_incorrect' ? 'Statement' : card.questionType === 'match_the_following' ? 'Instructions' : card.questionType === 'fitb' ? 'Sentence with blank' : card.questionType === 'concept_card' ? 'Concept Name' : 'Front'}
                  </Label>
                  <Textarea
                    id={`front-${index}`}
                    value={card.front}
                    onChange={(e) => updateFlashcard(index, 'front', e.target.value)}
                    placeholder={
                      card.questionType === 'mcq'
                        ? 'The question stem'
                        : card.questionType === 'correct_incorrect'
                          ? 'The statement to mark correct or incorrect'
                          : card.questionType === 'match_the_following'
                            ? 'e.g., Match each cost concept with its formula'
                            : card.questionType === 'fitb'
                              ? `e.g., The basic exemption limit for individuals below 60 is ${FITB_BLANK_PLACEHOLDER}.`
                              : card.questionType === 'concept_card'
                                ? 'e.g., SM-2 Algorithm'
                                : 'Question or prompt'
                    }
                    rows={3}
                  />
                  {card.questionType === 'fitb' && (
                    <p className="text-xs text-muted-foreground">
                      Mark the blank with {FITB_BLANK_PLACEHOLDER} (at least 3 underscores) somewhere in the sentence.
                    </p>
                  )}

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
                )}

                {card.questionType === 'mcq' ? (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label>Options <span className="text-red-500">*</span></Label>
                      <p className="text-xs text-muted-foreground">
                        Mark the correct option. {MCQ_MIN_OPTIONS}-{MCQ_MAX_OPTIONS} options.
                      </p>
                      <div className="space-y-2">
                        {card.options.map((opt, optIndex) => (
                          <div key={optIndex} className="flex items-center gap-2">
                            <input
                              type="radio"
                              name={`correct-option-${index}`}
                              checked={card.correctOptionIndex === optIndex}
                              onChange={() => updateFlashcard(index, 'correctOptionIndex', optIndex)}
                              className="h-4 w-4 shrink-0 accent-[#1e1b4b]"
                              aria-label={`Mark option ${optIndex + 1} as correct`}
                            />
                            <Input
                              value={opt}
                              onChange={(e) => updateMcqOption(index, optIndex, e.target.value)}
                              placeholder={`Option ${optIndex + 1}`}
                            />
                            {card.options.length > MCQ_MIN_OPTIONS && (
                              <Button
                                type="button"
                                variant="ghost"
                                size="sm"
                                onClick={() => removeMcqOption(index, optIndex)}
                                className="text-destructive hover:text-destructive shrink-0"
                              >
                                <X className="h-4 w-4" />
                              </Button>
                            )}
                          </div>
                        ))}
                      </div>
                      {card.options.length < MCQ_MAX_OPTIONS && (
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          onClick={() => addMcqOption(index)}
                        >
                          <Plus className="mr-2 h-4 w-4" />
                          Add Option
                        </Button>
                      )}
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor={`why-${index}`}>Why (Optional)</Label>
                      <Textarea
                        id={`why-${index}`}
                        value={card.why}
                        onChange={(e) => updateFlashcard(index, 'why', e.target.value)}
                        placeholder="Explanation shown after the student answers"
                        rows={3}
                      />
                    </div>
                  </div>
                ) : card.questionType === 'correct_incorrect' ? (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label>Correct Answer <span className="text-red-500">*</span></Label>
                      <div className="flex gap-2">
                        {VERDICT_OPTION_LABELS[card.questionType].map((label, optIndex) => (
                          <button
                            key={optIndex}
                            type="button"
                            onClick={() => updateFlashcard(index, 'correctOptionIndex', optIndex)}
                            className={cn(
                              'flex-1 rounded-lg border px-4 py-2.5 text-sm font-medium transition-colors',
                              card.correctOptionIndex === optIndex
                                ? 'border-[#1e1b4b] bg-[#1e1b4b] text-white'
                                : 'border-input bg-background hover:bg-accent',
                            )}
                          >
                            {label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor={`why-${index}`}>Why (Optional)</Label>
                      <Textarea
                        id={`why-${index}`}
                        value={card.why}
                        onChange={(e) => updateFlashcard(index, 'why', e.target.value)}
                        placeholder="Explanation shown after the student answers"
                        rows={3}
                      />
                    </div>
                  </div>
                ) : card.questionType === 'match_the_following' ? (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label>Left Items <span className="text-red-500">*</span></Label>
                      <p className="text-xs text-muted-foreground">
                        {MATCH_MIN_PAIRS}-{MATCH_MAX_PAIRS} items. Left and right lists must end up the same length.
                      </p>
                      <div className="space-y-2">
                        {card.matchLeft.map((val, li) => (
                          <div key={li} className="flex items-center gap-2">
                            <Input
                              value={val}
                              onChange={(e) => updateMatchItem(index, 'matchLeft', li, e.target.value)}
                              placeholder={`Left item ${li + 1}`}
                            />
                            {card.matchLeft.length > MATCH_MIN_PAIRS && (
                              <Button
                                type="button"
                                variant="ghost"
                                size="sm"
                                onClick={() => removeMatchLeft(index, li)}
                                className="text-destructive hover:text-destructive shrink-0"
                              >
                                <X className="h-4 w-4" />
                              </Button>
                            )}
                          </div>
                        ))}
                      </div>
                      {card.matchLeft.length < MATCH_MAX_PAIRS && (
                        <Button type="button" variant="outline" size="sm" onClick={() => addMatchLeft(index)}>
                          <Plus className="mr-2 h-4 w-4" />
                          Add Left Item
                        </Button>
                      )}
                    </div>

                    <div className="space-y-2">
                      <Label>Right Items <span className="text-red-500">*</span></Label>
                      <p className="text-xs text-muted-foreground">
                        Letters (A, B, C…) are assigned automatically — don't type them yourself.
                      </p>
                      <div className="space-y-2">
                        {card.matchRight.map((val, ri) => (
                          <div key={ri} className="flex items-center gap-2">
                            <span className="font-mono text-xs text-muted-foreground w-5 shrink-0 text-center">
                              {keyForRightIndex(ri)}
                            </span>
                            <Input
                              value={val}
                              onChange={(e) => updateMatchItem(index, 'matchRight', ri, e.target.value)}
                              placeholder={`Right item ${ri + 1}`}
                            />
                            {card.matchRight.length > MATCH_MIN_PAIRS && (
                              <Button
                                type="button"
                                variant="ghost"
                                size="sm"
                                onClick={() => removeMatchRight(index, ri)}
                                className="text-destructive hover:text-destructive shrink-0"
                              >
                                <X className="h-4 w-4" />
                              </Button>
                            )}
                          </div>
                        ))}
                      </div>
                      {card.matchRight.length < MATCH_MAX_PAIRS && (
                        <Button type="button" variant="outline" size="sm" onClick={() => addMatchRight(index)}>
                          <Plus className="mr-2 h-4 w-4" />
                          Add Right Item
                        </Button>
                      )}
                    </div>

                    <div className="space-y-2">
                      <Label>Correct Mapping <span className="text-red-500">*</span></Label>
                      <div className="space-y-2">
                        {card.matchLeft.map((leftVal, li) => (
                          <div key={li} className="flex items-center gap-2">
                            <span className="text-sm text-muted-foreground w-1/2 truncate">
                              {leftVal.trim() || `Left item ${li + 1}`}
                            </span>
                            <Select
                              value={card.matchCorrect[li] === null || card.matchCorrect[li] === undefined ? '' : String(card.matchCorrect[li])}
                              onValueChange={(val) => updateMatchCorrect(index, li, val === '' ? null : Number(val))}
                            >
                              <SelectTrigger className="w-1/2">
                                <SelectValue placeholder="Choose a match..." />
                              </SelectTrigger>
                              <SelectContent>
                                {card.matchRight.map((rightVal, ri) => (
                                  <SelectItem key={ri} value={String(ri)}>
                                    {keyForRightIndex(ri)} — {rightVal.trim() || `Right item ${ri + 1}`}
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor={`why-${index}`}>Why (Optional)</Label>
                      <Textarea
                        id={`why-${index}`}
                        value={card.why}
                        onChange={(e) => updateFlashcard(index, 'why', e.target.value)}
                        placeholder="Explanation shown after the student answers"
                        rows={3}
                      />
                    </div>
                  </div>
                ) : card.questionType === 'case_study_mcq' ? (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label htmlFor={`scenario-${index}`}>Scenario <span className="text-red-500">*</span></Label>
                      <Textarea
                        id={`scenario-${index}`}
                        value={card.caseScenario}
                        onChange={(e) => updateCaseScenario(index, e.target.value)}
                        placeholder="The shared case narrative — every question below is graded against this scenario"
                        rows={5}
                      />
                      <p className="text-xs text-muted-foreground">
                        Shown above every question in this case. {CASE_MIN_QUESTIONS}-{CASE_MAX_QUESTIONS} questions per case.
                      </p>
                    </div>

                    {card.caseQuestions.map((q, qi) => (
                      <div key={qi} className="rounded-lg border p-4 space-y-3">
                        <div className="flex items-center justify-between">
                          <Label className="text-sm font-semibold">Question {qi + 1}</Label>
                          {card.caseQuestions.length > CASE_MIN_QUESTIONS && (
                            <Button
                              type="button"
                              variant="ghost"
                              size="sm"
                              onClick={() => removeCaseQuestion(index, qi)}
                              className="text-destructive hover:text-destructive"
                            >
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          )}
                        </div>

                        <Textarea
                          value={q.front}
                          onChange={(e) => updateCaseQuestionField(index, qi, 'front', e.target.value)}
                          placeholder="The question stem"
                          rows={2}
                        />

                        <div className="space-y-2">
                          <p className="text-xs text-muted-foreground">
                            Mark the correct option. {MCQ_MIN_OPTIONS}-{MCQ_MAX_OPTIONS} options.
                          </p>
                          <div className="space-y-2">
                            {q.options.map((opt, optIndex) => (
                              <div key={optIndex} className="flex items-center gap-2">
                                <input
                                  type="radio"
                                  name={`case-correct-${index}-${qi}`}
                                  checked={q.correctOptionIndex === optIndex}
                                  onChange={() => updateCaseQuestionField(index, qi, 'correctOptionIndex', optIndex)}
                                  className="h-4 w-4 shrink-0 accent-[#1e1b4b]"
                                  aria-label={`Mark option ${optIndex + 1} as correct`}
                                />
                                <Input
                                  value={opt}
                                  onChange={(e) => updateCaseQuestionOption(index, qi, optIndex, e.target.value)}
                                  placeholder={`Option ${optIndex + 1}`}
                                />
                                {q.options.length > MCQ_MIN_OPTIONS && (
                                  <Button
                                    type="button"
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => removeCaseQuestionOption(index, qi, optIndex)}
                                    className="text-destructive hover:text-destructive shrink-0"
                                  >
                                    <X className="h-4 w-4" />
                                  </Button>
                                )}
                              </div>
                            ))}
                          </div>
                          {q.options.length < MCQ_MAX_OPTIONS && (
                            <Button type="button" variant="outline" size="sm" onClick={() => addCaseQuestionOption(index, qi)}>
                              <Plus className="mr-2 h-4 w-4" />
                              Add Option
                            </Button>
                          )}
                        </div>

                        <div className="space-y-2">
                          <Label htmlFor={`case-why-${index}-${qi}`}>Why (Optional)</Label>
                          <Textarea
                            id={`case-why-${index}-${qi}`}
                            value={q.why}
                            onChange={(e) => updateCaseQuestionField(index, qi, 'why', e.target.value)}
                            placeholder="Explanation shown after the student answers this question"
                            rows={2}
                          />
                        </div>
                      </div>
                    ))}

                    {card.caseQuestions.length < CASE_MAX_QUESTIONS && (
                      <Button type="button" variant="outline" size="sm" onClick={() => addCaseQuestion(index)}>
                        <Plus className="mr-2 h-4 w-4" />
                        Add Question
                      </Button>
                    )}
                  </div>
                ) : card.questionType === 'fitb' ? (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label>Acceptable Answers <span className="text-red-500">*</span></Label>
                      <p className="text-xs text-muted-foreground">
                        Every phrasing you'd accept as correct — a student's typed answer is checked against all of them, ignoring case/punctuation/extra spaces.
                      </p>
                      <div className="space-y-2">
                        {card.fitbOptions.map((opt, optIndex) => (
                          <div key={optIndex} className="flex items-center gap-2">
                            <Input
                              value={opt}
                              onChange={(e) => updateFitbOption(index, optIndex, e.target.value)}
                              placeholder={`Acceptable answer ${optIndex + 1}`}
                            />
                            {card.fitbOptions.length > 1 && (
                              <Button
                                type="button"
                                variant="ghost"
                                size="sm"
                                onClick={() => removeFitbOption(index, optIndex)}
                                className="text-destructive hover:text-destructive shrink-0"
                              >
                                <X className="h-4 w-4" />
                              </Button>
                            )}
                          </div>
                        ))}
                      </div>
                      {card.fitbOptions.length < FITB_MAX_ANSWERS && (
                        <Button type="button" variant="outline" size="sm" onClick={() => addFitbOption(index)}>
                          <Plus className="mr-2 h-4 w-4" />
                          Add Acceptable Answer
                        </Button>
                      )}
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor={`why-${index}`}>Why (Optional)</Label>
                      <Textarea
                        id={`why-${index}`}
                        value={card.why}
                        onChange={(e) => updateFlashcard(index, 'why', e.target.value)}
                        placeholder="Explanation shown after the student answers"
                        rows={3}
                      />
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <Label htmlFor={`back-${index}`}>{card.questionType === 'concept_card' ? 'Summary' : 'Back'}</Label>
                    <Textarea
                      id={`back-${index}`}
                      value={card.back}
                      onChange={(e) => updateFlashcard(index, 'back', e.target.value)}
                      placeholder={card.questionType === 'concept_card' ? 'A 2-3 sentence explanation of the concept' : 'Answer or explanation'}
                      rows={3}
                    />

                    {card.questionType === 'concept_card' && (
                      <div className="space-y-2 pt-2">
                        <Label>Key Terms <span className="text-red-500">*</span></Label>
                        <p className="text-xs text-muted-foreground">
                          At least one term + definition pair. Shown as an expandable list below the summary.
                        </p>
                        <div className="space-y-2">
                          {card.conceptTerms.map((t, ti) => (
                            <div key={ti} className="flex items-start gap-2">
                              <Input
                                value={t.term}
                                onChange={(e) => updateConceptTerm(index, ti, 'term', e.target.value)}
                                placeholder="Term"
                                className="w-1/3"
                              />
                              <Input
                                value={t.definition}
                                onChange={(e) => updateConceptTerm(index, ti, 'definition', e.target.value)}
                                placeholder="Definition"
                              />
                              {card.conceptTerms.length > 1 && (
                                <Button
                                  type="button"
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => removeConceptTerm(index, ti)}
                                  className="text-destructive hover:text-destructive shrink-0"
                                >
                                  <X className="h-4 w-4" />
                                </Button>
                              )}
                            </div>
                          ))}
                        </div>
                        {card.conceptTerms.length < CONCEPT_MAX_TERMS && (
                          <Button type="button" variant="outline" size="sm" onClick={() => addConceptTerm(index)}>
                            <Plus className="mr-2 h-4 w-4" />
                            Add Key Term
                          </Button>
                        )}
                      </div>
                    )}

                    {card.questionType === 'theory' && (
                      <div className="space-y-2 pt-2">
                        <Label htmlFor={`subtype-${index}`}>Subtype <span className="text-red-500">*</span></Label>
                        <Select
                          value={card.subtype || ''}
                          onValueChange={(val) => updateFlashcard(index, 'subtype', val)}
                        >
                          <SelectTrigger id={`subtype-${index}`}>
                            <SelectValue placeholder="Choose a subtype..." />
                          </SelectTrigger>
                          <SelectContent>
                            {Object.entries(THEORY_SUBTYPE_LABELS).map(([value, label]) => (
                              <SelectItem key={value} value={value}>{label}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    )}

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
                )}
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
            Add Another Item
          </Button>

          <div className="flex gap-4">
            <Button
              type="button"
              variant="outline"
              onClick={handleBack}
              className="flex-1"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={loading}
              className="flex-1"
            >
              {loading ? 'Creating...' : `Create ${flashcards.length} Item${flashcards.length > 1 ? 's' : ''}`}
            </Button>
          </div>
        </form>

        <Card className="bg-amber-50 border-amber-200">
          <CardContent className="pt-6">
            <p className="text-sm text-[#1e1b4b]">
              💡 <strong>Pro Tip:</strong> Your items are auto-saved as you type — if you accidentally leave this page, you can restore your work when you come back. Need to create many items at once?{' '}
              <Button
                variant="link"
                className="h-auto p-0 text-amber-600 hover:text-amber-700"
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

      {/* Leave-confirmation dialog: shown when user tries to navigate away with unsaved cards */}
      {showLeaveDialog && (
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
                  onClick={() => setShowLeaveDialog(false)}
                >
                  Keep editing
                </Button>
                <Button
                  variant="destructive"
                  className="flex-1"
                  onClick={handleLeaveConfirmed}
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
