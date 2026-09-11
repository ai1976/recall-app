/**
 * NavDataContext.jsx
 *
 * One place that owns the three "nav data" hooks — role, notifications, pending
 * friend requests — so they run ONCE for the whole app instead of once per
 * consuming component.
 *
 * Before Sprint 7.0 the nav shell called useRole() / useNotifications(5) /
 * useFriendRequestCount() directly, and several pages (NoteDetail, MyFlashcards,
 * Help, the admin consoles, …) each called useRole() again — every instance its
 * own `profiles` + `role_permissions` fetch. Combined with the un-stabilised
 * `user` object in AuthContext (fixed in the same sprint) this produced the
 * Finding 5 over-fetch (`profiles` ×46, each nav RPC ×12 on one page load).
 *
 * Now: <NavDataProvider> (mounted once, above the router) runs each hook a single
 * time; the nav shell and every former useRole() consumer read this cheap
 * context. The realtime notification / friend-request subscriptions are owned by
 * the same single hook instance, so they are unaffected — one channel each, as
 * before.
 *
 * The `useRole` export here is a drop-in for `@/hooks/useRole` — same field
 * shape — so consumers only swap the import path.
 */

import { createContext, useContext, useMemo } from 'react'
import { useRole as useRoleHook } from '@/hooks/useRole'
import { useNotifications } from '@/hooks/useNotifications'
import { useFriendRequestCount } from '@/hooks/useFriendRequestCount'
import { useDueForecast } from '@/hooks/useDueForecast'

const NavDataContext = createContext(null)

export const NavDataProvider = ({ children }) => {
  const role = useRoleHook()
  const notif = useNotifications(5)
  const friends = useFriendRequestCount()
  // Sprint 7.2-F: the Review-tab due badge (+ 7.2-A's professor own-due-count)
  // read this ONE singleton call instead of each firing get_due_forecast itself.
  const due = useDueForecast()

  const value = useMemo(
    () => ({
      // ── role ──────────────────────────────────────────────
      role: role.role,
      permissions: role.permissions,
      isLoading: role.isLoading,
      isSuperAdmin: role.isSuperAdmin,
      isAdmin: role.isAdmin,
      isProfessor: role.isProfessor,
      isStudent: role.isStudent,
      hasPermission: role.hasPermission,
      refetchRole: role.refetch,
      // ── notifications ─────────────────────────────────────
      notifications: notif.notifications,
      unreadCount: notif.unreadCount,
      notifLoading: notif.loading,
      notifError: notif.error,
      markAllRead: notif.markAllRead,
      markOneRead: notif.markOneRead,
      deleteNotification: notif.deleteNotification,
      refetchNotifications: notif.refetch,
      // ── pending friend requests ───────────────────────────
      pendingCount: friends.pendingCount,
      friendLoading: friends.loading,
      refetchFriendCount: friends.refetch,
      // ── due forecast (get_due_forecast, one call/session) ──
      dueToday: due.dueToday,
      dueNext7: due.dueNext7,
      dueNext30: due.dueNext30,
      dueLoading: due.loading,
      refetchDueForecast: due.refetch,
    }),
    [role, notif, friends, due],
  )

  return <NavDataContext.Provider value={value}>{children}</NavDataContext.Provider>
}

/** Full nav-data bundle (role + notifications + friend requests). */
// eslint-disable-next-line react-refresh/only-export-components
export const useNavData = () => {
  const ctx = useContext(NavDataContext)
  if (!ctx) throw new Error('useNavData must be used within <NavDataProvider>')
  return ctx
}

/**
 * Drop-in replacement for `@/hooks/useRole` that reads the shared context instead
 * of firing its own `profiles` + `role_permissions` query. Same return shape.
 */
// eslint-disable-next-line react-refresh/only-export-components
export const useRole = () => {
  const c = useNavData()
  return {
    role: c.role,
    permissions: c.permissions,
    isLoading: c.isLoading,
    isSuperAdmin: c.isSuperAdmin,
    isAdmin: c.isAdmin,
    isProfessor: c.isProfessor,
    isStudent: c.isStudent,
    hasPermission: c.hasPermission,
    refetch: c.refetchRole,
  }
}
