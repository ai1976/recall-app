-- Name: [DIAGNOSTIC] get_following_leaderboard reconstruction audit — capture live body + focused diff (Task 6.5-D)
-- Description: Task 6.5-D bounded audit. The Sprint 6.5 [FIX] (commit 72693fe) replaced the
-- WHOLE body of get_following_leaderboard with a reconstruction templated off
-- get_friends_leaderboard, because 01_DIAGNOSTIC's output (the live pre-fix body) was not
-- saved before 02_FUNCTIONS overwrote the function. This file (a) re-captures the CURRENT
-- (reconstructed) live definition so it is committed, and (b) gives the operator a focused
-- three-point diff to confirm the reconstruction returns the caller's FOLLOWED users and
-- only those. Read-only. Run in the Supabase SQL Editor as any role.
--
-- ── Recovery status of the ORIGINAL (pre-fix) body ───────────────────────────────────────
--   * git — UNRECOVERABLE. `git log -S 'get_following_leaderboard' --all` → only 3 commits
--     (071395d Sprint 3.5 create, 4c5c884 landmine doc, 72693fe the 6.5 fix). Sprint 3.5 ran
--     the CREATE directly in Supabase; no .sql file was ever committed. `git log --all
--     --diff-filter=A/D` over '*leaderboard*' confirms the only leaderboard SQL files that
--     ever existed in the repo are sprint6.5/01..03.
--   * DATABASE_SCHEMA.md @ 071395d — the ORIGINAL BEHAVIOURAL CONTRACT is documented (not the
--     body). Verbatim, Sprint 3.5:
--       "Returns top 20 followees (students only) + the caller's own row regardless of rank,
--        for the leaderboard widget (Following tab)."
--       "Aggregates full followee set before applying top-20 limit — caller's rank is exact,
--        not an approximation. Same DENSE_RANK logic as friends leaderboard."
--       "SECURITY DEFINER. Caller must be authenticated. Students only."
--       Week boundary (from the get_friends_leaderboard sibling block, same sprint):
--        "date_trunc('week', CURRENT_DATE) (Monday, server UTC). All stats COALESCE to 0."
--     RETURNS TABLE (rank integer, user_id uuid, full_name text, is_self boolean,
--        reviews_this_week bigint, study_time_this_week_seconds bigint).
--   * Supabase daily backup — the 6.5 deploy was 07/09/2026; a 06/09 or earlier backup still
--     holds the pre-fix function. If the plan allows a PITR / branch restore, run
--     `SELECT pg_get_functiondef('public.get_following_leaderboard'::regprocedure);` there and
--     paste it under "ORIGINAL BODY (from backup)" below. If not restorable, the diff relies
--     on the documented contract above (sufficient for the three focus areas).

-- ─────────────────────────────────────────────────────────────────────────────────────────
-- 1) CURRENT (reconstructed) live definition — paste the result under the marker below and
--    commit this file with it filled in.
-- ─────────────────────────────────────────────────────────────────────────────────────────
SELECT pg_get_functiondef('public.get_following_leaderboard'::regprocedure) AS current_live_src;

SELECT pg_get_functiondef('public.get_friends_leaderboard'::regprocedure)   AS sibling_live_src;

-- signature / security / search_path / volatility (expect: both identical except name)
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid)             AS returns,
       p.prosecdef                               AS security_definer,   -- expect t
       p.provolatile                             AS volatility,         -- expect s (STABLE)
       p.proconfig                               AS settings            -- expect {search_path=public, extensions}
FROM   pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE  n.nspname = 'public'
  AND  p.proname IN ('get_following_leaderboard','get_friends_leaderboard')
ORDER  BY p.proname;

-- ─────────────────────────────────────────────────────────────────────────────────────────
-- CURRENT LIVE BODY (pg_get_functiondef output — PASTE HERE, then commit)
-- ─────────────────────────────────────────────────────────────────────────────────────────
/*
<paste `current_live_src` here>
*/

