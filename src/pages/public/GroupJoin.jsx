import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Users, TrendingUp, Zap, Award, LogIn } from 'lucide-react';

export default function GroupJoin() {
  const { token } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [preview, setPreview] = useState(null); // { group, stats }
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [joining, setJoining] = useState(false);
  const [joined, setJoined] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const { data, error } = await supabase.rpc('get_group_preview', { p_token: token });
        if (error) throw error;
        if (!data || !data.group) {
          setNotFound(true);
        } else {
          setPreview(data);
        }
      } catch (err) {
        console.error('GroupJoin load:', err);
        setNotFound(true);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [token]);

  async function handleJoin() {
    if (!user) {
      localStorage.setItem('postAuthRedirect', `/join/${token}`);
      navigate('/login');
      return;
    }
    setJoining(true);
    try {
      const { data: groupId, error } = await supabase.rpc('join_group_by_token', { p_token: token });
      if (error) throw error;
      setJoined(true);
      setTimeout(() => navigate(`/dashboard/groups/${groupId}`), 1500);
    } catch (err) {
      console.error('handleJoin:', err);
      alert(err.message || 'Failed to join group');
    } finally {
      setJoining(false);
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
      </div>
    );
  }

  if (notFound) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
        <div className="text-center max-w-md">
          <Users className="h-16 w-16 text-gray-300 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Link not found</h1>
          <p className="text-gray-500 mb-6">
            This invite link is invalid or the group no longer exists.
          </p>
          <Link to="/">
            <Button variant="outline">Go to Recall</Button>
          </Link>
        </div>
      </div>
    );
  }

  const { group, stats } = preview;

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-md">
        {/* Logo / Brand */}
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold text-indigo-700">Recall</h2>
          <p className="text-sm text-gray-500 mt-1">Spaced repetition, done together</p>
        </div>

        <Card className="shadow-lg">
          <CardContent className="pt-8 pb-8 px-8">
            <div className="text-center mb-6">
              <div className="h-16 w-16 rounded-full bg-indigo-100 flex items-center justify-center mx-auto mb-4">
                <Users className="h-8 w-8 text-indigo-600" />
              </div>
              <h1 className="text-xl font-bold text-gray-900">{group.name}</h1>
              {group.description && (
                <p className="text-sm text-gray-500 mt-2">{group.description}</p>
              )}
              <p className="text-sm text-gray-500 mt-2">
                <span className="font-medium text-gray-700">{group.member_count}</span>{' '}
                {group.member_count === 1 ? 'member' : 'members'} studying together
              </p>
            </div>

            {/* Stats */}
            {stats && (
              <div className="grid grid-cols-2 gap-3 mb-6">
                <div className="bg-blue-50 rounded-lg p-3 text-center">
                  <TrendingUp className="h-5 w-5 text-blue-600 mx-auto mb-1" />
                  <p className="text-xs text-gray-500">Weekly Reviews</p>
                  <p className="font-bold text-gray-900">{stats.total_weekly_reviews ?? 0}</p>
                </div>
                <div className="bg-orange-50 rounded-lg p-3 text-center">
                  <Zap className="h-5 w-5 text-orange-500 mx-auto mb-1" />
                  <p className="text-xs text-gray-500">Avg Streak</p>
                  <p className="font-bold text-gray-900">{stats.avg_streak ?? 0} days</p>
                </div>
                {stats.top_badge_name && (
                  <div className="col-span-2 bg-amber-50 rounded-lg p-3 text-center">
                    <Award className="h-5 w-5 text-amber-600 mx-auto mb-1" />
                    <p className="text-xs text-gray-500">Top Badge</p>
                    <p className="font-semibold text-gray-900 text-sm">{stats.top_badge_name}</p>
                  </div>
                )}
              </div>
            )}

            {/* CTA */}
            {joined ? (
              <div className="text-center">
                <p className="text-green-600 font-medium mb-1">Joined! Redirecting...</p>
              </div>
            ) : user ? (
              <Button className="w-full" onClick={handleJoin} disabled={joining}>
                {joining ? 'Joining...' : 'Join Group'}
              </Button>
            ) : (
              <div className="space-y-3">
                <Button
                  className="w-full"
                  onClick={() => {
                    localStorage.setItem('postAuthRedirect', `/join/${token}`);
                    navigate('/signup');
                  }}
                >
                  Sign up free to join
                </Button>
                <p className="text-center text-xs text-gray-400">
                  Already on Recall?{' '}
                  <button
                    className="text-indigo-600 hover:underline inline-flex items-center gap-1"
                    onClick={() => {
                      localStorage.setItem('postAuthRedirect', `/join/${token}`);
                      navigate('/login');
                    }}
                  >
                    <LogIn className="h-3 w-3" />
                    Sign in
                  </button>
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
