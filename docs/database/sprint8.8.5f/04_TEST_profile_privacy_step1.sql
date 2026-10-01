-- [TEST] Profile privacy STEP 1 (run AFTER 03). Rollback-only, safe on production.
-- Description: Runs as the real people (SET LOCAL ROLE authenticated). It creates its own temporary group and members; everything is
--   undone by the final ROLLBACK. Needs 1 admin, 1 super_admin, 1 professor and 4 students with a name and email.
--   A1 admin reads profiles incl. email   A2 super_admin too   A3 STUDENT refused [CRITICAL]   A4 PROFESSOR refused [CRITICAL]
--   A5 anon cannot execute   A6 exact-email filter returns exactly one row   A7 id filter works   A8 p_limit is honoured / capped
--   G1 group admin finds a student by PARTIAL NAME     G2 exact full email finds the student     G3 PARTIAL email finds nothing
--   G4 result never contains the raw email (masked, no 'email' key)   G5 plain member refused   G6 non-member refused [CRITICAL]
--   G7 1-character query returns nothing   G8 already-active member is not offered   G9 anon cannot execute
--   G10 SUSPENDED group admin refused [CRITICAL]   T1 catalog: all 3 functions SECURITY DEFINER + fixed search_path + no anon/PUBLIC
--   execute + authenticated can run   P4 the step-3 precondition (no email in get_author_profile outside comments) is met
--   P1 get_author_profile has NO email key   P2 passing viewer = author does NOT make it "own" (viewer id ignored)   P3 own profile is_own=true

BEGIN;

DO $t$
DECLARE
  adm uuid; sup uuid; prof uuid; s1 uuid; s2 uuid; s3 uuid; s4 uuid;
  g uuid; s4name text; s4email text; frag text;
  v_res text[] := '{}'; v_err text; n int; r json; j jsonb;
  tgt_found boolean; leaked boolean; ok_p4 boolean;
