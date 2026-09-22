-- Name: [TEST] Verify Sprint 8.7.8c — get_practice_cards
--
-- Description: Post-deploy verification for get_practice_cards. Follows the established pattern
-- (docs/database/sprint8.7.8b/03_TEST...sql): TEMP table `_r` of (check_name, expected, actual,
-- verdict), impersonation via set_config('request.jwt.claims', ...), everything inside
-- BEGIN...ROLLBACK so no fixture or disposable row survives (including the add_to_my_cards call
-- used to build the "already-enrolled" fixture, and the friendship/study-group fixtures).
--
-- Picks two REAL existing student profiles that are NOT already accepted friends (so the
-- "inaccessible private card" and "friends-only card" scenarios have a known, uncontaminated
-- starting state), then builds one disposable flashcard per scenario, each in its own deck
-- (distinct custom_subject per card — flashcard_decks auto-creates one deck per unique
-- (user_id, subject_id, topic_id, custom_subject, custom_topic) combo via
-- trigger_update_deck_card_count).
--
-- Run this whole file in one Supabase SQL Editor execution, AFTER 01_FUNCTIONS_get_practice_cards.sql
-- has been deployed. Do not mix with persistent DDL in the same run (L3 17c lesson).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid; v_course text; v_group_id uuid;
  v_card_public uuid; v_deck_public uuid;
  v_card_friend uuid; v_deck_friend uuid;
  v_card_group uuid; v_deck_group uuid;
  v_card_own uuid; v_deck_own uuid;
  v_card_enrolled uuid; v_deck_enrolled uuid;
  v_card_private uuid; v_deck_private uuid;
  v_card_concept uuid;
  v_err text; v_cnt int;
  v_is_own boolean; v_is_enrolled boolean; v_can_add boolean;
