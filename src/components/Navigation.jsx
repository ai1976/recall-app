import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useRole } from '@/hooks/useRole';
import { Button } from '@/components/ui/button';
import {
  LayoutDashboard,
  FileText,
  CreditCard,
  Shield,
  Users,
  Upload,
  LogOut,
  Menu,
  X
} from 'lucide-react';
import { useState } from 'react';

export default function Navigation() {
  const { user, signOut } = useAuth();
  const { role, isSuperAdmin, isAdmin, isProfessor, isLoading } = useRole();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const getNavItems = () => {
    const baseItems = [
  {
    name: 'Dashboard',
    path: '/dashboard',
    icon: LayoutDashboard,
    roles: ['student', 'professor', 'admin', 'super_admin']
  },
  {
    name: 'My Notes',
    path: '/dashboard/notes/new',
    icon: FileText,
    roles: ['student', 'professor', 'admin', 'super_admin']
  },
  {
    name: 'Flashcards',
    path: '/dashboard/flashcards',
    icon: CreditCard,
    roles: ['student', 'professor', 'admin', 'super_admin']
  }
];

    const professorItems = [
  {
    name: 'Bulk Upload',
    path: '/professor/tools',
    icon: Upload,
    roles: ['student', 'professor', 'admin', 'super_admin']  // All users now!
  }
];

    const adminItems = [
      {
        name: 'Admin Dashboard',
        path: '/admin',
        icon: Users,
        roles: ['admin']
      }
    ];

    const superAdminItems = [
      {
        name: 'Super Admin',
        path: '/super-admin',
        icon: Shield,
        roles: ['super_admin']
      }
    ];

    let allItems = [...baseItems];

    if (isProfessor || isAdmin || isSuperAdmin) {
      allItems = [...allItems, ...professorItems];
    }

    if (isAdmin && !isSuperAdmin) {
      allItems = [...allItems, ...adminItems];
    }

    if (isSuperAdmin) {
      allItems = [...allItems, ...superAdminItems];
    }

    return allItems;
  };

  const navItems = getNavItems();

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

  return (
    <>
      <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <Link to="/dashboard" className="flex items-center">
                <span className="text-2xl font-bold text-blue-600">Recall</span>
              </Link>
            </div>

            <div className="hidden md:flex md:items-center md:space-x-1">
              {!isLoading && navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`
                      px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2
                      ${isActive(item.path)
                        ? 'bg-blue-50 text-blue-700'
                        : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                      }
                    `}
                  >
                    <Icon className="h-4 w-4" />
                    {item.name}
                  </Link>
                );
              })}
            </div>

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

        {mobileMenuOpen && (
          <div className="md:hidden border-t border-gray-200">
            <div className="px-2 pt-2 pb-3 space-y-1">
              {!isLoading && navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    onClick={() => setMobileMenuOpen(false)}
                    className={`
                      block px-3 py-2 rounded-md text-base font-medium flex items-center gap-3
                      ${isActive(item.path)
                        ? 'bg-blue-50 text-blue-700'
                        : 'text-gray-700 hover:bg-gray-50 hover:text-gray-900'
                      }
                    `}
                  >
                    <Icon className="h-5 w-5" />
                    {item.name}
                  </Link>
                );
              })}
            </div>

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