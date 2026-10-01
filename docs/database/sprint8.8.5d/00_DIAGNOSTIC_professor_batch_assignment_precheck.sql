-- Sprint 8.8.5d (explicit professor <-> batch assignment) - Step 0 pre-check. READ-ONLY.
-- Name: [DIAGNOSTIC] Professor-to-batch assignment pre-check
-- Description: Reads the LIVE catalog (never the docs) for every path through which a professor sees a batch: the live bodies of the
--   batch report / list / detail functions, any other function that mixes 'professor' with batches, RLS policies on the group tables,
--   whether an assignment table already exists, and who the professors are and which batches they sit in. Run each block separately in the
--   Supabase SQL Editor and paste the results. Nothing here writes data.

-- A. Live definitions of the functions named in D-44 (+ the admin list and the archive/restore functions that call the stats function)
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_my_batch_groups', 'get_batch_group_member_stats', 'get_batch_group_archive', 'get_group_detail',
                    'get_admin_batch_groups', 'archive_batch_group', 'restore_batch_group')
ORDER BY p.proname;

-- B. ANY other function whose body mentions professor AND batches / study groups (a second path we may not know about)
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%professor%'
  AND (pg_get_functiondef(p.oid) ILIKE '%is_batch_group%' OR pg_get_functiondef(p.oid) ILIKE '%study_group%' OR pg_get_functiondef(p.oid) ILIKE '%batch_%')
  AND p.proname NOT IN ('get_my_batch_groups', 'get_batch_group_member_stats', 'get_batch_group_archive', 'get_group_detail')
ORDER BY p.proname;

-- C. Does anything like an assignment table already exist?
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND (table_name ILIKE '%professor%' OR table_name ILIKE '%batch%')
ORDER BY table_name;

-- D. RLS policies on the group tables (can a professor read batch rows directly?)
SELECT tablename, policyname, cmd, roles, qual, with_check FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('study_groups', 'study_group_members', 'content_group_shares')
ORDER BY tablename, cmd, policyname;

-- E. The professors: who, status, and every group they sit in (their membership rows would show up in student reports)
SELECT p.id, p.full_name, p.role, p.status, p.course_level,
       sg.name AS group_name, sg.is_batch_group, sg.archived_at IS NOT NULL AS archived,
       m.role AS member_role, m.status AS member_status
FROM public.profiles p
LEFT JOIN public.study_group_members m ON m.user_id = p.id
LEFT JOIN public.study_groups sg ON sg.id = m.group_id
WHERE p.role = 'professor'
ORDER BY p.full_name, sg.name;

-- F. Batch groups: size, and how many of the members are NOT students (staff counted in the student report today)
SELECT sg.id, sg.name, sg.batch_course, sg.batch_institution, sg.archived_at IS NOT NULL AS archived,
       count(*) FILTER (WHERE m.status = 'active') AS active_members,
       count(*) FILTER (WHERE m.status = 'active' AND p.role = 'student') AS students,
       count(*) FILTER (WHERE m.status = 'active' AND p.role = 'professor') AS professors,
       count(*) FILTER (WHERE m.status = 'active' AND p.role IN ('admin', 'super_admin')) AS admins
FROM public.study_groups sg
LEFT JOIN public.study_group_members m ON m.group_id = sg.id
LEFT JOIN public.profiles p ON p.id = m.user_id
WHERE sg.is_batch_group = true
GROUP BY sg.id, sg.name, sg.batch_course, sg.batch_institution, sg.archived_at
ORDER BY sg.name;

-- G. Existing archive snapshots (a snapshot freezes the member list incl. any professors who were members at the time)
SELECT group_id, archived_at, jsonb_array_length(report->'members') AS members_in_snapshot
FROM public.batch_group_archives ORDER BY archived_at;
