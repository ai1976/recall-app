-- Name: [TEST] Verify get_public_deck_preview hides non-public cards
-- Description: Post-deploy verification for 02_FUNCTIONS. Builds a public deck containing one
-- public card and one private card (same owner + grouping columns, so both belong to the same
-- auto-created deck), calls get_public_deck_preview, and asserts the private card's front_text is
-- NOT in the preview while the public one IS, and that card_count reflects public cards only.
-- Self-contained BEGIN...ROLLBACK; row-returning verdict pattern (matches L2 11_TEST / 13_TEST).
-- SQL Editor runs as postgres, but get_public_deck_preview is SECURITY DEFINER and takes only
-- p_deck_id (no auth.uid()), so no role/JWT impersonation is needed. Run AFTER 02_FUNCTIONS.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_user_id uuid;
  v_deck_id uuid;
  v_result  jsonb;
  v_preview jsonb;
  v_count   text;
  v_pub_present  boolean;
  v_priv_present boolean;
BEGIN
  SELECT id INTO v_user_id FROM public.profiles LIMIT 1;
  IF v_user_id IS NULL THEN
    INSERT INTO _r VALUES ('fixture', 'a profile', 'none', 'SKIP: no profile fixture available');
    RETURN;
  END IF;

  -- Two cards, same 5 grouping columns (subject_id/topic_id NULL; custom_* tagged) -> one deck.
  -- Column shape matches L1 06_TEST / L2 11_TEST (proven-good); is_public is intentionally absent
  -- (dropped in L2). One public, one private.
  INSERT INTO public.flashcards
    (user_id, contributed_by, creator_id, target_course, subject_id, topic_id,
     custom_subject, custom_topic, front_text, back_text, visibility, is_verified, difficulty, batch_id)
  VALUES
    (v_user_id, v_user_id, v_user_id, 'test_course', NULL, NULL,
     '_BUGTEST_deck_subj', '_BUGTEST_deck_topic', '_BUGTEST_PUBLIC_CARD',  'x', 'public',  false, 'medium', gen_random_uuid()),
    (v_user_id, v_user_id, v_user_id, 'test_course', NULL, NULL,
     '_BUGTEST_deck_subj', '_BUGTEST_deck_topic', '_BUGTEST_PRIVATE_CARD', 'x', 'private', false, 'medium', gen_random_uuid());

  -- Find the auto-created deck (trigger_update_deck_card_count creates it on first insert) and
  -- force it public so the preview precondition (fd.visibility='public') is guaranteed.
  SELECT id INTO v_deck_id
  FROM public.flashcard_decks
  WHERE user_id = v_user_id
    AND subject_id IS NULL AND topic_id IS NULL
    AND custom_subject = '_BUGTEST_deck_subj'
    AND custom_topic   = '_BUGTEST_deck_topic';

  IF v_deck_id IS NULL THEN
    INSERT INTO _r VALUES ('deck created', 'a deck row', 'none',
      'FAIL: deck-count trigger did not create a flashcard_decks row for the test cards');
    RETURN;
  END IF;

  UPDATE public.flashcard_decks SET visibility = 'public' WHERE id = v_deck_id;

  -- Call the RPC under test.
  v_result  := public.get_public_deck_preview(v_deck_id);
  v_preview := v_result->'preview_items';
  v_count   := v_result->'deck'->>'card_count';

  v_pub_present := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_preview) e WHERE e->>'front_text' = '_BUGTEST_PUBLIC_CARD');
  v_priv_present := EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_preview) e WHERE e->>'front_text' = '_BUGTEST_PRIVATE_CARD');

  -- Assertions
  INSERT INTO _r VALUES ('public card in preview', 'true', v_pub_present::text,
    CASE WHEN v_pub_present THEN 'PASS' ELSE 'FAIL' END);

  INSERT INTO _r VALUES ('private card in preview [CRITICAL]', 'false', v_priv_present::text,
    CASE WHEN v_priv_present = false THEN 'PASS' ELSE 'FAIL: private card leaked into public preview' END);

  INSERT INTO _r VALUES ('deck card_count (public only)', '1', COALESCE(v_count, 'null'),
    CASE WHEN v_count = '1' THEN 'PASS' ELSE 'FAIL: card_count includes non-public cards' END);
END $$;

-- Single result set (Supabase shows only the LAST set): all verdict rows, failures sorted first.
-- Expect 3 rows, all PASS.
SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, check_name;

ROLLBACK;
