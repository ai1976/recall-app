import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Brain, ArrowLeft, RotateCcw, CheckCircle, XCircle, AlertCircle } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

// ✅ NOW ACCEPTS PROPS!
export default function StudyMode({ 
  flashcards: propFlashcards = null,  // Cards passed from ReviewSession
  onComplete = null,                   // Optional callback when done
  onExit = null                        // Optional exit callback
}) {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [searchParams] = useSearchParams();

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
    // ✅ FIX: Check if flashcards were passed as props
    if (propFlashcards && propFlashcards.length > 0) {
      // Use the flashcards passed from ReviewSession
      console.log('✅ Using passed flashcards:', propFlashcards.length);
      setFlashcards(propFlashcards);
      setLoading(false);
    } else {
      // No flashcards passed, fetch all flashcards (original behavior)
      console.log('🔍 No flashcards passed, fetching all...');
      fetchFlashcards();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [propFlashcards]);

  const fetchFlashcards = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const subjectParam = searchParams.get('subject');
      const topicParam = searchParams.get('topic');

      // Fetch all public flashcards + user's own flashcards
      let query = supabase
        .from('flashcards')
        .select(`
          *,
          subjects:subject_id (id, name),
          topics:topic_id (id, name)
        `)
        .or(`is_public.eq.true,user_id.eq.${user.id}`);

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) throw error;

      // Clean diamond characters and other special chars from text
      let cleanedData = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || ''
      }));

      // Filter by subject if provided
      if (subjectParam) {
        cleanedData = cleanedData.filter(card => 
          card.subjects?.name === subjectParam || 
          card.custom_subject === subjectParam
        );
      }

      // Filter by topic if provided
      if (topicParam) {
        cleanedData = cleanedData.filter(card => 
          card.topics?.name === topicParam || 
          card.custom_topic === topicParam
        );
      }

      // Shuffle flashcards for study session
      const shuffled = [...cleanedData].sort(() => Math.random() - 0.5);
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

    // Save review to database (for spaced repetition)
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error('No user found for review');
        return;
      }

      const today = new Date();
      
      // Calculate next review date
      let intervalDays;
      let qualityScore;
      let easeFactor;
      
      if (quality === 'easy') {
        intervalDays = 7;
        qualityScore = 5;
        easeFactor = 2.6;
      } else if (quality === 'medium') {
        intervalDays = 3;
        qualityScore = 3;
        easeFactor = 2.5;
      } else {
        intervalDays = 1;
        qualityScore = 1;
        easeFactor = 2.3;
      }
      
      // ✅ FIXED: Set next review to midnight UTC (not local time)
      const nextReview = new Date();
      nextReview.setDate(today.getDate() + intervalDays);
      nextReview.setUTCHours(0, 0, 0, 0);  // Changed from setHours to setUTCHours

      // ✅ FIX 1: Save review to reviews table
      const { error: reviewError } = await supabase
        .from('reviews')
        .insert({
          user_id: user.id,
          flashcard_id: currentCard.id,
          quality: qualityScore,
          created_at: new Date().toISOString()
        });

      if (reviewError) {
        console.error('Error saving review:', reviewError);
      }

      // ✅ FIX 2: Update flashcard's next_review in flashcards table
      // This is the CRITICAL missing step!
      const { error: updateError } = await supabase
        .from('flashcards')
        .update({
          next_review: nextReview.toISOString(),
          interval: intervalDays,
          ease_factor: easeFactor,
          repetitions: (currentCard.repetitions || 0) + 1
        })
        .eq('id', currentCard.id);

      if (updateError) {
        console.error('Error updating flashcard:', updateError);
        toast({
          title: "Warning",
          description: "Review saved, but scheduling may not work correctly",
          variant: "destructive"
        });
      } else {
        // ✅ Success toast
        toast({
          title: "Card saved! ✅",
          description: `Will review again in ${intervalDays} day${intervalDays > 1 ? 's' : ''}`,
        });
      }

    } catch (error) {
      console.error('Error saving review:', error);
      toast({
        title: "Error saving review",
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
      
      // ✅ Call onComplete callback if provided (for ReviewSession)
      if (onComplete) {
        onComplete(sessionStats);
      }
    }
  };

  const restartSession = () => {
    setCurrentIndex(0);
    setShowAnswer(false);
    setSessionStats({ easy: 0, medium: 0, hard: 0 });
    
    // ✅ If using passed flashcards, just reset. Otherwise, refetch.
    if (!propFlashcards) {
      fetchFlashcards(); // Reshuffle
    }
  };

  const handleExit = () => {
    if (onExit) {
      onExit();
    } else {
      navigate('/dashboard/review-flashcards');
    }
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
          <p className="text-gray-600 mb-6">No flashcards found for this selection</p>
          <Button onClick={handleExit}>
            Choose Different Subject
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
              onClick={handleExit}
              className="gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              Back to Selection
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
                onClick={handleExit}
                size="lg"
              >
                {onExit ? 'Exit Review' : 'Choose Different Topic'}
              </Button>
            </div>
          </div>
        ) : (
          // Flashcard Display
          <div>
            {/* Card Info */}
            {(currentCard.subjects || currentCard.custom_subject) && (
              <div className="text-center mb-4">
                <p className="text-sm text-gray-600">
                  {currentCard.subjects?.name || currentCard.custom_subject}
                  {(currentCard.topics?.name || currentCard.custom_topic) && 
                    ` • ${currentCard.topics?.name || currentCard.custom_topic}`
                  }
                </p>
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