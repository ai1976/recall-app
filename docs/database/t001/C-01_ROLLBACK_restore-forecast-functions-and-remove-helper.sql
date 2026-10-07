-- Name: [FUNCTIONS] T-001 C-01 ROLLBACK (v2) - restore get_due_forecast and get_due_forecast_buckets to their pre-C-01 bodies and remove the shared helper
--
-- Description: PERSISTENT DDL (undo of C-01_FUNCTIONS_due-eligibility-helper-and-forecast-functions.sql). Run only after the Founder has authorized it
-- (Gate 2 for this exact hash, as for every SQL file). It restores the two public functions to the bodies of docs/discussions/evidence/T-001_RUN-1B_04-10-2026.md
-- (the live bodies of 04/10/2026) and then drops public.fn_due_eligible_dates, in that order (the public functions depend on the helper).
-- v2 (supersedes v1 c114289e439f, which was never authorized or run): the byte comparison promised in v1 has been done against the live definitions
-- saved by diagnostic 10 v3 (docs/discussions/evidence/T-001_C-slice1-P1_07-10-2026.json, index T-001_C-slice1-index_07-10-2026.md section 3). RESULT: the
-- function bodies below are identical to the live definitions of get_due_forecast (1,762 characters) and get_due_forecast_buckets (2,516) except for
-- exactly two things, both intended and both stated here: (1) the search_path clause is written unquoted, SET search_path TO public, extensions (the
-- project standard; the live definition prints it as SET search_path TO 'public', 'extensions', and the live configuration value is
-- search_path=public, extensions, which is also what the unquoted form stores); (2) the live bodies contain carriage-return characters (Windows line
-- endings) which this line-feed file does not reproduce. The function LOGIC restored is therefore exactly the live logic.
-- HOW A ROLLBACK IS VERIFIED AFTER ANY USE OF THIS FILE: run RUN P1 of diagnostic 10 again and compare, after removing carriage returns from both sides,
-- the returned definitions of get_due_forecast and get_due_forecast_buckets with the saved pre-C-01 definitions (a raw md5 will differ only because of the
-- carriage returns); the helper must be absent (new_routine_names_already_present must not list fn_due_eligible_dates), and the execute_roles of both
-- functions must again be exactly authenticated, postgres, service_role.
-- The Supabase SQL Editor runs one selection in ONE transaction; this file has no verification and no ROLLBACK.

-- 1. get_due_forecast, as of 04/10/2026
CREATE OR REPLACE FUNCTION public.get_due_forecast(p_user_id uuid)
 RETURNS TABLE(due_today integer, due_next_7 integer, due_next_30 integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
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
$function$
;

REVOKE ALL ON FUNCTION public.get_due_forecast(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_due_forecast(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_due_forecast(uuid) TO authenticated, service_role;

-- 2. get_due_forecast_buckets, as of 04/10/2026
CREATE OR REPLACE FUNCTION public.get_due_forecast_buckets(p_user_id uuid)
 RETURNS TABLE(bucket_index integer, bucket_label text, scheduled_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
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
$function$
;

REVOKE ALL ON FUNCTION public.get_due_forecast_buckets(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_due_forecast_buckets(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_due_forecast_buckets(uuid) TO authenticated, service_role;

-- 3. The helper (nothing else depends on it)
DROP FUNCTION IF EXISTS public.fn_due_eligible_dates(uuid, date);
