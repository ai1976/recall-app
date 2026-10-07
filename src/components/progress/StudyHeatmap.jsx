import { useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { formatStudyTime, dayText, longDate, buildGrid, buildMonthLabels, longestStreakOf } from '@/lib/heatmapGrid';

// T-001 brief C v6, point 7 (C-7.1 to C-7.4). Reads `get_study_heatmap_split` (per local calendar date: review_count, in_app_seconds, offline_seconds,
// study_seconds, other_seconds). The date handling and the grid live in src/lib/heatmapGrid.js (no `new Date('YYYY-MM-DD')`, no `toISOString()` anywhere).

// ─── Color scale ───
// Single-hue navy ramp — magnitude encoding, not a status colour (green now carries the "mastered" semantic elsewhere on this page). Sprint 6.5.
// Sprint 8.8.5b (bug #1): a day is shaded by whichever of its two signals is stronger, card reviews OR logged study time (see lib/heatmapGrid.js).
// level: -1 = future or outside the window, 0 = no activity, 1–4 = increasing intensity.
const LEVEL_CLASS = ['bg-rv-bg-2', 'bg-rv-navy/20', 'bg-rv-navy/40', 'bg-rv-navy/70', 'bg-rv-navy'];
const getColor = (level) => (level < 0 ? 'bg-transparent' : LEVEL_CLASS[level]);

// ─── Day-of-week sidebar ─────────────────────────────────────────────────────
const DOW_LABELS = ['S','M','T','W','T','F','S'];

const CARD_WIDTH = 176; // px; matches w-44

export default function StudyHeatmap({ userId }) {
  const [heatmapData, setHeatmapData] = useState([]);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState(null);

  // Card state: hover and keyboard focus show it; tap, Enter or Space pins it.
  // Each is null or { date, pos } where pos is the card's position, measured in the event handler that opened it.
  const [hover, setHover]   = useState(null);
  const [focusCard, setFocusCard] = useState(null);
  const [pinned, setPinned] = useState(null);
  const [rovingDate, setRovingDate] = useState(null); // the one cell in the tab order

  const rootRef  = useRef(null);
  const cellRefs = useRef(new Map());

  useEffect(() => {
    if (!userId) return undefined;
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      const { data, error: rpcError } = await supabase.rpc('get_study_heatmap_split', {
        p_user_id: userId,
        p_days: 90,
      });
      if (cancelled) return;
      if (rpcError) {
        setError(rpcError.message);
      } else {
        setError(null);
        setHeatmapData(data || []);
      }
      setLoading(false);
    };
    load();
    return () => { cancelled = true; };
  }, [userId]);

  const closeAll = useCallback(() => {
    setHover(null);
    setFocusCard(null);
    setPinned(null);
  }, []);

  // A tap or click outside the heatmap closes a pinned card (a touch tap on a button does not move focus in every browser).
  useEffect(() => {
    if (!pinned) return undefined;
    const onPointerDown = (e) => { if (rootRef.current && !rootRef.current.contains(e.target)) closeAll(); };
    document.addEventListener('pointerdown', onPointerDown);
    return () => document.removeEventListener('pointerdown', onPointerDown);
  }, [pinned, closeAll]);

  // Place the card under a cell, kept inside the heatmap box (measured when the card is opened, not in an effect).
  const place = (dateStr) => {
    const cell = cellRefs.current.get(dateStr);
    const root = rootRef.current;
    if (!cell || !root) return null;
    const c = cell.getBoundingClientRect();
    const r = root.getBoundingClientRect();
    const center = c.left - r.left + c.width / 2;
    return { left: Math.max(0, Math.min(center - CARD_WIDTH / 2, Math.max(0, r.width - CARD_WIDTH))), top: c.bottom - r.top + 6 };
  };

  const activeCard = pinned ?? hover ?? focusCard;
  const activeDate = activeCard?.date ?? null;

  const weeks = buildGrid(heatmapData);
  const flat  = weeks.flat();
  const real  = flat.filter((d) => d.level >= 0);
  const todayDate = real.length ? real[real.length - 1].dateStr : null;
  const tabDate = rovingDate && real.some((d) => d.dateStr === rovingDate) ? rovingDate : todayDate;

  const moveFocus = (fromDate, key) => {
    const idx = real.findIndex((d) => d.dateStr === fromDate);
    if (idx < 0) return;
    let next = idx;
    if (key === 'ArrowUp') next = idx - 1;
    else if (key === 'ArrowDown') next = idx + 1;
    else if (key === 'ArrowLeft') next = idx - 7;
    else if (key === 'ArrowRight') next = idx + 7;
    else if (key === 'Home') next = 0;
    else if (key === 'End') next = real.length - 1;
    else return;
    next = Math.max(0, Math.min(real.length - 1, next));
    const target = real[next].dateStr;
    setRovingDate(target);
    cellRefs.current.get(target)?.focus();
  };

  const onCellKeyDown = (e, day) => {
    if (e.key === 'Escape') { closeAll(); return; }
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) {
      e.preventDefault();
      moveFocus(day.dateStr, e.key);
    }
  };

  // Focus leaving the whole heatmap closes the card and the pin.
  const onRootBlur = (e) => {
    if (!rootRef.current || !e.relatedTarget || !rootRef.current.contains(e.relatedTarget)) closeAll();
  };

  // A first tap pins the card; a second tap on the same day closes it (and clears hover and focus, which would otherwise keep it open).
  const togglePin = (dateStr) => {
    if (pinned?.date === dateStr) closeAll();
    else setPinned({ date: dateStr, pos: place(dateStr) });
  };

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

  const monthLabels   = buildMonthLabels(weeks);
  const activeDays    = heatmapData.map((d) => d.review_date);
  const totalDays     = activeDays.length;           // days with ≥1 review or logged study session
  const longestStreak = longestStreakOf(activeDays);
  const activeDay     = activeDate ? flat.find((d) => d.dateStr === activeDate) : null;

  return (
    <div
      ref={rootRef}
      className="relative bg-rv-bg-1 rounded-lg border border-rv-border p-4 sm:p-5"
      onBlur={onRootBlur}
      onKeyDown={(e) => { if (e.key === 'Escape') closeAll(); }}
    >
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-rv-ink-600">Study Activity — Last 90 Days</h3>
        <span className="text-xs text-rv-ink-400">
          {totalDays} active {totalDays === 1 ? 'day' : 'days'}
          {longestStreak > 1 && ` · ${longestStreak}-day best streak`}
        </span>
      </div>
      <p className="sr-only">
        Each day is a button. Shaded by card reviews or logged study time, whichever is higher. Use the arrow keys to move between days, Enter or Space to pin the
        details, Escape to close them.
      </p>

      {/* Grid */}
      <div className="flex gap-1" role="group" aria-label="Study activity by day, last 90 days">
        {/* Day-of-week labels */}
        <div className="flex flex-col gap-0.5 mr-1" aria-hidden="true">
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
            <div className="h-4 flex items-end" aria-hidden="true">
              {monthLabels[wi] && (
                <span className="text-[9px] text-rv-ink-400 leading-none">{monthLabels[wi]}</span>
              )}
            </div>
            {/* Day cells */}
            {week.map((day) => (
              day.level < 0 ? (
                <div key={day.dateStr} className="h-3 w-3" aria-hidden="true" />
              ) : (
                <button
                  key={day.dateStr}
                  type="button"
                  ref={(el) => { if (el) cellRefs.current.set(day.dateStr, el); else cellRefs.current.delete(day.dateStr); }}
                  tabIndex={day.dateStr === tabDate ? 0 : -1}
                  aria-label={dayText(day)}
                  aria-pressed={pinned?.date === day.dateStr}
                  data-date={day.dateStr}
                  className={`h-3 w-3 rounded-[2px] p-0 border-0 cursor-pointer ${getColor(day.level)} focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-rv-navy`}
                  onMouseEnter={() => setHover({ date: day.dateStr, pos: place(day.dateStr) })}
                  onMouseLeave={() => setHover((cur) => (cur?.date === day.dateStr ? null : cur))}
                  onFocus={() => { setFocusCard({ date: day.dateStr, pos: place(day.dateStr) }); setRovingDate(day.dateStr); }}
                  onBlur={() => setFocusCard((cur) => (cur?.date === day.dateStr ? null : cur))}
                  onClick={() => togglePin(day.dateStr)}
                  onKeyDown={(e) => onCellKeyDown(e, day)}
                />
              )
            ))}
          </div>
        ))}
      </div>

      {/* Card: date, in-app time, offline time, total, reviews. Mirrors the cell's accessible name, so it is hidden from screen readers. */}
      {activeDay && activeCard.pos && (
        <div
          data-testid="heatmap-card"
          aria-hidden="true"
          style={{ left: activeCard.pos.left, top: activeCard.pos.top, width: CARD_WIDTH }}
          className="pointer-events-none absolute z-10 rounded-md border border-rv-border bg-rv-bg-1 p-2 text-xs shadow-md motion-safe:transition-opacity motion-safe:duration-100"
        >
          <div className="font-semibold text-rv-ink-600">{longDate(activeDay.dateStr)}{pinned?.date === activeDay.dateStr ? ' (pinned)' : ''}</div>
          {activeDay.hasActivity ? (
            <dl className="mt-1 grid grid-cols-[1fr_auto] gap-x-2 gap-y-0.5 text-rv-ink-400">
              <dt>In-app</dt><dd className="text-right text-rv-ink-600">{formatStudyTime(activeDay.inApp)}</dd>
              <dt>Offline</dt><dd className="text-right text-rv-ink-600">{formatStudyTime(activeDay.offline)}</dd>
              <dt>Total</dt><dd className="text-right text-rv-ink-600">{formatStudyTime(activeDay.seconds)}</dd>
              <dt>Reviews</dt><dd className="text-right text-rv-ink-600">{activeDay.reviews}</dd>
            </dl>
          ) : (
            <div className="mt-1 text-rv-ink-400">No activity</div>
          )}
        </div>
      )}

      {/* Legend */}
      <div className="flex items-center gap-1.5 mt-3 justify-end" aria-hidden="true">
        <span className="text-[10px] text-rv-ink-400">Less</span>
        {[0, 1, 2, 3, 4].map((n) => (
          <div key={n} className={`h-3 w-3 rounded-[2px] ${getColor(n)}`} />
        ))}
        <span className="text-[10px] text-rv-ink-400">More</span>
      </div>
    </div>
  );
}
