import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Search, Users, UserMinus, Flame, BookOpen, Clock } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';

function formatStudyTime(seconds) {
  if (seconds < 60) return '< 1m';
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

export default function MyFriends() {
  const { user } = useAuth();
  const { toast } = useToast();

  const [searchTerm, setSearchTerm] = useState('');
  const [friends, setFriends] = useState([]);
  const [loadingFriends, setLoadingFriends] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [userCourseLevel, setUserCourseLevel] = useState(null);

  useEffect(() => {
    fetchFriends();
    fetchUserCourseLevel();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const fetchUserCourseLevel = async () => {
    try {
      const { data } = await supabase
        .from('profiles')
        .select('course_level')
        .eq('id', user.id)
        .single();
      setUserCourseLevel(data?.course_level || null);
    } catch {
      // non-critical — empty state falls back to generic copy
    }
  };

  const fetchFriends = async () => {
    setLoadingFriends(true);
    try {
      const { data, error } = await supabase.rpc('get_my_friends_with_stats');
      if (error) throw error;
      setFriends(data || []);
    } catch (error) {
      console.error('Error fetching friends:', error);
    } finally {
      setLoadingFriends(false);
    }
  };

  const handleUnfriend = async (friendshipId, friendName) => {
    if (!confirm(`Remove ${friendName} from your friends?`)) return;

    setSubmitting(true);
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

      fetchFriends();
    } catch (error) {
      console.error('Error removing friend:', error);
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setSubmitting(false);
    }
  };

  const filteredFriends = friends.filter(friend =>
    friend.full_name?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const emptyStateMessage = userCourseLevel
    ? `No friends yet — find people studying ${userCourseLevel} to connect with`
    : 'No friends yet — find people studying your course to connect with';

  return (
    <PageContainer width="full">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">My Friends</h1>
        <p className="text-gray-600">
          {loadingFriends
            ? 'Loading...'
            : friends.length === 0
              ? "You don't have any friends yet"
              : `You have ${friends.length} friend${friends.length > 1 ? 's' : ''}`
          }
        </p>
      </div>

      {/* Search Bar */}
      {!loadingFriends && friends.length > 0 && (
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
        {loadingFriends ? (
          Array.from({ length: 3 }).map((_, i) => (
            <Card key={i}>
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-3">
                    <div className="w-12 h-12 rounded-full bg-gray-200 animate-pulse" />
                    <div className="space-y-2 pt-1">
                      <div className="h-4 w-36 bg-gray-200 rounded animate-pulse" />
                      <div className="h-3 w-24 bg-gray-200 rounded animate-pulse" />
                    </div>
                  </div>
                  <div className="h-8 w-20 bg-gray-200 rounded animate-pulse" />
                </div>
                <div className="mt-3 flex gap-6">
                  <div className="h-3 w-12 bg-gray-200 rounded animate-pulse" />
                  <div className="h-3 w-20 bg-gray-200 rounded animate-pulse" />
                  <div className="h-3 w-16 bg-gray-200 rounded animate-pulse" />
                </div>
              </CardHeader>
            </Card>
          ))
        ) : friends.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Users className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">{emptyStateMessage}</p>
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
            <Card key={friend.user_id}>
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="flex items-start gap-3">
                    {/* Avatar */}
                    <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-semibold text-lg">
                      {friend.full_name?.charAt(0) || '?'}
                    </div>

                    {/* Info */}
                    <div>
                      <CardTitle className="text-lg">
                        <Link
                          to={`/dashboard/profile/${friend.user_id}`}
                          className="hover:text-blue-600 transition-colors"
                        >
                          {friend.full_name || 'Unknown'}
                        </Link>
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
                        Friends since {new Date(friend.friends_since).toLocaleDateString()}
                      </p>
                    </div>
                  </div>

                  {/* Unfriend Button */}
                  <Button
                    onClick={() => handleUnfriend(friend.friendship_id, friend.full_name)}
                    disabled={submitting}
                    size="sm"
                    variant="outline"
                  >
                    <UserMinus className="h-4 w-4 mr-2" />
                    Unfriend
                  </Button>
                </div>

                {/* Stats Row */}
                <div className="mt-3 flex flex-wrap gap-4 text-sm text-gray-600 border-t pt-3">
                  <span className="flex items-center gap-1">
                    <Flame className="h-3.5 w-3.5 text-orange-400" />
                    <span className="font-medium">
                      {friend.streak_days > 0 ? `${friend.streak_days}d` : '—'}
                    </span>
                    <span className="text-gray-400">streak</span>
                  </span>
                  <span className="flex items-center gap-1">
                    <BookOpen className="h-3.5 w-3.5 text-blue-400" />
                    <span className="font-medium">{Number(friend.reviews_this_week)}</span>
                    <span className="text-gray-400">reviews this week</span>
                  </span>
                  <span className="flex items-center gap-1">
                    <Clock className="h-3.5 w-3.5 text-green-400" />
                    <span className="font-medium">
                      {formatStudyTime(Number(friend.study_time_this_week_seconds))}
                    </span>
                    <span className="text-gray-400">study time</span>
                  </span>
                </div>
              </CardHeader>
            </Card>
          ))
        )}
      </div>
    </PageContainer>
  );
}
