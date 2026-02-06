-- Name: [FUNCTIONS] Get User Groups v2 (with invitation status filter)
-- Description: Returns all study groups the user is an ACTIVE member of.
-- Pending invitations (status='invited') are excluded — they show separately
-- via get_pending_group_invites(). Member count only includes active members.

CREATE OR REPLACE FUNCTION get_user_groups()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  creator_name TEXT,
  created_at TIMESTAMPTZ,
  member_count BIGINT,
  user_role TEXT
)
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

  RETURN QUERY
  SELECT
    sg.id,
    sg.name,
    sg.description,
    sg.created_by,
    p.full_name AS creator_name,
    sg.created_at,
    (SELECT COUNT(*) FROM study_group_members
     WHERE group_id = sg.id AND status = 'active') AS member_count,
    sgm.role AS user_role
  FROM study_groups sg
  JOIN study_group_members sgm
    ON sgm.group_id = sg.id
    AND sgm.user_id = v_user_id
    AND sgm.status = 'active'  -- Only active memberships, not pending invites
  JOIN profiles p ON p.id = sg.created_by
  ORDER BY sg.created_at DESC;
END;
$$;
