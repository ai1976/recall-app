-- Name: [DIAGNOSTIC] Sprint 7.8 pre-flight — live question_type CHECK + D-10 policy string match
--
-- Description: Run BEFORE any 7.8 SCHEMA change. The kickoff explicitly asks to confirm,
-- against the LIVE database (not blueprint.md's memory of it), two things before touching
-- match_the_following:
--   1. Does 'match_the_following' already exist EXACTLY as that string in the live
--      chk_flashcards_question_type CHECK constraint? Docs (DATABASE_SCHEMA.md §2.3,
--      blueprint.md D-10) claim it was added alongside mcq/true_false/etc. back in
--      Sprint 7.5, but Sprint 7.5's own diagnostic caught the docs assuming
--      'fill_in_the_blanks' was live when the real value was 'fitb' — so this is
--      re-verified from pg_get_constraintdef, not assumed from the docs.
--   2. Does the D-10 RESTRICTIVE policy pair's IN-list use the SAME exact string?
--      A mismatch here (as with the fitb naming catch) would leave the type
--      completely ungated, since `question_type NOT IN (...)` passes unconditionally
--      for any string not in the list.
--
-- If both already contain 'match_the_following' correctly: 7.8-A needs ZERO SQL,
-- same "real finding: needed zero SQL" outcome as true_false/correct_incorrect in 7.7.
-- If either doesn't: a small additive [SCHEMA] migration is required before any
-- frontend authoring/rendering work ships.

-- 1. Live CHECK constraint definition — read the exact IN-list from this, do not
--    hand-type it from blueprint.md or DATABASE_SCHEMA.md.
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.flashcards'::regclass
  AND conname = 'chk_flashcards_question_type';

-- 2. D-10 RESTRICTIVE policy IN-list — confirm 'match_the_following' is already in it
--    (per docs/database/sprint7.5/01_SCHEMA_d10_role_gate.sql, which was drafted to
--    cover all 7 verdict-bearing types at once).
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 3. Any existing rows already using this type (sanity check only — expect 0, since
--    there is no authoring UI for it yet anywhere in the app).
SELECT question_type, count(*)
FROM public.flashcards
WHERE question_type = 'match_the_following'
GROUP BY question_type;
