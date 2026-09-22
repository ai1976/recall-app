-- Name: [FUNCTIONS] add_to_my_cards / remove_from_my_cards / get_my_cards / log_practice_attempt
--
-- Description: The four Sprint 8.7.8b RPCs. All follow the established hardened-RPC convention
-- confirmed live across security/08, security/02b, sprint6/01 (get_study_queue): plpgsql,
-- SECURITY DEFINER, SET search_path TO public, extensions (unquoted — L3 17c outage lesson, never
-- single-quote a multi-schema search_path), self-only IDOR guard
-- `IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN RAISE`, explicit
-- REVOKE-then-GRANT ACLs (no PUBLIC/anon execute).
--
-- Two different visibility predicates are used deliberately (Anand's explicit decision, 22/09/2026,
-- overriding the diagnostic's tentative single-predicate assumption):
--   - add_to_my_cards / get_my_cards use get_study_queue's predicate (own + public + accepted-
--     friends only — no admin override, no group-share) because a card added to My Cards must be
--     reliably schedulable through the frozen SRS path, and get_study_queue does not know about
--     group-shared content today. A card visible only via a study-group share currently CANNOT be
--     added to My Cards — this is a known, recorded compatibility gap, not an oversight: once
--     get_study_queue's own visibility (frozen, out of scope here) is extended to group-shared
--     content, this predicate should be widened to match in a later sprint.
--   - log_practice_attempt uses the Browse/Practice predicate (own + public + accepted-friends +
--     admin override + group-shared), matching get_browsable_decks v8's card-level predicate
--     verbatim (docs/database/sprint8.7.7/11_..._v8_matching_card_count.sql:109-125), because
--     Practice Mode must match what the student can actually see on the Browse/Practice surface.
--
-- Neither predicate is centralized in this schema (proposal §2.2) — both are reproduced here
-- verbatim from their respective live sources rather than paraphrased, per the sprint's own
-- instruction not to invent a sixth inconsistent model.
--
-- No changes to apply_review, submit_review, srs_ladder_curves, srs_ladder_rules, get_study_queue,
-- suspend_card, unsuspend_card, reset_card, trg_badge_review, get_user_streak. suspend_card /
-- unsuspend_card are called (not reimplemented) where the design calls for their exact effect.
-- reset_card is never called — it hard-deletes reviews history, which would destroy the very
-- rung/repetition/easiness state this epic is required to preserve across Remove/Re-add.

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- 1. add_to_my_cards — add or re-add (own cards are never routed through this by the frontend,
--    but a caller passing their own card's id is harmless: the visibility check passes trivially
--    on `f.user_id = p_user_id`, and get_my_cards already returns own cards through a separate
--    branch, so no duplicate-membership-affects-composition risk — see get_my_cards below).
-- ─────────────────────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.add_to_my_cards(uuid, uuid);

