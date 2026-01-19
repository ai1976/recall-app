import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { 
  BookOpen, 
  CreditCard, 
  TrendingUp, 
  Award,
  Upload,
  PlusCircle,
  CheckCircle,
  Flame,
  FileText
} from 'lucide-react';

export default function Dashboard() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  
  // Stats
  const [notesCount, setNotesCount] = useState(0);
  const [flashcardsCount, setFlashcardsCount] = useState(0);
  const [cardsReviewedThisWeek, setCardsReviewedThisWeek] = useState(0);
  const [studyStreak, setStudyStreak] = useState(0);
  const [accuracy, setAccuracy] = useState(0);
  const [cardsMastered, setCardsMastered] = useState(0);
  const [reviewsDue, setReviewsDue] = useState(0);
  const [isNewUser, setIsNewUser] = useState(false);

  useEffect(() => {
    fetchUserAndStats();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchUserAndStats = async () => {
    try {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (!authUser) {
        navigate('/login');
        return;
      }

      await Promise.all([
        fetchNotesCount(authUser.id),
        fetchFlashcardsCount(authUser.id),
        fetchReviewStats(authUser.id),
      ]);

      const { count: reviewsCount } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', authUser.id);

      const { count: notesTotal } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', authUser.id);

      const { count: flashcardsTotal } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', authUser.id);

      setIsNewUser(
        (!reviewsCount || reviewsCount === 0) && 
        (!notesTotal || notesTotal === 0) && 
        (!flashcardsTotal || flashcardsTotal === 0)
      );

    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchNotesCount = async (userId) => {
    const { count } = await supabase
      .from('notes')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);
    setNotesCount(count || 0);
  };

  const fetchFlashcardsCount = async (userId) => {
    const { count } = await supabase
      .from('flashcards')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);
    setFlashcardsCount(count || 0);
  };

  const fetchReviewStats = async (userId) => {
    const { data: reviews } = await supabase
      .from('reviews')
      .select('created_at, quality, flashcard_id, next_review_date')
      .eq('user_id', userId);

    const reviewList = reviews || [];

    if (reviewList.length > 0) {
      const sortedReviews = [...reviewList].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
      
      const oneWeekAgo = new Date();
      oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
      const weeklyReviews = sortedReviews.filter(r => new Date(r.created_at) > oneWeekAgo);
      setCardsReviewedThisWeek(weeklyReviews.length);

      setStudyStreak(calculateStreak(sortedReviews));

      if (weeklyReviews.length > 0) {
        const easyMedium = weeklyReviews.filter(r => r.quality === 5 || r.quality === 3).length;
        setAccuracy(Math.round((easyMedium / weeklyReviews.length) * 100));
      }

      const unique = new Set(reviewList.map(r => r.flashcard_id));
      setCardsMastered(unique.size);
    }

    const todayStr = new Date().toISOString().split('T')[0];
    const scheduledDueCount = reviewList.filter(r => r.next_review_date <= todayStr).length;

    setReviewsDue(scheduledDueCount);
  };

  const calculateStreak = (reviews) => {
    if (!reviews || reviews.length === 0) return 0;
    const dates = [...new Set(reviews.map(r => new Date(r.created_at).toISOString().split('T')[0]))].sort().reverse();
    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    if (dates[0] !== today && dates[0] !== yesterday) return 0;

    let streak = 0;
    let checkDate = new Date();
    
    for (let i = 0; i < dates.length; i++) {
      const dateStr = checkDate.toISOString().split('T')[0];
      if (dates.includes(dateStr)) streak++;
      else if (i === 0 && dates[0] === yesterday) {
         checkDate.setDate(checkDate.getDate() - 1);
         if (dates.includes(yesterday)) streak++;
      } else break;
      
      checkDate.setDate(checkDate.getDate() - 1);
    }
    return streak;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <div className="mb-6 sm:mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold flex items-center gap-2">
            {isNewUser ? 'Welcome to Recall! 👋' : 'Welcome back! 👋'}
          </h1>
          <p className="text-muted-foreground mt-2">
            {isNewUser 
              ? "Let's get you started on your journey to mastering your subjects."
              : reviewsDue > 0 
                ? `You have ${reviewsDue} scheduled card${reviewsDue > 1 ? 's' : ''} ready for review!`
                : "All scheduled reviews complete! 🎉"
            }
          </p>
        </div>

        <div className="space-y-4 sm:space-y-6">
          {/* New User Onboarding */}
          {isNewUser && (
            <Card className="bg-gradient-to-r from-indigo-50 to-purple-50 border-indigo-200">
              <CardHeader>
                <CardTitle className="text-base sm:text-lg">Get Started</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4 sm:space-y-6">
                  <div>
                    <div className="flex items-center gap-2 mb-2">
                      <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-indigo-600" />
                      <h3 className="font-semibold text-sm sm:text-base">Browse Content</h3>
                    </div>
                    <p className="text-xs sm:text-sm text-gray-700 mb-3">
                      Explore expert notes and flashcards created by professors
                    </p>
                    <div className="flex flex-wrap gap-3 items-center">
                      <Button variant="outline" onClick={() => navigate('/dashboard/notes')}>
                        <FileText className="mr-2 h-4 w-4" /> Browse Notes
                      </Button>
                      <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')}>
                        <CreditCard className="mr-2 h-4 w-4" /> Browse Flashcards
                      </Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Reviews Due */}
          {!isNewUser && reviewsDue > 0 && (
            <Card className="bg-gradient-to-r from-green-50 to-emerald-50 border-green-200">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
                  <CheckCircle className="h-4 w-4 sm:h-5 sm:w-5 text-green-600" />
                  Ready to Review
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-base sm:text-lg font-semibold mb-4">
                  {reviewsDue} flashcard{reviewsDue > 1 ? 's' : ''} ready for review
                </p>
                <Button onClick={() => navigate('/dashboard/review-session')}>
                  Start Review Session
                </Button>
              </CardContent>
            </Card>
          )}

          {/* All Caught Up */}
          {!isNewUser && reviewsDue === 0 && (
            <Card className="bg-gradient-to-r from-green-50 to-emerald-50 border-green-200">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
                  🎉 All Caught Up!
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm sm:text-base text-muted-foreground mb-4">
                  No scheduled reviews due. Time to learn something new?
                </p>
                <div className="flex flex-wrap gap-3 items-center">
                  <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')}>Study New Cards</Button>
                  <Button onClick={() => navigate('/dashboard/notes')}>Browse Content</Button>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Stats Grid */}
          <div className="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-xs sm:text-sm font-medium">This Week</CardTitle>
                <CheckCircle className="h-3 w-3 sm:h-4 sm:w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-xl sm:text-2xl font-bold">{cardsReviewedThisWeek}</div>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Cards Reviewed</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-xs sm:text-sm font-medium">Days</CardTitle>
                <Flame className="h-3 w-3 sm:h-4 sm:w-4 text-orange-500" />
              </CardHeader>
              <CardContent>
                <div className="text-xl sm:text-2xl font-bold">{studyStreak}</div>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Day Streak</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-xs sm:text-sm font-medium">Last 7 Days</CardTitle>
                <TrendingUp className="h-3 w-3 sm:h-4 sm:w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-xl sm:text-2xl font-bold">{accuracy}%</div>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Accuracy</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-xs sm:text-sm font-medium">Total</CardTitle>
                <Award className="h-3 w-3 sm:h-4 sm:w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-xl sm:text-2xl font-bold">{cardsMastered}</div>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Cards Mastered</p>
              </CardContent>
            </Card>
          </div>

          {/* Quick Actions */}
          {!isNewUser && (
            <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-2">
              <Card className="hover:bg-accent cursor-pointer transition" onClick={() => navigate('/dashboard/notes/new')}>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2 text-sm sm:text-base">
                    <Upload className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" /> Upload Note
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-xs sm:text-sm text-muted-foreground">Add photos or PDFs of your notes</p>
                </CardContent>
              </Card>
              <Card className="hover:bg-accent cursor-pointer transition" onClick={() => navigate('/dashboard/flashcards/new')}>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2 text-sm sm:text-base">
                    <PlusCircle className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" /> Create Flashcard
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-xs sm:text-sm text-muted-foreground">Make your own flashcards</p>
                </CardContent>
              </Card>
            </div>
          )}

          {/* My Contributions - RESTORED */}
          {!isNewUser && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
                  <BookOpen className="h-4 w-4 sm:h-5 sm:w-5" />
                  My Contributions
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-xs sm:text-sm text-muted-foreground mb-4">
                  Track your personal study library
                </p>
                <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-2">
                  
                  <div 
                    className="flex items-center justify-between p-3 sm:p-4 border rounded-lg hover:border-primary hover:bg-accent cursor-pointer transition"
                    onClick={() => navigate('/dashboard/my-notes')}
                  >
                    <div className="flex items-center gap-2 sm:gap-3">
                      <BookOpen className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" />
                      <div>
                        <p className="font-medium text-xs sm:text-sm">My Notes</p>
                        <p className="text-[10px] sm:text-xs text-muted-foreground">{notesCount} uploaded</p>
                      </div>
                    </div>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      className="text-primary pointer-events-none text-xs sm:text-sm"
                    >
                      View →
                    </Button>
                  </div>

                  <div 
                    className="flex items-center justify-between p-3 sm:p-4 border rounded-lg hover:border-primary hover:bg-accent cursor-pointer transition"
                    onClick={() => navigate('/dashboard/flashcards')}
                  >
                    <div className="flex items-center gap-2 sm:gap-3">
                      <CreditCard className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
                      <div>
                        <p className="font-medium text-xs sm:text-sm">My Flashcards</p>
                        <p className="text-[10px] sm:text-xs text-muted-foreground">{flashcardsCount} created</p>
                      </div>
                    </div>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      className="text-primary pointer-events-none text-xs sm:text-sm"
                    >
                      View →
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}