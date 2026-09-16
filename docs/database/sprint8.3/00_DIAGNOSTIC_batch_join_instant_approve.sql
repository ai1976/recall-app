-- ============================================================================
-- Name: [DIAGNOSTIC] Batch join instant-approve anomaly (TestOutlook / TEST batch)
-- Description: Sprint 8.3 discovered a student account (TestOutlook,
--   anandmore@outlook.com) landed as an ACTIVE member of a batch group
--   immediately after clicking "Request to Join" on its invite link, instead
--   of the documented status='requested' pending-approval row. Per
--   docs/database/sprint8.0/02_FUNCTIONS_batch_join_approval.sql, a student
--   joining a batch group should always insert status='requested' — only a
--   non-student caller (professor/admin/super_admin) should insert
--   status='active' directly. This script checks three things:
--   1. The CURRENTLY DEPLOYED body of join_group_by_token (the docs/ .sql
--      file may be stale relative to what's actually live in Supabase).
--   2. TestOutlook's real profiles.role at the DB level (not the admin UI
--      badge, in case of a stale client cache).
--   3. The actual study_group_members row(s) created for TestOutlook joining
--      the "TEST — Demo Batch (Screenshot Sandbox, delete after)" batch
--      group, including status and joined_at.
-- Run in: Supabase Dashboard -> SQL Editor -> New Query. Read-only, safe to
--   run anytime.
-- ============================================================================

-- 1. Currently deployed join_group_by_token definition
SELECT pg_get_functiondef(oid) AS live_function_body
FROM pg_proc
WHERE proname = 'join_group_by_token';

-- 2. TestOutlook's real role at the DB level
SELECT id, email, full_name, role, account_type, course_level
FROM profiles
WHERE email = 'anandmore@outlook.com';

-- 3. The actual membership row(s) for TestOutlook in the TEST batch group
SELECT
  sgm.id,
  sgm.group_id,
  sg.name AS group_name,
  sg.is_batch_group,
  sg.group_type,
  sgm.user_id,
  p.email,
  p.role AS member_role_at_query_time,
  sgm.role AS group_role,
  sgm.status,
  sgm.joined_at,
  sgm.invited_by
FROM study_group_members sgm
JOIN study_groups sg ON sg.id = sgm.group_id
JOIN profiles p ON p.id = sgm.user_id
WHERE sg.name LIKE 'TEST %Screenshot Sandbox%'
ORDER BY sgm.joined_at DESC;
