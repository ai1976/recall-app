import { useAuth } from '@/contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { FileText, CreditCard, Flame, Upload, BookOpen } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function Dashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [stats, setStats] = useState({
    notesCount: 0,
    flashcardsCount: 0,
    studyStreak: 0,
    loading: true
  });

  useEffect(() => {
    if (user) {
      fetchStats();
    }
  }, [user]);

  const fetchStats = async () => {
    try {
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

      // Calculate study streak
      const studyStreak = await calculateStudyStreak(user.id);

      setStats({
        notesCount: notesCount || 0,
        flashcardsCount: flashcardsCount || 0,
        studyStreak: studyStreak,
        loading: false
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
      setStats(prev => ({ ...prev, loading: false }));
    }
  };

  const calculateStudyStreak = async (userId) => {
    try {
      // Get all review dates, sorted by date
      const { data: reviews } = await supabase
        .from('reviews')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (!reviews || reviews.length === 0) return 0;

      // Get unique dates (ignore time)
      const uniqueDates = [...new Set(
        reviews.map(r => new Date(r.created_at).toDateString())
      )].sort((a, b) => new Date(b) - new Date(a));

      if (uniqueDates.length === 0) return 0;

      // Check if most recent review was today or yesterday
      const today = new Date().toDateString();
      const yesterday = new Date(Date.now() - 86400000).toDateString();
      const mostRecentDate = uniqueDates[0];

      if (mostRecentDate !== today && mostRecentDate !== yesterday) {
        return 0; // Streak broken
      }

      // Count consecutive days
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

  if (stats.loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <main className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">
            Welcome back! 👋
          </h2>
          <p className="text-gray-600">
            Ready to make your study session count?
          </p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          {/* Notes Uploaded */}
          <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <FileText className="h-10 w-10 text-blue-600" />
              <span className="text-sm font-medium text-gray-500">Total</span>
            </div>
            <p className="text-3xl font-bold text-gray-900 mb-1">
              {stats.notesCount}
            </p>
            <p className="text-sm text-gray-600">Notes Uploaded</p>
          </div>

          {/* Flashcards Created */}
          <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <CreditCard className="h-10 w-10 text-purple-600" />
              <span className="text-sm font-medium text-gray-500">Total</span>
            </div>
            <p className="text-3xl font-bold text-gray-900 mb-1">
              {stats.flashcardsCount}
            </p>
            <p className="text-sm text-gray-600">Flashcards Created</p>
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
        </div>

        {/* Quick Actions */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4">Quick Actions</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Upload Note */}
            <button
              onClick={() => navigate('/dashboard/notes/new')}
              className="flex items-center gap-4 p-4 border-2 border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all text-left"
            >
              <Upload className="h-8 w-8 text-blue-600" />
              <div>
                <h4 className="font-semibold text-gray-900">Upload Note</h4>
                <p className="text-sm text-gray-600">Add a new photo or PDF of your notes</p>
              </div>
            </button>

            {/* My Notes */}
            <button
              onClick={() => navigate('/dashboard/notes')}
              className="flex items-center gap-4 p-4 border-2 border-gray-200 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-all text-left"
            >
              <FileText className="h-8 w-8 text-purple-600" />
              <div>
                <h4 className="font-semibold text-gray-900">My Notes</h4>
                <p className="text-sm text-gray-600">View and manage your notes</p>
              </div>
            </button>
          </div>
        </div>

        {/* Recent Notes Section (Optional - Coming Soon) */}
        <div className="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-blue-900 mb-2">📚 Recent Notes</h3>
          <p className="text-blue-800">
            Your recently uploaded notes will appear here. Keep uploading to build your study library!
          </p>
        </div>
      </main>
    </div>
  );
}