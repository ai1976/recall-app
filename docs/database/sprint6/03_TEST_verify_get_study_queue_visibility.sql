-- Name: [TEST] Verify get_study_queue visibility branches — friends / private / own
-- Description:
--   Sprint 6.0 follow-up. 02_TEST only exercised the PUBLIC + OWN-CARD branches of
--   get_study_queue's visibility guard. This file exercises the two remaining branches:
--     • friends-visible card of another user  -> in the queue ONLY with an accepted friendship
--     • private card of another user          -> NEVER in the queue, even with a due review row
--   plus a reverse-direction friendship check and a "flip to public" control.
--
--   Same idiom as 02_TEST: impersonate a real student via request.jwt.claims, all fixtures
--   (flashcards, reviews, friendships) inside BEGIN...ROLLBACK — nothing is committed.
--   NO persistent DDL here (get_study_queue is created by 01), so the single-txn ROLLBACK is safe.
--
--   Run AFTER 01 is deployed. Expect every row PASS. A SKIP row means the DB had < 2 students.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid;
  v_course text;
  v_card_friends uuid;
  v_card_private uuid;
  v_cnt int;
BEGIN
  -- ── Fixtures ───────────────────────────────────────────────────────────────
  -- A = the studying user (needs a course so the course filter passes). B = the card owner.
  SELECT id, course_level INTO v_a, v_course
  FROM public.profiles
  WHERE role = 'student' AND course_level IS NOT NULL
  LIMIT 1;

  SELECT id INTO v_b
  FROM public.profiles
  WHERE role = 'student' AND id <> v_a
  LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL THEN
    INSERT INTO _r VALUES ('fixtures','2 students w/ course','missing','SKIP');
    RETURN;
  END IF;

  -- Start from a known-clean friend graph between A and B (rolled back with everything else).
  DELETE FROM public.friendships
  WHERE (user_id = v_a AND friend_id = v_b)
     OR (user_id = v_b AND friend_id = v_a);

  -- B owns one friends-visible and one private card, both IN A's course, both non-concept
  -- (question_type omitted -> defaults to 'flashcard').
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_b, v_course, 'S6 FRIENDS front', 'S6 FRIENDS back', 'friends', 'manual')
  RETURNING id INTO v_card_friends;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, source)
  VALUES (v_b, v_course, 'S6 PRIVATE front', 'S6 PRIVATE back', 'private', 'manual')
  RETURNING id INTO v_card_private;

  -- A has a DUE review row on BOTH cards (yesterday, active, no skip)
  INSERT INTO public.reviews (user_id, flashcard_id, quality, easiness, interval, repetition,
                              next_review_date, status)
  VALUES (v_a, v_card_friends, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active'),
         (v_a, v_card_private, 3, 2.5, 1, 1, CURRENT_DATE - 1, 'active');

  -- Impersonate A for every get_study_queue call below
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- ── 1. Friends card is ABSENT when there is no friendship ─────────────────
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_friends;
  INSERT INTO _r VALUES ('friends card absent, NO friendship [CRITICAL]','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 2. Accepted friendship (A -> B) makes the friends card APPEAR ─────────
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (v_a, v_b, 'accepted');
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_friends;
  INSERT INTO _r VALUES ('friends card present, accepted friendship [CRITICAL]','1',v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 3. Pending (not accepted) friendship -> friends card ABSENT again ─────
  UPDATE public.friendships SET status = 'pending'
    WHERE user_id = v_a AND friend_id = v_b;
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_friends;
  INSERT INTO _r VALUES ('friends card absent, friendship pending [CRITICAL]','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 4. Reverse-direction accepted friendship (B -> A) also counts ────────
  DELETE FROM public.friendships WHERE user_id = v_a AND friend_id = v_b;
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (v_b, v_a, 'accepted');
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_friends;
  INSERT INTO _r VALUES ('friends card present, reverse-direction friendship','1',v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 5. PRIVATE card of another user -> NEVER in the queue (friendship active) ─
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_private;
  INSERT INTO _r VALUES ('private card of another user excluded [CRITICAL]','0',v_cnt::text,
    CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 6. Control: flip that same private card to public -> it appears ──────
  --     (proves the review row was otherwise due; exclusion in #5 was purely visibility)
  UPDATE public.flashcards SET visibility = 'public' WHERE id = v_card_private;
  SELECT count(*) INTO v_cnt FROM public.get_study_queue(v_a) WHERE flashcard_id = v_card_private;
  INSERT INTO _r VALUES ('same card appears once public (control)','1',v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
