// StudyRecovery — Sprint 8.8.5b2 (D-46). Runs the study-session recovery pass once the student is signed in (and
// again whenever they leave a study route, since the browser Back button only checkpoints locally), and tells them
// in one lightweight toast what happened. Renders nothing.

import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { recoverInterrupted, subscribeRecovery } from '@/lib/studyTracker';

const STUDY_ROUTES = ['/dashboard/study', '/dashboard/practice', '/dashboard/review-session'];

const formatDuration = (seconds) => {
  const m = Math.round(seconds / 60);
  if (m < 1) return 'less than a minute';
  if (m < 60) return `${m} minute${m === 1 ? '' : 's'}`;
  const h = Math.floor(m / 60);
  const r = m % 60;
  return r ? `${h}h ${r}m` : `${h}h`;
};

// sessionDate is a plain YYYY-MM-DD: parse the parts directly, never through a timezone-shifting Date parse.
const formatDay = (ymd) => {
  const [y, mo, d] = ymd.split('-').map(Number);
  return new Date(y, mo - 1, d).toLocaleDateString('en-GB', { day: 'numeric', month: 'long' });
};

export default function StudyRecovery() {
  const { user } = useAuth();
  const { toast } = useToast();
  const { pathname } = useLocation();

  useEffect(() => subscribeRecovery((summary) => {
    const lostSomething = summary.discarded.length > 0 || summary.legacyDiscarded;
    if (summary.recovered.length) {
      const parts = summary.recovered.map((r) => `${formatDuration(r.seconds)} from ${formatDay(r.sessionDate)}`);
      toast({
        title: 'Recovered study session',
        description: `${parts.join('; ')} ${parts.length === 1 ? 'was' : 'were'} saved after an interrupted session.${
          lostSomething ? " An older session couldn't be verified and was discarded." : ''}`,
      });
    } else if (lostSomething) {
      toast({
        title: "Previous study session wasn't saved",
        description: 'It had become too old or unverifiable, so RevisOp discarded it to keep your study statistics accurate.',
      });
    }
  }), [toast]);

  const onStudyRoute = STUDY_ROUTES.some((r) => pathname.startsWith(r));
  useEffect(() => {
    if (!user?.id || onStudyRoute) return undefined;
    const id = setTimeout(() => { recoverInterrupted(user.id); }, 1500);
    return () => clearTimeout(id);
  }, [user?.id, onStudyRoute, pathname]);

  return null;
}
