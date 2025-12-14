import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Brain, ArrowLeft, RotateCcw, CheckCircle, XCircle, AlertCircle, FileText } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

export default function StudyMode() {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [searchParams] = useSearchParams();
  const subjectFilter = searchParams.get('subject');

  const [flashcards, setFlashcards] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const [loading, setLoading] = useState(true);
  const [sessionStats, setSessionStats] = useState({
    easy: 0,
    medium: 0,
    hard: 0
  });

  useEffect(() => {
    fetchFlashcards();
  }, []);

  const fetchFlashcards = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      let query = supabase
        .from('flashcards')
        .select(`
          *,
          notes (
            id,
            title,
            subject,
            topic
          )
        `)
        .eq('user_id', user.id);

      // Filter by subject if provided
      if (subjectFilter) {
        const { data: notesData } = await supabase
          .from('notes')
          .select('id')
          .eq('subject', subjectFilter);
        
        const noteIds = notesData?.map(n => n.id) || [];
        query = query.in('note_id', noteIds);
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) throw error;

      // Shuffle flashcards for study session
      const shuffled = [...(data || [])].sort(() => Math.random() - 0.5);
      setFlashcards(shuffled);
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
    
    // Update session stats
    setSessionStats(prev => ({
      ...prev,
      [quality]: prev[quality] + 1
    }));

    // Save review to database (for future spaced repetition)
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error('No user found for review');
        return;
      }

      const today = new Date();
      const nextReview = new Date();
      
      // Simple interval calculation
      if (quality === 'easy') {
        nextReview.setDate(today.getDate() + 7);
      } else if (quality === 'medium') {
        nextReview.setDate(today.getDate() + 3);
      } else {
        nextReview.setDate(today.getDate() + 1);
      }

      const { data, error } = await supabase
        .from('reviews')
        .insert({
          user_id: user.id, // ADDED: Missing user_id!
          flashcard_id: currentCard.id,
          quality: quality === 'easy' ? 5 : quality === 'medium' ? 3 : 1,
          next_review_date: nextReview.toISOString().split('T')[0],
          interval: quality === 'easy' ? 7 : quality === 'medium' ? 3 : 1,
          repetition: 1,
          easiness: quality === 'easy' ? 2.6 : quality === 'medium' ? 2.5 : 2.3
        })
        .select();

      if (error) {
        console.error('Error saving review:', error);
        toast({
          title: "Failed to save review",
          description: error.message,
          variant: "destructive"
        });
      } else {
        console.log('Review saved successfully:', data);
      }
    } catch (error) {
      console.error('Error saving review:', error);
      toast({
        title: "Failed to save review",
        description: error.message,
        variant: "destructive"
      });
    }

    // Move to next card
    if (currentIndex < flashcards.length - 1) {
      setCurrentIndex(currentIndex + 1);
      setShowAnswer(false);
    } else {
      // Session complete
      toast({
        title: "Study session complete! 🎉",
        description: `You reviewed ${flashcards.length} flashcards`
      });
    }
  };

  const restartSession = () => {
    setCurrentIndex(0);
    setShowAnswer(false);
    setSessionStats({ easy: 0, medium: 0, hard: 0 });
    fetchFlashcards(); // Reshuffle
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600"></div>
      </div>
    );
  }

  if (flashcards.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <Brain className="h-16 w-16 text-gray-400 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-gray-900 mb-2">No flashcards to study</h2>
          <p className="text-gray-600 mb-6">Create some flashcards first to start studying!</p>
          <Button onClick={() => navigate('/dashboard/flashcards/new')}>
            Create Flashcards
          </Button>
        </div>
      </div>
    );
  }

  const currentCard = flashcards[currentIndex];
  const isComplete = currentIndex >= flashcards.length;
  const progress = ((currentIndex + 1) / flashcards.length) * 100;

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 to-blue-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Button
              variant="ghost"
              onClick={() => navigate('/dashboard/flashcards')}
              className="gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              Exit Study Mode
            </Button>
            <div className="flex items-center gap-4">
              <div className="text-sm text-gray-600">
                Card {currentIndex + 1} of {flashcards.length}
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={restartSession}
                className="gap-2"
              >
                <RotateCcw className="h-4 w-4" />
                Restart
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* Progress Bar */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
          <div className="relative">
            <div className="overflow-hidden h-2 text-xs flex rounded-full bg-gray-200">
              <div
                style={{ width: `${progress}%` }}
                className="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-purple-600 transition-all duration-300"
              />
            </div>
          </div>
          <div className="flex justify-between mt-2 text-xs text-gray-600">
            <div className="flex items-center gap-1">
              <CheckCircle className="h-3 w-3 text-green-600" />
              <span>Easy: {sessionStats.easy}</span>
            </div>
            <div className="flex items-center gap-1">
              <AlertCircle className="h-3 w-3 text-yellow-600" />
              <span>Medium: {sessionStats.medium}</span>
            </div>
            <div className="flex items-center gap-1">
              <XCircle className="h-3 w-3 text-red-600" />
              <span>Hard: {sessionStats.hard}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {isComplete ? (
          // Session Complete Screen
          <div className="bg-white rounded-xl shadow-lg p-12 text-center">
            <div className="mb-6">
              <Brain className="h-20 w-20 text-purple-600 mx-auto mb-4" />
              <h2 className="text-3xl font-bold text-gray-900 mb-2">
                Study Session Complete! 🎉
              </h2>
              <p className="text-gray-600">
                You reviewed {flashcards.length} flashcards
              </p>
            </div>

            <div className="grid grid-cols-3 gap-4 mb-8 max-w-md mx-auto">
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <CheckCircle className="h-8 w-8 text-green-600 mx-auto mb-2" />
                <div className="text-2xl font-bold text-green-900">{sessionStats.easy}</div>
                <div className="text-sm text-green-700">Easy</div>
              </div>
              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <AlertCircle className="h-8 w-8 text-yellow-600 mx-auto mb-2" />
                <div className="text-2xl font-bold text-yellow-900">{sessionStats.medium}</div>
                <div className="text-sm text-yellow-700">Medium</div>
              </div>
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <XCircle className="h-8 w-8 text-red-600 mx-auto mb-2" />
                <div className="text-2xl font-bold text-red-900">{sessionStats.hard}</div>
                <div className="text-sm text-red-700">Hard</div>
              </div>
            </div>

            <div className="flex gap-4 justify-center">
              <Button onClick={restartSession} className="gap-2" size="lg">
                <RotateCcw className="h-4 w-4" />
                Study Again
              </Button>
              <Button
                variant="outline"
                onClick={() => navigate('/dashboard')}
                size="lg"
              >
                Back to Dashboard
              </Button>
            </div>
          </div>
        ) : (
          // Flashcard Display
          <div>
            {/* Card Info */}
            {currentCard.notes && (
              <div className="text-center mb-4">
                <p className="text-sm text-gray-600 mb-2">
                  {currentCard.notes.subject} • {currentCard.notes.topic}
                </p>
                <a
                  href={`/dashboard/notes/${currentCard.notes.id}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-700 hover:underline"
                >
                  <FileText className="h-3 w-3" />
                  View Original Note
                </a>
              </div>
            )}

            {/* Flashcard */}
            <div className="bg-white rounded-xl shadow-xl p-8 md:p-12 min-h-[400px] flex flex-col justify-center items-center">
              {!showAnswer ? (
                // Front Side (Question)
                <div className="w-full text-center">
                  <div className="mb-6">
                    <span className="inline-block px-3 py-1 bg-purple-100 text-purple-700 text-sm font-semibold rounded-full">
                      QUESTION
                    </span>
                  </div>
                  
                  {currentCard.front_image_url && (
                    <img
                      src={currentCard.front_image_url}
                      alt="Question"
                      className="max-w-full h-auto max-h-64 mx-auto rounded-lg mb-6 shadow-md"
                    />
                  )}
                  
                  <p className="text-2xl md:text-3xl font-semibold text-gray-900 mb-8 whitespace-pre-wrap">
                    {currentCard.front_text}
                  </p>

                  <Button
                    onClick={() => setShowAnswer(true)}
                    size="lg"
                    className="gap-2 px-8"
                  >
                    <Brain className="h-5 w-5" />
                    Show Answer
                  </Button>
                </div>
              ) : (
                // Back Side (Answer)
                <div className="w-full">
                  {/* Question (smaller) */}
                  <div className="mb-6 pb-6 border-b border-gray-200">
                    <span className="inline-block px-3 py-1 bg-gray-100 text-gray-600 text-xs font-semibold rounded-full mb-3">
                      QUESTION
                    </span>
                    <p className="text-lg text-gray-700 whitespace-pre-wrap">
                      {currentCard.front_text}
                    </p>
                  </div>

                  {/* Answer */}
                  <div className="text-center mb-8">
                    <span className="inline-block px-3 py-1 bg-green-100 text-green-700 text-sm font-semibold rounded-full mb-4">
                      ANSWER
                    </span>
                    
                    {currentCard.back_image_url && (
                      <img
                        src={currentCard.back_image_url}
                        alt="Answer"
                        className="max-w-full h-auto max-h-64 mx-auto rounded-lg mb-4 shadow-md"
                      />
                    )}
                    
                    {currentCard.back_text ? (
                      <p className="text-xl md:text-2xl font-semibold text-gray-900 whitespace-pre-wrap">
                        {currentCard.back_text}
                      </p>
                    ) : (
                      <p className="text-lg text-gray-500 italic">
                        No written answer - refer to image
                      </p>
                    )}
                  </div>

                  {/* Rating Buttons */}
                  <div className="border-t border-gray-200 pt-6">
                    <p className="text-center text-sm text-gray-600 mb-4">
                      How well did you remember this?
                    </p>
                    <div className="grid grid-cols-3 gap-4">
                      <Button
                        onClick={() => handleRating('hard')}
                        variant="outline"
                        className="flex flex-col gap-2 h-auto py-4 border-red-300 hover:bg-red-50 hover:border-red-400"
                      >
                        <XCircle className="h-6 w-6 text-red-600" />
                        <span className="font-semibold">Hard</span>
                        <span className="text-xs text-gray-500">Review in 1 day</span>
                      </Button>
                      <Button
                        onClick={() => handleRating('medium')}
                        variant="outline"
                        className="flex flex-col gap-2 h-auto py-4 border-yellow-300 hover:bg-yellow-50 hover:border-yellow-400"
                      >
                        <AlertCircle className="h-6 w-6 text-yellow-600" />
                        <span className="font-semibold">Medium</span>
                        <span className="text-xs text-gray-500">Review in 3 days</span>
                      </Button>
                      <Button
                        onClick={() => handleRating('easy')}
                        variant="outline"
                        className="flex flex-col gap-2 h-auto py-4 border-green-300 hover:bg-green-50 hover:border-green-400"
                      >
                        <CheckCircle className="h-6 w-6 text-green-600" />
                        <span className="font-semibold">Easy</span>
                        <span className="text-xs text-gray-500">Review in 7 days</span>
                      </Button>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Navigation Hint */}
            <div className="text-center mt-6">
              <p className="text-sm text-gray-500">
                {showAnswer 
                  ? "Rate how well you remembered to continue"
                  : "Try to recall the answer before revealing it"}
              </p>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}