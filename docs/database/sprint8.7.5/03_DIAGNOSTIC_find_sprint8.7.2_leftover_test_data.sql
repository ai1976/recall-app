-- Name: [DIAGNOSTIC] Find leftover Sprint 8.7.2 verification test data
-- Description: Sprint 8.7.2 (18/09/2026, a prior session) live-verified flashcard creation via
-- create_flashcard_batches() but, unlike 8.7.3/8.7.4, never had a cleanup script written or run —
-- confirmed by the absence of any 09_CLEANUP-style file in docs/database/sprint8.7.2/. The operator
-- is now seeing this leftover data live in the app (Sprint 8.7.5 session, 18/09/2026). This query
-- enumerates it before any deletion — per this project's DB debugging rule, find ALL rows first,
-- don't guess from memory of what the test scripts probably created.

-- [DIAGNOSTIC] Flashcards matching known 8.7.2 test front_text patterns
SELECT id, front_text, batch_id, deck_id, visibility, source, created_at
FROM flashcards
WHERE front_text ILIKE 'Sprint 8.7.2%'
ORDER BY created_at;

-- [DIAGNOSTIC] Provenance rows created for 8.7.2's own verification
SELECT batch_id, content_source_type, content_source_name, created_by, created_at
FROM flashcard_batch_provenance
WHERE content_source_name ILIKE '%8.7.2%'
ORDER BY created_at;

-- [DIAGNOSTIC] Broader net — any flashcard whose batch_id ties to an 8.7.2-labelled provenance row,
-- in case a card's own front_text doesn't literally contain "Sprint 8.7.2" (e.g. bulk-upload rows)
SELECT fc.id, fc.front_text, fc.batch_id, fc.deck_id, fc.visibility, fc.source, fc.created_at
FROM flashcards fc
JOIN flashcard_batch_provenance bp ON bp.batch_id = fc.batch_id
WHERE bp.content_source_name ILIKE '%8.7.2%'
ORDER BY fc.created_at;
