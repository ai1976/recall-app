-- Name: [DATA] Make 8.7.8e disposable test MCQ card due today
--
-- Description: Live-verification step for Sprint 8.7.8e (not part of the
-- automated test suite — this is a real, non-rolled-back row, disposable,
-- cleaned up by 04_CLEANUP once the operator has visually confirmed the card
-- renders correctly through the normal Review flow).
--
-- The card itself was created for real through the app UI (Create Study Item,
-- as a professor, question_type='mcq', front_text starting with
-- "[8.7.8e TEST]", Content Source = Original creator / "8.7.8e live
-- verification (disposable)"). It has no `reviews` row yet — own content only
-- gets one on first grade, and grading it once would put next_review_date in
-- the future, not due today. This directly creates the reviews row already
-- due, skipping the "first grade" step since that's pre-existing StudyMode/
-- enrollment logic this sprint doesn't touch — the only thing being verified
-- here is whether get_study_queue now carries options/correct_answer/
-- explanation/scenario/subtype through to a real due card in the real app.
--
-- ON CONFLICT guards against re-running this twice (reviews_user_flashcard_
-- unique). Identifies the card by its unique front_text prefix rather than a
-- hardcoded id, since the id wasn't captured at creation time.

INSERT INTO public.reviews (user_id, flashcard_id, quality, next_review_date, status, rung)
SELECT f.user_id, f.id, 3, CURRENT_DATE - 1, 'active', 0
FROM public.flashcards f
WHERE f.front_text LIKE '[8.7.8e TEST]%'
ON CONFLICT (user_id, flashcard_id)
DO UPDATE SET next_review_date = EXCLUDED.next_review_date, status = 'active';

-- Confirm: should show exactly 1 row, status=active, next_review_date = yesterday.
SELECT r.user_id, r.flashcard_id, r.status, r.next_review_date, f.front_text
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.front_text LIKE '[8.7.8e TEST]%';
