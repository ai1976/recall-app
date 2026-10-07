/**
 * dueSet.js — the one place that changes what is "due" for the signed-in user, and the one signal that says so.
 *
 * T-001 brief C v6 (C-6.4). The Review badge, the Progress "due today" tile, the Dashboard Forward Load chart and the Dashboard zero-state strip all read ONE
 * snapshot (DueSnapshotContext). The snapshot must be refreshed whenever the user's own due set can have changed, so EVERY call that can change it goes
 * through a wrapper below, and each wrapper emits `notifyReviewDataChanged()` only when the call succeeded (never on a failure).
 *
 * What counts as due-changing (brief C v6 P6-E5 and QA Rounds 72, 74 and 76): reviewing, skipping, suspending and resetting a card (single and topic-wide),
 * adding to, removing from, pausing and resuming My Cards (single and bulk), a write of the profile's course or time zone, accepting or removing a friendship
 * (it decides who can see friends-only cards), and deleting a card or a note (its linked cards go with it).
 *
 * Enforcement (scripts/dueSetGuard.mjs, run by `npm test` and before every build): no such call may exist anywhere else in src/, every database call in the
 * code base must be classified in scripts/dueSetManifest.json, and a due-changing call is only allowed in THIS file. Add a new due-changing path here.
 *
 * Limit, stated: a change made by another user (an administrator changing a course, an author changing a card's visibility, another user deleting a card)
 * or on another device cannot signal this tab; the snapshot catches up when the user returns to the app or opens Dashboard, Progress or Review.
 */

import { supabase } from '@/lib/supabase';

// --- the signal --------------------------------------------------------------------------------------------------------------------------------

const listeners = new Set();
let pendingTimer = null;
const DEBOUNCE_MS = 1500;

/** Subscribe to "the due set may have changed". Returns an unsubscribe function. */
export function subscribeReviewDataChanged(fn) {
  listeners.add(fn);
  return () => { listeners.delete(fn); };
}

function emit() {
  for (const fn of [...listeners]) {
    try { fn(); } catch (err) { console.error('dueSet listener failed:', err); }
  }
}

/**
 * Emit the signal. With `{ debounce: true }` rapid calls coalesce into one signal after a trailing delay of 1.5 seconds (graded answers); otherwise the
 * signal is immediate. A pending debounced signal is replaced by an immediate one.
 */
export function notifyReviewDataChanged({ debounce = false } = {}) {
  if (debounce) {
    if (pendingTimer !== null) clearTimeout(pendingTimer);
    pendingTimer = setTimeout(() => { pendingTimer = null; emit(); }, DEBOUNCE_MS);
    return;
  }
  if (pendingTimer !== null) { clearTimeout(pendingTimer); pendingTimer = null; }
  emit();
}

/** Emit a pending debounced signal now (call when a review session ends or the page is left). Does nothing when none is pending. */
export function flushReviewDataChanged() {
  if (pendingTimer === null) return;
  clearTimeout(pendingTimer);
  pendingTimer = null;
  emit();
}

// A Supabase response is `{ data, error }`; the signal is emitted only when `error` is empty.
function afterSuccess(res, options) {
  if (res && !res.error) notifyReviewDataChanged(options);
  return res;
}

// --- RPC wrappers: same arguments and same `{ data, error }` result as `supabase.rpc`, plus the signal on success -------------------------------------

export async function applyReview(args) { return afterSuccess(await supabase.rpc('apply_review', args), { debounce: true }); }
export async function skipCard(args) { return afterSuccess(await supabase.rpc('skip_card', args)); }
export async function suspendCard(args) { return afterSuccess(await supabase.rpc('suspend_card', args)); }
export async function unsuspendCard(args) { return afterSuccess(await supabase.rpc('unsuspend_card', args)); }
export async function resetCard(args) { return afterSuccess(await supabase.rpc('reset_card', args)); }
export async function skipTopicCards(args) { return afterSuccess(await supabase.rpc('skip_topic_cards', args)); }
export async function suspendTopicCards(args) { return afterSuccess(await supabase.rpc('suspend_topic_cards', args)); }
export async function addToMyCards(args) { return afterSuccess(await supabase.rpc('add_to_my_cards', args)); }
export async function removeFromMyCards(args) { return afterSuccess(await supabase.rpc('remove_from_my_cards', args)); }

