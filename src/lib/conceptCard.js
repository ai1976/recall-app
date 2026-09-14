/**
 * Shared concept_card authoring helpers (Sprint 7.12) — used by
 * FlashcardCreate.jsx (manual authoring only; bulk upload is explicitly
 * deferred, see blueprint.md D-06 representation note / Sprint 7.12-C).
 *
 * Representation: `front_text` = heading (concept name). `back_text` =
 * summary (2-3 sentence explanation), typed directly like a plain flashcard's
 * back — not derived. `options` jsonb = array of `{term, definition}` objects
 * (keyTerms) — third reuse of that column after mcq (7.5) and fitb (7.11).
 * `correct_answer`/`hints`/`scenario`/`subtype`/`explanation` stay NULL —
 * concept cards are browse-only reference material, never graded (D-06).
 */

export const CONCEPT_MIN_TERMS = 1;
export const CONCEPT_MAX_TERMS = 10;

export function emptyConceptTerm() {
  return { term: '', definition: '' };
}

export function emptyConceptTerms() {
  return [emptyConceptTerm()];
}

/** Drops rows missing either half of the pair — shared by FlashcardCreate's
 *  add/remove list editor and the insert-time row builder. */
export function buildConceptOptions(terms) {
  return (terms || [])
    .map((t) => ({ term: (t?.term || '').trim(), definition: (t?.definition || '').trim() }))
    .filter((t) => t.term && t.definition);
}

/** Validates the key-terms list. Returns an error string, or null. */
export function validateConceptTerms(terms) {
  const filled = buildConceptOptions(terms);
  if (filled.length < CONCEPT_MIN_TERMS) {
    return 'Add at least one key term with both a term and a definition';
  }
  return null;
}
