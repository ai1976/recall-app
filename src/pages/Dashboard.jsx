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
  // eslint-disable-next-line no-unused-vars
  const [user, setUser] = useState(null);
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

  // Professor content stats
  // eslint-disable-next-line no-unused-vars
  const [professorCardsCount, setProfessorCardsCount] = useState(0);

  useEffect(() => {
    fetchUserAndStats();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchUserAndStats = async () => {
    try {
      // Get current user
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (!authUser) {
        navigate('/login');
        return;
      }

      // Get user profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single();

      setUser(profile);

      // Fetch all stats in parallel
      await Promise.all([
        fetchNotesCount(authUser.id),
        fetchFlashcardsCount(authUser.id),
        fetchReviewStats(authUser.id),
        fetchProfessorContent()
      ]);

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
    // Get all reviews for this user
    const { data: reviews } = await supabase
      .from('reviews')
      .select('created_at, quality')
      .eq('user_id', userId)
      .order('created_at', { descending: true });

    if (!reviews || reviews.length === 0) {
      setIsNewUser(true);
      return;
    }

    setIsNewUser(false);

    // Calculate cards reviewed this week
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    const weeklyReviews = reviews.filter(r => new Date(r.created_at) > oneWeekAgo);
    setCardsReviewedThisWeek(weeklyReviews.length);

    // Calculate study streak
    const streak = calculateStreak(reviews);
    setStudyStreak(streak);

    // Calculate accuracy (last 7 days)
    if (weeklyReviews.length > 0) {
      const easyMedium = weeklyReviews.filter(r => r.quality === 5 || r.quality === 3).length;
      const acc = Math.round((easyMedium / weeklyReviews.length) * 100);
      setAccuracy(acc);
    }

    // Calculate cards mastered (unique cards reviewed)
    const { data: uniqueCards } = await supabase
      .from('reviews')
      .select('flashcard_id')
      .eq('user_id', userId);
    
    const unique = new Set(uniqueCards?.map(r => r.flashcard_id) || []);
    setCardsMastered(unique.size);

    // Calculate reviews due today
    const { data: dueCards } = await supabase
      .from('flashcards')
      .select('id')
      .eq('user_id', userId)
      .lte('next_review', new Date().toISOString());
    
    setReviewsDue(dueCards?.length || 0);
  };

  const calculateStreak = (reviews) => {
    if (!reviews || reviews.length === 0) return 0;

    // Get unique dates
    const dates = [...new Set(reviews.map(r => {
      const date = new Date(r.created_at);
      return date.toISOString().split('T')[0];
    }))].sort().reverse();

    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    // Check if most recent review was today or yesterday
    if (dates[0] !== today && dates[0] !== yesterday) {
      return 0; // Streak broken
    }

    // Count consecutive days
    let streak = 0;
    let currentDate = new Date();
    
    for (let i = 0; i < dates.length; i++) {
      const checkDate = new Date(currentDate);
      checkDate.setDate(checkDate.getDate() - i);
      const checkDateStr = checkDate.toISOString().split('T')[0];
      
      if (dates.includes(checkDateStr)) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  };

  const fetchProfessorContent = async () => {
    // Get count of public flashcards
    const { count: cardsCount } = await supabase
      .from('flashcards')
      .select('*', { count: 'exact', head: true })
      .eq('is_public', true);
    
    setProfessorCardsCount(cardsCount || 0);
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
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      
      {/* Welcome Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold flex items-center gap-2">
          {isNewUser ? 'Welcome to Recall! 👋' : 'Welcome back! 👋'}
        </h1>
        <p className="text-muted-foreground mt-2">
          {isNewUser 
            ? "Let's get you started on your journey to mastering your subjects."
            : reviewsDue > 0 
              ? `You have ${reviewsDue} card${reviewsDue > 1 ? 's' : ''} ready for review!`
              : "All caught up! Great work! 🎉"
          }
        </p>
      </div>

      {/* Main Content Area */}
      <div className="space-y-6">
        
        {/* New User Onboarding */}
        {isNewUser && (
          <Card className="bg-gradient-to-r from-indigo-50 to-purple-50 border-indigo-200">
            <CardHeader>
              <CardTitle className="text-lg">Get Started</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                
                {/* Browse Content Section */}
                <div>
                  <div className="flex items-center gap-2 mb-2">
                    <FileText className="h-5 w-5 text-indigo-600" />
                    <h3 className="font-semibold">Browse Content</h3>
                  </div>
                  <p className="text-sm text-gray-700 mb-3">
                    Explore expert notes and flashcards created by professors
                  </p>
                  <div className="flex gap-2">
                    <Button 
                      variant="outline" 
                      onClick={() => navigate('/dashboard/notes')}
                    >
                      <FileText className="mr-2 h-4 w-4" />
                      Browse Notes
                    </Button>
                    <Button 
                      variant="outline"
                      onClick={() => navigate('/dashboard/study')}
                    >
                      <CreditCard className="mr-2 h-4 w-4" />
                      Browse Flashcards
                    </Button>
                  </div>
                </div>

                {/* Optional Create Section */}
                <div className="pt-4 border-t">
                  <p className="text-sm text-gray-700">
                    💡 Don't find what you want? Create your own{' '}
                    <button
                      onClick={() => navigate('/dashboard/notes/new')}
                      className="text-indigo-600 hover:text-indigo-700 underline font-medium"
                    >
                      notes
                    </button>
                    {' '}or{' '}
                    <button
                      onClick={() => navigate('/dashboard/flashcards/new')}
                      className="text-indigo-600 hover:text-indigo-700 underline font-medium"
                    >
                      flashcards
                    </button>
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Reviews Due Card (for returning users) */}
        {!isNewUser && reviewsDue > 0 && (
          <Card className="bg-gradient-to-r from-green-50 to-emerald-50 border-green-200">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CheckCircle className="h-5 w-5 text-green-600" />
                Ready to Review
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-lg font-semibold mb-4">
                {reviewsDue} flashcard{reviewsDue > 1 ? 's' : ''} ready for review
              </p>
              <Button onClick={() => navigate('/dashboard/study')}>
                Start Review Session
              </Button>
            </CardContent>
          </Card>
        )}

        {/* All Caught Up Card (for returning users with no reviews) */}
        {!isNewUser && reviewsDue === 0 && (
          <Card className="bg-gradient-to-r from-green-50 to-emerald-50 border-green-200">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                🎉 All Caught Up!
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground mb-4">
                No reviews due right now. Your next review is scheduled for tomorrow.
              </p>
              <div className="flex gap-2">
                <Button 
                  variant="outline"
                  onClick={() => navigate('/dashboard/flashcards/new')}
                >
                  Practice Anyway
                </Button>
                <Button 
                  onClick={() => navigate('/dashboard/notes')}
                >
                  Browse Content
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Stats Cards */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          
          {/* Cards Reviewed This Week */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                This Week
              </CardTitle>
              <CheckCircle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{cardsReviewedThisWeek}</div>
              <p className="text-xs text-muted-foreground">
                Cards Reviewed
              </p>
            </CardContent>
          </Card>

          {/* Study Streak */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Days
              </CardTitle>
              <Flame className="h-4 w-4 text-orange-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{studyStreak}</div>
              <p className="text-xs text-muted-foreground">
                Day Streak
              </p>
            </CardContent>
          </Card>

          {/* Accuracy */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Last 7 Days
              </CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{accuracy}%</div>
              <p className="text-xs text-muted-foreground">
                Accuracy
              </p>
            </CardContent>
          </Card>

          {/* Cards Mastered */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Total
              </CardTitle>
              <Award className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{cardsMastered}</div>
              <p className="text-xs text-muted-foreground">
                Cards Mastered
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Quick Actions (only for returning users) */}
        {!isNewUser && (
          <div className="grid gap-4 md:grid-cols-2">
            
            {/* Upload Note */}
            <Card className="hover:bg-accent cursor-pointer transition" onClick={() => navigate('/dashboard/notes/new')}>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Upload className="h-5 w-5 text-purple-600" />
                  Upload Note
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  Add photos or PDFs of your notes
                </p>
              </CardContent>
            </Card>

            {/* Create Flashcard */}
            <Card className="hover:bg-accent cursor-pointer transition" onClick={() => navigate('/dashboard/flashcards/new')}>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <PlusCircle className="h-5 w-5 text-blue-600" />
                  Create Flashcard
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  Make your own flashcards
                </p>
              </CardContent>
            </Card>
          </div>
        )}

        {/* Your Contributions (only for returning users) */}
        {!isNewUser && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <BookOpen className="h-5 w-5" />
                Your Contributions
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-4">
                Track your personal study library
              </p>
              <div className="grid gap-4 md:grid-cols-2">
                
                {/* Your Notes */}
                <div className="flex items-center justify-between p-4 border rounded-lg">
                  <div className="flex items-center gap-3">
                    <BookOpen className="h-5 w-5 text-purple-600" />
                    <div>
                      <p className="font-medium text-sm">Your Notes</p>
                      <p className="text-xs text-muted-foreground">{notesCount} uploaded</p>
                    </div>
                  </div>
                  <Button 
                    variant="outline" 
                    size="sm"
                    onClick={() => navigate('/dashboard/notes/new')}
                  >
                    Upload
                  </Button>
                </div>

                {/* Your Flashcards */}
                <div className="flex items-center justify-between p-4 border rounded-lg">
                  <div className="flex items-center gap-3">
                    <CreditCard className="h-5 w-5 text-blue-600" />
                    <div>
                      <p className="font-medium text-sm">Your Flashcards</p>
                      <p className="text-xs text-muted-foreground">{flashcardsCount} created</p>
                    </div>
                  </div>
                  <Button 
                    variant="outline" 
                    size="sm"
                    onClick={() => navigate('/dashboard/flashcards/new')}
                  >
                    Create
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