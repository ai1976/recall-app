-- Name: [DIAGNOSTIC] Sprint 8.7.1 pre-provenance — live schema/RLS/grant baseline
--
-- Description: Run BEFORE writing any DDL for the content-provenance foundation
-- (flashcard_batch_provenance table, notes provenance columns, create_flashcard_batches
-- RPC, RLS changes). Captures the exact live state so the migration can be reconciled
-- against reality rather than stale docs. Per sprint 8.7.1 spec, the pre-flight summary
-- claims flashcards INSERT authorization is TWO policies (users_insert_flashcards
-- PERMISSIVE + flashcards_gate_verdict_types_insert RESTRICTIVE, D-10) — this query
-- re-verifies that live rather than trusting the summary, since RESTRICTIVE policies
-- are easy to miss if you only look at permissive policies.
--
-- STOP CONDITION: if the results here materially differ from sprint8.7.1's assumptions
-- (policy bodies, column list, batch_id constraints), stop and re-scope before writing
-- 01_SCHEMA / 02_FUNCTIONS / 03_RLS.

-- 1a. Full column list + defaults for flashcards
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcards'
ORDER BY ordinal_position;

-- 1b. Full column list + defaults for notes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'notes'
ORDER BY ordinal_position;

-- 2a. All current RLS policies on flashcards (full USING + WITH CHECK bodies)
SELECT
  polname,
  CASE WHEN polpermissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END AS permissive_type,
  polcmd,
  pg_get_expr(polqual, polrelid) AS using_expr,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expr,
  (SELECT array_agg(rolname) FROM pg_roles WHERE oid = ANY(polroles)) AS roles
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
ORDER BY polname;

-- 2b. All current RLS policies on notes (full USING + WITH CHECK bodies)
SELECT
  polname,
  CASE WHEN polpermissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END AS permissive_type,
  polcmd,
  pg_get_expr(polqual, polrelid) AS using_expr,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expr,
  (SELECT array_agg(rolname) FROM pg_roles WHERE oid = ANY(polroles)) AS roles
FROM pg_policy
WHERE polrelid = 'public.notes'::regclass
ORDER BY polname;

-- 2c. Confirm RLS + FORCE ROW LEVEL SECURITY status on flashcards / notes
SELECT relname, relrowsecurity AS rls_enabled, relforcerowsecurity AS rls_forced
FROM pg_class
WHERE oid IN ('public.flashcards'::regclass, 'public.notes'::regclass);

-- 3a. Current GRANTs on flashcards for authenticated / anon / PUBLIC
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'flashcards'
  AND grantee IN ('authenticated', 'anon', 'PUBLIC')
ORDER BY grantee, privilege_type;

-- 3b. Current GRANTs on notes for authenticated / anon / PUBLIC
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'notes'
  AND grantee IN ('authenticated', 'anon', 'PUBLIC')
ORDER BY grantee, privilege_type;

-- 4a. Existing triggers on flashcards
SELECT trigger_name, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public' AND event_object_table = 'flashcards'
ORDER BY trigger_name;

-- 4b. Existing triggers on notes
SELECT trigger_name, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public' AND event_object_table = 'notes'
ORDER BY trigger_name;

-- 4c. Broad trigger scan (per project rule: filtering by event_object_table alone
-- can miss triggers if schema differs) — full public-schema trigger inventory
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 5. Existing functions/RPCs used by flashcard or note creation paths
SELECT p.proname, pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'is_professor_or_admin',
    'apply_review',
    'submit_review',
    'create_flashcard_batches'
  )
ORDER BY p.proname;

-- 6a. Exact live bodies of the two flashcards INSERT policies named in the spec
SELECT
  polname,
  CASE WHEN polpermissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END AS permissive_type,
  pg_get_expr(polqual, polrelid) AS using_expr,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expr
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('users_insert_flashcards', 'flashcards_gate_verdict_types_insert');

-- 6b. Confirm the verdict-bearing question_type list currently enforced
-- (cross-check against mcq, mcq_multi, match_the_following, case_study_mcq,
-- correct_incorrect, fitb per spec)
SELECT pg_get_constraintdef(oid) AS chk_flashcards_question_type
FROM pg_constraint
WHERE conname = 'chk_flashcards_question_type';

-- 7. Confirm flashcards.batch_id has no existing FK constraint; confirm its
-- data type / nullability / default
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcards' AND column_name = 'batch_id';

SELECT conname, contype, pg_get_constraintdef(oid) AS constraint_def
FROM pg_constraint
WHERE conrelid = 'public.flashcards'::regclass
  AND pg_get_constraintdef(oid) ILIKE '%batch_id%';

-- 8. Table owners relevant to the proposed SECURITY DEFINER RPC
SELECT c.relname, pg_get_userbyid(c.relowner) AS owner
FROM pg_class c
WHERE c.oid IN (
  'public.flashcards'::regclass,
  'public.notes'::regclass,
  'public.profiles'::regclass
);

-- Current role this session will create objects as (relevant for RPC ownership)
SELECT current_user, session_user;

-- 9. flashcards.source / bulk_upload default (known-suspect bug, log only — not fixed this sprint)
SELECT column_name, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcards' AND column_name IN ('source');
