-- Name: [CLEANUP] Remove orphaned provenance rows for Sprint 8.7.9 disposable proof
-- Description: Stage 8 live proof (Fixtures A-E) created 5 disposable private
-- case_study_mcq cards to verify [[TABLE]] rich-content rendering in the real
-- app. The 5 flashcards rows have already been deleted via the authenticated
-- client (confirmed 0 residue). Their flashcard_batch_provenance rows could
-- not be deleted client-side (RLS denies delete on this table — 42501), since
-- there is no AFTER DELETE trigger on flashcards that cascades this cleanup
-- (only trg_cleanup_orphan_batch_provenance, which fires on UPDATE). Run this
-- once in the Supabase SQL Editor to remove the 5 orphaned rows.

-- 1. Verify these are genuinely orphaned (no flashcards reference them) before deleting
SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_at,
       (SELECT count(*) FROM flashcards f WHERE f.batch_id = p.batch_id) AS remaining_flashcards
FROM flashcard_batch_provenance p
WHERE p.batch_id IN (
  'e269e107-c134-4871-8704-65189a00dc2e',
  'f18f3d9a-b05d-48b2-b62f-f20a50407e36',
  'ae3584f9-ed39-4203-9f48-63d0d54f4766',
  '8ca97ee1-1d0a-4d99-8f7b-44cc93841642',
  'c340ebe0-55d9-475d-9a8b-50fc46a438c1'
);

-- 2. Delete the 5 orphaned provenance rows (only after confirming remaining_flashcards = 0 above)
DELETE FROM flashcard_batch_provenance
WHERE batch_id IN (
  'e269e107-c134-4871-8704-65189a00dc2e',
  'f18f3d9a-b05d-48b2-b62f-f20a50407e36',
  'ae3584f9-ed39-4203-9f48-63d0d54f4766',
  '8ca97ee1-1d0a-4d99-8f7b-44cc93841642',
  'c340ebe0-55d9-475d-9a8b-50fc46a438c1'
);

-- 3. Re-verify: should return 0 rows
SELECT count(*) AS remaining_orphan_provenance
FROM flashcard_batch_provenance
WHERE batch_id IN (
  'e269e107-c134-4871-8704-65189a00dc2e',
  'f18f3d9a-b05d-48b2-b62f-f20a50407e36',
  'ae3584f9-ed39-4203-9f48-63d0d54f4766',
  '8ca97ee1-1d0a-4d99-8f7b-44cc93841642',
  'c340ebe0-55d9-475d-9a8b-50fc46a438c1'
);
