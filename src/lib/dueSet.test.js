// Tests for the due-set wrapper module (T-001 brief C v6, C-6.4 and C-6.5 item 5): every wrapper notifies exactly once on success and never on failure,
// a graded answer is debounced, the bulk wrapper notifies once after the last chunk and after a partial failure, and the profile wrapper notifies only
// when it set course_level or timezone.
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn(), from: vi.fn() } }));

import { supabase } from '@/lib/supabase';
import {
  subscribeReviewDataChanged, notifyReviewDataChanged, flushReviewDataChanged,
  applyReview, skipCard, suspendCard, unsuspendCard, resetCard, skipTopicCards, suspendTopicCards, addToMyCards, removeFromMyCards,
  runBulkMyCards, updateProfileDueFields, setFriendshipStatus, deleteFriendship, deleteFlashcard, deleteFlashcards, deleteNote,
  addBatchToMyCards, createFlashcardBatches, adminChangeRole, adminDeleteNote, adminDeleteUserData, adminGrantAccess, adminReactivateUser, adminSuspendUser,
  approveEducatorApplication, approveFeaturedNomination, nominateFeaturedContent, rejectFeaturedNomination, unfeatureContent, linkAccessRequest,
  toggleUpvote, updateDailyGoal, inviteToGroup, leaveGroup, unassignProfessorFromBatch, submitAccessRequest, submitEducatorApplication, submitInstituteInquiry,
  deleteDeck, upsertFriendRequest, updateFlashcardsByBatch, updateFlashcardVisibility, updateFlashcardsVisibility,
} from '@/lib/dueSet';

// A thenable stand-in for a Supabase query builder: every builder method returns itself and awaiting it yields `result`.
function builder(result) {
  const b = {};
  for (const m of ['update', 'delete', 'upsert', 'eq', 'in']) b[m] = vi.fn(() => b);
  b.then = (resolve, reject) => Promise.resolve(result).then(resolve, reject);
  return b;
}

let calls;
let unsubscribe;

beforeEach(() => {
  vi.useFakeTimers();
  supabase.rpc.mockReset();
  supabase.from.mockReset();
  calls = 0;
  unsubscribe = subscribeReviewDataChanged(() => { calls += 1; });
});

afterEach(() => {
  flushReviewDataChanged();
  unsubscribe();
  vi.useRealTimers();
});

const OK = { data: null, error: null };
const FAIL = { data: null, error: { message: 'boom' } };

describe('the signal', () => {
  it('is immediate by default and reaches every subscriber once', () => {
    let second = 0;
    const off = subscribeReviewDataChanged(() => { second += 1; });
    notifyReviewDataChanged();
    expect(calls).toBe(1);
    expect(second).toBe(1);
    off();
    notifyReviewDataChanged();
    expect(calls).toBe(2);
    expect(second).toBe(1);
  });

  it('coalesces debounced calls into one signal after 1.5 seconds', () => {
    notifyReviewDataChanged({ debounce: true });
    vi.advanceTimersByTime(1000);
    notifyReviewDataChanged({ debounce: true });
    vi.advanceTimersByTime(1499);
    expect(calls).toBe(0);
    vi.advanceTimersByTime(1);
    expect(calls).toBe(1);
  });

  it('flush sends a pending debounced signal now, once, and does nothing when none is pending', () => {
    flushReviewDataChanged();
    expect(calls).toBe(0);
    notifyReviewDataChanged({ debounce: true });
    flushReviewDataChanged();
    expect(calls).toBe(1);
    vi.advanceTimersByTime(5000);
    expect(calls).toBe(1);
  });

  it('an immediate signal replaces a pending debounced one (no double signal)', () => {
    notifyReviewDataChanged({ debounce: true });
    notifyReviewDataChanged();
    expect(calls).toBe(1);
    vi.advanceTimersByTime(5000);
    expect(calls).toBe(1);
  });

  it('a failing subscriber does not stop the others', () => {
    const err = vi.spyOn(console, 'error').mockImplementation(() => {});
    const off1 = subscribeReviewDataChanged(() => { throw new Error('bad listener'); });
    notifyReviewDataChanged();
    expect(calls).toBe(1);
    off1();
    err.mockRestore();
  });
});

