// useStudyTracker — React binding for src/lib/studyTracker.js (Sprint 8.8.5b2, D-46).
// Used by StudyMode and PracticeMode so both have identical time-tracking semantics.
//
//   const tracking = useStudyTracker({ source: 'study_mode', enabled: cardsAreReady });
//   tracking.finalize()           // save now (Finish / Exit buttons) — fire-and-forget is fine
//   tracking.restart()            // "Study Again": begin a brand-new session
//   tracking.resume()             // after the inactivity pause
//   tracking.blocked              // another RevisOp tab already owns the timed session
//   tracking.idlePaused / tracking.capReached / tracking.capSaveFailed  // drive the notices
//
// The tracker is created per effect run and detached on cleanup (React StrictMode mounts twice in dev): detach only
// checkpoints locally; a real save happens through finalize() or, later, recovery.

import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { StudyTracker, trackerRegistry } from '@/lib/studyTracker';

const INITIAL = { state: 'idle', guarded: false, activeSeconds: 0, sessionId: null, capReached: false, capSaveFailed: false };

export function useStudyTracker({ source, enabled }) {
  const { user } = useAuth();
  const userId = user?.id || null;
  const trackerRef = useRef(null);
  const [snap, setSnap] = useState(INITIAL);
  const [epoch, setEpoch] = useState(0);

  useEffect(() => {
    if (!enabled || !userId) return undefined;
    const tracker = new StudyTracker({ userId, source, onChange: setSnap });
    trackerRef.current = tracker;
    trackerRegistry.set(tracker);
    tracker.start(); // emits 'starting' immediately, which also resets the previous session's snapshot
    return () => {
      tracker.detach();
      trackerRegistry.clear(tracker);
      if (trackerRef.current === tracker) trackerRef.current = null;
    };
  }, [enabled, userId, source, epoch]);

  // Native "Leave page?" prompt for refresh / tab close / external navigation — only while a session is live.
  // No custom wording (browsers ignore it) and no async write here: recovery is the safety net.
  useEffect(() => {
    if (!snap.guarded) return undefined;
    const handler = (e) => {
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [snap.guarded]);

  const finalize = useCallback((opts) => {
    const t = trackerRef.current;
    return t ? t.finalize(opts) : Promise.resolve({ outcome: 'none' });
  }, []);
  const resume = useCallback(() => trackerRef.current?.resume(), []);
  const touch = useCallback(() => trackerRef.current?.touch(), []);
  // New session: used by "Study Again", "Continue studying" after the 4-hour save, and "Try again" when blocked.
  const restart = useCallback(() => setEpoch((e) => e + 1), []);

  return {
    state: snap.state,
    activeSeconds: snap.activeSeconds,
    blocked: snap.state === 'blocked',
    idlePaused: snap.state === 'paused_idle',
    capReached: snap.capReached,
    capSaveFailed: snap.capSaveFailed,
    finalize,
    resume,
    touch,
    restart,
  };
}
