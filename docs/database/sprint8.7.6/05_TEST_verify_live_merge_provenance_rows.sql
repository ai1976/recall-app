-- Name: [TEST] Verify live merge removed the merged-away provenance row (read-only)
-- Description: After the live UI merge of two 'T876-A' test batches, expect exactly TWO provenance rows
--   for the test names: one 'T876-A' (survivor, holding 2 cards) and one 'T876-B' (untouched, 1 card).
--   Before the merge there were three. Zero orphans expected. Read-only. Run each block separately.

-- Block 1: provenance rows for the test names, with live card counts
SELECT p.batch_id, p.content_source_type, p.content_source_name,
       (SELECT count(*) FROM public.flashcards f WHERE f.batch_id = p.batch_id) AS cards_in_batch
FROM public.flashcard_batch_provenance p
WHERE p.content_source_name IN ('T876-A', 'T876-B')
ORDER BY p.content_source_name;

-- Block 2: total orphan provenance rows (expect 0, same as Step 0)
SELECT count(*) AS orphan_provenance_rows
FROM public.flashcard_batch_provenance p
WHERE NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.batch_id = p.batch_id);
