import { BrowserRouter, Routes, Route, Navigate, useParams } from 'react-router-dom'
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

// Dashboard - Groups Pages
import MyGroups from '@/pages/dashboard/Groups/MyGroups'
import GroupDetail from '@/pages/dashboard/Groups/GroupDetail'
import CreateGroup from '@/pages/dashboard/Groups/CreateGroup'

// Dashboard - Content Pages
import MyNotes from '@/pages/dashboard/Content/MyNotes'
import BrowseNotes from '@/pages/dashboard/Content/BrowseNotes'
import MyContributions from '@/pages/dashboard/Content/MyContributions'

// Dashboard - Study Pages
import ReviewFlashcards from '@/pages/dashboard/Study/ReviewFlashcards'
import ReviewSession from '@/pages/dashboard/Study/ReviewSession'
import MyProgress from '@/pages/dashboard/Study/Progress'
import MyAchievements from '@/pages/dashboard/Profile/MyAchievements';
import AuthorProfile from '@/pages/dashboard/Profile/AuthorProfile';
import Help from '@/pages/dashboard/Help';
import ReviewBySubject from '@/pages/dashboard/Study/ReviewBySubject';

// Dashboard - Content Pages (Notes & Flashcards)
import NoteUpload from '@/pages/dashboard/Content/NoteUpload'
import NoteDetail from '@/pages/dashboard/Content/NoteDetail'
import NoteEdit from '@/pages/dashboard/Content/NoteEdit'
import FlashcardCreate from '@/pages/dashboard/Content/FlashcardCreate'
import MyFlashcards from '@/pages/dashboard/Content/MyFlashcards'

// Dashboard - Study Pages (continued)
import StudyMode from '@/pages/dashboard/Study/StudyMode'

// Admin Pages
import SuperAdminDashboard from '@/pages/admin/SuperAdminDashboard'
import AdminDashboard from '@/pages/admin/AdminDashboard'

// Professor Pages
import ProfessorTools from '@/pages/professor/ProfessorTools'

// Legacy redirect: /notes/edit/:id → /dashboard/notes/edit/:id
function LegacyNoteEditRedirect() {
  const { id } = useParams()
  return <Navigate to={`/dashboard/notes/edit/${id}`} replace />
}

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
          {/*
            Route → File Mapping (for quick reference):
            /                              → pages/Home.jsx
            /dashboard                     → pages/Dashboard.jsx
            /dashboard/notes               → pages/dashboard/Content/BrowseNotes.jsx
            /dashboard/notes/new           → pages/dashboard/Content/NoteUpload.jsx
            /dashboard/notes/:id           → pages/dashboard/Content/NoteDetail.jsx
            /dashboard/notes/edit/:id      → pages/dashboard/Content/NoteEdit.jsx
            /dashboard/my-notes            → pages/dashboard/Content/MyNotes.jsx
            /dashboard/my-contributions    → pages/dashboard/Content/MyContributions.jsx
            /dashboard/flashcards          → pages/dashboard/Content/MyFlashcards.jsx
            /dashboard/flashcards/new      → pages/dashboard/Content/FlashcardCreate.jsx
            /dashboard/review-flashcards   → pages/dashboard/Study/ReviewFlashcards.jsx
            /dashboard/review-session      → pages/dashboard/Study/ReviewSession.jsx
            /dashboard/review-by-subject   → pages/dashboard/Study/ReviewBySubject.jsx
            /dashboard/study               → pages/dashboard/Study/StudyMode.jsx
            /dashboard/progress            → pages/dashboard/Study/Progress.jsx
            /dashboard/achievements        → pages/dashboard/Profile/MyAchievements.jsx
            /dashboard/profile/:userId     → pages/dashboard/Profile/AuthorProfile.jsx
            /dashboard/help                → pages/dashboard/Help.jsx
            /dashboard/groups              → pages/dashboard/Groups/MyGroups.jsx
            /dashboard/groups/new          → pages/dashboard/Groups/CreateGroup.jsx
            /dashboard/groups/:groupId     → pages/dashboard/Groups/GroupDetail.jsx
            /dashboard/find-friends        → pages/dashboard/Friends/FindFriends.jsx
            /dashboard/friend-requests     → pages/dashboard/Friends/FriendRequests.jsx
            /dashboard/my-friends          → pages/dashboard/Friends/MyFriends.jsx
            /super-admin                   → pages/admin/SuperAdminDashboard.jsx
            /admin                         → pages/admin/AdminDashboard.jsx
            /professor/tools               → pages/professor/ProfessorTools.jsx
          */}

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
            path="/dashboard/notes/edit/:id"
            element={session ? <NoteEdit /> : <Navigate to="/login" replace />}
          />
          {/* Legacy redirect for old /notes/edit/:id bookmarks */}
          <Route
            path="/notes/edit/:id"
            element={<LegacyNoteEditRedirect />}
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
          <Route
          path="/dashboard/achievements"
          element={<MyAchievements />}
          />
          <Route
            path="/dashboard/profile/:userId"
            element={session ? <AuthorProfile /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/help"
            element={session ? <Help /> : <Navigate to="/login" replace />}
          />
          
          {/* Groups Routes */}
          <Route
            path="/dashboard/groups"
            element={session ? <MyGroups /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/groups/new"
            element={session ? <CreateGroup /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/groups/:groupId"
            element={session ? <GroupDetail /> : <Navigate to="/login" replace />}
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