import { Link } from 'react-router-dom';
import { Wordmark } from '@/components/revisop';
import FriendsDropdown from './FriendsDropdown';
import ActivityDropdown from './ActivityDropdown';

/**
 * NavMobile — the mobile TOP bar.
 *
 * Sprint 7.1 (Layout A): slimmed to Wordmark (left) · Friends + Bell (right).
 * The hamburger menu moved to the bottom-tab bar's "Menu" slot — its drawer now
 * lives in NavMenuSheet.jsx, rendered by NavBottomTabs. Everything else on
 * mobile (Dashboard / Review / Create / Progress) is in NavBottomTabs.
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

      {/* Right side icons */}
      <div className="flex items-center space-x-1">
        {/* Friends Icon */}
        <FriendsDropdown pendingCount={pendingCount} />

        {/* Bell Icon */}
        <ActivityDropdown
          notifications={notifications}
          unreadCount={unreadCount}
          markAllRead={markAllRead}
          deleteNotification={deleteNotification}
          refetch={refetchNotifications}
        />
      </div>
    </div>
  );
}
