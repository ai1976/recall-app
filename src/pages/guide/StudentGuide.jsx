import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { SITUATIONS } from '@/data/guideContent'

function scrollToSection(id) {
  const el = document.getElementById(id)
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}

export default function StudentGuide() {
  const pillRowRef = useRef(null)
  const navigate = useNavigate()
  const [activeId, setActiveId] = useState(SITUATIONS[0].id)

  // Set page title
  useEffect(() => {
    document.title = 'Student Guide — Recall'
    return () => { document.title = 'Recall' }
  }, [])

  // Scroll spy — fires when a section enters the upper third of the viewport
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setActiveId(entry.target.id)
          }
        })
      },
      { threshold: 0.2, rootMargin: '-20% 0px -60% 0px' }
    )

    SITUATIONS.forEach(({ id }) => {
      const el = document.getElementById(id)
      if (el) observer.observe(el)
    })

    return () => observer.disconnect()
  }, [])

  function handleStepLink(linkTo, isSignup) {
    if (!linkTo) return
    if (isSignup) {
      navigate('/signup')
    } else {
      localStorage.setItem('postAuthRedirect', linkTo)
      navigate('/login')
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header Bar */}
      <header className="sticky top-0 z-30 bg-white border-b border-gray-200">
        <div className="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold text-xl px-3 py-1 rounded">
              R
            </div>
            <span className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              Recall
            </span>
            <span className="text-gray-300 font-light text-xl">|</span>
            <span className="text-gray-500 text-sm font-medium">Study Guide</span>
          </Link>
          <Link
            to="/login"
            className="text-sm font-medium text-indigo-600 hover:text-indigo-800 transition-colors"
          >
            Log in
          </Link>
        </div>
      </header>

      {/* Mobile pill row — visible only on small screens */}
      <div className="md:hidden sticky top-14 z-20 bg-white border-b border-gray-200 px-4 py-2 overflow-x-auto scrollbar-hide">
        <div ref={pillRowRef} className="flex gap-2 w-max">
          {SITUATIONS.map((s) => (
            <button
              key={s.id}
              onClick={() => scrollToSection(s.id)}
              className={`flex-none px-3 py-1.5 rounded-full text-xs font-medium transition-colors whitespace-nowrap ${
                activeId === s.id
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-indigo-100 hover:text-indigo-700'
              }`}
            >
              {s.emoji} {s.sidebarLabel}
            </button>
          ))}
        </div>
      </div>

      {/* Intro block */}
      <div className="max-w-5xl mx-auto w-full px-4 pt-8">
        <div className="bg-indigo-50 border border-indigo-100 rounded-xl px-8 py-6 mb-10">
          <h1 className="text-2xl font-bold text-gray-900 mb-3">You are here.</h1>
          <p className="text-gray-600 leading-relaxed mb-4">
            Pick the situation that matches where you are right now. Each one gives you the exact next steps — nothing more, nothing less.
          </p>
          <p className="text-gray-600">
            Already have an account?{' '}
            <Link to="/login" className="text-indigo-600 font-medium underline">
              Log in →
            </Link>
          </p>
        </div>
      </div>

      {/* Main layout */}
      <div className="max-w-5xl mx-auto w-full flex flex-1 px-4 pb-8 gap-8">
        {/* Desktop Sidebar — hidden on mobile */}
        <aside className="hidden md:block w-64 flex-none">
          <nav className="sticky top-24 space-y-1">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3 px-3">
              Find your situation
            </p>
            {SITUATIONS.map((s) => (
              <button
                key={s.id}
                onClick={() => scrollToSection(s.id)}
                className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors flex items-center gap-2 ${
                  activeId === s.id
                    ? 'bg-blue-50 text-blue-700 font-semibold border-l-2 border-blue-500'
                    : 'text-gray-700 hover:bg-indigo-50 hover:text-indigo-700'
                }`}
              >
                <span className="text-base">{s.emoji}</span>
                <span>{s.sidebarLabel}</span>
              </button>
            ))}
            <button
              onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
              className="text-xs text-gray-400 hover:text-gray-600 mt-6 px-3 transition-colors"
            >
              ↑ Back to top
            </button>
          </nav>
        </aside>

        {/* Main content area */}
        <main className="flex-1 min-w-0 space-y-0">
          {SITUATIONS.map((s, idx) => (
            <div key={s.id}>
              <section
                id={s.id}
                className="scroll-mt-24 py-8"
              >
                <h2 className="flex items-center gap-3 text-xl font-semibold text-gray-900 mb-6">
                  <span className="text-2xl">{s.emoji}</span>
                  <span>{s.headline}</span>
                </h2>

                <ol className="space-y-5">
                  {s.steps.map((step, stepIdx) => (
                    <li key={stepIdx} className="flex gap-4">
                      {/* Step number */}
                      <span className="flex-none mt-0.5 w-6 h-6 rounded-full bg-indigo-100 text-indigo-700 text-xs font-bold flex items-center justify-center">
                        {stepIdx + 1}
                      </span>

                      {/* Step content */}
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-900 mb-0.5">
                          {step.label}
                        </p>
                        <p className="text-sm text-gray-500">
                          {step.detail}
                        </p>
                        {step.linkTo && (
                          <button
                            onClick={() => handleStepLink(step.linkTo, step.isSignup)}
                            className="mt-2 inline-block text-sm font-medium text-blue-600 border border-blue-200 rounded-full px-3 py-0.5 hover:bg-blue-50 transition-colors"
                          >
                            {step.linkLabel} →
                          </button>
                        )}
                      </div>
                    </li>
                  ))}
                </ol>
              </section>
              {idx < SITUATIONS.length - 1 && (
                <hr className="border-gray-200" />
              )}
            </div>
          ))}

          {/* Still need help? */}
          <hr className="border-gray-200" />
          <div className="bg-gray-50 border border-gray-200 rounded-xl px-8 py-6 mt-10">
            <h2 className="text-xl font-bold text-gray-900 mb-3">Still need help?</h2>
            <p className="text-gray-600 leading-relaxed mb-6">
              If your situation isn't listed here, reach out to your professor directly — they have full visibility into your account and can assist with anything not covered above.
            </p>
            <Link
              to="/"
              className="inline-flex items-center gap-2 text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors"
            >
              <ArrowLeft className="h-4 w-4" />
              Back to Home
            </Link>
          </div>
        </main>
      </div>
    </div>
  )
}
