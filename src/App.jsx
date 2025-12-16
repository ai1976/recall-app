import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import Login from './components/Login'
import Dashboard from './components/Dashboard'
import NoteUpload from './components/notes/NoteUpload'
import NoteDetail from './components/notes/NoteDetail'
import FlashcardCreate from './components/flashcards/FlashcardCreate'
import MyFlashcards from './components/flashcards/MyFlashcards'
import StudyMode from './components/flashcards/StudyMode'
import { Toaster } from './components/ui/toaster'
import NoteEdit from './components/notes/NoteEdit';
import Navigation from './components/Navigation'
import SuperAdminDashboard from './components/admin/SuperAdminDashboard'
import AdminDashboard from './components/admin/AdminDashboard'
import ProfessorTools from './components/professor/ProfessorTools'
import { AuthProvider } from './contexts/AuthContext'
import BrowseNotes from '@/pages/dashboard/notes';
import MyProgress from '@/pages/dashboard/progress';
import MyContributions from '@/pages/dashboard/my-contributions';

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
          <Route 
            path="/login" 
            element={session ? <Navigate to="/dashboard" replace /> : <Login />} 
          />
          
          <Route
            path="/dashboard"
            element={session ? <Dashboard /> : <Navigate to="/login" replace />}
          />
          
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
            path="/dashboard/flashcards/new"
            element={session ? <FlashcardCreate /> : <Navigate to="/login" replace />}
          />
          
          <Route
            path="/dashboard/flashcards"
            element={session ? <MyFlashcards /> : <Navigate to="/login" replace />}
          />
          
          <Route
            path="/dashboard/study"
            element={session ? <StudyMode /> : <Navigate to="/login" replace />}
          />
          
          <Route
            path="/dashboard/progress"
            element={session ? <MyProgress /> : <Navigate to="/login" replace />}
          />
          
          <Route
            path="/dashboard/my-contributions"
            element={session ? <MyContributions /> : <Navigate to="/login" replace />}
          />
          
          <Route
            path="/super-admin"
            element={session ? <SuperAdminDashboard /> : <Navigate to="/login" replace />}
          />

          <Route
            path="/admin"
            element={session ? <AdminDashboard /> : <Navigate to="/login" replace />}
          />

          <Route
            path="/professor/tools"
            element={session ? <ProfessorTools /> : <Navigate to="/login" replace />}
          />

          <Route 
            path="/notes/edit/:id" 
            element={session ? <NoteEdit /> : <Navigate to="/login" replace />}
          />
          
          <Route 
            path="/" 
            element={<Navigate to={session ? "/dashboard" : "/login"} replace />} 
          />
          
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