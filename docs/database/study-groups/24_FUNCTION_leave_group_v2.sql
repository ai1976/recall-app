-- Name: [FUNCTIONS] Leave Group v2 (with invitation status filter)
-- Description: Removes the calling user from a study group. Only ACTIVE members can leave.
-- Invited users should use decline_group_invite() instead.
-- Member count and admin count only consider active members.

CREATE OR REPLACE FUNCTION leave_group(
  p_group_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_admin_count INTEGER;
  v_member_count INTEGER;
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

  -- Count ACTIVE members only (not invited)
  SELECT COUNT(*) INTO v_member_count
  FROM study_group_members
  WHERE group_id = p_group_id AND status = 'active';

  -- If last active member, delete the entire group (cascades to members + shares)
  IF v_member_count = 1 THEN
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
$$;
