/**
 * Shared case_study_mcq authoring helpers (Sprint 7.10) — used by both
 * FlashcardCreate.jsx (manual) and BulkUploadFlashcards.jsx (CSV).
 *
 * Representation: ONE shared `scenario` narrative fans out into N independent
 * flashcards rows sharing one batch_id (D-01 grouping pattern) — each row is
 * its own SRS card, reviewed on its own schedule, with mcq's exact per-question
 * representation (options/correct_answer/back_text/explanation, see blueprint.md
 * §1.1 MCQ representation note). scenario is duplicated across every row in the
 * case so it renders on any review day without a JOIN. subject_id/topic_id are
 * the one shared anchor topic for the whole case (D-12 authoring clarification).
 */

import { validateMcqOptions } from '@/lib/mcq';

export const CASE_MIN_QUESTIONS = 2;
export const CASE_MAX_QUESTIONS = 8;
export const CASE_DEFAULT_QUESTIONS = 3;

/** A fresh, empty question block for the case-study authoring UI. */
export function emptyCaseQuestion(defaultOptionCount) {
  return {
    front: '',
    options: Array.from({ length: defaultOptionCount }, () => ''),
    correctOptionIndex: null,
    why: '',
  };
}

/**
 * Validates a case study's shared scenario + its question blocks. Returns an
 * error string, or null if valid. Each question is validated with the same
 * validateMcqOptions() mcq authoring already uses — a case question IS an mcq
 * question, just with a shared scenario instead of its own standalone stem.
 */
export function validateCaseStudy(scenario, questions) {
  if (!scenario || !scenario.trim()) {
    return 'Enter the shared case scenario';
  }
  const count = questions?.length || 0;
  if (count < CASE_MIN_QUESTIONS) {
    return `Case study needs at least ${CASE_MIN_QUESTIONS} questions`;
  }
  if (count > CASE_MAX_QUESTIONS) {
    return `Case study allows at most ${CASE_MAX_QUESTIONS} questions`;
  }
  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    if (!q.front || !q.front.trim()) {
      return `Question ${i + 1}: enter the question text`;
    }
    const mcqError = validateMcqOptions(q.options, q.correctOptionIndex);
    if (mcqError) return `Question ${i + 1}: ${mcqError}`;
  }
  return null;
}
