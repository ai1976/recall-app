-- Name: [FUNCTIONS] Invite to Group v2 (with notification + consent)
-- Description: Replaces the old invite_to_group that auto-added members.
-- Now inserts with status='invited' and creates a notification for the invited user.
-- The user must accept the invitation before becoming an active member.
-- Run AFTER 13 (notifications table), 14 (notification RPCs), 15 (status column).

DROP FUNCTION IF EXISTS invite_to_group(UUID, UUID);

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
  v_group_name TEXT;
  v_inviter_name TEXT;
  v_membership_id UUID;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Check caller is an ACTIVE admin of this group
  SELECT EXISTS(
    SELECT 1 FROM study_group_members
    WHERE group_id = p_group_id
      AND user_id = v_caller_id
      AND role = 'admin'
      AND status = 'active'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Only group admins can invite members';
  END IF;

  -- Get group name and inviter name for the notification
  SELECT name INTO v_group_name FROM study_groups WHERE id = p_group_id;
  SELECT full_name INTO v_inviter_name FROM profiles WHERE id = v_caller_id;

  -- Insert as invited (UNIQUE constraint prevents duplicates)
  INSERT INTO study_group_members (group_id, user_id, role, status, invited_by)
  VALUES (p_group_id, p_user_id, 'member', 'invited', v_caller_id)
  RETURNING id INTO v_membership_id;

  -- Create notification for the invited user
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    p_user_id,
    'group_invite',
    v_inviter_name || ' invited you to "' || v_group_name || '"',
    'Accept to start viewing shared notes and flashcards.',
    jsonb_build_object(
      'group_id', p_group_id,
      'group_name', v_group_name,
      'inviter_id', v_caller_id,
      'inviter_name', v_inviter_name,
      'membership_id', v_membership_id
    )
  );
END;
$$;
