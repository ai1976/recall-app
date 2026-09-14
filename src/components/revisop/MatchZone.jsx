import { useState } from 'react'
import { Check, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import Label from './Label'

/**
 * MatchZone — left-item / right-item pairing interaction (Sprint 7.8).
 *
 * Tap a left row to select it, then a right badge to assign it; re-tapping an
 * already-assigned left row lets you change it, and assigning a right badge
 * already used elsewhere un-assigns it from its previous row. Reveal follows
 * the AnswerOption convention — navy = correct, slate = missed, never red/green.
 * Record radius (r4), ≥48px right-badge targets.
 *
 * Props:
 *  - left      (string[])
 *  - right     ({k, v}[])
 *  - pairs     ({[leftIndex]: rightKey})   controlled — the student's current assignment
 *  - onChange  (fn)                        (newPairs) => void
 *  - revealed  (boolean)
 *  - correct   ({[leftIndex]: rightKey})   only read once revealed
 */
export default function MatchZone({ left, right, pairs, onChange, revealed, correct }) {
  const [selected, setSelected] = useState(null)
  const usedRight = Object.values(pairs)

  const pick = (li) => {
    if (revealed) return
    if (pairs[li] !== undefined) {
      const next = { ...pairs }
      delete next[li]
      onChange(next)
      setSelected(li)
      return
    }
    setSelected(selected === li ? null : li)
  }

  const assign = (k) => {
    if (revealed || selected === null) return
    const next = { ...pairs }
    Object.keys(next).forEach((key) => {
      if (next[key] === k) delete next[key]
    })
    next[selected] = k
    onChange(next)
    setSelected(null)
  }

  return (
    <div className="flex w-full flex-col gap-2 text-left">
      {left.map((l, li) => {
        const k = pairs[li]
        const ok = revealed && k === correct[li]
        const bad = revealed && k !== correct[li]
        const active = selected === li
        return (
          <div key={li}>
            <button
              type="button"
              onClick={() => pick(li)}
              disabled={revealed}
              className={cn(
                'flex w-full items-center gap-3 rounded-rec border px-3.5 py-3 text-left',
                'min-h-[54px] font-plex text-[15px] leading-snug text-rv-ink-900',
                revealed ? 'cursor-default' : 'cursor-pointer',
                ok
                  ? 'border-rv-navy bg-rv-navy-50'
                  : bad
                    ? 'border-rv-slate bg-rv-slate-50'
                    : active
                      ? 'border-rv-navy-400 bg-rv-navy-50'
                      : 'border-rv-border bg-rv-bg-1',
              )}
            >
              <span
                className={cn(
                  'flex h-6 w-6 shrink-0 items-center justify-center rounded-rec',
                  'font-plex-mono text-xs font-medium',
                  ok
                    ? 'bg-rv-navy text-rv-bg-1'
                    : bad
                      ? 'bg-rv-slate text-white'
                      : k
                        ? 'bg-rv-navy text-rv-bg-1'
                        : 'bg-rv-bg-2 text-rv-ink-400',
                )}
              >
                {ok ? (
                  <Check size={14} strokeWidth={3} />
                ) : bad ? (
                  <X size={14} strokeWidth={3} />
                ) : (
                  k || '—'
                )}
              </span>
              <span className="flex-1">{l}</span>
              {!revealed && active ? (
                <span className="whitespace-nowrap font-plex text-[11.5px] text-rv-navy">
                  pick a match →
                </span>
              ) : null}
            </button>
            {bad ? (
              <div className="flex items-baseline gap-1.5 px-3.5 pb-1 pt-1.5 font-plex text-[12.5px] text-rv-ink-600">
                <span className="font-medium text-rv-navy">Correct answer:</span>
                <span>
                  {correct[li]} — {right.find((r) => r.k === correct[li])?.v}
                </span>
              </div>
            ) : null}
          </div>
        )
      })}

      <div className="my-1 h-px bg-rv-border" />
      <Label className="mb-0.5">
        {revealed ? 'Options' : 'Tap a row above, then its match'}
      </Label>
      <div className="flex flex-wrap gap-1.5">
        {right.map((r) => {
          const used = usedRight.includes(r.k)
          return (
            <button
              key={r.k}
              type="button"
              onClick={() => assign(r.k)}
              disabled={revealed || selected === null}
              className={cn(
                'flex flex-[1_1_44%] items-center gap-2 rounded-rec border px-3 py-2.5 text-left',
                'min-h-[48px] font-plex text-sm text-rv-ink-900',
                selected !== null && !revealed ? 'border-rv-navy-400' : 'border-rv-border',
                used ? 'bg-rv-bg-2' : 'bg-rv-bg-1',
                used && !revealed ? 'opacity-55' : 'opacity-100',
                revealed || selected === null ? 'cursor-default' : 'cursor-pointer',
              )}
            >
              <span className="font-plex-mono text-xs font-medium text-rv-navy">{r.k}</span>
              <span>{r.v}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
