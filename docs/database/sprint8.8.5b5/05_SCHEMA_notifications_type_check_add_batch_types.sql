-- [SCHEMA] notifications_type_check: allow 'batch_added' and 'batch_approved' (Sprint 8.8.5b5, D-49)
-- Description: The 02 test (30/09/2026) failed because the batch functions insert notification types the table does not allow.
--   Live definition (04 diagnostic, block 1), 16 allowed values, 11 of them in use today (block 2):
--     content_upvoted, badge_earned, friend_request, friend_accepted, friend_rejected, welcome, group_invite, professor_content,
--     friend_content, group_content, system_announcement, content_flagged, access_request, access_granted, follow, upvote
--   This keeps EVERY one of them and adds exactly two: batch_added, batch_approved. The constraint is re-created VALIDATED
--   (about 1,600 existing rows, all in the old list, so the re-validation cannot fail). The 13 other functions that insert
--   notifications (04 block 3) write only old types and are unaffected.
--   Run order after this file: 01 (re-deploy the batch functions), then 02 (test).
-- Rollback: 06 (only valid while no batch_* notification exists).

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type = ANY (ARRAY[
    'content_upvoted'::text, 'badge_earned'::text, 'friend_request'::text, 'friend_accepted'::text,
    'friend_rejected'::text, 'welcome'::text, 'group_invite'::text, 'professor_content'::text,
    'friend_content'::text, 'group_content'::text, 'system_announcement'::text, 'content_flagged'::text,
    'access_request'::text, 'access_granted'::text, 'follow'::text, 'upvote'::text,
    'batch_added'::text, 'batch_approved'::text
  ]));
