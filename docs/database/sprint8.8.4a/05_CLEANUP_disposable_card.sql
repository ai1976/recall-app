-- Name: [CLEANUP] Sprint 8.8.4a - remove the disposable Part D regression-test card
-- Description: Run after the browser regression test is complete. Deletes the exact reviews row
-- and flashcard created by 04_DATA_disposable_card_for_frontend_regression.sql, identified by its
-- unique marker text (front_text ILIKE '%ZZ_TEST_8.8.4a_PARTD%'), never a bare id guess. Run the
-- SELECT preview first and confirm it returns exactly 1 row before running the DELETEs.

-- 1. Preview — confirm exactly 1 row before deleting anything
SELECT f.id, f.front_text, f.user_id, r.id AS review_id
FROM public.flashcards f
LEFT JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE f.front_text ILIKE '%ZZ_TEST_8.8.4a_PARTD%';
-- Expect: exactly 1 row. If not 1, STOP -- do not run the deletes below.

-- 2. Delete review_events (if any were written by the failed/retried apply_review attempts —
--    a rejected call never reaches the review_events INSERT, but a later successful retry would)
DELETE FROM public.review_events
WHERE flashcard_id IN (
  SELECT id FROM public.flashcards WHERE front_text ILIKE '%ZZ_TEST_8.8.4a_PARTD%'
);

-- 3. Delete the reviews row
DELETE FROM public.reviews
WHERE flashcard_id IN (
  SELECT id FROM public.flashcards WHERE front_text ILIKE '%ZZ_TEST_8.8.4a_PARTD%'
);

-- 4. Delete the flashcard itself
DELETE FROM public.flashcards
WHERE front_text ILIKE '%ZZ_TEST_8.8.4a_PARTD%';

-- 5. Confirm 0 residue
SELECT COUNT(*) AS residue_should_be_zero
FROM public.flashcards
WHERE front_text ILIKE '%ZZ_TEST_8.8.4a_PARTD%';
