import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export function useRole() {
  const { user } = useAuth();
  const [role, setRole] = useState(null);
  const [permissions, setPermissions] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setRole(null);
      setPermissions(null);
      setIsLoading(false);
      return;
    }

    fetchUserRole();
  }, [user]);

  async function fetchUserRole() {
    try {
      setIsLoading(true);

      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

      if (profileError) {
        console.error('Error fetching user role:', profileError);
        setRole('student');
        setIsLoading(false);
        return;
      }

      const userRole = profile?.role || 'student';
      setRole(userRole);

      const { data: rolePermissions, error: permError } = await supabase
        .from('role_permissions')
        .select('*')
        .eq('role', userRole)
        .single();

      if (permError) {
        console.error('Error fetching role permissions:', permError);
      }

      setPermissions(rolePermissions || getDefaultPermissions());
      setIsLoading(false);

    } catch (error) {
      console.error('Error in fetchUserRole:', error);
      setRole('student');
      setPermissions(getDefaultPermissions());
      setIsLoading(false);
    }
  }

  function getDefaultPermissions() {
    return {
      can_manage_users: false,
      can_manage_content: false,
      can_assign_roles: false,
      can_view_analytics: false,
      can_view_financials: false,
      can_create_admins: false,
      can_delete_users: false,
      can_bulk_upload: false,
      can_configure_system: false
    };
  }

  const isSuperAdmin = role === 'super_admin';
  const isAdmin = role === 'admin' || role === 'super_admin';
  const isProfessor = role === 'professor';
  const isStudent = role === 'student';

  const hasPermission = (permissionName) => {
    if (!permissions) return false;
    return permissions[permissionName] === true;
  };

  return {
    role,
    permissions,
    isLoading,
    isSuperAdmin,
    isAdmin,
    isProfessor,
    isStudent,
    hasPermission,
    refetch: fetchUserRole
  };
}