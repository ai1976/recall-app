// StudyTrackerNotices — the three student-facing states of the shared study tracker (Sprint 8.8.5b2, D-46):
//   * inactivity pause  ("Study timer paused due to inactivity")
//   * four-hour save    ("You've completed 4 hours in this study session")
//   * another tab owns the timed session (replaces the card screen)
// Shared by StudyMode and PracticeMode so both behave identically.

import { Clock, Timer } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

const noClose = () => {}; // these dialogs need an explicit choice

/** Inactivity pause + four-hour dialog. Render once inside the mode's main view. */
export function StudyTrackerNotices({ tracking, onTakeBreak }) {
  return (
    <>
      <Dialog open={tracking.idlePaused} onOpenChange={noClose}>
        <DialogContent hideCloseButton onEscapeKeyDown={(e) => e.preventDefault()} onInteractOutside={(e) => e.preventDefault()}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Clock className="h-5 w-5" /> Study timer paused due to inactivity
            </DialogTitle>
            <DialogDescription>We stopped counting after 10 minutes without activity.</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button onClick={tracking.resume}>Resume studying</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={tracking.capReached || tracking.capSaveFailed} onOpenChange={noClose}>
        <DialogContent hideCloseButton onEscapeKeyDown={(e) => e.preventDefault()} onInteractOutside={(e) => e.preventDefault()}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Timer className="h-5 w-5" /> You&apos;ve completed 4 hours in this study session
            </DialogTitle>
            <DialogDescription>
              {tracking.capSaveFailed
                ? "We couldn't save this session yet. Check your connection and try again — your time is kept safely on this device."
                : 'This session has been saved.'}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="gap-2 sm:gap-0">
            <Button variant="outline" onClick={onTakeBreak}>Take a break</Button>
            {tracking.capSaveFailed ? (
              <Button onClick={() => tracking.finalize({ reason: 'cap' })}>Try saving again</Button>
            ) : (
              <Button onClick={tracking.restart}>Continue studying</Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** Full-screen notice when another RevisOp tab in this browser already owns the timed session. */
export function OtherTabBlockedNotice({ onTryAgain, onBack }) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-rv-bg-0 font-plex p-4">
      <div className="max-w-md w-full rounded-lg border border-rv-border bg-rv-bg-1 p-6 space-y-4 text-center">
        <h2 className="text-lg font-semibold text-rv-ink-900">A study session is already running in another RevisOp tab</h2>
        <p className="text-sm text-rv-ink-600">
          Return to that session, or end it there before starting another, so your study time is never counted twice.
        </p>
        <div className="flex flex-col sm:flex-row gap-2 justify-center">
          <Button variant="outline" onClick={onBack}>Go back</Button>
          <Button onClick={onTryAgain}>Try again</Button>
        </div>
      </div>
    </div>
  );
}
