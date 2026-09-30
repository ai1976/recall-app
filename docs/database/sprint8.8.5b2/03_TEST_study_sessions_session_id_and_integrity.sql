-- [TEST] study_sessions session_id + integrity constraints (run AFTER 02)
-- Description: Rollback-only (BEGIN ... ROLLBACK), safe on production. Uses TestOutlook as the client-role
--   caller (SET LOCAL ROLE authenticated + JWT sub) so RLS is exercised for real, exactly like the app.
--     S1  column, unique index and both constraints exist; integrity is VALID, max-duration is NOT VALID
--     S2  valid study_mode row with a session_id is accepted
--     S3  same (user, session_id) again -> 23505 on study_sessions_user_session_uidx (explicit duplicate handling)
--     S4  the SAME session_id for a DIFFERENT user is accepted (unique per user, no cross-user blocking)
--     S5  study_mode duration 14401 -> rejected by study_sessions_machine_duration_max
--     S6  practice_mode duration 14401 -> rejected (same rule, both machine sources)
--     S7  duration exactly 14400 (span >= 4h) -> accepted (boundary)
--     S8  ended_at before started_at -> rejected by study_sessions_machine_time_integrity
--     S9  duration far larger than the wall-clock span -> rejected by study_sessions_machine_time_integrity
--     S10 wall-clock span 6h but active duration 90 min (pause/resume) -> accepted
--     S11 two rows with NULL session_id (legacy / old client) -> both accepted
--     S12 manual row of 5.5h is untouched by the new checks (its own floor/category rules still apply)
--     S13 inserting a row for another user is still refused by RLS
--   Results via a transaction-local setting; strings cast ::text.

BEGIN;

DO $t$
DECLARE
  uid   uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';  -- TestOutlook
  other uuid;
  sid   uuid;
  v_res text[] := '{}';
  v_err text;
  v_n   int;
  v_a   text;
  v_b   text;
BEGIN
  SELECT p.id INTO other FROM public.profiles p WHERE p.id <> uid ORDER BY p.created_at LIMIT 1;

  -- S1 catalog
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'study_sessions' AND column_name = 'session_id';
  SELECT count(*) INTO v_n FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'study_sessions_user_session_uidx'
   HAVING count(*) = 1 AND v_n = 1;
  SELECT (SELECT convalidated::text FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_machine_time_integrity'),
         (SELECT convalidated::text FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_machine_duration_max')
    INTO v_a, v_b;
  v_res := v_res || ('S1 column + unique index + constraints exist; integrity VALID, max-duration NOT VALID|true / false|' || COALESCE(v_a, 'missing') || ' / ' || COALESCE(v_b, 'missing') || '|' ||
           CASE WHEN v_n = 1 AND v_a = 'true' AND v_b = 'false' THEN 'PASS' ELSE 'FAIL' END)::text;

  -- S2 valid insert
  sid := gen_random_uuid();
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '30 minutes', now(), 1500, current_date, 'study_mode', sid);
    RESET ROLE;
    v_res := v_res || 'S2 valid study_mode row with session_id|accepted|accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S2 valid study_mode row with session_id|accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- S3 duplicate (user, session_id)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '30 minutes', now(), 1500, current_date, 'study_mode', sid);
    RESET ROLE;
    v_res := v_res || 'S3 duplicate (user, session_id)|23505|no error|FAIL'::text;
  EXCEPTION WHEN unique_violation THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S3 duplicate (user, session_id)|23505 on study_sessions_user_session_uidx|' || left(v_err, 60) || '|' ||
             CASE WHEN v_err ILIKE '%study_sessions_user_session_uidx%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text;
  WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S3 duplicate (user, session_id)|23505|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- S4 same session_id, different user
  IF other IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', other, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
      VALUES (other, now() - interval '30 minutes', now(), 1500, current_date, 'study_mode', sid);
      RESET ROLE;
      v_res := v_res || 'S4 same session_id for a different user|accepted|accepted|PASS'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('S4 same session_id for a different user|accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- S5 study_mode 14401
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '5 hours', now(), 14401, current_date, 'study_mode', gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'S5 study_mode duration 14401|rejected|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S5 study_mode duration 14401|rejected by machine_duration_max|' || left(v_err, 60) || '|' ||
             CASE WHEN v_err ILIKE '%study_sessions_machine_duration_max%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- S6 practice_mode 14401
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '5 hours', now(), 14401, current_date, 'practice_mode', gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'S6 practice_mode duration 14401|rejected|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S6 practice_mode duration 14401|rejected by machine_duration_max|' || left(v_err, 60) || '|' ||
             CASE WHEN v_err ILIKE '%study_sessions_machine_duration_max%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- S7 boundary 14400
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '4 hours', now(), 14400, current_date, 'study_mode', gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'S7 duration exactly 14400|accepted|accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S7 duration exactly 14400|accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- S8 ended before started
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now(), now() - interval '10 minutes', 60, current_date, 'study_mode', gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'S8 ended_at before started_at|rejected|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S8 ended_at before started_at|rejected by machine_time_integrity|' || left(v_err, 60) || '|' ||
             CASE WHEN v_err ILIKE '%study_sessions_machine_time_integrity%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- S9 duration >> span
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '1 minute', now(), 3600, current_date, 'study_mode', gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'S9 duration far larger than wall-clock span|rejected|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S9 duration far larger than wall-clock span|rejected by machine_time_integrity|' || left(v_err, 60) || '|' ||
             CASE WHEN v_err ILIKE '%study_sessions_machine_time_integrity%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- S10 span 6h, active 90 min
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
    VALUES (uid, now() - interval '6 hours', now(), 5400, current_date, 'study_mode', gen_random_uuid());
    RESET ROLE;
    v_res := v_res || 'S10 span 6h but active 90 min (pause/resume)|accepted|accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S10 span 6h but active 90 min (pause/resume)|accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- S11 two NULL session_id rows
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source)
    VALUES (uid, now() - interval '20 minutes', now(), 1200, current_date, 'study_mode');
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source)
    VALUES (uid, now() - interval '20 minutes', now(), 1200, current_date, 'study_mode');
    RESET ROLE;
    v_res := v_res || 'S11 two rows with NULL session_id (legacy/old client)|both accepted|both accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S11 two rows with NULL session_id (legacy/old client)|both accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- S12 manual 5.5h untouched
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
    VALUES (uid, now() - interval '330 minutes', now(), 19800, current_date, 'manual', 'reading');
    RESET ROLE;
    v_res := v_res || 'S12 manual 5.5h row not affected by new checks|accepted|accepted|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('S12 manual 5.5h row not affected by new checks|accepted|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  -- S13 RLS: insert for another user
  IF other IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, session_id)
      VALUES (other, now() - interval '10 minutes', now(), 600, current_date, 'study_mode', gen_random_uuid());
      RESET ROLE;
      v_res := v_res || 'S13 insert for another user [CRITICAL]|refused by RLS|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
      v_res := v_res || ('S13 insert for another user [CRITICAL]|refused by RLS|' || left(v_err, 60) || '|' ||
               CASE WHEN v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  END IF;

  RESET ROLE;
  PERFORM set_config('app.t02_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t02_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
