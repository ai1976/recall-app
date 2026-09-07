-- Name: [TEST] get_following_leaderboard membership audit — returned set == followed set (Task 6.5-D)
-- Description: The decisive check for Task 6.5-D. 03_TEST proved the STAT MATH (weekly
-- numbers == get_friends_leaderboard for shared users) but NOT the MEMBERSHIP SET — a
-- wrong follow-scope with correct numbers would still pass 03_TEST. This file asserts the
-- rows get_following_leaderboard() returns are exactly {caller} ∪ {students the caller
-- follows}, ranked by reviews_this_week DESC (study_time DESC tiebreak), with one is_self.
--
-- Run in the Supabase SQL Editor. One transaction, ROLLBACK at the end — no persisted
-- writes. Impersonation uses the repo `request.jwt.claims` JSON idiom (same as 03_TEST /
-- sprint6.3/02_TEST). Pure SQL — no psql backslash commands.
--
-- ACCOUNT SELECTION: by default the DO block auto-selects the student who follows the MOST
-- other students (>= 1). To PIN a specific account (e.g. the one whose Following tab you
-- will screenshot), replace  NULL::uuid  on the marked line with  'your-uuid-here'::uuid .
--
-- ── RESULT — RUN 07/09/2026 ──────────────────────────────────────────────────────────────
--   Live follow graph is sparse: 6 `follows` rows, 4 distinct followers, MAX 1 followed-
--   student per student (no account follows >= 2). Ran on the richest available account
--   f9377860-0991-4cdc-9679-f347c61d71b4 (follows 1 student → 2 expected rows):
--     exact set equality ................................. PASS  (no extras, nothing missing)
--     exactly one is_self row ........................... PASS
--     rank ordered by reviews_this_week DESC ............ PASS
--     no row the caller does NOT follow ................ PASS
--     every followed student present (not collapsed) ... PASS
--   → 5/5 PASS. The >20 top-N cutoff + multi-followee ordering are unexercised on live
--     data (contract-trivial; the body's `WHERE rnk <= 20 OR uid = v_uid` matches the
--     Sprint 3.5 contract). Reconstruction is FAITHFUL on membership. Finding 2 closed.

BEGIN;

CREATE TEMP TABLE _m (check_name text, expected text, got text, status text) ON COMMIT DROP;

DO $$
DECLARE
  v_pinned     uuid := NULL::uuid;   -- ◄── PIN HERE: e.g. '00000000-0000-0000-0000-000000000000'::uuid
  v_uid        uuid;
  v_followed   uuid[];               -- everyone v_uid follows (raw, directional)
  v_expected   uuid[];               -- {self if student} ∪ {followees who are students}
  v_rpc        uuid[];               -- user_id set the RPC returned
  v_self_ct    int;
  v_extra      uuid[];               -- in RPC but NOT expected  → scope too WIDE
  v_missing    uuid[];               -- in expected but NOT RPC  → scope too NARROW / collapsed
  v_rank_ok    boolean;
  v_cohort_ct  int;
