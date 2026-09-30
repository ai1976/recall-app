-- [FUNCTIONS] Admin-security closeout: server-side actions that write their OWN audit entries (Sprint 8.8.5b4, D-48)
-- Description: Moves the remaining browser-side audit writes into transactional server functions, so the history is
--   created by the database in the SAME transaction as the action - it cannot be skipped, half-written or forged.
--     admin_change_role(uuid, text, text)   super admin only; role change + role_change_log + audit in one transaction
--                                           (was: 3 separate browser calls; a failure in the middle left a role changed
--                                           with an incomplete record)
--     admin_delete_note(uuid)               admin; delete + audit; returns the image path for the client's storage cleanup
--     log_admin_event(text, jsonb, uuid)    server-authored logger for the events that are inherently client-driven
--                                           (admin_login, bulk_upload_flashcards, bulk_upload_topics, create_discipline):
--                                           fixed whitelist, admin_id ALWAYS = the caller, details size-capped
--     approve_educator_application / reject_educator_application   same bodies as before + their own audit entry
--                                           (target = the applicant, which the browser never logged)
--     admin_delete_user_data(uuid)          same deletes as before + its own audit entry (written BEFORE the profile row is
--                                           removed, so the target is recorded; the foreign key then nulls it, as it always
--                                           has) + new refusals: cannot delete yourself or an admin / super admin account
--                                           (demote first with admin_change_role) - previously a super admin could delete
--                                           ANY account including their own
--   All SECURITY DEFINER, unquoted search_path (public, extensions), executable by signed-in users only, each re-checks
--   the caller's role. Nothing here changes a table's policies or grants - that is step 14 (file 14), AFTER the frontend switches.
-- Rollback: 16. Test: 09.

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_change_role(p_user_id uuid, p_new_role text, p_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_old   text;
  v_n     integer;
  v_reason text := COALESCE(NULLIF(btrim(p_reason), ''), NULL);
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Access denied: super_admin only' USING ERRCODE = '42501';
  END IF;
  IF p_new_role IS NULL OR p_new_role NOT IN ('student', 'professor', 'admin', 'super_admin') THEN
    RAISE EXCEPTION 'Invalid role: %', COALESCE(p_new_role, 'NULL');
  END IF;
  IF p_user_id IS NULL OR p_user_id = v_actor THEN
    RAISE EXCEPTION 'Access denied: cannot_act_on_self' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_old FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Access denied: target_not_found' USING ERRCODE = '42501';
  END IF;
  IF v_old = p_new_role THEN
    RETURN jsonb_build_object('changed', false, 'reason', 'same_role', 'role', v_old);
  END IF;

  UPDATE public.profiles SET role = p_new_role WHERE id = p_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Change role failed: expected to change 1 profile, changed %', v_n;
  END IF;

  INSERT INTO public.role_change_log (user_id, old_role, new_role, changed_by, reason)
  VALUES (p_user_id, v_old, p_new_role, v_actor, COALESCE(v_reason, 'Changed from ' || v_old || ' to ' || p_new_role));

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('change_role', v_actor, p_user_id,
          jsonb_build_object('old_role', v_old, 'new_role', p_new_role, 'reason', v_reason, 'via', 'admin_change_role'));

  RETURN jsonb_build_object('changed', true, 'old_role', v_old, 'new_role', p_new_role);
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_note(p_note_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_note  public.notes%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: not_admin' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_note FROM public.notes WHERE id = p_note_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('deleted', false, 'reason', 'not_found');
  END IF;

  DELETE FROM public.notes WHERE id = p_note_id;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('delete_note', v_actor, v_note.user_id,
          jsonb_build_object('note_id', p_note_id, 'owner_id', v_note.user_id, 'had_image', v_note.image_url IS NOT NULL,
                             'via', 'admin_delete_note'));

  RETURN jsonb_build_object('deleted', true, 'image_url', v_note.image_url);
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_admin_event(p_action text, p_details jsonb DEFAULT '{}'::jsonb, p_target uuid DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: not_admin' USING ERRCODE = '42501';
  END IF;
  -- Only events that are inherently client-driven. Every state-changing admin action writes its own entry inside its
  -- own function instead.
  IF p_action IS NULL OR p_action NOT IN ('admin_login', 'bulk_upload_flashcards', 'bulk_upload_topics', 'create_discipline') THEN
    RAISE EXCEPTION 'Unknown admin event: %', COALESCE(p_action, 'NULL');
  END IF;
  IF length(COALESCE(p_details, '{}'::jsonb)::text) > 8192 THEN
    RAISE EXCEPTION 'Event details too large';
  END IF;
  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES (p_action, auth.uid(), p_target, COALESCE(p_details, '{}'::jsonb) || jsonb_build_object('via', 'log_admin_event'));
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_educator_application(p_request_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_caller_role text;
  v_req         access_requests%ROWTYPE;
  v_result      text;
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

    v_result := 'role_granted';
  ELSE
    v_result := 'approved_pending_signup';
  END IF;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('approve_educator_application', auth.uid(), v_req.requester_user_id,
          jsonb_build_object('access_request_id', p_request_id, 'result', v_result, 'via', 'approve_educator_application'));

  RETURN v_result;
END;
$function$;

-- ---------------------------------------------------------------------------
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

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('reject_educator_application', auth.uid(), v_req.requester_user_id,
          jsonb_build_object('access_request_id', p_request_id, 'via', 'reject_educator_application'));
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_user_data(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_denial  text;
  v_name    text;
  v_email   text;
  v_role    text;
  v_notes   integer;
  v_cards   integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only super_admin can delete user data';
  END IF;

  -- New: never yourself, never an admin / super admin account (demote first with admin_change_role).
  v_denial := public.admin_user_action_denial(auth.uid(), p_user_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  SELECT full_name, email, role INTO v_name, v_email, v_role FROM profiles WHERE id = p_user_id;
  SELECT count(*) INTO v_notes FROM notes WHERE user_id = p_user_id;
  SELECT count(*) INTO v_cards FROM flashcards WHERE user_id = p_user_id;

  -- Audit FIRST, while the profile still exists (the foreign key nulls target_user_id afterwards, as before).
  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('delete_user', auth.uid(), p_user_id,
          jsonb_build_object('deleted_user_name', v_name, 'deleted_user_email', v_email, 'deleted_user_role', v_role,
                             'deleted_notes_count', v_notes, 'deleted_flashcards_count', v_cards,
                             'total_content_deleted', v_notes + v_cards,
                             'auth_deletion_status', 'manual_required', 'via', 'admin_delete_user_data'));

  DELETE FROM study_group_members WHERE user_id = p_user_id;
  DELETE FROM profile_courses    WHERE user_id = p_user_id;
  DELETE FROM reviews            WHERE user_id = p_user_id;
  DELETE FROM flashcards         WHERE user_id = p_user_id;
  DELETE FROM flashcard_decks    WHERE user_id = p_user_id;
  DELETE FROM notes              WHERE user_id = p_user_id;
  DELETE FROM profiles           WHERE id      = p_user_id;
END;
$function$;

-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_change_role(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_delete_note(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_admin_event(text, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_change_role(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_note(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_admin_event(text, jsonb, uuid) TO authenticated;
-- The three redefined functions keep their existing grants (CREATE OR REPLACE does not change them).
