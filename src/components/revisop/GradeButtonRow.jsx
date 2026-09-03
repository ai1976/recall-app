import { cn } from '@/lib/utils'
import ForwardLedgerMicro from './ForwardLedgerMicro'

/**
 * GradeButtonRow — the visual climax of the study loop. The three grade options
 * are equal-weight, navy-outline, thumb-zone targets (≥48px; ~88px here). There
 * is NO traffic-light colour on the options — the mono interval text does the
 * differentiating, and each button carries a ForwardLedgerMicro showing where it
 * sends the card. A miss renders slate, never red.
 *
 * Static / sample intervals on the QA route; Sprint 6.4 wires `grades` to
 * get_srs_ladder_config. Presentational only (Sprint 6.1).
 *
 * Props:
 *  - grades     ({ label, iv, bucket }[])  usually length 3 (Hard / Medium / Easy)
 *  - onGrade    (fn)      called with the chosen grade object
 *  - missIndex  (number)  optional — render this option in the slate miss state
 *  - prompt     (string)  header line — default "How hard was recalling that?"
 *  - className  (string)
 */
export default function GradeButtonRow({
  grades = [],
  onGrade,
  missIndex = null,
  prompt = 'How hard was recalling that?',
  className,
}) {
  return (
    <div className={className}>
      {prompt ? (
        <div className="mb-[11px] text-center font-plex text-[13px] text-rv-ink-600">{prompt}</div>
      ) : null}
      <div className="flex gap-2.5">
        {grades.map((g, i) => {
          const miss = missIndex === i
          return (
            <button
              key={g.label}
              type="button"
              onClick={() => onGrade?.(g)}
              className={cn(
                'flex flex-1 flex-col items-center justify-center gap-0.5 rounded-obj',
                'min-h-[88px] px-2.5 pb-3 pt-[13px] border-[1.5px] cursor-pointer',
                miss
                  ? 'border-rv-slate bg-rv-slate-50'
                  : 'border-rv-navy-400 bg-rv-bg-1',
              )}
            >
              <span className="font-plex text-[14.5px] font-medium text-rv-ink-900">{g.label}</span>
              <span
                className={cn(
                  'font-plex-mono text-[21px] font-medium leading-tight [font-variant-numeric:tabular-nums]',
                  miss ? 'text-rv-slate' : 'text-rv-navy',
                )}
              >
                → {g.iv}
              </span>
              <ForwardLedgerMicro bucket={g.bucket} active={!miss} />
            </button>
          )
        })}
      </div>
    </div>
  )
}
