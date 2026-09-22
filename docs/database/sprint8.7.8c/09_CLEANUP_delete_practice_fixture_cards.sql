-- Name: [CLEANUP] Delete disposable Practice fixture cards
--
-- Description: Removes the two Sprint 8.7.8c fixture cards created by
-- 07_DATA_create_practice_fixture_objective_cards.sql. ON DELETE CASCADE removes any
-- practice_attempts / my_cards_enrollment / reviews / review_events rows created against them
-- during the browser test; trigger_update_deck_card_count auto-deletes the auto-created deck rows
-- once their card_count reaches 0. Run 08_TEST first if you want the before/after side-effect
-- proof; this file's final SELECT re-confirms zero residue afterward.

DELETE FROM public.flashcards
WHERE custom_subject IN ('8.7.8c-fixture-mcq', '8.7.8c-fixture-match');

-- Zero-residue confirmation: every count below must be 0.
SELECT
  (SELECT count(*) FROM public.flashcards WHERE custom_subject IN ('8.7.8c-fixture-mcq', '8.7.8c-fixture-match')) AS fixture_cards_remaining,
  (SELECT count(*) FROM public.flashcard_decks WHERE custom_subject IN ('8.7.8c-fixture-mcq', '8.7.8c-fixture-match')) AS fixture_decks_remaining;