// Routines that diagnostics 11 and 12 (T-001 evidence W1 and W2, accepted by the Founder) show can write a due-input table, or could not be cleared by the
// evidence and are therefore treated as due-changing (fail closed; the cost of a wrong "due-changing" is one extra debounced refresh).
// Immediate signal: these write reviews, my_cards_enrollment, flashcards, notes or profiles rows directly or through a routine they call.
export async function addBatchToMyCards(args) { return afterSuccess(await supabase.rpc('add_batch_to_my_cards', args)); }
export async function createFlashcardBatches(args) { return afterSuccess(await supabase.rpc('create_flashcard_batches', args)); }
export async function adminChangeRole(args) { return afterSuccess(await supabase.rpc('admin_change_role', args)); }
export async function adminDeleteNote(args) { return afterSuccess(await supabase.rpc('admin_delete_note', args)); }
export async function adminDeleteUserData(args) { return afterSuccess(await supabase.rpc('admin_delete_user_data', args)); }
export async function adminGrantAccess(args) { return afterSuccess(await supabase.rpc('admin_grant_access', args)); }
export async function adminReactivateUser(args) { return afterSuccess(await supabase.rpc('admin_reactivate_user', args)); }
export async function adminSuspendUser(args) { return afterSuccess(await supabase.rpc('admin_suspend_user', args)); }
export async function approveEducatorApplication(args) { return afterSuccess(await supabase.rpc('approve_educator_application', args)); }
export async function approveFeaturedNomination(args) { return afterSuccess(await supabase.rpc('approve_featured_nomination', args)); }
export async function nominateFeaturedContent(args) { return afterSuccess(await supabase.rpc('nominate_featured_content', args)); }
export async function rejectFeaturedNomination(args) { return afterSuccess(await supabase.rpc('reject_featured_nomination', args)); }
export async function unfeatureContent(args) { return afterSuccess(await supabase.rpc('unfeature_content', args)); }
export async function linkAccessRequest(args) { return afterSuccess(await supabase.rpc('link_access_request', args)); }
// Debounced signal: flagged only because the evidence could not clear them (no due-input write found, or a write only through a trigger or a profile
// field other than course_level and timezone); they are frequent or low-value, so rapid calls coalesce into one refresh.
export async function toggleUpvote(args) { return afterSuccess(await supabase.rpc('toggle_upvote', args), { debounce: true }); }
export async function updateDailyGoal(args) { return afterSuccess(await supabase.rpc('update_daily_goal', args), { debounce: true }); }
export async function inviteToGroup(args) { return afterSuccess(await supabase.rpc('invite_to_group', args), { debounce: true }); }
export async function leaveGroup(args) { return afterSuccess(await supabase.rpc('leave_group', args), { debounce: true }); }
export async function unassignProfessorFromBatch(args) { return afterSuccess(await supabase.rpc('unassign_professor_from_batch', args), { debounce: true }); }
export async function submitAccessRequest(args) { return afterSuccess(await supabase.rpc('submit_access_request', args), { debounce: true }); }
export async function submitEducatorApplication(args) { return afterSuccess(await supabase.rpc('submit_educator_application', args), { debounce: true }); }
export async function submitInstituteInquiry(args) { return afterSuccess(await supabase.rpc('submit_institute_inquiry', args), { debounce: true }); }

// --- bulk My Cards: chunks of 500, ONE signal after the last chunk, and one after a partial failure -------------------------------------------------

export const BULK_CHUNK = 500;

const bulkCall = {
  pause: (args) => supabase.rpc('bulk_pause_my_cards', args),
  resume: (args) => supabase.rpc('bulk_resume_my_cards', args),
  remove: (args) => supabase.rpc('bulk_remove_from_my_cards', args),
};

/**
 * Run a bulk My Cards action ('pause' | 'resume' | 'remove') over `ids` in chunks. Returns `{ processed, skipped, error }`; on the first failing chunk it
 * stops and returns that error. The signal is emitted once, after the last chunk finishes, and also when it stops part-way after at least one chunk succeeded.
 */
