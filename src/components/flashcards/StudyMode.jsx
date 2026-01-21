import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Brain, ArrowLeft, RotateCcw, CheckCircle, XCircle, AlertCircle } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

export default function StudyMode({ 
  flashcards: propFlashcards = null,
  onComplete = null,
  onExit = null
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
    console.log("✅ STABLE VERSION: StudyMode.jsx with Explicit DB Logic");

    if (propFlashcards && propFlashcards.length > 0) {
      console.log('✅ Using passed flashcards:', propFlashcards.length);
      setFlashcards(propFlashcards);
      setLoading(false);
    } else {
      fetchFlashcards();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [propFlashcards]);

  const fetchFlashcards = async () => {
    try {
      console.log("🔄 Starting fetchFlashcards...");
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error("❌ No authenticated user found");
        return;
      }

      const subjectParam = searchParams.get('subject');
      const topicParam = searchParams.get('topic');

      console.log(`📊 Parameters - Subject: ${subjectParam}, Topic: ${topicParam}`);

      const filterString = `is_public.eq.true,user_id.eq.${user.id},visibility.eq.friends`;

      let query = supabase
        .from('flashcards')
        .select(`
          *,
          subjects:subject_id (id, name),
          topics:topic_id (id, name)
        `)
        .or(filterString);

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) {
        console.error("❌ Supabase Error:", error);
        throw error;
      }

      console.log(`✅ Raw Cards Fetched: ${data?.length}`);

      // Clean special characters
      let cleanedData = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆]/g, '').trim() || ''
      }));

      // Filter by subject/topic
      if (subjectParam) {
        cleanedData = cleanedData.filter(card => {
          const dbSubject = card.subjects?.name;
          const customSubject = card.custom_subject;
          return dbSubject === subjectParam || customSubject === subjectParam;
        });
      }

      if (topicParam) {
        cleanedData = cleanedData.filter(card => {
          const dbTopic = card.topics?.name;
          const customTopic = card.custom_topic;
          return dbTopic === topicParam || customTopic === topicParam;
        });
      }

      // Shuffle
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
    
    setSessionStats(prev => ({
      ...prev,
      [quality]: prev[quality] + 1
    }));

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error('❌ No user found');
        return;
      }

      // 1. Calculate Interval
      let intervalDays;
      let qualityScore;
      let easinessFactor;
      
      if (quality === 'easy') {
        intervalDays = 7;
        qualityScore = 5;
        easinessFactor = 2.6;
      } else if (quality === 'medium') {
        intervalDays = 3;
        qualityScore = 3;
        easinessFactor = 2.5;
      } else { // hard
        intervalDays = 1;
        qualityScore = 1;
        easinessFactor = 2.3;
      }
      
      // 2. ✅ FIX: Strict Local Date Calculation (Replacing UTC logic)
      const today = new Date();
      const nextDate = new Date(today);
      nextDate.setDate(today.getDate() + intervalDays);
      
      // Manually construct YYYY-MM-DD using Local Time
      // This prevents the "Yesterday in UTC" bug which causes loops
      const year = nextDate.getFullYear();
      const month = String(nextDate.getMonth() + 1).padStart(2, '0');
      const day = String(nextDate.getDate()).padStart(2, '0');
      const dateString = `${year}-${month}-${day}`;

      console.log(`📅 Scheduling Card ${currentCard.id} for: ${dateString} (Local)`);

      // 3. Explicitly Check for existing review (Stability over Optimization)
      const { data: existingReview, error: selectError } = await supabase
        .from('reviews')
        .select('id, repetition')
        .eq('user_id', user.id)
        .eq('flashcard_id', currentCard.id)
        .maybeSingle();

      if (selectError) throw selectError;

      if (existingReview) {
        // UPDATE existing review
        console.log(`🔄 Updating existing review (ID: ${existingReview.id})`);
        
        const { error: updateError } = await supabase
          .from('reviews')
          .update({
            quality: qualityScore,
            interval: intervalDays,
            repetition: (existingReview.repetition || 0) + 1,
            easiness: easinessFactor,
            next_review_date: dateString,
            last_reviewed_at: new Date().toISOString()
          })
          .eq('id', existingReview.id);

        if (updateError) throw updateError;
        console.log('✅ Review updated successfully');

      } else {
        // INSERT new review
        console.log(`➕ Creating new review for card ${currentCard.id}`);
        
        const { error: insertError } = await supabase
          .from('reviews')
          .insert({
            user_id: user.id,
            flashcard_id: currentCard.id,
            quality: qualityScore,
            interval: intervalDays,
            repetition: 1,
            easiness: easinessFactor,
            next_review_date: dateString,
            last_reviewed_at: new Date().toISOString()
          });

        if (insertError) throw insertError;
        console.log('✅ New review created successfully');
      }

      // Success feedback
      toast({
        title: "Progress saved! ✅",
        description: `Next review in ${intervalDays} day${intervalDays > 1 ? 's' : ''}`,
      });

    } catch (error) {
      console.error('❌ Error saving review:', error);
      toast({
        title: "Error",
        description: "Failed to save progress.",
        variant: "destructive"
      });
      return; // Don't advance if failed
    }

    // 4. Advance to Next Card
    if (currentIndex < flashcards.length - 1) {
      setCurrentIndex(currentIndex + 1);
      setShowAnswer(false);
    } else {
      if (onComplete) {
        onComplete(sessionStats);
      } else {
        toast({
          title: "Study session complete! 🎉",
          description: `You reviewed ${flashcards.length} flashcards`,
        });
        if(onExit) onExit();
      }
    }
  };

  const restartSession = () => {
    setCurrentIndex(0);
    setShowAnswer(false);
    setSessionStats({ easy: 0, medium: 0, hard: 0 });
    if (!propFlashcards) {
      fetchFlashcards();
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
          <div className="flex flex-col gap-2">
            <Button onClick={handleExit}>
              Choose Different Subject
            </Button>
          </div>
        </div>
      </div>
    );
  }

  const currentCard = flashcards[currentIndex];
  const isComplete = currentIndex >= flashcards.length;
  const progress = ((currentIndex + 1) / flashcards.length) * 100;

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 to-blue-50">
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Button variant="ghost" onClick={handleExit} className="gap-2">
              <ArrowLeft className="h-4 w-4" />
              Back to Selection
            </Button>
            <div className="flex items-center gap-4">
              <div className="text-sm text-gray-600">
                Card {currentIndex + 1} of {flashcards.length}
              </div>
              <Button variant="outline" size="sm" onClick={restartSession} className="gap-2">
                <RotateCcw className="h-4 w-4" />
                Restart
              </Button>
            </div>
          </div>
        </div>
      </header>

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

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {isComplete ? (
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
              <Button variant="outline" onClick={handleExit} size="lg">
                {onExit ? 'Exit Review' : 'Choose Different Topic'}
              </Button>
            </div>
          </div>
        ) : (
          <div>
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

            <div className="bg-white rounded-xl shadow-xl p-8 md:p-12 min-h-[400px] flex flex-col justify-center items-center">
              {!showAnswer ? (
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

                  <Button onClick={() => setShowAnswer(true)} size="lg" className="gap-2 px-8">
                    <Brain className="h-5 w-5" />
                    Show Answer
                  </Button>
                </div>
              ) : (
                <div className="w-full">
                  <div className="mb-6 pb-6 border-b border-gray-200">
                    <span className="inline-block px-3 py-1 bg-gray-100 text-gray-600 text-xs font-semibold rounded-full mb-3">
                      QUESTION
                    </span>
                    <p className="text-lg text-gray-700 whitespace-pre-wrap">
                      {currentCard.front_text}
                    </p>
                  </div>

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