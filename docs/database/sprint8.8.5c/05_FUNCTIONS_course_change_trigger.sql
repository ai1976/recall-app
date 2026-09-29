-- Name: [FUNCTIONS] Sprint 8.8.5c - course-change trigger (archive old-course cards, restore destination-course cards)
-- Description: AFTER UPDATE OF course_level ON profiles, fired only when the value really changes. In the SAME
--   transaction as the profile update (so any error here rolls the course change back too) it:
--     1. ARCHIVES the student's active enrollments whose card belongs to the OLD course
--        (status -> 'course_archived', archived_course = that course, archived_at = now());
--     2. RESTORES enrollments previously archived FROM the destination course (status -> 'active', archive
--        columns cleared).
--   Both sets come from course_change_affected() - the same function the confirmation dialog previews with.
--   Scope: role = 'student' only (professors use profile_courses; a professor's primary teaching course is not a
--   study scope). `reviews` is never touched, so Paused/Mastered state survives. Manually removed cards are never
--   restored. A NULL new course does nothing; a NULL old course (first course set) can only restore.
--   Because it is a trigger it also covers any future admin-side course change - the database enforces the
--   consequence; every interactive UI should preview and confirm first.
--   Run after 03 and 04. THIS is the step that changes live behaviour: from this point every real course change
--   archives/restores. Run the backfill (10) right after 08 passes.

CREATE OR REPLACE FUNCTION public.fn_course_change_archive_restore()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF NEW.role IS DISTINCT FROM 'student' THEN
    RETURN NULL;
  END IF;

  UPDATE public.my_cards_enrollment e
     SET status = 'course_archived',
         archived_course = a.card_course,
         archived_at = now()
    FROM public.course_change_affected(NEW.id, OLD.course_level, NEW.course_level) a
   WHERE e.id = a.enrollment_id AND a.action = 'archive';

  UPDATE public.my_cards_enrollment e
     SET status = 'active',
         archived_course = NULL,
         archived_at = NULL
    FROM public.course_change_affected(NEW.id, OLD.course_level, NEW.course_level) a
   WHERE e.id = a.enrollment_id AND a.action = 'restore';

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_course_change_archive_restore ON public.profiles;
CREATE TRIGGER trg_course_change_archive_restore
  AFTER UPDATE OF course_level ON public.profiles
  FOR EACH ROW
  WHEN (OLD.course_level IS DISTINCT FROM NEW.course_level)
  EXECUTE FUNCTION public.fn_course_change_archive_restore();
