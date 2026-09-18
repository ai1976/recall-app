/**
 * Shared create_flashcard_batches() RPC helpers (Sprint 8.7.2) — used by both
 * FlashcardCreate.jsx (manual) and BulkUploadFlashcards.jsx (CSV), the two
 * flashcard-creation paths migrated off a direct `flashcards` insert onto the
 * provenance-gated RPC this sprint.
 */

/**
 * Groups a flat list of card-row objects (each already carrying its own
 * `batch_id` — one per case_study_mcq case, one per otherwise-independent
 * card, or a shared file-wide id for a plain bulk-upload row) into the RPC's
 * `p_batches` shape: `[{ batch_id, cards: [...] }, ...]`.
 *
 * `batch_description`, when present, stays on each card — the RPC reads it
 * per-card (`c->>'batch_description'`), not at the batch-object level, even
 * though it's semantically one label per batch (see DATABASE_SCHEMA.md §4.0b).
 */
export function groupCardsIntoBatches(rows) {
  const batchMap = new Map();
  for (const row of rows) {
    const { batch_id, ...cardFields } = row;
    if (!batchMap.has(batch_id)) {
      batchMap.set(batch_id, { batch_id, cards: [] });
    }
    batchMap.get(batch_id).cards.push(cardFields);
  }
  return Array.from(batchMap.values());
}

// Deliberately not a hard-coded list of restricted question_types — that would
// drift from v_verdict_types inside create_flashcard_batches(), the actual
// source of truth for which types are D-10-gated. Matched on the RPC's own
// error message substring instead (P0001 is shared by every RAISE EXCEPTION
// in that function, so the Postgres error code alone can't distinguish this
// case from any other validation failure).
const D10_MESSAGE_SUBSTRING = 'professors/admins may author';

/** True when a create_flashcard_batches() error is the D-10 verdict-type rejection. */
export function isD10Rejection(error) {
  return typeof error?.message === 'string' && error.message.includes(D10_MESSAGE_SUBSTRING);
}

/** Generic, type-agnostic user-facing copy for a D-10 rejection — see isD10Rejection. */
export const D10_REJECTION_MESSAGE =
  'One or more items use a question type that requires a professor/admin account. No items were created.';
