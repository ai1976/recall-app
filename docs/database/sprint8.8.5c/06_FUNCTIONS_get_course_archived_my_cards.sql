-- Name: [FUNCTIONS] Sprint 8.8.5c - History section "Archived - course change"
-- Description: Read-only list for the new section under My Study -> History. One jsonb per card: the full
--   flashcards row plus `archived_course` and `archived_at`, so the frontend can label each group by its SOURCE
--   course and reuse its existing Subject -> Topic grouping. Same IDOR guard and the same live visibility re-check
--   as get_removed_my_cards (own, public, or accepted-friends content only). Archived cards are NOT restorable
--   one by one - they return automatically when the student changes back to that course (approved design).
--   Run after 03. Run on its own.

CREATE OR REPLACE FUNCTION public.get_course_archived_my_cards(p_user_id uuid)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s My Study history';
  END IF;

  RETURN QUERY
  SELECT to_jsonb(f) || jsonb_build_object('archived_course', e.archived_course, 'archived_at', e.archived_at)
  FROM public.my_cards_enrollment e
  JOIN public.flashcards f ON f.id = e.flashcard_id
  WHERE e.user_id = p_user_id
    AND e.status = 'course_archived'
    AND (
      f.user_id = p_user_id
      OR f.visibility = 'public'
      OR ( f.visibility = 'friends' AND EXISTS (
             SELECT 1 FROM public.friendships fr
             WHERE fr.status = 'accepted'
               AND ( (fr.user_id = p_user_id AND fr.friend_id = f.user_id)
                  OR (fr.friend_id = p_user_id AND fr.user_id = f.user_id) )
           ) )
    )
  ORDER BY e.archived_course, f.created_at;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_course_archived_my_cards(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_course_archived_my_cards(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
