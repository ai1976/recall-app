// StudyTimerContext.jsx
// Sprint 7.3-C — app-wide home for the manual "offline study" timer.
//
// Previously StudyTimerWidget.jsx owned this state itself, which meant the
// three-tier stale-session policy only evaluated when a student happened to
// load whatever page the widget was mounted on. Moving it here means
// classification runs ONCE on app mount, for every authed page — closing the
// gap where a >16h-old timer could sit stale indefinitely until the student
// happened to revisit the one page that used to host the widget.
//
// Uses its OWN localStorage key (revisop_manual_timer_started_at) — separate
// from StudyMode.jsx / ReviewSession.jsx's revisop_session_started_at /
// revisop_session_source pair, which they keep exactly as-is. The two
// features used to share those keys, which meant starting a manual timer
// while a review session was also in flight (or vice versa) silently
// clobbered whichever one wrote last. No shared keys going forward.
//
// Three-tier stale-session policy (see StudyTimerWidget.jsx's original header
// comment for the full rationale) — < 4h auto-resume, 4-16h honest-session
// prompt, > 16h silent discard. Applied both at mount (here) and at stop()
// time (mirrors it), same as the original widget.
//
// Exposes: { isRunning, startedAt, elapsedMs, recoveryPrompt,
//            start(), stop(), stopAndLog(durationSeconds), discard() }
//
//   start()                    — begin a new timer.
//   stop()                     — tap-to-stop entry point. Applies the 3-tier
//                                 policy at call time: <4h logs immediately
//                                 (via stopAndLog), 4-16h sets recoveryPrompt
//                                 instead of logging, >16h discards. Same
//                                 implementation whether called from the nav
//                                 chip or the dedicated /dashboard/study-time
//                                 page's Stop button.
//   stopAndLog(durationSeconds) — the actual study_sessions insert + state
//                                 clear. Used internally by stop()'s <4h path,
//                                 and directly by the recovery UI's "log full"
//                                 / "log less" choices.
//   discard()                  — clears state without logging. Used by the
//                                 recovery UI's "Discard session" choice.
//
// All three return a Promise resolving to a result descriptor
// ({ outcome: 'logged' | 'needs_recovery' | 'discarded' | 'noop', ... }) —
// callers decide toast copy / navigation, this context stays UI-agnostic.

