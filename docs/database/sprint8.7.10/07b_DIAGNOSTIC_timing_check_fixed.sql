-- Name: [DIAGNOSTIC] Sprint 8.7.10 - timing check, corrected column name (reviewed_at not created_at)
-- Description: Re-run of 07_DIAGNOSTIC queries 3 and 4 with the correct review_events column name.

-- 3. When was review_events first ever written, vs. the reviews-row timestamps of the
--    "no review_events but populated rung" bucket (1078 cards). If that bucket's timestamps
--    predate review_events' earliest row, the legacy-grading theory (genuinely graded before the
--    audit table existed) holds.
SELECT MIN(reviewed_at) AS earliest_review_events_row FROM public.review_events;

SELECT
  MIN(r.created_at)        AS earliest_reviews_created_at,
  MAX(r.created_at)        AS latest_reviews_created_at,
  MIN(r.last_reviewed_at)  AS earliest_last_reviewed_at,
  MAX(r.last_reviewed_at)  AS latest_last_reviewed_at,
  COUNT(*)                 AS card_count
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active'
  AND r.rung IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id);

-- 4. Same timing check for the true bare-row bucket (NULL rung, no review_events, 103 cards) --
--    expect these spread across all time (skip/pause can happen anytime), not clustered pre-7.4.
SELECT
  MIN(r.created_at) AS earliest, MAX(r.created_at) AS latest, COUNT(*) AS card_count
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active'
  AND r.rung IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id);
