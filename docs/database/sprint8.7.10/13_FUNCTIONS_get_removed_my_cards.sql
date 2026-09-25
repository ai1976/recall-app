-- Name: [FUNCTIONS] Sprint 8.7.10 Scope D - get_removed_my_cards, for the History tab
-- Description: New RPC, justified because no existing path exposes removed-status enrollment to
-- the client at all. get_my_cards only ever returns active enrollment (own or external) --
-- remove_from_my_cards soft-deletes to my_cards_enrollment.status='removed', and that table has
-- zero client grants (RLS enabled, zero policies, RPC-only access per its own design). The
-- Scope D History tab needs to show these cards with a re-add ("Add to My Study") action, so a
-- dedicated read path is required.
--
-- Mirrors get_my_cards' own-card branch exactly (own content requires enrollment too, per
-- Scope A/D-32) but filters my_cards_enrollment.status = 'removed' instead of 'active', and
-- re-applies the same live visibility re-check (a card that's gone private/unfriended since being
-- removed simply won't show up here either -- same "enrollment expresses intent, not access"
-- principle as get_my_cards).
--
-- Lazy-loaded only: the frontend calls this once, the first time the History tab is opened --
-- never on the default My Study page load, so this adds zero cost to the common path.

CREATE OR REPLACE FUNCTION public.get_removed_my_cards(p_user_id uuid)
 RETURNS SETOF public.flashcards
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
  SELECT DISTINCT f.*
  FROM public.flashcards f
  WHERE EXISTS (
    SELECT 1
    FROM public.my_cards_enrollment e
    WHERE e.user_id = p_user_id
      AND e.flashcard_id = f.id
      AND e.status = 'removed'
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
  );
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_removed_my_cards(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_removed_my_cards(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
