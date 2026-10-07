-- Name: [TEST] T-001 C-01 TEST (v3) - verification of the due-eligibility helper and the two forecast functions (brief C v6, C-6.5 items 1 to 4)
--
-- Description: VERIFICATION, run AFTER C-01_FUNCTIONS_due-eligibility-helper-and-forecast-functions.sql has been executed (it fails or reports "not
-- found" before that). It changes NOTHING that persists: five runs; each ends in one SELECT that returns a single jsonb cell named `result` (T2 to T5 first create TEMPORARY functions in pg_temp,
-- which vanishes with the session, and the SELECT calls it; T1 is a single SELECT). v3 (supersedes v2 657d0962e36e and v1 65e25142f7fa, never authorized or run; QA Rounds 94 to 100; Founder Option A, Round 101):
-- adds run T5, which exercises the skip_until and next_review_date boundaries on REAL rows by moving the date the helper treats as today (day before, day of and
-- day after for every live skip date; 3 days before, 1 day before, the day itself and 1 day after for every live due date), against an independently
-- written recomputation at the same date, and counts the decisive rows per boundary relation; every pg_temp function is now CREATE OR REPLACE so a run can
-- never collide with an earlier one in the same session. v2 (supersedes v1 65e25142f7fa, never authorized or run; QA Round 94):
-- T1 now compares the COMPLETE, deterministically ordered set of roles holding EXECUTE with the approved ceiling (the helper: the owner only; each public
-- function: exactly authenticated, postgres and service_role), so an unexpected extra role fails; and the coverage run T5 of v1 is REMOVED, because the exact
-- coverage of the C-6.5 item 3 boundary cases is now measured BEFORE Gate 2 by the read-only diagnostic 10 v2, runs P3 and P4. No INSERT, UPDATE, DELETE or DDL on any application object. Role
-- switches use SET LOCAL ROLE inside the temporary function and are reset before it returns. No user id, card id or text is returned; only labels,
-- counts and pass flags. Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.
-- HOW TO RUN: select ONE run (from its banner line to the closing SELECT ... AS result;), click Run, copy the single result cell, and paste it into one
-- Notepad file under its label (T1 to T5), unchanged. Save as docs/discussions/evidence/T-001_C01-test-raw_<dd-mm-yyyy>.raw.txt. An error is evidence:
-- save the error text under its label, do not edit and re-run (stop and report instead).
--
-- What each run proves (the brief C v6 clause in brackets):
--   T1  catalogue facts: the helper exists once, is SECURITY DEFINER with the pinned search_path and the same owner as the two public functions; NO
--       application role (PUBLIC, anon, authenticated, service_role, authenticator, dashboard_user) can execute it; the two public functions are
--       SECURITY DEFINER, pinned, with EXECUTE for exactly authenticated, postgres and service_role (no anon, no PUBLIC); no (user, card) pair has two
--       enrollment rows, so the helper's join cannot double-count.  [C-6.3 invariants 1 to 3 and 5; C-6.5 item 4]
--   T2  direct invocation as real roles: the helper is refused (permission denied) for anon, authenticated own id, authenticated another user's id,
--       authenticated with an administrator's token, and service_role, and works for its owner as a control; each public function is refused for anon,
--       works for the owner of the data and for an administrator, and is refused by its own guard for another user and for service_role without a
--       token.  [C-6.3 invariant 4; C-6.5 item 4]
--   T3  ALL PROFILES, no sample: for every profile, as an administrator, (a) due_today of get_due_forecast = bucket 0 of get_due_forecast_buckets =
--       |get_study_queue ∩ get_my_cards| = an independently written recomputation; (b) due_next_7 and due_next_30 equal the recomputation; (c) all eight
--       buckets equal the recomputation, whose bucket index is computed by a different method (a count of thresholds); (d) the sum of the buckets equals
--       the number of eligible cards (every eligible card has a non-null date). Then the helper itself is compared with the recomputation for every
--       profile at six different "today" values (-1, 0, +1, +7, +30, +400 days), which exercises the skip_until boundary and the null rule at many dates.
--       [C-6.5 items 1 and 2, and the date boundary of item 3]
--   T4  the null date: for every profile, over many dates, the helper returns no null date; the number of null-dated active reviews that exist is
--       reported with the number that any figure counted (must be 0).  [brief C v6 D-C5; C-6.5 item 3]
--   T5  date boundaries on real rows: for every live skip_until and next_review_date the helper is called with the probe date moved so that the row sits
--       exactly on a boundary (skip exactly yesterday, today, tomorrow; due exactly today, tomorrow, in 3 days, overdue by one day) and compared with an
--       independent recomputation at the same date; the decisive live rows per relation are counted.  [C-6.5 item 3, skip_until and dated-card cases]
--   (Coverage of the other C-6.5 item 3 cases was measured exactly, before Gate 2, by diagnostic 10 run P3; T3 exercises every case that has live rows,
--       because it compares ALL profiles. The cases with no live row are the Founder-accepted residual gaps of Round 101.)
-- Not proven here, stated: a boundary case that diagnostic 10 v2 P3 reports as NOT COVERED by live data (for example a user at exactly +14 or -12 hours)
-- is not exercised by T3 and needs a decision of the Founder (accept the residual gap, or approve a safe fixture environment) before Gate 2; the frontend (C-03) is not touched; real-role tests use the SET LOCAL ROLE emulation with a JWT claim, the same mechanism as the platform.

