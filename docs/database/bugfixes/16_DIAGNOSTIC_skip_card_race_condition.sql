-- Name: [DIAGNOSTIC] skip_card / suspend_card — confirm live body before the atomic-upsert fix
-- Description: Reproduced live 14/09/2026 — clicking "Skip 24hr" on a never-reviewed card threw
-- `23505 duplicate key value violates reviews_user_flashcard_unique`. Two candidate bodies exist in
-- docs history (docs/database/bugfixes/09_FUNCTIONS_fix_skip_suspend_card_reviews_columns.sql —
-- corrected easiness/repetition columns — and the earlier, explicitly-flagged-buggy
-- docs/database/security/02b_FUNCTIONS_idor_guard_single_card.sql). Both use the SAME non-atomic
-- shape: `UPDATE ...; IF NOT FOUND THEN INSERT ...` — a classic TOCTOU race. Two near-simultaneous
-- calls for the same (user_id, flashcard_id) with no existing review row can both see "NOT FOUND" on
-- their UPDATE and both attempt the INSERT; the loser hits the unique constraint. This session has
-- only the anon key — run in Supabase SQL Editor and report back before the fix runs, per CLAUDE.md's
-- "introspect, don't assume the docs" discipline (the exact live body must be confirmed, not guessed
-- from either docs candidate, before a blind CREATE OR REPLACE).

-- 1. The exact live body of both functions.
SELECT p.proname, pg_get_functiondef(p.oid) AS live_body
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('skip_card', 'suspend_card')
ORDER BY p.proname;

-- 2. Confirm the unique constraint name/columns (from the live 23505 error).
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conname = 'reviews_user_flashcard_unique';

-- 3. reviews table's real column list + types (needed to write a correct ON CONFLICT DO UPDATE).
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'reviews'
ORDER BY ordinal_position;
