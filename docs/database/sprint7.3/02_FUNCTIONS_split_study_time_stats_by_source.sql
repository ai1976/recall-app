-- [FUNCTIONS] Split get_study_time_stats by session source (in-app vs offline)
-- Description: Adds today/week in-app (source='study_mode') and offline
-- (source='manual') second-totals alongside the existing combined totals, so
-- the Sprint 7.3-C dashboard Study Time report can show the split without a
-- new table or a breaking response shape for the 4 existing columns.
--
-- Changing the output column list requires DROP + CREATE — Postgres refuses
-- CREATE OR REPLACE across a return-type change. The 4 existing columns and
-- their values are otherwise byte-for-byte identical to the live function
-- (confirmed against docs/database/security/08_FUNCTIONS_read_idor_guards_group_a.sql).
-- The IDOR guard, SECURITY DEFINER, and unquoted search_path are preserved
-- exactly. `source` is confirmed (grep of src/) to only ever be 'manual'
-- (StudyTimerWidget/StudyTimerContext) or 'study_mode' (StudyMode.jsx) —
-- no other writers exist.
--
-- Run in Supabase, confirm with the [TEST] query below, THEN push/rely on the
-- dependent frontend (Dashboard.jsx's Study Time report + GoalProgressWidget's
-- todaySeconds, which already sum the two new columns).

DROP FUNCTION IF EXISTS public.get_study_time_stats(uuid, date);

CREATE FUNCTION public.get_study_time_stats(p_user_id uuid, p_local_date date)
 RETURNS TABLE(
   today_seconds bigint,
   week_seconds bigint,
   today_sessions bigint,
   week_sessions bigint,
   today_seconds_in_app bigint,
   today_seconds_offline bigint,
   week_seconds_in_app bigint,
   week_seconds_offline bigint
 )
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
DECLARE
  v_week_start date;
  v_week_end   date;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  v_week_start := date_trunc('week', p_local_date)::date;
  v_week_end   := v_week_start + 6;
  RETURN QUERY
  SELECT
    COALESCE(SUM(CASE WHEN s.session_date = p_local_date THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN s.session_date BETWEEN v_week_start AND v_week_end THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COUNT(CASE WHEN s.session_date = p_local_date THEN 1 END)::bigint,
    COUNT(CASE WHEN s.session_date BETWEEN v_week_start AND v_week_end THEN 1 END)::bigint,
    COALESCE(SUM(CASE WHEN s.session_date = p_local_date AND s.source = 'study_mode' THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN s.session_date = p_local_date AND s.source = 'manual' THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN s.session_date BETWEEN v_week_start AND v_week_end AND s.source = 'study_mode' THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN s.session_date BETWEEN v_week_start AND v_week_end AND s.source = 'manual' THEN s.duration_seconds ELSE 0 END), 0)::bigint
  FROM public.study_sessions s
  WHERE s.user_id = p_user_id;
END;
$function$;

-- DROP FUNCTION removes prior grants — re-apply. Only 'authenticated' is
-- needed: every call site (Dashboard.jsx) is behind the auth guard already;
-- no unauthenticated page calls this RPC.
GRANT EXECUTE ON FUNCTION public.get_study_time_stats(uuid, date) TO authenticated;
