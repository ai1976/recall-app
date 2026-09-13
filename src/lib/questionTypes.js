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

// Question types with a real authoring/content path as of Sprint 7.6 — the only
// ones worth offering in a "narrow decks by type" filter. Add to this array (not
// hardcoded JSX) as later sprints ship new authorable types.
export const BROWSABLE_QUESTION_TYPES = ['flashcard', 'mcq'];
