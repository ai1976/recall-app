-- Name: [TEST] Verify Sprint 7.9 — deletion, narrowed CHECK, explanation column,
--       D-10 policy regression
--
-- Description: Run immediately after 01_SCHEMA_sprint7.9_hygiene.sql. Confirms:
--   1. The 12 known QA rows are gone.
--   2. test_your_understanding and integrated_case are no longer insertable
--      (CHECK constraint violation — applies to every role, including postgres,
--      so no RLS impersonation needed for this part).
--   3. Every one of the 9 remaining live question_type values is still
--      insertable (regression — the ALTER TABLE must not have over-narrowed).
--   4. explanation column exists, nullable, jsonb.
--   5. Neither D-10 RESTRICTIVE policy mentions integrated_case any more.
--   6. Regression: D-10 gating itself still works post-ALTER POLICY — a real
--      student's mcq insert is still rejected, a real professor's still
--      succeeds (the ALTER POLICY in step 3 rewrote the whole WITH CHECK
--      expression, so confirming the surviving gate list still functions,
--      not just that the string dropped out, matters).
--
-- Self-contained and non-destructive: everything happens inside one
-- BEGIN/ROLLBACK — nothing below persists.

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
GRANT SELECT, INSERT ON _r TO authenticated;

-- 1. Confirm the 12 deleted rows are actually gone.
INSERT INTO _r
SELECT '12 QA rows deleted', '0 remaining', count(*)::text,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL: rows survived the DELETE' END
FROM flashcards
WHERE id IN (
  '3e148677-b203-4600-8b4d-41d464d6c4cc', 'd6f566f3-ca5b-4a99-a34e-e557264caba0',
  'b269e9b9-f09f-4ebf-a9e5-c2e16e99398d', '00cbfbf7-6ed3-4cfd-ba41-bab52d464534',
  'f84d137c-c939-4734-9c60-c9cf749de714', '6fd1a69b-eae3-44d1-b9b8-3ec86ec4fdaf',
  'd06b41f8-a2f8-4edc-8899-26c6dde64be9', '322c1b66-4464-4d5c-8ebd-cf45344b2787',
  '3a297f35-45c6-4b11-b8a2-0f078b87f1b5', 'ec364543-dcf3-4bbf-9646-707224fe671d',
  'd9df9670-49da-47db-b997-c165ec026d92', 'de1b88ee-399c-42c4-9a3f-d79cec413f64'
);

-- 2. test_your_understanding / integrated_case must now be CHECK-rejected.
DO $$
DECLARE v_err text; v_course text; v_uid uuid;
BEGIN
  SELECT target_course INTO v_course FROM flashcards LIMIT 1;
  SELECT id INTO v_uid FROM public.profiles LIMIT 1;
  BEGIN
    INSERT INTO flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type)
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'),
      '_79TEST_tyu', 'A', 'private', false, 'medium', gen_random_uuid(), 'test_your_understanding');
    INSERT INTO _r VALUES ('test_your_understanding rejected', 'CHECK violation', 'insert succeeded',
      'FAIL: test_your_understanding is still insertable');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO _r VALUES ('test_your_understanding rejected', 'CHECK violation', 'CHECK violation', 'PASS');
  WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('test_your_understanding rejected', 'CHECK violation', left(v_err, 60),
      'FAIL (unexpected error): ' || v_err);
  END;
END $$;

DO $$
DECLARE v_err text; v_course text; v_uid uuid;
BEGIN
  SELECT target_course INTO v_course FROM flashcards LIMIT 1;
  SELECT id INTO v_uid FROM public.profiles LIMIT 1;
  BEGIN
    INSERT INTO flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type)
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'),
      '_79TEST_ic', 'A', 'private', false, 'medium', gen_random_uuid(), 'integrated_case');
    INSERT INTO _r VALUES ('integrated_case rejected', 'CHECK violation', 'insert succeeded',
      'FAIL: integrated_case is still insertable');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO _r VALUES ('integrated_case rejected', 'CHECK violation', 'CHECK violation', 'PASS');
  WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('integrated_case rejected', 'CHECK violation', left(v_err, 60),
      'FAIL (unexpected error): ' || v_err);
  END;
END $$;

-- 3. Every surviving type must still be insertable (regression on the narrowed list).
-- Uses a real profiles.id for user_id/contributed_by/creator_id — a random UUID
-- trips flashcards_user_id_fkey before the row-shape check we actually care about here.
DO $$
DECLARE v_type text; v_err text; v_course text; v_uid uuid;
BEGIN
  SELECT target_course INTO v_course FROM flashcards LIMIT 1;
  SELECT id INTO v_uid FROM public.profiles LIMIT 1;
  FOREACH v_type IN ARRAY ARRAY['flashcard','mcq','true_false','correct_incorrect','theory','case_study_mcq','match_the_following','fitb','concept_card']
  LOOP
    BEGIN
      INSERT INTO flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text,
        visibility, is_verified, difficulty, batch_id, question_type)
      VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'),
        '_79TEST_' || v_type, 'A', 'private', false, 'medium', gen_random_uuid(), v_type);
      INSERT INTO _r VALUES ('surviving type: ' || v_type, 'insert succeeds', 'succeeded', 'PASS');
    EXCEPTION WHEN OTHERS THEN
      v_err := SQLERRM;
      INSERT INTO _r VALUES ('surviving type: ' || v_type, 'insert succeeds', left(v_err, 60),
        'FAIL: ' || v_err);
    END;
  END LOOP;
END $$;

-- 4. explanation column exists, nullable, jsonb.
INSERT INTO _r
SELECT 'explanation column shape', 'jsonb, nullable',
  data_type || ', ' || (CASE WHEN is_nullable = 'YES' THEN 'nullable' ELSE 'NOT NULL' END),
  CASE WHEN data_type = 'jsonb' AND is_nullable = 'YES' THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.columns
WHERE table_name = 'flashcards' AND column_name = 'explanation';

-- 5. Neither D-10 policy mentions integrated_case any more.
INSERT INTO _r
SELECT 'no integrated_case in ' || polname, 'no mention', pg_get_expr(polwithcheck, polrelid),
  CASE WHEN pg_get_expr(polwithcheck, polrelid) ILIKE '%integrated_case%' THEN 'FAIL: stale reference survives' ELSE 'PASS' END
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 6. D-10 regression: student mcq insert still rejected, professor mcq insert still succeeds.
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
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_79TEST_student_mcq', 'A',
      'private', false, 'medium', gen_random_uuid(), 'mcq', '["A","B"]'::jsonb, '0');
    INSERT INTO _r VALUES ('D-10 regression: student mcq [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: D-10 no longer enforced after ALTER POLICY');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('D-10 regression: student mcq [CRITICAL]', 'rejected', left(v_err, 60),
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
    VALUES (v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_79TEST_professor_mcq', 'A',
      'private', false, 'medium', gen_random_uuid(), 'mcq', '["A","B"]'::jsonb, '0');
    INSERT INTO _r VALUES ('D-10 regression: professor mcq [CRITICAL]', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('D-10 regression: professor mcq [CRITICAL]', 'succeeds', left(v_err, 60),
      'FAIL: D-10 blocked a professor after ALTER POLICY — ' || v_err);
  END;
END $$;

RESET ROLE;

SELECT * FROM _r ORDER BY check_name;

ROLLBACK; -- nothing above persists — read-safe, repeatable test
