-- [TEST] admin_audit_log immutability trigger (run AFTER 10, and after 08). Rollback-only, safe on production.
-- Description: Runs as the table owner / SQL editor role - the strongest possible caller - because the trigger is meant to
--   hold even then. Everything is rolled back at the end.
--     T1  UPDATE of action is refused          T2  UPDATE of details is refused
--     T3  DELETE is refused                    T4  TRUNCATE is refused
--     T5  re-pointing target_user_id to a DIFFERENT user is refused
--     T6  setting target_user_id to NULL is allowed (what the foreign key does when a user is deleted)
--     T7  REAL PATH: a super admin deletes a student's data with admin_delete_user_data -> its audit entry is written,
--         the profile is gone, and the entry survives with target_user_id NULL and admin_id intact (the trigger lets the
--         foreign key's SET NULL through) - so user deletion still works
--   Results via a transaction-local setting.

BEGIN;

DO $t$
DECLARE
  anand  constant uuid := '82bc189a-d072-4952-a47f-73b045c8a3c4';
  tester constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';
  v_res text[] := '{}';
  v_err text; v_row uuid; v_target uuid; n int; t2 uuid; adm uuid; tgt uuid;
BEGIN
  SELECT id, target_user_id INTO v_row, v_target
    FROM public.admin_audit_log WHERE target_user_id IS NOT NULL ORDER BY created_at LIMIT 1;
  IF v_row IS NULL THEN
    v_res := v_res || 'T1-T6 need at least one audit row with a target|rows|none found|SKIP'::text;
  ELSE
    BEGIN
      UPDATE public.admin_audit_log SET action = 'tampered' WHERE id = v_row;
      v_res := v_res || 'T1 UPDATE of action refused [CRITICAL]|refused|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('T1 UPDATE of action refused [CRITICAL]|refused|' || left(v_err, 40) || '|' || CASE WHEN v_err ILIKE '%append-only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

    BEGIN
      UPDATE public.admin_audit_log SET details = '{"x":1}'::jsonb WHERE id = v_row;
      v_res := v_res || 'T2 UPDATE of details refused [CRITICAL]|refused|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('T2 UPDATE of details refused [CRITICAL]|refused|' || left(v_err, 40) || '|' || CASE WHEN v_err ILIKE '%append-only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

    BEGIN
      DELETE FROM public.admin_audit_log WHERE id = v_row;
      v_res := v_res || 'T3 DELETE refused [CRITICAL]|refused|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('T3 DELETE refused [CRITICAL]|refused|' || left(v_err, 40) || '|' || CASE WHEN v_err ILIKE '%append-only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

    BEGIN
      TRUNCATE public.admin_audit_log;
      v_res := v_res || 'T4 TRUNCATE refused [CRITICAL]|refused|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('T4 TRUNCATE refused [CRITICAL]|refused|' || left(v_err, 40) || '|' || CASE WHEN v_err ILIKE '%append-only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

    SELECT p.id INTO t2 FROM public.profiles p WHERE p.id <> v_target LIMIT 1;
    BEGIN
      UPDATE public.admin_audit_log SET target_user_id = t2 WHERE id = v_row;
      v_res := v_res || 'T5 re-pointing the target to another user refused [CRITICAL]|refused|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('T5 re-pointing the target to another user refused [CRITICAL]|refused|' || left(v_err, 40) || '|' || CASE WHEN v_err ILIKE '%append-only%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

    BEGIN
      UPDATE public.admin_audit_log SET target_user_id = NULL WHERE id = v_row;
      v_res := v_res || 'T6 target_user_id -> NULL allowed (foreign-key path)|allowed|allowed|PASS'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('T6 target_user_id -> NULL allowed (foreign-key path)|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- T7: the real foreign-key path, through the real function
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.admin_delete_user_data(tester);
    RESET ROLE;
    SELECT count(*) INTO n FROM public.profiles WHERE id = tester;
    SELECT l.admin_id, l.target_user_id INTO adm, tgt
      FROM public.admin_audit_log l
     WHERE l.action = 'delete_user' AND l.details->>'deleted_user_email' IS NOT NULL AND l.admin_id = anand
     ORDER BY l.created_at DESC LIMIT 1;
    v_res := v_res || ('T7 user deletion still works: entry survives, target NULL, admin kept|0 profiles, admin = caller, target NULL|' || n || ' left, admin ' || CASE WHEN adm = anand THEN 'kept' ELSE 'LOST' END || ', target ' || CASE WHEN tgt IS NULL THEN 'NULL' ELSE 'set' END || '|' ||
             CASE WHEN n = 0 AND adm = anand AND tgt IS NULL THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('T7 user deletion still works|0 profiles, entry survives|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;

  PERFORM set_config('app.t11b4_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t11b4_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
