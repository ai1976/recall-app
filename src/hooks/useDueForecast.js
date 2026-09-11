import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

/**
 * useDueForecast — the same lightweight 3-int `get_due_forecast` RPC already
 * used by Progress.jsx, now shared as a NavDataContext singleton (Sprint 7.2-F)
 * so the nav due-badge and the professor's own due count (7.2-A) don't each
 * fire their own copy.
 */
export function useDueForecast() {
  const { user } = useAuth();
  const [dueToday, setDueToday] = useState(0);
  const [dueNext7, setDueNext7] = useState(0);
  const [dueNext30, setDueNext30] = useState(0);
  const [loading, setLoading] = useState(true);

  const fetchForecast = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }
    try {
      const { data, error } = await supabase.rpc('get_due_forecast', { p_user_id: user.id });
      if (error) throw error;
      const row = data?.[0] ?? null;
      setDueToday(row?.due_today ?? 0);
      setDueNext7(row?.due_next_7 ?? 0);
      setDueNext30(row?.due_next_30 ?? 0);
    } catch (err) {
      console.error('Error fetching due forecast:', err);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchForecast();
  }, [fetchForecast]);

  return { dueToday, dueNext7, dueNext30, loading, refetch: fetchForecast };
}
