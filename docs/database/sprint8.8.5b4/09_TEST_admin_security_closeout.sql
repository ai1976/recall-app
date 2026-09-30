-- [TEST] Admin-security closeout functions (run AFTER 08). Rollback-only, safe on production.
-- Description: Impersonates the real people with the client role (SET LOCAL ROLE authenticated). Everything - role
--   changes, deleted note, deleted user data, audit rows - is rolled back at the end.
--     C1  super admin changes a student's role -> changed, role_change_log +1, audit +1 (by him, target = student)
--     C2  same role again -> changed=false same_role, no new rows
--     C3  PLAIN admin cannot change roles [CRITICAL]
--     C4  super admin cannot change their own role
--     C5  invalid role refused          C6  a student cannot call it [CRITICAL]
--     N1  plain admin deletes a note -> deleted, note gone, audit +1 (target = owner)
--     N2  deleting it again -> deleted=false not_found, no new audit row
--     N3  a student cannot delete a note via the function [CRITICAL]
--     L1  log_admin_event: whitelisted event -> audit +1 with admin_id = the caller (cannot be forged)
--     L2  unknown event refused   L3  a student cannot log events [CRITICAL]   L4  oversized details refused
--     E1  approve_educator_application writes its own audit entry (SKIP if no pending application exists)
--     E2  reject_educator_application writes its own audit entry (SKIP if fewer than 2 pending)
--     U1  admin_delete_user_data refuses yourself     U2 refuses an admin / super admin target [CRITICAL]
--     U3  a plain admin cannot call it [CRITICAL]
--     U4  super admin deletes a student's data -> audit +1 (delete_user, details carry name/role/counts), profile gone
--     X1  anon cannot execute the new functions
--   Results via a transaction-local setting.

BEGIN;

DO $t$
DECLARE
  shailaja constant uuid := 'c80a9f56-fc73-4993-8acd-65a2330f1aa1';  -- plain admin
  anand    constant uuid := '82bc189a-d072-4952-a47f-73b045c8a3c4';  -- super admin
  tester   constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';  -- TestOutlook (student)
  v_res text[] := '{}';
  v_err text; r jsonb; a0 int; a1 int; l0 int; l1 int; n int; s text;
  v_note uuid; v_owner uuid; v_req1 uuid; v_req2 uuid; v_applicant uuid; txt text;
