-- Name: [FIX] Sprint 8.7.10 hotfix - add_batch_to_my_cards ambiguous column reference
-- Description: Live failure caught during Scope B smoke testing (25/09/2026): calling
-- add_batch_to_my_cards threw `42702 column reference "flashcard_id" is ambiguous`. Root cause:
-- RETURNS TABLE(flashcard_id uuid, enrollment_status text) implicitly declares flashcard_id as a
-- PL/pgSQL variable in the function body -- the exact same class of gotcha already documented in
-- this codebase's own get_practice_cards comment ("RETURNS TABLE(id uuid, ...) implicitly
-- declares id ... as a PL/pgSQL variable ... a bare id here would be ambiguous"). It collides
-- with the unqualified `flashcard_id` inside `ON CONFLICT (user_id, flashcard_id)` -- Postgres
-- parses an ON CONFLICT target list as index expressions (not a plain column-name list), so it
-- goes through the same identifier resolution as any other expression and picks up the
-- PL/pgSQL variable instead of the table column. add_to_my_cards never hit this because its
-- RETURNS TABLE columns (enrollment_id, enrollment_status) don't share a name with any table
-- column referenced in its body.
--
-- Fix: rename the OUT column from flashcard_id to out_flashcard_id, so nothing in the function
-- body collides with it. Same signature (uuid, uuid[]) -- CREATE OR REPLACE is safe (renaming an
-- OUT parameter/RETURNS TABLE column, unlike changing its type or count, does not change the
-- function's identity). No caller reads the RPC's returned columns today (both FlashcardCreate.jsx
-- and BulkUploadFlashcards.jsx only check for an error), so this needs no frontend change.
--
-- Everything else is byte-identical to 10_FUNCTIONS_add_batch_to_my_cards.sql.

CREATE OR REPLACE FUNCTION public.add_batch_to_my_cards(p_user_id uuid, p_flashcard_ids uuid[])
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
