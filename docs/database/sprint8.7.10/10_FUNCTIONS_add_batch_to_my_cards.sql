-- Name: [FUNCTIONS] Sprint 8.7.10 - add_batch_to_my_cards, atomic set-based enrollment
-- Description: New RPC. Justification (per the explicit "don't add a new RPC merely for
-- elegance" constraint): add_to_my_cards only takes one flashcard_id. Scope B's explicit
-- "Save & Add to My Study" / "Upload & Add to My Study" actions need to enroll everything just
-- created in ONE step -- for bulk upload that can be hundreds of cards. Looping the single-card
-- RPC client-side would mean hundreds of round trips with real partial-failure risk (exactly the
-- "two naive client calls" pattern flagged during planning) and no way to make a failure midway
-- cleanly recoverable. This function does the identical INSERT ... ON CONFLICT DO UPDATE as
-- add_to_my_cards, just set-based over an array, in ONE statement/transaction: either every
-- id in p_flashcard_ids gets enrolled, or none do.
--
-- Enrollment only. Never touches reviews or review_events -- a newly enrolled card starts as
-- New (get_my_cards will return it once 02_FUNCTIONS deploys) and only acquires SRS history the
-- first time it's genuinely graded through apply_review. This mirrors add_to_my_cards exactly,
-- it does not reimplement different semantics.
--
-- Same visibility re-check as add_to_my_cards (get_study_queue's predicate: own + public +
-- accepted-friends, concept_card excluded) -- a malicious client must not be able to enroll an
-- inaccessible card merely by knowing its UUID, same as the single-card RPC. In practice every
-- caller today only ever passes ids for cards it just created itself (always own, always passes
-- trivially), but the check is reproduced anyway for defense in depth, not skipped as "trusted
-- caller."
--
-- Idempotent (ON CONFLICT DO UPDATE) -- safe to retry the whole call after a partial/failed
-- attempt; retrying never creates a duplicate flashcard (this RPC never touches public.flashcards)
-- and never double-enrolls (re-running with the same ids converges, doesn't error).
--
-- Does NOT reproduce add_to_my_cards' "re-add after Remove -> unsuspend_card" branch: that case
-- is for re-adding a previously-removed card, which cannot happen for a batch of cards that were
-- all just created in this same request (they have no prior enrollment history by construction).
-- If a caller ever passes an id that WAS previously removed, this still safely reactivates it as
-- 'active' (same as add_to_my_cards would) but does not call unsuspend_card -- acceptable because
-- the only live callers (FlashcardCreate.jsx, BulkUploadFlashcards.jsx) only ever pass freshly
-- created ids, never a pre-existing card id.

CREATE OR REPLACE FUNCTION public.add_batch_to_my_cards(p_user_id uuid, p_flashcard_ids uuid[])
 RETURNS TABLE(flashcard_id uuid, enrollment_status text)
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
    -- Same visibility predicate as add_to_my_cards, reproduced verbatim (see file header) --
    -- silently drops any id the caller isn't actually allowed to enroll, rather than erroring
    -- the whole batch, so a stray inaccessible id can't block the legitimate ones.
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
