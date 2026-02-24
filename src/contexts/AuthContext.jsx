import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase';

const AuthContext = createContext({})

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthContext)

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  // ============================================================
  // HELPER: Update user's timezone in profiles table
  // Detects browser timezone and syncs to database if different
  // ============================================================
  const updateUserTimezone = async (userId) => {
    try {
      // Get browser's IANA timezone (e.g., 'Asia/Kolkata', 'America/New_York')
      const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      
      if (!browserTimezone) {
        console.log('⏰ Could not detect browser timezone');
        return;
      }

      // Fetch current stored timezone
      const { data: profile, error: fetchError } = await supabase
        .from('profiles')
        .select('timezone')
        .eq('id', userId)
        .single();

      if (fetchError) {
        console.warn('⏰ Could not fetch profile timezone:', fetchError);
        return;
      }

      // Only update if timezone is different or null
      if (profile?.timezone !== browserTimezone) {
        const { error: updateError } = await supabase
          .from('profiles')
          .update({ timezone: browserTimezone })
          .eq('id', userId);

        if (updateError) {
          console.warn('⏰ Failed to update timezone:', updateError);
        } else {
          console.log(`⏰ Timezone updated: ${profile?.timezone || 'null'} → ${browserTimezone}`);
        }
      } else {
        console.log(`⏰ Timezone already set: ${browserTimezone}`);
      }
    } catch (error) {
      // Non-critical error - don't block auth flow
      console.warn('⏰ Timezone sync error:', error);
    }
  };

  useEffect(() => {
    // Check active sessions — .catch() ensures loading resolves even if Supabase is unreachable
    supabase.auth.getSession()
      .then(({ data: { session } }) => {
        setUser(session?.user ?? null)
        setLoading(false)
        if (session?.user) {
          updateUserTimezone(session.user.id);
        }
      })
      .catch(() => {
        // Network error — treat as logged out so the app doesn't spin forever
        setUser(null)
        setLoading(false)
      })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
      setLoading(false)

      // ✅ NEW: Sync timezone on auth state change (login)
      if (session?.user && _event === 'SIGNED_IN') {
        updateUserTimezone(session.user.id);
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  const value = {
    user,
    loading,
    // 🆕 ENHANCED: Sign in with AUDIT LOGGING for admin/super_admin
   signIn: async (email, password) => {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) throw error;

    // Log admin/super_admin logins for security audit
    if (data.user) {
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .single();

      if (!profileError && profile && ['admin', 'super_admin'].includes(profile.role)) {
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

        if (logError) {
          console.error('⚠️ Failed to log admin login:', logError);
        }
      }

      await updateUserTimezone(data.user.id);
    }

    return data;
  } catch (error) {
    console.error('Sign in error:', error);
    throw error;
  }
},
    signUp: async (email, password, fullName, courseLevel) => {
      try {
        // Get browser timezone for new user
        const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Kolkata';

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
              role: 'student',
              timezone: browserTimezone // ✅ NEW: Set timezone on signup
            });

          // If profile creation fails, log warning but don't throw
          if (profileError) {
            console.warn('Profile creation warning:', profileError);
            // Don't throw - continue with signup
          } else {
            console.log(`⏰ New user timezone set: ${browserTimezone}`);
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
      {children}
    </AuthContext.Provider>
  )
}
