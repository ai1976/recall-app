-- Name: [FUNCTIONS] Sprint 8.1 — archived-state guards on existing batch enrollment paths
-- Description: CREATE OR REPLACE for every existing function that can create,
-- change, or display batch membership/group state, adding an archived_at
-- check under the same batch-row locking convention as archive_batch_group/
-- restore_batch_group. Each function below is reproduced from its exact live
-- body (confirmed via pg_get_functiondef during Sprint 8.1 pre-flight, NOT
-- from any previously-committed migration file — several had already
-- drifted). Diffs are called out per function; everything else is
-- byte-identical to the live version. Run after 01_SCHEMA and 02_FUNCTIONS.

-- ============================================================================
-- join_group_by_token — diff: (1) FOR UPDATE lock on the resolved group row,
-- (2) archived_at check raising 'This batch has ended' before any status
-- change (covers both the invited->active flip and the new-request insert;
-- archived_at is only ever non-null on batch groups, so this is a no-op for
-- ordinary groups), (3) the 'requested' insert's ON CONFLICT now reactivates
-- a 'closed' row (post-restore explicit re-request) instead of always doing
-- nothing, while still doing nothing for active/requested/invited conflicts
-- (unchanged idempotent behavior for those).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.join_group_by_token(p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_group_id    UUID;
  v_group_type  TEXT;
  v_archived_at TIMESTAMPTZ;
  v_caller_role TEXT;
  v_status      TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT id, group_type, archived_at INTO v_group_id, v_group_type, v_archived_at
  FROM study_groups
  WHERE invite_token = p_token
  FOR UPDATE;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite link';
  END IF;

  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'This batch has ended';
  END IF;

  IF v_group_type = 'batch' THEN
    SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  END IF;

  IF v_group_type = 'batch' AND v_caller_role = 'student' THEN
    -- Flip a pre-existing staff-initiated 'invited' row straight to active —
    -- a direct invite from staff is a stronger vetting signal than a student
    -- self-request, so it doesn't need to re-queue behind approval.
    UPDATE study_group_members
    SET status = 'active', joined_at = NOW()
    WHERE group_id = v_group_id AND user_id = auth.uid() AND status = 'invited';

    -- Atomic, idempotent self-request: does nothing if a row already exists
    -- in active/requested/invited state (matches prior behavior); reactivates
    -- a 'closed' row (left behind by a prior archive) into a fresh request,
    -- preserving closed_at/closed_reason as historical record.
    INSERT INTO study_group_members (group_id, user_id, role, status)
    VALUES (v_group_id, auth.uid(), 'member', 'requested')
    ON CONFLICT (group_id, user_id) DO UPDATE
      SET status = 'requested', joined_at = NOW()
      WHERE study_group_members.status = 'closed';

    SELECT status INTO v_status
    FROM study_group_members
    WHERE group_id = v_group_id AND user_id = auth.uid();

    RETURN jsonb_build_object('group_id', v_group_id, 'status', v_status);
  END IF;

  -- Original behavior: byte-identical for non-batch groups and for any
  -- non-student caller (professor/admin/super_admin) joining any group.
  INSERT INTO study_group_members (group_id, user_id, role, status)
  VALUES (v_group_id, auth.uid(), 'member', 'active')
  ON CONFLICT (group_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('group_id', v_group_id, 'status', 'active');
END;
$function$;

-- ============================================================================
-- get_group_preview — diff: (1) returns is_batch_group + archived_at in the
-- group object, (2) when archived, the stats block returns NULL instead of
-- the live aggregate (public previews must not expose any activity data,
-- live or archived, for an ended batch) and the join CTA is disabled purely
-- by GroupJoin.jsx reading archived_at — this function does not decide UI
-- copy, only exposes the flag, matching its existing group_type-only pattern.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_group_preview(p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_group_id      UUID;
  v_archived_at   TIMESTAMPTZ;
  v_is_batch      BOOLEAN;
  v_group         JSONB;
  v_stats         JSONB;
  v_viewer_status TEXT;
BEGIN
  SELECT id, archived_at, is_batch_group INTO v_group_id, v_archived_at, v_is_batch
  FROM study_groups
  WHERE invite_token = p_token;

  IF v_group_id IS NULL THEN
    RETURN jsonb_build_object('group', NULL, 'stats', NULL);
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT status INTO v_viewer_status
    FROM study_group_members
    WHERE group_id = v_group_id AND user_id = auth.uid();
  END IF;

  SELECT jsonb_build_object(
    'id',           sg.id,
    'name',         sg.name,
    'description',  sg.description,
    'member_count', (
      SELECT COUNT(*) FROM study_group_members
      WHERE group_id = sg.id AND status = 'active'
    ),
    'group_type',        sg.group_type,
    'is_batch_group',    sg.is_batch_group,
    'batch_course',      sg.batch_course,
    'batch_institution', sg.batch_institution,
    'viewer_status',     v_viewer_status,
    'archived_at',       sg.archived_at
  ) INTO v_group
  FROM study_groups sg
  WHERE sg.id = v_group_id;

  IF v_is_batch AND v_archived_at IS NOT NULL THEN
    RETURN jsonb_build_object('group', v_group, 'stats', NULL);
  END IF;

  -- stats block unchanged from the live version
  SELECT jsonb_build_object(
    'avg_streak',           0,
    'total_weekly_reviews', COALESCE(SUM(weekly.cnt), 0),
    'top_badge_name',       (
      SELECT bd.name
      FROM user_badges ub
      JOIN badge_definitions bd ON bd.id = ub.badge_id
      WHERE ub.user_id IN (
        SELECT user_id FROM study_group_members
        WHERE group_id = v_group_id AND status = 'active'
      )
      GROUP BY bd.name
      ORDER BY COUNT(*) DESC
      LIMIT 1
    )
  ) INTO v_stats
  FROM study_group_members sgm
  LEFT JOIN LATERAL (
    SELECT COUNT(*) AS cnt
    FROM reviews r
    WHERE r.user_id = sgm.user_id
      AND r.created_at >= NOW() - INTERVAL '7 days'
  ) weekly ON true
  WHERE sgm.group_id = v_group_id
    AND sgm.status = 'active';

  RETURN jsonb_build_object('group', v_group, 'stats', v_stats);
END;
$function$;

-- ============================================================================
-- enroll_user_in_batch_group (admin direct-add) — diff: FOR UPDATE lock +
-- archived_at check, same convention.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.enroll_user_in_batch_group(p_user_id uuid, p_group_id uuid)
 RETURNS void
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

-- ============================================================================
-- approve_batch_join_request — diff: resolves the request's group_id first,
-- locks that study_groups row (same convention), refuses if archived.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.approve_batch_join_request(p_membership_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
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

-- ============================================================================
-- reject_batch_join_request — same lock convention as approve, for symmetry.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reject_batch_join_request(p_membership_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
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

-- ============================================================================
-- leave_group — diff: a batch group is never cascade-deleted when its last
-- active member leaves (previously: any group, batch or not, was deleted at
-- member_count = 1). Batch group lifecycle is now governed only by explicit
-- admin archive/restore. Ordinary (non-batch) group behavior is unchanged —
-- same branch, same cascade-delete.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.leave_group(p_group_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_admin_count INTEGER;
  v_member_count INTEGER;
  v_is_batch BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get user's role (only active members can leave)
  SELECT role INTO v_user_role
  FROM study_group_members
  WHERE group_id = p_group_id AND user_id = v_user_id AND status = 'active';

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'You are not an active member of this group';
  END IF;

  SELECT is_batch_group INTO v_is_batch FROM study_groups WHERE id = p_group_id;

  -- Count ACTIVE members only (not invited)
  SELECT COUNT(*) INTO v_member_count
  FROM study_group_members
  WHERE group_id = p_group_id AND status = 'active';

  -- If last active member of an ordinary group, delete the entire group
  -- (cascades to members + shares). Batch groups are exempt — only an
  -- explicit admin archive/restore governs their lifecycle (Sprint 8.1).
  IF v_member_count = 1 AND NOT v_is_batch THEN
    DELETE FROM study_groups WHERE id = p_group_id;
    RETURN;
  END IF;

  -- If admin leaving, check active admin count
  IF v_user_role = 'admin' THEN
    SELECT COUNT(*) INTO v_admin_count
    FROM study_group_members
    WHERE group_id = p_group_id AND role = 'admin' AND status = 'active';

    -- If last active admin, promote oldest active member to admin
    IF v_admin_count = 1 THEN
      UPDATE study_group_members
      SET role = 'admin'
      WHERE id = (
        SELECT id FROM study_group_members
        WHERE group_id = p_group_id
          AND user_id != v_user_id
          AND status = 'active'
        ORDER BY joined_at ASC
        LIMIT 1
      );
    END IF;
  END IF;

  -- Remove user
  DELETE FROM study_group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;
END;
$function$;

-- ============================================================================
-- get_admin_batch_groups (AdminDashboard batch tab) — diff: adds archived_at
-- to the return columns (no WHERE change — still returns both active and
-- archived batch groups; AdminDashboard.jsx does the Active/Archived split
-- client-side, cheap at this dataset size). Ordered active-first.
--
-- Adding a return column changes the function's OUT-parameter row type, which
-- CREATE OR REPLACE cannot do in place (42P13) — an explicit DROP is required
-- first. The DROP also clears any grants Postgres attached to the old
-- function, so they're restored explicitly below to match what pre-flight
-- confirmed was live before this change (PUBLIC — which already covers
-- anon/authenticated — plus postgres/service_role as always).
-- ============================================================================
DROP FUNCTION IF EXISTS public.get_admin_batch_groups();

CREATE OR REPLACE FUNCTION public.get_admin_batch_groups()
 RETURNS TABLE(id uuid, name text, description text, batch_course text, batch_institution text, created_at timestamp with time zone, member_count bigint, is_batch_group boolean, creator_name text, created_by uuid, invite_token uuid, archived_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    sg.id,
    sg.name,
    sg.description,
    sg.batch_course,
    sg.batch_institution,
    sg.created_at,
    COUNT(sgm.user_id)::bigint AS member_count,
    true::boolean AS is_batch_group,
    p.full_name AS creator_name,
    sg.created_by,
    sg.invite_token,
    sg.archived_at
  FROM study_groups sg
  LEFT JOIN study_group_members sgm
    ON sgm.group_id = sg.id AND sgm.status = 'active'
  LEFT JOIN profiles p ON p.id = sg.created_by
  WHERE sg.is_batch_group = true
  GROUP BY sg.id, sg.name, sg.description, sg.batch_course, sg.batch_institution, sg.created_at, p.full_name, sg.created_by, sg.invite_token, sg.archived_at
  ORDER BY (sg.archived_at IS NOT NULL), sg.batch_course;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_admin_batch_groups() TO PUBLIC;

-- ============================================================================
-- get_my_batch_groups (MyGroups.jsx monitoring list, professor/admin) — diff:
-- excludes archived batches from both branches. This is a monitoring surface,
-- not the admin management view (that's get_admin_batch_groups, which keeps
-- both and filters client-side) — "remove archived batches from ongoing
-- monitoring lists" applies here.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_my_batch_groups()
 RETURNS TABLE(id uuid, name text, description text, created_by uuid, is_batch_group boolean, batch_course text, batch_institution text, member_count bigint, creator_name text, user_role text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role FROM profiles WHERE profiles.id = auth.uid();

  IF v_role IN ('admin', 'super_admin') THEN
    RETURN QUERY
      SELECT sg.id, sg.name, sg.description, sg.created_by, sg.is_batch_group,
        sg.batch_course, sg.batch_institution,
        COUNT(sgm.user_id)::bigint AS member_count,
        p.full_name AS creator_name,
        'admin'::text AS user_role
      FROM study_groups sg
      LEFT JOIN study_group_members sgm ON sgm.group_id = sg.id AND sgm.status = 'active'
      LEFT JOIN profiles p ON p.id = sg.created_by
      WHERE sg.is_batch_group = true AND sg.archived_at IS NULL
      GROUP BY sg.id, sg.name, sg.description, sg.created_by, sg.is_batch_group,
               sg.batch_course, sg.batch_institution, p.full_name;

  ELSIF v_role = 'professor' THEN
    RETURN QUERY
      SELECT sg.id, sg.name, sg.description, sg.created_by, sg.is_batch_group,
        sg.batch_course, sg.batch_institution,
        COUNT(sgm.user_id)::bigint AS member_count,
        p.full_name AS creator_name,
        'member'::text AS user_role
      FROM study_groups sg
      LEFT JOIN study_group_members sgm ON sgm.group_id = sg.id AND sgm.status = 'active'
      LEFT JOIN profiles p ON p.id = sg.created_by
      WHERE sg.is_batch_group = true AND sg.archived_at IS NULL
      GROUP BY sg.id, sg.name, sg.description, sg.created_by, sg.is_batch_group,
               sg.batch_course, sg.batch_institution, p.full_name;
  END IF;
END;
$function$;

-- ============================================================================
-- get_group_detail (GroupDetail.jsx, all group types) — diff: adds
-- sg.archived_at to the returned group object only. Members/pending/shared-
-- content blocks are untouched (shared-content access is explicitly out of
-- scope for this sprint). GroupDetail.jsx uses group.archived_at to decide
-- whether to call get_batch_group_member_stats (live) or
-- get_batch_group_archive (snapshot).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_group_detail(p_group_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_user_id UUID;
  v_role    TEXT;
  v_group   JSON;
  v_members JSON;
  v_pending JSON;
  v_notes   JSON;
  v_decks   JSON;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get caller's role once
  SELECT role INTO v_role FROM profiles WHERE id = v_user_id;

  -- Access check:
  -- Allow if (1) active member of the group, OR
  --          (2) professor/admin/super_admin viewing a batch group
  IF NOT EXISTS (
    SELECT 1 FROM study_group_members
    WHERE group_id = p_group_id AND user_id = v_user_id AND status = 'active'
  ) THEN
    IF NOT (
      v_role IN ('professor', 'admin', 'super_admin')
      AND EXISTS (SELECT 1 FROM study_groups WHERE id = p_group_id AND is_batch_group = true)
    ) THEN
      RAISE EXCEPTION 'Access denied';
    END IF;
  END IF;

  SELECT row_to_json(t) INTO v_group
  FROM (
    SELECT
      sg.id,
      sg.name,
      sg.description,
      sg.created_by,
      sg.created_at,
      sg.updated_at,
      sg.is_batch_group,
      sg.invite_token,
      sg.archived_at,
      p.full_name AS creator_name
    FROM study_groups sg
    JOIN profiles p ON p.id = sg.created_by
    WHERE sg.id = p_group_id
  ) t;
  IF v_group IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.joined_at ASC), '[]'::json) INTO v_members
  FROM (
    SELECT
      sgm.id,
      sgm.user_id,
      sgm.role,
      sgm.joined_at,
      p.full_name,
      p.role AS user_role
    FROM study_group_members sgm
    JOIN profiles p ON p.id = sgm.user_id
    WHERE sgm.group_id = p_group_id AND sgm.status = 'active'
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.invited_at DESC), '[]'::json) INTO v_pending
  FROM (
    SELECT
      sgm.id AS membership_id,
      sgm.user_id,
      p.full_name,
      p.role AS user_role,
      sgm.joined_at AS invited_at,
      inviter.full_name AS invited_by_name
    FROM study_group_members sgm
    JOIN profiles p ON p.id = sgm.user_id
    LEFT JOIN profiles inviter ON inviter.id = sgm.invited_by
    WHERE sgm.group_id = p_group_id AND sgm.status = 'invited'
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.shared_at DESC), '[]'::json) INTO v_notes
  FROM (
    SELECT
      n.id,
      n.title,
      n.description,
      n.image_url,
      n.target_course,
      n.created_at,
      n.upvote_count,
      p.full_name  AS author_name,
      p.role       AS author_role,
      n.user_id    AS author_id,
      s.name       AS subject_name,
      top.name     AS topic_name,
      cgs.shared_at
    FROM content_group_shares cgs
    JOIN notes n     ON n.id   = cgs.content_id
    JOIN profiles p  ON p.id   = n.user_id
    LEFT JOIN subjects s   ON s.id   = n.subject_id
    LEFT JOIN topics top   ON top.id = n.topic_id
    WHERE cgs.group_id = p_group_id AND cgs.content_type = 'note'
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.shared_at DESC), '[]'::json) INTO v_decks
  FROM (
    SELECT
      fd.id,
      fd.card_count,
      fd.target_course,
      fd.visibility,
      fd.upvote_count,
      fd.created_at,
      p.full_name  AS author_name,
      p.role       AS author_role,
      fd.user_id   AS author_id,
      s.name       AS subject_name,
      COALESCE(fd.custom_subject, s.name, 'Other')   AS display_subject,
      top.name     AS topic_name,
      COALESCE(fd.custom_topic, top.name, 'General') AS display_topic,
      cgs.shared_at
    FROM content_group_shares cgs
    JOIN flashcard_decks fd ON fd.id  = cgs.content_id
    JOIN profiles p         ON p.id   = fd.user_id
    LEFT JOIN subjects s    ON s.id   = fd.subject_id
    LEFT JOIN topics top    ON top.id = fd.topic_id
    WHERE cgs.group_id = p_group_id AND cgs.content_type = 'flashcard_deck'
  ) t;

  RETURN json_build_object(
    'group',   v_group,
    'members', COALESCE(v_members, '[]'::json),
    'pending_invitations', COALESCE(v_pending, '[]'::json),
    'shared_content', json_build_object(
      'notes', COALESCE(v_notes, '[]'::json),
      'decks', COALESCE(v_decks, '[]'::json)
    )
  );
END;
$function$;
