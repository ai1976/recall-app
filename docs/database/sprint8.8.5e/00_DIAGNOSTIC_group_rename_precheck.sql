-- ============================================================================
-- Sprint 8.8.5e (deferred #7: group rename) - Step 0 pre-check. READ-ONLY.
-- Name: [DIAGNOSTIC] Group rename pre-check
-- Description: Catalog + data checks for renaming study_groups.name. Run each
-- block separately in the Supabase SQL Editor and send me the results.
-- Nothing here writes data.
-- ============================================================================

-- A. Constraints on study_groups (any UNIQUE/CHECK on name?)
SELECT conname, contype, pg_get_constraintdef(oid) AS def
FROM pg_constraint WHERE conrelid = 'public.study_groups'::regclass ORDER BY contype, conname;

-- B. Indexes on study_groups (unique index on name?)
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename='study_groups';

-- C. Triggers anywhere in public that touch study_groups (broad scan)
SELECT trigger_name, event_object_table, event_manipulation, action_statement
FROM information_schema.triggers WHERE trigger_schema='public'
ORDER BY event_object_table, trigger_name;

-- D. RLS policies on study_groups
SELECT policyname, cmd, roles, qual, with_check FROM pg_policies
WHERE schemaname='public' AND tablename='study_groups';

-- E. Column grants on study_groups for client roles
SELECT grantee, privilege_type, column_name
FROM information_schema.column_privileges
WHERE table_schema='public' AND table_name='study_groups'
  AND grantee IN ('anon','authenticated') AND privilege_type='UPDATE'
ORDER BY grantee, column_name;

-- F. Existing functions that write study_groups or name text (rename candidates / name copies)
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND (pg_get_functiondef(p.oid) ILIKE '%update study_groups%'
    OR pg_get_functiondef(p.oid) ILIKE '%update public.study_groups%')
ORDER BY 1;

-- G. Current groups: names, type, archived, duplicates by (course, institution, lower(name))
SELECT id, name, group_type, is_batch_group, batch_course, batch_institution,
       archived_at IS NOT NULL AS archived,
       count(*) OVER (PARTITION BY lower(btrim(name))) AS same_name_count
FROM public.study_groups ORDER BY is_batch_group DESC, name;

-- H. Stored copies of the group name: notifications (data jsonb) and archive snapshots
SELECT type, count(*) AS n,
       count(*) FILTER (WHERE data ? 'group_name') AS with_group_name
FROM public.notifications
WHERE data ? 'group_name' OR type ILIKE '%group%' OR type ILIKE '%batch%'
GROUP BY type ORDER BY n DESC;

SELECT count(*) AS archive_snapshots,
       count(*) FILTER (WHERE report #>> '{group,name}' IS NOT NULL) AS snapshots_with_name
FROM public.batch_group_archives;

-- I. Does anything else hold the name as text? (columns named like *group_name*)
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema='public' AND column_name ILIKE '%group_name%';
