// DEV-ONLY design-system showcase — route /__design, NOT linked in any nav,
// NOT reachable in a production build (App.jsx gates it on import.meta.env.DEV).
// No auth, no DB, no Supabase.
//
//   Phase 5 Sprint 1  — brand tokens + StudyItemCard + FlipCard (kept below)
//   Phase 6 Sprint 6.1 — RevisOp reskin token layer + design-language primitives
//                        (the "RevisOp reskin" section; own light/dark toggle)
import { useState } from 'react'
import { BookOpen, Layers, Brain } from 'lucide-react'
import { StudyItemCard } from '@/components/ui/StudyItemCard'
import { FlipCard } from '@/components/ui/FlipCard'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Label as UiLabel } from '@/components/ui/label'
import { Card as UiCard, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Switch } from '@/components/ui/switch'
import {
  Wordmark,
  Label,
  Num,
  IntervalChip,
  Card,
  Row,
  VerifiedEdge,
  AnswerOption,
  ForwardLedgerMicro,
  ForwardLedgerMacro,
  GradeButtonRow,
} from '@/components/revisop'
import { REVISOP_BUCKETS, REVISOP_LITERATA_ENABLED } from '@/lib/revisop-tokens'

const swatches = [
  ['brand-navy', 'bg-brand-navy text-brand-navy-foreground'],
  ['brand-amber', 'bg-brand-amber text-brand-amber-foreground'],
  ['brand-success', 'bg-brand-success text-brand-success-foreground'],
  ['surface-card', 'bg-surface-card text-foreground border border-surface-border'],
  ['surface-muted', 'bg-surface-muted text-foreground'],
  ['surface-amber', 'bg-surface-amber text-brand-amber'],
  ['surface-navy', 'bg-surface-navy text-brand-navy'],
]

// ── RevisOp reskin: --rv-* token swatches ─────────────────────────────────────
const RV_FILLS = [
  'bg-rv-bg-0', 'bg-rv-bg-1', 'bg-rv-bg-2',
  'bg-rv-navy', 'bg-rv-navy-400', 'bg-rv-navy-100', 'bg-rv-navy-50',
  'bg-rv-amber', 'bg-rv-amber-50', 'bg-rv-amber-edge',
  'bg-rv-green', 'bg-rv-green-50',
  'bg-rv-slate', 'bg-rv-slate-50',
  'bg-rv-danger',
]
const RV_INKS = ['text-rv-ink-900', 'text-rv-ink-600', 'text-rv-ink-400', 'text-rv-amber-ink']
const RV_BORDERS = ['border-rv-border', 'border-rv-border-strong']

// ── sample data (stands in for get_study_queue / get_due_forecast shapes) ─────
const TODAY_LOAD = [28, 12, 18, 9, 14, 7, 4, 2]
const COHORT_LOAD = [340, 214, 486, 262, 388, 176, 88, 41]
const GRADES = [
  { label: 'Hard', iv: '1d', bucket: 1 },
  { label: 'Medium', iv: '4d', bucket: 3 },
  { label: 'Easy', iv: '9d', bucket: 4 },
]

function Swatch({ cls }) {
  return (
    <div className="space-y-1">
      <div className={`h-14 rounded-rec border border-rv-border ${cls}`} />
      <code className="text-[10px] text-rv-ink-400">{cls}</code>
    </div>
  )
}

/** The whole reskin gallery. Rendered inside a light frame and a dark frame. */
// Sprint 6.4 — sample computed grade intervals (as StudyMode derives them from
// get_srs_ladder_config for a card sitting at rung 2: Hard → relearn step,
// Medium → hold at rung 2, Easy → advance to rung 3).
const STUDY_GRADES = [
  { label: 'Hard', iv: '1d', bucket: 1 },
  { label: 'Medium', iv: '7d', bucket: 3 },
  { label: 'Easy', iv: '14d', bucket: 4 },
]

