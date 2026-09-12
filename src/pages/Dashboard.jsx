import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useCourseContext } from '@/contexts/CourseContext';
import { useNavData } from '@/contexts/NavDataContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { SearchableSelect } from '@/components/ui/SearchableSelect';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import OnboardingModal from '@/components/dashboard/OnboardingModal';
import LeaderboardWidget from '@/components/dashboard/LeaderboardWidget';
import GoalProgressWidget from '@/components/dashboard/GoalProgressWidget';
import ActivityFeed from '@/components/dashboard/ActivityFeed';
import PushPermissionBanner from '@/components/notifications/PushPermissionBanner';
// RevisOp reskin — Sprint 6.3. Section eyebrows, mono numerals, forward ledger.
import { Num, ForwardLedgerMacro } from '@/components/revisop';
import { useBadges } from '@/hooks/useBadges';
import { useToast } from '@/hooks/use-toast';
import BadgeToast from '@/components/badges/BadgeToast';
import PageContainer from '@/components/layout/PageContainer';
import {
  CreditCard,
  CheckCircle,
  Flame,
  Target,
  Award,
  Upload,
  FileText,
  Loader2,
  Shield,
  BarChart3,
  Users,
  Flag,
  AlertTriangle,
  Clock,
} from 'lucide-react';

// Must match ProfileSettings.jsx — static curated list, "Other" always last.
const COURSE_LEVELS = [
  'CA Foundation',
  'CA Intermediate',
  'CA Final',
];

const INSTITUTION_OPTIONS = [
  'Aldine CA',
  'Ambitions Commerce Institute Pvt Ltd',
  'EduSum',
  'Ektvam Academy',
  'JK Shah Classes',
  'More Classes Commerce',
  'PhysicsWallah',
  'Self Study',
  'Swapnil Patni Classes',
  'The Institute of Chartered Accountants of India (ICAI)',
  'Unacademy',
  'Other',
];

