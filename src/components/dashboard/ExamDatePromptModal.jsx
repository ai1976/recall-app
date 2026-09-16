// ExamDatePromptModal.jsx — Sprint 8.4
// Dismissible popup shown once on first login (any student, new or
// pre-existing) who hasn't set an exam date/month and hasn't dismissed this
// before. Same non-nagging pattern as the daily-goal prompt: dismiss is
// permanent (has_dismissed_exam_prompt), the nav chip + Dashboard CTA remain
// as the ongoing low-key reminder. Skippable — never blocks anything.

import { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Loader2, X, CalendarClock } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useExamDateContext } from '@/contexts/ExamDateContext';
import { MONTH_NAMES, buildExamMonthValue } from '@/lib/examDate';

const CURRENT_YEAR = new Date().getFullYear();
const YEAR_OPTIONS = [CURRENT_YEAR, CURRENT_YEAR + 1, CURRENT_YEAR + 2];

export default function ExamDatePromptModal({ open, onDismiss }) {
  const { toast } = useToast();
  const { saveExamDate, dismissPrompt } = useExamDateContext();

  const [mode, setMode] = useState('month'); // 'month' | 'exact'
  const [month, setMonth] = useState('');
  const [year, setYear] = useState(String(CURRENT_YEAR));
  const [exactDate, setExactDate] = useState('');
  const [saving, setSaving] = useState(false);

  const handleSkip = async () => {
    onDismiss();
    await dismissPrompt();
  };

  const handleSave = async () => {
    if (mode === 'exact' && !exactDate) {
      toast({ title: 'Pick a date', description: 'Select your exam date, or switch to "Only the month".', variant: 'destructive' });
      return;
    }
    if (mode === 'month' && !month) {
      toast({ title: 'Pick a month', description: 'Select the month your exam is expected in.', variant: 'destructive' });
      return;
    }

    setSaving(true);
    try {
      const { error } = mode === 'exact'
        ? await saveExamDate({ examDate: exactDate, examMonth: null })
        : await saveExamDate({ examDate: null, examMonth: buildExamMonthValue(Number(year), Number(month)) });

      if (error) throw error;

      toast({ title: 'Exam date saved', description: 'You can change this anytime in Profile Settings.' });
      onDismiss();
      await dismissPrompt();
    } catch (error) {
      toast({ title: 'Error', description: error.message, variant: 'destructive' });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={(o) => !o && handleSkip()}>
      <DialogContent className="sm:max-w-md">
        <button
          onClick={handleSkip}
          className="absolute right-4 top-4 text-gray-400 hover:text-gray-600 rounded-sm focus:outline-none"
        >
          <X className="h-4 w-4" />
        </button>

        <DialogHeader>
          <div className="flex justify-center mb-2">
            <CalendarClock className="h-10 w-10 text-amber-500" />
          </div>
          <DialogTitle className="text-center">When's your exam?</DialogTitle>
          <DialogDescription className="text-center">
            RevisOp can show you a countdown once we know. Don't know the exact date yet? Just the month is fine.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 pt-2">
          <div className="flex gap-2">
            <Button
              type="button"
              variant={mode === 'month' ? 'default' : 'outline'}
              size="sm"
              className="flex-1"
              onClick={() => setMode('month')}
            >
              Only the month
            </Button>
            <Button
              type="button"
              variant={mode === 'exact' ? 'default' : 'outline'}
              size="sm"
              className="flex-1"
              onClick={() => setMode('exact')}
            >
              I know the exact date
            </Button>
          </div>

          {mode === 'month' ? (
            <div className="flex gap-2">
              <div className="flex-1 space-y-1.5">
                <Label className="text-xs">Month</Label>
                <Select value={month} onValueChange={setMonth}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select month" />
                  </SelectTrigger>
                  <SelectContent>
                    {MONTH_NAMES.map((name, i) => (
                      <SelectItem key={name} value={String(i + 1)}>{name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="w-28 space-y-1.5">
                <Label className="text-xs">Year</Label>
                <Select value={year} onValueChange={setYear}>
                  <SelectTrigger>
                    <SelectValue placeholder="Year" />
                  </SelectTrigger>
                  <SelectContent>
                    {YEAR_OPTIONS.map((y) => (
                      <SelectItem key={y} value={String(y)}>{y}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
          ) : (
            <div className="space-y-1.5">
              <Label className="text-xs">Exam date</Label>
              <Input
                type="date"
                value={exactDate}
                onChange={(e) => setExactDate(e.target.value)}
              />
            </div>
          )}

          <div className="flex gap-2 pt-1">
            <Button variant="ghost" className="flex-1" onClick={handleSkip} disabled={saving}>
              Skip for now
            </Button>
            <Button className="flex-1" onClick={handleSave} disabled={saving}>
              {saving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              Save
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