CREATE OR REPLACE FUNCTION public.add_to_my_cards(p_user_id uuid, p_flashcard_id uuid)
 RETURNS TABLE(enrollment_id uuid, enrollment_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_old_status    text;
  v_enrollment_id uuid;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s My Cards';
  END IF;

  -- Server-side visibility re-check (get_study_queue's predicate — see file header). A malicious
  -- client must not be able to enroll an inaccessible/private card merely by knowing its UUID.
  -- concept_card is excluded here too: it never enters a study/practice loop (D-06) and
  -- apply_review already rejects it, so enrolling one would be permanently unschedulable.
  IF NOT EXISTS (
    SELECT 1
    FROM public.flashcards f
    WHERE f.id = p_flashcard_id
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
  ) THEN
    RAISE EXCEPTION 'Card not accessible: cannot add this flashcard to My Cards' USING ERRCODE = '42501';
  END IF;

  -- Atomic upsert (INSERT ... ON CONFLICT DO UPDATE, same idiom as skip_card/suspend_card's
  -- 23505-race fix) — never SELECT-then-INSERT. The `locked` CTE captures the pre-update status so
  -- we can tell "genuine re-add after Remove" (old_status='removed') from "already active, called
  -- again" (old_status='active', the Pause case — must NOT resume here) from "brand new"
  -- (old_status IS NULL) in one statement.
  WITH locked AS (
    SELECT my_cards_enrollment.status AS old_status
    FROM public.my_cards_enrollment
    WHERE user_id = p_user_id AND flashcard_id = p_flashcard_id
    FOR UPDATE
  ),
  upsert AS (
    INSERT INTO public.my_cards_enrollment (user_id, flashcard_id, status, added_at)
    VALUES (p_user_id, p_flashcard_id, 'active', now())
    ON CONFLICT (user_id, flashcard_id) DO UPDATE
      SET status   = 'active',
          added_at = CASE WHEN (SELECT locked.old_status FROM locked) = 'removed' THEN now()
                          ELSE public.my_cards_enrollment.added_at END
    RETURNING id
  )
  SELECT (SELECT locked.old_status FROM locked), (SELECT upsert.id FROM upsert)
  INTO v_old_status, v_enrollment_id;

  -- Re-add after Remove: resume the paired reviews row using unsuspend_card's exact, unchanged
  -- semantics (rung/repetition/easiness preserved, next_review_date reset to today — never
  -- reset_card). unsuspend_card's own WHERE status='suspended' makes this a safe no-op when the
  -- card was removed before it was ever graded (no reviews row) — matches the "never graded
  -- before removal" re-add case, which needs no reviews action at all.
  IF v_old_status = 'removed' THEN
    PERFORM public.unsuspend_card(p_user_id, p_flashcard_id);
  END IF;

  RETURN QUERY SELECT v_enrollment_id, 'active'::text;
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- 2. remove_from_my_cards — soft-remove membership; suspend the paired reviews row ONLY if one
--    exists and is genuinely graded (active/mastered). Never calls reset_card. Never creates a
--    bare reviews row for a never-graded card (that would be the pre-existing skip_card/
--    suspend_card bare-row bug, explicitly out of scope — see proposal §8).
-- ─────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.remove_from_my_cards(p_user_id uuid, p_flashcard_id uuid)
 RETURNS TABLE(removed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_exists boolean;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s My Cards';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.my_cards_enrollment
    WHERE user_id = p_user_id AND flashcard_id = p_flashcard_id
  ) INTO v_exists;

  IF NOT v_exists THEN
    -- Stable "not enrolled" contract: this pair has no membership row at all, so this is a
    -- safe idempotent no-op. Never suspend an unrelated review row just because the caller
    -- supplied a flashcard_id that was never actually enrolled.
    RETURN QUERY SELECT false;
    RETURN;
  END IF;

  -- Idempotent on an already-removed row (WHERE status='active' simply matches 0 rows the
  -- second time) — converges safely on repeat calls, per the sprint's requirement.
  UPDATE public.my_cards_enrollment
  SET status = 'removed'
  WHERE user_id = p_user_id AND flashcard_id = p_flashcard_id AND status = 'active';

  -- Only stop SRS surfacing if the card was genuinely graded. No reviews row -> no SRS write.
  -- Already-suspended -> left suspended (calling suspend_card again would be harmless/idempotent
  -- too, but skipping it keeps the write set minimal and matches the "leave it" instruction).
  IF EXISTS (
    SELECT 1 FROM public.reviews
    WHERE user_id = p_user_id AND flashcard_id = p_flashcard_id AND status IN ('active', 'mastered')
  ) THEN
    PERFORM public.suspend_card(p_user_id, p_flashcard_id);
  END IF;

  RETURN QUERY SELECT true;
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- 3. get_my_cards — own cards UNION actively-enrolled external cards, re-applying get_study_queue's
--    visibility predicate at READ time (enrollment expresses intent, not access — proposal §5). A
--    card that was public/friends-visible when added and has since gone private/unfriended stops
--    appearing automatically, with zero enrollment-specific code, by construction of this predicate
--    re-check. Returns SETOF flashcards (not a hand-enumerated column list) so the shape always
--    matches the live table exactly, including columns not exhaustively re-verified in this sprint
--    (e.g. deck_id, options, explanation) — this is deliberate: DATABASE_SCHEMA.md documents 34
--    flashcards columns but this sprint did not re-introspect the live table directly, so returning
--    SETOF flashcards avoids hand-copying a column list that could silently drift from live schema.
--    Does NOT touch or wrap get_study_queue (frozen contract, unchanged).
-- ─────────────────────────────────────────────────────────────────────────────────────────────
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

  -- DISTINCT is a defensive backstop against an anomalous own-card enrollment row ever producing
  -- a second logical membership for the same card — a single scan of flashcards with an OR/EXISTS
  -- predicate cannot itself duplicate rows, but this keeps the "one row per card" guarantee
  -- explicit rather than implicit.
  RETURN QUERY
  SELECT DISTINCT f.*
  FROM public.flashcards f
  WHERE
    f.user_id = p_user_id
    OR EXISTS (
      SELECT 1
      FROM public.my_cards_enrollment e
      WHERE e.user_id = p_user_id
        AND e.flashcard_id = f.id
        AND e.status = 'active'
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
    );
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- 4. log_practice_attempt — writes only to practice_attempts. No SRS write, no badge/streak write,
--    no review-event write. Re-checks the Browse/Practice visibility predicate (own + public +
--    accepted-friends + admin override + group-shared), matching get_browsable_decks v8's
--    card-level predicate verbatim.
-- ─────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.log_practice_attempt(p_user_id uuid, p_flashcard_id uuid, p_is_correct boolean)
 RETURNS TABLE(attempt_id bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_question_type text;
  v_user_role     text;
  v_attempt_id    bigint;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot log a practice attempt for another user';
  END IF;

  SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

  SELECT f.question_type INTO v_question_type
  FROM public.flashcards f
  WHERE f.id = p_flashcard_id
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
      OR v_user_role IN ('admin', 'super_admin')
      OR EXISTS (
        -- group-shared: same 5-grouping-column join CLAUDE.md documents for a NULL deck_id,
        -- mirroring get_browsable_decks v8's own vc lateral verbatim.
        SELECT 1
        FROM public.content_group_shares cgs
        JOIN public.study_group_members sgm ON sgm.group_id = cgs.group_id
        JOIN public.flashcard_decks fd ON fd.id = cgs.content_id
        WHERE cgs.content_type = 'flashcard_deck'
          AND sgm.user_id = p_user_id
          AND sgm.status = 'active'
          AND fd.user_id = f.user_id
          AND (fd.subject_id IS NOT DISTINCT FROM f.subject_id)
          AND (fd.topic_id IS NOT DISTINCT FROM f.topic_id)
          AND (fd.custom_subject IS NOT DISTINCT FROM f.custom_subject)
          AND (fd.custom_topic IS NOT DISTINCT FROM f.custom_topic)
      )
    );

  IF v_question_type IS NULL THEN
    RAISE EXCEPTION 'Card not accessible: cannot log a practice attempt for this flashcard' USING ERRCODE = '42501';
  END IF;

  IF v_question_type = 'concept_card' THEN
    RAISE EXCEPTION 'concept_card is browse-only reference material and is never logged as a practice attempt';
  END IF;

  -- Question-type integrity (8.7.8a confirmed semantics — proposal §4). Only what is necessary to
  -- prevent an impossible practice-log state; never recompute correctness from an answer payload.
  IF v_question_type IN ('flashcard', 'theory') AND p_is_correct IS NOT NULL THEN
    RAISE EXCEPTION 'is_correct must be NULL for question_type=% (self-graded, no objective verdict)', v_question_type;
  END IF;

  IF v_question_type IN ('mcq', 'mcq_multi', 'case_study_mcq', 'match_the_following') AND p_is_correct IS NULL THEN
    RAISE EXCEPTION 'is_correct is required (true/false) for question_type=%', v_question_type;
  END IF;

  IF v_question_type = 'fitb' AND p_is_correct IS FALSE THEN
    RAISE EXCEPTION 'is_correct must be TRUE or NULL for question_type=fitb (D-13 — unmatched wording is non-conclusive, never a hard FALSE)';
  END IF;

  INSERT INTO public.practice_attempts (user_id, flashcard_id, is_correct)
  VALUES (p_user_id, p_flashcard_id, p_is_correct)
  RETURNING id INTO v_attempt_id;

  RETURN QUERY SELECT v_attempt_id;
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- Least-privilege grants (L5 "REVOKE FROM PUBLIC/anon + GRANT to authenticated" pattern, verbatim
-- convention from get_study_queue / security/04).
-- ─────────────────────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.add_to_my_cards(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.add_to_my_cards(uuid, uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.add_to_my_cards(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.remove_from_my_cards(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.remove_from_my_cards(uuid, uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.remove_from_my_cards(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_cards(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_cards(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_my_cards(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.log_practice_attempt(uuid, uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_practice_attempt(uuid, uuid, boolean) FROM anon;
GRANT  EXECUTE ON FUNCTION public.log_practice_attempt(uuid, uuid, boolean) TO authenticated;

-- PostgREST: pick up the four new functions
NOTIFY pgrst, 'reload schema';
