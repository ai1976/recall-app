-- Name: [CLEANUP] Remove Sprint 8.7.6 live merge test data
-- Description: Deletes ONLY the disposable test cards (custom_subject 'ZZ-876-TEST', front_text 'T876 test%'),
--   then their provenance rows (source names 'T876-A'/'T876-B', only where no cards remain), then any empty
--   test deck. Run the 05 verification FIRST, then this. Run as ONE run; the last statement reports what is left
--   (expect all zeros). Deleting cards also empties the batches' provenance: this is the recorded-not-fixed
--   "final cards deleted leaves an orphan" path, so provenance is removed here explicitly.
DELETE FROM public.flashcards
WHERE custom_subject = 'ZZ-876-TEST' AND front_text LIKE 'T876 test%';

DELETE FROM public.flashcard_batch_provenance p
WHERE p.content_source_name IN ('T876-A', 'T876-B')
  AND NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.batch_id = p.batch_id);

DELETE FROM public.flashcard_decks
WHERE custom_subject = 'ZZ-876-TEST' AND COALESCE(card_count, 0) = 0;

SELECT
  (SELECT count(*) FROM public.flashcards WHERE custom_subject = 'ZZ-876-TEST')                       AS remaining_flashcards,
  (SELECT count(*) FROM public.flashcard_batch_provenance WHERE content_source_name IN ('T876-A','T876-B')) AS remaining_provenance,
  (SELECT count(*) FROM public.flashcard_decks WHERE custom_subject = 'ZZ-876-TEST')                  AS remaining_decks;
