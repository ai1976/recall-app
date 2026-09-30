-- [TEST] Batch bulk membership actions (run AFTER 01). Rollback-only, safe on production.
-- Description: Impersonates real people with the client role (SET LOCAL ROLE authenticated). It creates its OWN pending requests
--   inside the transaction (there are none in production), and everything - memberships, notifications, audit rows - is rolled back.
--   Needs a live (non-archived) batch, an archived batch and ~14 enrolled students who are in neither; otherwise rows report SKIP.
--     B1  plain admin (Shailaja) bulk-adds 3 students -> 3 added, active, +3 'batch_added' notifications, +1 audit entry
--     B2  same call again -> 0 added, 3 already active, NO new audit entry, NO new notifications, joined_at NOT re-stamped
--     B3  mixed list (1 new student, a professor, an unknown id, a Tier B student if any, a suspended student) -> only the eligible
--         student is added; every other id is skipped WITH its reason
--     B4  an ARCHIVED batch is refused            B5  a student cannot call it [CRITICAL]
--     B6  501 ids refused    B7  empty list refused    B8  anon cannot execute
--     R1  bulk APPROVE 3 pending requests -> processed 3, active, +3 'batch_approved', +1 audit
--     R2  approve the same ids again -> processed 0, skipped_resolved 3, no new audit
--     R3  bulk REJECT 2 pending requests -> processed 2, rows removed, NO notification, +1 audit
--     R4  a pending request sitting in an ARCHIVED batch -> skipped_archived 1, row stays 'requested'
--     R5  a student cannot resolve requests [CRITICAL]    R6  invalid action refused
--     S1  single approve_batch_join_request now audits (+1) and notifies (+1 'batch_approved')
--     S2  single enroll_user_in_batch_group notifies + audits once; a second call changes nothing (joined_at kept)
--     T1  catalog: no client role can execute admin_batch_action_denial
--   Results via a transaction-local setting.

BEGIN;

DO $t$
DECLARE
  shailaja constant uuid := 'c80a9f56-fc73-4993-8acd-65a2330f1aa1';
  tester   constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';
  b  uuid;  ab uuid;  prof uuid;  tierb uuid;
  pool uuid[];
  v_res text[] := '{}';
  v_err text; r jsonb; n0 int; n1 int; a0 int; a1 int; c int; s text; t text;
  j0 timestamptz; j1 timestamptz;
  ids_a uuid[]; ids_b uuid[]; ids_c uuid[]; ids_arch uuid[]; mixed uuid[];
  expected_skips int;
  s1_membership uuid;