-- ===== RUN T1: catalogue and ACL assertions =====
WITH h AS (
  SELECT p.oid, p.prosecdef, p.proconfig, p.proowner, p.proacl FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'fn_due_eligible_dates' AND p.prokind = 'f'
),
rp AS (
  SELECT p.oid, p.proname, p.prosecdef, p.proconfig, p.proowner, p.proacl FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('get_due_forecast', 'get_due_forecast_buckets') AND p.prokind = 'f'
),
roles(r) AS (
  VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator'), ('dashboard_user')
),
chk AS (
  SELECT 'helper_exists_exactly_once' AS name, (SELECT count(*) FROM h) = 1 AS pass
  UNION ALL SELECT 'helper_is_security_definer', COALESCE((SELECT bool_and(prosecdef) FROM h), false)
  UNION ALL SELECT 'helper_search_path_pinned_public_extensions',
         COALESCE((SELECT bool_and(proconfig @> ARRAY['search_path=public, extensions']) FROM h), false)
  UNION ALL SELECT 'two_public_functions_exist', (SELECT count(*) FROM rp) = 2
  UNION ALL SELECT 'public_functions_security_definer_and_pinned',
         COALESCE((SELECT bool_and(prosecdef AND proconfig @> ARRAY['search_path=public, extensions']) FROM rp), false)
  UNION ALL SELECT 'helper_owner_equals_both_public_function_owners',
         (SELECT count(DISTINCT o) FROM (SELECT proowner AS o FROM h UNION ALL SELECT proowner FROM rp) z) = 1
  UNION ALL SELECT 'helper_not_executable_by_PUBLIC',
         NOT EXISTS (SELECT 1 FROM h, aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) x
                     WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
  UNION ALL SELECT 'helper_not_executable_by_' || ro.r,
         NOT COALESCE((SELECT bool_or(has_function_privilege(ro.r, h.oid, 'EXECUTE')) FROM h), true)
         FROM roles ro WHERE EXISTS (SELECT 1 FROM pg_roles x WHERE x.rolname = ro.r)
  UNION ALL SELECT 'public_functions_not_executable_by_PUBLIC',
         NOT EXISTS (SELECT 1 FROM rp, aclexplode(COALESCE(rp.proacl, acldefault('f', rp.proowner))) x
                     WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
  UNION ALL SELECT 'public_functions_not_executable_by_anon',
         NOT COALESCE((SELECT bool_or(has_function_privilege('anon', rp.oid, 'EXECUTE')) FROM rp), true)
  UNION ALL SELECT 'public_functions_executable_by_authenticated_and_service_role',
         COALESCE((SELECT bool_and(has_function_privilege('authenticated', rp.oid, 'EXECUTE')
                                   AND has_function_privilege('service_role', rp.oid, 'EXECUTE')) FROM rp), false)
  UNION ALL SELECT 'helper_execute_set_is_exactly_the_owner',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY[pg_get_userbyid(h.proowner)::text] FROM h), false)
  UNION ALL SELECT 'public_function_execute_set_is_exactly_authenticated_postgres_service_role',
         COALESCE((SELECT bool_and((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(rp.proacl, acldefault('f', rp.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role']) FROM rp), false)
  UNION ALL SELECT 'no_duplicate_enrollment_pair',
         NOT EXISTS (SELECT 1 FROM public.my_cards_enrollment e GROUP BY e.user_id, e.flashcard_id HAVING count(*) > 1)
)
SELECT jsonb_build_object(
  'run', 'T1',
  'checks', (SELECT jsonb_agg(jsonb_build_object('check', name, 'pass', pass) ORDER BY name) FROM chk),
  'all_passed', (SELECT bool_and(pass) FROM chk),
  'public_function_execute_roles', (SELECT jsonb_agg(jsonb_build_object('function', rp.proname,
        'roles', to_jsonb((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(rp.proacl, acldefault('f', rp.proowner))) x WHERE x.privilege_type = 'EXECUTE') s))) ORDER BY rp.proname) FROM rp),
  'helper_execute_roles', (SELECT to_jsonb((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) x WHERE x.privilege_type = 'EXECUTE') s)) FROM h),
  -- informational, not a pass criterion: roles that can execute the helper only because they inherit the owner's privileges or are superusers
  'helper_effective_executors_other_than_owner', (SELECT COALESCE(jsonb_agg(r.rolname ORDER BY r.rolname), '[]'::jsonb)
        FROM pg_roles r, h WHERE r.oid <> h.proowner AND has_function_privilege(r.oid, h.oid, 'EXECUTE'))
) AS result;

-- ===== RUN T2: direct invocation as real roles =====
CREATE OR REPLACE FUNCTION pg_temp.c01_t2() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_user uuid; v_other uuid; v_admin uuid;
  v_res jsonb := '[]'::jsonb;
  v_case record;
  v_out text;
BEGIN
  SELECT r.user_id INTO v_user FROM public.reviews r ORDER BY r.user_id LIMIT 1;
  SELECT p.id INTO v_other FROM public.profiles p WHERE p.id <> v_user ORDER BY p.id LIMIT 1;
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_user IS NULL OR v_other IS NULL OR v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'T2', 'error', 'a fixture profile (a user with a review, another user, an administrator) is missing; the test cannot run');
  END IF;
  FOR v_case IN
    SELECT * FROM (VALUES
      ('helper',   'anon',          NULL::uuid, v_user,  'denied_42501', 'anon'),
      ('helper',   'authenticated', v_user,     v_user,  'denied_42501', 'authenticated_own_id'),
      ('helper',   'authenticated', v_user,     v_other, 'denied_42501', 'authenticated_other_id'),
      ('helper',   'authenticated', v_admin,    v_user,  'denied_42501', 'authenticated_admin_token'),
      ('helper',   'service_role',  NULL::uuid, v_user,  'denied_42501', 'service_role'),
      ('helper',   'postgres',      NULL::uuid, v_user,  'executed',     'owner_control'),
      ('forecast', 'anon',          NULL::uuid, v_user,  'denied_42501', 'anon'),
      ('forecast', 'authenticated', v_user,     v_user,  'executed',     'own'),
      ('forecast', 'authenticated', v_user,     v_other, 'guard_denied', 'other_user'),
      ('forecast', 'authenticated', v_admin,    v_user,  'executed',     'admin'),
      ('forecast', 'service_role',  NULL::uuid, v_user,  'guard_denied', 'service_role_without_token'),
      ('buckets',  'anon',          NULL::uuid, v_user,  'denied_42501', 'anon'),
      ('buckets',  'authenticated', v_user,     v_user,  'executed',     'own'),
      ('buckets',  'authenticated', v_user,     v_other, 'guard_denied', 'other_user'),
      ('buckets',  'authenticated', v_admin,    v_user,  'executed',     'admin'),
      ('buckets',  'service_role',  NULL::uuid, v_user,  'guard_denied', 'service_role_without_token')
    ) AS t(obj, rl, sub, target, expected, label)
  LOOP
    v_out := 'executed';
    BEGIN
      IF v_case.rl <> 'postgres' THEN
        EXECUTE format('SET LOCAL ROLE %I', v_case.rl);
      END IF;
      PERFORM set_config('request.jwt.claims',
                         CASE WHEN v_case.sub IS NULL THEN ''
                              ELSE jsonb_build_object('sub', v_case.sub::text, 'role', v_case.rl)::text END, true);
      IF v_case.obj = 'helper' THEN
        PERFORM count(*) FROM public.fn_due_eligible_dates(v_case.target, current_date);
      ELSIF v_case.obj = 'forecast' THEN
        PERFORM count(*) FROM public.get_due_forecast(v_case.target);
      ELSE
        PERFORM count(*) FROM public.get_due_forecast_buckets(v_case.target);
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN v_out := 'denied_42501';
      WHEN raise_exception THEN
        v_out := CASE WHEN SQLERRM LIKE 'Access denied%' THEN 'guard_denied' ELSE 'raise_other' END;
      WHEN OTHERS THEN v_out := 'error_' || SQLSTATE;
    END;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);
    v_res := v_res || jsonb_build_object('object', v_case.obj, 'case', v_case.label, 'role', v_case.rl,
                                         'expected', v_case.expected, 'got', v_out, 'pass', v_out = v_case.expected);
  END LOOP;
  RETURN jsonb_build_object('run', 'T2', 'cases', v_res,
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c01_t2() AS result;

-- ===== RUN T3: all profiles, public functions against the Review composition and an independent recomputation; helper at six dates =====
CREATE OR REPLACE FUNCTION pg_temp.c01_expected(p_offset integer)
 RETURNS TABLE(uid uuid, nrd date, today date)
 LANGUAGE sql STABLE
AS $f$
  -- INDEPENDENT recomputation of the C-6.1 rule plus the v6 null rule, written in a different form from the helper
  WITH u AS (
    SELECT p.id, p.course_level AS cl,
           ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + p_offset) AS today
    FROM public.profiles p
  )
  SELECT u.id, r.next_review_date, u.today
  FROM u
  JOIN public.reviews r ON r.user_id = u.id
  JOIN public.flashcards f ON f.id = r.flashcard_id
  WHERE r.status = 'active'
    AND r.next_review_date IS NOT NULL
    AND COALESCE(r.skip_until, DATE '-infinity') <= u.today
    AND f.question_type IS NOT NULL AND f.question_type <> 'concept_card'
    AND (u.cl IS NULL OR COALESCE(f.target_course, u.cl) = u.cl)
    AND EXISTS (SELECT 1 FROM public.my_cards_enrollment e
                WHERE e.user_id = u.id AND e.flashcard_id = r.flashcard_id AND e.status = 'active')
    AND (
      f.user_id = u.id
      OR f.visibility = 'public'
      OR (f.visibility = 'friends' AND f.user_id IN (
            SELECT CASE WHEN fr.user_id = u.id THEN fr.friend_id ELSE fr.user_id END
            FROM public.friendships fr
            WHERE fr.status = 'accepted' AND u.id IN (fr.user_id, fr.friend_id)))
    )
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c01_t3() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_admin uuid; v_ids uuid[]; v_u uuid;
  v_fc jsonb := '{}'::jsonb; v_bk jsonb := '{}'::jsonb; v_q jsonb := '{}'::jsonb;
  v_row jsonb; v_cnt integer;
  rec record;
  n_cmp integer := 0; n_day0 integer := 0; n_fc integer := 0; n_bk integer := 0; n_sum integer := 0; n_q integer := 0;
  v_f jsonb; v_b0 integer;
  v_off integer;
  v_helper jsonb := '[]'::jsonb;
  v_with_due integer := 0;
