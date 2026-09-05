-- Name: [TEST] Verify Sprint 6.3 dashboard reskin RPCs — bucketing / accuracy mapping / IDOR / concept-card exclusion
--
-- Description:
--   Post-deploy verification for 01_FUNCTIONS_dashboard_reskin_rpcs.sql.
--   Impersonates real users via request.jwt.claims (same idiom as
--   srs-ladder/03_TEST). ALL fixtures + writes are inside BEGIN…ROLLBACK —
--   nothing commits. No persistent DDL here, so the single-txn ROLLBACK is safe.
--
--   Run AFTER 01_FUNCTIONS is committed. Expect every row PASS.
--   A SKIP row means the DB had no usable fixture (2 students + 1 professor
--   with a course).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_stu   uuid; v_stu2 uuid; v_course text;
  v_prof  uuid; v_pcourse text;
  v_c_today uuid; v_c_1mo uuid; v_c_far uuid; v_c_concept uuid;
  v_pc_mcq uuid; v_pc_tf uuid; v_pc_concept uuid;
  v_int int; v_n int; v_pct numeric; v_err text;
BEGIN
  -- ── Fixtures ───────────────────────────────────────────────────────────────
  SELECT id, course_level INTO v_stu, v_course
  FROM public.profiles WHERE role = 'student' AND course_level IS NOT NULL LIMIT 1;
  SELECT id INTO v_stu2 FROM public.profiles WHERE role = 'student' AND id <> v_stu LIMIT 1;
  SELECT id, course_level INTO v_prof, v_pcourse
  FROM public.profiles WHERE role = 'professor' AND course_level IS NOT NULL LIMIT 1;

  IF v_stu IS NULL OR v_stu2 IS NULL OR v_prof IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '2 students + 1 professor w/ course', 'missing', 'SKIP');
    RETURN;
  END IF;

  -- Student's own private cards at controlled schedule offsets
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_stu, v_course, 'S63 today',  'b', 'private', 'manual') RETURNING id INTO v_c_today;
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_stu, v_course, 'S63 ~1mo',   'b', 'private', 'manual') RETURNING id INTO v_c_1mo;
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_stu, v_course, 'S63 far',    'b', 'private', 'manual') RETURNING id INTO v_c_far;
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, source)
  VALUES (v_stu, v_course, 'S63 concept','b', 'private', 'concept_card', 'manual') RETURNING id INTO v_c_concept;

  -- NOTE: v_stu is a REAL student with pre-existing review history, so absolute
  -- lane sums are not deterministic. The concept-card check below is delta-based.
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition, next_review_date, status)
  VALUES
    (v_stu, v_c_today,   3, 2.5, 1, 1, CURRENT_DATE - 2,  'active'),   -- overdue -> bucket 0
    (v_stu, v_c_1mo,     3, 2.5, 1, 1, CURRENT_DATE + 30, 'active'),   -- bucket 5 (1mo)
    (v_stu, v_c_far,     3, 2.5, 1, 1, CURRENT_DATE + 400,'active');   -- bucket 7 (6mo+)

  -- ══ 1. get_due_forecast_buckets — always 8 rows, ordered ════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_stu, 'role', 'authenticated')::text, true);

  SELECT count(*) INTO v_n FROM public.get_due_forecast_buckets(v_stu);
  INSERT INTO _r VALUES ('forecast_buckets: exactly 8 lanes', '8', v_n::text,
    CASE WHEN v_n = 8 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 2. overdue + today fold into bucket 0 ═══════════════════════════════════
  SELECT scheduled_count INTO v_int FROM public.get_due_forecast_buckets(v_stu) WHERE bucket_index = 0;
  INSERT INTO _r VALUES ('forecast_buckets: overdue -> lane 0 (Today)', 'ge 1', v_int::text,
    CASE WHEN v_int >= 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 3. +30d card lands in lane 5 (1mo) ═════════════════════════════════════
  SELECT scheduled_count INTO v_int FROM public.get_due_forecast_buckets(v_stu) WHERE bucket_index = 5;
  INSERT INTO _r VALUES ('forecast_buckets: +30d -> lane 5 (1mo)', 'ge 1', v_int::text,
    CASE WHEN v_int >= 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 4. far-future card lands in lane 7 (6mo+) ══════════════════════════════
  SELECT scheduled_count INTO v_int FROM public.get_due_forecast_buckets(v_stu) WHERE bucket_index = 7;
  INSERT INTO _r VALUES ('forecast_buckets: +400d -> lane 7 (6mo+)', 'ge 1', v_int::text,
    CASE WHEN v_int >= 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 5. concept card excluded from every lane (delta-based — real student) ═══
  --    Snapshot the total, add a due concept-card review, snapshot again:
  --    a correct RPC leaves the total unchanged.
  SELECT COALESCE(SUM(scheduled_count), 0) INTO v_int FROM public.get_due_forecast_buckets(v_stu);
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition, next_review_date, status)
  VALUES (v_stu, v_c_concept, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active');
  SELECT COALESCE(SUM(scheduled_count), 0) INTO v_n FROM public.get_due_forecast_buckets(v_stu);
  INSERT INTO _r VALUES ('forecast_buckets: concept card adds 0 to the ledger [CRITICAL]',
    v_int::text || ' (unchanged)', v_n::text,
    CASE WHEN v_n = v_int THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 6. IDOR — student cannot read another student's forecast ═══════════════
  BEGIN
    PERFORM public.get_due_forecast_buckets(v_stu2);
    INSERT INTO _r VALUES ('forecast_buckets: IDOR raises [CRITICAL]', 'exception', 'no exception', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('forecast_buckets: IDOR raises [CRITICAL]', 'exception', SQLERRM, 'PASS');
  END;

  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ── Educator accuracy fixtures ────────────────────────────────────────────
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, source)
  VALUES (v_prof, v_pcourse, 'S63 P mcq', 'b', 'public', 'mcq', 'manual') RETURNING id INTO v_pc_mcq;
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, source)
  VALUES (v_prof, v_pcourse, 'S63 P tf',  'b', 'public', 'true_false', 'manual') RETURNING id INTO v_pc_tf;
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, source)
  VALUES (v_prof, v_pcourse, 'S63 P concept', 'b', 'public', 'concept_card', 'manual') RETURNING id INTO v_pc_concept;

  -- mcq: 3 hits (q3/q5/q5) + 1 miss (q1) + 1 skip (q0) -> 3/4 = 75.0
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition, next_review_date, status) VALUES
    (v_stu,  v_pc_mcq, 5, 2.5, 1, 1, CURRENT_DATE, 'active'),
    (v_stu2, v_pc_mcq, 3, 2.5, 1, 1, CURRENT_DATE, 'active'),
    (v_stu,  v_pc_tf,  1, 2.5, 1, 1, CURRENT_DATE, 'active');
  -- extra mcq rows via a second review row per user is blocked by UNIQUE(user_id,flashcard_id);
  -- widen with more students if present
  UPDATE public.reviews SET quality = 5 WHERE user_id = v_stu2 AND flashcard_id = v_pc_mcq; -- keep 2 mcq rows: q5,q5 -> 2/2 = 100
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition, next_review_date, status)
  VALUES (v_stu2, v_pc_tf, 0, 2.5, 1, 1, CURRENT_DATE, 'active'); -- tf: 1 miss + 1 skip -> denom 1, hits 0 -> 0.0

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);

  -- ══ 7. accuracy mapping: mcq -> 100.0 (q5,q5) ══════════════════════════════
  SELECT accuracy_pct, total_graded, hits INTO v_pct, v_n, v_int
  FROM public.get_educator_accuracy_by_qtype(v_prof, v_pcourse) WHERE question_type = 'mcq';
  INSERT INTO _r VALUES ('accuracy: mcq 2 hits / 2 graded -> 100.0',
    '100.0 | 2 | 2', COALESCE(v_pct::text,'-')||' | '||COALESCE(v_n::text,'-')||' | '||COALESCE(v_int::text,'-'),
    CASE WHEN v_pct = 100.0 AND v_n = 2 AND v_int = 2 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 8. accuracy mapping: true_false -> 0.0, skip excluded from denom ════════
  SELECT accuracy_pct, total_graded INTO v_pct, v_n
  FROM public.get_educator_accuracy_by_qtype(v_prof, v_pcourse) WHERE question_type = 'true_false';
  INSERT INTO _r VALUES ('accuracy: true_false 1 miss (+1 skip) -> 0.0 / denom 1',
    '0.0 | 1', COALESCE(v_pct::text,'-')||' | '||COALESCE(v_n::text,'-'),
    CASE WHEN v_pct = 0.0 AND v_n = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 9. concept_card never appears ═════════════════════════════════════════
  SELECT count(*) INTO v_n FROM public.get_educator_accuracy_by_qtype(v_prof, v_pcourse)
  WHERE question_type = 'concept_card';
  INSERT INTO _r VALUES ('accuracy: concept_card excluded [CRITICAL]', '0', v_n::text,
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 10. IDOR — a non-owner professor cannot read this cohort ══════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_stu, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.get_educator_accuracy_by_qtype(v_prof, v_pcourse);
    INSERT INTO _r VALUES ('accuracy: IDOR raises for non-owned cohort [CRITICAL]', 'exception', 'no exception', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('accuracy: IDOR raises for non-owned cohort [CRITICAL]', 'exception', SQLERRM, 'PASS');
  END;

  -- ══ 11. cohort forecast buckets — 8 lanes + IDOR ═════════════════════════
  BEGIN
    PERFORM public.get_educator_cohort_forecast_buckets(v_prof, v_pcourse);
    INSERT INTO _r VALUES ('cohort_forecast: IDOR raises for non-owner [CRITICAL]', 'exception', 'no exception', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('cohort_forecast: IDOR raises for non-owner [CRITICAL]', 'exception', SQLERRM, 'PASS');
  END;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.get_educator_cohort_forecast_buckets(v_prof, v_pcourse);
  INSERT INTO _r VALUES ('cohort_forecast: exactly 8 lanes', '8', v_n::text,
    CASE WHEN v_n = 8 THEN 'PASS' ELSE 'FAIL' END);

  SELECT scheduled_count INTO v_int FROM public.get_educator_cohort_forecast_buckets(v_prof, v_pcourse)
  WHERE bucket_index = 0;
  INSERT INTO _r VALUES ('cohort_forecast: cohort due-today rows land in lane 0', 'ge 1', v_int::text,
    CASE WHEN v_int >= 1 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
