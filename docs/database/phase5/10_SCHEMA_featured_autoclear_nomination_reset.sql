-- Name: [SCHEMA] Featured Auto-Clear Also Resets Nomination Fields
-- Description: CREATE OR REPLACE of the existing fn_autoclear_featured_on_visibility_change()
-- (originally added in 04_SCHEMA_featured_landing_autoclear_triggers.sql) so that, in addition
-- to clearing is_featured_on_landing, it also nulls the four nomination/approval columns added
-- in 09_SCHEMA the moment a row's visibility leaves 'public' — a full reset on unpublish. This
-- is a function body replacement only: the BEFORE UPDATE triggers on flashcard_decks and notes
-- (trg_autoclear_featured_flashcard_decks / trg_autoclear_featured_notes) already point at this
-- function and do not need to be re-created.

CREATE OR REPLACE FUNCTION fn_autoclear_featured_on_visibility_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.visibility <> 'public' THEN
    NEW.is_featured_on_landing := false;
    NEW.featured_nominated_by := NULL;
    NEW.featured_nominated_at := NULL;
    NEW.featured_approved_by := NULL;
    NEW.featured_approved_at := NULL;
  END IF;
  RETURN NEW;
END;
$function$;
