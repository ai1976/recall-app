// studyTracker.test.js — Sprint 8.8.5b2 (D-46). Covers the shared study-time tracker's rules:
// active-time counting, hidden/idle pause+resume, four-hour stop, idempotent save, recovery window, legacy records.
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

const { insert } = vi.hoisted(() => ({ insert: vi.fn() }));
vi.mock('@/lib/supabase', () => ({ supabase: { from: () => ({ insert }) } }));

import {
  StudyTracker, validateRecord, persistRecord, recoverInterrupted, subscribeRecovery, makeUuid, localDateOf,
  MAX_ACTIVE_MS, IDLE_MS, HEARTBEAT_MS, RECOVERY_WINDOW_MS, TRACKER_VERSION,
} from '@/lib/studyTracker';

const U = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const T0 = new Date('2026-09-30T10:00:00Z').getTime();
const KEY = (id) => `revisop_study_session_v2:${id}`;

function record(over = {}) {
  const startedAt = over.startedAt ?? T0 - 3_600_000;
  const activeMs = over.activeMs ?? 41 * 60_000;
  return {
    trackerVersion: TRACKER_VERSION, sessionId: makeUuid(), userId: U, source: 'study_mode',
    startedAt, lastActiveAt: over.lastActiveAt ?? startedAt + activeMs + 60_000, activeMs,
    sessionDate: localDateOf(startedAt), ...over,
  };
}
const store = (rec) => localStorage.setItem(KEY(rec.sessionId), JSON.stringify(rec));
const stored = () => Object.keys(localStorage).filter((k) => k.startsWith('revisop_study_session_v2:'));
const setVisibility = (v) => {
  Object.defineProperty(document, 'visibilityState', { value: v, configurable: true });
  document.dispatchEvent(new Event('visibilitychange'));
};
const interact = () => window.dispatchEvent(new Event('pointerdown'));
async function advance(ms, { interactEvery = 0 } = {}) {
  let left = ms;
  while (left > 0) {
    const step = Math.min(left, HEARTBEAT_MS);
    if (interactEvery) interact();
    await vi.advanceTimersByTimeAsync(step);
    left -= step;
  }
}

beforeEach(() => {
  localStorage.clear();
  insert.mockReset();
  insert.mockResolvedValue({ error: null });
  vi.useFakeTimers();
  vi.setSystemTime(T0);
  setVisibility('visible');
});
afterEach(() => { vi.useRealTimers(); });

describe('validateRecord', () => {
  it('accepts a plausible recent v2 record', () => {
    expect(validateRecord(record(), T0).ok).toBe(true);
  });
  it('rejects a legacy / wrong-version record', () => {
    expect(validateRecord({ startedAt: T0 - 1e9 }, T0).ok).toBe(false);
    expect(validateRecord(record({ trackerVersion: 1 }), T0).reason).toBe('wrong_version');
  });
  it('rejects active time longer than the wall-clock span, over 4h, or future-dated', () => {
    expect(validateRecord(record({ activeMs: 3 * 3_600_000, lastActiveAt: T0 - 3_000_000 }), T0).reason).toBe('duration_exceeds_span');
    expect(validateRecord(record({ startedAt: T0 - 6 * 3_600_000, activeMs: MAX_ACTIVE_MS + 1, lastActiveAt: T0 - 3_600_000 }), T0).reason).toBe('implausible_duration');
    expect(validateRecord(record({ lastActiveAt: T0 + 3_600_000 }), T0).reason).toBe('future_timestamp');
  });
  it('flags a record older than 7 days as too_old but accepts one just inside', () => {
    const old = record({ startedAt: T0 - RECOVERY_WINDOW_MS - 3_600_000 });
    expect(validateRecord(old, T0).reason).toBe('too_old');
    const edge = record({ startedAt: T0 - RECOVERY_WINDOW_MS + 7_200_000 });
    expect(validateRecord(edge, T0).ok).toBe(true);
  });
});

describe('persistRecord', () => {
  it('saves with the stable session_id and the recorded active duration (never now - start)', async () => {
    const rec = record({ startedAt: T0 - 6 * 3_600_000, activeMs: 90 * 60_000, lastActiveAt: T0 });
    const res = await persistRecord(rec);
    expect(res).toMatchObject({ outcome: 'saved', seconds: 5400 });
    expect(insert.mock.calls[0][0]).toMatchObject({ session_id: rec.sessionId, duration_seconds: 5400, source: 'study_mode', user_id: U });
  });
  it('treats a duplicate on the session index as already saved, not an error', async () => {
    insert.mockResolvedValueOnce({ error: { code: '23505', message: 'duplicate key value violates unique constraint "study_sessions_user_session_uidx"' } });
    expect((await persistRecord(record())).outcome).toBe('duplicate');
  });
  it('separates permanent rejection (23514) from transient failure', async () => {
    insert.mockResolvedValueOnce({ error: { code: '23514', message: 'check violation' } });
    expect((await persistRecord(record())).outcome).toBe('rejected');
    insert.mockResolvedValueOnce({ error: { code: '', message: 'Failed to fetch' } });
    expect((await persistRecord(record())).outcome).toBe('failed');
    insert.mockRejectedValueOnce(new Error('offline'));
    expect((await persistRecord(record())).outcome).toBe('failed');
  });
  it('skips sessions under the 10 second noise floor', async () => {
    const res = await persistRecord(record({ activeMs: 5_000, lastActiveAt: T0 - 3_599_000 }));
    expect(res.outcome).toBe('too_short');
    expect(insert).not.toHaveBeenCalled();
  });
});

