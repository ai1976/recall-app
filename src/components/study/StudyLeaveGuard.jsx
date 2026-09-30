// StudyLeaveGuard — Sprint 8.8.5b2 (D-46). While a Study/Practice session is live, in-app navigation is
// intercepted and the student chooses: End session & log time / Continue studying / Leave without logging.
//
// The app uses <BrowserRouter> (not a data router), so useBlocker is unavailable. Instead this wraps the router's
// `navigator.push / replace / go` — the single path every <Link>, navigate() and <Navigate> goes through.
// Same-page updates (same pathname) pass through untouched. The mode's own Finish/Exit buttons finalize first, which
// clears the guard, so they never see this modal. Browser refresh / close is handled separately (beforeunload in
// useStudyTracker); the browser Back button falls through to the tracker's unmount checkpoint + recovery.

import { useContext, useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { UNSAFE_NavigationContext, useLocation } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { trackerRegistry } from '@/lib/studyTracker';

const targetPath = (to, current) => {
  if (typeof to === 'string') return to.split(/[?#]/)[0];
  if (to && typeof to === 'object' && typeof to.pathname === 'string') return to.pathname;
  return current;
};

export default function StudyLeaveGuard() {
  const { navigator } = useContext(UNSAFE_NavigationContext);
  const location = useLocation();
  const locationRef = useRef(location);
  locationRef.current = location;

  const guarded = useSyncExternalStore(
    (cb) => trackerRegistry.subscribe(cb),
    () => trackerRegistry.isGuarded(),
    () => false,
  );

  const [pending, setPending] = useState(null); // { run }
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!navigator) return undefined;
    const orig = { push: navigator.push, replace: navigator.replace, go: navigator.go };
    const wrap = (kind) => (...args) => {
      const t = trackerRegistry.current;
      if (!t || !t.isGuarded()) return orig[kind].apply(navigator, args);
      if (kind !== 'go' && targetPath(args[0], locationRef.current.pathname) === locationRef.current.pathname) {
        return orig[kind].apply(navigator, args);
      }
      setError(null);
      setPending({ run: () => orig[kind].apply(navigator, args) });
      return undefined;
    };
    // Deliberate: wrapping the router's navigator is the only interception point a non-data BrowserRouter offers.
    /* eslint-disable react-hooks/immutability */
    navigator.push = wrap('push');
    navigator.replace = wrap('replace');
    navigator.go = wrap('go');
    return () => {
      navigator.push = orig.push;
      navigator.replace = orig.replace;
      navigator.go = orig.go;
    };
    /* eslint-enable react-hooks/immutability */
  }, [navigator]);

  // The session ended some other way while the modal was open (e.g. the 4-hour save): nothing left to ask.
  useEffect(() => {
    if (!guarded && pending && !busy) setPending(null);
  }, [guarded, pending, busy]);

  const proceed = () => {
    const p = pending;
    setPending(null);
    setError(null);
    if (p) p.run();
  };

  const endAndLog = async () => {
    const t = trackerRegistry.current;
    if (!t) { proceed(); return; }
    setBusy(true);
    setError(null);
    const res = await t.finalize({ reason: 'leave' });
    setBusy(false);
    if (res.outcome === 'failed') {
      // The recoverable local session is kept; the student can retry or explicitly leave without logging.
      setError("We couldn't save your study time. Check your connection and try again, or leave without logging.");
      return;
    }
    proceed();
  };

  const leaveWithoutLogging = () => {
    const t = trackerRegistry.current;
    if (t) t.discard();
    proceed();
  };

  return (
    <Dialog open={!!pending} onOpenChange={(open) => { if (!open && !busy) { setPending(null); setError(null); } }}>
      <DialogContent hideCloseButton>
        <DialogHeader>
          <DialogTitle>Study session in progress</DialogTitle>
          <DialogDescription>
            You&apos;re in the middle of a study session. Save your time before you leave, or keep studying.
          </DialogDescription>
        </DialogHeader>
        {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
        <DialogFooter className="gap-2 sm:gap-0">
          <Button variant="ghost" disabled={busy} onClick={leaveWithoutLogging}>Leave without logging</Button>
          <Button variant="outline" disabled={busy} onClick={() => { setPending(null); setError(null); }}>Continue studying</Button>
          <Button disabled={busy} onClick={endAndLog}>
            {busy ? 'Saving…' : error ? 'Retry saving' : 'End session & log time'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
