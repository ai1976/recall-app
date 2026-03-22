import { useState, useEffect } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  ArrowLeft,
  Users,
  Crown,
  UserPlus,
  Search,
  FileText,
  CreditCard,
  Trash2,
  LogOut,
  X,
  Share2,
  Clock,
  Link2,
  MessageCircle,
  Shield,
  ChevronUp,
  ChevronDown,
  RefreshCw,
} from 'lucide-react';

export default function GroupDetail() {
  const { groupId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();

  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [pendingInvitations, setPendingInvitations] = useState([]);
  const [sharedContent, setSharedContent] = useState({ notes: [], decks: [] });
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);

  // Invite state
  const [inviteOpen, setInviteOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [inviting, setInviting] = useState(false);

  // Share content state
  const [shareOpen, setShareOpen] = useState(false);
  const [userNotes, setUserNotes] = useState([]);
  const [userDecks, setUserDecks] = useState([]);
  const [loadingUserContent, setLoadingUserContent] = useState(false);
  const [sharingContent, setSharingContent] = useState(false);

  // Remove member state
  const [removeDialog, setRemoveDialog] = useState({ open: false, member: null });
  const [actionLoading, setActionLoading] = useState(false);

  // Cancel invite loading
  const [cancellingInviteId, setCancellingInviteId] = useState(null);

  // Viewer role — fetched in parallel with group data
  const [role, setRole] = useState('');

  // Batch Performance state
  const [batchStats, setBatchStats] = useState([]);
  const [batchStatsLoading, setBatchStatsLoading] = useState(false);
  const [batchStatsError, setBatchStatsError] = useState(false);
  const [sortField, setSortField] = useState('reviews_this_week');
  const [sortDir, setSortDir] = useState('desc');

  useEffect(() => {
    fetchGroupData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId]);

  const fetchBatchStats = async () => {
    setBatchStatsLoading(true);
    setBatchStatsError(false);
    try {
      const { data, error } = await supabase.rpc('get_batch_group_member_stats', {
        p_group_id: groupId,
      });
      if (error) throw error;
      setBatchStats(data || []);
    } catch (error) {
      console.error('Error fetching batch stats:', error);
      setBatchStatsError(true);
    } finally {
      setBatchStatsLoading(false);
    }
  };

  const fetchGroupData = async () => {
    setLoading(true);
    try {
      // Fetch group detail and viewer role in parallel
      const [groupResult, profileResult] = await Promise.all([
        supabase.rpc('get_group_detail', { p_group_id: groupId }),
        supabase.from('profiles').select('role').eq('id', user.id).single(),
      ]);
      if (groupResult.error) throw groupResult.error;

      const { data } = groupResult;
      const viewerRole = profileResult.data?.role || 'student';
      setRole(viewerRole);

      // Group info
      setGroup(data.group);

      // Members with profile shape the rest of the component expects
      // NOTE: email is intentionally NOT returned by get_group_detail (privacy)
      const membersWithProfiles = (data.members || []).map(m => ({
        ...m,
        profile: {
          full_name: m.full_name,
          role: m.user_role,
        },
      }));
      setMembers(membersWithProfiles);

      // Pending invitations (from get_group_detail_v2)
      setPendingInvitations(data.pending_invitations || []);

      // Check if current user is admin
      const currentUserMember = data.members?.find(m => m.user_id === user.id);
      setIsAdmin(currentUserMember?.role === 'admin');

      // Shared content
      setSharedContent(data.shared_content || { notes: [], decks: [] });

      // If this is a batch group and the viewer is professor/admin, load stats
      if (data.group?.is_batch_group && ['professor', 'admin', 'super_admin'].includes(viewerRole)) {
        fetchBatchStats();
      }
    } catch (error) {
      console.error('Error fetching group data:', error);
      toast({
        title: 'Error',
        description: 'Failed to load group. You may not have access.',
        variant: 'destructive',
      });
      navigate('/dashboard/groups');
    } finally {
      setLoading(false);
    }
  };

  // Batch Performance helpers
  const formatStudyTime = (seconds) => {
    if (!seconds || seconds < 60) return '< 1m';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (h === 0) return `${m}m`;
    return `${h}h ${m}m`;
  };

  const formatLastActive = (dateStr) => {
    if (!dateStr) return '—';
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const date = new Date(dateStr);
    date.setHours(0, 0, 0, 0);
    const diffDays = Math.round((today - date) / (1000 * 60 * 60 * 24));
    if (diffDays === 0) return 'Today';
    if (diffDays <= 6) return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
  };

  const handleSort = (field) => {
    if (sortField === field) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDir('desc');
    }
  };

  // Search users for invite
  const searchUsers = async (query) => {
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .or(`full_name.ilike.%${query}%,email.ilike.%${query}%`)
        .limit(10);
      if (error) throw error;

      // Filter out existing active members AND pending invitations
      const memberIds = members.map(m => m.user_id);
      const pendingIds = pendingInvitations.map(p => p.user_id);
      const excludeIds = new Set([...memberIds, ...pendingIds]);
      const filtered = (data || []).filter(u => !excludeIds.has(u.id));
      setSearchResults(filtered);
    } catch (error) {
      console.error('Error searching users:', error);
    } finally {
      setSearching(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery.trim()) {
        searchUsers(searchQuery.trim());
      } else {
        setSearchResults([]);
      }
    }, 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQuery]);

  const handleInvite = async (userId) => {
    setInviting(true);
    try {
      const { error } = await supabase.rpc('invite_to_group', {
        p_group_id: groupId,
        p_user_id: userId,
      });
      if (error) throw error;
      toast({ title: 'Invitation sent!' });
      setSearchQuery('');
      setSearchResults([]);
      fetchGroupData();
    } catch (error) {
      console.error('Error inviting user:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to send invitation',
        variant: 'destructive',
      });
    } finally {
      setInviting(false);
    }
  };

  const handleCancelInvite = async (membershipId) => {
    setCancellingInviteId(membershipId);
    try {
      // Admin cancels a pending invitation by deleting the membership row
      const { error } = await supabase
        .from('study_group_members')
        .delete()
        .eq('id', membershipId)
        .eq('status', 'invited');
      if (error) throw error;
      toast({ title: 'Invitation cancelled' });
      fetchGroupData();
    } catch (error) {
      console.error('Error cancelling invite:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to cancel invitation',
        variant: 'destructive',
      });
    } finally {
      setCancellingInviteId(null);
    }
  };

  const handleRemoveMember = async () => {
    if (!removeDialog.member) return;
    setActionLoading(true);
    try {
      const { error } = await supabase.rpc('remove_group_member', {
        p_group_id: groupId,
        p_user_id: removeDialog.member.user_id,
      });
      if (error) throw error;
      toast({ title: 'Member removed' });
      setRemoveDialog({ open: false, member: null });
      fetchGroupData();
    } catch (error) {
      console.error('Error removing member:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to remove member',
        variant: 'destructive',
      });
    } finally {
      setActionLoading(false);
    }
  };

  // Fetch user's own content for sharing
  const fetchUserContent = async () => {
    setLoadingUserContent(true);
    try {
      // Get user's notes
      const { data: notes } = await supabase
        .from('notes')
        .select('id, title, target_course')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      // Get user's flashcard decks
      const { data: decks } = await supabase
        .from('flashcard_decks')
        .select('id, target_course, card_count, subject_id, topic_id, custom_subject, custom_topic')
        .eq('user_id', user.id)
        .gt('card_count', 0)
        .order('created_at', { ascending: false });

      // Fetch subject/topic names for decks
      const subjectIds = [...new Set(decks?.map(d => d.subject_id).filter(Boolean) || [])];
      const topicIds = [...new Set(decks?.map(d => d.topic_id).filter(Boolean) || [])];
      let subjectsMap = {};
      let topicsMap = {};
      if (subjectIds.length > 0) {
        const { data: subjects } = await supabase
          .from('subjects')
          .select('id, name')
          .in('id', subjectIds);
        subjects?.forEach(s => { subjectsMap[s.id] = s.name; });
      }
      if (topicIds.length > 0) {
        const { data: topics } = await supabase
          .from('topics')
          .select('id, name')
          .in('id', topicIds);
        topics?.forEach(t => { topicsMap[t.id] = t.name; });
      }

      setUserNotes(notes || []);
      setUserDecks(
        (decks || []).map(d => ({
          ...d,
          display_name: d.custom_subject || subjectsMap[d.subject_id] || 'Study Set',
          display_topic: d.custom_topic || topicsMap[d.topic_id] || '',
        }))
      );
    } catch (error) {
      console.error('Error fetching user content:', error);
    } finally {
      setLoadingUserContent(false);
    }
  };

  const handleShareContent = async (contentType, contentId) => {
    setSharingContent(true);
    try {
      const { error } = await supabase.rpc('share_content_with_groups', {
        p_content_type: contentType,
        p_content_id: contentId,
        p_group_ids: [groupId],
      });
      if (error) throw error;
      toast({ title: 'Content shared!' });
      fetchGroupData();
    } catch (error) {
      console.error('Error sharing content:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to share content',
        variant: 'destructive',
      });
    } finally {
      setSharingContent(false);
    }
  };

  const handleUnshare = async (shareType, contentId) => {
    try {
      const { error } = await supabase
        .from('content_group_shares')
        .delete()
        .eq('group_id', groupId)
        .eq('content_type', shareType)
        .eq('content_id', contentId);
      if (error) throw error;
      toast({ title: 'Content unshared' });
      fetchGroupData();
    } catch (error) {
      console.error('Error unsharing:', error);
      toast({
        title: 'Error',
        description: 'Failed to unshare content',
        variant: 'destructive',
      });
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!group) return null;

  // Safety guard: student navigating directly to a batch group URL
  if (group.is_batch_group && role === 'student') {
    navigate('/dashboard/groups');
    return null;
  }

  // Batch Performance view for professors/admins
  if (group.is_batch_group && ['professor', 'admin', 'super_admin'].includes(role)) {
    const SortHeader = ({ field, label }) => (
      <th
        className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-900 select-none whitespace-nowrap"
        onClick={() => handleSort(field)}
      >
        <span className="flex items-center gap-1">
          {label}
          {sortField === field ? (
            sortDir === 'asc'
              ? <ChevronUp className="h-3 w-3" />
              : <ChevronDown className="h-3 w-3" />
          ) : (
            <ChevronUp className="h-3 w-3 text-gray-300" />
          )}
        </span>
      </th>
    );

    const sortedStats = [...batchStats].sort((a, b) => {
      if (sortField === 'full_name') {
        const aVal = a.full_name || '';
        const bVal = b.full_name || '';
        return sortDir === 'asc' ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
      }
      if (sortField === 'last_active_date') {
        if (!a.last_active_date && !b.last_active_date) return 0;
        if (!a.last_active_date) return sortDir === 'asc' ? -1 : 1;
        if (!b.last_active_date) return sortDir === 'asc' ? 1 : -1;
        const diff = new Date(a.last_active_date) - new Date(b.last_active_date);
        return sortDir === 'asc' ? diff : -diff;
      }
      const aVal = Number(a[sortField] ?? 0);
      const bVal = Number(b[sortField] ?? 0);
      return sortDir === 'asc' ? aVal - bVal : bVal - aVal;
    });

    return (
      <PageContainer width="full">
        <Button variant="ghost" onClick={() => navigate('/dashboard/groups')} className="mb-6">
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Groups
        </Button>

        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-1">
            <h1 className="text-3xl font-bold text-gray-900">{group.name}</h1>
            <span className="flex items-center gap-1 px-2.5 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
              <Shield className="h-3.5 w-3.5" />
              Batch Performance
            </span>
          </div>
          <p className="text-gray-600">
            {members.length} {members.length === 1 ? 'student' : 'students'}
          </p>
        </div>

        {/* Stats Table */}
        <Card>
          <CardContent className="p-0">
            {batchStatsLoading ? (
              <div className="p-6 space-y-4">
                {[...Array(6)].map((_, i) => (
                  <div key={i} className="flex gap-4 animate-pulse">
                    <div className="h-4 bg-gray-200 rounded w-40" />
                    <div className="h-4 bg-gray-200 rounded w-24" />
                    <div className="h-4 bg-gray-200 rounded w-16" />
                    <div className="h-4 bg-gray-200 rounded w-28" />
                    <div className="h-4 bg-gray-200 rounded w-20" />
                  </div>
                ))}
              </div>
            ) : batchStatsError ? (
              <div className="py-16 text-center">
                <p className="text-gray-600 mb-4">Could not load batch stats</p>
                <Button variant="outline" onClick={fetchBatchStats}>
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Retry
                </Button>
              </div>
            ) : batchStats.length === 0 ? (
              <div className="py-16 text-center">
                <p className="text-gray-500">No activity recorded yet for this batch</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b bg-gray-50">
                      <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider w-10">#</th>
                      <SortHeader field="full_name" label="Name" />
                      <SortHeader field="reviews_this_week" label="Reviews This Week" />
                      <SortHeader field="streak_days" label="Streak" />
                      <SortHeader field="study_time_this_week_seconds" label="Study Time This Week" />
                      <SortHeader field="last_active_date" label="Last Active" />
                    </tr>
                  </thead>
                  <tbody>
                    {sortedStats.map((row, idx) => (
                      <tr key={row.user_id} className="border-b last:border-0 hover:bg-gray-50">
                        <td className="px-4 py-3 text-sm text-gray-400 font-medium">{idx + 1}</td>
                        <td className="px-4 py-3 font-medium text-gray-900">{row.full_name || '—'}</td>
                        <td className="px-4 py-3 text-gray-700">{Number(row.reviews_this_week)}</td>
                        <td className="px-4 py-3 text-gray-700">
                          {Number(row.streak_days) > 0 ? `${row.streak_days}d` : '—'}
                        </td>
                        <td className="px-4 py-3 text-gray-700">
                          {formatStudyTime(Number(row.study_time_this_week_seconds))}
                        </td>
                        <td className="px-4 py-3 text-gray-500">
                          {formatLastActive(row.last_active_date)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </PageContainer>
    );
  }

  // Determine which shared content IDs already exist to avoid duplicate share buttons
  const sharedNoteIds = new Set(sharedContent.notes.map(n => n.id));
  const sharedDeckIds = new Set(sharedContent.decks.map(d => d.id));

  return (
    <PageContainer width="full">
      <Button variant="ghost" onClick={() => navigate('/dashboard/groups')} className="mb-6">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back to Groups
      </Button>

      {/* Group Header */}
      <div className="mb-8">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">{group.name}</h1>
            {group.description && (
              <p className="text-gray-600 mt-2">{group.description}</p>
            )}
          </div>
          <div className="flex gap-2">
              <Button
                variant="outline"
                onClick={() => {
                  setShareOpen(true);
                  fetchUserContent();
                }}
              >
                <Share2 className="h-4 w-4 mr-2" />
                Share Content
              </Button>
              {isAdmin && (
                <Button onClick={() => setInviteOpen(true)}>
                  <UserPlus className="h-4 w-4 mr-2" />
                  Invite Members
                </Button>
              )}
            </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Members Panel */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              Members ({members.length})
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {members.map((member) => (
                <div key={member.id} className="flex items-center justify-between">
                  <div className="flex items-center gap-2 min-w-0">
                    <div className="h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center text-white text-sm font-bold shrink-0">
                      {member.profile.full_name?.charAt(0)?.toUpperCase() || '?'}
                    </div>
                    <div className="min-w-0">
                      <Link
                        to={`/dashboard/profile/${member.user_id}`}
                        className="text-sm font-medium text-gray-900 hover:text-blue-600 truncate block"
                      >
                        {member.profile.full_name || 'Unknown User'}
                        {member.user_id === user.id && ' (You)'}
                      </Link>
                      {member.role === 'admin' && (
                        <span className="flex items-center gap-1 text-xs text-amber-700">
                          <Crown className="h-3 w-3" />
                          Admin
                        </span>
                      )}
                    </div>
                  </div>
                  {isAdmin && member.user_id !== user.id && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-red-500 hover:text-red-700 shrink-0"
                      onClick={() => setRemoveDialog({ open: true, member })}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              ))}
            </div>

            {/* Pending Invitations in Members Panel (admin only) */}
            {isAdmin && pendingInvitations.length > 0 && (
              <div className="mt-4 pt-4 border-t">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1">
                  <Clock className="h-3 w-3" />
                  Pending ({pendingInvitations.length})
                </p>
                <div className="space-y-3">
                  {pendingInvitations.map((invite) => (
                    <div key={invite.membership_id} className="flex items-center justify-between">
                      <div className="flex items-center gap-2 min-w-0">
                        <div className="h-8 w-8 rounded-full bg-gray-300 flex items-center justify-center text-gray-600 text-sm font-bold shrink-0">
                          {invite.full_name?.charAt(0)?.toUpperCase() || '?'}
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-medium text-gray-600 truncate">
                            {invite.full_name || 'Unknown User'}
                          </p>
                          <span className="text-xs text-amber-600 font-medium">Invited</span>
                        </div>
                      </div>
                      <Button
                        variant="ghost"
                        size="sm"
                        className="text-red-500 hover:text-red-700 shrink-0"
                        onClick={() => handleCancelInvite(invite.membership_id)}
                        disabled={cancellingInviteId === invite.membership_id}
                      >
                        <X className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              </div>
            )}
            {/* Invite via Link (self-selected groups only) */}
            {!group.is_batch_group && isAdmin && (
              <div className="mt-4 pt-4 border-t">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3 flex items-center gap-1">
                  <Link2 className="h-3 w-3" />
                  Invite via Link
                </p>
                <div className="flex gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    className="flex-1"
                    onClick={() => {
                      const link = `${window.location.origin}/join/${group.invite_token}`;
                      navigator.clipboard.writeText(link).then(() => {
                        toast({ title: 'Link copied!', description: 'Share it with anyone you want to invite.' });
                      });
                    }}
                  >
                    <Link2 className="h-3.5 w-3.5 mr-1" />
                    Copy Link
                  </Button>
                  <Button
                    size="sm"
                    className="flex-1 bg-green-600 hover:bg-green-700 text-white"
                    onClick={() => {
                      const link = `${window.location.origin}/join/${group.invite_token}`;
                      const text = `Join our study group "${group.name}" on Recall: ${link}`;
                      if (navigator.share) {
                        navigator.share({ title: group.name, text, url: link }).catch(() => {});
                      } else {
                        window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank');
                      }
                    }}
                  >
                    <MessageCircle className="h-3.5 w-3.5 mr-1" />
                    WhatsApp
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Shared Content Panel */}
        <div className="lg:col-span-2 space-y-6">
          {/* Shared Notes */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <FileText className="h-5 w-5" />
                Shared Notes ({sharedContent.notes.length})
              </CardTitle>
            </CardHeader>
            <CardContent>
              {sharedContent.notes.length === 0 ? (
                <p className="text-sm text-gray-500 text-center py-4">
                  No notes shared with this group yet
                </p>
              ) : (
                <div className="space-y-3">
                  {sharedContent.notes.map((note) => (
                    <div
                      key={note.id}
                      className="flex items-center justify-between p-3 border rounded-lg hover:border-blue-300 transition-colors"
                    >
                      <div
                        className="min-w-0 flex-1 cursor-pointer"
                        onClick={() => navigate(`/dashboard/notes/${note.id}`)}
                      >
                        <p className="font-medium text-gray-900 truncate hover:text-blue-600">
                          {note.title || 'Untitled Note'}
                        </p>
                        <p className="text-xs text-gray-500">
                          {note.subject_name && `${note.subject_name} - `}
                          by{' '}
                          <Link
                            to={`/dashboard/profile/${note.author_id}`}
                            className="hover:text-blue-600"
                            onClick={(e) => e.stopPropagation()}
                          >
                            {note.author_name}
                          </Link>
                          {' - '}
                          Shared {formatDate(note.shared_at)}
                        </p>
                      </div>
                      {(isAdmin || note.author_id === user.id) && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-red-500 hover:text-red-700 shrink-0 ml-2"
                          onClick={() => handleUnshare('note', note.id)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Shared Study Sets */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CreditCard className="h-5 w-5" />
                Shared Study Sets ({sharedContent.decks.length})
              </CardTitle>
            </CardHeader>
            <CardContent>
              {sharedContent.decks.length === 0 ? (
                <p className="text-sm text-gray-500 text-center py-4">
                  No study sets shared with this group yet
                </p>
              ) : (
                <div className="space-y-3">
                  {sharedContent.decks.map((deck) => (
                    <div
                      key={deck.id}
                      className="flex items-center justify-between p-3 border rounded-lg hover:border-blue-300 transition-colors"
                    >
                      <div className="min-w-0 flex-1">
                        <p className="font-medium text-gray-900 truncate">
                          {deck.display_subject} {deck.display_topic ? `- ${deck.display_topic}` : ''}
                        </p>
                        <p className="text-xs text-gray-500">
                          {deck.card_count} cards - by{' '}
                          <Link
                            to={`/dashboard/profile/${deck.author_id}`}
                            className="hover:text-blue-600"
                            onClick={(e) => e.stopPropagation()}
                          >
                            {deck.author_name}
                          </Link>
                          {' - '}
                          Shared {formatDate(deck.shared_at)}
                        </p>
                      </div>
                      {(isAdmin || deck.author_id === user.id) && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-red-500 hover:text-red-700 shrink-0 ml-2"
                          onClick={() => handleUnshare('flashcard_deck', deck.id)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Invite Members Dialog */}
      <Dialog open={inviteOpen} onOpenChange={setInviteOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Invite Members</DialogTitle>
            <DialogDescription>
              Search for users by name or email to invite them to the group. They will receive a notification and can accept or decline.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search by name or email..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
            <div className="max-h-64 overflow-y-auto space-y-2">
              {searching && (
                <p className="text-sm text-gray-500 text-center py-2">Searching...</p>
              )}
              {!searching && searchQuery.length >= 2 && searchResults.length === 0 && (
                <p className="text-sm text-gray-500 text-center py-2">No users found</p>
              )}
              {searchResults.map((result) => (
                <div
                  key={result.id}
                  className="flex items-center justify-between p-2 border rounded-lg"
                >
                  <div>
                    <p className="text-sm font-medium">{result.full_name || 'Unknown'}</p>
                    <p className="text-xs text-gray-500">{result.email}</p>
                  </div>
                  <Button
                    size="sm"
                    onClick={() => handleInvite(result.id)}
                    disabled={inviting}
                  >
                    <UserPlus className="h-4 w-4 mr-1" />
                    Invite
                  </Button>
                </div>
              ))}
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Share Content Dialog */}
      <Dialog open={shareOpen} onOpenChange={setShareOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Share Content with Group</DialogTitle>
            <DialogDescription>
              Select notes or study sets to share with &quot;{group.name}&quot;. Members can view but NOT edit.
            </DialogDescription>
          </DialogHeader>
          {loadingUserContent ? (
            <div className="py-8 text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
            </div>
          ) : (
            <div className="space-y-4 max-h-96 overflow-y-auto">
              {/* Notes Section */}
              {userNotes.length > 0 && (
                <div>
                  <h4 className="text-sm font-semibold text-gray-700 mb-2 flex items-center gap-2">
                    <FileText className="h-4 w-4" />
                    Your Notes
                  </h4>
                  <div className="space-y-2">
                    {userNotes.map((note) => {
                      const alreadyShared = sharedNoteIds.has(note.id);
                      return (
                        <div
                          key={note.id}
                          className="flex items-center justify-between p-2 border rounded-lg"
                        >
                          <div className="min-w-0 flex-1">
                            <p className="text-sm font-medium truncate">{note.title || 'Untitled'}</p>
                            <p className="text-xs text-gray-500">{note.target_course}</p>
                          </div>
                          {alreadyShared ? (
                            <span className="text-xs text-green-600 font-medium px-2">Shared</span>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleShareContent('note', note.id)}
                              disabled={sharingContent}
                            >
                              Share
                            </Button>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Decks Section */}
              {userDecks.length > 0 && (
                <div>
                  <h4 className="text-sm font-semibold text-gray-700 mb-2 flex items-center gap-2">
                    <CreditCard className="h-4 w-4" />
                    Your Study Sets
                  </h4>
                  <div className="space-y-2">
                    {userDecks.map((deck) => {
                      const alreadyShared = sharedDeckIds.has(deck.id);
                      return (
                        <div
                          key={deck.id}
                          className="flex items-center justify-between p-2 border rounded-lg"
                        >
                          <div className="min-w-0 flex-1">
                            <p className="text-sm font-medium truncate">
                              {deck.display_name}{deck.display_topic ? ` - ${deck.display_topic}` : ''}
                            </p>
                            <p className="text-xs text-gray-500">
                              {deck.card_count} cards - {deck.target_course}
                            </p>
                          </div>
                          {alreadyShared ? (
                            <span className="text-xs text-green-600 font-medium px-2">Shared</span>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleShareContent('flashcard_deck', deck.id)}
                              disabled={sharingContent}
                            >
                              Share
                            </Button>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {userNotes.length === 0 && userDecks.length === 0 && (
                <p className="text-sm text-gray-500 text-center py-4">
                  You don&apos;t have any content to share yet. Create notes or flashcards first.
                </p>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* Remove Member Dialog */}
      <Dialog
        open={removeDialog.open}
        onOpenChange={(open) => !open && setRemoveDialog({ open: false, member: null })}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Remove Member</DialogTitle>
            <DialogDescription>
              Are you sure you want to remove {removeDialog.member?.profile?.full_name || 'this member'} from the group?
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRemoveDialog({ open: false, member: null })}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleRemoveMember} disabled={actionLoading}>
              {actionLoading ? 'Removing...' : 'Remove'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageContainer>
  );
}
