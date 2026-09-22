-- Name: [TEST] Verify Sprint 8.7.8b — My Cards enrollment + Practice attempts RPCs
--
-- Description: Post-deploy verification for add_to_my_cards / remove_from_my_cards / get_my_cards /
-- log_practice_attempt. Follows the established pattern (docs/database/security/11_TEST...): TEMP
-- table `_r` of (check_name, expected, actual, verdict), impersonation via
-- set_config('request.jwt.claims', ...), everything inside BEGIN...ROLLBACK so no fixture or
-- disposable row survives. Uses two REAL existing student profiles as v_a (self) / v_b (other
-- student, whose content v_a will try to reach) and inserts DISPOSABLE flashcards/reviews/
-- friendships as needed for specific states — all rolled back at the end.
--
-- Run this whole file in one Supabase SQL Editor execution. Do not mix this with persistent DDL in
-- the same run (L3 17c lesson — one transaction per run).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid;
  v_course text;
  v_card_public uuid; v_card_private uuid; v_card_friends uuid; v_card_own uuid;
  v_card_mcq uuid; v_card_mcq_multi uuid; v_card_theory uuid; v_card_fitb uuid; v_card_concept uuid;
  v_err text;
  v_removed boolean;
  v_status text;
  v_attempt_id bigint;
  v_cnt int;
  v_before int; v_after int;
