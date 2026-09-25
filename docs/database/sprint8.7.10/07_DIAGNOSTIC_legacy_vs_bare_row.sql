-- Name: [DIAGNOSTIC] Sprint 8.7.10 - distinguish legacy (pre-review_events) grading from true bare rows
-- Description: Read-only. Corrects a flaw in 06_DIAGNOSTIC query 2, which filtered to the NULL-rung
-- population before checking review_events, so it could never report on the other never-graded
-- rows that have a POPULATED rung. review_events was only introduced in Sprint 7.4
-- (docs/database/sprint7.4/01_SCHEMA_review_events.sql) -- a card genuinely graded before that
-- table existed has real rung/next_review_date history but legitimately zero review_events rows.
-- That is NOT the same thing as a skip_card/suspend_card bare row (which never sets rung at all,
-- leaving it NULL). This separates the two populations properly among the 1187 backfilled cards.

-- 1. Full breakdown: has_review_event x has_populated_rung, over all 1187 backfilled cards
SELECT
  has_review_event,
  (r.rung IS NOT NULL) AS has_populated_rung,
  COUNT(*) AS card_count
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
CROSS JOIN LATERAL (
  SELECT EXISTS (
    SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
  ) AS has_review_event
) x
WHERE me.status = 'active'
GROUP BY has_review_event, has_populated_rung
ORDER BY card_count DESC;
-- Four buckets expected:
--   has_review_event=true,  has_populated_rung=true  -> genuinely graded, recent (post-7.4)
--   has_review_event=false, has_populated_rung=true   -> likely genuinely graded PRE-7.4 (legacy, no audit row)
--   has_review_event=false, has_populated_rung=false  -> true skip_card/suspend_card bare row, never graded
--   has_review_event=true,  has_populated_rung=false  -> should not exist (sanity check)

-- 2. For the "no review_events but populated rung" bucket: does rung actually vary (evidence of
--    real grading progression), or is it suspiciously always the same starting value (which would
--    suggest something else wrote a placeholder rung, not genuine grading)?
SELECT r.rung, COUNT(*) AS card_count
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active'
  AND r.rung IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id)
GROUP BY r.rung
ORDER BY r.rung;

-- 3. Timing check: when was review_events actually deployed (earliest row), vs. the created_at /
--    last_reviewed_at distribution of the "no review_events but populated rung" bucket. If that
--    bucket's timestamps predate review_events' earliest row, the legacy-grading theory holds.
SELECT MIN(created_at) AS earliest_review_events_row FROM public.review_events;

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

-- 4. Same timing check for the true bare-row bucket (NULL rung, no review_events) -- expect these
--    to be spread across all time (skip/pause can happen anytime), not clustered pre-7.4.
SELECT
  MIN(r.created_at) AS earliest, MAX(r.created_at) AS latest, COUNT(*) AS card_count
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active'
  AND r.rung IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id);
