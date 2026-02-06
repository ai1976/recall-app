-- Name: [FUNCTIONS] Create Study Group
-- Description: Creates a study group and adds the creator as admin member in one transaction.
-- Returns the new group's UUID. Use when user clicks "Create Group" button.

CREATE OR REPLACE FUNCTION create_study_group(
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_group_id UUID;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Create the group
  INSERT INTO study_groups (name, description, created_by)
  VALUES (p_name, p_description, v_user_id)
  RETURNING id INTO v_group_id;

  -- Add creator as admin
  INSERT INTO study_group_members (group_id, user_id, role)
  VALUES (v_group_id, v_user_id, 'admin');

  RETURN v_group_id;
END;
$$;