BEGIN
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'T3', 'error', 'no administrator profile found; the test cannot run');
  END IF;
  SELECT array_agg(p.id ORDER BY p.id) INTO v_ids FROM public.profiles p;

  -- the public functions are called as the platform calls them: role authenticated, an administrator's token
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  FOREACH v_u IN ARRAY v_ids LOOP
    SELECT to_jsonb(f) INTO v_row FROM public.get_due_forecast(v_u) f;
    v_fc := v_fc || jsonb_build_object(v_u::text, v_row);
    SELECT jsonb_agg(b.scheduled_count ORDER BY b.bucket_index) INTO v_row FROM public.get_due_forecast_buckets(v_u) b;
    v_bk := v_bk || jsonb_build_object(v_u::text, v_row);
    SELECT count(*) INTO v_cnt FROM (
      SELECT x.flashcard_id FROM public.get_study_queue(v_u) x
      INTERSECT
      SELECT m.id FROM public.get_my_cards(v_u) m
    ) i;
    v_q := v_q || jsonb_build_object(v_u::text, v_cnt);
  END LOOP;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);

  FOR rec IN
    SELECT p.id AS uid,
           COALESCE(a.t0, 0) AS t0, COALESCE(a.t7, 0) AS t7, COALESCE(a.t30, 0) AS t30,
           COALESCE(a.cnt_all, 0) AS cnt_all,
           COALESCE(a.b, ARRAY[0, 0, 0, 0, 0, 0, 0, 0]) AS b
    FROM public.profiles p
    LEFT JOIN (
      SELECT z.uid,
             count(*) AS cnt_all,
             count(*) FILTER (WHERE z.nrd <= z.today) AS t0,
             count(*) FILTER (WHERE z.nrd <= z.today + 7) AS t7,
             count(*) FILTER (WHERE z.nrd <= z.today + 30) AS t30,
             ARRAY[count(*) FILTER (WHERE z.bi = 0), count(*) FILTER (WHERE z.bi = 1), count(*) FILTER (WHERE z.bi = 2),
                   count(*) FILTER (WHERE z.bi = 3), count(*) FILTER (WHERE z.bi = 4), count(*) FILTER (WHERE z.bi = 5),
                   count(*) FILTER (WHERE z.bi = 6), count(*) FILTER (WHERE z.bi = 7)]::integer[] AS b
      FROM (
        SELECT e.uid, e.nrd, e.today,
               (SELECT count(*) FROM unnest(ARRAY[1, 2, 5, 10, 22, 60, 135]) th WHERE (e.nrd - e.today) >= th) AS bi
        FROM pg_temp.c01_expected(0) e
      ) z
      GROUP BY z.uid
    ) a ON a.uid = p.id
    ORDER BY p.id
  LOOP
    n_cmp := n_cmp + 1;
    v_f := v_fc -> (rec.uid::text);
    v_b0 := ((v_bk -> (rec.uid::text)) -> 0)::text::integer;
    IF rec.t0 > 0 THEN v_with_due := v_with_due + 1; END IF;
    IF (v_f ->> 'due_today')::integer <> v_b0 OR (v_f ->> 'due_today')::integer <> rec.t0 THEN n_day0 := n_day0 + 1; END IF;
    IF (v_q ->> (rec.uid::text))::integer <> rec.t0 THEN n_q := n_q + 1; END IF;
    IF (v_f ->> 'due_next_7')::integer <> rec.t7 OR (v_f ->> 'due_next_30')::integer <> rec.t30 THEN n_fc := n_fc + 1; END IF;
    IF (v_bk -> (rec.uid::text)) <> to_jsonb(rec.b) THEN n_bk := n_bk + 1; END IF;
    IF (SELECT COALESCE(sum(x::text::integer), 0) FROM jsonb_array_elements(v_bk -> (rec.uid::text)) x) <> rec.cnt_all THEN n_sum := n_sum + 1; END IF;
  END LOOP;

  -- the helper itself, as its owner, against the recomputation, for every profile at six dates
  FOREACH v_off IN ARRAY ARRAY[-1, 0, 1, 7, 30, 400] LOOP
    SELECT count(*) INTO v_cnt FROM (
      SELECT COALESCE(a.uid, b.uid) AS uid
      FROM (SELECT e.uid, count(*) AS c, md5(string_agg(e.nrd::text, ',' ORDER BY e.nrd)) AS h
            FROM pg_temp.c01_expected(v_off) e GROUP BY e.uid) a
      FULL OUTER JOIN (
        SELECT p.id AS uid, count(*) AS c, md5(string_agg(h.due_date::text, ',' ORDER BY h.due_date)) AS h
        FROM public.profiles p
        CROSS JOIN LATERAL public.fn_due_eligible_dates(
              p.id, ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + v_off)) h
        GROUP BY p.id
      ) b ON a.uid = b.uid
      WHERE a.uid IS NULL OR b.uid IS NULL OR a.c <> b.c OR a.h <> b.h
    ) m;
    v_helper := v_helper || jsonb_build_object('today_offset_days', v_off, 'profiles_whose_helper_set_differs', v_cnt);
  END LOOP;

  RETURN jsonb_build_object(
    'run', 'T3',
    'profiles_compared', n_cmp,
    'profiles_with_something_due_today', v_with_due,
    'day_zero_mismatches', n_day0,
    'review_composition_mismatches', n_q,
    'cumulative_7_30_mismatches', n_fc,
    'bucket_vector_mismatches', n_bk,
    'bucket_sum_mismatches', n_sum,
    'helper_at_six_dates', v_helper,
    'all_passed', (n_cmp > 0 AND n_day0 = 0 AND n_q = 0 AND n_fc = 0 AND n_bk = 0 AND n_sum = 0
                   AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_helper) e WHERE (e ->> 'profiles_whose_helper_set_differs')::integer <> 0)));
