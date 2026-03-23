import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer,
  PieChart, Pie, Cell,
} from 'recharts';
import {
  BookOpen, Users, Star, TrendingUp, AlertTriangle,
  Upload, Copy, ChevronUp, ChevronDown, Minus,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useRole } from '@/hooks/useRole';
import { useCourseContext } from '@/contexts/CourseContext';
import { supabase } from '@/lib/supabase';
import PageContainer from '@/components/layout/PageContainer';
import { useToast } from '@/hooks/use-toast';
import { Button } from '@/components/ui/button';

// ─── Recharts custom tooltip ──────────────────────────────────────────────────
function WeeklyTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  const count = payload[0].value;
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-md px-3 py-2 text-sm">
      <p className="font-medium text-gray-700">Week of {label}</p>
      <p className="text-indigo-600 font-bold mt-0.5">
        {count} new student{count !== 1 ? 's' : ''}
      </p>
    </div>
  );
}

// ─── Recharts custom tooltip for quality pie ──────────────────────────────────
function QualityPieTooltip({ active, payload }) {
  if (!active || !payload?.length) return null;
  const { name, value } = payload[0];
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-md px-3 py-2 text-sm">
      <p className="font-medium text-gray-700">{name}</p>
      <p className="text-gray-500 mt-0.5">{value} card{value !== 1 ? 's' : ''}</p>
    </div>
  );
}

