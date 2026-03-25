// StudyTimerWidget.jsx
// Isolated manual study timer for students doing offline study (reading notes, etc.)
//
// Performance: clock display is updated via clockRef.current.textContent (DOM mutation),
// not React state, so the parent Dashboard never re-renders every second.
//
// Three-tier stale session policy (evaluated on mount):
//
//   < 4 hours  → AUTO-RESUME silently.
//               Student just switched apps or the browser reloaded the page.
//               Timer picks up from the original start time with no interruption.
//
//   4–16 hours → HONEST-SESSION PROMPT.
//               Timer has been running long enough that the student may have
//               forgotten it. Pause and ask:
//               "Your timer ran for Xh Ym. Were you studying the whole time?"
//               Options: [Yes, log Xh Ym] | [Log less…] | [Discard session]
//               "Log less…" reveals a number input (1 h to max elapsed hours)
//               so the student can self-report accurately.
//
//   > 16 hours → DISCARD silently.
//               Physically impossible as continuous study. Logging this would
//               corrupt leaderboard stats. No data is saved.

import { useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Timer, Square } from 'lucide-react';

const SHORT_BREAK_MS   = 4  * 60 * 60 * 1000; // < 4h  → auto-resume
const PROMPT_CUTOFF_MS = 16 * 60 * 60 * 1000; // 4–16h → prompt, > 16h → discard

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

