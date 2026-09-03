import { cn } from '@/lib/utils'

/**
 * VerifiedEdge — a 3px full-height rail on the leading edge of a record or study
 * object. Navy when the content is verified by the institute; transparent (but
 * still 3px, so nothing shifts) when it is the learner's own.
 *
 * The verified signal is carried by this edge alone — no badge, no colour beyond
 * the single navy strip. Presentational only (Sprint 6.1).
 *
 * Props:
 *  - on         (boolean)  render the navy rail
 *  - className  (string)
 */
export default function VerifiedEdge({ on = false, className, ...rest }) {
  return (
    <div
      aria-hidden="true"
      className={cn(
        'w-[3px] shrink-0 self-stretch',
        on ? 'bg-rv-navy' : 'bg-transparent',
        className,
      )}
      {...rest}
    />
  )
}
