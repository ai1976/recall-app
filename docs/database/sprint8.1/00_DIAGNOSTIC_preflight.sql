-- Name: [DIAGNOSTIC] Sprint 8.1 pre-flight — batch group archiving
-- Description: Mandatory pre-flight for Sprint 8.1 (Active/Archived workflow for
-- institution batch groups). Confirms the canonical batch identifier
-- (is_batch_group vs group_type), gets exact LIVE bodies of every function this
-- sprint will modify with CREATE OR REPLACE (several committed migration files
-- in docs/database/ have already drifted from what's actually live — do not
-- trust the repo copies), and checks RLS/trigger state relevant to the new
-- archived_at column and the deletion-guard requirement. Read-only. This
-- session has only the anon key (same limitation every sprint since 7.5) — run
-- in the Supabase SQL Editor and paste the full output back.

-- ============================================================================
-- Queries 1-5: RUN — results reviewed 15/09/2026.
-- Findings: is_batch_group and group_type are currently 1:1 consistent on live
-- data (all 3 live batch groups have group_type='batch'); is_batch_group is
-- used as the canonical flag for all archiving logic regardless. 151 active
-- batch memberships across 3 batch groups, 12 active non-batch memberships, no
-- outstanding requested/invited rows at time of check.
-- ============================================================================

-- 1. Live bodies of functions not committed to any SQL file in the repo
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('remove_group_member', 'get_my_batch_groups', 'get_group_detail', 'leave_group')
ORDER BY p.proname;

-- 2. EXECUTE grants on all batch/group RPCs
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN (
    'join_group_by_token','get_group_preview','approve_batch_join_request','reject_batch_join_request',
    'get_admin_pending_batch_requests','get_admin_batch_groups','create_batch_group','enroll_user_in_batch_group',
    'get_batch_group_member_stats','remove_group_member','get_my_batch_groups','get_group_detail','leave_group'
  )
ORDER BY routine_name, grantee;

-- 3. Reconcile group_type vs is_batch_group on live data
SELECT is_batch_group, group_type, count(*) AS n,
       bool_or(batch_course IS NULL OR btrim(batch_course)='') AS any_missing_course,
       bool_or(batch_institution IS NULL OR btrim(batch_institution)='') AS any_missing_institution
FROM study_groups
GROUP BY is_batch_group, group_type
ORDER BY is_batch_group, group_type;

-- 4. study_group_members status distribution for batch vs non-batch groups
SELECT sg.is_batch_group, sgm.status, count(*) AS n
FROM study_group_members sgm
JOIN study_groups sg ON sg.id = sgm.group_id
GROUP BY sg.is_batch_group, sgm.status
ORDER BY sg.is_batch_group, sgm.status;

-- 5. RLS policies currently on study_groups (confirm sg_delete_creator has no batch clause)
-- NOTE: original attempt used the wrong column name (polname); corrected below in query 7.

-- ============================================================================
-- Queries 6-9: PENDING — still need to run and paste back before writing the
-- migration. Gets exact live bodies for everything else Sprint 8.1 touches,
-- since 4 of the 5 functions in Query 1 already turned out to have drifted
-- from their last-committed .sql file — do not assume any of these still
-- match docs/database/study-groups/ or docs/database/sprint8.0/ verbatim.
-- ============================================================================

-- 6. Remaining live function bodies
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'get_group_preview', 'join_group_by_token', 'get_admin_batch_groups',
    'get_batch_group_member_stats', 'create_batch_group', 'enroll_user_in_batch_group',
    'approve_batch_join_request', 'reject_batch_join_request', 'get_admin_pending_batch_requests'
  )
ORDER BY p.proname;

-- 7. RLS policies on study_groups and study_group_members (corrected column name)
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('study_groups', 'study_group_members');

-- 8. Any triggers on study_groups (e.g. updated_at maintenance) to be aware of
SELECT trigger_name, event_manipulation, action_timing, action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public' AND event_object_table = 'study_groups';

-- 9. is_admin() helper body, since several guards call it
SELECT pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'is_admin';
