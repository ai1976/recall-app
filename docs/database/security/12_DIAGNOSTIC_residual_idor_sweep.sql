-- Name: [DIAGNOSTIC] Residual IDOR sweep — confirm no unguarded identity-taking secdef function
-- Description: The definitive "are the 116 advisor WARNs harmless?" check. Lists every
-- authenticated-executable SECURITY DEFINER function that takes an identity parameter and does NOT
-- reference auth.uid() — i.e. still trusts a caller-supplied id. After L5 + the read-IDOR pass, this
-- should return ONLY the intentional cross-user PUBLIC-data readers:
--   get_author_profile, get_author_content_summary, get_public_user_badges
-- (these return an author's PUBLIC profile / PUBLIC content summary / PUBLIC badges by design).
-- If anything ELSE appears, it's an unguarded identity-taking function that needs review. Read-only.
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  (pg_get_functiondef(p.oid) ~* '\m(insert into|update|delete)\M') AS writes
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef
  AND p.prokind = 'f'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
  AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
  AND pg_get_function_identity_arguments(p.oid) ~* '\m(p_user_id|p_author_id|p_professor_id|p_target_id|p_followee_id|p_requester_user_id|p_membership_id|p_group_id)\M'
  AND NOT (pg_get_functiondef(p.oid) ~* 'auth\.uid\(\)')
ORDER BY writes DESC, p.proname;
