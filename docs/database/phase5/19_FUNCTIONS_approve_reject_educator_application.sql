-- Name: [FUNCTIONS] approve_educator_application / reject_educator_application
-- Description: Phase 5 Sprint 6. Admin/super_admin-only RPCs that decide a pending
-- educator_application row in access_requests (see 18_FUNCTIONS for how the row is created).
-- Mirrors the admin-guard idiom used by 11_FUNCTIONS' approve_featured_nomination /
-- reject_featured_nomination (SELECT role INTO v_caller_role ... IF NOT IN ('admin',
-- 'super_admin') THEN RAISE EXCEPTION). Both require the row to currently be 'pending' —
-- re-deciding an already-approved/rejected row raises, which also prevents double-granting the
-- role or sending duplicate notifications.
--
-- approve_educator_application(p_request_id):
--   - If the application already has a requester_user_id (applicant was logged in when they
--     applied, or a prior signup already linked it), flips that account's profiles.role to
--     'professor' immediately, notifies them, and returns 'role_granted'.
--   - If requester_user_id is NULL (applied anonymously, hasn't signed up yet), only marks the
--     row approved and returns 'approved_pending_signup' — the role grant is deferred to first
--     login via 20_FUNCTIONS' extended link_access_request(), which checks for an approved
--     educator_application matching the ref_token the new signup carries.
--   - Returns text (not void) specifically so AdminDashboard.jsx can show the admin which of the
--     two outcomes happened.
--
-- reject_educator_application(p_request_id):
--   - Marks the row rejected; notifies the applicant only if they have a linked account (an
--     anonymous applicant has no way to receive an in-app notification).
--
-- Both require 17_SCHEMA's status CHECK extension to be deployed first (else the UPDATE to
-- 'approved'/'rejected' fails the CHECK).

CREATE OR REPLACE FUNCTION public.approve_educator_application(p_request_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
  v_req         access_requests%ROWTYPE;
BEGIN
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT * INTO v_req FROM access_requests
  WHERE id = p_request_id AND request_type = 'educator_application';
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Educator application not found';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Application is not pending (current status: %)', v_req.status;
  END IF;

  UPDATE access_requests SET status = 'approved' WHERE id = p_request_id;

  IF v_req.requester_user_id IS NOT NULL THEN
    -- Promote to professor, but never overwrite a higher role (don't demote an admin/super_admin).
    UPDATE profiles SET role = 'professor'
     WHERE id = v_req.requester_user_id AND role NOT IN ('admin', 'super_admin');

    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      v_req.requester_user_id,
      'access_request',
      'Your educator application was approved',
      'Welcome aboard — your account now has Educator access.',
      jsonb_build_object('request_type', 'educator_application', 'access_request_id', p_request_id)
    );

    RETURN 'role_granted';
  END IF;

  RETURN 'approved_pending_signup';
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_educator_application(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
  v_req         access_requests%ROWTYPE;
BEGIN
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT * INTO v_req FROM access_requests
  WHERE id = p_request_id AND request_type = 'educator_application';
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Educator application not found';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Application is not pending (current status: %)', v_req.status;
  END IF;

  UPDATE access_requests SET status = 'rejected' WHERE id = p_request_id;

  IF v_req.requester_user_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      v_req.requester_user_id,
      'access_request',
      'Your educator application was not approved',
      'Thanks for your interest — we were unable to approve your educator application at this time.',
      jsonb_build_object('request_type', 'educator_application', 'access_request_id', p_request_id)
    );
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.approve_educator_application(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_educator_application(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
