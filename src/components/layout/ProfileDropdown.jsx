import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  User,
  LogOut,
  BarChart3,
  Folder,
  Trophy,
  ChevronDown,
  HelpCircle,
  Settings,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { supabase } from '@/lib/supabase';

export default function ProfileDropdown({ user, role, isLoading, handleSignOut }) {
  const [userName, setUserName] = useState('');

  // Fetch user's full name from profiles table
  useEffect(() => {
    const fetchUserName = async () => {
      if (user?.id) {
        const { data } = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

        if (data?.full_name) {
          setUserName(data.full_name);
        }
      }
    };
    fetchUserName();
  }, [user?.id]);

  // Get user initials for avatar
  const getInitials = () => {
    if (userName) {
      return userName.charAt(0).toUpperCase();
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
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" className="flex items-center gap-2 px-2">
          <div className="h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center text-white font-bold text-sm">
            {getInitials()}
          </div>
          <ChevronDown className="h-4 w-4 text-gray-500" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-64">
        {/* User Header */}
        <div className="px-3 py-3 border-b">
          <p className="text-sm font-medium text-gray-900">
            {userName || user?.email}
          </p>
          <p className="text-xs text-gray-500 mt-0.5 truncate">
            {user?.email}
          </p>
          {!isLoading && role && (
            <span className={`inline-block mt-2 px-2 py-0.5 text-xs font-medium rounded-full ${getRoleBadgeClass()}`}>
              {role.replace('_', ' ')}
            </span>
          )}
        </div>

        {/* Profile Links */}
        <DropdownMenuItem asChild>
          <Link to="/dashboard/progress" className="flex items-center gap-2 cursor-pointer">
            <BarChart3 className="h-4 w-4" />
            My Progress
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/my-contributions" className="flex items-center gap-2 cursor-pointer">
            <Folder className="h-4 w-4" />
            My Contributions
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/achievements" className="flex items-center gap-2 cursor-pointer">
            <Trophy className="h-4 w-4" />
            My Achievements
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/help" className="flex items-center gap-2 cursor-pointer">
            <HelpCircle className="h-4 w-4" />
            Help & Guide
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/dashboard/settings" className="flex items-center gap-2 cursor-pointer">
            <Settings className="h-4 w-4" />
            Settings
          </Link>
        </DropdownMenuItem>

        <DropdownMenuSeparator />

        {/* Sign Out */}
        <DropdownMenuItem
          onClick={handleSignOut}
          className="flex items-center gap-2 cursor-pointer text-red-600 focus:text-red-600 focus:bg-red-50"
        >
          <LogOut className="h-4 w-4" />
          Sign Out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
