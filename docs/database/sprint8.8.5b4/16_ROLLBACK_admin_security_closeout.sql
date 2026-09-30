-- [SCHEMA] ROLLBACK for the admin-security closeout: 08, 10, 13 and 14 (Sprint 8.8.5b4)
-- Description: Restores the state found on 30/09/2026 (07 diagnostic, block 4 for the three redefined functions).
--   Run the sections in this order and only if needed:
--     A. undo 14 (re-open the browser's direct writes) - needed FIRST if the frontend is reverted to the browser-writes version
--     B. undo 10 (drop the immutability trigger)
--     C. undo 08 + 13 (drop the new functions, restore the ORIGINAL approve / reject / admin_delete_user_data bodies)
--   Sections B and C do not need the frontend to change; section C DOES require the frontend to be the browser-writes
--   version (the new pages call admin_change_role / admin_delete_note / log_admin_event).
--   Note: restoring the original admin_delete_user_data brings back the provenance-blocked user deletion (12 diagnostic).

-- ===== A. undo 14 =====
GRANT INSERT ON public.admin_audit_log TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.admin_audit_log TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.role_change_log TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.role_change_log TO authenticated;
GRANT EXECUTE ON FUNCTION public.notify_access_granted(uuid) TO authenticated;

-- ===== B. undo 10 =====
DROP TRIGGER IF EXISTS trg_guard_admin_audit_log_rows ON public.admin_audit_log;
DROP TRIGGER IF EXISTS trg_guard_admin_audit_log_truncate ON public.admin_audit_log;
DROP FUNCTION IF EXISTS public.fn_guard_admin_audit_log_immutable();

-- ===== C. undo 08 + 13 =====
DROP FUNCTION IF EXISTS public.admin_change_role(uuid, text, text);
DROP FUNCTION IF EXISTS public.admin_delete_note(uuid);
DROP FUNCTION IF EXISTS public.log_admin_event(text, jsonb, uuid);

CREATE OR REPLACE FUNCTION public.approve_educator_application(p_request_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
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
 SET search_path TO public, extensions
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

CREATE OR REPLACE FUNCTION public.admin_delete_user_data(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only super_admin can delete user data';
  END IF;

  DELETE FROM study_group_members WHERE user_id = p_user_id;
  DELETE FROM profile_courses    WHERE user_id = p_user_id;
  DELETE FROM reviews            WHERE user_id = p_user_id;
  DELETE FROM flashcards         WHERE user_id = p_user_id;
  DELETE FROM flashcard_decks    WHERE user_id = p_user_id;
  DELETE FROM notes              WHERE user_id = p_user_id;
  DELETE FROM profiles           WHERE id      = p_user_id;
END;
$function$;
