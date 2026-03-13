import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
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
import {
  Calendar,
  TrendingUp,
  Target,
  Award,
  PauseCircle,
  PlayCircle,
  ChevronDown,
  ChevronRight,
  Clock,
  BookOpen,
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useCourseContext } from '@/contexts/CourseContext';
import PageContainer from '@/components/layout/PageContainer';
import StudyHeatmap from '@/components/progress/StudyHeatmap';
import SubjectMasteryTable from '@/components/progress/SubjectMasteryTable';

// ─── Helpers ─────────────────────────────────────────────────────────────────
const formatLocalDate = (date) => new Date(date).toLocaleDateString('en-CA');

const WINDOW_OPTIONS = [
  { key: '7d',  label: 'Last 7 Days' },
  { key: '30d', label: 'Last 30 Days' },
  { key: 'all', label: 'All Time' },
];

const QT_LABELS = {
  flashcard:    'Flashcard',
  mcq:          'MCQ',
  true_false:   'True / False',
  short_answer: 'Short Answer',
  theory:       'Theory',
  fill_blank:   'Fill in the Blanks',
  match:        'Match the Following',
  case_study:   'Case Study',
  correct_incorrect: 'Correct / Incorrect',
};
const qtLabel = (key) => QT_LABELS[key] ?? key;

