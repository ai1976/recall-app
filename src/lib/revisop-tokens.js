// RevisOp reskin — shared JS constants for the design-language primitives.
// Phase 6 / Sprint 6.1. Presentational only: no data fetching, no Supabase.
//
// The CSS custom properties + Tailwind keys live in src/index.css and
// tailwind.config.js (namespaced --rv-* / rv.* / rounded-rec / rounded-obj /
// font-plex / font-plex-mono / font-literata / shadow-rv). This file holds the
// non-CSS pieces the primitives share.

/**
 * REVISOP_LITERATA_ENABLED — the "trivial on/off" for the Literata reading face.
 *
 * OFF for Sprint 6.1: nothing renders with font-family Literata, so the browser
 * never fetches /fonts/literata.woff2 (an unmatched @font-face costs 0 bytes on
 * the wire). Sprint 6.4 flips this when reading bodies (note / case-study / long
 * passage) actually adopt the face — and should lazy-trigger the download only
 * when such a body mounts, not on the critical path.
 *
 * Measured cost when enabled: ~85.7 KB (woff2, Latin subset — barely
 * compresses further under gzip since woff2 is already Brotli-packed).
 */
export const REVISOP_LITERATA_ENABLED = true;

/**
 * LITERATA_MIN_CHARS — where a "reading body" begins in the study loop.
 *
 * Sprint 6.4: the only reading-length content in the front/back loop is a long
 * flashcard answer (`back_text`). A revealed answer at or above this length
 * adopts --rv-font-read (Literata); shorter Q&A stays Plex. The first long
 * answer that mounts is what triggers the (lazy, same-origin) /fonts/literata.woff2
 * fetch — it is never on the session-start critical path and never on chrome.
 */
export const LITERATA_MIN_CHARS = 320;

/**
 * isReadingBody(text) → boolean. True when a passage is long enough to render
 * in the reading face. Guarded by REVISOP_LITERATA_ENABLED so a single flag
 * flip disables the behaviour everywhere.
 * @param {string|null|undefined} text
 */
export function isReadingBody(text) {
  return (
    REVISOP_LITERATA_ENABLED &&
    typeof text === 'string' &&
    text.trim().length >= LITERATA_MIN_CHARS
  );
}

/**
 * BUCKETS — the forward-ledger scale (the signature device's x-axis).
 * Eight scheduled-load lanes from "due now" out to six-months-plus. Index 0 is
 * always "Today"/now and is the emphasized lane at every scale (micro/macro).
 */
export const REVISOP_BUCKETS = ['Today', '1d', '3d', '6d', '2w', '1mo', '3mo', '6mo+'];

/**
 * Approx day-count at the centre of each bucket — used to map a real interval
 * (days) coming back from get_srs_ladder_config / get_study_queue onto a bucket
 * index for the forward-ledger primitives. Deterministic; tweak alongside the
 * ladder config, not independently.
 */
const BUCKET_DAYS = [0, 1, 3, 6, 14, 30, 90, 180];

/**
 * bucketForDays(days) → integer 0..7. Nearest bucket for an interval in days.
 * @param {number} days
 * @returns {number} bucket index into REVISOP_BUCKETS
 */
export function bucketForDays(days) {
  if (days == null || Number.isNaN(days) || days <= 0) return 0;
  let best = 0;
  let bestGap = Infinity;
  for (let i = 0; i < BUCKET_DAYS.length; i += 1) {
    const gap = Math.abs(BUCKET_DAYS[i] - days);
    if (gap < bestGap) {
      bestGap = gap;
      best = i;
    }
  }
  return best;
}

/**
 * ledgerFromForecast(rows) → number[8]. Fold a get_due_forecast-shaped result
 * (array of { due_on / interval_days, count }) into the 8-lane forward-ledger
 * series the macro primitive renders. Anything past 6mo lands in the last lane.
 *
 * Shape-tolerant on purpose — the RPC contract is still settling; on the QA
 * route the primitives are handed a literal number[8] instead.
 * @param {Array<{interval_days?: number, days?: number, count?: number, n?: number}>} rows
 * @returns {number[]} length-8 series
 */
export function ledgerFromForecast(rows) {
  const series = [0, 0, 0, 0, 0, 0, 0, 0];
  if (!Array.isArray(rows)) return series;
  for (const r of rows) {
    const days = r.interval_days ?? r.days ?? 0;
    const count = r.count ?? r.n ?? 0;
    series[bucketForDays(days)] += count;
  }
  return series;
}
