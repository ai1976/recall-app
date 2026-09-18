-- Name: [TEST] Sprint 8.7.2 — verify bulk upload (§4.4, §4.5 browser half, §4.6)
-- Confirms: source='bulk_upload' (closes the source bug), case_study_mcq scenario
-- text carried through, case group split into its own batch_id distinct from the
-- plain card's batch_id, provenance correct for both batches.

SELECT id, batch_id, question_type, source, scenario, options, correct_answer,
       explanation, deck_id, created_at, front_text
FROM public.flashcards
WHERE front_text IN (
  'Sprint 8.7.2 bulk test plain card',
  'Sprint 8.7.2 bulk case Q1',
  'Sprint 8.7.2 bulk case Q2'
)
ORDER BY created_at DESC;

SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_by
FROM public.flashcard_batch_provenance p
WHERE p.batch_id IN (
  SELECT DISTINCT batch_id FROM public.flashcards
  WHERE front_text IN (
    'Sprint 8.7.2 bulk test plain card',
    'Sprint 8.7.2 bulk case Q1',
    'Sprint 8.7.2 bulk case Q2'
  )
);
