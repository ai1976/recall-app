-- [TEST] get_my_enrollment_count (run AFTER 01). Rollback-only, read-only, safe on production.
-- Description: Impersonates real students with the client role (SET LOCAL ROLE authenticated / anon).
--     E1  a student with cards added (Niranjan Jog, 751aa7d4-...) gets a count >= 2
--     E2  a student with none (Aarya Bapat, bf13ff54-...) gets 0
--     E3  reading ANOTHER student's count is refused (Access denied)  [CRITICAL]
--     E4  anon cannot execute the function
--     E5  the function is SECURITY DEFINER with an unquoted-style search_path (public, extensions)
--   Results via a transaction-local setting; strings cast ::text.

BEGIN;

DO $t$
DECLARE
  niranjan constant uuid := '751aa7d4-5375-4413-9a92-5c2f095ec0ac';
  aarya    constant uuid := 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6';
  v_res text[] := '{}';
  v_err text; n integer; cfg text; secdef boolean;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', niranjan, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    n := public.get_my_enrollment_count(niranjan);
    v_res := v_res || ('E1 student with added cards gets a count|>= 2|' || n || '|' || CASE WHEN n >= 2 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E1 student with added cards gets a count|>= 2|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;

  BEGIN
    PERFORM public.get_my_enrollment_count(aarya);
    v_res := v_res || 'E3 reading another student is refused [CRITICAL]|Access denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E3 reading another student is refused [CRITICAL]|Access denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', aarya, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    n := public.get_my_enrollment_count(aarya);
    v_res := v_res || ('E2 student with no added cards gets 0|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E2 student with no added cards gets 0|0|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  RESET ROLE;

  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.get_my_enrollment_count(aarya);
    v_res := v_res || 'E4 anon cannot execute|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E4 anon cannot execute|permission denied|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  SELECT p.prosecdef, array_to_string(p.proconfig, ',') INTO secdef, cfg
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'get_my_enrollment_count';
  v_res := v_res || ('E5 SECURITY DEFINER + search_path public, extensions|true / search_path=public, extensions|' || COALESCE(secdef::text, 'missing') || ' / ' || COALESCE(cfg, 'none') || '|' ||
           CASE WHEN secdef AND cfg = 'search_path=public, extensions' THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t02b3_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t02b3_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
