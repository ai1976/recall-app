-- [TEST] admin_grant_access / admin_suspend_user / admin_reactivate_user (run AFTER 02). Rollback-only, safe on production.
-- Description: Impersonates the real people with the client role (SET LOCAL ROLE authenticated), so RLS and grants are
--   exercised exactly like the app. Everything (status changes, audit rows, notifications) is rolled back at the end.
--     G1  PLAIN ADMIN (Shailaja) grants access to a not-yet-enrolled student -> changed, profile updated, ONE audit row
--         by her, ONE notification            (this is the case the old page silently failed)
--     G2  the same grant again -> changed=false already_enrolled, NO new audit row, NO new notification
--     S1  plain admin suspends a student -> changed, status 'suspended', audit row by her
--     S2  suspend again -> changed=false, no new audit row
--     S3  super admin (Anand) reactivates -> changed, status 'active', audit row by him
--     S4  reactivate again -> changed=false not_suspended, no new audit row
--     D1  admin cannot act on themselves
--     D2  plain admin cannot act on a super admin  [CRITICAL]
--     D3  super admin cannot act on a plain admin (role changes belong to the Super Admin dashboard)
--     D4  a student cannot call the action [CRITICAL]
--     D5  unknown target user is refused
--     D6  anon cannot execute; no client role can execute the internal helper
--   If no not-yet-enrolled student exists, G1/G2 report SKIP (nothing to grant). Results via a transaction-local setting.

BEGIN;

DO $t$
DECLARE
  shailaja constant uuid := 'c80a9f56-fc73-4993-8acd-65a2330f1aa1';  -- plain admin
  anand    constant uuid := '82bc189a-d072-4952-a47f-73b045c8a3c4';  -- super admin
  tester   constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';  -- TestOutlook (student)
  stud     uuid;
  v_res text[] := '{}';
  v_err text; r jsonb; a0 int; a1 int; n0 int; n1 int; s text; t text;
