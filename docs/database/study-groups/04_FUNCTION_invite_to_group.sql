-- Name: [FUNCTIONS] Invite User to Study Group
-- Description: Adds a user to a study group as 'member'. Only group admins can invite.
-- Returns void. Raises error if caller is not admin or user is already a member.

CREATE OR REPLACE FUNCTION invite_to_group(
  p_group_id UUID,
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Check caller is admin of this group
  SELECT EXISTS(
    SELECT 1 FROM study_group_members
    WHERE group_id = p_group_id AND user_id = v_caller_id AND role = 'admin'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only group admins can invite members';
  END IF;

  -- Add user as member (UNIQUE constraint will prevent duplicates)
  INSERT INTO study_group_members (group_id, user_id, role)
  VALUES (p_group_id, p_user_id, 'member');
END;
$$;