describe('RPC wrappers', () => {
  const immediate = [
    ['skipCard', skipCard, 'skip_card'],
    ['suspendCard', suspendCard, 'suspend_card'],
    ['unsuspendCard', unsuspendCard, 'unsuspend_card'],
    ['resetCard', resetCard, 'reset_card'],
    ['skipTopicCards', skipTopicCards, 'skip_topic_cards'],
    ['suspendTopicCards', suspendTopicCards, 'suspend_topic_cards'],
    ['addToMyCards', addToMyCards, 'add_to_my_cards'],
    ['removeFromMyCards', removeFromMyCards, 'remove_from_my_cards'],
  ];

  it.each(immediate)('%s calls its RPC with the same arguments, returns the result and signals exactly once on success', async (_n, fn, rpcName) => {
    supabase.rpc.mockResolvedValue({ data: 7, error: null });
    const args = { p_user_id: 'u', p_flashcard_id: 'c' };
    const res = await fn(args);
    expect(supabase.rpc).toHaveBeenCalledTimes(1);
    expect(supabase.rpc).toHaveBeenCalledWith(rpcName, args);
    expect(res).toEqual({ data: 7, error: null });
    expect(calls).toBe(1);
  });

  it.each(immediate)('%s never signals on failure and returns the error result', async (_n, fn) => {
    supabase.rpc.mockResolvedValue(FAIL);
    const res = await fn({ p_user_id: 'u' });
    expect(res).toEqual(FAIL);
    vi.advanceTimersByTime(5000);
    expect(calls).toBe(0);
  });

  it('applyReview is debounced: one signal for rapid answers, none on failure', async () => {
    supabase.rpc.mockResolvedValue(OK);
    await applyReview({ p_user_id: 'u', p_flashcard_id: 'a' });
    await applyReview({ p_user_id: 'u', p_flashcard_id: 'b' });
    expect(supabase.rpc).toHaveBeenNthCalledWith(1, 'apply_review', { p_user_id: 'u', p_flashcard_id: 'a' });
    expect(calls).toBe(0);
    vi.advanceTimersByTime(1500);
    expect(calls).toBe(1);

    supabase.rpc.mockResolvedValue(FAIL);
    await applyReview({ p_user_id: 'u', p_flashcard_id: 'c' });
    vi.advanceTimersByTime(5000);
    expect(calls).toBe(1);
  });
});

describe('bulk My Cards', () => {
  const ids = Array.from({ length: 1200 }, (_, i) => `c${i}`);

  it('runs chunks of 500, sums the counts and signals once after the last chunk', async () => {
    supabase.rpc.mockResolvedValue({ data: { processed: 3, skipped: 1 }, error: null });
    const res = await runBulkMyCards('pause', 'u', ids);
    expect(supabase.rpc).toHaveBeenCalledTimes(3);
    expect(supabase.rpc.mock.calls.map((c) => c[1].p_flashcard_ids.length)).toEqual([500, 500, 200]);
    expect(supabase.rpc.mock.calls.every((c) => c[0] === 'bulk_pause_my_cards')).toBe(true);
    expect(res).toEqual({ processed: 9, skipped: 3, error: null });
    expect(calls).toBe(1);
  });

  it('uses the right RPC for resume and remove', async () => {
    supabase.rpc.mockResolvedValue({ data: { processed: 1, skipped: 0 }, error: null });
    await runBulkMyCards('resume', 'u', ['a']);
    await runBulkMyCards('remove', 'u', ['a']);
    expect(supabase.rpc.mock.calls.map((c) => c[0])).toEqual(['bulk_resume_my_cards', 'bulk_remove_from_my_cards']);
  });

  it('stops at the first failing chunk, still signals once because an earlier chunk succeeded, and returns the error', async () => {
    supabase.rpc
      .mockResolvedValueOnce({ data: { processed: 500, skipped: 0 }, error: null })
      .mockResolvedValueOnce(FAIL);
    const res = await runBulkMyCards('remove', 'u', ids);
    expect(supabase.rpc).toHaveBeenCalledTimes(2);
    expect(res.error).toEqual(FAIL.error);
    expect(res.processed).toBe(500);
    expect(calls).toBe(1);
  });

  it('does not signal when the very first chunk fails or when there is nothing to do', async () => {
    supabase.rpc.mockResolvedValue(FAIL);
    const res = await runBulkMyCards('pause', 'u', ids);
    expect(res.error).toEqual(FAIL.error);
    expect(calls).toBe(0);
    supabase.rpc.mockReset();
    const empty = await runBulkMyCards('pause', 'u', []);
    expect(empty).toEqual({ processed: 0, skipped: 0, error: null });
    expect(supabase.rpc).not.toHaveBeenCalled();
    expect(calls).toBe(0);
  });

  it('refuses an unknown action without calling the database', async () => {
    const res = await runBulkMyCards('explode', 'u', ['a']);
    expect(res.error).toBeTruthy();
    expect(supabase.rpc).not.toHaveBeenCalled();
    expect(calls).toBe(0);
  });
});

