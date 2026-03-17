import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import PlatformHeatmap from '@/components/progress/PlatformHeatmap';
import {
  Users,
  BookOpen,
  BarChart3,
  GraduationCap,
  AlertCircle,
  TrendingUp,
  ChevronUp,
  ChevronDown,
  Trophy,
  Shield,
} from 'lucide-react';

// ─── Role badge helper ────────────────────────────────────────────────────────
function RoleBadge({ role }) {
  const cfg = {
    super_admin: 'bg-purple-100 text-purple-800',
    admin:       'bg-red-100    text-red-800',
    professor:   'bg-blue-100   text-blue-800',
    student:     'bg-green-100  text-green-800',
  };
  const label = {
    super_admin: 'Super Admin',
    admin:       'Admin',
    professor:   'Professor',
    student:     'Student Contributor',
  };
  return (
    <span className={`inline-flex px-2 py-0.5 text-xs font-semibold rounded-full ${cfg[role] ?? 'bg-gray-100 text-gray-700'}`}>
      {label[role] ?? role}
    </span>
  );
}

// ─── Sortable column header ───────────────────────────────────────────────────
function SortTh({ label, field, sortField, sortDir, onSort }) {
  const active = sortField === field;
  return (
    <th
      className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer select-none hover:text-gray-700"
      onClick={() => onSort(field)}
    >
      <span className="flex items-center gap-1">
        {label}
        {active ? (
          sortDir === 'asc' ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />
        ) : (
          <ChevronDown className="h-3 w-3 text-gray-300" />
        )}
      </span>
    </th>
  );
}

