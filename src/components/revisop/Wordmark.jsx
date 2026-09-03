import { cn } from '@/lib/utils'

/**
 * Wordmark — the RevisOp logotype. LOCKED spec (blueprint §1041 / §1209):
 * two-tone TYPOGRAPHY, no icon, no gradient — "Revis" in the brand amber,
 * "Op" in the brand navy. Reads the reskin tokens (--rv-amber / --rv-navy via
 * the rv.* Tailwind colours), so in dark mode "Op" correctly resolves to the
 * navy-as-accent value instead of the near-black light-mode navy.
 *
 * In light mode this renders byte-for-byte the current inline wordmark in
 * NavDesktop.jsx (#f59e0b + #1e1b4b). The Nav swap is deferred to Sprint 6.2.
 *
 * Props:
 *  - size       ('sm' | 'md' | 'lg')  visual scale — default 'md'
 *  - tagline    (string)              optional text beside the mark
 *  - className  (string)
 */
const SIZES = {
  sm: 'text-lg',
  md: 'text-[22px]',
  lg: 'text-3xl',
}

export default function Wordmark({ size = 'md', tagline, className, ...rest }) {
  return (
    <span
      className={cn('inline-flex flex-wrap items-baseline gap-2.5', className)}
      {...rest}
    >
      <span
        className={cn(
          'font-plex font-semibold leading-none tracking-[-0.02em]',
          SIZES[size] || SIZES.md,
        )}
      >
        <span className="text-rv-amber">Revis</span>
        <span className="text-rv-navy">Op</span>
      </span>
      {tagline ? (
        <span className="font-plex text-xs font-normal text-rv-ink-600">{tagline}</span>
      ) : null}
    </span>
  )
}
