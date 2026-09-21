-- ============================================================================
-- Sprint 8.7.6 — Merge-batches provenance rule (D-23), server-side enforcement.
-- Persistent DDL only. Run this file ALONE, with NO verification/ROLLBACK in the same run.
--
-- Name: [FUNCTIONS] Guard + cleanup triggers for flashcards.batch_id changes
-- Description: (1) BEFORE UPDATE OF batch_id, row-level: blocks any move of a card to a different
--   batch unless both batches have identical provenance (same type AND same name, exact match)
--   or both are legacy (no provenance row). Also blocks moves to/from NULL and moves into a batch
--   the card's owner does not already hold. (2) AFTER UPDATE, statement-level with transition
--   tables: deletes the provenance row of every batch that lost cards, only if zero flashcards
--   still carry that batch_id. Atomic with the merge (same statement/transaction).
-- Live-schema basis (Step 0, 21/09/2026): no existing trigger touches batch_id; authenticated has
--   SELECT only on flashcard_batch_provenance, so SECURITY DEFINER is required for the DELETE and
--   for RLS-independent existence/ownership checks. search_path fixed, unquoted list.
-- Error contract for the UI: SQLSTATE 'RV601' and message prefix 'MERGE_PROVENANCE_MISMATCH:'
--   (provenance rule) or 'MERGE_TARGET_INVALID:' (NULL / foreign / non-existent target batch).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_guard_flashcard_batch_move()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public
AS $$
DECLARE
  o_has  boolean;
  n_has  boolean;
  o_type text;
  o_name text;
  n_type text;
  n_name text;
BEGIN
  IF OLD.batch_id IS NULL OR NEW.batch_id IS NULL THEN
    RAISE EXCEPTION 'MERGE_TARGET_INVALID: cards without a batch cannot be merged or moved into or out of a batch.'
      USING ERRCODE = 'RV601';
  END IF;

  -- Target batch must already exist and be held only by this card's owner (owner data, not auth.uid()).
  IF NOT EXISTS (SELECT 1 FROM public.flashcards f
                  WHERE f.batch_id = NEW.batch_id AND f.user_id = OLD.user_id AND f.id <> OLD.id)
     OR EXISTS (SELECT 1 FROM public.flashcards f
                 WHERE f.batch_id = NEW.batch_id AND f.user_id <> OLD.user_id) THEN
    RAISE EXCEPTION 'MERGE_TARGET_INVALID: cards can only be merged into an existing batch that belongs to the same owner.'
      USING ERRCODE = 'RV601';
  END IF;

  SELECT p.content_source_type, p.content_source_name INTO o_type, o_name
    FROM public.flashcard_batch_provenance p WHERE p.batch_id = OLD.batch_id;
  o_has := FOUND;
  SELECT p.content_source_type, p.content_source_name INTO n_type, n_name
    FROM public.flashcard_batch_provenance p WHERE p.batch_id = NEW.batch_id;
  n_has := FOUND;

  IF o_has <> n_has
     OR (o_has AND (o_type IS DISTINCT FROM n_type OR o_name IS DISTINCT FROM n_name)) THEN
    RAISE EXCEPTION 'MERGE_PROVENANCE_MISMATCH: these batches cannot be merged because their content sources differ (same source type and source name are required, or both must have no source recorded).'
      USING ERRCODE = 'RV601';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_cleanup_orphan_batch_provenance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public
AS $$
BEGIN
  -- Ordinary updates (no batch_id actually changed) return immediately.
  IF NOT EXISTS (SELECT 1 FROM old_rows o JOIN new_rows n ON n.id = o.id
                  WHERE o.batch_id IS DISTINCT FROM n.batch_id) THEN
    RETURN NULL;
  END IF;

  -- One batch-level pass: source batches that lost cards and now have zero cards left.
  DELETE FROM public.flashcard_batch_provenance p
   WHERE p.batch_id IN (SELECT DISTINCT o.batch_id
                          FROM old_rows o JOIN new_rows n ON n.id = o.id
                         WHERE o.batch_id IS NOT NULL
                           AND o.batch_id IS DISTINCT FROM n.batch_id)
     AND NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.batch_id = p.batch_id);

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_guard_flashcard_batch_move()      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_cleanup_orphan_batch_provenance() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_flashcard_batch_move ON public.flashcards;
CREATE TRIGGER trg_guard_flashcard_batch_move
  BEFORE UPDATE OF batch_id ON public.flashcards
  FOR EACH ROW
  WHEN (OLD.batch_id IS DISTINCT FROM NEW.batch_id)
  EXECUTE FUNCTION public.fn_guard_flashcard_batch_move();

-- Transition tables cannot be combined with a column list, so this fires on every flashcards
-- UPDATE statement and exits at once when no batch_id changed.
DROP TRIGGER IF EXISTS trg_cleanup_orphan_batch_provenance ON public.flashcards;
CREATE TRIGGER trg_cleanup_orphan_batch_provenance
  AFTER UPDATE ON public.flashcards
  REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.fn_cleanup_orphan_batch_provenance();
