-- Name: [TEST] Verify Sprint 7.4 — apply_review / review_events / submit_review compat / IDOR / atomicity
--
-- Description:
--   Post-deploy verification for 01_SCHEMA + 02_FUNCTIONS + 03_FUNCTIONS.
--   Impersonates a real student via request.jwt.claims (same idiom as
--   srs-ladder/03_TEST). ALL fixtures (flashcards, reviews, review_events)
--   and every apply_review/submit_review write are inside BEGIN…ROLLBACK —
--   nothing is committed. Re-runs the srs-ladder Phase 1 transition-maths
--   suite (advance / hold / drop / mastered / un-master / preview parity /
--   IDOR / concept-card reject) against apply_review instead of
--   submit_review, so the "byte-identical transition behavior" deliverable
--   is a real check, not an assertion. Adds: rung_before NULL-on-new-card,
--   one review_events row per grade, the submit_review compat shim, and an
--   atomicity kill test.
--
--   Run AFTER 01_SCHEMA, 02_FUNCTIONS and 03_FUNCTIONS are all committed.
--   Expect every row PASS. A SKIP row means the DB had no usable student
--   fixture.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid; v_course text;
  v_card    uuid;   -- private flashcard owned by A, in A's course (reshaped between checks)
  v_new     uuid;   -- a second card owned by A with NO review row (new-card path)
  v_kill    uuid;   -- dedicated card for the atomicity kill test
  v_concept uuid;
  v_rev     uuid;
  v_int int; v_rung int; v_status text; v_err text;
  v_exp_int int; v_prev_int int;
  r_rung int; r_rating text;
  v_re_count int;
  v_rung_before_check int;
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
  VALUES (v_a, v_course, 'S7.4 card front', 'S7.4 card back', 'private', 'manual')
  RETURNING id INTO v_card;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_a, v_course, 'S7.4 new-card front', 'S7.4 new-card back', 'private', 'manual')
  RETURNING id INTO v_new;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_a, v_course, 'S7.4 kill-card front', 'S7.4 kill-card back', 'private', 'manual')
  RETURNING id INTO v_kill;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, source)
  VALUES (v_a, v_course, 'S7.4 concept front', 'S7.4 concept back', 'private', 'concept_card', 'manual')
  RETURNING id INTO v_concept;

  -- one review row on v_card we reshape between checks
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition,
                              next_review_date, status, rung)
  VALUES (v_a, v_card, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active', 2)
  RETURNING id INTO v_rev;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ══ 1. apply_review — brand-new card (INSERT path), rung_before NULL ═════
  SELECT new_rung, interval_days, new_status
    INTO v_rung, v_int, v_status
  FROM public.apply_review(v_a, v_new, 'easy');
  INSERT INTO _r VALUES ('apply new-card easy -> rung2 / 7d / active',
    '2 / 7 / active', v_rung||' / '||v_int||' / '||v_status,
    CASE WHEN v_rung = 2 AND v_int = 7 AND v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  SELECT rung_before INTO v_rung_before_check
  FROM public.review_events WHERE flashcard_id = v_new AND user_id = v_a;
  INSERT INTO _r VALUES ('review_events: new-card rung_before IS NULL [CRITICAL]',
    'NULL', COALESCE(v_rung_before_check::text, 'NULL'),
    CASE WHEN v_rung_before_check IS NULL THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_re_count FROM public.review_events WHERE flashcard_id = v_new;
  INSERT INTO _r VALUES ('review_events: exactly 1 row for new card', '1', v_re_count::text,
    CASE WHEN v_re_count = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 2. apply_review — advance (rung 2 --easy--> rung 3) ═════════════════
  UPDATE public.reviews SET rung = 2, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days INTO v_rung, v_int FROM public.apply_review(v_a, v_card, 'easy');
  INSERT INTO _r VALUES ('apply advance rung2->3 = 14d', '3 / 14', v_rung||' / '||v_int,
    CASE WHEN v_rung = 3 AND v_int = 14 THEN 'PASS' ELSE 'FAIL' END);

  SELECT rung_before INTO v_rung_before_check
  FROM public.review_events WHERE flashcard_id = v_card ORDER BY id DESC LIMIT 1;
  INSERT INTO _r VALUES ('review_events: existing-card rung_before = 2', '2', COALESCE(v_rung_before_check::text,'NULL'),
    CASE WHEN v_rung_before_check = 2 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 3. apply_review — medium HOLD (rung 4 --medium--> rung 4) ═══════════
  UPDATE public.reviews SET rung = 4, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days INTO v_rung, v_int FROM public.apply_review(v_a, v_card, 'medium');
  INSERT INTO _r VALUES ('apply medium hold at rung4 = 30d', '4 / 30', v_rung||' / '||v_int,
    CASE WHEN v_rung = 4 AND v_int = 30 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 4. apply_review — hard DROP (rung 5 --hard--> rung 0, +1d) ══════════
  UPDATE public.reviews SET rung = 5, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days, new_status INTO v_rung, v_int, v_status
  FROM public.apply_review(v_a, v_card, 'hard');
  INSERT INTO _r VALUES ('apply hard drop rung5->0 = 1d / active',
    '0 / 1 / active', v_rung||' / '||v_int||' / '||v_status,
    CASE WHEN v_rung = 0 AND v_int = 1 AND v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 5. apply_review — MASTERED (rung 7 --easy--> status=mastered) ═══════
  UPDATE public.reviews SET rung = 7, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days, new_status INTO v_rung, v_int, v_status
  FROM public.apply_review(v_a, v_card, 'easy');
  INSERT INTO _r VALUES ('apply easy at rung7 -> mastered / rung7 / 240d [CRITICAL]',
    '7 / 240 / mastered', v_rung||' / '||v_int||' / '||v_status,
    CASE WHEN v_rung = 7 AND v_int = 240 AND v_status = 'mastered' THEN 'PASS' ELSE 'FAIL' END);

  SELECT status_after INTO v_status FROM public.review_events
  WHERE flashcard_id = v_card ORDER BY id DESC LIMIT 1;
  INSERT INTO _r VALUES ('review_events: status_after = mastered', 'mastered', COALESCE(v_status,'NULL'),
    CASE WHEN v_status = 'mastered' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 6. apply_review — UN-MASTER (mastered --hard--> active / rung 0) ════
  SELECT new_rung, new_status INTO v_rung, v_status
  FROM public.apply_review(v_a, v_card, 'hard');
  INSERT INTO _r VALUES ('apply hard on mastered -> active / rung0 [CRITICAL]',
    '0 / active', v_rung||' / '||v_status,
    CASE WHEN v_rung = 0 AND v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 7. PREVIEW PARITY — apply_review interval == srs_preview interval,
  --       AND one review_events row logged per call ══════════════════════
  FOR r_rung IN SELECT unnest(ARRAY[1, 3, 6]) LOOP
    FOREACH r_rating IN ARRAY ARRAY['hard','medium','easy'] LOOP
      UPDATE public.reviews SET rung = r_rung, status = 'active', next_review_date = CURRENT_DATE - 1
        WHERE id = v_rev;
      SELECT interval_days INTO v_exp_int  FROM public.apply_review(v_a, v_card, r_rating);
      SELECT interval_days INTO v_prev_int FROM public.srs_preview(r_rung) WHERE rating = r_rating;
      INSERT INTO _r VALUES (
        format('parity rung%s %s', r_rung, r_rating),
        v_prev_int::text, v_exp_int::text,
        CASE WHEN v_exp_int = v_prev_int THEN 'PASS' ELSE 'FAIL' END);
    END LOOP;
  END LOOP;

  SELECT count(*) INTO v_re_count FROM public.review_events WHERE flashcard_id = v_card;
  -- v_card has been graded 6 times before this loop (steps 2-6 minus the
  -- un-master's own event = 2,3,4,5,6 -> 5 events) + 9 parity-loop calls = 14
  INSERT INTO _r VALUES ('review_events: v_card has exactly 14 rows (one per grade)', '14', v_re_count::text,
    CASE WHEN v_re_count = 14 THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 8. IDOR — cross-user apply_review RAISEs, logs nothing ═════════════
  SELECT count(*) INTO v_re_count FROM public.review_events;
  BEGIN
    PERFORM public.apply_review(v_b, v_card, 'easy');
    INSERT INTO _r VALUES ('IDOR cross-user apply [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('IDOR cross-user apply [CRITICAL]', 'Access denied', left(v_err, 24),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
  INSERT INTO _r VALUES ('IDOR cross-user apply logs nothing', '0 new rows',
    (SELECT count(*) FROM public.review_events) - v_re_count || ' new rows',
    CASE WHEN (SELECT count(*) FROM public.review_events) = v_re_count THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 9. IDOR — NULL session apply RAISEs ═════════════════════════════════
  PERFORM set_config('request.jwt.claims', NULL, true);
  BEGIN
    PERFORM public.apply_review(v_a, v_card, 'easy');
    INSERT INTO _r VALUES ('IDOR null-session apply [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('IDOR null-session apply [CRITICAL]', 'Access denied', left(v_err, 24),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ══ 10. concept card rejected, logs nothing ═════════════════════════════
  SELECT count(*) INTO v_re_count FROM public.review_events;
  BEGIN
    PERFORM public.apply_review(v_a, v_concept, 'easy');
    INSERT INTO _r VALUES ('concept_card apply rejected', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('concept_card apply rejected', 'error', left(v_err, 24),
      CASE WHEN v_err ILIKE '%oncept%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
  INSERT INTO _r VALUES ('concept_card reject logs nothing', '0 new rows',
    (SELECT count(*) FROM public.review_events) - v_re_count || ' new rows',
    CASE WHEN (SELECT count(*) FROM public.review_events) = v_re_count THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 11. submit_review compat shim — still works, logs is_correct = NULL ═
  -- (rung 3 medium hold -> 14d per the _default curve: 1/3/7/14/30/60/120/240
  -- for rungs 0-7; confirmed by the "parity rung3 medium" check above)
  UPDATE public.reviews SET rung = 3, status = 'active', next_review_date = CURRENT_DATE - 1 WHERE id = v_rev;
  SELECT new_rung, interval_days INTO v_rung, v_int FROM public.submit_review(v_a, v_card, 'medium');
  INSERT INTO _r VALUES ('submit_review shim: medium hold at rung3 = 14d', '3 / 14', v_rung||' / '||v_int,
    CASE WHEN v_rung = 3 AND v_int = 14 THEN 'PASS' ELSE 'FAIL' END);

  SELECT is_correct::text INTO v_err FROM public.review_events
  WHERE flashcard_id = v_card ORDER BY id DESC LIMIT 1;
  INSERT INTO _r VALUES ('submit_review shim logs is_correct = NULL [CRITICAL]', 'NULL', COALESCE(v_err, 'NULL'),
    CASE WHEN v_err IS NULL THEN 'PASS' ELSE 'FAIL' END);

  -- ══ 12. ATOMICITY — force a failure inside apply_review AFTER the reviews
  --        write, confirm the reviews write rolled back with it ═══════════
  PERFORM set_config('app.test_kill_flashcard', v_kill::text, true);

  CREATE OR REPLACE FUNCTION pg_temp._s74_kill_trigger() RETURNS trigger AS $t$
  BEGIN
    IF NEW.flashcard_id::text = current_setting('app.test_kill_flashcard', true) THEN
      RAISE EXCEPTION 'INTENTIONAL_TEST_KILL_ATOMICITY';
    END IF;
    RETURN NEW;
  END;
  $t$ LANGUAGE plpgsql;

  CREATE TRIGGER _s74_kill_trg BEFORE INSERT ON public.review_events
  FOR EACH ROW EXECUTE FUNCTION pg_temp._s74_kill_trigger();

  BEGIN
    PERFORM public.apply_review(v_a, v_kill, 'easy');
    INSERT INTO _r VALUES ('atomicity kill test fired [CRITICAL]', 'INTENTIONAL_TEST_KILL', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('atomicity kill test fired [CRITICAL]', 'INTENTIONAL_TEST_KILL', left(v_err, 40),
      CASE WHEN v_err ILIKE '%INTENTIONAL_TEST_KILL%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  DROP TRIGGER _s74_kill_trg ON public.review_events;

  SELECT count(*) INTO v_int FROM public.reviews WHERE user_id = v_a AND flashcard_id = v_kill;
  INSERT INTO _r VALUES ('atomicity: killed call left NO reviews row [CRITICAL]', '0', v_int::text,
    CASE WHEN v_int = 0 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_int FROM public.review_events WHERE flashcard_id = v_kill;
  INSERT INTO _r VALUES ('atomicity: killed call left NO review_events row [CRITICAL]', '0', v_int::text,
    CASE WHEN v_int = 0 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;

-- ── zero client grants on review_events (checked outside impersonation) ────
SELECT
  has_table_privilege('anon', 'public.review_events', 'SELECT')         AS anon_can_select,
  has_table_privilege('authenticated', 'public.review_events', 'SELECT') AS authenticated_can_select,
  has_table_privilege('authenticated', 'public.review_events', 'INSERT') AS authenticated_can_insert;
-- expect: false / false / false for all three

ROLLBACK;
