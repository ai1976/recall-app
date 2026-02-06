-- Name: [FUNCTIONS] Get User Groups
-- Description: Returns all study groups the calling user belongs to,
-- with member count, user's role, and creator info.
-- Used on MyGroups page and group selection dropdowns.

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
    (SELECT COUNT(*) FROM study_group_members WHERE group_id = sg.id) AS member_count,
    sgm.role AS user_role
  FROM study_groups sg
  JOIN study_group_members sgm ON sgm.group_id = sg.id AND sgm.user_id = v_user_id
  JOIN profiles p ON p.id = sg.created_by
  ORDER BY sg.created_at DESC;
END;
$$;
