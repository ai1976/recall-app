import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';

// ─── Color scale (platform-wide counts are higher than per-user counts) ──────
const getColor = (count) => {
  if (count < 0)   return 'bg-transparent';   // future date
  if (count === 0) return 'bg-gray-100';
  if (count <= 10) return 'bg-blue-200';
  if (count <= 30) return 'bg-blue-400';
  if (count <= 70) return 'bg-blue-600';
  return 'bg-blue-800';
};

// ─── Build 52-week grid (Sun→Sat columns, today in last column) ──────────────
const buildGrid = (heatmapData) => {
  const countMap = new Map(heatmapData.map((d) => [d.review_date, Number(d.review_count)]));

  const today      = new Date();
  const lastSunday = new Date(today);
  lastSunday.setDate(today.getDate() - today.getDay());
  const firstSunday = new Date(lastSunday);
  firstSunday.setDate(lastSunday.getDate() - 51 * 7);

  const weeks = [];
  for (let w = 0; w < 52; w++) {
    const days = [];
    for (let d = 0; d < 7; d++) {
      const date    = new Date(firstSunday);
      date.setDate(firstSunday.getDate() + w * 7 + d);
      const isFuture = date > today;
      const dateStr  = date.toLocaleDateString('en-CA'); // YYYY-MM-DD, no timezone corruption
      days.push({ dateStr, count: isFuture ? -1 : (countMap.get(dateStr) ?? 0) });
    }
    weeks.push(days);
  }
  return weeks;
};

// ─── Month labels above the grid ─────────────────────────────────────────────
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const buildMonthLabels = (weeks) => {
  return weeks.map((week) => {
    const firstReal = week.find((d) => d.count >= 0);
    if (!firstReal) return null;
    const d         = new Date(firstReal.dateStr);
    const weekDates = week.filter((x) => x.count >= 0).map((x) => new Date(x.dateStr));
    const hasFirst  = weekDates.some((x) => x.getDate() === 1);
    return hasFirst ? MONTHS[d.getMonth()] : null;
  });
};

const DOW_LABELS = ['S','M','T','W','T','F','S'];

export default function PlatformHeatmap() {
  const [heatmapData, setHeatmapData] = useState([]);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState(null);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const { data, error: rpcError } = await supabase.rpc('get_platform_heatmap', {
        p_days: 365,
      });
      if (rpcError) {
        setError(rpcError.message);
      } else {
        setHeatmapData(data || []);
      }
      setLoading(false);
    };
    load();
  }, []);

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-4 animate-pulse">
        <div className="h-4 w-48 bg-gray-200 rounded mb-3" />
        <div className="h-24 bg-gray-100 rounded" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-4 text-sm text-red-500">
        Could not load platform heatmap.
      </div>
    );
  }

  const weeks       = buildGrid(heatmapData);
  const monthLabels = buildMonthLabels(weeks);
  const totalReviews = heatmapData.reduce((sum, d) => sum + Number(d.review_count), 0);
  const activeDays   = heatmapData.filter((d) => Number(d.review_count) > 0).length;

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4 sm:p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-gray-700">Platform Activity — Last 12 Months</h3>
        <span className="text-xs text-gray-400">
          {totalReviews.toLocaleString()} total reviews · {activeDays} active {activeDays === 1 ? 'day' : 'days'}
        </span>
      </div>

      {/* Scrollable wrapper for narrow screens */}
      <div className="overflow-x-auto">
        <div className="flex gap-0.5 min-w-max">
          {/* Day-of-week labels */}
          <div className="flex flex-col gap-0.5 mr-1">
            <div className="h-4" /> {/* spacer for month labels row */}
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
      </div>

      {/* Legend */}
      <div className="flex items-center gap-1.5 mt-3 justify-end">
        <span className="text-[10px] text-gray-400">Less</span>
        {[0, 5, 20, 50, 80].map((n) => (
          <div key={n} className={`h-3 w-3 rounded-[2px] ${getColor(n)}`} />
        ))}
        <span className="text-[10px] text-gray-400">More</span>
      </div>
    </div>
  );
}
