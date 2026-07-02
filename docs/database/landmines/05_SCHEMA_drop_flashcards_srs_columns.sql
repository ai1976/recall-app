-- Name: [SCHEMA] Drop Vestigial flashcards SRS Columns (blueprint.md §1.11 "Type inconsistencies")
-- Description: Drops flashcards.next_review, flashcards.interval, flashcards.ease_factor,
-- flashcards.repetitions. These are the pre-`reviews`-table SRS fields, superseded by
-- reviews.next_review_date (date, live), reviews.interval (live), reviews.easiness (live),
-- reviews.repetition (live). CLAUDE.md and blueprint.md §1.11 already say: always read SRS
-- state from `reviews`, never from `flashcards`.
--
-- ⚠️ REVERSED DEPLOY ORDER — this is FRONTEND-GATED, unlike 02/03/04 in this folder.
--
-- Writer found: FlashcardCreate.jsx (single-card create form) wrote all four columns on every
-- insert (next_review: new Date().toISOString(), interval: 1, ease_factor: 2.5, repetitions: 0)
-- — a hardcoded, never-updated seed value, not live SRS state. No other insert path writes
-- them: BulkUploadFlashcards.jsx and ProfessorTools.jsx (bulk paths) do NOT include these keys
-- in their insert payloads (confirmed by reading both files in full). No read path anywhere in
-- src/ references flashcards.next_review/interval/ease_factor/repetitions — every review-flow
-- read (Dashboard.jsx, ReviewBySubject.jsx, ReviewSession.jsx, StudyMode.jsx) queries
-- reviews.next_review_date instead.
--
-- Companion frontend change (this L1 sprint): stripped the four keys from the insert payload
-- in FlashcardCreate.jsx. That change MUST be deployed and verified live BEFORE this SQL runs,
-- or the pre-change frontend (if still live) will error on every single-card flashcard insert
-- the moment these columns no longer exist.
--
-- Deploy order (non-negotiable, per CLAUDE.md):
--   1. Deploy the frontend change (FlashcardCreate.jsx, SRS keys removed from insert payload).
--   2. Verify in production: create one flashcard via the single-card form, confirm success.
--   3. THEN run this SQL.
--
-- Live confirmation needed before step 3: 01_DIAGNOSTIC_landmine_l1_audit.sql query 5's
-- "most_recent_row_with_srs_data" should show no rows newer than the frontend deploy timestamp
-- from step 1 — that's the live proof the old insert payload is no longer running anywhere
-- (e.g. a stale cached tab).

ALTER TABLE public.flashcards
  DROP COLUMN IF EXISTS next_review,
  DROP COLUMN IF EXISTS interval,
  DROP COLUMN IF EXISTS ease_factor,
  DROP COLUMN IF EXISTS repetitions;