END;
$$;
SELECT pg_temp.c01_t3() AS result;

-- ===== RUN T4: the null date (brief C v6, D-C5) =====
CREATE OR REPLACE FUNCTION pg_temp.c01_t4() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_null_rows_returned integer; v_off integer; v_cnt integer; v_per jsonb := '[]'::jsonb;
BEGIN
  FOREACH v_off IN ARRAY ARRAY[-1, 0, 1, 7, 30, 400, 20000] LOOP
    SELECT count(*) INTO v_cnt
    FROM public.profiles p
    CROSS JOIN LATERAL public.fn_due_eligible_dates(
          p.id, ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + v_off)) h
    WHERE h.due_date IS NULL;
    v_per := v_per || jsonb_build_object('today_offset_days', v_off, 'helper_rows_with_a_null_date', v_cnt);
  END LOOP;
  SELECT COALESCE(sum((e ->> 'helper_rows_with_a_null_date')::integer), 0) INTO v_null_rows_returned FROM jsonb_array_elements(v_per) e;
  RETURN jsonb_build_object(
    'run', 'T4',
    'active_reviews_with_a_null_date_that_exist', (SELECT count(*) FROM public.reviews r WHERE r.status = 'active' AND r.next_review_date IS NULL),
    'users_holding_them', (SELECT count(DISTINCT r.user_id) FROM public.reviews r WHERE r.status = 'active' AND r.next_review_date IS NULL),
    'helper_rows_with_a_null_date_by_date', v_per,
    'null_rows_returned_in_total', v_null_rows_returned,
    'all_passed', v_null_rows_returned = 0);
