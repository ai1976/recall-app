import { Link, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Play,
  BookMarked,
  Plus,
  FileText,
  CreditCard,
  Upload,
  Timer,
  Network,
  BarChart3,
  Folder,
  Trophy,
  Flag,
  Shield,
} from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  isExact,
  isReviewRailActive,
  isMyStudyActive,
  isBrowseStudySetsActive,
  isBrowseNotesActive,
  isProgressActive,
  isMyContributionsActive,
  isReportHistoryActive,
  isAchievementsActive,
  isGroupsActive,
} from '@/lib/navActive';
import { Wordmark } from '@/components/revisop';
import NotificationCenter from './NotificationCenter';
import ProfileDropdown from './ProfileDropdown';
import CourseSwitcher from './CourseSwitcher';
import StudyTimerChip from './StudyTimerChip';
import ExamDateChip from './ExamDateChip';

/**
 * NavDesktop.jsx — desktop LEFT RAIL (Sprint 8.8.3, D-33 through D-38).
 *
 * Replaces the pre-8.8.3 horizontal top bar. Rendered only at md+ (`hidden
 * md:flex` on the root <aside>) — mobile's top bar/bottom tabs are untouched,
 * separate components. Fixed to the left edge; App.jsx pads authenticated
 * content with `md:pl-60` (rail width) to match.
 *
 * Three tiers, per D-33:
 *   Tier 1 — Home / Review / My Study (real routes, normal active styling)
 *   Tier 2 — the pinned "+" global action control (D-34): a <button>, never a
 *            route, never active-styled — see GlobalActionControl below
 *   Tier 3 — secondary sections: a temporary "Browse" group (Browse Study Sets
 *            / Browse Notes — retired when Discover ships, 8.8.5/D-36), then
 *            Personal, Community, and a role-conditional "Manage" group
 *
 * Non-route desktop chrome (Wordmark, NotificationCenter, ProfileDropdown,
 * CourseSwitcher, StudyTimerChip, ExamDateChip) all keep their existing
 * components/behavior — only their position moved, into the rail header/footer.
 */

const RAIL_LINK_BASE =
  'flex items-center gap-2.5 rounded-rec px-3 py-2 text-sm font-medium transition-colors';
const RAIL_LINK_ACTIVE = 'bg-rv-navy-50 text-rv-navy';
const RAIL_LINK_INACTIVE = 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900';

function RailLink({ to, active, icon, children, badge }) {
  const Icon = icon;
  return (
    <Link
      to={to}
      aria-current={active ? 'page' : undefined}
      className={`${RAIL_LINK_BASE} ${active ? RAIL_LINK_ACTIVE : RAIL_LINK_INACTIVE}`}
    >
      <Icon className="h-4 w-4 flex-shrink-0" />
      <span className="flex-1 truncate">{children}</span>
      {badge}
    </Link>
  );
}

function SectionLabel({ children }) {
  return (
    <p className="px-3 pb-1 pt-4 text-[11px] font-semibold uppercase tracking-wide text-rv-ink-400">
      {children}
    </p>
  );
}

/**
 * Tier 2 — pinned global action control (D-34).
 *
 * Binding rule (D-33/D-34, repeated in both places so neither sprint misses
 * it): a real <button> that opens a menu, icon-only "+", accessible name
 * "Add or log study activity" — never a <Link>/<NavLink>, never aria-current,
 * never route-active styling, never wired into navActive.js at all. Desktop
 * launcher membership is locked: Upload Note / Create Study Item / Bulk
 * Upload under "Create", Log Study Time under "Log". Create Group is
 * deliberately absent — reachable via Groups → MyGroups's own button instead.
 */
