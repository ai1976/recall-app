-- Name: [SCHEMA] Create Study Groups Tables
-- Description: Creates three tables for study group feature:
--   1. study_groups - Group metadata (name, description, creator)
--   2. study_group_members - Membership with roles (admin/member)
--   3. content_group_shares - Which content is shared with which groups
-- ON DELETE CASCADE ensures deleting a group removes members and shares but NOT original content.
-- Run once during initial study groups feature rollout.

-- ============================================
-- TABLE 1: study_groups
-- ============================================
CREATE TABLE study_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_study_groups_created_by ON study_groups(created_by);
CREATE INDEX idx_study_groups_created_at ON study_groups(created_at);

-- ============================================
-- TABLE 2: study_group_members
-- ============================================
CREATE TABLE study_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

-- Indexes
CREATE INDEX idx_sgm_group_id ON study_group_members(group_id);
CREATE INDEX idx_sgm_user_id ON study_group_members(user_id);
CREATE INDEX idx_sgm_role ON study_group_members(role);

-- ============================================
-- TABLE 3: content_group_shares
-- ============================================
CREATE TABLE content_group_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL CHECK (content_type IN ('note', 'flashcard_deck')),
  content_id UUID NOT NULL,
  shared_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  shared_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(group_id, content_type, content_id)
);

-- Indexes
CREATE INDEX idx_cgs_group_id ON content_group_shares(group_id);
CREATE INDEX idx_cgs_content ON content_group_shares(content_type, content_id);
CREATE INDEX idx_cgs_shared_by ON content_group_shares(shared_by);
