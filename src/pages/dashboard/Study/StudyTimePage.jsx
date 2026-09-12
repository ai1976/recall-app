// StudyTimePage.jsx
// Dedicated route for the manual "offline study" timer (Sprint 7.3-C).
// Reachable from both the desktop Create dropdown and the mobile ＋ sheet —
// unlike Bulk Upload, this is mobile-relevant: a student starts it, then puts
// the phone away to read a physical book.
//
// A thin host for StudyTimerWidget, which itself is a thin consumer of
// StudyTimerContext — all state lives there, so this page has nothing of its
// own to wire up.

import PageContainer from '@/components/layout/PageContainer';
import StudyTimerWidget from '@/components/dashboard/StudyTimerWidget';

export default function StudyTimePage() {
  return (
    <PageContainer width="narrow">
      <div className="mb-6">
        <h1 className="text-2xl sm:text-3xl font-bold">Log Study Time</h1>
        <p className="text-rv-ink-400 mt-2">
          Track offline study — reading notes, working through a physical book,
          anything away from the app.
        </p>
      </div>
      <StudyTimerWidget />
    </PageContainer>
  );
}
