-- Name: [FUNCTIONS] Sprint 8.6c — apply_review + p_selected_answer (mcq_multi evidence)
--
-- Description: CREATE OR REPLACE against the EXACT live apply_review signature
-- confirmed by 00_DIAGNOSTIC query 3 (unchanged since Sprint 7.4:
-- apply_review(p_user_id uuid, p_flashcard_id uuid, p_rating text,
-- p_is_correct boolean DEFAULT NULL, p_source text DEFAULT NULL)), PLUS exactly
-- one new trailing parameter, p_selected_answer jsonb DEFAULT NULL.
--
-- ⚠️ CORRECTED after a live failure (see 02b_HOTFIX): this file originally
-- claimed appending a defaulted trailing parameter "replaces it in place; it
-- does NOT create a second overload." That claim was WRONG — running this file
-- alone left TWO live apply_review functions (the old 5-arg one, untouched,
-- plus this new 6-arg one), because CREATE OR REPLACE FUNCTION only replaces a
-- function with the EXACT SAME parameter signature; a changed parameter list is
-- always a distinct overload to Postgres, confirmed live via
-- `ERROR 42725: function public.apply_review(...) is not unique` when 03_TEST
-- called the old 5-arg shape. This is the identical class of bug already
-- documented at blueprint.md §1.11 for get_browsable_decks v5 — same fix
-- applies: an explicit `DROP FUNCTION` of the old signature is REQUIRED before
-- (or after) this CREATE OR REPLACE. That drop is 02b_HOTFIX_drop_ambiguous_
-- apply_review_overload.sql — run it immediately after this file, then re-run
-- 03_TEST.
--
-- Every existing caller (submit_review's compat wrapper, and all 7 other
-- question types' StudyMode.jsx calls, none of which pass a 6th argument)
-- keeps working unchanged once only the 6-arg overload survives — the new
-- parameter defaults to NULL for all of them.
--
-- Body is otherwise BYTE-IDENTICAL to the live Sprint 7.4 function (see
-- docs/database/sprint7.4/02_FUNCTIONS_apply_review.sql) with one addition:
-- p_selected_answer is threaded into the existing review_events INSERT as a
-- new trailing column value.
--
-- Run as its own submission AFTER 01_SCHEMA is committed (review_events.
-- selected_answer must exist first). Pure CREATE OR REPLACE — let it COMMIT;
-- 03_TEST (BEGIN/ROLLBACK) verifies afterward in its own submission.

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

  v_quality  := CASE p_rating WHEN 'hard' THEN 1 WHEN 'medium' THEN 3 ELSE 5 END;
  v_easiness := CASE p_rating WHEN 'hard' THEN 2.3 WHEN 'medium' THEN 2.5 ELSE 2.6 END;

  SELECT r.id, COALESCE(r.rung, 0), r.status, COALESCE(r.repetition, 0)
    INTO v_review_id, v_cur_rung, v_cur_status, v_rep
  FROM public.reviews r
  WHERE r.user_id = p_user_id AND r.flashcard_id = p_flashcard_id;

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

-- ── PostgREST: pick up the new signature ────────────────────────────────────
NOTIFY pgrst, 'reload schema';