const LONG_ANSWER =
  'Under AS 10, an item of property, plant and equipment that qualifies for ' +
  'recognition as an asset is measured at its cost. Cost comprises the purchase ' +
  'price, import duties and non-refundable taxes, and any directly attributable ' +
  'cost of bringing the asset to the location and condition necessary for it to ' +
  'operate. Subsequent costs are capitalised only when it is probable that future ' +
  'economic benefits will flow to the enterprise.'

function ReskinGallery() {
  const [replayKey, setReplayKey] = useState(0)
  const [answered, setAnswered] = useState(false)
  return (
    <div className="space-y-8 rounded-obj border border-rv-border bg-rv-bg-0 p-6 text-rv-ink-900">
      {/* Wordmark */}
      <section className="space-y-3">
        <Label>Wordmark — two-tone, token-driven (no gradient)</Label>
        <div className="flex flex-wrap items-baseline gap-6">
          <Wordmark size="sm" />
          <Wordmark size="md" />
          <Wordmark size="lg" />
          <Wordmark size="md" tagline="The Revision Operating System." />
        </div>
      </section>

      {/* Type system */}
      <section className="space-y-2">
        <Label>Type system — self-hosted, subset woff2</Label>
        <p className="font-plex text-[15px] text-rv-ink-900">
          IBM Plex Sans — the UI face. The quick brown fox jumps over the lazy dog. 0123456789
        </p>
        <p className="font-plex-mono text-[14px] text-rv-ink-900">
          IBM Plex Mono — numbers concerning time / count. → 6d · 9 due · 1,204 · 41/24
        </p>
        <p className="font-literata text-[15px] text-rv-ink-900">
          Literata — reading bodies only.{' '}
          <span className="text-rv-ink-400">
            (gate {REVISOP_LITERATA_ENABLED ? 'ON' : 'OFF'} — Sprint 6.4 activates it for long
            flashcard answers ≥ 320 chars via lazy load; see the Study loop section below)
          </span>
        </p>
      </section>

      {/* rv token swatches */}
      <section className="space-y-3">
        <Label>--rv-* palette</Label>
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-5">
          {RV_FILLS.map((c) => <Swatch key={c} cls={c} />)}
        </div>
        <div className="flex flex-wrap gap-4 pt-1">
          {RV_INKS.map((c) => (
            <span key={c} className={`font-plex text-[13px] ${c}`}>{c}</span>
          ))}
          {RV_BORDERS.map((c) => (
            <span key={c} className={`rounded-rec border-2 px-2 py-1 text-[11px] text-rv-ink-400 ${c}`}>
              {c}
            </span>
          ))}
        </div>
      </section>

      {/* Two-tier radius */}
      <section className="space-y-3">
        <Label>Two-tier radius</Label>
        <div className="flex items-end gap-4">
          <div className="flex h-16 w-28 items-center justify-center rounded-rec border border-rv-border bg-rv-bg-1 font-plex-mono text-xs text-rv-ink-600">
            r4 · record
          </div>
          <div className="flex h-16 w-28 items-center justify-center rounded-obj border border-rv-border bg-rv-bg-1 font-plex-mono text-xs text-rv-ink-600">
            r14 · object
          </div>
        </div>
      </section>

      {/* Interval chip */}
      <section className="space-y-3">
        <Label>Interval chip — micro forward-ledger marker (mono)</Label>
        <div className="flex flex-wrap items-center gap-2">
          <IntervalChip tone="navy" title="Next scheduled review">→ 6d</IntervalChip>
          <IntervalChip tone="due">9 due</IntervalChip>
          <IntervalChip tone="due">now</IntervalChip>
          <IntervalChip tone="green">→ 1mo</IntervalChip>
          <IntervalChip tone="slate">missed → 1d</IntervalChip>
        </div>
      </section>

      {/* Card + Row */}
      <section className="space-y-3">
        <Label>Card (r14) &amp; Row (r4) — the two containers</Label>
        <Card elevated className="p-4">
          <div className="font-plex text-[15px] font-medium">Card — study object</div>
          <div className="font-plex text-[13px] text-rv-ink-400">
            r14, optional shadow-rv. The thing under review, sheets, focal surfaces.
          </div>
        </Card>
        <div className="space-y-1.5">
          <Row verified>
            <div className="min-w-0 flex-1">
              <div className="truncate font-plex text-[14.5px] font-medium">
                Accounting Standards · AS 10–16
              </div>
              <div className="font-plex-mono text-[11px] text-rv-ink-400">
                questions · last seen 2d ago
              </div>
            </div>
            <IntervalChip tone="due">9 due</IntervalChip>
          </Row>
          <Row>
            <div className="min-w-0 flex-1">
              <div className="truncate font-plex text-[14.5px] font-medium">
                Direct Tax · Capital gains (your own cards)
              </div>
              <div className="font-plex-mono text-[11px] text-rv-ink-400">
                flashcards · last seen 1d ago
              </div>
            </div>
            <IntervalChip tone="due">4 due</IntervalChip>
          </Row>
        </div>
      </section>

      {/* Verified edge */}
      <section className="space-y-3">
        <Label>Verified edge — navy = institute-verified, blank = your own</Label>
        <div className="flex gap-6">
          <div className="flex items-stretch gap-2 rounded-rec border border-rv-border bg-rv-bg-1 p-0">
            <VerifiedEdge on />
            <span className="px-3 py-2 font-plex text-[13px]">verified</span>
          </div>
          <div className="flex items-stretch gap-2 rounded-rec border border-rv-border bg-rv-bg-1 p-0">
            <VerifiedEdge />
            <span className="px-3 py-2 font-plex text-[13px] text-rv-ink-400">unmarked</span>
          </div>
        </div>
      </section>

      {/* Answer options — neutral correctness */}
      <section className="space-y-2">
        <Label>Answered treatment — glyph + label, no traffic-light colour</Label>
        <div className="max-w-xl space-y-2">
          <AnswerOption index={0} state="dim" disabled text="Site preparation and installation charges" />
          <AnswerOption index={2} state="correct" disabled text="Staff training on how to operate the machine" />
          <AnswerOption index={3} state="missed" disabled text="Professional fees of the erection engineer" />
          <AnswerOption index={1} state="selected" text="Initial delivery and handling costs (pre-reveal, selected)" />
        </div>
      </section>

      {/* Forward ledger — micro */}
      <section className="space-y-3">
        <Label>Forward ledger — micro (bucket rail)</Label>
        <div className="flex max-w-md gap-6">
          {[1, 3, 5].map((b) => (
            <div key={b} className="flex-1">
              <div className="font-plex-mono text-[11px] text-rv-ink-400">
                → {REVISOP_BUCKETS[b]}
              </div>
              <ForwardLedgerMicro bucket={b} active />
            </div>
          ))}
        </div>
      </section>

      {/* Forward ledger — macro */}
      <section className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-rec border border-rv-border bg-rv-bg-1 p-4">
          <Label className="mb-3">Forward ledger — Today (self)</Label>
          <ForwardLedgerMacro data={TODAY_LOAD} height={78} unit="items" />
        </div>
        <div className="rounded-rec border border-rv-border bg-rv-bg-1 p-4">
          <Label className="mb-3">Forward ledger — cohort (educator)</Label>
          <ForwardLedgerMacro data={COHORT_LOAD} height={78} unit="items across the batch" />
        </div>
      </section>

      {/* Grade button row */}
      <section className="space-y-3">
        <Label>Neutral grade-button row — the climax (≥48px, navy-outline, mono)</Label>
        <div className="max-w-xl rounded-obj border border-rv-border bg-rv-bg-1 p-4 shadow-rv">
          <GradeButtonRow grades={GRADES} onGrade={() => {}} />
        </div>
        <div className="max-w-xl rounded-obj border border-rv-border bg-rv-bg-1 p-4">
          <GradeButtonRow
            grades={GRADES}
            onGrade={() => {}}
            missIndex={0}
            prompt="Miss state — slate, never red"
          />
        </div>
      </section>

      {/* ════════ Sprint 6.2 — Shared chrome: nav shell + Button/Input atoms ════════ */}
      <section className="space-y-3">
        <Label>Chrome — reskinned nav strip (representative; DOM unchanged in the real nav)</Label>
        <div className="flex h-16 items-center gap-1 rounded-rec border border-rv-border bg-rv-bg-1 px-4 font-plex">
          <div className="mr-3"><Wordmark size="sm" /></div>
          <span className="rounded-rec bg-rv-navy-50 px-3 py-2 text-sm font-medium text-rv-navy">Dashboard</span>
          <span className="rounded-rec px-3 py-2 text-sm font-medium text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900">Study</span>
          <span className="rounded-rec px-3 py-2 text-sm font-medium text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900">Create</span>
          <span className="rounded-rec px-3 py-2 text-sm font-medium text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900">Groups</span>
        </div>
        <p className="font-plex text-[12px] text-rv-ink-400">
          Active item = navy tint + navy ink (was amber). Route-prefix active-state logic (Sprint 6.0) is untouched — only its output is restyled.
        </p>
      </section>

      <section className="space-y-3">
        <Label>Chrome — shared Button atom, all variants (ripples to every page)</Label>
        <div className="flex flex-wrap items-center gap-2.5">
          <Button>Default · navy</Button>
          <Button variant="secondary">Secondary</Button>
          <Button variant="outline">Outline</Button>
          <Button variant="ghost">Ghost</Button>
          <Button variant="link">Link</Button>
          <Button variant="destructive">Delete</Button>
        </div>
        <div className="flex flex-wrap items-center gap-2.5">
          <Button size="sm">Small</Button>
          <Button size="lg">Large</Button>
          <Button disabled>Disabled</Button>
          <Button variant="outline" disabled>Disabled outline</Button>
        </div>
      </section>

      <section className="space-y-3">
        <Label>Chrome — shared Input / Textarea / Label atoms</Label>
        <div className="grid max-w-md gap-3">
          <div className="space-y-1.5">
            <UiLabel htmlFor="dq-default">Default</UiLabel>
            <Input id="dq-default" placeholder="Placeholder text" />
          </div>
          <div className="space-y-1.5">
            <UiLabel htmlFor="dq-focus">Focus (navy light / accent dark)</UiLabel>
            <Input
              id="dq-focus"
              placeholder="Simulated focus ring"
              className="border-rv-navy-400 ring-2 ring-rv-navy"
            />
          </div>
          <div className="space-y-1.5">
            <UiLabel htmlFor="dq-disabled">Disabled</UiLabel>
            <Input id="dq-disabled" placeholder="Disabled input" disabled />
          </div>
          <div className="space-y-1.5">
            <UiLabel htmlFor="dq-error">Error (aria-invalid)</UiLabel>
            <Input id="dq-error" defaultValue="bad value" aria-invalid="true" />
          </div>
          <div className="space-y-1.5">
            <UiLabel htmlFor="dq-ta">Textarea</UiLabel>
            <Textarea id="dq-ta" placeholder="Multi-line field on the same input shell" />
          </div>
        </div>
      </section>

      {/* Stats sample using Num */}
      <section className="space-y-2">
        <Label>Numerics (Num)</Label>
        <div className="flex gap-8">
          {[['41', 'day streak'], ['78%', 'accuracy, 7d'], ['1,204', 'items retained']].map(([n, l]) => (
            <div key={l}>
              <Num className="text-xl">{n}</Num>
              <div className="font-plex text-xs text-rv-ink-400">{l}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ════════ Sprint 6.3 — Dashboard: reskinned stat tile + card + live ledger ════════ */}
      <section className="space-y-3">
        <Label>Dashboard — reskinned stat tiles (shadcn Card shell + mono Num numerals)</Label>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 font-plex">
          {[['Reviews', '128', 'Last 7 days'], ['Streak', '41', 'days in a row'],
            ['Accuracy', '78%', 'Easy + Medium'], ['Mastered', '312', 'Items mastered']].map(([t, v, s]) => (
            <UiCard key={t}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-xs sm:text-sm font-medium">{t}</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="font-plex-mono text-xl sm:text-2xl font-medium [font-variant-numeric:tabular-nums] text-rv-ink-900">{v}</div>
                <p className="text-[10px] sm:text-xs text-rv-ink-400">{s}</p>
              </CardContent>
            </UiCard>
          ))}
        </div>
      </section>

      <section className="space-y-3">
        <Label>Dashboard — Forward Ledger macro, live-shaped (get_due_forecast_buckets → number[8])</Label>
        <UiCard className="font-plex">
          <CardContent className="pt-5 pb-4">
            <ForwardLedgerMacro data={TODAY_LOAD} unit="items" />
          </CardContent>
        </UiCard>
      </section>

      {/* ════════ Sprint 6.3 — Surfaces: overlay atom family, open state ════════ */}
      <section className="space-y-3">
        <Label>Surfaces — overlay atoms (open-state reproduction; exact atom classes)</Label>
        <div className="flex flex-wrap gap-6">
          {/* dropdown-menu / select surface */}
          <div className="w-56 rounded-rec border border-rv-border bg-rv-bg-1 p-1 font-plex text-rv-ink-900 shadow-rv">
            <div className="px-2 py-1.5 font-plex text-sm font-semibold text-rv-ink-900">Menu label</div>
            <div className="-mx-1 my-1 h-px bg-rv-border" />
            <div className="flex items-center gap-2 rounded-rec bg-rv-navy-50 px-2 py-1.5 text-sm text-rv-navy">Active / hovered item</div>
            <div className="flex items-center gap-2 rounded-rec px-2 py-1.5 text-sm">Resting item</div>
            <div className="flex items-center gap-2 rounded-rec px-2 py-1.5 text-sm">Another item</div>
          </div>
          {/* popover surface */}
          <div className="w-64 rounded-rec border border-rv-border bg-rv-bg-1 p-4 font-plex text-rv-ink-900 shadow-rv">
            <p className="text-sm font-medium">Popover surface</p>
            <p className="mt-1 text-xs text-rv-ink-400">--rv-bg-1 · --rv-border · rounded-rec · shadow-rv · Plex.</p>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <Label>Surfaces — live interactive atoms (click to open — content portals; theme follows the app)</Label>
        <div className="flex flex-wrap items-center gap-4 font-plex">
          <Select>
            <SelectTrigger className="w-48"><SelectValue placeholder="Select an option" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="a">First option</SelectItem>
              <SelectItem value="b">Second option</SelectItem>
              <SelectItem value="c">Third option</SelectItem>
            </SelectContent>
          </Select>

          <DropdownMenu>
            <DropdownMenuTrigger asChild><Button variant="outline">Open menu</Button></DropdownMenuTrigger>
            <DropdownMenuContent align="start" className="w-52">
              <DropdownMenuLabel>Actions</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem>Edit</DropdownMenuItem>
              <DropdownMenuItem>Duplicate</DropdownMenuItem>
              <DropdownMenuItem>Archive</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          <Popover>
            <PopoverTrigger asChild><Button variant="outline">Open popover</Button></PopoverTrigger>
            <PopoverContent align="start">
              <p className="text-sm font-medium text-rv-ink-900">Popover content</p>
              <p className="mt-1 text-xs text-rv-ink-400">Portaled surface on the --rv-* tokens.</p>
            </PopoverContent>
          </Popover>

          <label className="flex items-center gap-2 text-sm text-rv-ink-900">
            <Switch defaultChecked /> Switch (on)
          </label>
          <label className="flex items-center gap-2 text-sm text-rv-ink-900">
            <Switch /> Switch (off)
          </label>
        </div>
      </section>

      {/* ════════ Sprint 6.4 — Study loop: card frame + grade row + complete ════════ */}
      <section className="space-y-4">
        <Label>Study loop — the review card on the unified frame (r14, Plex, --rv-*)</Label>

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => { setReplayKey((k) => k + 1); setAnswered(false) }}
            className="rounded-rec border border-rv-navy-400 px-3 py-1.5 font-plex text-sm text-rv-navy"
          >
            Replay post-forward animation
          </button>
          <button
            type="button"
            onClick={() => setAnswered((a) => !a)}
            className="rounded-rec border border-rv-navy-400 px-3 py-1.5 font-plex text-sm text-rv-navy"
          >
            {answered ? 'Show question side' : 'Reveal answer'}
          </button>
        </div>

        <Card
          key={replayKey}
          elevated
          className="max-w-2xl font-plex flex overflow-hidden rv-forward-in"
        >
          <VerifiedEdge on={answered} />
          <div className="flex-1 p-8">
            {!answered ? (
              <div className="text-center">
                <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">
                  QUESTION
                </span>
                <p className="mt-6 text-2xl font-semibold text-rv-ink-900">
                  How is an item of PP&amp;E initially measured under AS 10?
                </p>
                <div className="mt-8">
                  <Button size="lg" className="w-full min-h-[48px] gap-2">
                    <Brain className="h-5 w-5" /> Show Answer
                  </Button>
                </div>
              </div>
            ) : (
              <div>
                <div className="mb-6 pb-6 border-b border-rv-border">
                  <span className="inline-block px-3 py-1 bg-rv-bg-2 text-rv-ink-600 text-xs font-semibold tracking-wide rounded-rec">
                    QUESTION
                  </span>
                  <p className="mt-3 text-lg text-rv-ink-600">
                    How is an item of PP&amp;E initially measured under AS 10?
                  </p>
                </div>
                <div className="text-center mb-8">
                  <span className="inline-block px-3 py-1 bg-rv-navy-50 text-rv-navy text-xs font-semibold tracking-wide rounded-rec">
                    ANSWER
                  </span>
                  <p className="mt-4 font-literata font-normal leading-relaxed text-[1.35rem] text-rv-ink-900">
                    {LONG_ANSWER}
                  </p>
                  <p className="mt-2 font-plex text-[12px] text-rv-ink-400">
                    Reading body ≥ 320 chars → Literata (lazy). Shorter answers stay Plex.
                  </p>
                </div>
                <div className="border-t border-rv-border pt-6">
                  <GradeButtonRow
                    grades={STUDY_GRADES}
                    onGrade={() => {}}
                    prompt="How well did you remember this?"
                  />
                </div>
              </div>
            )}
          </div>
        </Card>

        <Label>Revealed-answer correctness — glyph + label, never colour-coded</Label>
        <div className="max-w-2xl space-y-2">
          <AnswerOption text="Measured at cost — purchase price + directly attributable costs." index={0} state="correct" disabled />
          <AnswerOption text="Measured at fair value on the acquisition date." index={1} state="missed" disabled />
          <AnswerOption text="Measured at net realisable value." index={2} state="dim" disabled />
        </div>

        <Label>Session complete — on --rv-* + Plex</Label>
        <Card elevated className="max-w-2xl font-plex p-10 text-center">
          <Brain className="h-16 w-16 text-rv-navy mx-auto mb-3" />
          <h3 className="text-2xl font-semibold text-rv-ink-900 mb-1">Study Session Complete!</h3>
          <p className="text-rv-ink-600 mb-6">You reviewed 12 flashcards</p>
          <div className="grid grid-cols-3 gap-3 max-w-sm mx-auto">
            {[['Easy', 7], ['Medium', 3], ['Hard', 2]].map(([k, n]) => (
              <div key={k} className="rounded-rec border border-rv-border bg-rv-bg-1 p-3">
                <div className="font-plex-mono text-xl font-medium text-rv-ink-900 [font-variant-numeric:tabular-nums]">{n}</div>
                <div className="text-xs text-rv-ink-400">{k}</div>
              </div>
            ))}
          </div>
        </Card>
      </section>
    </div>
  )
}

export default function DesignShowcase() {
  const [flipped, setFlipped] = useState(false)
  const [dark, setDark] = useState(false)

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="mx-auto max-w-6xl space-y-12">
        <header>
          <h1 className="text-2xl font-bold text-brand-navy">
            RevisOp Design System — Dev Showcase
          </h1>
          <p className="text-sm text-muted-foreground">
            Dev-only (<code>/__design</code>). Not linked anywhere, absent from production builds.
          </p>
        </header>

        {/* ══════════ Phase 6 · Sprint 6.1 — RevisOp reskin ══════════ */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-brand-navy">
              RevisOp reskin — token layer &amp; primitives (Sprint 6.1)
            </h2>
            <button
              type="button"
              onClick={() => setDark((d) => !d)}
              className="rounded-md border border-brand-navy px-3 py-1.5 text-sm font-medium text-brand-navy"
            >
              Theme: {dark ? 'Dark' : 'Light'} — toggle
            </button>
          </div>

          {/* single toggle drives the reskin subtree */}
          <div className={dark ? 'dark' : ''}>
            <ReskinGallery />
          </div>

          {/* both themes side-by-side for one-shot screenshot proof */}
          <details className="rounded-obj border border-dashed border-muted-foreground/40 p-2">
            <summary className="cursor-pointer px-2 py-1 text-sm text-muted-foreground">
              Both themes, side by side
            </summary>
            <div className="mt-3 grid gap-4 lg:grid-cols-2">
              <div><ReskinGallery /></div>
              <div className="dark"><ReskinGallery /></div>
            </div>
          </details>
        </section>

        {/* ══════════ Phase 5 · Sprint 1 — kept ══════════ */}
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Brand tokens (Phase 5 S1)</h2>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {swatches.map(([name, cls]) => (
              <div
                key={name}
                className={`flex h-20 items-center justify-center rounded-lg text-sm font-medium ${cls}`}
              >
                {name}
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">StudyItemCard (Phase 5 S1)</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <StudyItemCard
              title="Standards on Auditing"
              subjectLabel="Audit"
              topicLabel="SA 200-299"
              itemCount={42}
              authorName="CA Anand More"
              badgeLabel="Expert"
              icon={BookOpen}
              onClick={() => {}}
            />
            <StudyItemCard
              title="Accounting Standards Quick Recall"
              subjectLabel="FR"
              itemCount={1}
              authorName="Priya S."
              icon={Layers}
              onClick={() => {}}
            />
            <StudyItemCard
              title="Concept Cards — Cost Sheets"
              topicLabel="Costing"
              itemCount={18}
              authorName="Rahul K."
              icon={Brain}
            />
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">FlipCard (Phase 5 S1, controlled)</h2>
          <div className="flex flex-col items-start gap-4">
            <FlipCard
              className="h-48 w-80"
              isFlipped={flipped}
              front={
                <p className="text-center text-lg font-semibold">
                  What does SA 200 deal with?
                </p>
              }
              back={
                <p className="text-center">
                  Overall objectives of the independent auditor.
                </p>
              }
            />
            <button
              type="button"
              onClick={() => setFlipped((f) => !f)}
              className="rounded-lg bg-brand-amber px-4 py-2 text-sm font-semibold text-brand-amber-foreground"
            >
              {flipped ? 'Show question' : 'Show answer'}
            </button>
          </div>
        </section>
      </div>
    </div>
  )
}
