import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Clock, ArrowLeft, AlertCircle } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import StudyMode from '@/components/flashcards/StudyMode';
import { useToast } from '@/hooks/use-toast';

export default function ReviewSession() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(true);
  const [dueCards, setDueCards] = useState([]);
  const [showStudyMode, setShowStudyMode] = useState(false);

  useEffect(() => {
    fetchDueCards();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchDueCards = async () => {
    try {
      if (!user) {
        navigate('/login');
        return;
      }

      // Step 1: Get all flashcard IDs this user has reviewed
      const { data: reviews, error: reviewsError } = await supabase
        .from('reviews')
        .select('flashcard_id')
        .eq('user_id', user.id);

      if (reviewsError) throw reviewsError;

      const reviewedCardIds = reviews?.map(r => r.flashcard_id) || [];

      if (reviewedCardIds.length === 0) {
        // User hasn't reviewed any cards yet
        setLoading(false);
        return;
      }

      // Step 2: Get flashcards that are due for review RIGHT NOW
      const { data: cards, error: cardsError } = await supabase
        .from('flashcards')
        .select(`
          id,
          user_id,
          contributed_by,
          target_course,
          subject_id,
          custom_subject,
          topic_id,
          custom_topic,
          front_text,
          front_image_url,
          back_text,
          back_image_url,
          difficulty,
          is_verified,
          next_review,
          interval,
          ease_factor,
          repetitions,
          subjects:subject_id (id, name),
          topics:topic_id (id, name),
          contributors:contributed_by (id, full_name, role)
        `)
        .in('id', reviewedCardIds)
        .lte('next_review', new Date().toISOString())
        .order('next_review', { ascending: true });

      if (cardsError) throw cardsError;

      if (!cards || cards.length === 0) {
        // No cards due right now
        toast({
          title: "All Caught Up! 🎉",
          description: "No cards are due for review right now.",
        });
        setLoading(false);
        return;
      }

      // Clean diamond characters from text
      const cleanedCards = cards.map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        custom_subject: card.custom_subject?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null,
        custom_topic: card.custom_topic?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null
      }));

      setDueCards(cleanedCards);
      setShowStudyMode(true); // Automatically start study mode

    } catch (error) {
      console.error('Error fetching due cards:', error);
      toast({
        title: "Error",
        description: "Failed to load review session. Please try again.",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const handleStudyComplete = () => {
    toast({
      title: "Review Complete! 🎉",
      description: `You've reviewed ${dueCards.length} card${dueCards.length > 1 ? 's' : ''}.`,
    });
    navigate('/dashboard');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading your review session...</p>
        </div>
      </div>
    );
  }

  // No cards due - Show empty state
  if (dueCards.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {/* Back Button */}
          <Button
            variant="ghost"
            onClick={() => navigate('/dashboard')}
            className="mb-6"
          >
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Dashboard
          </Button>

          {/* Empty State */}
          <Card>
            <CardContent className="py-12 text-center">
              <div className="mb-6">
                <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
                  <Clock className="h-8 w-8 text-green-600" />
                </div>
                <h2 className="text-2xl font-bold text-gray-900 mb-2">
                  All Caught Up! 🎉
                </h2>
                <p className="text-gray-600 mb-6">
                  No cards are due for review right now. Great work on staying on top of your studies!
                </p>
                <div className="space-y-3">
                  <Button onClick={() => navigate('/dashboard')}>
                    Return to Dashboard
                  </Button>
                  <div>
                    <Button
                      variant="outline"
                      onClick={() => navigate('/dashboard/review-flashcards')}
                    >
                      Practice Anyway
                    </Button>
                  </div>
                </div>
              </div>

              {/* Info Box */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mt-6">
                <div className="flex items-start gap-3 text-left">
                  <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 flex-shrink-0" />
                  <div className="text-sm text-blue-900">
                    <p className="font-medium mb-1">How Review Sessions Work</p>
                    <p className="text-blue-700">
                      Cards appear here when they're scheduled for review based on how well you 
                      remembered them. Easy cards come back in 7 days, medium in 3 days, and hard 
                      cards come back tomorrow.
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // Show study mode with due cards
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-6">
          <div className="flex items-center justify-between mb-4">
            <Button
              variant="ghost"
              onClick={() => navigate('/dashboard')}
              size="sm"
            >
              <ArrowLeft className="mr-2 h-4 w-4" />
              Exit Review
            </Button>
            <div className="flex items-center gap-2 text-sm text-gray-600">
              <Clock className="h-4 w-4" />
              <span>Review Session</span>
            </div>
          </div>

          {/* Review Mode Indicator */}
          <div className="bg-blue-100 border border-blue-300 rounded-lg p-3 mb-4">
            <div className="flex items-center gap-2">
              <Clock className="h-5 w-5 text-blue-600" />
              <span className="font-medium text-blue-800">
                Review Mode: {dueCards.length} card{dueCards.length > 1 ? 's' : ''} due for review
              </span>
            </div>
          </div>
        </div>

        {/* Study Mode Component */}
        {showStudyMode && (
          <StudyMode
            flashcards={dueCards}
            onComplete={handleStudyComplete}
            onExit={() => navigate('/dashboard')}
          />
        )}
      </div>
    </div>
  );
}