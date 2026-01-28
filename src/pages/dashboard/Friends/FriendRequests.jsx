import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { UserPlus, UserCheck, UserX, Clock, Users } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';

export default function FriendRequests() {
  const { user } = useAuth();
  const { toast } = useToast();
  
  const [pendingRequests, setPendingRequests] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchPendingRequests();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const fetchPendingRequests = async () => {
    try {
      // Get pending requests WHERE current user is the friend_id (receiver)
      const { data: friendships, error } = await supabase
        .from('friendships')
        .select('*')
        .eq('friend_id', user.id)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (error) throw error;

      // Fetch sender profiles
      if (friendships && friendships.length > 0) {
        const senderIds = friendships.map(f => f.user_id);
        
        const { data: profiles, error: profileError } = await supabase
          .from('profiles')
          .select('id, full_name, email, course_level, role')
          .in('id', senderIds);

        if (profileError) throw profileError;

        // Merge friendships with profiles
        const requestsWithProfiles = friendships.map(friendship => ({
          ...friendship,
          sender: profiles.find(p => p.id === friendship.user_id)
        }));

        setPendingRequests(requestsWithProfiles);
      } else {
        setPendingRequests([]);
      }
    } catch (error) {
      console.error('Error fetching pending requests:', error);
    }
  };

  const handleAccept = async (friendshipId) => {
    setLoading(true);
    try {
      const { error } = await supabase
        .from('friendships')
        .update({ 
          status: 'accepted',
          updated_at: new Date().toISOString()
        })
        .eq('id', friendshipId);

      if (error) throw error;

      toast({
        title: "Friend request accepted!",
        description: "You are now friends.",
      });

      // Refresh list
      fetchPendingRequests();
    } catch (error) {
      console.error('Error accepting request:', error);
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  // ✅ FIX: Changed from Soft Delete (Update) to Hard Delete
  const handleReject = async (friendshipId) => {
    setLoading(true);
    try {
      const { error } = await supabase
        .from('friendships')
        .delete() // <--- THIS IS THE FIX (Deletes the row completely)
        .eq('id', friendshipId);

      if (error) throw error;

      toast({
        title: "Friend request rejected",
        description: "Request has been removed.",
      });

      // Refresh list
      fetchPendingRequests();
    } catch (error) {
      console.error('Error rejecting request:', error);
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <PageContainer width="full">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Friend Requests</h1>
        <p className="text-gray-600">
          {pendingRequests.length === 0 
            ? "No pending friend requests" 
            : `You have ${pendingRequests.length} pending request${pendingRequests.length > 1 ? 's' : ''}`
          }
        </p>
      </div>

      {/* Pending Requests List */}
      <div className="space-y-4">
        {pendingRequests.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Clock className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">No pending friend requests</p>
              <p className="text-sm text-gray-500 mt-2">
                Friend requests will appear here when someone wants to connect with you
              </p>
            </CardContent>
          </Card>
        ) : (
          pendingRequests.map((request) => (
            <Card key={request.id}>
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-3">
                    {/* Avatar */}
                    <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-semibold text-lg">
                      {request.sender?.full_name?.charAt(0) || request.sender?.email?.charAt(0)}
                    </div>
                    
                    {/* Info */}
                    <div>
                      <CardTitle className="text-lg">
                        {request.sender?.full_name || 'Unknown User'}
                        {request.sender?.role === 'professor' && (
                          <span className="ml-2 text-sm font-normal text-blue-600">
                            👨‍🏫 Professor
                          </span>
                        )}
                      </CardTitle>
                      <CardDescription>
                        {request.sender?.course_level || 'No course specified'}
                      </CardDescription>
                      <p className="text-xs text-gray-500 mt-1">
                        Sent {new Date(request.created_at).toLocaleDateString()}
                      </p>
                    </div>
                  </div>

                  {/* Action Buttons */}
                  <div className="flex gap-2">
                    <Button
                      onClick={() => handleAccept(request.id)}
                      disabled={loading}
                      size="sm"
                      variant="default"
                    >
                      <UserCheck className="h-4 w-4 mr-2" />
                      Accept
                    </Button>
                    <Button
                      onClick={() => handleReject(request.id)}
                      disabled={loading}
                      size="sm"
                      variant="outline"
                    >
                      <UserX className="h-4 w-4 mr-2" />
                      Decline
                    </Button>
                  </div>
                </div>
              </CardHeader>
            </Card>
          ))
        )}
      </div>
   </PageContainer>
  );
}