BEGIN
  -- ── choose the account ────────────────────────────────────────────────────────────────
  IF v_pinned IS NOT NULL THEN
    v_uid := v_pinned;
  ELSE
    SELECT f.follower_id INTO v_uid
    FROM public.follows f
    JOIN public.profiles pf ON pf.id = f.follower_id AND pf.role = 'student'
    JOIN public.profiles pe ON pe.id = f.followee_id AND pe.role = 'student'
    GROUP BY f.follower_id
    HAVING count(*) >= 1            -- ideally >= 2; live DB has none, so take the richest
    ORDER BY count(*) DESC
    LIMIT 1;
  END IF;

  IF v_uid IS NULL THEN
    INSERT INTO _m VALUES ('account with >=2 followed students', 'one exists',
      'none in this DB — seed one, then re-run (or pin a uuid)', 'BLOCKED');
    RETURN;
  END IF;

  -- ── expected set, computed WITHOUT the RPC (independent oracle) ────────────────────────
  SELECT array_agg(f.followee_id ORDER BY f.followee_id)
    INTO v_followed
  FROM public.follows f
  WHERE f.follower_id = v_uid;

  SELECT array_agg(x ORDER BY x) INTO v_expected FROM (
    SELECT v_uid AS x
      WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid AND role = 'student')
    UNION
    SELECT f.followee_id
    FROM public.follows f
    JOIN public.profiles p ON p.id = f.followee_id AND p.role = 'student'
    WHERE f.follower_id = v_uid
  ) s;

  v_cohort_ct := coalesce(array_length(v_expected, 1), 0);

  -- ── call the RPC as that user ───────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  SELECT array_agg(lb.user_id ORDER BY lb.user_id),
         count(*) FILTER (WHERE lb.is_self)
    INTO v_rpc, v_self_ct
  FROM public.get_following_leaderboard() lb;

  -- ranking: rank must be non-decreasing when rows are read in
  -- (reviews_this_week DESC, study_time_this_week_seconds DESC) order
  SELECT bool_and(rank >= prev) INTO v_rank_ok
  FROM (
    SELECT rank,
           lag(rank, 1, rank) OVER (ORDER BY reviews_this_week DESC,
                                             study_time_this_week_seconds DESC) AS prev
    FROM public.get_following_leaderboard()
  ) q;

  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ── set algebra ────────────────────────────────────────────────────────────────────
  SELECT array_agg(x ORDER BY x) INTO v_extra
  FROM (SELECT unnest(coalesce(v_rpc,      '{}'::uuid[]))
        EXCEPT
        SELECT unnest(coalesce(v_expected, '{}'::uuid[]))) a(x);

  SELECT array_agg(x ORDER BY x) INTO v_missing
  FROM (SELECT unnest(coalesce(v_expected, '{}'::uuid[]))
        EXCEPT
        SELECT unnest(coalesce(v_rpc,      '{}'::uuid[]))) b(x);

  -- ── report ─────────────────────────────────────────────────────────────────────────
  INSERT INTO _m VALUES ('account under test', 'a real multi-follow student',
    v_uid::text || '  (follows ' || coalesce(array_length(v_followed,1),0)::text
    || ' total; ' || v_cohort_ct::text || ' expected rows after students-only + self)', 'INFO');

  INSERT INTO _m VALUES ('no row the caller does NOT follow (scope not too wide)',
    'no extras',
    CASE WHEN v_extra IS NULL THEN '(none)' ELSE v_extra::text END,
    CASE WHEN v_extra IS NULL THEN 'PASS'
         ELSE 'FAIL — follow-join too broad / wrong graph' END);

  INSERT INTO _m VALUES ('every followed student present (scope not too narrow / not collapsed)',
    CASE WHEN v_cohort_ct <= 20 THEN 'nothing missing'
         ELSE 'nothing missing except genuine rank>20 rows' END,
    CASE WHEN v_missing IS NULL THEN '(none)' ELSE v_missing::text END,
    CASE WHEN v_missing IS NULL THEN 'PASS'
         WHEN v_cohort_ct > 20 THEN 'REVIEW — confirm each missing uuid is genuinely rank>20'
         ELSE 'FAIL — followed users dropped, or board collapsed to just the caller' END);

  INSERT INTO _m VALUES ('exactly one is_self row', '1', coalesce(v_self_ct::text,'NULL'),
    CASE WHEN v_self_ct = 1 THEN 'PASS' ELSE 'FAIL' END);

  INSERT INTO _m VALUES ('rank ordered by reviews_this_week DESC, study_time DESC',
    'non-decreasing', coalesce(v_rank_ok::text,'NULL'),
    CASE WHEN v_rank_ok THEN 'PASS' ELSE 'FAIL' END);

  INSERT INTO _m VALUES ('exact set equality: {caller} ∪ {followed students} == RPC set',
    'equal',
    CASE WHEN v_extra IS NULL AND v_missing IS NULL THEN 'equal'
         ELSE 'extra=' || coalesce(v_extra::text,'{}')
              || '  missing=' || coalesce(v_missing::text,'{}') END,
    CASE WHEN v_extra IS NULL AND v_missing IS NULL THEN 'PASS'
         WHEN v_extra IS NULL AND v_cohort_ct > 20 THEN 'PASS (subject to rank>20 review above)'
         ELSE 'FAIL' END);
END $$;

SELECT * FROM _m ORDER BY (status LIKE 'FAIL%') DESC, (status NOT IN ('PASS','INFO')) DESC, check_name;

ROLLBACK;

-- ── Interpreting the result ──────────────────────────────────────────────────────────
--  All PASS                    → reconstruction is FAITHFUL on membership. Close Finding 2.
--  "scope too wide" FAIL       → the follow-join pulled in non-followees. The cohort CTE
--                                must be  public.follows WHERE follower_id = auth.uid()
--                                projecting followee_id — NOT a friendships join and NOT a
--                                reciprocal `AND EXISTS (reverse follow)` clause.
--  "scope too narrow" FAIL     → followed students are dropped, OR the join is broken and
--                                the board always collapses to just the caller (the exact
--                                ambiguity the live "TestOutlook (you)"-only row left open).
--                                Ship 05_FIX_get_following_leaderboard_membership.sql.
--  many "missing", cohort <=20 → same as narrow FAIL.
--
-- Pair this with a screenshot of the app's Leaderboard → Following tab for the same
-- account (regression guard: both tabs load, no 400, no console.error).
