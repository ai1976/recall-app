import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export function useActivityFeed(limit = 5) {
  const { user } = useAuth();
  const [activities, setActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch activity feed
  const fetchActivities = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    try {
      setError(null);

      // First, get user's course_level from profile
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('course_level')
        .eq('id', user.id)
        .single();

      if (profileError) throw profileError;

      const courseLevel = profile?.course_level || null;

      // Call the RPC function with user's course level
      const { data, error: fetchError } = await supabase
        .rpc('get_recent_activity_feed', {
          p_user_id: user.id,
          p_course_level: courseLevel,
          p_limit: limit
        });

      if (fetchError) throw fetchError;

      setActivities(data || []);

    } catch (err) {
      console.error('Error fetching activity feed:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [user, limit]);

  // Initial fetch
  useEffect(() => {
    fetchActivities();
  }, [fetchActivities]);

  return {
    activities,
    loading,
    error,
    refetch: fetchActivities
  };
}
