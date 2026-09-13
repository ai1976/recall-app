-- Name: [DIAGNOSTIC] Sprint 7.4 — review_events storage projection (7.4-E)
--
-- Description:
--   Read-only. Run AFTER real apply_review calls have accumulated a few
--   review_events rows (StudyMode.jsx is now live-wired to apply_review).
--   Measures ACTUAL row/table/index size rather than estimating, then
--   projects 30/90/365-day growth from the real per-day rate observed so
--   far. Paste all results back — no writes, nothing to roll back.
--
--   Note: pre-review_events, there is no reliable way to reconstruct
--   historical daily grading volume — `reviews` is updated in place, so
--   only each card's MOST RECENT grade timestamp survives. That's exactly
--   the gap this table closes going forward; this diagnostic measures the
--   real thing now that it exists, rather than reconstructing an estimate
--   from `reviews`.

-- Q1 — real per-row size (bytes) of actual inserted review_events rows
SELECT
  id,
  reviewed_at,
  pg_column_size(review_events.*) AS row_bytes
FROM public.review_events
ORDER BY id DESC
LIMIT 20;

-- Q2 — average row size across all rows so far
SELECT
  COUNT(*) AS total_rows,
  ROUND(AVG(pg_column_size(review_events.*))) AS avg_row_bytes
FROM public.review_events;

-- Q3 — current on-disk size: table + both indexes
SELECT
  pg_size_pretty(pg_relation_size('public.review_events'))                       AS table_only,
  pg_size_pretty(pg_indexes_size('public.review_events'))                        AS indexes_only,
  pg_size_pretty(pg_total_relation_size('public.review_events'))                 AS table_plus_indexes;

-- Q4 — rows per day so far (real observed rate, however short the window)
SELECT
  reviewed_at::date AS day,
  COUNT(*) AS rows_that_day
FROM public.review_events
GROUP BY 1
ORDER BY 1;

-- Q5 — cross-check against study_sessions (same days) for context
SELECT session_date, COUNT(*) AS sessions_that_day
FROM public.study_sessions
WHERE session_date >= CURRENT_DATE - 7
GROUP BY 1
ORDER BY 1;

-- Q6 — current total DB size, for plan-limit context (check the Free-plan
-- storage cap in Supabase Dashboard -> Settings -> Billing separately)
SELECT pg_size_pretty(pg_database_size(current_database())) AS current_db_size;
