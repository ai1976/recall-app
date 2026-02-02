import { useRef } from 'react';
import { Link } from 'react-router-dom';
import { Bell, CheckCheck, UserPlus, Trophy, ThumbsUp, MessageSquare } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

export default function ActivityDropdown({ notifications, unreadCount, markAllRead }) {
  const hasMarkedRef = useRef(false);

  // Get icon for notification type
  const getNotificationIcon = (type) => {
    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
        return <UserPlus className="h-4 w-4 text-blue-500" />;
      case 'badge_earned':
        return <Trophy className="h-4 w-4 text-yellow-500" />;
      case 'upvote':
        return <ThumbsUp className="h-4 w-4 text-green-500" />;
      case 'comment':
        return <MessageSquare className="h-4 w-4 text-purple-500" />;
      default:
        return <Bell className="h-4 w-4 text-gray-500" />;
    }
  };

  // Get link for notification
  const getNotificationLink = (notification) => {
    switch (notification.type) {
      case 'friend_request':
        return '/dashboard/friend-requests';
      case 'friend_accepted':
        return '/dashboard/my-friends';
      case 'badge_earned':
        return '/dashboard/achievements';
      case 'upvote':
        return '/dashboard/my-contributions';
      default:
        return '/dashboard';
    }
  };

  // Format relative time
  const formatTime = (timestamp) => {
    const now = new Date();
    const date = new Date(timestamp);
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  // Mark all as read when dropdown opens (only once per open)
  const handleOpenChange = (open) => {
    if (open && unreadCount > 0 && !hasMarkedRef.current) {
      hasMarkedRef.current = true;
      markAllRead();
    }
    if (!open) {
      hasMarkedRef.current = false;
    }
  };

  return (
    <DropdownMenu onOpenChange={handleOpenChange}>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="relative h-10 w-10">
          <Bell className="h-5 w-5 text-gray-600" />
          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 h-5 w-5 flex items-center justify-center bg-red-500 text-white text-xs font-bold rounded-full">
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-80">
        {/* Header */}
        <div className="px-3 py-2 border-b flex items-center justify-between">
          <p className="text-sm font-semibold text-gray-900">Notifications</p>
          {unreadCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              className="h-7 text-xs text-blue-600 hover:text-blue-700"
              onClick={markAllRead}
            >
              <CheckCheck className="h-3 w-3 mr-1" />
              Mark all read
            </Button>
          )}
        </div>

        {/* Notifications List */}
        {notifications && notifications.length > 0 ? (
          <div className="max-h-80 overflow-y-auto">
            {notifications.map((notification) => (
              <DropdownMenuItem key={notification.id} asChild>
                <Link
                  to={getNotificationLink(notification)}
                  className={`
                    flex items-start gap-3 px-3 py-3 cursor-pointer
                    ${!notification.is_read ? 'bg-blue-50' : ''}
                  `}
                >
                  <div className="flex-shrink-0 mt-0.5">
                    {getNotificationIcon(notification.type)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm ${!notification.is_read ? 'font-medium' : ''} text-gray-900`}>
                      {notification.title}
                    </p>
                    {notification.message && (
                      <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">
                        {notification.message}
                      </p>
                    )}
                    <p className="text-xs text-gray-400 mt-1">
                      {formatTime(notification.created_at)}
                    </p>
                  </div>
                  {!notification.is_read && (
                    <div className="flex-shrink-0">
                      <div className="h-2 w-2 bg-blue-500 rounded-full" />
                    </div>
                  )}
                </Link>
              </DropdownMenuItem>
            ))}
          </div>
        ) : (
          <div className="px-3 py-8 text-center">
            <Bell className="h-8 w-8 text-gray-300 mx-auto mb-2" />
            <p className="text-sm text-gray-500">No new notifications</p>
          </div>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
