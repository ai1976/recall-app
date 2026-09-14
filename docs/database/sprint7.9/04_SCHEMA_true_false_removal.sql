-- Name: [SCHEMA] Sprint 7.9 (item 4) — remove true_false, merged into correct_incorrect (D-14)
--
-- Description: Confirmed via 03_DIAGNOSTIC_preflight_true_false_removal.sql against
-- production (14/09/2026):
--   - Live CHECK constraint has both true_false and correct_incorrect (9 values total).
--   - true_false: 0 rows. correct_incorrect: 0 rows. Nothing to delete or migrate.
--   - Both D-10 RESTRICTIVE policies list true_false in their with_check IN-list.
--   - srs_ladder_curves has no true_false-specific or correct_incorrect-specific rows —
--     only `_default` (rung 0-7, 1/3/7/14/30/60/120/240 days). Nothing goes orphaned.
--   - No pg_proc body anywhere hardcodes the string 'true_false'.
--
-- Net effect: a pure narrowing migration — no DELETE, no UPDATE, no backfill. Just the
-- CHECK constraint and the two RESTRICTIVE policies.

BEGIN;

-- Narrow the CHECK constraint: drop true_false, correct_incorrect survives.
ALTER TABLE flashcards DROP CONSTRAINT chk_flashcards_question_type;

ALTER TABLE flashcards ADD CONSTRAINT chk_flashcards_question_type
  CHECK (question_type = ANY (ARRAY[
    'flashcard'::text, 'mcq'::text, 'correct_incorrect'::text,
    'theory'::text, 'case_study_mcq'::text, 'match_the_following'::text,
    'fitb'::text, 'concept_card'::text
  ]));

-- Drop the now-stale true_false mention from both D-10 RESTRICTIVE policies.
-- Cosmetic — the CHECK constraint above already makes it uninsertable regardless —
-- but leaving a dead string in a security policy is worth cleaning up, same as
-- integrated_case's removal in 01_SCHEMA_sprint7.9_hygiene.sql.
ALTER POLICY flashcards_gate_verdict_types_insert ON flashcards
  WITH CHECK (
    (question_type <> ALL (ARRAY[
      'mcq'::text, 'correct_incorrect'::text, 'case_study_mcq'::text,
      'match_the_following'::text, 'fitb'::text
    ])) OR is_professor_or_admin()
  );

ALTER POLICY flashcards_gate_verdict_types_update ON flashcards
  WITH CHECK (
    (question_type <> ALL (ARRAY[
      'mcq'::text, 'correct_incorrect'::text, 'case_study_mcq'::text,
      'match_the_following'::text, 'fitb'::text
    ])) OR is_professor_or_admin()
  );

COMMIT;
