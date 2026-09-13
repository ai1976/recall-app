-- Name: [TEST] Verify Sprint 7.7 question types — CHECK constraint widened, D-10 gate unchanged
--
-- Description: Run AFTER 01_SCHEMA_add_test_your_understanding_type.sql. Confirms:
--   (1) test_your_understanding is now insertable (the whole point of 01_SCHEMA),
--   (2) theory was already insertable and still is (constraint widening didn't regress it),
--   (3) a STUDENT can insert both free-recall types unrestricted (D-10 must not have
--       accidentally started gating them),
--   (4) a STUDENT's true_false / correct_incorrect insert is still REJECTED — this is a
--       regression check, not new coverage: 01_SCHEMA touches only the CHECK constraint,
--       never the D-10 RESTRICTIVE policy, so these two types were ALREADY gated before
--       this sprint (confirmed live in docs/database/sprint7.5/02_TEST's true_false
--       assertion) and must still be after. If this FAILs, something in this sprint
--       touched RLS it shouldn't have.
--   (5) a PROFESSOR's true_false / correct_incorrect insert still succeeds.
--
-- Self-contained and non-destructive: everything happens inside one BEGIN/ROLLBACK,
-- same impersonation technique as docs/database/sprint7.5/02_TEST_verify_d10_role_gate.sql.

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
GRANT SELECT, INSERT ON _r TO authenticated;

CREATE TEMP TABLE _fixture(role_label text PRIMARY KEY, id uuid);
GRANT SELECT ON _fixture TO authenticated;
INSERT INTO _fixture SELECT 'student', id FROM public.profiles WHERE role = 'student' ORDER BY created_at LIMIT 1;
INSERT INTO _fixture SELECT 'professor', id FROM public.profiles WHERE role = 'professor' ORDER BY created_at LIMIT 1;

-- ============================================
-- ACTOR: STUDENT
-- ============================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'student'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_err text; v_uid uuid; v_course text;
BEGIN
  v_uid := (SELECT id FROM _fixture WHERE role_label = 'student');
  IF v_uid IS NULL THEN
    INSERT INTO _r VALUES ('student fixture', 'a student profile', 'none found', 'SKIP: need at least one profiles row with role=''student''');
    RETURN;
  END IF;
  SELECT target_course INTO v_course FROM public.flashcards LIMIT 1;

  -- (1) test_your_understanding must now succeed for a student (free-recall, ungated)
  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_S77TEST_student_tyu', 'A',
      'private', false, 'medium', gen_random_uuid(), 'test_your_understanding'
    );
    INSERT INTO _r VALUES ('student test_your_understanding insert [CRITICAL]', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student test_your_understanding insert [CRITICAL]', 'succeeds', left(v_err, 80),
      'FAIL: 01_SCHEMA not applied, or applied incorrectly — ' || v_err);
  END;

  -- (2) theory must still succeed for a student (unaffected free-recall type)
  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_S77TEST_student_theory', 'A',
      'private', false, 'medium', gen_random_uuid(), 'theory'
    );
    INSERT INTO _r VALUES ('student theory insert unaffected', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student theory insert unaffected', 'succeeds', left(v_err, 80),
      'FAIL: constraint widening regressed an existing free-recall type — ' || v_err);
  END;

  -- (3) true_false must still be REJECTED for a student — regression check, D-10 already
  -- covered this before 7.7 (this sprint changes zero RLS).
  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_S77TEST_student_true_false', 'True',
      'private', false, 'medium', gen_random_uuid(), 'true_false', '["True","False"]'::jsonb, '0'
    );
    INSERT INTO _r VALUES ('student true_false insert [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: student was able to create a true_false row — D-10 regressed');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student true_false insert [CRITICAL]', 'rejected', left(v_err, 80),
      CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL (unexpected error): ' || v_err END);
  END;

  -- (4) correct_incorrect must still be REJECTED for a student — same regression check.
  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_S77TEST_student_correct_incorrect', 'Correct',
      'private', false, 'medium', gen_random_uuid(), 'correct_incorrect', '["Correct","Incorrect"]'::jsonb, '0'
    );
    INSERT INTO _r VALUES ('student correct_incorrect insert [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: student was able to create a correct_incorrect row — D-10 regressed');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student correct_incorrect insert [CRITICAL]', 'rejected', left(v_err, 80),
      CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL (unexpected error): ' || v_err END);
  END;
END $$;

RESET ROLE;

-- ============================================
-- ACTOR: PROFESSOR — true_false / correct_incorrect must SUCCEED
-- ============================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'professor'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_err text; v_uid uuid; v_course text;
BEGIN
  v_uid := (SELECT id FROM _fixture WHERE role_label = 'professor');
  IF v_uid IS NULL THEN
    INSERT INTO _r VALUES ('professor fixture', 'a professor profile', 'none found', 'SKIP: need at least one profiles row with role=''professor''');
    RETURN;
  END IF;
  SELECT target_course INTO v_course FROM public.flashcards LIMIT 1;

  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_S77TEST_professor_true_false', 'True',
      'private', false, 'medium', gen_random_uuid(), 'true_false', '["True","False"]'::jsonb, '0'
    );
    INSERT INTO _r VALUES ('professor true_false insert [CRITICAL]', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('professor true_false insert [CRITICAL]', 'succeeds', left(v_err, 80),
      'FAIL: D-10 blocked a professor — ' || v_err);
  END;

  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_S77TEST_professor_correct_incorrect', 'Correct',
      'private', false, 'medium', gen_random_uuid(), 'correct_incorrect', '["Correct","Incorrect"]'::jsonb, '0'
    );
    INSERT INTO _r VALUES ('professor correct_incorrect insert [CRITICAL]', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('professor correct_incorrect insert [CRITICAL]', 'succeeds', left(v_err, 80),
      'FAIL: D-10 blocked a professor — ' || v_err);
  END;
END $$;

RESET ROLE;

SELECT * FROM _r ORDER BY check_name;

ROLLBACK; -- nothing above survives — this is a read-safe, repeatable test