// ─── Format week_start date string (timezone-safe — never uses Date constructor) ─
// Input: '2026-01-19'  →  Output: 'Jan 19'
function formatWeekLabel(dateStr) {
  if (!dateStr) return '';
  const parts = dateStr.split('-');
  const month = parseInt(parts[1], 10);
  const day   = parseInt(parts[2], 10);
  const MONTHS = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${MONTHS[month]} ${day}`;
}

// ─── Main component ───────────────────────────────────────────────────────────
export default function ProfessorAnalytics() {
  const { user }                                        = useAuth();
  const { isProfessor, isLoading: roleLoading } = useRole();
  const { teachingCourses, activeCourse, loading: courseLoading } = useCourseContext();
  const navigate                                        = useNavigate();
  const { toast }                                       = useToast();

  // ── Course selection ────────────────────────────────────────────────────────
  const [selectedCourse, setSelectedCourse] = useState(null);

  // ── Data ────────────────────────────────────────────────────────────────────
  const [overview,    setOverview]    = useState(null);
  const [subjects,    setSubjects]    = useState([]);
  const [weakCards,   setWeakCards]   = useState([]);
  const [topCards,    setTopCards]    = useState([]);
  const [weeklyReach, setWeeklyReach] = useState([]);
  const [loading,     setLoading]     = useState(true);

  // ── Subject table sort ──────────────────────────────────────────────────────
  const [sortCol, setSortCol] = useState('total_reviews');
  const [sortDir, setSortDir] = useState('desc');

  // ── Role guard — professors only ────────────────────────────────────────────
  // Admins and super_admins have their own dedicated analytics pages.
  // This page is about "my published content engagement" — only professors publish content.
  useEffect(() => {
    if (!roleLoading && !isProfessor) {
      navigate('/dashboard', { replace: true });
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roleLoading, isProfessor]);

  // ── Initialise selectedCourse once CourseContext resolves ───────────────────
  useEffect(() => {
    if (activeCourse && selectedCourse === null) {
      setSelectedCourse(activeCourse);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeCourse]);

  // ── Fetch all 5 RPCs in parallel ───────────────────────────────────────────
  const fetchAll = useCallback(async () => {
    if (!user?.id || !selectedCourse) return;
    setLoading(true);
    try {
      const [ov, sub, weak, top, weekly] = await Promise.all([
        supabase.rpc('get_professor_overview',           { p_professor_id: user.id, p_course_level: selectedCourse }),
        supabase.rpc('get_professor_subject_engagement', { p_professor_id: user.id, p_course_level: selectedCourse }),
        supabase.rpc('get_professor_weak_cards',         { p_professor_id: user.id, p_course_level: selectedCourse }),
        supabase.rpc('get_professor_top_cards',          { p_professor_id: user.id, p_course_level: selectedCourse }),
        supabase.rpc('get_professor_weekly_reach',       { p_professor_id: user.id, p_course_level: selectedCourse }),
      ]);
      setOverview(ov.data?.[0]    ?? null);
      setSubjects(sub.data        ?? []);
      setWeakCards(weak.data      ?? []);
      setTopCards(top.data        ?? []);
      setWeeklyReach(weekly.data  ?? []);
    } catch (err) {
      console.error('ProfessorAnalytics fetch error:', err);
    } finally {
      setLoading(false);
    }
  }, [user?.id, selectedCourse]);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // ── Sorted subject table ────────────────────────────────────────────────────
  const sortedSubjects = [...subjects].sort((a, b) => {
    const av = a[sortCol] ?? 0;
    const bv = b[sortCol] ?? 0;
    if (typeof av === 'string') {
      return sortDir === 'asc' ? av.localeCompare(bv) : bv.localeCompare(av);
    }
    return sortDir === 'asc' ? av - bv : bv - av;
  });

  const toggleSort = (col) => {
    if (sortCol === col) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortCol(col); setSortDir('desc'); }
  };

  // ── Copy card ID ────────────────────────────────────────────────────────────
  const copyCardId = async (id) => {
    try {
      await navigator.clipboard.writeText(id);
      toast({ title: 'Card ID copied', description: `${id.slice(0, 8)}…` });
    } catch {
      toast({ title: 'Copy failed', variant: 'destructive' });
    }
  };

  // ── Derived flags ───────────────────────────────────────────────────────────
  const showCoursePills = teachingCourses.length > 1;
  const totalCards   = overview ? Number(overview.total_cards_published) : 0;
  const totalReviews = overview ? Number(overview.total_reviews)         : 0;
  const noCards      = !loading && overview !== null && totalCards   === 0;
  const noReviews    = !loading && overview !== null && totalCards   >  0 && totalReviews === 0;
  const allZeroWeeks = weeklyReach.length > 0 && weeklyReach.every(w => w.new_students === 0);

  // ── Chart data (inject readable label) ─────────────────────────────────────
  const chartData = weeklyReach.map(w => ({ ...w, label: formatWeekLabel(w.week_start) }));

  // ── Quality distribution (computed from subject-level averages) ─────────────
  const qualityPieData = useMemo(() => {
    if (!subjects.length) return [];
    let easy = 0, medium = 0, hard = 0, unreviewed = 0;
    subjects.forEach(s => {
      const cards = Number(s.card_count) || 0;
      if (!Number(s.total_reviews)) { unreviewed += cards; return; }
      const q = Number(s.avg_quality);
      if (q >= 4) easy += cards;
      else if (q >= 3) medium += cards;
      else hard += cards;
    });
    return [
      { name: 'Easy (≥4.0)', value: easy,       color: '#22c55e' },
      { name: 'Medium (3–4)', value: medium,     color: '#f59e0b' },
      { name: 'Hard (<3.0)',  value: hard,        color: '#ef4444' },
      { name: 'Not Reviewed', value: unreviewed,  color: '#d1d5db' },
    ].filter(d => d.value > 0);
  }, [subjects]);

  // ── Full-page spinner while role/course context resolves ────────────────────
  if (roleLoading || courseLoading) {
    return (
      <div className="h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600" />
      </div>
    );
  }

  // ─── Render ────────────────────────────────────────────────────────────────
  return (
    <PageContainer width="full">

      {/* ── Page header ──────────────────────────────────────────────────── */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Professor Analytics</h1>
        <p className="text-sm text-gray-500 mt-1">
          How students are engaging with your published content
          {selectedCourse && <span className="font-medium text-gray-700"> · {selectedCourse}</span>}
        </p>
      </div>

      {/* ── Course selector pills ─────────────────────────────────────────── */}
      {showCoursePills && (
        <div className="flex items-center gap-3 mb-6 flex-wrap">
          <span className="text-sm text-gray-500 shrink-0">Course:</span>
          <div className="flex flex-wrap gap-2">
            {teachingCourses.map((c) => {
              const name     = c.disciplines.name;
              const isActive = name === selectedCourse;
              return (
                <button
                  key={c.id}
                  onClick={() => setSelectedCourse(name)}
                  className={`px-3 py-1.5 rounded-md text-sm font-medium border transition-colors ${
                    isActive
                      ? 'bg-indigo-600 text-white border-indigo-600 shadow-sm'
                      : 'bg-white text-gray-600 border-gray-300 hover:border-indigo-400 hover:text-indigo-600'
                  }`}
                >
                  {name}
                  {isActive && <span className="ml-1.5 text-indigo-200 text-xs">●</span>}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* ── Stat strip (always visible) ──────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard
          icon={<BookOpen className="h-7 w-7 text-blue-500" />}
          value={loading ? null : totalCards}
          label="Cards Published"
          sub={selectedCourse ?? ''}
        />
        <StatCard
          icon={<Users className="h-7 w-7 text-purple-500" />}
          value={loading ? null : (overview?.total_students_reached ?? 0)}
          label="Students Reached"
          sub="Reviewed at least once"
        />
        <StatCard
          icon={<TrendingUp className="h-7 w-7 text-green-500" />}
          value={loading ? null : totalReviews}
          label="Total Reviews"
          sub="All time"
        />
        <StatCard
          icon={<Star className="h-7 w-7 text-amber-500" />}
          value={
            loading                              ? null  :
            overview?.avg_quality == null        ? '—'   :
            Number(overview.avg_quality).toFixed(1)
          }
          label="Avg Quality"
          sub="Scale 1–5"
        />
      </div>

      {/* ── Zero-cards empty state ────────────────────────────────────────── */}
      {noCards && (
        <div className="bg-blue-50 border border-blue-200 rounded-xl p-10 text-center">
          <Upload className="h-12 w-12 text-blue-400 mx-auto mb-4" />
          <h3 className="text-base font-semibold text-blue-900 mb-1">
            No cards published yet
          </h3>
          <p className="text-sm text-blue-700 mb-5">
            Publish flashcards for{' '}
            <span className="font-medium">{selectedCourse}</span> to start seeing
            engagement data here.
          </p>
          <Link to="/dashboard/bulk-upload">
            <Button size="sm" className="bg-blue-600 hover:bg-blue-700 text-white">
              Go to Bulk Upload
            </Button>
          </Link>
        </div>
      )}

      {/* ── Main analytics body (cards exist) ────────────────────────────── */}
      {!noCards && (
        <div className="space-y-8">

          {/* No-reviews notice */}
          {noReviews && (
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-5 text-center">
              <p className="text-sm font-medium text-amber-800">
                No students have reviewed your content yet.
              </p>
              <p className="text-xs text-amber-600 mt-1">
                Student engagement data will appear here once reviews start coming in.
              </p>
            </div>
          )}

          {/* ── Subject engagement table ──────────────────────────────────── */}
          <section>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
              Subject Engagement
            </h2>
            <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
              {loading ? (
                <TableSkeleton rows={4} cols={5} />
              ) : subjects.length === 0 ? (
                <EmptyPanel message="No subject data found for this course." />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <SortTh col="subject_name"   label="Subject"     sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="left"  />
                        <SortTh col="card_count"     label="Cards"       sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                        <SortTh col="unique_students" label="Students"   sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                        <SortTh col="total_reviews"  label="Reviews"     sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                        <SortTh col="avg_quality"    label="Avg Quality" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {sortedSubjects.map((row) => {
                        const hasReviews  = Number(row.total_reviews) > 0;
                        const struggling  = hasReviews && Number(row.avg_quality) < 3;
                        return (
                          <tr
                            key={row.subject_name}
                            className={struggling ? 'bg-amber-50' : 'hover:bg-gray-50 transition-colors'}
                          >
                            <td className="px-4 py-3 font-medium text-gray-900">
                              <div className="flex items-center gap-2">
                                {struggling && (
                                  <AlertTriangle className="h-3.5 w-3.5 text-amber-500 shrink-0" />
                                )}
                                {row.subject_name}
                              </div>
                            </td>
                            <td className="px-4 py-3 text-right text-gray-600">
                              {row.card_count}
                            </td>
                            <td className="px-4 py-3 text-right text-gray-600">
                              {row.unique_students}
                            </td>
                            <td className="px-4 py-3 text-right text-gray-600">
                              {row.total_reviews}
                            </td>
                            <td className="px-4 py-3 text-right">
                              <QualityBadge value={row.avg_quality} hasReviews={hasReviews} />
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
            {!loading && subjects.length > 0 && (
              <p className="text-xs text-amber-700 mt-1.5 flex items-center gap-1">
                <AlertTriangle className="h-3 w-3 shrink-0" />
                Amber rows — avg quality below 3 means students are finding these cards hard.
              </p>
            )}
          </section>

          {/* ── Quality distribution + Weekly reach ──────────────────────── */}
          {!noReviews && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

              {/* Quality distribution donut */}
              <section>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
                  Quality Distribution
                  <span className="ml-1.5 text-xs font-normal normal-case text-gray-400">
                    (by subject avg · Easy ≥4, Medium 3–4, Hard &lt;3)
                  </span>
                </h2>
                <div className="bg-white rounded-lg border border-gray-200 p-4">
                  {loading ? (
                    <div className="h-52 animate-pulse bg-gray-100 rounded" />
                  ) : qualityPieData.length === 0 ? (
                    <EmptyPanel message="No review data yet." />
                  ) : (
                    <>
                      <ResponsiveContainer width="100%" height={200}>
                        <PieChart>
                          <Pie
                            data={qualityPieData}
                            cx="50%"
                            cy="50%"
                            innerRadius={55}
                            outerRadius={85}
                            paddingAngle={2}
                            dataKey="value"
                          >
                            {qualityPieData.map((entry, index) => (
                              <Cell key={index} fill={entry.color} />
                            ))}
                          </Pie>
                          <Tooltip content={<QualityPieTooltip />} />
                        </PieChart>
                      </ResponsiveContainer>
                      {/* Legend */}
                      <div className="flex flex-wrap justify-center gap-x-4 gap-y-1 mt-2">
                        {qualityPieData.map(d => (
                          <span key={d.name} className="flex items-center gap-1.5 text-xs text-gray-600">
                            <span className="inline-block h-2.5 w-2.5 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
                            {d.name} ({d.value})
                          </span>
                        ))}
                      </div>
                    </>
                  )}
                </div>
              </section>

              {/* Weekly student reach chart */}
              <section>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
                  New Students per Week
                  <span className="ml-1.5 text-xs font-normal normal-case text-gray-400">
                    (last 8 weeks — first-time reviewers only)
                  </span>
                </h2>
                <div className="bg-white rounded-lg border border-gray-200 p-4">
                  {loading ? (
                    <div className="h-52 animate-pulse bg-gray-100 rounded" />
                  ) : (
                    <>
                      <ResponsiveContainer width="100%" height={200}>
                        <BarChart
                          data={chartData}
                          margin={{ top: 4, right: 4, bottom: 0, left: -20 }}
                        >
                          <CartesianGrid
                            strokeDasharray="3 3"
                            stroke="#f0f0f0"
                            vertical={false}
                          />
                          <XAxis
                            dataKey="label"
                            tick={{ fontSize: 11, fill: '#9ca3af' }}
                            axisLine={false}
                            tickLine={false}
                          />
                          <YAxis
                            allowDecimals={false}
                            tick={{ fontSize: 11, fill: '#9ca3af' }}
                            axisLine={false}
                            tickLine={false}
                          />
                          <Tooltip content={WeeklyTooltip} cursor={{ fill: '#f5f3ff' }} />
                          <Bar
                            dataKey="new_students"
                            fill="#6366f1"
                            radius={[4, 4, 0, 0]}
                            maxBarSize={48}
                          />
                        </BarChart>
                      </ResponsiveContainer>
                      {allZeroWeeks && (
                        <p className="text-center text-sm text-gray-400 mt-2">
                          No new students reached in the last 8 weeks.
                        </p>
                      )}
                    </>
                  )}
                </div>
              </section>
            </div>
          )}

          {/* ── Challenging cards + Most Reviewed panels ──────────────────── */}
          {!noReviews && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

              {/* Challenging cards */}
              <section>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Challenging Cards
                  <span className="ml-1.5 text-xs font-normal normal-case text-gray-400">
                    (min 3 reviews to qualify)
                  </span>
                </h2>
                <p className="text-xs text-gray-400 mb-3">
                  Students are finding these concepts harder to recall — not necessarily a content issue.
                  Consider adding mnemonics or revisiting these in class.
                </p>
                <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
                  {loading ? (
                    <CardPanelSkeleton />
                  ) : weakCards.length === 0 ? (
                    <EmptyPanel message="No cards with 3+ reviews yet." />
                  ) : (
                    <div className="divide-y divide-gray-100">
                      {weakCards.map((card, i) => (
                        <CardPanelRow
                          key={card.card_id}
                          rank={i + 1}
                          card={card}
                          metric={<QualityBadge value={card.avg_quality} hasReviews />}
                          metaSub={`${card.review_count} reviews`}
                          onCopy={() => copyCardId(card.card_id)}
                          rankColor="text-red-500"
                        />
                      ))}
                    </div>
                  )}
                </div>
              </section>

              {/* Top cards */}
              <section>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Most Reviewed Cards
                </h2>
                <p className="text-xs text-gray-400 mb-3">
                  Cards students are returning to most often — high engagement, likely high importance.
                </p>
                <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
                  {loading ? (
                    <CardPanelSkeleton />
                  ) : topCards.length === 0 ? (
                    <EmptyPanel message="No reviews yet." />
                  ) : (
                    <div className="divide-y divide-gray-100">
                      {topCards.map((card, i) => (
                        <CardPanelRow
                          key={card.card_id}
                          rank={i + 1}
                          card={card}
                          metric={
                            <span className="text-sm font-bold text-gray-800">
                              {card.total_reviews}
                            </span>
                          }
                          metaSub={
                            card.avg_quality != null
                              ? `Quality: ${Number(card.avg_quality).toFixed(1)}`
                              : 'Quality: —'
                          }
                          onCopy={() => copyCardId(card.card_id)}
                          rankColor="text-indigo-500"
                        />
                      ))}
                    </div>
                  )}
                </div>
              </section>
            </div>
          )}

        </div>
      )}
    </PageContainer>
  );
}

// ─── StatCard ─────────────────────────────────────────────────────────────────
function StatCard({ icon, value, label, sub }) {
  return (
    <div className="bg-white p-5 rounded-lg shadow-sm border border-gray-200">
      <div className="flex items-center justify-between mb-3">
        {icon}
        <span className="text-2xl font-bold text-gray-900">
          {value === null
            ? <span className="text-gray-300 animate-pulse">—</span>
            : value}
        </span>
      </div>
      <h3 className="text-sm font-medium text-gray-600">{label}</h3>
      <p className="text-xs text-gray-400 mt-0.5 truncate">{sub}</p>
    </div>
  );
}

// ─── QualityBadge ─────────────────────────────────────────────────────────────
function QualityBadge({ value, hasReviews }) {
  if (!hasReviews || value == null) {
    return <span className="text-sm text-gray-400">—</span>;
  }
  const num = Number(value);
  const cls =
    num >= 4   ? 'text-green-700 bg-green-50 border border-green-200' :
    num >= 3   ? 'text-amber-700 bg-amber-50 border border-amber-200' :
                 'text-red-700   bg-red-50   border border-red-200';
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold ${cls}`}>
      {num.toFixed(1)} / 5
    </span>
  );
}

