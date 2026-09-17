-- Name: [TEST] Verify Sprint 8.6c — mcq_multi CHECK/D-10 gate + apply_review selected_answer
--
-- Description: Post-deploy verification for 01_SCHEMA + 02_FUNCTIONS + 02b_HOTFIX.
-- Impersonates real profiles via request.jwt.claims + SET LOCAL ROLE authenticated
-- (same idiom as sprint7.5/02_TEST_verify_d10_role_gate.sql). ALL fixtures and
-- writes are inside BEGIN...ROLLBACK — nothing is committed.
--
-- ⚠️ CORRECTED after a live run of the original version of this file: the
-- original only set request.jwt.claims (for auth.uid()) but never switched the
-- actual Postgres ROLE. The Supabase SQL Editor's connection runs as a
-- superuser/table-owner role, and Postgres Row-Level Security is bypassed
-- entirely for superusers/owners regardless of jwt claims — so the "student
-- blocked from mcq_multi insert" check silently ran with RLS OFF and the
-- student insert succeeded (a false FAIL on a working gate, confirmed by
-- separately reading the live policy body — it correctly lists mcq_multi).
-- This version adds `SET LOCAL ROLE authenticated;` around every RLS-relevant
-- statement, exactly the idiom sprint7.5/02_TEST already established for this
-- exact reason. Fixture ids are stashed in a temp table (`_fx`) instead of
-- plpgsql DECLARE variables, since a role switch happens between statements —
-- DO $$ ... $$ blocks don't share variables with each other.
--
-- Covers: (1) exactly one apply_review overload exists post-deploy; (2)
-- mcq_multi is insertable by a professor and rejected by RLS for a student —
-- now actually enforced; (3) apply_review's new p_selected_answer writes into
-- review_events.selected_answer; (4) a 5-arg call (no p_selected_answer) still
-- works and leaves selected_answer NULL; (5) submit_review's compat wrapper
-- still resolves and works unchanged.
--
-- Run AFTER 01_SCHEMA, 02_FUNCTIONS, and 02b_HOTFIX are all committed.

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
CREATE TEMP TABLE _fx(k text PRIMARY KEY, v text);
-- Temp tables are owned by the connecting (superuser) role by default —
-- 'authenticated' needs explicit access to keep writing results/fixtures
-- across the role switches below.
GRANT SELECT, INSERT, UPDATE ON _r, _fx TO authenticated;

