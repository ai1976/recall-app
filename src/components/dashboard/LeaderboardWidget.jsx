// LeaderboardWidget.jsx
// Isolated component — manages own state and fetches. The parent Dashboard receives
// zero re-renders from this component's activity.
//
// Tab fetch strategy:
//   Friends tab  → fetches on mount
//   Following tab → fetches lazily (only on first click)
//
// Ranking: reviews_this_week DESC, study_time_this_week_seconds as tiebreaker.
// Tied rows share the same rank number. No streak shown (excluded by design).
// Shows only to role === 'student' (parent guards this — component does not re-check).

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Trophy, RefreshCw } from 'lucide-react';

// ── Formatting ────────────────────────────────────────────────────────────────

function formatStudyTime(seconds) {
  if (!seconds || seconds < 60) return '< 1m';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
}

// ── Sub-components ────────────────────────────────────────────────────────────

function SkeletonRow() {
  return (
    <div className="flex items-center gap-3 px-3 py-2.5 animate-pulse">
      <div className="w-5 h-3.5 bg-gray-200 rounded shrink-0" />
      <div className="flex-1 h-3.5 bg-gray-200 rounded" />
      <div className="w-10 h-3.5 bg-gray-200 rounded" />
      <div className="w-12 h-3.5 bg-gray-200 rounded" />
    </div>
  );
}

function LeaderboardRow({ row, isLast }) {
  return (
    <div
      className={`flex items-center gap-3 px-3 py-2.5 text-sm ${
        row.is_self
          ? 'bg-blue-50 rounded-lg'
          : !isLast
          ? 'border-b border-gray-100'
          : ''
      }`}
    >
      <span className="w-5 text-xs font-semibold text-gray-400 shrink-0 text-right">
        {row.rank}
      </span>
      <span
        className={`flex-1 truncate ${
          row.is_self ? 'font-bold text-gray-900' : 'text-gray-700'
        }`}
      >
        {row.full_name || 'Unknown'}
        {row.is_self && (
          <span className="ml-1 text-[10px] text-blue-500 font-normal">(you)</span>
        )}
      </span>
      <span className="text-gray-600 text-xs whitespace-nowrap">
        {Number(row.reviews_this_week)} rev
      </span>
      <span className="text-gray-500 text-xs whitespace-nowrap w-14 text-right">
        {formatStudyTime(Number(row.study_time_this_week_seconds))}
      </span>
    </div>
  );
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function LeaderboardWidget({ courseLevel }) {
  const { user } = useAuth();

  const [activeTab, setActiveTab] = useState('friends');

  // null = not yet fetched, [] = fetched but empty, [...] = data
  const [friendsData, setFriendsData]       = useState(null);
  const [followingData, setFollowingData]   = useState(null);

  const [friendsLoading, setFriendsLoading]     = useState(false);
  const [followingLoading, setFollowingLoading] = useState(false);
  const [friendsError, setFriendsError]         = useState(false);
  const [followingError, setFollowingError]     = useState(false);

  // Tracks whether following tab has been fetched at least once (for lazy load)
  const [followingFetched, setFollowingFetched] = useState(false);

  const fetchFriends = useCallback(async () => {
    setFriendsLoading(true);
    setFriendsError(false);
    try {
      const { data, error } = await supabase.rpc('get_friends_leaderboard');
      if (error) throw error;
      setFriendsData(data || []);
    } catch (err) {
      console.error('LeaderboardWidget friends error:', err);
      setFriendsError(true);
    } finally {
      setFriendsLoading(false);
    }
  }, []);

  const fetchFollowing = useCallback(async () => {
    setFollowingLoading(true);
    setFollowingError(false);
    try {
      const { data, error } = await supabase.rpc('get_following_leaderboard');
      if (error) throw error;
      setFollowingData(data || []);
    } catch (err) {
      console.error('LeaderboardWidget following error:', err);
      setFollowingError(true);
    } finally {
      setFollowingLoading(false);
      setFollowingFetched(true);
    }
  }, []);

  // Friends tab fetches on mount
  useEffect(() => {
    if (user) fetchFriends();
  }, [user, fetchFriends]);

  const handleTabChange = (tab) => {
    setActiveTab(tab);
    // Following tab fetches lazily — only on first click
    if (tab === 'following' && !followingFetched) {
      fetchFollowing();
    }
  };

  // ── Render helpers ───────────────────────────────────────────────────────

  const renderContent = (data, loading, error, retryFn, emptyMessage) => {
    if (loading) {
      return (
        <div className="space-y-0.5 mt-1">
          {[...Array(4)].map((_, i) => <SkeletonRow key={i} />)}
        </div>
      );
    }
    if (error) {
      return (
        <div className="py-6 text-center">
          <p className="text-sm text-gray-500 mb-3">Could not load leaderboard</p>
          <Button size="sm" variant="outline" onClick={retryFn}>
            <RefreshCw className="h-3 w-3 mr-1.5" />
            Retry
          </Button>
        </div>
      );
    }
    if (!data || data.length === 0) {
      return (
        <p className="py-6 text-center text-sm text-gray-500 px-4">{emptyMessage}</p>
      );
    }
    return (
      <div>
        {/* Column headers */}
        <div className="flex items-center gap-3 px-3 pb-1.5 pt-0.5 text-[10px] text-gray-400 uppercase tracking-wider">
          <span className="w-5 shrink-0 text-right">#</span>
          <span className="flex-1">Name</span>
          <span>Reviews</span>
          <span className="w-14 text-right">Time</span>
        </div>
        {data.map((row, idx) => (
          <LeaderboardRow key={row.user_id} row={row} isLast={idx === data.length - 1} />
        ))}
      </div>
    );
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
        <CardTitle className="text-xs sm:text-sm font-medium">Leaderboard</CardTitle>
        <Trophy className="h-3 w-3 sm:h-4 sm:w-4 text-amber-500" />
      </CardHeader>
      <CardContent className="pt-0">

        {/* Tab switcher */}
        <div className="flex gap-1 p-1 bg-gray-100 rounded-md mb-2">
          <button
            className={`flex-1 text-xs font-medium py-1.5 rounded transition-all ${
              activeTab === 'friends'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => handleTabChange('friends')}
          >
            Friends
          </button>
          <button
            className={`flex-1 text-xs font-medium py-1.5 rounded transition-all ${
              activeTab === 'following'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => handleTabChange('following')}
          >
            Following
          </button>
        </div>

        {/* Tab content */}
        {activeTab === 'friends'
          ? renderContent(
              friendsData,
              friendsLoading,
              friendsError,
              fetchFriends,
              `Add friends studying ${courseLevel || 'your course'} to see how you compare`
            )
          : renderContent(
              followingData,
              followingLoading,
              followingError,
              fetchFollowing,
              'Follow other students to see how you rank'
            )
        }

      </CardContent>
    </Card>
  );
}
