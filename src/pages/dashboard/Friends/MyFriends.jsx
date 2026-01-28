import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Search, Users, UserMinus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';

export default function MyFriends() {
  const { user } = useAuth();
  const { toast } = useToast();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [friends, setFriends] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchFriends();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const fetchFriends = async () => {
    try {
      // Get accepted friendships where current user is either user_id or friend_id
      const { data: friendships, error } = await supabase
        .from('friendships')
        .select('*')
        .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`)
        .eq('status', 'accepted')
        .order('updated_at', { ascending: false });

      if (error) throw error;

      if (friendships && friendships.length > 0) {
        // Get friend IDs (the OTHER person in each friendship)
        const friendIds = friendships.map(f => 
          f.user_id === user.id ? f.friend_id : f.user_id
        );

        // Fetch friend profiles
        const { data: profiles, error: profileError } = await supabase
          .from('profiles')
          .select('id, full_name, email, course_level, role')
          .in('id', friendIds);

        if (profileError) throw profileError;

        // Merge friendships with profiles
        const friendsWithProfiles = friendships.map(friendship => {
          const friendId = friendship.user_id === user.id ? friendship.friend_id : friendship.user_id;
          return {
            friendshipId: friendship.id,
            becameFriendsAt: friendship.updated_at,
            ...profiles.find(p => p.id === friendId)
          };
        });

        setFriends(friendsWithProfiles);
      } else {
        setFriends([]);
      }
    } catch (error) {
      console.error('Error fetching friends:', error);
    }
  };

  const handleUnfriend = async (friendshipId, friendName) => {
    if (!confirm(`Remove ${friendName} from your friends?`)) return;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('friendships')
        .delete()
        .eq('id', friendshipId);

      if (error) throw error;

      toast({
        title: "Friend removed",
        description: `${friendName} has been removed from your friends.`,
      });

      // Refresh list
      fetchFriends();
    } catch (error) {
      console.error('Error removing friend:', error);
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  // Filter friends by search term
  const filteredFriends = friends.filter(friend => 
    friend.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    friend.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <PageContainer width="full">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">My Friends</h1>
        <p className="text-gray-600">
          {friends.length === 0 
            ? "You don't have any friends yet" 
            : `You have ${friends.length} friend${friends.length > 1 ? 's' : ''}`
          }
        </p>
      </div>

      {/* Search Bar */}
      {friends.length > 0 && (
        <div className="mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
            <Input
              type="text"
              placeholder="Search friends..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
          <p className="text-sm text-gray-500 mt-2">
            Showing {filteredFriends.length} of {friends.length} friends
          </p>
        </div>
      )}

      {/* Friends List */}
      <div className="space-y-4">
        {friends.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Users className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">No friends yet</p>
              <p className="text-sm text-gray-500 mt-2">
                Send friend requests to connect with your classmates
              </p>
            </CardContent>
          </Card>
        ) : filteredFriends.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Search className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">No friends found matching "{searchTerm}"</p>
            </CardContent>
          </Card>
        ) : (
          filteredFriends.map((friend) => (
            <Card key={friend.id}>
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-3">
                    {/* Avatar */}
                    <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-semibold text-lg">
                      {friend.full_name?.charAt(0) || friend.email?.charAt(0)}
                    </div>
                    
                    {/* Info */}
                    <div>
                      <CardTitle className="text-lg">
                        {friend.full_name || 'Unknown'}
                        {friend.role === 'professor' && (
                          <span className="ml-2 text-sm font-normal text-blue-600">
                            👨‍🏫 Professor
                          </span>
                        )}
                      </CardTitle>
                      <CardDescription>
                        {friend.course_level || 'No course specified'}
                      </CardDescription>
                      <p className="text-xs text-gray-500 mt-1">
                        Friends since {new Date(friend.becameFriendsAt).toLocaleDateString()}
                      </p>
                    </div>
                  </div>

                  {/* Unfriend Button */}
                  <Button
                    onClick={() => handleUnfriend(friend.friendshipId, friend.full_name)}
                    disabled={loading}
                    size="sm"
                    variant="outline"
                  >
                    <UserMinus className="h-4 w-4 mr-2" />
                    Unfriend
                  </Button>
                </div>
              </CardHeader>
            </Card>
          ))
        )}
      </div>
   </PageContainer>
  );
}