-- Name: [SCHEMA] Add test_your_understanding to the flashcards question_type CHECK constraint
--
-- Description: Sprint 7.7-B adds `theory` and `test_your_understanding` as free-recall,
-- ungated question types. `theory` is already a live value in `chk_flashcards_question_type`
-- (confirmed via Sprint 7.5's own diagnostic — see blueprint.md D-10 and
-- DATABASE_SCHEMA.md's flashcards.question_type row). `test_your_understanding` is NOT —
-- it was originally assumed live back when the content-types architecture was first
-- drafted (March 2026), then explicitly corrected out during Sprint 7.5's diagnostic
-- pass ("isn't in the live CHECK constraint at all and cannot be inserted today").
-- This is therefore a genuine hard prerequisite: FlashcardCreate.jsx and
-- BulkUploadFlashcards.jsx cannot INSERT a row with this question_type until this runs.
--
-- ⚠️ RUN 00_DIAGNOSTIC_preflight.sql FIRST and compare its query 2 output against the
-- IN-list below. This file assumes the live constraint is exactly the 10-value list
-- documented in DATABASE_SCHEMA.md (flashcard, mcq, true_false, correct_incorrect,
-- theory, case_study_mcq, integrated_case, match_the_following, fitb, concept_card) —
-- if the diagnostic shows anything different, adjust the IN-list below to match the
-- REAL live definition before running, not this comment's memory of it. This is exactly
-- the introspect-before-DDL case Sprint 7.5's own d10_role_gate.sql diagnostic exists
-- to prevent repeating.
--
-- Purely additive — every existing row's question_type is already in this constraint's
-- old list, so no existing row can violate the widened constraint. No RLS change needed:
-- test_your_understanding is a free-recall type, not in the D-10 verdict-bearing IN-list
-- (flashcards_gate_verdict_types_insert/_update), so it stays open to all users exactly
-- like theory/flashcard already are.

ALTER TABLE public.flashcards
  DROP CONSTRAINT chk_flashcards_question_type;

ALTER TABLE public.flashcards
  ADD CONSTRAINT chk_flashcards_question_type
  CHECK (question_type IN (
    'flashcard', 'mcq', 'true_false', 'correct_incorrect', 'theory',
    'case_study_mcq', 'integrated_case', 'match_the_following', 'fitb',
    'concept_card', 'test_your_understanding'
  ));

NOTIFY pgrst, 'reload schema';
