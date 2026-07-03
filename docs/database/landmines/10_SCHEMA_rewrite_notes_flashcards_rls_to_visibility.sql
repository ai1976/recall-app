-- Name: [SCHEMA] Rewrite notes + flashcards PUBLIC-read RLS predicate onto visibility
-- Description: Stage A of the L2 is_public -> visibility RLS migration (blueprint.md §1.11 #2).
-- CORRECTED against live 09_DIAGNOSTIC output (02/07/2026) — the original draft assumed policy
-- names/roles that do not match live reality. Key findings from 09:
--   - The friends tier is ALREADY enforced by live policies "Users can view friends notes" /
--     "Users can view friends flashcards" (both already `visibility='friends' AND EXISTS(accepted
--     friendship)`). blueprint §1.11's "friends tier never enforced in RLS" claim was WRONG (it
--     only looked at the public policy). So this script creates NO friends policy.
--   - Live policy names have spaces ("Users can view public notes"), and role targeting is
--     TO {public}. Locked decision 02/07/2026: PRESERVE TO public — anon reads PUBLIC content
--     directly (already the case pre-migration; private/friends are correctly excluded).
--   - Live predicates (09 Block 2): notes = `is_public = true`; flashcards = `is_public = true
--     OR visibility = 'public'`. 09 Block 5 confirmed `is_public=true` <=> `visibility='public'`
--     with ZERO drift on both tables → this swap is DATA-EQUIVALENT (no row changes visibility).
--   - 09 Block 3: no view/rule depends on is_public. After this swap, 09 Block 2's two policies
--     are the ONLY is_public references, so Stage B (12_SCHEMA) can then drop the column.
--
-- Uses ALTER POLICY (NOT DROP/CREATE): changes only the USING predicate in place — policy name,
-- roles (TO public), and cmd are preserved exactly. Friends / own / admin policies untouched.
--
-- REVERSIBLE — rollback restores the exact live predicates:
--   ALTER POLICY "Users can view public notes" ON public.notes USING (is_public = true);
--   ALTER POLICY "Users can view public flashcards" ON public.flashcards
--     USING (is_public = true OR visibility = 'public');
--
-- Deploy gate: after deploying, run 11_TEST in full — every "stranger/anon cannot see
-- friends/private" assertion must PASS before Stage B (12_SCHEMA) is drafted for deployment.

ALTER POLICY "Users can view public notes" ON public.notes
  USING (visibility = 'public');

ALTER POLICY "Users can view public flashcards" ON public.flashcards
  USING (visibility = 'public');
