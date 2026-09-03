import { cn } from '@/lib/utils'
import VerifiedEdge from './VerifiedEdge'

/**
 * Row — the record container (r4): list entries, deck rows, table-ish lines.
 * Flat by default (no shadow); pairs with <Card> (r14) for study objects.
 *
 * Renders an optional leading <VerifiedEdge>. Children are laid out in a padded
 * flex track; pass your own alignment via `contentClassName`.
 *
 * Presentational only (Sprint 6.1).
 *
 * Props:
 *  - verified          (boolean)  show the navy verified rail
 *  - onClick           (fn)       makes the row a button (role/tabIndex added)
 *  - className         (string)   on the outer shell
 *  - contentClassName  (string)   on the inner padded track
 *  - children          (node)
 */
export default function Row({
  verified = false,
  onClick,
  className,
  contentClassName,
  children,
  ...rest
}) {
  const interactive = typeof onClick === 'function'
  return (
    <div
      onClick={onClick}
      role={interactive ? 'button' : undefined}
      tabIndex={interactive ? 0 : undefined}
      onKeyDown={
        interactive
          ? (e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault()
                onClick(e)
              }
            }
          : undefined
      }
      className={cn(
        'flex overflow-hidden rounded-rec border border-rv-border bg-rv-bg-1 text-rv-ink-900',
        interactive && 'cursor-pointer focus:outline-none focus-visible:ring-2 focus-visible:ring-rv-navy-400',
        className,
      )}
      {...rest}
    >
      <VerifiedEdge on={verified} />
      <div
        className={cn(
          'flex min-h-[56px] flex-1 items-center gap-3 px-[13px] py-[11px]',
          contentClassName,
        )}
      >
        {children}
      </div>
    </div>
  )
}
