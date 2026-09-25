-- Name: [TEST] Sprint 8.7.10 - verify 08_CLEANUP landed correctly
-- Description: Read-only. Run after 08_CLEANUP's DELETE has been committed.

-- 1. Final backfilled total should now be 1084 (1187 - 103), split 6 review_events + 1078 legacy
SELECT
  COUNT(*) AS final_backfilled_total,
  COUNT(*) FILTER (WHERE has_review_event) AS with_review_events,
  COUNT(*) FILTER (WHERE NOT has_review_event AND r.rung IS NOT NULL) AS legacy_populated_rung,
  COUNT(*) FILTER (WHERE NOT has_review_event AND r.rung IS NULL) AS remaining_bare_rows_should_be_zero
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
CROSS JOIN LATERAL (
  SELECT EXISTS (
    SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
  ) AS has_review_event
) x
WHERE me.status = 'active';
-- Expect: total=1084, with_review_events=6, legacy_populated_rung=1078, remaining_bare_rows=0

-- 2. Confirm the reviews table itself was NOT touched by the cleanup (the 103 bare reviews rows
--    still exist -- only their enrollment was removed, per the plan)
SELECT COUNT(*) AS bare_reviews_rows_still_present
FROM public.reviews r
WHERE r.rung IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
  AND EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = r.flashcard_id AND f.user_id = r.user_id);
-- Expect: 103 (unchanged -- cleanup only deleted enrollment rows, never touched reviews)

-- 3. Confirm those 103 cards are no longer enrolled
SELECT COUNT(*) AS still_wrongly_enrolled
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id AND f.user_id = r.user_id
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id AND me.status = 'active'
WHERE r.rung IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id);
-- Expect: 0
