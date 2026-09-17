-- Name: [SCHEMA] Sprint 8.6c — add mcq_multi question_type + review_events.selected_answer
--
-- Description: Adds the new `mcq_multi` question_type value to the live 8-value
-- chk_flashcards_question_type CHECK constraint (flashcard, mcq, correct_incorrect,
-- theory, case_study_mcq, match_the_following, fitb, concept_card — confirmed via
-- 00_DIAGNOSTIC, sprint7.9's true_false-removal migration), bringing the roster to
-- 9. Extends both D-10 RESTRICTIVE policies (flashcards_gate_verdict_types_insert/
-- _update) to also gate mcq_multi — professor/admin/super_admin only, same
-- is_professor_or_admin() check every other verdict-bearing type uses (D-10,
-- blueprint.md §3.1). Adds review_events.selected_answer (nullable jsonb, no
-- default, no backfill) to preserve the student's actual selected set as attempt
-- evidence — populated only by mcq_multi for now; every other type's rows stay
-- NULL, no new analytics feature required this sprint.
--
-- Run as ONE transaction in the Supabase SQL Editor (single implicit txn — do not
-- mix this with a verification ROLLBACK in the same run, see
-- infra_supabase_sql_gotchas memory). Run 02_FUNCTIONS in a SEPARATE submission
-- afterward — apply_review's CREATE OR REPLACE references this column.

BEGIN;

-- ── Step 1: widen the CHECK constraint ──────────────────────────────────────
ALTER TABLE flashcards DROP CONSTRAINT chk_flashcards_question_type;

ALTER TABLE flashcards ADD CONSTRAINT chk_flashcards_question_type
  CHECK (question_type = ANY (ARRAY[
    'flashcard'::text, 'mcq'::text, 'correct_incorrect'::text,
    'theory'::text, 'case_study_mcq'::text, 'match_the_following'::text,
    'fitb'::text, 'concept_card'::text, 'mcq_multi'::text
  ]));

-- ── Step 2: extend both D-10 RESTRICTIVE policies to gate mcq_multi too ─────
ALTER POLICY flashcards_gate_verdict_types_insert ON flashcards
  WITH CHECK (
    (question_type <> ALL (ARRAY[
      'mcq'::text, 'correct_incorrect'::text, 'case_study_mcq'::text,
      'match_the_following'::text, 'fitb'::text, 'mcq_multi'::text
    ])) OR is_professor_or_admin()
  );

ALTER POLICY flashcards_gate_verdict_types_update ON flashcards
  WITH CHECK (
    (question_type <> ALL (ARRAY[
      'mcq'::text, 'correct_incorrect'::text, 'case_study_mcq'::text,
      'match_the_following'::text, 'fitb'::text, 'mcq_multi'::text
    ])) OR is_professor_or_admin()
  );

-- ── Step 3: attempt-evidence column on review_events ────────────────────────
ALTER TABLE public.review_events ADD COLUMN selected_answer jsonb;

COMMENT ON COLUMN public.review_events.selected_answer IS
  'Student''s actual selected answer set, as evidence alongside is_correct. '
  'Populated only by mcq_multi (Sprint 8.6c) — every other question_type '
  'leaves this NULL. No backfill; history starts at deploy.';

COMMIT;

NOTIFY pgrst, 'reload schema';
