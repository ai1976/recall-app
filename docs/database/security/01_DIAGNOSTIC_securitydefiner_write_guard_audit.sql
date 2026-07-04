-- Name: [DIAGNOSTIC] SECURITY DEFINER write-without-guard audit (L5 pre-check)
-- Description: The Supabase Advisor flags ~123 SECURITY DEFINER functions as anon/authenticated
-- EXECUTE-able (lint 0028). Most are defused by an internal caller guard (e.g.
-- approve_educator_application: SELECT role FROM profiles WHERE id=auth.uid(); IF NOT IN
-- ('admin','super_admin') RAISE). The REAL risk is any SECURITY DEFINER function that performs a
-- WRITE (INSERT/UPDATE/DELETE) yet never references the caller (auth.uid() / role / is_admin) —
-- an anon caller could invoke it and cause effects with definer privileges. This audit surfaces
-- exactly those, and dumps the admin_* bodies (notably admin_delete_user_data, which is NOT in the
-- repo) for manual guard review. Prompted 04/07/2026 by the advisor CSV. Read-only.

-- ============================================
-- 1. SECURITY DEFINER functions classified by (writes?) x (references caller?). REVIEW the rows
--    where writes_data = true AND references_caller = false FIRST — those are the candidates for an
--    unguarded, anon-invocable mutation. (Heuristic: a trigger function is safe here because it
--    only runs in trigger context, but it should still have EXECUTE revoked in L5 — see Block 3.)
-- ============================================
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  (pg_get_functiondef(p.oid) ~* '\m(insert into|update |delete from)\M')                       AS writes_data,
  (pg_get_functiondef(p.oid) ~* 'auth\.uid\(\)|is_admin\s*\(|is_super_admin|caller_role|\mrole\M') AS references_caller,
  p.proname LIKE 'fn\_%' ESCAPE '\'                                                             AS looks_like_trigger_fn
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
ORDER BY
  (pg_get_functiondef(p.oid) ~* '\m(insert into|update |delete from)\M') DESC,
  (pg_get_functiondef(p.oid) ~* 'auth\.uid\(\)|is_admin\s*\(|is_super_admin|caller_role|\mrole\M') ASC,
  p.proname;

-- ============================================
-- 2. Full bodies of the admin_* functions (and admin_delete_user_data specifically) for manual
--    guard review — these are the highest-impact if unguarded. Confirm each opens with an
--    auth.uid()/role check that RAISEs for non-admins.
-- ============================================
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (p.proname LIKE 'admin\_%' ESCAPE '\' OR p.proname = 'admin_delete_user_data')
ORDER BY p.proname;

-- ============================================
-- 3. For correlation: which of the above can anon actually EXECUTE? (Confirms the advisor grant.)
--    In L5 we REVOKE EXECUTE from anon (and authenticated where not needed) on trigger functions
--    and authenticated-only/admin-only functions; intentionally-public landing reads keep it.
-- ============================================
SELECT p.proname,
       has_function_privilege('anon',          p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
ORDER BY p.proname;
