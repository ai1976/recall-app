-- Name: [DIAGNOSTIC] get_following_leaderboard ambiguous "rank" (Sprint 6.5 Finding 2)
-- Description: Pulls the LIVE source of get_following_leaderboard and its working
-- sibling get_friends_leaderboard, plus the grant/security metadata, so the fix in
-- 02_FUNCTIONS can be ported onto the real body (change ONLY the ambiguous `rank`
-- identifier — keep every WITH / JOIN / filter exactly as live). Read-only.
--
-- Live symptom (production, Following tab):
--   POST /rest/v1/rpc/get_following_leaderboard  -> 400
--   Postgres 42702: column reference "rank" is ambiguous — could refer to either a
--   PL/pgSQL variable or a table column
-- Cause: the RETURNS TABLE (... rank ...) OUT column is an implicit plpgsql
-- variable; the body also has a `RANK()/DENSE_RANK() ... AS rank` (or a table
-- column `rank`) that collides on a bare `rank` reference (ORDER BY / WHERE / SELECT).

-- 1) Full live definition of the broken function ------------------------------
SELECT pg_get_functiondef(p.oid) AS get_following_leaderboard_live_src
FROM   pg_proc p
JOIN   pg_namespace n ON n.oid = p.pronamespace
WHERE  n.nspname = 'public'
  AND  p.proname = 'get_following_leaderboard';

-- 2) Full live definition of the WORKING sibling (behavioural reference) ------
SELECT pg_get_functiondef(p.oid) AS get_friends_leaderboard_live_src
FROM   pg_proc p
JOIN   pg_namespace n ON n.oid = p.pronamespace
WHERE  n.nspname = 'public'
  AND  p.proname = 'get_friends_leaderboard';

-- 3) Signature / security / search_path / volatility for both -----------------
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid)             AS returns,
       p.prosecdef                               AS security_definer,
       p.provolatile                             AS volatility,   -- s = STABLE
       p.proconfig                               AS settings      -- expect search_path=public, extensions
FROM   pg_proc p
JOIN   pg_namespace n ON n.oid = p.pronamespace
WHERE  n.nspname = 'public'
  AND  p.proname IN ('get_following_leaderboard', 'get_friends_leaderboard')
ORDER  BY p.proname;

-- 4) EXECUTE grants for both (the fix must preserve these exactly) ------------
SELECT r.routine_name, g.grantee, g.privilege_type
FROM   information_schema.routine_privileges g
JOIN   information_schema.routines r
       ON r.specific_name = g.specific_name
WHERE  r.routine_schema = 'public'
  AND  r.routine_name IN ('get_following_leaderboard', 'get_friends_leaderboard')
ORDER  BY r.routine_name, g.grantee;

-- 5) Reproduce the error (optional; run as a normal authenticated session) ----
-- SELECT * FROM public.get_following_leaderboard();  -- expect 42702 pre-fix
