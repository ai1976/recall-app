-- Name: [SCHEMA] Sprint 8.7.1 — content provenance foundation
--
-- Description: Creates the DB-side foundation for content-source tagging.
-- (1) flashcard_batch_provenance — one row per batch_id, source declared at
--     batch level; absence of a row = legacy/unknown, read via LEFT JOIN, never
--     backfilled. RLS enabled, no INSERT policy for authenticated — direct writes
--     are blocked; only the SECURITY DEFINER RPC in 02_FUNCTIONS can populate it.
-- (2) notes.content_source_type / content_source_name — row-level provenance,
--     enforced only on INSERT via trigger (not CHECK, so legacy NULL rows stay
--     editable — see fn_require_note_provenance comment below).
-- (3) Extends the existing flashcards INSERT policy so a direct client insert
--     into flashcards now requires a matching provenance row to already exist
--     for that batch_id.
--
-- *** BREAKING CHANGE WARNING ***
-- Per Step 0 diagnostic (00_DIAGNOSTIC_pre_provenance.sql, section 2a), the LIVE
-- policy name is "Users can insert their own flashcards" (not users_insert_flashcards
-- as assumed in the sprint 8.7.1 prompt — same logic, different display name; this
-- file uses the verified live name). FlashcardCreate.jsx and BulkUploadFlashcards.jsx
-- currently INSERT directly into flashcards and do NOT create a provenance row first.
-- Once this file is deployed, EVERY direct flashcard creation in production will start
-- failing (RLS violation) until those pages are migrated to call create_flashcard_batches()
-- in Sprint 8.7.2/8.7.3. This is intentional per the sprint 8.7.1 spec's non-goals
-- ("frontend creation paths intentionally still incompatible/unmigrated"), but it means
-- flashcard creation for all ~161 active students breaks the moment this runs. Confirm
-- deployment timing (and how close 8.7.2 will follow) before running this in the SQL Editor.
--
-- Prerequisite: 00_DIAGNOSTIC_pre_provenance.sql has been run and its output reconciled
-- against this file (done — see diagnostic results captured 18/09/2026).

BEGIN;

-- ── 1. flashcard_batch_provenance ──────────────────────────────────────────
CREATE TABLE public.flashcard_batch_provenance (
  batch_id uuid PRIMARY KEY,
  content_source_type text NOT NULL
    CHECK (content_source_type IN ('official_body', 'original_creator')),
  content_source_name text NOT NULL
    CHECK (btrim(content_source_name) <> ''),
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.flashcard_batch_provenance ENABLE ROW LEVEL SECURITY;

-- No INSERT/UPDATE/DELETE/SELECT policy for authenticated is created here —
-- with RLS enabled and zero policies, authenticated/anon get zero rows and
-- zero writes by default. Belt-and-suspenders: this project's tables have been
-- observed (Step 0 diagnostic, sections 3a/3b) to carry broad table-level GRANTs
-- to anon/authenticated (DELETE/INSERT/SELECT/TRUNCATE/UPDATE), almost certainly
-- via an ALTER DEFAULT PRIVILEGES rule that fires on every new table. Explicitly
-- revoke on this table rather than trusting RLS alone to be the only gate.
REVOKE ALL ON public.flashcard_batch_provenance FROM PUBLIC, anon, authenticated;

-- Re-grant table-level SELECT to authenticated only (04_HOTFIX, folded in here for
-- anyone reading this as the source of truth). This does NOT make provenance rows
-- readable — RLS stays enabled with zero SELECT policy, so authenticated still gets
-- 0 rows back on any direct query. It exists purely so the EXISTS(...) subquery in
-- the flashcards INSERT policy below can execute at all: without base SELECT grant,
-- Postgres throws a hard "permission denied for table" instead of gracefully
-- evaluating the RLS-filtered subquery to "0 rows -> false". Confirmed live: without
-- this grant, T1 in 03_TEST still blocked the insert, but via a permission error
-- rather than the intended RLS rejection.
GRANT SELECT ON public.flashcard_batch_provenance TO authenticated;

COMMENT ON TABLE public.flashcard_batch_provenance IS
  'One row per flashcard batch_id declaring its content source. Absence of a row for a given batch_id means legacy/unknown provenance (pre-8.7.1) — read via LEFT JOIN, never backfilled. Writable only through create_flashcard_batches() (SECURITY DEFINER).';

-- ── 2. notes provenance columns + INSERT-only enforcement trigger ─────────
ALTER TABLE public.notes
  ADD COLUMN content_source_type text
    CHECK (content_source_type IS NULL OR content_source_type IN ('official_body', 'original_creator')),
  ADD COLUMN content_source_name text;

CREATE OR REPLACE FUNCTION public.fn_require_note_provenance()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.content_source_type IS NULL
     OR NEW.content_source_name IS NULL
     OR btrim(NEW.content_source_name) = '' THEN
    RAISE EXCEPTION 'content_source_type and content_source_name are required on note creation';
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_require_note_provenance() IS
  'BEFORE INSERT only (not a CHECK constraint) so legacy pre-8.7.1 notes with NULL provenance remain editable — a CHECK would be re-evaluated on every UPDATE and either block harmless edits to legacy rows or, if loosened enough to allow that, equally allow NULL provenance on brand-new inserts.';

CREATE TRIGGER trg_require_note_provenance
BEFORE INSERT ON public.notes
FOR EACH ROW EXECUTE FUNCTION public.fn_require_note_provenance();

-- ── 3. Extend flashcards direct-INSERT policy to require provenance ───────
-- Live policy name confirmed in Step 0 (section 2a): "Users can insert their
-- own flashcards" (PERMISSIVE, INSERT, roles: PUBLIC/null i.e. all roles).
-- Original WITH CHECK: (auth.uid() = user_id)
-- The separate RESTRICTIVE policy flashcards_gate_verdict_types_insert (D-10)
-- is untouched — it ANDs with this one regardless of this policy's body.
ALTER POLICY "Users can insert their own flashcards" ON public.flashcards
  WITH CHECK (
    (auth.uid() = user_id)
    AND EXISTS (
      SELECT 1 FROM public.flashcard_batch_provenance p
      WHERE p.batch_id = flashcards.batch_id
    )
  );

COMMIT;
