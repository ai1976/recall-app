-- ===== RUN T1: catalogue and ACL assertions =====
WITH h AS (
  SELECT p.oid, p.prosecdef, p.proconfig, p.proowner, p.proacl FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'fn_due_eligible_dates' AND p.prokind = 'f'
),
rp AS (
  SELECT p.oid, p.proname, p.prosecdef, p.proconfig, p.proowner, p.proacl FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('get_due_forecast', 'get_due_forecast_buckets') AND p.prokind = 'f'
),
roles(r) AS (
  VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator'), ('dashboard_user')
),
chk AS (
  SELECT 'helper_exists_exactly_once' AS name, (SELECT count(*) FROM h) = 1 AS pass
  UNION ALL SELECT 'helper_is_security_definer', COALESCE((SELECT bool_and(prosecdef) FROM h), false)
  UNION ALL SELECT 'helper_search_path_pinned_public_extensions',
         COALESCE((SELECT bool_and(proconfig @> ARRAY['search_path=public, extensions']) FROM h), false)
  UNION ALL SELECT 'two_public_functions_exist', (SELECT count(*) FROM rp) = 2
  UNION ALL SELECT 'public_functions_security_definer_and_pinned',
         COALESCE((SELECT bool_and(prosecdef AND proconfig @> ARRAY['search_path=public, extensions']) FROM rp), false)
  UNION ALL SELECT 'helper_owner_equals_both_public_function_owners',
         (SELECT count(DISTINCT o) FROM (SELECT proowner AS o FROM h UNION ALL SELECT proowner FROM rp) z) = 1
  UNION ALL SELECT 'helper_not_executable_by_PUBLIC',
         NOT EXISTS (SELECT 1 FROM h, aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) x
                     WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
  UNION ALL SELECT 'helper_not_executable_by_' || ro.r,
         NOT COALESCE((SELECT bool_or(has_function_privilege(ro.r, h.oid, 'EXECUTE')) FROM h), true)
         FROM roles ro WHERE EXISTS (SELECT 1 FROM pg_roles x WHERE x.rolname = ro.r)
  UNION ALL SELECT 'public_functions_not_executable_by_PUBLIC',
         NOT EXISTS (SELECT 1 FROM rp, aclexplode(COALESCE(rp.proacl, acldefault('f', rp.proowner))) x
                     WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
  UNION ALL SELECT 'public_functions_not_executable_by_anon',
         NOT COALESCE((SELECT bool_or(has_function_privilege('anon', rp.oid, 'EXECUTE')) FROM rp), true)
  UNION ALL SELECT 'public_functions_executable_by_authenticated_and_service_role',
         COALESCE((SELECT bool_and(has_function_privilege('authenticated', rp.oid, 'EXECUTE')
                                   AND has_function_privilege('service_role', rp.oid, 'EXECUTE')) FROM rp), false)
  UNION ALL SELECT 'helper_execute_set_is_exactly_the_owner',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY[pg_get_userbyid(h.proowner)::text] FROM h), false)
  UNION ALL SELECT 'public_function_execute_set_is_exactly_authenticated_postgres_service_role',
         COALESCE((SELECT bool_and((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(rp.proacl, acldefault('f', rp.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role']) FROM rp), false)
  UNION ALL SELECT 'no_duplicate_enrollment_pair',
         NOT EXISTS (SELECT 1 FROM public.my_cards_enrollment e GROUP BY e.user_id, e.flashcard_id HAVING count(*) > 1)
)
SELECT jsonb_build_object(
  'run', 'T1',
  'checks', (SELECT jsonb_agg(jsonb_build_object('check', name, 'pass', pass) ORDER BY name) FROM chk),
  'all_passed', (SELECT bool_and(pass) FROM chk),
  'public_function_execute_roles', (SELECT jsonb_agg(jsonb_build_object('function', rp.proname,
        'roles', to_jsonb((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(rp.proacl, acldefault('f', rp.proowner))) x WHERE x.privilege_type = 'EXECUTE') s))) ORDER BY rp.proname) FROM rp),
  'helper_execute_roles', (SELECT to_jsonb((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) x WHERE x.privilege_type = 'EXECUTE') s)) FROM h),
  -- informational, not a pass criterion: roles that can execute the helper only because they inherit the owner's privileges or are superusers
  'helper_effective_executors_other_than_owner', (SELECT COALESCE(jsonb_agg(r.rolname ORDER BY r.rolname), '[]'::jsonb)
        FROM pg_roles r, h WHERE r.oid <> h.proowner AND has_function_privilege(r.oid, h.oid, 'EXECUTE'))
) AS result;
