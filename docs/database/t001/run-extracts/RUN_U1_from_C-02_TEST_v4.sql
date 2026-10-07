-- ===== RUN U1: catalogue and ACL assertions =====
WITH n AS (
  SELECT p.oid, p.prosecdef, p.proconfig, p.proowner, p.proacl, pg_get_function_result(p.oid) AS result_type
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'get_study_heatmap_split' AND p.prokind = 'f'
),
o AS (
  SELECT p.oid, p.proowner, p.proacl FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'get_study_heatmap' AND p.prokind = 'f'
),
chk AS (
  SELECT 'new_function_exists_exactly_once' AS name, (SELECT count(*) FROM n) = 1 AS pass
  UNION ALL SELECT 'new_function_security_definer', COALESCE((SELECT bool_and(prosecdef) FROM n), false)
  UNION ALL SELECT 'new_function_search_path_pinned_public_extensions',
         COALESCE((SELECT bool_and(proconfig @> ARRAY['search_path=public, extensions']) FROM n), false)
  UNION ALL SELECT 'new_function_return_columns_exact',
         COALESCE((SELECT bool_and(result_type = 'TABLE(review_date date, review_count integer, in_app_seconds integer, offline_seconds integer, study_seconds integer, other_seconds integer)') FROM n), false)
  UNION ALL SELECT 'new_function_not_executable_by_PUBLIC',
         NOT EXISTS (SELECT 1 FROM n, aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')
  UNION ALL SELECT 'new_function_not_executable_by_anon',
         NOT COALESCE((SELECT bool_or(has_function_privilege('anon', n.oid, 'EXECUTE')) FROM n), true)
  UNION ALL SELECT 'new_function_executable_by_authenticated_and_service_role',
         COALESCE((SELECT bool_and(has_function_privilege('authenticated', n.oid, 'EXECUTE') AND has_function_privilege('service_role', n.oid, 'EXECUTE')) FROM n), false)
  UNION ALL SELECT 'new_function_execute_set_is_exactly_authenticated_postgres_service_role',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role'] FROM n), false)
  UNION ALL SELECT 'live_function_execute_set_is_exactly_authenticated_postgres_service_role',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(o.proacl, acldefault('f', o.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role'] FROM o), false)
  UNION ALL SELECT 'new_function_execute_set_equals_live_function_execute_set',
         COALESCE((SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) FROM n) = (SELECT (SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(o.proacl, acldefault('f', o.proowner))) x WHERE x.privilege_type = 'EXECUTE') s) FROM o), false)
  UNION ALL SELECT 'live_function_still_exists_once', (SELECT count(*) FROM o) = 1
  UNION ALL SELECT 'new_function_owner_equals_live_function_owner', (SELECT n.proowner FROM n) = (SELECT o.proowner FROM o)
)
SELECT jsonb_build_object(
  'run', 'U1',
  'checks', (SELECT jsonb_agg(jsonb_build_object('check', name, 'pass', pass) ORDER BY name) FROM chk),
  'all_passed', (SELECT bool_and(pass) FROM chk),
  'live_get_study_heatmap_definition_md5', (SELECT md5(pg_get_functiondef(o.oid)) FROM o),
  'new_function_execute_roles', (SELECT to_jsonb((SELECT array_agg(DISTINCT s.g ORDER BY s.g) FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g FROM aclexplode(COALESCE(n.proacl, acldefault('f', n.proowner))) x WHERE x.privilege_type = 'EXECUTE') s)) FROM n)
) AS result;
