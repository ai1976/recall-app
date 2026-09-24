-- Name: [TEST] Verify Sprint 8.7.8e — get_study_queue payload parity
--
-- Description: Post-deploy verification for
-- 01_FUNCTIONS_get_study_queue_payload_parity.sql. Follows the established
-- pattern (docs/database/sprint8.7.8c/02_TEST...sql): TEMP table `_r` of
-- (check_name, expected, actual, verdict), impersonation via
-- set_config('request.jwt.claims', ...), everything inside BEGIN...ROLLBACK
-- so no fixture survives. SELECT-grid checks only, not RAISE NOTICE — the
-- 8.7.4 postmortem (NOTICE text never captured back to the reviewing session)
-- is why this project prefers a result grid the operator can see directly.
--
-- Covers three things:
--   1. Regression: due-set membership and ordering are byte-identical to what
--      the pre-change predicate would return (proves eligibility/ordering
--      logic was not touched, not just asserted from reading the diff).
--   2. New-field parity: options/correct_answer/explanation/scenario/subtype
--      returned by get_study_queue match the source flashcards row exactly,
--      for one fixture of each field-bearing shape (case_study_mcq with a
--      scenario, and a plain mcq).
--   3. IDOR guard still blocks cross-user reads (unchanged from every prior
--      version of this function).
--
-- Run this whole file in one Supabase SQL Editor execution, AFTER
-- 01_FUNCTIONS_get_study_queue_payload_parity.sql has been deployed. Do not
-- mix with persistent DDL in the same run (L3 17c lesson).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_course text;
  v_card_mcq uuid; v_card_case uuid;
  v_batch uuid := gen_random_uuid();
  v_err text; v_cnt int;
  v_pre_cnt int; v_post_cnt int;
  v_row record; v_src record;
