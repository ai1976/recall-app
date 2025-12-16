import { useState, useEffect } from 'react';
import { BarChart3, TrendingUp, Calendar, Flame } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export default function MyProgress() {
  const { user } = useAuth();
  const [stats, setStats] = useState({
    studyStreak: 0,
    cardsReviewed: 0,
    studyTime: 0,
    accuracy: 0,
    loading: true
  });

  useEffect(() => {
    if (user) {
      fetchProgressStats();
    }
  }, [user]);

  const fetchProgressStats = async () => {
    try {
      // Get reviews from last 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const { data: reviews } = await supabase
        .from('reviews')
        .select('*')
        .eq('user_id', user.id)
        .gte('created_at', sevenDaysAgo.toISOString());

      // Calculate accuracy
      let accuracy = 0;
      if (reviews && reviews.length > 0) {
        const easyCount = reviews.filter(r => r.quality >= 4).length;
        const mediumCount = reviews.filter(r => r.quality === 3).length;
        const totalReviewed = reviews.length;
        
        // Simple method: (Easy + Medium) / Total
        accuracy = Math.round(((easyCount + mediumCount) / totalReviewed) * 100);
      }

      // Calculate study streak (reuse from Dashboard)
      const studyStreak = await calculateStudyStreak(user.id);

      setStats({
        studyStreak: studyStreak,
        cardsReviewed: reviews?.length || 0,
        studyTime: 0, // Not implemented yet
        accuracy: accuracy,
        loading: false
      });
    } catch (error) {
      console.error('Error fetching progress stats:', error);
      setStats(prev => ({ ...prev, loading: false }));
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

  if (stats.loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
          <BarChart3 className="h-8 w-8 text-blue-600" />
          My Progress
        </h1>
        <p className="mt-2 text-gray-600">
          Track your study habits and performance
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {/* Study Streak */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Study Streak</p>
              <p className="text-3xl font-bold text-gray-900">{stats.studyStreak}</p>
              <p className="text-xs text-gray-500 mt-1">days</p>
            </div>
            <Flame className="h-12 w-12 text-orange-500" />
          </div>
        </div>

        {/* Cards Reviewed */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Cards Reviewed</p>
              <p className="text-3xl font-bold text-gray-900">{stats.cardsReviewed}</p>
              <p className="text-xs text-gray-500 mt-1">this week</p>
            </div>
            <TrendingUp className="h-12 w-12 text-green-500" />
          </div>
        </div>

        {/* Study Time */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Study Time</p>
              <p className="text-3xl font-bold text-gray-900">{stats.studyTime}</p>
              <p className="text-xs text-gray-500 mt-1">minutes today</p>
            </div>
            <Calendar className="h-12 w-12 text-blue-500" />
          </div>
        </div>

        {/* Accuracy */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Accuracy</p>
              <p className="text-3xl font-bold text-gray-900">{stats.accuracy}%</p>
              <p className="text-xs text-gray-500 mt-1">success rate</p>
            </div>
            <BarChart3 className="h-12 w-12 text-purple-500" />
          </div>
        </div>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
        <BarChart3 className="h-16 w-16 text-blue-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          Detailed Analytics - Coming Soon!
        </h2>
        <p className="text-gray-600 mb-4">
          Track your study patterns, subject-wise performance, and more.
        </p>
        <p className="text-sm text-gray-500">
          Available after Phase 1 launch
        </p>
      </div>
    </div>
  );
}