-- Name: [DATA] Sprint 8.8.4a - widen 8.7.10's enrollment backfill to non-own cards (production hotfix)
-- Description: Sprint 8.7.10 (25/09/2026) added an active-my_cards_enrollment requirement inside
-- apply_review, and backfilled enrollment for genuine review history -- but ONLY for own-authored
-- cards (docs/database/sprint8.7.10/01_DATA_backfill_own_card_enrollment.sql joined
-- `r.user_id = f.user_id`). The everyday "Review" flow (ReviewSession.jsx -> get_study_queue) was
-- never updated to require enrollment and still surfaces ANY due reviews row regardless of who
-- authored the card -- so students have continued seeing not-own cards as due, and every one of
-- those grades has been rejected by apply_review's new guard since 25/09/2026. Confirmed live
-- (26/09/2026 diagnostic): 5,813 currently-due not-own reviews rows across 103 distinct students
-- are missing enrollment. Reported by student Sarang Gore (uuid
-- e34acf2c-883d-41fa-a0e3-1d4a6704725e) as "Failed to save progress" on every grade.
--
-- This is NOT a new policy decision -- it is 8.7.10's own already-agreed backfill, corrected for
-- an ownership restriction that should never have scoped out non-own cards in the first place
-- (the genuine-review bar it enforces has nothing to do with who authored the card). The predicate
-- below is BYTE-IDENTICAL to what 8.7.10 actually shipped after its own correction (01_DATA's
-- initial insert, minus 08_CLEANUP's 103-row bare-row delete) -- see 01_DIAGNOSTIC_pre_migration_
-- control_totals.sql section A/D for this run's version of that same 07_DIAGNOSTIC/08_CLEANUP
-- analysis. The ONLY change from 8.7.10 is removing the `f.user_id = r.user_id` join condition.
--
-- Genuine-review predicate (identical to 8.7.10's final state):
--   INSERT if reviews.rung IS NOT NULL OR a review_events row exists for that user+card
--   SKIP   if reviews.rung IS NULL AND no review_events row exists (skip_card/suspend_card bare
--          row -- never actually graded, same bar 8.7.10 already enforced)
--
-- Guarantees (per this hotfix's constraints):
--   - INSERT only. Never touches reviews (status/rung/dates/history), flashcards (ownership/
--     provenance), or any existing my_cards_enrollment row.
--   - ON CONFLICT (user_id, flashcard_id) DO NOTHING -- a pair with an EXISTING enrollment row,
--     active or 'removed', is left completely alone. This never reactivates a deliberately-removed
--     enrollment (see 01_DIAGNOSTIC section C for that population, reported not touched).
--   - concept_card excluded, matching 8.7.10 and get_my_cards/get_study_queue's own exclusion.
--
-- Run 01_DIAGNOSTIC_pre_migration_control_totals.sql first and review its output (especially
-- section C) before running this. Run this as its own submission. Then run
-- 03_TEST_post_migration_verify.sql to confirm.

INSERT INTO public.my_cards_enrollment (user_id, flashcard_id, status, added_at)
SELECT
  r.user_id,
  r.flashcard_id,
  'active',
  now()
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND (
    r.rung IS NOT NULL
    OR EXISTS (
      SELECT 1 FROM public.review_events re
      WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id
    )
  )
ON CONFLICT (user_id, flashcard_id) DO NOTHING;

-- Check the editor's "rows affected" count. It should equal 01_DIAGNOSTIC section A's
-- qualifying_rows_missing_enrollment total (own + not-own combined, since 8.7.10's own-card
-- backfill already inserted most of the own-card rows -- this run only adds what's still missing:
-- the ~5,813 not-own rows plus that one account's 103 own-card gap).
