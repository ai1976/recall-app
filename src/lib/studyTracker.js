// studyTracker.js — Sprint 8.8.5b2 (D-46): one shared study-time tracker for Study Mode + Practice Mode.
//
// WHY THIS EXISTS: both modes used to compute duration as `now - localStorage started_at`, so an abandoned
// session turned into hundreds of hours (Avantika: 709h; another account: 4,097h), and backgrounding the tab
// logged-and-cleared the timer, so study after returning was lost. This module replaces both copies.
//
// MODEL
//   - One persisted record per session, keyed revisop_study_session_v2:<sessionId>:
//       { trackerVersion, sessionId, userId, source, startedAt, lastActiveAt, activeMs, sessionDate }
//   - `activeMs` (accumulated ACTIVE time) is the ONLY recorded duration. Duration is never `now - startedAt`.
//   - Heartbeat every 30 s adds min(gap, 90 s), and only while the tab is visible AND the student interacted within
//     the last 10 minutes. Hidden tab / idle => paused (not ended); the same session resumes.
//   - At 4 h of active time the session is saved and STOPS; a fresh session needs an explicit student choice.
//   - Save = insert with the stable session_id; a duplicate (23505 on study_sessions_user_session_uidx) counts as
//     "already saved". The local record is removed only AFTER a confirmed save / known duplicate.
//   - Recovery (app startup / next session start): a record for the current user, in the v2 format, plausible, and
//     no older than 7 days is saved from its recorded activeMs. Anything else is discarded. Legacy
//     `started_at`-only keys are NEVER converted into a duration.
//   - One timed session per user per browser: a Web Lock (or a heartbeat-refreshed localStorage lock where Web
//     Locks is unavailable) named per user. A second tab is told to return to the running session.
// DB safety net: study_sessions_machine_duration_max (<= 14400 s) and study_sessions_machine_time_integrity.

import { supabase } from '@/lib/supabase';

export const TRACKER_VERSION = 2;
export const HEARTBEAT_MS = 30_000;
export const HEARTBEAT_CAP_MS = 90_000;
export const IDLE_MS = 10 * 60_000;
export const MAX_ACTIVE_MS = 4 * 60 * 60_000; // mirrors study_sessions_machine_duration_max (14400 s)
export const RECOVERY_WINDOW_MS = 7 * 24 * 60 * 60_000;
export const MIN_LOG_SECONDS = 10; // noise floor, unchanged from the old tracker
export const SOURCES = ['study_mode', 'practice_mode'];

const KEY_PREFIX = 'revisop_study_session_v2:';
const LOCK_KEY_PREFIX = 'revisop_study_lock:';
const LOCK_STALE_MS = 120_000; // localStorage-fallback lock only
const DUPLICATE_INDEX = 'study_sessions_user_session_uidx';
// Pre-8.8.5b2 keys. Their presence proves nothing about activity, so they are discarded, never trusted.
const LEGACY_START_KEYS = [
  'revisop_session_started_at',
  'recall_session_started_at',
  'revisop_practice_session_started_at',
];
const LEGACY_OTHER_KEYS = ['revisop_session_source', 'recall_session_source'];

const TAB_ID = makeUuid();

// ── small utilities ─────────────────────────────────────────────────────────

export function makeUuid() {
  try {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  } catch { /* fall through */ }
  const s = () => Math.floor((1 + Math.random()) * 0x10000).toString(16).slice(1);
  return `${s()}${s()}-${s()}-4${s().slice(1)}-a${s().slice(1)}-${s()}${s()}${s()}`;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// RevisOp's canonical session_date convention: the device-local YYYY-MM-DD.
export const localDateOf = (ms) => new Date(ms).toLocaleDateString('en-CA');

function lsGet(key) { try { return localStorage.getItem(key); } catch { return null; } }
function lsSet(key, value) { try { localStorage.setItem(key, value); return true; } catch { return false; } }
function lsRemove(key) { try { localStorage.removeItem(key); } catch { /* ignore */ } }

function storedRecordKeys() {
  const keys = [];
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.startsWith(KEY_PREFIX)) keys.push(k);
    }
  } catch { /* storage unavailable */ }
  return keys;
}

const recordKey = (sessionId) => `${KEY_PREFIX}${sessionId}`;

// ── record validation ───────────────────────────────────────────────────────

