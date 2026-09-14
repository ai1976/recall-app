/**
 * Shared match_the_following authoring helpers (Sprint 7.8) — used by
 * FlashcardCreate.jsx (manual authoring only; bulk upload is explicitly
 * deferred, see blueprint.md D-10 / Sprint 7.8-C).
 *
 * Representation (options jsonb): { left: string[], right: {k,v}[], correct: {[leftIndex]: k} }.
 * Left and right lists are locked to the same length this sprint — no distractor
 * right-options. correct_answer stays NULL for this type; the verdict comes
 * entirely from options.correct, not a single scalar "the answer".
 */

export const MATCH_MIN_PAIRS = 2;
export const MATCH_MAX_PAIRS = 8;
export const MATCH_DEFAULT_PAIRS = 4;

const LETTERS = 'ABCDEFGH';

/** Auto-generated right-item key, by list position — never professor-typed. */
export function keyForRightIndex(i) {
  return LETTERS[i] ?? `R${i}`;
}

/**
 * Builds the options jsonb shape from authoring-time state. `correctByIndex`
 * is a left-index-keyed array of right-item indices (or null) — the letter
 * keys are only assigned here, from final right-list position.
 */
export function buildMatchOptions(left, right, correctByIndex) {
  const rightWithKeys = right.map((v, i) => ({ k: keyForRightIndex(i), v }));
  const correct = {};
  (correctByIndex || []).forEach((rightIndex, leftIndex) => {
    if (rightIndex !== null && rightIndex !== undefined) {
      correct[leftIndex] = keyForRightIndex(rightIndex);
    }
  });
  return { left: [...left], right: rightWithKeys, correct };
}

/**
 * back_text is never typed directly for match_the_following — a flattened
 * "left — key" summary, for any generic code reading back_text without
 * knowing about question_type. `correct` is the letter-keyed map already
 * built by buildMatchOptions.
 */
export function deriveMatchBackText(left, correct) {
  return left.map((l, i) => `${l} — ${correct[i] ?? '?'}`).join('; ');
}

/**
 * Validates a match_the_following card's left/right lists + correct mapping.
 * Returns an error string, or null if valid. A malformed mapping must fail
 * loudly here, not silently produce an unsolvable question.
 */
export function validateMatchPairs(left, right, correctByIndex) {
  const leftTrimmed = (left || []).map((s) => (s || '').trim());
  const rightTrimmed = (right || []).map((s) => (s || '').trim());

  if (leftTrimmed.some((s) => !s) || rightTrimmed.some((s) => !s)) {
    return 'Fill in every left and right item, or remove the empty row';
  }
  if (leftTrimmed.length < MATCH_MIN_PAIRS || rightTrimmed.length < MATCH_MIN_PAIRS) {
    return `Match the following needs at least ${MATCH_MIN_PAIRS} pairs on each side`;
  }
  if (leftTrimmed.length !== rightTrimmed.length) {
    return 'Left and right lists must have the same number of items';
  }
  const correct = correctByIndex || [];
  if (correct.length !== leftTrimmed.length || correct.some((v) => v === null || v === undefined)) {
    return 'Choose a match for every left item';
  }
  return null;
}
