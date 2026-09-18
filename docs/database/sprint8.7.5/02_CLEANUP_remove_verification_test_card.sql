-- Name: [CLEANUP] Remove Sprint 8.7.5 verification test card
-- Description: Deletes the single flashcard ("Checking 8.7.5") created live during Sprint 8.7.5's
-- public deck provenance verification (deck 7b6021e5-d68b-46a1-959f-7eb59990ed2e, Advanced
-- Accounting > Amalgamation of Companies). The in-app delete button's confirm() dialog was not
-- completing for the operator, so removing directly. Provenance row for the same batch is deleted
-- too (harmless if it happens to be reused by other real cards — this batch_id was minted solely
-- for this one test card).

-- Run the SELECT first to confirm you're about to delete the right (and only the right) row.

-- [DIAGNOSTIC] Confirm target row before deleting
SELECT id, front_text, batch_id, deck_id, visibility, created_at
FROM flashcards
WHERE front_text = 'Checking 8.7.5';

-- [CLEANUP] Delete the test flashcard and its provenance row
DELETE FROM flashcards
WHERE front_text = 'Checking 8.7.5';

DELETE FROM flashcard_batch_provenance
WHERE batch_id NOT IN (SELECT DISTINCT batch_id FROM flashcards WHERE batch_id IS NOT NULL)
  AND content_source_name = 'ICAI Study Material'
  AND created_at > now() - interval '1 day';

-- [TEST] Verify cleanup
SELECT count(*) AS remaining_test_cards FROM flashcards WHERE front_text = 'Checking 8.7.5';