-- ══ 1. Exactly one apply_review overload exists (no RLS involved) ═════════
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'apply_review';
  INSERT INTO _r VALUES ('exactly one apply_review overload exists [CRITICAL]', '1', v_count::text,
    CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ Fixtures: a real professor/admin/super_admin + a real student sharing
--    a course (no RLS involved — plain SELECT as the connecting role) ══════
DO $$
DECLARE v_prof uuid; v_student uuid; v_course text;
BEGIN
  SELECT id, course_level INTO v_prof, v_course
  FROM public.profiles WHERE role IN ('professor','admin','super_admin') AND course_level IS NOT NULL LIMIT 1;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' AND course_level = v_course LIMIT 1;

  IF v_prof IS NULL OR v_student IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', 'professor + student w/ course', 'missing', 'SKIP');
  ELSE
    INSERT INTO _fx VALUES ('prof', v_prof::text), ('student', v_student::text), ('course', v_course);
  END IF;
END $$;

-- ══ 2. D-10 gate — professor CAN insert mcq_multi (impersonated: jwt claim
--       AND actual role switch, so RLS is genuinely enforced) ═════════════
DO $$
DECLARE v_prof uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_prof uuid; v_card uuid; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  BEGIN
    INSERT INTO public.flashcards (
      user_id, target_course, front_text, back_text, visibility, question_type,
      options, correct_answer, source
    ) VALUES (
      v_prof, (SELECT v FROM _fx WHERE k = 'course'), 'S8.6c mcq_multi front', 'opt A • opt C', 'private', 'mcq_multi',
      '["opt A","opt B","opt C"]'::jsonb, '0;2', 'manual'
    ) RETURNING id INTO v_card;
    INSERT INTO _fx VALUES ('card', v_card::text);
    INSERT INTO _r VALUES ('professor can insert mcq_multi [CRITICAL]', 'insert succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('professor can insert mcq_multi [CRITICAL]', 'insert succeeds', 'FAIL: '||left(v_err,60), 'FAIL');
  END;
END $$;

RESET ROLE;

-- ══ 3. D-10 gate — student CANNOT insert mcq_multi (same real enforcement) ═
DO $$
DECLARE v_student uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN RETURN; END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_student uuid; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN RETURN; END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  BEGIN
    INSERT INTO public.flashcards (
      user_id, target_course, front_text, back_text, visibility, question_type,
      options, correct_answer, source
    ) VALUES (
      v_student, (SELECT v FROM _fx WHERE k = 'course'), 'S8.6c student mcq_multi', 'x', 'private', 'mcq_multi',
      '["opt A","opt B"]'::jsonb, '0', 'manual'
    );
    INSERT INTO _r VALUES ('student blocked from mcq_multi insert [CRITICAL]', 'RLS rejection', 'insert succeeded', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('student blocked from mcq_multi insert [CRITICAL]', 'RLS rejection', left(v_err, 40),
      CASE WHEN v_err ILIKE '%row-level security%' OR v_err ILIKE '%policy%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
END $$;

RESET ROLE;

-- ══ 4/5/6. apply_review + submit_review — back to the professor as the
--    "studying" user (impersonated the same way) ═══════════════════════════
DO $$
DECLARE v_prof uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

-- All three RPC calls run for real as 'authenticated' (matches real usage —
-- apply_review/submit_review are SECURITY DEFINER, so their own internal
-- writes to review_events succeed regardless of the caller's grants). The
-- CALLS happen here; verifying what they wrote happens in a separate block
-- below AFTER switching back — 'authenticated' has zero direct grants on
-- review_events (by design), so a raw SELECT against it must run as the
-- owner/admin role, same as any other test-tooling introspection.
DO $$
DECLARE
  v_prof uuid; v_card uuid; v_rung int; v_int int; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') OR NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'card') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  SELECT v::uuid INTO v_card FROM _fx WHERE k = 'card';

  -- ══ 4. apply_review WITH p_selected_answer ══════════════════════════════
  SELECT new_rung, interval_days INTO v_rung, v_int
  FROM public.apply_review(v_prof, v_card, 'hard', false, 'review_session', '["0","1"]'::jsonb);

  -- ══ 5. Backward compat — 5-arg call (no p_selected_answer) ══════════════
  SELECT new_rung, interval_days INTO v_rung, v_int
  FROM public.apply_review(v_prof, v_card, 'medium', true, 'review_session');

  -- ══ 6. submit_review compat wrapper ══════════════════════════════════════
  BEGIN
    SELECT new_rung, interval_days INTO v_rung, v_int
    FROM public.submit_review(v_prof, v_card, 'easy');
    INSERT INTO _r VALUES ('submit_review compat wrapper still works', 'no error', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('submit_review compat wrapper still works', 'no error', 'FAIL: '||left(v_err,60), 'FAIL');
  END;
END $$;

RESET ROLE;

-- ══ Verify what the 3 calls above actually wrote — as the owner/admin role,
--    which has full SELECT rights on review_events regardless of the
--    intentional zero-grant-to-authenticated design ══════════════════════
DO $$
DECLARE
  v_card uuid; v_selected_1 jsonb; v_selected_2 jsonb; v_rev_count int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'card') THEN RETURN; END IF;
  SELECT v::uuid INTO v_card FROM _fx WHERE k = 'card';

  SELECT count(*) INTO v_rev_count FROM public.review_events WHERE flashcard_id = v_card;
  INSERT INTO _r VALUES ('review_events: 3 rows for v_card (2x apply_review + 1x submit_review)', '3', v_rev_count::text,
    CASE WHEN v_rev_count = 3 THEN 'PASS' ELSE 'FAIL' END);

  -- oldest row = the p_selected_answer call
  SELECT selected_answer INTO v_selected_1 FROM public.review_events
  WHERE flashcard_id = v_card ORDER BY id ASC LIMIT 1;
  INSERT INTO _r VALUES ('apply_review writes selected_answer [CRITICAL]', '["0","1"]', COALESCE(v_selected_1::text, 'NULL'),
    CASE WHEN v_selected_1 = '["0","1"]'::jsonb THEN 'PASS' ELSE 'FAIL' END);

  -- 2nd-oldest row = the 5-arg backward-compat call
  SELECT selected_answer INTO v_selected_2 FROM public.review_events
  WHERE flashcard_id = v_card ORDER BY id ASC OFFSET 1 LIMIT 1;
  INSERT INTO _r VALUES ('5-arg apply_review call still works, selected_answer NULL [CRITICAL]',
    'NULL', COALESCE(v_selected_2::text, 'NULL'),
    CASE WHEN v_selected_2 IS NULL THEN 'PASS' ELSE 'FAIL' END);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;

ROLLBACK;
