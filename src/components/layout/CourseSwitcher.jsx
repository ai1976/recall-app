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

// Each entry is a full set of Tailwind classes for one color slot.
// Written as complete strings so Tailwind's scanner picks them up at build time.
// Cycles if a professor teaches more courses than there are entries.
const COURSE_COLORS = [
  {
    pill:  'bg-indigo-50 text-indigo-700 border-indigo-200 hover:bg-indigo-100 focus-visible:ring-indigo-400',
    dot:   'bg-indigo-500',
    label: 'text-indigo-700',
    badge: 'text-indigo-600 bg-indigo-50',
  },
  {
    pill:  'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100 focus-visible:ring-emerald-400',
    dot:   'bg-emerald-500',
    label: 'text-emerald-700',
    badge: 'text-emerald-600 bg-emerald-50',
  },
  {
    pill:  'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100 focus-visible:ring-amber-400',
    dot:   'bg-amber-500',
    label: 'text-amber-700',
    badge: 'text-amber-600 bg-amber-50',
  },
  {
    pill:  'bg-rose-50 text-rose-700 border-rose-200 hover:bg-rose-100 focus-visible:ring-rose-400',
    dot:   'bg-rose-500',
    label: 'text-rose-700',
    badge: 'text-rose-600 bg-rose-50',
  },
  {
    pill:  'bg-violet-50 text-violet-700 border-violet-200 hover:bg-violet-100 focus-visible:ring-violet-400',
    dot:   'bg-violet-500',
    label: 'text-violet-700',
    badge: 'text-violet-600 bg-violet-50',
  },
  {
    pill:  'bg-cyan-50 text-cyan-700 border-cyan-200 hover:bg-cyan-100 focus-visible:ring-cyan-400',
    dot:   'bg-cyan-500',
    label: 'text-cyan-700',
    badge: 'text-cyan-600 bg-cyan-50',
  },
  {
    pill:  'bg-orange-50 text-orange-700 border-orange-200 hover:bg-orange-100 focus-visible:ring-orange-400',
    dot:   'bg-orange-500',
    label: 'text-orange-700',
    badge: 'text-orange-600 bg-orange-50',
  },
  {
    pill:  'bg-pink-50 text-pink-700 border-pink-200 hover:bg-pink-100 focus-visible:ring-pink-400',
    dot:   'bg-pink-500',
    label: 'text-pink-700',
    badge: 'text-pink-600 bg-pink-50',
  },
];

export default function CourseSwitcher() {
  const { teachingCourses, activeCourse, setActiveCourse, isContentCreator } = useCourseContext();

  // Don't render for students or when there's only one (or zero) teaching courses
  if (!isContentCreator || teachingCourses.length < 2) return null;

  // Stable color per course — assigned by position, cycles if > 8 courses
  const colorOf = (idx) => COURSE_COLORS[idx % COURSE_COLORS.length];
  const activeIdx = teachingCourses.findIndex(c => c.disciplines.name === activeCourse);
  const activeColor = colorOf(activeIdx >= 0 ? activeIdx : 0);

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-xs font-medium transition-colors border focus:outline-none focus-visible:ring-2 ${activeColor.pill}`}
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

        {teachingCourses.map((course, idx) => {
          const name      = course.disciplines.name;
          const isActive  = name === activeCourse;
          const isPrimary = course.is_primary;
          const colors    = colorOf(idx);

          return (
            <DropdownMenuItem
              key={course.id}
              onClick={() => setActiveCourse(name)}
              className="flex items-center gap-2 cursor-pointer py-2"
            >
              {/* Color dot — filled with course color when active */}
              <span
                className={`h-2 w-2 rounded-full flex-shrink-0 ${
                  isActive ? colors.dot : 'bg-transparent border border-gray-300'
                }`}
              />

              <span className={`flex-1 ${isActive ? `font-medium ${colors.label}` : ''}`}>
                {name}
              </span>

              {/* Labels */}
              <div className="flex items-center gap-1 flex-shrink-0">
                {isActive && (
                  <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${colors.badge}`}>
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
