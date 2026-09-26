import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
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
  Flag,
} from 'lucide-react';
import { useCourseContext } from '@/contexts/CourseContext';
import { Button } from '@/components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetTrigger,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';

/**
 * NavMenuSheet — the mobile "everything else" drawer.
 *
 * Sprint 8.8.4 (D-33/D-37/D-38) rebuilt this drawer's contents: Today's
 * Reviews and My Study were removed (both are now persistent bottom-bar
 * destinations — Review, My Study); Browse Study Sets/Browse Notes moved into
 * a temporary "Browse" group (D-36, retired when Discover ships in 8.8.5);
 * the Groups section was renamed "Community" and keeps Following's
 * mobile-specific second entry point (D-33's Following exception) alongside
 * Groups; Progress/My Contributions/Achievements/Report History gained an
 * explicit "Personal" heading; the three separate role-conditional sections
 * were consolidated into one "Manage" heading, mirroring the desktop rail
 * (8.8.3), each item still individually gated by its existing role flag.
 *
 * The trigger renders as a bottom-bar tab (icon + label, ≥48px target); it shows
 * the active treatment while the sheet is open. Per D-33, it does not receive
 * aria-current — its accessible state is the button/sheet relationship
 * (Radix Dialog.Trigger already wires aria-expanded/aria-controls).
 */
export default function NavMenuSheet({
  user,
  role,
  isSuperAdmin,
  isAdmin,
  isProfessor,
  isLoading,
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
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <button
          type="button"
          aria-label="Open menu"
          className={`flex flex-1 flex-col items-center justify-center gap-0.5 min-h-[48px] border-t-2 px-1 text-[11px] font-medium transition-colors ${
            open
              ? 'border-rv-navy text-rv-navy'
              : 'border-transparent text-rv-ink-400 hover:text-rv-ink-900'
          }`}
        >
          <Menu className="h-5 w-5" />
          <span>Menu</span>
        </button>
      </SheetTrigger>

      <SheetContent side="right" className="w-[280px] sm:w-[320px] p-0 font-plex bg-rv-bg-1 text-rv-ink-900">

        {/* Accessibility: Hidden Title & Description */}
        <SheetTitle className="sr-only">Navigation Menu</SheetTitle>
        <SheetDescription className="sr-only">
          Main menu for accessing dashboard, study tools, and profile settings.
        </SheetDescription>

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

                {/* Browse Section — temporary, Discover-dependency (D-36).
                    Today's Reviews and My Study were removed here in 8.8.4:
                    both are now persistent bottom-bar destinations (Review,
                    My Study), so the Menu copies were redundant (D-33). */}
                <div className="px-4 py-2 mt-2">
                  <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                    <BookOpen className="h-4 w-4" />
                    Browse
                  </p>
                </div>
                <button
                  onClick={() => handleNavClick('/dashboard/review-flashcards')}
                  className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                >
                  <CreditCard className="h-4 w-4 text-rv-ink-400" />
                  <span className="text-sm text-rv-ink-600">Browse Study Sets</span>
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
                  <span className="text-sm text-rv-ink-600">Create Study Item</span>
                </button>
                <button
                  onClick={() => handleNavClick('/dashboard/bulk-upload')}
                  className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                >
                  <Upload className="h-4 w-4 text-rv-ink-400" />
                  <span className="text-sm text-rv-ink-600">Bulk Upload</span>
                </button>

                {/* Community Section — renamed from "Groups" in 8.8.4 (D-33).
                    Following keeps its mobile-specific second entry point
                    here (alongside NotificationCenter's bell) — the D-33
                    exception is explicit that this is not a duplicate to
                    remove, unlike the Groups/Study Groups label collision. */}
                <div className="px-4 py-2 mt-2">
                  <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                    <Network className="h-4 w-4" />
                    Community
                  </p>
                </div>
                <button
                  onClick={() => handleNavClick('/dashboard/groups')}
                  className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                >
                  <Network className="h-4 w-4 text-rv-ink-400" />
                  <span className="text-sm text-rv-ink-600">Groups</span>
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

                {/* Personal Section */}
                <div className="px-4 py-2">
                  <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                    <BarChart3 className="h-4 w-4" />
                    Personal
                  </p>
                </div>
                <button
                  onClick={() => handleNavClick('/dashboard/progress')}
                  className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                >
                  <BarChart3 className="h-5 w-5 text-rv-ink-400" />
                  <span className="text-sm font-medium text-rv-ink-900">Progress</span>
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
                  onClick={() => handleNavClick('/dashboard/my-reports')}
                  className="w-full px-4 py-3 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                >
                  <Flag className="h-5 w-5 text-rv-ink-400" />
                  <span className="text-sm font-medium text-rv-ink-900">Report History</span>
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

                {/* Manage — one consolidated role-conditional section (8.8.4,
                    D-33/D-38), mirroring the desktop rail's single "Manage"
                    Tier-3 grouping (8.8.3) instead of three separate headed
                    sections. Visibility only — each item still individually
                    gated by its existing role flag; no change to route
                    guards, RLS, or in-component access checks. Labels match
                    the desktop rail's exactly (e.g. "Admin Dashboard" /
                    "Super Admin" rather than a bare "Dashboard" repeated
                    across roles) since two items sharing one label would be
                    ambiguous once merged into a single flat section. */}
                {(isProfessor || isAdmin || isSuperAdmin) && (
                  <>
                    <div className="my-2 border-t border-rv-border" />
                    <div className="px-4 py-2">
                      <p className="text-xs font-semibold text-rv-ink-400 uppercase tracking-wider flex items-center gap-2">
                        <Shield className="h-4 w-4" />
                        Manage
                      </p>
                    </div>
                  </>
                )}
                {isProfessor && (
                  <button
                    onClick={() => handleNavClick('/dashboard/professor-analytics')}
                    className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                  >
                    <BarChart3 className="h-4 w-4 text-rv-ink-400" />
                    <span className="text-sm text-rv-ink-600">Analytics</span>
                  </button>
                )}
                {(isAdmin || isSuperAdmin) && (
                  <>
                    <button
                      onClick={() => handleNavClick('/admin')}
                      className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                    >
                      <Shield className="h-4 w-4 text-rv-ink-400" />
                      <span className="text-sm text-rv-ink-600">Admin Dashboard</span>
                    </button>
                    <button
                      onClick={() => handleNavClick('/admin/analytics')}
                      className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                    >
                      <BarChart3 className="h-4 w-4 text-rv-ink-400" />
                      <span className="text-sm text-rv-ink-600">Admin Analytics</span>
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
                {isSuperAdmin && (
                  <>
                    <button
                      onClick={() => handleNavClick('/super-admin')}
                      className="w-full px-6 py-2 text-left flex items-center gap-3 hover:bg-rv-bg-2"
                    >
                      <Shield className="h-4 w-4 text-rv-amber" />
                      <span className="text-sm text-rv-ink-600">Super Admin</span>
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
  );
}
