-- Sprint 8.8.5d - Step 0 follow-up. READ-ONLY.
-- Name: [DIAGNOSTIC] Block B re-run (always returns a visible result) + what professor memberships grant today
-- Description: (1) Re-runs block B of 00 in a form that ALWAYS returns at least one row, so an empty answer is explicit.
--   (2) Shows what a professor's MEMBERSHIP in an active batch currently grants through membership-based RLS (shared content), so the
--   post-verification clean-up of professor memberships can be planned from facts. Run each block separately and paste the grid.

-- 1. Other functions mixing professor + batches / study groups (explicit zero-row marker)
WITH hits AS (
  SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
         has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f'
    AND pg_get_functiondef(p.oid) ILIKE '%professor%'
    AND (pg_get_functiondef(p.oid) ILIKE '%is_batch_group%' OR pg_get_functiondef(p.oid) ILIKE '%study_group%' OR pg_get_functiondef(p.oid) ILIKE '%batch_%')
    AND p.proname NOT IN ('get_my_batch_groups', 'get_batch_group_member_stats', 'get_batch_group_archive', 'get_group_detail')
)
SELECT proname, args, security_definer, anon_exec FROM hits
UNION ALL
SELECT '(no other function matches)', NULL, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM hits)
UNION ALL
SELECT '== total matches: ' || count(*), NULL, NULL, NULL FROM hits;

-- 2. Content shared into each ACTIVE batch, and by whom (members can read these via cgs_select_member; any active member can add via cgs_insert_member)
SELECT sg.name AS batch, cgs.content_type, count(*) AS shares,
       count(*) FILTER (WHERE p.role = 'professor') AS shared_by_professors,
       count(*) FILTER (WHERE p.role IN ('admin', 'super_admin')) AS shared_by_admins,
       count(*) FILTER (WHERE p.role = 'student') AS shared_by_students
FROM public.study_groups sg
LEFT JOIN public.content_group_shares cgs ON cgs.group_id = sg.id
LEFT JOIN public.profiles p ON p.id = cgs.shared_by
WHERE sg.is_batch_group = true AND sg.archived_at IS NULL
GROUP BY sg.name, cgs.content_type
ORDER BY sg.name, cgs.content_type;

-- 3. Who in an ACTIVE batch is staff (these memberships are the ones the later clean-up would touch)
SELECT sg.name AS batch, p.full_name, p.role, m.role AS member_role, m.status, m.joined_at
FROM public.study_group_members m
JOIN public.study_groups sg ON sg.id = m.group_id AND sg.is_batch_group = true AND sg.archived_at IS NULL
JOIN public.profiles p ON p.id = m.user_id
WHERE p.role IN ('professor', 'admin', 'super_admin') AND m.status = 'active'
ORDER BY sg.name, p.full_name;

-- 4. The exact ids the deploy-day backfill will hard-code (so you can eyeball them before any SQL exists)
SELECT 'professor' AS kind, id::text AS id, full_name AS label, role AS role_now, status FROM public.profiles
WHERE id IN ('fa44711a-8877-47fd-9541-2829cc896908', '075ad481-13e8-45e4-9deb-3c38907eb3e6',
             '795f7baf-91f6-4ee3-958a-50d9094403a8', 'd3050e85-d37d-42b5-8ea5-7e4f47894033')
UNION ALL
SELECT 'batch', id::text, name || ' | ' || batch_course || ' | ' || COALESCE(batch_institution, '-'),
       CASE WHEN archived_at IS NULL THEN 'active' ELSE 'ARCHIVED' END, NULL FROM public.study_groups
WHERE id IN ('7067cc26-fb43-4538-8a3f-7788641aafaf', '77ff6271-16b3-488c-abb3-5f495eed740d', '7c4df0e5-c08a-4b67-b682-a012d6fb5139')
ORDER BY kind, label;
