/**
 * Shared question_type helpers — extracted from Dashboard.jsx (Sprint 6.3) so
 * ReviewFlashcards.jsx's question type filter (Sprint 7.6) uses the same
 * display strings instead of inventing new ones.
 */

// question_type slug → readable label
export const formatQuestionType = (qt) => {
  if (!qt) return 'Other';
  const map = {
    flashcard: 'Flashcard',
    mcq: 'MCQ',
    true_false: 'True / False',
    correct_incorrect: 'Correct / Incorrect',
    theory: 'Theory',
    test_your_understanding: 'Test your understanding',
    case_study_mcq: 'Case study MCQ',
    integrated_case: 'Integrated case',
    match_the_following: 'Match the following',
    fitb: 'Fill in the blanks',
  };
  return map[qt] || qt.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
};

// Question types with a real authoring/content path as of Sprint 7.7 — the only
// ones worth offering in a "narrow decks by type" filter. Add to this array (not
// hardcoded JSX) as later sprints ship new authorable types.
export const BROWSABLE_QUESTION_TYPES = [
  'flashcard', 'mcq', 'true_false', 'correct_incorrect', 'theory', 'test_your_understanding',
];

// D-10 (blueprint.md §3.1) verdict-bearing types with a real authoring UI as of Sprint 7.7 —
// mcq, true_false, correct_incorrect all render through the same AnswerOption/hybrid-grading
// path in StudyMode.jsx. case_study_mcq/integrated_case/match_the_following/fitb are also
// D-10-gated at the DB layer but have no authoring UI yet — do not add them here until they do.
export const GRADED_QUESTION_TYPES = ['mcq', 'true_false', 'correct_incorrect'];

// true_false/correct_incorrect auto-populate `options` from this pair — never professor-typed,
// unlike MCQ's free-text options. Index into the pair is what `correct_answer` stores (as a
// string), same 0-based-index convention as MCQ.
export const VERDICT_OPTION_LABELS = {
  true_false: ['True', 'False'],
  correct_incorrect: ['Correct', 'Incorrect'],
};
