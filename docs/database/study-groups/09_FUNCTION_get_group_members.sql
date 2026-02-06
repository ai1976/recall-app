-- Name: [FUNCTIONS] Get Group Members
-- Description: Returns all members of a study group with their profile info.
-- Only accessible by group members (checked via auth.uid()).
-- Needed because RLS on study_group_members only shows user's own rows
-- (to avoid infinite recursion), so a SECURITY DEFINER function is required
-- to list all members for the GroupDetail page.
--
-- PRIVACY: Email is NOT returned. Only safe public fields.
-- NOTE: GroupDetail.jsx now uses get_group_detail() instead.
-- This function is kept as a standalone utility if needed elsewhere.
--
-- IMPORTANT: Must DROP first if upgrading from old version (return type changed — email removed).

DROP FUNCTION IF EXISTS get_group_members(UUID);

CREATE OR REPLACE FUNCTION get_group_members(
  p_group_id UUID
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  role TEXT,
  joined_at TIMESTAMPTZ,
  full_name TEXT,
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

  -- Strict membership check
  IF NOT EXISTS (
    SELECT 1 FROM study_group_members
    WHERE group_id = p_group_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    sgm.id,
    sgm.user_id,
    sgm.role,
    sgm.joined_at,
    p.full_name,
    p.role AS user_role
  FROM study_group_members sgm
  JOIN profiles p ON p.id = sgm.user_id
  WHERE sgm.group_id = p_group_id
  ORDER BY sgm.joined_at ASC;
END;
$$;
