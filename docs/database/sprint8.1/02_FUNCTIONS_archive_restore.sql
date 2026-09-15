-- Name: [FUNCTIONS] Sprint 8.1 — archive_batch_group, restore_batch_group, get_batch_group_archive
-- Description: The three new RPCs for batch group archiving. archive_batch_group
-- and restore_batch_group are the only ways to set/clear study_groups.archived_at
-- (RLS narrowed in 01_SCHEMA to block direct client writes to that column).
-- get_batch_group_archive reads the frozen snapshot for an archived batch, gated
-- identically to the existing live get_batch_group_member_stats. Run after
-- 01_SCHEMA, before 03_FUNCTIONS.

-- ============================================================================
-- archive_batch_group(p_group_id) — admin-only. Locks the batch row, captures
-- a snapshot (group metadata + get_batch_group_member_stats rows, active
-- members only — identical to the live report), marks archived, and closes
-- outstanding requested/invited rows to 'closed'. All in one transaction: if
-- the snapshot capture fails, the whole call rolls back (default plpgsql
-- exception behavior — no explicit handling needed). Idempotent: calling on
-- an already-archived batch returns its existing state, no timestamp or
-- snapshot replacement.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.archive_batch_group(p_group_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_batch    boolean;
  v_archived_at timestamptz;
  v_new_archived_at timestamptz;
  v_report      jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  -- Lock the batch row first — same convention every enrollment path in
  -- 03_FUNCTIONS follows, so a concurrent join/approve/direct-add either
  -- completes before this lock is acquired (and stays valid) or blocks until
  -- this transaction commits, at which point it sees archived_at set and
  -- refuses.
  SELECT is_batch_group, archived_at INTO v_is_batch, v_archived_at
  FROM study_groups WHERE id = p_group_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group not found';
  END IF;
  IF NOT v_is_batch THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;

  IF v_archived_at IS NOT NULL THEN
    RETURN jsonb_build_object('group_id', p_group_id, 'archived_at', v_archived_at, 'already_archived', true);
  END IF;

  -- clock_timestamp(), not NOW(): NOW() returns the enclosing transaction's
  -- start time, constant for the whole transaction — a restore-then-
  -- re-archive done inside one transaction (e.g. 04_TEST's BEGIN...ROLLBACK)
  -- would compute the identical timestamp twice and violate
  -- batch_group_archives' UNIQUE(group_id, archived_at). clock_timestamp()
  -- advances on every statement regardless of transaction boundaries, and is
  -- the more correct choice anyway for an audit marker of the actual moment
  -- captured.
  v_new_archived_at := clock_timestamp();

  SELECT jsonb_build_object(
    'group', jsonb_build_object(
      'name', sg.name,
      'description', sg.description,
      'batch_course', sg.batch_course,
      'batch_institution', sg.batch_institution
    ),
    'member_count', (
      SELECT COUNT(*) FROM study_group_members WHERE group_id = p_group_id AND status = 'active'
    ),
    'members', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', s.user_id,
        'full_name', s.full_name,
        'reviews_this_week', s.reviews_this_week,
        'streak_days', s.streak_days,
        'study_time_this_week_seconds', s.study_time_this_week_seconds,
        'last_active_date', s.last_active_date
      ))
      FROM get_batch_group_member_stats(p_group_id) s
    ), '[]'::jsonb)
  ) INTO v_report
  FROM study_groups sg WHERE sg.id = p_group_id;

  INSERT INTO batch_group_archives (group_id, archived_at, archived_by, report)
  VALUES (p_group_id, v_new_archived_at, auth.uid(), v_report);

  UPDATE study_groups
  SET archived_at = v_new_archived_at, archived_by = auth.uid()
  WHERE id = p_group_id;

  UPDATE study_group_members
  SET status = 'closed', closed_at = v_new_archived_at, closed_reason = 'batch_archived'
  WHERE group_id = p_group_id AND status IN ('requested', 'invited');

  RETURN jsonb_build_object('group_id', p_group_id, 'archived_at', v_new_archived_at, 'already_archived', false);
END;
$function$;

-- ============================================================================
-- restore_batch_group(p_group_id) — admin-only. Same row-lock convention.
-- Reopens the batch (clears archived_at/archived_by) and retains approved
-- (active) memberships untouched. Does not revive 'closed' requests/invites —
-- a student must explicitly re-request via the invite link, which
-- join_group_by_token (03_FUNCTIONS) handles by reactivating the closed row
-- rather than erroring on the unique constraint. Idempotent on an already-
-- active batch.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.restore_batch_group(p_group_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
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

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group not found';
  END IF;
  IF NOT v_is_batch THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;

  IF v_archived_at IS NULL THEN
    RETURN jsonb_build_object('group_id', p_group_id, 'archived_at', NULL, 'already_active', true);
  END IF;

  UPDATE study_groups SET archived_at = NULL, archived_by = NULL WHERE id = p_group_id;

  RETURN jsonb_build_object('group_id', p_group_id, 'archived_at', NULL, 'already_active', false);
END;
$function$;

-- ============================================================================
-- get_batch_group_archive(p_group_id) — reads the frozen snapshot for the
-- batch's CURRENT archive event (matched by exact archived_at timestamp, so a
-- restore-then-re-archive cycle always resolves to the latest snapshot, never
-- a stale earlier one). Gated identically to get_batch_group_member_stats:
-- caller must be professor/admin/super_admin — "same authorized viewers",
-- nothing broadened.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_batch_group_archive(p_group_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role        text;
  v_is_batch    boolean;
  v_archived_at timestamptz;
  v_report      jsonb;
BEGIN
  SELECT role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('professor', 'admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT is_batch_group, archived_at INTO v_is_batch, v_archived_at
  FROM study_groups WHERE id = p_group_id;

  IF NOT FOUND OR NOT v_is_batch THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;
  IF v_archived_at IS NULL THEN
    RAISE EXCEPTION 'Batch is not archived';
  END IF;

  SELECT report INTO v_report
  FROM batch_group_archives
  WHERE group_id = p_group_id AND archived_at = v_archived_at;

  IF v_report IS NULL THEN
    RAISE EXCEPTION 'Archive snapshot not found';
  END IF;

  RETURN jsonb_build_object('archived_at', v_archived_at, 'report', v_report);
END;
$function$;

-- ============================================================================
-- Explicit grants, following the project's stated convention (DATABASE_SCHEMA.md
-- sprint6.3 note: GRANT EXECUTE TO authenticated, REVOKE from PUBLIC/anon).
-- These three are new and admin-facing (or admin/professor-facing) only — no
-- anon access needed, unlike join_group_by_token/get_group_preview.
-- ============================================================================
REVOKE ALL ON FUNCTION public.archive_batch_group(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.archive_batch_group(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.archive_batch_group(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.restore_batch_group(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.restore_batch_group(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.restore_batch_group(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_batch_group_archive(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_batch_group_archive(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_batch_group_archive(uuid) TO authenticated;
