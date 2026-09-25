-- Name: [FIX] Sprint 8.7.10 hotfix v2 - add_batch_to_my_cards, DROP FUNCTION first
-- Description: 11_HOTFIX's CREATE OR REPLACE failed live: `42P13 cannot change return type of
-- existing function -- Row type defined by OUT parameters is different`. Same lesson this
-- codebase already learned with get_practice_cards' scenario column and apply_review's overload
-- (blueprint.md §1.11) -- renaming/changing a RETURNS TABLE column requires DROP FUNCTION first;
-- CREATE OR REPLACE only tolerates an identical output row type. DROP FUNCTION also drops grants,
-- so they're re-applied explicitly below (same discipline as those two prior fixes).
--
-- Run this instead of 11_HOTFIX (which never took effect, since its CREATE OR REPLACE errored
-- and rolled back -- the live function is still the original 10_FUNCTIONS version with the
-- ambiguous-column bug).

DROP FUNCTION IF EXISTS public.add_batch_to_my_cards(uuid, uuid[]);

CREATE FUNCTION public.add_batch_to_my_cards(p_user_id uuid, p_flashcard_ids uuid[])
 RETURNS TABLE(out_flashcard_id uuid, enrollment_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s My Study';
  END IF;

  IF p_flashcard_ids IS NULL OR array_length(p_flashcard_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'p_flashcard_ids must be a non-empty array';
  END IF;

  RETURN QUERY
  WITH accessible AS (
    SELECT f.id
    FROM public.flashcards f
    WHERE f.id = ANY(p_flashcard_ids)
      AND f.question_type <> 'concept_card'
      AND (
        f.user_id = p_user_id
        OR f.visibility = 'public'
        OR (
          f.visibility = 'friends'
          AND EXISTS (
            SELECT 1 FROM public.friendships fr
            WHERE fr.status = 'accepted'
              AND (
                (fr.user_id = p_user_id AND fr.friend_id = f.user_id)
                OR (fr.friend_id = p_user_id AND fr.user_id = f.user_id)
              )
          )
        )
      )
  ),
  upsert AS (
    INSERT INTO public.my_cards_enrollment (user_id, flashcard_id, status, added_at)
    SELECT p_user_id, a.id, 'active', now()
    FROM accessible a
    ON CONFLICT (user_id, flashcard_id) DO UPDATE
      SET status = 'active'
    RETURNING public.my_cards_enrollment.flashcard_id
  )
  SELECT u.flashcard_id, 'active'::text FROM upsert u;
END;
$function$;

REVOKE ALL     ON FUNCTION public.add_batch_to_my_cards(uuid, uuid[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.add_batch_to_my_cards(uuid, uuid[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
