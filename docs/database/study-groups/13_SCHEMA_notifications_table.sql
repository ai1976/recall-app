-- Name: [SCHEMA] Create Notifications Table
-- Description: General-purpose notifications table for the Recall app.
-- Supports: friend_request, friend_accepted, badge_earned, upvote, comment, group_invite.
-- The metadata JSONB column stores type-specific data (e.g. group_id, inviter_name for group_invite).
-- Frontend hooks (useNotifications.js) and UI (ActivityDropdown.jsx) are already built and ready.
--
-- IMPORTANT: After running this SQL, enable Supabase Realtime on the notifications table:
--   Dashboard > Database > Replication > Toggle ON for 'notifications'
--   Without this, the real-time subscription in useNotifications.js will not receive new notifications.

-- ============================================
-- Create table
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read)
  WHERE is_read = false;

-- ============================================
-- Enable RLS
-- ============================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can view their own notifications
CREATE POLICY "notif_select_own"
  ON notifications FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Users can update their own notifications (mark as read)
CREATE POLICY "notif_update_own"
  ON notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

-- Users can delete their own notifications
CREATE POLICY "notif_delete_own"
  ON notifications FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- No INSERT policy for regular users — notifications are created
-- by SECURITY DEFINER functions (invite_to_group, etc.)