describe('profile writes', () => {
  it('signals when course_level or timezone was set and the update succeeded', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    await updateProfileDueFields('u', { course_level: 'CA Inter' });
    expect(supabase.from).toHaveBeenCalledWith('profiles');
    expect(b.update).toHaveBeenCalledWith({ course_level: 'CA Inter' });
    expect(b.eq).toHaveBeenCalledWith('id', 'u');
    expect(calls).toBe(1);
    await updateProfileDueFields('u', { timezone: 'Asia/Kolkata' });
    expect(calls).toBe(2);
    await updateProfileDueFields('u', { full_name: 'A', course_level: null, institution: 'X' });
    expect(calls).toBe(3);
  });

  it('does not signal for other profile fields or on failure', async () => {
    supabase.from.mockReturnValue(builder(OK));
    await updateProfileDueFields('u', { full_name: 'A', institution: 'X' });
    expect(calls).toBe(0);
    supabase.from.mockReturnValue(builder(FAIL));
    const res = await updateProfileDueFields('u', { course_level: 'CA Inter' });
    expect(res).toEqual(FAIL);
    expect(calls).toBe(0);
  });
});

describe('friendship, card and note writes', () => {
  it('setFriendshipStatus updates status and updated_at and signals on success only', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    await setFriendshipStatus('f1', 'accepted');
    expect(supabase.from).toHaveBeenCalledWith('friendships');
    expect(b.update).toHaveBeenCalledWith({ status: 'accepted', updated_at: expect.any(String) });
    expect(b.eq).toHaveBeenCalledWith('id', 'f1');
    expect(calls).toBe(1);
    supabase.from.mockReturnValue(builder(FAIL));
    await setFriendshipStatus('f1', 'rejected');
    expect(calls).toBe(1);
  });

  it('deleteFriendship, deleteFlashcard, deleteFlashcards and deleteNote delete the right rows and signal on success only', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    await deleteFriendship('f1');
    expect(supabase.from).toHaveBeenLastCalledWith('friendships');
    expect(b.delete).toHaveBeenCalled();
    expect(b.eq).toHaveBeenLastCalledWith('id', 'f1');
    await deleteFlashcard('c1');
    expect(supabase.from).toHaveBeenLastCalledWith('flashcards');
    expect(b.eq).toHaveBeenLastCalledWith('id', 'c1');
    await deleteFlashcards(['c1', 'c2']);
    expect(supabase.from).toHaveBeenLastCalledWith('flashcards');
    expect(b.in).toHaveBeenLastCalledWith('id', ['c1', 'c2']);
    await deleteNote('n1');
    expect(supabase.from).toHaveBeenLastCalledWith('notes');
    expect(b.eq).toHaveBeenLastCalledWith('id', 'n1');
    expect(calls).toBe(4);

    supabase.from.mockReturnValue(builder(FAIL));
    await deleteFriendship('f1');
    await deleteFlashcard('c1');
    await deleteFlashcards(['c1']);
    await deleteNote('n1');
    expect(calls).toBe(4);
  });
});

describe('RPC wrappers added from the W1 and W2 evidence', () => {
  const immediate = [
    ['addBatchToMyCards', addBatchToMyCards, 'add_batch_to_my_cards'],
    ['createFlashcardBatches', createFlashcardBatches, 'create_flashcard_batches'],
    ['adminChangeRole', adminChangeRole, 'admin_change_role'],
    ['adminDeleteNote', adminDeleteNote, 'admin_delete_note'],
    ['adminDeleteUserData', adminDeleteUserData, 'admin_delete_user_data'],
    ['adminGrantAccess', adminGrantAccess, 'admin_grant_access'],
    ['adminReactivateUser', adminReactivateUser, 'admin_reactivate_user'],
    ['adminSuspendUser', adminSuspendUser, 'admin_suspend_user'],
    ['approveEducatorApplication', approveEducatorApplication, 'approve_educator_application'],
    ['approveFeaturedNomination', approveFeaturedNomination, 'approve_featured_nomination'],
    ['nominateFeaturedContent', nominateFeaturedContent, 'nominate_featured_content'],
    ['rejectFeaturedNomination', rejectFeaturedNomination, 'reject_featured_nomination'],
    ['unfeatureContent', unfeatureContent, 'unfeature_content'],
    ['linkAccessRequest', linkAccessRequest, 'link_access_request'],
  ];
  const debounced = [
    ['toggleUpvote', toggleUpvote, 'toggle_upvote'],
    ['updateDailyGoal', updateDailyGoal, 'update_daily_goal'],
    ['inviteToGroup', inviteToGroup, 'invite_to_group'],
    ['leaveGroup', leaveGroup, 'leave_group'],
    ['unassignProfessorFromBatch', unassignProfessorFromBatch, 'unassign_professor_from_batch'],
    ['submitAccessRequest', submitAccessRequest, 'submit_access_request'],
    ['submitEducatorApplication', submitEducatorApplication, 'submit_educator_application'],
    ['submitInstituteInquiry', submitInstituteInquiry, 'submit_institute_inquiry'],
  ];

  it.each(immediate)('%s calls its RPC with the same arguments and signals once on success, never on failure', async (_n, fn, rpcName) => {
    supabase.rpc.mockResolvedValue({ data: 1, error: null });
    const args = { p_x: 1 };
    expect(await fn(args)).toEqual({ data: 1, error: null });
    expect(supabase.rpc).toHaveBeenCalledWith(rpcName, args);
    expect(calls).toBe(1);
    supabase.rpc.mockResolvedValue(FAIL);
    await fn(args);
    vi.advanceTimersByTime(5000);
    expect(calls).toBe(1);
  });

  it.each(debounced)('%s signals after the 1.5 second debounce on success and never on failure', async (_n, fn, rpcName) => {
    supabase.rpc.mockResolvedValue(OK);
    await fn({ p_x: 1 });
    await fn({ p_x: 2 });
    expect(supabase.rpc).toHaveBeenCalledWith(rpcName, { p_x: 1 });
    expect(calls).toBe(0);
    vi.advanceTimersByTime(1500);
    expect(calls).toBe(1);
    supabase.rpc.mockResolvedValue(FAIL);
    await fn({ p_x: 3 });
    vi.advanceTimersByTime(5000);
    expect(calls).toBe(1);
  });
});

