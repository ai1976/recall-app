import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { 
  Users, 
  Shield, 
  FileText,
  AlertCircle,
  UserPlus,
  GraduationCap
} from 'lucide-react';

export default function SuperAdminDashboard() {
  const { isSuperAdmin, isLoading: roleLoading } = useRole();
  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [admins, setAdmins] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [filteredUsers, setFilteredUsers] = useState([]);

  useEffect(() => {
    if (!roleLoading && isSuperAdmin) {
      fetchDashboardData();
    }
  }, [isSuperAdmin, roleLoading]);

  useEffect(() => {
    filterUsers();
  }, [searchTerm, roleFilter, users]);

  function filterUsers() {
    let filtered = [...users];

    // Filter by search term
    if (searchTerm) {
      filtered = filtered.filter(user =>
        user.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.email?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // Filter by role
    if (roleFilter !== 'all') {
      filtered = filtered.filter(user => user.role === roleFilter);
    }

    setFilteredUsers(filtered);
  }

  async function fetchDashboardData() {
    setIsLoading(true);
    await Promise.all([
      fetchStats(),
      fetchUsers(),
      fetchAdmins(),
      fetchRecentAuditLogs()
    ]);
    setIsLoading(false);
  }

  async function fetchStats() {
    try {
      const { data: profiles, error } = await supabase
        .from('profiles')
        .select('role');

      if (error) throw error;

      const roleCounts = {
        total: profiles.length,
        students: profiles.filter(p => p.role === 'student').length,
        professors: profiles.filter(p => p.role === 'professor').length,
        admins: profiles.filter(p => p.role === 'admin').length,
        super_admins: profiles.filter(p => p.role === 'super_admin').length
      };

      const { count: notesCount } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true });

      const { count: flashcardsCount } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true });

      setStats({
        ...roleCounts,
        totalNotes: notesCount || 0,
        totalFlashcards: flashcardsCount || 0
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  }

  async function fetchUsers() {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
    }
  }

  async function fetchAdmins() {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .in('role', ['admin', 'super_admin'])
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAdmins(data || []);
    } catch (error) {
      console.error('Error fetching admins:', error);
    }
  }

  async function fetchRecentAuditLogs() {
    try {
      const { data, error } = await supabase
        .from('admin_audit_log')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20);

      if (error) throw error;
      setAuditLogs(data || []);
    } catch (error) {
      console.error('Error fetching audit logs:', error);
    }
  }

  async function changeUserRole(userId, newRole, reason) {
    try {
      const { data: currentUser } = await supabase
        .from('profiles')
        .select('role, email, full_name')
        .eq('id', userId)
        .single();

      if (!currentUser) {
        alert('User not found');
        return;
      }

      const { error: updateError } = await supabase
        .from('profiles')
        .update({ role: newRole })
        .eq('id', userId);

      if (updateError) throw updateError;

      const { data: { user } } = await supabase.auth.getUser();

      const { error: logError } = await supabase
        .from('role_change_log')
        .insert({
          user_id: userId,
          old_role: currentUser.role,
          new_role: newRole,
          changed_by: user.id,
          reason: reason || `Changed from ${currentUser.role} to ${newRole}`
        });

      if (logError) throw logError;

      const { error: auditError } = await supabase
        .from('admin_audit_log')
        .insert({
          action: 'change_role',
          admin_id: user.id,
          target_user_id: userId,
          details: {
            old_role: currentUser.role,
            new_role: newRole,
            reason: reason
          }
        });

      if (auditError) throw auditError;

      alert(`Successfully changed ${currentUser.full_name || currentUser.email} to ${newRole}`);
      
      fetchDashboardData();
    } catch (error) {
      console.error('Error changing user role:', error);
      alert('Failed to change user role: ' + error.message);
    }
  }

  async function promoteToProf(userId) {
    const reason = prompt('Reason for promoting to professor (optional):');
    await changeUserRole(userId, 'professor', reason || 'Promoted to professor');
  }

  async function promoteToAdmin(userId) {
    const reason = prompt('Reason for promoting to admin (optional):');
    if (confirm('Are you sure you want to make this user an admin? They will have significant permissions.')) {
      await changeUserRole(userId, 'admin', reason || 'Promoted to admin');
    }
  }

  async function demoteUser(userId) {
    const reason = prompt('Reason for demotion (optional):');
    if (confirm('Are you sure you want to demote this user to student?')) {
      await changeUserRole(userId, 'student', reason || 'Demoted to student');
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

  if (!isSuperAdmin) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Alert variant="destructive" className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            Access Denied. This page is only accessible to Super Administrators.
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Super Admin Dashboard
        </h1>
        <p className="text-gray-600">
          Complete platform control and oversight
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Users
            </CardTitle>
            <Users className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.total || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              All registered users
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Students
            </CardTitle>
            <GraduationCap className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.students || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              Regular students
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Professors
            </CardTitle>
            <Shield className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.professors || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              Faculty members
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Admins
            </CardTitle>
            <UserPlus className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {(stats?.admins || 0) + (stats?.super_admins || 0)}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {stats?.super_admins || 0} super admin
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Content
            </CardTitle>
            <FileText className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {(stats?.totalNotes || 0) + (stats?.totalFlashcards || 0)}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {stats?.totalNotes || 0} notes, {stats?.totalFlashcards || 0} cards
            </p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="users" className="space-y-6">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="users">User Management</TabsTrigger>
          <TabsTrigger value="admins">Admin Team</TabsTrigger>
          <TabsTrigger value="audit">Audit Log</TabsTrigger>
        </TabsList>

        <TabsContent value="users" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>All Users</CardTitle>
              <CardDescription>
                All registered users. Click to manage roles.
              </CardDescription>
            </CardHeader>
            <CardContent>
              {/* Search and Filter */}
              <div className="space-y-4 mb-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Search Box */}
                  <div className="relative">
                    <input
                      type="text"
                      placeholder="Search by name or email..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="w-full px-4 py-2 pl-10 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                    <svg
                      className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </div>

                  {/* Role Filter */}
                  <select
                    value={roleFilter}
                    onChange={(e) => setRoleFilter(e.target.value)}
                    className="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="all">All Roles</option>
                    <option value="student">Students Only</option>
                    <option value="professor">Professors Only</option>
                    <option value="admin">Admins Only</option>
                    <option value="super_admin">Super Admins Only</option>
                  </select>
                </div>

                {/* Results Count */}
                <p className="text-sm text-gray-500">
                  Showing {filteredUsers.length} of {users.length} users
                  {searchTerm && ` matching "${searchTerm}"`}
                  {roleFilter !== 'all' && ` filtered by ${roleFilter}`}
                </p>
              </div>

              {/* User List */}
              {isLoading ? (
                <p className="text-center text-gray-500 py-8">Loading users...</p>
              ) : filteredUsers.length === 0 ? (
                <div className="text-center text-gray-500 py-8">
                  <p className="font-medium">No users found</p>
                  <p className="text-sm mt-2">Try adjusting your search or filters</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {filteredUsers.map((user) => (
                    <div 
                      key={user.id} 
                      className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50"
                    >
                      <div className="flex-1">
                        <div className="flex items-center gap-3">
                          <div>
                            <p className="font-medium text-gray-900">
                              {user.full_name || 'No name'}
                            </p>
                            <p className="text-sm text-gray-500">{user.email}</p>
                          </div>
                        </div>
                        <div className="mt-2 flex gap-2">
                          <span className={`
                            px-2 py-1 text-xs rounded-full
                            ${user.role === 'super_admin' ? 'bg-purple-100 text-purple-800' : ''}
                            ${user.role === 'admin' ? 'bg-red-100 text-red-800' : ''}
                            ${user.role === 'professor' ? 'bg-blue-100 text-blue-800' : ''}
                            ${user.role === 'student' ? 'bg-green-100 text-green-800' : ''}
                          `}>
                            {user.role || 'student'}
                          </span>
                          {user.course_level && (
                            <span className="px-2 py-1 text-xs bg-gray-100 text-gray-800 rounded-full">
                              {user.course_level}
                            </span>
                          )}
                        </div>
                      </div>
                      
                      <div className="flex gap-2">
                        {user.role === 'student' && (
                          <>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => promoteToProf(user.id)}
                            >
                              Make Professor
                            </Button>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => promoteToAdmin(user.id)}
                            >
                              Make Admin
                            </Button>
                          </>
                        )}
                        {(user.role === 'professor' || user.role === 'admin') && (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => demoteUser(user.id)}
                          >
                            Demote to Student
                          </Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="admins" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Admin Team</CardTitle>
              <CardDescription>
                All administrators and their permissions
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <p className="text-center text-gray-500 py-8">Loading admins...</p>
              ) : admins.length === 0 ? (
                <p className="text-center text-gray-500 py-8">No admins found</p>
              ) : (
                <div className="space-y-4">
                  {admins.map((admin) => (
                    <div 
                      key={admin.id} 
                      className="p-4 border rounded-lg"
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-gray-900">
                            {admin.full_name || 'No name'}
                          </p>
                          <p className="text-sm text-gray-500">{admin.email}</p>
                        </div>
                        <span className={`
                          px-3 py-1 text-sm font-medium rounded-full
                          ${admin.role === 'super_admin' 
                            ? 'bg-purple-100 text-purple-800' 
                            : 'bg-red-100 text-red-800'}
                        `}>
                          {admin.role === 'super_admin' ? 'Super Admin' : 'Admin'}
                        </span>
                      </div>
                      <div className="mt-2 text-xs text-gray-500">
                        Joined: {new Date(admin.created_at).toLocaleDateString()}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="audit" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Audit Log</CardTitle>
              <CardDescription>
                Recent admin actions (last 20 entries)
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <p className="text-center text-gray-500 py-8">Loading audit logs...</p>
              ) : auditLogs.length === 0 ? (
                <p className="text-center text-gray-500 py-8">No audit logs yet</p>
              ) : (
                <div className="space-y-3">
                  {auditLogs.map((log) => (
                    <div 
                      key={log.id} 
                      className="p-3 border rounded-lg bg-gray-50"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <p className="font-medium text-sm text-gray-900">
                            {log.action.replace(/_/g, ' ').toUpperCase()}
                          </p>
                          {log.details && (
                            <p className="text-xs text-gray-500 mt-1">
                              {JSON.stringify(log.details)}
                            </p>
                          )}
                        </div>
                        <span className="text-xs text-gray-500">
                          {new Date(log.created_at).toLocaleString()}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}