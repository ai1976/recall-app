import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase';

console.log('🧪 AuthContext.jsx loaded - DEBUG VERSION');
const AuthContext = createContext({})

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthContext)

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Check active sessions
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
      setLoading(false)
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
      setLoading(false)
    })

    return () => subscription.unsubscribe()
  }, [])

  const value = {
    user,
    loading,
    // 🆕 ENHANCED: Sign in with AUDIT LOGGING for admin/super_admin
   signIn: async (email, password) => {
  console.log('🟦 SIGN IN STARTED:', email);
  
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    console.log('🟦 Auth response received:', { 
      hasData: !!data, 
      hasUser: !!data?.user, 
      userId: data?.user?.id,
      hasError: !!error 
    });

    if (error) {
      console.log('🔴 Auth error, throwing:', error);
      throw error;
    }

    // 🆕 LOG ADMIN/SUPER_ADMIN LOGINS (SECURITY)
    if (data.user) {
      console.log('🟩 User logged in successfully, checking role...');
      
      // Fetch user role from profiles table
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .single();

      console.log('🟩 Profile fetch result:', {
        profile,
        profileError,
        hasProfile: !!profile,
        role: profile?.role
      });

      // Only log if admin or super_admin
      if (!profileError && profile && ['admin', 'super_admin'].includes(profile.role)) {
        console.log(`🔐 ADMIN DETECTED: Logging ${profile.role} login for ${data.user.email}`);
        
        // Log to admin_audit_log
        const { error: logError } = await supabase
          .from('admin_audit_log')
          .insert({
            action: 'admin_login',
            admin_id: data.user.id,
            target_user_id: null,
            details: {
              role: profile.role,
              login_time: new Date().toISOString(),
              email: data.user.email
            }
          });

        console.log('🔐 Audit log insert result:', {
          hasError: !!logError,
          error: logError
        });

        // Log warning if audit logging fails (but don't block login)
        if (logError) {
          console.error('⚠️ Failed to log admin login:', logError);
          // Continue - login succeeded, logging is secondary
        } else {
          console.log('✅ Admin login logged successfully');
        }
      } else {
        console.log('🟡 Not an admin/super_admin, skipping login logging');
        console.log('🟡 Profile details:', {
          profileError,
          role: profile?.role,
          isAdmin: ['admin', 'super_admin'].includes(profile?.role || '')
        });
      }
    } else {
      console.log('🔴 No user in data object');
    }

    console.log('🟦 SIGN IN COMPLETED, returning data');
    return data;
  } catch (error) {
    console.error('🔴 SIGN IN ERROR:', error);
    throw error;
  }
},
    signUp: async (email, password, fullName, courseLevel) => {
      try {
        // Step 1: Create auth user
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              full_name: fullName,
              course_level: courseLevel
            }
          }
        });

        if (error) throw error;

        // Step 2: Wait for auth.users to be created (100ms delay)
        await new Promise(resolve => setTimeout(resolve, 100));

        // Step 3: Create profile (with error handling)
        if (data.user) {
          const { error: profileError } = await supabase
            .from('profiles')
            .insert({
              id: data.user.id,
              email: email,
              full_name: fullName,
              course_level: courseLevel,
              institution: 'In-house',
              role: 'student'
            });

          // If profile creation fails, log warning but don't throw
          if (profileError) {
            console.warn('Profile creation warning:', profileError);
            // Don't throw - continue with signup
          }
        }

        return data;
      } catch (error) {
        console.error('Signup error:', error);
        throw error;
      }
    },
    signOut: async () => {
      const { error } = await supabase.auth.signOut()
      if (error) throw error
    },
  }

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  )
}