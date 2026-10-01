-- Sprint 8.8.5d - Step 0 follow-up 2. READ-ONLY.
-- Name: [DIAGNOSTIC] Block B hits - the exact lines that mention professors / batches
-- Description: Block B found 5 other functions whose text mentions "professor" together with batch / study-group words. Most are probably
--   false positives (flashcard "batch_id" and author-role labels), but join_group_by_token is a real study-group path. This prints ONLY the
--   matching lines of each, so we can classify each hit from the live code. Paste the grid.
SELECT p.proname,
       l.ord AS line_no,
       btrim(l.line) AS matching_line
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
CROSS JOIN LATERAL regexp_split_to_table(pg_get_functiondef(p.oid), E'\n') WITH ORDINALITY AS l(line, ord)
WHERE p.proname IN ('get_browsable_notes', 'get_practice_cards', 'get_browsable_decks', 'join_group_by_token', 'create_flashcard_batches')
  AND (l.line ILIKE '%professor%' OR l.line ILIKE '%study_group%' OR l.line ILIKE '%is_batch_group%' OR l.line ILIKE '%group_type%'
       OR l.line ILIKE '%v_caller_role%' OR l.line ILIKE '%auth.uid()%')
ORDER BY p.proname, l.ord;