// ─── SortTh ───────────────────────────────────────────────────────────────────
function SortTh({ col, label, sortCol, sortDir, onSort, align }) {
  const isActive = sortCol === col;
  const Icon     = isActive ? (sortDir === 'asc' ? ChevronUp : ChevronDown) : Minus;
  return (
    <th
      className={`px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide
                  cursor-pointer select-none hover:text-gray-700 text-${align}`}
      onClick={() => onSort(col)}
    >
      <span className={`inline-flex items-center gap-1 ${align === 'right' ? 'justify-end w-full' : ''}`}>
        {label}
        <Icon className={`h-3 w-3 shrink-0 ${isActive ? 'text-gray-700' : 'opacity-25'}`} />
      </span>
    </th>
  );
}

// ─── CardPanelRow ─────────────────────────────────────────────────────────────
function CardPanelRow({ rank, card, metric, metaSub, onCopy, rankColor }) {
  return (
    <div className="px-4 py-3 flex items-start gap-3 hover:bg-gray-50 transition-colors">
      <span className={`text-sm font-bold w-5 shrink-0 pt-0.5 ${rankColor}`}>{rank}</span>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900 truncate">{card.front_text}</p>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-xs text-gray-400 truncate">{card.subject_name}</span>
          <span className="text-xs text-gray-300">·</span>
          <span className="text-xs text-gray-400 shrink-0">{metaSub}</span>
        </div>
      </div>
      <div className="flex items-center gap-2 shrink-0">
        {metric}
        <button
          onClick={onCopy}
          title="Copy card ID"
          className="p-1 text-gray-300 hover:text-gray-500 transition-colors rounded"
        >
          <Copy className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

// ─── Skeleton loaders ─────────────────────────────────────────────────────────
function TableSkeleton({ rows = 3, cols = 5 }) {
  return (
    <div className="p-4 space-y-3 animate-pulse">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-4">
          {Array.from({ length: cols }).map((_, j) => (
            <div
              key={j}
              className={`h-4 bg-gray-100 rounded ${j === 0 ? 'flex-1' : 'w-16'}`}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

function CardPanelSkeleton() {
  return (
    <div className="divide-y divide-gray-100 animate-pulse">
      {[1, 2, 3, 4, 5].map((i) => (
        <div key={i} className="px-4 py-3 flex items-center gap-3">
          <div className="h-4 w-4 bg-gray-100 rounded shrink-0" />
          <div className="flex-1 space-y-1.5">
            <div className="h-3.5 bg-gray-100 rounded w-3/4" />
            <div className="h-3   bg-gray-100 rounded w-1/2" />
          </div>
          <div className="h-5 w-14 bg-gray-100 rounded shrink-0" />
        </div>
      ))}
    </div>
  );
}

function EmptyPanel({ message }) {
  return (
    <div className="px-4 py-8 text-center text-sm text-gray-400">
      {message}
    </div>
  );
}
