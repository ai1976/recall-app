-- Name: [FUNCTIONS] Share Content With Study Groups
-- Description: Shares a piece of content (note or flashcard_deck) with multiple groups at once.
-- Also updates the content's visibility to 'study_groups' if currently 'private'.
-- Only group admins can share content. Skips groups where content is already shared.
-- Returns the number of new shares created.

CREATE OR REPLACE FUNCTION share_content_with_groups(
  p_content_type TEXT,
  p_content_id UUID,
  p_group_ids UUID[]
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_group_id UUID;
  v_shares_created INTEGER := 0;
  v_is_admin BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_content_type NOT IN ('note', 'flashcard_deck') THEN
    RAISE EXCEPTION 'Invalid content type: %', p_content_type;
  END IF;

  FOREACH v_group_id IN ARRAY p_group_ids LOOP
    -- Check user is admin of this group
    SELECT EXISTS(
      SELECT 1 FROM study_group_members
      WHERE group_id = v_group_id AND user_id = v_user_id AND role = 'admin'
    ) INTO v_is_admin;

    IF v_is_admin THEN
      -- Insert share (skip if already exists via ON CONFLICT)
      INSERT INTO content_group_shares (group_id, content_type, content_id, shared_by)
      VALUES (v_group_id, p_content_type, p_content_id, v_user_id)
      ON CONFLICT (group_id, content_type, content_id) DO NOTHING;

      IF FOUND THEN
        v_shares_created := v_shares_created + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN v_shares_created;
END;
$$;
