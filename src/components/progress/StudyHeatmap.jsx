import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';

// ─── Color scale ────────────────────────────────────────────────────────────
const getColor = (count) => {
  if (count < 0)  return 'bg-transparent';             // future date
  if (count === 0) return 'bg-gray-100';
  if (count <= 3)  return 'bg-green-200';
  if (count <= 7)  return 'bg-green-400';
  if (count <= 14) return 'bg-green-600';
  return 'bg-green-800';
};

// ─── Build 13-week grid (Sun→Sat columns, today in last column) ─────────────
const buildGrid = (heatmapData) => {
  const countMap = new Map(heatmapData.map((d) => [d.review_date, d.review_count]));

  const today = new Date();
  // Start of the first column = Sunday 12 weeks before last Sunday
  const lastSunday = new Date(today);
  lastSunday.setDate(today.getDate() - today.getDay());
  const firstSunday = new Date(lastSunday);
  firstSunday.setDate(lastSunday.getDate() - 12 * 7);

  const weeks = [];
  for (let w = 0; w < 13; w++) {
    const days = [];
    for (let d = 0; d < 7; d++) {
      const date = new Date(firstSunday);
      date.setDate(firstSunday.getDate() + w * 7 + d);
      const isFuture = date > today;
      const dateStr  = date.toLocaleDateString('en-CA'); // YYYY-MM-DD
      days.push({ dateStr, count: isFuture ? -1 : (countMap.get(dateStr) ?? 0) });
    }
    weeks.push(days);
  }
  return weeks;
};

// ─── Month labels above the grid ────────────────────────────────────────────
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const buildMonthLabels = (weeks) => {
  return weeks.map((week) => {
    const firstReal = week.find((d) => d.count >= 0);
    if (!firstReal) return null;
    const d = new Date(firstReal.dateStr);
    // Show month label only on the first week that contains the 1st of the month
    const weekDates = week.filter((x) => x.count >= 0).map((x) => new Date(x.dateStr));
    const hasFirst  = weekDates.some((x) => x.getDate() === 1);
    return hasFirst ? MONTHS[d.getMonth()] : null;
  });
};

// ─── Day-of-week sidebar ─────────────────────────────────────────────────────
const DOW_LABELS = ['S','M','T','W','T','F','S'];

export default function StudyHeatmap({ userId }) {
  const [heatmapData, setHeatmapData] = useState([]);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState(null);

  useEffect(() => {
    if (!userId) return;
    const load = async () => {
      setLoading(true);
      const { data, error: rpcError } = await supabase.rpc('get_study_heatmap', {
        p_user_id: userId,
        p_days: 90,
      });
      if (rpcError) {
        setError(rpcError.message);
      } else {
        setHeatmapData(data || []);
      }
      setLoading(false);
    };
    load();
  }, [userId]);

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-4 animate-pulse">
        <div className="h-4 w-32 bg-gray-200 rounded mb-3" />
        <div className="h-20 bg-gray-100 rounded" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-4 text-sm text-red-500">
        Could not load heatmap.
      </div>
    );
  }

  const weeks        = buildGrid(heatmapData);
  const monthLabels  = buildMonthLabels(weeks);
  const totalDays    = heatmapData.length;           // days with ≥1 review
  const longestStreak = (() => {
    // compute longest streak from heatmap data for the summary line
    if (!heatmapData.length) return 0;
    const dates = heatmapData.map((d) => d.review_date).sort();
    let max = 1, cur = 1;
    for (let i = 1; i < dates.length; i++) {
      const prev = new Date(dates[i - 1]);
      const curr = new Date(dates[i]);
      prev.setDate(prev.getDate() + 1);
      if (prev.toLocaleDateString('en-CA') === curr.toLocaleDateString('en-CA')) {
        cur++;
        max = Math.max(max, cur);
      } else {
        cur = 1;
      }
    }
    return max;
  })();

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4 sm:p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-gray-700">Study Activity — Last 90 Days</h3>
        <span className="text-xs text-gray-400">
          {totalDays} active {totalDays === 1 ? 'day' : 'days'}
          {longestStreak > 1 && ` · ${longestStreak}-day best streak`}
        </span>
      </div>

      {/* Grid */}
      <div className="flex gap-1">
        {/* Day-of-week labels */}
        <div className="flex flex-col gap-0.5 mr-1">
          {/* Spacer for month labels row */}
          <div className="h-4" />
          {DOW_LABELS.map((label, i) => (
            <div
              key={i}
              className="h-3 w-3 flex items-center justify-center text-[9px] text-gray-400 leading-none"
            >
              {i % 2 === 1 ? label : ''}
            </div>
          ))}
        </div>

        {/* Week columns */}
        {weeks.map((week, wi) => (
          <div key={wi} className="flex flex-col gap-0.5">
            {/* Month label */}
            <div className="h-4 flex items-end">
              {monthLabels[wi] && (
                <span className="text-[9px] text-gray-400 leading-none">{monthLabels[wi]}</span>
              )}
            </div>
            {/* Day cells */}
            {week.map((day, di) => (
              <div
                key={di}
                title={day.count >= 0 ? `${day.dateStr}: ${day.count} review${day.count !== 1 ? 's' : ''}` : ''}
                className={`h-3 w-3 rounded-[2px] ${getColor(day.count)}`}
              />
            ))}
          </div>
        ))}
      </div>

      {/* Legend */}
      <div className="flex items-center gap-1.5 mt-3 justify-end">
        <span className="text-[10px] text-gray-400">Less</span>
        {[0, 2, 5, 10, 15].map((n) => (
          <div key={n} className={`h-3 w-3 rounded-[2px] ${getColor(n)}`} />
        ))}
        <span className="text-[10px] text-gray-400">More</span>
      </div>
    </div>
  );
}
