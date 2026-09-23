-- Name: [DATA] Create disposable scenario Practice fixture card
--
-- Description: Hotfix closeout for the missing-scenario defect on get_practice_cards. No live
-- content accessible to the test student (TestOutlook) has a case_study_mcq card in a
-- CA-Intermediate-scoped, accessible deck (the only real ones are CA Final — Advanced Auditing —
-- and blocked by the course gate). Same disposable-fixture pattern as
-- 07_DATA_create_practice_fixture_objective_cards.sql: one minimal, clearly-labeled, disposable
-- public case_study_mcq card under the professor account whose content the test student already
-- sees (075ad481-13e8-45e4-9deb-3c38907eb3e6, "CA Anand More"), scoped to that account's existing
-- target_course so it's actually reachable through the deck-level course gate.
--
-- Fully disposable: 14_CLEANUP_delete_scenario_fixture_card.sql removes the row; the
-- flashcard_decks trigger auto-deletes the auto-created deck row once card_count reaches 0.

INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, scenario, options, correct_answer, explanation, custom_subject)
VALUES (
  '075ad481-13e8-45e4-9deb-3c38907eb3e6',
  (SELECT target_course FROM public.flashcards WHERE user_id = '075ad481-13e8-45e4-9deb-3c38907eb3e6' AND target_course IS NOT NULL LIMIT 1),
  'Based on the scenario, which section governs the deduction Rahul can claim?',
  'n/a',
  'public',
  'case_study_mcq',
  'SCENARIO-FIX-FIXTURE (disposable): Rahul, a salaried individual, paid a health insurance premium of Rs 22,000 for himself and his spouse during FY 2025-26. He also repaid Rs 40,000 towards the principal of a housing loan taken for his self-occupied property. If this scenario renders correctly in Practice Mode, the fix worked.',
  '["12%","18%","28%","5%"]'::jsonb,
  '1',
  '["This is a disposable fixture card for verifying the scenario-column fix on get_practice_cards. The options/answer are placeholders, not meant to be pedagogically meaningful. Safe to delete."]'::jsonb,
  '8.7.8c-fixture-scenario'
);

-- Copy this deck id back to Claude — used as ?deck=<id>&type=case_study_mcq in the Practice Mode URL.
SELECT fc.id AS card_id, fc.question_type, fc.scenario, fd.id AS deck_id, fd.custom_subject
FROM public.flashcards fc
JOIN public.flashcard_decks fd
  ON fc.user_id = fd.user_id
 AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
 AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
 AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
 AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
WHERE fc.custom_subject = '8.7.8c-fixture-scenario';
