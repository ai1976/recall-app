-- Name: [DIAGNOSTIC] Read-side IDOR audit — SECURITY DEFINER reads that take a user_id param
-- Description: L5 fixed the WRITE IDOR on card-scheduling RPCs. This checks the READ side: SECURITY
-- DEFINER functions that accept a user-identity parameter and return data. If such a function does
-- NOT constrain that parameter to auth.uid() (and isn't an admin/cross-user-by-design read), an
-- authenticated user can pass ANOTHER user's UUID and read their private data (study stats,
-- notifications, streaks, etc.) — SECURITY DEFINER bypasses RLS, so the param is fully trusted.
-- Read-only. Paste both blocks; I'll classify each as needs-guard / self-checked / intentional-cross-user.

-- ============================================
-- 1. Every SECURITY DEFINER function with a user-id-like argument that does NOT write. Flags whether
--    the body references auth.uid() at all. `references_auth_uid = false` is a strong IDOR signal
--    (the function trusts the caller-supplied id blindly). `true` still needs body review (it may
--    use auth.uid() elsewhere without constraining the param).
-- ============================================
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid)                      AS args,
  (pg_get_functiondef(p.oid) ~* 'auth\.uid\(\)')                 AS references_auth_uid,
  (pg_get_functiondef(p.oid) ~* '\mis_admin\M|\mis_super_admin\M') AS references_admin
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef
  AND p.prokind = 'f'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
  -- takes a user-identity-style parameter
  AND pg_get_function_identity_arguments(p.oid) ~* '\m(p_user_id|p_author_id|p_target_id|p_followee_id|p_professor_id|p_requester_user_id)\M'
  -- read-only (exclude writers)
  AND NOT (pg_get_functiondef(p.oid) ~* '\m(insert into|update |delete from)\M')
ORDER BY references_auth_uid, p.proname;

-- ============================================
-- 2. Full bodies of the read functions that take p_user_id specifically and do NOT reference
--    auth.uid() — the clearest IDOR candidates. Confirm per function whether the returned data is
--    self-scoped-sensitive (needs a p_user_id = auth.uid() guard) or intentionally cross-user
--    (e.g. viewing someone's PUBLIC badges/profile — leave as-is).
-- ============================================
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef
  AND p.prokind = 'f'
  AND pg_get_function_identity_arguments(p.oid) ~* '\mp_user_id\M'
  AND NOT (pg_get_functiondef(p.oid) ~* '\m(insert into|update |delete from)\M')
  AND NOT (pg_get_functiondef(p.oid) ~* 'auth\.uid\(\)')
ORDER BY p.proname;