import { createContext, useContext, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

const SHORT_BREAK_MS   = 4  * 60 * 60 * 1000; // < 4h  → auto-resume
const PROMPT_CUTOFF_MS = 16 * 60 * 60 * 1000; // 4-16h → prompt, > 16h → discard
const COARSE_TICK_MS   = 30 * 1000;           // nav-chip display refresh — NOT per-second

const LS_STARTED = 'revisop_manual_timer_started_at';

const StudyTimerContext = createContext(null);

// Reads and classifies any in-flight manual-timer session ONE time — used as
// a lazy useState initializer below (not an effect), so classification is
// part of computing this provider's initial render rather than a setState
// call fired after mount. Same 3-tier policy as before: < 4h auto-resume,
// 4-16h honest-session prompt, > 16h silent discard (localStorage cleared as
// a read-time side effect here, same as the page-load behavior it replaces —
// no UI was ever shown for that case).
function readInitialTimerState() {
  const startedAtStr = localStorage.getItem(LS_STARTED);
  if (!startedAtStr) {
    return { isRunning: false, startedAt: null, elapsedMs: 0, recoveryPrompt: null };
  }

  const startMs = new Date(startedAtStr).getTime();
  const elapsed  = Date.now() - startMs;

  if (elapsed < SHORT_BREAK_MS) {
    return { isRunning: true, startedAt: startMs, elapsedMs: elapsed, recoveryPrompt: null };
  }
  if (elapsed < PROMPT_CUTOFF_MS) {
    return {
      isRunning: false, startedAt: null, elapsedMs: 0,
      recoveryPrompt: { startedAt: startMs, elapsedMs: elapsed, source: 'stale' },
    };
  }
  localStorage.removeItem(LS_STARTED);
  return { isRunning: false, startedAt: null, elapsedMs: 0, recoveryPrompt: null };
}

export function StudyTimerProvider({ children }) {
  const { user } = useAuth();

  const [isRunning, setIsRunning]           = useState(() => readInitialTimerState().isRunning);
  const [startedAt, setStartedAt]           = useState(() => readInitialTimerState().startedAt);
  const [elapsedMs, setElapsedMs]           = useState(() => readInitialTimerState().elapsedMs);
  const [recoveryPrompt, setRecoveryPrompt] = useState(() => readInitialTimerState().recoveryPrompt);

  const coarseTickRef = useRef(null);

  // ── Coarse display refresh while running (nav-chip cadence, not per-second)
  useEffect(() => {
    if (!isRunning || startedAt == null) {
      if (coarseTickRef.current) clearInterval(coarseTickRef.current);
      return undefined;
    }
    coarseTickRef.current = setInterval(() => {
      setElapsedMs(Date.now() - startedAt);
    }, COARSE_TICK_MS);
    return () => clearInterval(coarseTickRef.current);
  }, [isRunning, startedAt]);

  // ── Cross-tab sync — localStorage writes only fire `storage` in OTHER tabs
  // of the same origin, which is exactly what makes this correct: a second
  // tab picks up start/stop state without needing to remount. ─────────────
  useEffect(() => {
    function onStorage(e) {
      if (e.key !== LS_STARTED) return;
      if (e.newValue) {
        const startMs = new Date(e.newValue).getTime();
        setStartedAt(startMs);
        setElapsedMs(Date.now() - startMs);
        setIsRunning(true);
        setRecoveryPrompt(null);
      } else {
        setIsRunning(false);
        setStartedAt(null);
        setElapsedMs(0);
        setRecoveryPrompt(null);
      }
    }
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  // ── DB write ───────────────────────────────────────────────────────────
  const insertSession = useCallback(async (startedAtMs, durationSeconds) => {
    localStorage.removeItem(LS_STARTED);
    if (durationSeconds < 10 || !user) return 0;

    const sessionDate = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local

    const { error } = await supabase.from('study_sessions').insert({
      user_id:          user.id,
      started_at:       new Date(startedAtMs).toISOString(),
      ended_at:         new Date().toISOString(),
      duration_seconds: durationSeconds,
      session_date:     sessionDate,
      source:           'manual',
    });
    if (error) throw error;
    return durationSeconds;
  }, [user]);

  const start = useCallback(() => {
    const now = Date.now();
    localStorage.setItem(LS_STARTED, new Date(now).toISOString());
    setStartedAt(now);
    setElapsedMs(0);
    setIsRunning(true);
    setRecoveryPrompt(null);
  }, []);

  const stopAndLog = useCallback(async (durationSeconds) => {
    const baseStartedAt = recoveryPrompt ? recoveryPrompt.startedAt : startedAt;
    if (baseStartedAt == null) return { outcome: 'noop' };
    const duration = await insertSession(baseStartedAt, durationSeconds);
    setIsRunning(false);
    setStartedAt(null);
    setElapsedMs(0);
    setRecoveryPrompt(null);
    return { outcome: 'logged', durationSeconds: duration };
  }, [recoveryPrompt, startedAt, insertSession]);

  const discard = useCallback(() => {
    localStorage.removeItem(LS_STARTED);
    setIsRunning(false);
    setStartedAt(null);
    setElapsedMs(0);
    setRecoveryPrompt(null);
  }, []);

  const stop = useCallback(async () => {
    if (recoveryPrompt || !isRunning || startedAt == null) return { outcome: 'noop' };
    const elapsed = Date.now() - startedAt;

    if (elapsed >= PROMPT_CUTOFF_MS) {
      // Should not be reachable given app-wide mount classification, but
      // handled defensively — same as the original widget: discard + let the
      // caller toast an explanation (this IS a deliberate Stop tap, unlike
      // the silent mount-time discard above).
      discard();
      return { outcome: 'discarded', elapsedMs: elapsed };
    }
    if (elapsed >= SHORT_BREAK_MS) {
      setIsRunning(false);
      setRecoveryPrompt({ startedAt, elapsedMs: elapsed, source: 'stop' });
      return { outcome: 'needs_recovery', elapsedMs: elapsed };
    }
    return stopAndLog(Math.round(elapsed / 1000));
  }, [recoveryPrompt, isRunning, startedAt, discard, stopAndLog]);

  const value = useMemo(() => ({
    isRunning, startedAt, elapsedMs, recoveryPrompt,
    start, stop, stopAndLog, discard,
  }), [isRunning, startedAt, elapsedMs, recoveryPrompt, start, stop, stopAndLog, discard]);

  return (
    <StudyTimerContext.Provider value={value}>
      {children}
    </StudyTimerContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export const useStudyTimer = () => {
  const ctx = useContext(StudyTimerContext);
  if (!ctx) throw new Error('useStudyTimer must be used within a StudyTimerProvider');
  return ctx;
};
