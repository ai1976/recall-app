-- [TEST] Email sync + normalisation (run AFTER 02). Rollback-only, safe on production.
-- (E1-E3 look up their OWN audit row by the exact new address they set: all rows written in one transaction share a created_at.)
-- Description: Runs as the table owner (the SQL editor role) and simulates the three real ways an Auth email changes by setting
--   the request's JWT claims. Everything - the changed Auth email, the profile copy, the audit rows - is rolled back at the end.
--     N1  no profile email has uppercase or surrounding spaces any more
--     N2  the CHECK constraint exists and is VALIDATED; the unique index on lower(email) exists
--     N3  a mixed-case write to profiles.email is refused by the CHECK  [CRITICAL]
--     N4  the signup function stores trim+lower (definition check)
--     E1  SELF-SERVICE: the user changes their own Auth email (JWT sub = the user) to a MiXed-case address ->
--         profiles.email = lowercase, audit 'email_changed' with mechanism self_service and admin_id NULL
--     E2  DASHBOARD / service role (no JWT user) -> mechanism dashboard_or_admin, admin_id NULL
--     E3  an admin signed in and changing another user's email -> mechanism dashboard_or_admin, admin_id = that admin
--     E4  setting the email to the same value writes NO audit row and changes nothing
--     E5  changing to an address another profile already holds is refused (no half-synchronised state)  [CRITICAL]
--     E6  the trigger function is not executable by any client role
--   Not testable here (would need creating an Auth account): the "profile row missing" branch and a live signup. Results via a
--   transaction-local setting.

BEGIN;

DO $t$
DECLARE
  tester constant uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';   -- TestOutlook
  anand  constant uuid := '82bc189a-d072-4952-a47f-73b045c8a3c4';
  v_res text[] := '{}';
  v_err text; n int; a0 int; a1 int; v_orig text; v_other text; s text; t text;
  rec record;
