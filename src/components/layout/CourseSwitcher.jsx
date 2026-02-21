/**
 * CourseSwitcher.jsx
 *
 * A compact pill-style dropdown shown in the navigation bar for professors,
 * admins, and super_admins who have 2+ courses in profile_courses.
 *
 * Switching courses updates ONLY session state (React Context) — it does NOT
 * write to the database. This allows professors to "view as" different course
 * contexts without changing their Primary Course setting.
 *
 * To change the Primary Course (DB-persisted), use Profile Settings → Teaching Areas.
 *
 * Renders nothing for students or users with < 2 teaching courses.
 */

import { GraduationCap, ChevronDown } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { useCourseContext } from '@/contexts/CourseContext';

export default function CourseSwitcher() {
  const { teachingCourses, activeCourse, setActiveCourse, isContentCreator } = useCourseContext();

  // Don't render for students or when there's only one (or zero) teaching courses
  if (!isContentCreator || teachingCourses.length < 2) return null;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-xs font-medium bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition-colors border border-indigo-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400"
          title="Switch active course context (session only)"
        >
          <GraduationCap className="h-3.5 w-3.5 flex-shrink-0" />
          <span className="max-w-[130px] truncate">{activeCourse || 'Select Course'}</span>
          <ChevronDown className="h-3 w-3 flex-shrink-0" />
        </button>
      </DropdownMenuTrigger>

      <DropdownMenuContent align="end" className="w-60">
        <DropdownMenuLabel className="text-xs text-gray-500 font-normal leading-snug py-2">
          Switch course context
          <span className="block text-gray-400 font-normal mt-0.5">
            Session only — does not change your Primary Course
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />

        {teachingCourses.map((course) => {
          const name      = course.disciplines.name;
          const isActive  = name === activeCourse;
          const isPrimary = course.is_primary;

          return (
            <DropdownMenuItem
              key={course.id}
              onClick={() => setActiveCourse(name)}
              className="flex items-center gap-2 cursor-pointer py-2"
            >
              {/* Active indicator dot */}
              <span
                className={`h-2 w-2 rounded-full flex-shrink-0 ${
                  isActive ? 'bg-indigo-500' : 'bg-transparent border border-gray-300'
                }`}
              />

              <span className={`flex-1 ${isActive ? 'font-medium text-indigo-700' : ''}`}>
                {name}
              </span>

              {/* Labels */}
              <div className="flex items-center gap-1 flex-shrink-0">
                {isActive && (
                  <span className="text-[10px] font-medium text-indigo-600 bg-indigo-50 px-1.5 py-0.5 rounded">
                    Active
                  </span>
                )}
                {isPrimary && !isActive && (
                  <span className="text-[10px] text-gray-400">
                    Primary
                  </span>
                )}
              </div>
            </DropdownMenuItem>
          );
        })}

        <DropdownMenuSeparator />
        <DropdownMenuLabel className="text-[10px] text-gray-400 font-normal py-1.5">
          Manage courses in Profile Settings → Teaching Areas
        </DropdownMenuLabel>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
