-- Name: [TEST] get_following_leaderboard fix — no 42702, correct shape/order/security
-- Description: Verifies Sprint 6.5 Finding 2 after 02_FUNCTIONS is applied. One
-- transaction, collects into a temp table, single SELECT at the end (Supabase SQL
-- Editor shows only the last result set). Impersonation uses the repo idiom
-- `request.jwt.claims` JSON (same as sprint6.3/02_TEST). No persisted writes.
--
-- Covers: (1) return shape identical to the working sibling get_friends_leaderboard,
-- (2) SECURITY DEFINER + STABLE + unquoted search_path preserved, (3) EXECUTE grant
-- = authenticated (+ owner/service_role), (4) the RPC no longer raises 42702 and
-- returns a monotonic rank with exactly one is_self row, (5) students-only,
-- (6) SEMANTIC PARITY — for any user in BOTH leaderboards, reviews_this_week and
-- study_time_this_week_seconds match (guards the 02 reconstruction against drift),
-- (7) null session rejected.

BEGIN;

CREATE TEMP TABLE _r (test text, expected text, got text, status text) ON COMMIT DROP;

-- 1) shape parity with the working sibling ----------------------------------
WITH f AS (
  SELECT pg_get_function_result(p.oid) AS r
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_friends_leaderboard'
),
g AS (
  SELECT pg_get_function_result(p.oid) AS r
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_following_leaderboard'
)
INSERT INTO _r
SELECT 'return shape == get_friends_leaderboard',
       f.r, g.r,
       CASE WHEN f.r = g.r THEN 'PASS' ELSE 'FAIL' END
FROM f, g;

-- 2) security metadata unchanged -------------------------------------------------
INSERT INTO _r
SELECT 'SECURITY DEFINER + STABLE + unquoted search_path',
       'true / s / {search_path=public, extensions}',
       p.prosecdef::text || ' / ' || p.provolatile::text || ' / ' || COALESCE(p.proconfig::text,'NULL'),
       CASE WHEN p.prosecdef
             AND p.provolatile = 's'
             AND p.proconfig @> ARRAY['search_path=public, extensions']
            THEN 'PASS' ELSE 'FAIL' END
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='get_following_leaderboard';

-- 3) EXECUTE grants: authenticated yes, anon/PUBLIC no ------------------------
INSERT INTO _r
SELECT 'EXECUTE grant = authenticated only (no anon/PUBLIC)',
       'authenticated present, anon/PUBLIC absent',
       COALESCE(string_agg(g.grantee::text, ', ' ORDER BY g.grantee::text), '(none)'),
       CASE WHEN bool_or(g.grantee::text = 'authenticated')
             AND NOT bool_or(g.grantee::text IN ('anon','PUBLIC'))
            THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.routine_privileges g
JOIN information_schema.routines r ON r.specific_name = g.specific_name
WHERE r.routine_schema='public' AND r.routine_name='get_following_leaderboard';

-- 4/5/6) behavioural — impersonate a real student that follows >=1 person ----
DO $$
DECLARE
  v_student uuid;
  v_rows    int;
  v_self    int;
  v_ok_ord  boolean;
  v_nonstu  int;
  v_mismatch int;
BEGIN
  SELECT f.follower_id INTO v_student
  FROM public.follows f
  JOIN public.profiles p ON p.id = f.follower_id AND p.role = 'student'
  GROUP BY f.follower_id
  HAVING count(*) >= 1
  LIMIT 1;

  IF v_student IS NULL THEN
    INSERT INTO _r VALUES ('behavioural (needs a student with a followee)', 'n/a', 'no such student in this DB', 'SKIP');
    RETURN;
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_student, 'role', 'authenticated')::text, true);

  -- 4) no 42702; rank monotonic; exactly one is_self
  SELECT count(*),
         count(*) FILTER (WHERE is_self),
         bool_and(rank >= prev_rank)
    INTO v_rows, v_self, v_ok_ord
  FROM (
    SELECT is_self,
           rank,
           lag(rank, 1, rank) OVER (ORDER BY rank) AS prev_rank
    FROM public.get_following_leaderboard()
  ) q;

  INSERT INTO _r VALUES ('no 42702 — RPC returns rows',
    '>= 1', COALESCE(v_rows::text,'NULL'),
    CASE WHEN COALESCE(v_rows,0) >= 1 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('exactly one is_self row',
    '1', COALESCE(v_self::text,'NULL'),
    CASE WHEN v_self = 1 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('rank column is non-decreasing',
    'true', COALESCE(v_ok_ord::text,'NULL'),
    CASE WHEN v_ok_ord THEN 'PASS' ELSE 'FAIL' END);

  -- 5) students only
  SELECT count(*) INTO v_nonstu
  FROM public.get_following_leaderboard() lb
  JOIN public.profiles p ON p.id = lb.user_id
  WHERE p.role <> 'student';
  INSERT INTO _r VALUES ('students only (no professor/admin rows)',
    '0', v_nonstu::text,
    CASE WHEN v_nonstu = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- 6) semantic parity vs the working sibling for users present in BOTH
  SELECT count(*) INTO v_mismatch
  FROM public.get_following_leaderboard() fol
  JOIN public.get_friends_leaderboard()  fr USING (user_id)
  WHERE fol.reviews_this_week            IS DISTINCT FROM fr.reviews_this_week
     OR fol.study_time_this_week_seconds IS DISTINCT FROM fr.study_time_this_week_seconds;
  INSERT INTO _r VALUES ('weekly stats match get_friends_leaderboard for shared users',
    '0 mismatches', v_mismatch::text,
    CASE WHEN v_mismatch = 0 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

-- 7) null session is rejected -------------------------------------------------
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', NULL, true);
  BEGIN
    PERFORM public.get_following_leaderboard();
    INSERT INTO _r VALUES ('null session rejected', 'exception', 'no exception', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('null session rejected', 'exception', SQLERRM, 'PASS');
  END;
END $$;

SELECT * FROM _r ORDER BY (status <> 'PASS') DESC, test;

ROLLBACK;
