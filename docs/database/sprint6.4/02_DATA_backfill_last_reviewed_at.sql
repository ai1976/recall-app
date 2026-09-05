-- Name: [DATA] Sprint 6.4 — backfill reviews.last_reviewed_at from created_at (NULLs only)
--
-- Description:
--   Defensive backfill for the "Items Reviewed" stat re-point (Sprint 6.4).
--   Only touches rows where last_reviewed_at IS NULL, setting it to created_at
--   (the best available lower bound for "most recent rating" on an un-maintained
--   row). Idempotent. Reversible only in the sense that re-running is a no-op.
--
--   RUN 01_DIAGNOSTIC FIRST. If query 1 there reports 0 NULL rows (expected —
--   both historical write paths set last_reviewed_at, and the column has
--   DEFAULT now()), this script is unnecessary; skip it. The frontend already
--   falls back to created_at for NULL rows, so this is not a deployment-order
--   blocker either way.
--
--   Free plan: single UPDATE, no batching needed at this table size
--   (~8k rows total; NULL subset expected to be empty or trivially small).
--   No trigger on reviews touches last_reviewed_at, so this write has no
--   side effects on schedule / rung / status columns.

UPDATE public.reviews
SET last_reviewed_at = created_at
WHERE last_reviewed_at IS NULL;

-- Verify: expect 0 remaining.
SELECT 'reviews.last_reviewed_at still NULL' AS check, COUNT(*) AS rows_null
FROM public.reviews
WHERE last_reviewed_at IS NULL;
