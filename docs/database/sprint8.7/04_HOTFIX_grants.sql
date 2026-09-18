-- Name: [FIX] Sprint 8.7.1 hotfix — provenance SELECT grant + anon EXECUTE revoke
--
-- Description: Fixes two grant issues surfaced by a live run of 03_TEST (T1 and T8b):
--
-- T1: REVOKE ALL in 01_SCHEMA stripped table-level SELECT from `authenticated` on
-- flashcard_batch_provenance. The flashcards INSERT policy's EXISTS(...) subquery
-- needs base SELECT privilege just to run — without it, Postgres throws a hard
-- "permission denied for table" instead of evaluating the RLS-filtered subquery.
-- The insert was still blocked (same net effect), but ungracefully, and this would
-- also permanently break the EXISTS() check's ability to ever see a real match, which
-- matters once 8.7.4 needs it to work correctly. Fix: grant table-level SELECT to
-- authenticated, but add ZERO RLS SELECT policy — with RLS enabled and no policy,
-- authenticated still gets 0 rows back (nothing becomes readable), so this is not
-- "the read policy" from 8.7.4, just the base grant the subquery mechanically needs.
--
-- T8b: anon could execute create_flashcard_batches despite `REVOKE ALL ... FROM PUBLIC`
-- in 02_FUNCTIONS. This project has a default-privileges rule that grants EXECUTE on
-- new functions directly to anon/authenticated (not routed through PUBLIC) — the same
-- pattern Step 0's diagnostic saw on table grants. REVOKE FROM PUBLIC doesn't touch
-- anon's own separate grant; anon must be revoked explicitly.
--
-- Run AFTER 01_SCHEMA + 02_FUNCTIONS, BEFORE re-running 03_TEST.

BEGIN;

GRANT SELECT ON public.flashcard_batch_provenance TO authenticated;
-- No RLS SELECT policy is added — RLS stays enabled with zero policies for
-- authenticated, so this grant does NOT make provenance rows readable; it only
-- lets the EXISTS() subquery inside the flashcards INSERT policy execute at all.

REVOKE ALL ON FUNCTION public.create_flashcard_batches(text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_flashcard_batches(text, text, jsonb) TO authenticated;

COMMIT;
