-- Name: [FUNCTIONS] Sprint 7.4 — apply_review (write SSOT) + submit_review (compat shim)
--
-- Description:
--   Run AFTER 01_SCHEMA is committed, as its own submission. Pure
--   CREATE OR REPLACE — let it COMMIT; 04_TEST (BEGIN/ROLLBACK) verifies
--   in its own submission afterward.
--
--   apply_review absorbs the CURRENT live submit_review body VERBATIM
--   (confirmed byte-identical against the live function via Phase 0
--   introspection, Q5 — same IDOR guard, same rules fetch, same
--   today-in-tz calc, same quality/easiness mapping, same new-card-vs-
--   existing-card transition branches) and adds:
--     - p_is_correct / p_source parameters (both default NULL)
--     - v_topic_id captured alongside v_qtype in the existing flashcard lookup
--     - v_rung_before captured right after the existing defensive clamp,
--       using the already-clamped v_cur_rung (NULL for a brand-new card)
--     - ONE review_events INSERT after the IF/ELSE branch, using the same
--       final v_new_rung / v_new_status / v_next variables the transition
--       logic already computed — not duplicated into both branches.
--   Putting both writes in the same function body makes them atomic by
--   construction (same transaction, no explicit locking needed): if the
--   review_events INSERT fails for any reason, the reviews write in the
--   same invocation rolls back with it (04_TEST proves this directly).
--
--   submit_review becomes a thin LANGUAGE sql wrapper delegating to
--   apply_review(..., NULL, NULL) — a stale cached client bundle calling
--   the old three-argument signature keeps working during the deploy
--   window, and its events log with is_correct = NULL (no verdict, exactly
--   like today's self-graded flow). Grants preserved explicitly.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. apply_review — write SSOT for review scheduling + history
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.apply_review(
    p_user_id      uuid,
    p_flashcard_id uuid,
    p_rating       text,
    p_is_correct   boolean DEFAULT NULL,
    p_source       text    DEFAULT NULL
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
  --    so a failure here rolls back the reviews write too (04_TEST proves it) ──
  INSERT INTO public.review_events (
    user_id, flashcard_id, rating, is_correct, question_type, topic_id,
    rung_before, rung_after, status_after, interval_days, next_review_date, source
  ) VALUES (
    p_user_id, p_flashcard_id, p_rating, p_is_correct, v_qtype, v_topic_id,
    v_rung_before, v_new_rung, v_new_status, (v_next - v_today), v_next, p_source
  );

  new_rung         := v_new_rung::smallint;
  next_review_date := v_next;
  new_status       := v_new_status;
  interval_days    := (v_next - v_today);
  RETURN NEXT;
END;
$function$;

REVOKE ALL     ON FUNCTION public.apply_review(uuid, uuid, text, boolean, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.apply_review(uuid, uuid, text, boolean, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. submit_review — thin backward-compat wrapper (HARD requirement: a cached
--    old client bundle may still call this during the SQL-first deploy window;
--    it must keep working, logging events with is_correct = NULL)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.submit_review(p_user_id uuid, p_flashcard_id uuid, p_rating text)
 RETURNS TABLE (new_rung smallint, next_review_date date, new_status text, interval_days integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
  SELECT * FROM public.apply_review(p_user_id, p_flashcard_id, p_rating, NULL, NULL);
$function$;

REVOKE ALL     ON FUNCTION public.submit_review(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.submit_review(uuid, uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.submit_review(uuid, uuid, text) TO authenticated;

-- ── PostgREST: pick up the new signature (apply_review) ────────────────────
NOTIFY pgrst, 'reload schema';
