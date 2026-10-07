-- Name: [TEST] T-001 C-02 TEST (v4) - verification of the new study-heatmap function get_study_heatmap_split (brief C v6, C-7.5 items 1 to 5)
--
-- Description: VERIFICATION, run AFTER C-02_FUNCTIONS_study-heatmap-split.sql has been executed (before that it reports the function missing or fails).
-- It changes NOTHING that persists: four runs; each ends in one SELECT that returns a single jsonb cell named `result` (U2 to U4 first create
-- TEMPORARY functions in pg_temp, which vanish with the session; U1 is a single SELECT). v4 (supersedes v3 d6d14bfd6e0f, never authorized or run; QA Round 102: header citations of the coverage evidence corrected from the superseded diagnostic 10 v2 to the run diagnostic 10 v3; no SQL changed). v3 (supersedes v2 9da07d2c6954 and v1 fe815adb6cbd, never authorized or run;
-- QA Rounds 94 to 100; Founder Option A, Round 101): adds run U4, which tests the new function for EVERY profile at the windows 0, 1 and 7 days and at eight
-- further windows DERIVED from the data (offsets of actual listed days, chosen evenly by rank so the window start falls on listed rows), counts the listed
-- rows exactly on the window start and on today, and every pg_temp function is now CREATE OR REPLACE. v2 (supersedes v1 fe815adb6cbd, never authorized or run; QA Round 94):
-- U1 now compares COMPLETE, deterministically ordered sets of EXECUTE holders with the approved ceiling (exactly authenticated, postgres and service_role, for
-- the new and for the live function) instead of an order-dependent comparison with the live function; and the coverage run U4 of v1 is REMOVED, because the
-- exact coverage of the C-7.5 item 5 boundary cases, restricted to the days the 90-day window actually exercises, the exact +14 h and -12 h users, and the
-- complete upper-end count over ALL THREE sources are now measured BEFORE Gate 2 by the read-only diagnostic 10 v3 (39a1f3ab1981, run 07/10/2026, Gate 4 accepted), run P4. No INSERT, UPDATE, DELETE or DDL on any application
-- object. Role switches use SET LOCAL ROLE inside a temporary function and are reset before it returns. No user id, date, card id or text is returned:
-- only labels, counts and pass flags. Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.
-- HOW TO RUN: select ONE run (from its banner line to the closing SELECT ... AS result;), click Run, copy the single result cell, and paste it into one
-- Notepad file under its label (U1 to U4), unchanged. Save as docs/discussions/evidence/T-001_C02-test-raw_<dd-mm-yyyy>.raw.txt. An error is evidence:
-- save the error text under its label, do not edit and re-run (stop and report instead).
--
-- What each run proves (the brief C v6 clause in brackets):
--   U1  catalogue facts: exactly one get_study_heatmap_split(uuid, integer); SECURITY DEFINER; pinned search_path; EXECUTE for exactly authenticated,
--       postgres and service_role (no anon, no PUBLIC), the same ceiling as the live get_study_heatmap; the live function still exists with the
--       same owner and execute roles (it must be unchanged: its definition md5 is returned for comparison with the pre-check diagnostic 10 result);
--       the return columns are exactly review_date, review_count, in_app_seconds, offline_seconds, study_seconds, other_seconds.  [C-7.1, C-7.2]
--   U2  real roles: anon is refused (permission denied); an authenticated student reads their own data; is refused another student's data by the
--       function's own guard; an administrator reads a student's data; service_role without a token is refused by the guard.  [C-7.2; C-7.5 item 4]
--   U3  ALL PROFILES, no sample, for p_days 90 and 30, as an administrator:
--       (1) the new function equals an INDEPENDENT recomputation from reviews, user_activity_log and study_sessions under the C-7.3 window rule, on every
--           (profile, day, review_count, in_app_seconds, offline_seconds, study_seconds, other_seconds);  [C-7.5 item 1]
--       (1b) other_seconds is 0 on every day;  [C-7.1]
--       (2) the LIVE function get_study_heatmap equals an independent recomputation under ITS OWN predicates (instant cutoff for reviews, the server's
--           CURRENT_DATE for the other two, no upper end), so the old side of every comparison is itself checked, not trusted;
--       (3) old versus new on the COMMON day set, defined as the full local calendar days wholly inside both windows (the old review cutoff is an instant,
--           so its first calendar day is partial and is excluded, and the server's CURRENT_DATE - p_days is also respected): review_count and
--           study_seconds are equal for every profile and day;  [C-7.5 item 2]
--       (4) the boundary delta: the rows that exist on only one side (outside the common set) are counted with their review and study totals, and every
--           such row is already proven equal to its own side's independent recomputation by (1) and (2), so the delta consists of exactly the source rows in
--           the symmetric difference of the two windows and nothing else.  [C-7.5 item 3]
--   U4  windows 0, 1, 7 and eight data-derived windows (see its banner): the same independent comparison for every profile, with the window-start and today
--       edge rows counted.  [C-7.5 item 5, window-edge cases]
--   (Coverage of the other C-7.5 item 5 cases was measured exactly, before Gate 2, by diagnostic 10 run P4; U3 exercises every case that has live rows.)
-- Not proven here, stated: a case that diagnostic 10 v3 P4 reports NOT COVERED by live data (for example a user at exactly +14 or -12 hours) is not exercised
-- and needs a decision of the Founder (accept the residual gap, or approve a safe fixture environment) before Gate 2;
-- the frontend (C-7.4, accessibility and date handling) is part of C-03 and is not touched; real-role tests use SET LOCAL ROLE with a JWT claim.

-- ===== RUN U1: catalogue and ACL assertions =====
WITH n AS (
  SELECT p.oid, p.prosecdef, p.proconfig, p.proowner, p.proacl, pg_get_function_result(p.oid) AS result_type
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'get_study_heatmap_split' AND p.prokind = 'f'
),
o AS (
  SELECT p.oid, p.proowner, p.proacl FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'get_study_heatmap' AND p.prokind = 'f'
),
chk AS (
  SELECT 'new_function_exists_exactly_once' AS name, (SELECT count(*) FROM n) = 1 AS pass
  UNION ALL SELECT 'new_function_security_definer', COALESCE((SELECT bool_and(prosecdef) FROM n), false)
  UNION ALL SELECT 'new_function_search_path_pinned_public_extensions',
         COALESCE((SELECT bool_and(proconfig @> ARRAY['search_path=public, extensions']) FROM n), false)
  UNION ALL SELECT 'new_function_return_columns_exact',
         COALESCE((SELECT bool_and(result_type = 'TABLE(review_date date, review_count integer, in_app_seconds integer, offline_seconds integer, study_seconds integer, other_seconds integer)') FROM n), false)
  UNION ALL SELECT 'new_function_not_executable_by_PUBLIC',
         NOT EXISTS (SELECT 1 FROM n, aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
  UNION ALL SELECT 'new_function_not_executable_by_anon',
         NOT COALESCE((SELECT bool_or(has_function_privilege('anon', n.oid, 'EXECUTE')) FROM n), true)
  UNION ALL SELECT 'new_function_executable_by_authenticated_and_service_role',
         COALESCE((SELECT bool_and(has_function_privilege('authenticated', n.oid, 'EXECUTE') AND has_function_privilege('service_role', n.oid, 'EXECUTE')) FROM n), false)
  UNION ALL SELECT 'new_function_execute_set_is_exactly_authenticated_postgres_service_role',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role'] FROM n), false)
  UNION ALL SELECT 'live_function_execute_set_is_exactly_authenticated_postgres_service_role',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(o.proacl, acldefault('f', o.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role'] FROM o), false)
  UNION ALL SELECT 'new_function_execute_set_equals_live_function_execute_set',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) FROM n) = (SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(o.proacl, acldefault('f', o.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) FROM o), false)
  UNION ALL SELECT 'live_function_still_exists_once', (SELECT count(*) FROM o) = 1
  UNION ALL SELECT 'new_function_owner_equals_live_function_owner', (SELECT n.proowner FROM n) = (SELECT o.proowner FROM o)
)
SELECT jsonb_build_object(
  'run', 'U1',
  'checks', (SELECT jsonb_agg(jsonb_build_object('check', name, 'pass', pass) ORDER BY name) FROM chk),
  'all_passed', (SELECT bool_and(pass) FROM chk),
  'live_get_study_heatmap_definition_md5', (SELECT md5(pg_get_functiondef(o.oid)) FROM o),
  'new_function_execute_roles', (SELECT to_jsonb((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.privilege_type = 'EXECUTE') s)) FROM n)
) AS result;

-- ===== RUN U2: real roles =====
CREATE OR REPLACE FUNCTION pg_temp.c02_u2() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_user uuid; v_other uuid; v_admin uuid;
  v_res jsonb := '[]'::jsonb;
  v_case record;
  v_out text;
BEGIN
  SELECT s.user_id INTO v_user FROM public.study_sessions s ORDER BY s.user_id LIMIT 1;
  SELECT p.id INTO v_other FROM public.profiles p WHERE p.id <> v_user ORDER BY p.id LIMIT 1;
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_user IS NULL OR v_other IS NULL OR v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'U2', 'error', 'a fixture profile (a user with a study session, another user, an administrator) is missing; the test cannot run');
  END IF;
  FOR v_case IN
    SELECT * FROM (VALUES
      ('anon',          NULL::uuid, v_user,  'denied_42501', 'anon'),
      ('authenticated', v_user,     v_user,  'executed',     'own'),
      ('authenticated', v_user,     v_other, 'guard_denied', 'other_user'),
      ('authenticated', v_admin,    v_user,  'executed',     'admin'),
      ('service_role',  NULL::uuid, v_user,  'guard_denied', 'service_role_without_token')
    ) AS t(rl, sub, target, expected, label)
  LOOP
    v_out := 'executed';
    BEGIN
      EXECUTE format('SET LOCAL ROLE %I', v_case.rl);
      PERFORM set_config('request.jwt.claims',
                         CASE WHEN v_case.sub IS NULL THEN ''
                              ELSE jsonb_build_object('sub', v_case.sub::text, 'role', v_case.rl)::text END, true);
      PERFORM count(*) FROM public.get_study_heatmap_split(v_case.target, 90);
    EXCEPTION
      WHEN insufficient_privilege THEN v_out := 'denied_42501';
      WHEN raise_exception THEN
        v_out := CASE WHEN SQLERRM LIKE 'Access denied%' THEN 'guard_denied' ELSE 'raise_other' END;
      WHEN OTHERS THEN v_out := 'error_' || SQLSTATE;
    END;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);
    v_res := v_res || jsonb_build_object('case', v_case.label, 'role', v_case.rl, 'expected', v_case.expected, 'got', v_out, 'pass', v_out = v_case.expected);
  END LOOP;
  RETURN jsonb_build_object('run', 'U2', 'cases', v_res,
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c02_u2() AS result;

-- ===== RUN U3: all profiles, new function and live function against independent recomputations, common days and boundary delta =====
CREATE OR REPLACE FUNCTION pg_temp.c02_expected_new(p_days integer)
 RETURNS TABLE(uid uuid, d date, rc integer, ins integer, offs integer, tot integer, oth integer)
 LANGUAGE sql STABLE
AS $f$
  -- INDEPENDENT recomputation of the C-7.3 rule: window = [local today - p_days, local today] for all three sources
  WITH u AS (
    SELECT p.id, COALESCE(p.timezone, 'Asia/Kolkata') AS tz,
           (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date AS today
    FROM public.profiles p
  ),
  rv AS (
    SELECT u.id AS uid, (r.created_at AT TIME ZONE u.tz)::date AS d, count(*)::integer AS c
    FROM u JOIN public.reviews r ON r.user_id = u.id
    WHERE r.status = 'active'
      AND (r.created_at AT TIME ZONE u.tz)::date >= u.today - p_days
      AND (r.created_at AT TIME ZONE u.tz)::date <= u.today
    GROUP BY 1, 2
  ),
  al AS (
    SELECT u.id AS uid, a.activity_date AS d
    FROM u JOIN public.user_activity_log a ON a.user_id = u.id
    WHERE a.activity_type = 'review' AND a.activity_date >= u.today - p_days AND a.activity_date <= u.today
  ),
  st AS (
    SELECT u.id AS uid, s.session_date AS d,
           sum(s.duration_seconds)::integer AS tot,
           COALESCE(sum(s.duration_seconds) FILTER (WHERE s.source IN ('study_mode', 'practice_mode')), 0)::integer AS ins,
           COALESCE(sum(s.duration_seconds) FILTER (WHERE s.source = 'manual'), 0)::integer AS offs
    FROM u JOIN public.study_sessions s ON s.user_id = u.id
    WHERE s.session_date >= u.today - p_days AND s.session_date <= u.today
    GROUP BY 1, 2
  ),
  days AS (SELECT al.uid, al.d FROM al UNION SELECT st.uid, st.d FROM st)
  SELECT days.uid, days.d, COALESCE(rv.c, 0), COALESCE(st.ins, 0), COALESCE(st.offs, 0), COALESCE(st.tot, 0),
         COALESCE(st.tot, 0) - COALESCE(st.ins, 0) - COALESCE(st.offs, 0)
  FROM days
  LEFT JOIN rv ON rv.uid = days.uid AND rv.d = days.d
  LEFT JOIN st ON st.uid = days.uid AND st.d = days.d
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c02_expected_old(p_days integer)
 RETURNS TABLE(uid uuid, d date, rc integer, tot integer)
 LANGUAGE sql STABLE
AS $f$
  -- INDEPENDENT recomputation of the LIVE function's own predicates: reviews from the instant now() - p_days, the server's CURRENT_DATE - p_days
  -- for the other two sources, no upper end
  WITH u AS (SELECT p.id, COALESCE(p.timezone, 'Asia/Kolkata') AS tz FROM public.profiles p),
  rv AS (
    SELECT u.id AS uid, (r.created_at AT TIME ZONE u.tz)::date AS d, count(*)::integer AS c
    FROM u JOIN public.reviews r ON r.user_id = u.id
    WHERE r.status = 'active' AND r.created_at >= now() - make_interval(days => p_days)
    GROUP BY 1, 2
  ),
  al AS (
    SELECT a.user_id AS uid, a.activity_date AS d FROM public.user_activity_log a
    WHERE a.activity_type = 'review' AND a.activity_date >= CURRENT_DATE - p_days
  ),
  st AS (
    SELECT s.user_id AS uid, s.session_date AS d, sum(s.duration_seconds)::integer AS tot FROM public.study_sessions s
    WHERE s.session_date >= CURRENT_DATE - p_days GROUP BY 1, 2
  ),
  days AS (SELECT al.uid, al.d FROM al UNION SELECT st.uid, st.d FROM st)
  SELECT days.uid, days.d, COALESCE(rv.c, 0), COALESCE(st.tot, 0)
  FROM days
  LEFT JOIN rv ON rv.uid = days.uid AND rv.d = days.d
  LEFT JOIN st ON st.uid = days.uid AND st.d = days.d
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c02_u3() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_admin uuid; v_ids uuid[]; v_u uuid; v_row jsonb;
  v_days integer;
  v_new jsonb; v_old jsonb;
  v_out jsonb := '[]'::jsonb;
  n_new_mis integer; n_old_mis integer; n_other integer; n_common_mis integer;
  n_only_new integer; n_only_old integer; n_rows_new integer; n_rows_old integer; n_common_rows integer;
  v_only_new_rc bigint; v_only_new_tot bigint; v_only_old_rc bigint; v_only_old_tot bigint;
BEGIN
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'U3', 'error', 'no administrator profile found; the test cannot run');
  END IF;
  SELECT array_agg(p.id ORDER BY p.id) INTO v_ids FROM public.profiles p;

  FOREACH v_days IN ARRAY ARRAY[90, 30] LOOP
    v_new := '{}'::jsonb; v_old := '{}'::jsonb;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    FOREACH v_u IN ARRAY v_ids LOOP
      SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.review_date), '[]'::jsonb) INTO v_row FROM public.get_study_heatmap_split(v_u, v_days) h;
      v_new := v_new || jsonb_build_object(v_u::text, v_row);
      SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.review_date), '[]'::jsonb) INTO v_row FROM public.get_study_heatmap(v_u, v_days) h;
      v_old := v_old || jsonb_build_object(v_u::text, v_row);
    END LOOP;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);

    -- (1) the new function against its independent recomputation, both directions, with duplicates counted
    SELECT count(*) INTO n_new_mis FROM (
      (SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'in_app_seconds')::integer AS ins,
              (e ->> 'offline_seconds')::integer AS offs, (e ->> 'study_seconds')::integer AS tot, (e ->> 'other_seconds')::integer AS oth
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
       EXCEPT ALL SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_days) x)
      UNION ALL
      (SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_days) x
       EXCEPT ALL
       SELECT j.k::uuid, (e ->> 'review_date')::date, (e ->> 'review_count')::integer, (e ->> 'in_app_seconds')::integer,
              (e ->> 'offline_seconds')::integer, (e ->> 'study_seconds')::integer, (e ->> 'other_seconds')::integer
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e)
    ) m;
    -- (1b) other_seconds is 0 on every day
    SELECT count(*) INTO n_other FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e WHERE (e ->> 'other_seconds')::integer <> 0;
    SELECT count(*) INTO n_rows_new FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e;

    -- (2) the live function against its own independent recomputation
    SELECT count(*) INTO n_old_mis FROM (
      (SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'study_seconds')::integer AS tot
       FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
       EXCEPT ALL SELECT x.uid, x.d, x.rc, x.tot FROM pg_temp.c02_expected_old(v_days) x)
      UNION ALL
      (SELECT x.uid, x.d, x.rc, x.tot FROM pg_temp.c02_expected_old(v_days) x
       EXCEPT ALL
       SELECT j.k::uuid, (e ->> 'review_date')::date, (e ->> 'review_count')::integer, (e ->> 'study_seconds')::integer
       FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e)
    ) m;
    SELECT count(*) INTO n_rows_old FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e;

    -- (3) old versus new on the common day set (full local days wholly inside both windows), both directions
    WITH nw AS (
      SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'study_seconds')::integer AS tot
      FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
    ),
    od AS (
      SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'study_seconds')::integer AS tot
      FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
    ),
    win AS (
      SELECT p.id AS uid,
             GREATEST((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - v_days,
                      ((now() - make_interval(days => v_days)) AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + 1,
                      CURRENT_DATE - v_days) AS lo,
             (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date AS hi
      FROM public.profiles p
    ),
    nc AS (SELECT nw.* FROM nw JOIN win ON win.uid = nw.uid AND nw.d BETWEEN win.lo AND win.hi),
    oc AS (SELECT od.* FROM od JOIN win ON win.uid = od.uid AND od.d BETWEEN win.lo AND win.hi)
    SELECT (SELECT count(*) FROM ((SELECT * FROM nc EXCEPT ALL SELECT * FROM oc) UNION ALL (SELECT * FROM oc EXCEPT ALL SELECT * FROM nc)) q),
           (SELECT count(*) FROM nc),
           (SELECT count(*) FROM nw) - (SELECT count(*) FROM nc),
           (SELECT count(*) FROM od) - (SELECT count(*) FROM oc),
           (SELECT COALESCE(sum(nw.rc), 0) - COALESCE((SELECT sum(nc.rc) FROM nc), 0) FROM nw),
           (SELECT COALESCE(sum(nw.tot), 0) - COALESCE((SELECT sum(nc.tot) FROM nc), 0) FROM nw),
           (SELECT COALESCE(sum(od.rc), 0) - COALESCE((SELECT sum(oc.rc) FROM oc), 0) FROM od),
           (SELECT COALESCE(sum(od.tot), 0) - COALESCE((SELECT sum(oc.tot) FROM oc), 0) FROM od)
    INTO n_common_mis, n_common_rows, n_only_new, n_only_old, v_only_new_rc, v_only_new_tot, v_only_old_rc, v_only_old_tot;

    v_out := v_out || jsonb_build_object(
      'p_days', v_days,
      'new_rows', n_rows_new, 'live_rows', n_rows_old,
      'new_function_vs_independent_recomputation_mismatching_rows', n_new_mis,
      'new_rows_with_other_seconds_not_zero', n_other,
      'live_function_vs_its_own_independent_recomputation_mismatching_rows', n_old_mis,
      'common_day_rows_compared', n_common_rows,
      'common_day_old_vs_new_mismatching_rows', n_common_mis,
      'boundary_new_rows_outside_common_set', n_only_new,
      'boundary_live_rows_outside_common_set', n_only_old,
      'boundary_new_side_review_count_and_study_seconds_outside_common_set', jsonb_build_array(v_only_new_rc, v_only_new_tot),
      'boundary_live_side_review_count_and_study_seconds_outside_common_set', jsonb_build_array(v_only_old_rc, v_only_old_tot),
      'pass', (n_new_mis = 0 AND n_other = 0 AND n_old_mis = 0 AND n_common_mis = 0 AND n_rows_new > 0));
  END LOOP;
  RETURN jsonb_build_object('run', 'U3', 'profiles', array_length(v_ids, 1), 'by_window', v_out,
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_out) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c02_u3() AS result;

-- ===== RUN U4: small and data-derived windows, so the window start falls on LISTED live days (v3; QA Round 100; Founder Option A) =====
-- U3 tests the contract windows 90 and 30. The live data show a listed day exactly at today minus 30 and today, but none exactly at today minus 90, so U4
-- derives further windows from the data: the distinct offsets (local today minus the date) of every listed day, from the review activity log and the
-- study sessions, between 0 and 90 days; eight of them chosen evenly by rank (so the smallest and the largest are always among them), plus the fixed
-- windows 0 (today only), 1 and 7. For each window p_days the new function is compared, for EVERY profile as an administrator, with the independent
-- recomputation (both directions, duplicates counted), other_seconds is checked to be 0, and the number of listed rows that sit exactly on the window
-- start and exactly on today is reported, so the edge cases are exercised and counted, not assumed. Windows 30 and 90 stay in U3.
CREATE OR REPLACE FUNCTION pg_temp.c02_expected_new(p_days integer)
 RETURNS TABLE(uid uuid, d date, rc integer, ins integer, offs integer, tot integer, oth integer)
 LANGUAGE sql STABLE
AS $f$
  WITH u AS (
    SELECT p.id, COALESCE(p.timezone, 'Asia/Kolkata') AS tz,
           (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date AS today
    FROM public.profiles p
  ),
  rv AS (
    SELECT u.id AS uid, (r.created_at AT TIME ZONE u.tz)::date AS d, count(*)::integer AS c
    FROM u JOIN public.reviews r ON r.user_id = u.id
    WHERE r.status = 'active'
      AND (r.created_at AT TIME ZONE u.tz)::date >= u.today - p_days
      AND (r.created_at AT TIME ZONE u.tz)::date <= u.today
    GROUP BY 1, 2
  ),
  al AS (
    SELECT u.id AS uid, a.activity_date AS d
    FROM u JOIN public.user_activity_log a ON a.user_id = u.id
    WHERE a.activity_type = 'review' AND a.activity_date >= u.today - p_days AND a.activity_date <= u.today
  ),
  st AS (
    SELECT u.id AS uid, s.session_date AS d,
           sum(s.duration_seconds)::integer AS tot,
           COALESCE(sum(s.duration_seconds) FILTER (WHERE s.source IN ('study_mode', 'practice_mode')), 0)::integer AS ins,
           COALESCE(sum(s.duration_seconds) FILTER (WHERE s.source = 'manual'), 0)::integer AS offs
    FROM u JOIN public.study_sessions s ON s.user_id = u.id
    WHERE s.session_date >= u.today - p_days AND s.session_date <= u.today
    GROUP BY 1, 2
  ),
  days AS (SELECT al.uid, al.d FROM al UNION SELECT st.uid, st.d FROM st)
  SELECT days.uid, days.d, COALESCE(rv.c, 0), COALESCE(st.ins, 0), COALESCE(st.offs, 0), COALESCE(st.tot, 0),
         COALESCE(st.tot, 0) - COALESCE(st.ins, 0) - COALESCE(st.offs, 0)
  FROM days
  LEFT JOIN rv ON rv.uid = days.uid AND rv.d = days.d
  LEFT JOIN st ON st.uid = days.uid AND st.d = days.d
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c02_u4() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_admin uuid; v_ids uuid[]; v_u uuid; v_row jsonb; v_new jsonb;
  v_offs integer[]; v_days integer[]; v_d integer; i integer; n integer;
  v_out jsonb := '[]'::jsonb;
  n_mis integer; n_other integer; n_rows integer; n_start integer; n_today integer;
BEGIN
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'U4', 'error', 'no administrator profile found; the test cannot run');
  END IF;
  SELECT array_agg(p.id ORDER BY p.id) INTO v_ids FROM public.profiles p;

  SELECT array_agg(z.o ORDER BY z.o) INTO v_offs FROM (
    SELECT DISTINCT ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - d.d) AS o
    FROM public.profiles p
    JOIN (SELECT a.user_id AS uid, a.activity_date AS d FROM public.user_activity_log a WHERE a.activity_type = 'review'
          UNION
          SELECT s.user_id, s.session_date FROM public.study_sessions s) d ON d.uid = p.id
    WHERE ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - d.d) BETWEEN 0 AND 90
  ) z;
  n := COALESCE(array_length(v_offs, 1), 0);
  v_days := ARRAY[0, 1, 7];
  IF n > 0 THEN
    FOR i IN 0..7 LOOP
      v_days := v_days || v_offs[1 + (i * (n - 1)) / 7];
    END LOOP;
  END IF;
  SELECT array_agg(DISTINCT x ORDER BY x) INTO v_days FROM unnest(v_days) x;

  FOREACH v_d IN ARRAY v_days LOOP
    v_new := '{}'::jsonb;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    FOREACH v_u IN ARRAY v_ids LOOP
      SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.review_date), '[]'::jsonb) INTO v_row FROM public.get_study_heatmap_split(v_u, v_d) h;
      v_new := v_new || jsonb_build_object(v_u::text, v_row);
    END LOOP;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);

    SELECT count(*) INTO n_mis FROM (
      (SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'in_app_seconds')::integer AS ins,
              (e ->> 'offline_seconds')::integer AS offs, (e ->> 'study_seconds')::integer AS tot, (e ->> 'other_seconds')::integer AS oth
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
       EXCEPT ALL SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_d) x)
      UNION ALL
      (SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_d) x
       EXCEPT ALL
       SELECT j.k::uuid, (e ->> 'review_date')::date, (e ->> 'review_count')::integer, (e ->> 'in_app_seconds')::integer,
              (e ->> 'offline_seconds')::integer, (e ->> 'study_seconds')::integer, (e ->> 'other_seconds')::integer
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e)
    ) m;
    SELECT count(*) INTO n_other FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e WHERE (e ->> 'other_seconds')::integer <> 0;
    SELECT count(*) INTO n_rows FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e;
    SELECT count(*) FILTER (WHERE (e ->> 'review_date')::date = (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - v_d),
           count(*) FILTER (WHERE (e ->> 'review_date')::date = (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date)
      INTO n_start, n_today
    FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
    JOIN public.profiles p ON p.id = j.k::uuid;

    v_out := v_out || jsonb_build_object(
      'p_days', v_d, 'rows', n_rows,
      'mismatching_rows_against_the_independent_recomputation', n_mis,
      'rows_with_other_seconds_not_zero', n_other,
      'listed_rows_exactly_on_the_window_start', n_start,
      'listed_rows_exactly_on_today', n_today,
      'pass', (n_mis = 0 AND n_other = 0));
  END LOOP;
  RETURN jsonb_build_object(
    'run', 'U4', 'profiles', array_length(v_ids, 1), 'derived_distinct_listed_day_offsets_available', n,
    'p_days_tested', to_jsonb(v_days), 'by_window', v_out,
    'windows_greater_than_0_whose_start_falls_on_a_listed_row',
      (SELECT count(*) FROM jsonb_array_elements(v_out) e WHERE (e ->> 'p_days')::integer > 0 AND (e ->> 'listed_rows_exactly_on_the_window_start')::integer > 0),
    'windows_greater_than_0_tested', (SELECT count(*) FROM jsonb_array_elements(v_out) e WHERE (e ->> 'p_days')::integer > 0),
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_out) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c02_u4() AS result;
