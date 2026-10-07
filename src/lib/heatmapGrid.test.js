// Tests for the heatmap date and grid helpers (T-001 brief C v6, C-7.4 and C-7.5 item 6): calendar-date strings are handled as LOCAL dates built from parts,
// the grid and window follow the RPC's local today - 90 .. local today, and no UTC parsing or toISOString() is left in the heatmap code.
import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ymd, parseYmd, buildGrid, buildMonthLabels, longestStreakOf, dayText, formatStudyTime } from '@/lib/heatmapGrid';

const here = path.dirname(fileURLToPath(import.meta.url));

describe('calendar dates are local, never UTC', () => {
  it('ymd and parseYmd round-trip for every day of a year, including DST changes', () => {
    for (let d = new Date(2026, 0, 1); d.getFullYear() === 2026; d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) {
      const s = ymd(d);
      const back = parseYmd(s);
      expect(ymd(back)).toBe(s);
      expect(back.getHours()).toBe(0);
    }
  });

  it('a late-evening local time keeps its own calendar date (the failure of toISOString() west of UTC and early morning east of it)', () => {
    expect(ymd(new Date(2026, 9, 7, 23, 59, 59))).toBe('2026-10-07');
    expect(ymd(new Date(2026, 9, 7, 0, 0, 1))).toBe('2026-10-07');
  });

  it('parseYmd builds the date from its parts: month and day are exactly those of the string', () => {
    const d = parseYmd('2026-03-01');
    expect([d.getFullYear(), d.getMonth(), d.getDate()]).toEqual([2026, 2, 1]);
  });

  it('the heatmap code contains no toISOString() and no Date constructed from a date string', () => {
    for (const f of ['../components/progress/StudyHeatmap.jsx', 'heatmapGrid.js']) {
      const code = fs.readFileSync(path.join(here, f), 'utf8').replace(/\/\/.*$/gm, '');
      expect(code).not.toMatch(/toISOString/);
      expect(code).not.toMatch(/new Date\(\s*['"`]/);
      expect(code).not.toMatch(/Date\.parse/);
    }
  });
});

describe('buildGrid', () => {
  const today = new Date(2026, 9, 7, 15, 0, 0); // Wed 7 Oct 2026, local
  const rows = [
    { review_date: '2026-10-07', review_count: 5, in_app_seconds: 600, offline_seconds: 1800, study_seconds: 2400, other_seconds: 0 },
    { review_date: '2026-10-06', review_count: 0, in_app_seconds: 0, offline_seconds: 5400, study_seconds: 5400, other_seconds: 0 },
    { review_date: '2026-07-09', review_count: 20, in_app_seconds: 0, offline_seconds: 0, study_seconds: 0, other_seconds: 0 }, // exactly today - 90
  ];
  const weeks = buildGrid(rows, today);
  const flat = weeks.flat();
  const real = flat.filter((d) => d.level >= 0);

  it('is whole weeks of 7 days, Sunday first, covers the window, and the last drawn cell is today', () => {
    expect(weeks).toHaveLength(14); // Thu 9 Jul is in the week that starts Sun 5 Jul; today's week ends Sat 10 Oct
    weeks.forEach((w) => expect(w).toHaveLength(7));
    expect(real[real.length - 1].dateStr).toBe('2026-10-07');
    expect(parseYmd(weeks[0][0].dateStr).getDay()).toBe(0);
  });

  it('draws only the window local today - 90 .. local today (91 days): older cells and future cells are not drawn', () => {
    expect(real).toHaveLength(91);
    expect(real[0].dateStr).toBe('2026-07-09');
    expect(flat.filter((d) => d.level < 0 && d.dateStr > '2026-10-07').length).toBe(3); // Thu, Fri, Sat of this week
    expect(flat.filter((d) => d.level < 0 && d.dateStr < '2026-07-09').length).toBeGreaterThan(0);
  });

  it('carries in-app, offline, total and reviews per day and shades by the stronger signal (offline-only study is not grey)', () => {
    const t = real.find((d) => d.dateStr === '2026-10-07');
    expect([t.reviews, t.inApp, t.offline, t.seconds]).toEqual([5, 600, 1800, 2400]);
    const offlineOnly = real.find((d) => d.dateStr === '2026-10-06');
    expect(offlineOnly.reviews).toBe(0);
    expect(offlineOnly.level).toBeGreaterThanOrEqual(2); // 90 minutes of logged study
    expect(real.find((d) => d.dateStr === '2026-07-09').level).toBe(4); // 20 reviews
    expect(real.find((d) => d.dateStr === '2026-10-01').hasActivity).toBe(false);
  });

  it('copes with missing fields and with no rows', () => {
    const empty = buildGrid(null, today).flat().filter((d) => d.level >= 0);
    expect(empty).toHaveLength(91);
    expect(empty.every((d) => d.level === 0 && !d.hasActivity)).toBe(true);
    const sparse = buildGrid([{ review_date: '2026-10-07' }], today).flat().find((d) => d.dateStr === '2026-10-07');
    expect([sparse.reviews, sparse.seconds]).toEqual([0, 0]);
  });
});

describe('labels, streak and wording', () => {
  it('month labels appear once, on the first drawn week that contains the 1st', () => {
    const labels = buildMonthLabels(buildGrid([], new Date(2026, 9, 7)));
    const shown = labels.filter(Boolean);
    expect(shown).toEqual(['Aug', 'Sep', 'Oct']);
  });

  it('longest streak counts consecutive calendar days across month ends', () => {
    expect(longestStreakOf([])).toBe(0);
    expect(longestStreakOf(['2026-09-29', '2026-09-30', '2026-10-01', '2026-10-03'])).toBe(3);
    expect(longestStreakOf(['2026-10-05'])).toBe(1);
  });

  it('the accessible text names the date, in-app, offline, total and reviews in words (not colour alone)', () => {
    const text = dayText({ dateStr: '2026-10-07', hasActivity: true, inApp: 600, offline: 1800, seconds: 2400, reviews: 5 });
    expect(text).toMatch(/in-app 10m/);
    expect(text).toMatch(/offline 30m/);
    expect(text).toMatch(/total study time 40m/);
    expect(text).toMatch(/5 reviews/);
    expect(dayText({ dateStr: '2026-10-07', hasActivity: false, inApp: 0, offline: 0, seconds: 0, reviews: 0 })).toMatch(/no activity/);
    expect(dayText({ dateStr: '2026-10-07', hasActivity: true, inApp: 0, offline: 0, seconds: 60, reviews: 1 })).toMatch(/1 review(?!s)/);
  });

  it('formats study time', () => {
    expect([formatStudyTime(0), formatStudyTime(20), formatStudyTime(90), formatStudyTime(3600), formatStudyTime(3900)]).toEqual(['0m', '<1m', '2m', '1h', '1h 5m']);
  });
});
