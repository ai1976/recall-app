-- Name: [CLEANUP] Sprint 8.7.10 - remove the 103 skip/suspend bare-row enrollments from 01_DATA
-- Description: Corrective delete. 01_DATA backfilled 1187 own cards using "has a reviews row" as
-- evidence of a genuine study relationship. 06/07_DIAGNOSTIC found 103 of those only have a bare
-- reviews row written by skip_card/suspend_card (rung IS NULL, no review_events row ever,
-- timestamps clustered 14-21 Sept 2026) -- never actually graded. That doesn't meet the agreed
-- backfill bar. This removes exactly those 103 my_cards_enrollment rows and nothing else.
--
-- Predicate is identical to 07_DIAGNOSTIC's "true bare-row bucket" query: own card, active
-- enrollment, reviews.rung IS NULL, zero review_events rows. Does NOT touch: the 1084 legitimate
-- backfilled rows (6 with review_events + 1078 legacy pre-7.4 with populated rung), reviews table
-- (no reviews row is touched or deleted -- the bare row itself is harmless, it's the enrollment
-- that was wrongly granted), or any external-card enrollment (that branch of get_my_cards/
-- add_to_my_cards is untouched by this whole sprint).
--
-- Run the SELECT first (query 1) and confirm it returns exactly 103 before running the DELETE.

-- 1. Preview -- confirm this matches exactly 103 rows before deleting anything
SELECT COUNT(*) AS rows_to_delete
FROM public.my_cards_enrollment me
JOIN public.flashcards f ON f.id = me.flashcard_id AND f.user_id = me.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active'
  AND r.rung IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
  );
-- Expect: 103. If this is not 103, STOP -- do not run the delete below.

-- 2. The actual delete (run as its own submission after confirming query 1 = 103)
DELETE FROM public.my_cards_enrollment me
USING public.flashcards f, public.reviews r
WHERE f.id = me.flashcard_id AND f.user_id = me.user_id
  AND r.flashcard_id = f.id AND r.user_id = f.user_id
  AND me.status = 'active'
  AND r.rung IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
  );
-- Check the "rows affected" count in the editor's result -- must read 103.