BEGIN
  SELECT id INTO adm  FROM public.profiles WHERE role = 'admin' LIMIT 1;
  SELECT id INTO sup  FROM public.profiles WHERE role = 'super_admin' LIMIT 1;
  SELECT id INTO prof FROM public.profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO s1 FROM public.profiles WHERE role = 'student' AND email IS NOT NULL AND char_length(btrim(COALESCE(full_name,''))) >= 3 ORDER BY id LIMIT 1;
  SELECT id INTO s2 FROM public.profiles WHERE role = 'student' AND email IS NOT NULL AND char_length(btrim(COALESCE(full_name,''))) >= 3 AND id <> s1 ORDER BY id LIMIT 1;
  SELECT id INTO s3 FROM public.profiles WHERE role = 'student' AND email IS NOT NULL AND char_length(btrim(COALESCE(full_name,''))) >= 3 AND id NOT IN (s1, s2) ORDER BY id LIMIT 1;
  SELECT id INTO s4 FROM public.profiles WHERE role = 'student' AND email IS NOT NULL AND char_length(btrim(COALESCE(full_name,''))) >= 3 AND id NOT IN (s1, s2, s3) ORDER BY id LIMIT 1;
  IF adm IS NULL OR sup IS NULL OR prof IS NULL OR s4 IS NULL THEN
    PERFORM set_config('app.t04f_results', 'SETUP|need admin, super_admin, professor, 4 students|missing|SKIP', true);
    RETURN;
  END IF;
  SELECT full_name, email INTO s4name, s4email FROM public.profiles WHERE id = s4;
  -- Positive-path accounts are made explicitly ACTIVE inside this rolled-back transaction (never persisted).
  UPDATE public.profiles SET status = 'active' WHERE id IN (adm, sup, prof, s1, s2, s3, s4);

  INSERT INTO public.study_groups (name, group_type, created_by) VALUES ('ZZ Privacy Test Group', 'custom', s1) RETURNING id INTO g;
  INSERT INTO public.study_group_members (group_id, user_id, role, status) VALUES (g, s1, 'admin', 'active'), (g, s2, 'member', 'active');

  -- ---------- A: admin_read_profiles ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.admin_read_profiles(NULL, NULL, NULL, NULL, 50) WHERE email IS NOT NULL;
    RESET ROLE;
    v_res := v_res || ('A1 admin reads profiles incl. email|>0 rows with email|' || n || '|' || CASE WHEN n > 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('A1|ok|' || v_err || '|FAIL')::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', sup, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.admin_read_profiles(NULL, NULL, NULL, NULL, 50);
    RESET ROLE;
    v_res := v_res || ('A2 super_admin reads profiles|>0 rows|' || n || '|' || CASE WHEN n > 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('A2|ok|' || v_err || '|FAIL')::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', s3, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM * FROM public.admin_read_profiles(NULL, NULL, NULL, NULL, 5); RESET ROLE;
    v_res := v_res || 'A3 student refused [CRITICAL]|not_admin|returned rows|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('A3 student refused [CRITICAL]|not_admin|' || v_err || '|' || CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', prof, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM * FROM public.admin_read_profiles(NULL, NULL, NULL, NULL, 5); RESET ROLE;
    v_res := v_res || 'A4 professor refused [CRITICAL]|not_admin|returned rows|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('A4 professor refused [CRITICAL]|not_admin|' || v_err || '|' || CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  v_res := v_res || ('A5 anon cannot execute admin_read_profiles|false|' || has_function_privilege('anon', 'public.admin_read_profiles(uuid[],text[],text[],uuid[],integer)', 'EXECUTE') || '|' ||
           CASE WHEN NOT has_function_privilege('anon', 'public.admin_read_profiles(uuid[],text[],text[],uuid[],integer)', 'EXECUTE') THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.admin_read_profiles(NULL, NULL, ARRAY['  ' || upper(s4email) || ' '], NULL, 50);
    RESET ROLE;
    v_res := v_res || ('A6 email filter (case/space-insensitive) returns one row|1|' || n || '|' || CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('A6|1|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.admin_read_profiles(ARRAY[s1, s2], NULL, NULL, NULL, 50);
    RESET ROLE;
    v_res := v_res || ('A7 id filter|2|' || n || '|' || CASE WHEN n = 2 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('A7|2|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.admin_read_profiles(NULL, NULL, NULL, NULL, 3);
    RESET ROLE;
    v_res := v_res || ('A8 p_limit honoured|3|' || n || '|' || CASE WHEN n = 3 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('A8|3|' || v_err || '|FAIL')::text; END;

  -- ---------- G: search_users_for_group_invite (caller s1 = active group admin) ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', s1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT EXISTS (SELECT 1 FROM public.search_users_for_group_invite(g, substr(btrim(s4name), 1, 3)) x WHERE x.user_id = s4) INTO tgt_found;
    RESET ROLE;
    v_res := v_res || ('G1 partial NAME search finds the student|true|' || tgt_found || '|' || CASE WHEN tgt_found THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('G1|true|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT EXISTS (SELECT 1 FROM public.search_users_for_group_invite(g, s4email) x WHERE x.user_id = s4) INTO tgt_found;
    RESET ROLE;
    v_res := v_res || ('G2 exact full email finds the student|true|' || tgt_found || '|' || CASE WHEN tgt_found THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('G2|true|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    frag := left(s4email, char_length(s4email) - 3);  -- still contains '@' but is not the full address
    SELECT count(*) INTO n FROM public.search_users_for_group_invite(g, frag);
    RESET ROLE;
    v_res := v_res || ('G3 PARTIAL email (with @) finds nothing|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('G3|0|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT COALESCE(bool_or(to_jsonb(x)::text ILIKE '%' || s4email || '%' OR to_jsonb(x) ? 'email'), false) INTO leaked
      FROM public.search_users_for_group_invite(g, s4email) x;
    RESET ROLE;
    v_res := v_res || ('G4 raw email never returned|false|' || leaked || '|' || CASE WHEN NOT leaked THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('G4|false|' || v_err || '|FAIL')::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', s2, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM * FROM public.search_users_for_group_invite(g, 'abc'); RESET ROLE;
    v_res := v_res || 'G5 plain member refused|error|allowed|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('G5 plain member refused|error|' || v_err || '|' || CASE WHEN v_err ILIKE '%group admins%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', s3, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM * FROM public.search_users_for_group_invite(g, 'abc'); RESET ROLE;
    v_res := v_res || 'G6 non-member refused [CRITICAL]|error|allowed|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('G6 non-member refused [CRITICAL]|error|' || v_err || '|' || CASE WHEN v_err ILIKE '%group admins%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', s1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.search_users_for_group_invite(g, 'a');
    RESET ROLE;
    v_res := v_res || ('G7 1-character query returns nothing|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('G7|0|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO n FROM public.search_users_for_group_invite(g, (SELECT email FROM public.profiles WHERE id = s2));
    RESET ROLE;
    v_res := v_res || ('G8 an existing member is not offered|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('G8|0|' || v_err || '|FAIL')::text; END;

  v_res := v_res || ('G9 anon cannot execute search function|false|' || has_function_privilege('anon', 'public.search_users_for_group_invite(uuid,text)', 'EXECUTE') || '|' ||
           CASE WHEN NOT has_function_privilege('anon', 'public.search_users_for_group_invite(uuid,text)', 'EXECUTE') THEN 'PASS' ELSE 'FAIL' END)::text;

  -- G10: a SUSPENDED group admin is refused (done as postgres, then called as that user; rolled back with everything else)
  UPDATE public.profiles SET status = 'suspended' WHERE id = s1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', s1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM * FROM public.search_users_for_group_invite(g, s4email); RESET ROLE;
    v_res := v_res || 'G10 suspended group admin refused [CRITICAL]|error|allowed|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('G10 suspended group admin refused [CRITICAL]|not active|' || v_err || '|' || CASE WHEN v_err ILIKE '%not active%' THEN 'PASS' ELSE 'FAIL' END)::text; END;
  UPDATE public.profiles SET status = 'active' WHERE id = s1;

  -- ---------- P: get_author_profile ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', s3, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.get_author_profile(s4, s4);   -- caller s3 asks about s4 while PRETENDING to be s4
    RESET ROLE;
    j := r::jsonb;
    v_res := v_res || ('P1 no email key in profile|false|' || ((j->'profile') ? 'email') || '|' || CASE WHEN NOT ((j->'profile') ? 'email') THEN 'PASS' ELSE 'FAIL' END)::text;
    v_res := v_res || ('P2 viewer id ignored (is_own stays false)|false|' || (j->>'is_own') || '|' || CASE WHEN (j->>'is_own') = 'false' THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('P1/P2|ok|' || v_err || '|FAIL')::text; END;

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.get_author_profile(s3, NULL);
    RESET ROLE;
    j := r::jsonb;
    v_res := v_res || ('P3 own profile is_own=true|true|' || (j->>'is_own') || '|' || CASE WHEN (j->>'is_own') = 'true' THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('P3|true|' || v_err || '|FAIL')::text; END;

  -- ---------- T: catalog checks (all three functions) ----------
  DECLARE
    fn text; fo oid; bad text := '';
  BEGIN
    FOREACH fn IN ARRAY ARRAY['public.admin_read_profiles(uuid[],text[],text[],uuid[],integer)',
                              'public.search_users_for_group_invite(uuid,text)',
                              'public.get_author_profile(uuid,uuid)'] LOOP
      fo := to_regprocedure(fn);
      IF fo IS NULL THEN bad := bad || fn || ' missing; '; CONTINUE; END IF;
      IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = fo) THEN bad := bad || fn || ' not SECURITY DEFINER; '; END IF;
      IF NOT COALESCE((SELECT array_to_string(proconfig, ',') ILIKE '%search_path=public, extensions%' FROM pg_proc WHERE oid = fo), false) THEN
        bad := bad || fn || ' search_path not fixed to public, extensions; '; END IF;
      IF has_function_privilege('anon', fo, 'EXECUTE') THEN bad := bad || fn || ' anon can execute; '; END IF;
      IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
                  WHERE p.oid = fo AND a.grantee = 0 AND a.privilege_type = 'EXECUTE') THEN bad := bad || fn || ' PUBLIC can execute; '; END IF;
      IF NOT has_function_privilege('authenticated', fo, 'EXECUTE') THEN bad := bad || fn || ' authenticated cannot execute; '; END IF;
    END LOOP;
    v_res := v_res || ('T1 all 3 functions: SECURITY DEFINER, fixed search_path, no anon/PUBLIC, authenticated can run|no problems|' ||
             CASE WHEN bad = '' THEN 'none' ELSE bad END || '|' || CASE WHEN bad = '' THEN 'PASS' ELSE 'FAIL' END)::text;
  END;

  -- P4: the exact precondition that step 3 (06) checks must be satisfied after step 1
  ok_p4 := NOT (regexp_replace(pg_get_functiondef(to_regprocedure('public.get_author_profile(uuid,uuid)')), '--[^\n]*', '', 'g') ~* '\yemail\y');
  v_res := v_res || ('P4 step-3 precondition met (get_author_profile body has no email outside comments)|true|' || ok_p4::text || '|' ||
           CASE WHEN ok_p4 THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t04f_results', array_to_string(v_res, chr(10)), true);
END $t$;

SELECT split_part(l, '|', 1) AS test, split_part(l, '|', 2) AS expected, split_part(l, '|', 3) AS actual, split_part(l, '|', 4) AS result
FROM unnest(string_to_array(current_setting('app.t04f_results', true), chr(10))) AS l;

ROLLBACK;
