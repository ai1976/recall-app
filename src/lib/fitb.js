/**
 * Shared fill-in-the-blank (fitb) helpers (Sprint 7.11) — used by
 * FlashcardCreate.jsx (manual), BulkUploadFlashcards.jsx (CSV), and
 * StudyMode.jsx (grading), so the exact same normalization function runs on
 * both sides of the match check — never two similar-but-different copies.
 *
 * Representation: `options` jsonb = array of acceptable-answer strings (1+),
 * repurposing the existing "answer options for MCQ-type questions" column
 * with a generalized meaning (D-13, blueprint.md §3.1). `front_text` holds
 * the blank-containing sentence; `correct_answer` stays NULL (same pattern
 * as match_the_following — there's no single scalar "the answer"). `explanation`
 * = jsonb why-array, same column/shape as every other graded type since Sprint 7.9.
 *
 * Grading is confidence-gated, not binary (D-13) — see StudyMode.jsx's fitb
 * branch: a match is a confident-correct verdict (is_correct=true), a
 * non-match is NEVER treated as wrong — it falls back to the free-recall
 * self-grade path (is_correct=NULL). There is no "confident-wrong" state.
 */

export const FITB_BLANK_PATTERN = /_{3,}/;
export const FITB_BLANK_PLACEHOLDER = '______';
export const FITB_MIN_ANSWERS = 1;
export const FITB_MAX_ANSWERS = 6;

/**
 * Normalizes an answer string for comparison: trim, lowercase, strip
 * punctuation, collapse whitespace. MUST be the exact same function applied
 * to both the student's typed answer and every authored acceptable answer —
 * calling it identically on both sides is the whole point (D-13's "Used
 * identically at grading time" requirement).
 */
export function normalizeFitbAnswer(text) {
  return (text || '')
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * True if the student's typed answer normalizes to match any accepted
 * variant. A false return is never a verdict of "wrong" — it's a signal to
 * fall back to the free-recall grading path (D-13).
 */
export function isFitbMatch(studentAnswer, options) {
  const normalized = normalizeFitbAnswer(studentAnswer);
  if (!normalized) return false;
  return (options || []).some((opt) => normalizeFitbAnswer(opt) === normalized);
}

/** back_text is never typed directly for fitb — the first accepted answer,
 *  same "derive, don't ask" convention as mcq/match_the_following. */
export function deriveFitbBackText(options) {
  return options?.[0] ?? '';
}

/** Validates the front_text carries a blank marker — a fitb card with no
 *  visible blank for the student to fill in is a broken card. */
export function validateFitbBlank(frontText) {
  if (!frontText || !frontText.trim()) {
    return 'Enter the sentence with a blank';
  }
  if (!FITB_BLANK_PATTERN.test(frontText)) {
    return `Mark the blank with ${FITB_BLANK_PLACEHOLDER} (at least 3 underscores) somewhere in the sentence`;
  }
  return null;
}

/** Validates the acceptable-answers list. Returns an error string, or null. */
export function validateFitbOptions(options) {
  const filled = (options || []).map((o) => (o || '').trim()).filter(Boolean);
  if (filled.length < FITB_MIN_ANSWERS) {
    return 'Enter at least one acceptable answer';
  }
  return null;
}

/** Drops blank rows — shared by FlashcardCreate's add/remove list editor and
 *  BulkUploadFlashcards' semicolon-delimited CSV cell. */
export function compactFitbOptions(options) {
  return (options || []).map((o) => (o || '').trim()).filter(Boolean);
}

/** Splits front_text into {before, after} around the FIRST blank marker —
 *  used by StudyMode.jsx to render an inline input where the blank goes.
 *  A sentence with no marker (shouldn't happen past authoring-time
 *  validation) just renders as trailing text with the input after it. */
export function splitFitbSentence(frontText) {
  const text = frontText || '';
  const match = text.match(FITB_BLANK_PATTERN);
  if (!match) return { before: text, after: '' };
  return { before: text.slice(0, match.index), after: text.slice(match.index + match[0].length) };
}
