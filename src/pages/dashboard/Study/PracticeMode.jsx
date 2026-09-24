import { useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useStudySession } from '@/contexts/StudySessionContext';
import { Button } from '@/components/ui/button';
import { Card as RvCard, AnswerOption, MatchZone } from '@/components/revisop';
import { cn } from '@/lib/utils';
import { GRADED_QUESTION_TYPES } from '@/lib/questionTypes';
import { isFitbMatch, splitFitbSentence } from '@/lib/fitb';
import { parseMultiAnswer } from '@/lib/mcq';
import { useToast } from '@/hooks/use-toast';
import { Brain, ArrowLeft, SkipForward, Check, ChevronUp, ChevronDown } from 'lucide-react';
import RichText from '@/components/RichText';

// Sprint 8.7.8c — theory cards render as left-aligned, normal-weight prose (matches StudyMode.jsx).
const isTheory = (card) => card?.question_type === 'theory';

// A 42501 from add_to_my_cards / log_practice_attempt means access disappeared between render and
// click (§ "Reactive error handling remains mandatory") — never show the raw SQLSTATE/message.
const isAccessError = (err) =>
  err?.code === '42501' || /not accessible/i.test(err?.message || '');

/**
 * Practice / Explore — inspect and attempt external content with zero SRS side effects.
 * Never calls apply_review. Enrollment ("Add to My Cards") is a separate, explicit, proactively
 * eligibility-gated action (get_practice_cards' can_add_to_my_cards), never inferred client-side.
 */
