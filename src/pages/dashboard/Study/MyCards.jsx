import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
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
import { PauseCircle, PlayCircle, X, Award, BookMarked, Plus, Compass } from 'lucide-react';

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

export default function MyCards() {
  const { user } = useAuth();
  const { toast } = useToast();
  const navigate = useNavigate();

  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [cards, setCards] = useState([]); // enriched: { ...flashcard, is_own, reviewStatus }
  const [subjectNames, setSubjectNames] = useState({});
  const [topicNames, setTopicNames] = useState({});
  const [busyId, setBusyId] = useState(null);

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

      const subjectIds = [...new Set(enriched.map((c) => c.subject_id).filter(Boolean))];
      const topicIds = [...new Set(enriched.map((c) => c.topic_id).filter(Boolean))];
      if (subjectIds.length > 0) {
        const { data } = await supabase.from('subjects').select('id, name').in('id', subjectIds);
        setSubjectNames(Object.fromEntries((data || []).map((s) => [s.id, s.name])));
      }
      if (topicIds.length > 0) {
        const { data } = await supabase.from('topics').select('id, name').in('id', topicIds);
        setTopicNames(Object.fromEntries((data || []).map((t) => [t.id, t.name])));
      }
    } catch (err) {
      console.error('Failed to load My Cards:', err);
      setLoadError('Could not load My Cards. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (user) fetchMyCards();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  const handlePause = async (card) => {
    setBusyId(card.id);
    try {
      const { error } = await supabase.rpc('suspend_card', { p_user_id: user.id, p_flashcard_id: card.id });
      if (error) throw error;
      setCards((prev) => prev.map((c) => (c.id === card.id ? { ...c, reviewStatus: 'suspended' } : c)));
      toast({ title: 'Card paused', description: 'It stays in My Cards but will not be scheduled until you resume it.' });
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
      toast({ title: 'Removed from My Cards', description: 'You can add it again later from Practice.' });
    } catch {
      toast({ title: 'Could not remove this card', variant: 'destructive' });
    } finally {
      setBusyId(null);
      setRemoveDialog({ open: false, card: null });
    }
  };

  const renderActions = (card) => {
    const { key, isOwn } = deriveState(card, card.reviewStatus);
    const busy = busyId === card.id;

    if (key === 'new') {
      return isOwn ? null : (
        <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setRemoveDialog({ open: true, card })}>
          <X className="h-3.5 w-3.5" />
          Remove
        </Button>
      );
    }
    if (key === 'mastered') {
      return (
        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-rec bg-rv-navy-50 text-rv-navy text-xs font-semibold">
            <Award className="h-3.5 w-3.5" />
            Mastered
          </span>
          {!isOwn && (
            <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setRemoveDialog({ open: true, card })}>
              <X className="h-3.5 w-3.5" />
              Remove
            </Button>
          )}
        </div>
      );
    }
    if (key === 'active') {
      return (
        <div className="flex items-center gap-2">
          <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setPauseDialog({ open: true, card })}>
            <PauseCircle className="h-3.5 w-3.5" />
            Pause
          </Button>
          {!isOwn && (
            <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setRemoveDialog({ open: true, card })}>
              <X className="h-3.5 w-3.5" />
              Remove
            </Button>
          )}
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
          {!isOwn && (
            <Button size="sm" variant="outline" className="gap-1.5" disabled={busy} onClick={() => setRemoveDialog({ open: true, card })}>
              <X className="h-3.5 w-3.5" />
              Remove
            </Button>
          )}
        </div>
      );
    }
    return null;
  };

  const statusBadge = (card) => {
    const { key } = deriveState(card, card.reviewStatus);
    const map = {
      new: { label: 'New', cls: 'bg-rv-bg-2 text-rv-ink-600' },
      active: { label: 'Active', cls: 'bg-rv-navy-50 text-rv-navy' },
      suspended: { label: 'Paused', cls: 'bg-amber-50 text-amber-700' },
      mastered: { label: 'Mastered', cls: 'bg-rv-navy-50 text-rv-navy' },
    };
    const { label, cls } = map[key] || map.new;
    return <span className={`inline-block px-2 py-0.5 rounded-rec text-[11px] font-semibold ${cls}`}>{label}</span>;
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-rv-bg-0">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-rv-navy"></div>
      </div>
    );
  }

  return (
    <PageContainer width="medium">
      <h1 className="text-2xl font-semibold text-rv-ink-900 mb-6">My Cards</h1>
      {loadError ? (
        <RvCard className="p-8 text-center">
          <p className="text-rv-ink-600 mb-4">{loadError}</p>
          <Button onClick={fetchMyCards}>Try again</Button>
        </RvCard>
      ) : cards.length === 0 ? (
        <RvCard className="p-10 text-center">
          <BookMarked className="h-14 w-14 text-rv-ink-400 mx-auto mb-4" />
          <h2 className="text-xl font-semibold text-rv-ink-900 mb-2">No cards in My Cards yet</h2>
          <p className="text-rv-ink-600 mb-6 max-w-md mx-auto">
            Cards you create are added automatically once you start reviewing them. You can also add
            cards created by others from Practice.
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
        <div className="space-y-3">
          <p className="text-sm text-rv-ink-400">{cards.length} card{cards.length === 1 ? '' : 's'} in your personal review collection</p>
          {cards.map((card) => (
            <RvCard key={card.id} className="p-4 flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4">
              <div className="flex-1 min-w-0">
                <div className="flex flex-wrap items-center gap-2 mb-1.5">
                  {statusBadge(card)}
                  <span className="text-[11px] font-medium text-rv-ink-400">{formatQuestionType(card.question_type)}</span>
                  <span className={`text-[11px] font-medium ${card.is_own ? 'text-rv-ink-400' : 'text-rv-navy'}`}>
                    {card.is_own ? 'Yours' : 'Added from Practice'}
                  </span>
                </div>
                <p className="text-sm text-rv-ink-900 line-clamp-2">{card.front_text}</p>
                {(card.custom_subject || subjectNames[card.subject_id]) && (
                  <p className="text-xs text-rv-ink-400 mt-1">
                    {card.custom_subject || subjectNames[card.subject_id]}
                    {(card.custom_topic || topicNames[card.topic_id]) && ` • ${card.custom_topic || topicNames[card.topic_id]}`}
                  </p>
                )}
              </div>
              <div className="shrink-0">{renderActions(card)}</div>
            </RvCard>
          ))}
        </div>
      )}

      {/* Pause confirmation */}
      <Dialog open={pauseDialog.open} onOpenChange={(open) => setPauseDialog((prev) => ({ ...prev, open }))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pause this card?</DialogTitle>
            <DialogDescription>
              It stays in My Cards and its review history is preserved, but scheduled reviews stop
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
            <DialogTitle>Remove this item from My Cards?</DialogTitle>
            <DialogDescription>
              It will stop appearing in your personal review collection. Previous review history is
              preserved if any exists. The source content remains available through Practice while
              access remains valid, and you can add it again later.
            </DialogDescription>
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
