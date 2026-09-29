-- Name: [FUNCTIONS] get_study_heatmap v2 - count logged study time, not just reviews (Sprint 8.8.5b, bug #1)
-- Description: Aarya Bapat logged ~3h of offline study on 28-29/09/2026; the rows exist in
--   study_sessions but the heatmap only read user_activity_log (activity_type='review'), so a day with
--   study time and no card review could never be coloured. v2 returns the UNION of review days and
--   study-session days and adds a trailing column study_seconds (SUM of study_sessions.duration_seconds
--   for that session_date, ALL sources: manual / study_mode / practice_mode).
--   Review-side semantics are unchanged (same tz-adjusted COUNT of status='active' reviews; a review-log
--   day with no matching active review still reports review_count 0, as v1 did).
--   session_date is already the student's LOCAL date (stored by the client), so no tz conversion.
--   Deployed via DROP + CREATE because RETURNS TABLE gains a column (same reasoning as get_study_queue /
--   get_study_time_stats). Old frontend keeps working: it reads review_date/review_count and ignores the
--   extra column. Grants re-applied: authenticated only. IDOR guard preserved.
--   Run 02_DIAGNOSTIC first; run this file on its own (no ROLLBACK/verification in the same run).

DROP FUNCTION IF EXISTS public.get_study_heatmap(uuid, integer);

CREATE FUNCTION public.get_study_heatmap(p_user_id uuid, p_days integer DEFAULT 90)
 RETURNS TABLE(review_date date, review_count integer, study_seconds integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  WITH user_tz AS (
    SELECT COALESCE(pr.timezone, 'Asia/Kolkata') AS tz FROM public.profiles pr WHERE pr.id = p_user_id
  ),
  aggregated_reviews AS (
    SELECT (rv.created_at AT TIME ZONE (SELECT ut.tz FROM user_tz ut))::date AS rdate, COUNT(*)::integer AS cnt
    FROM public.reviews rv
    WHERE rv.user_id = p_user_id AND rv.status = 'active'
      AND rv.created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY 1
  ),
  review_days AS (
    SELECT ual.activity_date AS day
    FROM public.user_activity_log ual
    WHERE ual.user_id = p_user_id AND ual.activity_type = 'review'
      AND ual.activity_date >= CURRENT_DATE - p_days
  ),
  study_days AS (
    SELECT ss.session_date AS day, SUM(ss.duration_seconds)::integer AS secs
    FROM public.study_sessions ss
    WHERE ss.user_id = p_user_id AND ss.session_date >= CURRENT_DATE - p_days
    GROUP BY ss.session_date
  ),
  all_days AS (
    SELECT rd.day FROM review_days rd
    UNION
    SELECT sd.day FROM study_days sd
  )
  SELECT ad.day, COALESCE(ar.cnt, 0), COALESCE(sd2.secs, 0)
  FROM all_days ad
  LEFT JOIN aggregated_reviews ar ON ar.rdate = ad.day
  LEFT JOIN study_days sd2 ON sd2.day = ad.day
  ORDER BY ad.day;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_study_heatmap(uuid, integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_study_heatmap(uuid, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
