import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import PageContainer from '@/components/layout/PageContainer';
import BadgeIcon from '@/components/badges/BadgeIcon';
import {
  ArrowLeft,
  Users,
  UserPlus,
  Clock,
  FileText,
  Brain,
  BookOpen,
  Award,
  ChevronDown,
  ChevronRight,
  Eye,
  EyeOff,
} from 'lucide-react';

export default function AuthorProfile() {
  const { userId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();

  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState(null);
  const [badges, setBadges] = useState([]);
  const [friendshipStatus, setFriendshipStatus] = useState(null);
  const [friendshipData, setFriendshipData] = useState(null);
  const [contentSummary, setContentSummary] = useState([]);
  const [otherCourses, setOtherCourses] = useState([]);
  const [teachingCourses, setTeachingCourses] = useState([]); // array of course name strings
  const [sendingRequest, setSendingRequest] = useState(false);
  const [collapsedCourses, setCollapsedCourses] = useState({});
  const [showPreview, setShowPreview] = useState(false);

  const isOwnProfile = user?.id === userId;

  useEffect(() => {
    if (userId && user?.id) {
      fetchAllData();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId, user?.id]);

  const fetchAllData = async () => {
    setLoading(true);
    try {
      // Call both RPC functions in parallel (2 round-trips instead of 6)
      const [profileResult, contentResult] = await Promise.all([
        supabase.rpc('get_author_profile', {
          p_author_id: userId,
          p_viewer_id: user.id,
        }),
        supabase.rpc('get_author_content_summary', {
          p_author_id: userId,
          p_viewer_id: user.id,
        }),
      ]);

      if (profileResult.error) {
        console.error('Error fetching author profile:', profileResult.error);
        setProfile(null);
        return;
      }

      if (contentResult.error) {
        console.error('Error fetching content summary:', contentResult.error);
      }

      const profileData = profileResult.data;
      const contentData = contentResult.data;

      // Set profile
      setProfile(profileData?.profile || null);

      // Set badges
      setBadges(profileData?.badges || []);

      // Set friendship status
      if (profileData?.friendship) {
        const f = profileData.friendship;
        setFriendshipData(f);

        if (f.status === 'accepted') {
          setFriendshipStatus('accepted');
        } else if (f.status === 'pending') {
          setFriendshipStatus(
            f.user_id === user.id ? 'pending_sent' : 'pending_received'
          );
        } else {
          setFriendshipStatus(f.status);
        }
      } else {
        setFriendshipStatus(null);
        setFriendshipData(null);
      }

      // Set teaching courses (from updated get_author_profile RPC — array of strings)
      setTeachingCourses(profileData?.teaching_courses || []);

      // Set content
      setContentSummary(contentData?.accessible || []);
      setOtherCourses(contentData?.other_courses || []);
    } catch (error) {
      console.error('Error fetching profile data:', error);
    } finally {
      setLoading(false);
    }
  };

  const sendFriendRequest = async () => {
    setSendingRequest(true);
    try {
      const { error } = await supabase.from('friendships').upsert(
        {
          user_id: user.id,
          friend_id: userId,
          status: 'pending',
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id, friend_id' }
      );

      if (error) throw error;

      toast({
        title: 'Friend request sent!',
        description: `Your friend request has been sent to ${profile?.full_name}.`,
      });

      setFriendshipStatus('pending_sent');
    } catch (error) {
      console.error('Error sending friend request:', error);
      toast({
        title: 'Error',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setSendingRequest(false);
    }
  };

  const toggleCourseCollapse = (courseName) => {
    setCollapsedCourses((prev) => ({
      ...prev,
      [courseName]: !prev[courseName],
    }));
  };

  const getRoleBadgeColor = (role) => {
    switch (role) {
      case 'professor':
        return 'bg-purple-100 text-purple-700';
      case 'admin':
        return 'bg-red-100 text-red-700';
      case 'super_admin':
        return 'bg-red-100 text-red-700';
      default:
        return 'bg-blue-100 text-blue-700';
    }
  };

  const getRoleLabel = (role) => {
    switch (role) {
      case 'professor':
        return 'Professor';
      case 'admin':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return 'Student';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!profile) {
    return (
      <PageContainer width="full">
        <div className="text-center py-16">
          <Users className="h-16 w-16 text-gray-400 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-gray-900 mb-2">User not found</h2>
          <p className="text-gray-600 mb-6">This profile doesn't exist or has been removed.</p>
          <Button onClick={() => navigate(-1)}>Go Back</Button>
        </div>
      </PageContainer>
    );
  }

  const totalAccessibleNotes = contentSummary.reduce((sum, c) => sum + (c.totalNotes || 0), 0);
  const totalAccessibleFlashcards = contentSummary.reduce((sum, c) => sum + (c.totalFlashcards || 0), 0);

  // Only render public badges on the Author page — private badges are managed on My Achievements
  const publicBadges = badges.filter(b => b.is_public !== false);

  return (
    <PageContainer width="full">
      {/* Back button */}
      <Button
        variant="ghost"
        onClick={() => {
          if (window.history.length > 1) {
            navigate(-1);
          } else {
            navigate('/dashboard');
          }
        }}
        className="mb-6 gap-2"
      >
        <ArrowLeft className="h-4 w-4" />
        Back
      </Button>

      {/* Profile Header Card */}
      <Card className="mb-6">
        <CardContent className="pt-6">
          <div className="flex flex-col sm:flex-row items-start gap-4">
            {/* Avatar */}
            <div className="w-16 h-16 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold text-2xl flex-shrink-0">
              {profile.full_name?.charAt(0) || '?'}
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-3 flex-wrap">
                <h1 className="text-2xl font-bold text-gray-900">
                  {profile.full_name || 'Unknown User'}
                </h1>
                <span
                  className={`px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleBadgeColor(
                    profile.role
                  )}`}
                >
                  {getRoleLabel(profile.role)}
                </span>
                {isOwnProfile && (
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
                    You
                  </span>
                )}
              </div>

              {profile.institution && (
                <p className="text-gray-600 mt-1">{profile.institution}</p>
              )}

              {/* Teaching courses for professors/admins; course_level for students */}
              {teachingCourses.length > 0 ? (
                <div className="flex flex-wrap gap-1.5 mt-2">
                  {teachingCourses.map((courseName) => (
                    <span
                      key={courseName}
                      className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-50 text-indigo-700 border border-indigo-200"
                    >
                      {courseName}
                    </span>
                  ))}
                </div>
              ) : profile.course_level ? (
                <p className="text-sm text-gray-500 mt-0.5">{profile.course_level}</p>
              ) : null}

              {/* Badges — only public badges shown here; manage privacy in My Achievements */}
              {publicBadges.length > 0 && (
                <div className="flex items-center gap-2 mt-3 flex-wrap">
                  <Award className="h-4 w-4 text-yellow-500" />
                  {publicBadges.map((badge) => (
                    <div
                      key={badge.id}
                      className="flex items-center gap-1.5 px-2.5 py-1 bg-yellow-50 border border-yellow-200 rounded-full"
                      title={badge.badge_description}
                    >
                      <BadgeIcon
                        iconKey={badge.badge_icon_key}
                        size="xs"
                        unlocked={true}
                        showBackground={false}
                      />
                      <span className="text-xs font-medium text-yellow-800">
                        {badge.badge_name}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Action Buttons */}
            <div className="flex-shrink-0">
              {!isOwnProfile && (
                <>
                  {!friendshipStatus && (
                    <Button onClick={sendFriendRequest} disabled={sendingRequest} size="sm">
                      <UserPlus className="h-4 w-4 mr-2" />
                      Add Friend
                    </Button>
                  )}
                  {friendshipStatus === 'pending_sent' && (
                    <Button variant="outline" size="sm" disabled>
                      <Clock className="h-4 w-4 mr-2" />
                      Request Sent
                    </Button>
                  )}
                  {friendshipStatus === 'pending_received' && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => navigate('/dashboard/friend-requests')}
                    >
                      <Clock className="h-4 w-4 mr-2" />
                      Respond to Request
                    </Button>
                  )}
                  {friendshipStatus === 'accepted' && (
                    <Button variant="outline" size="sm" disabled>
                      <Users className="h-4 w-4 mr-2" />
                      Friends
                    </Button>
                  )}
                  {friendshipStatus === 'rejected' && (
                    <Button onClick={sendFriendRequest} disabled={sendingRequest} size="sm">
                      <UserPlus className="h-4 w-4 mr-2" />
                      Add Friend
                    </Button>
                  )}
                </>
              )}
              {isOwnProfile && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowPreview(!showPreview)}
                >
                  {showPreview ? (
                    <>
                      <EyeOff className="h-4 w-4 mr-2" />
                      Exit Preview
                    </>
                  ) : (
                    <>
                      <Eye className="h-4 w-4 mr-2" />
                      Preview as Visitor
                    </>
                  )}
                </Button>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Content Summary */}
      {contentSummary.length > 0 && (
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <BookOpen className="h-5 w-5 text-blue-600" />
              {isOwnProfile && !showPreview
                ? 'Your Content'
                : 'Contributions You Can Access'}
            </CardTitle>
            <p className="text-sm text-gray-500 mt-1">
              {totalAccessibleNotes} notes, {totalAccessibleFlashcards} flashcards
            </p>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {contentSummary.map((course) => {
                const isCollapsed = collapsedCourses[course.name];

                return (
                  <div key={course.name} className="border border-gray-200 rounded-lg overflow-hidden">
                    {/* Course Header */}
                    <button
                      onClick={() => toggleCourseCollapse(course.name)}
                      className="w-full flex items-center justify-between p-3 bg-gray-50 hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex items-center gap-2">
                        {isCollapsed ? (
                          <ChevronRight className="h-4 w-4 text-gray-500" />
                        ) : (
                          <ChevronDown className="h-4 w-4 text-gray-500" />
                        )}
                        <span className="font-medium text-gray-900">{course.name}</span>
                      </div>
                      <span className="text-sm text-gray-500">
                        {course.totalNotes} notes, {course.totalFlashcards} flashcards
                      </span>
                    </button>

                    {/* Subjects */}
                    {!isCollapsed && (
                      <div className="p-3 space-y-2">
                        {course.subjects.map((subject) => (
                          <div
                            key={subject.name}
                            className="flex items-center justify-between py-2 px-3 bg-white border border-gray-100 rounded"
                          >
                            <span className="text-gray-700">{subject.name}</span>
                            <div className="flex items-center gap-4 text-sm text-gray-500">
                              {subject.notes > 0 && (
                                <Link
                                  to={`/dashboard/notes?author=${userId}&subject=${encodeURIComponent(subject.name)}`}
                                  className="flex items-center gap-1 hover:text-blue-600 transition-colors"
                                >
                                  <FileText className="h-3.5 w-3.5" />
                                  {subject.notes} notes
                                </Link>
                              )}
                              {subject.flashcards > 0 && (
                                <Link
                                  to={`/dashboard/review-flashcards?author=${userId}&subject=${encodeURIComponent(subject.name)}`}
                                  className="flex items-center gap-1 hover:text-blue-600 transition-colors"
                                >
                                  <Brain className="h-3.5 w-3.5" />
                                  {subject.flashcards} flashcards
                                </Link>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Empty state for no accessible content */}
      {contentSummary.length === 0 && !loading && (
        <Card className="mb-6">
          <CardContent className="py-8 text-center">
            <BookOpen className="h-12 w-12 text-gray-400 mx-auto mb-3" />
            <h3 className="text-lg font-semibold text-gray-900 mb-1">No accessible content</h3>
            <p className="text-gray-600 text-sm">
              {isOwnProfile
                ? "You haven't created any content yet."
                : friendshipStatus === 'accepted'
                ? "This user hasn't shared any content yet."
                : 'Add as a friend to see their friends-only content.'}
            </p>
          </CardContent>
        </Card>
      )}

      {/* Also Creates Content For (upsell) */}
      {!isOwnProfile && otherCourses.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <BookOpen className="h-5 w-5 text-gray-500" />
              Also Creates Content For
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-3">
              {otherCourses.map((course) => (
                <div
                  key={course.name}
                  className="flex items-center gap-2 px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg"
                >
                  <span className="font-medium text-gray-700">{course.name}</span>
                  <span className="text-xs text-gray-400">
                    ({course.totalNotes} notes, {course.totalFlashcards} flashcards)
                  </span>
                </div>
              ))}
            </div>
            <p className="text-sm text-gray-500 mt-3">
              Enroll in these courses to access this content.
            </p>
          </CardContent>
        </Card>
      )}
    </PageContainer>
  );
}
