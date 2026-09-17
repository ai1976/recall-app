-- Name: [FIX] Sprint 8.6c hotfix — drop the stale 5-arg apply_review overload
--
-- Description: 02_FUNCTIONS_apply_review_selected_answer.sql's own header claimed
-- "appending a defaulted trailing parameter to an existing overload replaces it in
-- place; it does NOT create a second overload" — that claim was WRONG, disproven
-- live: running 02_FUNCTIONS left TWO apply_review functions on the server (the
-- original 5-param one from Sprint 7.4, untouched, plus the new 6-param one),
-- because `CREATE OR REPLACE FUNCTION` only replaces a function with the exact
-- same parameter signature — a changed parameter list (even one that only ADDS a
-- trailing DEFAULT-ed parameter) is a distinct overload to Postgres. This is the
-- identical class of bug already documented at blueprint.md §1.11 for
-- get_browsable_decks v5 (fixed there with an explicit DROP FUNCTION before the
-- CREATE OR REPLACE) — this sprint's own pre-flight named that exact risk and then
-- reproduced it anyway by trusting the wrong claim instead of the project's own
-- established pattern.
--
-- Confirmed live (03_TEST run) via the resulting error:
--   ERROR: 42725: function public.apply_review(uuid, uuid, unknown, boolean, unknown) is not unique
-- — proof both overloads exist and PostgREST/PL-pgSQL cannot resolve a 5-arg call.
--
-- Fix: DROP the old 5-arg overload explicitly by its exact signature. The 6-arg
-- version (created by 02_FUNCTIONS) is left untouched and becomes the only
-- surviving apply_review — its own GRANT/REVOKE (already run in 02_FUNCTIONS)
-- stays in effect, unaffected by dropping a different function. submit_review's
-- 5-positional-argument call (`apply_review(p_user_id, p_flashcard_id, p_rating,
-- NULL, NULL)`) resolves correctly against the sole remaining 6-arg function once
-- this runs — Postgres allows a call to omit trailing DEFAULT-ed parameters when
-- exactly one candidate function exists.
--
-- Run this BEFORE re-running 03_TEST.

BEGIN;

DROP FUNCTION IF EXISTS public.apply_review(uuid, uuid, text, boolean, text);

COMMIT;

-- ── PostgREST: pick up the now-unambiguous signature ────────────────────────
NOTIFY pgrst, 'reload schema';
