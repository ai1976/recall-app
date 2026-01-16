import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import Login from './components/Login'
import Dashboard from './pages/Dashboard';
import NoteUpload from './components/notes/NoteUpload'
import NoteDetail from './components/notes/NoteDetail'
import FlashcardCreate from './components/flashcards/FlashcardCreate'
import MyFlashcards from './components/flashcards/MyFlashcards'
import StudyMode from './components/flashcards/StudyMode'
import { Toaster } from './components/ui/toaster'
import NoteEdit from './components/notes/NoteEdit'
import Navigation from './components/Navigation'
import SuperAdminDashboard from './components/admin/SuperAdminDashboard'
import AdminDashboard from './components/admin/AdminDashboard'
import ProfessorTools from './components/professor/ProfessorTools'
import { AuthProvider } from './contexts/AuthContext'
import BrowseNotes from '@/pages/dashboard/notes'
import MyProgress from '@/pages/dashboard/progress'
import MyContributions from '@/pages/dashboard/my-contributions'
import Home from './pages/Home'
import Signup from './pages/Signup'
import MyNotes from './pages/dashboard/my-notes';
import ForgotPassword from './pages/ForgotPassword'
import ResetPassword from './pages/ResetPassword'
import ReviewFlashcards from './pages/dashboard/review-flashcards'
import TermsOfService from './pages/TermsOfService';
import PrivacyPolicy from './pages/PrivacyPolicy';
import ReviewSession from '@/pages/dashboard/review-session';
import FindFriends from './pages/dashboard/find-friends';
import FriendRequests from './pages/dashboard/friend-requests';
import MyFriends from './pages/dashboard/my-friends';

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
          
          {/* Signup Route */}
          <Route 
            path="/signup" 
            element={session ? <Navigate to="/dashboard" replace /> : <Signup />} 
          />

          {/* Password Reset Routes */}
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/reset-password" element={<ResetPassword />} />
          
          {/* Login Route */}
          <Route 
            path="/login" 
            element={session ? <Navigate to="/dashboard" replace /> : <Login />} 
          />

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
          
          {/* Review Flashcards Route - NEW */}
          <Route
            path="/dashboard/review-flashcards"
            element={session ? <ReviewFlashcards /> : <Navigate to="/login" replace />}
          />
          
          {/* Review Session Route - Due Cards Only */}
<Route
  path="/dashboard/review-session"
  element={session ? <ReviewSession /> : <Navigate to="/login" replace />}
/>

          <Route
            path="/dashboard/study"
            element={session ? <StudyMode /> : <Navigate to="/login" replace />}
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

          {/* FindFriends Routes */}
          <Route 
          path="/dashboard/find-friends" 
          element={<FindFriends />} 
          />

          {/* FriendRequests Routes */}
          <Route 
          path="/dashboard/friend-requests" 
          element={<FriendRequests />} 
          />

          {/* MyFriends Routes */}
<Route 
path="/dashboard/my-friends" 
element={<MyFriends />} 
/>

        </Routes>
        
        <Toaster />
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App