/** Returns { ok: true } or { ok: false, reason }. Pure. `too_old` is the only reason that is not corruption. */
export function validateRecord(rec, now = Date.now()) {
  if (!rec || typeof rec !== 'object') return { ok: false, reason: 'not_an_object' };
  if (rec.trackerVersion !== TRACKER_VERSION) return { ok: false, reason: 'wrong_version' };
  if (typeof rec.sessionId !== 'string' || !UUID_RE.test(rec.sessionId)) return { ok: false, reason: 'bad_session_id' };
  if (typeof rec.userId !== 'string' || !rec.userId) return { ok: false, reason: 'bad_user' };
  if (!SOURCES.includes(rec.source)) return { ok: false, reason: 'bad_source' };
  if (typeof rec.sessionDate !== 'string' || !DATE_RE.test(rec.sessionDate)) return { ok: false, reason: 'bad_date' };
  const { startedAt, lastActiveAt, activeMs } = rec;
  if (![startedAt, lastActiveAt, activeMs].every((n) => typeof n === 'number' && Number.isFinite(n))) {
    return { ok: false, reason: 'bad_numbers' };
  }
  if (startedAt < Date.UTC(2020, 0, 1)) return { ok: false, reason: 'implausible_start' };
  if (lastActiveAt < startedAt) return { ok: false, reason: 'active_before_start' };
  if (lastActiveAt > now + 5 * 60_000) return { ok: false, reason: 'future_timestamp' };
  if (activeMs < 0 || activeMs > MAX_ACTIVE_MS) return { ok: false, reason: 'implausible_duration' };
  // Genuine active time can never exceed the wall-clock span it happened in.
  if (activeMs > lastActiveAt - startedAt + 2000) return { ok: false, reason: 'duration_exceeds_span' };
  if (now - lastActiveAt > RECOVERY_WINDOW_MS) return { ok: false, reason: 'too_old' };
  return { ok: true };
}

// ── persistence (idempotent) ────────────────────────────────────────────────

/**
 * Save one record. Outcomes:
 *   saved | duplicate  -> stored on the server (duplicate = an earlier attempt already landed)
 *   too_short          -> under the noise floor, nothing to store
 *   rejected           -> the database refused it permanently (check constraint) — do not retry
 *   failed             -> transient (network etc.) — keep the record and retry later
 */
export async function persistRecord(rec) {
  const endedAt = rec.lastActiveAt;
  const spanSeconds = Math.floor((endedAt - rec.startedAt) / 1000);
  const seconds = Math.min(Math.floor(rec.activeMs / 1000), MAX_ACTIVE_MS / 1000, spanSeconds);
  if (!(seconds >= MIN_LOG_SECONDS)) return { outcome: 'too_short', seconds: Math.max(seconds, 0) };
  try {
    const { error } = await supabase.from('study_sessions').insert({
      user_id: rec.userId,
      started_at: new Date(rec.startedAt).toISOString(),
      ended_at: new Date(endedAt).toISOString(),
      duration_seconds: seconds,
      session_date: rec.sessionDate,
      source: rec.source,
      session_id: rec.sessionId,
    });
    if (!error) return { outcome: 'saved', seconds };
    const text = `${error.message || ''} ${error.details || ''}`;
    if (error.code === '23505' && text.includes(DUPLICATE_INDEX)) return { outcome: 'duplicate', seconds };
    if (error.code === '23514' || error.code === '22P02') return { outcome: 'rejected', seconds, error };
    return { outcome: 'failed', seconds, error };
  } catch (error) {
    return { outcome: 'failed', seconds, error };
  }
}

// ── one timed session per user per browser (lock) ───────────────────────────

let lastRelease = Promise.resolve();

