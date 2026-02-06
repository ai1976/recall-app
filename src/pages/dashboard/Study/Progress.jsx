import React, { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Calendar,
  TrendingUp,
  Target,
  Award,
  PauseCircle,
  PlayCircle,
  ChevronDown,
  ChevronRight,
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

// ============================================================
// HELPER: Format date as YYYY-MM-DD in user's LOCAL timezone
// ============================================================
const formatLocalDate = (date) => {
  return new Date(date).toLocaleDateString('en-CA');
};

export default function MyProgress() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [stats, setStats] = useState({
    studyStreak: 0,
    cardsReviewed: 0,
    accuracy: 0,
    totalMastered: 0,
    loading: true
  });

  // Suspended cards state
  const [suspendedCards, setSuspendedCards] = useState([]);
  const [suspendedLoading, setSuspendedLoading] = useState(true);
  const [suspendedExpanded, setSuspendedExpanded] = useState(false);
  const [unsuspendDialog, setUnsuspendDialog] = useState({ open: false, card: null });

  const fetchProgressStats = async () => {
    if (!user) return;

    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const { data: reviews, error: reviewsError } = await supabase
        .from('reviews')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .gte('created_at', sevenDaysAgo.toISOString());

      if (reviewsError) throw reviewsError;

      const cardsReviewed = reviews?.length || 0;

      const correctReviews = reviews?.filter(r => r.quality >= 3).length || 0;
      const accuracy = cardsReviewed > 0
        ? Math.round((correctReviews / cardsReviewed) * 100)
        : 0;

      const studyStreak = await calculateStudyStreak(user.id);

      const uniqueCards = new Set(reviews?.map(r => r.flashcard_id));
      const totalMastered = uniqueCards.size;

      setStats({
        studyStreak,
        cardsReviewed,
        accuracy,
        totalMastered,
        loading: false
      });

    } catch (err) {
      console.error('Error fetching progress stats:', err);
      setStats(prev => ({ ...prev, loading: false }));
    }
  };

  const fetchSuspendedCards = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('get_suspended_cards', {
        p_user_id: user.id
      });

      if (error) throw error;

      setSuspendedCards(data || []);
    } catch (err) {
      console.error('Error fetching suspended cards:', err);
    } finally {
      setSuspendedLoading(false);
    }
  };

  useEffect(() => {
    if (user) {
      fetchProgressStats();
      fetchSuspendedCards();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  // ============================================================
  // Calculate study streak using user's LOCAL timezone
  // Only counts active reviews (not suspended)
  // ============================================================
  const calculateStudyStreak = async (userId) => {
    try {
      const { data: reviews, error } = await supabase
        .from('reviews')
        .select('created_at')
        .eq('user_id', userId)
        .eq('status', 'active')
        .gt('quality', 0)
        .order('created_at', { ascending: false });

      if (error || !reviews || reviews.length === 0) return 0;

      const dates = reviews.map(r => formatLocalDate(r.created_at));
      const uniqueDates = [...new Set(dates)];

      const today = formatLocalDate(new Date());

      const yesterdayDate = new Date();
      yesterdayDate.setDate(yesterdayDate.getDate() - 1);
      const yesterday = formatLocalDate(yesterdayDate);

      if (uniqueDates[0] !== today && uniqueDates[0] !== yesterday) {
        return 0;
      }

      let streak = 0;
      let currentDate = new Date();

      if (uniqueDates[0] === yesterday) {
        currentDate.setDate(currentDate.getDate() - 1);
      }

      for (let i = 0; i < 365; i++) {
        const checkDateStr = formatLocalDate(currentDate);

        if (uniqueDates.includes(checkDateStr)) {
          streak++;
          currentDate.setDate(currentDate.getDate() - 1);
        } else {
          break;
        }
      }

      return streak;

    } catch (err) {
      console.error('Error calculating streak:', err);
      return 0;
    }
  };

  // ============================================================
  // Unsuspend a card
  // ============================================================
  const handleUnsuspend = async (card) => {
    try {
      const { error } = await supabase.rpc('unsuspend_card', {
        p_user_id: user.id,
        p_flashcard_id: card.flashcard_id
      });

      if (error) throw error;

      toast({
        title: "Card unsuspended",
        description: "This card is now active and due for review today.",
      });

      // Remove from local state
      setSuspendedCards(prev => prev.filter(c => c.flashcard_id !== card.flashcard_id));
      setUnsuspendDialog({ open: false, card: null });

    } catch (err) {
      console.error('Error unsuspending card:', err);
      toast({
        title: "Error",
        description: "Failed to unsuspend card.",
        variant: "destructive"
      });
    }
  };

  // Group suspended cards by subject
  const groupedSuspended = suspendedCards.reduce((acc, card) => {
    const subject = card.subject_name || 'General';
    if (!acc[subject]) acc[subject] = [];
    acc[subject].push(card);
    return acc;
  }, {});

  if (stats.loading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">My Progress</h1>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Study Streak */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <Calendar className="h-8 w-8 text-orange-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.studyStreak}</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Study Streak</h3>
            <p className="text-xs text-gray-500 mt-1">Consecutive days</p>
          </div>

          {/* Cards Reviewed */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <TrendingUp className="h-8 w-8 text-blue-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.cardsReviewed}</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Cards Reviewed</h3>
            <p className="text-xs text-gray-500 mt-1">Last 7 days</p>
          </div>

          {/* Accuracy */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <Target className="h-8 w-8 text-green-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.accuracy}%</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Accuracy</h3>
            <p className="text-xs text-gray-500 mt-1">Last 7 days</p>
          </div>

          {/* Total Mastered */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <Award className="h-8 w-8 text-purple-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.totalMastered}</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Cards Mastered</h3>
            <p className="text-xs text-gray-500 mt-1">Unique cards reviewed</p>
          </div>
        </div>

        {/* Empty State */}
        {stats.cardsReviewed === 0 && suspendedCards.length === 0 && (
          <div className="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
            <p className="text-blue-800 mb-2">
              <strong>No reviews yet!</strong>
            </p>
            <p className="text-sm text-blue-700">
              Start reviewing flashcards to see your progress statistics.
            </p>
          </div>
        )}

        {/* ============================================================ */}
        {/* SUSPENDED CARDS SECTION */}
        {/* ============================================================ */}
        {!suspendedLoading && suspendedCards.length > 0 && (
          <div className="mt-8">
            <button
              onClick={() => setSuspendedExpanded(!suspendedExpanded)}
              className="w-full flex items-center justify-between bg-amber-50 border border-amber-200 rounded-lg p-4 hover:bg-amber-100 transition-colors"
            >
              <div className="flex items-center gap-3">
                <PauseCircle className="h-5 w-5 text-amber-600" />
                <div className="text-left">
                  <h3 className="font-semibold text-amber-900">
                    Suspended Cards ({suspendedCards.length})
                  </h3>
                  <p className="text-xs text-amber-700">
                    These cards are hidden from your review queue
                  </p>
                </div>
              </div>
              {suspendedExpanded ? (
                <ChevronDown className="h-5 w-5 text-amber-600" />
              ) : (
                <ChevronRight className="h-5 w-5 text-amber-600" />
              )}
            </button>

            {suspendedExpanded && (
              <div className="mt-2 space-y-4">
                {Object.entries(groupedSuspended).map(([subject, cards]) => (
                  <div key={subject} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                    <div className="bg-gray-50 px-4 py-2 border-b border-gray-200">
                      <h4 className="text-sm font-semibold text-gray-700">
                        {subject} ({cards.length})
                      </h4>
                    </div>
                    <div className="divide-y divide-gray-100">
                      {cards.map((card) => (
                        <div
                          key={card.flashcard_id}
                          className="px-4 py-3 flex items-center justify-between gap-4"
                        >
                          <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-gray-900 truncate">
                              {card.front_text}
                            </p>
                            {card.topic_name && (
                              <p className="text-xs text-gray-500 mt-0.5">
                                {card.topic_name}
                              </p>
                            )}
                          </div>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setUnsuspendDialog({ open: true, card })}
                            className="gap-1 shrink-0 text-green-700 border-green-300 hover:bg-green-50 hover:border-green-400"
                          >
                            <PlayCircle className="h-3.5 w-3.5" />
                            Unsuspend
                          </Button>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Unsuspend Confirmation Dialog */}
      <Dialog
        open={unsuspendDialog.open}
        onOpenChange={(open) => setUnsuspendDialog(prev => ({ ...prev, open }))}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Unsuspend this card?</DialogTitle>
            <DialogDescription>
              This card will be reactivated and scheduled for review today.
              {unsuspendDialog.card && (
                <span className="block mt-2 font-medium text-gray-700">
                  &ldquo;{unsuspendDialog.card.front_text?.substring(0, 100)}
                  {unsuspendDialog.card.front_text?.length > 100 ? '...' : ''}&rdquo;
                </span>
              )}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setUnsuspendDialog({ open: false, card: null })}
            >
              Cancel
            </Button>
            <Button
              onClick={() => handleUnsuspend(unsuspendDialog.card)}
              className="bg-green-600 hover:bg-green-700"
            >
              <PlayCircle className="h-4 w-4 mr-2" />
              Unsuspend
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