BEGIN
  SELECT id INTO v_a FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_b FROM public.profiles WHERE role = 'student' AND id <> v_a LIMIT 1;
  SELECT target_course INTO v_course FROM public.flashcards WHERE target_course IS NOT NULL LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '2 students', 'missing', 'SKIP: need 2 students');
    RETURN;
  END IF;

  -- Disposable fixtures: cards owned by v_b (the "external" author from v_a's perspective).
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_b, v_course, '8.7.8b test — public', 'back', 'public', 'flashcard') RETURNING id INTO v_card_public;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_b, v_course, '8.7.8b test — private', 'back', 'private', 'flashcard') RETURNING id INTO v_card_private;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_b, v_course, '8.7.8b test — friends-only', 'back', 'friends', 'flashcard') RETURNING id INTO v_card_friends;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_a, v_course, '8.7.8b test — own', 'back', 'private', 'flashcard') RETURNING id INTO v_card_own;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, options, correct_answer)
  VALUES (v_b, v_course, '8.7.8b test — mcq', 'opt0', 'public', 'mcq', '["opt0","opt1"]'::jsonb, '0') RETURNING id INTO v_card_mcq;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, options, correct_answer)
  VALUES (v_b, v_course, '8.7.8b test — mcq_multi', 'opt0', 'public', 'mcq_multi', '["opt0","opt1"]'::jsonb, '0') RETURNING id INTO v_card_mcq_multi;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, subtype)
  VALUES (v_b, v_course, '8.7.8b test — theory', 'back', 'public', 'theory', 'pure_theory') RETURNING id INTO v_card_theory;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_b, v_course, '8.7.8b test — fitb', 'back', 'public', 'fitb') RETURNING id INTO v_card_fitb;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_b, v_course, '8.7.8b test — concept', 'back', 'public', 'concept_card') RETURNING id INTO v_card_concept;

  -- ═══════════════════════════════════ SECURITY / IDOR ═══════════════════════════════════
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  BEGIN PERFORM * FROM public.add_to_my_cards(v_b, v_card_public);
    INSERT INTO _r VALUES ('add_to_my_cards cross-user [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('add_to_my_cards cross-user [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM * FROM public.remove_from_my_cards(v_b, v_card_public);
    INSERT INTO _r VALUES ('remove_from_my_cards cross-user [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('remove_from_my_cards cross-user [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM * FROM public.get_my_cards(v_b);
    INSERT INTO _r VALUES ('get_my_cards cross-user [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_my_cards cross-user [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM * FROM public.log_practice_attempt(v_b, v_card_public, true);
    INSERT INTO _r VALUES ('log_practice_attempt cross-user [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('log_practice_attempt cross-user [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Inaccessible (private, not-own) card blocked for add_to_my_cards / log_practice_attempt.
  BEGIN PERFORM * FROM public.add_to_my_cards(v_a, v_card_private);
    INSERT INTO _r VALUES ('add_to_my_cards private-other-user card [CRITICAL]', 'Card not accessible', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('add_to_my_cards private-other-user card [CRITICAL]', 'Card not accessible', left(v_err,30),
      CASE WHEN v_err ILIKE '%not accessible%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM * FROM public.log_practice_attempt(v_a, v_card_private, true);
    INSERT INTO _r VALUES ('log_practice_attempt private-other-user card [CRITICAL]', 'Card not accessible', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('log_practice_attempt private-other-user card [CRITICAL]', 'Card not accessible', left(v_err,30),
      CASE WHEN v_err ILIKE '%not accessible%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Allowed external (public) card succeeds for both.
  BEGIN PERFORM * FROM public.add_to_my_cards(v_a, v_card_public);
    INSERT INTO _r VALUES ('add_to_my_cards public card allowed', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('add_to_my_cards public card allowed', 'ok', left(v_err,30), 'FAIL: '||v_err); END;
  PERFORM public.remove_from_my_cards(v_a, v_card_public); -- reset for enrollment section below

  -- v_card_public is question_type='flashcard' (self-graded, D-13) — is_correct must be NULL here.
  BEGIN PERFORM * FROM public.log_practice_attempt(v_a, v_card_public, NULL);
    INSERT INTO _r VALUES ('log_practice_attempt public card allowed', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('log_practice_attempt public card allowed', 'ok', left(v_err,30), 'FAIL: '||v_err); END;

  -- Unauthenticated / NULL session — matches the hardened project pattern (RAISE, not silent 0 rows).
  PERFORM set_config('request.jwt.claims', NULL, true);
  BEGIN PERFORM * FROM public.get_my_cards(v_a);
    INSERT INTO _r VALUES ('get_my_cards NULL session [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_my_cards NULL session [CRITICAL]', 'Access denied', left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ═══════════════════════════════════ ENROLLMENT ═══════════════════════════════════
  DELETE FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;

  PERFORM public.add_to_my_cards(v_a, v_card_public);
  SELECT count(*) INTO v_cnt FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public AND status = 'active';
  INSERT INTO _r VALUES ('first add inserts one active row', '1', v_cnt::text, CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  BEGIN
    PERFORM public.add_to_my_cards(v_a, v_card_public); -- second add, idempotent, no 23505
    SELECT count(*) INTO v_cnt FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;
    INSERT INTO _r VALUES ('second add idempotent, no duplicate', '1', v_cnt::text, CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('second add idempotent, no duplicate [CRITICAL]', '1, no error', 'error: '||SQLERRM, 'FAIL');
  END;

  -- ═══════════════════════════════════ REMOVE — NEVER GRADED ═══════════════════════════════════
  SELECT status INTO v_status FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;
  SELECT removed INTO v_removed FROM public.remove_from_my_cards(v_a, v_card_public);
  SELECT status INTO v_status FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;
  SELECT count(*) INTO v_cnt FROM public.reviews WHERE user_id = v_a AND flashcard_id = v_card_public;
  INSERT INTO _r VALUES ('remove (never graded): membership -> removed', 'removed', v_status, CASE WHEN v_status = 'removed' THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('remove (never graded): no reviews row created [CRITICAL]', '0', v_cnt::text, CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- Remove on a never-enrolled pair: stable no-op, never touches an unrelated review.
  DELETE FROM public.reviews WHERE user_id = v_a AND flashcard_id = v_card_friends; -- ensure clean slate (should already be none)
  SELECT removed INTO v_removed FROM public.remove_from_my_cards(v_a, v_card_friends);
  INSERT INTO _r VALUES ('remove on never-enrolled pair is a stable no-op', 'false', v_removed::text, CASE WHEN v_removed = false THEN 'PASS' ELSE 'FAIL' END);

  -- ═══════════════════════════════════ REMOVE — ALREADY GRADED (active) ═══════════════════════════════════
  PERFORM public.add_to_my_cards(v_a, v_card_public);
  INSERT INTO public.reviews (user_id, flashcard_id, quality, interval, repetition, easiness, rung, next_review_date, status)
  VALUES (v_a, v_card_public, 5, 3, 1, 2.6, 2, CURRENT_DATE + 3, 'active')
  ON CONFLICT (user_id, flashcard_id) DO UPDATE SET quality=5, interval=3, repetition=1, easiness=2.6, rung=2, next_review_date=CURRENT_DATE+3, status='active';

  SELECT removed INTO v_removed FROM public.remove_from_my_cards(v_a, v_card_public);
  SELECT count(*) INTO v_cnt FROM public.reviews WHERE user_id = v_a AND flashcard_id = v_card_public;
  SELECT status INTO v_status FROM public.reviews WHERE user_id = v_a AND flashcard_id = v_card_public;
  INSERT INTO _r VALUES ('remove (graded, active): exactly one reviews row remains', '1', v_cnt::text, CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('remove (graded, active): status -> suspended [CRITICAL]', 'suspended', v_status, CASE WHEN v_status = 'suspended' THEN 'PASS' ELSE 'FAIL' END);

  BEGIN
    PERFORM 1 FROM public.reviews WHERE user_id=v_a AND flashcard_id=v_card_public AND repetition=1 AND easiness=2.6 AND rung=2;
    IF FOUND THEN
      INSERT INTO _r VALUES ('remove (graded): rung/repetition/easiness preserved [CRITICAL]', 'unchanged', 'unchanged', 'PASS');
    ELSE
      INSERT INTO _r VALUES ('remove (graded): rung/repetition/easiness preserved [CRITICAL]', 'unchanged', 'CHANGED', 'FAIL');
    END IF;
  END;

  SELECT status INTO v_status FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;
  INSERT INTO _r VALUES ('remove (graded): membership -> removed', 'removed', v_status, CASE WHEN v_status = 'removed' THEN 'PASS' ELSE 'FAIL' END);

  -- ═══════════════════════════════════ RE-ADD AFTER REMOVE ═══════════════════════════════════
  PERFORM public.add_to_my_cards(v_a, v_card_public);
  SELECT status INTO v_status FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;
  SELECT count(*) INTO v_cnt FROM public.my_cards_enrollment WHERE user_id = v_a AND flashcard_id = v_card_public;
  INSERT INTO _r VALUES ('re-add: membership -> active, no duplicate row', 'active / 1', v_status||' / '||v_cnt, CASE WHEN v_status = 'active' AND v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT r.status INTO v_status FROM public.reviews r WHERE user_id=v_a AND flashcard_id=v_card_public;
  INSERT INTO _r VALUES ('re-add: paired reviews row resumed to active [CRITICAL]', 'active', v_status, CASE WHEN v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);
  BEGIN
    PERFORM 1 FROM public.reviews WHERE user_id=v_a AND flashcard_id=v_card_public AND repetition=1 AND easiness=2.6 AND rung=2 AND next_review_date=CURRENT_DATE;
    INSERT INTO _r VALUES ('re-add: rung/repetition/easiness preserved, next_review_date=today (unsuspend_card semantics)', 'preserved', CASE WHEN FOUND THEN 'preserved' ELSE 'CHANGED' END, CASE WHEN FOUND THEN 'PASS' ELSE 'FAIL' END);
  END;

  -- ═══════════════════════════════════ PAUSE-VS-REMOVE DISTINCTION [CRITICAL] ═══════════════════════════════════
  -- Membership already active; reviews.status='suspended' because the card is Paused (not Removed).
  PERFORM public.suspend_card(v_a, v_card_public); -- Pause: membership stays active, reviews -> suspended
  SELECT status INTO v_status FROM public.my_cards_enrollment WHERE user_id=v_a AND flashcard_id=v_card_public;
  INSERT INTO _r VALUES ('pause setup: membership still active', 'active', v_status, CASE WHEN v_status='active' THEN 'PASS' ELSE 'FAIL' END);

  PERFORM public.add_to_my_cards(v_a, v_card_public); -- calling Add again must NOT resume the Pause
  SELECT status INTO v_status FROM public.reviews WHERE user_id=v_a AND flashcard_id=v_card_public;
  INSERT INTO _r VALUES ('add_to_my_cards on active-membership Paused card does NOT resume it [CRITICAL]', 'suspended', v_status, CASE WHEN v_status='suspended' THEN 'PASS' ELSE 'FAIL' END);

  -- ═══════════════════════════════════ get_my_cards COMPOSITION ═══════════════════════════════════
  DELETE FROM public.my_cards_enrollment WHERE user_id = v_a; -- clean slate
  DELETE FROM public.reviews WHERE user_id = v_a AND flashcard_id IN (v_card_public, v_card_private, v_card_friends, v_card_own);

  PERFORM public.add_to_my_cards(v_a, v_card_public); -- enrolled, visible -> should appear

  SELECT count(*) INTO v_cnt FROM public.get_my_cards(v_a) WHERE id = v_card_own;
  INSERT INTO _r VALUES ('get_my_cards includes own card', '1', v_cnt::text, CASE WHEN v_cnt=1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_cnt FROM public.get_my_cards(v_a) WHERE id = v_card_public;
  INSERT INTO _r VALUES ('get_my_cards includes active enrolled visible external card', '1', v_cnt::text, CASE WHEN v_cnt=1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_cnt FROM public.get_my_cards(v_a) WHERE id = v_card_private;
  INSERT INTO _r VALUES ('get_my_cards excludes unrelated never-enrolled private card', '0', v_cnt::text, CASE WHEN v_cnt=0 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM public.remove_from_my_cards(v_a, v_card_public);
  SELECT count(*) INTO v_cnt FROM public.get_my_cards(v_a) WHERE id = v_card_public;
  INSERT INTO _r VALUES ('get_my_cards excludes removed enrollment [CRITICAL]', '0', v_cnt::text, CASE WHEN v_cnt=0 THEN 'PASS' ELSE 'FAIL' END);

  -- Enrolled-then-visibility-revoked (public -> private after enrollment): must not surface.
  PERFORM public.add_to_my_cards(v_a, v_card_public);
  UPDATE public.flashcards SET visibility = 'private' WHERE id = v_card_public;
  SELECT count(*) INTO v_cnt FROM public.get_my_cards(v_a) WHERE id = v_card_public;
  INSERT INTO _r VALUES ('get_my_cards excludes enrolled card that went private after add [CRITICAL]', '0', v_cnt::text, CASE WHEN v_cnt=0 THEN 'PASS' ELSE 'FAIL' END);
  UPDATE public.flashcards SET visibility = 'public' WHERE id = v_card_public; -- restore for any later checks

  SELECT count(*) INTO v_cnt FROM public.get_my_cards(v_a) WHERE id = v_card_own;
  INSERT INTO _r VALUES ('get_my_cards no duplicate row for own card', '1', v_cnt::text, CASE WHEN v_cnt=1 THEN 'PASS' ELSE 'FAIL' END);

  -- ═══════════════════════════════════ PRACTICE ATTEMPTS ═══════════════════════════════════
  SELECT count(*) INTO v_before FROM public.practice_attempts WHERE user_id = v_a;

  -- mcq: valid boolean accepted
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_mcq, true);
    INSERT INTO _r VALUES ('log_practice_attempt mcq true accepted', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN INSERT INTO _r VALUES ('log_practice_attempt mcq true accepted', 'ok', SQLERRM, 'FAIL'); END;

  -- mcq: NULL rejected (graded type requires boolean)
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_mcq, NULL);
    INSERT INTO _r VALUES ('log_practice_attempt mcq NULL rejected', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('log_practice_attempt mcq NULL rejected', 'error', 'error', 'PASS'); END;

  -- mcq_multi: valid boolean accepted
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_mcq_multi, false);
    INSERT INTO _r VALUES ('log_practice_attempt mcq_multi false accepted', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN INSERT INTO _r VALUES ('log_practice_attempt mcq_multi false accepted', 'ok', SQLERRM, 'FAIL'); END;

  -- theory: NULL accepted
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_theory, NULL);
    INSERT INTO _r VALUES ('log_practice_attempt theory NULL accepted', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN INSERT INTO _r VALUES ('log_practice_attempt theory NULL accepted', 'ok', SQLERRM, 'FAIL'); END;

  -- theory: non-NULL rejected
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_theory, true);
    INSERT INTO _r VALUES ('log_practice_attempt theory non-NULL rejected', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('log_practice_attempt theory non-NULL rejected', 'error', 'error', 'PASS'); END;

  -- fitb: TRUE accepted, NULL accepted, FALSE rejected (D-13)
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_fitb, true);
    INSERT INTO _r VALUES ('log_practice_attempt fitb TRUE accepted', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN INSERT INTO _r VALUES ('log_practice_attempt fitb TRUE accepted', 'ok', SQLERRM, 'FAIL'); END;

  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_fitb, NULL);
    INSERT INTO _r VALUES ('log_practice_attempt fitb NULL accepted', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN INSERT INTO _r VALUES ('log_practice_attempt fitb NULL accepted', 'ok', SQLERRM, 'FAIL'); END;

  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_fitb, false);
    INSERT INTO _r VALUES ('log_practice_attempt fitb FALSE rejected (D-13) [CRITICAL]', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('log_practice_attempt fitb FALSE rejected (D-13) [CRITICAL]', 'error', 'error', 'PASS'); END;

  -- concept_card: rejected / not logged
  BEGIN PERFORM public.log_practice_attempt(v_a, v_card_concept, NULL);
    INSERT INTO _r VALUES ('log_practice_attempt concept_card rejected', 'error', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('log_practice_attempt concept_card rejected', 'error', 'error', 'PASS'); END;

  SELECT count(*) INTO v_after FROM public.practice_attempts WHERE user_id = v_a;
  INSERT INTO _r VALUES ('practice_attempts count: +5 for the 5 accepted attempts above', (v_before+5)::text, v_after::text, CASE WHEN v_after = v_before + 5 THEN 'PASS' ELSE 'FAIL' END);

  -- ═══════════════ SIDE-EFFECT ISOLATION: log_practice_attempt touches nothing else ═══════════════
  SELECT count(*) INTO v_before FROM public.reviews WHERE user_id = v_a;
  PERFORM public.log_practice_attempt(v_a, v_card_mcq, true);
  SELECT count(*) INTO v_after FROM public.reviews WHERE user_id = v_a;
  INSERT INTO _r VALUES ('log_practice_attempt: reviews row count unchanged [CRITICAL]', v_before::text, v_after::text, CASE WHEN v_before = v_after THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_before FROM public.review_events WHERE user_id = v_a;
  PERFORM public.log_practice_attempt(v_a, v_card_mcq, true);
  SELECT count(*) INTO v_after FROM public.review_events WHERE user_id = v_a;
  INSERT INTO _r VALUES ('log_practice_attempt: review_events row count unchanged [CRITICAL]', v_before::text, v_after::text, CASE WHEN v_before = v_after THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_before FROM public.user_badges WHERE user_id = v_a;
  PERFORM public.log_practice_attempt(v_a, v_card_mcq, true);
  SELECT count(*) INTO v_after FROM public.user_badges WHERE user_id = v_a;
  INSERT INTO _r VALUES ('log_practice_attempt: user_badges row count unchanged [CRITICAL]', v_before::text, v_after::text, CASE WHEN v_before = v_after THEN 'PASS' ELSE 'FAIL' END);

  SELECT public.get_user_streak(v_a) INTO v_before;
  PERFORM public.log_practice_attempt(v_a, v_card_mcq, true);
  SELECT public.get_user_streak(v_a) INTO v_after;
  INSERT INTO _r VALUES ('log_practice_attempt: get_user_streak unchanged [CRITICAL]', v_before::text, v_after::text, CASE WHEN v_before = v_after THEN 'PASS' ELSE 'FAIL' END);

  -- Enrollment/remove writes touch nothing outside reviews + my_cards_enrollment either.
  SELECT count(*) INTO v_before FROM public.review_events WHERE user_id = v_a;
  PERFORM public.remove_from_my_cards(v_a, v_card_mcq); -- no-op (never enrolled) but exercise the path
  SELECT count(*) INTO v_after FROM public.review_events WHERE user_id = v_a;
  INSERT INTO _r VALUES ('remove_from_my_cards: review_events unchanged', v_before::text, v_after::text, CASE WHEN v_before = v_after THEN 'PASS' ELSE 'FAIL' END);

END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- Separate, read-only ACL/search_path confirmation — run standalone (not inside the above
-- transaction) any time after deployment to document/compare the four functions' final ACLs.
-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- SELECT p.proname, p.prosecdef AS security_definer, p.proconfig AS search_path_setting,
--        pg_get_userbyid(p.proowner) AS owner,
--        (SELECT array_agg(acl::text) FROM aclexplode(p.proacl) acl) AS grants
-- FROM pg_proc p
-- WHERE p.proname IN ('add_to_my_cards','remove_from_my_cards','get_my_cards','log_practice_attempt')
--   AND p.pronamespace = 'public'::regnamespace;
