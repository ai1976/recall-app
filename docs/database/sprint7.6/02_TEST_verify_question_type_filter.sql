-- Name: [TEST] Verify get_browsable_decks question_type filter
-- Description: get_browsable_decks() requires auth.uid(), which is NULL under the SQL Editor's
-- default `postgres` role (RAISE EXCEPTION 'Not authenticated') — same as every prior version.
-- This test impersonates a real profile via SET LOCAL ROLE authenticated + request.jwt.claims
-- (the technique PostgREST itself uses, matching docs/database/sprint7.5/02_TEST_verify_d10_role_gate.sql
-- and docs/database/landmines/11_TEST_verify_visibility_rls_matrix.sql), then confirms: (1) omitting
-- the arg reproduces the unfiltered row count, (2) 'flashcard'/'mcq' each narrow it, (3) a deck
-- mixing both types appears under both filters (the "at least one card of that type" semantic),
-- and (5) card_count stays whole-deck (not type-narrowed) even when filtering.
--
-- Self-contained and read-only: wrapped in BEGIN/ROLLBACK, no writes, safe to re-run anytime.
-- Picks the first available profile automatically — pass a specific id below if you want to
-- test as a particular account (e.g. one you know owns a mixed flashcard+mcq deck from 7.5).

BEGIN;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM public.profiles ORDER BY created_at LIMIT 1), 'role', 'authenticated')::text,
  true);

-- 1. Baseline — no filter (must match pre-migration row count for this account)
SELECT count(*) AS unfiltered_deck_count FROM get_browsable_decks();

-- 2. Flashcard-only narrowing
SELECT count(*) AS flashcard_deck_count FROM get_browsable_decks('flashcard');

-- 3. MCQ-only narrowing
SELECT count(*) AS mcq_deck_count FROM get_browsable_decks('mcq');

-- 4. An unused type must return zero decks, not error
SELECT count(*) AS theory_deck_count FROM get_browsable_decks('theory');

-- 5. Full rows side by side — eyeball a deck id present in BOTH the flashcard and mcq result
-- sets (proves "at least one card of that type", since a mixed deck isn't exclusive to either),
-- and confirm each row's card_count matches its value in the unfiltered call (whole-deck count,
-- not narrowed to the filtered type).
SELECT 'unfiltered' AS filter, id, subject_name, topic_name, card_count FROM get_browsable_decks()
UNION ALL
SELECT 'flashcard', id, subject_name, topic_name, card_count FROM get_browsable_decks('flashcard')
UNION ALL
SELECT 'mcq', id, subject_name, topic_name, card_count FROM get_browsable_decks('mcq')
ORDER BY id, filter;

RESET ROLE;

ROLLBACK; -- read-only test; nothing to undo, but consistent with project convention
