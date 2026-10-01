-- [FUNCTIONS] Professor <-> batch assignment - STEP 2 of 4: admin functions (Sprint 8.8.5d). ADDITIVE.
-- Description: Four SECURITY DEFINER functions, all with a fixed search_path (unquoted: public, extensions), EXECUTE for signed-in users
--   only (PUBLIC/anon revoked), each re-checking the caller server-side through batch_group_access_denial / an inline active-admin check:
--     assign_professor_to_batch(p_group_id, p_professor_id)    'manage' (active admin/super_admin; batch must be a real, non-archived
--                                                              batch); target must CURRENTLY be an active (not suspended) professor;
--                                                              idempotent; writes the audit entry in the SAME transaction ONLY when a row
--                                                              was actually created (assign_professor_to_batch)
--     unassign_professor_from_batch(p_group_id, p_professor_id) 'admin_view' (archived batches allowed so stale rows can be cleaned);
--                                                              idempotent; audit (unassign_professor_from_batch) only when a row was removed
--     get_batch_group_professors(p_group_id)                   'admin_view'; lists assigned professors incl. whether each is still an
--                                                              active professor (a demoted/suspended one is flagged, not hidden)
--     get_assignable_professors()                              active admin/super_admin only; active professors
--   The browser never writes audit rows or the table.
-- Self-guard: aborts if admin_audit_log has an action CHECK that would reject the new action names.
-- Rollback: 08. Test: 07.

DO $g$
DECLARE d text;
BEGIN
  SELECT string_agg(pg_get_constraintdef(c.oid), ' ; ') INTO d
    FROM pg_constraint c
   WHERE c.conrelid = 'public.admin_audit_log'::regclass AND c.contype = 'c' AND pg_get_constraintdef(c.oid) ILIKE '%action%';
  IF d IS NOT NULL AND (d NOT ILIKE '%assign_professor_to_batch%' OR d NOT ILIKE '%unassign_professor_from_batch%' OR d NOT ILIKE '%backfill_professor_assignments%') THEN
    RAISE EXCEPTION 'admin_audit_log has an action CHECK that does not allow the 8.8.5d actions: %', d;
  END IF;
  IF to_regprocedure('public.batch_group_access_denial(uuid,uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Run 03 first: batch_group_access_denial is missing';
  END IF;
END $g$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_professor_to_batch(p_group_id uuid, p_professor_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor    uuid := auth.uid();
  v_denial   text;
  v_name     text;
  v_archived timestamptz;
  v_pname    text;
  v_prole    text;
  v_pstatus  text;
  v_n        integer;
BEGIN
  v_denial := public.batch_group_access_denial(v_actor, p_group_id, 'manage');
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  -- Lock the batch row and re-check it under the lock (an archive racing this call must win).
  SELECT name, archived_at INTO v_name, v_archived FROM public.study_groups WHERE id = p_group_id FOR UPDATE;
  IF v_archived IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: batch_archived' USING ERRCODE = '42501';
  END IF;

  SELECT full_name, role, status INTO v_pname, v_prole, v_pstatus FROM public.profiles WHERE id = p_professor_id;
  IF NOT FOUND OR v_prole <> 'professor' OR COALESCE(v_pstatus, 'active') = 'suspended' THEN
    RAISE EXCEPTION 'Target must be an active professor';
  END IF;

  INSERT INTO public.batch_group_professors (group_id, professor_id, assigned_by, assignment_source)
  VALUES (p_group_id, p_professor_id, v_actor, 'admin')
  ON CONFLICT (group_id, professor_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  IF v_n > 0 THEN
    INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
    VALUES ('assign_professor_to_batch', v_actor, p_professor_id,
            jsonb_build_object('group_id', p_group_id, 'group_name', v_name, 'professor_name', v_pname, 'via', 'assign_professor_to_batch'));
  END IF;

  RETURN jsonb_build_object('changed', v_n > 0, 'group_id', p_group_id, 'professor_id', p_professor_id);
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unassign_professor_from_batch(p_group_id uuid, p_professor_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor  uuid := auth.uid();
  v_denial text;
  v_name   text;
  v_pname  text;
  v_n      integer;
BEGIN
  v_denial := public.batch_group_access_denial(v_actor, p_group_id, 'admin_view');
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  SELECT name INTO v_name FROM public.study_groups WHERE id = p_group_id FOR UPDATE;
  SELECT full_name INTO v_pname FROM public.profiles WHERE id = p_professor_id;

  DELETE FROM public.batch_group_professors WHERE group_id = p_group_id AND professor_id = p_professor_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  IF v_n > 0 THEN
    INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
    VALUES ('unassign_professor_from_batch', v_actor, p_professor_id,
            jsonb_build_object('group_id', p_group_id, 'group_name', v_name, 'professor_name', v_pname, 'via', 'unassign_professor_from_batch'));
  END IF;

  RETURN jsonb_build_object('changed', v_n > 0, 'group_id', p_group_id, 'professor_id', p_professor_id);
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_batch_group_professors(p_group_id uuid)
 RETURNS TABLE (professor_id uuid, full_name text, course_level text, assigned_at timestamptz, assigned_by_name text,
                assignment_source text, is_active_professor boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_denial text;
BEGIN
  v_denial := public.batch_group_access_denial(auth.uid(), p_group_id, 'admin_view');
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT bgp.professor_id, pr.full_name, pr.course_level, bgp.assigned_at, ab.full_name, bgp.assignment_source,
         (pr.role = 'professor' AND COALESCE(pr.status, 'active') <> 'suspended')
    FROM public.batch_group_professors bgp
    JOIN public.profiles pr ON pr.id = bgp.professor_id
    LEFT JOIN public.profiles ab ON ab.id = bgp.assigned_by
   WHERE bgp.group_id = p_group_id
   ORDER BY pr.full_name;
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_assignable_professors()
 RETURNS TABLE (professor_id uuid, full_name text, course_level text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles c
                  WHERE c.id = auth.uid() AND c.role IN ('admin', 'super_admin') AND COALESCE(c.status, 'active') <> 'suspended') THEN
    RAISE EXCEPTION 'Access denied: not_authorized' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT p.id, p.full_name, p.course_level
    FROM public.profiles p
   WHERE p.role = 'professor' AND COALESCE(p.status, 'active') <> 'suspended'
   ORDER BY p.full_name;
END;
$function$;

-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.assign_professor_to_batch(uuid, uuid)     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unassign_professor_from_batch(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_batch_group_professors(uuid)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_assignable_professors()               FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_professor_to_batch(uuid, uuid)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.unassign_professor_from_batch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_batch_group_professors(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_assignable_professors()               TO authenticated;
