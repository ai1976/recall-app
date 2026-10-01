-- Sprint 8.8.5f (profile privacy) - Step 0 follow-up. READ-ONLY.
-- Name: [DIAGNOSTIC] Profile privacy follow-up - get_author_profile and whole-row returners
-- Description: The first pre-check did not list get_author_profile among functions that read email, although earlier notes said it
--   returns the full email. This finds out whether it exists, what it returns, and whether any function hands back whole profile
--   rows (to_jsonb / row_to_json / SETOF profiles / p.*), which would also leak email without naming the column.

-- A. get_author_profile: does it exist, who can run it, and its full definition
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_author_profile';

-- B. Any function that could return whole profile rows without naming email
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       pg_get_function_result(p.oid) AS returns,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
  AND ( pg_get_function_result(p.oid) ILIKE '%profiles%'
     OR pg_get_functiondef(p.oid) ~* '(to_jsonb|row_to_json|to_json)\s*\(\s*(p|pr|prof|profiles|u)\s*\)'
     OR pg_get_functiondef(p.oid) ~* '\m(p|pr|prof|profiles)\.\*' )
ORDER BY p.proname;

-- C. Triggers/functions in the auth schema that copy emails elsewhere (so a column limit cannot be bypassed that way)
SELECT p.proname, n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND pg_get_functiondef(p.oid) ILIKE '%auth.users%' AND p.prokind = 'f' ORDER BY p.proname;
