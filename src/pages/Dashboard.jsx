import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import AnonymousStats from '@/components/dashboard/AnonymousStats';
import ActivityFeed from '@/components/dashboard/ActivityFeed';
import { useBadges } from '@/hooks/useBadges';
import { useToast } from '@/hooks/use-toast';
import BadgeToast from '@/components/badges/BadgeToast';
import PageContainer from '@/components/layout/PageContainer';
import { 
  BookOpen, 
  CreditCard, 
  CheckCircle,
  Flame,
  Target,
  Award,
  Upload,
  PlusCircle,
  FileText,
  Play
} from 'lucide-react';

// ============================================================
// HELPER: Format date as YYYY-MM-DD in user's LOCAL timezone
// Using 'en-CA' locale gives us ISO format (YYYY-MM-DD) which
// allows correct string comparison for dates.
// ============================================================
const formatLocalDate = (date) => {
  return new Date(date).toLocaleDateString('en-CA');
};

export default function Dashboard() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  
  // User info
  const [userName, setUserName] = useState('');
  
  // Personal stats
  const [reviewsDue, setReviewsDue] = useState(0);
  const [cardsReviewedThisWeek, setCardsReviewedThisWeek] = useState(0);
  const [studyStreak, setStudyStreak] = useState(0);
  const [accuracy, setAccuracy] = useState(0);
  const [cardsMastered, setCardsMastered] = useState(0);
  
  // Content counts
  const [notesCount, setNotesCount] = useState(0);
  const [flashcardsCount, setFlashcardsCount] = useState(0);
  
  // Anonymous class stats
  const [classStats, setClassStats] = useState({
    avgReviewsThisWeek: 0,
    totalActiveStudents: 0,
    studentsWithStreak: 0,
    studentsStudiedToday: 0,
    minUsersMet: false
  });
  
  // User state flags
  const [isNewUser, setIsNewUser] = useState(false);
  const [hasUserActivity, setHasUserActivity] = useState(false);

  // Badge notifications
  const { unnotifiedBadges, clearUnnotifiedBadges } = useBadges();
  const { toast } = useToast();

  // Show toast for newly earned badges
  useEffect(() => {
    if (unnotifiedBadges && unnotifiedBadges.length > 0) {
      unnotifiedBadges.forEach((badge) => {
        toast({
          description: <BadgeToast badge={badge} />,
          duration: 5000,
        });
      });
      clearUnnotifiedBadges();
    }
  }, [unnotifiedBadges, clearUnnotifiedBadges, toast]);

  useEffect(() => {
    fetchDashboardData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchDashboardData = async () => {
    try {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (!authUser) {
        navigate('/login');
        return;
      }

      // Fetch profile for name and course level
      const { data: profile } = await supabase
        .from('profiles')
        .select('full_name, course_level')
        .eq('id', authUser.id)
        .single();

      if (profile) {
        setUserName(profile.full_name || '');
      }

      // Fetch all data in parallel
      await Promise.all([
        fetchPersonalStats(authUser.id),
        fetchContentCounts(authUser.id),
        fetchClassStats(profile?.course_level)
      ]);

      // Determine if new user
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

      setHasUserActivity(reviewsCount > 0);

    } catch (error) {
      console.error('🔴 Dashboard Error:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchPersonalStats = async (userId) => {
    // Fetch user's active reviews (exclude suspended)
    const { data: reviews } = await supabase
      .from('reviews')
      .select('created_at, quality, flashcard_id, next_review_date, status, skip_until')
      .eq('user_id', userId);

    const reviewList = reviews || [];

    // Only use active reviews for stats
    const activeReviews = reviewList.filter(r => r.status === 'active' || !r.status);

    if (activeReviews.length > 0) {
      // Rolling 7 days calculation
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
      sevenDaysAgo.setHours(0, 0, 0, 0);

      // Only count reviews with quality > 0 for weekly stats (skip/suspend create quality=0 records)
      const weeklyReviews = activeReviews.filter(r => new Date(r.created_at) >= sevenDaysAgo && r.quality > 0);
      setCardsReviewedThisWeek(weeklyReviews.length);

      // Calculate streak (only count actual reviews, not skip/suspend actions)
      const actualReviews = activeReviews.filter(r => r.quality > 0);
      const sortedReviews = [...actualReviews].sort((a, b) =>
        new Date(b.created_at) - new Date(a.created_at)
      );
      setStudyStreak(calculateStreak(sortedReviews));

      // Calculate accuracy (Easy + Medium / Total) for this week
      if (weeklyReviews.length > 0) {
        const easyMedium = weeklyReviews.filter(r => r.quality === 5 || r.quality === 3).length;
        setAccuracy(Math.round((easyMedium / weeklyReviews.length) * 100));
      }

      // Cards mastered (unique cards ever reviewed, active only)
      const uniqueCards = new Set(actualReviews.map(r => r.flashcard_id));
      setCardsMastered(uniqueCards.size);

      // Reviews due: active, not suspended, not skipped, next_review_date <= today
      const todayString = formatLocalDate(new Date());

      const dueCount = activeReviews.filter(r =>
        r.next_review_date &&
        r.next_review_date <= todayString &&
        (!r.skip_until || r.skip_until <= todayString)
      ).length;
      setReviewsDue(dueCount);
    }
  };

  const fetchContentCounts = async (userId) => {
    const { count: notes } = await supabase
      .from('notes')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);
    setNotesCount(notes || 0);

    const { count: flashcards } = await supabase
      .from('flashcards')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);
    setFlashcardsCount(flashcards || 0);
  };

  const fetchClassStats = async (userCourseLevel) => {
    if (!userCourseLevel) return;

    try {
      const { data, error } = await supabase
        .rpc('get_anonymous_class_stats', { p_course_level: userCourseLevel });

      if (error) {
        console.error('🔴 Class Stats Error:', error);
        return;
      }

      if (data && data.length > 0) {
        const stats = data[0];
        setClassStats({
          avgReviewsThisWeek: Number(stats.avg_reviews_this_week) || 0,
          totalActiveStudents: stats.total_active_students || 0,
          studentsWithStreak: stats.students_with_7day_streak || 0,
          studentsStudiedToday: stats.students_studied_today || 0,
          minUsersMet: stats.min_users_met || false
        });
      }
    } catch (err) {
      console.error('🔴 RPC Error:', err);
    }
  };

  // ============================================================
  // Calculate study streak using user's LOCAL timezone
  // ============================================================
  const calculateStreak = (reviews) => {
    if (!reviews || reviews.length === 0) return 0;
    
    // Get unique study dates in user's LOCAL timezone
    const studyDates = [...new Set(
      reviews.map(r => formatLocalDate(r.created_at))
    )].sort().reverse();

    // Get today and yesterday in user's LOCAL timezone
    const today = formatLocalDate(new Date());
    
    const yesterdayDate = new Date();
    yesterdayDate.setDate(yesterdayDate.getDate() - 1);
    const yesterday = formatLocalDate(yesterdayDate);

    // Streak must start from today or yesterday
    if (studyDates[0] !== today && studyDates[0] !== yesterday) return 0;

    let streak = 0;
    let checkDate = new Date();
    
    // If most recent study was yesterday, start checking from yesterday
    if (studyDates[0] === yesterday) {
      checkDate.setDate(checkDate.getDate() - 1);
    }

    for (let i = 0; i < 365; i++) { // Max 1 year streak
      const dateStr = formatLocalDate(checkDate);
      if (studyDates.includes(dateStr)) {
        streak++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
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
    <PageContainer width="full">
        
        {/* Header Section */}
        <div className="mb-6 sm:mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold">
            {isNewUser 
              ? `Welcome to Recall${userName ? `, ${userName.split(' ')[0]}` : ''}! 👋` 
              : `Welcome back${userName ? `, ${userName.split(' ')[0]}` : ''}! 👋`
            }
          </h1>
          <p className="text-muted-foreground mt-2">
            {isNewUser 
              ? "Let's get you started on your journey to mastering your subjects."
              : reviewsDue > 0 
                ? `You have ${reviewsDue} card${reviewsDue > 1 ? 's' : ''} ready for review`
                : "All caught up! Time to learn something new? 🎉"
            }
          </p>
        </div>

        <div className="space-y-4 sm:space-y-6">
          
          {/* ===== NEW USER ONBOARDING ===== */}
          {isNewUser && (
            <Card className="bg-gradient-to-r from-indigo-50 to-purple-50 border-indigo-200">
              <CardHeader>
                <CardTitle className="text-base sm:text-lg">Get Started</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div>
                    <div className="flex items-center gap-2 mb-2">
                      <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-indigo-600" />
                      <h3 className="font-semibold text-sm sm:text-base">Browse Content</h3>
                    </div>
                    <p className="text-xs sm:text-sm text-gray-700 mb-3">
                      Explore expert notes and flashcards created by professors
                    </p>
                    <div className="flex flex-wrap gap-3">
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

          {/* ===== PRIMARY CTA: START REVIEW ===== */}
          {!isNewUser && reviewsDue > 0 && (
            <Card className="bg-gradient-to-r from-green-50 to-emerald-50 border-green-200">
              <CardContent className="pt-6">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                  <div className="flex items-center gap-3">
                    <div className="p-3 bg-green-100 rounded-full">
                      <Play className="h-5 w-5 sm:h-6 sm:w-6 text-green-600" />
                    </div>
                    <div>
                      <p className="text-lg sm:text-xl font-bold text-green-800">
                        {reviewsDue} card{reviewsDue > 1 ? 's' : ''} ready
                      </p>
                      <p className="text-sm text-green-600">
                        Keep your streak alive!
                      </p>
                    </div>
                  </div>
                  <Button 
                    size="lg" 
                    className="bg-green-600 hover:bg-green-700"
                    onClick={() => navigate('/dashboard/review-session')}
                  >
                    <Play className="mr-2 h-4 w-4" /> Start Review Session
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}

          {/* ===== ALL CAUGHT UP STATE ===== */}
          {!isNewUser && reviewsDue === 0 && (
            <Card className="bg-gradient-to-r from-blue-50 to-indigo-50 border-blue-200">
              <CardContent className="pt-6">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                  <div>
                    <p className="text-lg sm:text-xl font-bold text-blue-800">
                      🎉 All caught up!
                    </p>
                    <p className="text-sm text-blue-600">
                      No scheduled reviews. Time to learn something new?
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')}>
                      Study New Cards
                    </Button>
                    <Button onClick={() => navigate('/dashboard/notes')}>
                      Browse Notes
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* ===== YOUR WEEK STATS ===== */}
          {!isNewUser && (
            <div>
              <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-3">
                📊 Your Week
              </h2>
              <div className="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-xs sm:text-sm font-medium">Reviews</CardTitle>
                    <CheckCircle className="h-3 w-3 sm:h-4 sm:w-4 text-green-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-xl sm:text-2xl font-bold">{cardsReviewedThisWeek}</div>
                    <p className="text-[10px] sm:text-xs text-muted-foreground">Last 7 days</p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-xs sm:text-sm font-medium">Streak</CardTitle>
                    <Flame className="h-3 w-3 sm:h-4 sm:w-4 text-orange-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-xl sm:text-2xl font-bold">{studyStreak}</div>
                    <p className="text-[10px] sm:text-xs text-muted-foreground">
                      {studyStreak === 1 ? 'day' : 'days'} in a row
                    </p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-xs sm:text-sm font-medium">Accuracy</CardTitle>
                    <Target className="h-3 w-3 sm:h-4 sm:w-4 text-blue-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-xl sm:text-2xl font-bold">{accuracy}%</div>
                    <p className="text-[10px] sm:text-xs text-muted-foreground">Easy + Medium</p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-xs sm:text-sm font-medium">Mastered</CardTitle>
                    <Award className="h-3 w-3 sm:h-4 sm:w-4 text-purple-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-xl sm:text-2xl font-bold">{cardsMastered}</div>
                    <p className="text-[10px] sm:text-xs text-muted-foreground">Unique cards</p>
                  </CardContent>
                </Card>
              </div>
            </div>
          )}

          {/* ===== ANONYMOUS CLASS STATS ===== */}
          {!isNewUser && (
            <AnonymousStats
              userReviewsThisWeek={cardsReviewedThisWeek}
              classAverage={classStats.avgReviewsThisWeek}
              studentsStudiedToday={classStats.studentsStudiedToday}
              studentsWithStreak={classStats.studentsWithStreak}
              showComparison={classStats.minUsersMet}
              hasUserActivity={hasUserActivity}
            />
          )}

          {/* ===== RECENT ACTIVITY FEED ===== */}
          {!isNewUser && (
            <ActivityFeed limit={5} />
          )}

          {/* ===== QUICK ACTIONS ===== */}
          {!isNewUser && (
            <div>
              <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide mb-3">
                ⚡ Quick Actions
              </h2>
              <div className="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
                <Card 
                  className="hover:bg-accent cursor-pointer transition hover:border-primary" 
                  onClick={() => navigate('/dashboard/notes')}
                >
                  <CardContent className="pt-4 pb-4">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-purple-100 rounded-lg">
                        <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" />
                      </div>
                      <div>
                        <p className="font-medium text-sm sm:text-base">Browse Notes</p>
                        <p className="text-xs text-muted-foreground">Study materials</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card 
                  className="hover:bg-accent cursor-pointer transition hover:border-primary" 
                  onClick={() => navigate('/dashboard/review-flashcards')}
                >
                  <CardContent className="pt-4 pb-4">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-green-100 rounded-lg">
                        <CreditCard className="h-4 w-4 sm:h-5 sm:w-5 text-green-600" />
                      </div>
                      <div>
                        <p className="font-medium text-sm sm:text-base">Browse Flashcards</p>
                        <p className="text-xs text-muted-foreground">Review & learn</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card 
                  className="hover:bg-accent cursor-pointer transition hover:border-primary" 
                  onClick={() => navigate('/dashboard/flashcards/new')}
                >
                  <CardContent className="pt-4 pb-4">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-blue-100 rounded-lg">
                        <PlusCircle className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
                      </div>
                      <div>
                        <p className="font-medium text-sm sm:text-base">Create Flashcard</p>
                        <p className="text-xs text-muted-foreground">Add your own</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card 
                  className="hover:bg-accent cursor-pointer transition hover:border-primary" 
                  onClick={() => navigate('/dashboard/notes/new')}
                >
                  <CardContent className="pt-4 pb-4">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-amber-100 rounded-lg">
                        <Upload className="h-4 w-4 sm:h-5 sm:w-5 text-amber-600" />
                      </div>
                      <div>
                        <p className="font-medium text-sm sm:text-base">Upload Note</p>
                        <p className="text-xs text-muted-foreground">Photos or PDFs</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </div>
          )}

          {/* ===== MY CONTRIBUTIONS ===== */}
          {!isNewUser && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
                  <BookOpen className="h-4 w-4 sm:h-5 sm:w-5" />
                  My Contributions
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-2">
                  <div 
                    className="flex items-center justify-between p-3 sm:p-4 border rounded-lg hover:border-primary hover:bg-accent cursor-pointer transition"
                    onClick={() => navigate('/dashboard/my-notes')}
                  >
                    <div className="flex items-center gap-2 sm:gap-3">
                      <BookOpen className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" />
                      <div>
                        <p className="font-medium text-xs sm:text-sm">My Notes</p>
                        <p className="text-[10px] sm:text-xs text-muted-foreground">
                          {notesCount} uploaded
                        </p>
                      </div>
                    </div>
                    <span className="text-primary text-xs sm:text-sm">View →</span>
                  </div>

                  <div 
                    className="flex items-center justify-between p-3 sm:p-4 border rounded-lg hover:border-primary hover:bg-accent cursor-pointer transition"
                    onClick={() => navigate('/dashboard/flashcards')}
                  >
                    <div className="flex items-center gap-2 sm:gap-3">
                      <CreditCard className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
                      <div>
                        <p className="font-medium text-xs sm:text-sm">My Flashcards</p>
                        <p className="text-[10px] sm:text-xs text-muted-foreground">
                          {flashcardsCount} created
                        </p>
                      </div>
                    </div>
                    <span className="text-primary text-xs sm:text-sm">View →</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

        </div>
      </PageContainer>
  );
}
