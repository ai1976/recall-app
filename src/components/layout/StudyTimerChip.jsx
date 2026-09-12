// StudyTimerChip.jsx — Sprint 7.3-C
// Nav-bar indicator + stop control for the manual study timer. Sits beside the
// notification bell in both NavDesktop and NavMobile. Hidden entirely when no
// timer is running. Display refreshes on StudyTimerContext's own coarse
// (~30s) cadence — NOT a per-second tick — true per-second precision is
// reserved for the dedicated /dashboard/study-time route.
//
// Tap behavior:
//   elapsed < 4h   → stop + log immediately, toast confirmation, no navigation
//   elapsed 4–16h  → navigate to /dashboard/study-time, where the recovery
//                    prompt is already showing (context state drives it)
//   elapsed > 16h  → defensive — should not be reachable given the app-wide
//                    mount classification, but handled the same as the
//                    dedicated page would (discard + toast)

import { useNavigate } from 'react-router-dom';
import { Timer } from 'lucide-react';
import { useStudyTimer } from '@/contexts/StudyTimerContext';
import { useToast } from '@/hooks/use-toast';

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}s`;
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
}

// Mobile: compact minutes-only past the first hour (e.g. "72m", not "1h 12m") —
// the mobile top bar is already Wordmark + Bell only, so the chip stays terse.
function formatCompact(ms) {
  const totalMin = Math.floor(ms / 60000);
  return `${totalMin}m`;
}

// Desktop can afford the fuller label.
function formatFull(ms) {
  const totalMin = Math.floor(ms / 60000);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return h === 0 ? `${m}m` : `${h}h ${m}m`;
}

export default function StudyTimerChip({ compact = false }) {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { isRunning, elapsedMs, stop } = useStudyTimer();

  if (!isRunning) return null;

  const handleTap = async () => {
    const result = await stop();
    if (result.outcome === 'logged' && result.durationSeconds > 0) {
      toast({ title: 'Session logged', description: `Session logged: ${formatDuration(result.durationSeconds)}` });
    } else if (result.outcome === 'needs_recovery') {
      navigate('/dashboard/study-time');
    } else if (result.outcome === 'discarded') {
      toast({
        title: 'Session discarded',
        description: 'Timers over 16 hours cannot be logged to protect leaderboard integrity.',
        variant: 'destructive',
      });
    }
  };

  return (
    <button
      type="button"
      onClick={handleTap}
      aria-label={`Stop study timer — running ${formatFull(elapsedMs)}`}
      className="flex items-center gap-1 rounded-full border border-amber-200 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 transition-colors hover:bg-amber-100"
    >
      <Timer className="h-3.5 w-3.5" />
      <span>{compact ? formatCompact(elapsedMs) : formatFull(elapsedMs)}</span>
    </button>
  );
}
