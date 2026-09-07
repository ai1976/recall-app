-- Name: [FUNCTIONS] Fix get_following_leaderboard ambiguous "rank" (Sprint 6.5 Finding 2, FIX)
-- Description: Resolves Postgres 42702 on the Leaderboard "Following" tab. The
-- RETURNS TABLE (rank integer, ...) OUT column shadows a `rank` produced inside the
-- body (window-function alias / CTE column), so a bare `rank` in ORDER BY / WHERE /
-- SELECT is ambiguous and the RPC 400s. The "Friends" tab RPC
-- (get_friends_leaderboard) is unaffected and is the behavioural reference.
--
-- FIX APPROACH — in-place qualification, NO OUT-column rename:
--   * `#variable_conflict use_column` pragma → bare ambiguous identifiers resolve
--     to the column, not the OUT variable (matches the pre-bug intent everywhere a
--     bare `rank` appears).
--   * the window-function result is aliased `rnk` (never `rank`) and every
--     reference is table-qualified, so no ambiguity remains even without the pragma.
--   * RETURNS TABLE shape, arg list (none), SECURITY DEFINER, STABLE,
--     search_path (unquoted `public, extensions`) and the auth.uid() gate are
--     preserved. Return column stays `rank` → LeaderboardWidget.jsx (`row.rank`)
--     needs NO change; this SQL ships alone.
--
-- ⚠️ DEPLOY PREREQUISITE: run 01_DIAGNOSTIC first and DIFF this body against the
-- live source. The WITH / JOIN / week-boundary / student-filter / top-20 +
-- always-include-self logic below is reconstructed from DATABASE_SCHEMA.md and the
-- live get_friends_leaderboard. If the live body differs, port THIS file's only
-- real change (the `rank` -> `rnk` alias + qualification + the pragma) onto the
-- live body verbatim rather than replacing the logic wholesale.

CREATE OR REPLACE FUNCTION public.get_following_leaderboard()
 RETURNS TABLE (
   rank                          integer,
   user_id                       uuid,
   full_name                     text,
   is_self                       boolean,
   reviews_this_week             bigint,
   study_time_this_week_seconds  bigint
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
#variable_conflict use_column
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  WITH wk AS (
    SELECT date_trunc('week', CURRENT_DATE)::date AS start_date
  ),
  -- caller + everyone the caller follows, students only
  cohort AS (
    SELECT v_uid AS uid
    UNION
    SELECT f.followee_id
    FROM public.follows f
    WHERE f.follower_id = v_uid
  ),
  stats AS (
    SELECT
      p.id                                                 AS uid,
      p.full_name                                          AS full_name,
      COALESCE((
        SELECT COUNT(*)
        FROM public.reviews rv, wk
        WHERE rv.user_id = p.id
          AND rv.created_at >= wk.start_date
      ), 0)::bigint                                        AS reviews_this_week,
      COALESCE((
        SELECT SUM(ss.duration_seconds)
        FROM public.study_sessions ss, wk
        WHERE ss.user_id = p.id
          AND ss.created_at >= wk.start_date
      ), 0)::bigint                                        AS study_time_this_week_seconds
    FROM cohort c
    JOIN public.profiles p ON p.id = c.uid AND p.role = 'student'
  ),
  ranked AS (
    SELECT
      s.uid,
      s.full_name,
      s.reviews_this_week,
      s.study_time_this_week_seconds,
      DENSE_RANK() OVER (
        ORDER BY s.reviews_this_week DESC,
                 s.study_time_this_week_seconds DESC
      )::integer AS rnk
    FROM stats s
  )
  SELECT
    r.rnk                          AS rank,
    r.uid                          AS user_id,
    r.full_name                    AS full_name,
    (r.uid = v_uid)                AS is_self,
    r.reviews_this_week            AS reviews_this_week,
    r.study_time_this_week_seconds AS study_time_this_week_seconds
  FROM ranked r
  WHERE r.rnk <= 20 OR r.uid = v_uid
  ORDER BY r.rnk ASC, r.full_name ASC;
END;
$function$;

-- Preserve the live grant model (see 01_DIAGNOSTIC step 4). Expected:
REVOKE ALL ON FUNCTION public.get_following_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_following_leaderboard() TO authenticated;

NOTIFY pgrst, 'reload schema';
