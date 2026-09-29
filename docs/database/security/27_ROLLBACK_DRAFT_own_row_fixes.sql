-- Name: [SCHEMA] ROLLBACK - undo the friendships guard (24) and the reviews privilege revoke (25)
-- Status: DRAFT (pairs with 24/25). Reverts each independently; run only the part that needs reverting.
-- Description: Removing the friendships guard re-opens self-accepted friendships; re-granting reviews writes
--   re-opens direct SRS writes. Treat as temporary and report which real flow broke.

-- Undo 24
DROP TRIGGER IF EXISTS trg_guard_friendships_client_writes ON public.friendships;
DROP FUNCTION IF EXISTS public.fn_guard_friendships_client_writes();

-- Undo 25 (restores the privileges the catalog showed before: Supabase default grants)
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON public.reviews TO authenticated, anon;
