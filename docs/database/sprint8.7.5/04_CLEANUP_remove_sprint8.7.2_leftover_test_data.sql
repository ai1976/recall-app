-- Name: [CLEANUP] Remove Sprint 8.7.2 leftover test data (found live during Sprint 8.7.5)
-- Description: Sprint 8.7.2's own live verification never had a cleanup script — confirmed by
-- 03_DIAGNOSTIC's results: 8 flashcards across 7 batch_ids, all created 2026-09-18, all tied to
-- an 8.7.2-labelled flashcard_batch_provenance row, no orphans (every batch_id's cards accounted
-- for, every card's batch_id has a matching provenance row). Two of the private/manual cards
-- (batch 354875b5.../deck 64a21016..., and batch 52bab6d2.../deck be5744d7...) share deck
-- be5744d7... with another test card in the same batch set — deleting all 8 cards will leave
-- both decks empty; the trailing step removes those two decks only if they end up with
-- card_count = 0 and were never anything but this test data (guarded, not a blind sweep).

-- [CLEANUP] Delete the 8 test flashcards (exact IDs from 03_DIAGNOSTIC, not a pattern match —
-- avoids any risk of a front_text LIKE also matching a real card that happens to mention "8.7.2")
DELETE FROM flashcards
WHERE id IN (
  '8e6aee0a-e166-4369-956d-049af476d8f8',
  'd2d20bdb-196c-40e7-abf5-2852b49fb911',
  '42b62e6b-78ca-430d-babd-753f335a06d3',
  'cfd5dbf7-e968-4115-b5bb-7a28a2e148c0',
  'f1884f6c-be4f-4cca-9f66-bdb372f7d533',
  '705a265f-c65a-48c4-8b98-c78207285e99',
  '126a768d-c24b-49b8-be60-139554cc3090',
  '093cf1c9-bcd7-4c8d-a766-68690a331046'
);

-- [CLEANUP] Delete the 7 matching provenance rows
DELETE FROM flashcard_batch_provenance
WHERE batch_id IN (
  '354875b5-2ecc-4df0-985c-1fe2168eb6c7',
  '1d6936ec-4462-4a87-92c7-8643374df82a',
  'f2ccf5da-4333-43c2-9cf3-19562b46230e',
  'c4ec9174-88fc-4db7-8137-e4861c189e77',
  '0e15d579-66bb-4b55-821e-3ca5df5a03fa',
  '52bab6d2-ba2e-4a20-8c3d-36aec33c3763',
  '417233b5-bfc8-473e-92d1-f35c93107e18'
);

-- [CLEANUP] Remove the two now-empty test decks, guarded to only touch rows the trigger has
-- already confirmed are card_count = 0 post-delete (never a blind delete by id)
DELETE FROM flashcard_decks
WHERE id IN ('64a21016-eae5-4677-a47c-bf1fbe3a64a6', 'be5744d7-cd60-4398-b6ee-37276751121f')
  AND card_count = 0;

-- [TEST] Verify cleanup — all three should be 0
SELECT
  (SELECT count(*) FROM flashcards WHERE front_text ILIKE 'Sprint 8.7.2%' OR front_text = 'refactor smoke test front') AS remaining_flashcards,
  (SELECT count(*) FROM flashcard_batch_provenance WHERE content_source_name ILIKE '%8.7.2%') AS remaining_provenance,
  (SELECT count(*) FROM flashcard_decks WHERE id IN ('64a21016-eae5-4677-a47c-bf1fbe3a64a6', 'be5744d7-cd60-4398-b6ee-37276751121f')) AS remaining_test_decks;
