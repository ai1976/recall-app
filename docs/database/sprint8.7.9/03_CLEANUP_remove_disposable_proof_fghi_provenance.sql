-- Name: [CLEANUP] Remove orphaned provenance rows for Sprint 8.7.9 disposable proof (records F/G/H/I)
-- Description: Stage 8 live proof for records F (CAFA-AUD-SM1-C07-TYK16),
-- G (CAFA-AUD-SM1-C07-TYK04), H (CAFA-AUD-SM1-C05-CS01-TQ01), and I
-- (CAFA-AUD-SM1-C05-CS01-MCQ01..04) created 7 disposable private cards (3
-- theory sharing one file-wide batch, 4 case_study_mcq sharing one
-- case-group batch) to verify [[TABLE]] rendering, the theory-scenario
-- gate (Decision 3), and scenario byte-equality across a shared case group.
-- The 7 flashcards rows have already been deleted via the authenticated
-- client (confirmed 0 residue). Their 2 flashcard_batch_provenance rows
-- could not be deleted client-side (RLS denies delete on this table by
-- design — see DATABASE_SCHEMA.md §2.3A). Run this once in the Supabase
-- SQL Editor to remove them.

-- 1. Verify these are genuinely orphaned (no flashcards reference them) before deleting
SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_at,
       (SELECT count(*) FROM flashcards f WHERE f.batch_id = p.batch_id) AS remaining_flashcards
FROM flashcard_batch_provenance p
WHERE p.batch_id IN (
  'c3ea31be-aac2-4eb4-92e9-853a6146e70c',
  'e0e10b2e-55e8-48d7-b7e1-8a832c4606db'
);

-- 2. Delete the 2 orphaned provenance rows (only after confirming remaining_flashcards = 0 above)
DELETE FROM flashcard_batch_provenance
WHERE batch_id IN (
  'c3ea31be-aac2-4eb4-92e9-853a6146e70c',
  'e0e10b2e-55e8-48d7-b7e1-8a832c4606db'
);

-- 3. Re-verify: should return 0 rows
SELECT count(*) AS remaining_orphan_provenance
FROM flashcard_batch_provenance
WHERE batch_id IN (
  'c3ea31be-aac2-4eb4-92e9-853a6146e70c',
  'e0e10b2e-55e8-48d7-b7e1-8a832c4606db'
);
