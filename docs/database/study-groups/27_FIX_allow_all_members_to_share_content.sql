-- Name: [FIX] Allow All Group Members to Share Content
-- Description: Changes sharing permissions so any active group member can share their
-- own content with the group (not just admins). Admins can still delete any shared
-- content, while regular members can only remove their own shares.
-- Run once to update the function and RLS policies.

-- ============================================
-- 1. Update share_content_with_groups function
--    Change: admin check → active member check
-- ============================================

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
  v_is_member BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_content_type NOT IN ('note', 'flashcard_deck') THEN
    RAISE EXCEPTION 'Invalid content type: %', p_content_type;
  END IF;

  FOREACH v_group_id IN ARRAY p_group_ids LOOP
    -- Check user is an active member of this group (any role)
    SELECT EXISTS(
      SELECT 1 FROM study_group_members
      WHERE group_id = v_group_id AND user_id = v_user_id AND status = 'active'
    ) INTO v_is_member;

    IF v_is_member THEN
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

-- ============================================
-- 2. Update RLS INSERT policy on content_group_shares
--    Change: admin only → any active member can share
-- ============================================

DROP POLICY IF EXISTS "cgs_insert_admin" ON content_group_shares;

CREATE POLICY "cgs_insert_member"
  ON content_group_shares FOR INSERT TO authenticated
  WITH CHECK (
    shared_by = auth.uid()
    AND group_id IN (
      SELECT group_id FROM study_group_members
      WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- ============================================
-- 3. Update RLS DELETE policy on content_group_shares
--    Change: admin only → admin can delete any, member can delete own shares
-- ============================================

DROP POLICY IF EXISTS "cgs_delete_admin" ON content_group_shares;

CREATE POLICY "cgs_delete_own_or_admin"
  ON content_group_shares FOR DELETE TO authenticated
  USING (
    -- Member can remove their own shares
    shared_by = auth.uid()
    OR
    -- Admin can remove any share in their group
    group_id IN (
      SELECT group_id FROM study_group_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
