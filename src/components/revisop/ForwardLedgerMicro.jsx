import { cn } from '@/lib/utils'
import { REVISOP_BUCKETS } from '@/lib/revisop-tokens'

/**
 * ForwardLedgerMicro — the signature device at its smallest: a single-item
 * time rail with a dot at the bucket the item is about to land in. Lives inside
 * a grade button so the learner sees where "Easy" vs "Hard" sends this card.
 *
 * Driven by a bucket index (0..7 into REVISOP_BUCKETS), which callers derive
 * from real scheduled data via bucketForDays(). Presentational only (Sprint 6.1).
 *
 * Props:
 *  - bucket     (number)   0..7 — where the dot sits
 *  - active     (boolean)  emphasise the baseline (the button this belongs to is live)
 *  - className  (string)
 */
export default function ForwardLedgerMicro({ bucket = 0, active = false, className }) {
  const last = REVISOP_BUCKETS.length - 1
  const clamped = Math.max(0, Math.min(last, bucket))
  const pct = (clamped / last) * 100
  return (
    <div className={cn('relative mt-2.5 h-2.5 w-full', className)} aria-hidden="true">
      <div
        className={cn(
          'absolute inset-x-0 top-1 h-px',
          active ? 'bg-rv-navy-400' : 'bg-rv-border-strong',
        )}
      />
      {REVISOP_BUCKETS.map((b, i) => (
        <div
          key={b}
          className="absolute top-0.5 h-[5px] w-px -translate-x-[0.5px] bg-rv-border-strong"
          style={{ left: `${(i / last) * 100}%` }}
        />
      ))}
      <div
        className="absolute top-0 h-[9px] w-[9px] -translate-x-[4.5px] rounded-full bg-rv-navy"
        style={{ left: `${pct}%` }}
      />
    </div>
  )
}