BEGIN
  SELECT p.id INTO stud FROM public.profiles p
   WHERE p.role = 'student' AND p.id <> tester AND p.account_type IS DISTINCT FROM 'enrolled'
   ORDER BY p.created_at LIMIT 1;

  -- ---------- G1 / G2 ----------
  IF stud IS NULL THEN
    v_res := v_res || 'G1 plain admin grants access|changed|no not-yet-enrolled student to test|SKIP'::text;
    v_res := v_res || 'G2 grant again is a truthful no-op|changed=false|no not-yet-enrolled student to test|SKIP'::text;
  ELSE
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'grant_access' AND target_user_id = stud AND admin_id = shailaja;
    SELECT count(*) INTO n0 FROM public.notifications WHERE user_id = stud AND type = 'access_granted';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      r := public.admin_grant_access(stud);
      RESET ROLE;
      SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'grant_access' AND target_user_id = stud AND admin_id = shailaja;
      SELECT count(*) INTO n1 FROM public.notifications WHERE user_id = stud AND type = 'access_granted';
      SELECT account_type INTO s FROM public.profiles WHERE id = stud;
      v_res := v_res || ('G1 plain admin grants access|changed, enrolled, +1 audit, +1 notification|' || (r->>'changed') || ', ' || s || ', +' || (a1 - a0) || ', +' || (n1 - n0) || '|' ||
               CASE WHEN (r->>'changed') = 'true' AND s = 'enrolled' AND a1 - a0 = 1 AND n1 - n0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('G1 plain admin grants access|changed|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      r := public.admin_grant_access(stud);
      RESET ROLE;
      SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'grant_access' AND target_user_id = stud AND admin_id = shailaja;
      SELECT count(*) INTO n0 FROM public.notifications WHERE user_id = stud AND type = 'access_granted';
      v_res := v_res || ('G2 grant again is a truthful no-op|changed=false, audit/notification unchanged|' || (r->>'changed') || ' / ' || COALESCE(r->>'reason', '') || ' / audit ' || a0 || ' (was ' || a1 || ') / notif ' || n0 || ' (was ' || n1 || ')|' ||
               CASE WHEN (r->>'changed') = 'false' AND a0 = a1 AND n0 = n1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('G2 grant again is a truthful no-op|changed=false|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- ---------- S1 / S2 (plain admin suspends) ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_suspend_user(tester);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
    SELECT status INTO s FROM public.profiles WHERE id = tester;
    v_res := v_res || ('S1 plain admin suspends a student|changed, suspended, +1 audit|' || (r->>'changed') || ', ' || s || ', +' || (a1 - a0) || '|' ||
             CASE WHEN (r->>'changed') = 'true' AND s = 'suspended' AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S1 plain admin suspends a student|changed|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_suspend_user(tester);
    RESET ROLE;
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'suspend_user' AND target_user_id = tester AND admin_id = shailaja;
    v_res := v_res || ('S2 suspend again is a truthful no-op|changed=false, audit unchanged|' || (r->>'changed') || ' / audit ' || a0 || ' (was ' || a1 || ')|' ||
             CASE WHEN (r->>'changed') = 'false' AND a0 = a1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S2 suspend again is a truthful no-op|changed=false|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- ---------- S3 / S4 (super admin reactivates) ----------
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'reactivate_user' AND target_user_id = tester AND admin_id = anand;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_reactivate_user(tester);
    RESET ROLE;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'reactivate_user' AND target_user_id = tester AND admin_id = anand;
    SELECT status INTO s FROM public.profiles WHERE id = tester;
    v_res := v_res || ('S3 super admin reactivates|changed, active, +1 audit|' || (r->>'changed') || ', ' || s || ', +' || (a1 - a0) || '|' ||
             CASE WHEN (r->>'changed') = 'true' AND s = 'active' AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S3 super admin reactivates|changed|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_reactivate_user(tester);
    RESET ROLE;
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'reactivate_user' AND target_user_id = tester AND admin_id = anand;
    v_res := v_res || ('S4 reactivate again is a truthful no-op|changed=false not_suspended, audit unchanged|' || (r->>'changed') || ' / ' || COALESCE(r->>'reason', '') || ' / audit ' || a0 || ' (was ' || a1 || ')|' ||
             CASE WHEN (r->>'changed') = 'false' AND a0 = a1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S4 reactivate again is a truthful no-op|changed=false|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- ---------- D1 admin on self ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_suspend_user(shailaja);
    RESET ROLE;
    v_res := v_res || 'D1 admin cannot act on themselves|cannot_act_on_self|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('D1 admin cannot act on themselves|cannot_act_on_self|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%cannot_act_on_self%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- D2 plain admin on super admin ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_suspend_user(anand);
    RESET ROLE;
    v_res := v_res || 'D2 plain admin cannot act on a super admin [CRITICAL]|cannot_act_on_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('D2 plain admin cannot act on a super admin [CRITICAL]|cannot_act_on_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%cannot_act_on_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- D3 super admin on plain admin ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_suspend_user(shailaja);
    RESET ROLE;
    v_res := v_res || 'D3 super admin cannot act on a plain admin|cannot_act_on_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('D3 super admin cannot act on a plain admin|cannot_act_on_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%cannot_act_on_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- D4 student ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_grant_access(COALESCE(stud, shailaja));
    RESET ROLE;
    v_res := v_res || 'D4 a student cannot call the action [CRITICAL]|not_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('D4 a student cannot call the action [CRITICAL]|not_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- D5 unknown target ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_grant_access(gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'D5 unknown target user is refused|target_not_found|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('D5 unknown target user is refused|target_not_found|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%target_not_found%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- D6 anon + helper ----------
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.admin_grant_access(tester);
    RESET ROLE;
    s := 'no error';
  EXCEPTION WHEN OTHERS THEN s := SQLERRM; RESET ROLE; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_user_action_denial(shailaja, tester);
    RESET ROLE;
    t := 'no error';
  EXCEPTION WHEN OTHERS THEN t := SQLERRM; RESET ROLE; END;
  v_res := v_res || ('D6 anon cannot execute the action; no client role can execute the helper|permission denied / permission denied|' || left(s, 30) || ' / ' || left(t, 30) || '|' ||
           CASE WHEN s ILIKE '%permission denied%' AND t ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t03b4_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t03b4_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
