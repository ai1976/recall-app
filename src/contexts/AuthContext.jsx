import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase';

const AuthContext = createContext({})

// Session-scoped guard: the timezone sync fired on every getSession resolve AND
// every SIGNED_IN event (supabase-js re-emits SIGNED_IN on each tab focus), so it
// ran — and its "already set" branch logged — dozens of times per page. It only
// needs to run once per page load: the browser timezone doesn't change mid-session.
// Sprint 6.5 gated the log; Sprint 7.0 (7.0-A) gates the whole function → at most
// one profiles read per session. Reset on a hard reload (module re-eval).
let tzSyncedThisSession = false

// Sprint 8.8.5b (bug #4) — password-recovery guard. Opening a Supabase recovery link signs
// the user IN before they have chosen a new password. If that lands anywhere other than
// /reset-password (e.g. the Site URL "/", which redirects an authed user to /dashboard), the
// student sees the full logged-in app without ever resetting — and then can't log in with
// the "new" password they never set (Rujuta Bhatwadekar, 29/09/2026). The flag below marks
// the session as recovery-only until ResetPassword completes or abandons it. It is set from
// the URL synchronously (so there is no dashboard flash) and from the PASSWORD_RECOVERY
// event (covers any flow that does not leave type=recovery in the URL). sessionStorage, not
// localStorage: it must survive a reload of the same tab but not leak into a later visit.
const RECOVERY_KEY = 'revisop_password_recovery'

const readRecoveryFlag = () => {
  try {
    if (sessionStorage.getItem(RECOVERY_KEY) === '1') return true
    const fromUrl = /[#&?]type=recovery(&|$)/.test(window.location.hash + window.location.search)
    if (fromUrl) sessionStorage.setItem(RECOVERY_KEY, '1')
    return fromUrl
  } catch {
    return false
  }
}

// Evaluated once at module load — synchronously, in the same task that creates the Supabase
// client — so the URL is read BEFORE supabase-js finishes processing and strips the hash.
// Reading it lazily inside React's first render can lose that race.
readRecoveryFlag()

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthContext)

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [recoveryMode, setRecoveryMode] = useState(readRecoveryFlag)

  const clearRecoveryMode = () => {
    try { sessionStorage.removeItem(RECOVERY_KEY) } catch { /* storage unavailable */ }
    setRecoveryMode(false)
  }

  // ============================================================
  // HELPER: Update user's timezone in profiles table
  // Detects browser timezone and syncs to database if different
  // ============================================================
  const updateUserTimezone = async (userId) => {
    // Run at most once per page load — see tzSyncedThisSession note above. Set the
    // flag synchronously (before the first await) so a getSession resolve and a
    // SIGNED_IN event firing in the same tick can't both start a read.
    if (tzSyncedThisSession) return;
    tzSyncedThisSession = true;
    try {
      // Get browser's IANA timezone (e.g., 'Asia/Kolkata', 'America/New_York')
      const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

      if (!browserTimezone) {
        console.log('⏰ Could not detect browser timezone');
        tzSyncedThisSession = false; // nothing synced — allow a later retry
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
        tzSyncedThisSession = false; // read failed — allow a later retry
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
      tzSyncedThisSession = false;
      console.warn('⏰ Timezone sync error:', error);
    }
  };

  useEffect(() => {
    // Stabilise the user object reference. supabase-js calls back on every auth
    // event — INITIAL_SESSION, SIGNED_IN (re-emitted on each tab focus),
    // TOKEN_REFRESHED — and `session.user` is a fresh object every time. Setting
    // it unconditionally changed `user`'s identity on every event, so every
    // downstream `[user]` effect (useRole, useNotifications, useFriendRequestCount,
    // CourseContext, useActivityFeed, …) re-fired — the ~12× nav/RPC over-fetch in
    // Finding 5, and the churn that let the auth-init race in Finding 6 keep
    // landing. Only replace `user` when the id actually changes; a functional
    // updater returning the previous reference makes React bail the re-render.
    // Sprint 7.0 (7.0-A / 7.0-B).
    const applySession = (session) => {
      const nextUser = session?.user ?? null
      setUser((prev) => (prev?.id === nextUser?.id ? prev : nextUser))
      setLoading(false)
      if (nextUser) updateUserTimezone(nextUser.id)
    }

    // Check active sessions — .catch() ensures loading resolves even if Supabase is unreachable
    supabase.auth.getSession()
      .then(({ data: { session } }) => applySession(session))
      .catch(() => {
        // Network error — treat as logged out so the app doesn't spin forever
        setUser((prev) => (prev === null ? prev : null))
        setLoading(false)
      })

    // Listen for auth changes. applySession no-ops the state update when the user
    // id is unchanged, so TOKEN_REFRESHED / repeat SIGNED_IN events cost nothing.
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY') {
        try { sessionStorage.setItem(RECOVERY_KEY, '1') } catch { /* storage unavailable */ }
        setRecoveryMode(true)
      }
      // A signed-out session can never still be "in recovery".
      if (event === 'SIGNED_OUT') {
        try { sessionStorage.removeItem(RECOVERY_KEY) } catch { /* storage unavailable */ }
        setRecoveryMode(false)
      }
      applySession(session)
    })

    return () => subscription.unsubscribe()
  }, [])

  const value = {
    user,
    loading,
    recoveryMode,
    clearRecoveryMode,
    // 🆕 ENHANCED: Sign in with AUDIT LOGGING for admin/super_admin
   signIn: async (email, password) => {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) throw error;

    // A deliberate password login can never be a recovery session — drop any stale flag
    // left by an abandoned reset link in this tab.
    clearRecoveryMode();

    // Log admin/super_admin logins for security audit
    if (data.user) {
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .single();

      if (!profileError && profile && ['admin', 'super_admin'].includes(profile.role)) {
        // Server-authored audit entry (log_admin_event forces admin_id = the caller) — Sprint 8.8.5b4, D-48.
        const { error: logError } = await supabase.rpc('log_admin_event', {
          p_action: 'admin_login',
          p_details: {
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
        // Profile is created by DB trigger (trg_create_profile_on_signup) on auth.users INSERT.
        // Client-side insert was removed — it always fails during email-confirmation flow
        // (no session = auth.uid() is null, so RLS blocks it silently).
        // Timezone is synced on first login via updateUserTimezone().
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