describe('recovery', () => {
  it('recovers a recent interrupted session from its recorded active time and dates it by lastActiveAt', async () => {
    const rec = record({ startedAt: T0 - 5 * 86_400_000, activeMs: 41 * 60_000 });
    store(rec);
    const seen = [];
    const off = subscribeRecovery((s) => seen.push(s));
    await recoverInterrupted(U);
    off();
    expect(insert).toHaveBeenCalledTimes(1);
    expect(insert.mock.calls[0][0]).toMatchObject({ duration_seconds: 41 * 60, session_date: rec.sessionDate, session_id: rec.sessionId });
    expect(stored()).toHaveLength(0);
    expect(seen[0].recovered).toEqual([{ seconds: 41 * 60, sessionDate: rec.sessionDate }]);
  });
  it('discards a record older than 7 days without saving or inventing any duration', async () => {
    store(record({ startedAt: T0 - 8 * 86_400_000 }));
    const seen = [];
    const off = subscribeRecovery((s) => seen.push(s));
    await recoverInterrupted(U);
    off();
    expect(insert).not.toHaveBeenCalled();
    expect(stored()).toHaveLength(0);
    expect(seen[0].discarded[0].reason).toBe('too_old');
  });
  it('never converts a legacy started_at record into elapsed wall-clock study time', async () => {
    localStorage.setItem('revisop_session_started_at', new Date(T0 - 30 * 86_400_000).toISOString());
    localStorage.setItem('revisop_session_source', 'study_mode');
    localStorage.setItem('revisop_practice_session_started_at', new Date(T0 - 40 * 86_400_000).toISOString());
    const seen = [];
    const off = subscribeRecovery((s) => seen.push(s));
    await recoverInterrupted(U);
    off();
    expect(insert).not.toHaveBeenCalled();
    expect(localStorage.getItem('revisop_session_started_at')).toBeNull();
    expect(localStorage.getItem('revisop_practice_session_started_at')).toBeNull();
    expect(seen[0].legacyDiscarded).toBe(true);
  });
  it("leaves another account's record alone on a shared browser", async () => {
    store(record({ userId: OTHER }));
    await recoverInterrupted(U);
    expect(insert).not.toHaveBeenCalled();
    expect(stored()).toHaveLength(1);
  });
  it('keeps the record when the save fails, and removes it once a retry succeeds', async () => {
    store(record());
    insert.mockResolvedValueOnce({ error: { code: '', message: 'network' } });
    await recoverInterrupted(U);
    expect(stored()).toHaveLength(1);
    await recoverInterrupted(U);
    expect(stored()).toHaveLength(0);
  });
  it('concurrent recovery attempts produce exactly one insert', async () => {
    store(record());
    await Promise.all([recoverInterrupted(U), recoverInterrupted(U)]);
    expect(insert).toHaveBeenCalledTimes(1);
  });
  it('a duplicate on a second recovery pass still clears the local record', async () => {
    store(record());
    insert.mockResolvedValueOnce({ error: { code: '23505', message: 'duplicate key value violates unique constraint "study_sessions_user_session_uidx"' } });
    await recoverInterrupted(U);
    expect(stored()).toHaveLength(0);
  });
});

