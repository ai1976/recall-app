-- Name: [TEST] Verify objective-Practice wrong-answer side effects on the disposable fixture
--
-- Description: Run this AFTER driving the wrong-answer path in the browser against the two fixture
-- cards from 07_DATA_create_practice_fixture_objective_cards.sql. Read-only. Confirms the exact
-- risk this sprint exists to close: a wrong answer on an objective type must produce exactly one
-- practice_attempts row and ZERO reviews/review_events rows (the old code called apply_review
-- immediately on a wrong tap; Practice Mode must never do that).

SELECT
  fc.custom_subject,
  fc.id AS card_id,
  (SELECT count(*) FROM public.practice_attempts pa WHERE pa.flashcard_id = fc.id) AS practice_attempt_rows,
  (SELECT is_correct FROM public.practice_attempts pa WHERE pa.flashcard_id = fc.id ORDER BY attempted_at DESC LIMIT 1) AS last_attempt_is_correct,
  (SELECT count(*) FROM public.reviews r WHERE r.flashcard_id = fc.id) AS reviews_rows,
  (SELECT count(*) FROM public.review_events re WHERE re.flashcard_id = fc.id) AS review_events_rows,
  (SELECT count(*) FROM public.my_cards_enrollment e WHERE e.flashcard_id = fc.id AND e.status = 'active') AS active_enrollment_rows
FROM public.flashcards fc
WHERE fc.custom_subject IN ('8.7.8c-fixture-mcq', '8.7.8c-fixture-match')
ORDER BY fc.custom_subject;
