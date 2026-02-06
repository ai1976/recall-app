-- Name: [FUNCTIONS] Leave Study Group
-- Description: Removes the calling user from a study group. If the user is the last admin,
-- the group is deleted (cascading to members and shares). Returns void.

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

  -- Get user's role in the group
  SELECT role INTO v_user_role
  FROM study_group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'You are not a member of this group';
  END IF;

  -- Count members
  SELECT COUNT(*) INTO v_member_count
  FROM study_group_members
  WHERE group_id = p_group_id;

  -- If last member, delete the entire group (cascades)
  IF v_member_count = 1 THEN
    DELETE FROM study_groups WHERE id = p_group_id;
    RETURN;
  END IF;

  -- If admin leaving, check admin count
  IF v_user_role = 'admin' THEN
    SELECT COUNT(*) INTO v_admin_count
    FROM study_group_members
    WHERE group_id = p_group_id AND role = 'admin';

    -- If last admin, promote oldest member to admin
    IF v_admin_count = 1 THEN
      UPDATE study_group_members
      SET role = 'admin'
      WHERE id = (
        SELECT id FROM study_group_members
        WHERE group_id = p_group_id AND user_id != v_user_id
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
