-- Name: [TEST] Sprint 8.7.2 — verify professor-authorized MCQ creation (§4.3)
SELECT id, user_id, contributed_by, question_type, options, correct_answer,
       source, is_verified, batch_id, created_at
FROM public.flashcards
WHERE front_text = 'Sprint 8.7.2 professor MCQ question'
ORDER BY created_at DESC
LIMIT 5;

SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_by
FROM public.flashcard_batch_provenance p
JOIN public.flashcards fc ON fc.batch_id = p.batch_id
WHERE fc.front_text = 'Sprint 8.7.2 professor MCQ question';
