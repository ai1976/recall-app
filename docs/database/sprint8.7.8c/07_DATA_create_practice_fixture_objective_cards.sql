-- Name: [DATA] Create disposable objective-type Practice fixture cards
--
-- Description: Sprint 8.7.8c closeout — the highest-risk frontend path (objective wrong-answer in
-- Practice Mode) has no matching content in the live CA Intermediate course to exercise it, so this
-- creates two minimal, clearly-labeled, disposable public cards under the professor account whose
-- content the test student already sees (075ad481-13e8-45e4-9deb-3c38907eb3e6, "CA Anand More"):
-- one 'mcq' and one 'match_the_following', each designed so a straightforward/obvious answer is
-- WRONG, so the test can deliberately trigger the old code's exact former bug (apply_review firing
-- immediately on a wrong tap) and confirm Practice Mode no longer does that.
--
-- Fully disposable: 09_CLEANUP_delete_practice_fixture_cards.sql removes both rows; the
-- flashcard_decks trigger auto-deletes the auto-created deck rows once card_count reaches 0, and
-- ON DELETE CASCADE removes any practice_attempts/my_cards_enrollment/reviews/review_events rows
-- created against them during the test.

INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, options, correct_answer, explanation, custom_subject)
VALUES (
  '075ad481-13e8-45e4-9deb-3c38907eb3e6',
  (SELECT target_course FROM public.flashcards WHERE user_id = '075ad481-13e8-45e4-9deb-3c38907eb3e6' AND target_course IS NOT NULL LIMIT 1),
  '8.7.8c fixture (disposable) — What is the standard rate of GST on most goods and services?',
  'n/a',
  'public',
  'mcq',
  '["12%","18%","28%","5%"]'::jsonb,
  '1',
  '["Correct answer is 18% (index 1). Sprint 8.7.8c disposable test fixture — safe to delete."]'::jsonb,
  '8.7.8c-fixture-mcq'
);

INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type, options, explanation, custom_subject)
VALUES (
  '075ad481-13e8-45e4-9deb-3c38907eb3e6',
  (SELECT target_course FROM public.flashcards WHERE user_id = '075ad481-13e8-45e4-9deb-3c38907eb3e6' AND target_course IS NOT NULL LIMIT 1),
  '8.7.8c fixture (disposable) — Match each section to its deduction',
  'n/a',
  'public',
  'match_the_following',
  '{"left":["Section 80C","Section 80D"],"right":["Health insurance premium","Life insurance / PPF"],"correct":{"0":"1","1":"0"}}'::jsonb,
  '["80C -> Life insurance/PPF (right index 1), 80D -> Health insurance (right index 0) — deliberately crossed so the top-to-top pairing is wrong. Sprint 8.7.8c disposable test fixture — safe to delete."]'::jsonb,
  '8.7.8c-fixture-match'
);

-- Copy these two deck ids back to Claude — used as ?deck=<id> in the Practice Mode URL.
SELECT fc.id AS card_id, fc.question_type, fd.id AS deck_id, fd.custom_subject
FROM public.flashcards fc
JOIN public.flashcard_decks fd
  ON fc.user_id = fd.user_id
 AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
 AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
 AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
 AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
WHERE fc.custom_subject IN ('8.7.8c-fixture-mcq', '8.7.8c-fixture-match')
ORDER BY fc.custom_subject;
