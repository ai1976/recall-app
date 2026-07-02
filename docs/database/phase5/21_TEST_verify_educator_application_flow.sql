-- Name: [TEST] Verify educator-application → admin-approve → role grant flow
-- Description: Verifies the Sprint 6 hybrid educator on-ramp end to end: anonymous/logged-in
-- submission and field mapping (18_FUNCTIONS), required-field validation, the course default,
-- the admin notification, the admin-only gate on approve/reject (19_FUNCTIONS), the two approve
-- outcomes (immediate role grant when linked, deferred when not), reject, and the
-- link_access_request extension that grants the role on first login for a since-approved
-- application (20_FUNCTIONS) — plus a regression check that a still-pending application does
-- NOT grant the role on login.
--
-- OUTPUT: each block returns its verdict as a RESULT ROW (Supabase SQL Editor swallows RAISE
-- NOTICE). 'PASS ...' = passed, 'FAIL: ...' = real problem, 'SKIP: ...' = fixture missing.
-- Caller identity is simulated via set_config('request.jwt.claim.sub', ...), which auth.uid()
-- reads (same technique as 12_TEST). Each block is its own BEGIN/ROLLBACK — nothing persists.
-- Run each block separately.

-- ============================================
-- 1. Anonymous submit: all fields map correctly, request_type set, status=pending — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_ref uuid; v_row access_requests%ROWTYPE;
BEGIN
  SELECT submit_educator_application(
    'Anon Educator', '+919876511111', 'https://linkedin.com/in/anoneducator',
    'anon.educator@example.com', 'Anon Coaching Institute', 'CA Foundation',
    'I have taught 300+ students.'
  ) INTO v_ref;

  SELECT * INTO v_row FROM access_requests WHERE ref_token = v_ref;

  IF v_row.id IS NOT NULL
     AND v_row.request_type = 'educator_application'
     AND v_row.name = 'Anon Educator'
     AND v_row.whatsapp_number = '+919876511111'
     AND v_row.course = 'CA Foundation'
     AND v_row.email = 'anon.educator@example.com'
     AND v_row.content_name = 'Anon Coaching Institute'
     AND v_row.requester_user_id IS NULL
     AND v_row.status = 'pending'
     AND v_row.message = 'Credential/LinkedIn: https://linkedin.com/in/anoneducator' || E'\n\n' || 'I have taught 300+ students.'
  THEN INSERT INTO _r VALUES ('PASS: anonymous application inserted with all fields mapped correctly');
  ELSE INSERT INTO _r VALUES ('FAIL: field mismatch — ' || row_to_json(v_row)::text);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 2. Missing credential/LinkedIn is rejected — Expected: PASS (expected error)
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
BEGIN
  BEGIN
    PERFORM submit_educator_application('Some Name', '+919876500000', '   ');
    INSERT INTO _r VALUES ('FAIL: blank credential/LinkedIn should have been rejected');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 3. Course omitted -> defaults to 'Not specified' — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_ref uuid; v_course text;
BEGIN
  SELECT submit_educator_application(
    'No Course Educator', '+919876522222', 'https://linkedin.com/in/nocourse'
  ) INTO v_ref;
  SELECT course INTO v_course FROM access_requests WHERE ref_token = v_ref;
  IF v_course = 'Not specified' THEN INSERT INTO _r VALUES ('PASS: course defaulted to Not specified');
  ELSE INSERT INTO _r VALUES ('FAIL: expected Not specified, got ' || COALESCE(v_course, 'NULL'));
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 4. Admin notification created on submit — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_admin_count int; v_notif_count int; v_ref uuid;
BEGIN
  SELECT count(*) INTO v_admin_count FROM profiles WHERE role IN ('admin', 'super_admin');
  IF v_admin_count = 0 THEN
    INSERT INTO _r VALUES ('SKIP: no admin/super_admin fixture to notify'); RETURN;
  END IF;

  SELECT submit_educator_application(
    'Notify Test Educator', '+919876533333', 'https://linkedin.com/in/notifytest'
  ) INTO v_ref;

  SELECT count(*) INTO v_notif_count FROM notifications
  WHERE type = 'access_request'
    AND metadata->>'request_type' = 'educator_application'
    AND metadata->>'full_name' = 'Notify Test Educator';

  IF v_notif_count = v_admin_count THEN
    INSERT INTO _r VALUES ('PASS: notification created for every admin/super_admin');
  ELSE
    INSERT INTO _r VALUES ('FAIL: expected ' || v_admin_count || ' notifications, got ' || v_notif_count);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 5. Non-admin (student) cannot approve — Expected: PASS (expected error): Access denied
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_student_id uuid; v_ref uuid; v_req_id uuid;
BEGIN
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  IF v_student_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no student fixture'); RETURN;
  END IF;

  SELECT submit_educator_application('Gate Test Educator', '+919876588888', 'https://linkedin.com/in/gatetest') INTO v_ref;
  SELECT id INTO v_req_id FROM access_requests WHERE ref_token = v_ref AND request_type = 'educator_application';

  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  BEGIN
    PERFORM approve_educator_application(v_req_id);
    INSERT INTO _r VALUES ('FAIL: student approve should have been denied');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 6. Approve on a LINKED application (requester_user_id set) flips role→professor + notifies
-- Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_admin_id uuid; v_student_id uuid; v_ref uuid; v_req_id uuid; v_result text; v_role text; v_notif_count int;
BEGIN
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  IF v_admin_id IS NULL OR v_student_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no admin or student fixture'); RETURN;
  END IF;

  UPDATE profiles SET role = 'student' WHERE id = v_student_id;

  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  SELECT submit_educator_application(
    'Linked Test Educator', '+919876566666', 'https://linkedin.com/in/linkedtest',
    NULL, NULL, 'CA Inter', NULL, v_student_id
  ) INTO v_ref;
  SELECT id INTO v_req_id FROM access_requests WHERE ref_token = v_ref AND request_type = 'educator_application';

  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  SELECT approve_educator_application(v_req_id) INTO v_result;

  SELECT role INTO v_role FROM profiles WHERE id = v_student_id;
  SELECT count(*) INTO v_notif_count FROM notifications
  WHERE user_id = v_student_id AND (metadata->>'access_request_id')::uuid = v_req_id;

  IF v_result = 'role_granted' AND v_role = 'professor' AND v_notif_count >= 1 THEN
    INSERT INTO _r VALUES ('PASS: linked approve granted professor role + notified applicant');
  ELSE
    INSERT INTO _r VALUES ('FAIL: result=' || v_result || ' role=' || COALESCE(v_role, 'NULL') || ' notif_count=' || v_notif_count);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 7. Approve on an UNLINKED application marks approved WITHOUT a role flip — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_admin_id uuid; v_ref uuid; v_req_id uuid; v_result text; v_status text;
BEGIN
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  IF v_admin_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no admin fixture'); RETURN;
  END IF;

  SELECT submit_educator_application('Unlinked Test Educator', '+919876555555', 'https://linkedin.com/in/unlinkedtest') INTO v_ref;
  SELECT id INTO v_req_id FROM access_requests WHERE ref_token = v_ref AND request_type = 'educator_application';

  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  SELECT approve_educator_application(v_req_id) INTO v_result;

  SELECT status INTO v_status FROM access_requests WHERE id = v_req_id;

  IF v_result = 'approved_pending_signup' AND v_status = 'approved' THEN
    INSERT INTO _r VALUES ('PASS: unlinked application approved without role flip, status=approved');
  ELSE
    INSERT INTO _r VALUES ('FAIL: expected approved_pending_signup/approved, got ' || v_result || '/' || v_status);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 8. Reject marks rejected + notifies a linked applicant — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_admin_id uuid; v_student_id uuid; v_ref uuid; v_req_id uuid; v_status text; v_notif_count int;
BEGIN
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  IF v_admin_id IS NULL OR v_student_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no admin or student fixture'); RETURN;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  SELECT submit_educator_application(
    'Reject Test Educator', '+919876577777', 'https://linkedin.com/in/rejecttest',
    NULL, NULL, NULL, NULL, v_student_id
  ) INTO v_ref;
  SELECT id INTO v_req_id FROM access_requests WHERE ref_token = v_ref AND request_type = 'educator_application';

  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  PERFORM reject_educator_application(v_req_id);

  SELECT status INTO v_status FROM access_requests WHERE id = v_req_id;
  SELECT count(*) INTO v_notif_count FROM notifications
  WHERE user_id = v_student_id AND (metadata->>'access_request_id')::uuid = v_req_id;

  IF v_status = 'rejected' AND v_notif_count >= 1 THEN
    INSERT INTO _r VALUES ('PASS: reject marked rejected + notified applicant');
  ELSE
    INSERT INTO _r VALUES ('FAIL: status=' || v_status || ' notif_count=' || v_notif_count);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 9. link_access_request flips role for an approved application on first login — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_admin_id uuid; v_student_id uuid; v_ref uuid; v_req_id uuid; v_role text;
BEGIN
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  IF v_admin_id IS NULL OR v_student_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no admin or student fixture'); RETURN;
  END IF;

  -- Anonymous application (no requester_user_id) — applicant hasn't signed up yet
  SELECT submit_educator_application(
    'Link Test Educator', '+919876544444', 'https://linkedin.com/in/linktest',
    NULL, 'Link Test Institute', 'CA Final', 'Teaching 5 years.'
  ) INTO v_ref;
  SELECT id INTO v_req_id FROM access_requests WHERE ref_token = v_ref AND request_type = 'educator_application';

  -- Admin approves the still-unlinked application
  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  PERFORM approve_educator_application(v_req_id);

  -- Simulate the applicant's fresh signup: stand-in profile with no ref yet, role reset to student
  UPDATE profiles SET role = 'student', access_request_ref = NULL WHERE id = v_student_id;

  -- First Dashboard.jsx mount post-signup calls link_access_request with the carried ref_token
  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  PERFORM link_access_request(v_ref);

  SELECT role INTO v_role FROM profiles WHERE id = v_student_id;
  IF v_role = 'professor' THEN
    INSERT INTO _r VALUES ('PASS: link_access_request granted professor role on first login for approved application');
  ELSE
    INSERT INTO _r VALUES ('FAIL: expected role=professor, got ' || COALESCE(v_role, 'NULL'));
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 10. REGRESSION: link_access_request does NOT flip role for a still-PENDING application
-- Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_student_id uuid; v_ref uuid; v_role text;
BEGIN
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  IF v_student_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no student fixture'); RETURN;
  END IF;

  SELECT submit_educator_application(
    'Pending Test Educator', '+919876599999', 'https://linkedin.com/in/pendingtest'
  ) INTO v_ref;

  UPDATE profiles SET role = 'student', access_request_ref = NULL WHERE id = v_student_id;
  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  PERFORM link_access_request(v_ref);

  SELECT role INTO v_role FROM profiles WHERE id = v_student_id;
  IF v_role = 'student' THEN
    INSERT INTO _r VALUES ('PASS: role unchanged for a still-pending application');
  ELSE
    INSERT INTO _r VALUES ('FAIL: role unexpectedly changed to ' || COALESCE(v_role, 'NULL'));
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;
