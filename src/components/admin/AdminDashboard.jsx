import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { 
  Users, 
  FileText, 
  XCircle,
  AlertCircle,
  TrendingUp
} from 'lucide-react';

export default function AdminDashboard() {
  const { isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();
  const [stats, setStats] = useState(null);
  const [pendingContent, setPendingContent] = useState([]);
  const [recentUsers, setRecentUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!roleLoading && (isAdmin || isSuperAdmin)) {
      fetchDashboardData();
    }
     // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAdmin, isSuperAdmin, roleLoading]);

  async function fetchDashboardData() {
    setIsLoading(true);
    await Promise.all([
      fetchStats(),
      fetchPendingContent(),
      fetchRecentUsers()
    ]);
    setIsLoading(false);
  }

  async function fetchStats() {
    try {
      const { data: profiles } = await supabase
        .from('profiles')
        .select('role, created_at');

      const { data: notes } = await supabase
        .from('notes')
        .select('is_public, created_at');

      const { data: flashcards } = await supabase
        .from('flashcards')
        .select('is_public, created_at');

      const today = new Date();
      const lastWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

      setStats({
        totalUsers: profiles?.length || 0,
        newUsersThisWeek: profiles?.filter(p => 
          new Date(p.created_at) > lastWeek
        ).length || 0,
        totalNotes: notes?.length || 0,
        publicNotes: notes?.filter(n => n.is_public).length || 0,
        totalFlashcards: flashcards?.length || 0,
        publicFlashcards: flashcards?.filter(f => f.is_public).length || 0
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  }

  async function fetchPendingContent() {
    try {
      const { data: notes } = await supabase
        .from('notes')
        .select('*')
        .eq('is_public', true)
        .order('created_at', { ascending: false })
        .limit(10);

      setPendingContent(notes || []);
    } catch (error) {
      console.error('Error fetching pending content:', error);
    }
  }

  async function fetchRecentUsers() {
    try {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);

      setRecentUsers(data || []);
    } catch (error) {
      console.error('Error fetching recent users:', error);
    }
  }

  async function suspendUser(userId) {
    if (!confirm('Are you sure you want to suspend this user?')) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ status: 'suspended' })
        .eq('id', userId);

      if (error) throw error;

      const { data: { user } } = await supabase.auth.getUser();

      await supabase.from('admin_audit_log').insert({
        action: 'suspend_user',
        admin_id: user.id,
        target_user_id: userId,
        details: { reason: 'Suspended by admin' }
      });

      alert('User suspended successfully');
      fetchDashboardData();
    } catch (error) {
      console.error('Error suspending user:', error);
      alert('Failed to suspend user');
    }
  }

  async function deleteNote(noteId) {
    if (!confirm('Are you sure you want to delete this note?')) return;

    try {
      const { error } = await supabase
        .from('notes')
        .delete()
        .eq('id', noteId);

      if (error) throw error;

      const { data: { user } } = await supabase.auth.getUser();

      await supabase.from('admin_audit_log').insert({
        action: 'delete_note',
        admin_id: user.id,
        details: { note_id: noteId }
      });

      alert('Note deleted successfully');
      fetchDashboardData();
    } catch (error) {
      console.error('Error deleting note:', error);
      alert('Failed to delete note');
    }
  }

  if (roleLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  if (!isAdmin && !isSuperAdmin) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Alert variant="destructive" className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            Access Denied. This page is only accessible to Administrators.
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Admin Dashboard
        </h1>
        <p className="text-gray-600">
          Content moderation and user management
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Users
            </CardTitle>
            <Users className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.totalUsers || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              +{stats?.newUsersThisWeek || 0} this week
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Notes
            </CardTitle>
            <FileText className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.totalNotes || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              {stats?.publicNotes || 0} public
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Flashcards
            </CardTitle>
            <TrendingUp className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.totalFlashcards || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              {stats?.publicFlashcards || 0} public
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Pending Review
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">0</div>
            <p className="text-xs text-gray-500 mt-1">
              No pending items
            </p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="content" className="space-y-6">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="content">Content Moderation</TabsTrigger>
          <TabsTrigger value="users">User Management</TabsTrigger>
        </TabsList>

        <TabsContent value="content" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Recent Public Content</CardTitle>
              <CardDescription>
                Review and moderate publicly shared content
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <p className="text-center text-gray-500 py-8">Loading content...</p>
              ) : pendingContent.length === 0 ? (
                <p className="text-center text-gray-500 py-8">No content to review</p>
              ) : (
                <div className="space-y-4">
                  {pendingContent.map((note) => (
                    <div 
                      key={note.id} 
                      className="p-4 border rounded-lg hover:bg-gray-50"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <p className="font-medium text-gray-900">
                            {note.title}
                          </p>
                          {note.description && (
                            <p className="text-sm text-gray-600 mt-1">
                              {note.description}
                            </p>
                          )}
                          <div className="mt-2 flex items-center gap-4 text-xs text-gray-500">
                            <span>{new Date(note.created_at).toLocaleDateString()}</span>
                            <span>•</span>
                            <span>{note.view_count || 0} views</span>
                          </div>
                        </div>
                        
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            variant="outline"
                            className="text-red-600 hover:text-red-700"
                            onClick={() => deleteNote(note.id)}
                          >
                            <XCircle className="h-4 w-4 mr-1" />
                            Delete
                          </Button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="users" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Recent Users</CardTitle>
              <CardDescription>
                Latest registered users
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <p className="text-center text-gray-500 py-8">Loading users...</p>
              ) : recentUsers.length === 0 ? (
                <p className="text-center text-gray-500 py-8">No users found</p>
              ) : (
                <div className="space-y-4">
                  {recentUsers.map((user) => (
                    <div 
                      key={user.id} 
                      className="flex items-center justify-between p-4 border rounded-lg"
                    >
                      <div>
                        <p className="font-medium text-gray-900">
                          {user.full_name || 'No name'}
                        </p>
                        <p className="text-sm text-gray-500">{user.email}</p>
                        <div className="mt-2 flex gap-2">
                          <span className={`
                            px-2 py-1 text-xs rounded-full
                            ${user.role === 'admin' ? 'bg-red-100 text-red-800' : ''}
                            ${user.role === 'professor' ? 'bg-blue-100 text-blue-800' : ''}
                            ${user.role === 'student' ? 'bg-green-100 text-green-800' : ''}
                          `}>
                            {user.role || 'student'}
                          </span>
                        </div>
                      </div>
                      
                      {user.status === 'active' && (
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-red-600"
                          onClick={() => suspendUser(user.id)}
                        >
                          Suspend
                        </Button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          <Alert>
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              <strong>Note:</strong> To promote users to Professor or Admin roles, please contact the Super Administrator.
            </AlertDescription>
          </Alert>
        </TabsContent>
      </Tabs>
    </div>
  );
}