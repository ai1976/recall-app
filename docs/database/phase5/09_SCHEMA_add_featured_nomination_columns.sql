-- Name: [SCHEMA] Add Featured Nomination/Approval Columns
-- Description: Adds the nomination/approval audit trail on top of the deployed S2
-- is_featured_on_landing flag (03_SCHEMA), for Phase 5 Sprint 3's two-step curation gate:
-- professors/admins nominate their own already-public decks/notes, admins/super_admins
-- approve. is_featured_on_landing = true continues to mean "approved & live" — these four
-- columns are purely additive audit/state fields layered on top; no S2 object is touched.
-- All four columns are nullable (NULL = never nominated / never approved) and
-- IF NOT EXISTS makes this safe to run multiple times.

ALTER TABLE flashcard_decks
  ADD COLUMN IF NOT EXISTS featured_nominated_by uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS featured_nominated_at timestamptz,
  ADD COLUMN IF NOT EXISTS featured_approved_by uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS featured_approved_at timestamptz;

ALTER TABLE notes
  ADD COLUMN IF NOT EXISTS featured_nominated_by uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS featured_nominated_at timestamptz,
  ADD COLUMN IF NOT EXISTS featured_approved_by uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS featured_approved_at timestamptz;
