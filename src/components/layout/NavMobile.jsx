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
  Settings,
  GraduationCap,
  Rss,
  Play,
} from 'lucide-react';
import { useCourseContext } from '@/contexts/CourseContext';
import { Wordmark } from '@/components/revisop';
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

  // Course context for professors/admins
  const { teachingCourses, activeCourse, setActiveCourse, isContentCreator } = useCourseContext();

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
      case 'super_admin': return 'bg-amber-100 text-[#1e1b4b]';
      case 'admin': return 'bg-red-100 text-red-800';
      case 'professor': return 'bg-amber-100 text-[#1e1b4b]';
      default: return 'bg-green-100 text-green-800';
    }
  };

  return (
    <>
      {/* Mobile: Logo + Icons + Hamburger */}
      <div className="md:hidden flex items-center justify-between w-full">
        {/* Logo — shared <Wordmark /> (Sprint 6.2) */}
        <Link to="/dashboard" className="flex items-center gap-2">
          <Wordmark />
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
            
            <SheetContent side="right" className="w-[280px] sm:w-[320px] p-0 font-plex bg-rv-bg-1 text-rv-ink-900">
              
              {/* [FIX] Accessibility: Hidden Title & Description */}
              <SheetTitle className="sr-only">Navigation Menu</SheetTitle>
              <SheetDescription className="sr-only">
                Main menu for accessing dashboard, study tools, and profile settings.
              </SheetDescription>
              {/* [END FIX] */}

              <div className="flex flex-col h-full">
                {/* User Header */}
                <div className="p-4 border-b bg-rv-bg-2">
                  <div className="flex items-center gap-3">
                    <div className="h-10 w-10 rounded-full bg-rv-navy flex items-center justify-center text-white font-bold">
                      {getInitials()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-rv-ink-900 truncate">
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
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <LayoutDashboard className="h-5 w-5 text-rv-ink-400" />
                        <span className="text-sm font-medium text-rv-ink-900">Dashboard</span>
                      </button>

                      {/* Course Context Switcher — professors/admins with 2+ courses */}
                      {isContentCreator && teachingCourses.length > 1 && (
                        <>
                          <div className="px-4 py-2 mt-2">
                            <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                              <GraduationCap className="h-4 w-4" />
                              Course Context
                            </p>
                          </div>
                          {teachingCourses.map((course) => {
                            const name     = course.disciplines.name;
                            const isActive = name === activeCourse;
                            return (
                              <button
                                key={course.id}
                                onClick={() => {
                                  setActiveCourse(name);
                                  setOpen(false);
                                }}
                                className={`w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2 ${
                                  isActive ? 'bg-rv-navy-50' : ''
                                }`}
                              >
                                <span
                                  className={`h-2 w-2 rounded-full flex-shrink-0 ${
                                    isActive ? 'bg-rv-navy' : 'bg-rv-border-strong'
                                  }`}
                                />
                                <span className={`text-sm flex-1 ${isActive ? 'text-rv-navy font-medium' : 'text-rv-ink-600'}`}>
                                  {name}
                                </span>
                                {isActive && (
                                  <span className="text-[10px] font-medium text-rv-navy">Active</span>
                                )}
                                {course.is_primary && !isActive && (
                                  <span className="text-[10px] text-rv-ink-400">Primary</span>
                                )}
                              </button>
                            );
                          })}
                        </>
                      )}

                      {/* Study Section */}
                      <div className="px-4 py-2 mt-2">
                        <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                          <BookOpen className="h-4 w-4" />
                          Study
                        </p>
                      </div>
                      <button
                        onClick={() => handleNavClick('/dashboard/review-session')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Play className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Today's Reviews</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/review-flashcards')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <CreditCard className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Review Flashcards</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/notes')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <FileText className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Browse Notes</span>
                      </button>

                      {/* Create Section */}
                      <div className="px-4 py-2 mt-2">
                        <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                          <PenTool className="h-4 w-4" />
                          Create
                        </p>
                      </div>
                      <button
                        onClick={() => handleNavClick('/dashboard/notes/new')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <FileText className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Upload Note</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/flashcards/new')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <CreditCard className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Create Flashcard</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/bulk-upload')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Upload className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Bulk Upload</span>
                      </button>

                      {/* Groups Section */}
                      <div className="px-4 py-2 mt-2">
                        <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                          <Network className="h-4 w-4" />
                          Groups
                        </p>
                      </div>
                      <button
                        onClick={() => handleNavClick('/dashboard/groups')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Network className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Study Groups</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/following')}
                        className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Rss className="h-4 w-4 text-rv-ink-400" />
                        <span className="text-sm text-rv-ink-600">Following</span>
                      </button>

                      {/* Divider */}
                      <div className="my-2 border-t border-rv-border" />

                      {/* Profile Links */}
                      <button
                        onClick={() => handleNavClick('/dashboard/progress')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <BarChart3 className="h-5 w-5 text-rv-ink-400" />
                        <span className="text-sm font-medium text-rv-ink-900">My Progress</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/my-contributions')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Folder className="h-5 w-5 text-rv-ink-400" />
                        <span className="text-sm font-medium text-rv-ink-900">My Contributions</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/achievements')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Trophy className="h-5 w-5 text-rv-ink-400" />
                        <span className="text-sm font-medium text-rv-ink-900">My Achievements</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/help')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <HelpCircle className="h-5 w-5 text-rv-ink-400" />
                        <span className="text-sm font-medium text-rv-ink-900">Help & Guide</span>
                      </button>
                      <button
                        onClick={() => handleNavClick('/dashboard/settings')}
                        className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                      >
                        <Settings className="h-5 w-5 text-rv-ink-400" />
                        <span className="text-sm font-medium text-rv-ink-900">Settings</span>
                      </button>

                      {/* Professor Analytics — professor role only */}
                      {isProfessor && (
                        <>
                          <div className="my-2 border-t border-rv-border" />
                          <div className="px-4 py-2">
                            <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                              <BarChart3 className="h-4 w-4" />
                              Professor
                            </p>
                          </div>
                          <button
                            onClick={() => handleNavClick('/dashboard/professor-analytics')}
                            className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                          >
                            <BarChart3 className="h-4 w-4 text-rv-ink-400" />
                            <span className="text-sm text-rv-ink-600">Analytics</span>
                          </button>
                        </>
                      )}

                      {/* Admin: Analytics + Manage Topics */}
                      {(isAdmin || isSuperAdmin) && (
                        <>
                          <div className="my-2 border-t border-rv-border" />
                          <div className="px-4 py-2">
                            <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                              <BarChart3 className="h-4 w-4" />
                              Admin
                            </p>
                          </div>
                          <button
                            onClick={() => handleNavClick('/admin')}
                            className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                          >
                            <Shield className="h-4 w-4 text-rv-ink-400" />
                            <span className="text-sm text-rv-ink-600">Dashboard</span>
                          </button>
                          <button
                            onClick={() => handleNavClick('/admin/analytics')}
                            className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                          >
                            <BarChart3 className="h-4 w-4 text-rv-ink-400" />
                            <span className="text-sm text-rv-ink-600">Analytics</span>
                          </button>
                          <button
                            onClick={() => handleNavClick('/admin/bulk-upload-topics')}
                            className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                          >
                            <Upload className="h-4 w-4 text-rv-ink-400" />
                            <span className="text-sm text-rv-ink-600">Manage Topics</span>
                          </button>
                        </>
                      )}

                      {/* Super Admin */}
                      {isSuperAdmin && (
                        <>
                          <div className="my-2 border-t border-rv-border" />
                          <div className="px-4 py-2">
                            <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                              <Shield className="h-4 w-4" />
                              Super Admin
                            </p>
                          </div>
                          <button
                            onClick={() => handleNavClick('/super-admin')}
                            className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                          >
                            <Shield className="h-4 w-4 text-rv-amber" />
                            <span className="text-sm text-rv-ink-600">Dashboard</span>
                          </button>
                          <button
                            onClick={() => handleNavClick('/super-admin/analytics')}
                            className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                          >
                            <BarChart3 className="h-4 w-4 text-rv-amber" />
                            <span className="text-sm text-rv-ink-600">SA Analytics</span>
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