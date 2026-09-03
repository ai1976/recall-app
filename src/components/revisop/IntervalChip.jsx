import { cn } from '@/lib/utils'

/**
 * IntervalChip — the micro scale of the forward ledger: a per-item marker that
 * states a scheduling interval in mono figures. Record radius (r4).
 *
 * Never a retention / decay "%" — always a scheduled interval ("→ 6d", "9 due",
 * "now"). Presentational only (Sprint 6.1).
 *
 * Props:
 *  - tone       ('navy' | 'due' | 'green' | 'slate')  default 'navy'
 *  - title      (string)  hover hint, e.g. "Current scheduling interval"
 *  - className  (string)
 *  - children   (node)    the mono text
 */
const TONES = {
  navy: 'bg-rv-navy-50 text-rv-navy border-rv-navy-100',
  due: 'bg-rv-bg-2 text-rv-ink-900 border-rv-border-strong',
  green: 'bg-rv-green-50 text-rv-green border-rv-green',
  slate: 'bg-rv-slate-50 text-rv-slate border-rv-border-strong',
}

export default function IntervalChip({ tone = 'navy', title, className, children, ...rest }) {
  return (
    <span
      title={title}
      className={cn(
        'inline-block whitespace-nowrap rounded-rec border px-[7px] py-[5px]',
        'font-plex-mono text-[11.5px] font-medium leading-none [font-variant-numeric:tabular-nums]',
        TONES[tone] || TONES.navy,
        className,
      )}
      {...rest}
    >
      {children}
    </span>
  )
}
