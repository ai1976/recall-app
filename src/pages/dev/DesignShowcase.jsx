// DEV-ONLY design-system showcase — route /__design, NOT linked in any nav.
// No auth, no DB, no Supabase. Sprint 1 (Phase 5) token + component QA only.
// Sprint 4 may remove or keep this file.
import { useState } from 'react'
import { BookOpen, Layers, Brain } from 'lucide-react'
import { StudyItemCard } from '@/components/ui/StudyItemCard'
import { FlipCard } from '@/components/ui/FlipCard'

const swatches = [
  ['brand-navy', 'bg-brand-navy text-brand-navy-foreground'],
  ['brand-amber', 'bg-brand-amber text-brand-amber-foreground'],
  ['brand-success', 'bg-brand-success text-brand-success-foreground'],
  ['surface-card', 'bg-surface-card text-foreground border border-surface-border'],
  ['surface-muted', 'bg-surface-muted text-foreground'],
  ['surface-amber', 'bg-surface-amber text-brand-amber'],
  ['surface-navy', 'bg-surface-navy text-brand-navy'],
]

export default function DesignShowcase() {
  const [flipped, setFlipped] = useState(false)

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="mx-auto max-w-5xl space-y-12">
        <header>
          <h1 className="text-2xl font-bold text-brand-navy">
            RevisOp Design System — Dev Showcase
          </h1>
          <p className="text-sm text-muted-foreground">
            Dev-only (<code>/__design</code>). Not linked anywhere. Sprint 1 token &amp; component QA.
          </p>
        </header>

        {/* Token swatches */}
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Brand tokens</h2>
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

        {/* StudyItemCard */}
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">StudyItemCard</h2>
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

        {/* FlipCard */}
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">FlipCard (controlled)</h2>
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
