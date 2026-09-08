import { useAuth } from '@/contexts/AuthContext';
import { useNavData } from '@/contexts/NavDataContext';
import NavDesktop from './NavDesktop';
import NavMobile from './NavMobile';

export default function Navigation() {
  const { user, signOut } = useAuth();
  // Sprint 7.0 (Finding 5): role / notifications / friend-request count now come
  // from the single NavDataProvider instance instead of three per-mount fetches.
  const {
    role, isSuperAdmin, isAdmin, isProfessor, isLoading: roleLoading,
    notifications, unreadCount, markAllRead, deleteNotification,
    refetchNotifications, notifLoading,
    pendingCount, friendLoading,
  } = useNavData();

  if (!user) return null;

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  // Shared props for both nav components
  const navProps = {
    user,
    role,
    isSuperAdmin,
    isAdmin,
    isProfessor,
    isLoading: roleLoading,
    notifications,
    unreadCount,
    markAllRead,
    deleteNotification,
    refetchNotifications,
    notifLoading,
    pendingCount,
    friendLoading,
    handleSignOut,
  };

  return (
    <nav className="bg-rv-bg-1 border-b border-rv-border sticky top-0 z-50 font-plex">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          {/* Desktop Navigation - hidden on mobile */}
          <NavDesktop {...navProps} />
          
          {/* Mobile Navigation - hidden on desktop */}
          <NavMobile {...navProps} />
        </div>
      </div>
    </nav>
  );
}
