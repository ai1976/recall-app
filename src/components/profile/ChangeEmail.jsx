// ChangeEmail — Sprint 8.8.5b6 (D-50, deferred bug #6). Self-service secure email change for Profile Settings.
//
// Uses Supabase's own flow: auth.updateUser({ email }). With "Secure email change" ON (confirmed in the dashboard 01/10/2026),
// Supabase emails a confirmation link to BOTH the current and the new address; the login email changes only after both are opened.
// The Auth -> profiles.email copy and the audit entry are written by the database trigger trg_sync_profile_email_from_auth (SQL
// 02) - this component never writes the profile or the audit log. Messages are deliberately neutral about whether an address
// already belongs to another account (no account enumeration).

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function ChangeEmail({ currentEmail }) {
  const [open, setOpen] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [pending, setPending] = useState(null); // an address waiting for confirmation, if any

  // A change that was started earlier (and not yet confirmed on both addresses) lives on the Auth user.
  useEffect(() => {
    let cancelled = false;
    supabase.auth.getUser().then(({ data }) => {
      if (!cancelled) setPending(data?.user?.new_email || null);
    });
    return () => { cancelled = true; };
  }, [currentEmail]);

  const request = async (address) => {
    setBusy(true);
    setError('');
    try {
      const { error: err } = await supabase.auth.updateUser(
        { email: address },
        { emailRedirectTo: `${window.location.origin}/dashboard/settings` },
      );
      if (err) {
        const text = `${err.code || ''} ${err.message || ''}`;
        if (/rate|too many|429/i.test(text)) {
          setError('Too many requests. Please wait a few minutes and try again.');
        } else if (/already|exists|registered|invalid/i.test(text)) {
          setError("We couldn't use that address. If it belongs to another account, please choose a different one.");
        } else {
          setError("We couldn't start the change. Please try again.");
        }
        return false;
      }
      setPending(address);
      return true;
    } catch (e) {
      console.error('ChangeEmail:', e);
      setError("We couldn't start the change. Please try again.");
      return false;
    } finally {
      setBusy(false);
    }
  };

  const submit = async (e) => {
    e.preventDefault();
    const candidate = newEmail.trim().toLowerCase();
    if (!EMAIL_RE.test(candidate)) { setError('Enter a valid email address.'); return; }
    if (candidate === (currentEmail || '').toLowerCase()) { setError('That is already your email address.'); return; }
    if (await request(candidate)) { setOpen(false); setNewEmail(''); }
  };

  return (
    <div className="space-y-2">
      <Label htmlFor="email">Email</Label>
      <Input id="email" value={currentEmail} disabled className="bg-gray-50" />

      {pending && (
        <div role="status" className="rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-gray-800 space-y-2">
          <p>
            A change to <strong>{pending}</strong> is waiting for confirmation. Open the confirmation links we sent to
            <strong> both</strong> your current address and the new one. Until both are opened, you keep logging in with
            your current email.
          </p>
          <Button type="button" size="sm" variant="outline" disabled={busy} onClick={() => request(pending)}>
            {busy ? 'Sending…' : 'Send the links again'}
          </Button>
          {error && !open && <p role="alert" className="text-red-600">{error}</p>}
        </div>
      )}

      {!open ? (
        <div className="flex items-center gap-3">
          <Button type="button" size="sm" variant="outline" onClick={() => { setOpen(true); setError(''); }}>
            Change email
          </Button>
          <p className="text-xs text-gray-500">
            For your security we ask you to confirm from both your current and your new address.
          </p>
        </div>
      ) : (
        <form onSubmit={submit} className="space-y-2 rounded-md border border-gray-200 p-3">
          <Label htmlFor="newEmail">New email address</Label>
          <Input
            id="newEmail"
            type="email"
            autoComplete="email"
            value={newEmail}
            onChange={(e) => setNewEmail(e.target.value)}
            placeholder="name@example.com"
            disabled={busy}
          />
          {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
          <div className="flex gap-2">
            <Button type="submit" size="sm" disabled={busy || !newEmail.trim()}>
              {busy ? 'Sending…' : 'Send confirmation links'}
            </Button>
            <Button type="button" size="sm" variant="ghost" disabled={busy} onClick={() => { setOpen(false); setError(''); setNewEmail(''); }}>
              Cancel
            </Button>
          </div>
          <p className="text-xs text-gray-500">
            If you no longer have access to your current email, contact support — we can help after verifying your identity.
          </p>
        </form>
      )}
    </div>
  );
}