export async function runBulkMyCards(action, userId, ids, chunkSize = BULK_CHUNK) {
  const call = bulkCall[action];
  if (!call) return { processed: 0, skipped: 0, error: new Error(`Unknown bulk action: ${action}`) };
  let processed = 0;
  let skipped = 0;
  let anySucceeded = false;
  let error = null;
  for (let i = 0; i < ids.length; i += chunkSize) {
    const res = await call({ p_user_id: userId, p_flashcard_ids: ids.slice(i, i + chunkSize) });
    if (res.error) { error = res.error; break; }
    anySucceeded = true;
    processed += res.data?.processed ?? 0;
    skipped += res.data?.skipped ?? 0;
  }
  if (anySucceeded) notifyReviewDataChanged();
  return { processed, skipped, error };
}

// --- table writes ------------------------------------------------------------------------------------------------------------------------------

/**
 * Update the signed-in user's profile. The signal is emitted when the update succeeded AND it set `course_level` or `timezone` (the two profile columns
 * that change what is due); other profile fields do not emit.
 */
export async function updateProfileDueFields(userId, fields) {
  const res = await supabase.from('profiles').update(fields).eq('id', userId);
  if (res && !res.error && Object.keys(fields).some((k) => k === 'course_level' || k === 'timezone')) notifyReviewDataChanged();
  return res;
}

/** Set a friendship's status ('accepted' | 'rejected'); accepting decides who can see friends-only cards. */
export async function setFriendshipStatus(friendshipId, status) {
  return afterSuccess(await supabase
    .from('friendships')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', friendshipId));
}

/** Delete a friendship row (an accepted friendship ends, or a pending request is withdrawn or rejected). */
export async function deleteFriendship(friendshipId) {
  return afterSuccess(await supabase.from('friendships').delete().eq('id', friendshipId));
}

/** Delete one flashcard; its reviews and enrollments go with it. */
export async function deleteFlashcard(cardId) {
  return afterSuccess(await supabase.from('flashcards').delete().eq('id', cardId));
}

/** Delete several flashcards by id. */
export async function deleteFlashcards(cardIds) {
  return afterSuccess(await supabase.from('flashcards').delete().in('id', cardIds));
}

/** Delete a note; its linked flashcards go with it. */
export async function deleteNote(noteId) {
  return afterSuccess(await supabase.from('notes').delete().eq('id', noteId));
}

/** Delete a deck (study set); its cards, and their reviews and enrollments, go with it (foreign key cascade). */
export async function deleteDeck(deckId) {
  return afterSuccess(await supabase.from('flashcard_decks').delete().eq('id', deckId));
}

/** Send a friend request (insert or replace the pending row). A friendship decides who can see friends-only cards, so the signal is emitted on success. */
export async function upsertFriendRequest(row) {
  return afterSuccess(await supabase.from('friendships').upsert(row, { onConflict: 'user_id, friend_id' }));
}

// Flashcard columns that can change what is due: target_course (the course rule), question_type (concept cards are never due) and visibility (who can see
// the card; the owner's own cards stay eligible, other users' due sets cannot be signalled from this tab).
export const DUE_FLASHCARD_COLUMNS = ['target_course', 'question_type', 'visibility'];

/** Update every card of a batch (course, subject, topic and description edits of a group of cards). */
export async function updateFlashcardsByBatch(batchId, updates) {
  const res = await supabase.from('flashcards').update(updates).eq('batch_id', batchId);
  if (res && !res.error && Object.keys(updates).some((k) => DUE_FLASHCARD_COLUMNS.includes(k))) notifyReviewDataChanged();
  return res;
}

/** Set the visibility of one card. */
export async function updateFlashcardVisibility(cardId, visibility) {
  return afterSuccess(await supabase.from('flashcards').update({ visibility }).eq('id', cardId));
}

/** Set the visibility of several cards. */
export async function updateFlashcardsVisibility(cardIds, visibility) {
  return afterSuccess(await supabase.from('flashcards').update({ visibility }).in('id', cardIds));
}
