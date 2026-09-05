-- Name: [DIAGNOSTIC] Sprint 6.4 — reviews.last_reviewed_at coverage for the "Items Reviewed" re-point
--
-- Description:
--   Sprint 6.4 re-points the "Items Reviewed (last 7 days)" surfaces (Dashboard
--   tile + GoalProgressWidget today-count + Progress 7d/30d window) from
--   reviews.created_at (the card's FIRST review — never moves, because
--   submit_review UPDATEs the single UNIQUE(user_id, flashcard_id) row) to
--   reviews.last_reviewed_at (the most recent rating).
--
--   last_reviewed_at is timestamptz with DEFAULT now(), and BOTH write paths
--   have always maintained it:
--     - pre-ladder StudyMode.handleRating  -> UPDATE ... last_reviewed_at = now()
--     - submit_review (SRS ladder, live 03/09/2026) -> INSERT + UPDATE set it
--   so this diagnostic is expected to report ZERO NULLs and no backfill needed.
--   Run it to confirm before deciding whether 02_DATA has to run at all.
--
--   Read-only. Safe to run anytime. No deployment-order constraint.

-- 1. NULL coverage — the backfill target. Expected: 0.
SELECT
  'reviews.last_reviewed_at IS NULL' AS check,
  COUNT(*)                            AS rows_null,
  (SELECT COUNT(*) FROM public.reviews) AS rows_total,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM public.reviews), 0), 3) AS pct_null
FROM public.reviews
WHERE last_reviewed_at IS NULL;

-- 2. Sanity: last_reviewed_at should be >= created_at for essentially every row
--    (a rating cannot predate the row). A non-trivial count here would mean the
--    column was not maintained at some point and the re-point needs more care.
SELECT
  'last_reviewed_at < created_at (unexpected)' AS check,
  COUNT(*) AS rows_before_created
FROM public.reviews
WHERE last_reviewed_at IS NOT NULL
  AND last_reviewed_at < created_at;

-- 3. The actual effect of the re-point: how many active, graded rows are
--    "recent by last_reviewed_at" but NOT "recent by created_at" in a rolling
--    7-day window. These are the reviews the old stat was silently dropping.
--    (Uses UTC-ish boundaries — indicative, not the app's per-user-tz maths.)
WITH w AS (SELECT (now() - interval '7 days') AS since)
SELECT
  'graded rows recent by last_reviewed_at' AS metric,
  COUNT(*) FILTER (WHERE r.last_reviewed_at >= w.since)                       AS by_last_reviewed,
  COUNT(*) FILTER (WHERE r.created_at        >= w.since)                       AS by_created,
  COUNT(*) FILTER (WHERE r.last_reviewed_at >= w.since
                    AND r.created_at        <  w.since)                       AS recovered_by_repoint
FROM public.reviews r, w
WHERE (r.status = 'active' OR r.status IS NULL)
  AND r.quality > 0;

-- 4. Distribution of days between created_at and last_reviewed_at — shows how
--    stale created_at is as a recency proxy across the live dataset.
SELECT
  CASE
    WHEN age_days = 0                    THEN '0 (same day / single review)'
    WHEN age_days BETWEEN 1   AND 7      THEN '1-7 days'
    WHEN age_days BETWEEN 8   AND 30     THEN '8-30 days'
    WHEN age_days BETWEEN 31  AND 90     THEN '31-90 days'
    ELSE                                     '90+ days'
  END AS created_to_last_reviewed_gap,
  COUNT(*) AS rows
FROM (
  SELECT EXTRACT(DAY FROM (last_reviewed_at - created_at))::int AS age_days
  FROM public.reviews
  WHERE last_reviewed_at IS NOT NULL
) g
GROUP BY 1
ORDER BY 1;
