import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Search, UserPlus, Users, Clock } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

export default function FindFriends() {
  const { user } = useAuth();
  const { toast } = useToast();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [friendships, setFriendships] = useState([]);

  // Fetch all users on mount
  useEffect(() => {
    fetchUsers();
    fetchFriendships();
  }, [user?.id]);

  const fetchUsers = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('id, full_name, email, course_level, role')
        .neq('id', user.id) // Exclude current user
        .order('full_name');

      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
    }
  };

  const fetchFriendships = async () => {
    try {
      const { data, error } = await supabase
        .from('friendships')
        .select('*')
        .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`);

      if (error) throw error;
      setFriendships(data || []);
    } catch (error) {
      console.error('Error fetching friendships:', error);
    }
  };

  const sendFriendRequest = async (friendId) => {
    setLoading(true);
    try {
      const { error } = await supabase
        .from('friendships')
        .insert({
          user_id: user.id,
          friend_id: friendId,
          status: 'pending'
        });

      if (error) throw error;

      toast({
        title: "Friend request sent!",
        description: "Your friend request has been sent.",
      });

      // Refresh friendships
      fetchFriendships();
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

  // Get friendship status for a user
  const getFriendshipStatus = (userId) => {
    const friendship = friendships.find(
      f => (f.user_id === user.id && f.friend_id === userId) ||
           (f.friend_id === user.id && f.user_id === userId)
    );
    
    if (!friendship) return null;
    
    // If current user sent the request
    if (friendship.user_id === user.id) {
      return { status: friendship.status, type: 'sent' };
    }
    // If current user received the request
    return { status: friendship.status, type: 'received' };
  };

  // Filter users by search term
  const filteredUsers = users.filter(u => 
    u.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    u.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Find Friends</h1>
        <p className="text-gray-600">
          Connect with your classmates to share study materials
        </p>
      </div>

      {/* Search Bar */}
      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
          <Input
            type="text"
            placeholder="Search by name or email..."
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
            const friendStatus = getFriendshipStatus(person.id);
            
            return (
              <Card key={person.id}>
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex items-start gap-3">
                      {/* Avatar */}
                      <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-semibold text-lg">
                        {person.full_name?.charAt(0) || person.email?.charAt(0)}
                      </div>
                      
                      {/* Info */}
                      <div>
                        <CardTitle className="text-lg">
                          {person.full_name || 'Unknown'}
                          {person.role === 'professor' && (
                            <span className="ml-2 text-sm font-normal text-blue-600">
                              👨‍🏫 Professor
                            </span>
                          )}
                        </CardTitle>
                        <CardDescription>
                          {person.email}
                          {person.course_level && (
                            <span className="ml-2">• {person.course_level}</span>
                          )}
                        </CardDescription>
                      </div>
                    </div>

                    {/* Action Button */}
                    <div>
                      {!friendStatus && (
                        <Button
                          onClick={() => sendFriendRequest(person.id)}
                          disabled={loading}
                          size="sm"
                        >
                          <UserPlus className="h-4 w-4 mr-2" />
                          Add Friend
                        </Button>
                      )}
                      
                      {friendStatus?.status === 'pending' && friendStatus?.type === 'sent' && (
                        <Button variant="outline" size="sm" disabled>
                          <Clock className="h-4 w-4 mr-2" />
                          Request Sent
                        </Button>
                      )}
                      
                      {friendStatus?.status === 'pending' && friendStatus?.type === 'received' && (
                        <Button variant="outline" size="sm" disabled>
                          <Clock className="h-4 w-4 mr-2" />
                          Pending
                        </Button>
                      )}
                      
                      {friendStatus?.status === 'accepted' && (
                        <Button variant="outline" size="sm" disabled>
                          <Users className="h-4 w-4 mr-2" />
                          Friends
                        </Button>
                      )}
                    </div>
                  </div>
                </CardHeader>
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
}