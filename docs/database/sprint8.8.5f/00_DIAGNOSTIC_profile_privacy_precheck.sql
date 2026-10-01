-- Sprint 8.8.5f (profile privacy) - Step 0 pre-check. READ-ONLY.
-- Name: [DIAGNOSTIC] Profile privacy pre-check
-- Description: Reads the LIVE catalog for everything that exposes profiles.email (and other private profile columns) to
--   signed-in users: column privileges, policies, views, and every function that returns or filters by email.
--   Run each block separately in the Supabase SQL Editor and paste the results. Nothing here writes data.

-- A. profiles policies (SELECT especially)
SELECT policyname, cmd, roles, qual, with_check FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profiles' ORDER BY cmd, policyname;

-- B. Which client roles can SELECT which profiles columns (table-level grant shows as every column)
SELECT grantee, column_name, privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public' AND table_name = 'profiles' AND grantee IN ('anon', 'authenticated')
  AND privilege_type = 'SELECT'
ORDER BY grantee, column_name;

-- C. Table-level privileges on profiles for client roles
SELECT grantee, privilege_type FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'profiles' AND grantee IN ('anon', 'authenticated')
ORDER BY grantee, privilege_type;

-- D. Views (or materialized views) that read profiles - they would bypass or inherit column limits
SELECT schemaname, viewname FROM pg_views WHERE schemaname = 'public' AND definition ILIKE '%profiles%'
UNION ALL
SELECT schemaname, matviewname FROM pg_matviews WHERE schemaname = 'public' AND definition ILIKE '%profiles%';

-- E. Functions that RETURN an email column/value (by result type) - who can call them
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       pg_get_function_result(p.oid) AS returns,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND pg_get_function_result(p.oid) ILIKE '%email%'
ORDER BY p.proname;

-- F. Functions whose BODY reads profiles.email at all (finds jsonb-returning ones that hide email inside) - names only
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
  AND (pg_get_functiondef(p.oid) ~* '(\.|\s)email\b' OR pg_get_functiondef(p.oid) ILIKE '%masked_email%')
ORDER BY p.proname;

-- G. How many users hold each role (sizes the admin-only email surface)
SELECT role, count(*) FROM public.profiles GROUP BY role ORDER BY role;
