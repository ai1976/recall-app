import { cn } from '@/lib/utils'

/**
 * Label — RevisOp section eyebrow. Uppercase, tracked, muted ink, Plex Sans 500.
 *
 * Presentational only. Part of the reskin type system (Sprint 6.1); consumed by
 * the new primitives and the /__design QA route. Un-migrated pages are untouched.
 *
 * Props:
 *  - className  (string)
 *  - children   (node)
 */
export default function Label({ className, children, ...rest }) {
  return (
    <div
      className={cn(
        'font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400',
        className,
      )}
      {...rest}
    >
      {children}
    </div>
  )
}
