// BatchBulkActions — Sprint 8.8.5b5 (D-49, deferred bug #5).
// Two action bars for the Admin Dashboard:
//   <BulkAddToBatchBar>       Users tab: add many selected students to ONE batch (admin_bulk_add_to_batch)
//   <BulkResolveRequestsBar>  Batch Groups tab: approve / reject many pending join requests (admin_bulk_resolve_batch_requests)
// Both use an in-app confirmation dialog (not window.confirm) and show an honest result summary: what changed, and every
// skipped id with its reason. The server re-checks everything; the UI only sends explicit ids.

import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

const MAX_PER_CALL = 500;

const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;

function ResultDialog({ result, onClose }) {
  return (
    <Dialog open={!!result} onOpenChange={(open) => { if (!open) onClose(); }}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{result?.title}</DialogTitle>
          <DialogDescription>{result?.summary}</DialogDescription>
        </DialogHeader>
        {result?.lines?.length > 0 && (
          <ul className="text-sm text-gray-700 list-disc pl-5 space-y-1">
            {result.lines.map((l) => <li key={l}>{l}</li>)}
          </ul>
        )}
        {result?.error && <p role="alert" className="text-sm text-red-600">{result.error}</p>}
        <DialogFooter>
          <Button onClick={onClose}>Done</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

const errorText = (err) => {
  const m = String(err?.message || '');
  if (m.includes('batch_archived')) return 'That batch has been archived, so nobody can be added to it.';
  if (m.includes('not_admin')) return 'Only admins can do this.';
  if (m.includes('max 500')) return 'Too many selected at once (the limit is 500). Select fewer and try again.';
  return m || 'Something went wrong. Nothing was changed — please try again.';
};

/** Users tab: add the selected students to one batch. */
export function BulkAddToBatchBar({ selectedIds, batchGroups, onClear, onDone }) {
  const [groupId, setGroupId] = useState('');
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState(null);

  const count = selectedIds.length;
  const group = batchGroups.find((g) => g.id === groupId);
  if (count === 0 && !result) return null;

  const run = async () => {
    setBusy(true);
    try {
      const { data, error } = await supabase.rpc('admin_bulk_add_to_batch', {
        p_group_id: groupId,
        p_user_ids: selectedIds.slice(0, MAX_PER_CALL),
      });
      if (error) throw error;
      const lines = [];
      if (data.already_active) lines.push(`${plural(data.already_active, 'student was', 'students were')} already in the batch — left as they were.`);
      if (data.skipped_not_enrolled) lines.push(`${plural(data.skipped_not_enrolled, 'student', 'students')} skipped: not yet enrolled (Tier B) — grant access first.`);
      if (data.skipped_suspended) lines.push(`${plural(data.skipped_suspended, 'student', 'students')} skipped: suspended.`);
      if (data.skipped_not_student) lines.push(`${plural(data.skipped_not_student, 'account', 'accounts')} skipped: not a student.`);
      if (data.skipped_not_found) lines.push(`${plural(data.skipped_not_found, 'account', 'accounts')} skipped: not found.`);
      setResult({
        title: data.added > 0 ? `Added ${plural(data.added, 'student', 'students')} to ${group?.name || 'the batch'}` : 'Nobody was added',
        summary: data.added > 0
          ? 'Each added student got a notification and now has access to the batch\'s shared content.'
          : 'Everyone selected was already in the batch or could not be added.',
        lines,
      });
      setConfirmOpen(false);
      setGroupId('');
      onClear();
      onDone?.();
    } catch (err) {
      console.error('admin_bulk_add_to_batch:', err);
      setConfirmOpen(false);
      setResult({ title: 'Nothing was changed', summary: '', lines: [], error: errorText(err) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      {count > 0 && (
        <div className="sticky top-2 z-20 mb-3 flex flex-wrap items-center gap-2 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm shadow-sm">
          <span className="font-medium text-gray-900">{plural(count, 'student', 'students')} selected</span>
          <select
            value={groupId}
            onChange={(e) => setGroupId(e.target.value)}
            aria-label="Batch to add the selected students to"
            className="text-sm border border-gray-300 rounded px-2 py-1.5 bg-white max-w-[16rem]"
          >
            <option value="">Choose a batch…</option>
            {batchGroups.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
          </select>
          <Button size="sm" disabled={!groupId || count > MAX_PER_CALL} onClick={() => setConfirmOpen(true)}>
            Add to batch
          </Button>
          <Button size="sm" variant="ghost" onClick={onClear}>Clear selection</Button>
          {count > MAX_PER_CALL && <span className="text-xs text-red-600">Select at most {MAX_PER_CALL} at a time.</span>}
        </div>
      )}

      <Dialog open={confirmOpen} onOpenChange={(open) => { if (!busy) setConfirmOpen(open); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add {plural(count, 'student', 'students')} to {group?.name}?</DialogTitle>
            <DialogDescription>
              They will be notified and get access to this batch&apos;s shared content. Students who are not yet enrolled,
              are suspended, or are already in the batch are skipped automatically.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-2 sm:gap-0">
            <Button variant="outline" disabled={busy} onClick={() => setConfirmOpen(false)}>Cancel</Button>
            <Button disabled={busy} onClick={run}>{busy ? 'Adding…' : 'Add to batch'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ResultDialog result={result} onClose={() => setResult(null)} />
    </>
  );
}

/** Batch Groups tab: approve or reject the selected pending requests. */
export function BulkResolveRequestsBar({ selectedIds, onClear, onDone }) {
  const [action, setAction] = useState(null); // 'approve' | 'reject' | null (confirm dialog open for this action)
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState(null);

  const count = selectedIds.length;
  if (count === 0 && !result) return null;

  const run = async () => {
    setBusy(true);
    const verb = action;
    try {
      const { data, error } = await supabase.rpc('admin_bulk_resolve_batch_requests', {
        p_action: verb,
        p_membership_ids: selectedIds.slice(0, MAX_PER_CALL),
      });
      if (error) throw error;
      const lines = [];
      if (data.skipped_archived) lines.push(`${plural(data.skipped_archived, 'request', 'requests')} skipped: the batch has been archived.`);
      if (data.skipped_resolved) lines.push(`${plural(data.skipped_resolved, 'request', 'requests')} skipped: already handled.`);
      setResult({
        title: data.processed > 0
          ? `${verb === 'approve' ? 'Approved' : 'Rejected'} ${plural(data.processed, 'request', 'requests')}`
          : 'Nothing was changed',
        summary: data.processed > 0 && verb === 'approve'
          ? 'Approved students were notified and now have access to the batch\'s shared content.'
          : data.processed > 0 ? 'Rejected requests were removed. Those students were not notified.' : 'Every selected request was skipped.',
        lines,
      });
      setAction(null);
      onClear();
      onDone?.();
    } catch (err) {
      console.error('admin_bulk_resolve_batch_requests:', err);
      setAction(null);
      setResult({ title: 'Nothing was changed', summary: '', lines: [], error: errorText(err) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      {count > 0 && (
        <div className="sticky top-2 z-20 mb-3 flex flex-wrap items-center gap-2 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm shadow-sm">
          <span className="font-medium text-gray-900">{plural(count, 'request', 'requests')} selected</span>
          <Button size="sm" variant="outline" className="text-green-600 border-green-300" disabled={count > MAX_PER_CALL} onClick={() => setAction('approve')}>
            Approve selected
          </Button>
          <Button size="sm" variant="outline" className="text-red-600" disabled={count > MAX_PER_CALL} onClick={() => setAction('reject')}>
            Reject selected
          </Button>
          <Button size="sm" variant="ghost" onClick={onClear}>Clear selection</Button>
          {count > MAX_PER_CALL && <span className="text-xs text-red-600">Select at most {MAX_PER_CALL} at a time.</span>}
        </div>
      )}

      <Dialog open={!!action} onOpenChange={(open) => { if (!busy && !open) setAction(null); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{action === 'approve' ? 'Approve' : 'Reject'} {plural(count, 'request', 'requests')}?</DialogTitle>
            <DialogDescription>
              {action === 'approve'
                ? 'The students will be notified and get access to their batch\'s shared content.'
                : 'The requests will be removed. The students are not notified and can request again with the invite link.'}
              {' '}Requests in archived batches or already handled are skipped automatically.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-2 sm:gap-0">
            <Button variant="outline" disabled={busy} onClick={() => setAction(null)}>Cancel</Button>
            <Button disabled={busy} variant={action === 'reject' ? 'destructive' : 'default'} onClick={run}>
              {busy ? 'Working…' : action === 'approve' ? 'Approve' : 'Reject'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ResultDialog result={result} onClose={() => setResult(null)} />
    </>
  );
}
