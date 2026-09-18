-- Name: [TEST] Sprint 8.7.2 — verify live-created rows from browser verification
--
-- Description: Ad-hoc checks run during §4 live verification. Not idempotent /
-- not meant to be re-run automatically — each query below targets rows created
-- during this session's manual browser testing (matched by front_text/back_text
-- markers used in the test data), to confirm the RPC's actual writes match the
-- migrated frontend's intent.

-- 4.1: manual creation, ordinary student, flashcard type
SELECT id, user_id, contributed_by, creator_id, content_creator_id, deck_id, batch_id,
       question_type, source, is_verified, visibility, created_at, front_text, back_text
FROM public.flashcards
WHERE front_text = 'Sprint 8.7.2 verification front'
ORDER BY created_at DESC
LIMIT 5;

-- Matching provenance row
SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_by, p.created_at
FROM public.flashcard_batch_provenance p
JOIN public.flashcards fc ON fc.batch_id = p.batch_id
WHERE fc.front_text = 'Sprint 8.7.2 verification front';
