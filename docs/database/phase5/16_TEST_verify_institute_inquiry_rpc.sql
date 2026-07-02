-- Name: [TEST] Verify submit_institute_inquiry RPC
-- Description: Verifies the Sprint 5 institute-inquiry write path: the row lands in
-- access_requests with request_type='institute_inquiry' and every field mapped correctly
-- (14_SCHEMA + 15_FUNCTIONS), the course default kicks in when omitted, the city+message
-- combination formats correctly, required-field validation rejects blanks, and an admin
-- notification is created with the distinguishing metadata.
--
-- OUTPUT: each block returns its verdict as a RESULT ROW (Supabase SQL Editor swallows RAISE
-- NOTICE). 'PASS ...' = passed, 'FAIL: ...' = real problem, 'SKIP: ...' = fixture missing.
-- Each block is its own BEGIN/ROLLBACK — nothing persists. Run each block separately.

-- ============================================
-- 1. Full submit: all fields map correctly, request_type set — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_row access_requests%ROWTYPE;
BEGIN
  PERFORM submit_institute_inquiry(
    'Test Coaching Institute', 'Jane Doe', '+919876543210',
    'jane@testinstitute.com', 'Mumbai', 'CA Foundation, CA Intermediate',
    'We have 200 students, interested in a pilot.'
  );
  SELECT * INTO v_row FROM access_requests
  WHERE content_name = 'Test Coaching Institute' ORDER BY requested_at DESC LIMIT 1;

  IF v_row.id IS NOT NULL
     AND v_row.request_type = 'institute_inquiry'
     AND v_row.name = 'Jane Doe'
     AND v_row.whatsapp_number = '+919876543210'
     AND v_row.course = 'CA Foundation, CA Intermediate'
     AND v_row.email = 'jane@testinstitute.com'
     AND v_row.message = 'City: Mumbai' || E'\n\n' || 'We have 200 students, interested in a pilot.'
  THEN INSERT INTO _r VALUES ('PASS: all fields mapped correctly, request_type=institute_inquiry');
  ELSE INSERT INTO _r VALUES ('FAIL: field mismatch — ' || row_to_json(v_row)::text);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 2. Course omitted -> defaults to 'General inquiry' — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_course text;
BEGIN
  PERFORM submit_institute_inquiry(
    'No Course Institute', 'John Smith', '+919876500000'
  );
  SELECT course INTO v_course FROM access_requests
  WHERE content_name = 'No Course Institute' ORDER BY requested_at DESC LIMIT 1;

  IF v_course = 'General inquiry' THEN INSERT INTO _r VALUES ('PASS: course defaulted to General inquiry');
  ELSE INSERT INTO _r VALUES ('FAIL: expected General inquiry, got ' || COALESCE(v_course, 'NULL'));
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 3. City only, no message -> message = 'City: X' with no trailing text — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_message text;
BEGIN
  PERFORM submit_institute_inquiry(
    'City Only Institute', 'Amit Kumar', '+919876511111',
    NULL, 'Pune'
  );
  SELECT message INTO v_message FROM access_requests
  WHERE content_name = 'City Only Institute' ORDER BY requested_at DESC LIMIT 1;

  IF v_message = 'City: Pune' THEN INSERT INTO _r VALUES ('PASS: message is City-only, no trailing text');
  ELSE INSERT INTO _r VALUES ('FAIL: expected "City: Pune", got ' || COALESCE(v_message, 'NULL'));
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 4. Missing institute name is rejected — Expected: PASS (expected error): Institute name is required
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
BEGIN
  BEGIN
    PERFORM submit_institute_inquiry('', 'Jane Doe', '+919876543210');
    INSERT INTO _r VALUES ('FAIL: blank institute name should have been rejected');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 5. Missing WhatsApp number is rejected — Expected: PASS (expected error): WhatsApp number is required
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
BEGIN
  BEGIN
    PERFORM submit_institute_inquiry('Some Institute', 'Jane Doe', '   ');
    INSERT INTO _r VALUES ('FAIL: blank WhatsApp number should have been rejected');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 6. Admin notification created with distinguishing metadata — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_admin_count int; v_notif_count int;
BEGIN
  SELECT count(*) INTO v_admin_count FROM profiles WHERE role IN ('admin', 'super_admin');
  IF v_admin_count = 0 THEN
    INSERT INTO _r VALUES ('SKIP: no admin/super_admin fixture to notify'); RETURN;
  END IF;

  PERFORM submit_institute_inquiry(
    'Notify Test Institute', 'Priya Singh', '+919876522222', NULL, 'Delhi'
  );

  SELECT count(*) INTO v_notif_count FROM notifications
  WHERE type = 'access_request'
    AND metadata->>'request_type' = 'institute_inquiry'
    AND metadata->>'institute_name' = 'Notify Test Institute';

  IF v_notif_count = v_admin_count THEN
    INSERT INTO _r VALUES ('PASS: notification created for every admin/super_admin with correct metadata');
  ELSE
    INSERT INTO _r VALUES ('FAIL: expected ' || v_admin_count || ' notifications, got ' || v_notif_count);
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;
