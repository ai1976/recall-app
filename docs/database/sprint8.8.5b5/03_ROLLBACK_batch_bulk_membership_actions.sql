-- [FUNCTIONS] ROLLBACK for 01 (Sprint 8.8.5b5): remove the bulk functions, restore the single-request functions
-- Description: approve_batch_join_request / reject_batch_join_request are restored to the LIVE bodies found by the 00 diagnostic on
--   30/09/2026 (Block 1). enroll_user_in_batch_group is restored to the Sprint 8.1 body (docs/database/sprint8.1/03) - its live body
--   was not re-read in 00, so compare with pg_get_functiondef before relying on this section. Run only if the new Batch Groups page
--   is reverted, since it calls the bulk functions.

DROP FUNCTION IF EXISTS public.admin_bulk_add_to_batch(uuid, uuid[]);
DROP FUNCTION IF EXISTS public.admin_bulk_resolve_batch_requests(text, uuid[]);
DROP FUNCTION IF EXISTS public.admin_batch_action_denial(uuid, uuid);

CREATE OR REPLACE FUNCTION public.approve_batch_join_request(p_membership_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_group_id    uuid;
  v_archived_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT group_id INTO v_group_id FROM study_group_members WHERE id = p_membership_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;

  SELECT archived_at INTO v_archived_at FROM study_groups WHERE id = v_group_id FOR UPDATE;
  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'This batch has been archived';
  END IF;

  UPDATE study_group_members
  SET status = 'active', joined_at = NOW()
  WHERE id = p_membership_id AND status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_batch_join_request(p_membership_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_group_id    uuid;
  v_archived_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT group_id INTO v_group_id FROM study_group_members WHERE id = p_membership_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;

  SELECT archived_at INTO v_archived_at FROM study_groups WHERE id = v_group_id FOR UPDATE;
  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'This batch has been archived';
  END IF;

  DELETE FROM study_group_members
  WHERE id = p_membership_id AND status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.enroll_user_in_batch_group(p_user_id uuid, p_group_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_is_batch    boolean;
  v_archived_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT is_batch_group, archived_at INTO v_is_batch, v_archived_at
  FROM study_groups WHERE id = p_group_id FOR UPDATE;

  IF NOT FOUND OR NOT v_is_batch THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;
  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'This batch has been archived';
  END IF;

  INSERT INTO study_group_members (group_id, user_id, role, status)
  VALUES (p_group_id, p_user_id, 'member', 'active')
  ON CONFLICT (group_id, user_id) DO UPDATE
    SET status = 'active', joined_at = NOW();
END;
$function$;
