import { Link } from 'react-router-dom';
import { Wordmark } from '@/components/revisop';
import NotificationCenter from './NotificationCenter';
import StudyTimerChip from './StudyTimerChip';

/**
 * NavMobile — the mobile TOP bar.
 *
 * Sprint 7.1 (Layout A): slimmed to Wordmark (left) · Friends + Bell (right).
 * Sprint 7.2-B: Friends + Bell merged into a single NotificationCenter bell —
 * top bar is now Wordmark (left) · Bell (right). The hamburger menu moved to
 * the bottom-tab bar's "Menu" slot — its drawer lives in NavMenuSheet.jsx,
 * rendered by NavBottomTabs. Everything else on mobile (Dashboard / Review /
 * Create / Progress) is in NavBottomTabs.
 */
export default function NavMobile({
  notifications,
  unreadCount,
  markAllRead,
  deleteNotification,
  refetchNotifications,
  pendingCount,
}) {
  return (
    <div className="md:hidden flex items-center justify-between w-full">
      {/* Logo — shared <Wordmark /> (Sprint 6.2) */}
      <Link to="/dashboard" className="flex items-center gap-2">
        <Wordmark />
      </Link>

      <div className="flex items-center gap-2">
        {/* Manual study-timer indicator (Sprint 7.3-C) — hidden when not running */}
        <StudyTimerChip compact />

        {/* Unified notification center (Sprint 7.2-B) */}
        <NotificationCenter
          notifications={notifications}
          unreadCount={unreadCount}
          markAllRead={markAllRead}
          deleteNotification={deleteNotification}
          refetch={refetchNotifications}
          pendingCount={pendingCount}
        />
      </div>
    </div>
  );
}