/** Resolves { release(), refresh() } when this tab owns the user's study lock, or null if another tab does. */
export async function acquireStudyLock(userId) {
  const name = `revisop-study-${userId}`;
  if (typeof navigator !== 'undefined' && navigator.locks && typeof navigator.locks.request === 'function') {
    await lastRelease; // a lock this tab just released (remount) must settle first
    return new Promise((resolve) => {
      let signalReleased;
      const released = new Promise((r) => { signalReleased = r; });
      navigator.locks
        .request(name, { ifAvailable: true }, (lock) => {
          if (!lock) { resolve(null); return undefined; }
          return new Promise((holdEnds) => {
            resolve({
              refresh() {},
              release() { holdEnds(); lastRelease = released; return released; },
            });
          });
        })
        .then(() => signalReleased(), () => { signalReleased(); resolve(null); });
    });
  }
  // Fallback: a heartbeat-refreshed localStorage lock. Stale after LOCK_STALE_MS so a crashed tab cannot wedge it.
  const key = `${LOCK_KEY_PREFIX}${userId}`;
  const now = Date.now();
  try {
    const cur = JSON.parse(lsGet(key) || 'null');
    if (cur && cur.tabId !== TAB_ID && now - cur.ts < LOCK_STALE_MS) return null;
  } catch { /* corrupt lock value: take it */ }
  lsSet(key, JSON.stringify({ tabId: TAB_ID, ts: now }));
  try {
    const check = JSON.parse(lsGet(key) || 'null');
    if (!check || check.tabId !== TAB_ID) return null; // lost a same-instant race
  } catch { return null; }
  return {
    refresh() { lsSet(key, JSON.stringify({ tabId: TAB_ID, ts: Date.now() })); },
    release() {
      try {
        const cur = JSON.parse(lsGet(key) || 'null');
        if (cur && cur.tabId === TAB_ID) lsRemove(key);
      } catch { lsRemove(key); }
      return Promise.resolve();
    },
  };
}

async function acquireWithRetry(userId, tries = 3, gapMs = 150) {
  for (let i = 0; i < tries; i++) {
    const lock = await acquireStudyLock(userId);
    if (lock) return lock;
    if (i < tries - 1) await new Promise((r) => setTimeout(r, gapMs));
  }
  return null;
}

// ── recovery ────────────────────────────────────────────────────────────────

const recoveryListeners = new Set();
/** cb({ recovered: [{seconds, sessionDate}], discarded: [{reason}], legacyDiscarded }) — for the toast component. */
export function subscribeRecovery(cb) {
  recoveryListeners.add(cb);
  return () => recoveryListeners.delete(cb);
}
const emitRecovery = (summary) => recoveryListeners.forEach((cb) => { try { cb(summary); } catch { /* ignore */ } });

const liveSessionIds = new Set();
let recovering = null;

function discardLegacyKeys() {
  let present = false;
  for (const k of LEGACY_START_KEYS) if (lsGet(k) !== null) present = true;
  for (const k of [...LEGACY_START_KEYS, ...LEGACY_OTHER_KEYS]) lsRemove(k);
  return present;
}

/**
 * Recover interrupted sessions for `userId`. Safe to call repeatedly and from several tabs:
 * a record is only touched when this tab can take the user's lock (no live session anywhere), or when the caller
 * already holds it (`haveLock`, with its own live record excluded); saves are idempotent.
 */
export function recoverInterrupted(userId, { haveLock = false, exclude = null } = {}) {
  if (!userId) return Promise.resolve(null);
  if (recovering) return recovering;
  recovering = runRecovery(userId, haveLock, exclude).finally(() => { recovering = null; });
  return recovering;
}
export const isRecovering = () => recovering;

async function runRecovery(userId, haveLock, exclude) {
  const summary = { recovered: [], discarded: [], legacyDiscarded: false };
  summary.legacyDiscarded = discardLegacyKeys();

  const keys = storedRecordKeys().filter((k) => !liveSessionIds.has(k.slice(KEY_PREFIX.length)) && k.slice(KEY_PREFIX.length) !== exclude);
  if (keys.length) {
    const lock = haveLock ? { release: () => Promise.resolve() } : await acquireStudyLock(userId);
    if (lock) {
      try {
        for (const key of keys) {
          let rec = null;
          try { rec = JSON.parse(lsGet(key) || 'null'); } catch { rec = null; }
          if (!rec) { lsRemove(key); summary.discarded.push({ reason: 'unreadable' }); continue; }
          const verdict = validateRecord(rec);
          if (rec.userId && rec.userId !== userId) {
            // another account's record on a shared browser: leave it for them, drop it only once it is past the window
            if (!verdict.ok && verdict.reason === 'too_old') lsRemove(key);
            continue;
          }
          if (!verdict.ok) { lsRemove(key); summary.discarded.push({ reason: verdict.reason }); continue; }
          const res = await persistRecord(rec);
          if (res.outcome === 'saved') { lsRemove(key); summary.recovered.push({ seconds: res.seconds, sessionDate: rec.sessionDate }); }
          else if (res.outcome === 'duplicate' || res.outcome === 'too_short') lsRemove(key);
          else if (res.outcome === 'rejected') { lsRemove(key); summary.discarded.push({ reason: 'rejected' }); }
          // 'failed' -> keep for the next attempt
        }
      } finally {
        await lock.release();
      }
    }
  }
  if (summary.recovered.length || summary.discarded.length || summary.legacyDiscarded) emitRecovery(summary);
  return summary;
}

