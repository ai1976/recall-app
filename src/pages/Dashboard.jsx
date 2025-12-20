import { useAuth } from '@/contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { 
  FileText, 
  CreditCard, 
  Flame, 
  Upload, 
  BookOpen, 
  TrendingUp,
  Award,
  Zap,
  CheckCircle,
  Clock,
  Users
} from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function Dashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [stats, setStats] = useState({
    reviewsDueToday: 0,
    reviewedThisWeek: 0,
    studyStreak: 0,
    totalCardsMastered: 0,
    accuracy: 0,
    notesCount: 0,
    flashcardsCount: 0,
    professorFlashcards: 0,
    loading: true
  });

  const [professorContent, setProfessorContent] = useState([]);
  const [isNewUser, setIsNewUser] = useState(false);

  // Define all functions BEFORE useEffect
  const checkIfNewUser = async () => {
    try {
      // Check if user has any reviews
      const { count } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      setIsNewUser(count === 0);
    } catch (error) {
      console.error('Error checking new user:', error);
    }
  };

  const calculateStudyStreak = async (userId) => {
    try {
      const { data: reviews } = await supabase
        .from('reviews')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (!reviews || reviews.length === 0) return 0;

      const uniqueDates = [...new Set(
        reviews.map(r => new Date(r.created_at).toDateString())
      )].sort((a, b) => new Date(b) - new Date(a));

      if (uniqueDates.length === 0) return 0;

      const today = new Date().toDateString();
      const yesterday = new Date(Date.now() - 86400000).toDateString();
      const mostRecentDate = uniqueDates[0];

      if (mostRecentDate !== today && mostRecentDate !== yesterday) {
        return 0;
      }

      let streak = 0;
      let currentDate = new Date();
      
      for (let i = 0; i < uniqueDates.length; i++) {
        const expectedDate = new Date(currentDate);
        expectedDate.setDate(expectedDate.getDate() - i);
        const expectedDateStr = expectedDate.toDateString();
        
        if (uniqueDates[i] === expectedDateStr) {
          streak++;
        } else {
          break;
        }
      }

      return streak;
    } catch (error) {
      console.error('Error calculating streak:', error);
      return 0;
    }
  };

  const fetchStats = async () => {
    try {
      // Fetch reviews due today
      const today = new Date().toISOString().split('T')[0];
      const { count: dueCount } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .lte('next_review', today);

      // Fetch reviews this week
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      const { count: weekCount } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .gte('created_at', weekAgo.toISOString());

      // Calculate study streak
      const studyStreak = await calculateStudyStreak(user.id);

      // Calculate accuracy (last 7 days)
      const { data: recentReviews } = await supabase
        .from('reviews')
        .select('quality')
        .eq('user_id', user.id)
        .gte('created_at', weekAgo.toISOString());

      let accuracy = 0;
      if (recentReviews && recentReviews.length > 0) {
        const correctReviews = recentReviews.filter(r => r.quality >= 3).length;
        accuracy = Math.round((correctReviews / recentReviews.length) * 100);
      }

      // Fetch total cards mastered (reviewed at least once)
      const { data: masteredCards } = await supabase
        .from('reviews')
        .select('flashcard_id')
        .eq('user_id', user.id);

      const uniqueCards = new Set(masteredCards?.map(r => r.flashcard_id) || []);

      // Fetch notes count
      const { count: notesCount } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      // Fetch flashcards count
      const { count: flashcardsCount } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      // Fetch professor flashcards count (for all users to see)
      const { count: professorCount } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('is_verified', true);

      setStats({
        reviewsDueToday: dueCount || 0,
        reviewedThisWeek: weekCount || 0,
        studyStreak: studyStreak,
        totalCardsMastered: uniqueCards.size,
        accuracy: accuracy,
        notesCount: notesCount || 0,
        flashcardsCount: flashcardsCount || 0,
        professorFlashcards: professorCount || 0,
        loading: false
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
      setStats(prev => ({ ...prev, loading: false }));
    }
  };

  const fetchProfessorContent = async () => {
    try {
      // Fetch professor-verified flashcards grouped by subject
      const { data: flashcards } = await supabase
        .from('flashcards')
        .select(`
          id,
          subject_id,
          subjects (name),
          users!flashcards_contributed_by_fkey (full_name, role)
        `)
        .eq('is_verified', true)
        .limit(5);

      // Group by subject
      const grouped = {};
      flashcards?.forEach(card => {
        const subjectName = card.subjects?.name || 'General';
        if (!grouped[subjectName]) {
          grouped[subjectName] = {
            subject: subjectName,
            count: 0,
            professors: new Set()
          };
        }
        grouped[subjectName].count++;
        if (card.users?.full_name) {
          grouped[subjectName].professors.add(card.users.full_name);
        }
      });

      const contentArray = Object.values(grouped).map(item => ({
        subject: item.subject,
        count: item.count,
        professors: Array.from(item.professors)
      }));

      setProfessorContent(contentArray);
    } catch (error) {
      console.error('Error fetching professor content:', error);
    }
  };

  // useEffect now comes AFTER all function definitions
  useEffect(() => {
    if (user) {
      fetchStats();
      fetchProfessorContent();
      checkIfNewUser();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  if (stats.loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  // NEW USER EXPERIENCE
  if (isNewUser) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
        <main className="max-w-4xl mx-auto px-4 py-12 sm:px-6 lg:px-8">
          {/* Welcome Hero */}
          <div className="text-center mb-12">
            <div className="mb-4">
              <span className="text-6xl">👋</span>
            </div>
            <h1 className="text-4xl font-bold text-gray-900 mb-4">
              Welcome to Recall!
            </h1>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Let's get you started on your journey to mastering your subjects.
            </p>
          </div>

          {/* Quick Start Steps */}
          <div className="space-y-6 mb-12">
            {/* Step 1: Review Professor Content */}
            <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-xl p-8 shadow-lg">
              <div className="flex items-start space-x-4">
                <div className="bg-white text-blue-600 rounded-full w-12 h-12 flex items-center justify-center text-xl font-bold flex-shrink-0">
                  1
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold mb-2">
                    Start with Expert Flashcards
                  </h3>
                  <p className="text-blue-100 mb-6">
                    {stats.professorFlashcards}+ expert-verified flashcards ready for you. 
                    Takes just 5 minutes to see value!
                  </p>
                  <Button 
                    onClick={() => navigate('/dashboard/study')}
                    className="bg-white text-blue-600 hover:bg-blue-50 font-semibold px-8 py-3 text-lg"
                  >
                    <Zap className="h-5 w-5 mr-2" />
                    Start Reviewing Now
                  </Button>
                </div>
              </div>
            </div>

            {/* Step 2: Upload Your Note */}
            <div className="bg-white rounded-xl p-8 shadow-md border-2 border-gray-200">
              <div className="flex items-start space-x-4">
                <div className="bg-purple-100 text-purple-600 rounded-full w-12 h-12 flex items-center justify-center text-xl font-bold flex-shrink-0">
                  2
                </div>
                <div className="flex-1">
                  <h3 className="text-xl font-bold text-gray-900 mb-2">
                    Upload Your First Note
                  </h3>
                  <p className="text-gray-600 mb-4">
                    Take a photo of your handwritten notes or upload a PDF.
                  </p>
                  <Button 
                    onClick={() => navigate('/dashboard/notes/new')}
                    variant="outline"
                    className="border-purple-600 text-purple-600 hover:bg-purple-50"
                  >
                    <Upload className="h-4 w-4 mr-2" />
                    Upload Note
                  </Button>
                </div>
              </div>
            </div>

            {/* Step 3: Create Flashcard */}
            <div className="bg-white rounded-xl p-8 shadow-md border-2 border-gray-200">
              <div className="flex items-start space-x-4">
                <div className="bg-green-100 text-green-600 rounded-full w-12 h-12 flex items-center justify-center text-xl font-bold flex-shrink-0">
                  3
                </div>
                <div className="flex-1">
                  <h3 className="text-xl font-bold text-gray-900 mb-2">
                    Create Your First Flashcard
                  </h3>
                  <p className="text-gray-600 mb-4">
                    Build your own flashcard collection alongside expert content.
                  </p>
                  <Button 
                    onClick={() => navigate('/dashboard/flashcards/new')}
                    variant="outline"
                    className="border-green-600 text-green-600 hover:bg-green-50"
                  >
                    <CreditCard className="h-4 w-4 mr-2" />
                    Create Flashcard
                  </Button>
                </div>
              </div>
            </div>
          </div>

          {/* Tip */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
            <p className="text-blue-900 font-semibold mb-2">💡 Pro Tip</p>
            <p className="text-blue-800">
              Review expert flashcards daily for just 5-10 minutes to build a powerful study habit!
            </p>
          </div>
        </main>
      </div>
    );
  }

  // REGULAR DASHBOARD (Returning Users)
  return (
    <div className="min-h-screen bg-gray-50">
      <main className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">
            Welcome back! 👋
          </h2>
          <p className="text-gray-600">
            {stats.reviewsDueToday > 0 
              ? `You have ${stats.reviewsDueToday} flashcard${stats.reviewsDueToday === 1 ? '' : 's'} due today.`
              : "All caught up! Great work! 🎉"
            }
          </p>
        </div>

        {/* PRIMARY ACTION: Review Cards */}
        {stats.reviewsDueToday > 0 ? (
          <div className="bg-gradient-to-r from-blue-600 to-purple-600 rounded-xl shadow-lg p-8 mb-8 text-white">
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <div className="flex items-center space-x-2 mb-3">
                  <BookOpen className="h-6 w-6" />
                  <h3 className="text-2xl font-bold">Ready to Review</h3>
                </div>
                <p className="text-xl mb-2">
                  {stats.reviewsDueToday} flashcard{stats.reviewsDueToday === 1 ? '' : 's'} due today
                </p>
                <p className="text-blue-100 mb-6">
                  Keep your {stats.studyStreak}-day streak alive! 🔥
                </p>
                <Button 
                  onClick={() => navigate('/dashboard/study')}
                  className="bg-white text-blue-600 hover:bg-blue-50 font-semibold px-8 py-3 text-lg"
                >
                  <Zap className="h-5 w-5 mr-2" />
                  Start Review Session
                </Button>
              </div>
              <div className="hidden md:block">
                <div className="text-8xl opacity-20">📚</div>
              </div>
            </div>
          </div>
        ) : (
          // All Caught Up State
          <div className="bg-green-50 border-2 border-green-200 rounded-xl p-8 mb-8">
            <div className="text-center">
              <div className="text-6xl mb-4">🎉</div>
              <h3 className="text-2xl font-bold text-green-900 mb-2">All Caught Up!</h3>
              <p className="text-green-800 mb-6">
                No reviews due right now. Your next review is scheduled for tomorrow.
              </p>
              <div className="flex justify-center space-x-4">
                <Button 
                  onClick={() => navigate('/dashboard/study')}
                  className="bg-green-600 hover:bg-green-700 text-white"
                >
                  Practice Anyway
                </Button>
                <Button 
                  onClick={() => navigate('/dashboard/notes')}
                  variant="outline"
                  className="border-green-600 text-green-600 hover:bg-green-50"
                >
                  Browse Content
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* Stats Cards - Student Focus */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          {/* Cards Reviewed This Week */}
          <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <CheckCircle className="h-10 w-10 text-green-600" />
              <span className="text-sm font-medium text-gray-500">This Week</span>
            </div>
            <p className="text-3xl font-bold text-gray-900 mb-1">
              {stats.reviewedThisWeek}
            </p>
            <p className="text-sm text-gray-600">Cards Reviewed</p>
          </div>

          {/* Study Streak */}
          <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <Flame className="h-10 w-10 text-orange-500" />
              <span className="text-sm font-medium text-gray-500">Days</span>
            </div>
            <p className="text-3xl font-bold text-gray-900 mb-1">
              {stats.studyStreak}
            </p>
            <p className="text-sm text-gray-600">Day Streak</p>
          </div>

          {/* Accuracy */}
          <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <TrendingUp className="h-10 w-10 text-blue-600" />
              <span className="text-sm font-medium text-gray-500">Last 7 Days</span>
            </div>
            <p className="text-3xl font-bold text-gray-900 mb-1">
              {stats.accuracy}%
            </p>
            <p className="text-sm text-gray-600">Accuracy</p>
          </div>

          {/* Total Cards Mastered */}
          <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <Award className="h-10 w-10 text-purple-600" />
              <span className="text-sm font-medium text-gray-500">Total</span>
            </div>
            <p className="text-3xl font-bold text-gray-900 mb-1">
              {stats.totalCardsMastered}
            </p>
            <p className="text-sm text-gray-600">Cards Mastered</p>
          </div>
        </div>

        {/* Featured Professor Content */}
        {professorContent.length > 0 && (
          <div className="bg-white rounded-lg shadow p-6 mb-8">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center space-x-2">
                <Award className="h-6 w-6 text-blue-600" />
                <h3 className="text-xl font-bold text-gray-900">Expert Content Available</h3>
              </div>
              <Button 
                onClick={() => navigate('/dashboard/notes')}
                variant="outline"
                size="sm"
              >
                Browse All
              </Button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {professorContent.slice(0, 3).map((content, index) => (
                <div 
                  key={index}
                  className="border-2 border-gray-200 rounded-lg p-4 hover:border-blue-500 hover:bg-blue-50 transition-all cursor-pointer"
                  onClick={() => navigate('/dashboard/study')}
                >
                  <div className="flex items-start justify-between mb-2">
                    <h4 className="font-semibold text-gray-900">{content.subject}</h4>
                    <span className="bg-blue-100 text-blue-800 text-xs font-semibold px-2 py-1 rounded">
                      {content.count} cards
                    </span>
                  </div>
                  {content.professors.length > 0 && (
                    <p className="text-sm text-gray-600">
                      by {content.professors.join(', ')}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Quick Actions - Secondary */}
        <div className="bg-white rounded-lg shadow p-6 mb-8">
          <div className="flex items-center space-x-2 mb-4">
            <Users className="h-5 w-5 text-gray-600" />
            <h3 className="text-lg font-semibold text-gray-900">Want to Contribute?</h3>
          </div>
          <p className="text-gray-600 mb-4">
            Add your own notes and flashcards to build your personal study library.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Upload Note */}
            <button
              onClick={() => navigate('/dashboard/notes/new')}
              className="flex items-center gap-4 p-4 border-2 border-gray-200 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-all text-left"
            >
              <Upload className="h-8 w-8 text-purple-600" />
              <div>
                <h4 className="font-semibold text-gray-900">Upload Note</h4>
                <p className="text-sm text-gray-600">Add photos or PDFs of your notes</p>
              </div>
            </button>

            {/* Create Flashcard */}
            <button
              onClick={() => navigate('/dashboard/flashcards/new')}
              className="flex items-center gap-4 p-4 border-2 border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all text-left"
            >
              <CreditCard className="h-8 w-8 text-blue-600" />
              <div>
                <h4 className="font-semibold text-gray-900">Create Flashcard</h4>
                <p className="text-sm text-gray-600">Make your own flashcards</p>
              </div>
            </button>
          </div>
        </div>

        {/* Creator Stats (Small Section) */}
        {(stats.notesCount > 0 || stats.flashcardsCount > 0) && (
          <div className="bg-gray-100 rounded-lg p-6">
            <h3 className="text-sm font-semibold text-gray-600 mb-4">Your Contributions</h3>
            <div className="flex space-x-8">
              <div>
                <p className="text-2xl font-bold text-gray-900">{stats.notesCount}</p>
                <p className="text-sm text-gray-600">Notes Uploaded</p>
              </div>
              <div>
                <p className="text-2xl font-bold text-gray-900">{stats.flashcardsCount}</p>
                <p className="text-sm text-gray-600">Flashcards Created</p>
              </div>
            </div>
            <Button 
              onClick={() => navigate('/dashboard/my-contributions')}
              variant="link"
              className="mt-4 p-0 h-auto text-blue-600"
            >
              View All Contributions →
            </Button>
          </div>
        )}
      </main>
    </div>
  );
}
