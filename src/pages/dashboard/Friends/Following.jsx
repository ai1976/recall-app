import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Flame, BookOpen, Clock, UserMinus, Users2 } from 'lucide-react';
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

export default function Following() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [following, setFollowing] = useState([]);
  const [loading, setLoading] = useState(true);
  const [unfollowing, setUnfollowing] = useState(null);

  useEffect(() => {
    fetchFollowing();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  const fetchFollowing = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_following_with_stats');
      if (error) throw error;
      setFollowing(data || []);
    } catch (error) {
      console.error('Error fetching following:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleUnfollow = async (userId) => {
    setUnfollowing(userId);
    // Optimistic update
    setFollowing(prev => prev.filter(f => f.user_id !== userId));
    try {
      const { error } = await supabase.rpc('unfollow_user', { p_followee_id: userId });
      if (error) throw error;
    } catch (error) {
      console.error('Error unfollowing:', error);
      fetchFollowing();
      toast({
        title: 'Error',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setUnfollowing(null);
    }
  };

  return (
    <PageContainer width="full">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Following</h1>
        <p className="text-gray-600">
          {loading
            ? 'Loading...'
            : following.length === 0
              ? "You're not following anyone"
              : `You're following ${following.length} ${following.length === 1 ? 'person' : 'people'}`
          }
        </p>
      </div>

      <div className="space-y-4">
        {loading ? (
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
        ) : following.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Users2 className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">
                You're not following anyone yet. Visit a student or professor's profile to follow them.
              </p>
            </CardContent>
          </Card>
        ) : (
          following.map((person) => (
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
                      <CardTitle className="text-lg">
                        <Link
                          to={`/dashboard/profile/${person.user_id}`}
                          className="hover:text-blue-600 transition-colors"
                        >
                          {person.full_name || 'Unknown'}
                        </Link>
                        {person.role === 'professor' && (
                          <span className="ml-2 text-sm font-normal text-blue-600">
                            👨‍🏫 Professor
                          </span>
                        )}
                      </CardTitle>
                      <CardDescription>
                        {person.course_level || 'No course specified'}
                      </CardDescription>
                      <p className="text-xs text-gray-500 mt-1">
                        Following since {new Date(person.following_since).toLocaleDateString()}
                      </p>
                    </div>
                  </div>

                  {/* Unfollow Button */}
                  <Button
                    onClick={() => handleUnfollow(person.user_id)}
                    disabled={unfollowing === person.user_id}
                    size="sm"
                    variant="outline"
                  >
                    <UserMinus className="h-4 w-4 mr-2" />
                    Unfollow
                  </Button>
                </div>

                {/* Stats Row — students only; professors/admins don't use review metrics */}
                {person.role === 'student' || !person.role ? (
                  <div className="mt-3 flex flex-wrap gap-4 text-sm text-gray-600 border-t pt-3">
                    <span className="flex items-center gap-1">
                      <Flame className="h-3.5 w-3.5 text-orange-400" />
                      <span className="font-medium">
                        {person.streak_days > 0 ? `${person.streak_days}d` : '—'}
                      </span>
                      <span className="text-gray-400">streak</span>
                    </span>
                    <span className="flex items-center gap-1">
                      <BookOpen className="h-3.5 w-3.5 text-blue-400" />
                      <span className="font-medium">{Number(person.reviews_this_week)}</span>
                      <span className="text-gray-400">reviews this week</span>
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock className="h-3.5 w-3.5 text-green-400" />
                      <span className="font-medium">
                        {formatStudyTime(Number(person.study_time_this_week_seconds))}
                      </span>
                      <span className="text-gray-400">study time</span>
                    </span>
                  </div>
                ) : (
                  <p className="mt-3 text-sm text-gray-400 border-t pt-3">
                    Visit their profile to explore notes and flashcards.
                  </p>
                )}
              </CardHeader>
            </Card>
          ))
        )}
      </div>
    </PageContainer>
  );
}
