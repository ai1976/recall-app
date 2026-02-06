-- Name: [FUNCTIONS] Decline Group Invite
-- Description: Declines a pending group invitation. Hard deletes the membership row
-- (same pattern as friendship rejection). Also marks the notification as read.
-- Only the invited user can decline their own invitation.

CREATE OR REPLACE FUNCTION decline_group_invite(p_membership_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Automatic notification cleanup: mark the corresponding notification as read
  UPDATE notifications
  SET is_read = true
  WHERE user_id = v_user_id
    AND type = 'group_invite'
    AND metadata->>'membership_id' = p_membership_id::TEXT
    AND is_read = false;

  -- Hard delete the invitation row (same pattern as friendship rejection)
  DELETE FROM study_group_members
  WHERE id = p_membership_id
    AND user_id = v_user_id
    AND status = 'invited';
END;
$$;
