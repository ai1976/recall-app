-- Name: [FUNCTIONS] Sprint 8.7.10 - apply_review, add enrollment + not-suspended guard
-- Description: CREATE OR REPLACE against the live 6-arg signature (unchanged since Sprint 8.6c:
-- apply_review(p_user_id, p_flashcard_id, p_rating, p_is_correct, p_source,
-- p_selected_answer)) -- same parameter list, true in-place replace, no DROP FUNCTION needed.
--
-- Body is byte-identical to the live 8.6c version (docs/database/sprint8.6c/
-- 02_FUNCTIONS_apply_review_selected_answer.sql) with ONE addition: a guard inserted right after
-- the existing reviews-row lookup (which already reads v_review_id / v_cur_status), before the
-- brand-new-vs-existing branch. Previously apply_review had NO enrollment check of any kind --
-- it trusted the caller's card list entirely (get_my_cards / get_study_queue upstream filtering).
-- This closes that gap as defense-in-depth, not a caller-visible change: the only live caller is
-- StudyMode.jsx's submitReview, which only ever grades cards already sourced from get_my_cards
-- (now enrollment-gated for own cards too, see 02_FUNCTIONS_get_my_cards_v2.sql) and further
-- filtered through get_study_queue, which already excludes suspended cards. Confirmed via full
-- codebase grep (25/09/2026): apply_review has exactly one caller; Practice Mode and
-- ConceptCardViewer explicitly never call it. No legitimate flow is broken by this guard.
--
-- The not-suspended check uses v_cur_status, which the pre-existing SELECT (below, unchanged)
-- already populates for an existing reviews row; NULL (brand-new card, no reviews row yet) never
-- trips it, since a brand-new card can't yet be suspended.
--
-- Run this AFTER 01_DATA_backfill_own_card_enrollment.sql and 02_FUNCTIONS_get_my_cards_v2.sql
-- are committed and verified.
--
-- Run as its own submission (pure CREATE OR REPLACE, let it COMMIT). Verify with
-- 03_TEST_verify_get_my_cards_and_apply_review.sql afterward.

