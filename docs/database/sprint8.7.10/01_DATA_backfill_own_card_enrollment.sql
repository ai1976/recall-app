-- Name: [DATA] Sprint 8.7.10 - backfill own-card enrollment from genuine reviews history
-- Description: One-time backfill. Inserts an ACTIVE my_cards_enrollment row for every
-- own-authored flashcard that has at least one reviews row (the agreed evidence of a genuine
-- historical study relationship under the pre-8.7.10 auto-enroll design). Concept cards are
-- excluded (they never enter SRS). Cards with no reviews row get NO enrollment row, regardless
-- of authorship. This does NOT touch reviews.status, rung, next_review_date, or any other SRS
-- history -- a suspended reviews row stays suspended; only enrollment membership is added.
-- Confirmed against live control totals (25/09/2026): 908 reviews.status='active' +
-- 279 reviews.status='suspended' = 1187 rows expected to insert. 1618 never-reviewed own
-- cards are expected to be skipped. Idempotent: ON CONFLICT DO NOTHING means re-running this
-- file is always safe.
-- Run once as its own submission, then run 02_TEST_verify_backfill.sql immediately after
-- (separate submission, read-only) to confirm the count matches the expected 1187.
-- Do not combine the INSERT and its verification into one script/transaction: Supabase SQL
-- Editor runs a whole submission as a single transaction, so a same-script SELECT can't give
-- you a real chance to stop before COMMIT anyway -- run them as two submissions instead.

INSERT INTO public.my_cards_enrollment (user_id, flashcard_id, status, added_at)
SELECT
  f.user_id,
  f.id,
  'active',
  now()
FROM public.flashcards f
JOIN public.reviews r
  ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
ON CONFLICT (user_id, flashcard_id) DO NOTHING;
