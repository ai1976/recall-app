import { useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { Users, Check, X, UserPlus, UserCheck, Clock } from 'lucide-react';
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

export default function FriendsDropdown({ pendingCount }) {
  const { user } = useAuth();
  const [pendingRequests, setPendingRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(null);

  // Fetch pending requests when dropdown opens
  const fetchPendingRequests = useCallback(async () => {
    if (!user || pendingCount === 0) return;

    setLoading(true);
    try {
      // Fetch pending requests where current user is the recipient
      const { data: requests, error } = await supabase
        .from('friendships')
        .select('id, user_id, created_at')
        .eq('friend_id', user.id)
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .limit(3);

      if (error) throw error;

      if (requests && requests.length > 0) {
        // Fetch profile info for each requester
        const userIds = requests.map(r => r.user_id);
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name, email')
          .in('id', userIds);

        // Merge profile data with requests
        const merged = requests.map(req => ({
          ...req,
          profile: profiles?.find(p => p.id === req.user_id) || null
        }));

        setPendingRequests(merged);
      } else {
        setPendingRequests([]);
      }
    } catch (err) {
      console.error('Error fetching pending requests:', err);
    } finally {
      setLoading(false);
    }
  }, [user, pendingCount]);

  // Handle accept request
  const handleAccept = async (friendshipId, e) => {
    e.preventDefault();
    e.stopPropagation();

    // Capture sender id before the async update
    const request = pendingRequests.find((r) => r.id === friendshipId);
    const senderId = request?.user_id;

    setActionLoading(friendshipId);

    try {
      const { error } = await supabase
        .from('friendships')
        .update({ status: 'accepted', updated_at: new Date().toISOString() })
        .eq('id', friendshipId);

      if (error) throw error;

      // Fire-and-forget: notify the original sender
      if (senderId) {
        notifyFriendEvent({ event_type: 'friend_accepted', actor_id: user.id, target_user_id: senderId });
      }

      // Remove from local list
      setPendingRequests(prev => prev.filter(r => r.id !== friendshipId));
    } catch (err) {
      console.error('Error accepting request:', err);
    } finally {
      setActionLoading(null);
    }
  };

  // Handle decline request
  const handleDecline = async (friendshipId, e) => {
    e.preventDefault();
    e.stopPropagation();
    setActionLoading(friendshipId);

    try {
      const { error } = await supabase
        .from('friendships')
        .update({ status: 'rejected', updated_at: new Date().toISOString() })
        .eq('id', friendshipId);

      if (error) throw error;

      // Remove from local list
      setPendingRequests(prev => prev.filter(r => r.id !== friendshipId));
    } catch (err) {
      console.error('Error declining request:', err);
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <DropdownMenu onOpenChange={(open) => open && fetchPendingRequests()}>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="relative h-10 w-10">
          <Users className="h-5 w-5 text-gray-600" />
          {pendingCount > 0 && (
            <span className="absolute -top-1 -right-1 h-5 w-5 flex items-center justify-center bg-red-500 text-white text-xs font-bold rounded-full">
              {pendingCount > 9 ? '9+' : pendingCount}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-72">
        {/* Header */}
        <div className="px-3 py-2 border-b">
          <p className="text-sm font-semibold text-gray-900">Friend Requests</p>
        </div>

        {/* Pending Requests */}
        {loading ? (
          <div className="px-3 py-4 text-center text-sm text-gray-500">
            Loading...
          </div>
        ) : pendingRequests.length > 0 ? (
          <div className="py-1">
            {pendingRequests.map((request) => (
              <div
                key={request.id}
                className="px-3 py-2 hover:bg-gray-50"
              >
                <div className="flex items-center justify-between">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {request.profile?.full_name || 'Unknown User'}
                    </p>
                    <p className="text-xs text-gray-500 truncate">
                      {request.profile?.email}
                    </p>
                  </div>
                  <div className="flex items-center gap-1 ml-2">
                    <Button
                      size="icon"
                      variant="ghost"
                      className="h-7 w-7 text-green-600 hover:text-green-700 hover:bg-green-50"
                      onClick={(e) => handleAccept(request.id, e)}
                      disabled={actionLoading === request.id}
                    >
                      <Check className="h-4 w-4" />
                    </Button>
                    <Button
                      size="icon"
                      variant="ghost"
                      className="h-7 w-7 text-red-600 hover:text-red-700 hover:bg-red-50"
                      onClick={(e) => handleDecline(request.id, e)}
                      disabled={actionLoading === request.id}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="px-3 py-4 text-center text-sm text-gray-500">
            No pending requests
          </div>
        )}

        <DropdownMenuSeparator />

        {/* Quick Links */}
        <DropdownMenuItem asChild>
          <Link to="/dashboard/friend-requests" className="flex items-center gap-2 cursor-pointer">
            <Clock className="h-4 w-4" />
            View All Requests
            {pendingCount > 3 && (
              <span className="ml-auto text-xs text-gray-500">+{pendingCount - 3} more</span>
            )}
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/find-friends" className="flex items-center gap-2 cursor-pointer">
            <UserPlus className="h-4 w-4" />
            Find Friends
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/my-friends" className="flex items-center gap-2 cursor-pointer">
            <UserCheck className="h-4 w-4" />
            My Friends
          </Link>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
