// StudyTimerWidget.jsx
// Manual study timer UI for students doing offline study (reading notes, etc.)
//
// Sprint 7.3-C: this is now a THIN CONSUMER of StudyTimerContext — all state
// (running/idle, elapsed, recovery prompt) and the three-tier stale-session
// policy live in the context, classified once app-wide on mount. This
// component's own mount/unmount lifetime is irrelevant to correctness; it
// only renders whatever the context currently reports. Rendered on the
// dedicated /dashboard/study-time route.
//
// The clock display is still driven via a DOM ref (clockRef.current.textContent)
// ticked every second, purely local to this mounted instance — true per-second
// precision belongs here, not in the app-wide context (which refreshes its own
// `elapsedMs` on a coarse ~30s cadence for the nav chip).

import { useEffect, useRef, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Timer, Square } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useStudyTimer } from '@/contexts/StudyTimerContext';
import { cn } from '@/lib/utils';

// Sprint 8.5 — required at stop/log time, both for the direct <4h stop path
// and the resolved recovery-prompt path. Values match study_sessions.category's
// CHECK constraint (docs/database/sprint8.5/01_SCHEMA_add_study_session_category.sql).
const CATEGORIES = [
  { value: 'reading',          label: 'Reading' },
  { value: 'writing_practice', label: 'Writing Practice' },
  { value: 'lecture_viewing',  label: 'Lecture Viewing' },
  { value: 'paper_solving',    label: 'Paper Solving' },
  { value: 'mock_test',        label: 'Mock Test (timed)' },
];

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

