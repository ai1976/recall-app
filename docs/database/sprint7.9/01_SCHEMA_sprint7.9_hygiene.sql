-- Name: [SCHEMA] Sprint 7.9 — retire test_your_understanding + integrated_case,
--       add explanation column
--
-- Description: Combined migration for all three Sprint 7.9 hygiene items.
-- Confirmed via 00_DIAGNOSTIC_preflight.sql against production (14/09/2026):
--   - chk_flashcards_question_type currently allows 11 values, including
--     test_your_understanding and integrated_case.
--   - integrated_case: 0 rows (pre-flight step 3) — safe to drop, no data to migrate.
--   - test_your_understanding: 2 rows, both confirmed by the operator to be
--     Claude-authored QA/testing artifacts from Sprint 7.7's live verification
--     (created 13/09/2026), not real professor/student content. Operator chose
--     "delete them first" over classifying+migrating (AskUserQuestion, this session).
--   - points_to_remember was non-null only on 10 more rows — 4 mcq, 2 true_false,
--     2 correct_incorrect, 2 match_the_following — ALL also confirmed by the
--     operator to be the same class of QA/testing artifact (question types were
--     added to the live app across Sprints 7.5-7.8; no professor has authored
--     real graded content yet). Operator chose to delete these too rather than
--     migrate their points_to_remember into the new explanation column.
--   - subtype: confirmed genuinely inert, 0 non-null rows (pre-flight step 5).
--   - Neither RESTRICTIVE policy (flashcards_gate_verdict_types_insert/_update)
--     lists test_your_understanding (it was never graded/gated — correct, no
--     RLS change needed there) or references any string needing removal except
--     integrated_case (pre-flight step 6).
--
-- Net effect: because every row using a type being removed, or holding
-- points_to_remember data that would otherwise need migrating to the new
-- explanation column, is one of these 12 known QA rows, this migration is a
-- clean DELETE + additive-only schema change — no UPDATE/backfill needed.
--
-- Run as ONE transaction in the Supabase SQL Editor (single implicit txn —
-- do not mix this with a verification ROLLBACK in the same run, see
-- infra_supabase_sql_gotchas memory).

BEGIN;

-- ── Step 1: delete the 12 known QA/testing rows ─────────────────────────────
-- IDs from the operator's live query (this session, 14/09/2026):
--   test_your_understanding (2): 3e148677-b203-4600-8b4d-41d464d6c4cc,
--                                 d6f566f3-ca5b-4a99-a34e-e557264caba0
--   mcq (4):                     b269e9b9-f09f-4ebf-a9e5-c2e16e99398d,
--                                 00cbfbf7-6ed3-4cfd-ba41-bab52d464534,
--                                 f84d137c-c939-4734-9c60-c9cf749de714,
--                                 6fd1a69b-eae3-44d1-b9b8-3ec86ec4fdaf
--   true_false (2):              d06b41f8-a2f8-4edc-8899-26c6dde64be9,
--                                 322c1b66-4464-4d5c-8ebd-cf45344b2787
--   correct_incorrect (2):       3a297f35-45c6-4b11-b8a2-0f078b87f1b5,
--                                 ec364543-dcf3-4bbf-9646-707224fe671d
--   match_the_following (2):     d9df9670-49da-47db-b997-c165ec026d92,
--                                 de1b88ee-399c-42c4-9a3f-d79cec413f64
DELETE FROM flashcards
WHERE id IN (
  '3e148677-b203-4600-8b4d-41d464d6c4cc', 'd6f566f3-ca5b-4a99-a34e-e557264caba0',
  'b269e9b9-f09f-4ebf-a9e5-c2e16e99398d', '00cbfbf7-6ed3-4cfd-ba41-bab52d464534',
  'f84d137c-c939-4734-9c60-c9cf749de714', '6fd1a69b-eae3-44d1-b9b8-3ec86ec4fdaf',
  'd06b41f8-a2f8-4edc-8899-26c6dde64be9', '322c1b66-4464-4d5c-8ebd-cf45344b2787',
  '3a297f35-45c6-4b11-b8a2-0f078b87f1b5', 'ec364543-dcf3-4bbf-9646-707224fe671d',
  'd9df9670-49da-47db-b997-c165ec026d92', 'de1b88ee-399c-42c4-9a3f-d79cec413f64'
);
-- Expect: DELETE 12

-- ── Step 2 (Part A + Part C): narrow the CHECK constraint ───────────────────
-- Drops test_your_understanding (D-10 collapse into theory+subtype) and
-- integrated_case (D-12, merged into case_study_mcq). Must run AFTER step 1 —
-- Postgres validates a re-added CHECK constraint against existing rows, and
-- both dropped rows above would otherwise violate the narrower list.
ALTER TABLE flashcards DROP CONSTRAINT chk_flashcards_question_type;

ALTER TABLE flashcards ADD CONSTRAINT chk_flashcards_question_type
  CHECK (question_type = ANY (ARRAY[
    'flashcard'::text, 'mcq'::text, 'true_false'::text, 'correct_incorrect'::text,
    'theory'::text, 'case_study_mcq'::text, 'match_the_following'::text,
    'fitb'::text, 'concept_card'::text
  ]));

-- ── Step 3 (Part C): drop the stale integrated_case reference from both
--    D-10 RESTRICTIVE policies ────────────────────────────────────────────
-- Dropping the CHECK-constraint value already makes integrated_case
-- uninsertable regardless — this only removes a now-meaningless mention.
ALTER POLICY flashcards_gate_verdict_types_insert ON flashcards
  WITH CHECK (
    (question_type <> ALL (ARRAY[
      'mcq'::text, 'true_false'::text, 'correct_incorrect'::text,
      'case_study_mcq'::text, 'match_the_following'::text, 'fitb'::text
    ])) OR is_professor_or_admin()
  );

ALTER POLICY flashcards_gate_verdict_types_update ON flashcards
  WITH CHECK (
    (question_type <> ALL (ARRAY[
      'mcq'::text, 'true_false'::text, 'correct_incorrect'::text,
      'case_study_mcq'::text, 'match_the_following'::text, 'fitb'::text
    ])) OR is_professor_or_admin()
  );

-- ── Step 4 (Part B): add the explanation column ─────────────────────────────
-- Nullable, additive, same shape as points_to_remember (jsonb array of
-- strings) so the save-logic swap in FlashcardCreate.jsx/BulkUploadFlashcards.jsx
-- is mechanical. No backfill needed — every pre-existing row holding grading-
-- rationale text in points_to_remember was deleted in step 1.
ALTER TABLE flashcards ADD COLUMN explanation jsonb;

COMMIT;
