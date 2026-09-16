// ExamDateChip.jsx — Sprint 8.4
// Nav-bar exam-date indicator, sits beside StudyTimerChip in both NavDesktop
// and NavMobile. Student-only — self-gates via NavDataContext's isStudent.
// Three states: exact date → days-remaining countdown; month only → text,
// no fabricated countdown (D-15-style — a month-level guess doesn't earn a
// day count); neither set → low-key "Set exam date" CTA. Tapping any state
// goes to Profile Settings, where the value is set/changed.

import { useNavigate } from 'react-router-dom';
import { CalendarClock } from 'lucide-react';
import { useNavData } from '@/contexts/NavDataContext';
import { useExamDateContext } from '@/contexts/ExamDateContext';
import { daysUntilExamDate, formatExamMonth } from '@/lib/examDate';

export default function ExamDateChip({ compact = false }) {
  const navigate = useNavigate();
  const { isStudent } = useNavData();
  const { examDate, examMonth, loading } = useExamDateContext();

  if (!isStudent || loading) return null;

  const goToSettings = () => navigate('/dashboard/settings');

  if (examDate) {
    const days = daysUntilExamDate(examDate);
    const label = days < 0 ? 'Exam date passed' : days === 0 ? 'Exam is today' : `${days}d left`;
    return (
      <button
        type="button"
        onClick={goToSettings}
        aria-label={`Exam in ${days} days — tap to edit in Profile Settings`}
        className="flex items-center gap-1 rounded-full border border-rv-navy-100 bg-rv-navy-50 px-2 py-1 text-xs font-medium text-rv-navy transition-colors hover:bg-rv-navy-100"
      >
        <CalendarClock className="h-3.5 w-3.5" />
        <span>{compact ? (days < 0 ? '—' : `${days}d`) : label}</span>
      </button>
    );
  }

  if (examMonth) {
    const label = formatExamMonth(examMonth);
    return (
      <button
        type="button"
        onClick={goToSettings}
        aria-label={`Exam expected ${label} — tap to refine in Profile Settings`}
        className="flex items-center gap-1 rounded-full border border-rv-navy-100 bg-rv-navy-50 px-2 py-1 text-xs font-medium text-rv-navy transition-colors hover:bg-rv-navy-100"
      >
        <CalendarClock className="h-3.5 w-3.5" />
        <span>{compact ? label.split(' ')[0] : `Exam: ${label}`}</span>
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={goToSettings}
      aria-label="Set your exam date in Profile Settings"
      className="flex items-center gap-1 rounded-full border border-dashed border-rv-border bg-transparent px-2 py-1 text-xs font-medium text-rv-ink-400 transition-colors hover:bg-rv-bg-2 hover:text-rv-ink-600"
    >
      <CalendarClock className="h-3.5 w-3.5" />
      {!compact && <span>Set exam date</span>}
    </button>
  );
}
