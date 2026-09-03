-- Name: [TEST] Verify SRS Ladder Phase 1 engine — preview / advance / drop-back / mastered / parity / IDOR
--
-- Description:
--   Post-deploy verification for 01_SCHEMA + 02_FUNCTIONS. Impersonates a real student via
--   request.jwt.claims (same idiom as sprint6/02_TEST). ALL fixtures (flashcards, reviews) and
--   every submit_review write are inside BEGIN…ROLLBACK — nothing is committed.
--   NO persistent DDL here (01 + 02 create everything), so the single-txn ROLLBACK is safe.
--
--   Run AFTER 01_SCHEMA and 02_FUNCTIONS are committed. Expect every row PASS.
--   A SKIP row means the DB had no usable student fixture.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid; v_course text;
  v_card    uuid;   -- private flashcard owned by A, in A's course
  v_new     uuid;   -- a second card owned by A with NO review row (new-card path)
  v_concept uuid;
  v_rev     uuid;
  v_cfg     jsonb;
  v_int     int; v_rung int; v_status text; v_err text;
  v_exp_int int; v_prev_int int;
  r_rung int; r_rating text;
BEGIN
  -- ── Fixtures ───────────────────────────────────────────────────────────────
  SELECT id, course_level INTO v_a, v_course
  FROM public.profiles WHERE role = 'student' AND course_level IS NOT NULL LIMIT 1;
  SELECT id INTO v_b FROM public.profiles WHERE role = 'student' AND id <> v_a LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '2 students w/ course', 'missing', 'SKIP');
    RETURN;
  END IF;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_a, v_course, 'LADDER card front', 'LADDER card back', 'private', 'manual')
  RETURNING id INTO v_card;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_a, v_course, 'LADDER new-card front', 'LADDER new-card back', 'private', 'manual')
  RETURNING id INTO v_new;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, source)
  VALUES (v_a, v_course, 'LADDER concept front', 'LADDER concept back', 'private', 'concept_card', 'manual')
  RETURNING id INTO v_concept;

  -- one review row on v_card we reshape between checks
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition,
                              next_review_date, status, rung)
  VALUES (v_a, v_card, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active', 2)
  RETURNING id INTO v_rev;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ══ 1. get_srs_ladder_config shape ═══════════════════════════════════════
  v_cfg := public.get_srs_ladder_config();
  INSERT INTO _r VALUES ('config: 8 curve rows',
    '8', jsonb_array_length(v_cfg->'curves')::text,
    CASE WHEN jsonb_array_length(v_cfg->'curves') = 8 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('config: rules.top_rung = 7',
    '7', (v_cfg->'rules'->>'top_rung'),
    CASE WHEN (v_cfg->'rules'->>'top_rung') = '7' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 2. srs_preview(NULL) — new card ══════════════════════════════════════
  SELECT interval_days INTO v_int FROM public.srs_preview(NULL::integer) WHERE rating = 'easy';
  INSERT INTO _r VALUES ('preview new-card easy -> 7d', '7', v_int::text,
    CASE WHEN v_int = 7 THEN 'PASS' ELSE 'FAIL' END);
  SELECT interval_days INTO v_int FROM public.srs_preview(NULL::integer) WHERE rating = 'hard';
  INSERT INTO _r VALUES ('preview new-card hard -> 1d', '1', v_int::text,
    CASE WHEN v_int = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 3. srs_preview(2) — existing card at rung 2 ══════════════════════════
  SELECT interval_days INTO v_int FROM public.srs_preview(2) WHERE rating = 'easy';
  INSERT INTO _r VALUES ('preview rung2 easy -> rung3 = 14d', '14', v_int::text,
    CASE WHEN v_int = 14 THEN 'PASS' ELSE 'FAIL' END);
  SELECT interval_days INTO v_int FROM public.srs_preview(2) WHERE rating = 'medium';
  INSERT INTO _r VALUES ('preview rung2 medium -> hold = 7d', '7', v_int::text,
    CASE WHEN v_int = 7 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 4. srs_preview(7) — top rung ════════════════════════════════════════
  SELECT interval_days INTO v_int FROM public.srs_preview(7) WHERE rating = 'easy';
  INSERT INTO _r VALUES ('preview rung7 easy -> 240d', '240', v_int::text,
    CASE WHEN v_int = 240 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 5. submit_review — brand-new card (INSERT path) ═════════════════════
  SELECT new_rung, interval_days, new_status
    INTO v_rung, v_int, v_status
  FROM public.submit_review(v_a, v_new, 'easy');
  INSERT INTO _r VALUES ('submit new-card easy -> rung2 / 7d / active',
    '2 / 7 / active', v_rung||' / '||v_int||' / '||v_status,
    CASE WHEN v_rung = 2 AND v_int = 7 AND v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);
  SELECT rung INTO v_rung FROM public.reviews WHERE user_id = v_a AND flashcard_id = v_new;
  INSERT INTO _r VALUES ('submit new-card persisted a row', '2', COALESCE(v_rung::text,'<none>'),
    CASE WHEN v_rung = 2 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 6. submit_review — advance (rung 2 --easy--> rung 3) ═══════════════
  UPDATE public.reviews SET rung = 2, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days INTO v_rung, v_int FROM public.submit_review(v_a, v_card, 'easy');
  INSERT INTO _r VALUES ('submit advance rung2->3 = 14d', '3 / 14', v_rung||' / '||v_int,
    CASE WHEN v_rung = 3 AND v_int = 14 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 7. submit_review — medium HOLD (rung 4 --medium--> rung 4) ═════════
  UPDATE public.reviews SET rung = 4, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days INTO v_rung, v_int FROM public.submit_review(v_a, v_card, 'medium');
  INSERT INTO _r VALUES ('submit medium hold at rung4 = 30d', '4 / 30', v_rung||' / '||v_int,
    CASE WHEN v_rung = 4 AND v_int = 30 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 8. submit_review — hard DROP (rung 5 --hard--> rung 0, +1d) ═══════
  UPDATE public.reviews SET rung = 5, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days, new_status INTO v_rung, v_int, v_status
  FROM public.submit_review(v_a, v_card, 'hard');
  INSERT INTO _r VALUES ('submit hard drop rung5->0 = 1d / active',
    '0 / 1 / active', v_rung||' / '||v_int||' / '||v_status,
    CASE WHEN v_rung = 0 AND v_int = 1 AND v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 9. submit_review — MASTERED (rung 7 --easy--> status=mastered) ════
  UPDATE public.reviews SET rung = 7, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days, new_status INTO v_rung, v_int, v_status
  FROM public.submit_review(v_a, v_card, 'easy');
  INSERT INTO _r VALUES ('submit easy at rung7 -> mastered / rung7 / 240d [CRITICAL]',
    '7 / 240 / mastered', v_rung||' / '||v_int||' / '||v_status,
    CASE WHEN v_rung = 7 AND v_int = 240 AND v_status = 'mastered' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 10. submit_review — UN-MASTER (mastered --hard--> active / rung 0) ═
  SELECT new_rung, new_status INTO v_rung, v_status
  FROM public.submit_review(v_a, v_card, 'hard');
  INSERT INTO _r VALUES ('submit hard on mastered -> active / rung0 [CRITICAL]',
    '0 / active', v_rung||' / '||v_status,
    CASE WHEN v_rung = 0 AND v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 11. PREVIEW PARITY — submit_review interval == srs_preview interval ═
  --        3 rungs x {hard, medium, easy}. Reset the row before each grade.
  FOR r_rung IN SELECT unnest(ARRAY[1, 3, 6]) LOOP
    FOREACH r_rating IN ARRAY ARRAY['hard','medium','easy'] LOOP
      UPDATE public.reviews SET rung = r_rung, status = 'active', next_review_date = CURRENT_DATE - 1
        WHERE id = v_rev;
      SELECT interval_days INTO v_exp_int  FROM public.submit_review(v_a, v_card, r_rating);
      SELECT interval_days INTO v_prev_int FROM public.srs_preview(r_rung) WHERE rating = r_rating;
      INSERT INTO _r VALUES (
        format('parity rung%s %s', r_rung, r_rating),
        v_prev_int::text, v_exp_int::text,
        CASE WHEN v_exp_int = v_prev_int THEN 'PASS' ELSE 'FAIL' END);
    END LOOP;
  END LOOP;

  -- ══ 12. IDOR — cross-user submit RAISEs ══════════════════════════════
  BEGIN
    PERFORM public.submit_review(v_b, v_card, 'easy');
    INSERT INTO _r VALUES ('IDOR cross-user submit [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('IDOR cross-user submit [CRITICAL]', 'Access denied', left(v_err, 24),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ══ 13. IDOR — NULL session submit RAISEs ═══════════════════════════
  PERFORM set_config('request.jwt.claims', NULL, true);
  BEGIN
    PERFORM public.submit_review(v_a, v_card, 'easy');
    INSERT INTO _r VALUES ('IDOR null-session submit [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('IDOR null-session submit [CRITICAL]', 'Access denied', left(v_err, 24),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ══ 14. concept card rejected ═══════════════════════════════════════
  BEGIN
    PERFORM public.submit_review(v_a, v_concept, 'easy');
    INSERT INTO _r VALUES ('concept_card submit rejected', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('concept_card submit rejected', 'error', left(v_err, 24),
      CASE WHEN v_err ILIKE '%oncept%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ══ 15. get_study_queue exposes `rung` ════════════════════════════════
  UPDATE public.reviews SET rung = 3, status = 'active', skip_until = NULL,
    next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  UPDATE public.profiles SET course_level = v_course WHERE id = v_a;
  UPDATE public.flashcards SET target_course = v_course WHERE id = v_card;
  SELECT rung INTO v_rung FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card;
  INSERT INTO _r VALUES ('get_study_queue returns rung', '3', COALESCE(v_rung::text,'<absent>'),
    CASE WHEN v_rung = 3 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 16. get_study_queue EXCLUDES mastered ════════════════════════════
  UPDATE public.reviews SET status = 'mastered' WHERE id = v_rev;
  SELECT count(*) INTO v_int FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card;
  INSERT INTO _r VALUES ('get_study_queue excludes mastered [CRITICAL]', '0', v_int::text,
    CASE WHEN v_int = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 17. get_due_forecast shares the queue predicate (course filter) ══
  UPDATE public.reviews SET status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  UPDATE public.flashcards SET target_course = v_course WHERE id = v_card;
  SELECT due_today INTO v_int FROM public.get_due_forecast(v_a);
  INSERT INTO _r VALUES ('forecast counts an in-course due card', 'ge 1', v_int::text,
    CASE WHEN v_int >= 1 THEN 'PASS' ELSE 'FAIL' END);

  UPDATE public.flashcards SET target_course = 'ZZZ_LADDER_NOMATCH' WHERE id = v_card;
  SELECT due_today INTO v_prev_int FROM public.get_due_forecast(v_a);
  INSERT INTO _r VALUES ('forecast drops an out-of-course due card [CRITICAL]',
    (v_int - 1)::text, v_prev_int::text,
    CASE WHEN v_prev_int = v_int - 1 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
