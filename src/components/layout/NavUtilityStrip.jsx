import { useStudyTimer } from '@/contexts/StudyTimerContext';
import NotificationCenter from './NotificationCenter';
import ExamDateChip from './ExamDateChip';
import StudyTimerChip from './StudyTimerChip';

/**
 * NavUtilityStrip.jsx — desktop status strip (Sprint 8.8.3a, D-39).
 *
 * Separates "what's happening right now" (this strip) from "where can I go"
 * (NavDesktop.jsx's rail) — the desktop half of the split NavMobile.jsx's top
 * bar already had. Fixed, 48px tall, spans from the rail's right edge
 * (`md:left-60`) to the viewport's right edge — never full-width, never over
 * the rail. Hidden below `md`, exactly like the rail. App.jsx pads
 * authenticated content with `md:pt-12` to match.
 *
 * NotificationCenter / ExamDateChip / StudyTimerChip render in their existing
 * non-compact ("full-label") mode, unmodified — this only relocates them from
 * NavDesktop.jsx's old rail footer. StudyTimerChip still self-gates on
 * isRunning inside its own component; the `timerRunning` read here just
 * mirrors NavDesktop's pre-existing isRunning gate so the chip's wrapper
 * doesn't reserve empty space when no timer is running.
 */
export default function NavUtilityStrip({
  notifications,
  unreadCount,
  markAllRead,
  deleteNotification,
  refetchNotifications,
  pendingCount,
}) {
  const { isRunning: timerRunning } = useStudyTimer();

  return (
    <div className="hidden md:fixed md:top-0 md:left-60 md:right-0 md:z-40 md:flex md:h-12 md:items-center md:justify-end md:gap-3 border-b border-rv-border bg-rv-bg-1 px-4 font-plex">
      <NotificationCenter
        notifications={notifications}
        unreadCount={unreadCount}
        markAllRead={markAllRead}
        deleteNotification={deleteNotification}
        refetch={refetchNotifications}
        pendingCount={pendingCount}
      />
      <ExamDateChip />
      {timerRunning && <StudyTimerChip />}
    </div>
  );
}
