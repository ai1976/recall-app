/**
 * Shared MCQ authoring helpers — used by both FlashcardCreate.jsx (manual) and
 * BulkUploadFlashcards.jsx (CSV) so back_text derivation can't drift between
 * the two entry paths (Sprint 7.5).
 */

export const MCQ_MIN_OPTIONS = 2;
export const MCQ_MAX_OPTIONS = 6;
export const MCQ_DEFAULT_OPTIONS = 4;

/** back_text is never typed directly for MCQ — it's the correct option's text. */
export function deriveMcqBackText(options, correctIndex) {
  return options?.[correctIndex] ?? '';
}

/** explanation jsonb: one array entry per non-blank line, or null if empty. Also
 *  reused for points_to_remember on free-recall types that ever adopt this shape. */
export function toPointsToRemember(whyText) {
  if (!whyText) return null;
  const lines = whyText.split('\n').map(l => l.trim()).filter(Boolean);
  return lines.length ? lines : null;
}

/**
 * Drops blank option rows and remaps correctIndex to its new position — shared
 * by FlashcardCreate.jsx (add/remove option rows) and BulkUploadFlashcards.jsx
 * (fixed option_1..option_4 CSV columns, some of which may be blank). Matching
 * by ORIGINAL index (not by text) matters: two options can have identical text,
 * which is exactly why correct_answer is index-based in the first place.
 */
export function compactMcqOptions(options, correctIndex) {
  const kept = (options || [])
    .map((text, originalIndex) => ({ text: (text || '').trim(), originalIndex }))
    .filter(o => o.text);
  const newCorrectIndex = kept.findIndex(o => o.originalIndex === correctIndex);
  return {
    options: kept.map(o => o.text),
    correctIndex: newCorrectIndex === -1 ? null : newCorrectIndex,
  };
}

/**
 * Validates an MCQ card's options + correct-answer selection.
 * Returns an error string, or null if valid.
 */
export function validateMcqOptions(options, correctIndex) {
  const filled = (options || []).filter(o => o.trim());
  if (filled.length < MCQ_MIN_OPTIONS) {
    return `Multiple choice needs at least ${MCQ_MIN_OPTIONS} options`;
  }
  if (correctIndex === null || correctIndex === undefined) {
    return 'Mark which option is correct';
  }
  if (!options[correctIndex]?.trim()) {
    return 'The option marked correct cannot be empty';
  }
  return null;
}

/**
 * mcq_multi (Sprint 8.6c) — multi-select MCQ helpers. Shares options'
 * 2-6-option shape and MCQ_MIN/MAX_OPTIONS with single-select mcq, but
 * correct_answer stores a SET of indices, not one — canonicalized on every
 * write (authoring AND CSV import) so the same underlying set always
 * serializes identically, and compared as a parsed set (never a raw string)
 * at grading time.
 */

/**
 * Canonical serialization of a multi-select answer set: unique indices,
 * sorted ascending, joined with a single semicolon, no spaces. {4,0,2}
 * always -> "0;2;4", never "4;0;2" or "0; 2; 4".
 */
export function canonicalizeMultiAnswer(indices) {
  const unique = Array.from(new Set((indices || []).map(Number)))
    .filter(n => Number.isInteger(n) && n >= 0);
  unique.sort((a, b) => a - b);
  return unique.join(';');
}

/** Inverse of canonicalizeMultiAnswer — "0;2;4" -> [0, 2, 4]. */
export function parseMultiAnswer(str) {
  return (str || '')
    .split(';')
    .map(s => parseInt(s.trim(), 10))
    .filter(n => Number.isInteger(n));
}

/**
 * Drops blank option rows and remaps every correct index in the set to its
 * new position — the multi-select sibling of compactMcqOptions.
 */
export function compactMcqMultiOptions(options, correctIndices) {
  const kept = (options || [])
    .map((text, originalIndex) => ({ text: (text || '').trim(), originalIndex }))
    .filter(o => o.text);
  const indexMap = new Map(kept.map((o, newIndex) => [o.originalIndex, newIndex]));
  const remapped = (correctIndices || [])
    .map(i => indexMap.get(i))
    .filter(i => i !== undefined);
  return {
    options: kept.map(o => o.text),
    correctIndices: remapped,
  };
}

/**
 * Validates an mcq_multi card's options + correct-answer set. Hard
 * requirement only: 2-6 total options, at least 1 marked correct. "At least
 * 1 incorrect" is a pedagogical preference, not enforced here — a
 * course-agnostic platform shouldn't hard-block content it can't anticipate.
 * The "all options correct" case is a non-blocking confirmation in the UI,
 * not a validation error.
 */
export function validateMcqMultiOptions(options, correctIndices) {
  const filled = (options || []).filter(o => o.trim());
  if (filled.length < MCQ_MIN_OPTIONS) {
    return `Multi-select MCQ needs at least ${MCQ_MIN_OPTIONS} options`;
  }
  if (filled.length > MCQ_MAX_OPTIONS) {
    return `Multi-select MCQ allows at most ${MCQ_MAX_OPTIONS} options`;
  }
  const filledCorrect = (correctIndices || []).filter(i => options[i]?.trim());
  if (filledCorrect.length === 0) {
    return 'Mark at least one option as correct';
  }
  return null;
}

/** back_text for mcq_multi is every correct option's text, joined — never
 *  typed directly, same convention as single-select deriveMcqBackText. */
export function deriveMcqMultiBackText(options, correctIndices) {
  return (correctIndices || [])
    .slice()
    .sort((a, b) => a - b)
    .map(i => options?.[i])
    .filter(Boolean)
    .join(' • ');
}
