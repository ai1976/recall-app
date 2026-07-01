-- Name: [SCHEMA] Add is_featured_on_landing Column
-- Description: Adds the is_featured_on_landing boolean flag to flashcard_decks and notes,
-- with an inline CHECK enforcing featured content must be public. DEFAULT false means every
-- existing row (161 users, 2182 flashcards, 128 notes) satisfies the CHECK on creation — zero
-- migration risk. Curation UI that actually sets this flag ships in Sprint 3; this script only
-- adds the column + integrity constraint. IF NOT EXISTS makes this safe to run multiple times.

ALTER TABLE flashcard_decks
ADD COLUMN IF NOT EXISTS is_featured_on_landing boolean NOT NULL DEFAULT false
CHECK (is_featured_on_landing = false OR visibility = 'public');

ALTER TABLE notes
ADD COLUMN IF NOT EXISTS is_featured_on_landing boolean NOT NULL DEFAULT false
CHECK (is_featured_on_landing = false OR visibility = 'public');
