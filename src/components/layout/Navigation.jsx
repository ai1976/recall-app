import { useAuth } from '@/contexts/AuthContext';
import { useRole } from '@/hooks/useRole';
import { useNotifications } from '@/hooks/useNotifications';
import { useFriendRequestCount } from '@/hooks/useFriendRequestCount';
import NavDesktop from './NavDesktop';
import NavMobile from './NavMobile';

export default function Navigation() {
  const { user, signOut } = useAuth();
  const { role, isSuperAdmin, isAdmin, isProfessor, isLoading: roleLoading } = useRole();
  const { notifications, unreadCount, markAllRead, deleteNotification, refetch: refetchNotifications, loading: notifLoading } = useNotifications(5);
  const { pendingCount, loading: friendLoading } = useFriendRequestCount();

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
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
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
