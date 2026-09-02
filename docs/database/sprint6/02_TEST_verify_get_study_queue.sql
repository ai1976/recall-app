-- Name: [TEST] Verify get_study_queue — IDOR guard, concept-card exclusion, course filter, non-mutation
-- Description: Post-deploy verification for 01_FUNCTIONS_get_study_queue.sql. Impersonates a real
-- student via request.jwt.claims (same idiom as security/11_TEST). All fixtures + the temporary
-- course_level flip are wrapped in BEGIN...ROLLBACK — nothing is committed, reviews rows are
-- restored, so this doubles as the "course switch is reversible / non-destructive" proof.
-- NO persistent DDL in this file (the function is created by 01) so the single-txn ROLLBACK is safe.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid;
  v_card_pub  uuid; v_course text;
  v_concept   uuid;
  v_nrd_before date; v_nrd_after date;
  v_cnt int; v_err text;
BEGIN
  -- ── Fixtures ───────────────────────────────────────────────────────────────
  SELECT id INTO v_a FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_b FROM public.profiles WHERE role = 'student' AND id <> v_a LIMIT 1;

  SELECT id, target_course INTO v_card_pub, v_course
  FROM public.flashcards
  WHERE visibility = 'public' AND question_type <> 'concept_card' AND target_course IS NOT NULL
  LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL OR v_card_pub IS NULL THEN
    INSERT INTO _r VALUES ('fixtures','2 students + 1 public card','missing','SKIP');
    RETURN;
  END IF;

  -- Give A a DUE review row on the public card, and align A's course so it matches.
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition,
                              next_review_date, status)
  VALUES (v_a, v_card_pub, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active')
  ON CONFLICT (user_id, flashcard_id)
    DO UPDATE SET next_review_date = CURRENT_DATE - 1, status = 'active', skip_until = NULL;

  UPDATE public.profiles SET course_level = v_course WHERE id = v_a;

  -- A concept_card owned by A, also "due" — must never appear in the queue.
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility,
                                 question_type, source)
  VALUES (v_a, v_course, 'CONCEPT front', 'CONCEPT back', 'private', 'concept_card', 'manual')
  RETURNING id INTO v_concept;

  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition,
                              next_review_date, status)
  VALUES (v_a, v_concept, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active');

  -- ── 1. Cross-user call RAISEs (impersonate A, ask for B's queue) ───────────
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  BEGIN
    PERFORM * FROM public.get_study_queue(v_b);
    INSERT INTO _r VALUES ('cross-user call [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('cross-user call [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ── 2. NULL session RAISEs ────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims', NULL, true);
  BEGIN
    PERFORM * FROM public.get_study_queue(v_a);
    INSERT INTO _r VALUES ('null-session call [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('null-session call [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- ── 3. Self call returns the due public card ──────────────────────────────
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_pub;
  INSERT INTO _r VALUES ('self call returns due card','1',v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 4. Concept card excluded ─────────────────────────────────────────────
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_concept;
  INSERT INTO _r VALUES ('concept_card excluded [CRITICAL]','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 5. Course filter — card in a non-matching course is absent ────────────
  UPDATE public.flashcards SET target_course = 'ZZZ_SPRINT6_NOMATCH' WHERE id = v_card_pub;
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_pub;
  INSERT INTO _r VALUES ('non-matching course filtered out [CRITICAL]','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 6. Null-course student sees everything ───────────────────────────────
  UPDATE public.profiles SET course_level = NULL WHERE id = v_a;
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_pub;
  INSERT INTO _r VALUES ('null course_level -> no filter','1',v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 7. skip_until in the future excludes the card ───────────────────────
  UPDATE public.profiles SET course_level = v_course WHERE id = v_a;
  UPDATE public.flashcards SET target_course = v_course WHERE id = v_card_pub;
  UPDATE public.reviews SET skip_until = CURRENT_DATE + 1
    WHERE user_id = v_a AND flashcard_id = v_card_pub;
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_pub;
  INSERT INTO _r VALUES ('future skip_until excluded','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 8. suspended status excludes the card ──────────────────────────────
  UPDATE public.reviews SET skip_until = NULL, status = 'suspended'
    WHERE user_id = v_a AND flashcard_id = v_card_pub;
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_pub;
  INSERT INTO _r VALUES ('suspended status excluded','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 9. Non-mutation: the RPC never writes to reviews ───────────────────
  UPDATE public.reviews SET status = 'active' WHERE user_id = v_a AND flashcard_id = v_card_pub;
  SELECT next_review_date INTO v_nrd_before FROM public.reviews
    WHERE user_id = v_a AND flashcard_id = v_card_pub;
  PERFORM * FROM public.get_study_queue(v_a);
  SELECT next_review_date INTO v_nrd_after FROM public.reviews
    WHERE user_id = v_a AND flashcard_id = v_card_pub;
  INSERT INTO _r VALUES ('reviews row unchanged after call [CRITICAL]',
    v_nrd_before::text, v_nrd_after::text,
    CASE WHEN v_nrd_before = v_nrd_after THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
