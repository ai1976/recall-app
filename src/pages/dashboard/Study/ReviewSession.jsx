import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Clock, ArrowLeft, AlertCircle, Play, BookOpen } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import StudyMode from '@/components/flashcards/StudyMode';
import { useToast } from '@/hooks/use-toast';

export default function ReviewSession() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();
  
  const [loading, setLoading] = useState(true);
  const [dueCards, setDueCards] = useState([]);
  
  // Grouping State
  const [groupedCards, setGroupedCards] = useState({});
  const [activeSessionCards, setActiveSessionCards] = useState(null);
  const [activeSubjectName, setActiveSubjectName] = useState('');

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

      console.log('🔄 Fetching scheduled + new cards...');

      const todayStr = new Date().toISOString().split('T')[0];

      // 1. Get Scheduled Reviews (Due Today or earlier)
      const { data: dueReviews, error: reviewsError } = await supabase
        .from('reviews')
        .select('flashcard_id')
        .eq('user_id', user.id)
        .lte('next_review_date', todayStr);

      if (reviewsError) throw reviewsError;
      
      // 2. Get All Tracked IDs (to identify new cards)
      const { data: allReviews } = await supabase
        .from('reviews')
        .select('flashcard_id')
        .eq('user_id', user.id);
        
      const scheduledIds = dueReviews?.map(r => r.flashcard_id) || [];
      const trackedIds = allReviews?.map(r => r.flashcard_id) || [];

      // 3. Fetch Visible Flashcards (Using RLS + Friendship logic)
      // Get accepted friends first
      const { data: friendships } = await supabase
        .from('friendships')
        .select('user_id, friend_id')
        .eq('status', 'accepted')
        .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`);
        
      const friendIds = friendships?.map(f => f.user_id === user.id ? f.friend_id : f.user_id) || [];
      
      let query = supabase.from('flashcards').select(`
          id,
          user_id,
          front_text,
          back_text,
          subjects:subject_id (id, name),
          custom_subject,
          visibility
        `);

      if (friendIds.length > 0) {
        query = query.or(`visibility.eq.public,user_id.eq.${user.id},and(visibility.eq.friends,user_id.in.(${friendIds.join(',')}))`);
      } else {
        query = query.or(`visibility.eq.public,user_id.eq.${user.id}`);
      }

      const { data: allVisibleCards, error: cardsError } = await query;
      if (cardsError) throw cardsError;

      // 4. Filter for New Cards (Visible - Tracked)
      const newCards = (allVisibleCards || []).filter(c => !trackedIds.includes(c.id));
      
      // 5. Get Content for Scheduled Cards
      const scheduledCards = (allVisibleCards || []).filter(c => scheduledIds.includes(c.id));

      // 6. Combine
      const totalSession = [...scheduledCards, ...newCards];

      console.log(`✅ Found: ${scheduledCards.length} Scheduled + ${newCards.length} New = ${totalSession.length} Total`);

      if (totalSession.length === 0) {
        setLoading(false);
        setDueCards([]);
        return;
      }

      // Clean text
      const cleanedCards = totalSession.map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆]/g, '').trim() || ''
      }));

      setDueCards(cleanedCards);
      groupCardsBySubject(cleanedCards);

    } catch (error) {
      console.error('Error fetching due cards:', error);
      toast({
        title: "Error",
        description: "Failed to load review session.",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const groupCardsBySubject = (cards) => {
    const groups = {};
    
    cards.forEach(card => {
      const subjectName = card.subjects?.name || card.custom_subject || 'General';
      
      if (!groups[subjectName]) {
        groups[subjectName] = [];
      }
      groups[subjectName].push(card);
    });
    
    setGroupedCards(groups);
  };

  const startSpecificSession = (subjectName) => {
    const cards = groupedCards[subjectName];
    setActiveSubjectName(subjectName);
    setActiveSessionCards(cards);
  };

  const handleStudyComplete = () => {
    toast({
      title: "Subject Complete! 🎉",
      description: `You've finished reviewing ${activeSubjectName}.`,
    });
    // Refresh to update counts
    setActiveSessionCards(null);
    setLoading(true);
    fetchDueCards();
  };

  const handleExitStudy = () => {
    // Just go back to the list instead of dashboard
    setActiveSessionCards(null);
    setLoading(true);
    fetchDueCards();
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Checking your schedule...</p>
        </div>
      </div>
    );
  }

  // ACTIVE STUDY MODE
  if (activeSessionCards) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {/* Header */}
          <div className="mb-6">
            <div className="flex items-center justify-between mb-4">
              <Button
                variant="ghost"
                onClick={handleExitStudy}
                size="sm"
              >
                <ArrowLeft className="mr-2 h-4 w-4" />
                Back to List
              </Button>
              <div className="flex items-center gap-2 text-sm text-gray-600">
                <Clock className="h-4 w-4" />
                <span>{activeSubjectName}</span>
              </div>
            </div>

            <div className="bg-blue-100 border border-blue-300 rounded-lg p-3 mb-4">
              <div className="flex items-center gap-2">
                <Clock className="h-5 w-5 text-blue-600" />
                <span className="font-medium text-blue-800">
                  Reviewing: {activeSessionCards.length} card{activeSessionCards.length > 1 ? 's' : ''} due
                </span>
              </div>
            </div>
          </div>

          <StudyMode
            flashcards={activeSessionCards}
            onComplete={handleStudyComplete}
            onExit={handleExitStudy}
          />
        </div>
      </div>
    );
  }

  // EMPTY STATE
  if (dueCards.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Button variant="ghost" onClick={() => navigate('/dashboard')} className="mb-6">
            <ArrowLeft className="mr-2 h-4 w-4" /> Back to Dashboard
          </Button>
          <Card>
            <CardContent className="py-12 text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
                <Clock className="h-8 w-8 text-green-600" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">All Caught Up! 🎉</h2>
              <p className="text-gray-600 mb-6">No cards are due right now.</p>
              <div className="space-y-3">
                <Button onClick={() => navigate('/dashboard')}>Return to Dashboard</Button>
                <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')}>Practice Anyway</Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // DASHBOARD VIEW (Subject List)
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Today's Reviews</h1>
            <p className="text-gray-600">
              You have {dueCards.length} total cards due for review
            </p>
          </div>
          <Button variant="outline" onClick={() => navigate('/dashboard')}>
            Dashboard
          </Button>
        </div>

        <div className="space-y-4">
          {Object.entries(groupedCards).map(([subject, cards]) => (
            <Card key={subject} className="hover:shadow-md transition-shadow">
              <div className="p-6 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="h-12 w-12 rounded-full bg-blue-100 flex items-center justify-center">
                    <BookOpen className="h-6 w-6 text-blue-600" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-gray-900">{subject}</h3>
                    <p className="text-sm text-gray-500">
                      {cards.length} cards due
                    </p>
                  </div>
                </div>
                
                <Button onClick={() => startSpecificSession(subject)}>
                  <Play className="h-4 w-4 mr-2" />
                  Start
                </Button>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}