describe('StudyTracker', () => {
  async function started(source = 'study_mode') {
    const snaps = [];
    const t = new StudyTracker({ userId: U, source, onChange: (s) => snaps.push(s) });
    await t.start();
    return { t, snaps };
  }

  it('counts active time from heartbeats and saves it (not now - start) on finalize', async () => {
    const { t } = await started();
    await advance(5 * 60_000, { interactEvery: 1 });
    const res = await t.finalize();
    expect(res.outcome).toBe('saved');
    expect(insert.mock.calls[0][0].duration_seconds).toBe(300);
    expect(stored()).toHaveLength(0);
  });

  it('pauses (does not end) while the tab is hidden and resumes the same session', async () => {
    const { t } = await started();
    await advance(10 * 60_000, { interactEvery: 1 });
    const id = t.rec.sessionId;
    setVisibility('hidden');
    expect(t.state).toBe('paused_hidden');
    await advance(3 * 3_600_000);
    setVisibility('visible');
    expect(t.state).toBe('running');
    await advance(10 * 60_000, { interactEvery: 1 });
    expect(t.rec.sessionId).toBe(id);
    const res = await t.finalize();
    // 20 minutes of genuine study; the 3 hidden hours are not counted, and the wall-clock span is > 3h
    expect(insert.mock.calls[0][0].duration_seconds).toBe(1200);
    expect(res.outcome).toBe('saved');
  });

  it('stops counting after 10 idle minutes, keeps the session, and resumes only on request', async () => {
    const { t } = await started();
    await advance(IDLE_MS + 5 * 60_000); // no interaction at all
    expect(t.state).toBe('paused_idle');
    expect(t.rec.activeMs).toBe(IDLE_MS);
    await advance(2 * 3_600_000);
    expect(t.rec.activeMs).toBe(IDLE_MS);
    t.resume();
    expect(t.state).toBe('running');
    await advance(60_000, { interactEvery: 1 });
    expect(t.rec.activeMs).toBe(IDLE_MS + 60_000);
  });

  it('a laptop that sleeps with the tab open only adds one capped heartbeat gap', async () => {
    const { t } = await started();
    interact();
    vi.setSystemTime(T0 + 6 * 3_600_000); // clock jumps, timers did not run
    interact();
    t._tick(Date.now());
    expect(t.rec.activeMs).toBeLessThanOrEqual(90_000);
  });

  it('saves at four hours of active time and STOPS; a new session needs an explicit choice', async () => {
    const { t, snaps } = await started();
    await advance(MAX_ACTIVE_MS + 5 * 60_000, { interactEvery: 1 });
    expect(insert).toHaveBeenCalledTimes(1);
    expect(insert.mock.calls[0][0].duration_seconds).toBe(14400);
    expect(t.state).toBe('stopped');
    expect(snaps.at(-1).capReached).toBe(true);
    expect(stored()).toHaveLength(0);
  });

  it('double finalize (double click / two exits) shares one save', async () => {
    const { t } = await started();
    await advance(60_000, { interactEvery: 1 });
    const [a, b] = await Promise.all([t.finalize(), t.finalize()]);
    expect(insert).toHaveBeenCalledTimes(1);
    expect(a).toBe(b);
  });

  it('a failed save keeps the session, reports save_failed, and a retry is idempotent', async () => {
    const { t } = await started();
    await advance(120_000, { interactEvery: 1 });
    insert.mockResolvedValueOnce({ error: { code: '', message: 'offline' } });
    const failed = await t.finalize();
    expect(failed.outcome).toBe('failed');
    expect(t.state).toBe('save_failed');
    expect(stored()).toHaveLength(1);
    const ok = await t.finalize();
    expect(ok.outcome).toBe('saved');
    expect(stored()).toHaveLength(0);
    const ids = insert.mock.calls.map((c) => c[0].session_id);
    expect(new Set(ids).size).toBe(1); // both attempts carried the same session_id
  });

  it('leave-without-logging discards the session', async () => {
    const { t } = await started();
    await advance(120_000, { interactEvery: 1 });
    t.discard();
    expect(stored()).toHaveLength(0);
    expect(insert).not.toHaveBeenCalled();
  });

  it('unmount checkpoints locally and never writes to the server', async () => {
    const { t } = await started();
    await advance(120_000, { interactEvery: 1 });
    t.detach();
    expect(insert).not.toHaveBeenCalled();
    expect(stored()).toHaveLength(1);
    await recoverInterrupted(U); // ...and recovery later saves the recorded active time
    expect(insert.mock.calls[0][0].duration_seconds).toBe(120);
  });

  it('is blocked while another tab owns the user lock, and free once that lock goes stale (fallback lock)', async () => {
    // jsdom has no Web Locks, so this exercises the localStorage fallback lock owned by a DIFFERENT tab id.
    const lockKey = `revisop_study_lock:${U}`;
    localStorage.setItem(lockKey, JSON.stringify({ tabId: 'some-other-tab', ts: Date.now() }));
    const blocked = new StudyTracker({ userId: U, source: 'practice_mode' });
    const p = blocked.start();
    await vi.advanceTimersByTimeAsync(2000); // start-up retry window
    expect((await p).reason).toBe('other_tab');
    expect(blocked.state).toBe('blocked');
    expect(stored()).toHaveLength(0);
    vi.setSystemTime(Date.now() + 121_000); // the other tab stopped refreshing: lock is stale
    const free = new StudyTracker({ userId: U, source: 'practice_mode' });
    expect((await free.start()).ok).toBe(true);
    free.detach();
  });

  it('finalize before the session has begun never lets it begin', async () => {
    const t = new StudyTracker({ userId: U, source: 'study_mode' });
    const p = t.start();
    await t.finalize();
    const res = await p;
    expect(res.ok).toBe(false);
    expect(stored()).toHaveLength(0);
  });

  it('Study Mode and Practice Mode share identical semantics (only the source differs)', async () => {
    for (const source of ['study_mode', 'practice_mode']) {
      insert.mockClear();
      const { t } = await started(source);
      await advance(3 * 60_000, { interactEvery: 1 });
      await t.finalize();
      expect(insert.mock.calls[0][0]).toMatchObject({ source, duration_seconds: 180 });
    }
  });
});
