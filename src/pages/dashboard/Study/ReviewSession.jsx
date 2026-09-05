import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Clock, ArrowLeft, AlertCircle, Play, BookOpen } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import StudyMode from '@/pages/dashboard/Study/StudyMode';
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

      // Single source of truth for the due queue -- get_study_queue RPC.
      // Course-aware, concept-cards excluded, status / skip_until / next_review_date
      // are all resolved server-side in the user's timezone. No client-side date math.
      const { data: queue, error: queueError } = await supabase
        .rpc('get_study_queue', { p_user_id: user.id });

      if (queueError) throw queueError;

      // Map RPC rows to the card shape StudyMode + groupCardsBySubject expect.
      const cleanedCards = (queue || []).map(row => ({
        id: row.flashcard_id,
        user_id: row.card_user_id,
        contributed_by: row.contributed_by,
        target_course: row.target_course,
        subject_id: row.subject_id,
        custom_subject: row.custom_subject,
        topic_id: row.topic_id,
        custom_topic: row.custom_topic,
        front_text: row.front_text?.replace(/[◆♦]/g, '').trim() || '',
        front_image_url: row.front_image_url,
        back_text: row.back_text?.replace(/[◆♦]/g, '').trim() || '',
        back_image_url: row.back_image_url,
        difficulty: row.difficulty,
        is_verified: row.is_verified,
        question_type: row.question_type,
        rung: row.rung, // current SRS ladder position — drives StudyMode's local grade-button preview
        subject_name: row.subject_name,
        topic_name: row.topic_name,
        subjects: row.subject_name ? { id: row.subject_id, name: row.subject_name } : null,
        topics: row.topic_name ? { id: row.topic_id, name: row.topic_name } : null,
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
      const subjectName = card.subject_name || card.custom_subject || 'General';

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
    setActiveSessionCards(null);
    setLoading(true);
    fetchDueCards();
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-rv-bg-0 font-plex">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-rv-navy mx-auto mb-4"></div>
          <p className="text-rv-ink-600">Checking your schedule...</p>
        </div>
      </div>
    );
  }

  // ACTIVE STUDY MODE
  if (activeSessionCards) {
    return (
      <div className="min-h-screen bg-rv-bg-0 font-plex">
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
              <div className="flex items-center gap-2 text-sm text-rv-ink-600">
                <Clock className="h-4 w-4" />
                <span>{activeSubjectName}</span>
              </div>
            </div>

            <div className="bg-rv-navy-50 border border-rv-navy-100 rounded-rec p-3 mb-4">
              <div className="flex items-center gap-2">
                <Clock className="h-5 w-5 text-rv-navy" />
                <span className="font-medium text-rv-navy">
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
      <div className="min-h-screen bg-rv-bg-0 font-plex">
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                    <Button
            variant="ghost"
            onClick={() => {
              if (window.history.length > 1) {
                navigate(-1);
              } else {
                navigate('/dashboard');
              }
            }}
            className="mb-6"
          >
            <ArrowLeft className="mr-2 h-4 w-4" /> Back
          </Button>

          <Card className="border-rv-border">
            <CardContent className="py-12 text-center">
              <div className="inline-flex items-center justify-center w-16 h-16 bg-rv-navy-50 rounded-full mb-4">
                <Clock className="h-8 w-8 text-rv-navy" />
              </div>
              <h2 className="text-2xl font-semibold text-rv-ink-900 mb-2">All Caught Up! 🎉</h2>
              <p className="text-rv-ink-600 mb-6">No scheduled reviews due right now.</p>
              <div className="space-y-3">
                <Button onClick={() => navigate('/dashboard')}>Return to Dashboard</Button>
                <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')}>Study New Cards</Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // DASHBOARD VIEW (Subject List)
  return (
    <div className="min-h-screen bg-rv-bg-0 font-plex">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-semibold text-rv-ink-900">Today's Reviews</h1>
            <p className="text-rv-ink-600">
              You have {dueCards.length} scheduled items due
            </p>
          </div>
          <Button variant="outline" onClick={() => navigate('/dashboard')}>
            Dashboard
          </Button>
        </div>

        <div className="space-y-4">
          {Object.entries(groupedCards).map(([subject, cards]) => (
            <Card key={subject} className="border-rv-border hover:shadow-rv transition-shadow">
              <div className="p-6 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="h-12 w-12 rounded-rec bg-rv-navy-50 flex items-center justify-center">
                    <BookOpen className="h-6 w-6 text-rv-navy" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-rv-ink-900">{subject}</h3>
                    <p className="text-sm font-plex-mono text-rv-ink-400 [font-variant-numeric:tabular-nums]">
                      {cards.length} items due
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
