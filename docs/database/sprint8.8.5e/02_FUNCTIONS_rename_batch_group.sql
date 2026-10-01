-- [FUNCTIONS] rename_batch_group (Sprint 8.8.5e, deferred #7)
-- Description: Admin / super_admin rename of a BATCH group. The browser cannot do this today (sg_update_creator is limited to
--   non-batch groups), so this is a SECURITY DEFINER function that re-checks the caller server-side.
--   Rules: caller must be admin/super_admin (admin_batch_action_denial; archived batches refused); name is trimmed and inner
--   whitespace collapsed; 1-100 chars; no-op if unchanged (no audit); duplicate = another BATCH group (archived included, so a
--   restore can never create a clash) with the same lower-cased name AND the same course AND the same institution, where
--   NULL course / NULL institution count as EQUAL to each other (IS NOT DISTINCT FROM) - unscoped batches are one bucket.
--   Concurrent renames are serialised with a transaction advisory lock. One audit entry (rename_batch_group, old + new name)
--   is written in the same transaction. Old notifications / archive snapshots keep the old name (historical record).
--   Personal (non-batch) groups are untouched: creators keep renaming them through the existing policy.
-- Self-guard: aborts if admin_audit_log has an action CHECK that would reject the new action.
-- Rollback: 04. Test: 03.

DO $g$
DECLARE d text;
BEGIN
  SELECT string_agg(pg_get_constraintdef(c.oid), ' ; ') INTO d
    FROM pg_constraint c
   WHERE c.conrelid = 'public.admin_audit_log'::regclass AND c.contype = 'c' AND pg_get_constraintdef(c.oid) ILIKE '%action%';
  IF d IS NOT NULL AND d NOT ILIKE '%rename_batch_group%' THEN
    RAISE EXCEPTION 'admin_audit_log has an action CHECK that does not allow rename_batch_group: %', d;
  END IF;
END $g$;

CREATE OR REPLACE FUNCTION public.rename_batch_group(p_group_id uuid, p_new_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor  uuid := auth.uid();
  v_denial text;
  v_new    text;
  v_old    text;
  v_course text;
  v_inst   text;
BEGIN
  v_denial := public.admin_batch_action_denial(v_actor, p_group_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  v_new := btrim(regexp_replace(COALESCE(p_new_name, ''), '\s+', ' ', 'g'));
  IF v_new = '' THEN
    RAISE EXCEPTION 'Name cannot be blank';
  END IF;
  IF char_length(v_new) > 100 THEN
    RAISE EXCEPTION 'Name is too long (max 100 characters)';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('rename_batch_group'));

  SELECT name, batch_course, batch_institution INTO v_old, v_course, v_inst
    FROM public.study_groups WHERE id = p_group_id AND is_batch_group = true AND archived_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Access denied: batch_not_found' USING ERRCODE = '42501';
  END IF;

  IF v_old = v_new THEN
    RETURN jsonb_build_object('changed', false, 'name', v_old);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.study_groups g
     WHERE g.is_batch_group = true AND g.id <> p_group_id
       AND lower(btrim(regexp_replace(g.name, '\s+', ' ', 'g'))) = lower(v_new)
       AND g.batch_course      IS NOT DISTINCT FROM v_course
       AND g.batch_institution IS NOT DISTINCT FROM v_inst
  ) THEN
    RAISE EXCEPTION 'Another batch with this course and institution already uses that name';
  END IF;

  UPDATE public.study_groups SET name = v_new, updated_at = NOW() WHERE id = p_group_id;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('rename_batch_group', v_actor, NULL,
          jsonb_build_object('group_id', p_group_id, 'old_name', v_old, 'new_name', v_new, 'via', 'rename_batch_group'));

  RETURN jsonb_build_object('changed', true, 'old_name', v_old, 'name', v_new);
END;
$function$;

REVOKE ALL ON FUNCTION public.rename_batch_group(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rename_batch_group(uuid, text) TO authenticated;
