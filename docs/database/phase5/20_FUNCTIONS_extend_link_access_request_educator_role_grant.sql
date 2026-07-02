-- Name: [FUNCTIONS] Extend link_access_request for educator role grant on first login
-- Description: Phase 5 Sprint 6. Ground-truth introspection (pg_get_functiondef) showed the
-- live link_access_request is much simpler than assumed going in — it does NOT touch
-- access_requests at all; it only tags the newly-authenticated user's
-- profiles.access_request_ref with the ref_token (AdminDashboard.jsx separately matches
-- profiles to access_requests rows by that tag for its existing manual "Grant Access" flow).
-- This CREATE OR REPLACE matches that exact signature/return type (public.link_access_request
-- (uuid) RETURNS void, LANGUAGE plpgsql, SECURITY DEFINER, no SET search_path — preserved as-is
-- from the introspected definition rather than added, since the sprint brief requires not
-- changing existing behavior).
--
-- Closes the apply-anonymously-then-sign-up path for educator applications: submit_educator_
-- application (18_FUNCTIONS) returns a ref_token even for anonymous applicants; the /educators
-- form stores it into localStorage['revisop_access_ref'] exactly like Signup.jsx's ?ref= query
-- param does today. If an admin approves that application (19_FUNCTIONS) BEFORE the applicant
-- has an account (requester_user_id was NULL, so the role grant was deferred), this extension
-- catches it here: after the existing access_request_ref tagging, it checks whether the token
-- belongs to an approved educator_application, and if so grants the professor role right then
-- (first Dashboard.jsx mount post-signup, same call site as before — no frontend change needed
-- beyond what 18_FUNCTIONS' return value already requires).
--
-- All other request_types (student_access, institute_inquiry) are unaffected — the added lookup
-- only ever matches rows with request_type = 'educator_application' AND status = 'approved'.

CREATE OR REPLACE FUNCTION public.link_access_request(p_ref_token uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user_id UUID;
  v_approved_app_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RETURN; END IF;

  UPDATE profiles
    SET access_request_ref = p_ref_token
    WHERE id = v_user_id AND access_request_ref IS NULL;

  SELECT id INTO v_approved_app_id
  FROM access_requests
  WHERE ref_token = p_ref_token
    AND request_type = 'educator_application'
    AND status = 'approved'
  LIMIT 1;

  IF v_approved_app_id IS NOT NULL THEN
    UPDATE profiles SET role = 'professor' WHERE id = v_user_id;

    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      v_user_id,
      'access_request',
      'Your educator application was approved',
      'Welcome aboard — your account now has Educator access.',
      jsonb_build_object('request_type', 'educator_application', 'access_request_id', v_approved_app_id)
    );
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.link_access_request(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
