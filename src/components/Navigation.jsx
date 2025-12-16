import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useRole } from '@/hooks/useRole';
import { Button } from '@/components/ui/button';
import {
  LayoutDashboard,
  BookOpen,
  PenTool,
  Shield,
  Users,
  LogOut,
  Menu,
  X,
  CreditCard,
  FileText,
  Upload,
  BarChart3,
  ChevronDown
} from 'lucide-react';
import { useState } from 'react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

export default function Navigation() {
  const { user, signOut } = useAuth();
  const { role, isSuperAdmin, isAdmin, isProfessor, isLoading } = useRole();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const isActive = (path) => {
    return location.pathname === path;
  };

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  if (!user) return null;

  // Check if any Study submenu item is active
  const isStudyActive = () => {
    return location.pathname === '/dashboard/flashcards' || 
           location.pathname === '/dashboard/notes' ||
           location.pathname === '/dashboard/progress';
  };

  // Check if any Create submenu item is active
  const isCreateActive = () => {
    return location.pathname === '/dashboard/notes/new' || 
           location.pathname === '/dashboard/flashcards/new' ||
           location.pathname === '/professor/tools' ||
           location.pathname === '/dashboard/my-contributions';
  };

  return (
    <>
      <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            {/* Logo */}
            <div className="flex items-center">
              <Link to="/dashboard" className="flex items-center gap-2">
                <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center shadow-sm">
                  <span className="text-white font-bold text-lg">R</span>
                </div>
                <span className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                  RECALL
                </span>
              </Link>
            </div>

            {/* Desktop Navigation */}
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
                    <DropdownMenuContent align="start" className="w-48">
                      <DropdownMenuItem asChild>
                        <Link to="/dashboard/flashcards" className="flex items-center gap-2 cursor-pointer">
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
                      <DropdownMenuItem asChild>
                        <Link to="/dashboard/progress" className="flex items-center gap-2 cursor-pointer">
                          <BarChart3 className="h-4 w-4" />
                          My Progress
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
                    <DropdownMenuContent align="start" className="w-48">
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
                        <Link to="/professor/tools" className="flex items-center gap-2 cursor-pointer">
                          <Upload className="h-4 w-4" />
                          Bulk Upload
                        </Link>
                      </DropdownMenuItem>
                      <DropdownMenuItem asChild>
                        <Link to="/dashboard/my-contributions" className="flex items-center gap-2 cursor-pointer">
                          <BarChart3 className="h-4 w-4" />
                          My Contributions
                        </Link>
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>

                  {/* Admin Dashboard (for admins only) */}
                  {isAdmin && !isSuperAdmin && (
                    <Link
                      to="/admin"
                      className={`
                        px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                        ${isActive('/admin')
                          ? 'bg-blue-50 text-blue-700'
                          : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                        }
                      `}
                    >
                      <Users className="h-4 w-4" />
                      Admin
                    </Link>
                  )}

                  {/* Super Admin Dashboard */}
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

            {/* Right side: Role badge + Sign out */}
            <div className="hidden md:flex md:items-center md:space-x-4">
              {!isLoading && role && (
                <span className={`
                  px-3 py-1 text-xs font-medium rounded-full
                  ${role === 'super_admin' ? 'bg-purple-100 text-purple-800' : ''}
                  ${role === 'admin' ? 'bg-red-100 text-red-800' : ''}
                  ${role === 'professor' ? 'bg-blue-100 text-blue-800' : ''}
                  ${role === 'student' ? 'bg-green-100 text-green-800' : ''}
                `}>
                  {role.replace('_', ' ')}
                </span>
              )}

              <Button
                variant="ghost"
                size="sm"
                onClick={handleSignOut}
                className="flex items-center gap-2"
              >
                <LogOut className="h-4 w-4" />
                Sign Out
              </Button>
            </div>

            {/* Mobile menu button */}
            <div className="md:hidden flex items-center">
              <button
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                className="inline-flex items-center justify-center p-2 rounded-md text-gray-700 hover:bg-gray-100"
              >
                {mobileMenuOpen ? (
                  <X className="h-6 w-6" />
                ) : (
                  <Menu className="h-6 w-6" />
                )}
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <div className="md:hidden border-t border-gray-200">
            <div className="px-2 pt-2 pb-3 space-y-1">
              {!isLoading && (
                <>
                  {/* Dashboard */}
                  <Link
                    to="/dashboard"
                    onClick={() => setMobileMenuOpen(false)}
                    className={`
                      block px-3 py-2 rounded-md text-base font-medium flex items-center gap-3
                      ${isActive('/dashboard')
                        ? 'bg-blue-50 text-blue-700'
                        : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                      }
                    `}
                  >
                    <LayoutDashboard className="h-5 w-5" />
                    Dashboard
                  </Link>

                  {/* Study Mode Section */}
                  <div className="pt-2 pb-1 px-3">
                    <div className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                      <BookOpen className="h-4 w-4" />
                      Study Mode
                    </div>
                  </div>
                  <Link
                    to="/dashboard/flashcards"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <CreditCard className="h-4 w-4" />
                    Review Flashcards
                  </Link>
                  <Link
                    to="/dashboard/notes"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <FileText className="h-4 w-4" />
                    Browse Notes
                  </Link>
                  <Link
                    to="/dashboard/progress"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <BarChart3 className="h-4 w-4" />
                    My Progress
                  </Link>

                  {/* Creator Mode Section */}
                  <div className="pt-2 pb-1 px-3">
                    <div className="text-xs font-semibold text-gray-500 uppercase tracking-wider flex items-center gap-2">
                      <PenTool className="h-4 w-4" />
                      Creator Mode
                    </div>
                  </div>
                  <Link
                    to="/dashboard/notes/new"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <FileText className="h-4 w-4" />
                    Upload Note
                  </Link>
                  <Link
                    to="/dashboard/flashcards/new"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <CreditCard className="h-4 w-4" />
                    Create Flashcard
                  </Link>
                  <Link
                    to="/professor/tools"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <Upload className="h-4 w-4" />
                    Bulk Upload
                  </Link>
                  <Link
                    to="/dashboard/my-contributions"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block px-6 py-2 rounded-md text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-3"
                  >
                    <BarChart3 className="h-4 w-4" />
                    My Contributions
                  </Link>

                  {/* Admin section */}
                  {isAdmin && !isSuperAdmin && (
                    <Link
                      to="/admin"
                      onClick={() => setMobileMenuOpen(false)}
                      className={`
                        block px-3 py-2 rounded-md text-base font-medium flex items-center gap-3 mt-2
                        ${isActive('/admin')
                          ? 'bg-blue-50 text-blue-700'
                          : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                        }
                      `}
                    >
                      <Users className="h-5 w-5" />
                      Admin Dashboard
                    </Link>
                  )}

                  {/* Super Admin section */}
                  {isSuperAdmin && (
                    <Link
                      to="/super-admin"
                      onClick={() => setMobileMenuOpen(false)}
                      className={`
                        block px-3 py-2 rounded-md text-base font-medium flex items-center gap-3 mt-2
                        ${isActive('/super-admin')
                          ? 'bg-blue-50 text-blue-700'
                          : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                        }
                      `}
                    >
                      <Shield className="h-5 w-5" />
                      Super Admin
                    </Link>
                  )}
                </>
              )}
            </div>

            {/* Mobile user info and sign out */}
            <div className="pt-4 pb-3 border-t border-gray-200">
              <div className="px-4 flex items-center justify-between">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <div className="h-10 w-10 rounded-full bg-blue-600 flex items-center justify-center text-white font-bold">
                      {user?.email?.charAt(0).toUpperCase()}
                    </div>
                  </div>
                  <div className="ml-3">
                    <div className="text-sm font-medium text-gray-800">
                      {user?.email}
                    </div>
                    {!isLoading && role && (
                      <div className="text-xs text-gray-500 mt-1">
                        {role.replace('_', ' ')}
                      </div>
                    )}
                  </div>
                </div>
              </div>
              <div className="mt-3 px-2">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleSignOut}
                  className="w-full justify-start"
                >
                  <LogOut className="h-4 w-4 mr-2" />
                  Sign Out
                </Button>
              </div>
            </div>
          </div>
        )}
      </nav>
    </>
  );
}