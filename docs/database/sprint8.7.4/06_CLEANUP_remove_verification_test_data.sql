-- Name: [CLEANUP] Sprint 8.7.4 — remove live-verification test data
--
-- Description: Removes the flashcards/note created during the §3(a) live
-- reconciliation pass (manual flashcard, bulk-upload batch, note) run as the
-- TestOutlook student account. The Browser pane's sandbox suppresses the
-- native confirm() dialog the in-app delete buttons rely on (same limitation
-- noted in sprint8.6c's own cleanup), so these are removed directly via SQL
-- instead of the UI. Deletes flashcard_batch_provenance rows too — direct
-- writes to that table are normally blocked by RLS for `authenticated`, but
-- this runs as the SQL Editor's superuser/table-owner role, which bypasses
-- RLS (same reason 03_TEST's role-impersonation idiom exists at all).
--
-- Run each SELECT first to confirm exactly what will be deleted, then run
-- the DELETE statements. Re-run the two verification SELECTs at the end —
-- both should return 0 rows.
--
-- Wrapped in BEGIN/COMMIT explicitly (added post-run, on code-review request)
-- for consistency with 01_SCHEMA/05_TEST and to not rely solely on the
-- Supabase SQL Editor's implicit single-transaction-per-run behavior — a
-- failure between the flashcards DELETE and the flashcard_batch_provenance
-- DELETE would otherwise leave orphaned provenance rows with no compensating
-- rollback if this is ever run through a tool that doesn't auto-wrap
-- multi-statement runs (e.g. psql with autocommit on). This file already ran
-- successfully once (18/09/2026, unwrapped) with all three counters
-- confirmed at 0 — this wrapper is a safety hardening for any future reuse,
-- not a redo of that already-verified run.

BEGIN;

-- 1. Preview what will be deleted
SELECT id, batch_id, front_text, source, created_at
FROM flashcards
WHERE front_text ILIKE 'Sprint 8.7.4%verification%'
   OR front_text ILIKE 'D-10 reprobe%'
ORDER BY created_at;

SELECT id, title, content_source_name, created_at
FROM notes
WHERE title = 'Sprint 8.7.4 verification note';

SELECT batch_id, content_source_name
FROM flashcard_batch_provenance
WHERE batch_id IN (
  SELECT DISTINCT batch_id FROM flashcards
  WHERE front_text ILIKE 'Sprint 8.7.4%verification%'
);

-- 2. Delete (flashcards first, then their provenance rows, then the note)
DELETE FROM flashcards
WHERE front_text ILIKE 'Sprint 8.7.4%verification%'
   OR front_text ILIKE 'D-10 reprobe%';

DELETE FROM flashcard_batch_provenance
WHERE batch_id NOT IN (SELECT DISTINCT batch_id FROM flashcards WHERE batch_id IS NOT NULL)
  AND content_source_name IN ('Sprint 8.7.4 verification', 'Sprint 8.7.4 bulk verification', 'Sprint 8.7.4 D-10 reprobe');

DELETE FROM notes
WHERE title = 'Sprint 8.7.4 verification note';

-- 3. Re-verify at 0 rows
SELECT count(*) AS remaining_flashcards FROM flashcards
WHERE front_text ILIKE 'Sprint 8.7.4%verification%' OR front_text ILIKE 'D-10 reprobe%';

SELECT count(*) AS remaining_notes FROM notes
WHERE title = 'Sprint 8.7.4 verification note';

SELECT count(*) AS remaining_provenance FROM flashcard_batch_provenance
WHERE content_source_name IN ('Sprint 8.7.4 verification', 'Sprint 8.7.4 bulk verification', 'Sprint 8.7.4 D-10 reprobe');

COMMIT;

-- Note: the test note's uploaded image (a synthetic 1x1 PNG, ~100 bytes) is
-- NOT cleaned up by this script — deleting the notes row directly via SQL
-- bypasses MyNotes.jsx's own delete handler (src/lib/noteStorage.js), which
-- is what actually removes the Storage object. The orphan is negligible
-- (~100 bytes, one object) but if you want it gone: Supabase Dashboard →
-- Storage → notes bucket → look for a file uploaded 18/09/2026 matching this
-- note's image_url (captured by the first preview SELECT above before you
-- delete the row) → delete manually.
