-- Name: [SCHEMA] RLS Policies for Study Groups
-- Description: Row Level Security policies for study_groups, study_group_members,
--   and content_group_shares tables. Members can read group data they belong to.
--   Only admins/creators can modify groups. Content sharing is read-only for members.
--
-- IMPORTANT: study_group_members policies use DIRECT column checks (not subqueries
-- against the same table) to avoid infinite recursion. Supabase evaluates RLS on
-- every SELECT, so a policy that SELECTs from its own table triggers itself infinitely.
--
-- Run AFTER creating the tables (01_SCHEMA).
-- If re-running, DROP existing policies first (see cleanup section at bottom).

-- ============================================
-- Enable RLS on all three tables
-- ============================================
ALTER TABLE study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_group_shares ENABLE ROW LEVEL SECURITY;

-- ============================================
-- study_group_members policies (MUST be created FIRST)
-- These use direct column checks to avoid recursion.
-- ============================================

-- Members can see their own membership rows (no self-referencing subquery)
CREATE POLICY "sgm_select_own"
  ON study_group_members FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Admins can insert new members.
-- We check the INSERTING user is admin via a direct lookup that won't recurse
-- because the SELECT policy above only returns rows where user_id = auth.uid().
CREATE POLICY "sgm_insert_admin"
  ON study_group_members FOR INSERT TO authenticated
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM study_group_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Users can remove themselves, OR admins can remove others
CREATE POLICY "sgm_delete"
  ON study_group_members FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR group_id IN (
      SELECT group_id FROM study_group_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- study_groups policies
-- Now safe to reference study_group_members because sgm_select_own
-- is a simple column check (no recursion).
-- ============================================

-- Users can view groups they are members of
CREATE POLICY "sg_select_member"
  ON study_groups FOR SELECT TO authenticated
  USING (
    id IN (SELECT group_id FROM study_group_members WHERE user_id = auth.uid())
  );

-- Users can create groups (they must set themselves as created_by)
CREATE POLICY "sg_insert"
  ON study_groups FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

-- Only the creator can update their group
CREATE POLICY "sg_update_creator"
  ON study_groups FOR UPDATE TO authenticated
  USING (created_by = auth.uid());

-- Only the creator can delete their group
CREATE POLICY "sg_delete_creator"
  ON study_groups FOR DELETE TO authenticated
  USING (created_by = auth.uid());

-- ============================================
-- content_group_shares policies
-- ============================================

-- Members can view shared content in their groups
CREATE POLICY "cgs_select_member"
  ON content_group_shares FOR SELECT TO authenticated
  USING (
    group_id IN (SELECT group_id FROM study_group_members WHERE user_id = auth.uid())
  );

-- Group admins can share content
CREATE POLICY "cgs_insert_admin"
  ON content_group_shares FOR INSERT TO authenticated
  WITH CHECK (
    shared_by = auth.uid()
    AND group_id IN (
      SELECT group_id FROM study_group_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Group admins can unshare content
CREATE POLICY "cgs_delete_admin"
  ON content_group_shares FOR DELETE TO authenticated
  USING (
    group_id IN (
      SELECT group_id FROM study_group_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- CLEANUP: Run these ONLY if re-applying policies
-- (skip on first install)
-- ============================================
-- DROP POLICY IF EXISTS "sgm_select_member" ON study_group_members;
-- DROP POLICY IF EXISTS "sgm_select_own" ON study_group_members;
-- DROP POLICY IF EXISTS "sgm_insert_admin" ON study_group_members;
-- DROP POLICY IF EXISTS "sgm_delete" ON study_group_members;
-- DROP POLICY IF EXISTS "sg_select_member" ON study_groups;
-- DROP POLICY IF EXISTS "sg_insert" ON study_groups;
-- DROP POLICY IF EXISTS "sg_update_creator" ON study_groups;
-- DROP POLICY IF EXISTS "sg_delete_creator" ON study_groups;
-- DROP POLICY IF EXISTS "cgs_select_member" ON content_group_shares;
-- DROP POLICY IF EXISTS "cgs_insert_admin" ON content_group_shares;
-- DROP POLICY IF EXISTS "cgs_delete_admin" ON content_group_shares;
