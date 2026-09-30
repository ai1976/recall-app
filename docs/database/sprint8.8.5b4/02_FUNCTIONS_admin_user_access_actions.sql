-- [FUNCTIONS] Server-authorized admin actions: grant access, suspend, reactivate (Sprint 8.8.5b4, D-48)
-- Description: Replaces the Admin Dashboard's direct `profiles.update(...)` calls. Those were silent no-ops for a plain
--   `admin` (only super admins have an UPDATE policy on other users' profiles), yet the page still showed success,
--   wrote an audit entry and told the student "Full access granted!" (00 diagnostic, 30/09/2026).
--   Each action here:
--     * is authorised in ONE place - admin_user_action_denial() - so future B2B institution scoping (an admin may
--       only manage users of their own institution) is a single-function change, not a change to every action;
--     * refuses to act on yourself or on any admin / super admin (role changes stay in the Super Admin dashboard);
--     * is truthful: returns {changed: true|false, ...}; a no-op (already enrolled / already suspended) says so
--       instead of pretending, and writes NO audit entry and sends NO notification;
--     * writes its OWN audit entry (and, for grant, the notification) in the SAME transaction, as the definer, so the
--       history is created server-side and cannot be forged, skipped or half-written by the browser.
--   SECURITY DEFINER, unquoted search_path (public, extensions), executable by signed-in users only (each function
--   re-checks that the caller is an admin). The helper is internal: no client role can execute it.
-- Rollback: 06. Test: 03.

CREATE OR REPLACE FUNCTION public.admin_user_action_denial(p_actor uuid, p_target uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor_role  text;
  v_target_role text;
BEGIN
  -- Returns NULL when the actor may manage the target, otherwise a short machine-readable reason.
  SELECT role INTO v_actor_role FROM public.profiles WHERE id = p_actor;
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('admin', 'super_admin') THEN
    RETURN 'not_admin';
  END IF;
  IF p_target IS NULL THEN
    RETURN 'target_not_found';
  END IF;
  IF p_target = p_actor THEN
    RETURN 'cannot_act_on_self';
  END IF;
  SELECT role INTO v_target_role FROM public.profiles WHERE id = p_target;
  IF v_target_role IS NULL THEN
    RETURN 'target_not_found';
  END IF;
  IF v_target_role IN ('admin', 'super_admin') THEN
    RETURN 'cannot_act_on_admin';
  END IF;
  -- FUTURE (B2B): institution scoping goes here, e.g. an 'admin' may only manage targets whose institution matches
  -- the actor's; a 'super_admin' stays global. Every admin action below inherits it automatically.
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_user_action_denial(uuid, uuid) FROM PUBLIC, anon, authenticated;


CREATE OR REPLACE FUNCTION public.admin_grant_access(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor  uuid := auth.uid();
  v_denial text;
  v_old    text;
  v_n      integer;
BEGIN
  v_denial := public.admin_user_action_denial(v_actor, p_user_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  SELECT account_type INTO v_old FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF v_old = 'enrolled' THEN
    RETURN jsonb_build_object('changed', false, 'reason', 'already_enrolled', 'account_type', v_old);
  END IF;

  UPDATE public.profiles SET account_type = 'enrolled' WHERE id = p_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Grant access failed: expected to change 1 profile, changed %', v_n;
  END IF;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('grant_access', v_actor, p_user_id,
          jsonb_build_object('account_type_from', v_old, 'account_type_to', 'enrolled', 'via', 'admin_grant_access'));

  INSERT INTO public.notifications (user_id, type, title, message, metadata)
  VALUES (p_user_id, 'access_granted', 'Full access granted!',
          'You now have full access to all public study content on Recall.', '{}'::jsonb);

  RETURN jsonb_build_object('changed', true, 'account_type_from', v_old, 'account_type_to', 'enrolled');
END;
$function$;


CREATE OR REPLACE FUNCTION public.admin_suspend_user(p_user_id uuid, p_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor  uuid := auth.uid();
  v_denial text;
  v_old    text;
  v_n      integer;
BEGIN
  v_denial := public.admin_user_action_denial(v_actor, p_user_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  SELECT status INTO v_old FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF v_old = 'suspended' THEN
    RETURN jsonb_build_object('changed', false, 'reason', 'already_suspended', 'status', v_old);
  END IF;

  UPDATE public.profiles SET status = 'suspended' WHERE id = p_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Suspend failed: expected to change 1 profile, changed %', v_n;
  END IF;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('suspend_user', v_actor, p_user_id,
          jsonb_build_object('status_from', v_old, 'status_to', 'suspended',
                             'reason', COALESCE(NULLIF(btrim(p_reason), ''), 'Suspended by admin'),
                             'via', 'admin_suspend_user'));

  RETURN jsonb_build_object('changed', true, 'status_from', v_old, 'status_to', 'suspended');
END;
$function$;


CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor  uuid := auth.uid();
  v_denial text;
  v_old    text;
  v_n      integer;
BEGIN
  v_denial := public.admin_user_action_denial(v_actor, p_user_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  SELECT status INTO v_old FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF v_old IS DISTINCT FROM 'suspended' THEN
    RETURN jsonb_build_object('changed', false, 'reason', 'not_suspended', 'status', v_old);
  END IF;

  UPDATE public.profiles SET status = 'active' WHERE id = p_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Reactivate failed: expected to change 1 profile, changed %', v_n;
  END IF;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('reactivate_user', v_actor, p_user_id,
          jsonb_build_object('status_from', v_old, 'status_to', 'active', 'via', 'admin_reactivate_user'));

  RETURN jsonb_build_object('changed', true, 'status_from', v_old, 'status_to', 'active');
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_grant_access(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_suspend_user(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_reactivate_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_grant_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_suspend_user(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_user(uuid) TO authenticated;
