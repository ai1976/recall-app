-- Name: [FUNCTIONS] SRS Ladder Epic — Phase 1 engine (interval helper, config, preview, submit, queue+forecast)
--
-- Description:
--   Phase 1 engine for the SRS Ladder Epic. Run this as its own Supabase SQL Editor submission
--   AFTER 01_SCHEMA is committed. Pure `CREATE OR REPLACE` / `DROP…CREATE` DDL — let it COMMIT;
--   do NOT append a ROLLBACK verification (that is 03_TEST's job, in its own submission).
--
--   Objects:
--     1. srs_interval_for_rung(p_rung, p_question_type)  -> integer
--          Internal calculator: the card's own curve if present, else '_default'. Locked down
--          (no anon/authenticated EXECUTE) — only the SECURITY DEFINER functions below call it.
--     2. get_srs_ladder_config()  -> jsonb  { "curves":[...], "rules":{...} }
--          The client's one-time mount fetch. Returns the SAME srs_ladder_rules row the server
--          enforces, so client-side button previews cannot drift from submit_review.
--          GRANT EXECUTE TO anon, authenticated (landing hero demo is anonymous).
--     3. srs_preview(p_rung, p_question_type DEFAULT NULL)
--          -> TABLE(rating text, resulting_rung int, interval_days int)   (3 rows: hard/medium/easy)
--          Server-side mirror of the transition maths for Sprint 6.4 + the drift-parity test.
--          NOT called in the study loop. GRANT EXECUTE TO anon, authenticated.
--     4. submit_review(p_user_id, p_flashcard_id, p_rating)
--          -> TABLE(new_rung smallint, next_review_date date, new_status text, interval_days int)
--          THE write SSOT for review scheduling. SECURITY DEFINER. L5 IDOR idiom
--          (p_user_id must equal auth.uid(); admins exempt; NULL session RAISEs). SELECT-or-INSERT
--          on (user_id, flashcard_id); applies the deterministic rung transition; graduates to
--          status='mastered' on Easy at top_rung; un-masters on any non-mastering grade.
--          GRANT EXECUTE TO authenticated only.
--     5. get_study_queue(p_user_id)  — DROP + CREATE to append `rung` to the return shape
--          (needed so the Phase 3 client can compute button previews with no per-card call).
--          Body is otherwise byte-identical to sprint6/01. MASTERED is excluded for free
--          (the filter is already `r.status = 'active'`).
--     6. get_due_forecast(p_user_id)  — body rewrite, signature unchanged. `due_today` now uses
--          the EXACT get_study_queue due predicate (user-tz today, status='active',
--          next_review_date <= today, skip_until null/<=today, question_type <> 'concept_card',
--          read-time course filter, L2 visibility guard). due_next_7 / due_next_30 = same
--          predicate with a forward date window (cumulative, preserving the current UI meaning).
--          Closes bugs.md "Due Items Forecast disagrees with the review queue".
--
--   search_path pinned UNQUOTED on every function (L3 17c outage lesson).
--   Ends with NOTIFY pgrst so PostgREST picks up the new/changed signatures.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. srs_interval_for_rung — internal calculator
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.srs_interval_for_rung(p_rung integer, p_question_type text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
  SELECT COALESCE(
    (SELECT interval_days FROM public.srs_ladder_curves
      WHERE question_type = p_question_type AND rung_index = p_rung),
    (SELECT interval_days FROM public.srs_ladder_curves
      WHERE question_type = '_default'      AND rung_index = p_rung)
  );
$function$;

REVOKE ALL ON FUNCTION public.srs_interval_for_rung(integer, text) FROM PUBLIC, anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. get_srs_ladder_config
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_srs_ladder_config()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
  SELECT jsonb_build_object(
    'curves', COALESCE((
      SELECT jsonb_agg(
               jsonb_build_object(
                 'question_type', c.question_type,
                 'rung_index',    c.rung_index,
                 'interval_days', c.interval_days
               )
               ORDER BY c.question_type, c.rung_index
             )
      FROM public.srs_ladder_curves c
    ), '[]'::jsonb),
    'rules', (SELECT r.rules FROM public.srs_ladder_rules r WHERE r.id = 1)
  );
$function$;

REVOKE ALL     ON FUNCTION public.get_srs_ladder_config() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_srs_ladder_config() TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. srs_preview
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.srs_preview(p_rung integer, p_question_type text DEFAULT NULL)
 RETURNS TABLE (rating text, resulting_rung integer, interval_days integer)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_rules   jsonb;
  v_top     integer;
  v_relearn integer;
  v_qt      text := COALESCE(p_question_type, 'flashcard');
  v_cur     integer;
BEGIN
  SELECT r.rules INTO v_rules FROM public.srs_ladder_rules r WHERE r.id = 1;
  IF v_rules IS NULL THEN
    RAISE EXCEPTION 'srs_ladder_rules not seeded';
  END IF;
  v_top     := (v_rules->>'top_rung')::int;
  v_relearn := (v_rules->>'relearn_step_days')::int;

  IF p_rung IS NULL OR p_rung < 0 THEN
    -- brand-new card: intervals from the configured entry rungs
    RETURN QUERY
      SELECT 'hard'::text,
             (v_rules->'new_card_rung'->>'hard')::int,
             v_relearn
      UNION ALL
      SELECT 'medium'::text,
             (v_rules->'new_card_rung'->>'medium')::int,
             public.srs_interval_for_rung((v_rules->'new_card_rung'->>'medium')::int, v_qt)
      UNION ALL
      SELECT 'easy'::text,
             (v_rules->'new_card_rung'->>'easy')::int,
             public.srs_interval_for_rung((v_rules->'new_card_rung'->>'easy')::int, v_qt);
  ELSE
    RETURN QUERY
      SELECT 'hard'::text, 0, v_relearn
      UNION ALL
      SELECT 'medium'::text,
             LEAST(p_rung, v_top),
             public.srs_interval_for_rung(LEAST(p_rung, v_top), v_qt)
      UNION ALL
      SELECT 'easy'::text,
             LEAST(p_rung + 1, v_top),
             public.srs_interval_for_rung(LEAST(p_rung + 1, v_top), v_qt);
  END IF;
END;
$function$;

REVOKE ALL     ON FUNCTION public.srs_preview(integer, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.srs_preview(integer, text) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. submit_review — the write SSOT for review scheduling
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.submit_review(
    p_user_id      uuid,
    p_flashcard_id uuid,
    p_rating       text
)
 RETURNS TABLE (new_rung smallint, next_review_date date, new_status text, interval_days integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_rules      jsonb;
  v_top        integer;
  v_relearn    integer;
  v_today      date;
  v_qtype      text;
  v_review_id  uuid;
  v_cur_rung   integer;
  v_cur_status text;
  v_rep        integer;
  v_new_rung   integer;
  v_new_status text;
  v_next       date;
  v_quality    integer;
  v_easiness   numeric;
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

  SELECT COALESCE(f.question_type, 'flashcard') INTO v_qtype
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

  new_rung         := v_new_rung::smallint;
  next_review_date := v_next;
  new_status       := v_new_status;
  interval_days    := (v_next - v_today);
  RETURN NEXT;
END;
$function$;

REVOKE ALL     ON FUNCTION public.submit_review(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.submit_review(uuid, uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.submit_review(uuid, uuid, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. get_study_queue — DROP + CREATE to append `rung` to the return shape
--    Body is byte-identical to docs/database/sprint6/01_FUNCTIONS_get_study_queue.sql
--    except: `rung smallint` added to RETURNS TABLE and `r.rung` added to the SELECT list.
--    MASTERED is excluded automatically (the filter is already `r.status = 'active'`).
-- ═══════════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.get_study_queue(uuid);

CREATE FUNCTION public.get_study_queue(p_user_id uuid)
 RETURNS TABLE (
   flashcard_id     uuid,
   card_user_id     uuid,
   contributed_by   uuid,
   target_course    text,
   subject_id       uuid,
   subject_name     text,
   topic_id         uuid,
   topic_name       text,
   custom_subject   text,
   custom_topic     text,
   front_text       text,
   front_image_url  text,
   back_text        text,
   back_image_url   text,
   difficulty       text,
   is_verified      boolean,
   question_type    text,
   next_review_date date,
   skip_until       date,
   last_reviewed_at timestamptz,
   rung             smallint
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_today        date;
  v_course_level text;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s study queue';
  END IF;

  SELECT
    (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date,
    p.course_level
  INTO v_today, v_course_level
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_today IS NULL THEN
    v_today := CURRENT_DATE;
  END IF;

  RETURN QUERY
  SELECT
    f.id,
    f.user_id,
    f.contributed_by,
    f.target_course,
    f.subject_id,
    s.name,
    f.topic_id,
    t.name,
    f.custom_subject,
    f.custom_topic,
    f.front_text,
    f.front_image_url,
    f.back_text,
    f.back_image_url,
    f.difficulty,
    f.is_verified,
    f.question_type,
    r.next_review_date,
    r.skip_until,
    r.last_reviewed_at,
    r.rung
  FROM reviews r
  JOIN flashcards f            ON f.id = r.flashcard_id
  LEFT JOIN subjects s         ON s.id = f.subject_id
  LEFT JOIN topics   t         ON t.id = f.topic_id
  WHERE r.user_id = p_user_id
    AND r.status = 'active'
    AND r.next_review_date <= v_today
    AND (r.skip_until IS NULL OR r.skip_until <= v_today)
    AND f.question_type <> 'concept_card'
    AND (
      v_course_level IS NULL
      OR f.target_course IS NULL
      OR f.target_course = v_course_level
    )
    AND (
      f.user_id = p_user_id
      OR f.visibility = 'public'
      OR (
        f.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships fr
          WHERE fr.status = 'accepted'
            AND (
              (fr.user_id = p_user_id AND fr.friend_id = f.user_id)
              OR (fr.friend_id = p_user_id AND fr.user_id = f.user_id)
            )
        )
      )
    )
  ORDER BY s.name NULLS LAST, f.custom_subject NULLS LAST, f.created_at;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_study_queue(uuid) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_study_queue(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_study_queue(uuid) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. get_due_forecast — body rewrite, signature unchanged (CREATE OR REPLACE keeps grants)
--    `due_today` now shares the EXACT get_study_queue predicate. Closes the 6.0 follow-up.
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_due_forecast(p_user_id uuid)
 RETURNS TABLE (due_today integer, due_next_7 integer, due_next_30 integer)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_today        date;
  v_course_level text;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;

  SELECT
    (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date,
    p.course_level
  INTO v_today, v_course_level
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_today IS NULL THEN
    v_today := CURRENT_DATE;
  END IF;

  RETURN QUERY
  WITH due AS (
    SELECT r.next_review_date AS nrd
    FROM reviews r
    JOIN flashcards f ON f.id = r.flashcard_id
    WHERE r.user_id = p_user_id
      AND r.status = 'active'
      AND (r.skip_until IS NULL OR r.skip_until <= v_today)
      AND f.question_type <> 'concept_card'
      AND (
        v_course_level IS NULL
        OR f.target_course IS NULL
        OR f.target_course = v_course_level
      )
      AND (
        f.user_id = p_user_id
        OR f.visibility = 'public'
        OR (
          f.visibility = 'friends'
          AND EXISTS (
            SELECT 1 FROM friendships fr
            WHERE fr.status = 'accepted'
              AND (
                (fr.user_id = p_user_id AND fr.friend_id = f.user_id)
                OR (fr.friend_id = p_user_id AND fr.user_id = f.user_id)
              )
          )
        )
      )
  )
  SELECT
    COUNT(*) FILTER (WHERE nrd <= v_today)::int,
    COUNT(*) FILTER (WHERE nrd <= v_today + 7)::int,
    COUNT(*) FILTER (WHERE nrd <= v_today + 30)::int
  FROM due;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_due_forecast(uuid) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_due_forecast(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_due_forecast(uuid) TO authenticated;

-- ── PostgREST: pick up the new + changed signatures ────────────────────────
NOTIFY pgrst, 'reload schema';