function GlobalActionControl() {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          aria-label="Add or log study activity"
          className="flex h-10 w-10 items-center justify-center rounded-rec bg-rv-navy text-white transition-colors hover:bg-rv-navy-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-rv-navy-400"
        >
          <Plus className="h-5 w-5" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-52">
        <DropdownMenuLabel className="text-xs text-rv-ink-400">Create</DropdownMenuLabel>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/notes/new" className="flex items-center gap-2 cursor-pointer">
            <FileText className="h-4 w-4" />
            Upload Note
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/flashcards/new" className="flex items-center gap-2 cursor-pointer">
            <CreditCard className="h-4 w-4" />
            Create Study Item
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/bulk-upload" className="flex items-center gap-2 cursor-pointer">
            <Upload className="h-4 w-4" />
            Bulk Upload
          </Link>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="text-xs text-rv-ink-400">Log</DropdownMenuLabel>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/study-time" className="flex items-center gap-2 cursor-pointer">
            <Timer className="h-4 w-4" />
            Log Study Time
          </Link>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

export default function NavDesktop({
  user,
  role,
  isSuperAdmin,
  isAdmin,
  isProfessor,
  isLoading,
  notifications,
  unreadCount,
  markAllRead,
  deleteNotification,
  refetchNotifications,
  pendingCount,
  dueToday,
  handleSignOut,
}) {
  const { pathname } = useLocation();
  const showManageSection = isProfessor || isAdmin || isSuperAdmin;

  return (
    <nav
      aria-label="Primary"
      className="hidden md:fixed md:inset-y-0 md:left-0 md:z-40 md:flex md:w-60 md:flex-col md:border-r md:border-rv-border md:bg-rv-bg-1 font-plex"
    >
      {/* Logo — unchanged target, shared <Wordmark /> */}
      <div className="flex h-16 flex-shrink-0 items-center border-b border-rv-border px-4">
        <Link to="/dashboard" className="flex items-center gap-2">
          <Wordmark />
        </Link>
      </div>

      {!isLoading && (
        <>
          {/* Tier 2 — global action control, pinned near the top, structurally
              separate from Tier 1 below it. */}
          <div className="flex-shrink-0 px-3 pt-3">
            <GlobalActionControl />
          </div>

          {/* Tier 1 — persistent primary destinations */}
          <div className="flex flex-shrink-0 flex-col gap-0.5 px-3 pt-3">
            <RailLink to="/dashboard" active={isExact(pathname, '/dashboard')} icon={LayoutDashboard}>
              Home
            </RailLink>
            <RailLink
              to="/dashboard/review-session"
              active={isReviewRailActive(pathname)}
              icon={Play}
              badge={
                dueToday > 0 && (
                  <span className="flex h-4 min-w-[16px] items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold leading-none text-white">
                    {dueToday > 9 ? '9+' : dueToday}
                  </span>
                )
              }
            >
              Review
            </RailLink>
            <RailLink to="/dashboard/my-cards" active={isMyStudyActive(pathname)} icon={BookMarked}>
              My Study
            </RailLink>
          </div>

          {/* Tier 3 — secondary sections, independently scrollable so a long
              Manage grouping never pushes the footer utilities off-screen. */}
          <div className="flex-1 overflow-y-auto pb-3">
            {/* Temporary Discover-dependency placement (D-36, sequencing
                correction): Browse Study Sets / Browse Notes stay live and
                reachable under their existing labels/routes/behavior until
                Sprint 8.8.5 ships Discover and retires this group. */}
            <SectionLabel>Browse</SectionLabel>
            <div className="flex flex-col gap-0.5 px-3">
              <RailLink
                to="/dashboard/review-flashcards"
                active={isBrowseStudySetsActive(pathname)}
                icon={CreditCard}
              >
                Browse Study Sets
              </RailLink>
              <RailLink to="/dashboard/notes" active={isBrowseNotesActive(pathname)} icon={FileText}>
                Browse Notes
              </RailLink>
            </div>

            <SectionLabel>Personal</SectionLabel>
            <div className="flex flex-col gap-0.5 px-3">
              <RailLink to="/dashboard/progress" active={isProgressActive(pathname)} icon={BarChart3}>
                Progress
              </RailLink>
              <RailLink
                to="/dashboard/my-contributions"
                active={isMyContributionsActive(pathname)}
                icon={Folder}
              >
                My Contributions
              </RailLink>
              <RailLink to="/dashboard/my-reports" active={isReportHistoryActive(pathname)} icon={Flag}>
                Report History
              </RailLink>
              <RailLink to="/dashboard/achievements" active={isAchievementsActive(pathname)} icon={Trophy}>
                Achievements
              </RailLink>
            </div>

            <SectionLabel>Community</SectionLabel>
            <div className="flex flex-col gap-0.5 px-3">
              <RailLink to="/dashboard/groups" active={isGroupsActive(pathname)} icon={Network}>
                Groups
              </RailLink>
            </div>

            {/* Role-conditional — one distinct "Manage"-style grouping (D-33/
                D-38), gated exactly as the old Manage dropdown + standalone
                Analytics link were: isProfessor / isAdmin||isSuperAdmin /
                isSuperAdmin. Visibility only — no change to route guards,
                RLS, or in-component access checks. */}
            {showManageSection && (
              <>
                <SectionLabel>Manage</SectionLabel>
                <div className="flex flex-col gap-0.5 px-3">
                  {isProfessor && (
                    <RailLink
                      to="/dashboard/professor-analytics"
                      active={isExact(pathname, '/dashboard/professor-analytics')}
                      icon={BarChart3}
                    >
                      Analytics
                    </RailLink>
                  )}
                  {(isAdmin || isSuperAdmin) && (
                    <>
                      <RailLink to="/admin" active={isExact(pathname, '/admin')} icon={Shield}>
                        Admin Dashboard
                      </RailLink>
                      <RailLink
                        to="/admin/analytics"
                        active={isExact(pathname, '/admin/analytics')}
                        icon={BarChart3}
                      >
                        Admin Analytics
                      </RailLink>
                      <RailLink
                        to="/admin/bulk-upload-topics"
                        active={isExact(pathname, '/admin/bulk-upload-topics')}
                        icon={Upload}
                      >
                        Manage Topics
                      </RailLink>
                    </>
                  )}
                  {isSuperAdmin && (
                    <>
                      <RailLink to="/super-admin" active={isExact(pathname, '/super-admin')} icon={Shield}>
                        Super Admin
                      </RailLink>
                      <RailLink
                        to="/super-admin/analytics"
                        active={isExact(pathname, '/super-admin/analytics')}
                        icon={BarChart3}
                      >
                        SA Analytics
                      </RailLink>
                    </>
                  )}
                </div>
              </>
            )}
          </div>
        </>
      )}

      {/* Utility footer — non-route desktop chrome, unchanged components,
          relocated from the old top bar's right-hand side. */}
      <div className="flex flex-shrink-0 flex-col gap-2 border-t border-rv-border px-3 py-3">
        {/* Course Context Switcher — professors/admins with 2+ courses only, self-gates */}
        <CourseSwitcher />

        <div className="flex flex-wrap items-center gap-2">
          {/* Manual study-timer indicator — hidden when not running */}
          <StudyTimerChip />
          {/* Exam date indicator — student-only, self-gates */}
          <ExamDateChip />
        </div>

        <div className="flex items-center justify-between">
          {/* Unified notification center — friend requests + content notifications */}
          <NotificationCenter
            notifications={notifications}
            unreadCount={unreadCount}
            markAllRead={markAllRead}
            deleteNotification={deleteNotification}
            refetch={refetchNotifications}
            pendingCount={pendingCount}
          />

          {/* Profile Dropdown — Profile Settings / Help & Guide live here, unchanged */}
          <ProfileDropdown user={user} role={role} isLoading={isLoading} handleSignOut={handleSignOut} />
        </div>
      </div>
    </nav>
  );
}
