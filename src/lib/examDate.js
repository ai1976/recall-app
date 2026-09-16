// examDate.js — Sprint 8.4
// Shared date-math/formatting for the exam-date feature (ExamDateChip,
// ExamDatePromptModal, ProfileSettings, Dashboard countdown card).
//
// profiles.exam_date / exam_month are Postgres `date` columns — Supabase
// returns them as plain 'YYYY-MM-DD' strings with no time/timezone component.
// Parsing them through `new Date(str)` and reading back local getters (or
// worse, toISOString()) risks an off-by-one-day shift depending on the
// viewer's timezone offset. Every helper here parses the Y/M/D parts directly
// and does arithmetic in UTC-anchored day counts, never through a
// timezone-local Date read.

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

function parseDateOnly(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  return { y, m, d };
}

/** Days remaining until an exact 'YYYY-MM-DD' exam_date. Can be negative if past. */
export function daysUntilExamDate(dateStr) {
  const { y, m, d } = parseDateOnly(dateStr);
  const target = Date.UTC(y, m - 1, d);
  const now = new Date();
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.round((target - today) / 86400000);
}

/** "November 2026" from a 1st-of-month 'YYYY-MM-DD' exam_month value. */
export function formatExamMonth(dateStr) {
  const { y, m } = parseDateOnly(dateStr);
  return `${MONTH_NAMES[m - 1]} ${y}`;
}

/** 'YYYY-MM-DD' for the 1st of the given month/year (month select → DB value). */
export function buildExamMonthValue(year, month1to12) {
  return `${year}-${String(month1to12).padStart(2, '0')}-01`;
}

export { MONTH_NAMES };
