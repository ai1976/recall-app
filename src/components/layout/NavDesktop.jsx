import { Link, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  BookOpen,
  PenTool,
  Shield,
  ChevronDown,
  CreditCard,
  FileText,
  Upload,
  Network,
  BarChart3,
  Play,
} from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  isExact,
  isCreateActive as isCreateActivePath,
  isStudyActive as isStudyActivePath,
  isManageActive as isManageActivePath,
  isGroupsActive as isGroupsActivePath,
} from '@/lib/navActive';
import { Wordmark } from '@/components/revisop';
import NotificationCenter from './NotificationCenter';
import ProfileDropdown from './ProfileDropdown';
import CourseSwitcher from './CourseSwitcher';

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
  const location = useLocation();

  // Active-route predicates now live in @/lib/navActive (Sprint 7.1) so NavDesktop
  // and NavBottomTabs share ONE implementation. Behaviour is byte-identical to the
  // previous inline helpers — the Sprint 6.0/6.2 nested-route tie-break is locked.
  const isActive = (path) => isExact(location.pathname, path);
  const isCreateActive = () => isCreateActivePath(location.pathname);
  const isStudyActive = () => isStudyActivePath(location.pathname);
  const isManageActive = () => isManageActivePath(location.pathname);

  return (
    <>
      {/* Left: Logo — shared <Wordmark /> (Sprint 6.2). Two-tone typographic mark,
          token-driven: identical amber/navy in light, 'Op' → accent in dark. */}
      <div className="hidden md:flex md:items-center">
        <Link to="/dashboard" className="flex items-center gap-2">
          <Wordmark />
        </Link>
      </div>

      {/* Center: Nav Links */}
      <div className="hidden md:flex md:items-center md:space-x-1">
        {!isLoading && (
          <>
            {/* Dashboard */}
            <Link
              to="/dashboard"
              className={`
                px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                ${isActive('/dashboard')
                  ? 'bg-rv-navy-50 text-rv-navy'
                  : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                }
              `}
            >
              <LayoutDashboard className="h-4 w-4" />
              Dashboard
            </Link>

            {/* Study Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button
                  className={`
                    relative px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                    ${isStudyActive()
                      ? 'bg-rv-navy-50 text-rv-navy'
                      : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                    }
                  `}
                >
                  <BookOpen className="h-4 w-4" />
                  Study
                  <ChevronDown className="h-3 w-3" />
                  {/* Due-count badge — desktop counterpart to the mobile Review-tab
                      pill (7.2-F), added for consistency: same solid red/white as
                      the notification/friend badges, hidden at 0, capped "9+". */}
                  {dueToday > 0 && (
                    <span className="absolute -right-1.5 -top-1.5 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold leading-none text-white">
                      {dueToday > 9 ? '9+' : dueToday}
                    </span>
                  )}
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="center" className="w-48">
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/review-session" className="flex items-center justify-between gap-2 cursor-pointer">
                    <span className="flex items-center gap-2">
                      <Play className="h-4 w-4" />
                      Today's Reviews
                    </span>
                    {dueToday > 0 && (
                      <span className="flex h-4 min-w-[16px] items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold leading-none text-white">
                        {dueToday > 9 ? '9+' : dueToday}
                      </span>
                    )}
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/review-flashcards" className="flex items-center gap-2 cursor-pointer">
                    <CreditCard className="h-4 w-4" />
                    Review Flashcards
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/notes" className="flex items-center gap-2 cursor-pointer">
                    <FileText className="h-4 w-4" />
                    Browse Notes
                  </Link>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Create Dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button
                  className={`
                    px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                    ${isCreateActive()
                      ? 'bg-rv-navy-50 text-rv-navy'
                      : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                    }
                  `}
                >
                  <PenTool className="h-4 w-4" />
                  Create
                  <ChevronDown className="h-3 w-3" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="center" className="w-48">
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/notes/new" className="flex items-center gap-2 cursor-pointer">
                    <FileText className="h-4 w-4" />
                    Upload Note
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/flashcards/new" className="flex items-center gap-2 cursor-pointer">
                    <CreditCard className="h-4 w-4" />
                    Create Flashcard
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/bulk-upload" className="flex items-center gap-2 cursor-pointer">
                    <Upload className="h-4 w-4" />
                    Bulk Upload
                  </Link>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Groups */}
            <Link
              to="/dashboard/groups"
              className={`
                px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                ${isGroupsActivePath(location.pathname)
                  ? 'bg-rv-navy-50 text-rv-navy'
                  : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                }
              `}
            >
              <Network className="h-4 w-4" />
              Groups
            </Link>

            {/* Professor Analytics — professor role only (admins/super_admins have their own dashboards) */}
            {isProfessor && (
              <Link
                to="/dashboard/professor-analytics"
                className={`
                  px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                  ${isActive('/dashboard/professor-analytics')
                    ? 'bg-rv-navy-50 text-rv-navy'
                    : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                  }
                `}
              >
                <BarChart3 className="h-4 w-4" />
                Analytics
              </Link>
            )}

            {/* Manage Dropdown — admin and super_admin only */}
            {(isAdmin || isSuperAdmin) && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <button
                    className={`
                      px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                      ${isManageActive()
                        ? 'bg-rv-navy-50 text-rv-navy'
                        : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                      }
                    `}
                  >
                    <Shield className="h-4 w-4" />
                    Manage
                    <ChevronDown className="h-3 w-3" />
                  </button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="center" className="w-52">
                  <DropdownMenuItem asChild>
                    <Link to="/admin" className="flex items-center gap-2 cursor-pointer">
                      <Shield className="h-4 w-4" />
                      Admin Dashboard
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link to="/admin/analytics" className="flex items-center gap-2 cursor-pointer">
                      <BarChart3 className="h-4 w-4" />
                      Admin Analytics
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link to="/admin/bulk-upload-topics" className="flex items-center gap-2 cursor-pointer">
                      <Upload className="h-4 w-4" />
                      Manage Topics
                    </Link>
                  </DropdownMenuItem>
                  {isSuperAdmin && (
                    <>
                      <DropdownMenuItem asChild>
                        <Link to="/super-admin" className="flex items-center gap-2 cursor-pointer">
                          <Shield className="h-4 w-4" />
                          Super Admin
                        </Link>
                      </DropdownMenuItem>
                      <DropdownMenuItem asChild>
                        <Link to="/super-admin/analytics" className="flex items-center gap-2 cursor-pointer">
                          <BarChart3 className="h-4 w-4" />
                          SA Analytics
                        </Link>
                      </DropdownMenuItem>
                    </>
                  )}
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </>
        )}
      </div>

      {/* Right: Course Switcher + Icons + Profile */}
      <div className="hidden md:flex md:items-center md:space-x-2">
        {/* Course Context Switcher — professors/admins with 2+ courses only */}
        <CourseSwitcher />

        {/* Unified notification center (Sprint 7.2-B) — friend requests +
            content notifications, one bell, one badge. */}
        <NotificationCenter
          notifications={notifications}
          unreadCount={unreadCount}
          markAllRead={markAllRead}
          deleteNotification={deleteNotification}
          refetch={refetchNotifications}
          pendingCount={pendingCount}
        />

        {/* Profile Dropdown */}
        <ProfileDropdown
          user={user}
          role={role}
          isLoading={isLoading}
          handleSignOut={handleSignOut}
        />
      </div>
    </>
  );
}
