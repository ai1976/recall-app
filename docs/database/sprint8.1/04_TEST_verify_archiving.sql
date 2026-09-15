-- Name: [TEST] Verify Sprint 8.1 batch group archiving
-- Description: Post-deploy verification for 01_SCHEMA + 02_FUNCTIONS +
-- 03_FUNCTIONS. Runs inside BEGIN...ROLLBACK (same idiom as sprint8.0's
-- 03_TEST) so nothing here touches real data. Uses set_config('request.jwt.claims', ...)
-- to impersonate a real student/professor/admin profile per check, matching
-- how auth.uid() is populated for SECURITY DEFINER functions in production.
-- Three checks additionally need `SET ROLE authenticated` (noted inline) to
-- actually exercise RLS — the Supabase SQL Editor runs as the postgres
-- superuser by default, which bypasses RLS regardless of jwt.claims, so
-- setting jwt.claims alone is enough for function-level auth checks
-- (is_admin()/auth.uid() reads) but NOT for RLS policy checks. Not covered
-- here (need a live browser session or two concurrent SQL Editor tabs):
-- concurrent archive-vs-enrollment races (see 05_TEST_concurrency.sql) and
-- anything requiring real review/study_sessions activity data. Run in
-- Supabase SQL Editor and report the _r table back.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_student    uuid;
  v_student2   uuid;
  v_professor  uuid;
  v_admin      uuid;
  v_group_a    uuid;
  v_ordinary   uuid;
  v_token_a    uuid := gen_random_uuid();
  v_token_ord  uuid := gen_random_uuid();
  v_req_id     uuid;
  v_result     jsonb;
  v_archived_at1 timestamptz;
  v_archived_at2 timestamptz;
  v_first_archived_at timestamptz; -- dedicated, never reused as scratch (see re-archive check below)
  v_status     text;
  v_count      int;
  v_err        text;
