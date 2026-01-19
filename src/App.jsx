import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { Toaster } from '@/components/ui/toaster'
import { AuthProvider } from '@/contexts/AuthContext'

// Layout Components
import Navigation from '@/components/layout/Navigation'

// Auth Pages
import Login from '@/pages/auth/Login'
import Signup from '@/pages/auth/Signup'
import ForgotPassword from '@/pages/auth/ForgotPassword'
import ResetPassword from '@/pages/auth/ResetPassword'

// Main Pages
import Home from '@/pages/Home'
import Dashboard from '@/pages/Dashboard'
import TermsOfService from '@/pages/TermsOfService'
import PrivacyPolicy from '@/pages/PrivacyPolicy'

// Dashboard - Friends Pages
import FindFriends from '@/pages/dashboard/Friends/FindFriends'
import FriendRequests from '@/pages/dashboard/Friends/FriendRequests'
import MyFriends from '@/pages/dashboard/Friends/MyFriends'

// Dashboard - Content Pages
import MyNotes from '@/pages/dashboard/Content/MyNotes'
import BrowseNotes from '@/pages/dashboard/Content/BrowseNotes'
import MyContributions from '@/pages/dashboard/Content/MyContributions'

// Dashboard - Study Pages
import ReviewFlashcards from '@/pages/dashboard/Study/ReviewFlashcards'
import ReviewSession from '@/pages/dashboard/Study/ReviewSession'
import MyProgress from '@/pages/dashboard/Study/Progress'
import ReviewBySubject from '@/pages/dashboard/Study/ReviewBySubject';

// Note Components
import NoteUpload from '@/components/notes/NoteUpload'
import NoteDetail from '@/components/notes/NoteDetail'
import NoteEdit from '@/components/notes/NoteEdit'

// Flashcard Components
import FlashcardCreate from '@/components/flashcards/FlashcardCreate'
import MyFlashcards from '@/components/flashcards/MyFlashcards'
import StudyMode from '@/components/flashcards/StudyMode'

// Admin Components
import SuperAdminDashboard from '@/components/admin/SuperAdminDashboard'
import AdminDashboard from '@/components/admin/AdminDashboard'

// Professor Components
import ProfessorTools from '@/components/professor/ProfessorTools'

function App() {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })

    return () => subscription.unsubscribe()
  }, [])

  if (loading) {
    return (
      <div className="h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    )
  }

  return (
    <AuthProvider>
      <BrowserRouter>
        {session && <Navigation />}
        <Routes>
          {/* Landing Page Route */}
          <Route 
            path="/" 
            element={session ? <Navigate to="/dashboard" replace /> : <Home />} 
          />
          
          {/* Auth Routes */}
          <Route 
            path="/signup" 
            element={session ? <Navigate to="/dashboard" replace /> : <Signup />} 
          />
          <Route 
            path="/login" 
            element={session ? <Navigate to="/dashboard" replace /> : <Login />} 
          />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/reset-password" element={<ResetPassword />} />

          {/* Legal Pages */}
          <Route path="/terms-of-service" element={<TermsOfService />} />
          <Route path="/privacy-policy" element={<PrivacyPolicy />} />
          
          {/* Dashboard Route */}
          <Route
            path="/dashboard"
            element={session ? <Dashboard /> : <Navigate to="/login" replace />}
          />
          
          {/* Notes Routes */}
          <Route
            path="/dashboard/notes/new"
            element={session ? <NoteUpload /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/notes/:id"
            element={session ? <NoteDetail /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/notes"
            element={session ? <BrowseNotes /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/my-notes"
            element={session ? <MyNotes /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/notes/edit/:id" 
            element={session ? <NoteEdit /> : <Navigate to="/login" replace />}
          />
          
          {/* Flashcards Routes */}
          <Route
            path="/dashboard/flashcards/new"
            element={session ? <FlashcardCreate /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/flashcards"
            element={session ? <MyFlashcards /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/review-flashcards"
            element={session ? <ReviewFlashcards /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/review-session"
            element={session ? <ReviewSession /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/study"
            element={session ? <StudyMode /> : <Navigate to="/login" replace />}
          />
          <Route 
          path="/dashboard/review-by-subject" 
          element={<ReviewBySubject />} 
          />
          
          {/* Progress & Contributions Routes */}
          <Route
            path="/dashboard/progress"
            element={session ? <MyProgress /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/my-contributions"
            element={session ? <MyContributions /> : <Navigate to="/login" replace />}
          />
          
          {/* Friends Routes */}
          <Route 
            path="/dashboard/find-friends" 
            element={session ? <FindFriends /> : <Navigate to="/login" replace />} 
          />
          <Route 
            path="/dashboard/friend-requests" 
            element={session ? <FriendRequests /> : <Navigate to="/login" replace />} 
          />
          <Route 
            path="/dashboard/my-friends" 
            element={session ? <MyFriends /> : <Navigate to="/login" replace />} 
          />

          {/* Admin Routes */}
          <Route
            path="/super-admin"
            element={session ? <SuperAdminDashboard /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/admin"
            element={session ? <AdminDashboard /> : <Navigate to="/login" replace />}
          />

          {/* Professor Routes */}
          <Route
            path="/professor/tools"
            element={session ? <ProfessorTools /> : <Navigate to="/login" replace />}
          />
          
          {/* Catch-all Route */}
          <Route 
            path="*" 
            element={<Navigate to="/" replace />} 
          />
        </Routes>
        
        <Toaster />
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App