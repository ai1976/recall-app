import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';

// ─── Color scale ────────────────────────────────────────────────────────────
// Single-hue navy ramp — magnitude encoding, not a status colour (green now
// carries the "mastered" semantic elsewhere on this page). Sprint 6.5.
//
// Sprint 8.8.5b (bug #1): a day is shaded by whichever of its two signals is stronger —
// card reviews OR logged study time (manual / study-mode / practice sessions). Offline study
// with zero card reviews used to leave the cell grey. Each signal is mapped to a 0–4 level on
// its own scale, then the higher level wins, so the two units never get added together.
// level: -1 = future, 0 = no activity, 1–4 = increasing intensity.
const LEVEL_CLASS = ['bg-rv-bg-2', 'bg-rv-navy/20', 'bg-rv-navy/40', 'bg-rv-navy/70', 'bg-rv-navy'];
const getColor = (level) => (level < 0 ? 'bg-transparent' : LEVEL_CLASS[level]);

const reviewLevel = (count) => {
  if (count <= 0)  return 0;
  if (count <= 3)  return 1;
  if (count <= 7)  return 2;
  if (count <= 14) return 3;
  return 4;
};

const studyLevel = (seconds) => {
  const min = seconds / 60;
  if (min <= 0)   return 0;
  if (min <= 30)  return 1;
  if (min <= 60)  return 2;
  if (min <= 120) return 3;
  return 4;
};

const formatStudyTime = (seconds) => {
  const totalMin = Math.round(seconds / 60);
  if (totalMin < 60) return `${totalMin}m`;
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return m ? `${h}h ${m}m` : `${h}h`;
};

const dayTitle = (day) => {
  if (day.level < 0) return '';
  const parts = [];
  if (day.reviews > 0) parts.push(`${day.reviews} review${day.reviews !== 1 ? 's' : ''}`);
  if (day.seconds > 0) parts.push(`${formatStudyTime(day.seconds)} study time`);
  return `${day.dateStr}: ${parts.length ? parts.join(' · ') : 'no activity'}`;
};

// ─── Build 13-week grid (Sun→Sat columns, today in last column) ─────────────
const buildGrid = (heatmapData) => {
  // study_seconds is absent if the v1 RPC is still deployed — treat as 0, never crash.
  const dayMap = new Map(heatmapData.map((d) => [d.review_date, {
    reviews: d.review_count ?? 0,
    seconds: d.study_seconds ?? 0,
  }]));

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
      const activity = dayMap.get(dateStr) ?? { reviews: 0, seconds: 0 };
      days.push({
        dateStr,
        reviews: activity.reviews,
        seconds: activity.seconds,
        level: isFuture ? -1 : Math.max(reviewLevel(activity.reviews), studyLevel(activity.seconds)),
      });
    }
    weeks.push(days);
  }
  return weeks;
};

// ─── Month labels above the grid ────────────────────────────────────────────
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const buildMonthLabels = (weeks) => {
  return weeks.map((week) => {
    const firstReal = week.find((d) => d.level >= 0);
    if (!firstReal) return null;
    const d = new Date(firstReal.dateStr);
    // Show month label only on the first week that contains the 1st of the month
    const weekDates = week.filter((x) => x.level >= 0).map((x) => new Date(x.dateStr));
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
      <div className="bg-rv-bg-1 rounded-lg border border-rv-border p-4 animate-pulse">
        <div className="h-4 w-32 bg-rv-bg-2 rounded mb-3" />
        <div className="h-20 bg-rv-bg-2 rounded" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-rv-bg-1 rounded-lg border border-rv-border p-4 text-sm text-red-500">
        Could not load heatmap.
      </div>
    );
  }

  const weeks        = buildGrid(heatmapData);
  const monthLabels  = buildMonthLabels(weeks);
  const totalDays    = heatmapData.length;           // days with ≥1 review or logged study session
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
    <div className="bg-rv-bg-1 rounded-lg border border-rv-border p-4 sm:p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-rv-ink-600" title="Shaded by card reviews or logged study time, whichever is higher">Study Activity — Last 90 Days</h3>
        <span className="text-xs text-rv-ink-400">
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
              className="h-3 w-3 flex items-center justify-center text-[9px] text-rv-ink-400 leading-none"
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
                <span className="text-[9px] text-rv-ink-400 leading-none">{monthLabels[wi]}</span>
              )}
            </div>
            {/* Day cells */}
            {week.map((day, di) => (
              <div
                key={di}
                title={dayTitle(day)}
                className={`h-3 w-3 rounded-[2px] ${getColor(day.level)}`}
              />
            ))}
          </div>
        ))}
      </div>

      {/* Legend */}
      <div className="flex items-center gap-1.5 mt-3 justify-end">
        <span className="text-[10px] text-rv-ink-400">Less</span>
        {[0, 1, 2, 3, 4].map((n) => (
          <div key={n} className={`h-3 w-3 rounded-[2px] ${getColor(n)}`} />
        ))}
        <span className="text-[10px] text-rv-ink-400">More</span>
      </div>
    </div>
  );
}
