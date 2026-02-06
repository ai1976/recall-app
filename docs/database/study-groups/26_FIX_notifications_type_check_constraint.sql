-- Name: [FIX] Update notifications type check constraint to include group_invite
-- Description: The existing notifications table has a CHECK constraint on the 'type' column
-- that only allows the original notification types. We need to drop it and recreate it
-- to also allow 'group_invite' (and future types).
-- Run this BEFORE attempting to invite users to groups.

-- Drop the existing constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Recreate with all supported types (original + new)
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'content_upvoted',
    'badge_earned',
    'friend_request',
    'friend_accepted',
    'friend_rejected',
    'welcome',
    'group_invite'
  ));
