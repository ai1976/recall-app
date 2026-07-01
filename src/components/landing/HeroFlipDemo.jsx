import { useState } from 'react'
import { Link } from 'react-router-dom'
import { XCircle, AlertCircle, CheckCircle, Sparkles } from 'lucide-react'
import { FlipCard } from '@/components/ui/FlipCard'
import { Button } from '@/components/ui/button'

// Shown when there is no featured deck yet (or the featured deck has no teaser cards),
// so the hero is never blank. Kept generic and clearly illustrative.
const FALLBACK_CARDS = [
  {
    front_text: 'What is the SM-2 algorithm?',
    back_text: 'A spaced repetition scheduling algorithm that widens review intervals as your recall improves.',
  },
  {
    front_text: 'What does spaced repetition prevent?',
    back_text: 'The forgetting curve — reviewing just before you\'d naturally forget locks it into long-term memory.',
  },
  {
    front_text: 'How often is an easy card reviewed?',
    back_text: 'Less and less often — intervals grow exponentially the more consistently you recall it correctly.',
  },
]

const RATINGS = [
  { key: 'hard', label: 'Hard', icon: XCircle, className: 'border-red-300 hover:bg-red-50 hover:border-red-400 text-red-600' },
  { key: 'medium', label: 'Medium', icon: AlertCircle, className: 'border-yellow-300 hover:bg-yellow-50 hover:border-yellow-400 text-yellow-600' },
  { key: 'easy', label: 'Easy', icon: CheckCircle, className: 'border-green-300 hover:bg-green-50 hover:border-green-400 text-green-600' },
]

export default function HeroFlipDemo({ deck }) {
  const isFallback = !deck?.cards?.length
  const cards = isFallback ? FALLBACK_CARDS : deck.cards

  const [index, setIndex] = useState(0)
  const [isFlipped, setIsFlipped] = useState(false)
  const [done, setDone] = useState(false)

  const currentCard = cards[index]

  function handleRate() {
    if (index + 1 >= cards.length) {
      setDone(true)
    } else {
      setIndex((i) => i + 1)
      setIsFlipped(false)
    }
  }

  if (done) {
    return (
      <div className="mx-auto max-w-md rounded-xl border border-surface-border bg-surface-card p-8 text-center shadow-lg">
        <Sparkles className="h-8 w-8 text-brand-amber mx-auto mb-3" />
        <h3 className="text-lg font-bold text-brand-navy mb-2">Sign up to save your progress</h3>
        <p className="text-sm text-muted-foreground mb-5">
          Every card you just reviewed gets scheduled for you the moment you create a free account.
        </p>
        <Link to="/signup">
          <Button className="bg-[#1e1b4b] hover:bg-[#2d2a6e]">Start free</Button>
        </Link>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-md">
      {!isFallback && deck?.name && (
        <p className="text-center text-xs font-semibold uppercase tracking-wide text-brand-amber mb-3">
          From &ldquo;{deck.name}&rdquo;
        </p>
      )}

      <FlipCard
        className="h-56 w-full cursor-pointer"
        isFlipped={isFlipped}
        onClick={() => !isFlipped && setIsFlipped(true)}
        front={
          <div className="text-center px-4">
            <span className="inline-block px-3 py-1 bg-gray-100 text-gray-600 text-xs font-semibold rounded-full mb-4">
              QUESTION
            </span>
            <p className="text-lg text-gray-800">{currentCard.front_text}</p>
            <p className="text-xs text-gray-400 mt-4">Tap to flip</p>
          </div>
        }
        back={
          <div className="text-center px-4">
            <span className="inline-block px-3 py-1 bg-white/20 text-white text-xs font-semibold rounded-full mb-4">
              ANSWER
            </span>
            <p className="text-lg font-semibold">{currentCard.back_text}</p>
          </div>
        }
      />

      {isFlipped && (
        <div className="mt-6">
          <p className="text-center text-sm text-gray-600 mb-3">How well did you remember this?</p>
          <div className="grid grid-cols-3 gap-3">
            {RATINGS.map(({ key, label, icon: Icon, className }) => (
              <Button
                key={key}
                variant="outline"
                onClick={handleRate}
                className={`flex flex-col gap-1 h-auto py-3 ${className}`}
              >
                <Icon className="h-5 w-5" />
                <span className="text-sm font-semibold">{label}</span>
              </Button>
            ))}
          </div>
        </div>
      )}

      <p className="text-center text-xs text-gray-400 mt-4">
        Card {index + 1} of {cards.length}{isFallback ? ' · demo' : ''}
      </p>
    </div>
  )
}
