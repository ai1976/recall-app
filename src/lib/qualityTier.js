// Single source of truth for "score / quality / rate -> colour tier" across the
// analytics dashboards. Replaces the copy-pasted `>=x ? green : >=y ? amber : red`
// ternaries that were duplicated (with inconsistent thresholds) in
// AdminAnalytics.jsx (QualityBadge, 0-5 scale) and SuperAdminDashboard.jsx
// (daily/weekly active-user rate, 0-100 scale).
//
// Usage:
//   qualityTier(4.2)            -> TIERS.strong   (default thresholds [4, 3], a 0-5 quality score)
//   qualityTier(72, [80, 60])   -> TIERS.ok       (0-100 rate, custom thresholds)
//
// The returned object carries every class/label variant a consumer needs:
//   .key    'strong' | 'ok' | 'weak'
//   .text   text colour for a bold number  (text-*-600)
//   .bar    fill colour for a progress bar  (bg-*-500)
//   .badge  full pill classes               (text-*-700 bg-*-50 border border-*-200)
//   .emoji  '✅' | '⚠️' | '🚨'
//   .label  'Above target' | 'Below target' | 'Well below target'

const TIERS = {
  strong: {
    key: 'strong',
    text: 'text-green-600',
    bar: 'bg-green-500',
    badge: 'text-green-700 bg-green-50 border border-green-200',
    emoji: '✅',
    label: 'Above target',
  },
  ok: {
    key: 'ok',
    text: 'text-yellow-600',
    bar: 'bg-yellow-500',
    badge: 'text-amber-700 bg-amber-50 border border-amber-200',
    emoji: '⚠️',
    label: 'Below target',
  },
  weak: {
    key: 'weak',
    text: 'text-red-600',
    bar: 'bg-red-500',
    badge: 'text-red-700 bg-red-50 border border-red-200',
    emoji: '🚨',
    label: 'Well below target',
  },
};

/**
 * Classify a value into a colour tier.
 * @param {number} value       the score/rate to classify
 * @param {[number, number]} thresholds  [strongMin, okMin] on the same scale as `value`
 * @returns {typeof TIERS.strong}
 */
export function qualityTier(value, thresholds = [4, 3]) {
  const [strongMin, okMin] = thresholds;
  const n = Number(value);
  if (Number.isNaN(n)) return TIERS.weak;
  if (n >= strongMin) return TIERS.strong;
  if (n >= okMin) return TIERS.ok;
  return TIERS.weak;
}

export { TIERS as qualityTiers };
