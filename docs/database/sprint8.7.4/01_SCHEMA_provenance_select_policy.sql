-- Name: [SCHEMA] Sprint 8.7.4 — flashcard_batch_provenance read policy
--
-- Description: D-21's deliberately-deferred read policy (8.7.1/8.7.2 both left
-- this at zero SELECT policies — see DATABASE_SCHEMA.md §2.3A). Adds a single
-- unconditional `authenticated` SELECT policy, not an attempt to mirror
-- flashcards' own visibility rules (private/friends/public) inside a subquery
-- against this table.
--
-- Reasoning (flagged in the sprint brief as a judgment call, not a technical
-- constraint — recorded here for the record): provenance content is a source
-- type + a name ("ICAI", "More Classes Commerce"), not the flashcard content
-- itself. Mirroring flashcards' full visibility logic here would re-litigate
-- D-04/visibility rules inside a second table and is a real place to introduce
-- a subtle bug, for a privacy gain that doesn't exist — a curious authenticated
-- user learning that some batch_id they can't otherwise see belongs to "ICAI"
-- is not a real exposure. This does NOT grant access to flashcards.* content —
-- flashcards keeps its own RLS unchanged; this only unlocks the provenance
-- label for a batch_id the client already has.
--
-- Table-level GRANT SELECT TO authenticated already exists (04_HOTFIX_grants.sql,
-- 8.7.1) — that grant made the EXISTS() subquery in the flashcards INSERT policy
-- work but intentionally left 0 rows readable (RLS enabled, no SELECT policy).
-- This file adds the actual SELECT policy; no grant change needed.

BEGIN;

CREATE POLICY authenticated_read_flashcard_batch_provenance
  ON public.flashcard_batch_provenance
  FOR SELECT
  TO authenticated
  USING (true);

COMMENT ON POLICY authenticated_read_flashcard_batch_provenance
  ON public.flashcard_batch_provenance IS
  'Sprint 8.7.4, D-21 display. Unconditional read for any authenticated user — provenance (source type + name) is not sensitive per-batch content, unlike the flashcards themselves, whose own RLS is untouched by this policy.';

COMMIT;

-- PostgREST: pick up the new policy immediately rather than waiting for the
-- next schema-cache refresh interval.
NOTIFY pgrst, 'reload schema';