export default function StudyTimerWidget() {
  const { toast } = useToast();
  const {
    isRunning, startedAt, recoveryPrompt, pendingLog,
    start, stop, stopAndLog, discard, confirmCategory,
  } = useStudyTimer();

  const [busy, setBusy] = useState(false);
  const [confirmation, setConfirmation] = useState('');
  const [postRecovery, setPostRecovery] = useState(false);
  const [customInputMode, setCustomInputMode] = useState(false);
  const [customHours, setCustomHours] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [pendingViaRecovery, setPendingViaRecovery] = useState(false);

  const clockRef = useRef(null);

  // Local per-second clock, driven off context's `startedAt` timestamp.
  useEffect(() => {
    if (!isRunning || startedAt == null) return undefined;
    const tick = () => {
      if (clockRef.current) clockRef.current.textContent = formatElapsed(Date.now() - startedAt);
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [isRunning, startedAt]);

  const handleStart = () => {
    setConfirmation('');
    setPostRecovery(false);
    start();
  };

  const handleStop = async () => {
    setBusy(true);
    try {
      const result = await stop();
      if (result.outcome === 'needs_category') {
        setPendingViaRecovery(false);
        setSelectedCategory('');
      } else if (result.outcome === 'logged' && result.durationSeconds > 0) {
        setConfirmation(`Session logged: ${formatDuration(result.durationSeconds)}`);
      } else if (result.outcome === 'discarded') {
        toast({
          title: 'Session discarded',
          description:
            'Timers over 16 hours cannot be logged to protect leaderboard integrity.',
          variant: 'destructive',
        });
      }
      // 'needs_recovery' → context's recoveryPrompt is now set; the block
      // below reacts automatically on the next render.
    } finally {
      setBusy(false);
    }
  };

  const handleRecoveryFull = async () => {
    setBusy(true);
    try {
      const result = await stopAndLog(Math.round(recoveryPrompt.elapsedMs / 1000));
      if (result.outcome === 'needs_category') {
        setPendingViaRecovery(true);
        setSelectedCategory('');
      }
    } finally {
      setBusy(false);
    }
  };

  const maxHrs = recoveryPrompt ? Math.floor(recoveryPrompt.elapsedMs / 3600000) : 0;

  const handleRecoveryCustom = async () => {
    const hrs = parseInt(customHours, 10);
    if (!hrs || hrs < 1 || hrs > maxHrs) return;

    setBusy(true);
    try {
      const result = await stopAndLog(hrs * 3600);
      if (result.outcome === 'needs_category') {
        setPendingViaRecovery(true);
        setSelectedCategory('');
      }
    } finally {
      setCustomHours('');
      setCustomInputMode(false);
      setBusy(false);
    }
  };

  const handleConfirmCategory = async () => {
    if (!selectedCategory) return;
    setBusy(true);
    try {
      const result = await confirmCategory(selectedCategory);
      if (result.outcome === 'logged' && result.durationSeconds > 0) {
        setConfirmation(`Session logged: ${formatDuration(result.durationSeconds)}`);
        if (pendingViaRecovery) setPostRecovery(true);
      }
    } finally {
      setSelectedCategory('');
      setPendingViaRecovery(false);
      setBusy(false);
    }
  };

  const handleRecoveryDiscard = () => {
    discard();
    setCustomInputMode(false);
    setCustomHours('');
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Card className="h-full">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-xs sm:text-sm font-medium">Study Timer</CardTitle>
        <Timer className="h-3 w-3 sm:h-4 sm:w-4 text-amber-500" />
      </CardHeader>
      <CardContent>

        {/* ── Recovery prompt (4–16h) ── */}
        {recoveryPrompt && !busy && (
          <div className="space-y-3">
            <p className="text-xs sm:text-sm font-medium text-amber-800 leading-snug">
              {recoveryPrompt.source === 'stop'
                ? `Wow, a ${formatMs(recoveryPrompt.elapsedMs)} session! Just confirming — do you want to log the full time, or did you leave the timer running during a break?`
                : `Your timer ran for ${formatMs(recoveryPrompt.elapsedMs)}. Were you studying the whole time?`
              }
            </p>

            {!customInputMode ? (
              <div className="flex flex-col gap-1.5">
                <Button
                  size="sm"
                  className="h-8 w-full justify-start text-xs"
                  onClick={handleRecoveryFull}
                >
                  {recoveryPrompt.source === 'stop'
                    ? `Log full ${formatMs(recoveryPrompt.elapsedMs)}`
                    : `Yes — log ${formatMs(recoveryPrompt.elapsedMs)}`
                  }
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

        {/* ── Category picker — required before the session is logged (Sprint 8.5) ── */}
        {pendingLog && !busy && (
          <div className="space-y-2">
            <p className="text-xs sm:text-sm font-medium leading-snug">
              What were you studying?
            </p>
            <div className="grid grid-cols-1 gap-1.5">
              {CATEGORIES.map(({ value, label }) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setSelectedCategory(value)}
                  className={cn(
                    'h-8 rounded-md border px-3 text-left text-xs transition-colors',
                    selectedCategory === value
                      ? 'border-amber-500 bg-amber-50 font-medium text-amber-800'
                      : 'border-input hover:bg-muted'
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
            <Button
              size="sm"
              className="h-8 w-full"
              disabled={!selectedCategory}
              onClick={handleConfirmCategory}
            >
              Save
            </Button>
          </div>
        )}

        {/* ── Saving ── */}
        {busy && !recoveryPrompt && (
          <p className="text-xs sm:text-sm text-muted-foreground">Saving...</p>
        )}

        {/* ── Idle ── */}
        {!isRunning && !recoveryPrompt && !pendingLog && !busy && (
          <div className="flex items-center justify-between">
            <div>
              {confirmation ? (
                <>
                  <p className="text-xs sm:text-sm text-green-600 font-medium">{confirmation}</p>
                  {postRecovery && (
                    <p className="text-[10px] text-muted-foreground mt-0.5">
                      Tap Start to begin a new session.
                    </p>
                  )}
                </>
              ) : (
                <p className="text-[10px] sm:text-xs text-muted-foreground">Offline study</p>
              )}
            </div>
            <Button size="sm" className="h-8" onClick={handleStart}>
              Start
            </Button>
          </div>
        )}

        {/* ── Running — clock via DOM ref, zero context-wide re-renders ── */}
        {isRunning && !recoveryPrompt && (
          <div className="flex items-center justify-between">
            <div>
              <div
                ref={clockRef}
                className="text-xl sm:text-2xl font-bold font-mono text-amber-600"
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
              disabled={busy}
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