export default function PracticeMode() {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { user } = useAuth();
  const { setInStudySession } = useStudySession();
  const [searchParams] = useSearchParams();
  const deckId = searchParams.get('deck');
  const typeParam = searchParams.get('type');

  useEffect(() => {
    setInStudySession(true);
    return () => setInStudySession(false);
  }, [setInStudySession]);

  const [cards, setCards] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [addingId, setAddingId] = useState(null);

  // Per-card interaction state — same shape as StudyMode.jsx, reset on every card change.
  const [showAnswer, setShowAnswer] = useState(false);
  const [mcqSelectedIndex, setMcqSelectedIndex] = useState(null);
  const [mcqIsCorrect, setMcqIsCorrect] = useState(null);
  const [matchPairs, setMatchPairs] = useState({});
  const [matchRevealed, setMatchRevealed] = useState(false);
  const [matchIsCorrect, setMatchIsCorrect] = useState(null);
  const [scenarioExpanded, setScenarioExpanded] = useState(true);
  const [fitbAnswer, setFitbAnswer] = useState('');
  const [fitbSubmitted, setFitbSubmitted] = useState(false);
  const [fitbMatched, setFitbMatched] = useState(null);
  const [mcqMultiSelected, setMcqMultiSelected] = useState([]);
  const [mcqMultiRevealed, setMcqMultiRevealed] = useState(false);
  const [mcqMultiIsCorrect, setMcqMultiIsCorrect] = useState(null);

  useEffect(() => {
    setShowAnswer(false);
    setMcqSelectedIndex(null);
    setMcqIsCorrect(null);
    setMatchPairs({});
    setMatchRevealed(false);
    setMatchIsCorrect(null);
    setScenarioExpanded(true);
    setFitbAnswer('');
    setFitbSubmitted(false);
    setFitbMatched(null);
    setMcqMultiSelected([]);
    setMcqMultiRevealed(false);
    setMcqMultiIsCorrect(null);
  }, [currentIndex]);

  // A practice attempt is logged exactly once per card, regardless of rerenders/repeat clicks
  // (Step 0 §7's write-semantics requirement) — keyed by flashcard id, not index, so it survives
  // any future reordering.
  const loggedAttempts = useRef(new Set());

  const fetchCards = async () => {
    setLoading(true);
    setLoadError(null);
    try {
      if (!user || !deckId) {
        setLoadError('No Study Set was specified.');
        return;
      }
      const { data, error } = await supabase.rpc('get_practice_cards', {
        p_user_id: user.id,
        p_deck_id: deckId,
        p_question_type: typeParam || null,
      });
      if (error) {
        setLoadError(isAccessError(error) ? 'This Study Set is not available to practice.' : 'Could not load this Study Set.');
        return;
      }
      const cleaned = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[◆♦◆]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[◆♦◆]/g, '').trim() || '',
      }));
      setCards(cleaned);
      setCurrentIndex(0);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCards();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [deckId, typeParam, user?.id]);

  // Practice study-time logging — reuses StudyMode's exact timer/noise-floor pattern (10s noise
  // floor, single INSERT on exit/backgrounding) with source='practice_mode'. study_sessions.source
  // is free text with no CHECK enum (Step 0 §6 finding), and the 600s minimum is scoped to
  // source='manual' only, so no SQL change was needed and no manual-floor leak is possible here.
  useEffect(() => {
    if (!loading && cards.length > 0) {
      localStorage.setItem('revisop_practice_session_started_at', new Date().toISOString());
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading]);

  const logPracticeSession = async () => {
    try {
      const startedAtStr = localStorage.getItem('revisop_practice_session_started_at');
      if (!startedAtStr || !user) return;
      const startedAt = new Date(startedAtStr);
      const endedAt = new Date();
      const durationSeconds = Math.round((endedAt.getTime() - startedAt.getTime()) / 1000);
      localStorage.removeItem('revisop_practice_session_started_at');
      if (durationSeconds < 10) return;
      const sessionDate = new Date().toLocaleDateString('en-CA');
      const { error } = await supabase.from('study_sessions').insert({
        user_id: user.id,
        started_at: startedAt.toISOString(),
        ended_at: endedAt.toISOString(),
        duration_seconds: durationSeconds,
        session_date: sessionDate,
        source: 'practice_mode',
      });
      if (error) console.error('Failed to log practice_mode session:', error);
    } catch (err) {
      console.error('Failed to log practice_mode session:', err);
    }
  };

  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') logPracticeSession();
    };
    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleExit = () => {
    logPracticeSession();
    navigate('/dashboard/review-flashcards');
  };

  const logAttempt = async (card, isCorrect) => {
    if (loggedAttempts.current.has(card.id)) return;
    loggedAttempts.current.add(card.id);
    try {
      const { error } = await supabase.rpc('log_practice_attempt', {
        p_user_id: user.id,
        p_flashcard_id: card.id,
        p_is_correct: isCorrect,
      });
      if (error) throw error;
    } catch (err) {
      loggedAttempts.current.delete(card.id); // allow a retry on Next/re-render rather than silently losing the attempt
      if (isAccessError(err)) {
        toast({
          title: 'Not available',
          description: 'This item is no longer available. Your answer could not be saved.',
          variant: 'destructive',
        });
      } else {
        console.error('Failed to log practice attempt:', err);
      }
    }
  };

  const handleAdd = async (card) => {
    setAddingId(card.id);
    try {
      const { error } = await supabase.rpc('add_to_my_cards', {
        p_user_id: user.id,
        p_flashcard_id: card.id,
      });
      if (error) throw error;
      setCards(prev => prev.map(c => (c.id === card.id ? { ...c, is_enrolled: true } : c)));
    } catch (err) {
      toast({
        title: 'Could not add',
        description: isAccessError(err)
          ? "This item is no longer available to add to My Cards."
          : 'Something went wrong — please try again.',
        variant: 'destructive',
      });
    } finally {
      setAddingId(null);
    }
  };

  const advanceCard = () => {
    if (currentIndex < cards.length - 1) {
      setCurrentIndex(currentIndex + 1);
    } else {
      logPracticeSession();
      setCurrentIndex(cards.length);
    }
  };

  const handleMcqSelect = (optIndex) => {
    const card = cards[currentIndex];
    const isCorrect = String(optIndex) === card.correct_answer;
    setMcqSelectedIndex(optIndex);
    setMcqIsCorrect(isCorrect);
    logAttempt(card, isCorrect);
  };

  const handleMatchSubmit = () => {
    const card = cards[currentIndex];
    const correctMap = card.options?.correct || {};
    const left = card.options?.left || [];
    const allCorrect = left.every((_, i) => matchPairs[i] === correctMap[i]);
    setMatchRevealed(true);
    setMatchIsCorrect(allCorrect);
    logAttempt(card, allCorrect);
  };

  const toggleMcqMultiOption = (optIndex) => {
    if (mcqMultiRevealed) return;
    setMcqMultiSelected((prev) =>
      prev.includes(optIndex) ? prev.filter((i) => i !== optIndex) : [...prev, optIndex].sort((a, b) => a - b)
    );
  };

  const handleMcqMultiSubmit = () => {
    const card = cards[currentIndex];
    const correctSet = new Set(parseMultiAnswer(card.correct_answer));
    const selectedSet = new Set(mcqMultiSelected);
    const isCorrect = correctSet.size === selectedSet.size && [...correctSet].every((i) => selectedSet.has(i));
    setMcqMultiRevealed(true);
    setMcqMultiIsCorrect(isCorrect);
    logAttempt(card, isCorrect);
  };

  const handleFitbSubmit = () => {
    const card = cards[currentIndex];
    const matched = isFitbMatch(fitbAnswer, card.options);
    setFitbSubmitted(true);
    setFitbMatched(matched);
    // D-13: unmatched wording is non-conclusive, never a hard false — matches log_practice_attempt's
    // own fitb CHECK (rejects FALSE outright).
    logAttempt(card, matched ? true : null);
  };

  const handleReveal = () => {
    const card = cards[currentIndex];
    setShowAnswer(true);
    logAttempt(card, null);
  };

  // ─────────────────────────────────────────────────────────────────────────────────────────
  // Add-to-My-Cards control — proactive, server-derived, three normal states + one race state.
  // Never inferred client-side: is_own / is_enrolled / can_add_to_my_cards all come straight from
  // get_practice_cards, exactly the predicate add_to_my_cards itself accepts (eligibility parity,
  // live-verified in docs/database/sprint8.7.8c/02_TEST_verify_get_practice_cards.sql).
  // ─────────────────────────────────────────────────────────────────────────────────────────
  const renderAddControl = (card, showNudge) => {
    if (card.is_own || card.is_enrolled) {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-rec bg-rv-bg-2 text-rv-ink-600 text-sm font-medium">
          <Check className="h-4 w-4" />
          {card.is_own ? 'Already in My Cards' : 'Added to My Cards'}
        </span>
      );
    }
    if (!card.can_add_to_my_cards) {
      return (
        <div className="text-center">
          <span className="inline-block px-3 py-1.5 rounded-rec bg-rv-bg-2 text-rv-ink-400 text-sm font-medium">
            Available for Practice only
          </span>
          <p className="text-xs text-rv-ink-400 mt-1.5 max-w-sm mx-auto">
            This shared item can be practised here but can&apos;t yet be added to My Cards.
          </p>
        </div>
      );
    }
    return (
      <div className="flex flex-col items-center gap-1.5">
        <Button onClick={() => handleAdd(card)} disabled={addingId === card.id} size="lg" className="gap-2 px-6">
          {addingId === card.id ? 'Adding…' : 'Add to My Cards'}
        </Button>
        {showNudge && <p className="text-xs text-rv-ink-400">Worth revisiting?</p>}
      </div>
    );
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-rv-bg-0">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-rv-navy"></div>
      </div>
    );
  }

  if (loadError) {
    return (
      <div className="min-h-screen bg-rv-bg-0 font-plex flex items-center justify-center">
        <div className="text-center">
          <Brain className="h-16 w-16 text-rv-ink-400 mx-auto mb-4" />
          <h2 className="text-2xl font-semibold text-rv-ink-900 mb-2">Can&apos;t open Practice</h2>
          <p className="text-rv-ink-600 mb-6">{loadError}</p>
          <Button onClick={() => navigate('/dashboard/review-flashcards')}>Back to Study Sets</Button>
        </div>
      </div>
    );
  }

  if (cards.length === 0) {
    return (
      <div className="min-h-screen bg-rv-bg-0 font-plex flex items-center justify-center">
        <div className="text-center">
          <Brain className="h-16 w-16 text-rv-ink-400 mx-auto mb-4" />
          <h2 className="text-2xl font-semibold text-rv-ink-900 mb-2">Nothing to practice here</h2>
          <p className="text-rv-ink-600 mb-6">No practiceable cards were found for this selection.</p>
          <Button onClick={() => navigate('/dashboard/review-flashcards')}>Back to Study Sets</Button>
        </div>
      </div>
    );
  }

  const isComplete = currentIndex >= cards.length;
  const card = cards[currentIndex];
  const progress = ((currentIndex + 1) / cards.length) * 100;
  const { before: fitbBefore, after: fitbAfter } = card?.question_type === 'fitb'
    ? splitFitbSentence(card.front_text)
    : { before: '', after: '' };

  return (
    <div className="min-h-screen bg-rv-bg-0 font-plex">
      <header className="bg-rv-bg-1 border-b border-rv-border">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Button variant="ghost" onClick={handleExit} className="gap-2">
              <ArrowLeft className="h-4 w-4" />
              Exit Practice
            </Button>
            <div className="flex items-center gap-2">
              <Brain className="h-4 w-4 text-rv-ink-400" />
              <span className="font-plex-mono text-sm text-rv-ink-600 [font-variant-numeric:tabular-nums]">
                {isComplete ? `${cards.length} of ${cards.length}` : `${currentIndex + 1} of ${cards.length}`}
              </span>
            </div>
          </div>
        </div>
      </header>

      <div className="bg-rv-bg-1 border-b border-rv-border">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div className="flex items-center justify-center mb-2">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold rounded-rec">
              PRACTICE — no grades, nothing added to your reviews unless you choose to
            </span>
          </div>
          <div className="overflow-hidden h-2 flex rounded-full bg-rv-bg-2">
            <div style={{ width: `${progress}%` }} className="flex flex-col justify-center bg-rv-navy transition-all duration-300" />
          </div>
        </div>
      </div>

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {isComplete ? (
          <RvCard elevated className="font-plex p-12 text-center">
            <Brain className="h-20 w-20 text-rv-navy mx-auto mb-4" />
            <h2 className="text-3xl font-semibold text-rv-ink-900 mb-2">Practice complete!</h2>
            <p className="text-rv-ink-600 mb-8">You practiced {cards.length} item{cards.length === 1 ? '' : 's'}.</p>
            <Button onClick={handleExit} size="lg">Back to Study Sets</Button>
          </RvCard>
        ) : (
          <div>
            {(card.subject_name || card.custom_subject) && (
              <div className="text-center mb-4">
                <p className="text-sm text-rv-ink-400">
                  {card.subject_name || card.custom_subject}
                  {(card.topic_name || card.custom_topic) && ` • ${card.topic_name || card.custom_topic}`}
                </p>
              </div>
            )}

            <RvCard elevated className="font-plex flex min-h-[400px] overflow-hidden">
              <div className="flex-1 min-w-0 p-5 sm:p-8 md:p-12 flex flex-col justify-center items-center">
                {card.question_type === 'fitb' ? (
                  <div className="w-full">
                    <div className="mb-6 flex items-center justify-center gap-2">
                      <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">QUESTION</span>
                    </div>
                    <p className="text-xl md:text-2xl font-semibold text-rv-ink-900 mb-6 whitespace-pre-wrap text-center leading-relaxed">
                      {fitbBefore}
                      {!fitbSubmitted ? (
                        <input
                          type="text"
                          value={fitbAnswer}
                          onChange={(e) => setFitbAnswer(e.target.value)}
                          onKeyDown={(e) => { if (e.key === 'Enter' && fitbAnswer.trim()) handleFitbSubmit(); }}
                          placeholder="your answer"
                          autoFocus
                          className="inline-block mx-1 min-w-[8rem] max-w-full align-middle border-b-2 border-rv-navy bg-transparent px-1 py-0.5 text-center font-plex-mono text-base sm:text-lg text-rv-ink-900 focus:outline-none"
                        />
                      ) : (
                        <span className={cn('inline-block mx-1 px-1 font-plex-mono', fitbMatched ? 'text-rv-navy' : 'text-rv-ink-900 underline decoration-rv-slate decoration-2 underline-offset-4')}>
                          {fitbAnswer.trim() || '—'}
                        </span>
                      )}
                      {fitbAfter}
                    </p>

                    {fitbSubmitted && fitbMatched === false && (
                      <div className="mb-3.5 rounded-rec bg-rv-bg-2 px-4 py-3.5 text-center">
                        <p className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400 mb-1.5">ACCEPTED ANSWERS</p>
                        <p className="font-literata text-[15px] text-rv-ink-900">{(card.options || []).join(' · ')}</p>
                      </div>
                    )}

                    {fitbSubmitted && Array.isArray(card.explanation) && card.explanation.length > 0 && (
                      <div className="mt-3.5 rounded-rec bg-rv-bg-2 border-l-[3px] border-rv-navy px-4 py-3.5 text-left">
                        <p className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400 mb-1.5">WHY</p>
                        {card.explanation.map((point, i) => (
                          <p key={i} className="font-literata text-[15px] leading-relaxed text-rv-ink-900 mb-1.5 last:mb-0">{point}</p>
                        ))}
                      </div>
                    )}

                    {!fitbSubmitted ? (
                      <div className="flex flex-wrap items-center justify-center gap-3 mt-6">
                        <Button onClick={handleFitbSubmit} disabled={!fitbAnswer.trim()} size="lg" className="gap-2 px-6 sm:px-8 min-h-[48px]">Submit</Button>
                      </div>
                    ) : (
                      <div className="mt-6 border-t border-rv-border pt-6 flex flex-col items-center gap-4">
                        {renderAddControl(card, false)}
                        <Button variant="outline" onClick={advanceCard} className="gap-2">
                          <SkipForward className="h-4 w-4" />
                          Next
                        </Button>
                      </div>
                    )}
                  </div>
                ) : card.question_type === 'match_the_following' ? (
                  <div className="w-full">
                    <div className="mb-6 flex items-center justify-center gap-2">
                      <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">QUESTION</span>
                    </div>
                    <RichText className="text-xl md:text-2xl font-semibold text-rv-ink-900 mb-6 whitespace-pre-wrap text-center" text={card.front_text} />
                    <MatchZone
                      left={card.options?.left || []}
                      right={card.options?.right || []}
                      pairs={matchPairs}
                      onChange={setMatchPairs}
                      revealed={matchRevealed}
                      correct={card.options?.correct || {}}
                    />
                    {matchRevealed && Array.isArray(card.explanation) && card.explanation.length > 0 && (
                      <div className="mt-3.5 rounded-rec bg-rv-bg-2 border-l-[3px] border-rv-navy px-4 py-3.5 text-left">
                        <p className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400 mb-1.5">WHY</p>
                        {card.explanation.map((point, i) => (
                          <p key={i} className="font-literata text-[15px] leading-relaxed text-rv-ink-900 mb-1.5 last:mb-0">{point}</p>
                        ))}
                      </div>
                    )}
                    {!matchRevealed ? (
                      <div className="flex flex-wrap items-center justify-center gap-3 mt-6">
                        <Button
                          onClick={handleMatchSubmit}
                          disabled={!(card.options?.left || []).every((_, i) => matchPairs[i] !== undefined)}
                          size="lg"
                          className="gap-2 px-6 sm:px-8 min-h-[48px]"
                        >
                          Check Answers
                        </Button>
                      </div>
                    ) : (
                      <div className="mt-6 border-t border-rv-border pt-6 flex flex-col items-center gap-4">
                        {renderAddControl(card, matchIsCorrect === false)}
                        <Button variant="outline" onClick={advanceCard} className="gap-2">
                          <SkipForward className="h-4 w-4" />
                          Next
                        </Button>
                      </div>
                    )}
                  </div>
                ) : card.question_type === 'mcq_multi' ? (
                  <div className="w-full">
                    <div className="mb-6 flex items-center justify-center gap-2">
                      <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">QUESTION</span>
                    </div>
                    <RichText className="text-xl md:text-2xl font-semibold text-rv-ink-900 mb-2 whitespace-pre-wrap text-center" text={card.front_text} />
                    <p className="text-center text-xs text-rv-ink-400 mb-6">Select all that apply</p>
                    <div className="flex flex-col gap-2.5 mb-2">
                      {(card.options || []).map((optionText, optIndex) => {
                        const correctSet = new Set(parseMultiAnswer(card.correct_answer));
                        let state = 'idle';
                        if (mcqMultiRevealed) {
                          if (correctSet.has(optIndex)) state = 'correct';
                          else if (mcqMultiSelected.includes(optIndex)) state = 'missed';
                          else state = 'dim';
                        } else if (mcqMultiSelected.includes(optIndex)) {
                          state = 'selected';
                        }
                        return (
                          <AnswerOption key={optIndex} text={optionText} index={optIndex} state={state} disabled={mcqMultiRevealed} onClick={() => toggleMcqMultiOption(optIndex)} />
                        );
                      })}
                    </div>
                    {mcqMultiRevealed && Array.isArray(card.explanation) && card.explanation.length > 0 && (
                      <div className="mt-3.5 rounded-rec bg-rv-bg-2 border-l-[3px] border-rv-navy px-4 py-3.5 text-left">
                        <p className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400 mb-1.5">WHY</p>
                        {card.explanation.map((point, i) => (
                          <p key={i} className="font-literata text-[15px] leading-relaxed text-rv-ink-900 mb-1.5 last:mb-0">{point}</p>
                        ))}
                      </div>
                    )}
                    {!mcqMultiRevealed ? (
                      <div className="flex flex-wrap items-center justify-center gap-3 mt-6">
                        <Button onClick={handleMcqMultiSubmit} disabled={mcqMultiSelected.length === 0} size="lg" className="gap-2 px-6 sm:px-8 min-h-[48px]">Submit</Button>
                      </div>
                    ) : (
                      <div className="mt-6 border-t border-rv-border pt-6 flex flex-col items-center gap-4">
                        {renderAddControl(card, mcqMultiIsCorrect === false)}
                        <Button variant="outline" onClick={advanceCard} className="gap-2">
                          <SkipForward className="h-4 w-4" />
                          Next
                        </Button>
                      </div>
                    )}
                  </div>
                ) : GRADED_QUESTION_TYPES.includes(card.question_type) ? (
                  <div className="w-full">
                    {card.question_type === 'case_study_mcq' && card.scenario && (
                      <div className="w-full mb-6 rounded-rec border border-rv-border bg-rv-bg-1 text-left">
                        <button type="button" onClick={() => setScenarioExpanded((v) => !v)} className="w-full flex items-center justify-between gap-2 px-4 py-3">
                          <span className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400">CASE SCENARIO</span>
                          {scenarioExpanded ? <ChevronUp className="h-4 w-4 text-rv-ink-400 shrink-0" /> : <ChevronDown className="h-4 w-4 text-rv-ink-400 shrink-0" />}
                        </button>
                        {scenarioExpanded && (
                          <RichText className="font-literata text-[15px] leading-relaxed text-rv-ink-900 px-4 pb-4 whitespace-pre-wrap max-h-[40vh] overflow-y-auto" text={card.scenario} />
                        )}
                      </div>
                    )}
                    <div className={cn('mb-6 flex items-center gap-2', card.question_type === 'case_study_mcq' ? 'justify-start' : 'justify-center')}>
                      <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">QUESTION</span>
                    </div>
                    <RichText className={cn('text-xl md:text-2xl font-semibold text-rv-ink-900 mb-6 whitespace-pre-wrap text-center', card.question_type === 'case_study_mcq' && 'text-lg md:text-xl text-left')} text={card.front_text} />
                    <div className="flex flex-col gap-2.5 mb-2">
                      {(card.options || []).map((optionText, optIndex) => {
                        const correctIndex = parseInt(card.correct_answer, 10);
                        const answered = mcqSelectedIndex !== null;
                        let state = 'idle';
                        if (answered) {
                          if (optIndex === correctIndex) state = 'correct';
                          else if (optIndex === mcqSelectedIndex) state = 'missed';
                          else state = 'dim';
                        }
                        return (
                          <AnswerOption key={optIndex} text={optionText} index={optIndex} state={state} disabled={answered} onClick={() => handleMcqSelect(optIndex)} />
                        );
                      })}
                    </div>
                    {mcqSelectedIndex !== null && Array.isArray(card.explanation) && card.explanation.length > 0 && (
                      <div className="mt-3.5 rounded-rec bg-rv-bg-2 border-l-[3px] border-rv-navy px-4 py-3.5 text-left">
                        <p className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400 mb-1.5">WHY</p>
                        {card.explanation.map((point, i) => (
                          <p key={i} className="font-literata text-[15px] leading-relaxed text-rv-ink-900 mb-1.5 last:mb-0">{point}</p>
                        ))}
                      </div>
                    )}
                    {mcqSelectedIndex !== null && (
                      <div className="mt-6 border-t border-rv-border pt-6 flex flex-col items-center gap-4">
                        {renderAddControl(card, mcqIsCorrect === false)}
                        <Button variant="outline" onClick={advanceCard} className="gap-2">
                          <SkipForward className="h-4 w-4" />
                          Next
                        </Button>
                      </div>
                    )}
                  </div>
                ) : !showAnswer ? (
                  <div className={cn('w-full', !isTheory(card) && 'text-center')}>
                    {isTheory(card) && card.scenario && (
                      <div className="w-full mb-6 rounded-rec border border-rv-border bg-rv-bg-1 text-left">
                        <button type="button" onClick={() => setScenarioExpanded((v) => !v)} className="w-full flex items-center justify-between gap-2 px-4 py-3">
                          <span className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400">CASE SCENARIO</span>
                          {scenarioExpanded ? <ChevronUp className="h-4 w-4 text-rv-ink-400 shrink-0" /> : <ChevronDown className="h-4 w-4 text-rv-ink-400 shrink-0" />}
                        </button>
                        {scenarioExpanded && (
                          <RichText className="font-literata text-[15px] leading-relaxed text-rv-ink-900 px-4 pb-4 whitespace-pre-wrap max-h-[40vh] overflow-y-auto" text={card.scenario} />
                        )}
                      </div>
                    )}
                    <div className={cn('mb-6 flex items-center gap-2', isTheory(card) ? 'justify-start' : 'justify-center')}>
                      <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">QUESTION</span>
                    </div>
                    <RichText className={cn('text-2xl md:text-3xl font-semibold text-rv-ink-900 mb-8 whitespace-pre-wrap', isTheory(card) && 'text-base md:text-lg font-normal leading-relaxed text-left')} text={card.front_text} />
                    <div className="flex flex-wrap items-center justify-center gap-3">
                      <Button onClick={handleReveal} size="lg" className="gap-2 px-6 sm:px-8 min-h-[48px]">
                        <Brain className="h-5 w-5" />
                        Reveal Answer
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div className="w-full">
                    {isTheory(card) && card.scenario && (
                      <div className="w-full mb-6 rounded-rec border border-rv-border bg-rv-bg-1 text-left">
                        <button type="button" onClick={() => setScenarioExpanded((v) => !v)} className="w-full flex items-center justify-between gap-2 px-4 py-3">
                          <span className="font-plex-mono text-[11px] tracking-wide text-rv-ink-400">CASE SCENARIO</span>
                          {scenarioExpanded ? <ChevronUp className="h-4 w-4 text-rv-ink-400 shrink-0" /> : <ChevronDown className="h-4 w-4 text-rv-ink-400 shrink-0" />}
                        </button>
                        {scenarioExpanded && (
                          <RichText className="font-literata text-[15px] leading-relaxed text-rv-ink-900 px-4 pb-4 whitespace-pre-wrap max-h-[40vh] overflow-y-auto" text={card.scenario} />
                        )}
                      </div>
                    )}
                    <div className="mb-6 pb-6 border-b border-rv-border">
                      <div className="flex items-center gap-2 mb-3">
                        <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">QUESTION</span>
                      </div>
                      <RichText className="text-lg text-rv-ink-600 whitespace-pre-wrap" text={card.front_text} />
                    </div>
                    <div className="mb-8">
                      <div className="flex items-center justify-start gap-2 mb-4">
                        <span className="inline-block px-3 py-1 bg-rv-navy-50 text-rv-navy text-xs font-semibold tracking-wide rounded-rec">ANSWER</span>
                      </div>
                      {card.back_text ? (
                        <RichText className={cn('text-xl md:text-2xl font-semibold text-rv-ink-900 whitespace-pre-wrap', isTheory(card) && 'text-base md:text-lg font-normal leading-relaxed text-left')} text={card.back_text} />
                      ) : (
                        <p className="text-lg text-rv-ink-400 italic">No written answer</p>
                      )}
                    </div>
                    <div className="border-t border-rv-border pt-6 flex flex-col items-center gap-4">
                      {renderAddControl(card, false)}
                      <Button variant="outline" onClick={advanceCard} className="gap-2">
                        <SkipForward className="h-4 w-4" />
                        Next
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            </RvCard>
          </div>
        )}
      </main>
    </div>
  );
}