describe('deck, friend-request and flashcard-update writes', () => {
  it('deleteDeck deletes the deck and signals on success only', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    await deleteDeck('d1');
    expect(supabase.from).toHaveBeenLastCalledWith('flashcard_decks');
    expect(b.eq).toHaveBeenLastCalledWith('id', 'd1');
    expect(calls).toBe(1);
    supabase.from.mockReturnValue(builder(FAIL));
    await deleteDeck('d1');
    expect(calls).toBe(1);
  });

  it('upsertFriendRequest upserts the row with the conflict key and signals on success only', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    const row = { user_id: 'u', friend_id: 'f', status: 'pending' };
    await upsertFriendRequest(row);
    expect(supabase.from).toHaveBeenLastCalledWith('friendships');
    expect(b.upsert).toHaveBeenCalledWith(row, { onConflict: 'user_id, friend_id' });
    expect(calls).toBe(1);
    supabase.from.mockReturnValue(builder(FAIL));
    await upsertFriendRequest(row);
    expect(calls).toBe(1);
  });

  it('updateFlashcardsByBatch signals only when it sets a due-relevant column (target_course, question_type, visibility; subject_id and discipline_id are covered next)', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    await updateFlashcardsByBatch('b1', { batch_description: 'x', topic_id: 't' });
    expect(b.eq).toHaveBeenLastCalledWith('batch_id', 'b1');
    expect(calls).toBe(0);
    await updateFlashcardsByBatch('b1', { target_course: 'CA Final', topic_id: 't' });
    expect(calls).toBe(1);
    supabase.from.mockReturnValue(builder(FAIL));
    await updateFlashcardsByBatch('b1', { target_course: 'CA Final' });
    expect(calls).toBe(1);
  });

  it('updateFlashcardsByBatch also signals when it sets subject_id or discipline_id (T-002 F0)', async () => {
    supabase.from.mockReturnValue(builder(OK));
    await updateFlashcardsByBatch('b1', { subject_id: 's1' });
    expect(calls).toBe(1);
    await updateFlashcardsByBatch('b1', { discipline_id: 'd1', topic_id: 't' });
    expect(calls).toBe(2);
    supabase.from.mockReturnValue(builder(FAIL));
    await updateFlashcardsByBatch('b1', { subject_id: 's1' });
    expect(calls).toBe(2);
  });

  it('updateFlashcardVisibility and updateFlashcardsVisibility set only the visibility and signal on success', async () => {
    const b = builder(OK);
    supabase.from.mockReturnValue(b);
    await updateFlashcardVisibility('c1', 'public');
    expect(b.update).toHaveBeenLastCalledWith({ visibility: 'public' });
    expect(b.eq).toHaveBeenLastCalledWith('id', 'c1');
    await updateFlashcardsVisibility(['c1', 'c2'], 'friends');
    expect(b.update).toHaveBeenLastCalledWith({ visibility: 'friends' });
    expect(b.in).toHaveBeenLastCalledWith('id', ['c1', 'c2']);
    expect(calls).toBe(2);
  });
});
