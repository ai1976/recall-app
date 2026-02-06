-- Name: [FUNCTIONS] Get Pending Group Invites
-- Description: Returns all pending group invitations for the current user.
-- Used on the MyGroups page to show a "Pending Invitations" section.
-- PRIVACY: No email returned. Only safe public fields.

CREATE OR REPLACE FUNCTION get_pending_group_invites()
RETURNS TABLE (
  membership_id UUID,
  group_id UUID,
  group_name TEXT,
  group_description TEXT,
  invited_by_name TEXT,
  invited_at TIMESTAMPTZ,
  member_count BIGINT
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
    sgm.id AS membership_id,
    sg.id AS group_id,
    sg.name AS group_name,
    sg.description AS group_description,
    p.full_name AS invited_by_name,
    sgm.joined_at AS invited_at,
    (SELECT COUNT(*) FROM study_group_members sub
     WHERE sub.group_id = sg.id AND sub.status = 'active') AS member_count
  FROM study_group_members sgm
  JOIN study_groups sg ON sg.id = sgm.group_id
  LEFT JOIN profiles p ON p.id = sgm.invited_by
  WHERE sgm.user_id = v_user_id
    AND sgm.status = 'invited'
  ORDER BY sgm.joined_at DESC;
END;
$$;
