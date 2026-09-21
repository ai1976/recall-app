-- [CLEANUP] Remove the orphaned provenance row left by the Sprint 8.7.7 B2 live upload test
-- Description: The B2 verification uploaded one private test card (front "ZZ B2 TEST card - safe to delete")
--   and then deleted it. Deleting the last card of a batch does not remove its flashcard_batch_provenance row
--   (the known final-card-delete orphan gap recorded in Sprint 8.7.6), so one orphan row remains for batch
--   5e76768d-ecac-4ea9-af41-20f79d3137b3. Authenticated users have SELECT-only on that table, so it can only
--   be removed here. Run section 1 first (expect 1 provenance row, 0 cards), then section 2, then section 3.

-- 1. Confirm it is exactly the test batch and truly orphaned
SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_at,
       (SELECT count(*) FROM public.flashcards f WHERE f.batch_id = p.batch_id) AS cards_in_batch
FROM public.flashcard_batch_provenance p
WHERE p.batch_id = '5e76768d-ecac-4ea9-af41-20f79d3137b3';
-- expect: 1 row, content_source_name = 'Sprint 8.7.7 B2 test', cards_in_batch = 0

-- 2. Delete it (guarded: only if the batch really has no cards)
DELETE FROM public.flashcard_batch_provenance p
WHERE p.batch_id = '5e76768d-ecac-4ea9-af41-20f79d3137b3'
  AND p.content_source_name = 'Sprint 8.7.7 B2 test'
  AND NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.batch_id = p.batch_id);
-- expect: DELETE 1

-- 3. Verify
SELECT count(*) AS remaining FROM public.flashcard_batch_provenance
WHERE batch_id = '5e76768d-ecac-4ea9-af41-20f79d3137b3';
-- expect: 0
