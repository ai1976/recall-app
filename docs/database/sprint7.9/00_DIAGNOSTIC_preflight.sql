-- Name: [DIAGNOSTIC] Sprint 7.9 pre-flight — test_your_understanding collapse,
--       explanation column split, integrated_case removal
--
-- Description: Run BEFORE any 7.9 SCHEMA change. Confirms, against the LIVE
-- database (not blueprint.md's memory of it), everything the sprint's three
-- hygiene items depend on:
--   1. Exact current chk_flashcards_question_type CHECK constraint definition.
--   2. Row count + full row detail for question_type='test_your_understanding'
--      (needs manual classification into theory/subtype if any rows exist).
--   3. Row count for question_type='integrated_case' (expected 0 — if nonzero,
--      STOP, do not proceed, report back — something inserted outside the
--      normal UI path and needs investigation first).
--   4. Which question_types actually have non-null points_to_remember, so the
--      Part B explanation-column split migrates the right rows.
--   5. Whether `subtype` is genuinely unused today (expected 0).
--   6. Live D-10 RESTRICTIVE policy definitions, to check for a stale
--      `integrated_case` reference in either policy's IN-list.
--   7. (Code-side, not SQL — confirmed by grep, see report) GRADED_QUESTION_TYPES
--      does not include theory/test_your_understanding.
--
-- Run all 6 SQL queries below in the Supabase SQL Editor and paste back the
-- full result of each (real numbers/rows, not just row counts) — several
-- downstream decisions (manual row classification, whether to STOP on
-- integrated_case, which types Part B's UPDATE targets) depend on the actual
-- data, not assumptions carried over from blueprint.md.

-- 1. Live CHECK constraint definition — read the exact IN-list from this, do
--    not hand-type it from blueprint.md or DATABASE_SCHEMA.md.
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conname = 'chk_flashcards_question_type';

-- 2. test_your_understanding rows — full detail, not just a count. If this
--    returns any rows, classify each as 'pure_theory' or 'descriptive_case_study'
--    by reading front_text/back_text before writing the migration.
SELECT id, front_text, back_text, points_to_remember, created_at
FROM flashcards
WHERE question_type = 'test_your_understanding'
ORDER BY created_at;

SELECT count(*) AS test_your_understanding_count
FROM flashcards
WHERE question_type = 'test_your_understanding';

-- 3. integrated_case rows — expected 0. If nonzero, STOP and report back
--    before proceeding with Part C.
SELECT count(*) AS integrated_case_count, array_agg(id) AS ids
FROM flashcards
WHERE question_type = 'integrated_case';

-- 4. points_to_remember usage by question_type — confirms which graded types
--    actually reuse this field for grading-rationale ("Why") text, per
--    FlashcardCreate.jsx/BulkUploadFlashcards.jsx save logic.
SELECT question_type, count(*)
FROM flashcards
WHERE points_to_remember IS NOT NULL AND points_to_remember != '[]'::jsonb
GROUP BY question_type;

-- 5. subtype — confirm genuinely inert today (expected 0).
SELECT count(*) AS subtype_non_null_count
FROM flashcards
WHERE subtype IS NOT NULL;

-- 6. D-10 RESTRICTIVE policy pair — check whether either policy's IN-list
--    still mentions integrated_case (dropping the CHECK-constraint value makes
--    it uninsertable regardless, but a stale mention is worth cleaning up in
--    the same migration).
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');
