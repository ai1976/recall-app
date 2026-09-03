import { cn } from '@/lib/utils'
import { REVISOP_BUCKETS } from '@/lib/revisop-tokens'

/**
 * ForwardLedgerMacro — the signature device at Today / cohort scale: a
 * scheduled-load bar rail across the eight buckets, "now" (index 0) emphasised.
 *
 * This is scheduled work, from now to six months out — NOT a retention curve.
 * `data` is a length-8 series; callers fold get_due_forecast / get_study_queue
 * into that shape with ledgerFromForecast(). On the /__design QA route it is
 * handed literal sample series. Presentational only (Sprint 6.1).
 *
 * Props:
 *  - data       (number[8])  scheduled count per bucket
 *  - height     (number)     bar-area height in px — default 72
 *  - unit       (string)     caption noun — default 'items'
 *  - showCaption (boolean)   render the "Scheduled … from now to six months out." line
 *  - className  (string)
 */
export default function ForwardLedgerMacro({
  data = [],
  height = 72,
  unit = 'items',
  showCaption = true,
  className,
}) {
  const series = Array.from({ length: 8 }, (_, i) => Number(data[i]) || 0)
  const max = Math.max(1, ...series)
  return (
    <div className={className}>
      <div className="flex items-end gap-1" style={{ height }}>
        {series.map((v, i) => {
          const h = Math.max(4, Math.round((v / max) * (height - 18)))
          const now = i === 0
          return (
            <div key={REVISOP_BUCKETS[i]} className="flex flex-1 flex-col items-center justify-end">
              <span
                className={cn(
                  'mb-1 font-plex-mono text-[10.5px] [font-variant-numeric:tabular-nums]',
                  now ? 'font-medium text-rv-ink-900' : 'text-rv-ink-400',
                )}
              >
                {v}
              </span>
              <div
                className={cn(
                  'w-[78%] rounded-t-rec',
                  now ? 'bg-rv-navy' : 'border border-b-0 border-rv-navy-100 bg-rv-navy-100',
                )}
                style={{ height: h }}
              />
            </div>
          )
        })}
      </div>
      <div className="h-px bg-rv-border-strong" />
      <div className="mt-[5px] flex gap-1">
        {REVISOP_BUCKETS.map((b, i) => (
          <div
            key={b}
            className={cn(
              'flex-1 text-center font-plex-mono text-[10.5px]',
              i === 0 ? 'font-medium text-rv-ink-900' : 'text-rv-ink-400',
            )}
          >
            {b}
          </div>
        ))}
      </div>
      {showCaption ? (
        <div className="mt-2 font-plex text-[11.5px] text-rv-ink-400">
          Scheduled {unit}, from now to six months out.
        </div>
      ) : null}
    </div>
  )
}
