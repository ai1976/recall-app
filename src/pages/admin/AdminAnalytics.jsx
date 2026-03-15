import { useState, useEffect, useCallback } from 'react';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer,
} from 'recharts';
import {
  Users, BookOpen, AlertCircle, TrendingUp,
  CheckCircle2, Clock, UserX, FileWarning,
  ChevronUp, ChevronDown, Minus,
} from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useRole } from '@/hooks/useRole';
import { supabase } from '@/lib/supabase';
import PageContainer from '@/components/layout/PageContainer';
import { Button } from '@/components/ui/button';

// ─── Recharts custom tooltip ──────────────────────────────────────────────────
function WeeklyTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  const count = payload[0].value;
  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-md px-3 py-2 text-sm">
      <p className="font-medium text-gray-700">Week of {label}</p>
      <p className="text-indigo-600 font-bold mt-0.5">
        {count} review{count !== 1 ? 's' : ''}
      </p>
    </div>
  );
}

// ─── Format week_start date string (timezone-safe — never uses Date constructor)
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
export default function AdminAnalytics() {
  const { isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();
  const navigate = useNavigate();

  // ── Data ────────────────────────────────────────────────────────────────────
  const [overview,      setOverview]      = useState(null);
  const [contentHealth, setContentHealth] = useState([]);
  const [onboarding,    setOnboarding]    = useState(null);
  const [weeklyReviews, setWeeklyReviews] = useState([]);
  const [loading,       setLoading]       = useState(true);

  // ── Content health table sort ────────────────────────────────────────────────
  const [sortCol, setSortCol] = useState('total_items');
  const [sortDir, setSortDir] = useState('desc');

  // ── Role guard — admin and super_admin only ──────────────────────────────────
  useEffect(() => {
    if (!roleLoading && !isAdmin && !isSuperAdmin) {
      navigate('/dashboard', { replace: true });
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roleLoading, isAdmin, isSuperAdmin]);

  // ── Fetch all 4 RPCs in parallel ────────────────────────────────────────────
  const fetchAll = useCallback(async () => {
    setLoading(true);
    try {
      const [ov, ch, ob, wr] = await Promise.all([
        supabase.rpc('get_admin_platform_overview'),
        supabase.rpc('get_content_health_stats'),
        supabase.rpc('get_user_onboarding_stats'),
        supabase.rpc('get_weekly_platform_reviews'),
      ]);
      if (ov.error) console.error('[AdminAnalytics] get_admin_platform_overview:', ov.error);
      if (ch.error) console.error('[AdminAnalytics] get_content_health_stats:', ch.error);
      if (ob.error) console.error('[AdminAnalytics] get_user_onboarding_stats:', ob.error);
      if (wr.error) console.error('[AdminAnalytics] get_weekly_platform_reviews:', wr.error);
      setOverview(ov.data?.[0]   ?? null);
      setContentHealth(ch.data   ?? []);
      setOnboarding(ob.data?.[0] ?? null);
      setWeeklyReviews(wr.data   ?? []);
    } catch (err) {
      console.error('AdminAnalytics fetch error:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // ── Sorted content health table ──────────────────────────────────────────────
  const sortedHealth = [...contentHealth].sort((a, b) => {
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

  // ── Derived ──────────────────────────────────────────────────────────────────
  const chartData = weeklyReviews.map(w => ({
    ...w,
    label: formatWeekLabel(w.week_start),
  }));
  const allZeroWeeks = weeklyReviews.length > 0 && weeklyReviews.every(w => w.review_count === 0);

  const reviewCoverage = onboarding && Number(onboarding.total_students) > 0
    ? Math.round((Number(onboarding.users_with_reviews) / Number(onboarding.total_students)) * 100)
    : 0;

  // ── Full-page spinner while role resolves ────────────────────────────────────
  if (roleLoading) {
    return (
      <div className="h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600" />
      </div>
    );
  }

  // ─── Render ─────────────────────────────────────────────────────────────────
  return (
    <PageContainer width="full">

      {/* ── Page header ───────────────────────────────────────────────────── */}
      <div className="flex items-start justify-between mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Admin Analytics</h1>
          <p className="text-sm text-gray-500 mt-1">
            Platform-wide health — content, users, and engagement
          </p>
        </div>
        <Link to="/admin" className="shrink-0">
          <Button variant="outline" size="sm">
            Admin Dashboard →
          </Button>
        </Link>
      </div>

      {/* ── Overview stat strip ───────────────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard
          icon={<Users className="h-7 w-7 text-blue-500" />}
          value={loading ? null : Number(overview?.total_users ?? 0)}
          label="Total Users"
          sub="All roles"
        />
        <StatCard
          icon={<TrendingUp className="h-7 w-7 text-green-500" />}
          value={loading ? null : Number(overview?.active_this_week ?? 0)}
          label="Active This Week"
          sub="Any study activity"
        />
        <StatCard
          icon={<FileWarning className="h-7 w-7 text-amber-500" />}
          value={loading ? null : Number(overview?.pending_reviews ?? 0)}
          label="Public Notes"
          sub="Shared by users"
        />
        <StatCard
          icon={<BookOpen className="h-7 w-7 text-purple-500" />}
          value={loading ? null : Number(overview?.published_items ?? 0)}
          label="Published Items"
          sub="Public flashcards"
        />
      </div>

      <div className="space-y-8">

        {/* ── Content health by course ───────────────────────────────────── */}
        <section>
          <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
            Content Health by Course
          </h2>
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            {loading ? (
              <TableSkeleton rows={4} cols={5} />
            ) : contentHealth.length === 0 ? (
              <EmptyPanel message="No active courses found." />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <SortTh col="course_name"    label="Course"          sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="left"  />
                      <SortTh col="total_items"    label="Published Items" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                      <SortTh col="verified_items" label="Verified"        sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                      <SortTh col="pending_notes"  label="Pending Notes"   sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                      <SortTh col="avg_quality"    label="Avg Quality"     sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} align="right" />
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {sortedHealth.map((row) => {
                      const hasPending = Number(row.pending_notes) > 0;
                      const lowQuality = row.avg_quality != null && Number(row.avg_quality) < 3;
                      const rowClass   = hasPending
                        ? 'bg-red-50'
                        : lowQuality
                          ? 'bg-amber-50'
                          : 'hover:bg-gray-50 transition-colors';
                      return (
                        <tr key={row.course_name} className={rowClass}>
                          <td className="px-4 py-3 font-medium text-gray-900">
                            <div className="flex items-center gap-2">
                              {hasPending && (
                                <AlertCircle className="h-3.5 w-3.5 text-red-500 shrink-0" />
                              )}
                              {row.course_name}
                            </div>
                          </td>
                          <td className="px-4 py-3 text-right text-gray-600">
                            {Number(row.total_items)}
                          </td>
                          <td className="px-4 py-3 text-right">
                            {Number(row.total_items) > 0 ? (
                              <span className="inline-flex items-center gap-1 text-green-700">
                                <CheckCircle2 className="h-3 w-3" />
                                {Number(row.verified_items)}
                              </span>
                            ) : (
                              <span className="text-gray-400">—</span>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right">
                            {Number(row.pending_notes) > 0 ? (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-semibold text-red-700 bg-red-100 border border-red-200">
                                <Clock className="h-3 w-3" />
                                {Number(row.pending_notes)}
                              </span>
                            ) : (
                              <span className="text-gray-400 text-xs">—</span>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right">
                            <QualityBadge value={row.avg_quality} hasItems={Number(row.total_items) > 0} />
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
          {!loading && contentHealth.some(r => Number(r.pending_notes) > 0) && (
            <div className="flex items-center justify-between mt-2">
              <p className="text-xs text-red-700 flex items-center gap-1">
                <AlertCircle className="h-3 w-3 shrink-0" />
                Red rows have public notes shared for that course.
              </p>
              <Link
                to="/admin"
                className="text-xs font-medium text-indigo-600 hover:text-indigo-800 underline-offset-2 hover:underline shrink-0"
              >
                Review content in Admin →
              </Link>
            </div>
          )}
          {!loading && contentHealth.length > 0 && !contentHealth.some(r => Number(r.pending_notes) > 0) && (
            <p className="text-xs text-gray-400 mt-1.5">All courses have no public notes.</p>
          )}
        </section>

        {/* ── Student onboarding funnel ──────────────────────────────────── */}
        <section>
          <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
            Student Onboarding
          </h2>
          <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
            <FunnelCard
              loading={loading}
              icon={<Users className="h-5 w-5 text-blue-500" />}
              value={onboarding?.new_this_week ?? 0}
              label="New This Week"
              sub={`${onboarding?.new_this_month ?? 0} in last 30 days`}
            />
            <FunnelCard
              loading={loading}
              icon={<UserX className="h-5 w-5 text-amber-500" />}
              value={onboarding?.users_no_reviews ?? 0}
              label="Never Studied"
              sub={`of ${onboarding?.total_students ?? 0} students`}
              highlight={!loading && Number(onboarding?.users_no_reviews) > 0}
            />
            <FunnelCard
              loading={loading}
              icon={<CheckCircle2 className="h-5 w-5 text-green-500" />}
              value={`${reviewCoverage}%`}
              label="Review Coverage"
              sub={`${onboarding?.users_with_reviews ?? 0} students active`}
            />
            <FunnelCard
              loading={loading}
              icon={<Users className="h-5 w-5 text-purple-500" />}
              value={onboarding?.total_students ?? 0}
              label="Total Students"
              sub="Registered accounts"
            />
            <FunnelCard
              loading={loading}
              icon={<AlertCircle className="h-5 w-5 text-red-400" />}
              value={onboarding?.incomplete_profiles ?? 0}
              label="Incomplete Profiles"
              sub="Missing name or course"
              highlight={!loading && Number(onboarding?.incomplete_profiles) > 0}
            />
          </div>
        </section>

        {/* ── Weekly review activity chart ───────────────────────────────── */}
        <section>
          <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
            Platform Reviews per Week
            <span className="ml-1.5 text-xs font-normal normal-case text-gray-400">
              (last 8 weeks — all students)
            </span>
          </h2>
          <div className="bg-white rounded-lg border border-gray-200 p-6">
            {loading ? (
              <div className="h-48 animate-pulse bg-gray-100 rounded" />
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
                      dataKey="review_count"
                      fill="#6366f1"
                      radius={[4, 4, 0, 0]}
                      maxBarSize={48}
                    />
                  </BarChart>
                </ResponsiveContainer>
                {allZeroWeeks && (
                  <p className="text-center text-sm text-gray-400 mt-2">
                    No review activity recorded in the last 8 weeks.
                  </p>
                )}
              </>
            )}
          </div>
        </section>

      </div>
    </PageContainer>
  );
}

// ─── StatCard ─────────────────────────────────────────────────────────────────
function StatCard({ icon, value, label, sub, highlight = false }) {
  return (
    <div className={`bg-white p-5 rounded-lg shadow-sm border ${highlight ? 'border-amber-300' : 'border-gray-200'}`}>
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

// ─── FunnelCard ───────────────────────────────────────────────────────────────
function FunnelCard({ loading, icon, value, label, sub, highlight = false }) {
  return (
    <div className={`bg-white p-4 rounded-lg border shadow-sm ${highlight ? 'border-amber-300' : 'border-gray-200'}`}>
      <div className="flex items-start gap-3">
        <div className="shrink-0 mt-0.5">{icon}</div>
        <div className="min-w-0">
          <p className="text-xl font-bold text-gray-900">
            {loading
              ? <span className="text-gray-300 animate-pulse">—</span>
              : value}
          </p>
          <p className="text-sm font-medium text-gray-600 mt-0.5">{label}</p>
          <p className="text-xs text-gray-400 mt-0.5 truncate">{sub}</p>
        </div>
      </div>
    </div>
  );
}

// ─── QualityBadge ─────────────────────────────────────────────────────────────
function QualityBadge({ value, hasItems }) {
  if (!hasItems || value == null) {
    return <span className="text-sm text-gray-400">—</span>;
  }
  const num = Number(value);
  const cls =
    num >= 4 ? 'text-green-700 bg-green-50 border border-green-200' :
    num >= 3 ? 'text-amber-700 bg-amber-50 border border-amber-200' :
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

function EmptyPanel({ message }) {
  return (
    <div className="px-4 py-8 text-center text-sm text-gray-400">
      {message}
    </div>
  );
}
