-- Name: [DIAGNOSTIC] Introspect Existing Preview RPCs
-- Description: Retrieves the full function definitions for get_public_deck_preview and
-- get_public_note_preview so the new Sprint 2 featured-content RPC
-- (get_featured_landing_content) can mirror their exact joins, column names, and
-- SECURITY DEFINER conventions instead of guessing. Run once before writing any Sprint 2 SQL.
-- Read-only — safe to run anytime.

SELECT pg_get_functiondef('public.get_public_deck_preview'::regproc);
SELECT pg_get_functiondef('public.get_public_note_preview'::regproc);
