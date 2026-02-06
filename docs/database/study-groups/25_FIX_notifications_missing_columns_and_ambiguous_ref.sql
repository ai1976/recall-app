-- Name: [FIX] Add missing columns to notifications + fix ambiguous group_id
-- Description: Two fixes:
-- 1. The notifications table existed BEFORE our SQL #13 ran, so CREATE TABLE IF NOT EXISTS
--    did nothing. The existing table is missing 'title', 'metadata', 'is_read' columns.
--    We ALTER TABLE to add them.
-- 2. get_pending_group_invites() has ambiguous 'group_id' in subquery because RETURNS TABLE
--    also declares a column named group_id. Fix with explicit table alias.
-- Run this AFTER SQL 13-24.

-- ============================================
-- Fix 1: Add missing columns to notifications table
-- ============================================
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false;

-- Backfill: set title from message for existing rows that have no title
UPDATE notifications SET title = message WHERE title IS NULL AND message IS NOT NULL;

-- Add missing indexes (IF NOT EXISTS handles duplicates safely)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read)
  WHERE is_read = false;

-- ============================================
-- Fix 2: Recreate get_pending_group_invites with aliased subquery
-- ============================================
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
