import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Users, Share2, BookOpen, ChevronRight, ChevronLeft, X } from 'lucide-react';

const STEPS = [
  {
    icon: <Users className="h-12 w-12 text-indigo-500" />,
    title: 'Join your course batch group',
    description:
      'You\'ve been auto-enrolled in a batch group for your course. Head to Study Groups to connect with classmates, share notes, and study together.',
    action: {
      label: 'Go to Study Groups',
      path: '/dashboard/groups',
    },
  },
  {
    icon: <Users className="h-12 w-12 text-blue-500" />,
    title: 'Create your own study group',
    description:
      'Study with a smaller circle — create a group and invite friends via link or WhatsApp. Share notes and study sets exclusively with your group.',
    action: {
      label: 'Create a Group',
      path: '/dashboard/groups/new',
    },
  },
  {
    icon: <Share2 className="h-12 w-12 text-green-500" />,
    title: 'Share study sets via WhatsApp',
    description:
      'Found a great study set? Share it with friends in one tap. Public study sets have a share button that generates a WhatsApp-ready preview link.',
    action: {
      label: 'Browse Study Sets',
      path: '/dashboard/review-flashcards',
    },
  },
];

export default function OnboardingModal({ open, onDismiss }) {
  const navigate = useNavigate();
  const [step, setStep] = useState(0);

  const current = STEPS[step];
  const isFirst = step === 0;
  const isLast = step === STEPS.length - 1;

  function handleAction() {
    onDismiss();
    navigate(current.action.path);
  }

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onDismiss()}>
      <DialogContent className="sm:max-w-md" onInteractOutside={(e) => e.preventDefault()}>
        <button
          onClick={onDismiss}
          className="absolute right-4 top-4 text-gray-400 hover:text-gray-600 rounded-sm focus:outline-none"
        >
          <X className="h-4 w-4" />
        </button>

        <DialogHeader className="sr-only">
          <DialogTitle>Welcome to Recall</DialogTitle>
          <DialogDescription>Get started with these key features</DialogDescription>
        </DialogHeader>

        {/* Progress dots */}
        <div className="flex justify-center gap-1.5 mb-6 mt-2">
          {STEPS.map((_, i) => (
            <div
              key={i}
              className={`h-1.5 rounded-full transition-all ${
                i === step ? 'w-6 bg-indigo-600' : 'w-1.5 bg-gray-200'
              }`}
            />
          ))}
        </div>

        {/* Step content */}
        <div className="flex flex-col items-center text-center px-4 pb-2">
          <div className="mb-5">{current.icon}</div>
          <h2 className="text-xl font-bold text-gray-900 mb-3">{current.title}</h2>
          <p className="text-sm text-gray-500 leading-relaxed mb-8">{current.description}</p>
        </div>

        {/* Navigation */}
        <div className="flex items-center justify-between gap-3 px-4 pb-2">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setStep(s => s - 1)}
            disabled={isFirst}
            className="text-gray-400"
          >
            <ChevronLeft className="h-4 w-4" />
          </Button>

          <div className="flex gap-2 flex-1 justify-center">
            <Button
              variant="outline"
              size="sm"
              onClick={handleAction}
              className="flex-1 max-w-[160px]"
            >
              <BookOpen className="h-4 w-4 mr-1" />
              {current.action.label}
            </Button>
            {isLast ? (
              <Button size="sm" onClick={onDismiss} className="flex-1 max-w-[120px]">
                Done
              </Button>
            ) : (
              <Button size="sm" onClick={() => setStep(s => s + 1)} className="flex-1 max-w-[120px]">
                Next
                <ChevronRight className="h-4 w-4 ml-1" />
              </Button>
            )}
          </div>

          <div className="w-8" /> {/* spacer for symmetry */}
        </div>
      </DialogContent>
    </Dialog>
  );
}
