-- [TEST] study_sessions privilege hardening (run AFTER 07). Rollback-only, safe on production.
-- Description: Runs as TestOutlook with the client role (SET LOCAL ROLE authenticated / anon) so it proves what the
--   real app can and cannot do.
--     P1  catalog: authenticated keeps exactly SELECT + INSERT; anon has nothing
--     P2  authenticated can still INSERT its own session (the tracker's write)
--     P3  authenticated can still SELECT its own rows
--     P4  authenticated UPDATE is now refused with permission denied (not merely 0 rows)
--     P5  authenticated DELETE is now refused with permission denied
--     P6  anon SELECT is refused
--     P7  the SECURITY DEFINER stats function still works for the student (get_study_time_stats)
--   Results via a transaction-local setting; strings cast ::text.

BEGIN;

DO $t$
DECLARE
  uid constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';  -- TestOutlook
  v_res text[] := '{}';
  v_err text; n int; a text; b text; sid uuid := gen_random_uuid();
BEGIN
  SELECT string_agg(privilege_type, ',' ORDER BY privilege_type) INTO a
    FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'study_sessions' AND grantee = 'authenticated';
  SELECT COALESCE(string_agg(privilege_type, ',' ORDER BY privilege_type), 'none') INTO b
    FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'study_sessions' AND grantee = 'anon';
  v_res := v_res || ('P1 authenticated = SELECT,INSERT; anon = none|INSERT,SELECT / none|' || COALESCE(a, 'none') || ' / ' || b || '|' ||
           CASE WHEN a = 'INSERT,SELECT' AND b = 'none' THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '5 minutes', now(), 300, current_date, 'study_mode', sid);
    v_res := v_res || 'P2 authenticated can still insert its own session|accepted|accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P2 authenticated can still insert its own session|accepted|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;

  BEGIN
    SELECT count(*) INTO n FROM public.study_sessions WHERE session_id = sid;
    v_res := v_res || ('P3 authenticated can still read its own rows|1|' || n || '|' || CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P3 authenticated can still read its own rows|1|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;

  BEGIN
    UPDATE public.study_sessions SET duration_seconds = 1 WHERE session_id = sid;
    v_res := v_res || 'P4 authenticated UPDATE refused|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P4 authenticated UPDATE refused|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  BEGIN
    DELETE FROM public.study_sessions WHERE session_id = sid;
    v_res := v_res || 'P5 authenticated DELETE refused|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P5 authenticated DELETE refused|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  BEGIN
    PERFORM count(*) FROM public.get_study_time_stats(uid, current_date);
    v_res := v_res || 'P7 get_study_time_stats still works for the student|runs|runs|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P7 get_study_time_stats still works for the student|runs|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  RESET ROLE;

  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM 1 FROM public.study_sessions LIMIT 1;
    v_res := v_res || 'P6 anon SELECT refused|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P6 anon SELECT refused|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  PERFORM set_config('app.t08_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t08_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
