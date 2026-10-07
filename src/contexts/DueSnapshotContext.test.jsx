// Tests for the shared due snapshot (T-001 brief C v6, C-6.4): one snapshot published only when both RPCs succeed, request numbers that discard a stale
// answer, the previous numbers kept (with an error state) when a refresh fails, refresh on a due-changing signal, on visibility and on page entry only when
// the snapshot is older than 60 seconds.
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn(), from: vi.fn() } }));
const authState = { user: { id: 'u1' } };
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => authState }));

import { supabase } from '@/lib/supabase';
import { notifyReviewDataChanged } from '@/lib/dueSet';
import { DueSnapshotProvider, useDueSnapshot, useRefreshDueSnapshotOnEntry, foldBuckets, STALE_AFTER_MS } from '@/contexts/DueSnapshotContext';

const wrapper = ({ children }) => <DueSnapshotProvider>{children}</DueSnapshotProvider>;

function answers({ today = 3, n7 = 10, n30 = 40, buckets = [1, 2, 3, 4, 5, 6, 7, 8], forecastError = null, bucketsError = null } = {}) {
  return {
    forecast: { data: forecastError ? null : [{ due_today: today, due_next_7: n7, due_next_30: n30 }], error: forecastError },
    buckets: { data: bucketsError ? null : buckets.map((v, i) => ({ bucket_index: i, scheduled_count: v })), error: bucketsError },
  };
}
function mockRpc(a) {
  supabase.rpc.mockImplementation((name) => Promise.resolve(name === 'get_due_forecast' ? a.forecast : a.buckets));
}
const callsOf = (name) => supabase.rpc.mock.calls.filter((c) => c[0] === name).length;

beforeEach(() => {
  supabase.rpc.mockReset();
  authState.user = { id: 'u1' };
  vi.spyOn(console, 'error').mockImplementation(() => {});
});
afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe('foldBuckets', () => {
  it('orders by bucket_index and fills missing lanes with zero', () => {
    expect(foldBuckets([{ bucket_index: 2, scheduled_count: '5' }, { bucket_index: 0, scheduled_count: 1 }])).toEqual([1, 0, 5, 0, 0, 0, 0, 0]);
    expect(foldBuckets(null)).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
  });
});

