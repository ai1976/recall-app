-- Name: [FUNCTIONS] submit_educator_application RPC
-- Description: Phase 5 Sprint 6 (hybrid educator on-ramp — self-serve application, admin
-- approval grants the professor role). SECURITY DEFINER RPC backing the "Apply to teach on
-- RevisOp" form on /educators, which may be filled out anonymously or while logged in. This
-- must be the only write path into access_requests for educator applications (no direct
-- .from() insert — see CLAUDE.md's unauthenticated-pages rule).
--
-- Required fields: full name, WhatsApp number, and a credential-or-LinkedIn URL (the applicant's
-- core proof of expertise — the vetted-educator trust moat is core to the brand, so an
-- application with no verifiable credential is rejected outright, mirroring submit_access_request
-- / submit_institute_inquiry's required-field style). Email, institute name, course(s) taught,
-- and "why" are optional.
--
-- Field mapping onto the existing access_requests shape (no new columns beyond 17_SCHEMA's status
-- CHECK extension):
--   p_full_name              -> name              (existing NOT NULL)
--   p_whatsapp_number        -> whatsapp_number   (existing NOT NULL)
--   p_course                 -> course            (existing NOT NULL; defaults to 'Not specified'
--                                                   if blank, since not every applicant will name
--                                                   a specific course)
--   p_email                  -> email             (existing nullable)
--   p_institute_name         -> content_name      (existing nullable, reused — same slot
--                                                   submit_institute_inquiry uses; request_type
--                                                   disambiguates the two)
--   p_credential_or_linkedin
--     + p_why                -> message           (existing nullable, combined as
--                                                   "Credential/LinkedIn: <url>" + optional
--                                                   "\n\n<why>", mirroring submit_institute_inquiry's
--                                                   city+message combination idiom)
--   request_type is hardcoded to 'educator_application'.
--
-- Returns the inserted row's ref_token (uuid), NOT void — unlike the other two submit_* RPCs.
-- An anonymous applicant has no account yet; the frontend stores this token exactly like the
-- existing signup-referral mechanism (Signup.jsx reads ?ref=<token> into
-- localStorage['revisop_access_ref']; Dashboard.jsx replays it via link_access_request() on first
-- mount). Storing the token directly (no query-param round trip needed) means that if the
-- applicant signs up in the same browser later, 20_FUNCTIONS' extended link_access_request will
-- find their now-approved application and grant the professor role automatically.
--
-- Admin notification: reuses the existing 'access_request' notifications.type (not CHECK-extended
-- — out of scope, same reasoning as submit_institute_inquiry); metadata->>'request_type'
-- distinguishes it as an educator application.

CREATE OR REPLACE FUNCTION public.submit_educator_application(
  p_full_name              text,
  p_whatsapp_number        text,
  p_credential_or_linkedin text,
  p_email                  text DEFAULT NULL,
  p_institute_name         text DEFAULT NULL,
  p_course                 text DEFAULT NULL,
  p_why                    text DEFAULT NULL,
  p_requester_user_id      uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_course  text;
  v_message text;
  v_ref     uuid;
BEGIN
  IF p_full_name IS NULL OR trim(p_full_name) = '' THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;
  IF p_whatsapp_number IS NULL OR trim(p_whatsapp_number) = '' THEN
    RAISE EXCEPTION 'WhatsApp number is required';
  END IF;
  IF p_credential_or_linkedin IS NULL OR trim(p_credential_or_linkedin) = '' THEN
    RAISE EXCEPTION 'A credential or LinkedIn URL is required';
  END IF;

  v_course := COALESCE(NULLIF(trim(p_course), ''), 'Not specified');

  v_message := 'Credential/LinkedIn: ' || trim(p_credential_or_linkedin);
  IF p_why IS NOT NULL AND trim(p_why) <> '' THEN
    v_message := v_message || E'\n\n' || trim(p_why);
  END IF;

  INSERT INTO access_requests (
    request_type, name, whatsapp_number, course, email,
    content_name, message, requester_user_id
  ) VALUES (
    'educator_application', trim(p_full_name), trim(p_whatsapp_number), v_course,
    CASE WHEN p_email IS NOT NULL AND trim(p_email) <> '' THEN trim(p_email) ELSE NULL END,
    CASE WHEN p_institute_name IS NOT NULL AND trim(p_institute_name) <> '' THEN trim(p_institute_name) ELSE NULL END,
    v_message, p_requester_user_id
  )
  RETURNING ref_token INTO v_ref;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  SELECT
    p.id,
    'access_request',
    'New educator application: ' || trim(p_full_name),
    v_course || CASE WHEN p_institute_name IS NOT NULL AND trim(p_institute_name) <> ''
                 THEN ' — ' || trim(p_institute_name) ELSE ' — Independent' END,
    jsonb_build_object(
      'request_type', 'educator_application',
      'full_name', trim(p_full_name),
      'whatsapp', trim(p_whatsapp_number),
      'email', p_email,
      'institute_name', p_institute_name,
      'course', v_course,
      'credential_or_linkedin', trim(p_credential_or_linkedin),
      'why', p_why
    )
  FROM profiles p
  WHERE p.role IN ('admin', 'super_admin');

  RETURN v_ref;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_educator_application(text, text, text, text, text, text, text, uuid) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
