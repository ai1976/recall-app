import { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { SITUATIONS } from '@/data/guideContent';

/**
 * GuideInfoModal — inline contextual explainer for public share pages.
 *
 * Pulls content directly from guideContent.js (single source of truth).
 * Never navigates away — safe to use on pages with postAuthRedirect funnels.
 *
 * Props:
 *   situationId  — SITUATIONS[n].id  (e.g. 'studying', 'social')
 *   triggerLabel — text shown on the subtle trigger button
 */
export default function GuideInfoModal({ situationId, triggerLabel }) {
  const [open, setOpen] = useState(false);
  const situation = SITUATIONS.find((s) => s.id === situationId);
  if (!situation) return null;

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="text-xs text-gray-400 hover:text-indigo-600 underline underline-offset-2 transition-colors mt-3 block mx-auto"
      >
        {triggerLabel}
      </button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-lg">
              <span>{situation.emoji}</span>
              <span>{situation.headline}</span>
            </DialogTitle>
          </DialogHeader>

          <div className="space-y-5 py-2">
            {situation.steps.map((step, i) => (
              <div key={i} className="flex gap-3">
                <div className="flex-shrink-0 w-6 h-6 rounded-full bg-indigo-100 text-indigo-700 text-xs font-bold flex items-center justify-center mt-0.5">
                  {i + 1}
                </div>
                <div>
                  <p className="text-sm font-semibold text-gray-900">{step.label}</p>
                  <p className="text-sm text-gray-500 mt-0.5 leading-relaxed">{step.detail}</p>
                </div>
              </div>
            ))}
          </div>

          <DialogFooter className="pt-2">
            <Button onClick={() => setOpen(false)} className="w-full sm:w-auto">
              Got it
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
