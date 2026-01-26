import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export function useBadges() {
  const { user } = useAuth();
  const [badges, setBadges] = useState([]);
  const [allBadgeDefinitions, setAllBadgeDefinitions] = useState([]);
  const [unnotifiedBadges, setUnnotifiedBadges] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch all badge definitions and user's earned badges
  const fetchBadges = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    try {
      setError(null);

      // Fetch all badge definitions
      const { data: definitions, error: defError } = await supabase
        .from('badge_definitions')
        .select('*')
        .eq('is_active', true)
        .order('order_num', { ascending: true });

      if (defError) throw defError;

      // Fetch user's earned badges
      const { data: userBadges, error: userError } = await supabase
        .rpc('get_user_badges', { p_user_id: user.id });

      if (userError) throw userError;

      setAllBadgeDefinitions(definitions || []);
      setBadges(userBadges || []);

    } catch (err) {
      console.error('Error fetching badges:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Check for unnotified badges and mark them as notified
  const checkUnnotifiedBadges = useCallback(async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .rpc('get_unnotified_badges', { p_user_id: user.id });

      if (error) throw error;

      if (data && data.length > 0) {
        setUnnotifiedBadges(data);
      }

    } catch (err) {
      console.error('Error checking unnotified badges:', err);
    }
  }, [user]);

  // Clear unnotified badges from state (after toast is shown)
  const clearUnnotifiedBadges = useCallback(() => {
    setUnnotifiedBadges([]);
  }, []);

  // Fetch badges for another user (for display in Find Friends, etc.)
  const fetchUserBadges = useCallback(async (userId) => {
    try {
      const { data, error } = await supabase
        .rpc('get_user_badges', { p_user_id: userId });

      if (error) throw error;
      return data || [];

    } catch (err) {
      console.error('Error fetching user badges:', err);
      return [];
    }
  }, []);

  // Initial fetch
  useEffect(() => {
    fetchBadges();
  }, [fetchBadges]);

  // Check for unnotified badges on mount and periodically
  useEffect(() => {
    if (user) {
      checkUnnotifiedBadges();
      
      // Check every 30 seconds for new badges
      const interval = setInterval(checkUnnotifiedBadges, 30000);
      return () => clearInterval(interval);
    }
  }, [user, checkUnnotifiedBadges]);

  return {
    badges,                    // User's earned badges
    allBadgeDefinitions,       // All available badges
    unnotifiedBadges,          // Newly earned badges (for toast)
    loading,
    error,
    refetch: fetchBadges,
    fetchUserBadges,           // Fetch another user's badges
    clearUnnotifiedBadges      // Clear after showing toast
  };
}