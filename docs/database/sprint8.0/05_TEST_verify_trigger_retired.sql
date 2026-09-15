-- Name: [TEST] Verify fn_auto_enroll_batch_group is fully retired
-- Description: Post-deploy verification for 04_SCHEMA_retire_auto_enroll_trigger.sql.
-- Confirms the trigger/function are gone, AND — the actual behavior change —
-- that a student's course-level change no longer removes them from an
-- existing active batch membership. Same BEGIN...ROLLBACK idiom as 03_TEST.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

-- 1. Trigger and function are both gone.
DO $$
DECLARE v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.triggers
  WHERE trigger_schema = 'public' AND trigger_name = 'trg_auto_enroll_batch_group';
  INSERT INTO _r VALUES ('trg_auto_enroll_batch_group no longer exists [CRITICAL]', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fn_auto_enroll_batch_group';
  INSERT INTO _r VALUES ('fn_auto_enroll_batch_group no longer exists [CRITICAL]', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- 2. A course-level change no longer removes an existing active batch membership.
DO $$
DECLARE
  v_student uuid;
  v_admin   uuid;
  v_group_a uuid;
  v_token_a uuid := gen_random_uuid();
  v_before_status text;
  v_after_status  text;
BEGIN
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_admin   FROM public.profiles WHERE role IN ('admin','super_admin') LIMIT 1;

  IF v_student IS NULL OR v_admin IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', 'student+admin profiles', 'missing', 'SKIP: need >=1 student, >=1 admin profile');
    RETURN;
  END IF;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('Sprint8.0 Retire-Trigger Test Batch', 'temp', true, 'batch', 'ZZ Retire Course', 'ZZ Retire Institution', v_admin, v_token_a)
  RETURNING id INTO v_group_a;

  -- Give the student an existing active membership in this batch.
  INSERT INTO study_group_members (group_id, user_id, role, status)
  VALUES (v_group_a, v_student, 'member', 'active')
  ON CONFLICT (group_id, user_id) DO UPDATE SET status = 'active';

  SELECT status INTO v_before_status FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student;

  -- Change the student's course level — previously this triggered cleanup
  -- that would have removed them from an "old matched" batch group.
  UPDATE profiles
  SET course_level = 'ZZ Some Entirely Different Course'
  WHERE id = v_student AND role = 'student';

  SELECT status INTO v_after_status FROM study_group_members WHERE group_id = v_group_a AND user_id = v_student;

  INSERT INTO _r VALUES ('course change no longer removes existing batch membership [CRITICAL]',
    'active (unchanged)', COALESCE(v_after_status, '<row deleted>'),
    CASE WHEN v_after_status = 'active' THEN 'PASS' ELSE 'FAIL' END);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
