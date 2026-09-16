-- [DIAGNOSTIC] Confirm study_sessions rows are immutable after creation
-- Description: Pre-flight for 04_SCHEMA_manual_requires_category.sql. A
-- NOT VALID CHECK constraint is enforced on every future INSERT and UPDATE
-- (just not validated against rows that already existed when it was added).
-- Before relying on "old rows are simply never touched again" as the reason
-- a historical source='manual', category=NULL row can never violate it, this
-- confirms that claim live rather than trusting DATABASE_SCHEMA.md's
-- documented "no UPDATE or DELETE — sessions are immutable" note alone.
-- Three checks: (1) no RLS policy grants UPDATE to any role on this table,
-- (2) no function anywhere in the public schema both references
-- study_sessions and contains an UPDATE statement (rules out a
-- SECURITY DEFINER RPC quietly mutating rows outside RLS), (3) no trigger
-- is attached to the table itself.

-- 1. RLS policies — expect no row with cmd = 'UPDATE' (or 'ALL')
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'study_sessions';

-- 2. Any function whose body references study_sessions AND contains UPDATE
-- expect: 0 rows
SELECT p.proname
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace
  AND pg_get_functiondef(p.oid) ILIKE '%study_sessions%'
  AND pg_get_functiondef(p.oid) ILIKE '%update %';

-- 3. Any trigger attached to study_sessions itself — expect: 0 rows
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal;
