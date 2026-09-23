-- Name: [CLEANUP] Delete disposable scenario Practice fixture card
--
-- Description: Removes the fixture card created by 13_DATA_create_scenario_fixture_card.sql.
-- ON DELETE CASCADE removes any practice_attempts / my_cards_enrollment / reviews / review_events
-- rows created against it during the browser test; trigger_update_deck_card_count auto-deletes the
-- auto-created deck row once its card_count reaches 0. Run only after the scenario has been
-- confirmed rendering correctly in Practice Mode.

DELETE FROM public.flashcards
WHERE custom_subject = '8.7.8c-fixture-scenario';

-- Zero-residue confirmation: both counts below must be 0.
SELECT
  (SELECT count(*) FROM public.flashcards WHERE custom_subject = '8.7.8c-fixture-scenario') AS fixture_cards_remaining,
  (SELECT count(*) FROM public.flashcard_decks WHERE custom_subject = '8.7.8c-fixture-scenario') AS fixture_decks_remaining;
