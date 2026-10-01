-- [TEST] Profile privacy STEP 3 (run AFTER 06). Rollback-only, safe on production.
-- Description: Proves the lock-down as the real client roles, and that the anonymous public surfaces still work.
--   C1 student CANNOT read email directly [CRITICAL]    C2 student cannot read access_request_ref    C3 SELECT * is refused
--   C4 student CAN still read name / role / course      C5 student can read their OWN row (allow-listed columns)
--   C6 student can still update their own full_name (write path unchanged)   C7 student still cannot change their own role (D-45 guard)
--   C8 admin (client role) cannot read email from the table, but CAN through admin_read_profiles
--   C9 catalog: email and access_request_ref are not SELECT-able by authenticated or anon (effective, incl. via PUBLIC)
--   C10 authenticated: no effective table-level SELECT / TRUNCATE / TRIGGER / REFERENCES   C11 anon: no effective table or column privilege
--   C12 nothing granted to PUBLIC on profiles, table or column level
--   D1 anon direct read of profiles FAILS   D2 anon cannot read email either
--   R1-R4 anonymous PUBLIC SURFACES still work (their RPCs run as definer): get_public_educators, get_platform_stats,
--      get_featured_landing_content, get_group_preview (R4 uses a real token and must return that group's name, else SKIP/FAIL)
--   R5 a signed-in student can still call get_my_friends_with_stats / get_discoverable_users
BEGIN;

DO $t$
DECLARE
  adm uuid; stu uuid;
  v_res text[] := '{}'; v_err text; n int; nm text; rl text; sqlst text;
  tz text; tok uuid; tokname text; pv text;
BEGIN
  SELECT id INTO adm FROM public.profiles WHERE role = 'admin' LIMIT 1;
  SELECT id INTO stu FROM public.profiles WHERE role = 'student' AND full_name IS NOT NULL ORDER BY id LIMIT 1;
  IF adm IS NULL OR stu IS NULL THEN
    PERFORM set_config('app.t07f_results', 'SETUP|need an admin and a student|missing|SKIP', true);
    RETURN;
  END IF;

  -- ---------- as a student ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', stu, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  BEGIN PERFORM email FROM public.profiles LIMIT 1; RESET ROLE;
    v_res := v_res || 'C1 student cannot read email [CRITICAL]|permission denied|read succeeded|FAIL';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS sqlst = RETURNED_SQLSTATE; RESET ROLE;
    v_res := v_res || ('C1 student cannot read email [CRITICAL]|42501|' || sqlst || '|' || CASE WHEN sqlst = '42501' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM access_request_ref FROM public.profiles LIMIT 1; RESET ROLE;
    v_res := v_res || 'C2 student cannot read access_request_ref|permission denied|read succeeded|FAIL';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS sqlst = RETURNED_SQLSTATE; RESET ROLE;
    v_res := v_res || ('C2 student cannot read access_request_ref|42501|' || sqlst || '|' || CASE WHEN sqlst = '42501' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM * FROM public.profiles LIMIT 1; RESET ROLE;
    v_res := v_res || 'C3 SELECT * is refused|permission denied|read succeeded|FAIL';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS sqlst = RETURNED_SQLSTATE; RESET ROLE;
    v_res := v_res || ('C3 SELECT * is refused|42501|' || sqlst || '|' || CASE WHEN sqlst = '42501' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN SELECT count(*) INTO n FROM (SELECT id, full_name, role, course_level, institution FROM public.profiles LIMIT 20) x; RESET ROLE;
    v_res := v_res || ('C4 other profiles still readable (name/role/course)|>0|' || n || '|' || CASE WHEN n > 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('C4|>0|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN SELECT timezone INTO tz FROM public.profiles WHERE id = stu; GET DIAGNOSTICS n = ROW_COUNT; RESET ROLE;
    v_res := v_res || ('C5 own row readable (allow-listed columns)|1 row|' || n || ' row|' || CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('C5|1 row|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN UPDATE public.profiles SET full_name = full_name WHERE id = stu; GET DIAGNOSTICS n = ROW_COUNT; RESET ROLE;
    v_res := v_res || ('C6 student can still update own full_name|1 row|' || n || ' row|' || CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('C6|1 row|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN UPDATE public.profiles SET role = 'super_admin' WHERE id = stu; GET DIAGNOSTICS n = ROW_COUNT; RESET ROLE;
    v_res := v_res || ('C7 student cannot change own role [CRITICAL]|error|accepted (' || n || ' row)|FAIL')::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C7 student cannot change own role [CRITICAL]|error|' || left(v_err, 60) || '|PASS')::text; END;

  -- ---------- as an admin (still a client role) ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    BEGIN PERFORM email FROM public.profiles LIMIT 1; n := 1; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS sqlst = RETURNED_SQLSTATE; n := 0; END;
    SELECT count(*) INTO nm FROM public.admin_read_profiles(NULL, NULL, NULL, NULL, 5) WHERE email IS NOT NULL;
    RESET ROLE;
    v_res := v_res || ('C8 admin: table read of email blocked, admin function works|blocked, >0 rows|' || CASE WHEN n = 0 THEN 'blocked' ELSE 'READ OK' END || ', ' || nm || ' rows|' ||
             CASE WHEN n = 0 AND nm::int > 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('C8|ok|' || v_err || '|FAIL')::text; END;

  -- ---------- catalog ----------
  v_res := v_res || ('C9 email/access_request_ref not SELECT-able by authenticated or anon|all false|' ||
           has_column_privilege('authenticated', 'public.profiles', 'email', 'SELECT') || '/' || has_column_privilege('authenticated', 'public.profiles', 'access_request_ref', 'SELECT') || '/' ||
           has_column_privilege('anon', 'public.profiles', 'email', 'SELECT') || '/' || has_column_privilege('anon', 'public.profiles', 'access_request_ref', 'SELECT') || '|' ||
           CASE WHEN NOT (has_column_privilege('authenticated', 'public.profiles', 'email', 'SELECT') OR has_column_privilege('authenticated', 'public.profiles', 'access_request_ref', 'SELECT')
                          OR has_column_privilege('anon', 'public.profiles', 'email', 'SELECT') OR has_column_privilege('anon', 'public.profiles', 'access_request_ref', 'SELECT')) THEN 'PASS' ELSE 'FAIL' END)::text;
  -- EFFECTIVE privileges (has_*_privilege includes anything inherited through PUBLIC), not just direct grantee rows.
  SELECT count(*) INTO n FROM unnest(ARRAY['SELECT', 'TRUNCATE', 'TRIGGER', 'REFERENCES']) AS pv
   WHERE has_table_privilege('authenticated', 'public.profiles', pv);
  v_res := v_res || ('C10 authenticated: no effective table-level SELECT / TRUNCATE / TRIGGER / REFERENCES|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  SELECT count(*) INTO n FROM unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'TRIGGER', 'REFERENCES']) AS pv
   WHERE has_table_privilege('anon', 'public.profiles', pv);
  SELECT count(*) INTO nm FROM pg_attribute a
   WHERE a.attrelid = 'public.profiles'::regclass AND a.attnum > 0 AND NOT a.attisdropped
     AND (has_column_privilege('anon', a.attrelid, a.attnum, 'SELECT') OR has_column_privilege('anon', a.attrelid, a.attnum, 'UPDATE')
          OR has_column_privilege('anon', a.attrelid, a.attnum, 'INSERT'));
  v_res := v_res || ('C11 anon: no effective table or column privilege on profiles|0 / 0|' || n || ' / ' || nm || '|' || CASE WHEN n = 0 AND nm::int = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  -- C12: nothing granted to PUBLIC (grantee 0) at table or column level
  SELECT count(*) INTO n FROM (
    SELECT 1 FROM pg_class c, aclexplode(c.relacl) a WHERE c.oid = 'public.profiles'::regclass AND a.grantee = 0
    UNION ALL
    SELECT 1 FROM pg_attribute at, aclexplode(at.attacl) a WHERE at.attrelid = 'public.profiles'::regclass AND at.attacl IS NOT NULL AND a.grantee = 0
  ) pub;
  v_res := v_res || ('C12 nothing granted to PUBLIC on profiles (table or column)|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ---------- as anon ----------
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM id FROM public.profiles LIMIT 1; RESET ROLE;
    v_res := v_res || 'D1 anon direct profile read fails|42501|read succeeded|FAIL';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS sqlst = RETURNED_SQLSTATE; RESET ROLE;
    v_res := v_res || ('D1 anon direct profile read fails|42501|' || sqlst || '|' || CASE WHEN sqlst = '42501' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM email FROM public.profiles LIMIT 1; RESET ROLE;
    v_res := v_res || 'D2 anon email read fails|42501|read succeeded|FAIL';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS sqlst = RETURNED_SQLSTATE; RESET ROLE;
    v_res := v_res || ('D2 anon email read fails|42501|' || sqlst || '|' || CASE WHEN sqlst = '42501' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- ---------- anonymous public surfaces (definer RPCs) ----------
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM * FROM public.get_public_educators(); RESET ROLE; v_res := v_res || 'R1 get_public_educators works for anon|no error|ok|PASS';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R1 get_public_educators works for anon|no error|' || left(v_err, 70) || '|FAIL')::text; END;
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM public.get_platform_stats(); RESET ROLE; v_res := v_res || 'R2 get_platform_stats works for anon|no error|ok|PASS';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R2 get_platform_stats works for anon|no error|' || left(v_err, 70) || '|FAIL')::text; END;
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM public.get_featured_landing_content(); RESET ROLE; v_res := v_res || 'R3 get_featured_landing_content works for anon|no error|ok|PASS';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R3 get_featured_landing_content works for anon|no error|' || left(v_err, 70) || '|FAIL')::text; END;
  -- R4 uses a REAL, eligible invite token (an active group) and requires the preview to actually contain that group's name.
  SELECT invite_token, name INTO tok, tokname FROM public.study_groups
   WHERE invite_token IS NOT NULL AND archived_at IS NULL AND name !~ '["\\]' ORDER BY created_at LIMIT 1;
  IF tok IS NULL THEN
    v_res := v_res || 'R4 get_group_preview works for anon|a real group token|none found|SKIP';
  ELSE
    EXECUTE 'SET LOCAL ROLE anon';
    BEGIN
      pv := (SELECT public.get_group_preview(tok))::text; RESET ROLE;
      v_res := v_res || ('R4 get_group_preview returns the real group to anon|preview contains "' || tokname || '"|' || left(COALESCE(pv, 'NULL'), 60) || '|' ||
               CASE WHEN pv IS NOT NULL AND position(tokname IN pv) > 0 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R4 get_group_preview works for anon|real preview|' || left(v_err, 70) || '|FAIL')::text; END;
  END IF;

  -- ---------- signed-in surfaces that already used masked emails ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', stu, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM * FROM public.get_my_friends_with_stats(); PERFORM * FROM public.get_discoverable_users(); RESET ROLE;
    v_res := v_res || 'R5 friends / discoverable users functions still work|no error|ok|PASS';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R5 friends / discoverable users functions|no error|' || left(v_err, 70) || '|FAIL')::text; END;

  PERFORM set_config('app.t07f_results', array_to_string(v_res, chr(10)), true);
END $t$;

SELECT split_part(l, '|', 1) AS test, split_part(l, '|', 2) AS expected, split_part(l, '|', 3) AS actual, split_part(l, '|', 4) AS result
FROM unnest(string_to_array(current_setting('app.t07f_results', true), chr(10))) AS l;

ROLLBACK;
