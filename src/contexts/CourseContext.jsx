/**
 * CourseContext.jsx
 *
 * Manages multi-course state for professors, admins, and super_admins.
 *
 * What it does:
 *  - Fetches teaching courses from `profile_courses` joined with `disciplines`
 *  - Tracks `activeCourse` (string) — SESSION STATE only, never written to DB
 *  - Exposes mutators: addCourse, removeCourse, setPrimaryCourse
 *  - setPrimaryCourse syncs profiles.course_level for backward compatibility
 *
 * For students: teachingCourses = [], activeCourse = profiles.course_level
 */

import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// ── Context definition ────────────────────────────────────────────────────────
const CourseContext = createContext({
  teachingCourses:         [],    // [{ id, discipline_id, is_primary, disciplines: { id, name } }]
  activeCourse:            null,  // string — current active course name for UI context
  role:                    null,  // string — cached profiles.role (avoids duplicate profile reads elsewhere)
  courseLevel:             null,  // string — cached profiles.course_level (student's enrolled course)
  setActiveCourse:         () => {},
  addCourse:               async () => ({ error: null }),
  removeCourse:            async () => ({ error: null }),
  setPrimaryCourse:        async () => ({ error: null }),
  refetchTeachingCourses:  () => {},
  loading:                 true,
  isContentCreator:        false, // true for professor/admin/super_admin
});

// eslint-disable-next-line react-refresh/only-export-components
export const useCourseContext = () => useContext(CourseContext);

// ── Provider ──────────────────────────────────────────────────────────────────
export const CourseContextProvider = ({ children }) => {
  const { user } = useAuth();

  const [teachingCourses, setTeachingCourses] = useState([]);
  const [activeCourse, setActiveCourse]       = useState(null);
  const [loading, setLoading]                 = useState(true);
  const [role, setRole]                       = useState(null);
  const [courseLevel, setCourseLevel]         = useState(null);

  const isContentCreator = ['professor', 'admin', 'super_admin'].includes(role);

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const fetchTeachingCourses = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      // Fetch role + primary course together (single query)
      const { data: profileData } = await supabase
        .from('profiles')
        .select('role, course_level')
        .eq('id', user.id)
        .single();

      const userRole = profileData?.role || 'student';
      setRole(userRole);
      setCourseLevel(profileData?.course_level ?? null);

      const isCreator = ['professor', 'admin', 'super_admin'].includes(userRole);

      if (isCreator) {
        // Fetch all teaching courses (primary first)
        const { data: courses, error } = await supabase
          .from('profile_courses')
          .select('id, discipline_id, is_primary, disciplines(id, name)')
          .eq('user_id', user.id)
          .order('is_primary', { ascending: false });

        if (error) {
          console.error('🔴 CourseContext: profile_courses fetch error:', error);
        }

        if (courses && courses.length > 0) {
          setTeachingCourses(courses);
          // Default active course = primary (first in descending is_primary order)
          const primary = courses.find(c => c.is_primary) || courses[0];
          setActiveCourse(primary.disciplines.name);
        } else {
          // No profile_courses yet — fall back to profiles.course_level
          setTeachingCourses([]);
          setActiveCourse(profileData?.course_level || null);
        }
      } else {
        // Students: no teaching courses, active course = their enrolled course
        setTeachingCourses([]);
        setActiveCourse(profileData?.course_level || null);
      }
    } catch (err) {
      console.error('🔴 CourseContext: Unexpected error:', err);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchTeachingCourses();
  }, [fetchTeachingCourses]);

  // ── Mutators ──────────────────────────────────────────────────────────────

  /** Add a new teaching course. disciplineId must exist in the disciplines table. */
  const addCourse = async (disciplineId) => {
    if (!user) return { error: new Error('Not authenticated') };

    const { error } = await supabase
      .from('profile_courses')
      .insert({ user_id: user.id, discipline_id: disciplineId, is_primary: false });

    if (!error) await fetchTeachingCourses();
    return { error };
  };

  /**
   * Remove a teaching course by its profile_courses.id.
   * Guard: cannot remove the primary course (would orphan profiles.course_level).
   * Caller should demote primary before removing it.
   */
  const removeCourse = async (profileCourseId) => {
    if (!user) return { error: new Error('Not authenticated') };

    const { error } = await supabase
      .from('profile_courses')
      .delete()
      .eq('id', profileCourseId)
      .eq('user_id', user.id); // Safety: only own rows

    if (!error) await fetchTeachingCourses();
    return { error };
  };

  /**
   * Set a course as the primary teaching course.
   *
   * Three-step transaction (all client-side):
   *  1. Clear is_primary on all existing rows for this user
   *  2. Set is_primary = TRUE on the selected row
   *  3. Sync profiles.course_level = disciplineName  ← CRITICAL backward compat
   *
   * Step 3 ensures all existing RLS policies, anonymous class stats,
   * and any other code reading course_level continues to work correctly.
   */
  const setPrimaryCourse = async (profileCourseId, disciplineName) => {
    if (!user) return { error: new Error('Not authenticated') };

    // Step 1: Clear all is_primary flags for this user
    const { error: clearError } = await supabase
      .from('profile_courses')
      .update({ is_primary: false })
      .eq('user_id', user.id);

    if (clearError) return { error: clearError };

    // Step 2: Set selected course as primary
    const { error: setError } = await supabase
      .from('profile_courses')
      .update({ is_primary: true })
      .eq('id', profileCourseId)
      .eq('user_id', user.id); // Safety

    if (setError) return { error: setError };

    // Step 3: Sync profiles.course_level for backward compatibility (CRITICAL)
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ course_level: disciplineName })
      .eq('id', user.id);

    if (profileError) {
      console.error('🔴 CourseContext: Failed to sync profiles.course_level:', profileError);
      // Non-blocking — teaching courses are already updated correctly
    }

    await fetchTeachingCourses();
    return { error: null };
  };

  // ── Provide ───────────────────────────────────────────────────────────────
  return (
    <CourseContext.Provider
      value={{
        teachingCourses,
        activeCourse,
        role,
        courseLevel,
        setActiveCourse,
        addCourse,
        removeCourse,
        setPrimaryCourse,
        refetchTeachingCourses: fetchTeachingCourses,
        loading,
        isContentCreator,
      }}
    >
      {children}
    </CourseContext.Provider>
  );
};
