-- [FUNCTIONS] ROLLBACK for 03-06 (Sprint 8.8.5d). Restores the LIVE bodies read on 01/10/2026 (00 diagnostic block A + the join/enroll sources),
-- then removes the new objects. Run the whole file in order. After it, professors again see EVERY batch (role-only gates), a professor can
-- self-join a batch through a link, and the student report lists staff - i.e. the pre-sprint state.
-- Frontend note: if the new Admin Dashboard "Professors" panel is already deployed, revert it too (it calls the functions dropped below).

-- 1. Restore the tightened functions ---------------------------------------
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

CREATE OR REPLACE FUNCTION public.get_batch_group_member_stats(p_group_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, reviews_this_week bigint, streak_days integer, study_time_this_week_seconds bigint, last_active_date date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF (SELECT role FROM profiles WHERE id = auth.uid()) NOT IN ('professor', 'admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM study_groups WHERE id = p_group_id AND is_batch_group = true
  ) THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;
  RETURN QUERY
  SELECT
    m.user_id,
    p.full_name,
    COALESCE(rv.reviews_this_week, 0)            AS reviews_this_week,
    COALESCE(get_user_streak(m.user_id), 0)      AS streak_days,
    COALESCE(ss.study_time_this_week_seconds, 0) AS study_time_this_week_seconds,
    rv.last_active_date
  FROM study_group_members m
  JOIN profiles p ON p.id = m.user_id
  LEFT JOIN (
    SELECT
      r.user_id,
      COUNT(*)::bigint        AS reviews_this_week,
      MAX(r.created_at)::date AS last_active_date
    FROM reviews r
    WHERE r.created_at >= date_trunc('week', CURRENT_DATE)
    GROUP BY r.user_id
  ) rv ON rv.user_id = m.user_id
  LEFT JOIN (
    SELECT
      s.user_id,
      SUM(s.duration_seconds)::bigint AS study_time_this_week_seconds
    FROM study_sessions s
    WHERE s.session_date >= date_trunc('week', CURRENT_DATE)::date
    GROUP BY s.user_id
  ) ss ON ss.user_id = m.user_id
  WHERE m.group_id = p_group_id
    AND m.status = 'active';
END;
$function$;

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
    UPDATE study_group_members
    SET status = 'active', joined_at = NOW()
    WHERE group_id = v_group_id AND user_id = auth.uid() AND status = 'invited';

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

  INSERT INTO study_group_members (group_id, user_id, role, status)
  VALUES (v_group_id, auth.uid(), 'member', 'active')
  ON CONFLICT (group_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('group_id', v_group_id, 'status', 'active');
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

-- get_admin_batch_groups: original ACL (default PUBLIC execute; anon was true on 01/10/2026)
GRANT EXECUTE ON FUNCTION public.get_admin_batch_groups() TO PUBLIC, anon, authenticated;

-- 2. Remove the new objects ---------------------------------------------------
DROP FUNCTION IF EXISTS public.assign_professor_to_batch(uuid, uuid);
DROP FUNCTION IF EXISTS public.unassign_professor_from_batch(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_batch_group_professors(uuid);
DROP FUNCTION IF EXISTS public.get_assignable_professors();
DROP FUNCTION IF EXISTS public.batch_group_access_denial(uuid, uuid, text);
DROP TABLE IF EXISTS public.batch_group_professors;
-- Audit rows written by the new functions stay (admin_audit_log is append-only).
