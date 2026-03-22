import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Search, UserPlus, Users, Rss, UserCheck } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import BadgeIcon from '@/components/badges/BadgeIcon';
import PageContainer from '@/components/layout/PageContainer';
import { notifyFriendEvent } from '@/lib/notifyEdge';

export default function FindFriends() {
  const { user } = useAuth();
  const { toast } = useToast();

  const [searchTerm, setSearchTerm] = useState('');
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [userBadges, setUserBadges] = useState({});
  const [followingSet, setFollowingSet] = useState(new Set()); // user_ids the caller follows
  const [followLoading, setFollowLoading] = useState(null); // user_id currently being toggled

  useEffect(() => {
    fetchUsers();
    fetchFollowingSet();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const fetchFollowingSet = async () => {
    try {
      const { data } = await supabase.rpc('get_following_with_stats');
      setFollowingSet(new Set((data || []).map(f => f.user_id)));
    } catch {
      // non-critical — buttons default to "Follow"
    }
  };

  const handleFollowToggle = async (userId) => {
    const isFollowing = followingSet.has(userId);
    setFollowLoading(userId);
    // optimistic update
    setFollowingSet(prev => {
      const next = new Set(prev);
      isFollowing ? next.delete(userId) : next.add(userId);
      return next;
    });
    try {
      const rpc = isFollowing ? 'unfollow_user' : 'follow_user';
      const { error } = await supabase.rpc(rpc, { p_followee_id: userId });
      if (error) throw error;
    } catch (error) {
      // revert on error
      setFollowingSet(prev => {
        const next = new Set(prev);
        isFollowing ? next.add(userId) : next.delete(userId);
        return next;
      });
      toast({ title: 'Error', description: error.message, variant: 'destructive' });
    } finally {
      setFollowLoading(null);
    }
  };

  const fetchUsers = async () => {
    try {
      const { data, error } = await supabase.rpc('get_discoverable_users');
      if (error) throw error;
      setUsers(data || []);
      fetchUserBadges((data || []).map(u => u.user_id));
    } catch (error) {
      console.error('Error fetching users:', error);
    }
  };

  const fetchUserBadges = async (userIds) => {
    if (!userIds || userIds.length === 0) return;
    try {
      const { data, error } = await supabase
        .from('user_badges')
        .select(`
          user_id,
          badge_id,
          is_public,
          badge_definitions (
            key,
            name,
            icon_key
          )
        `)
        .in('user_id', userIds)
        .eq('is_public', true);

      if (error) throw error;

      const badgesByUser = {};
      (data || []).forEach(item => {
        if (!badgesByUser[item.user_id]) badgesByUser[item.user_id] = [];
        if (item.badge_definitions) badgesByUser[item.user_id].push(item.badge_definitions);
      });
      setUserBadges(badgesByUser);
    } catch (error) {
      console.error('Error fetching user badges:', error);
    }
  };

  const sendFriendRequest = async (friendId) => {
    setLoading(true);
    try {
      const { error } = await supabase
        .from('friendships')
        .upsert({
          user_id: user.id,
          friend_id: friendId,
          status: 'pending',
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id, friend_id' });

      if (error) throw error;

      toast({
        title: "Friend request sent!",
        description: "Your friend request has been sent.",
      });

      notifyFriendEvent({ event_type: 'friend_request', actor_id: user.id, target_user_id: friendId });
      fetchUsers();
    } catch (error) {
      console.error('Error sending friend request:', error);
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter(u =>
    u.full_name?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <PageContainer width="full">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Find People</h1>
        <p className="text-gray-600">
          Add friends or follow anyone who inspires you
        </p>
      </div>

      {/* Search Bar */}
      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
          <Input
            type="text"
            placeholder="Search by name..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
        <p className="text-sm text-gray-500 mt-2">
          Showing {filteredUsers.length} of {users.length} users
        </p>
      </div>

      {/* User List */}
      <div className="space-y-4">
        {filteredUsers.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Users className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">No users found</p>
            </CardContent>
          </Card>
        ) : (
          filteredUsers.map((person) => {
            const personBadges = userBadges[person.user_id] || [];

            return (
              <Card key={person.user_id}>
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex items-start gap-3">
                      {/* Avatar */}
                      <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-semibold text-lg">
                        {person.full_name?.charAt(0) || '?'}
                      </div>

                      {/* Info */}
                      <div>
                        <CardTitle className="text-lg flex items-center gap-2 flex-wrap">
                          <Link
                            to={`/dashboard/profile/${person.user_id}`}
                            className="hover:text-blue-600 transition-colors"
                          >
                            {person.full_name || 'Unknown'}
                          </Link>
                          {person.role === 'professor' && (
                            <span className="text-sm font-normal text-blue-600">
                              👨‍🏫 Professor
                            </span>
                          )}
                          {personBadges.length > 0 && (
                            <div className="flex items-center gap-1 ml-1">
                              {personBadges.slice(0, 4).map((badge) => (
                                <BadgeIcon
                                  key={badge.key}
                                  iconKey={badge.icon_key}
                                  size="xs"
                                  unlocked={true}
                                  showBackground={true}
                                />
                              ))}
                              {personBadges.length > 4 && (
                                <span className="text-xs text-gray-500 ml-1">
                                  +{personBadges.length - 4}
                                </span>
                              )}
                            </div>
                          )}
                        </CardTitle>
                        <CardDescription>
                          {person.masked_email}
                          {person.course_level && (
                            <span className="ml-2">• {person.course_level}</span>
                          )}
                          {person.institution && (
                            <span className="ml-2">• {person.institution}</span>
                          )}
                        </CardDescription>
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex items-center gap-2">
                      <Button
                        onClick={() => handleFollowToggle(person.user_id)}
                        disabled={followLoading === person.user_id}
                        size="sm"
                        variant="outline"
                      >
                        {followingSet.has(person.user_id) ? (
                          <>
                            <UserCheck className="h-4 w-4 mr-2" />
                            Following
                          </>
                        ) : (
                          <>
                            <Rss className="h-4 w-4 mr-2" />
                            Follow
                          </>
                        )}
                      </Button>
                      <Button
                        onClick={() => sendFriendRequest(person.user_id)}
                        disabled={loading}
                        size="sm"
                      >
                        <UserPlus className="h-4 w-4 mr-2" />
                        Add Friend
                      </Button>
                    </div>
                  </div>
                </CardHeader>
              </Card>
            );
          })
        )}
      </div>
    </PageContainer>
  );
}
