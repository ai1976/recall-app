import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Card as RvCard } from '@/components/revisop';
import { formatQuestionType } from '@/lib/questionTypes';
import {
  PauseCircle, PlayCircle, X, Plus, Compass, ChevronDown, ChevronRight, Award, Undo2,
} from 'lucide-react';

// Same chunk size/pattern StudyMode.jsx established in Sprint 8.7.7 to avoid oversized
// `.in('flashcard_id', ids)` requests (proven safe up to ~700+ ids for this project's largest
// live collections — Sprint 8.7.8d Step 0 diagnostic).
const REVIEW_LOOKUP_CHUNK = 100;

// Sprint 8.7.8d — own concept cards ARE returned by get_my_cards (its own-card branch has no
// question_type filter, by design — the frozen RPC is never touched for this). Concept cards are
// browse-only and never enter SRS (D-06), so they are excluded here, at the presentation layer.
const isConceptCard = (card) => card.question_type === 'concept_card';

const deriveState = (card, reviewStatus) => {
  const isOwn = true === card.is_own;
  if (!reviewStatus) return { key: 'new', isOwn };
  return { key: reviewStatus, isOwn }; // 'active' | 'suspended' | 'mastered'
};

// Sprint 8.7.10 Scope D — Subject → Topic grouping. `counts` tallies New/Active/Paused only
// (Mastered/Removed are shown in the History tab, grouped separately, where a 3-way count isn't
// meaningful since every card there already shares one status).
function groupCards(cards, subjectNames, topicNames) {
  const bySubject = new Map();
  for (const card of cards) {
    const subjectKey = card.subject_id || `custom:${card.custom_subject || 'Other'}`;
    const subjectName = card.custom_subject || subjectNames[card.subject_id] || 'Other';
    if (!bySubject.has(subjectKey)) {
      bySubject.set(subjectKey, {
        key: subjectKey, name: subjectName, topics: new Map(), counts: { new: 0, active: 0, suspended: 0 },
      });
    }
    const subject = bySubject.get(subjectKey);

    const topicKey = card.topic_id || `custom:${card.custom_topic || 'General'}`;
    const topicName = card.custom_topic || topicNames[card.topic_id] || 'General';
    if (!subject.topics.has(topicKey)) {
      subject.topics.set(topicKey, {
        key: topicKey, name: topicName, cards: [], counts: { new: 0, active: 0, suspended: 0 },
      });
    }
    const topic = subject.topics.get(topicKey);
    topic.cards.push(card);

    const { key: stateKey } = deriveState(card, card.reviewStatus);
    if (stateKey in subject.counts) {
      subject.counts[stateKey] += 1;
      topic.counts[stateKey] += 1;
    }
  }

  return Array.from(bySubject.values())
    .map((s) => ({ ...s, topics: Array.from(s.topics.values()).sort((a, b) => a.name.localeCompare(b.name)) }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function CountBadges({ counts }) {
  return (
    <div className="flex items-center gap-1.5 text-[11px] font-medium flex-wrap">
      <span className="px-2 py-0.5 rounded-rec bg-rv-bg-2 text-rv-ink-600">{counts.new} New</span>
      <span className="px-2 py-0.5 rounded-rec bg-rv-navy-50 text-rv-navy">{counts.active} Active</span>
      <span className="px-2 py-0.5 rounded-rec bg-amber-50 text-amber-700">{counts.suspended} Paused</span>
    </div>
  );
}

export default function MyCards() {
  const { user } = useAuth();
  const { toast } = useToast();
  const navigate = useNavigate();

  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [cards, setCards] = useState([]); // enriched: { ...flashcard, is_own, reviewStatus } — excludes concept cards
  const [subjectNames, setSubjectNames] = useState({});
  const [topicNames, setTopicNames] = useState({});
  const [busyId, setBusyId] = useState(null);

  // Sprint 8.7.10 Scope D — Mastered + Removed live in a separate History tab, out of the default
  // working view. Removed cards aren't part of the main get_my_cards fetch at all (that RPC only
  // ever returns active enrollment) — lazy-loaded via get_removed_my_cards on first tab switch,
  // so a page load that never opens History pays zero extra cost.
  const [tab, setTab] = useState('working'); // 'working' | 'history'
  const [removedCards, setRemovedCards] = useState(null); // null = not yet fetched
  const [removedLoading, setRemovedLoading] = useState(false);
  const [removedError, setRemovedError] = useState(null);

  // Subjects default open (shows topic-level counts immediately); topics default closed —
  // "individual-card rows only after opening a topic."
  const [closedSubjects, setClosedSubjects] = useState({});
  const [openTopics, setOpenTopics] = useState({});

  const [pauseDialog, setPauseDialog] = useState({ open: false, card: null });
  const [resumeDialog, setResumeDialog] = useState({ open: false, card: null });
  const [removeDialog, setRemoveDialog] = useState({ open: false, card: null });

  const fetchMyCards = async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const { data: rawCards, error: mcError } = await supabase.rpc('get_my_cards', { p_user_id: user.id });
      if (mcError) throw mcError;

      const nonConcept = (rawCards || []).filter((c) => !isConceptCard(c));

      // Chunked reviews lookup — reuse StudyMode's established pattern, do not recreate the
      // large-set 400 bug fixed in Sprint 8.7.7.
      const ids = nonConcept.map((c) => c.id);
      const reviewsByCardId = {};
      for (let i = 0; i < ids.length; i += REVIEW_LOOKUP_CHUNK) {
        const chunk = ids.slice(i, i + REVIEW_LOOKUP_CHUNK);
        if (chunk.length === 0) continue;
        const { data: reviewRows, error: rErr } = await supabase
          .from('reviews')
          .select('flashcard_id, status')
          .eq('user_id', user.id)
          .in('flashcard_id', chunk);
        if (rErr) throw rErr;
        (reviewRows || []).forEach((r) => { reviewsByCardId[r.flashcard_id] = r.status; });
      }

      const enriched = nonConcept.map((c) => ({
        ...c,
        is_own: c.user_id === user.id,
        reviewStatus: reviewsByCardId[c.id] || null, // null = never graded
      }));

      setCards(enriched);
      await loadNames(enriched, setSubjectNames, setTopicNames);
    } catch (err) {
      console.error('Failed to load My Study:', err);
      setLoadError('Could not load My Study. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const loadNames = async (cardList, setSubjects, setTopics) => {
    const subjectIds = [...new Set(cardList.map((c) => c.subject_id).filter(Boolean))];
    const topicIds = [...new Set(cardList.map((c) => c.topic_id).filter(Boolean))];
    if (subjectIds.length > 0) {
      const { data } = await supabase.from('subjects').select('id, name').in('id', subjectIds);
      setSubjects((prev) => ({ ...prev, ...Object.fromEntries((data || []).map((s) => [s.id, s.name])) }));
    }
    if (topicIds.length > 0) {
      const { data } = await supabase.from('topics').select('id, name').in('id', topicIds);
      setTopics((prev) => ({ ...prev, ...Object.fromEntries((data || []).map((t) => [t.id, t.name])) }));
    }
  };

  useEffect(() => {
    if (user) fetchMyCards();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  const fetchRemovedCards = async () => {
    setRemovedLoading(true);
    setRemovedError(null);
    try {
      const { data, error } = await supabase.rpc('get_removed_my_cards', { p_user_id: user.id });
      if (error) throw error;
      const enriched = (data || [])
        .filter((c) => !isConceptCard(c))
        .map((c) => ({ ...c, is_own: c.user_id === user.id }));
      setRemovedCards(enriched);
      await loadNames(enriched, setSubjectNames, setTopicNames);
    } catch (err) {
      console.error('Failed to load removed items:', err);
      setRemovedError('Could not load your removed items. Please try again.');
    } finally {
      setRemovedLoading(false);
    }
  };

  const handleTabChange = (nextTab) => {
    setTab(nextTab);
    if (nextTab === 'history' && removedCards === null && !removedLoading) {
      fetchRemovedCards();
    }
  };

  const toggleSubject = (key) => setClosedSubjects((prev) => ({ ...prev, [key]: !prev[key] }));
  const toggleTopic = (key) => setOpenTopics((prev) => ({ ...prev, [key]: !prev[key] }));

  const handlePause = async (card) => {
    setBusyId(card.id);
    try {
      const { error } = await supabase.rpc('suspend_card', { p_user_id: user.id, p_flashcard_id: card.id });
      if (error) throw error;
      setCards((prev) => prev.map((c) => (c.id === card.id ? { ...c, reviewStatus: 'suspended' } : c)));
      toast({ title: 'Card paused', description: 'It stays in My Study but will not be scheduled until you resume it.' });
    } catch {
      toast({ title: 'Could not pause this card', variant: 'destructive' });
    } finally {
      setBusyId(null);
      setPauseDialog({ open: false, card: null });
    }
  };

  const handleResume = async (card) => {
    setBusyId(card.id);
    try {
      const { error } = await supabase.rpc('unsuspend_card', { p_user_id: user.id, p_flashcard_id: card.id });
      if (error) throw error;
      setCards((prev) => prev.map((c) => (c.id === card.id ? { ...c, reviewStatus: 'active' } : c)));
      toast({ title: 'Card resumed', description: 'Review scheduling resumes — it is due for review today.' });
    } catch {
      toast({ title: 'Could not resume this card', variant: 'destructive' });
    } finally {
      setBusyId(null);
      setResumeDialog({ open: false, card: null });
    }
  };

  const handleRemove = async (card) => {
    setBusyId(card.id);
    try {
      const { error } = await supabase.rpc('remove_from_my_cards', { p_user_id: user.id, p_flashcard_id: card.id });
      if (error) throw error;
      setCards((prev) => prev.filter((c) => c.id !== card.id));
      // Removed cards move into History — invalidate the lazy cache so it's fetched fresh next open.
      setRemovedCards(null);
      toast({ title: 'Removed from My Study', description: 'Your content and review history are preserved — find it under History, or add it back anytime.' });
    } catch {
      toast({ title: 'Could not remove this card', variant: 'destructive' });
    } finally {
      setBusyId(null);
      setRemoveDialog({ open: false, card: null });
    }
  };

  // Sprint 8.7.10 Scope D — re-add from History, reusing the unchanged add_to_my_cards RPC
  // (already own-card-safe: "a caller passing their own card's id is harmless").
  const handleReAdd = async (card) => {
    setBusyId(card.id);
    try {
      const { error } = await supabase.rpc('add_to_my_cards', { p_user_id: user.id, p_flashcard_id: card.id });
      if (error) throw error;
      setRemovedCards((prev) => (prev || []).filter((c) => c.id !== card.id));
      toast({ title: 'Added to My Study', description: 'Find it in your working list.' });
      fetchMyCards();
    } catch {
      toast({ title: 'Could not add this card', variant: 'destructive' });
    } finally {
      setBusyId(null);
    }
  };

  const removeButton = (card, busy) => (
    <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setRemoveDialog({ open: true, card })}>
      <X className="h-3.5 w-3.5" />
      Remove from My Study
    </Button>
  );

  // Sprint 8.7.10 (D-32): Remove from My Study is now universal — own content is enrollment-based
  // too, so removing it here only ends the study relationship, exactly like external content.
  // Deleting the content itself remains a My Contributions-only action, never offered here.
  const renderActions = (card) => {
    const { key } = deriveState(card, card.reviewStatus);
    const busy = busyId === card.id;

    if (key === 'new') return removeButton(card, busy);
    if (key === 'active') {
      return (
        <div className="flex items-center gap-2">
          <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setPauseDialog({ open: true, card })}>
            <PauseCircle className="h-3.5 w-3.5" />
            Pause
          </Button>
          {removeButton(card, busy)}
        </div>
      );
    }
    if (key === 'suspended') {
      return (
        <div className="flex items-center gap-2">
          <Button size="sm" variant="outline" className="gap-1.5 bg-green-50 hover:bg-green-100 border-green-200" disabled={busy} onClick={() => setResumeDialog({ open: true, card })}>
            <PlayCircle className="h-3.5 w-3.5" />
            Resume
          </Button>
          {removeButton(card, busy)}
        </div>
      );
    }
    return null; // mastered is only ever rendered via renderHistoryActions below
  };

  const renderHistoryActions = (card, status) => {
    const busy = busyId === card.id;
    if (status === 'mastered') return removeButton(card, busy);
    return (
      <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => handleReAdd(card)}>
        <Undo2 className="h-3.5 w-3.5" />
        Add to My Study
      </Button>
    );
  };

  const statusBadge = (card) => {
    const { key } = deriveState(card, card.reviewStatus);
    const map = {
      new: { label: 'New', cls: 'bg-rv-bg-2 text-rv-ink-600' },
      active: { label: 'Active', cls: 'bg-rv-navy-50 text-rv-navy' },
      suspended: { label: 'Paused', cls: 'bg-amber-50 text-amber-700' },
    };
    const { label, cls } = map[key] || map.new;
    return <span className={`inline-block px-2 py-0.5 rounded-rec text-[11px] font-semibold ${cls}`}>{label}</span>;
  };

  // Shared Subject → Topic renderer. `badge`/`actions` are per-card render functions so Working
  // and History can share the exact same grouping/collapse behavior with different card chrome.
  const renderGroups = (groups, { showCounts, badge, actions }) => (
    <div className="space-y-3">
      {groups.map((subject) => {
        const isClosed = !!closedSubjects[subject.key];
        const totalCards = subject.topics.reduce((sum, t) => sum + t.cards.length, 0);
        return (
          <RvCard key={subject.key} className="overflow-hidden">
            <button
              type="button"
              onClick={() => toggleSubject(subject.key)}
              className="w-full flex items-center justify-between gap-3 p-4 text-left hover:bg-rv-bg-2 transition-colors"
            >
              <div className="flex items-center gap-2 min-w-0">
                {isClosed ? <ChevronRight className="h-4 w-4 text-rv-ink-400 shrink-0" /> : <ChevronDown className="h-4 w-4 text-rv-ink-400 shrink-0" />}
                <span className="font-semibold text-rv-ink-900 truncate">{subject.name}</span>
              </div>
              {showCounts ? <CountBadges counts={subject.counts} /> : (
                <span className="text-[11px] font-medium px-2 py-0.5 rounded-rec bg-rv-bg-2 text-rv-ink-600 shrink-0">{totalCards} item{totalCards === 1 ? '' : 's'}</span>
              )}
            </button>
            {!isClosed && (
              <div className="border-t border-rv-bg-2 divide-y divide-rv-bg-2">
                {subject.topics.map((topic) => {
                  const topicOpen = !!openTopics[topic.key];
                  return (
                    <div key={topic.key}>
                      <button
                        type="button"
                        onClick={() => toggleTopic(topic.key)}
                        className="w-full flex items-center justify-between gap-3 px-4 py-3 pl-9 text-left hover:bg-rv-bg-2 transition-colors"
                      >
                        <div className="flex items-center gap-2 min-w-0">
                          {topicOpen ? <ChevronDown className="h-3.5 w-3.5 text-rv-ink-400 shrink-0" /> : <ChevronRight className="h-3.5 w-3.5 text-rv-ink-400 shrink-0" />}
                          <span className="text-sm text-rv-ink-900 truncate">{topic.name}</span>
                        </div>
                        {showCounts ? <CountBadges counts={topic.counts} /> : (
                          <span className="text-[11px] font-medium px-2 py-0.5 rounded-rec bg-rv-bg-2 text-rv-ink-600 shrink-0">{topic.cards.length}</span>
                        )}
                      </button>
                      {topicOpen && (
                        <div className="bg-rv-bg-0 px-4 pb-3 pl-9 space-y-2">
                          {topic.cards.map((card) => (
                            <RvCard key={card.id} className="p-3 flex flex-col sm:flex-row sm:items-center gap-3">
                              <div className="flex-1 min-w-0">
                                <div className="flex flex-wrap items-center gap-2 mb-1">
                                  {badge(card)}
                                  <span className="text-[11px] font-medium text-rv-ink-400">{formatQuestionType(card.question_type)}</span>
                                  <span className={`text-[11px] font-medium ${card.is_own ? 'text-rv-ink-400' : 'text-rv-navy'}`}>
                                    {card.is_own ? 'Yours' : 'Added from Practice'}
                                  </span>
                                </div>
                                <p className="text-sm text-rv-ink-900 line-clamp-2">{card.front_text}</p>
                              </div>
                              <div className="shrink-0">{actions(card)}</div>
                            </RvCard>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </RvCard>
        );
      })}
    </div>
  );

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-rv-bg-0">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-rv-navy"></div>
      </div>
    );
  }

  const workingCards = cards.filter((c) => deriveState(c, c.reviewStatus).key !== 'mastered');
  const masteredCards = cards.filter((c) => deriveState(c, c.reviewStatus).key === 'mastered');
  const groupedWorking = groupCards(workingCards, subjectNames, topicNames);
  const groupedMastered = groupCards(masteredCards, subjectNames, topicNames);
  const groupedRemoved = removedCards ? groupCards(removedCards, subjectNames, topicNames) : [];

  return (
    <PageContainer width="medium">
      <h1 className="text-2xl font-semibold text-rv-ink-900 mb-1">My Study</h1>
      <p className="text-sm text-rv-ink-400 mb-6">Cards you've deliberately added to study — organized by subject and topic.</p>

      {/* Working / History tabs */}
      <div className="flex items-center gap-1 mb-6 border-b border-rv-bg-2">
        <button
          type="button"
          onClick={() => handleTabChange('working')}
          className={`px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors ${tab === 'working' ? 'border-rv-navy text-rv-navy' : 'border-transparent text-rv-ink-400 hover:text-rv-ink-600'}`}
        >
          Working ({workingCards.length})
        </button>
        <button
          type="button"
          onClick={() => handleTabChange('history')}
          className={`px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors ${tab === 'history' ? 'border-rv-navy text-rv-navy' : 'border-transparent text-rv-ink-400 hover:text-rv-ink-600'}`}
        >
          History
        </button>
      </div>

      {loadError ? (
        <RvCard className="p-8 text-center">
          <p className="text-rv-ink-600 mb-4">{loadError}</p>
          <Button onClick={fetchMyCards}>Try again</Button>
        </RvCard>
      ) : tab === 'working' ? (
        workingCards.length === 0 ? (
          <RvCard className="p-10 text-center">
            <Compass className="h-14 w-14 text-rv-ink-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-rv-ink-900 mb-2">Nothing in My Study yet</h2>
            <p className="text-rv-ink-600 mb-6 max-w-md mx-auto">
              Choose "Save &amp; Add to My Study" when you create a card, or add cards created by
              others from Practice.
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3">
              <Button onClick={() => navigate('/dashboard/flashcards/new')} className="gap-2">
                <Plus className="h-4 w-4" />
                Create a card
              </Button>
              <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')} className="gap-2">
                <Compass className="h-4 w-4" />
                Browse & Practice
              </Button>
            </div>
          </RvCard>
        ) : (
          renderGroups(groupedWorking, { showCounts: true, badge: statusBadge, actions: renderActions })
        )
      ) : (
        // History tab
        <div className="space-y-8">
          <div>
            <h2 className="text-sm font-semibold text-rv-ink-600 mb-2 flex items-center gap-1.5">
              <Award className="h-4 w-4" />
              Mastered ({masteredCards.length})
            </h2>
            {masteredCards.length === 0 ? (
              <p className="text-sm text-rv-ink-400">Nothing mastered yet.</p>
            ) : (
              renderGroups(groupedMastered, { showCounts: false, badge: () => (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-rec bg-rv-navy-50 text-rv-navy text-[11px] font-semibold">
                  <Award className="h-3 w-3" />
                  Mastered
                </span>
              ), actions: (card) => renderHistoryActions(card, 'mastered') })
            )}
          </div>

          <div>
            <h2 className="text-sm font-semibold text-rv-ink-600 mb-2 flex items-center gap-1.5">
              <Undo2 className="h-4 w-4" />
              Removed
            </h2>
            {removedLoading ? (
              <div className="flex items-center justify-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-rv-navy"></div>
              </div>
            ) : removedError ? (
              <RvCard className="p-6 text-center">
                <p className="text-rv-ink-600 mb-3">{removedError}</p>
                <Button onClick={fetchRemovedCards}>Try again</Button>
              </RvCard>
            ) : (removedCards || []).length === 0 ? (
              <p className="text-sm text-rv-ink-400">Nothing removed.</p>
            ) : (
              renderGroups(groupedRemoved, { showCounts: false, badge: () => (
                <span className="inline-block px-2 py-0.5 rounded-rec bg-rv-bg-2 text-rv-ink-400 text-[11px] font-semibold">Removed</span>
              ), actions: (card) => renderHistoryActions(card, 'removed') })
            )}
          </div>
        </div>
      )}

      {/* Pause confirmation */}
      <Dialog open={pauseDialog.open} onOpenChange={(open) => setPauseDialog((prev) => ({ ...prev, open }))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pause this card?</DialogTitle>
            <DialogDescription>
              It stays in My Study and its review history is preserved, but scheduled reviews stop
              until you resume it.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPauseDialog({ open: false, card: null })}>Cancel</Button>
            <Button onClick={() => handlePause(pauseDialog.card)}>
              <PauseCircle className="h-4 w-4 mr-2" />
              Pause
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Resume confirmation */}
      <Dialog open={resumeDialog.open} onOpenChange={(open) => setResumeDialog((prev) => ({ ...prev, open }))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Resume this card?</DialogTitle>
            <DialogDescription>Review scheduling resumes — it will be due for review today.</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setResumeDialog({ open: false, card: null })}>Cancel</Button>
            <Button onClick={() => handleResume(resumeDialog.card)} className="bg-green-600 hover:bg-green-700">
              <PlayCircle className="h-4 w-4 mr-2" />
              Resume
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Remove confirmation */}
      <Dialog open={removeDialog.open} onOpenChange={(open) => setRemoveDialog((prev) => ({ ...prev, open }))}>
        <DialogContent>
          <DialogHeader>
            {removeDialog.card?.reviewStatus === 'mastered' ? (
              <>
                <DialogTitle>Remove this mastered card from My Study?</DialogTitle>
                <DialogDescription>
                  It will move to History → Removed. Your previous review history will be preserved,
                  but if you add it again later it will return to active review rather than remain
                  Mastered.
                </DialogDescription>
              </>
            ) : (
              <>
                <DialogTitle>Remove this item from My Study?</DialogTitle>
                <DialogDescription>
                  {removeDialog.card?.is_own
                    ? 'It stays in My Contributions — this only ends the study relationship. It moves to History → Removed, and you can add it back anytime.'
                    : 'It will stop appearing in your working list and move to History → Removed. Previous review history is preserved if any exists, and you can add it again later.'}
                </DialogDescription>
              </>
            )}
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRemoveDialog({ open: false, card: null })}>Cancel</Button>
            <Button variant="destructive" onClick={() => handleRemove(removeDialog.card)}>
              <X className="h-4 w-4 mr-2" />
              Remove
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageContainer>
  );
}
