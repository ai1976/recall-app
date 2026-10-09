-- Name: [FUNCTIONS] T-002 B-06a ROLLBACK (v2) - drop the four B-06a functions
--
-- Description: PERSISTENT DDL, the undo of B-06a_FUNCTIONS_course-catalogue-and-picker-subjects_v2.sql. Run as ONE selection BEFORE B-05_ROLLBACK (undo order: B-06c, B-06b, B-06a, B-05, B-04a, B-07, B-03,
-- B-02b, B-02a, B-01) and only while nothing depends on the functions: no later reader (B-06b, B-06c) calls the core, and the F1 frontend is not serving the course picker. It proves each function is the B-06a one
-- (body hash, owner, security mode, volatility, search_path, complete EXECUTE ACL, exact execute matrix), drops them, and raises unless none of the four exact signatures remains. A dependent object makes DROP fail
-- (no CASCADE) and the whole run stops. Tables and data are not touched. Not run unless the Founder decides to undo B-06a.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $guard$
DECLARE
  v text;
  r record;
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  FOR r IN SELECT x.k, x.sig, x.exp_md5, x.exp_priv, x.exp_acl FROM (VALUES
    ('core', 'public.fn_course_options_core(text, uuid)', '2f23c1c89c0592d1133d2d048d0e3e9b', 'FFF', 'postgres:EXECUTE:false'),
    ('pub', 'public.get_course_options_public()', '57f136c64a2b4c24884566a9052f3660', 'TTF', 'anon:EXECUTE:false;authenticated:EXECUTE:false;postgres:EXECUTE:false'),
    ('auth', 'public.get_course_options(text)', '6bbd4debe463cf4a85f53b5830564af7', 'FTF', 'authenticated:EXECUTE:false;postgres:EXECUTE:false'),
    ('subj', 'public.get_picker_subjects(uuid, text)', 'ae6d158258af287d4008aaa8a1e13203', 'FTF', 'authenticated:EXECUTE:false;postgres:EXECUTE:false')
  ) AS x(k, sig, exp_md5, exp_priv, exp_acl) LOOP
    SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; volatility=' || p.provolatile::text || '; config=' || coalesce(p.proconfig::text, '-')
           || '; language=' || (SELECT l.lanname FROM pg_language l WHERE l.oid = p.prolang)
           || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
           || '; acl=' || coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type || ':' || a.is_grantable::text, ';' ORDER BY CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END COLLATE "C", a.privilege_type) FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a), '(none)')
           || '; anon_authenticated_service_role=' || CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
           || CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
           || CASE WHEN has_function_privilege('service_role', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
      INTO v FROM pg_proc p WHERE p.oid = to_regprocedure(r.sig);
    IF v IS DISTINCT FROM 'owner=postgres; secdef=true; volatility=s; config={"search_path=pg_catalog, public"}; language=plpgsql; body_md5_without_carriage_returns=' || r.exp_md5
                          || '; acl=' || r.exp_acl || '; anon_authenticated_service_role=' || r.exp_priv THEN
      RAISE EXCEPTION 'B-06a stopped: % is not as built. Live: %', r.sig, coalesce(v, '(missing)');
    END IF;
  END LOOP;
END
$guard$;

DROP FUNCTION public.get_course_options(text);
DROP FUNCTION public.get_course_options_public();
DROP FUNCTION public.get_picker_subjects(uuid, text);
DROP FUNCTION public.fn_course_options_core(text, uuid);

DO $postcheck$
BEGIN
  IF to_regprocedure('public.fn_course_options_core(text, uuid)') IS NOT NULL OR to_regprocedure('public.get_course_options_public()') IS NOT NULL
     OR to_regprocedure('public.get_course_options(text)') IS NOT NULL OR to_regprocedure('public.get_picker_subjects(uuid, text)') IS NOT NULL THEN
    RAISE EXCEPTION 'B-06a ROLLBACK stopped: a B-06a function still exists; nothing is applied';
  END IF;
END
$postcheck$;

SELECT (to_regprocedure('public.fn_course_options_core(text, uuid)') IS NULL AND to_regprocedure('public.get_course_options_public()') IS NULL
        AND to_regprocedure('public.get_course_options(text)') IS NULL AND to_regprocedure('public.get_picker_subjects(uuid, text)') IS NULL) AS b06a_functions_removed_expected_true;
