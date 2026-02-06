-- Name: [SCHEMA] Add Invitation Status to study_group_members
-- Description: Adds 'status' and 'invited_by' columns to support invitation flow.
-- status: 'invited' (pending consent) or 'active' (accepted member).
-- invited_by: UUID of the admin who sent the invitation.
-- DEFAULT 'active' ensures all existing members remain unaffected (zero migration risk).
-- Run AFTER creating the notifications table (13_SCHEMA).

-- ============================================
-- Add columns
-- ============================================
ALTER TABLE study_group_members
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
CHECK (status IN ('invited', 'active'));

ALTER TABLE study_group_members
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- ============================================
-- Index for status filtering
-- ============================================
CREATE INDEX IF NOT EXISTS idx_sgm_status ON study_group_members(status);