END;
$$;
SELECT pg_temp.c01_t4() AS result;

-- ===== RUN T5: date-boundary probes on REAL rows (v3; QA Round 100; Founder Option A) =====
-- The helper takes the date as a parameter, so a live row can be put exactly on a rule boundary by moving "today" instead of writing any data. For every
-- active review with a skip_until the helper is called, for that review's user, at skip_until minus 1, skip_until and skip_until plus 1 (the skip is then
-- exactly tomorrow, exactly today and exactly yesterday relative to the probe date); for every active review with a next_review_date, at that date minus 3,
-- minus 1, the date itself and plus 1 (the card is then due exactly in 3 days, tomorrow, today and overdue by one day). Each (user, date) result is compared,
-- as a multiset of dates, with an independently written recomputation at the same probe date. The run also counts the decisive live rows for each
-- boundary relation so that a relation with no row is reported, never assumed. This is the heaviest run (several thousand helper calls): run it last.
CREATE OR REPLACE FUNCTION pg_temp.c01_probes() RETURNS TABLE(uid uuid, p date)
 LANGUAGE sql STABLE
AS $f$
  SELECT r.user_id, (r.skip_until + v.k)::date
  FROM public.reviews r CROSS JOIN (VALUES (-1), (0), (1)) v(k)
  WHERE r.status = 'active' AND r.skip_until IS NOT NULL
  UNION
  SELECT r.user_id, (r.next_review_date + v.k)::date
  FROM public.reviews r CROSS JOIN (VALUES (-3), (-1), (0), (1)) v(k)
  WHERE r.status = 'active' AND r.next_review_date IS NOT NULL
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c01_rows_at() RETURNS TABLE(uid uuid, p date, nrd date, su date)
 LANGUAGE sql STABLE
