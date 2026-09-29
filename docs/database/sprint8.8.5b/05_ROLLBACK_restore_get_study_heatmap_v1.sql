-- Name: [FUNCTIONS] ROLLBACK - restore get_study_heatmap v1 (Sprint 8.8.5b)
-- Description: Emergency revert of 03_FUNCTIONS to the exact v1 body from
--   security/08_FUNCTIONS_read_idor_guards_group_a.sql (IDOR guard, review-only). Only needed if v2 misbehaves.
--   The new frontend tolerates v1 (it treats a missing study_seconds as 0).

DROP FUNCTION IF EXISTS public.get_study_heatmap(uuid, integer);

CREATE FUNCTION public.get_study_heatmap(p_user_id uuid, p_days integer DEFAULT 90)
 RETURNS TABLE(review_date date, review_count integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  WITH user_tz AS (
    SELECT COALESCE(timezone, 'Asia/Kolkata') AS tz FROM profiles WHERE id = p_user_id
  ),
  aggregated_reviews AS (
    SELECT (created_at AT TIME ZONE (SELECT tz FROM user_tz))::date AS rdate, COUNT(*)::integer AS cnt
    FROM reviews
    WHERE user_id = p_user_id AND status = 'active' AND created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY 1
  )
  SELECT ual.activity_date, COALESCE(ar.cnt, 0)
  FROM user_activity_log ual
  LEFT JOIN aggregated_reviews ar ON ar.rdate = ual.activity_date
  WHERE ual.user_id = p_user_id AND ual.activity_type = 'review' AND ual.activity_date >= CURRENT_DATE - p_days
  ORDER BY ual.activity_date;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_study_heatmap(uuid, integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_study_heatmap(uuid, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
