-- Name: [TEST] Sprint 8.7.2 — verify create_flashcard_batches signature/grants after deploy
--
-- Description: Run immediately after 01_FUNCTIONS_creation_channel.sql. Confirms the
-- 4-arg signature is the ONLY one that exists at the database level (DB-level half of
-- the migration-safety check — the other half, confirming PostgREST's API surface
-- actually exposes the new signature and no longer resolves the old one, requires a
-- real HTTP/RPC call and is done separately, not via SQL — see sprint notes).

-- T1: exactly one overload, with the new 4-arg signature
SELECT p.oid::regprocedure AS overload
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'create_flashcard_batches';
-- EXPECT: exactly 1 row: create_flashcard_batches(text, text, jsonb, text)

-- T2: full definition includes p_creation_channel validation, scenario, source
SELECT pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'create_flashcard_batches';
-- EXPECT: body contains 'p_creation_channel', 'scenario', and the INSERT column list
-- ends with '..., subtype, scenario, source)'

-- T3: grants — authenticated only, anon/PUBLIC revoked
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public' AND routine_name = 'create_flashcard_batches';
-- EXPECT: authenticated (EXECUTE), postgres/service_role only — no anon, no PUBLIC

-- T4: old 3-arg signature is gone at the DB level
SELECT count(*) AS should_be_zero
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'create_flashcard_batches'
  AND pg_get_function_identity_arguments(p.oid) = 'p_source_type text, p_source_name text, p_batches jsonb';
-- EXPECT: 0