BEGIN
  -- ---------- C1 / C2 ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'change_role' AND target_user_id = tester AND admin_id = anand;
  SELECT count(*) INTO l0 FROM public.role_change_log WHERE user_id = tester;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_change_role(tester, 'professor', 'test');
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'change_role' AND target_user_id = tester AND admin_id = anand;
    SELECT count(*) INTO l1 FROM public.role_change_log WHERE user_id = tester;
    SELECT role INTO s FROM public.profiles WHERE id = tester;
    v_res := v_res || ('C1 super admin changes a role|changed, professor, +1 audit, +1 role log|' || (r->>'changed') || ', ' || s || ', +' || (a1 - a0) || ', +' || (l1 - l0) || '|' ||
             CASE WHEN (r->>'changed') = 'true' AND s = 'professor' AND a1 - a0 = 1 AND l1 - l0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C1 super admin changes a role|changed|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_change_role(tester, 'professor', 'again');
    RESET ROLE;
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'change_role' AND target_user_id = tester AND admin_id = anand;
    SELECT count(*) INTO l0 FROM public.role_change_log WHERE user_id = tester;
    v_res := v_res || ('C2 same role again is a truthful no-op|changed=false same_role, nothing new written|' || (r->>'changed') || ' / ' || COALESCE(r->>'reason', '') || ' / audit ' || a0 || ' (was ' || a1 || ') / log ' || l0 || ' (was ' || l1 || ')|' ||
             CASE WHEN (r->>'changed') = 'false' AND a0 = a1 AND l0 = l1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C2 same role again is a truthful no-op|changed=false|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- ---------- C3 plain admin ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_change_role(tester, 'admin', 'x');
    RESET ROLE;
    v_res := v_res || 'C3 plain admin cannot change roles [CRITICAL]|super_admin only|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C3 plain admin cannot change roles [CRITICAL]|super_admin only|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%super_admin only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- C4 / C5 / C6 ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_change_role(anand, 'student', 'x');
    RESET ROLE;
    v_res := v_res || 'C4 cannot change your own role|cannot_act_on_self|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C4 cannot change your own role|cannot_act_on_self|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%cannot_act_on_self%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_change_role(tester, 'emperor', 'x');
    RESET ROLE;
    v_res := v_res || 'C5 invalid role refused|Invalid role|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C5 invalid role refused|Invalid role|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%Invalid role%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_change_role(tester, 'super_admin', 'x');
    RESET ROLE;
    v_res := v_res || 'C6 a student cannot call it [CRITICAL]|super_admin only|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('C6 a student cannot call it [CRITICAL]|super_admin only|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%super_admin only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- N1 / N2 / N3 (notes) ----------
  SELECT n2.id, n2.user_id INTO v_note, v_owner FROM public.notes n2 WHERE n2.user_id <> shailaja LIMIT 1;
  IF v_note IS NULL THEN
    v_res := v_res || 'N1 plain admin deletes a note|deleted|no note available to test|SKIP'::text;
    v_res := v_res || 'N2 deleting again is a truthful no-op|not_found|no note available to test|SKIP'::text;
  ELSE
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'delete_note' AND admin_id = shailaja AND details->>'note_id' = v_note::text;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      r := public.admin_delete_note(v_note);
      RESET ROLE;
      SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'delete_note' AND admin_id = shailaja AND details->>'note_id' = v_note::text AND target_user_id = v_owner;
      SELECT count(*) INTO n FROM public.notes WHERE id = v_note;
      v_res := v_res || ('N1 plain admin deletes a note|deleted, note gone, +1 audit (target = owner)|' || (r->>'deleted') || ', ' || n || ' left, +' || (a1 - a0) || '|' ||
               CASE WHEN (r->>'deleted') = 'true' AND n = 0 AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('N1 plain admin deletes a note|deleted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      r := public.admin_delete_note(v_note);
      RESET ROLE;
      SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'delete_note' AND admin_id = shailaja AND details->>'note_id' = v_note::text;
      v_res := v_res || ('N2 deleting again is a truthful no-op|deleted=false not_found, no new audit|' || (r->>'deleted') || ' / ' || COALESCE(r->>'reason', '') || ' / audit ' || a0 || ' (was ' || a1 || ')|' ||
               CASE WHEN (r->>'deleted') = 'false' AND a0 = a1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('N2 deleting again is a truthful no-op|not_found|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  END IF;

  SELECT n2.id INTO v_note FROM public.notes n2 LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_delete_note(COALESCE(v_note, gen_random_uuid()));
    RESET ROLE;
    v_res := v_res || 'N3 a student cannot delete a note via the function [CRITICAL]|not_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('N3 a student cannot delete a note via the function [CRITICAL]|not_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- L1..L4 (log_admin_event) ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'create_discipline' AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.log_admin_event('create_discipline', '{"name":"test"}'::jsonb);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'create_discipline' AND admin_id = shailaja;
    v_res := v_res || ('L1 whitelisted event is logged under the caller|+1 with admin_id = caller|+' || (a1 - a0) || '|' || CASE WHEN a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('L1 whitelisted event is logged under the caller|+1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.log_admin_event('grant_access', '{}'::jsonb);
    RESET ROLE;
    v_res := v_res || 'L2 an action outside the whitelist is refused|Unknown admin event|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('L2 an action outside the whitelist is refused|Unknown admin event|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%Unknown admin event%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.log_admin_event('admin_login', '{}'::jsonb);
    RESET ROLE;
    v_res := v_res || 'L3 a student cannot log admin events [CRITICAL]|not_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('L3 a student cannot log admin events [CRITICAL]|not_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.log_admin_event('admin_login', jsonb_build_object('blob', repeat('x', 9000)));
    RESET ROLE;
    v_res := v_res || 'L4 oversized details refused|too large|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('L4 oversized details refused|too large|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%too large%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- E1 / E2 (educator applications) ----------
  SELECT (array_agg(id))[1], (array_agg(id))[2]
    INTO v_req1, v_req2
    FROM public.access_requests WHERE request_type = 'educator_application' AND status = 'pending';
  IF v_req1 IS NULL THEN
    v_res := v_res || 'E1 approve writes its own audit entry|+1|no pending educator application to test|SKIP'::text;
  ELSE
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'approve_educator_application' AND details->>'access_request_id' = v_req1::text;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      txt := public.approve_educator_application(v_req1);
      RESET ROLE;
      SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'approve_educator_application' AND details->>'access_request_id' = v_req1::text AND admin_id = shailaja;
      v_res := v_res || ('E1 approve writes its own audit entry|+1 by the admin|' || txt || ', +' || (a1 - a0) || '|' || CASE WHEN a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('E1 approve writes its own audit entry|+1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  END IF;
  IF v_req2 IS NULL THEN
    v_res := v_res || 'E2 reject writes its own audit entry|+1|fewer than 2 pending applications|SKIP'::text;
  ELSE
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'reject_educator_application' AND details->>'access_request_id' = v_req2::text;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      PERFORM public.reject_educator_application(v_req2);
      RESET ROLE;
      SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'reject_educator_application' AND details->>'access_request_id' = v_req2::text AND admin_id = shailaja;
      v_res := v_res || ('E2 reject writes its own audit entry|+1 by the admin|+' || (a1 - a0) || '|' || CASE WHEN a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('E2 reject writes its own audit entry|+1|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- ---------- U1 / U2 / U3 (delete user data guards) ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_delete_user_data(anand);
    RESET ROLE;
    v_res := v_res || 'U1 super admin cannot delete themselves [CRITICAL]|cannot_act_on_self|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('U1 super admin cannot delete themselves [CRITICAL]|cannot_act_on_self|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%cannot_act_on_self%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_delete_user_data(shailaja);
    RESET ROLE;
    v_res := v_res || 'U2 cannot delete an admin account [CRITICAL]|cannot_act_on_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('U2 cannot delete an admin account [CRITICAL]|cannot_act_on_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%cannot_act_on_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_delete_user_data(tester);
    RESET ROLE;
    v_res := v_res || 'U3 a plain admin cannot call it [CRITICAL]|Only super_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('U3 a plain admin cannot call it [CRITICAL]|Only super_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%Only super_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- X1 anon ----------
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.admin_change_role(tester, 'student', 'x');
    RESET ROLE;
    s := 'no error';
  EXCEPTION WHEN OTHERS THEN s := SQLERRM; RESET ROLE; END;
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.log_admin_event('admin_login', '{}'::jsonb);
    RESET ROLE;
    txt := 'no error';
  EXCEPTION WHEN OTHERS THEN txt := SQLERRM; RESET ROLE; END;
  v_res := v_res || ('X1 anon cannot execute the new functions|permission denied / permission denied|' || left(s, 30) || ' / ' || left(txt, 30) || '|' ||
           CASE WHEN s ILIKE '%permission denied%' AND txt ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ---------- U4 (LAST: deletes the test student's data inside the rolled-back transaction) ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'delete_user' AND admin_id = anand AND details->>'deleted_user_role' IS NOT NULL;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_delete_user_data(tester);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'delete_user' AND admin_id = anand AND details->>'deleted_user_role' IS NOT NULL;
    SELECT count(*) INTO n FROM public.profiles WHERE id = tester;
    v_res := v_res || ('U4 super admin deletes a student''s data -> own audit entry, profile gone|+1 audit, 0 profiles left|+' || (a1 - a0) || ', ' || n || ' left|' ||
             CASE WHEN a1 - a0 = 1 AND n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('U4 super admin deletes a student''s data|+1 audit|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('app.t09b4_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t09b4_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
