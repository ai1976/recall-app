-- Name: [DIAGNOSTIC] Sprint 7.7 pre-flight — get_browsable_decks overload count + live question_type CHECK
--
-- Description: Run BEFORE any 7.7 SCHEMA change. Two things this sprint's kickoff
-- explicitly asked to confirm before touching anything:
--   1. Exactly ONE live signature of get_browsable_decks exists (the 7.6 v5 one-arg
--      version) — no old zero-arg overload left behind. This is the exact landmine
--      class documented in blueprint.md §1.11 #3 and hit for real during Sprint 7.6
--      (an ADD-a-parameter CREATE OR REPLACE silently created a second overload
--      instead of replacing the function — fixed there with an explicit DROP FUNCTION
--      first; this query is the regression check that the fix stuck).
--   2. The LIVE chk_flashcards_question_type CHECK constraint definition, via
--      pg_get_constraintdef — not the docs. Sprint 7.5's own diagnostic caught the
--      docs assuming 'fill_in_the_blanks'/'test_your_understanding' were live when
--      they weren't; this sprint adds test_your_understanding as a real question_type
--      for the first time, so the ADD CONSTRAINT in 01_SCHEMA must be built from
--      whatever this query actually returns, not from blueprint.md's memory of it.

-- 1. get_browsable_decks — must return exactly ONE row.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_browsable_decks';

-- 2. Live CHECK constraint definition — copy the exact IN-list from this into 01_SCHEMA,
--    do not hand-type it from blueprint.md.
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.flashcards'::regclass
  AND conname = 'chk_flashcards_question_type';

-- 3. D-10 RESTRICTIVE policy IN-list — confirm true_false/correct_incorrect are already
--    in it (they should be, per docs/database/sprint7.5/01_SCHEMA_d10_role_gate.sql) so
--    7.7-A needs zero RLS changes, only the two new authoring surfaces.
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 4. Any existing rows already using the 4 new types (sanity check only — expect 0 for
--    test_your_understanding since it isn't insertable yet; flashcard/theory rows using
--    the front/back path already exist in volume and are irrelevant here).
SELECT question_type, count(*)
FROM public.flashcards
WHERE question_type IN ('true_false', 'correct_incorrect', 'theory', 'test_your_understanding')
GROUP BY question_type;
