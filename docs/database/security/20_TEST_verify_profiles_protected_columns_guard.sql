-- Name: [TEST] Verify profiles protected-columns guard (19) - attacks blocked AND real workflows proven
-- Description: Post-deploy verification. Everything runs inside BEGIN...ROLLBACK, so no data survives.
--   Impersonates real users with SET LOCAL ROLE authenticated + a JWT sub (current_user must be
--   'authenticated' for the guard to apply - a plain SQL-editor session bypasses it, which is exactly why
--   the older phase5/21_TEST, run as postgres, never exercised the guard path).
--
--   PART A - attacks that MUST be blocked (student -> own role / account_type / status / email; admin ->
--            own role to super_admin).
--   PART B - legitimate client edits that MUST still work (student full_name / course_level / institution /
--            timezone / goals / onboarding flags in one statement, like ProfileSettings + Dashboard do).
--   PART C - legitimate admin operations that MUST still work (admin own account_type; super admin changing
--            another user's role and status via the "Super admins can update any profile" path).
--   PART D - the REAL SECURITY DEFINER workflows that touch protected columns, called by a client-role
--            session exactly as the app calls them (18b found three profiles writers):
--              approve_educator_application (linked applicant -> role = professor)
--              link_access_request           (approved anonymous application -> role = professor on first login;
--                                             also tags access_request_ref)
--              update_daily_goal             (unprotected columns; must be unaffected)
--            plus the signup path is INSERT-only (trg_create_profile_on_signup) and is not covered by the
--            guard by construction (BEFORE UPDATE only).
--   PART E - non-client paths (postgres) unconstrained.
--   INFO   - an admin (non-super) updating ANOTHER user's account_type: reported, not judged. RLS has no
--            UPDATE policy for plain admins on other users' rows, so this is expected to affect 0 rows with
--            or without the guard (AdminDashboard.jsx:395/467 rely on it; it works today only for super admin).
--   Results are collected in a variable and inserted after RESET ROLE (the temp table is not accessible while
--   the role is switched). Run as its own script; the last SELECT is the result.

BEGIN;
CREATE TEMP TABLE _r(seq int, check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_res text[] := '{}';
  v_student uuid; v_student2 uuid; v_student3 uuid; v_admin uuid; v_super uuid;
  v_err text; v_n int; v_old_name text;
  v_ref uuid; v_ref2 uuid; v_req_a uuid; v_req_l uuid; v_result text; v_role text; v_ref_tag uuid;
BEGIN
  SELECT id, full_name INTO v_student, v_old_name FROM public.profiles WHERE role = 'student' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_student2 FROM public.profiles WHERE role = 'student' AND id <> v_student ORDER BY created_at LIMIT 1;
  SELECT id INTO v_student3 FROM public.profiles WHERE role = 'student' AND id NOT IN (v_student, v_student2) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_admin FROM public.profiles WHERE role = 'admin' LIMIT 1;
  SELECT id INTO v_super FROM public.profiles WHERE role = 'super_admin' LIMIT 1;

  -- Fixtures created as the server BEFORE switching role: two educator applications.
  --   v_ref  : ANONYMOUS application (requester_user_id NULL) -> exercises link_access_request
  --   v_ref2 : LINKED application for v_student3            -> exercises approve_educator_application role grant
  v_ref  := public.submit_educator_application('Guard Test Anonymous', '+919876500901', 'https://linkedin.com/in/guardtest1');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student3, 'role', 'authenticated')::text, true);
  v_ref2 := public.submit_educator_application('Guard Test Linked', '+919876500902', 'https://linkedin.com/in/guardtest2',
                                               NULL, NULL, 'CA Inter', NULL, v_student3);
  UPDATE public.profiles SET role = 'student', access_request_ref = NULL WHERE id IN (v_student, v_student3);
  -- Look the request ids up NOW, as the server: under the client role, RLS on access_requests could hide them
  -- and turn a harness problem into a false FAIL.
  SELECT id INTO v_req_a FROM public.access_requests WHERE ref_token = v_ref  AND request_type = 'educator_application';
  SELECT id INTO v_req_l FROM public.access_requests WHERE ref_token = v_ref2 AND request_type = 'educator_application';

  -- ══ PART A: attacks that must be blocked ════════════════════════════════════
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  BEGIN UPDATE public.profiles SET role = 'super_admin' WHERE id = v_student;
    v_res := v_res || 'A1 student -> own role [CRITICAL]|RAISE|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('A1 student -> own role [CRITICAL]|RAISE|' || left(v_err, 24) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  -- A REAL change: the cohort is already 'enrolled', and setting an unchanged value never fires the guard.
  BEGIN UPDATE public.profiles
           SET account_type = CASE WHEN account_type = 'enrolled' THEN 'self_registered' ELSE 'enrolled' END
         WHERE id = v_student;
    v_res := v_res || 'A2 student -> own account_type, a real change [CRITICAL]|RAISE|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('A2 student -> own account_type, a real change [CRITICAL]|RAISE|' || left(v_err, 24) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  BEGIN UPDATE public.profiles SET status = 'suspended' WHERE id = v_student;
    v_res := v_res || 'A3 student -> own status|RAISE|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('A3 student -> own status|RAISE|' || left(v_err, 24) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  BEGIN UPDATE public.profiles SET email = 'someone.else@example.com' WHERE id = v_student;
    v_res := v_res || 'A4 student -> own email|RAISE|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('A4 student -> own email|RAISE|' || left(v_err, 24) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  BEGIN UPDATE public.profiles SET access_request_ref = gen_random_uuid() WHERE id = v_student;
    v_res := v_res || 'A5 student -> own access_request_ref directly|RAISE|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('A5 student -> own access_request_ref directly|RAISE|' || left(v_err, 24) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  -- ══ PART B: legitimate client edits still work ══════════════════════════════
  BEGIN
    UPDATE public.profiles
       SET full_name = COALESCE(v_old_name, 'Test') || ' ',
           course_level = course_level,
           institution = institution,
           timezone = 'Asia/Kolkata',
           daily_review_goal = 20,
           has_seen_onboarding = true,
           has_dismissed_goal_prompt = true,
           has_dismissed_exam_prompt = true,
           exam_date = NULL
     WHERE id = v_student;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('B1 student edits name/institution/timezone/goal/onboarding flags in one UPDATE|allowed|' || v_n || ' row|' ||
             CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('B1 student edits name/institution/timezone/goal/onboarding flags in one UPDATE|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

  -- ══ PART D (client-role calls into the real definer RPCs) ═══════════════════
  -- D3 update_daily_goal - unprotected columns, must be unaffected.
  BEGIN
    PERFORM public.update_daily_goal(30, NULL);
    v_res := v_res || 'D3 update_daily_goal (definer RPC, unprotected columns)|allowed|allowed|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('D3 update_daily_goal (definer RPC, unprotected columns)|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

  -- ══ PART C/D: admin session ═════════════════════════════════════════════════
  IF v_admin IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

    -- A REAL change (staff are 'enrolled' today, so setting 'enrolled' would not fire the guard at all).
    BEGIN UPDATE public.profiles SET account_type = 'self_registered' WHERE id = v_admin;
      v_res := v_res || 'C1 admin -> own account_type, a real change (allowed)|allowed|allowed|PASS'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C1 admin -> own account_type, a real change (allowed)|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

    BEGIN UPDATE public.profiles SET role = 'super_admin' WHERE id = v_admin;
      v_res := v_res || 'A6 admin -> own role to super_admin [CRITICAL]|RAISE|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('A6 admin -> own role to super_admin [CRITICAL]|RAISE|' || left(v_err, 24) || '|' ||
               CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

    -- INFO: plain admin updating ANOTHER user's account_type (AdminDashboard "Grant Access" path).
    BEGIN UPDATE public.profiles SET account_type = 'enrolled' WHERE id = v_student2;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('INFO admin -> another user''s account_type (AdminDashboard.jsx:395)|info|' || v_n ||
               ' row(s)|INFO (0 = RLS-blocked for non-super admins, independent of the guard)');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('INFO admin -> another user''s account_type (AdminDashboard.jsx:395)|info|' || left(v_err, 24) || '|INFO');
    END;

    -- D1 approve_educator_application (admin caller, linked applicant v_student3): definer writes role.
    BEGIN
      v_result := public.approve_educator_application(v_req_l);
      v_res := v_res || ('D1 approve_educator_application returns|role_granted|' || COALESCE(v_result, 'NULL') || '|' ||
               CASE WHEN v_result = 'role_granted' THEN 'PASS' ELSE 'FAIL' END);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('D1 approve_educator_application returns|role_granted|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

    -- Approve the ANONYMOUS application too, so D2 has an approved token to claim.
    BEGIN
      PERFORM public.approve_educator_application(v_req_a);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('D0 approve anonymous application (fixture)|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;
  END IF;

  -- ══ PART D2: link_access_request as the first-login student ═════════════════
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.link_access_request(v_ref);
    v_res := v_res || 'D2 link_access_request executes (definer RPC writing role + access_request_ref)|allowed|allowed|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('D2 link_access_request executes (definer RPC writing role + access_request_ref)|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

  -- ══ PART C: super admin changes ANOTHER user's role and status (SuperAdminDashboard.jsx:375 path) ══
  IF v_super IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_super, 'role', 'authenticated')::text, true);
    BEGIN
      UPDATE public.profiles SET role = 'professor' WHERE id = v_student2;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C2 super admin changes another user''s role (allowed)|allowed|' || v_n || ' row|' ||
               CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C2 super admin changes another user''s role (allowed)|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

    BEGIN
      UPDATE public.profiles SET status = 'suspended', account_type = 'enrolled' WHERE id = v_student2;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C3 super admin changes another user''s status/account_type (allowed)|allowed|' || v_n || ' row|' ||
               CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C3 super admin changes another user''s status/account_type (allowed)|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;
  END IF;

  -- ══ Back to the session role: read back what the definer RPCs did, then PART E ══
  EXECUTE 'RESET ROLE';

  SELECT role INTO v_role FROM public.profiles WHERE id = v_student3;
  v_res := v_res || ('D1b linked applicant now has role professor|professor|' || COALESCE(v_role, 'NULL') || '|' ||
           CASE WHEN v_role = 'professor' THEN 'PASS' ELSE 'FAIL' END);

  SELECT role, access_request_ref INTO v_role, v_ref_tag FROM public.profiles WHERE id = v_student;
  v_res := v_res || ('D2b anonymous-application claimer now has role professor|professor|' || COALESCE(v_role, 'NULL') || '|' ||
           CASE WHEN v_role = 'professor' THEN 'PASS' ELSE 'FAIL' END);
  v_res := v_res || ('D2c link_access_request tagged access_request_ref|token set|' ||
           CASE WHEN v_ref_tag IS NOT NULL THEN 'set' ELSE 'NULL' END || '|' ||
           CASE WHEN v_ref_tag = v_ref THEN 'PASS' ELSE 'FAIL' END);

  -- PART E: not 'authenticated' (SQL editor / postgres): unconstrained.
  BEGIN
    UPDATE public.profiles SET role = role, account_type = account_type WHERE id = v_student;
    v_res := v_res || 'E1 non-client path (postgres) unconstrained|allowed|allowed|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('E1 non-client path (postgres) unconstrained|allowed|' || left(v_err, 24) || '|FAIL: ' || v_err); END;

  INSERT INTO _r
  SELECT ord, split_part(x, '|', 1), split_part(x, '|', 2), split_part(x, '|', 3), split_part(x, '|', 4)
  FROM unnest(v_res) WITH ORDINALITY AS t(x, ord);
END $$;

SELECT * FROM _r ORDER BY seq;
ROLLBACK;
