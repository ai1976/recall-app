-- [DIAGNOSTIC] Step 0 for the study-timer integrity fix (session_id + duration integrity)
-- Description: READ-ONLY. Confirms, from the live catalog and data (not from code/docs):
--   1. what constraints / triggers / policies / grants / indexes study_sessions has today
--   2. whether session_id (or a quarantine table) already exists
--   3. how the existing rows behave against the checks I intend to add
--      (ended_at >= started_at, duration_seconds <= wall-clock span + 2s, non-manual <= 14400s)
--   4. every function / view / materialized view / trigger that reads or writes study_sessions,
--      and any column anywhere that looks like a stored study-time total (possible cache)
-- Run each block separately in the Supabase SQL editor and paste all results back.

-- Block 1a: constraints (catalog)
SELECT conname, convalidated, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass
ORDER BY conname;

-- Block 1b: triggers on the table (real ones only)
SELECT tgname, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal;

-- Block 1c: RLS state + policies
SELECT c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c WHERE c.oid = 'public.study_sessions'::regclass;

SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'study_sessions';

-- Block 1d: grants + indexes
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'study_sessions'
ORDER BY grantee, privilege_type;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'study_sessions';

-- Block 2: do session_id / a quarantine table already exist? (expect: no rows in both)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_sessions'
ORDER BY ordinal_position;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name ILIKE '%study_session%';

-- Block 3a: existing rows vs the proposed checks, by source
SELECT source,
       count(*) AS total_rows,
       count(*) FILTER (WHERE ended_at < started_at) AS ended_before_started,
       count(*) FILTER (WHERE duration_seconds > extract(epoch FROM (ended_at - started_at)) + 2) AS duration_exceeds_span,
       count(*) FILTER (WHERE duration_seconds > 14400) AS over_4h,
       count(*) FILTER (WHERE ended_at > now() + interval '5 minutes') AS ended_in_future,
       count(*) FILTER (WHERE session_date <> (ended_at AT TIME ZONE 'Asia/Kolkata')::date) AS date_differs_from_ended_ist
FROM public.study_sessions
GROUP BY source
ORDER BY source;

-- Block 3b: the specific rows that break "duration exceeds span" (first 20), so we know
-- whether the real writers ever produced inconsistent timestamps
SELECT id, user_id, source, started_at, ended_at, duration_seconds,
       round(extract(epoch FROM (ended_at - started_at))) AS span_seconds
FROM public.study_sessions
WHERE duration_seconds > extract(epoch FROM (ended_at - started_at)) + 2
ORDER BY duration_seconds DESC
LIMIT 20;

-- Block 4a: functions (any schema you own) whose body mentions study_sessions - readers AND writers
SELECT n.nspname AS schema, p.proname AS function_name,
       (pg_get_functiondef(p.oid) ~* 'insert[[:space:]]+into[[:space:]]+(public[.])?study_sessions')  AS inserts,
       (pg_get_functiondef(p.oid) ~* 'update[[:space:]]+(public[.])?study_sessions')                   AS updates,
       (pg_get_functiondef(p.oid) ~* 'delete[[:space:]]+from[[:space:]]+(public[.])?study_sessions')   AS deletes
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prokind = 'f'
  AND n.nspname IN ('public')
  AND pg_get_functiondef(p.oid) ILIKE '%study_sessions%'
ORDER BY p.proname;

-- Block 4b: views / materialized views that reference it
SELECT schemaname, viewname AS name, 'view' AS kind FROM pg_views
WHERE definition ILIKE '%study_sessions%' AND schemaname = 'public'
UNION ALL
SELECT schemaname, matviewname, 'materialized view' FROM pg_matviews
WHERE definition ILIKE '%study_sessions%' AND schemaname = 'public';

-- Block 4c: any column that could be a stored (cached) study-time total
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (column_name ILIKE '%study_sec%' OR column_name ILIKE '%study_time%'
       OR column_name ILIKE '%study_min%' OR column_name ILIKE '%total_study%')
ORDER BY table_name, column_name;

-- Block 4d: cron jobs that touch study_sessions (pg_cron), if pg_cron is installed
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE command ILIKE '%study_sessions%';
