-- Name: [SCHEMA] Featured Landing Partial Indexes
-- Description: Partial indexes on flashcard_decks and notes for the
-- get_featured_landing_content() RPC hot path (06_FUNCTIONS_get_featured_landing_content.sql).
-- Only indexes rows where is_featured_on_landing = true, which will always be a tiny fraction
-- of total rows since featuring is curated (Sprint 3 UI), not self-service. IF NOT EXISTS
-- makes this safe to run multiple times.

CREATE INDEX IF NOT EXISTS idx_flashcard_decks_featured
  ON flashcard_decks (is_featured_on_landing)
  WHERE is_featured_on_landing = true;

CREATE INDEX IF NOT EXISTS idx_notes_featured
  ON notes (is_featured_on_landing)
  WHERE is_featured_on_landing = true;
