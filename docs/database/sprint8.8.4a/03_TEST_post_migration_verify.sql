-- Name: [TEST] Sprint 8.8.4a - post-migration verification for the enrollment backfill widen
-- Description: Read-only. Run after 02_DATA_backfill_all_cards_enrollment.sql has been committed.
-- Re-runs 01_DIAGNOSTIC's four checks; compare against that run's output.

-- A. Should now be ZERO rows (every qualifying genuine-review pair has an enrollment row).
SELECT
  (f.user_id = r.user_id) AS is_own_card,
  COUNT(*) AS qualifying_rows_still_missing_enrollment
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND (
    r.rung IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.my_cards_enrollment e
    WHERE e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
  )
GROUP BY 1
ORDER BY 1;
-- Expect: no rows returned (or both counts 0).

-- B. Section C's population (existing non-active enrollment + active/due review) must be
-- UNCHANGED -- this migration must never have touched it.
SELECT COUNT(*) AS inactive_enrollment_with_due_review_unchanged_count
FROM public.my_cards_enrollment e
JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE e.status <> 'active'
  AND r.status = 'active'
  AND r.next_review_date <= CURRENT_DATE;
-- Compare to 01_DIAGNOSTIC section C's row count -- must be identical.

-- C. Bare-row population must be UNCHANGED (still correctly excluded, not backfilled).
SELECT
  (f.user_id = r.user_id) AS is_own_card,
  COUNT(*) AS bare_row_count_unchanged
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND r.rung IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
GROUP BY 1
ORDER BY 1;
-- Compare to 01_DIAGNOSTIC section D -- must be identical to before the migration.

-- D. Confirm reviews/flashcards were not touched by this migration (spot check: row counts
-- unchanged is implicit since this migration only INSERTs into my_cards_enrollment, but this
-- confirms no trigger side-effect fired unexpectedly).
SELECT
  (SELECT COUNT(*) FROM public.reviews) AS reviews_row_count,
  (SELECT COUNT(*) FROM public.flashcards) AS flashcards_row_count;
-- Compare manually against pre-migration counts if you captured them; these tables should be
-- byte-identical in row count (this migration never inserts/updates/deletes either one).

-- E. Sarang Gore (uuid e34acf2c-883d-41fa-a0e3-1d4a6704725e) specifically -- confirm his due
-- queue now has zero missing-enrollment rows (should match Section A restricted to him = 0).
SELECT COUNT(*) AS sarang_still_missing_enrollment
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE r.user_id = 'e34acf2c-883d-41fa-a0e3-1d4a6704725e'
  AND f.question_type IS DISTINCT FROM 'concept_card'
  AND (
    r.rung IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.my_cards_enrollment e
    WHERE e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
  );
-- Expect: 0

-- F. Sarang's SA 530 card specifically -- BEFORE-state snapshot to compare against Part C's
-- live-Review-flow regression test (run this now, then again after Sarang actually grades the
-- card in the app, per the Part C protocol).
SELECT r.flashcard_id, r.status, r.rung, r.next_review_date, r.last_reviewed_at,
       (SELECT COUNT(*) FROM public.review_events re
         WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id) AS review_events_count,
       e.status AS enrollment_status
FROM public.reviews r
LEFT JOIN public.my_cards_enrollment e ON e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
WHERE r.user_id = 'e34acf2c-883d-41fa-a0e3-1d4a6704725e'
  AND r.flashcard_id = '13f8f242-993d-4490-8734-430d0e5a4299';
