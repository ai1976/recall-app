// StudyTimerWidget.jsx
// Isolated manual study timer for students doing offline study (reading notes, etc.)
//
// Performance note: The ticking clock display is updated via direct DOM manipulation
// (clockRef.current.textContent) so the parent Dashboard never re-renders every second.
// The only React state here is timerState (3 transitions per session max) and
// recoveryPrompt (set once on mount if a stale session exists).
//
// Stale session policy:
//   > 4 hours old  → silently discard (likely an accident / forgotten tab)
//   ≤ 4 hours old  → prompt: "Unfinished session from X ago. Log it?"
//   Source must be 'manual' — study_mode sessions are handled in StudyMode.jsx

import { useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Timer, Square } from 'lucide-react';

const STALE_THRESHOLD_MS = 4 * 60 * 60 * 1000; // 4 hours
const LS_STARTED = 'recall_session_started_at';
const LS_SOURCE  = 'recall_session_source';

// ── Formatting helpers ────────────────────────────────────────────────────────

function formatElapsed(ms) {
  const totalSecs = Math.floor(ms / 1000);
  const h = Math.floor(totalSecs / 3600);
  const m = Math.floor((totalSecs % 3600) / 60);
  const s = totalSecs % 60;
  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}s`;
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
}

function formatAgo(ms) {
  const mins = Math.round(ms / 60000);
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.floor(mins / 60);
  const rem = mins % 60;
  return rem > 0 ? `${hrs}h ${rem}m ago` : `${hrs}h ago`;
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function StudyTimerWidget({ onSessionLogged }) {
  const { user } = useAuth();

  // timerState drives which UI slice is shown — changes at most 3× per session
  const [timerState, setTimerState] = useState('idle'); // 'idle' | 'running' | 'saving'
  // Set on mount if a stale manual session is found in localStorage
  const [recoveryPrompt, setRecoveryPrompt] = useState(null); // null | { startedAt, elapsedMs }
  // Brief confirmation shown after a successful log
  const [confirmation, setConfirmation] = useState('');

  // Interval handle — stored in ref, never in state (no re-render on tick)
  const intervalRef = useRef(null);
  // The clock display element — updated via textContent, not React state
  const clockRef = useRef(null);

  // ── Mount: check for stale manual session ──────────────────────────────────
  useEffect(() => {
    const startedAtStr = localStorage.getItem(LS_STARTED);
    const source       = localStorage.getItem(LS_SOURCE);

    // Only recover manual sessions — study_mode recovery is out of scope here
    if (!startedAtStr || source !== 'manual') return;

    const elapsedMs = Date.now() - new Date(startedAtStr).getTime();

    if (elapsedMs > STALE_THRESHOLD_MS) {
      // Silently discard — too old to be meaningful
      localStorage.removeItem(LS_STARTED);
      localStorage.removeItem(LS_SOURCE);
    } else {
      setRecoveryPrompt({ startedAt: startedAtStr, elapsedMs });
    }

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);

  // ── Tick: update clock display via DOM — no React re-renders ──────────────
  const startTick = useCallback((startMs) => {
    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = setInterval(() => {
      if (clockRef.current) {
        clockRef.current.textContent = formatElapsed(Date.now() - startMs);
      }
    }, 1000);
  }, []);

  // ── Insert completed session into DB ──────────────────────────────────────
  // Returns duration_seconds logged, or 0 if skipped (too short / no user).
  const insertSession = async (startedAtStr, endedAt) => {
    const startedAt      = new Date(startedAtStr);
    const durationSeconds = Math.round((endedAt.getTime() - startedAt.getTime()) / 1000);

    // Clear localStorage first — prevents double-logging if component remounts
    localStorage.removeItem(LS_STARTED);
    localStorage.removeItem(LS_SOURCE);

    if (durationSeconds < 10 || !user) return 0;

    const sessionDate = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local

    const { error } = await supabase.from('study_sessions').insert({
      user_id:          user.id,
      started_at:       startedAt.toISOString(),
      ended_at:         endedAt.toISOString(),
      duration_seconds: durationSeconds,
      session_date:     sessionDate,
      source:           'manual',
    });

    if (error) throw error;
    return durationSeconds;
  };

  // ── Handlers ──────────────────────────────────────────────────────────────

  const handleStart = () => {
    const isoStr = new Date().toISOString();
    localStorage.setItem(LS_STARTED, isoStr);
    localStorage.setItem(LS_SOURCE, 'manual');
    startTick(new Date(isoStr).getTime());
    setConfirmation('');
    setTimerState('running');
  };

  const handleStop = async () => {
    if (intervalRef.current) clearInterval(intervalRef.current);
    setTimerState('saving');

    try {
      const startedAtStr = localStorage.getItem(LS_STARTED);
      const endedAt      = new Date();
      const duration     = await insertSession(startedAtStr, endedAt);

      if (duration > 0) {
        setConfirmation(`Session logged: ${formatDuration(duration)}`);
        onSessionLogged?.();
      }
    } catch (err) {
      console.error('Failed to log manual session:', err);
    }

    if (clockRef.current) clockRef.current.textContent = '00:00';
    setTimerState('idle');
  };

  const handleRecoveryLog = async () => {
    if (!recoveryPrompt) return;
    setRecoveryPrompt(null);
    setTimerState('saving');

    try {
      const endedAt  = new Date();
      const duration = await insertSession(recoveryPrompt.startedAt, endedAt);

      if (duration > 0) {
        setConfirmation(`Session logged: ${formatDuration(duration)}`);
        onSessionLogged?.();
      }
    } catch (err) {
      console.error('Failed to log recovered session:', err);
    }

    setTimerState('idle');
  };

  const handleRecoveryDiscard = () => {
    localStorage.removeItem(LS_STARTED);
    localStorage.removeItem(LS_SOURCE);
    setRecoveryPrompt(null);
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Card className="h-full">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-xs sm:text-sm font-medium">Study Timer</CardTitle>
        <Timer className="h-3 w-3 sm:h-4 sm:w-4 text-blue-500" />
      </CardHeader>
      <CardContent>

        {/* Stale session recovery prompt */}
        {recoveryPrompt && (
          <div className="mb-3 p-3 bg-amber-50 border border-amber-200 rounded-lg">
            <p className="text-xs sm:text-sm text-amber-800 font-medium mb-2">
              Unfinished session from {formatAgo(recoveryPrompt.elapsedMs)}
            </p>
            <div className="flex gap-2">
              <Button size="sm" className="h-7 text-xs" onClick={handleRecoveryLog}>
                Log it
              </Button>
              <Button size="sm" variant="ghost" className="h-7 text-xs" onClick={handleRecoveryDiscard}>
                Discard
              </Button>
            </div>
          </div>
        )}

        {/* Idle state */}
        {timerState === 'idle' && !recoveryPrompt && (
          <div className="flex items-center justify-between">
            <div>
              {confirmation ? (
                <p className="text-xs sm:text-sm text-green-600 font-medium">{confirmation}</p>
              ) : (
                <p className="text-[10px] sm:text-xs text-muted-foreground">Offline study</p>
              )}
            </div>
            <Button size="sm" className="h-8" onClick={handleStart}>
              Start
            </Button>
          </div>
        )}

        {/* Running state — clock updated via DOM ref, zero parent re-renders */}
        {timerState === 'running' && (
          <div className="flex items-center justify-between">
            <div>
              <div
                ref={clockRef}
                className="text-xl sm:text-2xl font-bold font-mono text-blue-600"
              >
                00:00
              </div>
              <p className="text-[10px] sm:text-xs text-muted-foreground">Running</p>
            </div>
            <Button
              size="sm"
              variant="destructive"
              className="h-8"
              onClick={handleStop}
            >
              <Square className="h-3 w-3 mr-1" />
              Stop
            </Button>
          </div>
        )}

        {/* Saving state */}
        {timerState === 'saving' && (
          <p className="text-xs sm:text-sm text-muted-foreground">Saving...</p>
        )}

      </CardContent>
    </Card>
  );
}
