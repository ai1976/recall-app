-- Name: [FUNCTIONS] Guard admin-only writers (enroll_user_in_batch_group, notify_access_granted)
-- Description: 12's residual sweep + 13 confirmed these two SECURITY DEFINER writers take p_user_id
-- (the TARGET user) with no authorization check — any authenticated user could enroll/notify arbitrary
-- users. 14 confirmed both are called ONLY by AdminDashboard via RPC (no signup/trigger caller —
-- fn_auto_enroll_batch_group enrolls directly, doesn't delegate), so an is_admin() guard is safe.
-- Bodies verbatim from 13 + guard; search_path pinned (unquoted).

CREATE OR REPLACE FUNCTION public.enroll_user_in_batch_group(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_course_level text;
  v_institution text;
  v_group_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT course_level, institution INTO v_course_level, v_institution
  FROM profiles WHERE id = p_user_id;

  SELECT id INTO v_group_id
  FROM study_groups
  WHERE is_batch_group = true
    AND batch_course = v_course_level
    AND batch_institution = v_institution
  LIMIT 1;

  IF v_group_id IS NOT NULL THEN
    INSERT INTO study_group_members (group_id, user_id, role, status)
    VALUES (v_group_id, p_user_id, 'member', 'active')
    ON CONFLICT (group_id, user_id) DO NOTHING;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_access_granted(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    p_user_id,
    'access_granted',
    'Full access granted!',
    'You now have full access to all public study content on Recall.',
    '{}'::jsonb
  );
END;
$function$;
