-- Name: [TEST] Sprint 8.7.2 — verify batch_description fix (code-review finding, fixed pre-ship)
SELECT id, batch_id, batch_description, source, front_text
FROM public.flashcards
WHERE front_text = 'Sprint 8.7.2 batch label retest card'
ORDER BY created_at DESC LIMIT 3;