BEGIN
  -- Two students, not already accepted friends, so the "friends" fixture below is a clean,
  -- controlled transition and the "private inaccessible" scenario isn't accidentally friend-visible.
  SELECT p1.id, p2.id INTO v_a, v_b
  FROM public.profiles p1
  JOIN public.profiles p2 ON p2.id <> p1.id
  WHERE p1.role = 'student' AND p2.role = 'student'
    AND NOT EXISTS (
      SELECT 1 FROM public.friendships f WHERE f.status = 'accepted'
        AND ((f.user_id = p1.id AND f.friend_id = p2.id) OR (f.friend_id = p1.id AND f.user_id = p2.id))
    )
  LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '2 non-friend students', 'missing', 'SKIP: need 2 non-friend students');
    RETURN;
  END IF;

  SELECT target_course INTO v_course FROM public.flashcards WHERE target_course IS NOT NULL LIMIT 1;

  -- ═══════════════════════════════════ FIXTURES ═══════════════════════════════════
  -- 1. Public external card (v_b), plus a concept_card in the SAME deck — proves concept_card is
  --    excluded even from an otherwise fully-accessible, otherwise-matching deck.
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_b, v_course, '8.7.8c test — public', 'back', 'public', 'flashcard', '8.7.8c-public')
  RETURNING id INTO v_card_public;
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_b, v_course, '8.7.8c test — concept', 'back', 'public', 'concept_card', '8.7.8c-public')
  RETURNING id INTO v_card_concept;
  SELECT id INTO v_deck_public FROM public.flashcard_decks WHERE user_id = v_b AND custom_subject = '8.7.8c-public';

  -- 2. Friends-only card (v_b) + a fresh accepted friendship v_a<->v_b.
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (v_a, v_b, 'accepted');
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_b, v_course, '8.7.8c test — friend', 'back', 'friends', 'flashcard', '8.7.8c-friend')
  RETURNING id INTO v_card_friend;
  SELECT id INTO v_deck_friend FROM public.flashcard_decks WHERE user_id = v_b AND custom_subject = '8.7.8c-friend';

  -- 3. Group-share-only card (v_b, visibility='private', not friends-visible) shared to a group v_a is in.
  INSERT INTO public.study_groups (name, created_by) VALUES ('8.7.8c test group', v_b) RETURNING id INTO v_group_id;
  INSERT INTO public.study_group_members (group_id, user_id, role, status) VALUES (v_group_id, v_a, 'member', 'active');
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_b, v_course, '8.7.8c test — group', 'back', 'private', 'flashcard', '8.7.8c-group')
  RETURNING id INTO v_card_group;
  SELECT id INTO v_deck_group FROM public.flashcard_decks WHERE user_id = v_b AND custom_subject = '8.7.8c-group';
  INSERT INTO public.content_group_shares (group_id, content_type, content_id, shared_by)
  VALUES (v_group_id, 'flashcard_deck', v_deck_group, v_b);

  -- 4. Own card (v_a).
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_a, v_course, '8.7.8c test — own', 'back', 'private', 'flashcard', '8.7.8c-own')
  RETURNING id INTO v_card_own;
  SELECT id INTO v_deck_own FROM public.flashcard_decks WHERE user_id = v_a AND custom_subject = '8.7.8c-own';

  -- 5. Public external card (v_b) that v_a will enroll partway through this test.
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_b, v_course, '8.7.8c test — to-enroll', 'back', 'public', 'flashcard', '8.7.8c-enrolled')
  RETURNING id INTO v_card_enrolled;
  SELECT id INTO v_deck_enrolled FROM public.flashcard_decks WHERE user_id = v_b AND custom_subject = '8.7.8c-enrolled';

  -- 6. Private, not-owned, not-friends-visible, not group-shared card (v_b) — the inaccessible deck.
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, custom_subject)
  VALUES (v_b, v_course, '8.7.8c test — private', 'back', 'private', 'flashcard', '8.7.8c-private')
  RETURNING id INTO v_card_private;
  SELECT id INTO v_deck_private FROM public.flashcard_decks WHERE user_id = v_b AND custom_subject = '8.7.8c-private';

  -- ═══════════════════════════════════ TESTS (as v_a) ═══════════════════════════════════
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- IDOR: v_a cannot fetch Practice cards "for" v_b.
  BEGIN PERFORM * FROM public.get_practice_cards(v_b, v_deck_public);
    INSERT INTO _r VALUES ('get_practice_cards cross-user [CRITICAL]', 'Access denied', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_practice_cards cross-user [CRITICAL]', 'Access denied', left(v_err,40),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Public deck: returns the public card, excludes the concept_card sharing its deck.
  SELECT count(*) FILTER (WHERE gpc.id = v_card_public),
         count(*) FILTER (WHERE gpc.id = v_card_concept)
    INTO v_cnt, v_is_own -- v_is_own reused as scratch int-as-bool below via explicit cast
  FROM public.get_practice_cards(v_a, v_deck_public) gpc;
  INSERT INTO _r VALUES ('public deck returns public card', '1', v_cnt::text, CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_cnt FROM public.get_practice_cards(v_a, v_deck_public) gpc WHERE gpc.id = v_card_concept;
  INSERT INTO _r VALUES ('public deck excludes concept_card [CRITICAL]', '0', v_cnt::text, CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- Explicit concept_card type filter still returns nothing (unconditional exclusion, not just default).
  SELECT count(*) INTO v_cnt FROM public.get_practice_cards(v_a, v_deck_public, 'concept_card');
  INSERT INTO _r VALUES ('explicit concept_card filter still excluded [CRITICAL]', '0', v_cnt::text, CASE WHEN v_cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

  SELECT gpc.is_own, gpc.is_enrolled, gpc.can_add_to_my_cards INTO v_is_own, v_is_enrolled, v_can_add
  FROM public.get_practice_cards(v_a, v_deck_public) gpc WHERE gpc.id = v_card_public;
  INSERT INTO _r VALUES ('public card flags', 'own=f enrolled=f can_add=t',
    format('own=%s enrolled=%s can_add=%s', v_is_own, v_is_enrolled, v_can_add),
    CASE WHEN v_is_own = false AND v_is_enrolled = false AND v_can_add = true THEN 'PASS' ELSE 'FAIL' END);

  -- Friends deck: accessible, can_add = true.
  SELECT count(*), bool_and(gpc.can_add_to_my_cards) INTO v_cnt, v_can_add
  FROM public.get_practice_cards(v_a, v_deck_friend) gpc WHERE gpc.id = v_card_friend;
  INSERT INTO _r VALUES ('accepted-friend card visible + eligible', '1 row, can_add=t',
    format('%s rows, can_add=%s', v_cnt, v_can_add),
    CASE WHEN v_cnt = 1 AND v_can_add = true THEN 'PASS' ELSE 'FAIL' END);

  -- Group-share-only deck: Practice-visible but NOT enrollable [CRITICAL — the core eligibility split].
  SELECT count(*), bool_and(gpc.can_add_to_my_cards), bool_and(gpc.is_own)
    INTO v_cnt, v_can_add, v_is_own
  FROM public.get_practice_cards(v_a, v_deck_group) gpc WHERE gpc.id = v_card_group;
  INSERT INTO _r VALUES ('group-share-only: Practice-visible, can_add=false [CRITICAL]',
    '1 row, can_add=f, own=f', format('%s rows, can_add=%s, own=%s', v_cnt, v_can_add, v_is_own),
    CASE WHEN v_cnt = 1 AND v_can_add = false AND v_is_own = false THEN 'PASS' ELSE 'FAIL' END);

  -- Parity check: the same card that get_practice_cards marks can_add=false must actually be
  -- rejected by add_to_my_cards itself — proves the two predicates agree, not just resemble.
  BEGIN PERFORM * FROM public.add_to_my_cards(v_a, v_card_group);
    INSERT INTO _r VALUES ('eligibility parity: group-share card rejected by add_to_my_cards [CRITICAL]',
      '42501 not accessible', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('eligibility parity: group-share card rejected by add_to_my_cards [CRITICAL]',
      '42501 not accessible', left(v_err,40),
      CASE WHEN v_err ILIKE '%not accessible%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Own card: is_own=true, not counted as enrolled.
  SELECT gpc.is_own, gpc.is_enrolled INTO v_is_own, v_is_enrolled
  FROM public.get_practice_cards(v_a, v_deck_own) gpc WHERE gpc.id = v_card_own;
  INSERT INTO _r VALUES ('own card flags', 'own=t enrolled=f',
    format('own=%s enrolled=%s', v_is_own, v_is_enrolled),
    CASE WHEN v_is_own = true AND v_is_enrolled = false THEN 'PASS' ELSE 'FAIL' END);

  -- Enrollment-state distinction [CRITICAL]: before add, is_enrolled=false; after add_to_my_cards,
  -- is_enrolled=true — this is the exact signal Practice Mode needs to stop offering "Add" again.
  SELECT gpc.is_enrolled INTO v_is_enrolled FROM public.get_practice_cards(v_a, v_deck_enrolled) gpc WHERE gpc.id = v_card_enrolled;
  INSERT INTO _r VALUES ('pre-add: is_enrolled=false', 'false', v_is_enrolled::text, CASE WHEN v_is_enrolled = false THEN 'PASS' ELSE 'FAIL' END);

  PERFORM * FROM public.add_to_my_cards(v_a, v_card_enrolled);

  SELECT gpc.is_enrolled, gpc.can_add_to_my_cards INTO v_is_enrolled, v_can_add
  FROM public.get_practice_cards(v_a, v_deck_enrolled) gpc WHERE gpc.id = v_card_enrolled;
  INSERT INTO _r VALUES ('post-add: is_enrolled=true [CRITICAL]', 'true', v_is_enrolled::text,
    CASE WHEN v_is_enrolled = true THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('post-add: can_add_to_my_cards still reflects predicate (frontend must gate on is_enrolled first)',
    'true', v_can_add::text, CASE WHEN v_can_add = true THEN 'PASS' ELSE 'FAIL' END);

  -- Deck-level access re-check [CRITICAL — amendment 2]: an inaccessible deck raises before any
  -- card-level filtering happens, it does not just return an empty set.
  BEGIN PERFORM * FROM public.get_practice_cards(v_a, v_deck_private);
    INSERT INTO _r VALUES ('inaccessible deck raises, not empty-set [CRITICAL]', '42501 not accessible', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('inaccessible deck raises, not empty-set [CRITICAL]', '42501 not accessible', left(v_err,40),
      CASE WHEN v_err ILIKE '%not accessible%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Same private card is also rejected by add_to_my_cards and log_practice_attempt (already proven
  -- in 8.7.8b's own tests; re-asserted here for this test's own fixture as a sanity cross-check).
  BEGIN PERFORM * FROM public.log_practice_attempt(v_a, v_card_private, NULL);
    INSERT INTO _r VALUES ('private card also rejected by log_practice_attempt', '42501 not accessible', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('private card also rejected by log_practice_attempt', '42501 not accessible', left(v_err,40),
      CASE WHEN v_err ILIKE '%not accessible%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Non-existent deck id behaves the same as inaccessible (no information leak via a different error).
  BEGIN PERFORM * FROM public.get_practice_cards(v_a, gen_random_uuid());
    INSERT INTO _r VALUES ('nonexistent deck raises', '42501 not accessible', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('nonexistent deck raises', '42501 not accessible', left(v_err,40),
      CASE WHEN v_err ILIKE '%not accessible%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

END;
$$;

SELECT * FROM _r ORDER BY (verdict LIKE 'FAIL%') DESC, check_name;

ROLLBACK;
