/**
 * StudySessionContext.jsx
 *
 * A single boolean the app shell can read to know "the user is inside the
 * full-screen card loop right now" — regardless of which route they entered by.
 *
 * Sprint 7.1: NavBottomTabs must vanish during an active study session so it
 * cannot overlap GradeButtonRow / Show Answer, but MUST stay visible on the
 * `/dashboard/review-session` subject-picker (a normal list page). A pathname
 * check can't tell those apart — both are `/dashboard/review-session`. So
 * `StudyMode` (the one component that renders the card loop in BOTH entry paths
 * — the `/dashboard/study` route AND embedded inside ReviewSession) flips this
 * flag on mount and clears it on unmount, and NavBottomTabs reads it.
 */

import { createContext, useContext, useState, useMemo, useCallback } from 'react'

const StudySessionContext = createContext(null)

export const StudySessionProvider = ({ children }) => {
  const [inStudySession, setInStudySessionState] = useState(false)
  const setInStudySession = useCallback((v) => setInStudySessionState(!!v), [])
  const value = useMemo(
    () => ({ inStudySession, setInStudySession }),
    [inStudySession, setInStudySession],
  )
  return (
    <StudySessionContext.Provider value={value}>
      {children}
    </StudySessionContext.Provider>
  )
}

/** `{ inStudySession, setInStudySession }`. Safe to call outside the provider (returns a no-op). */
// eslint-disable-next-line react-refresh/only-export-components
export const useStudySession = () => {
  const ctx = useContext(StudySessionContext)
  if (!ctx) return { inStudySession: false, setInStudySession: () => {} }
  return ctx
}