BEGIN
  -- N1
  SELECT count(*) INTO n FROM public.profiles WHERE email IS NOT NULL AND email <> lower(btrim(email));
  v_res := v_res || ('N1 every profile email is trimmed + lowercase|0 not normalised|' || n || '|' || CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END)::text;

  -- N2
  SELECT convalidated::text INTO s FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_email_normalized';
  SELECT count(*) INTO n FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'profiles_email_lower_key';
  v_res := v_res || ('N2 CHECK validated + unique index on lower(email)|true / 1|' || COALESCE(s, 'missing') || ' / ' || n || '|' || CASE WHEN s = 'true' AND n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;

  -- N3
  BEGIN
    UPDATE public.profiles SET email = 'MiXed@Example.com' WHERE id = tester;
    v_res := v_res || 'N3 a mixed-case write is refused [CRITICAL]|check violation|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('N3 a mixed-case write is refused [CRITICAL]|profiles_email_normalized|' || left(v_err, 60) || '|' ||
             CASE WHEN v_err ILIKE '%profiles_email_normalized%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- N4
  SELECT pg_get_functiondef(p.oid) ILIKE '%lower(btrim(NEW.email))%' INTO s
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace WHERE ns.nspname = 'public' AND p.proname = 'fn_create_profile_on_signup';
  v_res := v_res || ('N4 the signup function stores trim+lower|true|' || COALESCE(s, 'missing') || '|' || CASE WHEN s = 'true' THEN 'PASS' ELSE 'FAIL' END)::text;

  SELECT email INTO v_orig FROM auth.users WHERE id = tester;
  SELECT email INTO v_other FROM auth.users WHERE id <> tester AND email IS NOT NULL ORDER BY id LIMIT 1;

  -- E1 self-service
  PERFORM set_config('request.jwt.claims', json_build_object('sub', tester, 'role', 'authenticated')::text, true);
  BEGIN
    UPDATE auth.users SET email = 'MiXed-Sync-Test@Example.com' WHERE id = tester;
    SELECT p.email INTO s FROM public.profiles p WHERE p.id = tester;
    SELECT l.admin_id, l.details INTO rec FROM public.admin_audit_log l
      WHERE l.action = 'email_changed' AND l.target_user_id = tester AND l.details->>'new_email' = 'MiXed-Sync-Test@Example.com' LIMIT 1;
    v_res := v_res || ('E1 self-service change: profile lowercased, audit self_service, no admin actor|mixed-sync-test@example.com / self_service / NULL|' || COALESCE(s, 'NULL') || ' / ' || COALESCE(rec.details->>'mechanism', 'no entry') || ' / ' || COALESCE(rec.admin_id::text, 'NULL') || '|' ||
             CASE WHEN s = 'mixed-sync-test@example.com' AND rec.details->>'mechanism' = 'self_service' AND rec.admin_id IS NULL THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E1 self-service change|synced|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- E2 dashboard / service role: no JWT user
  PERFORM set_config('request.jwt.claims', '', true);
  BEGIN
    UPDATE auth.users SET email = 'dashboard-sync-test@example.com' WHERE id = tester;
    SELECT p.email INTO s FROM public.profiles p WHERE p.id = tester;
    SELECT l.admin_id, l.details INTO rec FROM public.admin_audit_log l
      WHERE l.action = 'email_changed' AND l.target_user_id = tester AND l.details->>'new_email' = 'dashboard-sync-test@example.com' LIMIT 1;
    v_res := v_res || ('E2 dashboard change: profile synced, mechanism dashboard_or_admin, admin NULL|dashboard-sync-test@example.com / dashboard_or_admin / NULL|' || COALESCE(s, 'NULL') || ' / ' || COALESCE(rec.details->>'mechanism', 'no entry') || ' / ' || COALESCE(rec.admin_id::text, 'NULL') || '|' ||
             CASE WHEN s = 'dashboard-sync-test@example.com' AND rec.details->>'mechanism' = 'dashboard_or_admin' AND rec.admin_id IS NULL THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E2 dashboard change|synced|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- E3 an admin signed in, changing someone else's email
  PERFORM set_config('request.jwt.claims', json_build_object('sub', anand, 'role', 'authenticated')::text, true);
  BEGIN
    UPDATE auth.users SET email = 'admin-sync-test@example.com' WHERE id = tester;
    SELECT l.admin_id, l.details INTO rec FROM public.admin_audit_log l
      WHERE l.action = 'email_changed' AND l.target_user_id = tester AND l.details->>'new_email' = 'admin-sync-test@example.com' LIMIT 1;
    v_res := v_res || ('E3 an admin changing another user: admin recorded as actor|dashboard_or_admin / admin = caller|' || COALESCE(rec.details->>'mechanism', 'no entry') || ' / ' || CASE WHEN rec.admin_id = anand THEN 'admin = caller' ELSE COALESCE(rec.admin_id::text, 'NULL') END || '|' ||
             CASE WHEN rec.details->>'mechanism' = 'dashboard_or_admin' AND rec.admin_id = anand THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E3 an admin changing another user|actor recorded|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- E4 same value: nothing happens
  SELECT count(*) INTO a0 FROM public.admin_audit_log WHERE action = 'email_changed' AND target_user_id = tester;
  PERFORM set_config('request.jwt.claims', '', true);
  BEGIN
    UPDATE auth.users SET email = email WHERE id = tester;
    SELECT count(*) INTO a1 FROM public.admin_audit_log WHERE action = 'email_changed' AND target_user_id = tester;
    v_res := v_res || ('E4 setting the same email writes nothing|no new audit row|+' || (a1 - a0) || '|' || CASE WHEN a1 = a0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E4 setting the same email writes nothing|no new audit row|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- E5 collision with another profile's address
  IF v_other IS NULL THEN
    v_res := v_res || 'E5 a duplicate address is refused|refused|no other user to collide with|SKIP'::text;
  ELSE
    BEGIN
      UPDATE auth.users SET email = v_other WHERE id = tester;
      v_res := v_res || 'E5 a duplicate address is refused [CRITICAL]|refused, nothing half-synced|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      SELECT p.email INTO s FROM public.profiles p WHERE p.id = tester;
      v_res := v_res || ('E5 a duplicate address is refused [CRITICAL]|unique violation; profile still admin-sync-test@example.com|' || left(v_err, 40) || ' / profile ' || COALESCE(s, 'NULL') || '|' ||
               CASE WHEN v_err ILIKE '%unique%' OR v_err ILIKE '%duplicate%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  END IF;

  -- E6 trigger function not executable by clients
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.fn_sync_profile_email_from_auth();
    RESET ROLE; s := 'no error';
  EXCEPTION WHEN OTHERS THEN s := SQLERRM; RESET ROLE; END;
  v_res := v_res || ('E6 the sync function is not executable by clients|permission denied|' || left(s, 40) || '|' ||
           CASE WHEN s ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t03b6_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $t$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t03b6_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
