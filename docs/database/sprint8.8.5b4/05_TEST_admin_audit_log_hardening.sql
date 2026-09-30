-- [TEST] admin_audit_log hardening (run AFTER 04). Rollback-only, safe on production.
-- Description: Runs as the real people with the client role.
--     U1  an admin can insert an entry under THEIR OWN id (what every page does)
--     U2  an admin CANNOT insert an entry claiming to be another admin  [CRITICAL]
--     U3  a student cannot insert at all
--     U4  an admin can still read the log
--     U5  UPDATE is refused (permission denied)      [CRITICAL]
--     U6  DELETE is refused (permission denied)      [CRITICAL]
--     U7  catalog: authenticated = INSERT,SELECT; anon = none; TRUNCATE not granted to either
--     U8  the definer functions still write their own entries (a suspend by the plain admin adds an audit row)
--   Results via a transaction-local setting.

BEGIN;

DO $t$
DECLARE
  shailaja constant uuid := 'c80a9f56-fc73-4993-8acd-65a2330f1aa1';
  anand    constant uuid := '82bc189a-d072-4952-a47f-73b045c8a3c4';
  tester   constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';
  v_res text[] := '{}';
  v_err text; n int; a text; b text; c boolean; d boolean; a0 int; a1 int;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.admin_audit_log (action, admin_id, details) VALUES ('test_own_entry', shailaja, '{}'::jsonb);
    v_res := v_res || 'U1 admin inserts under their own id|accepted|accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('U1 admin inserts under their own id|accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  BEGIN
    INSERT INTO public.admin_audit_log (action, admin_id, details) VALUES ('test_forged_entry', anand, '{}'::jsonb);
    v_res := v_res || 'U2 admin cannot forge another admin [CRITICAL]|refused by RLS|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('U2 admin cannot forge another admin [CRITICAL]|refused by RLS|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  BEGIN
    SELECT count(*) INTO n FROM public.admin_audit_log WHERE action = 'test_own_entry';
    v_res := v_res || ('U4 admin can still read the log|>= 1|' || n || '|' || CASE WHEN n >= 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('U4 admin can still read the log|>= 1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  BEGIN
    UPDATE public.admin_audit_log SET action = 'tampered' WHERE action = 'test_own_entry';
    v_res := v_res || 'U5 UPDATE refused [CRITICAL]|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('U5 UPDATE refused [CRITICAL]|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  BEGIN
    DELETE FROM public.admin_audit_log WHERE action = 'test_own_entry';
    v_res := v_res || 'U6 DELETE refused [CRITICAL]|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('U6 DELETE refused [CRITICAL]|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.admin_audit_log (action, admin_id, details) VALUES ('test_student_entry', tester, '{}'::jsonb);
    v_res := v_res || 'U3 a student cannot insert|refused by RLS|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('U3 a student cannot insert|refused by RLS|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO a
    FROM information_schema.role_table_grants WHERE table_schema = 'public' AND table_name = 'admin_audit_log' AND grantee = 'authenticated';
  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO b
    FROM information_schema.role_table_grants WHERE table_schema = 'public' AND table_name = 'admin_audit_log' AND grantee = 'anon';
  c := has_table_privilege('authenticated', 'public.admin_audit_log', 'TRUNCATE');
  d := has_table_privilege('anon', 'public.admin_audit_log', 'TRUNCATE');
  v_res := v_res || ('U7 authenticated = INSERT,SELECT; anon = none; no TRUNCATE|INSERT,SELECT / none / false / false|' || a || ' / ' || b || ' / ' || c || ' / ' || d || '|' ||
           CASE WHEN a = 'INSERT,SELECT' AND b = 'none' AND NOT c AND NOT d THEN 'PASS' ELSE 'FAIL' END)::text;

  -- U8: a definer function still writes its own audit entry
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_suspend_user(tester);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
    v_res := v_res || ('U8 admin_suspend_user still writes its own audit entry|+1|+' || (a1 - a0) || '|' || CASE WHEN a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('U8 admin_suspend_user still writes its own audit entry|+1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('app.t05b4_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t05b4_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