AS $f$
  -- every (probe, review) pair of the probe's user that satisfies every rule condition EXCEPT the skip rule, with the probe date as "today"
  SELECT pr.uid, pr.p, r.next_review_date, r.skip_until
  FROM pg_temp.c01_probes() pr
  JOIN public.profiles u ON u.id = pr.uid
  JOIN public.reviews r ON r.user_id = pr.uid
  JOIN public.flashcards f ON f.id = r.flashcard_id
  WHERE r.status = 'active'
    AND r.next_review_date IS NOT NULL
    AND f.question_type IS NOT NULL AND f.question_type <> 'concept_card'
    AND (u.course_level IS NULL OR COALESCE(f.target_course, u.course_level) = u.course_level)
    AND EXISTS (SELECT 1 FROM public.my_cards_enrollment e
                WHERE e.user_id = pr.uid AND e.flashcard_id = r.flashcard_id AND e.status = 'active')
    AND (
      f.user_id = pr.uid
      OR f.visibility = 'public'
      OR (f.visibility = 'friends' AND f.user_id IN (
            SELECT CASE WHEN fr.user_id = pr.uid THEN fr.friend_id ELSE fr.user_id END
            FROM public.friendships fr
            WHERE fr.status = 'accepted' AND pr.uid IN (fr.user_id, fr.friend_id)))
    )
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c01_t5() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_pairs integer; v_mis integer; v_rel jsonb;
BEGIN
  SELECT count(*) INTO v_pairs FROM pg_temp.c01_probes();
  SELECT count(*) INTO v_mis FROM (
    SELECT COALESCE(a.uid, b.uid) AS uid
    FROM (SELECT x.uid, x.p, count(*) AS c, md5(string_agg(x.nrd::text, ',' ORDER BY x.nrd)) AS h
          FROM pg_temp.c01_rows_at() x
          WHERE COALESCE(x.su, DATE '-infinity') <= x.p
          GROUP BY x.uid, x.p) a
    FULL OUTER JOIN (
      SELECT pr.uid, pr.p, count(*) AS c, md5(string_agg(hh.due_date::text, ',' ORDER BY hh.due_date)) AS h
      FROM pg_temp.c01_probes() pr
      CROSS JOIN LATERAL public.fn_due_eligible_dates(pr.uid, pr.p) hh
      GROUP BY pr.uid, pr.p
    ) b ON a.uid = b.uid AND a.p = b.p
    WHERE a.uid IS NULL OR b.uid IS NULL OR a.c <> b.c OR a.h <> b.h
  ) m;
  SELECT jsonb_build_object(
    'skip_until_exactly_yesterday_rows', count(*) FILTER (WHERE x.su = x.p - 1),
    'skip_until_exactly_today_rows', count(*) FILTER (WHERE x.su = x.p),
    'skip_until_exactly_tomorrow_rows', count(*) FILTER (WHERE x.su = x.p + 1),
    'due_exactly_today_and_not_skipped_rows', count(*) FILTER (WHERE x.nrd = x.p AND COALESCE(x.su, DATE '-infinity') <= x.p),
    'due_exactly_in_3_days_rows', count(*) FILTER (WHERE x.nrd = x.p + 3 AND COALESCE(x.su, DATE '-infinity') <= x.p),
    'due_exactly_tomorrow_rows', count(*) FILTER (WHERE x.nrd = x.p + 1 AND COALESCE(x.su, DATE '-infinity') <= x.p),
    'overdue_by_exactly_one_day_rows', count(*) FILTER (WHERE x.nrd = x.p - 1 AND COALESCE(x.su, DATE '-infinity') <= x.p))
  INTO v_rel
  FROM pg_temp.c01_rows_at() x;
  RETURN jsonb_build_object(
    'run', 'T5',
    'probe_pairs_user_and_date', v_pairs,
    'pairs_whose_helper_result_differs_from_the_recomputation', v_mis,
    'decisive_live_rows_by_boundary_relation', v_rel,
    'boundary_relations_with_no_decisive_row',
      (SELECT COALESCE(jsonb_agg(e.key ORDER BY e.key), '[]'::jsonb) FROM jsonb_each(v_rel) e WHERE (e.value)::text::integer = 0),
    'all_passed', (v_pairs > 0 AND v_mis = 0));
END;
$$;
SELECT pg_temp.c01_t5() AS result;
