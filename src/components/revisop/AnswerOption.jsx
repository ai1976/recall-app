import { Check, X } from 'lucide-react'
import { cn } from '@/lib/utils'

/**
 * AnswerOption — a single choice row and its answered/verified treatment.
 *
 * Correctness is shown WITHOUT traffic-light colour: a check or cross glyph plus
 * a "Correct answer" / "You chose this" label. The correct row reads in neutral
 * navy ink (never green); a miss renders in slate (never red — red #b91c1c is
 * reserved for delete-confirmations). Record radius (r4), ≥56px target.
 * Presentational only (Sprint 6.1; green removed from `correct` in 6.4).
 *
 * Props:
 *  - text       (node)     the option body
 *  - index      (number)   0-based → A/B/C/D badge (when not revealed)
 *  - state      ('idle' | 'selected' | 'correct' | 'missed' | 'dim')
 *  - disabled   (boolean)  set once the answer is revealed
 *  - onClick    (fn)
 *  - className  (string)
 */
const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']

const SHELL = {
  idle: 'border-rv-border bg-rv-bg-1 text-rv-ink-900',
  selected: 'border-rv-navy-400 bg-rv-navy-50 text-rv-ink-900',
  correct: 'border-rv-navy bg-rv-navy-50 text-rv-ink-900',
  missed: 'border-rv-slate bg-rv-slate-50 text-rv-ink-900',
  dim: 'border-rv-border bg-rv-bg-1 text-rv-ink-400',
}
const BADGE = {
  idle: 'bg-rv-bg-2 text-rv-ink-600',
  selected: 'bg-rv-navy text-rv-bg-1',
  correct: 'bg-rv-navy text-rv-bg-1',
  missed: 'bg-rv-slate text-white',
  dim: 'bg-rv-bg-2 text-rv-ink-400',
}

export default function AnswerOption({
  text,
  index = 0,
  state = 'idle',
  disabled = false,
  onClick,
  className,
  ...rest
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={cn(
        'flex w-full items-center gap-3 rounded-rec border px-3.5 py-3 text-left',
        'min-h-[56px] font-plex text-[15px] leading-snug',
        disabled ? 'cursor-default' : 'cursor-pointer',
        SHELL[state] || SHELL.idle,
        className,
      )}
      {...rest}
    >
      <span
        className={cn(
          'flex h-6 w-6 shrink-0 items-center justify-center rounded-rec',
          'font-plex-mono text-xs font-medium',
          BADGE[state] || BADGE.idle,
        )}
      >
        {state === 'correct' ? (
          <Check size={14} strokeWidth={3} />
        ) : state === 'missed' ? (
          <X size={14} strokeWidth={3} />
        ) : (
          LETTERS[index]
        )}
      </span>
      <span className="flex-1">{text}</span>
      {state === 'correct' ? (
        <span className="whitespace-nowrap font-plex text-[11.5px] font-medium text-rv-navy">
          Correct answer
        </span>
      ) : null}
      {state === 'missed' ? (
        <span className="whitespace-nowrap font-plex text-[11.5px] font-medium text-rv-slate">
          You chose this
        </span>
      ) : null}
    </button>
  )
}
