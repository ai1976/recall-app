-- Name: [FUNCTIONS] Sprint 8.8.5c - shared course-change calculation + student preview RPC
-- Description: ONE place defines which enrollments a course change archives and restores. The trigger (05) and the
--   Profile Settings confirmation dialog (preview_course_change) both call it, so the rule can never diverge.
--   course_change_affected(user, old_course, new_course) - READ ONLY, SECURITY DEFINER (the table has zero client
--     grants), NOT executable by any client role. Returns one row per enrollment with the action:
--       'archive' : enrollment status 'active' AND the card's target_course = old_course
--                   (only when both courses are known and different)
--       'restore' : enrollment status 'course_archived' AND archived_course = new_course
--     Manually removed rows ('removed') are never returned. A NULL new course (a student clearing the field) does
--     nothing; a NULL old course (first course set) can only restore.
--   preview_course_change(new_course) - client-callable, self only (auth.uid()). Returns jsonb with BOTH effects:
--     cards that will be archived from the current course (with paused / mastered breakdown from `reviews`) and
--     cards that will be restored for the destination. Non-students and same-course calls return zeros.
--     It never writes anything: course selection stays non-mutating until the user confirms.
--   Run after 03. Run on its own.

CREATE OR REPLACE FUNCTION public.course_change_affected(p_user_id uuid, p_old_course text, p_new_course text)
 RETURNS TABLE(enrollment_id uuid, flashcard_id uuid, action text, card_course text)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
  SELECT e.id, e.flashcard_id, 'archive'::text, f.target_course
  FROM public.my_cards_enrollment e
  JOIN public.flashcards f ON f.id = e.flashcard_id
  WHERE p_old_course IS NOT NULL
    AND p_new_course IS NOT NULL
    AND p_old_course IS DISTINCT FROM p_new_course
    AND e.user_id = p_user_id
    AND e.status = 'active'
    AND f.target_course = p_old_course
  UNION ALL
  SELECT e.id, e.flashcard_id, 'restore'::text, e.archived_course
  FROM public.my_cards_enrollment e
  WHERE p_new_course IS NOT NULL
    AND p_old_course IS DISTINCT FROM p_new_course
    AND e.user_id = p_user_id
    AND e.status = 'course_archived'
    AND e.archived_course = p_new_course;
$function$;

REVOKE ALL ON FUNCTION public.course_change_affected(uuid, text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.preview_course_change(p_new_course text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_role   text;
  v_old    text;
  v_arch   int := 0;
  v_paused int := 0;
  v_mast   int := 0;
  v_rest   int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT pr.role, pr.course_level INTO v_role, v_old FROM public.profiles pr WHERE pr.id = v_uid;

  IF v_role IS DISTINCT FROM 'student'
     OR p_new_course IS NULL OR btrim(p_new_course) = ''
     OR v_old IS NOT DISTINCT FROM p_new_course THEN
    RETURN jsonb_build_object(
      'old_course', v_old, 'new_course', p_new_course,
      'is_student', v_role IS NOT DISTINCT FROM 'student',
      'same_course', v_old IS NOT DISTINCT FROM p_new_course,
      'archive_count', 0, 'archive_paused', 0, 'archive_mastered', 0, 'restore_count', 0);
  END IF;

  SELECT COUNT(*) FILTER (WHERE a.action = 'archive'),
         COUNT(*) FILTER (WHERE a.action = 'archive' AND r.status = 'suspended'),
         COUNT(*) FILTER (WHERE a.action = 'archive' AND r.status = 'mastered'),
         COUNT(*) FILTER (WHERE a.action = 'restore')
    INTO v_arch, v_paused, v_mast, v_rest
  FROM public.course_change_affected(v_uid, v_old, p_new_course) a
  LEFT JOIN public.reviews r ON r.user_id = v_uid AND r.flashcard_id = a.flashcard_id;

  RETURN jsonb_build_object(
    'old_course', v_old, 'new_course', p_new_course,
    'is_student', true, 'same_course', false,
    'archive_count', v_arch, 'archive_paused', v_paused, 'archive_mastered', v_mast,
    'restore_count', v_rest);
END;
$function$;

REVOKE ALL     ON FUNCTION public.preview_course_change(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.preview_course_change(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
