// T-001 brief C v6, points 7 (C-7.1 to C-7.4). The heatmap component reads `get_study_heatmap_split`, which returns per local calendar date: review_count, in_app_seconds
// (study_mode + practice_mode), offline_seconds (manual), study_seconds (all sources) and other_seconds (always 0). Dates are calendar-date strings
// (YYYY-MM-DD). This module never calls `new Date('YYYY-MM-DD')` (that parses as UTC and shifts the day for anyone west of UTC) and never `toISOString()`: a date
// string is split into year, month and day and turned into a LOCAL date, and a cell is keyed by its `YYYY-MM-DD` string built from local date parts.


const WINDOW_DAYS = 90;

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

export const formatStudyTime = (seconds) => {
  if (!seconds || seconds <= 0) return '0m';
  const totalMin = Math.round(seconds / 60);
  if (totalMin < 1) return '<1m';
  if (totalMin < 60) return `${totalMin}m`;
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return m ? `${h}h ${m}m` : `${h}h`;
};

// ─── Calendar-date helpers (local dates only; no UTC parsing) ───────────────
const pad2 = (n) => String(n).padStart(2, '0');

/** Local date -> 'YYYY-MM-DD' from its local year, month and day. */
export const ymd = (date) => `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;

/** 'YYYY-MM-DD' -> local Date at local midnight (split into parts; never the UTC-parsing Date(string) form). */
export const parseYmd = (str) => {
  const [y, m, d] = String(str).split('-').map(Number);
  return new Date(y, m - 1, d);
};

export const addDays = (date, n) => {
  const next = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  next.setDate(next.getDate() + n);
  return next;
};

export const longDate = (dateStr) => parseYmd(dateStr).toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });

const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`;

/** The text of a cell, for the accessible name and the card: date, in-app, offline, total, reviews (never colour alone). */
export const dayText = (day) => {
  const when = longDate(day.dateStr);
  if (!day.hasActivity) return `${when}: no activity`;
  return `${when}: in-app ${formatStudyTime(day.inApp)}, offline ${formatStudyTime(day.offline)}, total study time ${formatStudyTime(day.seconds)}, ${plural(day.reviews, 'review')}`;
};

// ─── Build the week grid (Sun→Sat columns, today in the last column) ─────────
export const buildGrid = (rows, today = new Date(), windowDays = WINDOW_DAYS) => {
  const dayMap = new Map((rows || []).map((d) => [d.review_date, {
    reviews: d.review_count ?? 0,
    inApp: d.in_app_seconds ?? 0,
    offline: d.offline_seconds ?? 0,
    seconds: d.study_seconds ?? 0,
  }]));

  const todayStr = ymd(today);
  const windowStart = ymd(addDays(today, -windowDays)); // the RPC returns local today - 90 .. local today; older cells are not covered, so they are not drawn
  // The grid always covers the whole window: it starts on the Sunday on or before (today - windowDays) and ends with the week that contains today (13 or 14 weeks).
  const windowStartDate = addDays(today, -windowDays);
  const firstSunday = addDays(windowStartDate, -windowStartDate.getDay());

  const weeks = [];
  for (let w = 0; ymd(addDays(firstSunday, w * 7)) <= todayStr; w++) {
    const days = [];
    for (let d = 0; d < 7; d++) {
      const date = addDays(firstSunday, w * 7 + d);
      const dateStr = ymd(date);
      const isFuture = dateStr > todayStr; // 'YYYY-MM-DD' strings compare as calendar dates
      const a = dayMap.get(dateStr) ?? { reviews: 0, inApp: 0, offline: 0, seconds: 0 };
      days.push({
        dateStr,
        reviews: a.reviews,
        inApp: a.inApp,
        offline: a.offline,
        seconds: a.seconds,
        hasActivity: a.reviews > 0 || a.seconds > 0,
        level: isFuture || dateStr < windowStart ? -1 : Math.max(reviewLevel(a.reviews), studyLevel(a.seconds)),
      });
    }
    weeks.push(days);
  }
  return weeks;
};

// ─── Month labels above the grid ────────────────────────────────────────────
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
export const buildMonthLabels = (weeks) => weeks.map((week) => {
  const real = week.filter((d) => d.level >= 0).map((d) => parseYmd(d.dateStr));
  if (!real.length) return null;
  // Show the month label only on the first week that contains the 1st of the month
  const first = real.find((x) => x.getDate() === 1);
  return first ? MONTHS[first.getMonth()] : null; // named after the month that starts in this week
});

/** Longest run of consecutive calendar days in a list of 'YYYY-MM-DD' strings. */
export const longestStreakOf = (dateStrs) => {
  if (!dateStrs.length) return 0;
  const dates = [...dateStrs].sort();
  let max = 1;
  let cur = 1;
  for (let i = 1; i < dates.length; i++) {
    if (ymd(addDays(parseYmd(dates[i - 1]), 1)) === dates[i]) {
      cur++;
      max = Math.max(max, cur);
    } else {
      cur = 1;
    }
  }
  return max;
};