function toTitleCase(str) {
  return str
    .toLowerCase()
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

// ============================================================
// HELPER: Format date as YYYY-MM-DD in user's LOCAL timezone
// Using 'en-CA' locale gives us ISO format (YYYY-MM-DD) which
// allows correct string comparison for dates.
// ============================================================
const formatLocalDate = (date) => {
  return new Date(date).toLocaleDateString('en-CA');
};

// question_type slug → readable label for the educator accuracy widget
const formatQuestionType = (qt) => {
  if (!qt) return 'Other';
  const map = {
    flashcard: 'Flashcard',
    mcq: 'MCQ',
    true_false: 'True / False',
    correct_incorrect: 'Correct / Incorrect',
    theory: 'Theory',
    test_your_understanding: 'Test your understanding',
    case_study_mcq: 'Case study MCQ',
    integrated_case: 'Integrated case',
    match_the_following: 'Match the following',
    fill_in_the_blanks: 'Fill in the blanks',
  };
  return map[qt] || qt.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
};

// Format seconds → "1h 23m" / "45m" / "< 1m"
const formatStudyTime = (seconds) => {
  if (!seconds || seconds < 60) return '< 1m';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
};

export default function Dashboard() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);

  // activeCourse from CourseContext — lets professors switch class stats by course
  const { activeCourse } = useCourseContext();
  // Sprint 7.2-A: professor's own due count, for contrast against the cohort
  // forward-load chart below — reads the NavDataContext singleton (7.2-F), no
  // separate get_due_forecast call.
  const { dueToday: myDueToday } = useNavData();
  // Track initial mount so the activeCourse effect doesn't double-fetch on first load
  const isInitialMount = useRef(true);
  
  // User info
  const [userName, setUserName] = useState('');
  
  // Personal stats
  const [reviewsDue, setReviewsDue] = useState(0);
  
  // Content counts
  const [notesCount, setNotesCount] = useState(0);
  const [flashcardsCount, setFlashcardsCount] = useState(0);
  
  // Forward Ledger — student's 8-lane scheduled-load series (Sprint 6.3).
  // Sourced from get_due_forecast_buckets; folded to number[8] for ForwardLedgerMacro.
  const [forecastSeries, setForecastSeries] = useState(null);

  // Educator dashboard — accuracy by question type + cohort forward load (Sprint 6.3)
  const [educatorAccuracy, setEducatorAccuracy] = useState(null);
  const [cohortForecastSeries, setCohortForecastSeries] = useState(null);
  // Curated Professor Analytics summary embedded on the dashboard (Sprint 7.2-C) —
  // the two most actionable sections from ProfessorAnalytics.jsx (overview row +
  // weak cards); the other 3 sections stay behind "View full analytics →".
  const [professorOverview, setProfessorOverview] = useState(null);
  const [professorWeakCards, setProfessorWeakCards] = useState([]);

  // User state flags
  const [isNewUser, setIsNewUser] = useState(false);
  const [userRole, setUserRole] = useState('');
  const [userCourseLevel, setUserCourseLevel] = useState('');
  const [needsAttentionItems, setNeedsAttentionItems] = useState([]);
  const [needsReviewCount, setNeedsReviewCount] = useState(0);

  // Study time stats (student only) — Sprint 7.3-C: split by session source
  // (in-app vs offline/manual) via get_study_time_stats' new additive columns.
  const [studyTimeStats, setStudyTimeStats] = useState({
    today_seconds: 0, week_seconds: 0, today_sessions: 0, week_sessions: 0,
    today_seconds_in_app: 0, today_seconds_offline: 0,
    week_seconds_in_app: 0, week_seconds_offline: 0,
  });
  const [studyTimeLoading, setStudyTimeLoading] = useState(true);
  // Stored so the onSessionLogged callback can re-fetch without re-reading auth
  const [authUserId, setAuthUserId] = useState(null);

  // Daily goal values (student only) — fetched from profiles
  const [reviewGoal, setReviewGoal]           = useState(null);
  const [studyGoalMinutes, setStudyGoalMinutes] = useState(null);
  // Today's review count — computed in fetchPersonalStats, used by GoalProgressWidget
  const [todayReviews, setTodayReviews]       = useState(0);
  // Sprint 7.3-B: one-time dismissal of the "no goal set" prompt line
  const [goalPromptDismissed, setGoalPromptDismissed] = useState(false);

  // Onboarding modal state
  const [showOnboarding, setShowOnboarding] = useState(false);

  // Profile completion modal state
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [modalCourseLevel, setModalCourseLevel] = useState('');
  const [modalInstitutionSelect, setModalInstitutionSelect] = useState('');
  const [modalCustomInstitution, setModalCustomInstitution] = useState('');
  const [savingProfile, setSavingProfile] = useState(false);

  // Badge notifications
  const { unnotifiedBadges, clearUnnotifiedBadges } = useBadges();
  const { toast } = useToast();

  // Show toast for newly earned badges
  useEffect(() => {
    if (unnotifiedBadges && unnotifiedBadges.length > 0) {
      unnotifiedBadges.forEach((badge) => {
        toast({
          description: <BadgeToast badge={badge} />,
          duration: 5000,
        });
      });
      clearUnnotifiedBadges();
    }
  }, [unnotifiedBadges, clearUnnotifiedBadges, toast]);

  useEffect(() => {
    fetchDashboardData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Re-fetch the educator widgets when a professor switches active course context
  // Skip the very first render (fetchDashboardData already handles initial load)
  useEffect(() => {
    if (isInitialMount.current) {
      isInitialMount.current = false;
      return;
    }
    if (activeCourse && userRole === 'professor' && authUserId) {
      fetchEducatorWidgets(authUserId, activeCourse);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeCourse]);

  const fetchDashboardData = async () => {
    try {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (!authUser) {
        navigate('/login');
        return;
      }
      setAuthUserId(authUser.id);

      // Fetch profile for name, course level, institution, onboarding flag, role, and goal columns
      const { data: profile } = await supabase
        .from('profiles')
        .select('full_name, course_level, institution, has_seen_onboarding, role, daily_review_goal, daily_study_goal_minutes, has_dismissed_goal_prompt')
        .eq('id', authUser.id)
        .single();

      if (profile) {
        setUserName(profile.full_name || '');
        setUserRole(profile.role || 'student');
        setUserCourseLevel(profile.course_level || '');
        setReviewGoal(profile.daily_review_goal ?? null);
        setStudyGoalMinutes(profile.daily_study_goal_minutes ?? null);
        setGoalPromptDismissed(!!profile.has_dismissed_goal_prompt);

        const isAdminRole = ['admin', 'super_admin'].includes(profile.role);

        // Show profile completion modal if course_level or institution is missing
        // Admins/super_admins intentionally have no course_level — skip modal for them
        if (!isAdminRole && (!profile.course_level || !profile.institution)) {
          setModalCourseLevel(profile.course_level || '');
          // Pre-fill institution dropdown if they have one
          if (profile.institution) {
            const presetMatch = INSTITUTION_OPTIONS.find(
              opt => opt !== 'Other' && opt === profile.institution
            );
            setModalInstitutionSelect(presetMatch ? presetMatch : 'Other');
            if (!presetMatch) setModalCustomInstitution(profile.institution);
          }
          setShowProfileModal(true);
        } else if (!profile.has_seen_onboarding) {
          // Profile complete but hasn't seen onboarding yet
          setShowOnboarding(true);
        }
      }

      // Link access request ref token if stranger signed up via invite link
      // migrate-on-mount: recall_access_ref → revisop_access_ref
      let accessRef = localStorage.getItem('revisop_access_ref');
      if (!accessRef) {
        accessRef = localStorage.getItem('recall_access_ref');
        if (accessRef) {
          localStorage.setItem('revisop_access_ref', accessRef);
          localStorage.removeItem('recall_access_ref');
        }
      }
      if (accessRef) {
        localStorage.removeItem('revisop_access_ref');
        supabase.rpc('link_access_request', { p_ref_token: accessRef }).catch(() => {});
      }

      // Fetch all data in parallel
      // For professors: activeCourse may override profile.course_level for cohort widgets
      const courseForStats = activeCourse || profile?.course_level;
      const isStudent = !['professor', 'admin', 'super_admin'].includes(profile?.role);
      await Promise.all([
        fetchPersonalStats(authUser.id),
        fetchContentCounts(authUser.id),
        isStudent ? fetchForecastSeries(authUser.id) : Promise.resolve(),
        profile?.role === 'professor'
          ? fetchEducatorWidgets(authUser.id, courseForStats)
          : Promise.resolve(),
      ]);

      // Fetch flagged content for professor/admin dashboard cards
      if (profile?.role === 'professor') {
        const { data: flagData } = await supabase.rpc('get_my_content_flags');
        setNeedsAttentionItems(flagData || []);
      } else if (['admin', 'super_admin'].includes(profile?.role)) {
        const { data: flagData } = await supabase.rpc('get_admin_flags', { p_status: 'pending' });
        setNeedsReviewCount((flagData || []).length);
      }

      // Determine if new user
      const { count: reviewsCount } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', authUser.id);

      const { count: notesTotal } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', authUser.id);

      const { count: flashcardsTotal } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', authUser.id);

      setIsNewUser(
        (!reviewsCount || reviewsCount === 0) &&
        (!notesTotal || notesTotal === 0) &&
        (!flashcardsTotal || flashcardsTotal === 0)
      );

      // Fetch study time stats for student dashboard
      if (!['professor', 'admin', 'super_admin'].includes(profile?.role)) {
        fetchStudyTimeStats(authUser.id);
      }

    } catch (error) {
      console.error('🔴 Dashboard Error:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchPersonalStats = async (userId) => {
    // Reviews due — single source of truth: get_study_queue RPC (course-aware,
    // concept-cards excluded, skip/suspend/skip_until all handled server-side).
    const { data: dueQueue } = await supabase.rpc('get_study_queue', { p_user_id: userId });
    setReviewsDue((dueQueue || []).length);

    // Fetch user's reviews for today's count (exclude suspended). Weekly/streak/
    // accuracy/mastered stats live on the Progress tab (Sprint 7.3-A) — this
    // dashboard only needs today's count, for GoalProgressWidget.
    const { data: reviews } = await supabase
      .from('reviews')
      .select('created_at, last_reviewed_at, quality, flashcard_id, status')
      .eq('user_id', userId);

    const reviewList = reviews || [];

    // Only use active reviews for stats
    const activeReviews = reviewList.filter(r => r.status === 'active' || !r.status);

    if (activeReviews.length > 0) {
      // Today's reviews — used by GoalProgressWidget. "Items reviewed" recency =
      // the most recent rating (last_reviewed_at), NOT created_at (which is the
      // card's FIRST review — submit_review UPDATEs the one row per user/card, so
      // created_at never moves). Fallback to created_at for legacy rows.
      const todayStr = formatLocalDate(new Date());
      const todayRevCount = activeReviews.filter(
        r => r.quality > 0 && formatLocalDate(r.last_reviewed_at || r.created_at) === todayStr
      ).length;
      setTodayReviews(todayRevCount);
    }
  };

  const fetchContentCounts = async (userId) => {
    const { count: notes } = await supabase
      .from('notes')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);
    setNotesCount(notes || 0);

    const { count: flashcards } = await supabase
      .from('flashcards')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);
    setFlashcardsCount(flashcards || 0);
  };

  // Fold the 8-row get_due_forecast_buckets result into the number[8] series the
  // ForwardLedgerMacro renders. Ordered 0..7 by bucket_index server-side.
  const fetchForecastSeries = async (userId) => {
    try {
      const { data, error } = await supabase.rpc('get_due_forecast_buckets', { p_user_id: userId });
      if (error) { console.error('🔴 Forecast buckets error:', error); return; }
      const series = Array.from({ length: 8 }, (_, i) => {
        const row = (data || []).find(r => Number(r.bucket_index) === i);
        return row ? Number(row.scheduled_count) || 0 : 0;
      });
      setForecastSeries(series);
    } catch (err) {
      console.error('🔴 Forecast buckets RPC error:', err);
    }
  };

  // Educator dashboard widgets — accuracy by question type + cohort forward load +
  // (Sprint 7.2-C) the curated Professor Analytics summary (overview + weak cards).
  // All 4 RPCs fire once per mount / once per course switch, in parallel — same
  // pattern ProfessorAnalytics.jsx already uses, network-traced to confirm no
  // regression on the Sprint 7.0 over-fetch fix.
  const fetchEducatorWidgets = async (professorId, courseLevel) => {
    if (!courseLevel) return;
    try {
      const [acc, cohort, overview, weak] = await Promise.all([
        supabase.rpc('get_educator_accuracy_by_qtype', {
          p_professor_id: professorId, p_course_level: courseLevel,
        }),
        supabase.rpc('get_educator_cohort_forecast_buckets', {
          p_professor_id: professorId, p_course_level: courseLevel,
        }),
        supabase.rpc('get_professor_overview', {
          p_professor_id: professorId, p_course_level: courseLevel,
        }),
        supabase.rpc('get_professor_weak_cards', {
          p_professor_id: professorId, p_course_level: courseLevel,
        }),
      ]);
      if (!acc.error) setEducatorAccuracy(acc.data || []);
      if (!cohort.error) {
        const series = Array.from({ length: 8 }, (_, i) => {
          const row = (cohort.data || []).find(r => Number(r.bucket_index) === i);
          return row ? Number(row.scheduled_count) || 0 : 0;
        });
        setCohortForecastSeries(series);
      }
      if (!overview.error) setProfessorOverview(overview.data?.[0] ?? null);
      if (!weak.error) setProfessorWeakCards((weak.data || []).slice(0, 5));
    } catch (err) {
      console.error('🔴 Educator widgets RPC error:', err);
    }
  };

  const fetchStudyTimeStats = async (userId) => {
    try {
      const localDate = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD in user's timezone
      const { data, error } = await supabase.rpc('get_study_time_stats', {
        p_user_id:    userId,
        p_local_date: localDate,
      });
      if (!error && data && data.length > 0) {
        setStudyTimeStats({
          today_seconds:  Number(data[0].today_seconds)  || 0,
          week_seconds:   Number(data[0].week_seconds)   || 0,
          today_sessions: Number(data[0].today_sessions) || 0,
          week_sessions:  Number(data[0].week_sessions)  || 0,
          today_seconds_in_app:  Number(data[0].today_seconds_in_app)  || 0,
          today_seconds_offline: Number(data[0].today_seconds_offline) || 0,
          week_seconds_in_app:   Number(data[0].week_seconds_in_app)   || 0,
          week_seconds_offline:  Number(data[0].week_seconds_offline)  || 0,
        });
      }
    } catch (err) {
      console.error('🔴 Study time stats error:', err);
    } finally {
      setStudyTimeLoading(false);
    }
  };

  // Profile completion modal save handler
  const handleProfileModalSave = async () => {
    if (!modalCourseLevel) {
      toast({ title: 'Course required', description: 'Please select your primary course.', variant: 'destructive' });
      return;
    }
    if (!modalInstitutionSelect) {
      toast({ title: 'Institution required', description: 'Please select your institution.', variant: 'destructive' });
      return;
    }
    if (modalInstitutionSelect === 'Other' && !modalCustomInstitution.trim()) {
      toast({ title: 'Institution required', description: 'Please enter your institution name.', variant: 'destructive' });
      return;
    }

    let finalInstitution = '';
    if (modalInstitutionSelect === 'Other') {
      const trimmed = modalCustomInstitution.trim();
      finalInstitution = trimmed ? toTitleCase(trimmed) : '';
    } else {
      finalInstitution = modalInstitutionSelect;
    }

    setSavingProfile(true);
    try {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      const { error } = await supabase
        .from('profiles')
        .update({
          course_level: modalCourseLevel,
          institution: finalInstitution,
        })
        .eq('id', authUser.id);

      if (error) throw error;

      setShowProfileModal(false);
      toast({ title: 'Profile updated!', description: 'Your course and institution have been saved.' });

      // Reload dashboard data to reflect updated course_level (for class stats)
      fetchDashboardData();
    } catch (error) {
      console.error('Error saving profile:', error);
      toast({ title: 'Error', description: error.message, variant: 'destructive' });
    } finally {
      setSavingProfile(false);
    }
  };

  const handleDismissOnboarding = async () => {
    setShowOnboarding(false);
    try {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        await supabase
          .from('profiles')
          .update({ has_seen_onboarding: true })
          .eq('id', authUser.id);
      }
    } catch (err) {
      console.error('Error dismissing onboarding:', err);
    }
  };

  // Sprint 7.3-B: one-time "no goal set" prompt dismissal — persists so the
  // line never reappears for this student, plus a one-time confirmation toast.
  const handleDismissGoalPrompt = async () => {
    setGoalPromptDismissed(true);
    toast({ title: 'Got it', description: 'You can set a daily goal anytime in Settings.' });
    try {
      if (authUserId) {
        await supabase
          .from('profiles')
          .update({ has_dismissed_goal_prompt: true })
          .eq('id', authUserId);
      }
    } catch (err) {
      console.error('Error dismissing goal prompt:', err);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <PageContainer width="full" className="font-plex">

        {/* ===== ONBOARDING MODAL ===== */}
        <OnboardingModal open={showOnboarding} onDismiss={handleDismissOnboarding} />

        {/* ===== PROFILE COMPLETION MODAL (non-dismissible) ===== */}
        <Dialog open={showProfileModal} onOpenChange={() => {}}>
          <DialogContent
            className="sm:max-w-md"
            onPointerDownOutside={(e) => e.preventDefault()}
            onEscapeKeyDown={(e) => e.preventDefault()}
            onInteractOutside={(e) => e.preventDefault()}
            hideCloseButton
          >
            <DialogHeader>
              <DialogTitle>Complete Your Profile</DialogTitle>
              <DialogDescription>
                Please set your course and institution to get the most out of RevisOp.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 pt-2">
              {/* Primary Course */}
              <div className="space-y-2">
                <Label>Primary Course <span className="text-red-500">*</span></Label>
                <Select value={modalCourseLevel} onValueChange={setModalCourseLevel}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select your active course" />
                  </SelectTrigger>
                  <SelectContent>
                    {COURSE_LEVELS.map((level) => (
                      <SelectItem key={level} value={level}>
                        {level}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Institution */}
              <div className="space-y-2">
                <Label>Institution <span className="text-red-500">*</span></Label>
                <SearchableSelect
                  value={modalInstitutionSelect}
                  onValueChange={(val) => {
                    setModalInstitutionSelect(val);
                    if (val !== 'Other') setModalCustomInstitution('');
                  }}
                  options={INSTITUTION_OPTIONS}
                  placeholder="Select your institution"
                />
                {modalInstitutionSelect === 'Other' && (
                  <Input
                    value={modalCustomInstitution}
                    onChange={(e) => setModalCustomInstitution(e.target.value)}
                    placeholder="Enter your institution name"
                    className="mt-2"
                  />
                )}
              </div>

              {/* Save Button */}
              <Button onClick={handleProfileModalSave} disabled={savingProfile} className="w-full">
                {savingProfile ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : null}
                {savingProfile ? 'Saving...' : 'Save & Continue'}
              </Button>
            </div>
          </DialogContent>
        </Dialog>

        {/* ===== PROFESSOR DASHBOARD ===== */}
        {userRole === 'professor' ? (
          <>
            {/* Header */}
            <div className="mb-6 sm:mb-8">
              <h1 className="text-2xl sm:text-3xl font-bold">
                Welcome back{userName ? `, ${userName.split(' ')[0]}` : ''}!
              </h1>
              <p className="text-rv-ink-400 mt-2">
                Manage your content and track your students' engagement.
              </p>
            </div>

            <div className="space-y-4 sm:space-y-6">
              {/* Needs Attention — flagged content errors on professor's own content.
                  Sprint 7.2-C: moved to the top of the page — unconditional render
                  is unchanged, only its position moved (settled-design rule). */}
              <Card className={`cursor-pointer transition hover:border-rv-navy-400 ${needsAttentionItems.length > 0 ? 'border-amber-300 bg-amber-50' : 'border-rv-border'}`}>
                <CardHeader className="pb-2">
                  <CardTitle className={`flex items-center gap-2 text-base ${needsAttentionItems.length > 0 ? 'text-amber-800' : 'text-rv-ink-900'}`}>
                    <AlertTriangle className={`h-4 w-4 ${needsAttentionItems.length > 0 ? 'text-rv-navy' : 'text-rv-ink-400'}`} />
                    Needs Attention{needsAttentionItems.length > 0 ? ` (${needsAttentionItems.length})` : ''}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {needsAttentionItems.length === 0 ? (
                    <p className="text-sm text-rv-ink-400">No flags on your content. All clear!</p>
                  ) : (
                    <div className="space-y-3">
                      {needsAttentionItems.slice(0, 5).map((item) => (
                        <div
                          key={item.flag_id}
                          className="flex items-start justify-between gap-3 p-3 bg-rv-bg-1 rounded-rec border border-rv-amber-edge"
                        >
                          <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-rv-ink-900 truncate">
                              {item.content_title || 'Untitled'}
                            </p>
                            <p className="text-xs text-rv-ink-400 mt-0.5">
                              {item.flag_count} {item.flag_count === 1 ? 'student' : 'students'} flagged
                              {item.details ? ` · "${item.details.slice(0, 60)}${item.details.length > 60 ? '…' : ''}"` : ''}
                            </p>
                            {item.priority === 'high' && (
                              <span className="inline-flex items-center text-xs text-red-600 font-medium mt-1">
                                🔴 High priority
                              </span>
                            )}
                          </div>
                          <div className="flex gap-2 shrink-0">
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => navigate(
                                item.content_type === 'note'
                                  ? `/dashboard/notes/edit/${item.content_id}`
                                  : `/dashboard/flashcards/edit/${item.content_id}`
                              )}
                            >
                              Edit
                            </Button>
                            <Button
                              size="sm"
                              variant="ghost"
                              className="text-green-700 hover:text-green-800 hover:bg-green-50"
                              onClick={async () => {
                                await supabase.rpc('resolve_content_flag', {
                                  p_flag_id: item.flag_id,
                                  p_action: 'resolve',
                                  p_resolution_note: 'Marked resolved by creator',
                                });
                                const { data: flagData } = await supabase.rpc('get_my_content_flags');
                                setNeedsAttentionItems(flagData || []);
                              }}
                            >
                              Mark resolved
                            </Button>
                          </div>
                        </div>
                      ))}
                      {needsAttentionItems.length > 5 && (
                        <p className="text-xs text-center text-amber-700">
                          +{needsAttentionItems.length - 5} more items need attention
                        </p>
                      )}
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* Analytics snapshot — curated Professor Analytics summary (Sprint 7.2-C).
                  Overview row + Challenging Cards are the two most actionable
                  ProfessorAnalytics.jsx sections; Subjects/Top Cards/Weekly Reach
                  stay behind "View full analytics →". */}
              {professorOverview && (
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400">
                      Analytics Snapshot
                    </h2>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7 text-xs text-rv-navy hover:text-rv-navy-400"
                      onClick={() => navigate('/dashboard/professor-analytics')}
                    >
                      View full analytics →
                    </Button>
                  </div>

                  <div className="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4 mb-4">
                    <Card>
                      <CardContent className="pt-4 pb-4">
                        <p className="text-xs text-rv-ink-400 mb-1">Cards Published</p>
                        <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">
                          {professorOverview.total_cards_published ?? 0}
                        </div>
                      </CardContent>
                    </Card>
                    <Card>
                      <CardContent className="pt-4 pb-4">
                        <p className="text-xs text-rv-ink-400 mb-1">Students Reached</p>
                        <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">
                          {professorOverview.total_students_reached ?? 0}
                        </div>
                      </CardContent>
                    </Card>
                    <Card>
                      <CardContent className="pt-4 pb-4">
                        <p className="text-xs text-rv-ink-400 mb-1">Total Reviews</p>
                        <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">
                          {professorOverview.total_reviews ?? 0}
                        </div>
                      </CardContent>
                    </Card>
                    <Card>
                      <CardContent className="pt-4 pb-4">
                        <p className="text-xs text-rv-ink-400 mb-1">Avg Quality</p>
                        <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">
                          {professorOverview.avg_quality == null ? '—' : Number(professorOverview.avg_quality).toFixed(1)}
                        </div>
                      </CardContent>
                    </Card>
                  </div>

                  {professorWeakCards.length > 0 && (
                    <Card>
                      <CardHeader className="pb-2">
                        <CardTitle className="text-sm font-medium text-rv-ink-900">Challenging Cards</CardTitle>
                        <p className="text-xs text-rv-ink-400">Students are finding these harder to recall (min 3 reviews)</p>
                      </CardHeader>
                      <CardContent className="space-y-0">
                        {professorWeakCards.map((card) => (
                          <div
                            key={card.card_id}
                            className="flex items-center justify-between gap-3 py-2 border-b border-rv-border last:border-0"
                          >
                            <div className="min-w-0">
                              <p className="text-sm text-rv-ink-900 truncate">{card.front_text}</p>
                              <p className="text-xs text-rv-ink-400">{card.subject_name} · {card.review_count} reviews</p>
                            </div>
                            <span className="shrink-0 text-xs font-medium text-rv-ink-900">
                              {Number(card.avg_quality ?? 0).toFixed(1)}/5
                            </span>
                          </div>
                        ))}
                      </CardContent>
                    </Card>
                  )}
                </div>
              )}

              {/* Your Content — Sprint 7.2-C: pushed down (Create actions already
                  live in the desktop Create dropdown + mobile ＋ sheet since 7.1). */}
              <div>
                <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">
                  Your Content
                </h2>
                <div className="grid gap-3 sm:gap-4 grid-cols-2">
                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/dashboard/my-notes')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-navy-50 rounded-rec">
                          <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">My Notes</p>
                          <p className="text-xs text-rv-ink-400">{notesCount} uploaded</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/dashboard/flashcards')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-navy-50 rounded-rec">
                          <CreditCard className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">My Flashcards</p>
                          <p className="text-xs text-rv-ink-400">{flashcardsCount} created</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                </div>
              </div>

              {/* Accuracy by question type — this educator's cohort (Sprint 6.3) */}
              {educatorAccuracy && educatorAccuracy.length > 0 && (
                <div>
                  <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">Accuracy by question type</h2>
                  <Card>
                    <CardContent className="pt-5 pb-4 space-y-3">
                      {educatorAccuracy.map((row) => {
                        const pct = row.accuracy_pct == null ? 0 : Number(row.accuracy_pct);
                        return (
                          <div key={row.question_type} className="space-y-1">
                            <div className="flex items-baseline justify-between gap-3">
                              <span className="text-sm text-rv-ink-900">
                                {formatQuestionType(row.question_type)}
                              </span>
                              <span className="shrink-0 text-xs text-rv-ink-400">
                                <Num className="text-rv-ink-900">{pct.toFixed(0)}%</Num>
                                {' · '}
                                <Num>{row.total_graded}</Num> graded
                              </span>
                            </div>
                            <div className="h-1.5 w-full overflow-hidden rounded-rec bg-rv-slate-50">
                              <div
                                className="h-full rounded-rec bg-rv-navy"
                                style={{ width: `${Math.max(2, Math.min(100, pct))}%` }}
                              />
                            </div>
                          </div>
                        );
                      })}
                      <p className="pt-1 text-[11px] text-rv-ink-400">
                        Hit = graded Medium or Easy; Hard = miss. Concept cards excluded.
                      </p>
                    </CardContent>
                  </Card>
                </div>
              )}

              {/* Cohort forward load — scheduled reviews across ALL students in this
                  course (Sprint 7.2-A: relabelled for clarity — this is not the
                  professor's own load; their own due count sits alongside it for
                  contrast, since the two numbers measure different things). */}
              {cohortForecastSeries && cohortForecastSeries.some(v => v > 0) && (
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400">
                      Cohort forward load — all students in your course
                    </h2>
                    <span className="text-xs text-rv-ink-400">
                      Your own due today: <span className="font-plex-mono font-medium text-rv-ink-900">{myDueToday}</span>
                    </span>
                  </div>
                  <Card>
                    <CardContent className="pt-5 pb-4">
                      <ForwardLedgerMacro data={cohortForecastSeries} unit="reviews" />
                    </CardContent>
                  </Card>
                </div>
              )}

              {/* Activity Feed */}
              <ActivityFeed limit={5} />
            </div>
          </>
        ) : userRole === 'admin' ? (
          <>
            {/* ===== ADMIN DASHBOARD ===== */}
            <div className="mb-6 sm:mb-8">
              <h1 className="text-2xl sm:text-3xl font-bold">
                Welcome back{userName ? `, ${userName.split(' ')[0]}` : ''}!
              </h1>
              <p className="text-rv-ink-400 mt-2">
                Manage the RevisOp platform — content, users, and topics.
              </p>
            </div>

            <div className="space-y-4 sm:space-y-6">
              {/* Admin Tools */}
              <div>
                <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">
                  Admin Tools
                </h2>
                <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-3">
                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/admin')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-navy-50 rounded-rec">
                          <Shield className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Admin Dashboard</p>
                          <p className="text-xs text-rv-ink-400">Users & platform overview</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/admin/analytics')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-navy-50 rounded-rec">
                          <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Admin Analytics</p>
                          <p className="text-xs text-rv-ink-400">Platform-wide stats</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/admin/bulk-upload-topics')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-green-50 rounded-rec">
                          <Upload className="h-4 w-4 sm:h-5 sm:w-5 text-green-600" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Manage Topics</p>
                          <p className="text-xs text-rv-ink-400">Subjects & topic tree</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                </div>
              </div>

              {/* Needs Review — flagged content queue */}
              <Card
                className={`cursor-pointer transition hover:border-rv-navy-400 ${needsReviewCount > 0 ? 'border-red-200 bg-red-50' : 'border-rv-border'}`}
                onClick={() => navigate('/admin')}
              >
                <CardHeader className="pb-2">
                  <CardTitle className={`flex items-center gap-2 text-base ${needsReviewCount > 0 ? 'text-red-800' : 'text-rv-ink-900'}`}>
                    <Flag className={`h-4 w-4 ${needsReviewCount > 0 ? 'text-red-600' : 'text-rv-ink-400'}`} />
                    {needsReviewCount > 0 ? `${needsReviewCount} Item${needsReviewCount === 1 ? '' : 's'} Need Review` : 'Needs Review'}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className={`text-sm ${needsReviewCount > 0 ? 'text-red-700' : 'text-rv-ink-400'}`}>
                    {needsReviewCount > 0
                      ? `${needsReviewCount} pending flag${needsReviewCount === 1 ? '' : 's'} from students. Review in Admin Dashboard → Content tab.`
                      : 'No pending flags. All clear!'}
                  </p>
                </CardContent>
              </Card>

              {/* Activity Feed */}
              <ActivityFeed limit={5} />
            </div>
          </>
        ) : userRole === 'super_admin' ? (
          <>
            {/* ===== SUPER ADMIN DASHBOARD ===== */}
            <div className="mb-6 sm:mb-8">
              <h1 className="text-2xl sm:text-3xl font-bold">
                Welcome back{userName ? `, ${userName.split(' ')[0]}` : ''}!
              </h1>
              <p className="text-rv-ink-400 mt-2">
                Full platform access — admin and super admin tools.
              </p>
            </div>

            <div className="space-y-4 sm:space-y-6">
              {/* Admin Tools */}
              <div>
                <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">
                  Admin Tools
                </h2>
                <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-3">
                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/admin')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-navy-50 rounded-rec">
                          <Shield className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Admin Dashboard</p>
                          <p className="text-xs text-rv-ink-400">Users & platform overview</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/admin/analytics')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-navy-50 rounded-rec">
                          <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Admin Analytics</p>
                          <p className="text-xs text-rv-ink-400">Platform-wide stats</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition hover:border-rv-navy-400"
                    onClick={() => navigate('/admin/bulk-upload-topics')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-rv-green-50 rounded-rec">
                          <Upload className="h-4 w-4 sm:h-5 sm:w-5 text-green-600" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Manage Topics</p>
                          <p className="text-xs text-rv-ink-400">Subjects & topic tree</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                </div>
              </div>

              {/* Super Admin Tools — elevated privilege, visually distinct */}
              <div>
                <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">
                  Super Admin Tools
                  <span className="ml-2 text-[10px] font-normal bg-red-100 text-red-700 px-1.5 py-0.5 rounded">Elevated</span>
                </h2>
                <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-2">
                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition border-red-200 hover:border-red-400"
                    onClick={() => navigate('/super-admin')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-red-100 rounded-lg">
                          <Shield className="h-4 w-4 sm:h-5 sm:w-5 text-red-600" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">Super Admin Dashboard</p>
                          <p className="text-xs text-rv-ink-400">Roles, access, system controls</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  <Card
                    className="hover:bg-rv-bg-2 cursor-pointer transition border-red-200 hover:border-red-400"
                    onClick={() => navigate('/super-admin/analytics')}
                  >
                    <CardContent className="pt-4 pb-4">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-red-100 rounded-lg">
                          <BarChart3 className="h-4 w-4 sm:h-5 sm:w-5 text-red-600" />
                        </div>
                        <div>
                          <p className="font-medium text-sm sm:text-base">SA Analytics</p>
                          <p className="text-xs text-rv-ink-400">Cross-platform deep stats</p>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                </div>
              </div>

              {/* Needs Review — flagged content queue */}
              <Card
                className={`cursor-pointer transition hover:border-rv-navy-400 ${needsReviewCount > 0 ? 'border-red-200 bg-red-50' : 'border-rv-border'}`}
                onClick={() => navigate('/admin')}
              >
                <CardHeader className="pb-2">
                  <CardTitle className={`flex items-center gap-2 text-base ${needsReviewCount > 0 ? 'text-red-800' : 'text-rv-ink-900'}`}>
                    <Flag className={`h-4 w-4 ${needsReviewCount > 0 ? 'text-red-600' : 'text-rv-ink-400'}`} />
                    {needsReviewCount > 0 ? `${needsReviewCount} Item${needsReviewCount === 1 ? '' : 's'} Need Review` : 'Needs Review'}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className={`text-sm ${needsReviewCount > 0 ? 'text-red-700' : 'text-rv-ink-400'}`}>
                    {needsReviewCount > 0
                      ? `${needsReviewCount} pending flag${needsReviewCount === 1 ? '' : 's'} from students. Review in Admin Dashboard → Content tab.`
                      : 'No pending flags. All clear!'}
                  </p>
                </CardContent>
              </Card>

              {/* Activity Feed */}
              <ActivityFeed limit={5} />
            </div>
          </>
        ) : (
          <>
            {/* ===== STUDENT DASHBOARD ===== */}

            {/* Header Section */}
            <div className="mb-6 sm:mb-8">
              <h1 className="text-2xl sm:text-3xl font-bold">
                {isNewUser
                  ? `Welcome to RevisOp${userName ? `, ${userName.split(' ')[0]}` : ''}! 👋`
                  : `Welcome back${userName ? `, ${userName.split(' ')[0]}` : ''}! 👋`
                }
              </h1>
            </div>

            {/* Push notification permission prompt — shown once, dismissed to localStorage */}
            <PushPermissionBanner />

            <div className="space-y-4 sm:space-y-6">

              {/* ===== NEW USER ONBOARDING ===== */}
              {isNewUser && (
                <Card className="bg-amber-50 border-amber-200">
                  <CardHeader>
                    <CardTitle className="text-base sm:text-lg">Get Started</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div>
                        <div className="flex items-center gap-2 mb-2">
                          <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-rv-navy" />
                          <h3 className="font-semibold text-sm sm:text-base">Browse Content</h3>
                        </div>
                        <p className="text-xs sm:text-sm text-rv-ink-600 mb-3">
                          Explore expert notes and flashcards created by professors
                        </p>
                        <div className="flex flex-wrap gap-3">
                          <Button variant="outline" onClick={() => navigate('/dashboard/notes')}>
                            <FileText className="mr-2 h-4 w-4" /> Browse Notes
                          </Button>
                          <Button variant="outline" onClick={() => navigate('/dashboard/review-flashcards')}>
                            <CreditCard className="mr-2 h-4 w-4" /> Browse Flashcards
                          </Button>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              )}

              {/* Sprint 7.2-D: the standalone "N items ready" / "All caught up" CTA
                   card is REMOVED — it duplicated the header subtitle above (which
                   already says the same thing) and the Review-tab due badge (7.2-F).
                   Browse links for the caught-up state moved into a slim strip. */}
              {!isNewUser && reviewsDue === 0 && (
                <div className="flex flex-wrap gap-2">
                  <Button variant="outline" size="sm" onClick={() => navigate('/dashboard/review-flashcards')}>
                    Browse Study Sets
                  </Button>
                  <Button size="sm" onClick={() => navigate('/dashboard/notes')}>
                    Browse Notes
                  </Button>
                </div>
              )}

              {/* ===== GOAL PROGRESS =====
                   Sprint 7.3-A: reordered to the top of the reporting stack — this is
                   the "am I on track today" signal, so it leads. Two-state behavior
                   (goal set / not set) lives inside GoalProgressWidget (7.3-B). */}
              {!isNewUser && (
                <GoalProgressWidget
                  reviewGoal={reviewGoal}
                  studyGoalMinutes={studyGoalMinutes}
                  todayReviews={todayReviews}
                  todaySeconds={studyTimeStats.today_seconds_in_app + studyTimeStats.today_seconds_offline}
                  goalPromptDismissed={goalPromptDismissed}
                  onDismissGoalPrompt={handleDismissGoalPrompt}
                  onGoalUpdated={(rg, sg) => {
                    setReviewGoal(rg);
                    setStudyGoalMinutes(sg);
                  }}
                />
              )}

              {/* ===== LEADERBOARD ===== */}
              {!isNewUser && (
                <LeaderboardWidget courseLevel={userCourseLevel} />
              )}

              {/* ===== FORWARD LEDGER — scheduled load, today → 6 months out ===== */}
              {!isNewUser && forecastSeries && forecastSeries.some(v => v > 0) && (
                <div>
                  <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">Forward load</h2>
                  <Card>
                    <CardContent className="pt-5 pb-4">
                      <ForwardLedgerMacro data={forecastSeries} unit="items" />
                    </CardContent>
                  </Card>
                </div>
              )}

              {/* ===== STUDY TIME REPORT =====
                   Sprint 7.3-C: pure end-of-day report now — in-app vs offline split,
                   no interactive control here (that moved to the nav timer chip + the
                   dedicated /dashboard/study-time route). */}
              {!isNewUser && (
                <div>
                  <h2 className="font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400 mb-3">
                    ⏱ Study Time
                  </h2>
                  <div className="grid gap-3 sm:gap-4 grid-cols-2">
                    <Card>
                      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-xs sm:text-sm font-medium">Today</CardTitle>
                        <Clock className="h-3 w-3 sm:h-4 sm:w-4 text-amber-500" />
                      </CardHeader>
                      <CardContent>
                        <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">
                          {studyTimeLoading ? '—' : formatStudyTime(studyTimeStats.today_seconds_in_app + studyTimeStats.today_seconds_offline)}
                        </div>
                        <p className="text-[10px] sm:text-xs text-rv-ink-400">
                          {studyTimeLoading ? '' : `${formatStudyTime(studyTimeStats.today_seconds_in_app)} in-app · ${formatStudyTime(studyTimeStats.today_seconds_offline)} offline`}
                        </p>
                      </CardContent>
                    </Card>

                    <Card>
                      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-xs sm:text-sm font-medium">This Week</CardTitle>
                        <Clock className="h-3 w-3 sm:h-4 sm:w-4 text-amber-500" />
                      </CardHeader>
                      <CardContent>
                        <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">
                          {studyTimeLoading ? '—' : formatStudyTime(studyTimeStats.week_seconds_in_app + studyTimeStats.week_seconds_offline)}
                        </div>
                        <p className="text-[10px] sm:text-xs text-rv-ink-400">
                          {studyTimeLoading ? '' : `${formatStudyTime(studyTimeStats.week_seconds_in_app)} in-app · ${formatStudyTime(studyTimeStats.week_seconds_offline)} offline`}
                        </p>
                      </CardContent>
                    </Card>
                  </div>
                </div>
              )}

              {/* ===== RECENT ACTIVITY FEED =====
                   Last card on the student dashboard (Sprint 7.3 follow-up) —
                   Quick Actions / My Contributions removed (redundant with the
                   Create dropdown/sheet and the ProfileDropdown "My
                   Contributions" link); My Reports moved to a dedicated
                   "Report History" page linked from the profile dropdown. */}
              {!isNewUser && (
                <ActivityFeed limit={5} />
              )}

            </div>
          </>
        )}
      </PageContainer>
  );
}