// Human-readable duration from milliseconds (for the recovery prompt label)
function formatMs(ms) {
  return formatDuration(Math.round(ms / 1000));
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function StudyTimerWidget({ onSessionLogged }) {
  const { user } = useAuth();

  // timerState: 'idle' | 'running' | 'saving'
  const [timerState, setTimerState] = useState('idle');
  // Set when a 4–16h stale session is found on mount
  const [recoveryPrompt, setRecoveryPrompt] = useState(null); // null | { startedAt, elapsedMs }
  // Whether the "Log less…" custom-hours input is visible within the recovery prompt
  const [customInputMode, setCustomInputMode] = useState(false);
  const [customHours, setCustomHours] = useState('');
  // Brief confirmation message shown after a successful log
  const [confirmation, setConfirmation] = useState('');

  // Interval handle — in ref so ticks never trigger re-renders
  const intervalRef = useRef(null);
  // Clock display DOM node — textContent updated directly
  const clockRef    = useRef(null);
  // Epoch ms when the current running session started
  const startMsRef  = useRef(null);

  // ── Start ticking from a given epoch ms ──────────────────────────────────
  const startTick = useCallback((startMs) => {
    startMsRef.current = startMs;
    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = setInterval(() => {
      if (clockRef.current) {
        clockRef.current.textContent = formatElapsed(Date.now() - startMs);
      }
    }, 1000);
  }, []);

  // ── Initialize clock display right after the 'running' UI mounts ─────────
  // clockRef.current is null until timerState === 'running' renders the element.
  // This fires after that render and shows the correct elapsed time immediately
  // (critical for auto-resume, where the clock should show "15:34" not "00:00").
  useEffect(() => {
    if (timerState === 'running' && startMsRef.current && clockRef.current) {
      clockRef.current.textContent = formatElapsed(Date.now() - startMsRef.current);
    }
  }, [timerState]);

  // ── Mount: classify any stale manual session ──────────────────────────────
  useEffect(() => {
    const startedAtStr = localStorage.getItem(LS_STARTED);
    const source       = localStorage.getItem(LS_SOURCE);

    if (!startedAtStr || source !== 'manual') return;

    const startMs   = new Date(startedAtStr).getTime();
    const elapsedMs = Date.now() - startMs;

    if (elapsedMs < SHORT_BREAK_MS) {
      // < 4h — auto-resume, no interruption
      startTick(startMs);
      setTimerState('running');
    } else if (elapsedMs < PROMPT_CUTOFF_MS) {
      // 4–16h — honest-session prompt
      setRecoveryPrompt({ startedAt: startedAtStr, elapsedMs });
    } else {
      // > 16h — discard silently, leaderboard protection
      localStorage.removeItem(LS_STARTED);
      localStorage.removeItem(LS_SOURCE);
    }

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Core insert helper ────────────────────────────────────────────────────
  // Accepts explicit durationSeconds so recovery can pass a custom value.
  // Clears localStorage before the DB call to prevent double-logging on remount.
  const insertSession = async (startedAtStr, durationSeconds) => {
    localStorage.removeItem(LS_STARTED);
    localStorage.removeItem(LS_SOURCE);

    if (durationSeconds < 10 || !user) return 0;

    const sessionDate = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local

    const { error } = await supabase.from('study_sessions').insert({
      user_id:          user.id,
      started_at:       new Date(startedAtStr).toISOString(),
      ended_at:         new Date().toISOString(),
      duration_seconds: durationSeconds,
      session_date:     sessionDate,
      source:           'manual',
    });

    if (error) throw error;
    return durationSeconds;
  };

  // ── Normal start / stop ───────────────────────────────────────────────────

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
    startMsRef.current = null;
    setTimerState('saving');

    try {
      const startedAtStr    = localStorage.getItem(LS_STARTED);
      const durationSeconds = Math.round((Date.now() - new Date(startedAtStr).getTime()) / 1000);
      const duration        = await insertSession(startedAtStr, durationSeconds);

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

  // ── Recovery handlers ─────────────────────────────────────────────────────

  // Log the full elapsed duration as reported
  const handleRecoveryFull = async () => {
    setTimerState('saving');
    try {
      const durationSeconds = Math.round(recoveryPrompt.elapsedMs / 1000);
      const duration = await insertSession(recoveryPrompt.startedAt, durationSeconds);
      if (duration > 0) {
        setConfirmation(`Session logged: ${formatDuration(duration)}`);
        onSessionLogged?.();
      }
    } catch (err) {
      console.error('Failed to log recovery session (full):', err);
    }
    setRecoveryPrompt(null);
    setTimerState('idle');
  };

  // Log a custom number of whole hours
  const handleRecoveryCustom = async () => {
    const hrs    = parseInt(customHours, 10);
    const maxHrs = Math.floor(recoveryPrompt.elapsedMs / 3600000);
    if (!hrs || hrs < 1 || hrs > maxHrs) return;

    setTimerState('saving');
    try {
      const duration = await insertSession(recoveryPrompt.startedAt, hrs * 3600);
      if (duration > 0) {
        setConfirmation(`Session logged: ${formatDuration(duration)}`);
        onSessionLogged?.();
      }
    } catch (err) {
      console.error('Failed to log recovery session (custom):', err);
    }
    setCustomHours('');
    setCustomInputMode(false);
    setRecoveryPrompt(null);
    setTimerState('idle');
  };

  const handleRecoveryDiscard = () => {
    localStorage.removeItem(LS_STARTED);
    localStorage.removeItem(LS_SOURCE);
    setRecoveryPrompt(null);
    setCustomInputMode(false);
    setCustomHours('');
  };

  // Max whole hours the student can claim (can't claim more than elapsed)
  const maxHrs = recoveryPrompt ? Math.floor(recoveryPrompt.elapsedMs / 3600000) : 0;

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Card className="h-full">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-xs sm:text-sm font-medium">Study Timer</CardTitle>
        <Timer className="h-3 w-3 sm:h-4 sm:w-4 text-blue-500" />
      </CardHeader>
      <CardContent>

        {/* ── Recovery prompt (4–16h stale session) ── */}
        {recoveryPrompt && timerState !== 'saving' && (
          <div className="space-y-3">
            <p className="text-xs sm:text-sm font-medium text-amber-800 leading-snug">
              Your timer ran for {formatMs(recoveryPrompt.elapsedMs)}.
              Were you studying the whole time?
            </p>

            {!customInputMode ? (
              <div className="flex flex-col gap-1.5">
                <Button
                  size="sm"
                  className="h-8 w-full justify-start text-xs"
                  onClick={handleRecoveryFull}
                >
                  Yes — log {formatMs(recoveryPrompt.elapsedMs)}
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-8 w-full justify-start text-xs"
                  onClick={() => {
                    setCustomInputMode(true);
                    setCustomHours(String(maxHrs > 1 ? maxHrs - 1 : 1));
                  }}
                >
                  Log less…
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-8 w-full justify-start text-xs text-muted-foreground"
                  onClick={handleRecoveryDiscard}
                >
                  Discard session
                </Button>
              </div>
            ) : (
              /* Custom hours input */
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <Input
                    type="number"
                    min={1}
                    max={maxHrs}
                    value={customHours}
                    onChange={(e) => setCustomHours(e.target.value)}
                    className="h-8 w-20 text-sm"
                  />
                  <span className="text-[10px] sm:text-xs text-muted-foreground">
                    hours (max {maxHrs})
                  </span>
                </div>
                <div className="flex gap-2">
                  <Button size="sm" className="h-8 text-xs" onClick={handleRecoveryCustom}>
                    Save
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="h-8 text-xs"
                    onClick={() => { setCustomInputMode(false); setCustomHours(''); }}
                  >
                    Back
                  </Button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ── Saving ── */}
        {timerState === 'saving' && (
          <p className="text-xs sm:text-sm text-muted-foreground">Saving...</p>
        )}

        {/* ── Idle ── */}
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

        {/* ── Running — clock via DOM ref, zero parent re-renders ── */}
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

      </CardContent>
    </Card>
  );
}
