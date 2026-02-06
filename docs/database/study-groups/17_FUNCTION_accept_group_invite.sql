-- Name: [FUNCTIONS] Accept Group Invite
-- Description: Accepts a pending group invitation. Updates status from 'invited' to 'active'.
-- Also marks the corresponding notification as read (automatic cleanup).
-- Only the invited user can accept their own invitation.

CREATE OR REPLACE FUNCTION accept_group_invite(p_membership_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_group_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Verify this invitation belongs to the current user and is pending
  SELECT group_id INTO v_group_id
  FROM study_group_members
  WHERE id = p_membership_id
    AND user_id = v_user_id
    AND status = 'invited';

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invitation not found or already processed';
  END IF;

  -- Accept: update status to active, reset joined_at to now
  UPDATE study_group_members
  SET status = 'active', joined_at = NOW()
  WHERE id = p_membership_id;

  -- Automatic notification cleanup: mark the corresponding notification as read
  UPDATE notifications
  SET is_read = true
  WHERE user_id = v_user_id
    AND type = 'group_invite'
    AND metadata->>'membership_id' = p_membership_id::TEXT
    AND is_read = false;
END;
$$;
