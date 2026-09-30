-- [DIAGNOSTIC] Deferred bug #5 - batch join requests: bulk approve (pre-check, 30/09/2026)
-- Description: READ-ONLY. Today an admin approves/rejects pending batch join requests ONE AT A TIME
--   (AdminDashboard.jsx -> approve_batch_join_request(membership_id) / reject_batch_join_request(membership_id), admin-only,
--   no audit entry, no notification). Before designing a bulk action this shows, from the LIVE database (the repo SQL files
--   have drifted before):
--     1. the live function bodies (approve / reject / pending list / join by token)
--     2. how many requests are pending, in which batches, how old, and who is asking (role / account type / status)
--     3. the membership table's rules (status values, uniqueness) and any trigger that fires on an approval
--     4. membership counts by status per batch (to size the work and see archived batches)
-- Run each block separately and paste all results.

-- Block 1: live definitions
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('approve_batch_join_request', 'reject_batch_join_request', 'get_admin_pending_batch_requests', 'join_group_by_token')
ORDER BY p.proname;

-- Block 2a: pending requests per batch
SELECT sg.name AS batch, sg.batch_course, sg.batch_institution,
       (sg.archived_at IS NOT NULL) AS batch_is_archived,
       count(*) AS pending_requests,
       min(sgm.joined_at)::date AS oldest_request,
       max(sgm.joined_at)::date AS newest_request
FROM public.study_group_members sgm
JOIN public.study_groups sg ON sg.id = sgm.group_id
WHERE sgm.status = 'requested'
GROUP BY sg.name, sg.batch_course, sg.batch_institution, sg.archived_at
ORDER BY pending_requests DESC;

-- Block 2b: who is asking (role / account type / profile status), and does the asker's course match the batch's course?
SELECT p.role, p.account_type, COALESCE(p.status, 'active') AS profile_status,
       count(*) AS pending_requests,
       count(*) FILTER (WHERE p.course_level IS DISTINCT FROM sg.batch_course) AS course_differs_from_batch
FROM public.study_group_members sgm
JOIN public.study_groups sg ON sg.id = sgm.group_id
JOIN public.profiles p ON p.id = sgm.user_id
WHERE sgm.status = 'requested'
GROUP BY p.role, p.account_type, COALESCE(p.status, 'active')
ORDER BY pending_requests DESC;

-- Block 3a: study_group_members structure and constraints
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_group_members'
ORDER BY ordinal_position;

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_group_members'::regclass
ORDER BY conname;

-- Block 3b: triggers that fire on study_group_members (would run once PER ROW in a bulk update)
SELECT trigger_name, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public' AND event_object_table = 'study_group_members'
ORDER BY trigger_name, event_manipulation;

-- Block 4: membership by status per batch (all batches, including archived)
SELECT sg.name AS batch, (sg.archived_at IS NOT NULL) AS archived,
       count(*) FILTER (WHERE sgm.status = 'active')    AS active_members,
       count(*) FILTER (WHERE sgm.status = 'requested') AS pending,
       count(*) FILTER (WHERE sgm.status = 'invited')   AS invited,
       count(*) FILTER (WHERE sgm.status = 'closed')    AS closed
FROM public.study_groups sg
LEFT JOIN public.study_group_members sgm ON sgm.group_id = sg.id
WHERE sg.is_batch_group = true
GROUP BY sg.name, sg.archived_at
ORDER BY archived, sg.name;

-- Block 5: does an approval leave any trace today? (audit + notification types seen for batch membership)
SELECT 'admin_audit_log' AS source, action AS kind, count(*) AS entries
FROM public.admin_audit_log
WHERE action ILIKE '%batch%' OR action ILIKE '%member%' OR action ILIKE '%join%'
GROUP BY action
UNION ALL
SELECT 'notifications', type, count(*)
FROM public.notifications
WHERE type ILIKE '%batch%' OR type ILIKE '%group%' OR type ILIKE '%join%'
GROUP BY type
ORDER BY 1, 2;
