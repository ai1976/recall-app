-- [SCHEMA] ROLLBACK for 05: restore the original 16-value notifications_type_check
-- Description: Only works while NO 'batch_added' / 'batch_approved' notification exists (the constraint is re-validated). If any
--   exist, delete them first (they are informational only) or keep the new constraint. Run the function rollback (03) first, or the
--   batch functions will fail on insert again.

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type = ANY (ARRAY[
    'content_upvoted'::text, 'badge_earned'::text, 'friend_request'::text, 'friend_accepted'::text,
    'friend_rejected'::text, 'welcome'::text, 'group_invite'::text, 'professor_content'::text,
    'friend_content'::text, 'group_content'::text, 'system_announcement'::text, 'content_flagged'::text,
    'access_request'::text, 'access_granted'::text, 'follow'::text, 'upvote'::text
  ]));
