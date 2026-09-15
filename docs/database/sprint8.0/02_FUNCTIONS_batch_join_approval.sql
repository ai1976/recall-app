-- Name: [FUNCTIONS] Sprint 8.0 — batch invite-link join with staff approval
-- Description: Minimum-complete approval workflow for batch (B2B) study groups,
-- replacing automatic/immediate enrollment. Design, decided in the PhaseBuilder
-- thread before this SQL was written:
--
--   1. Batch membership is fully separate from profiles.course_level/institution.
--      join_group_by_token never writes those fields — only study_group_members.
--      (Those profile fields change only through an explicit, separate action,
--      which does not exist in the UI yet — not this sprint's to build.)
--   2. There are exactly TWO ways a batch-group membership row is ever created,
--      and BOTH are an explicit action by a specific human about a specific
--      (student, batch) pair — never a guess from course+institution:
--        a. Student clicks the batch's own invite link -> join_group_by_token
--           inserts status='requested'. Only approve_batch_join_request (an
--           admin acting on that specific pending row) flips it to 'active'.
--        b. Admin explicitly picks one student AND one exact batch group in
--           the UI -> enroll_user_in_batch_group(p_user_id, p_group_id)
--           inserts/activates status='active' directly — the admin's explicit
--           selection of the exact group IS the approval, so there is no
--           'requested' intermediate step for this path.
--      Neither path ever resolves "the" batch group by matching
--      course_level+institution. create_batch_group creates the study_groups
--      row ONLY (no auto-add of matching students, pending or active) and
--      fn_auto_enroll_batch_group (the profiles trigger) no longer creates
--      ANY membership row at all — a guessed match, even landed as
--      'requested', can still point at the wrong batch when two batch groups
--      share the same course+institution, and a pending request for the wrong
--      batch is still a real, incorrect thing an admin would have to catch.
--   3. Verified before writing this: get_browsable_notes/get_browsable_decks/
--      get_group_detail already gate all group-shared content on
--      `sgm.status = 'active'` — confirmed live (pg_policy dump: notes/
--      flashcards/flashcard_decks base-table RLS has NO group-share clause at
--      all, own/public/friends/admin only) that there is no direct-table
--      bypass of that gate. So a 'requested' row is already fully inert for
--      content access — no paid/free tier concept needed, per the agreed design.
--   4. This also fully retires the original STOP-condition risk in
--      fn_auto_enroll_batch_group (its course+institution LIMIT-1 match wasn't
--      scoped to a specific group_id): the trigger no longer creates any new
--      membership at all, guessed or otherwise, so the ambiguity has nothing
--      left to act on. It still performs course-change cleanup (removing
--      membership in the OLD matched group) — that branch has the same
--      LIMIT-1 course+institution lookup and so the same theoretical
--      wrong-group risk, just on the remove side, not the grant side; left
--      in place since it doesn't grant anything, flagged in the summary.
--
-- Explicitly NOT built here (deliberately cut from the original broader Sprint
-- 8.0 draft, per "minimum complete, no optional features"): emailRedirectTo /
-- cross-device signup confirmation, a redesigned "check your email" screen,
-- locking the course selector at signup, delegated (non-admin) approvers,
-- bulk roster upload, payment integration.
--
-- Run AFTER 01_SCHEMA_add_requested_status.sql.

-- ============================================================================
-- 1. join_group_by_token — return type changes (uuid -> jsonb), so DROP first.
-- ============================================================================
DROP FUNCTION IF EXISTS public.join_group_by_token(uuid);

CREATE OR REPLACE FUNCTION public.join_group_by_token(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
DECLARE
  v_group_id    UUID;
  v_group_type  TEXT;
  v_caller_role TEXT;
  v_status      TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT id, group_type INTO v_group_id, v_group_type
  FROM study_groups
  WHERE invite_token = p_token;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite link';
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
    -- (active, requested, or the just-activated invited row above) — two
    -- concurrent clicks / double-submits never race into a duplicate or error.
    INSERT INTO study_group_members (group_id, user_id, role, status)
    VALUES (v_group_id, auth.uid(), 'member', 'requested')
    ON CONFLICT (group_id, user_id) DO NOTHING;

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
-- 2. get_group_preview — same jsonb return type, additive fields only.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_group_preview(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
DECLARE
  v_group_id      UUID;
  v_group         JSONB;
  v_stats         JSONB;
  v_viewer_status TEXT;
BEGIN
  SELECT id INTO v_group_id
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
    'batch_course',      sg.batch_course,
    'batch_institution', sg.batch_institution,
    'viewer_status',     v_viewer_status
  ) INTO v_group
  FROM study_groups sg
  WHERE sg.id = v_group_id;

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
-- 3. approve_batch_join_request / reject_batch_join_request — admin-only.
-- Mirrors this codebase's existing accept_group_invite/decline_group_invite
-- and approve_featured_nomination/reject_featured_nomination pairs.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.approve_batch_join_request(p_membership_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
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
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  DELETE FROM study_group_members
  WHERE id = p_membership_id AND status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found or already resolved';
  END IF;
END;
$function$;

-- ============================================================================
-- 4. get_admin_pending_batch_requests — the "simple pending list", admin-only.
-- joined_at doubles as requested_at: it's only reset to NOW() on activation
-- (see approve_batch_join_request above), so for a still-'requested' row it
-- still holds the original request time.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_admin_pending_batch_requests()
RETURNS TABLE (
  membership_id     uuid,
  group_id          uuid,
  group_name        text,
  batch_course      text,
  batch_institution text,
  user_id           uuid,
  full_name         text,
  requested_at      timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  RETURN QUERY
  SELECT
    sgm.id,
    sg.id,
    sg.name,
    sg.batch_course,
    sg.batch_institution,
    p.id,
    p.full_name,
    sgm.joined_at
  FROM study_group_members sgm
  JOIN study_groups sg ON sg.id = sgm.group_id
  JOIN profiles p ON p.id = sgm.user_id
  WHERE sgm.status = 'requested' AND sg.is_batch_group = true
  ORDER BY sgm.joined_at ASC;
END;
$function$;

-- ============================================================================
-- 5. get_admin_batch_groups — additive column only (invite_token), so the
-- "Copy Invite Link" action has something to call. Return type changes
-- (new column), so DROP first. Body otherwise byte-identical to live.
-- ============================================================================
DROP FUNCTION IF EXISTS public.get_admin_batch_groups();

CREATE OR REPLACE FUNCTION public.get_admin_batch_groups()
RETURNS TABLE(id uuid, name text, description text, batch_course text, batch_institution text, created_at timestamptz, member_count bigint, is_batch_group boolean, creator_name text, created_by uuid, invite_token uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
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
    sg.invite_token
  FROM study_groups sg
  LEFT JOIN study_group_members sgm
    ON sgm.group_id = sg.id AND sgm.status = 'active'
  LEFT JOIN profiles p ON p.id = sg.created_by
  WHERE sg.is_batch_group = true
  GROUP BY sg.id, sg.name, sg.description, sg.batch_course, sg.batch_institution, sg.created_at, p.full_name, sg.created_by, sg.invite_token
  ORDER BY sg.batch_course;
END;
$function$;

-- ============================================================================
-- 6. create_batch_group — creates the study_groups row ONLY. No auto-add of
-- matching students, pending or active — students request admission via this
-- batch's own invitation link (join_group_by_token). Also adds an is_admin()
-- guard that was missing entirely from the live function (not part of the
-- approval-workflow ask, but the exact same class of gap already fixed for
-- enroll_user_in_batch_group / notify_access_granted in
-- docs/database/security/15 — any authenticated user could call this and
-- create arbitrary batch groups today). Flagged separately in the summary;
-- added here since this function is already being replaced.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_batch_group(p_course_level text, p_name text, p_description text DEFAULT ''::text, p_institution text DEFAULT 'More Classes Commerce'::text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
DECLARE
  v_group_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  INSERT INTO study_groups (name, description, is_batch_group, batch_course, batch_institution, created_by)
  VALUES (p_name, p_description, true, p_course_level, p_institution, auth.uid())
  RETURNING id INTO v_group_id;

  RETURN v_group_id;
END;
$function$;

-- ============================================================================
-- 7. enroll_user_in_batch_group — signature change: now takes an explicit
-- p_group_id instead of guessing the group from course+institution. The
-- admin picking one specific student AND one specific batch group in the UI
-- is itself the approval, so this activates immediately (status='active'),
-- with no 'requested' intermediate step for this path. Single atomic
-- INSERT ... ON CONFLICT DO UPDATE — same "protected" (atomic, admin-gated)
-- pattern as approve_batch_join_request, just keyed by (group_id, user_id)
-- instead of membership_id since there may be no pre-existing row yet.
-- ============================================================================
DROP FUNCTION IF EXISTS public.enroll_user_in_batch_group(uuid);

CREATE OR REPLACE FUNCTION public.enroll_user_in_batch_group(p_user_id uuid, p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM study_groups WHERE id = p_group_id AND is_batch_group = true
  ) THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;

  INSERT INTO study_group_members (group_id, user_id, role, status)
  VALUES (p_group_id, p_user_id, 'member', 'active')
  ON CONFLICT (group_id, user_id) DO UPDATE
    SET status = 'active', joined_at = NOW();
END;
$function$;

-- ============================================================================
-- 8. fn_auto_enroll_batch_group — the "find a NEW batch group by
-- course+institution and add membership" branch is REMOVED entirely (not
-- just downgraded to 'requested'): a guessed match can still point at the
-- wrong batch when two batch groups share the same course+institution, and a
-- pending request for the wrong batch is still a real, incorrect thing an
-- admin has to notice and catch. Batch membership now only ever comes from
-- join_group_by_token (explicit invite-link request) or
-- enroll_user_in_batch_group (admin's explicit student+batch selection) —
-- never a guess. The course-promotion cleanup branch (removing membership in
-- the OLD matched group when a student's course_level changes) is KEPT — it
-- removes real existing membership rather than generating a guessed one, so
-- it's out of scope for this directive, though it uses the same LIMIT-1
-- course+institution lookup and so carries the same theoretical
-- wrong-group risk on the remove side. Flagged in the summary, not changed.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_auto_enroll_batch_group()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
DECLARE
  v_old_batch_group_id UUID;
BEGIN
  -- Skip non-student roles (admin/super_admin/professor must never be auto-enrolled)
  IF NEW.role IN ('admin', 'super_admin', 'professor') THEN
    RETURN NEW;
  END IF;
  -- Skip self-registered users (B2C — no batch group assignment)
  IF NEW.account_type = 'self_registered' THEN
    RETURN NEW;
  END IF;
  -- Skip if no course assigned
  IF NEW.course_level IS NULL THEN
    RETURN NEW;
  END IF;

  -- Course promotion cleanup (UPDATE only): remove from OLD batch group
  IF TG_OP = 'UPDATE'
     AND OLD.course_level IS NOT NULL
     AND OLD.course_level IS DISTINCT FROM NEW.course_level
  THEN
    SELECT id INTO v_old_batch_group_id
    FROM study_groups
    WHERE is_batch_group = true
      AND batch_course    = OLD.course_level
      AND batch_institution = OLD.institution
    LIMIT 1;
    IF v_old_batch_group_id IS NOT NULL THEN
      DELETE FROM study_group_members
      WHERE group_id = v_old_batch_group_id
        AND user_id  = NEW.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
