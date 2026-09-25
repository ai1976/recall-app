-- Name: [FUNCTIONS] Sprint 8.7.10 - get_my_cards v2, own cards now require enrollment too
-- Description: CREATE OR REPLACE against the live signature (unchanged: get_my_cards(p_user_id
-- uuid) RETURNS SETOF flashcards) -- same parameter list, so this is a true in-place replace,
-- not a new overload (no DROP FUNCTION needed, unlike the get_practice_cards / apply_review
-- overload changes elsewhere in this project's history).
--
-- Behavior change: the own-card branch (f.user_id = p_user_id) previously had NO enrollment
-- check at all -- any authored card was automatically My-Study-eligible. This reverses that
-- (blueprint.md D-27), making own cards subject to the exact same active-enrollment requirement
-- as external cards. The not-own branch (public/friends visibility + active enrollment) is
-- UNCHANGED from the live 8.7.8b version.
--
-- Run this AFTER 01_DATA_backfill_own_card_enrollment.sql has been committed and verified --
-- otherwise every own card with real study history would vanish from Study Mode / My Cards
-- until the backfill runs.
--
-- Run as its own submission (pure CREATE OR REPLACE, let it COMMIT). Verify with
-- 03_TEST_verify_get_my_cards_and_apply_review.sql afterward.

CREATE OR REPLACE FUNCTION public.get_my_cards(p_user_id uuid)
 RETURNS SETOF public.flashcards
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s My Cards';
  END IF;

  RETURN QUERY
  SELECT DISTINCT f.*
  FROM public.flashcards f
  WHERE
    EXISTS (
      SELECT 1
      FROM public.my_cards_enrollment e
      WHERE e.user_id = p_user_id
        AND e.flashcard_id = f.id
        AND e.status = 'active'
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
