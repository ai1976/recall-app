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
