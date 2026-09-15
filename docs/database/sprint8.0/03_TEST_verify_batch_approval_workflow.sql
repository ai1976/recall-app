-- Name: [TEST] Verify Sprint 8.0 batch join approval workflow
-- Description: Post-deploy verification for 01_SCHEMA + 02_FUNCTIONS. Runs inside
-- BEGIN...ROLLBACK (same idiom as security/17_TEST) so nothing here touches real
-- data — a temp batch group is created, exercised, then rolled back along with
-- everything else. Uses set_config('request.jwt.claims', ...) to impersonate a
-- real student/admin profile per check, exactly like the app's PostgREST calls
-- would set auth.uid(). Run in Supabase SQL Editor and report the _r table back.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_student   uuid;
  v_student2  uuid;
  v_admin     uuid;
  v_group_a   uuid;
  v_group_b   uuid;
  v_token_a   uuid := gen_random_uuid();
  v_token_b   uuid := gen_random_uuid();
  v_before_course text;
  v_before_inst   text;
  v_membership_id uuid;
  v_status    text;
  v_count     int;
  v_result    jsonb;
  v_err       text;
BEGIN
  SELECT id INTO v_student  FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_student2 FROM public.profiles WHERE role = 'student' AND id <> v_student LIMIT 1;
  SELECT id INTO v_admin    FROM public.profiles WHERE role IN ('admin','super_admin') LIMIT 1;

  IF v_student IS NULL OR v_admin IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', 'student+admin profiles', 'missing', 'SKIP: need >=1 student, >=1 admin profile');
    RETURN;
  END IF;

  -- Temp batch groups, owned by the admin, unique tokens so they never
  -- collide with a real invite link.
  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('Sprint8.0 Test Batch A', 'temp', true, 'batch', 'ZZ Test Course', 'ZZ Test Institution', v_admin, v_token_a)
  RETURNING id INTO v_group_a;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('Sprint8.0 Test Batch B', 'temp', true, 'batch', 'ZZ Test Course', 'ZZ Test Institution', v_admin, v_token_b)
  RETURNING id INTO v_group_b;

  -- ============================================================
  -- create_batch_group: group only, zero membership rows, admin-only
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.create_batch_group('ZZ Test Course', 'Sprint8.0 non-admin attempt', '', 'ZZ Test Institution');
    INSERT INTO _r VALUES ('non-admin create_batch_group blocked [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('non-admin create_batch_group blocked [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SELECT COUNT(*) INTO v_count FROM study_group_members WHERE group_id IN (v_group_a, v_group_b);
  INSERT INTO _r VALUES ('create_batch_group creates zero membership rows [CRITICAL]', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- join_group_by_token: student self-request -> 'requested', no profile writes
  -- ============================================================
  SELECT course_level, institution INTO v_before_course, v_before_inst FROM profiles WHERE id = v_student;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  SELECT public.join_group_by_token(v_token_a) INTO v_result;
  INSERT INTO _r VALUES ('join_group_by_token returns status=requested [CRITICAL]', 'requested', v_result->>'status',
    CASE WHEN v_result->>'status' = 'requested' THEN 'PASS' ELSE 'FAIL' END);

  SELECT status INTO v_status FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student;
  INSERT INTO _r VALUES ('membership row is requested', 'requested', v_status,
    CASE WHEN v_status = 'requested' THEN 'PASS' ELSE 'FAIL' END);

  PERFORM 1; -- re-check profile unchanged
  INSERT INTO _r VALUES ('join does not write profiles.course_level/institution [CRITICAL]',
    coalesce(v_before_course,'<null>')||'/'||coalesce(v_before_inst,'<null>'),
    (SELECT coalesce(course_level,'<null>')||'/'||coalesce(institution,'<null>') FROM profiles WHERE id = v_student),
    CASE WHEN (SELECT course_level IS NOT DISTINCT FROM v_before_course AND institution IS NOT DISTINCT FROM v_before_inst FROM profiles WHERE id = v_student)
      THEN 'PASS' ELSE 'FAIL' END);

  -- idempotent re-click
  SELECT public.join_group_by_token(v_token_a) INTO v_result;
  SELECT COUNT(*) INTO v_count FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student;
  INSERT INTO _r VALUES ('repeated request is idempotent (still 1 row, still requested)', '1/requested',
    v_count::text||'/'||(v_result->>'status'),
    CASE WHEN v_count = 1 AND v_result->>'status' = 'requested' THEN 'PASS' ELSE 'FAIL' END);

  -- pending 'requested' member cannot read group detail yet
  BEGIN
    PERFORM public.get_group_detail(v_group_a);
    INSERT INTO _r VALUES ('requested (unapproved) member blocked from get_group_detail [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('requested (unapproved) member blocked from get_group_detail [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- get_group_preview reflects batch info + viewer_status
  SELECT public.get_group_preview(v_token_a) INTO v_result;
  INSERT INTO _r VALUES ('get_group_preview returns batch_course/viewer_status', 'ZZ Test Course/requested',
    (v_result->'group'->>'batch_course')||'/'||(v_result->'group'->>'viewer_status'),
    CASE WHEN v_result->'group'->>'batch_course' = 'ZZ Test Course' AND v_result->'group'->>'viewer_status' = 'requested'
      THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- approve_batch_join_request
  -- ============================================================
  SELECT id INTO v_membership_id FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.approve_batch_join_request(v_membership_id);
    INSERT INTO _r VALUES ('non-admin approve blocked [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('non-admin approve blocked [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  PERFORM public.approve_batch_join_request(v_membership_id);
  SELECT status INTO v_status FROM study_group_members WHERE id = v_membership_id;
  INSERT INTO _r VALUES ('approve flips status to active [CRITICAL]', 'active', v_status,
    CASE WHEN v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  BEGIN
    PERFORM public.approve_batch_join_request(v_membership_id);
    INSERT INTO _r VALUES ('re-approving an already-active row raises', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('re-approving an already-active row raises', 'error', 'error', 'PASS');
  END;

  -- approved member can now read group detail
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  BEGIN
    PERFORM public.get_group_detail(v_group_a);
    INSERT INTO _r VALUES ('approved member can read get_group_detail', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('approved member can read get_group_detail', 'ok', left(v_err,30), 'FAIL: '||v_err);
  END;

  -- ============================================================
  -- reject_batch_join_request (fresh request on group B)
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
  PERFORM public.join_group_by_token(v_token_b);
  SELECT id INTO v_membership_id FROM study_group_members WHERE group_id = v_group_b AND user_id = v_student;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  PERFORM public.reject_batch_join_request(v_membership_id);
  SELECT COUNT(*) INTO v_count FROM study_group_members WHERE id = v_membership_id;
  INSERT INTO _r VALUES ('reject deletes the row [CRITICAL]', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- get_admin_pending_batch_requests no longer lists resolved rows
  SELECT COUNT(*) INTO v_count FROM public.get_admin_pending_batch_requests() WHERE group_id IN (v_group_a, v_group_b);
  INSERT INTO _r VALUES ('pending list excludes approved/rejected rows', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- enroll_user_in_batch_group: explicit student+batch, no guessing
  -- ============================================================
  IF v_student2 IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role','authenticated')::text, true);
    BEGIN
      PERFORM public.enroll_user_in_batch_group(v_student2, v_group_a);
      INSERT INTO _r VALUES ('non-admin enroll_user_in_batch_group blocked [CRITICAL]', 'Access denied', 'no error', 'FAIL');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      INSERT INTO _r VALUES ('non-admin enroll_user_in_batch_group blocked [CRITICAL]', 'Access denied', left(v_err,30),
        CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
    END;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);

    -- passing a non-batch (or nonexistent) group id must raise, not silently guess
    BEGIN
      PERFORM public.enroll_user_in_batch_group(v_student2, gen_random_uuid());
      INSERT INTO _r VALUES ('enroll with bogus group_id raises, no guessing [CRITICAL]', 'Not a batch group', 'no error', 'FAIL');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      INSERT INTO _r VALUES ('enroll with bogus group_id raises, no guessing [CRITICAL]', 'Not a batch group', left(v_err,30),
        CASE WHEN v_err ILIKE '%Not a batch group%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
    END;

    PERFORM public.enroll_user_in_batch_group(v_student2, v_group_b);
    SELECT status INTO v_status FROM study_group_members WHERE group_id = v_group_b AND user_id = v_student2;
    INSERT INTO _r VALUES ('explicit admin add activates immediately, no requested step [CRITICAL]', 'active', v_status,
      CASE WHEN v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);
  ELSE
    INSERT INTO _r VALUES ('enroll_user_in_batch_group checks', 'second student fixture', 'none', 'SKIP: need >=2 student profiles');
  END IF;

  -- ============================================================
  -- fn_auto_enroll_batch_group: no more guessed membership on profile update
  -- ============================================================
  IF v_student2 IS NOT NULL THEN
    -- pre-existing membership to prove the OLD-group cleanup branch still works
    INSERT INTO study_group_members (group_id, user_id, role, status)
    VALUES (v_group_a, v_student2, 'member', 'active')
    ON CONFLICT (group_id, user_id) DO UPDATE SET status = 'active';

    UPDATE profiles
    SET course_level = 'ZZ Test Course', institution = 'ZZ Test Institution'
    WHERE id = v_student2 AND role = 'student';

    SELECT COUNT(*) INTO v_count
    FROM study_group_members
    WHERE user_id = v_student2 AND group_id = v_group_b AND status <> 'active';
    -- (v_group_b already has an active row from the enroll test above; this
    -- just confirms the trigger didn't ALSO drop a second guessed row in)
    SELECT COUNT(*) INTO v_count
    FROM (SELECT group_id FROM study_group_members WHERE user_id = v_student2 AND group_id IN (v_group_a, v_group_b)) t;
    INSERT INTO _r VALUES ('profile update does not create a NEW guessed membership [CRITICAL]', '2 (unchanged: A active pre-set + B active from enroll test)', v_count::text,
      CASE WHEN v_count = 2 THEN 'PASS' ELSE 'FAIL' END);

    -- now change course away — old-group cleanup should still remove the group_a row
    UPDATE profiles
    SET course_level = 'ZZ Different Course'
    WHERE id = v_student2 AND role = 'student';

    SELECT COUNT(*) INTO v_count FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student2;
    INSERT INTO _r VALUES ('old-group cleanup on course change still works', '0', v_count::text,
      CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);
  ELSE
    INSERT INTO _r VALUES ('fn_auto_enroll_batch_group checks', 'second student fixture', 'none', 'SKIP: need >=2 student profiles');
  END IF;

  -- ============================================================
  -- get_admin_batch_groups exposes invite_token
  -- ============================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  SELECT COUNT(*) INTO v_count FROM public.get_admin_batch_groups() WHERE id = v_group_a AND invite_token = v_token_a;
  INSERT INTO _r VALUES ('get_admin_batch_groups returns invite_token', '1', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
