-- Name: [TEST] Verify D-10 role gate — student mcq insert rejected, professor mcq insert succeeds
--
-- Description: The ONE test that actually matters for D-10 — a passing UI test alone proves
-- nothing about the security boundary. Run immediately after 01_SCHEMA_d10_role_gate.sql.
-- Confirms: (1) a real student profile cannot INSERT a flashcards row with
-- question_type='mcq' (RLS RESTRICTIVE policy rejects it), (2) that same student CAN still
-- insert a plain question_type='flashcard' row (D-10 must not over-block free-recall types),
-- (3) a real professor profile CAN insert the identical mcq row, (4) a student's 'fitb' and
-- 'true_false' rows are ALSO rejected — added specifically because 00_DIAGNOSTIC caught the
-- policy's draft using the wrong string ('fill_in_the_blanks' instead of the live 'fitb'),
-- which would have silently let that one type through ungated. mcq is the only type with a
-- real authoring UI this sprint, but the policy's IN-list covers all 7 verdict-bearing types
-- at once, so it's worth confirming the list itself is correct, not just the mcq path.
--
-- Self-contained and non-destructive: everything happens inside one BEGIN/ROLLBACK. The SQL
-- Editor runs as `postgres`, which bypasses RLS entirely — so each actor block explicitly
-- SET LOCAL ROLEs to `authenticated` and sets `request.jwt.claims` to impersonate a specific
-- real user, the same technique PostgREST itself uses (mirrors the pattern already
-- established in docs/database/landmines/11_TEST_verify_visibility_rls_matrix.sql).

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
GRANT SELECT, INSERT ON _r TO authenticated;

CREATE TEMP TABLE _fixture(role_label text PRIMARY KEY, id uuid);
GRANT SELECT ON _fixture TO authenticated;
INSERT INTO _fixture SELECT 'student', id FROM public.profiles WHERE role = 'student' ORDER BY created_at LIMIT 1;
INSERT INTO _fixture SELECT 'professor', id FROM public.profiles WHERE role = 'professor' ORDER BY created_at LIMIT 1;

-- ============================================
-- ACTOR: STUDENT — mcq insert must be REJECTED; plain flashcard insert must still succeed
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

  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type, options, correct_answer
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_D10TEST_student_mcq', 'A',
      'private', false, 'medium', gen_random_uuid(), 'mcq', '["A","B"]'::jsonb, '0'
    );
    INSERT INTO _r VALUES ('student mcq insert [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: student was able to create an mcq row — D-10 is NOT enforced');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student mcq insert [CRITICAL]', 'rejected', left(v_err, 60),
      CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL (unexpected error): ' || v_err END);
  END;

  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_D10TEST_student_flashcard', 'A',
      'private', false, 'medium', gen_random_uuid(), 'flashcard'
    );
    INSERT INTO _r VALUES ('student flashcard insert unaffected', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student flashcard insert unaffected', 'succeeds', left(v_err, 60),
      'FAIL: D-10 over-blocked a free-recall type — ' || v_err);
  END;

  -- Regression check for the exact bug class 00_DIAGNOSTIC caught: confirm the
  -- policy's IN-list uses the LIVE enum string ('fitb'), not the kickoff spec's
  -- assumed 'fill_in_the_blanks' (which does not exist in chk_flashcards_
  -- question_type and would have left this type completely ungated).
  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_D10TEST_student_fitb', 'A',
      'private', false, 'medium', gen_random_uuid(), 'fitb'
    );
    INSERT INTO _r VALUES ('student fitb insert [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: student was able to create a fitb row — the IN-list is missing/wrong for this type');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student fitb insert [CRITICAL]', 'rejected', left(v_err, 60),
      CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL (unexpected error): ' || v_err END);
  END;

  BEGIN
    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_verified, difficulty, batch_id, question_type
    ) VALUES (
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_D10TEST_student_true_false', 'A',
      'private', false, 'medium', gen_random_uuid(), 'true_false'
    );
    INSERT INTO _r VALUES ('student true_false insert [CRITICAL]', 'rejected', 'succeeded',
      'FAIL: student was able to create a true_false row');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('student true_false insert [CRITICAL]', 'rejected', left(v_err, 60),
      CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL (unexpected error): ' || v_err END);
  END;
END $$;

RESET ROLE;

-- ============================================
-- ACTOR: PROFESSOR — identical mcq insert must SUCCEED
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
      v_uid, v_uid, v_uid, COALESCE(v_course, 'test_course'), '_D10TEST_professor_mcq', 'A',
      'private', false, 'medium', gen_random_uuid(), 'mcq', '["A","B"]'::jsonb, '0'
    );
    INSERT INTO _r VALUES ('professor mcq insert [CRITICAL]', 'succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('professor mcq insert [CRITICAL]', 'succeeds', left(v_err, 60),
      'FAIL: D-10 blocked a professor — ' || v_err);
  END;
END $$;

RESET ROLE;

SELECT * FROM _r ORDER BY check_name;

ROLLBACK; -- nothing above survives — this is a read-safe, repeatable test