// ── registry (lets the navigation guard see the live tracker) ───────────────

const registryListeners = new Set();
export const trackerRegistry = {
  current: null,
  set(tracker) { this.current = tracker; registryListeners.forEach((cb) => cb()); },
  clear(tracker) { if (this.current === tracker) { this.current = null; registryListeners.forEach((cb) => cb()); } },
  subscribe(cb) { registryListeners.add(cb); return () => registryListeners.delete(cb); },
  isGuarded() { return !!(this.current && this.current.isGuarded()); },
};

// ── the tracker ─────────────────────────────────────────────────────────────

const INTERACTION_EVENTS = ['pointerdown', 'keydown', 'touchstart', 'wheel', 'scroll', 'mousemove'];

export class StudyTracker {
  constructor({ userId, source, onChange = () => {} }) {
    this.userId = userId;
    this.source = source;
    this.onChange = onChange;
    this.state = 'idle'; // idle | starting | running | paused_hidden | paused_idle | save_failed | stopped | blocked
    this.rec = null;
    this.lock = null;
    this.timer = null;
    this.lastBeatAt = 0;
    this.lastInteractionAt = 0;
    this.detached = false;
    this.abortStart = false;
    this.finalizing = null;
    this.capPending = false;
    this._onVisibility = () => this._handleVisibility();
    this._onInteraction = () => { if (this.state === 'running') this.lastInteractionAt = Date.now(); };
    this._onPageHide = () => this._checkpoint(true);
  }

  // Guarded = a session exists and is not already being saved (so its own Finish/Exit buttons pass the guard).
  isGuarded() { return !!this.rec && !this.finalizing && this.state !== 'stopped'; }

  snapshot() {
    return {
      state: this.state,
      guarded: this.isGuarded(),
      activeSeconds: this.rec ? Math.floor(this.rec.activeMs / 1000) : 0,
      sessionId: this.rec ? this.rec.sessionId : null,
      capReached: this.capPending && this.state === 'stopped',
      capSaveFailed: this.capPending && this.state === 'save_failed',
    };
  }

  _set(state) {
    this.state = state;
    this.onChange(this.snapshot());
    registryListeners.forEach((cb) => cb());
  }

  async start() {
    if (this.state !== 'idle') return { ok: this.state === 'running' };
    this._set('starting');
    // A recovery pass already in flight may hold the lock for a moment; let it finish (bounded).
    if (recovering) await Promise.race([recovering, new Promise((r) => setTimeout(r, 4000))]);
    if (this.detached || this.abortStart) { this._set('stopped'); return { ok: false, reason: 'aborted' }; }
    const lock = await acquireWithRetry(this.userId);
    if (!lock) { this._set('blocked'); return { ok: false, reason: 'other_tab' }; }
    if (this.detached || this.abortStart) { await lock.release(); this._set('stopped'); return { ok: false, reason: 'aborted' }; }

    const now = Date.now();
    this.rec = {
      trackerVersion: TRACKER_VERSION,
      sessionId: makeUuid(),
      userId: this.userId,
      source: this.source,
      startedAt: now,
      lastActiveAt: now,
      activeMs: 0,
      sessionDate: localDateOf(now),
    };
    liveSessionIds.add(this.rec.sessionId);
    lsSet(recordKey(this.rec.sessionId), JSON.stringify(this.rec));
    this.lock = lock;
    this.lastBeatAt = now;
    this.lastInteractionAt = now;
    this._attach();
    this._set(typeof document !== 'undefined' && document.visibilityState === 'hidden' ? 'paused_hidden' : 'running');
    // We hold the user's lock, so any OTHER stored record is an orphan: recover it in the background.
    recoverInterrupted(this.userId, { haveLock: true, exclude: this.rec.sessionId });
    return { ok: true };
  }

  _attach() {
    document.addEventListener('visibilitychange', this._onVisibility);
    window.addEventListener('pagehide', this._onPageHide);
    INTERACTION_EVENTS.forEach((ev) => window.addEventListener(ev, this._onInteraction, { passive: true, capture: true }));
    this.timer = window.setInterval(() => this._tick(), HEARTBEAT_MS);
  }

  _teardown() {
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', this._onVisibility);
    if (typeof window !== 'undefined') {
      window.removeEventListener('pagehide', this._onPageHide);
      INTERACTION_EVENTS.forEach((ev) => window.removeEventListener(ev, this._onInteraction, { capture: true }));
    }
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
  }

