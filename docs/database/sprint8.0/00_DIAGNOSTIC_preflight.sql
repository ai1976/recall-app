-- Name: [DIAGNOSTIC] Sprint 8.0 pre-flight — bulk student addition (batch invite links)
-- Description: Mandatory pre-flight for Sprint 8.0 (admin-generated cohort invite
-- links via study_groups/batch groups). Two of these checks are STOP conditions
-- per the sprint brief — no SQL or frontend code for the enrollment path gets
-- written until the results of Query 1 (and, if it surfaces a problem, Query 3)
-- are reviewed and an explicit decision is made. Read-only. This session has
-- only the anon key (same limitation every sprint since 7.5) — run this in the
-- Supabase SQL Editor and paste the full output back.

-- ============================================================================
-- 1. STOP CONDITION CHECK — fn_auto_enroll_batch_group() exact matching logic.
-- Does this trigger enroll a student into ANY batch group beyond the one
-- specific group resolved from the invite token (e.g. a second batch group
-- that happens to share the same course+institution)? If the WHERE/matching
-- clause is not scoped to a single specific group_id, STOP — do not write any
-- Sprint 8.0 SQL or frontend code for the enrollment path; report this back
-- and wait for an explicit decision.
-- ============================================================================
SELECT pg_get_functiondef(p.oid) AS fn_auto_enroll_batch_group_body
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'fn_auto_enroll_batch_group';

-- Trigger wiring for the above (confirm event + timing + table, broad scan
-- per this project's D-07 rule — never filter by event_object_table alone).
SELECT trigger_name, event_object_table, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============================================================================
-- 2. Current bodies/return shapes of the 4 functions Sprint 8.0 extends or
-- reads from. Confirms exact signatures before any DROP/CREATE OR REPLACE,
-- and whether get_admin_batch_groups already returns invite_token.
-- ============================================================================
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS return_type,
       pg_get_functiondef(p.oid) AS body
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('join_group_by_token', 'get_group_preview', 'get_admin_batch_groups', 'create_batch_group');

-- ============================================================================
-- 3. DATA QUALITY CHECK — any live batch group with NULL/empty
-- batch_course or batch_institution? The admin UI's create_batch_group form
-- guards against this client-side, but the column is nullable. If any such
-- row exists, note it for the BATCH_MISCONFIGURED test case (test #8).
-- ============================================================================
SELECT id, name, batch_course, batch_institution, invite_token, created_by, created_at
FROM study_groups
WHERE group_type = 'batch'
  AND (batch_course IS NULL OR btrim(batch_course) = ''
       OR batch_institution IS NULL OR btrim(batch_institution) = '');

-- Full inventory of live batch groups (context for the above + for testing).
SELECT id, name, batch_course, batch_institution, invite_token, created_by, created_at
FROM study_groups
WHERE group_type = 'batch'
ORDER BY created_at;

-- ============================================================================
-- 4. RLS on study_groups SELECT — can a non-creator admin read invite_token
-- today via a direct table read (not through a SECURITY DEFINER RPC)?
-- ============================================================================
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr,
       pg_get_expr(polwithcheck, polrelid) AS with_check_expr, polroles::regrole[]
FROM pg_policy
WHERE polrelid = 'public.study_groups'::regclass;

SELECT relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE oid = 'public.study_groups'::regclass;

-- ============================================================================
-- 5a. emailRedirectTo — confirmed by direct code read (AuthContext.jsx
-- signUp()) that no emailRedirectTo is currently passed. No SQL needed for
-- this half. The Supabase Auth "Redirect URLs" allow-list itself must be
-- checked in the Dashboard (Authentication → URL Configuration) — not a SQL
-- query — confirm https://www.revisop.com/** actually covers /join/:token.
-- ============================================================================

-- Supporting: unique constraint backing study_group_members(group_id, user_id)
-- — needed for the ON CONFLICT (group_id, user_id) target in the new upsert.
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.study_group_members'::regclass
  AND contype IN ('u', 'p');

-- Supporting: study_group_members full column list + status CHECK (if any).
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_group_members'
ORDER BY ordinal_position;

SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.study_group_members'::regclass AND contype = 'c';

-- Supporting: profiles columns this sprint writes (role/account_type/
-- course_level/institution) — types + nullability, to match in the RPC.
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
  AND column_name IN ('role', 'account_type', 'course_level', 'institution')
ORDER BY ordinal_position;
