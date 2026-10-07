-- ===== RUN U2: real roles =====
CREATE OR REPLACE FUNCTION pg_temp.c02_u2() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_user uuid; v_other uuid; v_admin uuid;
  v_res jsonb := '[]'::jsonb;
  v_case record;
  v_out text;
BEGIN
  SELECT s.user_id INTO v_user FROM public.study_sessions s ORDER BY s.user_id LIMIT 1;
  SELECT p.id INTO v_other FROM public.profiles p WHERE p.id <> v_user ORDER BY p.id LIMIT 1;
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_user IS NULL OR v_other IS NULL OR v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'U2', 'error', 'a fixture profile (a user with a study session, another user, an administrator) is missing; the test cannot run');
  END IF;
  FOR v_case IN
    SELECT * FROM (VALUES
      ('anon',          NULL::uuid, v_user,  'denied_42501', 'anon'),
      ('authenticated', v_user,     v_user,  'executed',     'own'),
      ('authenticated', v_user,     v_other, 'guard_denied', 'other_user'),
      ('authenticated', v_admin,    v_user,  'executed',     'admin'),
      ('service_role',  NULL::uuid, v_user,  'guard_denied', 'service_role_without_token')
    ) AS t(rl, sub, target, expected, label)
  LOOP
    v_out := 'executed';
    BEGIN
      EXECUTE format('SET LOCAL ROLE %I', v_case.rl);
      PERFORM set_config('request.jwt.claims',
                         CASE WHEN v_case.sub IS NULL THEN ''
                              ELSE jsonb_build_object('sub', v_case.sub::text, 'role', v_case.rl)::text END, true);
      PERFORM count(*) FROM public.get_study_heatmap_split(v_case.target, 90);
    EXCEPTION
      WHEN insufficient_privilege THEN v_out := 'denied_42501';
      WHEN raise_exception THEN
        v_out := CASE WHEN SQLERRM LIKE 'Access denied%' THEN 'guard_denied' ELSE 'raise_other' END;
      WHEN OTHERS THEN v_out := 'error_' || SQLSTATE;
    END;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);
    v_res := v_res || jsonb_build_object('case', v_case.label, 'role', v_case.rl, 'expected', v_case.expected, 'got', v_out, 'pass', v_out = v_case.expected);
  END LOOP;
  RETURN jsonb_build_object('run', 'U2', 'cases', v_res,
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c02_u2() AS result;
