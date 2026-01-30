import React, { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { Calendar, TrendingUp, Target, Award } from 'lucide-react';

// ============================================================
// HELPER: Format date as YYYY-MM-DD in user's LOCAL timezone
// Using 'en-CA' locale gives us ISO format (YYYY-MM-DD) which
// allows correct string comparison for dates.
// ============================================================
const formatLocalDate = (date) => {
  return new Date(date).toLocaleDateString('en-CA');
};

export default function MyProgress() {
  const { user } = useAuth();
  const [stats, setStats] = useState({
    studyStreak: 0,
    cardsReviewed: 0,
    accuracy: 0,
    totalMastered: 0,
    loading: true
  });

  // ✅ FIXED: Function declared BEFORE useEffect
  const fetchProgressStats = async () => {
    if (!user) return;
    
    try {
      // Get reviews from last 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      // ✅ FIXED: Use 'created_at' instead of 'reviewed_at'
      const { data: reviews, error: reviewsError } = await supabase
        .from('reviews')
        .select('*')
        .eq('user_id', user.id)
        .gte('created_at', sevenDaysAgo.toISOString());
      
      if (reviewsError) throw reviewsError;

      // Calculate stats
      const cardsReviewed = reviews?.length || 0;
      
      // Calculate accuracy (Easy = 5, Medium = 3, Hard = 1)
      // Easy + Medium count as correct
      const correctReviews = reviews?.filter(r => r.quality >= 3).length || 0;
      const accuracy = cardsReviewed > 0 
        ? Math.round((correctReviews / cardsReviewed) * 100) 
        : 0;

      // Calculate study streak
      const studyStreak = await calculateStudyStreak(user.id);
      
      // Get unique flashcards mastered
      const uniqueCards = new Set(reviews?.map(r => r.flashcard_id));
      const totalMastered = uniqueCards.size;

      setStats({
        studyStreak,
        cardsReviewed,
        accuracy,
        totalMastered,
        loading: false
      });
      
    } catch (err) {
      console.error('Error fetching progress stats:', err);
      setStats(prev => ({ ...prev, loading: false }));
    }
  };

  // ✅ NOW useEffect can call fetchProgressStats
  useEffect(() => {
    if (user) {
      fetchProgressStats();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  // ============================================================
  // Calculate study streak using user's LOCAL timezone
  // ============================================================
  const calculateStudyStreak = async (userId) => {
    try {
      // ✅ FIXED: Use 'created_at' instead of 'reviewed_at'
      const { data: reviews, error } = await supabase
        .from('reviews')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      
      if (error || !reviews || reviews.length === 0) return 0;

      // ✅ FIXED: Get unique dates in user's LOCAL timezone (not UTC)
      const dates = reviews.map(r => formatLocalDate(r.created_at));
      const uniqueDates = [...new Set(dates)];
      
      // ✅ FIXED: Get today and yesterday in user's LOCAL timezone
      const today = formatLocalDate(new Date());
      
      const yesterdayDate = new Date();
      yesterdayDate.setDate(yesterdayDate.getDate() - 1);
      const yesterday = formatLocalDate(yesterdayDate);
      
      // Check if reviewed today or yesterday
      if (uniqueDates[0] !== today && uniqueDates[0] !== yesterday) {
        return 0; // Streak broken
      }
      
      // Count consecutive days
      let streak = 0;
      let currentDate = new Date();
      
      // If most recent study was yesterday, start checking from yesterday
      if (uniqueDates[0] === yesterday) {
        currentDate.setDate(currentDate.getDate() - 1);
      }
      
      for (let i = 0; i < 365; i++) { // Max 1 year streak
        const checkDateStr = formatLocalDate(currentDate);
        
        if (uniqueDates.includes(checkDateStr)) {
          streak++;
          currentDate.setDate(currentDate.getDate() - 1);
        } else {
          break;
        }
      }
      
      return streak;
      
    } catch (err) {
      console.error('Error calculating streak:', err);
      return 0;
    }
  };

  if (stats.loading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">My Progress</h1>
        
        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Study Streak */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <Calendar className="h-8 w-8 text-orange-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.studyStreak}</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Study Streak</h3>
            <p className="text-xs text-gray-500 mt-1">Consecutive days</p>
          </div>

          {/* Cards Reviewed */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <TrendingUp className="h-8 w-8 text-blue-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.cardsReviewed}</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Cards Reviewed</h3>
            <p className="text-xs text-gray-500 mt-1">Last 7 days</p>
          </div>

          {/* Accuracy */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <Target className="h-8 w-8 text-green-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.accuracy}%</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Accuracy</h3>
            <p className="text-xs text-gray-500 mt-1">Last 7 days</p>
          </div>

          {/* Total Mastered */}
          <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
            <div className="flex items-center justify-between mb-4">
              <Award className="h-8 w-8 text-purple-600" />
              <span className="text-3xl font-bold text-gray-900">{stats.totalMastered}</span>
            </div>
            <h3 className="text-sm font-medium text-gray-600">Cards Mastered</h3>
            <p className="text-xs text-gray-500 mt-1">Unique cards reviewed</p>
          </div>
        </div>

        {/* Empty State */}
        {stats.cardsReviewed === 0 && (
          <div className="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
            <p className="text-blue-800 mb-2">
              <strong>No reviews yet!</strong>
            </p>
            <p className="text-sm text-blue-700">
              Start reviewing flashcards to see your progress statistics.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
