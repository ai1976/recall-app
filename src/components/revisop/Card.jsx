import { cn } from '@/lib/utils'

/**
 * Card — the study-object container (r14). The card under review, sheets, and
 * anything that is the focus of an interaction rather than a list entry.
 *
 * Pairs with <Row> (r4), which is the record container. Presentational only
 * (Sprint 6.1) — no data, no routing.
 *
 * Props:
 *  - elevated   (boolean)  apply the reskin drop shadow (shadow-rv)
 *  - className  (string)
 *  - children   (node)
 */
export default function Card({ elevated = false, className, children, ...rest }) {
  return (
    <div
      className={cn(
        'rounded-obj border border-rv-border bg-rv-bg-1 text-rv-ink-900',
        elevated && 'shadow-rv',
        className,
      )}
      {...rest}
    >
      {children}
    </div>
  )
}
