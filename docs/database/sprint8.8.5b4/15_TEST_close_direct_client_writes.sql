-- [TEST] Direct client writes closed (run AFTER 14). Rollback-only, safe on production.
-- Description: Runs as the real people with the client role. Proves the browser can no longer write the history tables
--   directly AND that every legitimate path still works through the server functions (regression).
--     W1  admin cannot INSERT into admin_audit_log directly [CRITICAL]     W2  a student cannot either
--     W3  admin can still READ the audit log
--     W4  super admin cannot INSERT into role_change_log directly [CRITICAL]   W5  super admin can still READ it
--     W6  anon cannot read role_change_log or the audit log
--     W7  an admin can no longer execute notify_access_granted [CRITICAL]
--     R1  admin_grant_access still works AND still sends exactly one notification (if a not-yet-enrolled student exists)
--     R2  log_admin_event still writes an audit entry under the caller
--     R3  admin_change_role still writes role_change_log + audit (through the definer, not the browser)
--     R4  admin_suspend_user still writes its audit entry
--     P1  catalog: authenticated on admin_audit_log = SELECT; on role_change_log = SELECT; anon = none on both
--   Results via a transaction-local setting.

BEGIN;

DO $t$
DECLARE
  shailaja constant uuid := 'c80a9f56-fc73-4993-8acd-65a2330f1aa1';
  anand    constant uuid := '82bc189a-d072-4952-a47f-73b045c8a3c4';
  tester   constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';
  stud     uuid;
  v_res text[] := '{}';
  v_err text; r jsonb; n int; a0 int; a1 int; n0 int; n1 int; l0 int; l1 int; a text; b text; c text; d text;
BEGIN
  -- ---------- W1 / W3 (plain admin) ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.admin_audit_log (action, admin_id, details) VALUES ('test_direct', shailaja, '{}'::jsonb);
    v_res := v_res || 'W1 admin cannot insert into the audit log directly [CRITICAL]|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W1 admin cannot insert into the audit log directly [CRITICAL]|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  BEGIN
    SELECT count(*) INTO n FROM public.admin_audit_log;
    v_res := v_res || ('W3 admin can still read the audit log|> 0|' || n || '|' || CASE WHEN n > 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W3 admin can still read the audit log|> 0|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  BEGIN
    PERFORM public.notify_access_granted(tester);
    v_res := v_res || 'W7 admin cannot execute notify_access_granted [CRITICAL]|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W7 admin cannot execute notify_access_granted [CRITICAL]|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  -- ---------- W2 student ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.admin_audit_log (action, admin_id, details) VALUES ('test_student', tester, '{}'::jsonb);
    v_res := v_res || 'W2 a student cannot insert into the audit log|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W2 a student cannot insert into the audit log|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  -- ---------- W4 / W5 (super admin) ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.role_change_log (user_id, old_role, new_role, changed_by, reason) VALUES (tester, 'student', 'professor', anand, 'direct');
    v_res := v_res || 'W4 super admin cannot insert into role_change_log directly [CRITICAL]|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W4 super admin cannot insert into role_change_log directly [CRITICAL]|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  BEGIN
    SELECT count(*) INTO n FROM public.role_change_log;
    v_res := v_res || ('W5 super admin can still read role_change_log|>= 0 (no error)|' || n || '|PASS')::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W5 super admin can still read role_change_log|no error|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  RESET ROLE;

  -- ---------- W6 anon ----------
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM 1 FROM public.role_change_log LIMIT 1; a := 'no error'; EXCEPTION WHEN OTHERS THEN a := SQLERRM; END;
  BEGIN PERFORM 1 FROM public.admin_audit_log LIMIT 1; b := 'no error'; EXCEPTION WHEN OTHERS THEN b := SQLERRM; END;
  RESET ROLE;
  v_res := v_res || ('W6 anon cannot read either history table|permission denied / permission denied|' || left(a, 25) || ' / ' || left(b, 25) || '|' ||
           CASE WHEN a ILIKE '%permission denied%' AND b ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ---------- R1 grant still works, exactly one notification ----------
  SELECT p.id INTO stud FROM public.profiles p
   WHERE p.role = 'student' AND p.id <> tester AND p.account_type IS DISTINCT FROM 'enrolled' LIMIT 1;
  IF stud IS NULL THEN
    v_res := v_res || 'R1 admin_grant_access still works, one notification|changed, +1 notification|no not-yet-enrolled student to test|SKIP'::text;
  ELSE
    SELECT count(*) INTO n0 FROM public.notifications WHERE user_id = stud AND type = 'access_granted';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      r := public.admin_grant_access(stud);
      RESET ROLE;
      SELECT count(*) INTO n1 FROM public.notifications WHERE user_id = stud AND type = 'access_granted';
      v_res := v_res || ('R1 admin_grant_access still works, one notification|changed, +1 notification|' || (r->>'changed') || ', +' || (n1 - n0) || '|' ||
               CASE WHEN (r->>'changed') = 'true' AND n1 - n0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('R1 admin_grant_access still works, one notification|changed|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- ---------- R2 log_admin_event ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'admin_login' AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.log_admin_event('admin_login', '{"t":1}'::jsonb);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'admin_login' AND admin_id = shailaja;
    v_res := v_res || ('R2 log_admin_event still writes an entry under the caller|+1|+' || (a1 - a0) || '|' || CASE WHEN a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R2 log_admin_event still writes an entry under the caller|+1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- ---------- R3 change_role ----------
  SELECT count(*) INTO l0 FROM public.role_change_log WHERE user_id = tester;
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'change_role' AND target_user_id = tester;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_change_role(tester, 'professor', 'closeout regression');
    RESET ROLE;
    SELECT count(*) INTO l1 FROM public.role_change_log WHERE user_id = tester;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'change_role' AND target_user_id = tester;
    v_res := v_res || ('R3 admin_change_role still writes role log + audit|+1 / +1|+' || (l1 - l0) || ' / +' || (a1 - a0) || '|' ||
             CASE WHEN l1 - l0 = 1 AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R3 admin_change_role still writes role log + audit|+1 / +1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- ---------- R4 suspend ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_suspend_user(tester);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
    v_res := v_res || ('R4 admin_suspend_user still writes its audit entry|+1|+' || (a1 - a0) || '|' || CASE WHEN a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R4 admin_suspend_user still writes its audit entry|+1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- ---------- P1 catalog ----------
  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO a FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'admin_audit_log' AND grantee = 'authenticated';
  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO b FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'role_change_log' AND grantee = 'authenticated';
  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO c FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'admin_audit_log' AND grantee = 'anon';
  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO d FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'role_change_log' AND grantee = 'anon';
  v_res := v_res || ('P1 authenticated = SELECT on both; anon = none on both|SELECT / SELECT / none / none|' || a || ' / ' || b || ' / ' || c || ' / ' || d || '|' ||
           CASE WHEN a = 'SELECT' AND b = 'SELECT' AND c = 'none' AND d = 'none' THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t15b4_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t15b4_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
