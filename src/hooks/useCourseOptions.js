// T-002 F1 - loads the course catalogue rows for one screen, routed by the session state.
//
// Nothing is called until AuthContext.loading has resolved (plan v18 section 8, routing): with a session the authenticated reader is used (the student's
// current course and own earlier labels are added), without one the public list. `status` is 'idle' (waiting for the session state, or disabled),
// 'loading', 'ready' (rows follow the contract) or 'error' (the call failed or the rows broke the contract: the screen shows its neutral state).

import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { fetchCourseOptions } from '@/lib/courseOptions';

export function useCourseOptions(surface, { enabled = true } = {}) {
  const { user, loading: authLoading } = useAuth();
  const userId = user ? user.id : null;
  const [result, setResult] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);

  // One request per (surface, session, reload); `requestKey` is null while nothing may be called.
  const requestKey = enabled && !authLoading ? `${surface}|${userId === null ? '' : userId}|${reloadKey}` : null;

  useEffect(() => {
    if (requestKey === null) return undefined;
    let cancelled = false;
    fetchCourseOptions(surface, userId !== null).then((fetched) => {
      if (!cancelled) setResult({ key: requestKey, ok: fetched.ok, rows: fetched.ok ? fetched.rows : [] });
    });
    return () => {
      cancelled = true;
    };
  }, [requestKey, surface, userId]);

  const reload = useCallback(() => setReloadKey((key) => key + 1), []);

  if (requestKey === null) return { status: 'idle', rows: [], reload };
  if (result && result.key === requestKey) return { status: result.ok ? 'ready' : 'error', rows: result.rows, reload };
  return { status: 'loading', rows: [], reload };
}