CREATE OR REPLACE FUNCTION public.apply_review(
    p_user_id          uuid,
    p_flashcard_id     uuid,
    p_rating           text,
    p_is_correct       boolean DEFAULT NULL,
    p_source           text    DEFAULT NULL,
    p_selected_answer  jsonb   DEFAULT NULL
)
 RETURNS TABLE (new_rung smallint, next_review_date date, new_status text, interval_days integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_rules       jsonb;
  v_top         integer;
  v_relearn     integer;
  v_today       date;
  v_qtype       text;
  v_topic_id    uuid;
  v_review_id   uuid;
  v_cur_rung    integer;
  v_cur_status  text;
  v_rep         integer;
  v_rung_before integer;
  v_new_rung    integer;
  v_new_status  text;
  v_next        date;
  v_quality     integer;
  v_easiness    numeric;
BEGIN
  -- ── L5 IDOR guard (verbatim idiom: skip_card / get_study_queue / security-08) ──
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Access denied: authentication required';
  END IF;
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot submit a review for another user';
  END IF;

  IF p_rating NOT IN ('hard', 'medium', 'easy') THEN
    RAISE EXCEPTION 'Invalid rating "%": expected hard | medium | easy', p_rating;
  END IF;

  SELECT r.rules INTO v_rules FROM public.srs_ladder_rules r WHERE r.id = 1;
  IF v_rules IS NULL THEN
    RAISE EXCEPTION 'srs_ladder_rules not seeded';
  END IF;
  v_top     := (v_rules->>'top_rung')::int;
  v_relearn := (v_rules->>'relearn_step_days')::int;

  -- today in the user's timezone (matches get_study_queue / get_user_streak)
  SELECT (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date
    INTO v_today
  FROM public.profiles p WHERE p.id = p_user_id;
  IF v_today IS NULL THEN
    v_today := CURRENT_DATE;
  END IF;

  SELECT COALESCE(f.question_type, 'flashcard'), f.topic_id INTO v_qtype, v_topic_id
  FROM public.flashcards f WHERE f.id = p_flashcard_id;
  IF v_qtype IS NULL THEN
    RAISE EXCEPTION 'Flashcard % not found', p_flashcard_id;
  END IF;
  IF v_qtype = 'concept_card' THEN
    RAISE EXCEPTION 'Concept cards are reference-only and cannot be reviewed';
  END IF;

  -- ── Sprint 8.7.10: My Study enrollment guard ──────────────────────────────────────
  -- apply_review is the SRS-grading RPC only. It must never mutate SRS state for a card
  -- the user hasn't deliberately enrolled in My Study (own or external — same rule now).
  IF NOT EXISTS (
    SELECT 1 FROM public.my_cards_enrollment e
    WHERE e.user_id = p_user_id
      AND e.flashcard_id = p_flashcard_id
      AND e.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Card is not enrolled in My Study' USING ERRCODE = '42501';
  END IF;

  v_quality  := CASE p_rating WHEN 'hard' THEN 1 WHEN 'medium' THEN 3 ELSE 5 END;
  v_easiness := CASE p_rating WHEN 'hard' THEN 2.3 WHEN 'medium' THEN 2.5 ELSE 2.6 END;

  SELECT r.id, COALESCE(r.rung, 0), r.status, COALESCE(r.repetition, 0)
    INTO v_review_id, v_cur_rung, v_cur_status, v_rep
  FROM public.reviews r
  WHERE r.user_id = p_user_id AND r.flashcard_id = p_flashcard_id;

  -- ── Sprint 8.7.10: reject grading a paused card ───────────────────────────────────
  -- A suspended card keeps an ACTIVE enrollment row (enrollment = membership, pause =
  -- scheduling state), so the enrollment check above alone can't distinguish it from an
  -- actively-scheduled card. get_study_queue already excludes suspended cards upstream, so
  -- this never fires for any existing legitimate flow -- it's a defense-in-depth backstop.
  IF v_cur_status = 'suspended' THEN
    RAISE EXCEPTION 'Card is paused; resume it before grading' USING ERRCODE = '42501';
  END IF;

  -- defensive clamp (CHECK allows 0..20; the _default curve only defines 0..7)
  v_cur_rung := LEAST(GREATEST(COALESCE(v_cur_rung, 0), 0), v_top);
  -- NULL (not 0) for a brand-new card — v_cur_rung is only meaningful when a
  -- prior review row existed.
  v_rung_before := CASE WHEN v_review_id IS NULL THEN NULL ELSE v_cur_rung END;

  IF v_review_id IS NULL THEN
    -- ── brand-new card: enter the ladder at the configured starting rung ──
    v_new_rung := CASE p_rating
                    WHEN 'hard'   THEN (v_rules->'new_card_rung'->>'hard')::int
                    WHEN 'medium' THEN (v_rules->'new_card_rung'->>'medium')::int
                    ELSE               (v_rules->'new_card_rung'->>'easy')::int
                  END;
    v_new_status := 'active';
    IF p_rating = 'hard' THEN
      v_next := v_today + v_relearn;
    ELSE
      v_next := v_today + public.srs_interval_for_rung(v_new_rung, v_qtype);
    END IF;

    INSERT INTO public.reviews (
      user_id, flashcard_id, quality, "interval", repetition, easiness,
      next_review_date, last_reviewed_at, status, skip_until, rung
    ) VALUES (
      p_user_id, p_flashcard_id, v_quality, (v_next - v_today), 1, v_easiness,
      v_next, now(), v_new_status, NULL, v_new_rung
    );  -- created_at left to its DEFAULT now() (matches the pre-ladder StudyMode INSERT)
  ELSE
    -- ── existing card: deterministic transition ──
    IF p_rating = 'hard' THEN
      v_new_rung   := 0;
      v_next       := v_today + v_relearn;                       -- relearning step
      v_new_status := 'active';                                  -- un-masters if it was mastered
    ELSIF p_rating = 'medium' THEN
      v_new_rung   := v_cur_rung;                                -- hold
      v_next       := v_today + public.srs_interval_for_rung(v_cur_rung, v_qtype);
      v_new_status := 'active';
    ELSE  -- easy
      IF v_cur_rung >= v_top THEN
        v_new_rung   := v_top;
        v_next       := v_today + public.srs_interval_for_rung(v_top, v_qtype);
        v_new_status := 'mastered';                              -- master_threshold = 1
      ELSE
        v_new_rung   := v_cur_rung + 1;
        v_next       := v_today + public.srs_interval_for_rung(v_cur_rung + 1, v_qtype);
        v_new_status := 'active';
      END IF;
    END IF;

    UPDATE public.reviews
    SET quality          = v_quality,
        "interval"        = (v_next - v_today),
        repetition       = v_rep + 1,
        easiness         = v_easiness,
        next_review_date = v_next,
        last_reviewed_at = now(),
        status           = v_new_status,
        skip_until       = NULL,
        rung             = v_new_rung
    WHERE id = v_review_id;
  END IF;

  -- ── durable history row — same transaction as the reviews write above,
  --    so a failure here rolls back the reviews write too ──
  INSERT INTO public.review_events (
    user_id, flashcard_id, rating, is_correct, question_type, topic_id,
    rung_before, rung_after, status_after, interval_days, next_review_date, source,
    selected_answer
  ) VALUES (
    p_user_id, p_flashcard_id, p_rating, p_is_correct, v_qtype, v_topic_id,
    v_rung_before, v_new_rung, v_new_status, (v_next - v_today), v_next, p_source,
    p_selected_answer
  );

  new_rung         := v_new_rung::smallint;
  next_review_date := v_next;
  new_status       := v_new_status;
  interval_days    := (v_next - v_today);
  RETURN NEXT;
END;
$function$;

REVOKE ALL     ON FUNCTION public.apply_review(uuid, uuid, text, boolean, text, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.apply_review(uuid, uuid, text, boolean, text, jsonb) TO authenticated;

-- ── PostgREST: pick up the replaced function ────────────────────────────────────
NOTIFY pgrst, 'reload schema';
