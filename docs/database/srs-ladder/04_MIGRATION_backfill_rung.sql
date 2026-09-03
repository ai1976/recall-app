-- Name: [FIX] SRS Ladder Epic — Phase 2 migration: backfill reviews.rung from repetition + easiness
--
-- Description:
--   Phase 2 of the SRS Ladder Epic. One-time backfill of the new `reviews.rung` column.
--   Phase 0 measured 7,824 rows / 2.7 MB → this is a SINGLE committed UPDATE, no batching.
--
--   Mapping (approved 03/09/2026):
--       rung = CASE WHEN easiness <= 2.35 THEN LEAST(repetition, 2)   -- last grade was Hard: re-enter at 7d max
--                   ELSE                       LEAST(repetition, 4)   -- everyone else: 30d max on entry
--              END
--   Rationale: nobody enters rungs 5–7 — the ladder must EARN the 60/120/240-day intervals
--   through real post-migration reviews. `easiness` holds exactly 3 discrete values
--   (2.30 / 2.50 / 2.60 = last grade — Phase 0 Q4), so `<= 2.35` cleanly selects the Hard rows.
--
--   ⚠️ `next_review_date` is NEVER touched. No card's due date moves. No card is mastered by
--   this migration (status='mastered' is only ever set by submit_review on an Easy at rung 7).
--
--   Idempotent: `WHERE rung IS NULL` — re-running only affects rows not yet backfilled.
--
--   REVERSIBILITY:  UPDATE public.reviews SET rung = NULL;      -- (or) ALTER TABLE public.reviews DROP COLUMN rung;
--   Nothing else is changed, so schedules are already intact — reverting the column fully reverts Phase 2.
--
--   Run this as its own Supabase SQL Editor submission (it COMMITs). Run 05_TEST PART A BEFORE
--   this file and 05_TEST PART B AFTER it.

-- ── Pre-flight 1: no UPDATE trigger on reviews would fire on a bulk rung write ──
--    (expect only INSERT / DELETE triggers — trg_aaa_counter_reviews, trg_badge_review)
SELECT tgname,
       CASE WHEN (tgtype & 16) > 0 THEN 'UPDATE ' ELSE '' END ||
       CASE WHEN (tgtype & 4)  > 0 THEN 'INSERT ' ELSE '' END ||
       CASE WHEN (tgtype & 8)  > 0 THEN 'DELETE ' ELSE '' END AS fires_on
FROM pg_trigger
WHERE tgrelid = 'public.reviews'::regclass AND NOT tgisinternal
ORDER BY tgname;

-- ── Pre-flight 2: how many rows still need a rung (expect all of them on first run) ──
SELECT count(*) FILTER (WHERE rung IS NULL) AS to_backfill,
       count(*) FILTER (WHERE rung IS NOT NULL) AS already_done,
       count(*) AS total
FROM public.reviews;

-- ═══════════════════════════════════════════════════════════════════════════════
-- BACKFILL
-- ═══════════════════════════════════════════════════════════════════════════════
UPDATE public.reviews
SET rung = CASE
             WHEN COALESCE(easiness, 2.5) <= 2.35 THEN LEAST(COALESCE(repetition, 0), 2)
             ELSE                                       LEAST(COALESCE(repetition, 0), 4)
           END
WHERE rung IS NULL;

-- ── Post: rows processed + resulting rung distribution ──
SELECT rung, count(*) AS rows
FROM public.reviews
GROUP BY rung
ORDER BY rung;

SELECT count(*) AS reviews_still_null_rung
FROM public.reviews
WHERE rung IS NULL;   -- expect 0
