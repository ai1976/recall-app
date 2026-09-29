-- Name: [DIAGNOSTIC] Every writer of the protected profiles columns (pre-flight for 19 / 20)
-- Description: READ ONLY. The guard in 19 must not break any legitimate workflow, and 20_TEST must PROVE
--   the real workflows, not just assert them. This lists every database object that can UPDATE
--   profiles, so 20_TEST can call each real one inside its rollback. Run each block separately and paste.

-- 1. Public functions that UPDATE profiles (with the SET clause snippet, so protected columns show).
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid)                         AS args,
       p.prosecdef                                                        AS security_definer,
       pg_get_userbyid(p.proowner)                                        AS owner,
       substring(p.prosrc from '(?i)update\s+(?:public\.)?profiles[^;]{0,240}') AS update_snippet
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ~* 'update\s+(public\.)?profiles'
ORDER BY p.proname;

-- 2. Of those, the ones that touch a PROTECTED column (role, account_type, status, email,
--    access_request_ref, id). These are the workflows 20_TEST must exercise for real.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ~* 'update\s+(public\.)?profiles[^;]{0,250}\m(role|account_type|status|email|access_request_ref)\M'
ORDER BY p.proname;

-- 3. Triggers on auth.users (e.g. a sync that writes profiles) and the functions they run.
SELECT t.tgname, pg_get_triggerdef(t.oid) AS trigger_def, p.proname AS function_name,
       p.prosecdef AS security_definer, pg_get_userbyid(p.proowner) AS owner
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'auth.users'::regclass AND NOT t.tgisinternal;

-- 4. Views or policies that reference profiles columns in a way a rewritten UPDATE could matter: none
--    expected. Listed for completeness - any updatable view over profiles?
SELECT c.relname, c.relkind
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('v', 'm')
  AND pg_get_viewdef(c.oid) ILIKE '%profiles%';
