-- Name: [TEST] Verify get_browsable_decks v6 — has_concept_card flag
-- Description: Post-deploy verification for 01_FUNCTIONS_get_browsable_decks_v6_has_concept_card.sql.
-- Impersonates a real student via request.jwt.claims (same idiom as sprint6/02_TEST). All fixtures
-- (a throwaway deck with one concept_card row + one gradeable row) are wrapped in BEGIN...ROLLBACK —
-- nothing is committed. Confirms: (1) the new column is present and correctly true for a mixed deck,
-- (2) a deck with no concept_card row still returns has_concept_card = false (not NULL, not an error),
-- (3) the pre-existing p_question_type filter and visible_card_count behavior are unchanged (the v5
-- regression surface), (4) NULL session still RAISEs (unauthenticated callers must never reach this).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_student uuid;
  v_deck_mixed uuid; v_deck_plain uuid;
  v_subject_id uuid; v_topic_id uuid;
  v_concept_card_id uuid; v_flash_card_id uuid; v_plain_card_id uuid;
  v_has_concept boolean; v_cnt int; v_err text;
BEGIN
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_subject_id FROM public.subjects LIMIT 1;
  SELECT id INTO v_topic_id FROM public.topics WHERE subject_id = v_subject_id LIMIT 1;

  IF v_student IS NULL OR v_subject_id IS NULL OR v_topic_id IS NULL THEN
    INSERT INTO _r VALUES ('fixtures','1 student + 1 subject/topic','missing','SKIP');
    RETURN;
  END IF;

  -- Deck A: mixed — one concept_card + one gradeable flashcard, both public, owned by v_student.
  INSERT INTO public.flashcard_decks (user_id, subject_id, topic_id, target_course, visibility, card_count, upvote_count)
  VALUES (v_student, v_subject_id, v_topic_id, 'ZZZ_SPRINT712_TEST', 'public', 0, 0)
  RETURNING id INTO v_deck_mixed;

  INSERT INTO public.flashcards (user_id, subject_id, topic_id, target_course, front_text, back_text,
                                  visibility, question_type, options)
  VALUES (v_student, v_subject_id, v_topic_id, 'ZZZ_SPRINT712_TEST', 'CONCEPT front', 'CONCEPT summary',
          'public', 'concept_card', '[{"term":"SM-2","definition":"A spaced repetition algorithm"}]'::jsonb)
  RETURNING id INTO v_concept_card_id;

  INSERT INTO public.flashcards (user_id, subject_id, topic_id, target_course, front_text, back_text,
                                  visibility, question_type)
  VALUES (v_student, v_subject_id, v_topic_id, 'ZZZ_SPRINT712_TEST', 'FLASH front', 'FLASH back',
          'public', 'flashcard')
  RETURNING id INTO v_flash_card_id;

  -- Deck B: plain — one flashcard, no concept_card, different topic so it doesn't collide with Deck A.
  INSERT INTO public.flashcard_decks (user_id, subject_id, topic_id, target_course, visibility, card_count, upvote_count)
  VALUES (v_student, v_subject_id, NULL, 'ZZZ_SPRINT712_TEST', 'public', 0, 0)
  RETURNING id INTO v_deck_plain;

  INSERT INTO public.flashcards (user_id, subject_id, topic_id, target_course, front_text, back_text,
                                  visibility, question_type)
  VALUES (v_student, v_subject_id, NULL, 'ZZZ_SPRINT712_TEST', 'PLAIN front', 'PLAIN back',
          'public', 'flashcard')
  RETURNING id INTO v_plain_card_id;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_student, 'role', 'authenticated')::text, true);

  -- ── 1. Mixed deck reports has_concept_card = true ─────────────────────────
  SELECT has_concept_card INTO v_has_concept
  FROM public.get_browsable_decks() WHERE id = v_deck_mixed;
  INSERT INTO _r VALUES ('mixed deck has_concept_card = true [CRITICAL]','true',
    coalesce(v_has_concept::text,'NULL'),
    CASE WHEN v_has_concept IS TRUE THEN 'PASS' ELSE 'FAIL' END);

  -- ── 2. Plain deck reports has_concept_card = false (not NULL) ────────────
  SELECT has_concept_card INTO v_has_concept
  FROM public.get_browsable_decks() WHERE id = v_deck_plain;
  INSERT INTO _r VALUES ('plain deck has_concept_card = false','false',
    coalesce(v_has_concept::text,'NULL'),
    CASE WHEN v_has_concept IS FALSE THEN 'PASS' ELSE 'FAIL' END);

  -- ── 3. Mixed deck's visible_card_count still counts BOTH rows (type-agnostic,
  --    unchanged from v5 — has_concept_card must not narrow this) ───────────
  SELECT card_count INTO v_cnt FROM public.get_browsable_decks() WHERE id = v_deck_mixed;
  INSERT INTO _r VALUES ('visible_card_count unchanged (both rows counted) [CRITICAL]','2',v_cnt::text,
    CASE WHEN v_cnt = 2 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 4. p_question_type filter still narrows to the concept_card deck only ─
  SELECT count(*) INTO v_cnt
  FROM public.get_browsable_decks('concept_card') WHERE id IN (v_deck_mixed, v_deck_plain);
  INSERT INTO _r VALUES ('p_question_type=concept_card filter unchanged','1',v_cnt::text,
    CASE WHEN v_cnt = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- ── 5. NULL session RAISEs (unauthenticated callers must never reach this) ─
  PERFORM set_config('request.jwt.claims', NULL, true);
  BEGIN
    PERFORM * FROM public.get_browsable_decks();
    INSERT INTO _r VALUES ('null-session call [CRITICAL]','Not authenticated','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('null-session call [CRITICAL]','Not authenticated',left(v_err,30),
      CASE WHEN v_err ILIKE '%not authenticated%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
