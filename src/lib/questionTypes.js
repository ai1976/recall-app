/**
 * Shared question_type helpers — extracted from Dashboard.jsx (Sprint 6.3) so
 * ReviewFlashcards.jsx's question type filter (Sprint 7.6) uses the same
 * display strings instead of inventing new ones.
 */

// question_type slug → readable label. test_your_understanding, integrated_case, and
// true_false are deliberately absent as of Sprint 7.9 (D-10/D-12/D-14 corrections) —
// all three are now live-uninsertable (dropped from chk_flashcards_question_type), so
// any row still showing one is impossible post-migration; no fallback label is worth carrying.
export const formatQuestionType = (qt) => {
  if (!qt) return 'Other';
  const map = {
    flashcard: 'Flashcard',
    mcq: 'MCQ',
    correct_incorrect: 'Correct / Incorrect',
    theory: 'Theory',
    case_study_mcq: 'Case study MCQ',
    match_the_following: 'Match the following',
    fitb: 'Fill in the blanks',
    concept_card: 'Concept Card',
    mcq_multi: 'Multi-select MCQ',
  };
  return map[qt] || qt.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
};

// Question types with a real authoring/content path as of Sprint 7.12 — the only
// ones worth offering in a "narrow decks by type" filter. Add to this array (not
// hardcoded JSX) as later sprints ship new authorable types. test_your_understanding
// removed (D-10 correction) — collapsed into theory + subtype. true_false removed
// (D-14) — merged into correct_incorrect (CA Revision Portal's own schema documents
// them as functionally identical, and correct_incorrect is the one with real usage).
// concept_card (Sprint 7.12) is browse-only reference material — belongs here so
// Browse Study Sets can filter to it, but must NEVER be added to
// GRADED_QUESTION_TYPES below (D-06: no grade, no rung, no reviews row, ever).
export const BROWSABLE_QUESTION_TYPES = [
  'flashcard', 'mcq', 'correct_incorrect', 'theory',
  'match_the_following', 'case_study_mcq', 'fitb', 'concept_card', 'mcq_multi',
];

// theory's required 2-option classification field (Sprint 7.9) — mirrors the CA
// Revision Portal's own D14 exactly (pure_theory | descriptive_case_study),
// activating the flashcards.subtype column that had sat unused since it was added.
// Classification metadata only — does not change how StudyMode.jsx renders the card.
export const THEORY_SUBTYPE_LABELS = {
  pure_theory: 'Pure theory',
  descriptive_case_study: 'Descriptive case study',
};

// D-10 (blueprint.md §3.1) verdict-bearing types that render through the SHARED
// AnswerOption/hybrid-grading list in StudyMode.jsx — mcq, correct_incorrect, and
// case_study_mcq (Sprint 7.10) all pick one option from a flat list per question;
// case_study_mcq's shared scenario is a collapsible block layered ABOVE that same
// branch, not a different grading mechanic. match_the_following also has a real
// authoring UI (Sprint 7.8) but renders through its OWN MatchZone branch (a
// build-up-then-submit pairing interaction, not a single tap) — deliberately NOT
// added here. fitb (Sprint 7.11) has a real authoring UI + its own StudyMode
// branch too, same reasoning as match_the_following — its verdict is
// confidence-gated three-way (match/no-match/self-grade, D-13), not the clean
// binary this shared list assumes, so it deliberately stays out of this array.
// integrated_case (D-12) and true_false (D-14) were also on this list — both
// removed entirely, no longer live question_type values. mcq_multi (Sprint
// 8.6c) is NOT added here either — same reasoning as match_the_following: it
// builds up a selection across multiple taps with no verdict until an
// explicit Submit (mirrors handleMatchSubmit, not handleMcqSelect), so it
// renders through its own StudyMode branch, not this shared single-tap list.
export const GRADED_QUESTION_TYPES = ['mcq', 'correct_incorrect', 'case_study_mcq'];

// correct_incorrect auto-populates `options` from this pair — never professor-typed,
// unlike MCQ's free-text options. Index into the pair is what `correct_answer` stores (as a
// string), same 0-based-index convention as MCQ. true_false's ['True','False'] pair removed
// (D-14, Sprint 7.9) — merged into correct_incorrect, the one with real usage.
export const VERDICT_OPTION_LABELS = {
  correct_incorrect: ['Correct', 'Incorrect'],
};
