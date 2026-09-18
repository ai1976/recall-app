-- Name: [DIAGNOSTIC] Sprint 8.7.4 pre-flight — provenance read policy + RPC baselines
--
-- Description: Run before any 8.7.4 schema change. Confirms three things the
-- sprint's design depends on, rather than assuming them from prior sprints'
-- docs (which were correct as of 18/09/2026 but this re-verifies live):
--   1. flashcard_batch_provenance still has zero SELECT policies (8.7.1's
--      deliberate deferral) — if a policy already exists, section 1 below
--      shows its name/definition and 01_SCHEMA must NOT blindly add a second one.
--   2. The exact current return signatures of get_browsable_decks,
--      get_browsable_notes, and get_study_queue — the DROP FUNCTION in each
--      02_FUNCTIONS_* file must match these exactly or the DROP will fail
--      (wrong arg types) or silently miss an overload.
--   3. Confirms notes.content_source_type / content_source_name exist (8.7.1)
--      and are already reachable via `SELECT *` on notes (no RLS surprise).

-- 1. flashcard_batch_provenance: policy list (expect ZERO rows)
SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE tablename = 'flashcard_batch_provenance';

-- 2. Confirm RLS is enabled + current grants on flashcard_batch_provenance
SELECT relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE oid = 'public.flashcard_batch_provenance'::regclass;

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'flashcard_batch_provenance'
ORDER BY grantee, privilege_type;

-- 3. Exact live signatures for every function this sprint replaces
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS returns
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_browsable_decks', 'get_browsable_notes', 'get_study_queue');

-- 4. Confirm notes provenance columns exist and are plain columns (no column-level
--    RLS/masking — this project doesn't use that, but verify not assumed)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'notes'
  AND column_name IN ('content_source_type', 'content_source_name');

-- 5. Sanity: how many live flashcard_batch_provenance rows exist right now
--    (informs whether badges will actually be visible post-deploy, or whether
--    everything currently live is still pre-8.7.2/legacy with no provenance row)
SELECT count(*) AS provenance_rows FROM public.flashcard_batch_provenance;
