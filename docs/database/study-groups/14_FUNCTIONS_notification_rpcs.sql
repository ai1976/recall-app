-- Name: [FUNCTIONS] Notification RPC Functions
-- Description: 5 SECURITY DEFINER RPCs that the useNotifications.js hook expects.
-- Plus a cleanup_old_notifications() utility for cron-based retention.
-- Run AFTER creating the notifications table (13_SCHEMA).

-- ============================================
-- Drop existing functions (return type changes require DROP first)
-- ============================================
DROP FUNCTION IF EXISTS get_unread_notification_count(UUID);
DROP FUNCTION IF EXISTS get_recent_notifications(UUID, INTEGER);
DROP FUNCTION IF EXISTS get_recent_notifications(UUID);
DROP FUNCTION IF EXISTS mark_notifications_read(UUID);
DROP FUNCTION IF EXISTS mark_single_notification_read(UUID);
DROP FUNCTION IF EXISTS delete_notification(UUID);
DROP FUNCTION IF EXISTS cleanup_old_notifications();

-- ============================================
-- 1. Get unread notification count
-- ============================================
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_count
  FROM notifications
  WHERE user_id = p_user_id AND is_read = false;

  RETURN v_count;
END;
$$;

-- ============================================
-- 2. Get recent notifications
-- ============================================
CREATE OR REPLACE FUNCTION get_recent_notifications(p_user_id UUID, p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  type TEXT,
  title TEXT,
  message TEXT,
  is_read BOOLEAN,
  metadata JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    n.id, n.user_id, n.type, n.title, n.message, n.is_read, n.metadata, n.created_at
  FROM notifications n
  WHERE n.user_id = p_user_id
  ORDER BY n.created_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================
-- 3. Mark all notifications as read
-- ============================================
CREATE OR REPLACE FUNCTION mark_notifications_read(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  UPDATE notifications
  SET is_read = true
  WHERE user_id = p_user_id AND is_read = false;
END;
$$;

-- ============================================
-- 4. Mark single notification as read
-- ============================================
CREATE OR REPLACE FUNCTION mark_single_notification_read(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE notifications
  SET is_read = true
  WHERE id = p_notification_id AND user_id = auth.uid();
END;
$$;

-- ============================================
-- 5. Delete a notification
-- ============================================
CREATE OR REPLACE FUNCTION delete_notification(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM notifications
  WHERE id = p_notification_id AND user_id = auth.uid();
END;
$$;

-- ============================================
-- 6. Cleanup old notifications (utility for cron)
-- ============================================
-- Run this via Supabase pg_cron or manually to delete notifications older than 60 days.
-- Example cron setup (in Supabase SQL Editor):
--   SELECT cron.schedule('cleanup-notifications', '0 3 * * 0', $$SELECT cleanup_old_notifications()$$);
--   This runs every Sunday at 3:00 AM UTC.

CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM notifications
  WHERE created_at < NOW() - INTERVAL '60 days';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;
