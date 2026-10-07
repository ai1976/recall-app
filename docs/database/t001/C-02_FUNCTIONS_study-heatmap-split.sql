-- Name: [FUNCTIONS] T-001 C-02 (v1) - new study-heatmap function with the in-app and offline split and a student-local window (brief C v6, point 7)
--
-- Description: PERSISTENT DDL. Implements brief C v6 (20647dbce877, Gate 1 given by the Founder on 07/10/2026), C-7.1 to C-7.3. ADDS a new function
-- public.get_study_heatmap_split(p_user_id uuid, p_days integer DEFAULT 90); the live get_study_heatmap is NOT changed and stays until the frontend
-- is verified (brief C C-7.1). Run ONLY after: (a) QA has passed this exact file by hash and the Founder has approved it (Gate 2); (b) the pre-check
-- diagnostic 10 has been run and reconciled (study_sessions columns and source CHECK, user_activity_log columns, the new name absent). The Supabase SQL
-- Editor runs one selection in ONE transaction; this file has no verification and no ROLLBACK. Verification is C-02_TEST; undo is C-02_ROLLBACK.
--
-- Return columns, per local date (C-7.1):
--   review_date     the local calendar date
--   review_count    reviews created on that date in the profile's time zone, status 'active' only, exactly as the live function counts them
--   in_app_seconds  seconds of study_sessions with source 'study_mode' or 'practice_mode'
--   offline_seconds seconds of study_sessions with source 'manual'
--   study_seconds   seconds of study_sessions over ALL sources (the live meaning of study_seconds)
--   other_seconds   study_seconds - in_app_seconds - offline_seconds; it must be 0 on every day, so a source outside the three known ones fails a test
--                   instead of disappearing
-- Days listed: unchanged from the live function: a day appears when it has a review activity-log row (user_activity_log, activity_type 'review') or a
-- study session; review_count is then taken from the reviews table for that day (so a day with reviews but no activity-log row is not listed, as live).
-- Authorization (C-7.2): the caller must be the target or is_admin(), the same guard and error text as live; SECURITY DEFINER; pinned search_path;
-- grants no wider than the live get_study_heatmap (authenticated, postgres, service_role; no anon, no PUBLIC): the REVOKE below is required because
-- objects created by postgres are default-granted to anon, authenticated and service_role (T-001_FU4-*).
-- Window (C-7.3 c), the ONE intended difference from the live function: dates from (the student's local today - p_days) up to the student's local
-- today, both ends included, for all three sources, where the student's local today is (now() AT TIME ZONE profile timezone, default Asia/Kolkata)::date.
-- The live function mixes NOW() - p_days (an instant) for reviews with the server's CURRENT_DATE - p_days for the other two sources and has no upper end.
-- CONSEQUENCE TO REVIEW (stated, not hidden): the upper end means a study_sessions row whose client-written session_date is later than the profile's
-- local today (a device date ahead of the profile time zone) is not listed, where the live function lists it. Diagnostic 10 run P2
-- (study_sessions_dated_after_profile_local_today) measures how many such rows exist; if that count is not 0, this file waits for a decision.
-- A NULL or non-positive p_days returns no rows or a short window exactly as the date arithmetic gives (NULL: no rows, as live); no cap is added here.
-- Evidence relied on: live body and grants docs/discussions/evidence/T-001_RUN-1B_04-10-2026.md and T-001_RUN-2_04-10-2026.md; source values and mix
-- T-001_RUN-3 (brief C P7-E3); study_sessions.session_date is the client's local date (DATABASE_SCHEMA.md, confirmed by diagnostic 10 for the columns
-- and the source CHECK before this file runs). Lock order: none taken (read-only function).
-- Not changed here: get_study_heatmap, any table, trigger, policy or data.

CREATE OR REPLACE FUNCTION public.get_study_heatmap_split(p_user_id uuid, p_days integer DEFAULT 90)
 RETURNS TABLE(review_date date, review_count integer, in_app_seconds integer, offline_seconds integer, study_seconds integer, other_seconds integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;

  RETURN QUERY
  WITH user_tz AS (
    SELECT COALESCE((SELECT pr.timezone FROM public.profiles pr WHERE pr.id = p_user_id), 'Asia/Kolkata') AS tz
  ),
  win AS (
    SELECT (now() AT TIME ZONE ut.tz)::date AS today FROM user_tz ut
  ),
  aggregated_reviews AS (
    SELECT (rv.created_at AT TIME ZONE ut.tz)::date AS rdate, COUNT(*)::integer AS cnt
    FROM public.reviews rv
    CROSS JOIN user_tz ut
    CROSS JOIN win w
    WHERE rv.user_id = p_user_id
      AND rv.status = 'active'
      AND (rv.created_at AT TIME ZONE ut.tz)::date BETWEEN w.today - p_days AND w.today
    GROUP BY 1
  ),
  review_days AS (
    SELECT ual.activity_date AS day
    FROM public.user_activity_log ual
    CROSS JOIN win w
    WHERE ual.user_id = p_user_id
      AND ual.activity_type = 'review'
      AND ual.activity_date BETWEEN w.today - p_days AND w.today
  ),
  study_days AS (
    SELECT ss.session_date AS day,
           SUM(ss.duration_seconds)::integer AS tot_secs,
           (SUM(ss.duration_seconds) FILTER (WHERE ss.source IN ('study_mode', 'practice_mode')))::integer AS in_secs,
           (SUM(ss.duration_seconds) FILTER (WHERE ss.source = 'manual'))::integer AS off_secs
    FROM public.study_sessions ss
    CROSS JOIN win w
    WHERE ss.user_id = p_user_id
      AND ss.session_date BETWEEN w.today - p_days AND w.today
    GROUP BY ss.session_date
  ),
  all_days AS (
    SELECT rd.day FROM review_days rd
    UNION
    SELECT sd.day FROM study_days sd
  )
  SELECT ad.day,
         COALESCE(ar.cnt, 0),
         COALESCE(s.in_secs, 0),
         COALESCE(s.off_secs, 0),
         COALESCE(s.tot_secs, 0),
         COALESCE(s.tot_secs, 0) - COALESCE(s.in_secs, 0) - COALESCE(s.off_secs, 0)
  FROM all_days ad
  LEFT JOIN aggregated_reviews ar ON ar.rdate = ad.day
  LEFT JOIN study_days s ON s.day = ad.day
  ORDER BY ad.day;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_study_heatmap_split(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_study_heatmap_split(uuid, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_study_heatmap_split(uuid, integer) TO authenticated, service_role;
