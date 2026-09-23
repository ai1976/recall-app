-- Name: [DIAGNOSTIC] Find a user_id + deck_id for the scenario fix test
--
-- Description: Finds a real case_study_mcq card that has a non-null scenario, plus its owning
-- deck (via the standard 5-grouping-column join, never flashcards.deck_id, which is NULL for
-- bulk-uploaded cards) and owner user_id. Use the returned user_id/deck_id to fill in
-- 11_TEST_verify_scenario_fix.sql. Prefer a row where card_owner_id = deck_owner_id (the simple,
-- own-content case) to avoid any visibility-predicate complications while testing the scenario fix
-- itself.

SELECT
  fc.id                AS card_id,
  fc.user_id            AS card_owner_id,
  fc.question_type,
  left(fc.scenario, 80) AS scenario_preview,
  fd.id                 AS deck_id,
  fd.user_id             AS deck_owner_id,
  fd.name                AS deck_name
FROM public.flashcards fc
JOIN public.flashcard_decks fd
  ON fd.user_id = fc.user_id
  AND (fd.subject_id     IS NOT DISTINCT FROM fc.subject_id)
  AND (fd.topic_id       IS NOT DISTINCT FROM fc.topic_id)
  AND (fd.custom_subject IS NOT DISTINCT FROM fc.custom_subject)
  AND (fd.custom_topic   IS NOT DISTINCT FROM fc.custom_topic)
WHERE fc.question_type = 'case_study_mcq'
  AND fc.scenario IS NOT NULL
ORDER BY fc.created_at DESC
LIMIT 10;
