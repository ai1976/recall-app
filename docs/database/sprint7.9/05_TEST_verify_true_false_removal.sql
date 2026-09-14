-- Name: [TEST] Verify Sprint 7.9 item 4 — true_false removal, D-10 regression
--
-- Description: Run immediately after 04_SCHEMA_true_false_removal.sql. Confirms:
--   1. true_false is no longer insertable (CHECK violation, applies regardless of role).
--   2. Every surviving type (8, was 9) still inserts cleanly.
--   3. Neither D-10 RESTRICTIVE policy mentions true_false any more.
--   4. D-10 regression: a real student's correct_incorrect insert is still rejected, a
--      real professor's still succeeds — the ALTER POLICY rewrote the whole WITH CHECK
--      expression, so this needs re-checking, not assuming (same discipline as
--      02_TEST's regression check after the integrated_case ALTER POLICY).
--
-- Self-contained and non-destructive: everything happens inside one BEGIN/ROLLBACK.

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
GRANT SELECT, INSERT ON _r TO authenticated;

-- 1. true_false must now be CHECK-rejected.
DO $$
DECLARE v_err text; v_course text; v_uid uuid;
BEGIN
  SELECT target_course INTO v_course FROM flashcards LIMIT 1;
  SELECT id INTO v_uid FROM public.profiles LIMIT 1;
  BEGIN
    INSERT INTO flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type)
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'),
      '_79ITEM4TEST_tf', 'A', 'private', false, 'medium', gen_random_uuid(), 'true_false');
    INSERT INTO _r VALUES ('true_false rejected', 'CHECK violation', 'insert succeeded',
      'FAIL: true_false is still insertable');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO _r VALUES ('true_false rejected', 'CHECK violation', 'CHECK violation', 'PASS');
  WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('true_false rejected', 'CHECK violation', left(v_err, 60),
      'FAIL (unexpected error): ' || v_err);
  END;
END $$;

-- 2. Every surviving type must still be insertable.
DO $$
DECLARE v_type text; v_err text; v_course text; v_uid uuid;
BEGIN
  SELECT target_course INTO v_course FROM flashcards LIMIT 1;
  SELECT id INTO v_uid FROM public.profiles LIMIT 1;
  FOREACH v_type IN ARRAY ARRAY['flashcard','mcq','correct_incorrect','theory','case_study_mcq','match_the_following','fitb','concept_card']
  LOOP
    BEGIN
      INSERT INTO flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
        visibility, is_verified, difficulty, batch_id, question_type)
      VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'),
        '_79ITEM4TEST_' || v_type, 'A', 'private', false, 'medium', gen_random_uuid(), v_type);
      INSERT INTO _r VALUES ('surviving type: ' || v_type, 'insert succeeds', 'succeeded', 'PASS');
    EXCEPTION WHEN OTHERS THEN
      v_err := SQLERRM;
      INSERT INTO _r VALUES ('surviving type: ' || v_type, 'insert succeeds', left(v_err, 60),
        'FAIL: ' || v_err);
    END;
  END LOOP;
END $$;

-- 3. Neither D-10 policy mentions true_false any more.
INSERT INTO _r
SELECT 'no true_false in ' || polname, 'no mention', pg_get_expr(polwithcheck, polrelid),
  CASE WHEN pg_get_expr(polwithcheck, polrelid) ILIKE '%true_false%' THEN 'FAIL: stale reference survives' ELSE 'PASS' END
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 4. D-10 regression: student correct_incorrect insert still rejected, professor's still succeeds.
CREATE TEMP TABLE _fixture(role_label text PRIMARY KEY, id uuid);
GRANT SELECT ON _fixture TO authenticated;
INSERT INTO _fixture SELECT 'student', id FROM public.profiles WHERE role = 'student' ORDER BY created_at LIMIT 1;
INSERT INTO _fixture SELECT 'professor', id FROM public.profiles WHERE role = 'professor' ORDER BY created_at LIMIT 1;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'student'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_err text; v_uid uuid; v_course text;
BEGIN
  v_uid := (SELECT id FROM _fixture WHERE role_label = 'student');
  IF v_uid IS NULL THEN
    INSERT INTO _r VALUES ('student fixture', 'a student profile', 'none found', 'SKIP');
    RETURN;
  END IF;
  SELECT target_course INTO v_course FROM public.flashcards LIMIT 1;
  BEGIN
    INSERT INTO public.flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer)
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_79ITEM4TEST_student_ci', 'A',
      'private', false, 'medium', gen_random_uuid(), 'correct_incorrect', '["Correct","Incorrect"]'::jsonb, '0');
    INSERT INTO _r VALUES ('D-10 regression: student correct_incorrect [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: D-10 no longer enforced after ALTER POLICY');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('D-10 regression: student correct_incorrect [CRITICAL]', 'rejected', left(v_err, 60),
      CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL (unexpected error): ' || v_err END);
  END;
END $$;

SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'professor'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_err text; v_uid uuid; v_course text;
BEGIN
  v_uid := (SELECT id FROM _fixture WHERE role_label = 'professor');
  IF v_uid IS NULL THEN
    INSERT INTO _r VALUES ('professor fixture', 'a professor profile', 'none found', 'SKIP');
    RETURN;
  END IF;
  SELECT target_course INTO v_course FROM public.flashcards LIMIT 1;
  BEGIN
    INSERT INTO public.flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer)
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_79ITEM4TEST_professor_ci', 'A',
      'private', false, 'medium', gen_random_uuid(), 'correct_incorrect', '["Correct","Incorrect"]'::jsonb, '0');
    INSERT INTO _r VALUES ('D-10 regression: professor correct_incorrect [CRITICAL]', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('D-10 regression: professor correct_incorrect [CRITICAL]', 'succeeds', left(v_err, 60),
      'FAIL: D-10 blocked a professor after ALTER POLICY — ' || v_err);
  END;
END $$;

RESET ROLE;

SELECT * FROM _r ORDER BY check_name;

ROLLBACK; -- nothing above persists — read-safe, repeatable test
