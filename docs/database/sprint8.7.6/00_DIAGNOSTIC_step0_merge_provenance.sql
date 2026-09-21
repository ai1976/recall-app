-- ============================================================================
-- Sprint 8.7.6 STEP 0 — READ-ONLY diagnostics. Nothing here writes or changes anything.
-- Run each numbered block SEPARATELY in the Supabase SQL Editor and paste every result back.
-- (The editor only shows the last statement's result, so run one block at a time.)
-- ============================================================================

-- Name: [DIAGNOSTIC] 1 - All triggers in public schema
-- Description: Broad scan of every trigger in the public schema (not filtered by table),
--   so we can see everything that fires on flashcards / flashcard_batch_provenance.
SELECT trigger_name, event_object_table, event_manipulation, action_timing, action_orientation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name, event_manipulation;

-- Name: [DIAGNOSTIC] 1b - Triggers straight from pg_trigger (cross-check)
-- Description: information_schema can hide triggers (known project gotcha). This reads the catalog
--   directly for flashcards and flashcard_batch_provenance, including the UPDATE-column list.
SELECT c.relname AS table_name, t.tgname, t.tgenabled, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND NOT t.tgisinternal
  AND c.relname IN ('flashcards', 'flashcard_batch_provenance', 'flashcard_decks')
ORDER BY c.relname, t.tgname;

-- Name: [DIAGNOSTIC] 2 - Function definitions touching batch_id / flashcard_batch_provenance
-- Description: Full source of every public function whose body mentions flashcard_batch_provenance
--   or batch_id, plus every function used as a trigger on flashcards/provenance.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       p.proconfig AS config, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND ( pg_get_functiondef(p.oid) ILIKE '%flashcard_batch_provenance%'
     OR pg_get_functiondef(p.oid) ILIKE '%batch_id%'
     OR p.oid IN (SELECT t.tgfoid FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
                  WHERE NOT t.tgisinternal AND c.relname IN ('flashcards','flashcard_batch_provenance')) )
ORDER BY p.proname;

-- Name: [DIAGNOSTIC] 3 - RLS policies on flashcards and flashcard_batch_provenance
-- Description: Every policy (command, roles, USING, WITH CHECK) plus whether RLS is enabled/forced.
SELECT tablename, policyname, cmd, roles, permissive, qual AS using_expr, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('flashcards', 'flashcard_batch_provenance')
ORDER BY tablename, cmd, policyname;

-- Name: [DIAGNOSTIC] 3b - RLS flags and table grants
-- Description: Confirms RLS enabled/forced and which roles hold UPDATE/DELETE grants on both tables.
SELECT c.relname, c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN ('flashcards', 'flashcard_batch_provenance');

SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name IN ('flashcards', 'flashcard_batch_provenance')
  AND grantee IN ('anon', 'authenticated', 'service_role', 'PUBLIC')
ORDER BY table_name, grantee, privilege_type;

-- Name: [DIAGNOSTIC] 4 - flashcard_batch_provenance table shape
-- Description: Columns, primary key, unique constraints, CHECKs and foreign keys (both directions).
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcard_batch_provenance'
ORDER BY ordinal_position;

SELECT conrelid::regclass AS on_table, conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.flashcard_batch_provenance'::regclass
   OR confrelid = 'public.flashcard_batch_provenance'::regclass
ORDER BY contype, conname;

-- Name: [DIAGNOSTIC] 5 - Existing orphan provenance rows (REPORT ONLY)
-- Description: Provenance rows whose batch_id has no flashcards rows. Count + list. NOT cleaned up here.
SELECT count(*) AS orphan_provenance_rows
FROM public.flashcard_batch_provenance p
WHERE NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.batch_id = p.batch_id);

SELECT p.batch_id, p.content_source_type, p.content_source_name, p.created_by, p.created_at
FROM public.flashcard_batch_provenance p
WHERE NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.batch_id = p.batch_id)
ORDER BY p.created_at DESC;

-- Name: [DIAGNOSTIC] 6 - Legacy check (batches with no provenance row)
-- Description: How many distinct batch_ids (and cards) have no provenance row, vs. how many do.
SELECT
  count(DISTINCT f.batch_id) FILTER (WHERE p.batch_id IS NULL)     AS legacy_batches_no_provenance,
  count(DISTINCT f.batch_id) FILTER (WHERE p.batch_id IS NOT NULL) AS batches_with_provenance,
  count(*)                   FILTER (WHERE p.batch_id IS NULL)     AS legacy_cards,
  count(*)                   FILTER (WHERE p.batch_id IS NOT NULL) AS provenanced_cards
FROM public.flashcards f
LEFT JOIN public.flashcard_batch_provenance p ON p.batch_id = f.batch_id
WHERE f.batch_id IS NOT NULL;

-- Name: [DIAGNOSTIC] 7 - NULL batch_id cards
-- Description: How many flashcards have batch_id IS NULL (the "no-batch" group in MyFlashcards).
SELECT count(*) AS null_batch_cards, count(DISTINCT user_id) AS users_affected
FROM public.flashcards
WHERE batch_id IS NULL;

-- Name: [DIAGNOSTIC] 8 - Cross-owner batches (extra, informs the design)
-- Description: Can one batch_id span more than one user_id? Matters because a merge trigger
--   must not assume one owner per batch.
SELECT count(*) AS batches_with_multiple_owners
FROM (SELECT batch_id FROM public.flashcards WHERE batch_id IS NOT NULL
      GROUP BY batch_id HAVING count(DISTINCT user_id) > 1) x;