-- Expected content (the deployed 02_FUNCTIONS body — DATABASE_SCHEMA.md + changelog both
-- record `CREATE OR REPLACE ... "Success. No rows returned"` on 07/09/2026, so absent an
-- out-of-band hand-edit this IS what is live). The audit diffs the pasted body against
-- these three focus areas:
--
--   ┌─ FOCUS 1 — follow-graph join (the primary risk vector) ────────────────────────────┐
--   │ Deployed body:                                                                     │
--   │   cohort AS (                                                                      │
--   │     SELECT v_uid AS uid                                                            │
--   │     UNION                                                                          │
--   │     SELECT f.followee_id FROM public.follows f WHERE f.follower_id = v_uid         │
--   │   )                                                                               │
--   │ Table  = public.follows        Predicate = follower_id = auth.uid()               │
--   │ Projects followee_id → DIRECTIONAL ("users the caller follows"). CORRECT for a     │
--   │ "Following" leaderboard. It does NOT touch `friendships` and has no mutual/        │
--   │ reciprocal ("...AND EXISTS reverse row") clause — that would be the get_friends_   │
--   │ leaderboard semantic and the wrong answer here.                                    │
--   │ follows schema (DATABASE_SCHEMA.md): follower_id, followee_id, both FK auth.users, │
--   │ UNIQUE(follower_id,followee_id), CHECK(follower_id <> followee_id).                │
--   │ VERDICT: MATCH — directional, matches "followees" in the 071395d contract.         │
--   └───────────────────────────────────────────────────────────────────────────────────┘
--
--   ┌─ FOCUS 2 — population filter ─────────────────────────────────────────────────────┐
--   │ Deployed body:  JOIN public.profiles p ON p.id = c.uid AND p.role = 'student'      │
--   │ Students-only. No course_level / target_course / account_type filter.              │
--   │ 071395d contract: "Students only." — no course filter mentioned; neither sibling   │
--   │ (get_friends_leaderboard, get_my_friends_with_stats) has one.                      │
--   │ Note: the caller row also flows through this join, so a non-student caller gets an │
--   │ empty board (no self row). Consistent with intended use — LeaderboardWidget only   │
--   │ renders in the student dashboard branch.                                           │
--   │ VERDICT: MATCH.                                                                    │
--   └───────────────────────────────────────────────────────────────────────────────────┘
--
--   ┌─ FOCUS 3 — result window ─────────────────────────────────────────────────────────┐
--   │ Deployed body:                                                                     │
--   │   ranked AS (SELECT ..., DENSE_RANK() OVER (ORDER BY reviews_this_week DESC,        │
--   │              study_time_this_week_seconds DESC)::int AS rnk FROM stats)             │
--   │   SELECT ... , (r.uid = v_uid) AS is_self FROM ranked r                            │
--   │   WHERE r.rnk <= 20 OR r.uid = v_uid                                               │
--   │   ORDER BY r.rnk ASC, r.full_name ASC;                                             │
--   │ N = 20. Self always returned (OR r.uid = v_uid), regardless of rank. Rank is       │
--   │ computed over the FULL cohort before the <= 20 slice → caller's rank is exact.     │
--   │ is_self true on exactly one row (caller appears in cohort exactly once via UNION). │
--   │ 071395d contract: "top 20 followees + the caller's own row regardless of rank",    │
--   │ "Aggregates full followee set before applying top-20 limit — caller's rank is      │
--   │ exact", "Same DENSE_RANK logic as friends leaderboard".                            │
--   │ VERDICT: MATCH — N, self-inclusion, exact-rank ordering all as documented.         │
--   └───────────────────────────────────────────────────────────────────────────────────┘
--
-- Incidental (not a focus area, but checked): RETURNS TABLE shape == 071395d signature;
-- week boundary = date_trunc('week', CURRENT_DATE)::date with `>=`; both weekly stats
-- COALESCE(...,0); reviews counted on reviews.created_at; study time SUM(study_sessions.
-- duration_seconds); SECURITY DEFINER + STABLE + unquoted `SET search_path TO public,
-- extensions` + `IF auth.uid() IS NULL THEN RAISE` gate + REVOKE FROM PUBLIC,anon +
-- GRANT EXECUTE TO authenticated — all present and matching the Sprint 6.5 constraints.
--
-- The one dimension pg_get_functiondef + the contract CANNOT settle: whether the live
-- membership SET is right on real data. That is 04_AUDIT_membership_test.sql.
