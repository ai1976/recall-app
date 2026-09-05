-- Name: [FUNCTIONS] Sprint 6.3 — dashboard reskin support RPCs
--
-- Description:
--   Three read-only SECURITY DEFINER RPCs backing the Sprint 6.3 dashboard reskin.
--   All three follow the established L5 IDOR idiom (self-or-admin for the student
--   RPC; professor-or-admin for the two educator RPCs — same guard as the
--   get_professor_* analytics family, docs/database/security/09), pinned
--   unquoted search_path, and REVOKE public/anon + GRANT authenticated.
--
--   1. get_due_forecast_buckets(p_user_id)
--        The 8-lane forward-scheduled load behind ForwardLedgerMacro on the
--        student dashboard. Same "what counts as a scheduled review row"
--        predicate as get_due_forecast (active · not concept_card · course-
--        filtered · visibility-guarded · skip_until not in the future), but
--        instead of three cumulative thresholds it returns eight DISJOINT
--        buckets keyed to REVISOP_BUCKETS / BUCKET_DAYS in
--        src/lib/revisop-tokens.js: Today · 1d · 3d · 6d · 2w · 1mo · 3mo · 6mo+
--        at centre-day [0,1,3,6,14,30,90,180], nearest-centre assignment.
--        Overdue rows fold into bucket 0 ("Today"). Always returns exactly 8
--        rows (0-count buckets included) so the client maps straight to number[8].
--
--   2. get_educator_accuracy_by_qtype(p_professor_id, p_course_level)
--        "Accuracy by question type" for an educator's own cohort. Accuracy uses
--        the SRS ladder's own hit/miss mapping so it stays consistent with the
--        engine: quality 3 (Medium) or 5 (Easy) = hit, quality 1 (Hard) = miss.
--        quality 0 rows (skip / suspend bookkeeping) are excluded from the
--        denominator. question_type = 'concept_card' excluded entirely (never a
--        graded review surface). One row per question_type that has >= 1 graded
--        review, ordered by volume.
--
--   3. get_educator_cohort_forecast_buckets(p_professor_id, p_course_level)
--        The educator cohort variant of (1): the same 8-lane forward-scheduled
--        load, but summed across every student who has an active review on one
--        of this educator's published cards for the course. No per-viewer
--        visibility guard needed — an educator's cohort content is their own.
--        Powers the optional cohort ForwardLedgerMacro on the educator dashboard.
--
--   Deploy order: run this file as ONE Supabase SQL Editor submission (it
--   COMMITs — pure CREATE OR REPLACE, no destructive DDL), then run
--   02_TEST_dashboard_reskin_rpcs.sql (BEGIN/ROLLBACK) to verify, THEN push the
--   frontend that consumes them. Everything else in Sprint 6.3 is frontend-only.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. get_due_forecast_buckets — student forward-scheduled load, 8 disjoint lanes
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_due_forecast_buckets(p_user_id uuid)
 RETURNS TABLE (bucket_index integer, bucket_label text, scheduled_count integer)
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
  WITH spine(bucket_index, bucket_label) AS (
    VALUES (0,'Today'),(1,'1d'),(2,'3d'),(3,'6d'),(4,'2w'),(5,'1mo'),(6,'3mo'),(7,'6mo+')
  ),
  scheduled AS (
    SELECT (r.next_review_date - v_today) AS days_out
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
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN days_out <  1   THEN 0   -- overdue + today
        WHEN days_out <  2   THEN 1   -- centre 1d
        WHEN days_out <  5   THEN 2   -- centre 3d   (2..4)
        WHEN days_out < 10   THEN 3   -- centre 6d   (5..9)
        WHEN days_out < 22   THEN 4   -- centre 2w   (10..21)
        WHEN days_out < 60   THEN 5   -- centre 1mo  (22..59)
        WHEN days_out < 135  THEN 6   -- centre 3mo  (60..134)
        ELSE 7                        -- 6mo+        (135..)
      END AS bi
    FROM scheduled
  )
  SELECT s.bucket_index, s.bucket_label, COALESCE(COUNT(b.bi), 0)::int
  FROM spine s
  LEFT JOIN bucketed b ON b.bi = s.bucket_index
  GROUP BY s.bucket_index, s.bucket_label
  ORDER BY s.bucket_index;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_due_forecast_buckets(uuid) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_due_forecast_buckets(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_due_forecast_buckets(uuid) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. get_educator_accuracy_by_qtype — educator cohort accuracy, grouped by qtype
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_educator_accuracy_by_qtype(
  p_professor_id uuid,
  p_course_level text
)
 RETURNS TABLE (
   question_type text,
   total_graded  integer,
   hits          integer,
   accuracy_pct  numeric
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another educator''s cohort';
  END IF;

  RETURN QUERY
  WITH prof_cards AS (
    SELECT f.id, f.question_type
    FROM flashcards f
    WHERE f.user_id = p_professor_id
      AND f.target_course = p_course_level
      AND f.question_type <> 'concept_card'
  )
  SELECT
    pc.question_type,
    COUNT(*) FILTER (WHERE r.quality > 0)::int,
    COUNT(*) FILTER (WHERE r.quality IN (3, 5))::int,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE r.quality IN (3, 5))
            / NULLIF(COUNT(*) FILTER (WHERE r.quality > 0), 0),
      1
    )
  FROM prof_cards pc
  JOIN reviews r ON r.flashcard_id = pc.id
  GROUP BY pc.question_type
  HAVING COUNT(*) FILTER (WHERE r.quality > 0) > 0
  ORDER BY COUNT(*) FILTER (WHERE r.quality > 0) DESC;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_educator_accuracy_by_qtype(uuid, text) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_educator_accuracy_by_qtype(uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_educator_accuracy_by_qtype(uuid, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. get_educator_cohort_forecast_buckets — cohort variant of (1)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_educator_cohort_forecast_buckets(
  p_professor_id uuid,
  p_course_level text
)
 RETURNS TABLE (bucket_index integer, bucket_label text, scheduled_count integer)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_today date := CURRENT_DATE;
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another educator''s cohort';
  END IF;

  RETURN QUERY
  WITH spine(bucket_index, bucket_label) AS (
    VALUES (0,'Today'),(1,'1d'),(2,'3d'),(3,'6d'),(4,'2w'),(5,'1mo'),(6,'3mo'),(7,'6mo+')
  ),
  prof_cards AS (
    SELECT f.id
    FROM flashcards f
    WHERE f.user_id = p_professor_id
      AND f.target_course = p_course_level
      AND f.question_type <> 'concept_card'
  ),
  scheduled AS (
    SELECT (r.next_review_date - v_today) AS days_out
    FROM reviews r
    JOIN prof_cards pc ON pc.id = r.flashcard_id
    WHERE r.status = 'active'
      AND (r.skip_until IS NULL OR r.skip_until <= v_today)
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN days_out <  1   THEN 0
        WHEN days_out <  2   THEN 1
        WHEN days_out <  5   THEN 2
        WHEN days_out < 10   THEN 3
        WHEN days_out < 22   THEN 4
        WHEN days_out < 60   THEN 5
        WHEN days_out < 135  THEN 6
        ELSE 7
      END AS bi
    FROM scheduled
  )
  SELECT s.bucket_index, s.bucket_label, COALESCE(COUNT(b.bi), 0)::int
  FROM spine s
  LEFT JOIN bucketed b ON b.bi = s.bucket_index
  GROUP BY s.bucket_index, s.bucket_label
  ORDER BY s.bucket_index;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_educator_cohort_forecast_buckets(uuid, text) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_educator_cohort_forecast_buckets(uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_educator_cohort_forecast_buckets(uuid, text) TO authenticated;

-- ── PostgREST: pick up the new signatures ─────────────────────────────────────
NOTIFY pgrst, 'reload schema';
