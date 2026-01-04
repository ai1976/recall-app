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
  GraduationCap,
  Activity,
  Trash2,
  TrendingUp,
  TrendingDown,
  UserX,
  UserCheck,
  Clock,
  BookOpen,
  CreditCard,
  Target,
  Award,
  Flame
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

  // New state for additional reports
  const [contentStats, setContentStats] = useState(null);
  const [engagementStats, setEngagementStats] = useState(null);
  const [retentionStats, setRetentionStats] = useState(null);

  useEffect(() => {
    if (!roleLoading && isSuperAdmin) {
      fetchDashboardData();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuperAdmin, roleLoading]);

  useEffect(() => {
    filterUsers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchTerm, roleFilter, users]);

  function filterUsers() {
    let filtered = [...users];

    if (searchTerm) {
      filtered = filtered.filter(user =>
        user.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.email?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    if (roleFilter !== 'all') {
      filtered = filtered.filter(user => user.role === roleFilter);
    }

    setFilteredUsers(filtered);
  }

  async function fetchDashboardData() {
    console.log('📊 Super Admin Dashboard: Starting data fetch...');
    setIsLoading(true);
    await Promise.all([
      fetchStats(),
      fetchUsers(),
      fetchAdmins(),
      fetchRecentAuditLogs(),
      fetchContentStats(),
      fetchEngagementStats(),
      fetchRetentionStats()
    ]);
    setIsLoading(false);
    console.log('✅ Super Admin Dashboard: All data loaded');
  }

  async function fetchStats() {
    console.log('🔍 fetchStats() - START');
    
    try {
      // Role counts
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

      console.log('📊 Role counts:', roleCounts);

      // Content counts
      const { count: notesCount } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true });

      const { count: flashcardsCount } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true });

      console.log('📝 Content counts:', { notesCount, flashcardsCount });

      // User Activity Stats
      console.log('🔄 Attempting to call SQL function: get_user_activity_stats()');

      const { data: activityData, error: activityError } = await supabase
        .rpc('get_user_activity_stats');

      console.log('📡 RPC Response:', activityData);
      console.log('📡 RPC Error:', activityError);

      let activityStats = {
        daily_active_users: 0,
        daily_active_percent: 0,
        weekly_active_users: 0,
        weekly_active_percent: 0
      };

      if (!activityError && activityData) {
        if (Array.isArray(activityData) && activityData.length > 0) {
          const firstItem = activityData[0];
          activityStats = {
            daily_active_users: firstItem.daily_active_users || 0,
            daily_active_percent: firstItem.daily_active_percent || 0,
            weekly_active_users: firstItem.weekly_active_users || 0,
            weekly_active_percent: firstItem.weekly_active_percent || 0
          };
          console.log('✅ Using SQL function (array format):', activityStats);
        } else if (!Array.isArray(activityData) && typeof activityData === 'object') {
          activityStats = {
            daily_active_users: activityData.daily_active_users || 0,
            daily_active_percent: activityData.daily_active_percent || 0,
            weekly_active_users: activityData.weekly_active_users || 0,
            weekly_active_percent: activityData.weekly_active_percent || 0
          };
          console.log('✅ Using SQL function (object format):', activityStats);
        }
      }

      const finalStats = {
        ...roleCounts,
        totalNotes: notesCount || 0,
        totalFlashcards: flashcardsCount || 0,
        dailyActiveUsers: activityStats.daily_active_users || 0,
        dailyActivePercent: Math.round(activityStats.daily_active_percent || 0),
        weeklyActiveUsers: activityStats.weekly_active_users || 0,
        weeklyActivePercent: Math.round(activityStats.weekly_active_percent || 0)
      };

      console.log('📊 Final stats to display:', finalStats);
      setStats(finalStats);

    } catch (error) {
      console.error('❌ Error in fetchStats():', error);
    }

    console.log('🔍 fetchStats() - END');
  }

  async function fetchContentStats() {
    try {
      const { data, error } = await supabase.rpc('get_content_creation_stats');
      
      if (error) {
        console.error('Error fetching content stats:', error);
        return;
      }

      if (data && data.length > 0) {
        setContentStats(data[0]);
      }
    } catch (error) {
      console.error('Error fetching content stats:', error);
    }
  }

  async function fetchEngagementStats() {
    try {
      const { data, error } = await supabase.rpc('get_study_engagement_stats');
      
      if (error) {
        console.error('Error fetching engagement stats:', error);
        return;
      }

      if (data && data.length > 0) {
        setEngagementStats(data[0]);
      }
    } catch (error) {
      console.error('Error fetching engagement stats:', error);
    }
  }

  async function fetchRetentionStats() {
    try {
      const { data, error } = await supabase.rpc('get_user_retention_stats');
      
      if (error) {
        console.error('Error fetching retention stats:', error);
        return;
      }

      if (data && data.length > 0) {
        setRetentionStats(data[0]);
      }
    } catch (error) {
      console.error('Error fetching retention stats:', error);
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
      // Fetch audit logs
      const { data: logs, error } = await supabase
        .from('admin_audit_log')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20);

      if (error) throw error;

      if (!logs || logs.length === 0) {
        setAuditLogs([]);
        return;
      }

      // Get unique user IDs (admin_id and target_user_id)
      const userIds = new Set();
      logs.forEach(log => {
        if (log.admin_id) userIds.add(log.admin_id);
        if (log.target_user_id) userIds.add(log.target_user_id);
      });

      // Fetch user profiles for those IDs
      const { data: profiles, error: profileError } = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .in('id', Array.from(userIds));

      if (profileError) throw profileError;

      // Create a map of user ID to user info
      const userMap = {};
      (profiles || []).forEach(p => {
        userMap[p.id] = p;
      });

      // Merge user info into logs
      const enrichedLogs = logs.map(log => ({
        ...log,
        admin_name: userMap[log.admin_id]?.full_name || userMap[log.admin_id]?.email || 'Unknown Admin',
        target_user_name: log.target_user_id 
          ? (userMap[log.target_user_id]?.full_name || userMap[log.target_user_id]?.email || 'Unknown User')
          : null
      }));

      setAuditLogs(enrichedLogs);
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

  async function deleteUser(userId) {
    try {
      const { data: targetUser } = await supabase
        .from('profiles')
        .select('email, full_name, role')
        .eq('id', userId)
        .single();

      if (!targetUser) {
        alert('User not found');
        return;
      }

      if (targetUser.role === 'super_admin') {
        alert('Cannot delete Super Admin accounts!');
        return;
      }

      const { count: notesCount } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId);

      const { count: flashcardsCount } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId);

      const totalContent = (notesCount || 0) + (flashcardsCount || 0);

      const confirmMessage = `⚠️ DELETE USER - CANNOT BE UNDONE

User: ${targetUser.full_name || targetUser.email}
Email: ${targetUser.email}
Role: ${targetUser.role}

This will DELETE:
- User profile data
- ${notesCount || 0} notes
- ${flashcardsCount || 0} flashcards
- All reviews

⚠️ NOTE: Authentication account requires manual deletion
(You'll get instructions after this step)

Are you ABSOLUTELY SURE?`;

      if (!confirm(confirmMessage)) {
        return;
      }

      const secondConfirm = prompt('Type DELETE in capital letters to confirm:');
      if (secondConfirm !== 'DELETE') {
        alert('Deletion cancelled - incorrect confirmation');
        return;
      }

      console.log('Deleting user content...');
      await supabase.from('reviews').delete().eq('user_id', userId);
      await supabase.from('flashcards').delete().eq('user_id', userId);
      await supabase.from('notes').delete().eq('user_id', userId);

      console.log('Deleting user profile...');
      const { error: deleteProfileError } = await supabase
        .from('profiles')
        .delete()
        .eq('id', userId);

      if (deleteProfileError) throw deleteProfileError;

      const { data: { user } } = await supabase.auth.getUser();
      
      await supabase
        .from('admin_audit_log')
        .insert({
          action: 'delete_user',
          admin_id: user.id,
          target_user_id: userId,
          details: {
            deleted_user: targetUser.email,
            deleted_role: targetUser.role,
            deleted_content: totalContent,
            auth_deletion: 'manual_required'
          }
        });

      alert(`✅ USER PROFILE & CONTENT DELETED SUCCESSFULLY!

Deleted User: ${targetUser.full_name || targetUser.email}
Email: ${targetUser.email}
Content Removed: ${totalContent} items (notes + flashcards)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ MANUAL STEP REQUIRED - COMPLETE DELETION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The authentication account still exists.
To complete deletion:

1. Open Supabase Dashboard
2. Go to: Authentication → Users
3. Search for: ${targetUser.email}
4. Click the trash icon (🗑️) to delete

Why manual? 
Auth deletion requires service role access (not available in browser for security).

This will be automated in Phase 2 with Edge Functions.`);
      
      fetchDashboardData();
      
    } catch (error) {
      console.error('Error deleting user:', error);
      alert('❌ Failed to delete user: ' + error.message);
    }
  }

  async function promoteToProf(userId) {
    const reason = prompt('Reason for promoting to professor (optional):');
    if (reason !== null) {
      await changeUserRole(userId, 'professor', reason || 'Promoted to professor');
    }
  }

  async function promoteToAdmin(userId) {
    if (confirm('Are you sure you want to make this user an ADMIN? They will have significant permissions.')) {
      const reason = prompt('Reason for promoting to admin (optional):');
      if (reason !== null) {
        await changeUserRole(userId, 'admin', reason || 'Promoted to admin');
      }
    }
  }

  async function demoteUser(userId) {
    if (confirm('Are you sure you want to DEMOTE this user to student?')) {
      const reason = prompt('Reason for demotion (optional):');
      if (reason !== null) {
        await changeUserRole(userId, 'student', reason || 'Demoted to student');
      }
    }
  }

  function handleStatCardClick(role) {
    const userManagementTab = document.querySelector('[value="users"]');
    if (userManagementTab) {
      userManagementTab.click();
    }
    
    setRoleFilter(role);
    
    setTimeout(() => {
      const userList = document.getElementById('user-management-section');
      if (userList) {
        userList.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  }

  // ✅ NEW: Click handlers for retention cards
  function handleNewUsersClick() {
    const userManagementTab = document.querySelector('[value="users"]');
    if (userManagementTab) {
      userManagementTab.click();
    }
    
    // Filter for users created in last 7 days
    setRoleFilter('student');
    
    setTimeout(() => {
      const userList = document.getElementById('user-management-section');
      if (userList) {
        userList.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  }

  function handleInactiveUsersClick() {
    const userManagementTab = document.querySelector('[value="users"]');
    if (userManagementTab) {
      userManagementTab.click();
    }
    
    setRoleFilter('student');
    
    setTimeout(() => {
      const userList = document.getElementById('user-management-section');
      if (userList) {
        userList.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
      // TODO: Add filter for inactive users (0 activity)
      alert('Filtering for inactive users (students with 0 notes, 0 flashcards, 0 reviews). This requires additional filtering logic.');
    }, 100);
  }

  function handleRetentionClick() {
    const userManagementTab = document.querySelector('[value="users"]');
    if (userManagementTab) {
      userManagementTab.click();
    }
    
    setRoleFilter('student');
    
    setTimeout(() => {
      const userList = document.getElementById('user-management-section');
      if (userList) {
        userList.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
      // TODO: Add filter for users who came back after signup
      alert('Filtering for users who came back after signup (7-day retention). This requires additional filtering logic.');
    }, 100);
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

      {/* Stats Cards - Original 5 Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
        <Card 
          className="cursor-pointer hover:shadow-lg transition-shadow"
          onClick={() => handleStatCardClick('all')}
        >
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Users
            </CardTitle>
            <Users className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.total || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              Click to view all users
            </p>
          </CardContent>
        </Card>

        <Card 
          className="cursor-pointer hover:shadow-lg transition-shadow"
          onClick={() => handleStatCardClick('student')}
        >
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Students
            </CardTitle>
            <GraduationCap className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.students || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              Click to view students
            </p>
          </CardContent>
        </Card>

        <Card 
          className="cursor-pointer hover:shadow-lg transition-shadow"
          onClick={() => handleStatCardClick('professor')}
        >
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Professors
            </CardTitle>
            <Shield className="h-4 w-4 text-gray-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.professors || 0}</div>
            <p className="text-xs text-gray-500 mt-1">
              Click to view professors
            </p>
          </CardContent>
        </Card>

        <Card 
          className="cursor-pointer hover:shadow-lg transition-shadow"
          onClick={() => handleStatCardClick('admin')}
        >
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

      {/* User Retention Cards - NOW CLICKABLE ✅ */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-4">
          <Clock className="h-5 w-5 text-purple-600" />
          <h2 className="text-xl font-bold text-gray-900">User Growth & Retention</h2>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* New Users This Week - CLICKABLE */}
          <Card 
            className="cursor-pointer hover:shadow-lg transition-shadow"
            onClick={handleNewUsersClick}
          >
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <UserCheck className="h-5 w-5 text-green-600" />
                New Users This Week
              </CardTitle>
              <CardDescription>Students who signed up in last 7 days</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-4xl font-bold text-gray-900">
                {retentionStats?.new_users_this_week || 0}
              </div>
              <p className="text-sm text-gray-600 mt-2">
                Click to view new students
              </p>
            </CardContent>
          </Card>

          {/* Inactive Users - CLICKABLE */}
          <Card 
            className="cursor-pointer hover:shadow-lg transition-shadow"
            onClick={handleInactiveUsersClick}
          >
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <UserX className="h-5 w-5 text-red-600" />
                Inactive Users
              </CardTitle>
              <CardDescription>Signed up but never engaged</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-4xl font-bold text-red-600">
                {retentionStats?.inactive_users || 0}
              </div>
              <p className="text-sm text-gray-600 mt-2">
                Click to view inactive students
              </p>
            </CardContent>
          </Card>

          {/* 7-Day Retention - CLICKABLE */}
          <Card 
            className="cursor-pointer hover:shadow-lg transition-shadow"
            onClick={handleRetentionClick}
          >
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Target className="h-5 w-5 text-blue-600" />
                7-Day Retention
              </CardTitle>
              <CardDescription>Users who came back after signup</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex items-baseline gap-2">
                <span className="text-4xl font-bold text-blue-600">
                  {Math.round(retentionStats?.seven_day_retention_rate || 0)}%
                </span>
                <span className="text-xl text-gray-500">
                  ({retentionStats?.seven_day_retention_count || 0}/{retentionStats?.new_users_this_week || 0})
                </span>
              </div>
              <p className="text-sm text-gray-600 mt-2">
                Click to view retained students
              </p>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* User Activity Report (Existing - DAU & WAU) */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-4">
          <Activity className="h-5 w-5 text-blue-600" />
          <h2 className="text-xl font-bold text-gray-900">User Activity Report</h2>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Daily Active Users Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Daily Active Users</CardTitle>
              <CardDescription>Students active today</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-baseline gap-3">
                  <span className="text-4xl font-bold text-gray-900">
                    {stats?.dailyActiveUsers || 0}
                  </span>
                  <span className="text-2xl text-gray-500">
                    / {stats?.students || 0}
                  </span>
                </div>
                
                <div className="flex items-center gap-2">
                  <div className="flex-1 bg-gray-200 rounded-full h-3">
                    <div 
                      className={`h-3 rounded-full transition-all ${
                        (stats?.dailyActivePercent || 0) >= 60 
                          ? 'bg-green-500' 
                          : (stats?.dailyActivePercent || 0) >= 40 
                            ? 'bg-yellow-500' 
                            : 'bg-red-500'
                      }`}
                      style={{ width: `${Math.min(stats?.dailyActivePercent || 0, 100)}%` }}
                    />
                  </div>
                  <span className={`text-2xl font-bold ${
                    (stats?.dailyActivePercent || 0) >= 60 
                      ? 'text-green-600' 
                      : (stats?.dailyActivePercent || 0) >= 40 
                        ? 'text-yellow-600' 
                        : 'text-red-600'
                  }`}>
                    {stats?.dailyActivePercent || 0}%
                  </span>
                </div>
                
                <div className="pt-3 border-t">
                  <p className="text-sm text-gray-600">
                    Target: 60% (
                    {stats?.students ? Math.ceil((stats.students * 60) / 100) : 0} students)
                  </p>
                  <p className={`text-sm font-medium mt-1 ${
                    (stats?.dailyActivePercent || 0) >= 60 
                      ? 'text-green-600' 
                      : (stats?.dailyActivePercent || 0) >= 40 
                        ? 'text-yellow-600' 
                        : 'text-red-600'
                  }`}>
                    {(stats?.dailyActivePercent || 0) >= 60 
                      ? '✅ Above target' 
                      : (stats?.dailyActivePercent || 0) >= 40 
                        ? '⚠️ Below target' 
                        : '🚨 Well below target'}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Weekly Active Users Card */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Weekly Active Users</CardTitle>
              <CardDescription>Students active in last 7 days</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-baseline gap-3">
                  <span className="text-4xl font-bold text-gray-900">
                    {stats?.weeklyActiveUsers || 0}
                  </span>
                  <span className="text-2xl text-gray-500">
                    / {stats?.students || 0}
                  </span>
                </div>
                
                <div className="flex items-center gap-2">
                  <div className="flex-1 bg-gray-200 rounded-full h-3">
                    <div 
                      className={`h-3 rounded-full transition-all ${
                        (stats?.weeklyActivePercent || 0) >= 80 
                          ? 'bg-green-500' 
                          : (stats?.weeklyActivePercent || 0) >= 60 
                            ? 'bg-yellow-500' 
                            : 'bg-red-500'
                      }`}
                      style={{ width: `${Math.min(stats?.weeklyActivePercent || 0, 100)}%` }}
                    />
                  </div>
                  <span className={`text-2xl font-bold ${
                    (stats?.weeklyActivePercent || 0) >= 80 
                      ? 'text-green-600' 
                      : (stats?.weeklyActivePercent || 0) >= 60 
                        ? 'text-yellow-600' 
                        : 'text-red-600'
                  }`}>
                    {stats?.weeklyActivePercent || 0}%
                  </span>
                </div>
                
                <div className="pt-3 border-t">
                  <p className="text-sm text-gray-600">
                    Target: 80% (
                    {stats?.students ? Math.ceil((stats.students * 80) / 100) : 0} students)
                  </p>
                  <p className={`text-sm font-medium mt-1 ${
                    (stats?.weeklyActivePercent || 0) >= 80 
                      ? 'text-green-600' 
                      : (stats?.weeklyActivePercent || 0) >= 60 
                        ? 'text-yellow-600' 
                        : 'text-red-600'
                  }`}>
                    {(stats?.weeklyActivePercent || 0) >= 80 
                      ? '✅ Above target' 
                      : (stats?.weeklyActivePercent || 0) >= 60 
                        ? '⚠️ Below target' 
                        : '🚨 Well below target'}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Content Creation Report */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-4">
          <BookOpen className="h-5 w-5 text-indigo-600" />
          <h2 className="text-xl font-bold text-gray-900">Content Creation Report</h2>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Notes Per Student */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Avg Notes/Student</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {contentStats?.avg_notes_per_student 
                  ? parseFloat(contentStats.avg_notes_per_student).toFixed(1) 
                  : '0.0'}
              </div>
              <p className="text-xs text-gray-500 mt-1">
                Total: {contentStats?.total_notes || 0} notes
              </p>
            </CardContent>
          </Card>

          {/* Flashcards Per Student */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Avg Cards/Student</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {contentStats?.avg_flashcards_per_student 
                  ? parseFloat(contentStats.avg_flashcards_per_student).toFixed(1) 
                  : '0.0'}
              </div>
              <p className="text-xs text-gray-500 mt-1">
                Total: {contentStats?.total_flashcards || 0} flashcards
              </p>
            </CardContent>
          </Card>

          {/* Top Note Contributor */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Top Note Contributor</CardTitle>
            </CardHeader>
            <CardContent>
              {contentStats?.top_note_contributor_name ? (
                <>
                  <div className="text-lg font-semibold truncate">
                    {contentStats.top_note_contributor_name}
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    {contentStats.top_note_contributor_count} notes uploaded
                  </p>
                </>
              ) : (
                <p className="text-sm text-gray-500">No contributors yet</p>
              )}
            </CardContent>
          </Card>

          {/* Top Flashcard Contributor */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Top Card Contributor</CardTitle>
            </CardHeader>
            <CardContent>
              {contentStats?.top_flashcard_contributor_name ? (
                <>
                  <div className="text-lg font-semibold truncate">
                    {contentStats.top_flashcard_contributor_name}
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    {contentStats.top_flashcard_contributor_count} flashcards
                  </p>
                </>
              ) : (
                <p className="text-sm text-gray-500">No contributors yet</p>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Zero Contributors Alert */}
        {contentStats?.zero_contributors_count > 0 && (
          <Alert className="mt-4">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              <strong>{contentStats.zero_contributors_count} students</strong> haven't created any content yet. 
              Consider sending them reminders or tutorials.
            </AlertDescription>
          </Alert>
        )}
      </div>

      {/* Study Engagement Report */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-4">
          <CreditCard className="h-5 w-5 text-purple-600" />
          <h2 className="text-xl font-bold text-gray-900">Study Engagement Report</h2>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Total Reviews */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Total Reviews</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {engagementStats?.total_reviews_completed || 0}
              </div>
              <p className="text-xs text-gray-500 mt-1">All-time count</p>
            </CardContent>
          </Card>

          {/* Reviews This Week */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Reviews This Week</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {engagementStats?.reviews_this_week || 0}
              </div>
              <p className="text-xs text-gray-500 mt-1">Last 7 days</p>
            </CardContent>
          </Card>

          {/* Avg Reviews Per Student */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Avg Reviews/Student</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {engagementStats?.avg_reviews_per_student 
                  ? parseFloat(engagementStats.avg_reviews_per_student).toFixed(1) 
                  : '0.0'}
              </div>
              <p className="text-xs text-gray-500 mt-1">Per student average</p>
            </CardContent>
          </Card>

          {/* Students with Streaks */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm flex items-center gap-1">
                <Flame className="h-4 w-4 text-orange-500" />
                Active Streaks
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {engagementStats?.students_with_streaks || 0}
              </div>
              <p className="text-xs text-gray-500 mt-1">3+ consecutive days</p>
            </CardContent>
          </Card>
        </div>

        {/* Review Completion Rate */}
        <Card className="mt-4">
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Award className="h-5 w-5 text-yellow-600" />
              Review Completion Rate
            </CardTitle>
            <CardDescription>Percentage of due cards reviewed today</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-4">
              <div className="flex-1 bg-gray-200 rounded-full h-4">
                <div 
                  className="bg-gradient-to-r from-green-400 to-green-600 h-4 rounded-full transition-all"
                  style={{ width: `${Math.min(engagementStats?.review_completion_rate || 0, 100)}%` }}
                />
              </div>
              <span className="text-3xl font-bold text-green-600">
                {Math.round(engagementStats?.review_completion_rate || 0)}%
              </span>
            </div>
            <p className="text-sm text-gray-600 mt-2">
              Cards reviewed today out of total due today
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Tabs Section */}
      <Tabs defaultValue="users" className="space-y-6">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="users">User Management</TabsTrigger>
          <TabsTrigger value="admins">Admin Team</TabsTrigger>
          <TabsTrigger value="audit">Audit Log</TabsTrigger>
        </TabsList>

        <TabsContent value="users" className="space-y-4" id="user-management-section">
          <Card>
            <CardHeader>
              <CardTitle>All Users</CardTitle>
              <CardDescription>
                All registered users. Manage roles and permissions.
              </CardDescription>
            </CardHeader>
            <CardContent>
              {/* Search and Filter */}
              <div className="space-y-4 mb-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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

                <p className="text-sm text-gray-500">
                  Showing {filteredUsers.length} of {users.length} users
                  {searchTerm && ` matching "${searchTerm}"`}
                  {roleFilter !== 'all' && ` filtered by ${roleFilter}`}
                </p>
              </div>

              {/* User Table */}
              {isLoading ? (
                <p className="text-center text-gray-500 py-8">Loading users...</p>
              ) : filteredUsers.length === 0 ? (
                <div className="text-center text-gray-500 py-8">
                  <p className="font-medium">No users found</p>
                  <p className="text-sm mt-2">Try adjusting your search or filters</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gray-50 border-b">
                      <tr>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          User
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Role
                        </th>
                        <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Course
                        </th>
                        <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Actions
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {filteredUsers.map((user) => (
                        <tr key={user.id} className="hover:bg-gray-50">
                          <td className="px-4 py-4">
                            <div>
                              <p className="font-medium text-gray-900">
                                {user.full_name || 'No name'}
                              </p>
                              <p className="text-sm text-gray-500">{user.email}</p>
                            </div>
                          </td>
                          <td className="px-4 py-4">
                            <span className={`
                              inline-flex px-2 py-1 text-xs font-semibold rounded-full
                              ${user.role === 'super_admin' ? 'bg-purple-100 text-purple-800' : ''}
                              ${user.role === 'admin' ? 'bg-red-100 text-red-800' : ''}
                              ${user.role === 'professor' ? 'bg-blue-100 text-blue-800' : ''}
                              ${user.role === 'student' ? 'bg-green-100 text-green-800' : ''}
                            `}>
                              {user.role || 'student'}
                            </span>
                          </td>
                          <td className="px-4 py-4 text-sm text-gray-500">
                            {user.course_level || '-'}
                          </td>
                          <td className="px-4 py-4">
                            <div className="flex justify-end gap-2">
                              {user.role === 'student' && (
                                <>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => promoteToProf(user.id)}
                                    className="text-xs text-green-700 hover:bg-green-50 border-green-300"
                                  >
                                    <TrendingUp className="h-3 w-3 mr-1" />
                                    Prof
                                  </Button>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => promoteToAdmin(user.id)}
                                    className="text-xs text-green-700 hover:bg-green-50 border-green-300"
                                  >
                                    <TrendingUp className="h-3 w-3 mr-1" />
                                    Admin
                                  </Button>
                                </>
                              )}
                              {user.role === 'professor' && (
                                <>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => promoteToAdmin(user.id)}
                                    className="text-xs text-green-700 hover:bg-green-50 border-green-300"
                                  >
                                    <TrendingUp className="h-3 w-3 mr-1" />
                                    Admin
                                  </Button>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => demoteUser(user.id)}
                                    className="text-xs text-orange-700 hover:bg-orange-50 border-orange-300"
                                  >
                                    <TrendingDown className="h-3 w-3 mr-1" />
                                    Student
                                  </Button>
                                </>
                              )}
                              {user.role === 'admin' && (
                                <>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => changeUserRole(user.id, 'professor', 'Demoted from admin to professor')}
                                    className="text-xs text-orange-700 hover:bg-orange-50 border-orange-300"
                                  >
                                    <TrendingDown className="h-3 w-3 mr-1" />
                                    Prof
                                  </Button>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => demoteUser(user.id)}
                                    className="text-xs text-orange-700 hover:bg-orange-50 border-orange-300"
                                  >
                                    <TrendingDown className="h-3 w-3 mr-1" />
                                    Student
                                  </Button>
                                </>
                              )}
                              
                              {user.role !== 'super_admin' && (
                                <Button
                                  size="sm"
                                  variant="outline"
                                  onClick={() => deleteUser(user.id)}
                                  className="text-xs text-red-600 hover:text-red-700 hover:bg-red-50"
                                >
                                  <Trash2 className="h-3 w-4" />
                                </Button>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
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
                          
                          {/* Admin who performed action */}
                          <p className="text-xs text-gray-600 mt-1">
                            <span className="font-semibold">By:</span> {log.admin_name}
                          </p>
                          
                          {/* Target user (if applicable) */}
                          {log.target_user_name && (
                            <p className="text-xs text-gray-600">
                              <span className="font-semibold">Target:</span> {log.target_user_name}
                            </p>
                          )}
                          
                          {/* Details */}
                          {log.details && (
                            <p className="text-xs text-gray-500 mt-1">
                              {log.details.reason || JSON.stringify(log.details)}
                            </p>
                          )}
                        </div>
                        <span className="text-xs text-gray-500 whitespace-nowrap ml-4">
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