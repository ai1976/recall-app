/**
 * DueSnapshotContext.jsx — ONE published snapshot of the signed-in user's due set.
 *
 * T-001 brief C v6 (C-6.4). The Review badge (nav), the Progress "due today / next 7 / next 30" tiles, the Dashboard zero-state strip and the Dashboard
 * Forward Load chart all read this one snapshot, so they can never disagree with each other. It replaces the separate `get_due_forecast` calls that
 * NavDataContext (via useDueForecast), Progress and Dashboard each made, and Dashboard's `get_study_queue` length for the zero-state strip.
 *
 * Rules (each is tested in DueSnapshotContext.test.jsx):
 *   - Both RPCs (`get_due_forecast`, `get_due_forecast_buckets`) are fetched together; a snapshot is published only when BOTH succeed, as one object.
 *   - Every request gets a number; a response that is not from the latest request is discarded (an older, slower answer never overwrites a newer one).
 *   - A failed refresh keeps the previous snapshot and sets `error`; the next successful refresh clears it. With no snapshot at all, `dueToday`, `dueNext7`,
 *     `dueNext30` and `forecast` are null (never 0), so no surface can show "nothing due" because of a failure.
 *   - A refresh is requested when: a due-changing wrapper in src/lib/dueSet.js signals success (`subscribeReviewDataChanged`; graded answers are already
 *     debounced there), the tab becomes visible and the snapshot is older than 60 seconds, and a page that shows the numbers (Dashboard, Progress, Review)
 *     is entered while the snapshot is older than 60 seconds (`useRefreshDueSnapshotOnEntry`).
 *
 * Limit, stated: a change made by another user or on another device cannot signal this tab; the numbers catch up on the next visibility or page-entry
 * refresh after 60 seconds.
 */

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { subscribeReviewDataChanged } from '@/lib/dueSet';

export const STALE_AFTER_MS = 60 * 1000;
export const BUCKET_COUNT = 8;

/** Fold the 8-row `get_due_forecast_buckets` result into a number[8] ordered by bucket_index (missing rows are 0). */
// eslint-disable-next-line react-refresh/only-export-components
export function foldBuckets(rows) {
  return Array.from({ length: BUCKET_COUNT }, (_, i) => {
    const row = (rows || []).find((r) => Number(r.bucket_index) === i);
    return row ? Number(row.scheduled_count) || 0 : 0;
  });
}

const DueSnapshotContext = createContext(null);

export function DueSnapshotProvider({ children }) {
  const { user } = useAuth();
  const userId = user?.id ?? null;
  const [state, setState] = useState({ snapshot: null, loading: Boolean(userId), error: null });
  const seq = useRef(0);          // number of the latest request
  const inflight = useRef(false); // whether the latest request has not answered yet
  const latest = useRef(null);    // latest published snapshot (for staleness checks outside React state)

  const load = useCallback(async () => {
    if (!userId) return;
    const id = ++seq.current;
    inflight.current = true;
    try {
      const [forecast, buckets] = await Promise.all([
        supabase.rpc('get_due_forecast', { p_user_id: userId }),
        supabase.rpc('get_due_forecast_buckets', { p_user_id: userId }),
      ]);
      if (id !== seq.current) return; // a newer request exists: this answer is stale
      const failure = forecast.error || buckets.error;
      if (failure) throw failure;
      const row = forecast.data?.[0] ?? null;
      const snapshot = {
        row: row ? { due_today: Number(row.due_today) || 0, due_next_7: Number(row.due_next_7) || 0, due_next_30: Number(row.due_next_30) || 0 } : { due_today: 0, due_next_7: 0, due_next_30: 0 },
        buckets: foldBuckets(buckets.data),
        fetchedAt: Date.now(),
      };
      latest.current = snapshot;
      inflight.current = false;
      setState({ snapshot, loading: false, error: null });
    } catch (err) {
      if (id !== seq.current) return;
      inflight.current = false;
      console.error('Due snapshot refresh failed (keeping the previous numbers):', err);
      setState((s) => ({ snapshot: s.snapshot, loading: false, error: err }));
    }
  }, [userId]);

  // A new user (or sign-out) invalidates everything in flight and starts clean.
  useEffect(() => {
    seq.current += 1;
    inflight.current = false;
    latest.current = null;
    if (!userId) {
      setState({ snapshot: null, loading: false, error: null });
      return;
    }
    setState({ snapshot: null, loading: true, error: null });
    load();
  }, [userId, load]);

  // A due-changing wrapper succeeded: refresh now.
  useEffect(() => subscribeReviewDataChanged(() => { load(); }), [load]);

  const isStale = useCallback(() => !latest.current || Date.now() - latest.current.fetchedAt > STALE_AFTER_MS, []);

  const refreshIfStale = useCallback(() => {
    if (!userId) return;
    if (!latest.current && inflight.current) return; // the first load is already on its way
    if (isStale()) load();
  }, [userId, isStale, load]);

  // The tab became visible again: refresh when older than 60 seconds.
  useEffect(() => {
    const onVisible = () => { if (document.visibilityState === 'visible') refreshIfStale(); };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [refreshIfStale]);

  const value = useMemo(() => {
    const row = state.snapshot?.row ?? null;
    return {
      forecast: row,                                   // { due_today, due_next_7, due_next_30 } or null until the first success
      // null means "not known" (no snapshot yet, or the first load failed). It is never 0: a consumer must show a dash or nothing, not "nothing due".
      dueToday: row ? row.due_today : null,
      dueNext7: row ? row.due_next_7 : null,
      dueNext30: row ? row.due_next_30 : null,
      hasSnapshot: row !== null,
      buckets: state.snapshot?.buckets ?? null,        // number[8] or null until the first success
      fetchedAt: state.snapshot?.fetchedAt ?? null,
      loading: state.loading,                          // true only until the first answer
      error: state.error,                              // set when the latest refresh failed; the previous numbers stay
      refresh: load,
      refreshIfStale,
    };
  }, [state, load, refreshIfStale]);

  return <DueSnapshotContext.Provider value={value}>{children}</DueSnapshotContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useDueSnapshot() {
  const ctx = useContext(DueSnapshotContext);
  if (!ctx) throw new Error('useDueSnapshot must be used within <DueSnapshotProvider>');
  return ctx;
}

/** Call from a page that shows the due numbers (Dashboard, Progress, Review): refresh on entry when the snapshot is older than 60 seconds. */
// eslint-disable-next-line react-refresh/only-export-components
export function useRefreshDueSnapshotOnEntry() {
  const { refreshIfStale } = useDueSnapshot();
  useEffect(() => { refreshIfStale(); }, [refreshIfStale]);
}
