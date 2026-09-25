-- Name: [DIAGNOSTIC] Sprint 8.7.10 - investigate the 180 NULL-rung backfilled cards
-- Description: Read-only. 05_TEST query 7 found 180 of the 1187 backfilled own cards have
-- reviews.rung IS NULL or next_review_date IS NULL. skip_card / suspend_card both insert a bare
-- reviews row without ever setting rung (the known "skip/suspend bare-row" pattern referenced in
-- remove_from_my_cards's own code comments) -- so these 180 may have been merely skipped/paused,
-- never actually graded via apply_review. review_events is written ONLY by apply_review, so
-- "has a review_events row" is the unambiguous signal of genuine grading. This measures the
-- overlap precisely before deciding whether to leave the 180 backfilled as-is.

-- 1. Of the 1187 backfilled cards, how many have ZERO review_events rows at all (never graded,
--    only ever skipped/paused/etc)?
SELECT
  COUNT(*) AS backfilled_total,
  COUNT(*) FILTER (WHERE has_review_event) AS backfilled_with_at_least_one_grade,
  COUNT(*) FILTER (WHERE NOT has_review_event) AS backfilled_never_actually_graded
FROM (
  SELECT
    f.id,
    EXISTS (
      SELECT 1 FROM public.review_events re
      WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
    ) AS has_review_event
  FROM public.flashcards f
  JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
  WHERE me.status = 'active'
    AND EXISTS (SELECT 1 FROM public.reviews r WHERE r.flashcard_id = f.id AND r.user_id = f.user_id)
) x;

-- 2. Does "never actually graded" line up with the 180 NULL-rung/NULL-next_review_date finding?
--    (should be the same population, or a subset/superset -- this tells us which)
SELECT
  COUNT(*) FILTER (WHERE null_srs AND NOT has_review_event) AS null_srs_and_never_graded,
  COUNT(*) FILTER (WHERE null_srs AND has_review_event)     AS null_srs_but_has_review_event,
  COUNT(*) FILTER (WHERE NOT null_srs AND NOT has_review_event) AS populated_srs_but_never_graded,
  COUNT(*) AS total_180_null_srs_set
FROM (
  SELECT
    f.id,
    (r.rung IS NULL OR r.next_review_date IS NULL) AS null_srs,
    EXISTS (
      SELECT 1 FROM public.review_events re
      WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
    ) AS has_review_event
  FROM public.flashcards f
  JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
  JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
  WHERE me.status = 'active' AND (r.rung IS NULL OR r.next_review_date IS NULL)
) x;

-- 3. Breakdown of the never-graded-but-backfilled population by reviews.status and source
--    (skip_card leaves status='active' with a future skip_until; suspend_card leaves
--    status='suspended') -- helps distinguish "was skipped once" from "was paused, never graded"
SELECT
  r.status AS reviews_status,
  (r.skip_until IS NOT NULL AND r.skip_until > CURRENT_DATE) AS currently_skipped,
  COUNT(*) AS card_count
FROM public.flashcards f
JOIN public.my_cards_enrollment me ON me.flashcard_id = f.id AND me.user_id = f.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active'
  AND NOT EXISTS (
    SELECT 1 FROM public.review_events re WHERE re.flashcard_id = f.id AND re.user_id = f.user_id
  )
GROUP BY r.status, currently_skipped
ORDER BY card_count DESC;
