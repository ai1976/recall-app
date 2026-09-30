-- [TEST] Verify the corrupt-row remediation (run AFTER 05). Read-only apart from a rollback-only role check.
-- Description: One result table.
--   R1  both rows are in the quarantine with reason stale_timer_over_max_duration and the original values intact
--   R2  neither row remains in study_sessions
--   R3  the deliberately-untouched rows are still there (6.4 h study_mode, 11.7 h practice_mode: >4h non-manual rows
--       remaining should be exactly those two)
--   R4  no study_mode / practice_mode row over 4 h remains beyond those two untouched ones, and none for the two users
--   R5  Avantika's 29/09/2026 total is now her genuine manual sessions only (2,984 s expected)
--   R6  a signed-in student cannot read the quarantine table (server-side only)

BEGIN;

DO $t$
DECLARE
  v_res text[] := '{}';
  n int; a int; b int; c int; sec bigint; err text;
  avantika constant uuid := '1de7a5d4-c780-4a5b-be53-47b95bb9e308';
  other    constant uuid := '075ad481-13e8-45e4-9deb-3c38907eb3e6';
  tester   constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';
BEGIN
  SELECT count(*), count(*) FILTER (WHERE duration_seconds IN (2553404, 14749689))
    INTO n, a FROM public.study_sessions_quarantine WHERE quarantine_reason = 'stale_timer_over_max_duration';
  v_res := v_res || ('R1 quarantine holds both rows, values intact|2 / 2|' || n || ' / ' || a || '|' ||
           CASE WHEN n = 2 AND a = 2 THEN 'PASS' ELSE 'FAIL' END)::text;

  SELECT count(*) INTO n FROM public.study_sessions s
   WHERE s.id = '687abe30-93f8-4c88-b114-bb07a065d886' OR (s.user_id = other AND s.duration_seconds = 14749689);
  v_res := v_res || ('R2 neither corrupt row remains in study_sessions|0|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;

  SELECT count(*) INTO n FROM public.study_sessions WHERE source <> 'manual' AND duration_seconds > 14400;
  SELECT count(*) INTO a FROM public.study_sessions WHERE source = 'study_mode' AND duration_seconds BETWEEN 22000 AND 24000;
  SELECT count(*) INTO b FROM public.study_sessions WHERE source = 'practice_mode' AND duration_seconds BETWEEN 41000 AND 43000;
  v_res := v_res || ('R3 the 6.4h study_mode and 11.7h practice_mode rows are untouched|1 / 1|' || a || ' / ' || b || '|' ||
           CASE WHEN a = 1 AND b = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  v_res := v_res || ('R4 only those two non-manual >4h rows remain|2|' || n || '|' || CASE WHEN n = 2 THEN 'PASS' ELSE 'FAIL' END)::text;

  SELECT COALESCE(sum(duration_seconds), 0) INTO sec FROM public.study_sessions WHERE user_id = avantika AND session_date = DATE '2026-09-29';
  v_res := v_res || ('R5 Avantika 29/09/2026 total is genuine manual time only|2984 s|' || sec || ' s|' ||
           CASE WHEN sec = 2984 THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM 1 FROM public.study_sessions_quarantine LIMIT 1;
    RESET ROLE;
    v_res := v_res || 'R6 a student cannot read the quarantine [CRITICAL]|permission denied|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R6 a student cannot read the quarantine [CRITICAL]|permission denied|' || left(err, 40) || '|' ||
             CASE WHEN err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || err END)::text; END;

  PERFORM set_config('app.t06_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t06_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
