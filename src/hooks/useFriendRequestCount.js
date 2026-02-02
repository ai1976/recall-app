import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export function useFriendRequestCount() {
  const { user } = useAuth();
  const [pendingCount, setPendingCount] = useState(0);
  const [loading, setLoading] = useState(true);

  // Fetch pending friend request count
  const fetchPendingCount = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    try {
      const { count, error } = await supabase
        .from('friendships')
        .select('*', { count: 'exact', head: true })
        .eq('friend_id', user.id)
        .eq('status', 'pending');

      if (error) throw error;

      setPendingCount(count || 0);

    } catch (err) {
      console.error('Error fetching friend request count:', err);
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Initial fetch
  useEffect(() => {
    fetchPendingCount();
  }, [fetchPendingCount]);

  // Subscribe to realtime changes on friendships table
  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel('friend-requests-realtime')
      .on(
        'postgres_changes',
        {
          event: '*', // Listen to INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'friendships',
          filter: `friend_id=eq.${user.id}`
        },
        () => {
          // Refetch count on any change to friendships where user is the recipient
          fetchPendingCount();
        }
      )
      .subscribe();

    // Cleanup subscription on unmount
    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, fetchPendingCount]);

  return {
    pendingCount,
    loading,
    refetch: fetchPendingCount
  };
}
