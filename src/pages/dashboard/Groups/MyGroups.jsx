import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, Plus, Crown, LogOut, Trash2, Check, X, Mail } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

export default function MyGroups() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [leaveDialog, setLeaveDialog] = useState({ open: false, group: null });
  const [deleteDialog, setDeleteDialog] = useState({ open: false, group: null });
  const [actionLoading, setActionLoading] = useState(false);

  // Pending invitations state
  const [pendingInvites, setPendingInvites] = useState([]);
  const [inviteLoading, setInviteLoading] = useState(true);
  const [inviteActionId, setInviteActionId] = useState(null); // track which invite is being acted on

  useEffect(() => {
    fetchGroups();
    fetchPendingInvites();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchGroups = async () => {
    try {
      const { data, error } = await supabase.rpc('get_user_groups');
      if (error) throw error;
      setGroups(data || []);
    } catch (error) {
      console.error('Error fetching groups:', error);
      toast({
        title: 'Error',
        description: 'Failed to load study groups',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  const fetchPendingInvites = async () => {
    try {
      const { data, error } = await supabase.rpc('get_pending_group_invites');
      if (error) throw error;
      setPendingInvites(data || []);
    } catch (error) {
      console.error('Error fetching pending invites:', error);
    } finally {
      setInviteLoading(false);
    }
  };

  const handleAcceptInvite = async (membershipId) => {
    setInviteActionId(membershipId);
    try {
      const { error } = await supabase.rpc('accept_group_invite', {
        p_membership_id: membershipId,
      });
      if (error) throw error;
      toast({ title: 'Invitation accepted', description: 'You have joined the group!' });
      // Refresh both lists
      fetchGroups();
      fetchPendingInvites();
    } catch (error) {
      console.error('Error accepting invite:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to accept invitation',
        variant: 'destructive',
      });
    } finally {
      setInviteActionId(null);
    }
  };

  const handleDeclineInvite = async (membershipId) => {
    setInviteActionId(membershipId);
    try {
      const { error } = await supabase.rpc('decline_group_invite', {
        p_membership_id: membershipId,
      });
      if (error) throw error;
      toast({ title: 'Invitation declined' });
      fetchPendingInvites();
    } catch (error) {
      console.error('Error declining invite:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to decline invitation',
        variant: 'destructive',
      });
    } finally {
      setInviteActionId(null);
    }
  };

  const handleLeaveGroup = async () => {
    if (!leaveDialog.group) return;
    setActionLoading(true);
    try {
      const { error } = await supabase.rpc('leave_group', {
        p_group_id: leaveDialog.group.id,
      });
      if (error) throw error;
      toast({ title: 'Left group', description: `You left "${leaveDialog.group.name}"` });
      setLeaveDialog({ open: false, group: null });
      fetchGroups();
    } catch (error) {
      console.error('Error leaving group:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to leave group',
        variant: 'destructive',
      });
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteGroup = async () => {
    if (!deleteDialog.group) return;
    setActionLoading(true);
    try {
      const { error } = await supabase
        .from('study_groups')
        .delete()
        .eq('id', deleteDialog.group.id);
      if (error) throw error;
      toast({ title: 'Group deleted', description: `"${deleteDialog.group.name}" has been deleted` });
      setDeleteDialog({ open: false, group: null });
      fetchGroups();
    } catch (error) {
      console.error('Error deleting group:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to delete group',
        variant: 'destructive',
      });
    } finally {
      setActionLoading(false);
    }
  };

  if (loading && inviteLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <PageContainer width="full">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Study Groups</h1>
          <p className="text-gray-600">
            Create and join groups to share notes and flashcards with selected people
          </p>
        </div>
        <Button onClick={() => navigate('/dashboard/groups/new')}>
          <Plus className="h-4 w-4 mr-2" />
          Create Group
        </Button>
      </div>

      {/* Pending Invitations Section */}
      {pendingInvites.length > 0 && (
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <Mail className="h-5 w-5 text-amber-600" />
            Pending Invitations ({pendingInvites.length})
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {pendingInvites.map((invite) => (
              <Card
                key={invite.membership_id}
                className="border-amber-200 bg-amber-50/50"
              >
                <CardHeader className="pb-3">
                  <CardTitle className="text-lg line-clamp-1">{invite.group_name}</CardTitle>
                </CardHeader>
                <CardContent>
                  {invite.group_description && (
                    <p className="text-sm text-gray-600 mb-3 line-clamp-2">
                      {invite.group_description}
                    </p>
                  )}
                  <div className="text-sm text-gray-500 mb-3 space-y-1">
                    <p>
                      Invited by <span className="font-medium text-gray-700">{invite.invited_by_name}</span>
                    </p>
                    <p className="flex items-center gap-1">
                      <Users className="h-4 w-4" />
                      {invite.member_count} {invite.member_count === 1 ? 'member' : 'members'}
                    </p>
                  </div>
                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      className="flex-1"
                      onClick={() => handleAcceptInvite(invite.membership_id)}
                      disabled={inviteActionId === invite.membership_id}
                    >
                      <Check className="h-4 w-4 mr-1" />
                      {inviteActionId === invite.membership_id ? 'Accepting...' : 'Accept'}
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="flex-1"
                      onClick={() => handleDeclineInvite(invite.membership_id)}
                      disabled={inviteActionId === invite.membership_id}
                    >
                      <X className="h-4 w-4 mr-1" />
                      Decline
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {groups.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center">
            <Users className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No study groups yet</h3>
            <p className="text-gray-600 mb-6">
              Create a group to start sharing content with classmates
            </p>
            <Button onClick={() => navigate('/dashboard/groups/new')}>
              <Plus className="h-4 w-4 mr-2" />
              Create Your First Group
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {groups.map((group) => (
            <Card
              key={group.id}
              className="hover:border-blue-300 hover:shadow-md transition-all cursor-pointer"
              onClick={() => navigate(`/dashboard/groups/${group.id}`)}
            >
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <CardTitle className="text-lg line-clamp-1">{group.name}</CardTitle>
                  {group.user_role === 'admin' && (
                    <span className="flex items-center gap-1 px-2 py-0.5 bg-amber-100 text-amber-800 text-xs font-medium rounded-full shrink-0">
                      <Crown className="h-3 w-3" />
                      Admin
                    </span>
                  )}
                </div>
              </CardHeader>
              <CardContent>
                {group.description && (
                  <p className="text-sm text-gray-600 mb-3 line-clamp-2">{group.description}</p>
                )}
                <div className="flex items-center justify-between text-sm text-gray-500">
                  <span className="flex items-center gap-1">
                    <Users className="h-4 w-4" />
                    {group.member_count} {group.member_count === 1 ? 'member' : 'members'}
                  </span>
                  <span>by {group.creator_name}</span>
                </div>

                {/* Actions */}
                <div className="flex gap-2 mt-3 pt-3 border-t">
                  {group.user_role === 'admin' && group.created_by === user.id ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-red-600 hover:text-red-700 hover:bg-red-50"
                      onClick={(e) => {
                        e.stopPropagation();
                        setDeleteDialog({ open: true, group });
                      }}
                    >
                      <Trash2 className="h-4 w-4 mr-1" />
                      Delete
                    </Button>
                  ) : (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-gray-600 hover:text-gray-700"
                      onClick={(e) => {
                        e.stopPropagation();
                        setLeaveDialog({ open: true, group });
                      }}
                    >
                      <LogOut className="h-4 w-4 mr-1" />
                      Leave
                    </Button>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Leave Group Dialog */}
      <Dialog open={leaveDialog.open} onOpenChange={(open) => !open && setLeaveDialog({ open: false, group: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Leave Group</DialogTitle>
            <DialogDescription>
              Are you sure you want to leave &quot;{leaveDialog.group?.name}&quot;? You will lose access to shared content in this group.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setLeaveDialog({ open: false, group: null })}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleLeaveGroup} disabled={actionLoading}>
              {actionLoading ? 'Leaving...' : 'Leave Group'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Group Dialog */}
      <Dialog open={deleteDialog.open} onOpenChange={(open) => !open && setDeleteDialog({ open: false, group: null })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete Group</DialogTitle>
            <DialogDescription>
              Are you sure you want to delete &quot;{deleteDialog.group?.name}&quot;? This will remove all members and shared content links. Original content will NOT be deleted.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialog({ open: false, group: null })}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDeleteGroup} disabled={actionLoading}>
              {actionLoading ? 'Deleting...' : 'Delete Group'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageContainer>
  );
}
