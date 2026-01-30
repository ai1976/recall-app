import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Clock, ArrowLeft, BookOpen, AlertCircle } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';

// ============================================================
// HELPER: Format date as YYYY-MM-DD in user's LOCAL timezone
// Using 'en-CA' locale gives us ISO format (YYYY-MM-DD) which
// allows correct string comparison for dates.
// ============================================================
const formatLocalDate = (date) => {
  return new Date(date).toLocaleDateString('en-CA');
};

export default function ReviewBySubject() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(true);
  const [subjectGroups, setSubjectGroups] = useState([]);
  const [totalDueCards, setTotalDueCards] = useState(0);

  useEffect(() => {
    fetchDueCardsBySubject();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchDueCardsBySubject = async () => {
    try {
      if (!user) {
        navigate('/login');
        return;
      }

      console.log('✅ Fetching due cards grouped by subject');

      // ✅ FIXED: Get today's date in user's LOCAL timezone (not UTC)
      const todayString = formatLocalDate(new Date());

      // Get due reviews
      const { data: dueReviews, error: reviewsError } = await supabase
        .from('reviews')
        .select('flashcard_id, next_review_date')
        .eq('user_id', user.id)
        .lte('next_review_date', todayString);

      if (reviewsError) throw reviewsError;

      if (!dueReviews || dueReviews.length === 0) {
        setLoading(false);
        return;
      }

      const dueCardIds = dueReviews.map(r => r.flashcard_id);

      // Get flashcards with subject info
      const { data: cards, error: cardsError } = await supabase
        .from('flashcards')
        .select(`
          id,
          subject_id,
          custom_subject,
          target_course,
          subjects:subject_id (id, name)
        `)
        .in('id', dueCardIds);

      if (cardsError) throw cardsError;

      // Group by subject
      const grouped = {};
      cards.forEach(card => {
        const subjectName = card.subjects?.name || card.custom_subject || 'Other';
        const subjectId = card.subject_id || `custom_${subjectName}`;
        
        if (!grouped[subjectId]) {
          grouped[subjectId] = {
            id: subjectId,
            name: subjectName,
            course: card.target_course,
            cardIds: [],
            count: 0
          };
        }
        grouped[subjectId].cardIds.push(card.id);
        grouped[subjectId].count++;
      });

      const subjectList = Object.values(grouped);
      setSubjectGroups(subjectList);
      setTotalDueCards(dueCardIds.length);

      console.log(`✅ Found ${subjectList.length} subjects with ${dueCardIds.length} total cards`);

    } catch (error) {
      console.error('❌ Error fetching due cards by subject:', error);
      toast({
        title: "Error",
        description: "Failed to load subjects. Please try again.",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const startSubjectReview = (subjectCardIds) => {
    // Store card IDs in sessionStorage for ReviewSession to use
    sessionStorage.setItem('reviewCardIds', JSON.stringify(subjectCardIds));
    navigate('/dashboard/review-session');
  };

  const startAllReview = () => {
    // Clear any stored card IDs to review all
    sessionStorage.removeItem('reviewCardIds');
    navigate('/dashboard/review-session');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading subjects...</p>
        </div>
      </div>
    );
  }

  if (subjectGroups.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Button
            variant="ghost"
            onClick={() => navigate('/dashboard')}
            className="mb-6"
          >
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Dashboard
          </Button>

          <Card>
            <CardContent className="py-12 text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
                <Clock className="h-8 w-8 text-green-600" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">
                All Caught Up! 🎉
              </h2>
              <p className="text-gray-600 mb-6">
                No cards are due for review right now.
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
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Button
          variant="ghost"
          onClick={() => navigate('/dashboard')}
          className="mb-6"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Dashboard
        </Button>

        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Review by Subject
          </h1>
          <p className="text-gray-600">
            Choose a subject to focus your review session, or review all subjects together
          </p>
        </div>

        {/* Subject Cards */}
        <div className="grid gap-4 mb-6">
          {subjectGroups.map((subject) => (
            <Card key={subject.id} className="hover:shadow-lg transition-shadow">
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <CardTitle className="text-xl flex items-center gap-2 mb-1">
                      <BookOpen className="h-5 w-5 text-blue-600" />
                      {subject.name}
                    </CardTitle>
                    <div className="flex items-center gap-3 text-sm text-gray-600">
                      {subject.course && (
                        <span className="font-medium">{subject.course}</span>
                      )}
                      <span className="flex items-center gap-1">
                        <Clock className="h-4 w-4" />
                        {subject.count} card{subject.count > 1 ? 's' : ''} due
                      </span>
                    </div>
                  </div>
                  <Button
                    onClick={() => startSubjectReview(subject.cardIds)}
                    className="gap-2"
                  >
                    <Clock className="h-4 w-4" />
                    Review
                  </Button>
                </div>
              </CardHeader>
            </Card>
          ))}
        </div>

        {/* Review All Button */}
        <Card className="border-2 border-blue-200 bg-blue-50">
          <CardContent className="py-6">
            <div className="flex items-center justify-between">
              <div className="flex items-start gap-3">
                <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 flex-shrink-0" />
                <div>
                  <h3 className="font-semibold text-blue-900 mb-1">
                    Review All Subjects Together
                  </h3>
                  <p className="text-sm text-blue-700">
                    Study all {totalDueCards} cards from {subjectGroups.length} subject{subjectGroups.length > 1 ? 's' : ''} in one session
                  </p>
                </div>
              </div>
              <Button
                onClick={startAllReview}
                variant="default"
                size="lg"
                className="gap-2"
              >
                <Clock className="h-4 w-4" />
                Review All ({totalDueCards})
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
