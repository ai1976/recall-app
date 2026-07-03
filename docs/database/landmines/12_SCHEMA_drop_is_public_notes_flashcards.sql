-- Name: [SCHEMA] Drop is_public on notes + flashcards
-- Description: Stage B (final step) of the L2 is_public -> visibility RLS migration
-- (blueprint.md §1.11 landmine #2). Drops the now-fully-unused `is_public` boolean from
-- both tables. `idx_notes_is_public` / `idx_flashcards_is_public` drop automatically with
-- their column — no separate DROP INDEX needed.
--
-- HARD PREREQUISITES — do not deploy until ALL of these are true:
--   1. 10_SCHEMA (Stage A) is deployed live and every cell in 11_TEST is PASS, including
--      the [CRITICAL] stranger/anon rows.
--   2. The frontend Stage B change (strip `is_public` from every insert/update payload —
--      see the L2 report / changelog entry for the exact file list) is deployed to
--      production AND verified: create a note and a flashcard live, confirm they still
--      save and their visibility toggle still works.
--   3. Re-run 09_DIAGNOSTIC query 3 (pg_depend) immediately before this deploy — confirm
--      it still returns zero rows for is_public. If a view/rule was added since the
--      original audit, STOP.
--   4. Re-run 09_DIAGNOSTIC query 2 — confirm no policy anywhere still references is_public
--      (10_SCHEMA should have already cleared notes/flashcards; this is the final check
--      before the column that backs those old predicates is gone for good).
--
-- ROLLBACK (schema-level only — restores the column and re-syncs it from visibility as the
-- best available reconstruction; does NOT recover any pre-drop drift caught by
-- 09_DIAGNOSTIC query 5, since that data is gone once this commits):
--   ALTER TABLE public.notes ADD COLUMN is_public boolean NOT NULL DEFAULT false;
--   UPDATE public.notes SET is_public = (visibility = 'public');
--   CREATE INDEX idx_notes_is_public ON public.notes(is_public);
--   ALTER TABLE public.flashcards ADD COLUMN is_public boolean NOT NULL DEFAULT false;
--   UPDATE public.flashcards SET is_public = (visibility = 'public');
--   CREATE INDEX idx_flashcards_is_public ON public.flashcards(is_public);
-- (Adjust NOT NULL/DEFAULT to match whatever 09_DIAGNOSTIC query 4b showed for the live
-- column before it was dropped, if different from the assumption above.)

BEGIN;

ALTER TABLE public.notes DROP COLUMN is_public;
ALTER TABLE public.flashcards DROP COLUMN is_public;

COMMIT;

-- Post-deploy: run 13_TEST_verify_insert_without_is_public.sql, then re-run
-- 11_TEST_verify_visibility_rls_matrix.sql (after removing `is_public` from its two fixture
-- INSERT statements per the note at the top of that file — the column no longer exists).