describe('the snapshot', () => {
  it('is loading until the first answer, then publishes both RPCs as one snapshot', async () => {
    mockRpc(answers());
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    expect(result.current.loading).toBe(true);
    expect(result.current.buckets).toBeNull();
    expect(result.current.dueToday).toBeNull();
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.forecast).toEqual({ due_today: 3, due_next_7: 10, due_next_30: 40 });
    expect(result.current.dueToday).toBe(3);
    expect(result.current.buckets).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(result.current.error).toBeNull();
    expect(supabase.rpc).toHaveBeenCalledWith('get_due_forecast', { p_user_id: 'u1' });
    expect(supabase.rpc).toHaveBeenCalledWith('get_due_forecast_buckets', { p_user_id: 'u1' });
  });

  it('publishes nothing when only one of the two RPCs fails, and shows no snapshot rather than a zero', async () => {
    mockRpc(answers({ bucketsError: { message: 'boom' } }));
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.forecast).toBeNull();
    expect(result.current.buckets).toBeNull();
    expect(result.current.error).toBeTruthy();
    // unknown is null, never 0, on every field a surface reads (nav badge, professor own-due count, Progress tiles, Dashboard strip)
    expect([result.current.dueToday, result.current.dueNext7, result.current.dueNext30]).toEqual([null, null, null]);
    expect(result.current.hasSnapshot).toBe(false);
  });

  it('keeps the previous numbers and sets an error when a refresh fails, then recovers on the next success', async () => {
    mockRpc(answers({ today: 3 }));
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    await waitFor(() => expect(result.current.dueToday).toBe(3));
    mockRpc(answers({ forecastError: { message: 'down' } }));
    await act(async () => { await result.current.refresh(); });
    expect(result.current.dueToday).toBe(3);
    expect(result.current.hasSnapshot).toBe(true);
    expect(result.current.buckets).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(result.current.error).toBeTruthy();
    mockRpc(answers({ today: 5 }));
    await act(async () => { await result.current.refresh(); });
    expect(result.current.dueToday).toBe(5);
    expect(result.current.error).toBeNull();
  });

  it('discards a stale answer: an older, slower request never overwrites a newer one', async () => {
    const pending = [];
    supabase.rpc.mockImplementation((name) => new Promise((resolve) => { pending.push({ name, resolve }); }));
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    // request 1 (initial) is in flight; start request 2
    await act(async () => { result.current.refresh(); });
    expect(pending.length).toBe(4);
    const reply = (p, today) => p.resolve(p.name === 'get_due_forecast' ? answers({ today }).forecast : answers({ buckets: [9, 9, 9, 9, 9, 9, 9, 9] }).buckets);
    // the NEWER request answers first, then the OLDER one answers late
    await act(async () => { reply(pending[2], 7); reply(pending[3], 7); });
    await waitFor(() => expect(result.current.dueToday).toBe(7));
    await act(async () => { reply(pending[0], 1); reply(pending[1], 1); });
    expect(result.current.dueToday).toBe(7);
    expect(result.current.buckets).toEqual([9, 9, 9, 9, 9, 9, 9, 9]);
  });

  it('refreshes when a due-changing wrapper signals', async () => {
    mockRpc(answers({ today: 3 }));
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    await waitFor(() => expect(result.current.dueToday).toBe(3));
    const before = callsOf('get_due_forecast');
    mockRpc(answers({ today: 2 }));
    await act(async () => { notifyReviewDataChanged(); });
    await waitFor(() => expect(result.current.dueToday).toBe(2));
    expect(callsOf('get_due_forecast')).toBe(before + 1);
  });

  it('refreshIfStale does nothing within 60 seconds, refreshes after 60 seconds, and does not duplicate the first load', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    mockRpc(answers());
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    const base = callsOf('get_due_forecast');
    await act(async () => { result.current.refreshIfStale(); });
    expect(callsOf('get_due_forecast')).toBe(base);
    await act(async () => { vi.setSystemTime(Date.now() + STALE_AFTER_MS + 1000); result.current.refreshIfStale(); });
    await waitFor(() => expect(callsOf('get_due_forecast')).toBe(base + 1));
  });

  it('does not start a second load while the very first one is still in flight', async () => {
    supabase.rpc.mockImplementation(() => new Promise(() => {}));
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    await act(async () => { result.current.refreshIfStale(); });
    expect(callsOf('get_due_forecast')).toBe(1);
  });

  it('retries on page entry when the first load failed (no snapshot yet)', async () => {
    mockRpc(answers({ forecastError: { message: 'down' } }));
    const { result } = renderHook(() => { const s = useDueSnapshot(); useRefreshDueSnapshotOnEntry(); return s; }, { wrapper });
    await waitFor(() => expect(result.current.error).toBeTruthy());
    mockRpc(answers({ today: 4 }));
    const { result: entered } = renderHook(() => { const s = useDueSnapshot(); useRefreshDueSnapshotOnEntry(); return s; }, { wrapper });
    await waitFor(() => expect(entered.current.dueToday).toBe(4));
  });

  it('refreshes when the tab becomes visible only if the snapshot is older than 60 seconds', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    mockRpc(answers());
    const { result } = renderHook(() => useDueSnapshot(), { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    const base = callsOf('get_due_forecast');
    Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
    await act(async () => { document.dispatchEvent(new Event('visibilitychange')); });
    expect(callsOf('get_due_forecast')).toBe(base);
    await act(async () => { vi.setSystemTime(Date.now() + STALE_AFTER_MS + 1000); document.dispatchEvent(new Event('visibilitychange')); });
    await waitFor(() => expect(callsOf('get_due_forecast')).toBe(base + 1));
    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
    await act(async () => { vi.setSystemTime(Date.now() + STALE_AFTER_MS * 2); document.dispatchEvent(new Event('visibilitychange')); });
    expect(callsOf('get_due_forecast')).toBe(base + 1);
  });

  it('clears the snapshot and stops fetching when the user signs out', async () => {
    mockRpc(answers());
    const { result, rerender } = renderHook(() => useDueSnapshot(), { wrapper });
    await waitFor(() => expect(result.current.dueToday).toBe(3));
    authState.user = null;
    rerender();
    await waitFor(() => expect(result.current.forecast).toBeNull());
    expect(result.current.loading).toBe(false);
    const base = callsOf('get_due_forecast');
    await act(async () => { notifyReviewDataChanged(); });
    expect(callsOf('get_due_forecast')).toBe(base);
  });
});