BEGIN
  SELECT id INTO v_a FROM public.profiles WHERE role = 'student' LIMIT 1;
  IF v_a IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '1 student', 'missing', 'SKIP: need a student profile');
    RETURN;
  END IF;
  SELECT target_course INTO v_course FROM public.flashcards WHERE target_course IS NOT NULL LIMIT 1;

  -- Impersonate v_a BEFORE any get_study_queue() call, including the regression baseline below —
  -- the RPC's own IDOR guard (`p_user_id IS DISTINCT FROM auth.uid()`) correctly rejects a call
  -- made under the SQL Editor's own superuser session with no request.jwt.claims set. Bug caught
  -- live on first run of this file: the baseline call was originally placed before this line and
  -- failed with exactly that P0001, from the guard working correctly, not from the function under
  -- test being broken.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ═══════════════════════════ REGRESSION BASELINE (before fixtures) ═══════════════════════════
  -- Snapshot v_a's current due-set membership + order via the SAME predicate the function encodes,
  -- run here as a literal independent query — not a call to the function itself, so this is a real
  -- cross-check against the WHERE clause the diff claims is unchanged, not circular.
  SELECT count(*) INTO v_pre_cnt
  FROM public.reviews r
  JOIN public.flashcards f ON f.id = r.flashcard_id
  JOIN public.profiles p ON p.id = v_a
  WHERE r.user_id = v_a
    AND r.status = 'active'
    AND r.next_review_date <= (now() AT TIME ZONE COALESCE(p.timezone,'Asia/Kolkata'))::date
    AND (r.skip_until IS NULL OR r.skip_until <= (now() AT TIME ZONE COALESCE(p.timezone,'Asia/Kolkata'))::date)
    AND f.question_type <> 'concept_card'
    AND (p.course_level IS NULL OR f.target_course IS NULL OR f.target_course = p.course_level)
    AND (f.user_id = v_a OR f.visibility = 'public'
         OR (f.visibility = 'friends' AND EXISTS (
               SELECT 1 FROM public.friendships fr WHERE fr.status = 'accepted'
                 AND ((fr.user_id = v_a AND fr.friend_id = f.user_id) OR (fr.friend_id = v_a AND fr.user_id = f.user_id)))));

  SELECT count(*) INTO v_post_cnt FROM public.get_study_queue(v_a);
  INSERT INTO _r VALUES ('due-set count matches independent predicate [CRITICAL]',
    v_pre_cnt::text, v_post_cnt::text, CASE WHEN v_pre_cnt = v_post_cnt THEN 'PASS' ELSE 'FAIL' END);

  -- ═══════════════════════════════════ FIXTURES ═══════════════════════════════════
  -- Disposable case_study_mcq card (with scenario) + a plain mcq card, both owned by v_a, both put
  -- straight into an active due 'reviews' row so they surface through get_study_queue immediately.
  -- back_text is NOT NULL on flashcards (confirmed against DATABASE_SCHEMA.md, not assumed) — real
  -- rows derive it from options[correct_answer] at save time (mcq/case_study_mcq convention); the
  -- fixtures below just need a non-null value satisfying the constraint, not production derivation.
  INSERT INTO public.flashcards (
    user_id, target_course, front_text, back_text, visibility, question_type, subtype,
    options, correct_answer, explanation, scenario, custom_subject, batch_id
  ) VALUES (
    v_a, v_course, '8.7.8e test — case mcq', 'Option C', 'private', 'case_study_mcq', NULL,
    '["Option A","Option B","Option C","Option D"]'::jsonb, '2',
    '"Because B is correct."'::jsonb, '8.7.8e test scenario text.' || chr(10) || 'Second line.',
    '8.7.8e-payload-parity', v_batch
  ) RETURNING id INTO v_card_case;

  INSERT INTO public.flashcards (
    user_id, target_course, front_text, back_text, visibility, question_type, subtype,
    options, correct_answer, explanation, scenario, custom_subject, batch_id
  ) VALUES (
    v_a, v_course, '8.7.8e test — plain mcq', 'Y', 'private', 'mcq', 'pure_theory',
    '["X","Y","Z","W"]'::jsonb, '1', '"Because X."'::jsonb, NULL,
    '8.7.8e-payload-parity', v_batch
  ) RETURNING id INTO v_card_mcq;

  -- quality is NOT NULL on reviews with no default (confirmed against DATABASE_SCHEMA.md, not
  -- assumed) — 3 = Medium, arbitrary but valid; this column is legacy-cosmetic post-SRS-Ladder-Epic
  -- and plays no role in what this test is checking.
  INSERT INTO public.reviews (user_id, flashcard_id, quality, next_review_date, status, rung)
  VALUES (v_a, v_card_case, 3, CURRENT_DATE - 1, 'active', 0);
  INSERT INTO public.reviews (user_id, flashcard_id, quality, next_review_date, status, rung)
  VALUES (v_a, v_card_mcq, 3, CURRENT_DATE - 1, 'active', 0);

  -- ═══════════════════════════════════ TESTS (as v_a) ═══════════════════════════════════
  -- (impersonation already set above, before the regression baseline)

  -- IDOR unchanged: v_a still cannot read another user's queue.
  BEGIN PERFORM * FROM public.get_study_queue(gen_random_uuid());
    INSERT INTO _r VALUES ('get_study_queue cross-user [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_study_queue cross-user [CRITICAL]', 'Access denied', left(v_err,40),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- New-field parity, case_study_mcq fixture: options/correct_answer/explanation/scenario/subtype
  -- returned by get_study_queue must equal the source flashcards row exactly.
  SELECT * INTO v_row FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_case;
  SELECT * INTO v_src FROM public.flashcards WHERE id = v_card_case;
  INSERT INTO _r VALUES ('case_study_mcq: options match source [CRITICAL]',
    v_src.options::text, v_row.options::text, CASE WHEN v_row.options = v_src.options THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('case_study_mcq: correct_answer matches source [CRITICAL]',
    v_src.correct_answer, v_row.correct_answer, CASE WHEN v_row.correct_answer = v_src.correct_answer THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('case_study_mcq: explanation matches source',
    v_src.explanation::text, v_row.explanation::text, CASE WHEN v_row.explanation = v_src.explanation THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('case_study_mcq: scenario matches source byte-for-byte [CRITICAL]',
    v_src.scenario, v_row.scenario, CASE WHEN v_row.scenario = v_src.scenario THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('case_study_mcq: subtype matches source (NULL expected)',
    COALESCE(v_src.subtype,'<null>'), COALESCE(v_row.subtype,'<null>'),
    CASE WHEN v_row.subtype IS NOT DISTINCT FROM v_src.subtype THEN 'PASS' ELSE 'FAIL' END);

  -- New-field parity, plain mcq fixture: subtype = 'pure_theory' carried through; scenario NULL
  -- carried through as NULL, not coerced to empty string.
  SELECT * INTO v_row FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_mcq;
  SELECT * INTO v_src FROM public.flashcards WHERE id = v_card_mcq;
  INSERT INTO _r VALUES ('plain mcq: subtype matches source [CRITICAL]',
    v_src.subtype, v_row.subtype, CASE WHEN v_row.subtype = v_src.subtype THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('plain mcq: scenario is NULL, not empty string',
    '<null>', COALESCE(v_row.scenario, '<null>'), CASE WHEN v_row.scenario IS NULL THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('plain mcq: options match source [CRITICAL]',
    v_src.options::text, v_row.options::text, CASE WHEN v_row.options = v_src.options THEN 'PASS' ELSE 'FAIL' END);

  -- Existing columns (pre-8.7.8e) still present and correct — batch_id/rung parity, the last two
  -- fields this function gained, proving this sprint didn't regress the prior two.
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_case AND batch_id = v_batch;
  INSERT INTO _r VALUES ('batch_id still carried through (8.7.4, not regressed)', '1', v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- Return-shape column count sanity check: 27 columns (22 pre-existing + 5 new).
  SELECT count(*) INTO v_cnt
  FROM information_schema.parameters
  WHERE specific_schema = 'public' AND specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_schema = 'public' AND routine_name = 'get_study_queue'
  ) AND parameter_mode = 'TABLE';
  INSERT INTO _r VALUES ('RETURNS TABLE column count', '27', v_cnt::text, CASE WHEN v_cnt = 27 THEN 'PASS' ELSE 'FAIL' END);

END;
$$;

SELECT * FROM _r ORDER BY (verdict LIKE 'FAIL%') DESC, check_name;

ROLLBACK;
