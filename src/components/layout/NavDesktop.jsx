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
} from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import FriendsDropdown from './FriendsDropdown';
import ActivityDropdown from './ActivityDropdown';
import ProfileDropdown from './ProfileDropdown';

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

  const isActive = (path) => location.pathname === path;

  const isStudyActive = () => {
    return location.pathname === '/dashboard/review-flashcards' ||
           location.pathname === '/dashboard/notes';
  };

  const isCreateActive = () => {
    return location.pathname === '/dashboard/notes/new' ||
           location.pathname === '/dashboard/flashcards/new' ||
           location.pathname === '/dashboard/bulk-upload';
  };

  return (
    <>
      {/* Left: Logo */}
      <div className="hidden md:flex md:items-center">
        <Link to="/dashboard" className="flex items-center gap-2">
          <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center shadow-sm">
            <span className="text-white font-bold text-lg">R</span>
          </div>
          <span className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            RECALL
          </span>
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
                px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                ${isActive('/dashboard')
                  ? 'bg-blue-50 text-blue-700'
                  : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
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
                    px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                    ${isStudyActive()
                      ? 'bg-blue-50 text-blue-700'
                      : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
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
                    px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                    ${isCreateActive()
                      ? 'bg-blue-50 text-blue-700'
                      : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
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
                {(isProfessor || isAdmin || isSuperAdmin) && (
                  <DropdownMenuItem asChild>
                    <Link to="/dashboard/bulk-upload" className="flex items-center gap-2 cursor-pointer">
                      <Upload className="h-4 w-4" />
                      Bulk Upload
                    </Link>
                  </DropdownMenuItem>
                )}
              </DropdownMenuContent>
            </DropdownMenu>

            {/* Groups */}
            <Link
              to="/dashboard/groups"
              className={`
                px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                ${isActive('/dashboard/groups') || location.pathname.startsWith('/dashboard/groups/')
                  ? 'bg-blue-50 text-blue-700'
                  : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                }
              `}
            >
              <Network className="h-4 w-4" />
              Groups
            </Link>

            {/* Super Admin Link */}
            {isSuperAdmin && (
              <Link
                to="/super-admin"
                className={`
                  px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                  ${isActive('/super-admin')
                    ? 'bg-blue-50 text-blue-700'
                    : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                  }
                `}
              >
                <Shield className="h-4 w-4" />
                Super Admin
              </Link>
            )}
          </>
        )}
      </div>

      {/* Right: Icons + Profile */}
      <div className="hidden md:flex md:items-center md:space-x-2">
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
