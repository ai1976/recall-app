import { useState, useEffect, useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Card as RvCard, GradeButtonRow, VerifiedEdge } from '@/components/revisop';
import { bucketForDays, isReadingBody } from '@/lib/revisop-tokens';
import ContentPreviewWall from '@/components/ui/ContentPreviewWall';
import FlagButton from '@/components/ui/FlagButton';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Brain,
  ArrowLeft,
  RotateCcw,
  Check,
  X,
  Minus,
  SkipForward,
  MoreVertical,
  PauseCircle,
  Trash2,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useToast } from '@/hooks/use-toast';
import { useSpeech } from '@/hooks/useSpeech';
import SpeakButton from '@/components/flashcards/SpeakButton';
import SpeechSettings from '@/components/flashcards/SpeechSettings';

const PREVIEW_LIMIT = 10;

export default function StudyMode({
  flashcards: propFlashcards = null,
  onComplete = null,
  onExit = null
}) {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { user } = useAuth();
  const [searchParams] = useSearchParams();
  const previewModeParam = searchParams.get('previewMode') === 'true';
  const totalCardsParam = previewModeParam ? (parseInt(searchParams.get('totalCards')) || 0) : 0;

  const [flashcards, setFlashcards] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const [loading, setLoading] = useState(true);
  // Post-forward animation gate — true briefly between a grade submit and the
  // next card mounting (Sprint 6.4). Respects prefers-reduced-motion.
  const [transitioning, setTransitioning] = useState(false);
  const [sessionStats, setSessionStats] = useState({
    easy: 0,
    medium: 0,
    hard: 0
  });

  // SRS ladder config (curves + transition rules) — fetched ONCE per session.
  // Button interval text is computed locally from this + the current card's rung;
  // there is NO network request between cards. submit_review is the server-side
  // authority on click; srs_preview is its mirror for tests, not called here.
  const [ladderCfg, setLadderCfg] = useState(null);

  // TTS
  const { speak, stop, isSpeaking, isSupported, voices, selectedVoice, selectVoice, rate, setRate } = useSpeech();

  // Confirmation dialog state
  const [confirmDialog, setConfirmDialog] = useState({
    open: false,
    type: null, // 'suspend' | 'suspendTopic' | 'skipTopic' | 'reset'
    title: '',
    description: '',
  });

  useEffect(() => {
    if (propFlashcards && propFlashcards.length > 0) {
      setFlashcards(propFlashcards);
      setLoading(false);
    } else {
      fetchFlashcards();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [propFlashcards]);

  // Mark session start in localStorage once cards are ready.
  // Preview mode sessions are excluded — Tier B users shouldn't log study time
  // for content they haven't unlocked.
  // The DB row is only written when the session ends (single INSERT pattern).
  useEffect(() => {
    if (!loading && flashcards.length > 0 && !previewModeParam) {
      localStorage.setItem('revisop_session_started_at', new Date().toISOString());
      localStorage.setItem('revisop_session_source', 'study_mode');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading]);

  // Capture study time when the user backgrounds the app or closes the tab.
  // Covers iOS force-quit and app-switch scenarios where handleExit() never fires.
  // logStudyModeSession() clears localStorage before the DB call, so if the user
  // returns and exits cleanly afterward, the second call is a safe no-op.
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') {
        logStudyModeSession(); // fire-and-forget
      }
    };
    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Stop speech when card changes or answer is revealed
  useEffect(() => {
    stop();
  }, [currentIndex, showAnswer, stop]);

  // One-time ladder-config fetch. Failure is non-fatal — the grade buttons just
  // fall back to no interval text; submit_review still schedules correctly.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase.rpc('get_srs_ladder_config');
      if (!cancelled && !error && data) setLadderCfg(data);
    })();
    return () => { cancelled = true; };
  }, []);

  // Local grade-button interval preview for the current card: computed from the
  // once-fetched ladder config + the card's current rung. Mirrors the server's
  // srs_preview / submit_review transition maths (Easy +1 rung, Medium hold,
  // Hard -> relearn step). No per-card network call.
  const gradePreview = useMemo(() => {
    const card = flashcards[currentIndex];
    if (!card || !ladderCfg?.curves?.length || !ladderCfg?.rules) return null;
    const { curves, rules } = ladderCfg;
    const qt = card.question_type || 'flashcard';
    const top = rules.top_rung ?? 7;
    const relearn = rules.relearn_step_days ?? 1;
    const intervalFor = (rung) => {
      const hit =
        curves.find((c) => c.question_type === qt && c.rung_index === rung) ??
        curves.find((c) => c.question_type === '_default' && c.rung_index === rung);
      return hit ? hit.interval_days : null;
    };
    const rung = card.rung;
    if (rung === null || rung === undefined) {
      const nc = rules.new_card_rung || {};
      return { hard: relearn, medium: intervalFor(nc.medium ?? 1), easy: intervalFor(nc.easy ?? 2) };
    }
    return {
      hard: relearn,
      medium: intervalFor(Math.min(rung, top)),
      easy: intervalFor(Math.min(rung + 1, top)),
    };
  }, [flashcards, currentIndex, ladderCfg]);

  // GradeButtonRow inputs — the neutral navy-outline row (no traffic-light colour).
  // Each button's mono label is the real computed interval for THIS card's rung,
  // read from the session-cached ladder config; `bucket` places the micro-ledger
  // dot. rating is passed straight through to handleRating on click.
  const gradeButtons = useMemo(() => {
    const gp = gradePreview || { hard: 1, medium: 3, easy: 7 };
    const mk = (label, rating, days) => ({
      label,
      rating,
      iv: days == null ? '—' : `${days}d`,
      bucket: bucketForDays(days),
    });
    return [
      mk('Hard', 'hard', gp.hard),
      mk('Medium', 'medium', gp.medium),
      mk('Easy', 'easy', gp.easy),
    ];
  }, [gradePreview]);

  const prefersReducedMotion = () =>
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const handleSpeakFront = () => {
    if (isSpeaking) {
      stop();
    } else {
      const card = flashcards[currentIndex];
      if (card?.front_text) speak(card.front_text);
    }
  };

  const handleSpeakBack = () => {
    if (isSpeaking) {
      stop();
    } else {
      const card = flashcards[currentIndex];
      if (card?.back_text) speak(card.back_text);
    }
  };

  const fetchFlashcards = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const subjectParam = searchParams.get('subject');
      const topicParam = searchParams.get('topic');
      const authorParam = searchParams.get('author');
      const deckParam = searchParams.get('deck');

      // Step 1: Fetch all cards visible to this user
      const { data, error } = await supabase
        .from('flashcards')
        .select(`
          *,
          subjects:subject_id (id, name),
          topics:topic_id (id, name)
        `)
        .or(`visibility.eq.public,user_id.eq.${user.id},visibility.eq.friends`)
        .order('created_at', { ascending: false });

      if (error) throw error;

      // Clean special characters
      let cleanedData = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆]/g, '').trim() || ''
      }));

      // Filter by deck_id (individual deck click) or subject/topic/author (Study All)
      if (deckParam) {
        // Try precise deck_id match first
        const byDeckId = cleanedData.filter(card => card.deck_id === deckParam);
        if (byDeckId.length > 0) {
          cleanedData = byDeckId;
        } else {
          // Fallback for cards where deck_id is null (created before deck tracking):
          // look up the deck record and match by user + subject + topic
          const { data: deckInfo } = await supabase
            .from('flashcard_decks')
            .select('user_id, subject_id, topic_id, custom_subject, custom_topic')
            .eq('id', deckParam)
            .single();
          if (deckInfo) {
            cleanedData = cleanedData.filter(card =>
              card.user_id === deckInfo.user_id &&
              (deckInfo.subject_id
                ? card.subject_id === deckInfo.subject_id
                : card.custom_subject === deckInfo.custom_subject) &&
              (deckInfo.topic_id
                ? card.topic_id === deckInfo.topic_id
                : card.custom_topic === deckInfo.custom_topic)
            );
          }
        }
      } else {
        if (subjectParam) {
          cleanedData = cleanedData.filter(card =>
            card.subjects?.name === subjectParam || card.custom_subject === subjectParam
          );
        }
        if (topicParam) {
          cleanedData = cleanedData.filter(card =>
            card.topics?.name === topicParam || card.custom_topic === topicParam
          );
        }
        if (authorParam) {
          cleanedData = cleanedData.filter(card => card.user_id === authorParam);
        }
      }

      // Step 2: SRS-aware filter — show a card if it is DUE, or if it is NEW (never reviewed).
      // "Due" comes from the get_study_queue RPC (the single source of truth — course-aware,
      // concept-cards excluded, status/skip_until/next_review_date resolved server-side).
      // Cards with a review row that are NOT in the due set (not-yet-due / suspended / skipped)
      // are excluded. No client-side date arithmetic.
      if (cleanedData.length > 0) {
        const cardIds = cleanedData.map(c => c.id);

        const { data: dueQueue } = await supabase.rpc('get_study_queue', { p_user_id: user.id });
        const dueIds = new Set((dueQueue || []).map(r => r.flashcard_id));
        // current ladder rung per due card — drives the local grade-button interval text
        const rungById = new Map((dueQueue || []).map(r => [r.flashcard_id, r.rung]));

        const { data: reviewed } = await supabase
          .from('reviews')
          .select('flashcard_id')
          .eq('user_id', user.id)
          .in('flashcard_id', cardIds);
        const reviewedIds = new Set((reviewed || []).map(r => r.flashcard_id));

        cleanedData = cleanedData
          .filter(c => dueIds.has(c.id) || !reviewedIds.has(c.id))
          // due card -> its stored rung; never-reviewed card -> undefined (new-card ladder entry)
          .map(c => ({ ...c, rung: rungById.has(c.id) ? rungById.get(c.id) : undefined }));
      }

      // Shuffle
      const shuffled = [...cleanedData].sort(() => Math.random() - 0.5);
      // Preview mode: Tier B users only see the first PREVIEW_LIMIT cards of professor decks
      setFlashcards(previewModeParam ? shuffled.slice(0, PREVIEW_LIMIT) : shuffled);
    } catch (error) {
      console.error('Error fetching flashcards:', error);
      toast({
        title: "Error loading flashcards",
        description: error.message,
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const handleRating = async (quality) => {
    const currentCard = flashcards[currentIndex];

    setSessionStats(prev => ({
      ...prev,
      [quality]: prev[quality] + 1
    }));

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // The SRS ladder governs every transition server-side. No client-side
      // interval math, no direct reviews write — submit_review does the
      // SELECT-or-INSERT, computes the rung transition, sets next_review_date
      // (kept DATE, user-tz), and applies/reverts MASTERED at the threshold.
      const { data, error } = await supabase.rpc('submit_review', {
        p_user_id: user.id,
        p_flashcard_id: currentCard.id,
        p_rating: quality, // 'easy' | 'medium' | 'hard'
      });
      if (error) throw error;

      const result = Array.isArray(data) ? data[0] : data;
      const intervalDays = result?.interval_days ?? null;
      const mastered = result?.new_status === 'mastered';

      toast({
        title: mastered ? "Mastered! 🎓" : "Progress saved!",
        description: mastered
          ? "This item graduated — it leaves your daily reviews and moves to your Mastered list."
          : (intervalDays != null
              ? `Next review in ${intervalDays} day${intervalDays === 1 ? '' : 's'}`
              : "Review scheduled."),
      });

    } catch (error) {
      console.error('Error saving review:', error);
      toast({
        title: "Error",
        description: "Failed to save progress.",
        variant: "destructive"
      });
      return;
    }

    // 4. Advance to Next Card — after the post-forward animation plays out.
    //    The answered card "files forward" (rv-forward-out); the next card
    //    rises in on mount (rv-forward-in via key). Reduced-motion shortens
    //    this to a 100ms opacity-only crossfade.
    const gradedIndex = currentIndex;
    setTransitioning(true);
    setTimeout(() => {
      setTransitioning(false);
      if (gradedIndex < flashcards.length - 1) {
        setCurrentIndex(gradedIndex + 1);
        setShowAnswer(false);
      } else if (previewModeParam) {
        // Preview mode: trigger ContentPreviewWall instead of navigating away
        setCurrentIndex(flashcards.length);
        setShowAnswer(false);
      } else {
        finishSession();
      }
    }, prefersReducedMotion() ? 100 : 240);
  };

  // ============================================================
  // SKIP: Hide card for 24 hours
  // ============================================================
  const handleSkip = async () => {
    const currentCard = flashcards[currentIndex];

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { error } = await supabase.rpc('skip_card', {
        p_user_id: user.id,
        p_flashcard_id: currentCard.id
      });

      if (error) throw error;

      toast({
        title: "Card skipped",
        description: "This card will reappear tomorrow.",
      });

      advanceOrFinish();
    } catch (error) {
      console.error('Error skipping card:', error);
      toast({
        title: "Error",
        description: "Failed to skip card.",
        variant: "destructive"
      });
    }
  };

  // ============================================================
  // SUSPEND: Remove card indefinitely
  // ============================================================
  const handleSuspend = async () => {
    const currentCard = flashcards[currentIndex];

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { error } = await supabase.rpc('suspend_card', {
        p_user_id: user.id,
        p_flashcard_id: currentCard.id
      });

      if (error) throw error;

      toast({
        title: "Card suspended",
        description: "You can unsuspend it from the Progress page.",
      });

      advanceOrFinish();
    } catch (error) {
      console.error('Error suspending card:', error);
      toast({
        title: "Error",
        description: "Failed to suspend card.",
        variant: "destructive"
      });
    }
  };

  // ============================================================
  // SKIP TOPIC: Bulk 24hr snooze for all cards in this topic
  // ============================================================
  const handleSkipTopic = async () => {
    const currentCard = flashcards[currentIndex];
    const topicId = currentCard.topic_id;
    const customTopic = currentCard.custom_topic;

    if (!topicId && !customTopic) {
      toast({
        title: "No topic",
        description: "This card doesn't belong to a topic.",
        variant: "destructive"
      });
      return;
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: count, error } = await supabase.rpc('skip_topic_cards', {
        p_user_id: user.id,
        p_topic_id: topicId || null,
        p_custom_topic: customTopic || null,
      });

      if (error) throw error;

      const topicName = currentCard.topics?.name || customTopic;
      toast({
        title: "Topic snoozed",
        description: `${count} card${count !== 1 ? 's' : ''} in "${topicName}" hidden until tomorrow.`,
      });

      // Remove all cards from this topic from the current session
      const remaining = flashcards.filter((c, idx) => {
        if (idx <= currentIndex) return false;
        const cTopic = c.topics?.name || c.custom_topic;
        return cTopic !== topicName;
      });

      if (remaining.length > 0) {
        setFlashcards([flashcards[currentIndex], ...remaining]);
        setCurrentIndex(0);
        advanceOrFinish();
      } else {
        finishSession();
      }
    } catch (error) {
      console.error('Error skipping topic:', error);
      toast({
        title: "Error",
        description: "Failed to skip topic.",
        variant: "destructive"
      });
    }
  };

  // ============================================================
  // SUSPEND TOPIC: Bulk suspend all cards for this topic (indefinite)
  // ============================================================
  const handleSuspendTopic = async () => {
    const currentCard = flashcards[currentIndex];
    const topicId = currentCard.topic_id;
    const customTopic = currentCard.custom_topic;

    if (!topicId && !customTopic) {
      toast({
        title: "No topic",
        description: "This card doesn't belong to a topic.",
        variant: "destructive"
      });
      return;
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: count, error } = await supabase.rpc('suspend_topic_cards', {
        p_user_id: user.id,
        p_topic_id: topicId || null,
        p_custom_topic: customTopic || null,
      });

      if (error) throw error;

      toast({
        title: "Topic suspended",
        description: `${count} card${count !== 1 ? 's' : ''} suspended. Unsuspend from the Progress page.`,
      });

      // Remove all cards from this topic from current session
      const topicName = currentCard.topics?.name || customTopic;
      const remaining = flashcards.filter((c, idx) => {
        if (idx <= currentIndex) return false;
        const cTopic = c.topics?.name || c.custom_topic;
        return cTopic !== topicName;
      });

      if (remaining.length > 0) {
        setFlashcards([flashcards[currentIndex], ...remaining]);
        setCurrentIndex(0);
        advanceOrFinish();
      } else {
        finishSession();
      }
    } catch (error) {
      console.error('Error suspending topic:', error);
      toast({
        title: "Error",
        description: "Failed to suspend topic.",
        variant: "destructive"
      });
    }
  };

  // ============================================================
  // RESET: Delete review record, card becomes "New"
  // ============================================================
  const handleReset = async () => {
    const currentCard = flashcards[currentIndex];

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { error } = await supabase.rpc('reset_card', {
        p_user_id: user.id,
        p_flashcard_id: currentCard.id
      });

      if (error) throw error;

      toast({
        title: "Card reset",
        description: "This card is now treated as new.",
      });

      advanceOrFinish();
    } catch (error) {
      console.error('Error resetting card:', error);
      toast({
        title: "Error",
        description: "Failed to reset card.",
        variant: "destructive"
      });
    }
  };

  // ============================================================
  // Helper: Advance to next card or finish session
  // ============================================================
  const advanceOrFinish = () => {
    if (currentIndex < flashcards.length - 1) {
      setCurrentIndex(prev => prev + 1);
      setShowAnswer(false);
    } else if (previewModeParam) {
      setCurrentIndex(flashcards.length);
      setShowAnswer(false);
    } else {
      finishSession();
    }
  };

  // Log the completed study_mode session to DB (single INSERT pattern).
  // Called fire-and-forget from finishSession, handleExit, and the
  // visibilitychange listener — never blocks the user flow.
  // Minimum 10 seconds to avoid logging accidental/empty sessions.
  // localStorage is cleared before the DB call so a second caller always
  // finds empty keys and returns early — no double-logging possible.
  const logStudyModeSession = async () => {
    try {
      // migrate-on-mount: recall_session_started_at → revisop_session_started_at
      if (!localStorage.getItem('revisop_session_started_at')) {
        const oldStarted = localStorage.getItem('recall_session_started_at');
        if (oldStarted) {
          localStorage.setItem('revisop_session_started_at', oldStarted);
          localStorage.removeItem('recall_session_started_at');
        }
      }
      // migrate-on-mount: recall_session_source → revisop_session_source
      if (!localStorage.getItem('revisop_session_source')) {
        const oldSource = localStorage.getItem('recall_session_source');
        if (oldSource) {
          localStorage.setItem('revisop_session_source', oldSource);
          localStorage.removeItem('recall_session_source');
        }
      }

      const startedAtStr = localStorage.getItem('revisop_session_started_at');
      const source       = localStorage.getItem('revisop_session_source');

      if (!startedAtStr || source !== 'study_mode' || !user) return;

      const startedAt      = new Date(startedAtStr);
      const endedAt        = new Date();
      const durationSeconds = Math.round((endedAt.getTime() - startedAt.getTime()) / 1000);

      // Clear localStorage before the DB call to prevent double-logging
      localStorage.removeItem('revisop_session_started_at');
      localStorage.removeItem('revisop_session_source');

      if (durationSeconds < 10) return;

      const sessionDate = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local

      await supabase.from('study_sessions').insert({
        user_id:          user.id,
        started_at:       startedAt.toISOString(),
        ended_at:         endedAt.toISOString(),
        duration_seconds: durationSeconds,
        session_date:     sessionDate,
        source:           'study_mode',
      });
    } catch (err) {
      // Silent fail — never interrupt the user's study completion flow
      console.error('Failed to log study_mode session:', err);
    }
  };

  const finishSession = () => {
    logStudyModeSession(); // fire-and-forget
    if (onComplete) {
      onComplete(sessionStats);
    } else {
      toast({
        title: "Study session complete!",
        description: `You reviewed ${flashcards.length} flashcards`,
      });
      if (onExit) onExit();
    }
  };

  // ============================================================
  // Confirmation dialog handler
  // ============================================================
  const handleConfirmAction = () => {
    setConfirmDialog(prev => ({ ...prev, open: false }));

    switch (confirmDialog.type) {
      case 'suspend':
        handleSuspend();
        break;
      case 'suspendTopic':
        handleSuspendTopic();
        break;
      case 'skipTopic':
        handleSkipTopic();
        break;
      case 'reset':
        handleReset();
        break;
      default:
        break;
    }
  };

  const openConfirmDialog = (type) => {
    const currentCard = flashcards[currentIndex];
    const topicName = currentCard?.topics?.name || currentCard?.custom_topic || 'this topic';

    const configs = {
      suspend: {
        title: 'Suspend this card?',
        description: 'This card will be removed from your review queue indefinitely. You can unsuspend it from the Progress page.',
      },
      suspendTopic: {
        title: `Suspend all "${topicName}" cards?`,
        description: `All cards in this topic will be removed from your review queue indefinitely. You can unsuspend them individually from the Progress page.`,
      },
      skipTopic: {
        title: `Skip all "${topicName}" cards today?`,
        description: `All "${topicName}" cards will be hidden until tomorrow. Your review schedule is preserved — nothing is deleted.`,
      },
      reset: {
        title: 'Reset this card?',
        description: 'This will delete all review history for this card. It will become a "New" card with no scheduling data. This action cannot be undone.',
      },
    };

    setConfirmDialog({
      open: true,
      type,
      ...configs[type],
    });
  };

  const restartSession = () => {
    setCurrentIndex(0);
    setShowAnswer(false);
    setSessionStats({ easy: 0, medium: 0, hard: 0 });
    if (!propFlashcards) {
      fetchFlashcards();
    }
  };

  const handleExit = () => {
    logStudyModeSession(); // fire-and-forget — captures partial session on mid-deck exit
    if (onExit) {
      onExit();
    } else {
      navigate('/dashboard/review-flashcards');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-rv-bg-0">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-rv-navy"></div>
      </div>
    );
  }

  if (flashcards.length === 0) {
    return (
      <div className="min-h-screen bg-rv-bg-0 font-plex flex items-center justify-center">
        <div className="text-center">
          <Brain className="h-16 w-16 text-rv-ink-400 mx-auto mb-4" />
          <h2 className="text-2xl font-semibold text-rv-ink-900 mb-2">No flashcards to study</h2>
          <p className="text-rv-ink-600 mb-6">No flashcards found for this selection</p>
          <div className="flex flex-col gap-2">
            <Button onClick={handleExit}>
              Choose Different Subject
            </Button>
          </div>
        </div>
      </div>
    );
  }

  const currentCard = flashcards[currentIndex];
  const isComplete = currentIndex >= flashcards.length;
  const progressDenominator = (previewModeParam && totalCardsParam > flashcards.length)
    ? totalCardsParam
    : flashcards.length;
  const progress = ((currentIndex + 1) / progressDenominator) * 100;

  return (
    <div className="min-h-screen bg-rv-bg-0 font-plex">
      <header className="bg-rv-bg-1 border-b border-rv-border">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Button variant="ghost" onClick={handleExit} className="gap-2">
              <ArrowLeft className="h-4 w-4" />
              Back to Selection
            </Button>
            <div className="flex items-center gap-2 sm:gap-4">
              <div className="font-plex-mono text-sm text-rv-ink-600 [font-variant-numeric:tabular-nums]">
                Card {currentIndex + 1} of {flashcards.length}
              </div>
              <Button variant="outline" size="sm" onClick={restartSession} className="gap-2">
                <RotateCcw className="h-4 w-4" />
                <span className="hidden sm:inline">Restart</span>
              </Button>
            </div>
          </div>
        </div>
      </header>

      <div className="bg-rv-bg-1 border-b border-rv-border">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
          {previewModeParam && (
            <div className="flex items-center justify-center mb-2">
              <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-rv-navy-50 border border-rv-navy-100 text-rv-navy text-xs font-semibold rounded-rec">
                PREVIEW MODE — first {PREVIEW_LIMIT} of {totalCardsParam || PREVIEW_LIMIT} items
              </span>
            </div>
          )}
          <div className="relative">
            <div className="overflow-hidden h-2 flex rounded-full bg-rv-bg-2">
              <div
                style={{ width: `${progress}%` }}
                className="flex flex-col justify-center bg-rv-navy transition-all duration-300"
              />
            </div>
          </div>
          <div className="flex justify-between mt-2 font-plex-mono text-xs text-rv-ink-400 [font-variant-numeric:tabular-nums]">
            <div className="flex items-center gap-1">
              <Check className="h-3 w-3" />
              <span>Easy {sessionStats.easy}</span>
            </div>
            <div className="flex items-center gap-1">
              <Minus className="h-3 w-3" />
              <span>Medium {sessionStats.medium}</span>
            </div>
            <div className="flex items-center gap-1">
              <X className="h-3 w-3" />
              <span>Hard {sessionStats.hard}</span>
            </div>
          </div>
        </div>
      </div>

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {isComplete ? (
          previewModeParam ? (
            <RvCard elevated className="font-plex overflow-hidden">
              <div className="p-8 text-center border-b border-rv-border">
                <Brain className="h-12 w-12 text-rv-ink-400 mx-auto mb-3" />
                <h2 className="text-xl font-semibold text-rv-ink-900 mb-1">
                  You&apos;ve previewed {PREVIEW_LIMIT} items
                </h2>
                <p className="text-sm text-rv-ink-400">
                  Get full access to study the complete set
                </p>
              </div>
              <ContentPreviewWall
                contentId={searchParams.get('deck')}
                contentType="flashcard_deck"
                contentName={null}
              />
              <div className="p-6 text-center border-t border-rv-border">
                <Button variant="outline" onClick={handleExit}>
                  Back to Study Sets
                </Button>
              </div>
            </RvCard>
          ) : (
          <RvCard elevated className="font-plex p-12 text-center">
            <div className="mb-6">
              <Brain className="h-20 w-20 text-rv-navy mx-auto mb-4" />
              <h2 className="text-3xl font-semibold text-rv-ink-900 mb-2">
                Study Session Complete!
              </h2>
              <p className="text-rv-ink-600">
                You reviewed {flashcards.length} flashcards
              </p>
            </div>

            <div className="grid grid-cols-3 gap-4 mb-8 max-w-md mx-auto">
              <div className="rounded-rec border border-rv-border bg-rv-bg-1 p-4">
                <Check className="h-8 w-8 text-rv-ink-600 mx-auto mb-2" />
                <div className="font-plex-mono text-2xl font-medium text-rv-ink-900 [font-variant-numeric:tabular-nums]">{sessionStats.easy}</div>
                <div className="text-sm text-rv-ink-400">Easy</div>
              </div>
              <div className="rounded-rec border border-rv-border bg-rv-bg-1 p-4">
                <Minus className="h-8 w-8 text-rv-ink-600 mx-auto mb-2" />
                <div className="font-plex-mono text-2xl font-medium text-rv-ink-900 [font-variant-numeric:tabular-nums]">{sessionStats.medium}</div>
                <div className="text-sm text-rv-ink-400">Medium</div>
              </div>
              <div className="rounded-rec border border-rv-slate bg-rv-slate-50 p-4">
                <X className="h-8 w-8 text-rv-slate mx-auto mb-2" />
                <div className="font-plex-mono text-2xl font-medium text-rv-ink-900 [font-variant-numeric:tabular-nums]">{sessionStats.hard}</div>
                <div className="text-sm text-rv-slate">Hard</div>
              </div>
            </div>

            <div className="flex gap-4 justify-center">
              <Button onClick={restartSession} className="gap-2" size="lg">
                <RotateCcw className="h-4 w-4" />
                Study Again
              </Button>
              <Button variant="outline" onClick={handleExit} size="lg">
                {onExit ? 'Exit Review' : 'Choose Different Topic'}
              </Button>
            </div>
          </RvCard>
          )
        ) : (
          <div>
            {(currentCard.subjects || currentCard.custom_subject) && (
              <div className="text-center mb-4">
                <p className="text-sm text-rv-ink-400">
                  {currentCard.subjects?.name || currentCard.custom_subject}
                  {(currentCard.topics?.name || currentCard.custom_topic) &&
                    ` • ${currentCard.topics?.name || currentCard.custom_topic}`
                  }
                </p>
              </div>
            )}

            <RvCard
              elevated
              key={currentIndex}
              className={cn(
                'font-plex flex min-h-[400px] overflow-hidden',
                transitioning ? 'rv-forward-out' : 'rv-forward-in',
              )}
            >
              <VerifiedEdge on={showAnswer && !!currentCard.is_verified} />
              <div className="flex-1 p-8 md:p-12 flex flex-col justify-center items-center">
              {!showAnswer ? (
                <div className="w-full text-center">
                  <div className="mb-6 flex items-center justify-center gap-2">
                    <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">
                      QUESTION
                    </span>
                    {currentCard.front_text && (
                      <SpeakButton
                        onClick={handleSpeakFront}
                        isSpeaking={isSpeaking}
                        isSupported={isSupported}
                      />
                    )}
                    <SpeechSettings
                      voices={voices}
                      selectedVoice={selectedVoice}
                      onSelectVoice={selectVoice}
                      rate={rate}
                      onRateChange={setRate}
                      isSupported={isSupported}
                    />
                  </div>

                  {currentCard.front_image_url && (
                    <img
                      src={currentCard.front_image_url}
                      alt="Question"
                      className="max-w-full h-auto max-h-64 mx-auto rounded-rec mb-6 shadow-rv"
                    />
                  )}

                  <p className="text-2xl md:text-3xl font-semibold text-rv-ink-900 mb-8 whitespace-pre-wrap">
                    {currentCard.front_text}
                  </p>

                  <div className="flex items-center justify-center gap-3">
                    <Button
                      variant="outline"
                      onClick={handleSkip}
                      className="gap-2"
                    >
                      <SkipForward className="h-4 w-4" />
                      Skip 24hr
                    </Button>

                    <Button
                      onClick={() => setShowAnswer(true)}
                      size="lg"
                      className="gap-2 px-8 min-h-[48px]"
                    >
                      <Brain className="h-5 w-5" />
                      Show Answer
                    </Button>

                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="outline" size="icon" className="text-rv-ink-400">
                          <MoreVertical className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        {(currentCard.topic_id || currentCard.custom_topic) && (
                          <DropdownMenuItem onClick={() => openConfirmDialog('skipTopic')}>
                            <SkipForward className="h-4 w-4 mr-2 text-amber-500" />
                            Skip Topic (24hr)
                          </DropdownMenuItem>
                        )}
                        {(currentCard.topic_id || currentCard.custom_topic) && (
                          <DropdownMenuSeparator />
                        )}
                        <DropdownMenuItem
                          onClick={() => openConfirmDialog('suspend')}
                          className="text-red-600 focus:text-red-600"
                        >
                          <PauseCircle className="h-4 w-4 mr-2" />
                          Suspend Card
                        </DropdownMenuItem>
                        {(currentCard.topic_id || currentCard.custom_topic) && (
                          <DropdownMenuItem
                            onClick={() => openConfirmDialog('suspendTopic')}
                            className="text-red-600 focus:text-red-600"
                          >
                            <PauseCircle className="h-4 w-4 mr-2" />
                            Suspend Topic
                          </DropdownMenuItem>
                        )}
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          onClick={() => openConfirmDialog('reset')}
                          className="text-red-600 focus:text-red-600"
                        >
                          <Trash2 className="h-4 w-4 mr-2" />
                          Reset Card
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>

                    {currentCard.user_id !== user?.id && (
                      <FlagButton contentType="flashcard" contentId={currentCard.id} />
                    )}
                  </div>
                </div>
              ) : (
                <div className="w-full">
                  <div className="mb-6 pb-6 border-b border-rv-border">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">
                        QUESTION
                      </span>
                      {currentCard.front_text && (
                        <SpeakButton
                          onClick={handleSpeakFront}
                          isSpeaking={isSpeaking}
                          isSupported={isSupported}
                        />
                      )}
                    </div>
                    <p className="text-lg text-rv-ink-600 whitespace-pre-wrap">
                      {currentCard.front_text}
                    </p>
                  </div>

                  <div className="text-center mb-8">
                    <div className="flex items-center justify-center gap-2 mb-4">
                      <span className="inline-block px-3 py-1 bg-rv-navy-50 text-rv-navy text-xs font-semibold tracking-wide rounded-rec">
                        ANSWER
                      </span>
                      {currentCard.back_text && (
                        <SpeakButton
                          onClick={handleSpeakBack}
                          isSpeaking={isSpeaking}
                          isSupported={isSupported}
                        />
                      )}
                    </div>

                    {currentCard.back_image_url && (
                      <img
                        src={currentCard.back_image_url}
                        alt="Answer"
                        className="max-w-full h-auto max-h-64 mx-auto rounded-rec mb-4 shadow-rv"
                      />
                    )}

                    {currentCard.back_text ? (
                      <p
                        className={cn(
                          'text-xl md:text-2xl font-semibold text-rv-ink-900 whitespace-pre-wrap',
                          isReadingBody(currentCard.back_text) &&
                            'font-literata font-normal leading-relaxed text-[1.35rem]',
                        )}
                      >
                        {currentCard.back_text}
                      </p>
                    ) : (
                      <p className="text-lg text-rv-ink-400 italic">
                        No written answer - refer to image
                      </p>
                    )}
                  </div>

                  <div className="border-t border-rv-border pt-6">
                    <GradeButtonRow
                      grades={gradeButtons}
                      onGrade={(g) => handleRating(g.rating)}
                      prompt="How well did you remember this?"
                      className="mb-4"
                    />

                    {/* Skip/More actions also available on answer side */}
                    <div className="flex items-center justify-center gap-3 pt-2">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={handleSkip}
                        className="gap-1 text-xs text-rv-ink-400"
                      >
                        <SkipForward className="h-3 w-3" />
                        Skip 24hr
                      </Button>

                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm" className="gap-1 text-xs text-gray-500">
                            <MoreVertical className="h-3 w-3" />
                            More
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="center">
                          {(currentCard.topic_id || currentCard.custom_topic) && (
                            <DropdownMenuItem onClick={() => openConfirmDialog('skipTopic')}>
                              <SkipForward className="h-4 w-4 mr-2 text-amber-500" />
                              Skip Topic (24hr)
                            </DropdownMenuItem>
                          )}
                          {(currentCard.topic_id || currentCard.custom_topic) && (
                            <DropdownMenuSeparator />
                          )}
                          <DropdownMenuItem
                            onClick={() => openConfirmDialog('suspend')}
                            className="text-red-600 focus:text-red-600"
                          >
                            <PauseCircle className="h-4 w-4 mr-2" />
                            Suspend Card
                          </DropdownMenuItem>
                          {(currentCard.topic_id || currentCard.custom_topic) && (
                            <DropdownMenuItem
                              onClick={() => openConfirmDialog('suspendTopic')}
                              className="text-red-600 focus:text-red-600"
                            >
                              <PauseCircle className="h-4 w-4 mr-2" />
                              Suspend Topic
                            </DropdownMenuItem>
                          )}
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            onClick={() => openConfirmDialog('reset')}
                            className="text-red-600 focus:text-red-600"
                          >
                            <Trash2 className="h-4 w-4 mr-2" />
                            Reset Card
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>

                      {currentCard.user_id !== user?.id && (
                        <FlagButton contentType="flashcard" contentId={currentCard.id} />
                      )}
                    </div>
                  </div>
                </div>
              )}
              </div>
            </RvCard>

            <div className="text-center mt-6">
              <p className="text-sm text-rv-ink-400">
                {showAnswer
                  ? "Rate how well you remembered to continue"
                  : "Try to recall the answer before revealing it"}
              </p>
            </div>
          </div>
        )}
      </main>

      {/* Confirmation Dialog */}
      <Dialog open={confirmDialog.open} onOpenChange={(open) => setConfirmDialog(prev => ({ ...prev, open }))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{confirmDialog.title}</DialogTitle>
            <DialogDescription>{confirmDialog.description}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))}>
              Cancel
            </Button>
            <Button
              variant={confirmDialog.type === 'skipTopic' ? 'default' : 'destructive'}
              onClick={handleConfirmAction}
            >
              {confirmDialog.type === 'reset' ? 'Reset Card'
                : confirmDialog.type === 'skipTopic' ? 'Skip Topic'
                : 'Suspend'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