BEGIN
  SELECT id INTO b  FROM public.study_groups WHERE is_batch_group AND archived_at IS NULL ORDER BY name LIMIT 1;
  SELECT id INTO ab FROM public.study_groups WHERE is_batch_group AND archived_at IS NOT NULL ORDER BY name LIMIT 1;
  SELECT id INTO prof  FROM public.profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO tierb FROM public.profiles WHERE role = 'student' AND account_type = 'self_registered' LIMIT 1;

  SELECT array_agg(x.id) INTO pool FROM (
    SELECT p.id FROM public.profiles p
     WHERE p.role = 'student' AND p.account_type IS DISTINCT FROM 'self_registered' AND COALESCE(p.status, 'active') <> 'suspended'
       AND p.id <> tester
       AND NOT EXISTS (SELECT 1 FROM public.study_group_members m WHERE m.user_id = p.id AND m.group_id IN (b, ab))
     ORDER BY p.id LIMIT 14) x;

  IF b IS NULL OR ab IS NULL OR COALESCE(cardinality(pool), 0) < 14 THEN
    v_res := v_res || ('SETUP need a live batch, an archived batch and 14 free enrolled students|found|live=' || COALESCE(b::text, 'none') || ' archived=' || COALESCE(ab::text, 'none') || ' pool=' || COALESCE(cardinality(pool), 0) || '|SKIP')::text;
    PERFORM set_config('app.t02b5_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
    RETURN;
  END IF;

  -- ---------- B1 ----------
  SELECT count(*) INTO n0 FROM public.notifications WHERE type = 'batch_added' AND user_id = ANY (pool[1:3]);
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'bulk_add_to_batch' AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_add_to_batch(b, pool[1:3]);
    RESET ROLE;
    SELECT count(*) INTO n1 FROM public.notifications WHERE type = 'batch_added' AND user_id = ANY (pool[1:3]);
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'bulk_add_to_batch' AND admin_id = shailaja;
    SELECT count(*) INTO c FROM public.study_group_members WHERE group_id = b AND user_id = ANY (pool[1:3]) AND status = 'active';
    v_res := v_res || ('B1 plain admin bulk-adds 3 students|3 added, 3 active, +3 notifications, +1 audit|' || (r->>'added') || ' added, ' || c || ' active, +' || (n1 - n0) || ', +' || (a1 - a0) || '|' ||
             CASE WHEN (r->>'added')::int = 3 AND c = 3 AND n1 - n0 = 3 AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B1 plain admin bulk-adds 3 students|3 added|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- B2 ----------
  SELECT joined_at INTO j0 FROM public.study_group_members WHERE group_id = b AND user_id = pool[1];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_add_to_batch(b, pool[1:3]);
    RESET ROLE;
    SELECT count(*) INTO n0 FROM public.notifications WHERE type = 'batch_added' AND user_id = ANY (pool[1:3]);
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'bulk_add_to_batch' AND admin_id = shailaja;
    SELECT joined_at INTO j1 FROM public.study_group_members WHERE group_id = b AND user_id = pool[1];
    v_res := v_res || ('B2 same call again is a truthful no-op|0 added, 3 already active, nothing new written, joined_at kept|' || (r->>'added') || ' added, ' || (r->>'already_active') || ' already / notif ' || n0 || ' (was ' || n1 || ') / audit ' || a0 || ' (was ' || a1 || ') / joined_at ' || CASE WHEN j0 = j1 THEN 'kept' ELSE 'CHANGED' END || '|' ||
             CASE WHEN (r->>'added')::int = 0 AND (r->>'already_active')::int = 3 AND n0 = n1 AND a0 = a1 AND j0 = j1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B2 same call again is a truthful no-op|0 added|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- B3 mixed list ----------
  UPDATE public.profiles SET status = 'suspended' WHERE id = pool[5];
  mixed := ARRAY[pool[4], prof, gen_random_uuid(), pool[5]];
  IF tierb IS NOT NULL THEN mixed := mixed || tierb; END IF;
  expected_skips := 3 + CASE WHEN tierb IS NOT NULL THEN 1 ELSE 0 END;   -- unknown + professor + suspended (+ Tier B)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_add_to_batch(b, mixed);
    RESET ROLE;
    v_res := v_res || ('B3 mixed list: only the eligible student is added, every skip has a reason|1 added; not_found 1, not_student 1, suspended 1, not_enrolled ' || CASE WHEN tierb IS NOT NULL THEN '1' ELSE '0' END ||
             '|' || (r->>'added') || ' added; not_found ' || (r->>'skipped_not_found') || ', not_student ' || (r->>'skipped_not_student') || ', suspended ' || (r->>'skipped_suspended') || ', not_enrolled ' || (r->>'skipped_not_enrolled') || '|' ||
             CASE WHEN (r->>'added')::int = 1 AND (r->>'skipped_not_found')::int = 1 AND (r->>'skipped_not_student')::int = 1 AND (r->>'skipped_suspended')::int = 1
                       AND (r->>'skipped_not_enrolled')::int = CASE WHEN tierb IS NOT NULL THEN 1 ELSE 0 END THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B3 mixed list|1 added with reasons|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- B4 archived batch ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_bulk_add_to_batch(ab, pool[6:6]);
    RESET ROLE;
    v_res := v_res || 'B4 an archived batch is refused|batch_archived|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B4 an archived batch is refused|batch_archived|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%batch_archived%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- B5 student / B6 / B7 / B8 ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_bulk_add_to_batch(b, pool[7:7]);
    RESET ROLE;
    v_res := v_res || 'B5 a student cannot bulk-add [CRITICAL]|not_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B5 a student cannot bulk-add [CRITICAL]|not_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_bulk_add_to_batch(b, ARRAY(SELECT gen_random_uuid() FROM generate_series(1, 501)));
    RESET ROLE;
    v_res := v_res || 'B6 501 ids refused|max 500|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B6 501 ids refused|max 500|' || left(v_err, 50) || '|' || CASE WHEN v_err ILIKE '%max 500%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_bulk_add_to_batch(b, ARRAY[]::uuid[]);
    RESET ROLE;
    v_res := v_res || 'B7 empty list refused|at least one|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B7 empty list refused|at least one|' || left(v_err, 50) || '|' || CASE WHEN v_err ILIKE '%at least one%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.admin_bulk_add_to_batch(b, pool[8:8]);
    RESET ROLE; s := 'no error';
  EXCEPTION WHEN OTHERS THEN s := SQLERRM; RESET ROLE; END;
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.admin_bulk_resolve_batch_requests('approve', ARRAY[gen_random_uuid()]);
    RESET ROLE; t := 'no error';
  EXCEPTION WHEN OTHERS THEN t := SQLERRM; RESET ROLE; END;
  v_res := v_res || ('B8 anon cannot execute either bulk function|permission denied / permission denied|' || left(s, 28) || ' / ' || left(t, 28) || '|' ||
           CASE WHEN s ILIKE '%permission denied%' AND t ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ---------- R setup: create pending requests inside the transaction ----------
  INSERT INTO public.study_group_members (group_id, user_id, role, status)
    SELECT b, u, 'member', 'requested' FROM unnest(pool[9:13]) u;
  INSERT INTO public.study_group_members (group_id, user_id, role, status)
    VALUES (ab, pool[14], 'member', 'requested');
  SELECT array_agg(id) INTO ids_a    FROM public.study_group_members WHERE group_id = b  AND user_id = ANY (pool[9:11]);
  SELECT array_agg(id) INTO ids_b    FROM public.study_group_members WHERE group_id = b  AND user_id = ANY (pool[12:13]);
  SELECT array_agg(id) INTO ids_arch FROM public.study_group_members WHERE group_id = ab AND user_id = pool[14];

  -- ---------- R1 / R2 ----------
  SELECT count(*) INTO n0 FROM public.notifications WHERE type = 'batch_approved' AND user_id = ANY (pool[9:11]);
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'bulk_approve_batch_requests' AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_resolve_batch_requests('approve', ids_a);
    RESET ROLE;
    SELECT count(*) INTO n1 FROM public.notifications WHERE type = 'batch_approved' AND user_id = ANY (pool[9:11]);
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'bulk_approve_batch_requests' AND admin_id = shailaja;
    SELECT count(*) INTO c FROM public.study_group_members WHERE id = ANY (ids_a) AND status = 'active';
    v_res := v_res || ('R1 bulk approve 3 pending requests|3 processed, 3 active, +3 notifications, +1 audit|' || (r->>'processed') || ' processed, ' || c || ' active, +' || (n1 - n0) || ', +' || (a1 - a0) || '|' ||
             CASE WHEN (r->>'processed')::int = 3 AND c = 3 AND n1 - n0 = 3 AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R1 bulk approve 3 pending requests|3 processed|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_resolve_batch_requests('approve', ids_a);
    RESET ROLE;
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'bulk_approve_batch_requests' AND admin_id = shailaja;
    v_res := v_res || ('R2 approving the same ids again is a truthful no-op|0 processed, 3 skipped_resolved, no new audit|' || (r->>'processed') || ' processed, ' || (r->>'skipped_resolved') || ' resolved / audit ' || a0 || ' (was ' || a1 || ')|' ||
             CASE WHEN (r->>'processed')::int = 0 AND (r->>'skipped_resolved')::int = 3 AND a0 = a1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R2 approving the same ids again|0 processed|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- R3 bulk reject ----------
  SELECT count(*) INTO n0 FROM public.notifications WHERE user_id = ANY (pool[12:13]) AND type IN ('batch_approved', 'batch_added');
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'bulk_reject_batch_requests' AND admin_id = shailaja;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_resolve_batch_requests('reject', ids_b);
    RESET ROLE;
    SELECT count(*) INTO n1 FROM public.notifications WHERE user_id = ANY (pool[12:13]) AND type IN ('batch_approved', 'batch_added');
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'bulk_reject_batch_requests' AND admin_id = shailaja;
    SELECT count(*) INTO c FROM public.study_group_members WHERE id = ANY (ids_b);
    v_res := v_res || ('R3 bulk reject 2 pending requests|2 processed, rows removed, no notification, +1 audit|' || (r->>'processed') || ' processed, ' || c || ' rows left, notif +' || (n1 - n0) || ', audit +' || (a1 - a0) || '|' ||
             CASE WHEN (r->>'processed')::int = 2 AND c = 0 AND n1 = n0 AND a1 - a0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R3 bulk reject 2 pending requests|2 processed|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- R4 request in an archived batch ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.admin_bulk_resolve_batch_requests('approve', ids_arch);
    RESET ROLE;
    SELECT count(*) INTO c FROM public.study_group_members WHERE id = ANY (ids_arch) AND status = 'requested';
    v_res := v_res || ('R4 a request in an archived batch is skipped and stays pending|0 processed, 1 skipped_archived, still requested|' || (r->>'processed') || ' processed, ' || (r->>'skipped_archived') || ' archived, ' || c || ' still requested|' ||
             CASE WHEN (r->>'processed')::int = 0 AND (r->>'skipped_archived')::int = 1 AND c = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R4 a request in an archived batch is skipped|1 skipped_archived|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- R5 student / R6 invalid action ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_bulk_resolve_batch_requests('approve', ids_arch);
    RESET ROLE;
    v_res := v_res || 'R5 a student cannot resolve requests [CRITICAL]|not_admin|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R5 a student cannot resolve requests [CRITICAL]|not_admin|' || left(v_err, 50) || '|' ||
             CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_bulk_resolve_batch_requests('delete', ids_arch);
    RESET ROLE;
    v_res := v_res || 'R6 invalid action refused|Invalid action|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R6 invalid action refused|Invalid action|' || left(v_err, 50) || '|' || CASE WHEN v_err ILIKE '%Invalid action%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- ---------- S1 single approve audits + notifies ----------
  INSERT INTO public.study_group_members (group_id, user_id, role, status) VALUES (b, pool[7], 'member', 'requested');
  SELECT id INTO s1_membership FROM public.study_group_members WHERE group_id = b AND user_id = pool[7];   -- look it up BEFORE switching role (RLS hides it from the client role)
  SELECT count(*) INTO n0 FROM public.notifications WHERE type = 'batch_approved' AND user_id = pool[7];
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'approve_batch_join_request' AND target_user_id = pool[7];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.approve_batch_join_request(s1_membership);
    RESET ROLE;
    SELECT count(*) INTO n1 FROM public.notifications WHERE type = 'batch_approved' AND user_id = pool[7];
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'approve_batch_join_request' AND target_user_id = pool[7];
    v_res := v_res || ('S1 single approve now audits and notifies|+1 audit, +1 notification|+' || (a1 - a0) || ', +' || (n1 - n0) || '|' ||
             CASE WHEN a1 - a0 = 1 AND n1 - n0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S1 single approve now audits and notifies|+1 / +1|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- S2 single enroll: once, then untouched ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.enroll_user_in_batch_group(pool[8], b);
    RESET ROLE;
    SELECT joined_at INTO j0 FROM public.study_group_members WHERE group_id = b AND user_id = pool[8];
    SELECT count(*) INTO n0 FROM public.notifications WHERE type = 'batch_added' AND user_id = pool[8];
    SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'add_to_batch' AND target_user_id = pool[8];
    PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.enroll_user_in_batch_group(pool[8], b);
    RESET ROLE;
    SELECT joined_at INTO j1 FROM public.study_group_members WHERE group_id = b AND user_id = pool[8];
    SELECT count(*) INTO n1 FROM public.notifications WHERE type = 'batch_added' AND user_id = pool[8];
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'add_to_batch' AND target_user_id = pool[8];
    v_res := v_res || ('S2 single add: one notification + one audit, second call changes nothing|1 / 1, then unchanged, joined_at kept|' || n0 || ' / ' || a0 || ', then ' || n1 || ' / ' || a1 || ', joined_at ' || CASE WHEN j0 = j1 THEN 'kept' ELSE 'CHANGED' END || '|' ||
             CASE WHEN n0 = 1 AND a0 = 1 AND n1 = 1 AND a1 = 1 AND j0 = j1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S2 single add: one notification + one audit|1 / 1|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- ---------- T1 helper not executable by clients ----------
  PERFORM set_config('request.jwt.claims', json_build_object('sub', shailaja, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_batch_action_denial(shailaja, b);
    RESET ROLE; s := 'no error';
  EXCEPTION WHEN OTHERS THEN s := SQLERRM; RESET ROLE; END;
  v_res := v_res || ('T1 no client role can execute the internal helper|permission denied|' || left(s, 40) || '|' ||
           CASE WHEN s ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t02b5_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t02b5_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
