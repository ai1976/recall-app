-- Name: [SCHEMA] Rewrite notes + flashcards public/friends-read RLS onto visibility
-- Description: Stage A of the L2 is_public -> visibility RLS migration (blueprint.md
-- §1.11 landmine #2). Replaces the is_public-keyed public-read policies on `notes` and
-- `flashcards` with visibility-keyed ones, and ADDS the friends-tier policy that has never
-- existed in RLS (today `visibility='friends'` rows are only reachable by the owner — the
-- friends tier is UI-only and silently blocked by RLS for everyone else). Does NOT touch
-- is_public itself, INSERT/UPDATE/DELETE policies, or role targeting.
--
-- PREREQUISITE: run 09_DIAGNOSTIC first. If query 1's live `qual` text differs from the
-- ROLLBACK comments below, update those comments to match the live text before deploying —
-- the rollback must reproduce exactly what was live, not what the docs assumed.
--
-- Reversible: every DROP POLICY below is preceded by a ROLLBACK comment with the exact
-- CREATE POLICY needed to restore the pre-migration behavior. To roll back, run the four
-- ROLLBACK statements and DROP the four new/replaced policies this script creates.
--
-- Deploy gate: do not deploy until the founder has reviewed 09_DIAGNOSTIC output (especially
-- the query 5 drift check) and the matrix in 11_TEST is written and reviewed. After deploy,
-- run 11_TEST in full — every "stranger/anon cannot see friends/private" assertion must PASS
-- before Stage B (12_SCHEMA) is even drafted for deployment.

BEGIN;

-- ============================================
-- NOTES
-- ============================================

-- ROLLBACK (restores pre-migration behavior — confirm against 09_DIAGNOSTIC query 1 first):
--   CREATE POLICY users_view_public_notes ON public.notes
--     FOR SELECT TO authenticated USING (is_public = true);
DROP POLICY IF EXISTS users_view_public_notes ON public.notes;
CREATE POLICY users_view_public_notes ON public.notes
  FOR SELECT TO authenticated
  USING (visibility = 'public');

-- New — the friends tier has never been enforced in RLS before this. Bidirectional:
-- either side of an accepted friendship can read the other's visibility='friends' rows.
-- ROLLBACK: DROP POLICY users_view_friends_notes ON public.notes;
DROP POLICY IF EXISTS users_view_friends_notes ON public.notes;
CREATE POLICY users_view_friends_notes ON public.notes
  FOR SELECT TO authenticated
  USING (
    visibility = 'friends'
    AND EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE f.status = 'accepted'
        AND (
          (f.user_id = auth.uid() AND f.friend_id = notes.user_id)
          OR (f.friend_id = auth.uid() AND f.user_id = notes.user_id)
        )
    )
  );

-- Untouched, listed for completeness (owner + super_admin already cover private/friends
-- for their own audience — no change needed):
--   users_view_own_notes    FOR SELECT TO authenticated USING (user_id = auth.uid())
--   super_admin_view_all_notes FOR SELECT TO authenticated USING (role = 'super_admin')
--   users_insert_notes, users_update_own_notes, users_delete_own_notes — unchanged

-- ============================================
-- FLASHCARDS
-- ============================================

-- ROLLBACK (restores pre-migration behavior — confirm against 09_DIAGNOSTIC query 1 first;
-- blueprint.md §1.11 #2 records this predicate as `is_public = true OR visibility =
-- 'public'`, DATABASE_SCHEMA.md records it as `is_public = true` — use whichever query 1
-- actually returns):
--   CREATE POLICY users_view_public_flashcards ON public.flashcards
--     FOR SELECT TO authenticated USING (is_public = true OR visibility = 'public');
DROP POLICY IF EXISTS users_view_public_flashcards ON public.flashcards;
CREATE POLICY users_view_public_flashcards ON public.flashcards
  FOR SELECT TO authenticated
  USING (visibility = 'public');

-- New — same friends-tier gap as notes. StudyMode.jsx already queries with
-- `visibility.eq.friends` in its client-side .or() filter today, but RLS has never actually
-- granted that access (is_public is false on friends-tier rows), so it has been a silent
-- no-op for every user. This is the fix.
-- ROLLBACK: DROP POLICY users_view_friends_flashcards ON public.flashcards;
DROP POLICY IF EXISTS users_view_friends_flashcards ON public.flashcards;
CREATE POLICY users_view_friends_flashcards ON public.flashcards
  FOR SELECT TO authenticated
  USING (
    visibility = 'friends'
    AND EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE f.status = 'accepted'
        AND (
          (f.user_id = auth.uid() AND f.friend_id = flashcards.user_id)
          OR (f.friend_id = auth.uid() AND f.user_id = flashcards.user_id)
        )
    )
  );

-- Untouched, listed for completeness:
--   users_view_own_flashcards FOR SELECT TO authenticated USING (user_id = auth.uid())
--   super_admin_view_all_flashcards FOR SELECT TO authenticated USING (role = 'super_admin')
--   users_insert_flashcards, users_update_own_flashcards, users_delete_own_flashcards — unchanged

COMMIT;

-- Post-deploy: run 11_TEST_verify_visibility_rls_matrix.sql in full before touching Stage B.