BEGIN
  SELECT id INTO v_student    FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_student2   FROM public.profiles WHERE role = 'student' AND id <> v_student LIMIT 1;
  SELECT id INTO v_professor  FROM public.profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin      FROM public.profiles WHERE role IN ('admin','super_admin') LIMIT 1;

  IF v_student IS NULL OR v_student2 IS NULL OR v_admin IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '>=2 students, >=1 admin', 'missing', 'SKIP: insufficient profile fixtures');
    RETURN;
  END IF;

  -- One temp batch group + one ordinary group, unique tokens.
  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('Sprint8.1 Test Batch A', 'temp', true, 'batch', 'ZZ Test Course', 'ZZ Test Institution', v_admin, v_token_a)
  RETURNING id INTO v_group_a;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, created_by, invite_token)
  VALUES ('Sprint8.1 Test Ordinary', 'temp', false, 'custom', v_student, v_token_ord)
  RETURNING id INTO v_ordinary;

  -- Fixture memberships on Batch A: student=active, student2=requested,
  -- ordinary group: student=active (sole member, for the leave_group check).
  INSERT INTO study_group_members (group_id, user_id, role, status) VALUES (v_group_a, v_student, 'member', 'active');
  INSERT INTO study_group_members (group_id, user_id, role, status) VALUES (v_group_a, v_student2, 'member', 'requested');
  INSERT INTO study_group_members (group_id, user_id, role, status) VALUES (v_ordinary, v_student, 'admin', 'active');

  -- ============================================================
  -- archive_batch_group: authorization
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.archive_batch_group(v_group_a);
    INSERT INTO _r VALUES ('non-admin archive_batch_group blocked [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('non-admin archive_batch_group blocked [CRITICAL]', 'Access denied', left(v_err,40),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  IF v_professor IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_professor, 'role','authenticated')::text, true);
    BEGIN
      PERFORM public.archive_batch_group(v_group_a);
      INSERT INTO _r VALUES ('professor archive_batch_group blocked [CRITICAL]', 'Access denied', 'no error', 'FAIL');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      INSERT INTO _r VALUES ('professor archive_batch_group blocked [CRITICAL]', 'Access denied', left(v_err,40),
        CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
    END;
  END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.archive_batch_group(v_ordinary);
    INSERT INTO _r VALUES ('archive_batch_group on non-batch group rejected [CRITICAL]', 'Not a batch group', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('archive_batch_group on non-batch group rejected [CRITICAL]', 'Not a batch group', left(v_err,40),
      CASE WHEN v_err ILIKE '%Not a batch group%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  BEGIN
    PERFORM public.archive_batch_group(gen_random_uuid());
    INSERT INTO _r VALUES ('archive_batch_group on missing group rejected', 'Group not found', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('archive_batch_group on missing group rejected', 'Group not found', left(v_err,40),
      CASE WHEN v_err ILIKE '%Group not found%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ============================================================
  -- archive_batch_group: first call — snapshot, close outstanding requests,
  -- preserve active memberships
  -- ============================================================
  SELECT public.archive_batch_group(v_group_a) INTO v_result;
  v_archived_at1 := (v_result->>'archived_at')::timestamptz;
  INSERT INTO _r VALUES ('first archive: already_archived=false', 'false', v_result->>'already_archived',
    CASE WHEN (v_result->>'already_archived') = 'false' THEN 'PASS' ELSE 'FAIL' END);

  SELECT archived_at INTO v_archived_at1 FROM study_groups WHERE id = v_group_a;
  v_first_archived_at := v_archived_at1; -- captured once, never reassigned — v_archived_at1 itself is reused as scratch further down
  INSERT INTO _r VALUES ('study_groups.archived_at set [CRITICAL]', 'not null', COALESCE(v_archived_at1::text,'null'),
    CASE WHEN v_archived_at1 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_count FROM batch_group_archives WHERE group_id = v_group_a AND archived_at = v_archived_at1;
  INSERT INTO _r VALUES ('snapshot row created (same tx, matching timestamp) [CRITICAL]', '1', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT status INTO v_status FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student;
  INSERT INTO _r VALUES ('approved (active) membership untouched by archive [CRITICAL]', 'active', v_status,
    CASE WHEN v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  SELECT status INTO v_status FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student2;
  INSERT INTO _r VALUES ('outstanding requested row closed, not deleted [CRITICAL]', 'closed', v_status,
    CASE WHEN v_status = 'closed' THEN 'PASS' ELSE 'FAIL' END);

  SELECT closed_reason INTO v_err FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student2;
  INSERT INTO _r VALUES ('closed row has closure reason recorded', 'batch_archived', v_err,
    CASE WHEN v_err = 'batch_archived' THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- archive_batch_group: idempotent second call
  -- ============================================================
  SELECT public.archive_batch_group(v_group_a) INTO v_result;
  INSERT INTO _r VALUES ('repeat archive: already_archived=true [CRITICAL]', 'true', v_result->>'already_archived',
    CASE WHEN (v_result->>'already_archived') = 'true' THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('repeat archive: timestamp unchanged [CRITICAL]', v_first_archived_at::text, v_result->>'archived_at',
    CASE WHEN (v_result->>'archived_at')::timestamptz = v_first_archived_at THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_count FROM batch_group_archives WHERE group_id = v_group_a;
  INSERT INTO _r VALUES ('repeat archive: no duplicate snapshot [CRITICAL]', '1', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- Enrollment paths refuse an archived batch
  -- ============================================================
  BEGIN
    PERFORM public.enroll_user_in_batch_group(v_student2, v_group_a);
    INSERT INTO _r VALUES ('direct-add refused on archived batch [CRITICAL]', 'archived error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('direct-add refused on archived batch [CRITICAL]', 'archived error', left(v_err,40),
      CASE WHEN v_err ILIKE '%archived%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student2, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.join_group_by_token(v_token_a);
    INSERT INTO _r VALUES ('join_group_by_token refused on archived batch [CRITICAL]', 'This batch has ended', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('join_group_by_token refused on archived batch [CRITICAL]', 'This batch has ended', left(v_err,40),
      CASE WHEN v_err ILIKE '%This batch has ended%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  SELECT (public.get_group_preview(v_token_a)->'group'->>'archived_at') INTO v_err;
  INSERT INTO _r VALUES ('get_group_preview surfaces archived_at', 'not null', COALESCE(v_err,'null'),
    CASE WHEN v_err IS NOT NULL THEN 'PASS' ELSE 'FAIL' END);
  -- get_group_preview builds 'stats' via jsonb_build_object(..., NULL), which
  -- stores a JSON null, not the absence of the key — so -> returns the jsonb
  -- scalar null, which casts to the 4-char text 'null' here, never actual SQL
  -- NULL. Compare against that string, not IS NULL.
  SELECT (public.get_group_preview(v_token_a)->'stats') INTO v_err;
  INSERT INTO _r VALUES ('get_group_preview suppresses stats when archived [CRITICAL]', 'null', COALESCE(v_err,'null'),
    CASE WHEN v_err IS NULL OR v_err = 'null' THEN 'PASS' ELSE 'FAIL' END);

  -- approve_batch_join_request locks the group and checks archived_at BEFORE
  -- the status-based "already resolved" fallback, so an archived group's
  -- explicit message wins here (not a bug — more informative than the
  -- generic fallback, which would only fire for e.g. a request already
  -- approved/rejected on a still-active batch).
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SELECT id INTO v_req_id FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student2;
  BEGIN
    PERFORM public.approve_batch_join_request(v_req_id);
    INSERT INTO _r VALUES ('approve refused on closed/archived request [CRITICAL]', 'This batch has been archived', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('approve refused on closed/archived request [CRITICAL]', 'This batch has been archived', left(v_err,40),
      CASE WHEN v_err ILIKE '%archived%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ============================================================
  -- RLS bypass checks — need SET ROLE authenticated, since the SQL Editor's
  -- postgres session otherwise bypasses RLS entirely regardless of jwt.claims.
  -- IMPORTANT: RESET ROLE before every INSERT INTO _r below — the temp table
  -- was created by the session's original (postgres) role, so 'authenticated'
  -- has no grant on it and any _r write attempted while role-switched fails
  -- with 42501. Do the RLS-gated action, capture its result into a variable,
  -- RESET ROLE, then log.
  -- ============================================================
  -- Ground-truth existence check must happen AFTER RESET ROLE (bypassing
  -- RLS) — v_admin is not a member of v_group_a's study_group_members, so
  -- sg_select_member makes the row invisible to 'authenticated' regardless
  -- of whether the DELETE actually succeeded. Checking COUNT(*) while still
  -- role-switched answers "can this role see the row," not "did the delete
  -- work" — those are different questions, and conflating them was the bug.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  DELETE FROM study_groups WHERE id = v_group_a;
  RESET ROLE;
  SELECT COUNT(*) INTO v_count FROM study_groups WHERE id = v_group_a;
  INSERT INTO _r VALUES ('RLS blocks direct client DELETE of archived batch (as creator/admin) [CRITICAL]', '1 (still exists)', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  UPDATE study_groups SET archived_at = NULL WHERE id = v_group_a;
  RESET ROLE;
  SELECT archived_at INTO v_archived_at1 FROM study_groups WHERE id = v_group_a;
  INSERT INTO _r VALUES ('RLS blocks direct client UPDATE of archived_at [CRITICAL]', 'still archived (not null)', COALESCE(v_archived_at1::text,'null'),
    CASE WHEN v_archived_at1 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- leave_group: batch group survives its last active member leaving;
  -- ordinary group behavior unchanged (still deletes).
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  PERFORM public.leave_group(v_group_a);
  SELECT COUNT(*) INTO v_count FROM study_groups WHERE id = v_group_a;
  INSERT INTO _r VALUES ('leave_group: batch group NOT deleted when last member leaves [CRITICAL]', '1 (still exists)', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM public.leave_group(v_ordinary);
  SELECT COUNT(*) INTO v_count FROM study_groups WHERE id = v_ordinary;
  INSERT INTO _r VALUES ('leave_group: ordinary group still deleted when last member leaves (unchanged)', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);
  v_ordinary := NULL; -- already deleted, avoid confusing later cleanup

  -- ============================================================
  -- restore_batch_group
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SELECT public.restore_batch_group(v_group_a) INTO v_result;
  INSERT INTO _r VALUES ('restore: already_active=false [CRITICAL]', 'false', v_result->>'already_active',
    CASE WHEN (v_result->>'already_active') = 'false' THEN 'PASS' ELSE 'FAIL' END);

  SELECT archived_at INTO v_archived_at1 FROM study_groups WHERE id = v_group_a;
  INSERT INTO _r VALUES ('restore: archived_at cleared [CRITICAL]', 'null', COALESCE(v_archived_at1::text,'null'),
    CASE WHEN v_archived_at1 IS NULL THEN 'PASS' ELSE 'FAIL' END);

  SELECT status INTO v_status FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student2;
  INSERT INTO _r VALUES ('restore: closed request NOT auto-revived [CRITICAL]', 'closed', v_status,
    CASE WHEN v_status = 'closed' THEN 'PASS' ELSE 'FAIL' END);

  SELECT public.restore_batch_group(v_group_a) INTO v_result;
  INSERT INTO _r VALUES ('repeat restore: already_active=true (idempotent)', 'true', v_result->>'already_active',
    CASE WHEN (v_result->>'already_active') = 'true' THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- Explicit re-request after restore reactivates the closed row
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student2, 'role','authenticated')::text, true);
  SELECT public.join_group_by_token(v_token_a) INTO v_result;
  INSERT INTO _r VALUES ('re-request after restore reactivates closed row [CRITICAL]', 'requested', v_result->>'status',
    CASE WHEN v_result->>'status' = 'requested' THEN 'PASS' ELSE 'FAIL' END);

  SELECT closed_reason INTO v_err FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student2;
  INSERT INTO _r VALUES ('re-request preserves prior closure history', 'batch_archived', v_err,
    CASE WHEN v_err = 'batch_archived' THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- Re-archive: new snapshot, earlier snapshot retained
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SELECT public.archive_batch_group(v_group_a) INTO v_result;
  v_archived_at2 := (v_result->>'archived_at')::timestamptz;
  INSERT INTO _r VALUES ('re-archive produces a new (different) timestamp [CRITICAL]', 'different from first ('||v_first_archived_at::text||')', v_archived_at2::text,
    CASE WHEN v_archived_at2 IS DISTINCT FROM v_first_archived_at THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_count FROM batch_group_archives WHERE group_id = v_group_a;
  INSERT INTO _r VALUES ('earlier snapshot retained after restore+re-archive [CRITICAL]', '2', v_count::text,
    CASE WHEN v_count = 2 THEN 'PASS' ELSE 'FAIL' END);

  SELECT (public.get_batch_group_archive(v_group_a)->>'archived_at') INTO v_err;
  INSERT INTO _r VALUES ('get_batch_group_archive returns the LATEST snapshot', v_archived_at2::text, v_err,
    CASE WHEN v_err::timestamptz = v_archived_at2 THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- get_batch_group_archive: same authorized-viewer gate as get_batch_group_member_stats
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.get_batch_group_archive(v_group_a);
    INSERT INTO _r VALUES ('student cannot read archive snapshot [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('student cannot read archive snapshot [CRITICAL]', 'Access denied', left(v_err,40),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ============================================================
  -- Listing surfaces
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SELECT COUNT(*) INTO v_count FROM public.get_admin_batch_groups() WHERE id = v_group_a AND archived_at IS NOT NULL;
  INSERT INTO _r VALUES ('get_admin_batch_groups exposes archived_at for archived batch', '1', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_count FROM public.get_my_batch_groups() WHERE id = v_group_a;
  INSERT INTO _r VALUES ('get_my_batch_groups excludes archived batch from monitoring list [CRITICAL]', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
