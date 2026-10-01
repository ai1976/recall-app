-- Sprint 8.8.5f - corrected Block F of 00. READ-ONLY.
-- Name: [DIAGNOSTIC] Functions that read or return profiles.email (corrected word-boundary)
-- Description: Block F of 00 used \b, which in PostgreSQL regular expressions means "backspace", not "word boundary" (that is \y).
--   So it only found functions mentioning masked_email and MISSED functions that use a plain email column (e.g. get_author_profile).
--   This version uses \y. Paste the result.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       pg_get_function_result(p.oid) AS returns,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
  AND ( pg_get_functiondef(p.oid) ~* '\yemail\y' OR pg_get_functiondef(p.oid) ILIKE '%masked_email%' )
ORDER BY p.proname;
