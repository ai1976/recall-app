-- [FUNCTIONS] Batch membership: bulk add students, bulk approve/reject requests, audit + notification (Sprint 8.8.5b5, D-49)
-- Description: Deferred bug #5. The real pain (founder, 30/09/2026): adding many students to a batch means using the Users tab's
--   "Add to batch..." picker one student at a time. Pending-request approval (join by invite link) is also one at a time and has
--   never been used (0 pending, 0 audit entries, 0 notifications - 00 diagnostic). Decisions: bulk add NOW; bulk approve AND
--   bulk reject; students are notified when they are added / approved; rejection is silent (assumption - confirm).
--   New:
--     admin_bulk_add_to_batch(p_group_id, p_user_ids[])            admin; max 500 ids; adds ENROLLED, non-suspended STUDENTS as active
--                                                                  members; everyone else is skipped WITH a reason (nothing silent);
--                                                                  members already active are left untouched (joined_at preserved)
--     admin_bulk_resolve_batch_requests(p_action, p_membership_ids[])  'approve' | 'reject'; explicit ids only (a request that arrives
--                                                                  while the admin is looking is never swept in); archived batches and
--                                                                  already-resolved requests are skipped and counted
--     admin_batch_action_denial(actor, group)                      ONE place for "may this admin act on this batch" (not_admin /
--                                                                  batch_not_found / not_a_batch / batch_archived) - future B2B
--                                                                  institution scoping is a single-function change
--   Every bulk call writes ONE audit entry (bulk_add_to_batch / bulk_approve_batch_requests / bulk_reject_batch_requests) in the same
--   transaction, only when something actually changed. Added/approved students get a notification (batch_added / batch_approved).
--   Changed (same signatures, behaviour fixed):
--     approve_batch_join_request   now also writes its audit entry (approve_batch_join_request) and notifies the student
--     reject_batch_join_request    now also writes its audit entry (reject_batch_join_request); no notification
--     enroll_user_in_batch_group   now audits (add_to_batch) and notifies ONLY when membership newly becomes active; an already-active
--                                  member is no longer re-stamped with a new joined_at
--   All SECURITY DEFINER, unquoted search_path (public, extensions), executable by signed-in users only; each re-checks the caller is
--   an admin. The helper is internal (no client role can execute it).
-- Rollback: 03. Test: 02.

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_batch_action_denial(p_actor uuid, p_group_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_role     text;
  v_is_batch boolean;
  v_archived timestamptz;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = p_actor;
  IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') THEN
    RETURN 'not_admin';
  END IF;
  SELECT is_batch_group, archived_at INTO v_is_batch, v_archived FROM public.study_groups WHERE id = p_group_id;
  IF NOT FOUND THEN
    RETURN 'batch_not_found';
  END IF;
  IF v_is_batch IS NOT TRUE THEN
    RETURN 'not_a_batch';
  END IF;
  IF v_archived IS NOT NULL THEN
    RETURN 'batch_archived';
  END IF;
  -- FUTURE (B2B): institution scoping goes here (an 'admin' may only manage batches of their own institution; a
  -- 'super_admin' stays global). Every batch action inherits it automatically.
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_batch_action_denial(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_bulk_add_to_batch(p_group_id uuid, p_user_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor      uuid := auth.uid();
  v_denial     text;
  v_name       text;
  v_archived   timestamptz;
  v_requested  integer;
  v_not_found  integer;
  v_not_student integer;
  v_not_enrolled integer;
  v_suspended  integer;
  v_eligible   integer;
  v_added      integer;
  v_added_ids  uuid[];
BEGIN
  IF p_user_ids IS NULL OR cardinality(p_user_ids) = 0 THEN
    RAISE EXCEPTION 'Select at least one student';
  END IF;
  IF cardinality(p_user_ids) > 500 THEN
    RAISE EXCEPTION 'Too many students in one call (max 500)';
  END IF;

  v_denial := public.admin_batch_action_denial(v_actor, p_group_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  -- Lock the batch row (same convention as the single-student functions) and re-check it under the lock.
  SELECT name, archived_at INTO v_name, v_archived FROM public.study_groups WHERE id = p_group_id FOR UPDATE;
  IF v_archived IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: batch_archived' USING ERRCODE = '42501';
  END IF;

  SELECT count(*),
         count(*) FILTER (WHERE reason = 'not_found'),
         count(*) FILTER (WHERE reason = 'not_student'),
         count(*) FILTER (WHERE reason = 'not_enrolled'),
         count(*) FILTER (WHERE reason = 'suspended'),
         count(*) FILTER (WHERE reason IS NULL)
    INTO v_requested, v_not_found, v_not_student, v_not_enrolled, v_suspended, v_eligible
    FROM (
      SELECT i.u AS id,
             CASE
               WHEN p.id IS NULL                               THEN 'not_found'
               WHEN p.role <> 'student'                        THEN 'not_student'
               WHEN p.account_type = 'self_registered'         THEN 'not_enrolled'
               WHEN COALESCE(p.status, 'active') = 'suspended' THEN 'suspended'
               ELSE NULL
             END AS reason
        FROM (SELECT DISTINCT u FROM unnest(p_user_ids) AS u) i
        LEFT JOIN public.profiles p ON p.id = i.u
    ) cls;

  WITH cls AS (
    SELECT i.u AS id,
           CASE
             WHEN p.id IS NULL                               THEN 'not_found'
             WHEN p.role <> 'student'                        THEN 'not_student'
             WHEN p.account_type = 'self_registered'         THEN 'not_enrolled'
             WHEN COALESCE(p.status, 'active') = 'suspended' THEN 'suspended'
             ELSE NULL
           END AS reason
      FROM (SELECT DISTINCT u FROM unnest(p_user_ids) AS u) i
      LEFT JOIN public.profiles p ON p.id = i.u
  ), ups AS (
    INSERT INTO public.study_group_members (group_id, user_id, role, status)
    SELECT p_group_id, c.id, 'member', 'active' FROM cls c WHERE c.reason IS NULL
    ON CONFLICT (group_id, user_id) DO UPDATE
      SET status = 'active', joined_at = NOW()
      WHERE study_group_members.status <> 'active'
    RETURNING user_id
  ), notif AS (
    INSERT INTO public.notifications (user_id, type, title, message, metadata)
    SELECT u.user_id, 'batch_added', 'You''ve been added to ' || v_name,
           'You now have access to this batch''s shared study content.',
           jsonb_build_object('group_id', p_group_id)
    FROM ups u
    RETURNING 1
  )
  SELECT count(*), COALESCE(array_agg(user_id), ARRAY[]::uuid[]) INTO v_added, v_added_ids FROM ups;

  IF v_added > 0 THEN
    INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
    VALUES ('bulk_add_to_batch', v_actor, NULL,
            jsonb_build_object('group_id', p_group_id, 'group_name', v_name, 'requested', v_requested, 'added', v_added,
                               'already_active', v_eligible - v_added,
                               'skipped', jsonb_build_object('not_found', v_not_found, 'not_student', v_not_student,
                                                             'not_enrolled', v_not_enrolled, 'suspended', v_suspended),
                               'user_ids', to_jsonb(v_added_ids[1:200]), 'via', 'admin_bulk_add_to_batch'));
  END IF;

  RETURN jsonb_build_object(
    'requested', v_requested, 'added', v_added, 'already_active', v_eligible - v_added,
    'skipped_not_found', v_not_found, 'skipped_not_student', v_not_student,
    'skipped_not_enrolled', v_not_enrolled, 'skipped_suspended', v_suspended);
END;
$function$;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_bulk_resolve_batch_requests(p_action text, p_membership_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_actor      uuid := auth.uid();
  v_requested  integer;
  v_archived   integer;
  v_processed  integer := 0;
  v_user_ids   uuid[] := ARRAY[]::uuid[];
  v_group_ids  uuid[] := ARRAY[]::uuid[];
BEGIN
  IF p_action IS NULL OR p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action: %', COALESCE(p_action, 'NULL');
  END IF;
  IF p_membership_ids IS NULL OR cardinality(p_membership_ids) = 0 THEN
    RAISE EXCEPTION 'Select at least one request';
  END IF;
  IF cardinality(p_membership_ids) > 500 THEN
    RAISE EXCEPTION 'Too many requests in one call (max 500)';
  END IF;
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: not_admin' USING ERRCODE = '42501';
  END IF;

  -- Lock every involved batch in a stable order (no deadlocks between concurrent bulk calls).
  PERFORM 1 FROM public.study_groups g
   WHERE g.id IN (SELECT m.group_id FROM public.study_group_members m WHERE m.id = ANY (p_membership_ids))
   ORDER BY g.id FOR UPDATE;

  SELECT count(DISTINCT x) INTO v_requested FROM unnest(p_membership_ids) AS x;

  -- Pending requests that sit in an archived batch: skipped, counted.
  SELECT count(*) INTO v_archived
    FROM public.study_group_members m
    JOIN public.study_groups g ON g.id = m.group_id
   WHERE m.id = ANY (p_membership_ids) AND m.status = 'requested' AND g.archived_at IS NOT NULL;

  IF p_action = 'approve' THEN
    WITH upd AS (
      UPDATE public.study_group_members m
         SET status = 'active', joined_at = NOW()
        FROM public.study_groups g
       WHERE m.id = ANY (p_membership_ids) AND m.status = 'requested'
         AND g.id = m.group_id AND g.is_batch_group = true AND g.archived_at IS NULL
      RETURNING m.user_id, g.id AS gid, g.name AS gname
    ), notif AS (
      INSERT INTO public.notifications (user_id, type, title, message, metadata)
      SELECT u.user_id, 'batch_approved', 'Your request to join ' || u.gname || ' was approved',
             'You now have access to this batch''s shared study content.',
             jsonb_build_object('group_id', u.gid)
      FROM upd u
      RETURNING 1
    )
    SELECT count(*), COALESCE(array_agg(user_id), ARRAY[]::uuid[]), COALESCE(array_agg(DISTINCT gid), ARRAY[]::uuid[])
      INTO v_processed, v_user_ids, v_group_ids FROM upd;
  ELSE
    WITH del AS (
      DELETE FROM public.study_group_members m
       USING public.study_groups g
       WHERE m.id = ANY (p_membership_ids) AND m.status = 'requested'
         AND g.id = m.group_id AND g.is_batch_group = true AND g.archived_at IS NULL
      RETURNING m.user_id, g.id AS gid
    )
    SELECT count(*), COALESCE(array_agg(user_id), ARRAY[]::uuid[]), COALESCE(array_agg(DISTINCT gid), ARRAY[]::uuid[])
      INTO v_processed, v_user_ids, v_group_ids FROM del;
  END IF;

  IF v_processed > 0 THEN
    INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
    VALUES (CASE WHEN p_action = 'approve' THEN 'bulk_approve_batch_requests' ELSE 'bulk_reject_batch_requests' END,
            v_actor, NULL,
            jsonb_build_object('requested', v_requested, 'processed', v_processed,
                               'skipped_archived', v_archived, 'skipped_resolved', v_requested - v_processed - v_archived,
                               'group_ids', to_jsonb(v_group_ids), 'user_ids', to_jsonb(v_user_ids[1:200]),
                               'via', 'admin_bulk_resolve_batch_requests'));
  END IF;

  RETURN jsonb_build_object('action', p_action, 'requested', v_requested, 'processed', v_processed,
                            'skipped_archived', v_archived, 'skipped_resolved', v_requested - v_processed - v_archived);
END;
$function$;

-- ---------------------------------------------------------------------------
-- Single-request functions: same signatures and rules as live (07 diagnostic of 30/09/2026), plus audit + notification.
CREATE OR REPLACE FUNCTION public.approve_batch_join_request(p_membership_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_group_id    uuid;
  v_user_id     uuid;
  v_name        text;
  v_archived_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT group_id, user_id INTO v_group_id, v_user_id FROM study_group_members WHERE id = p_membership_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;

  SELECT name, archived_at INTO v_name, v_archived_at FROM study_groups WHERE id = v_group_id FOR UPDATE;
  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'This batch has been archived';
  END IF;

  UPDATE study_group_members
  SET status = 'active', joined_at = NOW()
  WHERE id = p_membership_id AND status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('approve_batch_join_request', auth.uid(), v_user_id,
          jsonb_build_object('group_id', v_group_id, 'group_name', v_name, 'membership_id', p_membership_id,
                             'via', 'approve_batch_join_request'));

  INSERT INTO public.notifications (user_id, type, title, message, metadata)
  VALUES (v_user_id, 'batch_approved', 'Your request to join ' || v_name || ' was approved',
          'You now have access to this batch''s shared study content.', jsonb_build_object('group_id', v_group_id));
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
  v_user_id     uuid;
  v_name        text;
  v_archived_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT group_id, user_id INTO v_group_id, v_user_id FROM study_group_members WHERE id = p_membership_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;

  SELECT name, archived_at INTO v_name, v_archived_at FROM study_groups WHERE id = v_group_id FOR UPDATE;
  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'This batch has been archived';
  END IF;

  DELETE FROM study_group_members
  WHERE id = p_membership_id AND status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('reject_batch_join_request', auth.uid(), v_user_id,
          jsonb_build_object('group_id', v_group_id, 'group_name', v_name, 'membership_id', p_membership_id,
                             'via', 'reject_batch_join_request'));
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
  v_name        text;
  v_changed     integer;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT is_batch_group, archived_at, name INTO v_is_batch, v_archived_at, v_name
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
    SET status = 'active', joined_at = NOW()
    WHERE study_group_members.status <> 'active';
  GET DIAGNOSTICS v_changed = ROW_COUNT;

  -- Audit + notify only when membership newly became active (an already-active member is left untouched).
  IF v_changed > 0 THEN
    INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
    VALUES ('add_to_batch', auth.uid(), p_user_id,
            jsonb_build_object('group_id', p_group_id, 'group_name', v_name, 'via', 'enroll_user_in_batch_group'));

    INSERT INTO public.notifications (user_id, type, title, message, metadata)
    VALUES (p_user_id, 'batch_added', 'You''ve been added to ' || v_name,
            'You now have access to this batch''s shared study content.', jsonb_build_object('group_id', p_group_id));
  END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_bulk_add_to_batch(uuid, uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_bulk_resolve_batch_requests(text, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_bulk_add_to_batch(uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_bulk_resolve_batch_requests(text, uuid[]) TO authenticated;
-- approve / reject / enroll keep their existing grants (CREATE OR REPLACE does not change them).
