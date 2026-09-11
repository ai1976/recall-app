import { useRef, useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import {
  Bell, CheckCheck, UserPlus, Trophy, ThumbsUp, MessageSquare, Users,
  Check, X, UserCheck, Clock, Rss,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { notifyFriendEvent } from '@/lib/notifyEdge';

/**
 * NotificationCenter — Sprint 7.2-B.
 *
 * Merges the former FriendsDropdown + ActivityDropdown into ONE bell icon /
 * dropdown, shared by NavDesktop.jsx and NavMobile.jsx (single import, no
 * duplicated merge logic). One feed: incoming friend requests (with their
 * inline accept/decline, preserved verbatim) at the top, content notifications
 * below. Badge = unreadCount + pendingCount (a single summed number — the
 * two-part-indicator alternative wasn't worth the extra visual complexity for
 * one badge).
 *
 * `notifications` / `unreadCount` / `markAllRead` / `deleteNotification` /
 * `refetch` / `pendingCount` all still flow from NavDataContext via the
 * navProps bundle — this is a UI merge only, no new fetch hook.
 */
export default function NotificationCenter({
  notifications, unreadCount, markAllRead, deleteNotification, refetch,
  pendingCount,
}) {
  const { user } = useAuth();
  const hasMarkedRef = useRef(false);
  const [actionLoading, setActionLoading] = useState(null);

  // ── Friend requests (from FriendsDropdown) ──────────────────────────────
  const [pendingRequests, setPendingRequests] = useState([]);
  const [requestsLoading, setRequestsLoading] = useState(false);

  const fetchPendingRequests = useCallback(async () => {
    if (!user || pendingCount === 0) return;

    setRequestsLoading(true);
    try {
      const { data: requests, error } = await supabase
        .from('friendships')
        .select('id, user_id, created_at')
        .eq('friend_id', user.id)
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .limit(3);

      if (error) throw error;

      if (requests && requests.length > 0) {
        const userIds = requests.map((r) => r.user_id);
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name, email')
          .in('id', userIds);

        setPendingRequests(
          requests.map((req) => ({
            ...req,
            profile: profiles?.find((p) => p.id === req.user_id) || null,
          })),
        );
      } else {
        setPendingRequests([]);
      }
    } catch (err) {
      console.error('Error fetching pending requests:', err);
    } finally {
      setRequestsLoading(false);
    }
  }, [user, pendingCount]);

  const handleAcceptRequest = async (friendshipId, e) => {
    e.preventDefault();
    e.stopPropagation();

    const request = pendingRequests.find((r) => r.id === friendshipId);
    const senderId = request?.user_id;

    setActionLoading(`req-${friendshipId}`);
    try {
      const { error } = await supabase
        .from('friendships')
        .update({ status: 'accepted', updated_at: new Date().toISOString() })
        .eq('id', friendshipId);

      if (error) throw error;

      if (senderId) {
        notifyFriendEvent({ event_type: 'friend_accepted', actor_id: user.id, target_user_id: senderId });
      }

      setPendingRequests((prev) => prev.filter((r) => r.id !== friendshipId));
    } catch (err) {
      console.error('Error accepting request:', err);
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeclineRequest = async (friendshipId, e) => {
    e.preventDefault();
    e.stopPropagation();
    setActionLoading(`req-${friendshipId}`);

    try {
      const { error } = await supabase
        .from('friendships')
        .update({ status: 'rejected', updated_at: new Date().toISOString() })
        .eq('id', friendshipId);

      if (error) throw error;

      setPendingRequests((prev) => prev.filter((r) => r.id !== friendshipId));
    } catch (err) {
      console.error('Error declining request:', err);
    } finally {
      setActionLoading(null);
    }
  };

  // ── Content notifications (from ActivityDropdown) ───────────────────────
  const getNotificationIcon = (type) => {
    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
        return <UserPlus className="h-4 w-4 text-amber-500" />;
      case 'badge_earned':
        return <Trophy className="h-4 w-4 text-yellow-500" />;
      case 'upvote':
        return <ThumbsUp className="h-4 w-4 text-green-500" />;
      case 'comment':
        return <MessageSquare className="h-4 w-4 text-amber-500" />;
      case 'group_invite':
        return <Users className="h-4 w-4 text-amber-500" />;
      case 'access_request':
        return <UserPlus className="h-4 w-4 text-orange-500" />;
      case 'access_granted':
        return <CheckCheck className="h-4 w-4 text-green-500" />;
      case 'follow':
        return <UserPlus className="h-4 w-4 text-amber-500" />;
      default:
        return <Bell className="h-4 w-4 text-rv-ink-400" />;
    }
  };

  const getNotificationLink = (notification) => {
    switch (notification.type) {
      case 'friend_request':
        return '/dashboard/friend-requests';
      case 'friend_accepted':
        return '/dashboard/my-friends';
      case 'badge_earned':
        return '/dashboard/achievements';
      case 'upvote': {
        const { content_type, content_id } = notification.metadata || {};
        if (content_id && content_type === 'note') return `/dashboard/notes/${content_id}`;
        return '/dashboard/my-contributions';
      }
      case 'group_invite':
        return '/dashboard/groups';
      case 'access_request':
        return '/admin?tab=access-requests';
      case 'access_granted':
        return '/dashboard/review-flashcards';
      case 'follow': {
        const { follower_id } = notification.metadata || {};
        if (follower_id) return `/dashboard/profile/${follower_id}`;
        return '/dashboard/find-people';
      }
      default:
        return '/dashboard';
    }
  };

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

  const handleOpenChange = (open) => {
    if (open) {
      fetchPendingRequests();
      if (unreadCount > 0 && !hasMarkedRef.current) {
        hasMarkedRef.current = true;
        markAllRead();
      }
    } else {
      hasMarkedRef.current = false;
    }
  };

  const handleAcceptInvite = async (notification, e) => {
    e.preventDefault();
    e.stopPropagation();
    const membershipId = notification.metadata?.membership_id;
    if (!membershipId) return;

    setActionLoading(notification.id);
    try {
      const { error } = await supabase.rpc('accept_group_invite', { p_membership_id: membershipId });
      if (error) throw error;
      if (deleteNotification) await deleteNotification(notification.id);
      if (refetch) refetch();
    } catch (err) {
      console.error('Error accepting group invite:', err);
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeclineInvite = async (notification, e) => {
    e.preventDefault();
    e.stopPropagation();
    const membershipId = notification.metadata?.membership_id;
    if (!membershipId) return;

    setActionLoading(notification.id);
    try {
      const { error } = await supabase.rpc('decline_group_invite', { p_membership_id: membershipId });
      if (error) throw error;
      if (deleteNotification) await deleteNotification(notification.id);
      if (refetch) refetch();
    } catch (err) {
      console.error('Error declining group invite:', err);
    } finally {
      setActionLoading(null);
    }
  };

  const renderNotificationBody = (notification) => {
    const isGroupInvite = notification.type === 'group_invite';
    return (
      <div className="flex-1 min-w-0">
        <p className={`text-sm ${!notification.is_read ? 'font-medium' : ''} text-rv-ink-900`}>
          {notification.title}
        </p>
        {notification.message && (
          <p className="text-xs text-rv-ink-400 mt-0.5 line-clamp-2">{notification.message}</p>
        )}
        {isGroupInvite && notification.metadata?.membership_id && (
          <div className="flex items-center gap-2 mt-2">
            <Button
              size="sm"
              className="h-7 text-xs bg-green-600 hover:bg-green-700 text-white"
              onClick={(e) => handleAcceptInvite(notification, e)}
              disabled={actionLoading === notification.id}
            >
              <Check className="h-3 w-3 mr-1" /> Accept
            </Button>
            <Button
              size="sm"
              variant="outline"
              className="h-7 text-xs text-red-600 border-red-200 hover:bg-red-50"
              onClick={(e) => handleDeclineInvite(notification, e)}
              disabled={actionLoading === notification.id}
            >
              <X className="h-3 w-3 mr-1" /> Decline
            </Button>
          </div>
        )}
        <p className="text-xs text-rv-ink-400 mt-1">{formatTime(notification.created_at)}</p>
      </div>
    );
  };

  const totalBadge = (unreadCount || 0) + (pendingCount || 0);
  const hasContent = (pendingRequests.length > 0) || (notifications && notifications.length > 0);

  return (
    <DropdownMenu onOpenChange={handleOpenChange}>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="relative h-10 w-10" aria-label="Notifications">
          <Bell className="h-5 w-5 text-rv-ink-600" />
          {totalBadge > 0 && (
            <span className="absolute -top-1 -right-1 h-5 w-5 flex items-center justify-center bg-red-500 text-white text-xs font-bold rounded-full">
              {totalBadge > 9 ? '9+' : totalBadge}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-80">
        {/* Header */}
        <div className="px-3 py-2 border-b flex items-center justify-between">
          <p className="text-sm font-semibold text-rv-ink-900">Notifications</p>
          {unreadCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              className="h-7 text-xs text-rv-navy hover:text-rv-navy-400"
              onClick={markAllRead}
            >
              <CheckCheck className="h-3 w-3 mr-1" /> Mark all read
            </Button>
          )}
        </div>

        <div className="max-h-96 overflow-y-auto">
          {/* Friend requests — kept inline accept/decline, no dead-end link */}
          {(requestsLoading || pendingRequests.length > 0) && (
            <>
              <div className="px-3 pt-2 pb-1">
                <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wide">Friend Requests</p>
              </div>
              {requestsLoading ? (
                <div className="px-3 py-3 text-center text-sm text-rv-ink-400">Loading...</div>
              ) : (
                pendingRequests.map((request) => (
                  <div key={request.id} className="px-3 py-2 hover:bg-rv-bg-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-rv-ink-900 truncate">
                          {request.profile?.full_name || 'Unknown User'}
                        </p>
                        <p className="text-xs text-rv-ink-400 truncate">{request.profile?.email}</p>
                      </div>
                      <div className="flex items-center gap-1 shrink-0">
                        <Button
                          size="icon"
                          variant="ghost"
                          className="h-7 w-7 text-green-600 hover:text-green-700 hover:bg-green-50"
                          onClick={(e) => handleAcceptRequest(request.id, e)}
                          disabled={actionLoading === `req-${request.id}`}
                        >
                          <Check className="h-4 w-4" />
                        </Button>
                        <Button
                          size="icon"
                          variant="ghost"
                          className="h-7 w-7 text-red-600 hover:text-red-700 hover:bg-red-50"
                          onClick={(e) => handleDeclineRequest(request.id, e)}
                          disabled={actionLoading === `req-${request.id}`}
                        >
                          <X className="h-4 w-4" />
                        </Button>
                      </div>
                    </div>
                  </div>
                ))
              )}
              {pendingCount > 3 && (
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/friend-requests" className="text-xs text-rv-ink-400 cursor-pointer justify-center">
                    +{pendingCount - 3} more requests
                  </Link>
                </DropdownMenuItem>
              )}
              <DropdownMenuSeparator />
            </>
          )}

          {/* Content notifications */}
          {notifications && notifications.length > 0 ? (
            notifications.map((notification) =>
              notification.type === 'group_invite' ? (
                <DropdownMenuItem key={notification.id} asChild>
                  <div className={`flex items-start gap-3 px-3 py-3 cursor-default ${!notification.is_read ? 'bg-rv-navy-50' : ''}`}>
                    <div className="flex-shrink-0 mt-0.5">{getNotificationIcon(notification.type)}</div>
                    {renderNotificationBody(notification)}
                    {!notification.is_read && (
                      <div className="flex-shrink-0">
                        <div className="h-2 w-2 bg-rv-navy rounded-full" />
                      </div>
                    )}
                  </div>
                </DropdownMenuItem>
              ) : (
                <DropdownMenuItem key={notification.id} asChild>
                  <Link
                    to={getNotificationLink(notification)}
                    className={`flex items-start gap-3 px-3 py-3 cursor-pointer ${!notification.is_read ? 'bg-rv-navy-50' : ''}`}
                  >
                    <div className="flex-shrink-0 mt-0.5">{getNotificationIcon(notification.type)}</div>
                    {renderNotificationBody(notification)}
                    {!notification.is_read && (
                      <div className="flex-shrink-0">
                        <div className="h-2 w-2 bg-rv-navy rounded-full" />
                      </div>
                    )}
                  </Link>
                </DropdownMenuItem>
              ),
            )
          ) : null}

          {!hasContent && !requestsLoading && (
            <div className="px-3 py-8 text-center">
              <Bell className="h-8 w-8 text-rv-ink-400 mx-auto mb-2" />
              <p className="text-sm text-rv-ink-400">No new notifications</p>
            </div>
          )}
        </div>

        <DropdownMenuSeparator />

        {/* Friends & Following quick links — preserved from the former FriendsDropdown */}
        <DropdownMenuItem asChild>
          <Link to="/dashboard/find-friends" className="flex items-center gap-2 cursor-pointer">
            <UserPlus className="h-4 w-4" /> Find People
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/my-friends" className="flex items-center gap-2 cursor-pointer">
            <UserCheck className="h-4 w-4" /> My Friends
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/following" className="flex items-center gap-2 cursor-pointer">
            <Rss className="h-4 w-4" /> Following
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/friend-requests" className="flex items-center gap-2 cursor-pointer">
            <Clock className="h-4 w-4" /> View All Requests
          </Link>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
