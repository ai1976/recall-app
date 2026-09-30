-- [DIAGNOSTIC] Follow-up to 00: what does "Delete study set and ALL its cards" really delete, and is the audit log tamper-proof?
-- Description: READ-ONLY. Run each block separately and paste all results.

-- Block 1: every foreign key that points at flashcard_decks (does deleting a deck cascade to cards or anything else?)
SELECT c.conrelid::regclass AS referencing_table, c.conname, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.contype = 'f' AND c.confrelid = 'public.flashcard_decks'::regclass;

-- Block 2: flashcards.deck_id - is there a foreign key on it at all?
SELECT c.conname, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.contype = 'f' AND c.conrelid = 'public.flashcards'::regclass;

-- Block 3: how many flashcards would be left behind if a deck row were deleted (cards sharing the deck's 5 grouping columns,
-- or pointing at it via deck_id) - top 10 decks by card count
SELECT d.id AS deck_id, d.card_count, d.visibility,
       (SELECT count(*) FROM public.flashcards f WHERE f.deck_id = d.id) AS cards_by_deck_id,
       (SELECT count(*) FROM public.flashcards f
         WHERE f.user_id = d.user_id
           AND f.subject_id IS NOT DISTINCT FROM d.subject_id
           AND f.topic_id IS NOT DISTINCT FROM d.topic_id
           AND f.custom_subject IS NOT DISTINCT FROM d.custom_subject
           AND f.custom_topic IS NOT DISTINCT FROM d.custom_topic) AS cards_by_grouping
FROM public.flashcard_decks d
ORDER BY d.card_count DESC NULLS LAST
LIMIT 10;

-- Block 4: what maintains flashcard_decks rows - does inserting a card re-create a missing deck?
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname ILIKE '%update_deck_card_count%';

-- Block 5: the admin_audit_log table - columns and who could forge/alter entries
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'admin_audit_log'
ORDER BY ordinal_position;

SELECT l.action, count(*) AS entries,
       count(*) FILTER (WHERE l.admin_id IS NULL) AS null_admin_id
FROM public.admin_audit_log l
GROUP BY l.action
ORDER BY l.action;
