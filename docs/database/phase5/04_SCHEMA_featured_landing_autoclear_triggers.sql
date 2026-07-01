-- Name: [SCHEMA] Featured Landing Auto-Clear Triggers
-- Description: BEFORE UPDATE trigger on flashcard_decks and notes that clears
-- is_featured_on_landing back to false the instant a row's visibility leaves 'public'.
-- This guarantees the CHECK constraint added in 03_SCHEMA_add_is_featured_on_landing_column.sql
-- can never reject a visibility-downgrade UPDATE, and correctly revokes a featured item from
-- the landing page the moment it's unpublished. One shared trigger function is reused by both
-- tables since the logic and column names (visibility, is_featured_on_landing) are identical.
-- Collision check: 02_DIAGNOSTIC_trigger_collision_scan.sql confirmed flashcard_decks has NO
-- existing triggers at all, and notes has no BEFORE UPDATE trigger (only AFTER UPDATE
-- trg_auto_resolve_note_flags) — no collision risk. DROP TRIGGER IF EXISTS makes this
-- safe to run multiple times.

CREATE OR REPLACE FUNCTION fn_autoclear_featured_on_visibility_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.visibility <> 'public' THEN
    NEW.is_featured_on_landing := false;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_autoclear_featured_flashcard_decks ON flashcard_decks;
CREATE TRIGGER trg_autoclear_featured_flashcard_decks
  BEFORE UPDATE ON flashcard_decks
  FOR EACH ROW
  EXECUTE FUNCTION fn_autoclear_featured_on_visibility_change();

DROP TRIGGER IF EXISTS trg_autoclear_featured_notes ON notes;
CREATE TRIGGER trg_autoclear_featured_notes
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION fn_autoclear_featured_on_visibility_change();
