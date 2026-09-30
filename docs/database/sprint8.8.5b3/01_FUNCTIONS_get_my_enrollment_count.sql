-- [FUNCTIONS] get_my_enrollment_count(p_user_id) - has this student ever added cards to My Study?
-- Description: Read-only helper for the dashboard's "is this a brand-new student?" check. `my_cards_enrollment` has no
--   client grants by design (8.7.8), so the app cannot count it directly. Students who added cards / logged study time
--   but have not graded a card yet were wrongly shown the first-time "Get Started" page with no leaderboard
--   (30/09/2026, see 00_DIAGNOSTIC). Counts rows in ANY status (active, removed, course_archived): a student who has
--   ever used My Study is not new.
--   SECURITY DEFINER, own-data guard identical to the other stats RPCs (own id, or an admin), unquoted search_path,
--   executable by signed-in users only (not anon, not PUBLIC).
-- Rollback: 03. Test: 02.

CREATE OR REPLACE FUNCTION public.get_my_enrollment_count(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_count integer;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  SELECT count(*)::integer INTO v_count
    FROM public.my_cards_enrollment e
   WHERE e.user_id = p_user_id;
  RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_enrollment_count(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_enrollment_count(uuid) TO authenticated;
