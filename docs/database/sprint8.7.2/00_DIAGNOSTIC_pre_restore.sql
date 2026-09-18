-- Name: [DIAGNOSTIC] Sprint 8.7.2 pre-restore — live RPC contract + source/deck_id baseline
--
-- Description: Run BEFORE writing the create_flashcard_batches() signature change or
-- touching FlashcardCreate.jsx / BulkUploadFlashcards.jsx. Confirms the exact live
-- contract of the RPC deployed in Sprint 8.7.1, the real (not documented) behavior of
-- flashcards.deck_id and flashcards.source, and the exact error shape D-10 rejection
-- produces today. Paste the full result set back so the migration can be written
-- against reality instead of the 8.7.1 completion report or stale doc claims.
--
-- STOP CONDITION: if section 1's signature differs from
-- docs/database/sprint8.7/02_FUNCTIONS_create_flashcard_batches.sql, or section 4/5
-- show deck_id/source behaving differently than the code at
-- src/pages/dashboard/Content/FlashcardCreate.jsx and
-- src/pages/dashboard/BulkUploadFlashcards.jsx suggests, stop and re-scope.

-- 1. Exact live signature, return type, security mode, and body of create_flashcard_batches
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  pg_get_function_result(p.oid) AS returns,
  CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END AS security,
  pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'create_flashcard_batches';

-- 2. Every overload sharing this name (catches an accidental second signature)
SELECT p.oid::regprocedure AS overload
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'create_flashcard_batches';

-- 3. Current EXECUTE grants on the RPC
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public' AND routine_name = 'create_flashcard_batches';

-- 4a. flashcards.deck_id — column definition
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcards' AND column_name = 'deck_id';

-- 4b. flashcards.deck_id — actual population rate, most recent 500 rows
SELECT
  count(*) AS total_sampled,
  count(deck_id) AS deck_id_populated,
  count(*) FILTER (WHERE deck_id IS NULL) AS deck_id_null,
  count(*) FILTER (WHERE source = 'manual') AS from_manual,
  count(*) FILTER (WHERE source = 'bulk_upload') AS from_bulk,
  count(*) FILTER (WHERE deck_id IS NOT NULL AND source = 'manual') AS manual_with_deck_id,
  count(*) FILTER (WHERE deck_id IS NOT NULL AND source = 'bulk_upload') AS bulk_with_deck_id
FROM (SELECT * FROM public.flashcards ORDER BY created_at DESC LIMIT 500) recent;

-- 4c. Does a populated deck_id actually match the row it would resolve to via the
-- 5-column grouping join? (Sanity check that deck_id, where present, is not stale/wrong.)
SELECT fc.id AS flashcard_id, fc.deck_id, fd.id AS resolved_deck_id_via_5col_join,
       (fc.deck_id = fd.id) AS matches
FROM public.flashcards fc
JOIN public.flashcard_decks fd
  ON fc.user_id = fd.user_id
 AND fc.subject_id IS NOT DISTINCT FROM fd.subject_id
 AND fc.topic_id IS NOT DISTINCT FROM fd.topic_id
 AND fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject
 AND fc.custom_topic IS NOT DISTINCT FROM fd.custom_topic
WHERE fc.deck_id IS NOT NULL
ORDER BY fc.created_at DESC
LIMIT 100;

-- 5a. flashcards.source — column definition + any CHECK constraint
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcards' AND column_name = 'source';

SELECT con.conname, pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'flashcards' AND con.contype = 'c'
  AND pg_get_constraintdef(con.oid) ILIKE '%source%';

-- 5b. Current distinct values in production
SELECT source, count(*) FROM public.flashcards GROUP BY source ORDER BY count(*) DESC;

-- 6. is_professor_or_admin() — confirm it still exists with this exact name/signature
-- (create_flashcard_batches calls it directly; if renamed/changed this breaks silently)
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'is_professor_or_admin';

-- 7. flashcard_batch_provenance — confirm columns + constraints (for p_creation_channel addition)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcard_batch_provenance'
ORDER BY ordinal_position;
