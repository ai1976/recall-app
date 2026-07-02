-- Name: [FUNCTIONS] submit_institute_inquiry RPC
-- Description: Phase 5 Sprint 5 (B2B /educators route). SECURITY DEFINER RPC backing the
-- /educators lead form. The page is anonymous, so this must be the only write path into
-- access_requests for institute leads (no direct .from() insert — see CLAUDE.md's
-- unauthenticated-pages rule). Mirrors submit_access_request's validation/trim style.
--
-- Field mapping onto the existing access_requests shape (see 14_SCHEMA for the request_type/
-- message columns; no other columns changed):
--   p_contact_name     -> name              (existing NOT NULL)
--   p_whatsapp_number  -> whatsapp_number   (existing NOT NULL)
--   p_course           -> course            (existing NOT NULL; defaults to 'General inquiry'
--                                             if blank, since institute leads may not target one course)
--   p_email            -> email             (existing nullable)
--   p_institute_name   -> content_name      (existing nullable, reused; content_id/content_type
--                                             stay NULL since there's no associated content preview)
--   p_city + p_message -> message           (new nullable column; combined as "City: X" +
--                                             optional "\n\n<message>")
--   request_type is hardcoded to 'institute_inquiry'.
--
-- Admin notification: notifications.type is CHECK-constrained to a fixed list that does NOT
-- include an institute-specific value (confirmed via [DIAGNOSTIC] introspection) and this
-- sprint does not touch that constraint (out of scope). Reuses the existing 'access_request'
-- type so it lands in admins' existing notification handling; the title/message text and
-- metadata->>'request_type' distinguish it as an institute inquiry.

CREATE OR REPLACE FUNCTION public.submit_institute_inquiry(
  p_institute_name   text,
  p_contact_name     text,
  p_whatsapp_number  text,
  p_email            text DEFAULT NULL,
  p_city             text DEFAULT NULL,
  p_course           text DEFAULT NULL,
  p_message          text DEFAULT NULL,
  p_requester_user_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_course  text;
  v_message text;
BEGIN
  IF p_institute_name IS NULL OR trim(p_institute_name) = '' THEN
    RAISE EXCEPTION 'Institute name is required';
  END IF;
  IF p_contact_name IS NULL OR trim(p_contact_name) = '' THEN
    RAISE EXCEPTION 'Contact name is required';
  END IF;
  IF p_whatsapp_number IS NULL OR trim(p_whatsapp_number) = '' THEN
    RAISE EXCEPTION 'WhatsApp number is required';
  END IF;

  v_course := COALESCE(NULLIF(trim(p_course), ''), 'General inquiry');

  v_message := CASE WHEN p_city IS NOT NULL AND trim(p_city) <> ''
    THEN 'City: ' || trim(p_city)
    ELSE NULL END;
  IF p_message IS NOT NULL AND trim(p_message) <> '' THEN
    v_message := CASE WHEN v_message IS NOT NULL
      THEN v_message || E'\n\n' || trim(p_message)
      ELSE trim(p_message) END;
  END IF;

  INSERT INTO access_requests (
    request_type, name, whatsapp_number, course, email,
    content_name, message, requester_user_id
  ) VALUES (
    'institute_inquiry', trim(p_contact_name), trim(p_whatsapp_number), v_course,
    CASE WHEN p_email IS NOT NULL AND trim(p_email) <> '' THEN trim(p_email) ELSE NULL END,
    trim(p_institute_name), v_message, p_requester_user_id
  );

  INSERT INTO notifications (user_id, type, title, message, metadata)
  SELECT
    p.id,
    'access_request',
    'New institute inquiry: ' || trim(p_institute_name),
    trim(p_contact_name) || ' — ' || v_course,
    jsonb_build_object(
      'request_type', 'institute_inquiry',
      'institute_name', trim(p_institute_name),
      'contact_name', trim(p_contact_name),
      'whatsapp', trim(p_whatsapp_number),
      'city', p_city,
      'course', v_course
    )
  FROM profiles p
  WHERE p.role IN ('admin', 'super_admin');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_institute_inquiry(text, text, text, text, text, text, text, uuid) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