export default function SuperAdminAnalytics() {
  const { isSuperAdmin, isLoading: roleLoading } = useRole();

  // ── Section 1: header stats
  const [headerStats,     setHeaderStats]     = useState(null);
  const [headerError,     setHeaderError]     = useState(null);

  // ── Section 2: cohort comparison
  const [cohortRows,      setCohortRows]      = useState([]);
  const [cohortError,     setCohortError]     = useState(null);
  const [sortField,       setSortField]       = useState('student_count');
  const [sortDir,         setSortDir]         = useState('desc');

  // ── Section 3: creator leaderboard
  const [leaderboard,     setLeaderboard]     = useState([]);
  const [leaderboardError, setLeaderboardError] = useState(null);

  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!roleLoading && isSuperAdmin) {
      fetchAll();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuperAdmin, roleLoading]);

  async function fetchAll() {
    setIsLoading(true);
    await Promise.all([
      fetchHeaderStats(),
      fetchCohortComparison(),
      fetchLeaderboard(),
    ]);
    setIsLoading(false);
  }

  // ── Section 1 ───────────────────────────────────────────────────────────────
  async function fetchHeaderStats() {
    const result = await supabase.rpc('get_super_admin_header_stats');
    if (result.error) {
      console.error('get_super_admin_header_stats:', result.error);
      setHeaderError(result.error.message);
    } else {
      setHeaderStats(result.data?.[0] ?? null);
    }
  }

  // ── Section 2 ───────────────────────────────────────────────────────────────
  async function fetchCohortComparison() {
    const result = await supabase.rpc('get_super_admin_cohort_comparison');
    if (result.error) {
      console.error('get_super_admin_cohort_comparison:', result.error);
      setCohortError(result.error.message);
    } else {
      setCohortRows(result.data ?? []);
    }
  }

  // ── Section 3 ───────────────────────────────────────────────────────────────
  async function fetchLeaderboard() {
    const result = await supabase.rpc('get_creator_leaderboard');
    if (result.error) {
      console.error('get_creator_leaderboard:', result.error);
      setLeaderboardError(result.error.message);
      return;
    }

    const rows = result.data ?? [];
    if (rows.length === 0) {
      setLeaderboard([]);
      return;
    }

    // User attribution pattern: fetch profiles separately, merge in JS
    const userIds = rows.map((r) => r.user_id);
    const { data: profiles, error: profileError } = await supabase
      .from('profiles')
      .select('id, full_name, role, course_level')
      .in('id', userIds);

    if (profileError) {
      console.error('leaderboard profiles fetch:', profileError);
    }

    const profileMap = new Map((profiles ?? []).map((p) => [p.id, p]));
    const merged = rows.map((row, i) => ({
      ...row,
      rank:    i + 1,
      profile: profileMap.get(row.user_id) ?? null,
    }));
    setLeaderboard(merged);
  }

  // ── Cohort sort ──────────────────────────────────────────────────────────────
  function handleSort(field) {
    if (sortField === field) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortField(field);
      setSortDir('desc');
    }
  }

  const sortedCohort = [...cohortRows].sort((a, b) => {
    const av = a[sortField] ?? 0;
    const bv = b[sortField] ?? 0;
    if (typeof av === 'string') return sortDir === 'asc' ? av.localeCompare(bv) : bv.localeCompare(av);
    return sortDir === 'asc' ? av - bv : bv - av;
  });

  // ── Guards ───────────────────────────────────────────────────────────────────
  if (roleLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600" />
      </div>
    );
  }

  if (!isSuperAdmin) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Alert className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>Super Admin access required.</AlertDescription>
        </Alert>
      </div>
    );
  }

  // ── Render ───────────────────────────────────────────────────────────────────
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-10">

      {/* Page header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Shield className="h-6 w-6 text-purple-600" />
            Super Admin Analytics
          </h1>
          <p className="text-sm text-gray-500 mt-1">Platform-wide health, cohort performance, and creator activity</p>
        </div>
        <Link
          to="/super-admin"
          className="text-sm text-gray-500 hover:text-gray-700 underline underline-offset-2"
        >
          ← Back to Dashboard
        </Link>
      </div>

      {/* ── Section 1: Header stat strip ─────────────────────────────────────── */}
      {isLoading ? (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="bg-white rounded-lg border border-gray-200 p-5 animate-pulse">
              <div className="h-3 w-24 bg-gray-200 rounded mb-3" />
              <div className="h-8 w-16 bg-gray-200 rounded" />
            </div>
          ))}
        </div>
      ) : headerError ? (
        <Alert>
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>Header stats unavailable: {headerError}</AlertDescription>
        </Alert>
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={<Users className="h-5 w-5 text-blue-600" />}
            label="Total Users"
            value={headerStats?.total_users ?? 0}
            bg="bg-blue-50"
          />
          <StatCard
            icon={<TrendingUp className="h-5 w-5 text-green-600" />}
            label="Content Creators"
            value={headerStats?.content_creator_count ?? 0}
            bg="bg-green-50"
          />
          <StatCard
            icon={<BarChart3 className="h-5 w-5 text-purple-600" />}
            label="Reviews This Month"
            value={Number(headerStats?.reviews_this_month ?? 0).toLocaleString()}
            bg="bg-purple-50"
          />
          <StatCard
            icon={<GraduationCap className="h-5 w-5 text-amber-600" />}
            label="Active Courses"
            value={headerStats?.active_courses ?? 0}
            bg="bg-amber-50"
          />
        </div>
      )}

      {/* ── Section 2: Course Cohort Comparison ──────────────────────────────── */}
      <div>
        <h2 className="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <GraduationCap className="h-5 w-5 text-gray-500" />
          Course Cohort Comparison
        </h2>
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-6 space-y-3">
                {[...Array(4)].map((_, i) => (
                  <div key={i} className="h-10 bg-gray-100 rounded animate-pulse" />
                ))}
              </div>
            ) : cohortError ? (
              <div className="p-6">
                <Alert>
                  <AlertCircle className="h-4 w-4" />
                  <AlertDescription>Cohort data unavailable: {cohortError}</AlertDescription>
                </Alert>
              </div>
            ) : sortedCohort.length === 0 ? (
              <p className="p-6 text-sm text-gray-500">No active courses found.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50 border-b">
                    <tr>
                      <SortTh label="Course"                  field="course_level"            sortField={sortField} sortDir={sortDir} onSort={handleSort} />
                      <SortTh label="Students"                field="student_count"           sortField={sortField} sortDir={sortDir} onSort={handleSort} />
                      <SortTh label="Published Items"         field="published_items"         sortField={sortField} sortDir={sortDir} onSort={handleSort} />
                      <SortTh label="Reviews This Week"       field="reviews_this_week"       sortField={sortField} sortDir={sortDir} onSort={handleSort} />
                      <SortTh label="Avg Reviews / Student"   field="avg_reviews_per_student" sortField={sortField} sortDir={sortDir} onSort={handleSort} />
                      <SortTh label="7-Day Retention"         field="retention_rate"          sortField={sortField} sortDir={sortDir} onSort={handleSort} />
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {sortedCohort.map((row) => {
                      const zeroActivity = Number(row.reviews_this_week) === 0;
                      return (
                        <tr
                          key={row.course_level}
                          className={zeroActivity ? 'bg-amber-50' : 'hover:bg-gray-50'}
                        >
                          <td className="px-4 py-3 text-sm font-medium text-gray-900">
                            {row.course_level}
                            {zeroActivity && (
                              <span className="ml-2 text-xs text-amber-600 font-normal">no reviews this week</span>
                            )}
                          </td>
                          <td className="px-4 py-3 text-sm text-gray-700">{Number(row.student_count).toLocaleString()}</td>
                          <td className="px-4 py-3 text-sm text-gray-700">{Number(row.published_items).toLocaleString()}</td>
                          <td className="px-4 py-3 text-sm text-gray-700">{Number(row.reviews_this_week).toLocaleString()}</td>
                          <td className="px-4 py-3 text-sm text-gray-700">{Number(row.avg_reviews_per_student).toFixed(1)}</td>
                          <td className="px-4 py-3 text-sm text-gray-700">
                            {row.retention_rate != null
                              ? `${(Number(row.retention_rate) * 100).toFixed(0)}%`
                              : '—'}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
        <p className="text-xs text-gray-400 mt-2">
          Amber rows = zero reviews this week. Click column headers to sort.
          Retention = new students this week who also reviewed ÷ new students this week.
        </p>
      </div>

      {/* ── Section 3: Creator Leaderboard ───────────────────────────────────── */}
      <div>
        <h2 className="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <Trophy className="h-5 w-5 text-gray-500" />
          Creator Leaderboard
          <span className="text-sm font-normal text-gray-400">(top 20 by published items)</span>
        </h2>
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-6 space-y-3">
                {[...Array(5)].map((_, i) => (
                  <div key={i} className="h-10 bg-gray-100 rounded animate-pulse" />
                ))}
              </div>
            ) : leaderboardError ? (
              <div className="p-6">
                <Alert>
                  <AlertCircle className="h-4 w-4" />
                  <AlertDescription>Leaderboard unavailable: {leaderboardError}</AlertDescription>
                </Alert>
              </div>
            ) : leaderboard.length === 0 ? (
              <p className="p-6 text-sm text-gray-500">No public content published yet.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50 border-b">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-12">Rank</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Creator</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Course</th>
                      <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Items Published</th>
                      <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Students Reached</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {leaderboard.map((row) => (
                      <tr key={row.user_id} className="hover:bg-gray-50">
                        <td className="px-4 py-3">
                          <span className={`text-sm font-bold ${row.rank <= 3 ? 'text-amber-500' : 'text-gray-400'}`}>
                            #{row.rank}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-sm font-medium text-gray-900">
                          {row.profile?.full_name ?? 'Unknown'}
                        </td>
                        <td className="px-4 py-3">
                          <RoleBadge role={row.profile?.role} />
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-500">
                          {row.profile?.course_level ?? '—'}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-700 text-right font-medium">
                          {Number(row.published_items).toLocaleString()}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-700 text-right">
                          {Number(row.students_reached).toLocaleString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* ── Section 4: Platform Activity Heatmap ─────────────────────────────── */}
      <div>
        <h2 className="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <BarChart3 className="h-5 w-5 text-gray-500" />
          Platform Activity Heatmap
          <span className="text-sm font-normal text-gray-400">(all users, last 12 months)</span>
        </h2>
        <PlatformHeatmap />
      </div>

    </div>
  );
}

// ─── Shared stat card ─────────────────────────────────────────────────────────
function StatCard({ icon, label, value, bg }) {
  return (
    <Card>
      <CardContent className="p-5">
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-lg ${bg}`}>{icon}</div>
          <div>
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{label}</p>
            <p className="text-2xl font-bold text-gray-900 leading-tight">{value}</p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
