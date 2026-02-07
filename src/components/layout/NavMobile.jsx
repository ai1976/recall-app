import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  BookOpen,
  PenTool,
  Shield,
  Menu,
  CreditCard,
  FileText,
  Upload,
  BarChart3,
  Trophy,
  LogOut,
  Folder,
  Network,
  HelpCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetTrigger,
  SheetTitle,        // [ADDED] Import Title
  SheetDescription   // [ADDED] Import Description
} from '@/components/ui/sheet';
import FriendsDropdown from './FriendsDropdown';
import ActivityDropdown from './ActivityDropdown';

export default function NavMobile({
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
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();

  // Navigate and close sheet
  const handleNavClick = (path) => {
    setOpen(false);
    navigate(path);
  };

  // Get user initials for avatar
  const getInitials = () => {
    if (user?.user_metadata?.full_name) {
      return user.user_metadata.full_name.charAt(0).toUpperCase();
    }
    return user?.email?.charAt(0).toUpperCase() || 'U';
  };

  // Get role badge color
  const getRoleBadgeClass = () => {
    switch (role) {
      case 'super_admin': return 'bg-purple-100 text-purple-800';
      case 'admin': return 'bg-red-100 text-red-800';
      case 'professor': return 'bg-blue-100 text-blue-800';
      default: return 'bg-green-100 text-green-800';
    }
  };

  return (
    <>
      {/* Mobile: Logo + Icons + Hamburger */}
      <div className="md:hidden flex items-center justify-between w-full">
        {/* Logo - smaller on mobile */}
        <Link to="/dashboard" className="flex items-center gap-2">
          <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center shadow-sm">
            <span className="text-white font-bold text-lg">R</span>
          </div>
          <span className="hidden sm:block text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            RECALL
          </span>
        </Link>

        {/* Right side icons */}
        <div className="flex items-center space-x-1">
          {/* Friends Icon */}
          <FriendsDropdown pendingCount={pendingCount} />

          {/* Bell Icon */}
          <ActivityDropdown
            notifications={notifications}
            unreadCount={unreadCount}
            markAllRead={markAllRead}
            deleteNotification={deleteNotification}
            refetch={refetchNotifications}
          />

          {/* Hamburger Menu */}
          <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" className="h-10 w-10">
                <Menu className="h-5 w-5" />
              </Button>
            </SheetTrigger>
            
            <SheetContent side="right" className="w-[280px] sm:w-[320px] p-0">
              
              {/* [FIX] Accessibility: Hidden Title & Description */}
              <SheetTitle className="sr-only">Navigation Menu</SheetTitle>
              <SheetDescription className="sr-only">
                Main menu for accessing dashboard, study tools, and profile settings.
              </SheetDescription>
              {/* [END FIX] */}

              <div className="flex flex-col h-full">
                {/* User Header */}
                <div className="p-4 border-b bg-gray-50">
                  <div className="flex items-center gap-3">
                    <div className="h-10 w-10 rounded-full bg-blue-600 flex items-center justify-center text-white font-bold">
                      {getInitials()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">
                        {user?.user_metadata?.full_name || user?.email}
                      </p>
                      {!isLoading && role && (
                        <span className={`inline-block mt-1 px-2 py-0.5 text-xs font-medium rounded-full ${getRoleBadgeClass()}`}>
                          {role.replace('_', ' ')}
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Navigation Links */}
                <div className="flex-1 overflow-y-auto py-2">
                  {!isLoading && (
                    <>
                      {/* Dashboard */}
                      <button
                        onClick={() => handleNavClick('/dashboard')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <LayoutDashboard className="h-5 w-5 text-gray-500" />
                        <span className="text-sm font-medium text-gray-900">Dashboard</span>
                      </button>

                      {/* Study Section */}
                      <div className="px-4 py-2 mt-2">
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                          <BookOpen className="h-4 w-4" />
                          Study
                        </p>
                      </div>
                      <button
                        onClick={() => handleNavClick('/dashboard/review-flashcards')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <CreditCard className="h-4 w-4 text-gray-400" />
                        <span className="text-sm text-gray-700">Review Flashcards</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/notes')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <FileText className="h-4 w-4 text-gray-400" />
                        <span className="text-sm text-gray-700">Browse Notes</span>
                      </button>

                      {/* Create Section */}
                      <div className="px-4 py-2 mt-2">
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                          <PenTool className="h-4 w-4" />
                          Create
                        </p>
                      </div>
                      <button
                        onClick={() => handleNavClick('/dashboard/notes/new')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <FileText className="h-4 w-4 text-gray-400" />
                        <span className="text-sm text-gray-700">Upload Note</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/flashcards/new')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <CreditCard className="h-4 w-4 text-gray-400" />
                        <span className="text-sm text-gray-700">Create Flashcard</span>
                      </button>
                      {(isProfessor || isAdmin || isSuperAdmin) && (
                        <button
                          onClick={() => handleNavClick('/dashboard/bulk-upload')}
                          className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-gray-50"
                        >
                          <Upload className="h-4 w-4 text-gray-400" />
                          <span className="text-sm text-gray-700">Bulk Upload</span>
                        </button>
                      )}

                      {/* Groups Section */}
                      <div className="px-4 py-2 mt-2">
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                          <Network className="h-4 w-4" />
                          Groups
                        </p>
                      </div>
                      <button
                        onClick={() => handleNavClick('/dashboard/groups')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <Network className="h-4 w-4 text-gray-400" />
                        <span className="text-sm text-gray-700">Study Groups</span>
                      </button>

                      {/* Divider */}
                      <div className="my-2 border-t border-gray-200" />

                      {/* Profile Links */}
                      <button
                        onClick={() => handleNavClick('/dashboard/progress')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <BarChart3 className="h-5 w-5 text-gray-500" />
                        <span className="text-sm font-medium text-gray-900">My Progress</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/my-contributions')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <Folder className="h-5 w-5 text-gray-500" />
                        <span className="text-sm font-medium text-gray-900">My Contributions</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/achievements')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <Trophy className="h-5 w-5 text-gray-500" />
                        <span className="text-sm font-medium text-gray-900">My Achievements</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/help')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-gray-50"
                      >
                        <HelpCircle className="h-5 w-5 text-gray-500" />
                        <span className="text-sm font-medium text-gray-900">Help & Guide</span>
                      </button>

                      {/* Super Admin */}
                      {isSuperAdmin && (
                        <>
                          <div className="my-2 border-t border-gray-200" />
                          <button
                            onClick={() => handleNavClick('/super-admin')}
                            className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-gray-50"
                          >
                            <Shield className="h-5 w-5 text-purple-500" />
                            <span className="text-sm font-medium text-gray-900">Super Admin</span>
                          </button>
                        </>
                      )}
                    </>
                  )}
                </div>

                {/* Sign Out at bottom */}
                <div className="p-4 border-t">
                  <Button
                    variant="ghost"
                    className="w-full justify-start text-red-600 hover:text-red-700 hover:bg-red-50"
                    onClick={() => {
                      setOpen(false);
                      handleSignOut();
                    }}
                  >
                    <LogOut className="h-4 w-4 mr-2" />
                    Sign Out
                  </Button>
                </div>
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </>
  );
}