import { cn } from '@/lib/utils'

/**
 * Num — RevisOp numeric span. Plex Mono, tabular figures, medium weight.
 *
 * Use for numbers that concern time or count (intervals, due counts, streaks,
 * dates). Never for prose. Presentational only (Sprint 6.1).
 *
 * Props:
 *  - className  (string)  size/colour via utilities, e.g. "text-xl text-rv-ink-900"
 *  - children   (node)
 */
export default function Num({ className, children, ...rest }) {
  return (
    <span
      className={cn(
        'font-plex-mono font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900',
        className,
      )}
      {...rest}
    >
      {children}
    </span>
  )
}
