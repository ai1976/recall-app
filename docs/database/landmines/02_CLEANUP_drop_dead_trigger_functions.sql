-- Name: [CLEANUP] Drop Dead Trigger-Functions (blueprint.md §1.11 #4, #5)
-- Description: Drops seven trigger-functions that exist in the DB but have no trigger wired to
-- them and are called by no application code. Live equivalents remain untouched:
--   - Badges are awarded by the trg_badge_* / fn_badge_check_* family (see
--     DATABASE_SCHEMA.md and blueprint.md §"Known DB Triggers").
--   - Notifications are created via RPC / Edge Functions, not these trigger-functions.
-- Audit trail: codebase grep for 'trg_check_badge_' and 'notify_friend_request|
-- notify_friend_accepted|notify_content_upvoted' across src/ returned zero matches. Live
-- confirmation (no trigger wired, no other function calling them) comes from
-- 01_DIAGNOSTIC_landmine_l1_audit.sql queries 1-3 — do not run this until that output confirms
-- zero live references.
--
-- Deploy: immediately deployable, no frontend dependency.

DROP FUNCTION IF EXISTS public.trg_check_badge_flashcard_create() CASCADE;
DROP FUNCTION IF EXISTS public.trg_check_badge_note_upload() CASCADE;
DROP FUNCTION IF EXISTS public.trg_check_badge_review() CASCADE;
DROP FUNCTION IF EXISTS public.trg_check_badge_upvote() CASCADE;
DROP FUNCTION IF EXISTS public.notify_friend_request() CASCADE;
DROP FUNCTION IF EXISTS public.notify_friend_accepted() CASCADE;
DROP FUNCTION IF EXISTS public.notify_content_upvoted() CASCADE;

-- CASCADE here only matters if diagnostic query 1 finds a trigger still attached (it shouldn't
-- — that's the whole premise of "dead"). If a trigger IS found, CASCADE will drop that trigger
-- too; stop and re-verify before running if that's the case, since it changes the blast radius
-- from "dead code cleanup" to "removing live behavior."
