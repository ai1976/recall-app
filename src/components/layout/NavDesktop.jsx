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
import { Wordmark } from '@/components/revisop';
import FriendsDropdown from './FriendsDropdown';
import ActivityDropdown from './ActivityDropdown';
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
  handleSignOut,
}) {
  const location = useLocation();

  // Exact match — only for the top-level Dashboard link (every route lives under /dashboard).
  const isActive = (path) => location.pathname === path;

  // Prefix match — a route is "under" `path` when it equals it or is nested beneath it.
  // Keeps the parent nav item highlighted on nested routes (e.g. /dashboard/notes/:id).
  const underAny = (paths) =>
    paths.some((p) => location.pathname === p || location.pathname.startsWith(p + '/'));

  // Create routes are nested under /dashboard/notes and /dashboard/flashcards, so Create must
  // win the tie against Study's broader prefixes.
  const isCreateActive = () =>
    underAny([
      '/dashboard/notes/new',
      '/dashboard/flashcards/new',
      '/dashboard/bulk-upload',
    ]);

  const isStudyActive = () =>
    !isCreateActive() &&
    underAny([
      '/dashboard/review-flashcards',
      '/dashboard/review-session',
      '/dashboard/review-by-subject',
      '/dashboard/study',
      '/dashboard/notes',       // Browse Notes + note detail/edit
      '/dashboard/flashcards',  // My Flashcards + card detail/edit
      '/dashboard/progress',
    ]);

  const isManageActive = () => {
    return location.pathname.startsWith('/admin') ||
           location.pathname.startsWith('/super-admin');
  };

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
                    px-3 py-2 rounded-rec text-sm font-medium flex items-center gap-2
                    ${isStudyActive()
                      ? 'bg-rv-navy-50 text-rv-navy'
                      : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                    }
                  `}
                >
                  <BookOpen className="h-4 w-4" />
                  Study
                  <ChevronDown className="h-3 w-3" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="center" className="w-48">
                <DropdownMenuItem asChild>
                  <Link to="/dashboard/review-session" className="flex items-center gap-2 cursor-pointer">
                    <Play className="h-4 w-4" />
                    Today's Reviews
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
                ${isActive('/dashboard/groups') || location.pathname.startsWith('/dashboard/groups/')
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

        {/* Friends Icon with Dropdown */}
        <FriendsDropdown pendingCount={pendingCount} />

        {/* Bell Icon with Dropdown */}
        <ActivityDropdown
          notifications={notifications}
          unreadCount={unreadCount}
          markAllRead={markAllRead}
          deleteNotification={deleteNotification}
          refetch={refetchNotifications}
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