  _releaseLock() {
    const lock = this.lock;
    this.lock = null;
    if (this.rec) liveSessionIds.delete(this.rec.sessionId);
    return lock ? lock.release() : Promise.resolve();
  }

  /** Count active time up to `now`. Only counts while running; never longer than the heartbeat cap. */
  _tick(now = Date.now()) {
    if (this.lock && this.lock.refresh) this.lock.refresh();
    if (!this.rec || this.state !== 'running') return;
    const countUntil = Math.min(now, this.lastInteractionAt + IDLE_MS);
    const delta = Math.max(0, Math.min(countUntil - this.lastBeatAt, HEARTBEAT_CAP_MS));
    if (delta > 0) {
      this.rec.activeMs += delta;
      this.rec.lastActiveAt = this.lastBeatAt + delta;
      this.rec.sessionDate = localDateOf(this.rec.lastActiveAt);
    }
    this.lastBeatAt = now;

    if (this.rec.activeMs >= MAX_ACTIVE_MS) {
      this.rec.activeMs = MAX_ACTIVE_MS;
      this._checkpoint();
      this.capPending = true;
      this.state = 'stopping'; // not 'running', so finalize() does not tick again
      this.finalize({ reason: 'cap' });
      return;
    }
    this._checkpoint();
    if (now >= this.lastInteractionAt + IDLE_MS) this._set('paused_idle');
  }

  _checkpoint(withTick = false) {
    if (!this.rec) return;
    if (withTick) this._tick();
    lsSet(recordKey(this.rec.sessionId), JSON.stringify(this.rec));
  }

  _handleVisibility() {
    if (!this.rec) return;
    if (document.visibilityState === 'hidden') {
      if (this.state === 'running') {
        this._tick();
        this._checkpoint();
        this._set('paused_hidden');
      }
    } else if (this.state === 'paused_hidden') {
      const now = Date.now();
      this.lastBeatAt = now;
      this.lastInteractionAt = now; // coming back to the tab is a deliberate act
      this._set('running');
    }
  }

  /** Explicit study interaction (card navigation, grading). Window-level events already cover taps/keys. */
  touch() { if (this.state === 'running') this.lastInteractionAt = Date.now(); }

  /** "Resume studying" after the inactivity pause. */
  resume() {
    if (this.state !== 'paused_idle') return;
    const now = Date.now();
    this.lastBeatAt = now;
    this.lastInteractionAt = now;
    this._set(typeof document !== 'undefined' && document.visibilityState === 'hidden' ? 'paused_hidden' : 'running');
  }

  /** Save the session. Concurrent/duplicate calls share one in-flight attempt. */
  finalize({ reason = 'finish' } = {}) {
    if (this.finalizing) return this.finalizing;
    if (!this.rec) {
      this.abortStart = true; // finished before the session had even begun: never begin it
      return Promise.resolve({ outcome: 'none' });
    }
    if (this.state === 'running') this._tick();
    this._checkpoint();
    const rec = { ...this.rec };
    this.finalizing = (async () => {
      const res = await persistRecord(rec);
      if (res.outcome === 'failed') {
        this.finalizing = null;
        if (this.detached) { await this._releaseLock(); this._teardown(); this._set('stopped'); }
        else this._set('save_failed');
        return { ...res, reason };
      }
      lsRemove(recordKey(rec.sessionId));
      this._teardown();
      const lockDone = this._releaseLock();
      this.rec = null;
      this.finalizing = null;
      this._set('stopped');
      await lockDone;
      return { ...res, reason };
    })();
    this.onChange(this.snapshot());
    registryListeners.forEach((cb) => cb());
    return this.finalizing;
  }

  /** "Leave without logging": drop the session for good. */
  discard() {
    if (this.finalizing) return;
    if (this.rec) lsRemove(recordKey(this.rec.sessionId));
    this._teardown();
    this._releaseLock();
    this.rec = null;
    this.abortStart = true;
    this._set('stopped');
  }

  /** Component unmounted. Keeps a recoverable local checkpoint; never writes to the server itself. */
  detach() {
    this.detached = true;
    if (this.finalizing) return; // the in-flight save finishes (and cleans up) on its own
    if (this.rec) {
      if (this.state === 'running') this._tick();
      this._checkpoint(); // record stays in storage for recovery
    }
    this._teardown();
    this._releaseLock();
    this.rec = null;
    this.state = 'stopped';
    registryListeners.forEach((cb) => cb());
  }
}