// ─── Main component ───────────────────────────────────────────────────────────
export default function MyProgress() {
  const { user } = useAuth();
  const { toast } = useToast();
  const { teachingCourses } = useCourseContext();

  // ── Time-window selector ─────────────────────────────────────────────────
  const [window, setWindow] = useState('7d');

  // ── Content partition tab ────────────────────────────────────────────────
  const [tab, setTab] = useState('all');

  // ── Selected course for the "By Course" tab ───────────────────────────────
  const [selectedCourse, setSelectedCourse] = useState(null);

  // ── User profile (for course_level) ──────────────────────────────────────
  const [profile, setProfile] = useState(null);

  // ── Window-driven stat cards ──────────────────────────────────────────────
  const [windowStats, setWindowStats] = useState({ reviewed: 0, accuracy: 0 });
  const [windowLoading, setWindowLoading] = useState(true);

  // ── Lifetime stats (streak + mastered) ───────────────────────────────────
  const [lifetimeStats, setLifetimeStats] = useState({ streak: 0, mastered: 0 });
  const [lifetimeLoading, setLifetimeLoading] = useState(true);

  // ── Due forecast ─────────────────────────────────────────────────────────
  const [forecast, setForecast] = useState(null);
  const [forecastLoading, setForecastLoading] = useState(true);

  // ── Question type performance ─────────────────────────────────────────────
  const [qtPerf, setQtPerf] = useState([]);
  const [qtLoading, setQtLoading] = useState(true);

  // ── Suspended cards (existing feature, preserved) ────────────────────────
  const [suspendedCards, setSuspendedCards] = useState([]);
  const [suspendedLoading, setSuspendedLoading] = useState(true);
  const [suspendedExpanded, setSuspendedExpanded] = useState(false);
  const [unsuspendDialog, setUnsuspendDialog] = useState({ open: false, card: null });

  // ─── Fetch profile ────────────────────────────────────────────────────────
  useEffect(() => {
    if (!user) return;
    supabase
      .from('profiles')
      .select('course_level')
      .eq('id', user.id)
      .single()
      .then(({ data }) => {
        setProfile(data);
        // Initialise selectedCourse to primary course on first load
        if (data?.course_level) setSelectedCourse(data.course_level);
      });
  }, [user]);

  // ─── Fetch lifetime stats once ────────────────────────────────────────────
  useEffect(() => {
    if (!user) return;
    const load = async () => {
      setLifetimeLoading(true);
      try {
        const streak = await calculateStudyStreak(user.id);
        const { data: allReviews } = await supabase
          .from('reviews')
          .select('flashcard_id')
          .eq('user_id', user.id)
          .eq('status', 'active');
        const mastered = new Set(allReviews?.map((r) => r.flashcard_id)).size;
        setLifetimeStats({ streak, mastered });
      } finally {
        setLifetimeLoading(false);
      }
    };
    load();
  }, [user]);

  // ─── Fetch window stats when window changes ───────────────────────────────
  useEffect(() => {
    if (!user) return;
    const load = async () => {
      setWindowLoading(true);
      try {
        let query = supabase
          .from('reviews')
          .select('quality')
          .eq('user_id', user.id)
          .eq('status', 'active');

        if (window !== 'all') {
          const days = window === '7d' ? 7 : 30;
          const since = new Date();
          since.setDate(since.getDate() - days);
          query = query.gte('created_at', since.toISOString());
        }

        const { data: reviews } = await query;
        const total   = reviews?.length ?? 0;
        const correct = reviews?.filter((r) => r.quality >= 3).length ?? 0;
        setWindowStats({
          reviewed: total,
          accuracy: total > 0 ? Math.round((correct / total) * 100) : 0,
        });
      } finally {
        setWindowLoading(false);
      }
    };
    load();
  }, [user, window]);

  // ─── Fetch forecast once ──────────────────────────────────────────────────
  useEffect(() => {
    if (!user) return;
    const load = async () => {
      setForecastLoading(true);
      const { data } = await supabase.rpc('get_due_forecast', { p_user_id: user.id });
      setForecast(data?.[0] ?? null);
      setForecastLoading(false);
    };
    load();
  }, [user]);

  // ─── Fetch question-type performance when tab or selected course changes ───
  useEffect(() => {
    if (!user) return;
    const courseLevel = tab === 'course' ? selectedCourse : null;
    const load = async () => {
      setQtLoading(true);
      const { data } = await supabase.rpc('get_question_type_performance', {
        p_user_id:      user.id,
        p_course_level: courseLevel,
      });
      setQtPerf(data || []);
      setQtLoading(false);
    };
    load();
  }, [user, tab, selectedCourse]);

  // ─── Fetch suspended cards ────────────────────────────────────────────────
  useEffect(() => {
    if (!user) return;
    const load = async () => {
      setSuspendedLoading(true);
      const { data } = await supabase.rpc('get_suspended_cards', { p_user_id: user.id });
      setSuspendedCards(data || []);
      setSuspendedLoading(false);
    };
    load();
  }, [user]);

  // ─── Unsuspend handler ────────────────────────────────────────────────────
  const handleUnsuspend = async (card) => {
    try {
      const { error } = await supabase.rpc('unsuspend_card', {
        p_user_id:      user.id,
        p_flashcard_id: card.flashcard_id,
      });
      if (error) throw error;
      toast({ title: 'Card unsuspended', description: 'This card is now active and due for review today.' });
      setSuspendedCards((prev) => prev.filter((c) => c.flashcard_id !== card.flashcard_id));
      setUnsuspendDialog({ open: false, card: null });
    } catch {
      toast({ title: 'Error', description: 'Failed to unsuspend card.', variant: 'destructive' });
    }
  };

  // ─── Study streak helper ──────────────────────────────────────────────────
  const calculateStudyStreak = async (userId) => {
    try {
      const { data: reviews, error } = await supabase
        .from('reviews')
        .select('created_at')
        .eq('user_id', userId)
        .eq('status', 'active')
        .gt('quality', 0)
        .order('created_at', { ascending: false });

      if (error || !reviews?.length) return 0;

      const dates = reviews.map((r) => formatLocalDate(r.created_at));
      const uniqueDates = [...new Set(dates)];
      const today     = formatLocalDate(new Date());
      const yesterday = formatLocalDate(new Date(Date.now() - 86400000));

      if (uniqueDates[0] !== today && uniqueDates[0] !== yesterday) return 0;

      let streak = 0;
      const current = new Date(uniqueDates[0] === yesterday ? Date.now() - 86400000 : Date.now());
      for (let i = 0; i < 365; i++) {
        if (uniqueDates.includes(formatLocalDate(current))) {
          streak++;
          current.setDate(current.getDate() - 1);
        } else {
          break;
        }
      }
      return streak;
    } catch {
      return 0;
    }
  };

  // ─── Derived values ───────────────────────────────────────────────────────
  const courseLabel       = selectedCourse ?? profile?.course_level ?? 'By Course';
  const activeCourseLevel = tab === 'course' ? selectedCourse : null;
  // All courses available for the dropdown (professors have profile_courses; students fall back to primary)
  const courseOptions = teachingCourses.length > 0
    ? teachingCourses.map((c) => c.disciplines.name)
    : (profile?.course_level ? [profile.course_level] : []);
  const groupedSuspended  = suspendedCards.reduce((acc, card) => {
    const subject = card.subject_name || 'General';
    (acc[subject] = acc[subject] || []).push(card);
    return acc;
  }, {});

  const statsLoading = windowLoading || lifetimeLoading;

  // ─── Render ───────────────────────────────────────────────────────────────
  return (
    <PageContainer width="full">
      {/* Page header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-6">
        <h1 className="text-2xl font-bold text-gray-900">My Progress</h1>

        {/* Time-window selector */}
        <div className="flex items-center gap-1 bg-gray-100 rounded-lg p-1">
          {WINDOW_OPTIONS.map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setWindow(key)}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                window === key
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* Content partition tabs */}
      <div>
        {/* Tab buttons */}
        <div className="inline-flex h-10 items-center justify-center rounded-md bg-gray-100 p-1 mb-6">
          {[
            { value: 'all', label: 'All My Content' },
            { value: 'course', label: `Course: ${courseLabel}` },
          ].map(({ value, label }) => (
            <button
              key={value}
              onClick={() => setTab(value)}
              className={`inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1.5 text-sm font-medium transition-all ${
                tab === value
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* ── All Content tab ────────────────────────────────────────────── */}
        {tab === 'all' && (
          <div className="space-y-6">
            <ProgressBody
              statsLoading={statsLoading}
              windowStats={windowStats}
              lifetimeStats={lifetimeStats}
              window={window}
              forecast={forecast}
              forecastLoading={forecastLoading}
              userId={user?.id}
              courseLevel={null}
              qtPerf={qtPerf}
              qtLoading={qtLoading}
              suspendedCards={suspendedCards}
              suspendedLoading={suspendedLoading}
              suspendedExpanded={suspendedExpanded}
              setSuspendedExpanded={setSuspendedExpanded}
              groupedSuspended={groupedSuspended}
              setUnsuspendDialog={setUnsuspendDialog}
            />
          </div>
        )}

        {/* ── By Course tab ───────────────────────────────────────────────── */}
        {tab === 'course' && (
          <div className="space-y-6">
            {courseOptions.length === 0 ? (
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
                <BookOpen className="h-8 w-8 text-blue-400 mx-auto mb-3" />
                <p className="text-sm font-medium text-blue-800 mb-1">No course set</p>
                <p className="text-sm text-blue-700 mb-4">
                  Select your course in Settings to see course-specific progress.
                </p>
                <Link to="/dashboard/settings">
                  <Button size="sm" variant="outline" className="border-blue-300 text-blue-700 hover:bg-blue-100">
                    Go to Settings
                  </Button>
                </Link>
              </div>
            ) : (
              <>
                {/* Course selector — shown only when user has 2+ courses */}
                {courseOptions.length > 1 && (
                  <div className="flex items-center gap-3">
                    <span className="text-sm text-gray-500 shrink-0">Viewing course:</span>
                    <div className="flex flex-wrap gap-2">
                      {courseOptions.map((name) => (
                        <button
                          key={name}
                          onClick={() => setSelectedCourse(name)}
                          className={`px-3 py-1.5 rounded-md text-sm font-medium border transition-colors ${
                            selectedCourse === name
                              ? 'bg-indigo-600 text-white border-indigo-600'
                              : 'bg-white text-gray-600 border-gray-300 hover:border-indigo-400 hover:text-indigo-600'
                          }`}
                        >
                          {name}
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                <ProgressBody
                  statsLoading={statsLoading}
                  windowStats={windowStats}
                  lifetimeStats={lifetimeStats}
                  window={window}
                  forecast={forecast}
                  forecastLoading={forecastLoading}
                  userId={user?.id}
                  courseLevel={activeCourseLevel}
                  qtPerf={qtPerf}
                  qtLoading={qtLoading}
                  suspendedCards={suspendedCards}
                  suspendedLoading={suspendedLoading}
                  suspendedExpanded={suspendedExpanded}
                  setSuspendedExpanded={setSuspendedExpanded}
                  groupedSuspended={groupedSuspended}
                  setUnsuspendDialog={setUnsuspendDialog}
                />
              </>
            )}
          </div>
        )}
      </div>

      {/* Unsuspend confirmation dialog */}
      <Dialog
        open={unsuspendDialog.open}
        onOpenChange={(open) => setUnsuspendDialog((prev) => ({ ...prev, open }))}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Unsuspend this card?</DialogTitle>
            <DialogDescription>
              This card will be reactivated and scheduled for review today.
              {unsuspendDialog.card && (
                <span className="block mt-2 font-medium text-gray-700">
                  &ldquo;{unsuspendDialog.card.front_text?.substring(0, 100)}
                  {unsuspendDialog.card.front_text?.length > 100 ? '...' : ''}&rdquo;
                </span>
              )}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setUnsuspendDialog({ open: false, card: null })}>
              Cancel
            </Button>
            <Button
              onClick={() => handleUnsuspend(unsuspendDialog.card)}
              className="bg-green-600 hover:bg-green-700"
            >
              <PlayCircle className="h-4 w-4 mr-2" />
              Unsuspend
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageContainer>
  );
}

// ─── ProgressBody ─────────────────────────────────────────────────────────────
// Renders the full content block for either tab (avoids duplication).
function ProgressBody({
  statsLoading, windowStats, lifetimeStats, window,
  forecast, forecastLoading,
  userId, courseLevel,
  qtPerf, qtLoading,
  suspendedCards, suspendedLoading, suspendedExpanded, setSuspendedExpanded,
  groupedSuspended, setUnsuspendDialog,
}) {
  const windowLabel = window === '7d' ? 'Last 7 days' : window === '30d' ? 'Last 30 days' : 'All time';

  return (
    <>
      {/* ── 4 Stat cards ──────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          icon={<Calendar className="h-7 w-7 text-orange-500" />}
          value={statsLoading ? '—' : lifetimeStats.streak}
          label="Study Streak"
          sub="Consecutive days"
          loading={statsLoading}
        />
        <StatCard
          icon={<TrendingUp className="h-7 w-7 text-blue-500" />}
          value={statsLoading ? '—' : windowStats.reviewed}
          label="Items Reviewed"
          sub={windowLabel}
          loading={statsLoading}
        />
        <StatCard
          icon={<Target className="h-7 w-7 text-green-500" />}
          value={statsLoading ? '—' : `${windowStats.accuracy}%`}
          label="Accuracy"
          sub={windowLabel}
          loading={statsLoading}
        />
        <StatCard
          icon={<Award className="h-7 w-7 text-purple-500" />}
          value={statsLoading ? '—' : lifetimeStats.mastered}
          label="Items Mastered"
          sub="All time"
          loading={statsLoading}
        />
      </div>

      {/* ── Due Items Forecast ─────────────────────────────────────────────── */}
      <div>
        <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
          Due Items Forecast
        </h2>
        <div className="grid grid-cols-3 gap-4">
          <ForecastCard
            label="Due Today"
            value={forecastLoading ? null : (forecast?.due_today ?? 0)}
            accent="text-red-600 bg-red-50 border-red-200"
          />
          <ForecastCard
            label="Next 7 Days"
            value={forecastLoading ? null : (forecast?.due_next_7 ?? 0)}
            accent="text-amber-600 bg-amber-50 border-amber-200"
          />
          <ForecastCard
            label="Next 30 Days"
            value={forecastLoading ? null : (forecast?.due_next_30 ?? 0)}
            accent="text-blue-600 bg-blue-50 border-blue-200"
          />
        </div>
      </div>

      {/* ── Study Calendar Heatmap ─────────────────────────────────────────── */}
      <div>
        <StudyHeatmap userId={userId} />
      </div>

      {/* ── Subject Mastery Table ──────────────────────────────────────────── */}
      <div>
        <SubjectMasteryTable userId={userId} courseLevel={courseLevel} />
      </div>

      {/* ── Question Type Performance ──────────────────────────────────────── */}
      <div>
        <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
          Performance by Question Type
        </h2>
        <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
          {qtLoading ? (
            <div className="p-4 space-y-3 animate-pulse">
              {[1, 2, 3].map((i) => (
                <div key={i} className="flex items-center gap-3">
                  <div className="h-4 w-28 bg-gray-100 rounded" />
                  <div className="flex-1 h-2 bg-gray-100 rounded" />
                  <div className="h-4 w-10 bg-gray-100 rounded" />
                </div>
              ))}
            </div>
          ) : qtPerf.length === 0 ? (
            <div className="p-6 text-center text-sm text-gray-400">
              No review data yet.
            </div>
          ) : (
            <div className="divide-y divide-gray-50">
              {qtPerf.map((row) => (
                <QuestionTypeRow key={row.question_type} row={row} />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Suspended Cards ────────────────────────────────────────────────── */}
      {!suspendedLoading && suspendedCards.length > 0 && (
        <div>
          <button
            onClick={() => setSuspendedExpanded(!suspendedExpanded)}
            className="w-full flex items-center justify-between bg-amber-50 border border-amber-200 rounded-lg p-4 hover:bg-amber-100 transition-colors"
          >
            <div className="flex items-center gap-3">
              <PauseCircle className="h-5 w-5 text-amber-600" />
              <div className="text-left">
                <h3 className="font-semibold text-amber-900">
                  Suspended Items ({suspendedCards.length})
                </h3>
                <p className="text-xs text-amber-700">These items are hidden from your review queue</p>
              </div>
            </div>
            {suspendedExpanded
              ? <ChevronDown className="h-5 w-5 text-amber-600" />
              : <ChevronRight className="h-5 w-5 text-amber-600" />
            }
          </button>

          {suspendedExpanded && (
            <div className="mt-2 space-y-4">
              {Object.entries(groupedSuspended).map(([subject, cards]) => (
                <div key={subject} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                  <div className="bg-gray-50 px-4 py-2 border-b border-gray-200">
                    <h4 className="text-sm font-semibold text-gray-700">{subject} ({cards.length})</h4>
                  </div>
                  <div className="divide-y divide-gray-100">
                    {cards.map((card) => (
                      <div key={card.flashcard_id} className="px-4 py-3 flex items-center justify-between gap-4">
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">{card.front_text}</p>
                          {card.topic_name && (
                            <p className="text-xs text-gray-500 mt-0.5">{card.topic_name}</p>
                          )}
                        </div>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => setUnsuspendDialog({ open: true, card })}
                          className="gap-1 shrink-0 text-green-700 border-green-300 hover:bg-green-50 hover:border-green-400"
                        >
                          <PlayCircle className="h-3.5 w-3.5" />
                          Unsuspend
                        </Button>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Empty state */}
      {!statsLoading && windowStats.reviewed === 0 && suspendedCards.length === 0 && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
          <p className="text-blue-800 mb-1 font-medium">No reviews yet!</p>
          <p className="text-sm text-blue-700">Start reviewing items to see your progress statistics.</p>
        </div>
      )}
    </>
  );
}

// ─── Small reusable sub-components ───────────────────────────────────────────
function StatCard({ icon, value, label, sub, loading }) {
  return (
    <div className="bg-white p-5 rounded-lg shadow-sm border border-gray-200">
      <div className="flex items-center justify-between mb-3">
        {icon}
        <span className="text-2xl font-bold text-gray-900">
          {loading ? <span className="text-gray-300 animate-pulse">—</span> : value}
        </span>
      </div>
      <h3 className="text-sm font-medium text-gray-600">{label}</h3>
      <p className="text-xs text-gray-400 mt-0.5">{sub}</p>
    </div>
  );
}

function ForecastCard({ label, value, accent }) {
  return (
    <div className={`rounded-lg border p-4 text-center ${accent}`}>
      <div className="flex items-center justify-center gap-1 mb-1">
        <Clock className="h-4 w-4 opacity-70" />
      </div>
      <p className="text-2xl font-bold leading-none mb-1">
        {value === null ? <span className="animate-pulse">—</span> : value}
      </p>
      <p className="text-xs font-medium opacity-80">{label}</p>
    </div>
  );
}

function QuestionTypeRow({ row }) {
  const pct = Number(row.accuracy_pct) || 0;
  return (
    <div className="px-4 py-3 flex items-center gap-3">
      <div className="w-32 shrink-0">
        <p className="text-sm font-medium text-gray-800 truncate">{qtLabel(row.question_type)}</p>
        <p className="text-xs text-gray-400">{row.reviewed_count} / {row.total_cards_available} reviewed</p>
      </div>
      <div className="flex-1 bg-gray-100 rounded-full h-2 overflow-hidden">
        <div
          className="h-2 rounded-full bg-indigo-500 transition-all"
          style={{ width: `${Math.min(pct, 100)}%` }}
        />
      </div>
      <span className="text-sm font-semibold text-gray-700 w-12 text-right shrink-0">{pct}%</span>
    </div>
  );
}
