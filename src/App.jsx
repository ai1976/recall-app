import { Suspense, lazy } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useParams } from 'react-router-dom'
import { Toaster } from '@/components/ui/toaster'
import { AuthProvider, useAuth } from '@/contexts/AuthContext'
import { CourseContextProvider } from '@/contexts/CourseContext'

// Layout Components (not lazy — part of the app shell, needed immediately)
import Navigation from '@/components/layout/Navigation'

// Auth Pages
const Login = lazy(() => import('@/pages/auth/Login'))
const Signup = lazy(() => import('@/pages/auth/Signup'))
const ForgotPassword = lazy(() => import('@/pages/auth/ForgotPassword'))
const ResetPassword = lazy(() => import('@/pages/auth/ResetPassword'))

// Main Pages
const Home = lazy(() => import('@/pages/Home'))
const Dashboard = lazy(() => import('@/pages/Dashboard'))
const TermsOfService = lazy(() => import('@/pages/TermsOfService'))
const PrivacyPolicy = lazy(() => import('@/pages/PrivacyPolicy'))

// Dashboard - Friends Pages
const FindFriends = lazy(() => import('@/pages/dashboard/Friends/FindFriends'))
const FriendRequests = lazy(() => import('@/pages/dashboard/Friends/FriendRequests'))
const MyFriends = lazy(() => import('@/pages/dashboard/Friends/MyFriends'))

// Dashboard - Groups Pages
const MyGroups = lazy(() => import('@/pages/dashboard/Groups/MyGroups'))
const GroupDetail = lazy(() => import('@/pages/dashboard/Groups/GroupDetail'))
const CreateGroup = lazy(() => import('@/pages/dashboard/Groups/CreateGroup'))

// Dashboard - Content Pages
const MyNotes = lazy(() => import('@/pages/dashboard/Content/MyNotes'))
const BrowseNotes = lazy(() => import('@/pages/dashboard/Content/BrowseNotes'))
const MyContributions = lazy(() => import('@/pages/dashboard/Content/MyContributions'))
const NoteUpload = lazy(() => import('@/pages/dashboard/Content/NoteUpload'))
const NoteDetail = lazy(() => import('@/pages/dashboard/Content/NoteDetail'))
const NoteEdit = lazy(() => import('@/pages/dashboard/Content/NoteEdit'))
const FlashcardCreate = lazy(() => import('@/pages/dashboard/Content/FlashcardCreate'))
const MyFlashcards = lazy(() => import('@/pages/dashboard/Content/MyFlashcards'))

// Dashboard - Study Pages
const ReviewFlashcards = lazy(() => import('@/pages/dashboard/Study/ReviewFlashcards'))
const ReviewSession = lazy(() => import('@/pages/dashboard/Study/ReviewSession'))
const MyProgress = lazy(() => import('@/pages/dashboard/Study/Progress'))
const ReviewBySubject = lazy(() => import('@/pages/dashboard/Study/ReviewBySubject'))
const StudyMode = lazy(() => import('@/pages/dashboard/Study/StudyMode'))

// Dashboard - Profile Pages
const MyAchievements = lazy(() => import('@/pages/dashboard/Profile/MyAchievements'))
const AuthorProfile = lazy(() => import('@/pages/dashboard/Profile/AuthorProfile'))
const ProfileSettings = lazy(() => import('@/pages/dashboard/Profile/ProfileSettings'))

// Dashboard - Other
const Help = lazy(() => import('@/pages/dashboard/Help'))
const BulkUploadFlashcards = lazy(() => import('@/pages/dashboard/BulkUploadFlashcards'))

// Admin Pages
const SuperAdminDashboard = lazy(() => import('@/pages/admin/SuperAdminDashboard'))
const AdminDashboard = lazy(() => import('@/pages/admin/AdminDashboard'))
const MigrateNoteImages = lazy(() => import('@/pages/admin/MigrateNoteImages')) // TEMP — delete after migration
const BulkUploadTopics = lazy(() => import('@/pages/admin/BulkUploadTopics'))

const PageLoader = () => (
  <div className="h-screen flex items-center justify-center">
    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
  </div>
)

// Legacy redirect: /notes/edit/:id → /dashboard/notes/edit/:id
function LegacyNoteEditRedirect() {
  const { id } = useParams()
  return <Navigate to={`/dashboard/notes/edit/${id}`} replace />
}

// Routing lives inside AuthProvider so it can read auth state via useAuth()
// This eliminates the duplicate getSession() call that was in the old App component
function AppContent() {
  const { user, loading } = useAuth()

  if (loading) return <PageLoader />

  return (
    <>
      {user && <Navigation />}
      <Suspense fallback={<PageLoader />}>
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
            /dashboard/settings            → pages/dashboard/Profile/ProfileSettings.jsx
            /dashboard/help                → pages/dashboard/Help.jsx
            /dashboard/groups              → pages/dashboard/Groups/MyGroups.jsx
            /dashboard/groups/new          → pages/dashboard/Groups/CreateGroup.jsx
            /dashboard/groups/:groupId     → pages/dashboard/Groups/GroupDetail.jsx
            /dashboard/find-friends        → pages/dashboard/Friends/FindFriends.jsx
            /dashboard/friend-requests     → pages/dashboard/Friends/FriendRequests.jsx
            /dashboard/my-friends          → pages/dashboard/Friends/MyFriends.jsx
            /super-admin                   → pages/admin/SuperAdminDashboard.jsx
            /admin                         → pages/admin/AdminDashboard.jsx
            /professor/tools               → (redirects to /dashboard/bulk-upload)
            /dashboard/bulk-upload         → pages/dashboard/BulkUploadFlashcards.jsx
            /admin/bulk-upload-topics      → pages/admin/BulkUploadTopics.jsx
          */}

          {/* Landing Page Route */}
          <Route
            path="/"
            element={user ? <Navigate to="/dashboard" replace /> : <Home />}
          />

          {/* Auth Routes */}
          <Route
            path="/signup"
            element={user ? <Navigate to="/dashboard" replace /> : <Signup />}
          />
          <Route
            path="/login"
            element={user ? <Navigate to="/dashboard" replace /> : <Login />}
          />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/reset-password" element={<ResetPassword />} />

          {/* Legal Pages */}
          <Route path="/terms-of-service" element={<TermsOfService />} />
          <Route path="/privacy-policy" element={<PrivacyPolicy />} />

          {/* Dashboard Route */}
          <Route
            path="/dashboard"
            element={user ? <Dashboard /> : <Navigate to="/login" replace />}
          />

          {/* Notes Routes */}
          <Route
            path="/dashboard/notes/new"
            element={user ? <NoteUpload /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/notes/:id"
            element={user ? <NoteDetail /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/notes"
            element={user ? <BrowseNotes /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/my-notes"
            element={user ? <MyNotes /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/notes/edit/:id"
            element={user ? <NoteEdit /> : <Navigate to="/login" replace />}
          />
          {/* Legacy redirect for old /notes/edit/:id bookmarks */}
          <Route
            path="/notes/edit/:id"
            element={<LegacyNoteEditRedirect />}
          />

          {/* Flashcards Routes */}
          <Route
            path="/dashboard/flashcards/new"
            element={user ? <FlashcardCreate /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/flashcards"
            element={user ? <MyFlashcards /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/review-flashcards"
            element={user ? <ReviewFlashcards /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/review-session"
            element={user ? <ReviewSession /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/study"
            element={user ? <StudyMode /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/review-by-subject"
            element={<ReviewBySubject />}
          />

          {/* Progress & Contributions Routes */}
          <Route
            path="/dashboard/progress"
            element={user ? <MyProgress /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/my-contributions"
            element={user ? <MyContributions /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/achievements"
            element={<MyAchievements />}
          />
          <Route
            path="/dashboard/profile/:userId"
            element={user ? <AuthorProfile /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/settings"
            element={user ? <ProfileSettings /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/help"
            element={user ? <Help /> : <Navigate to="/login" replace />}
          />

          {/* Groups Routes */}
          <Route
            path="/dashboard/groups"
            element={user ? <MyGroups /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/groups/new"
            element={user ? <CreateGroup /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/groups/:groupId"
            element={user ? <GroupDetail /> : <Navigate to="/login" replace />}
          />

          {/* Friends Routes */}
          <Route
            path="/dashboard/find-friends"
            element={user ? <FindFriends /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/friend-requests"
            element={user ? <FriendRequests /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/dashboard/my-friends"
            element={user ? <MyFriends /> : <Navigate to="/login" replace />}
          />

          {/* Admin Routes */}
          <Route
            path="/super-admin"
            element={user ? <SuperAdminDashboard /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/admin"
            element={user ? <AdminDashboard /> : <Navigate to="/login" replace />}
          />

          {/* Bulk Upload Routes */}
          <Route
            path="/dashboard/bulk-upload"
            element={user ? <BulkUploadFlashcards /> : <Navigate to="/login" replace />}
          />
          <Route
            path="/admin/bulk-upload-topics"
            element={user ? <BulkUploadTopics /> : <Navigate to="/login" replace />}
          />
          {/* TEMP migration route — remove after use */}
          <Route
            path="/admin/migrate-note-images"
            element={user ? <MigrateNoteImages /> : <Navigate to="/login" replace />}
          />

          {/* Professor Routes (legacy redirect) */}
          <Route
            path="/professor/tools"
            element={user ? <Navigate to="/dashboard/bulk-upload" replace /> : <Navigate to="/login" replace />}
          />

          {/* Catch-all Route */}
          <Route
            path="*"
            element={<Navigate to="/" replace />}
          />
        </Routes>
      </Suspense>

      <Toaster />
    </>
  )
}

function App() {
  return (
    <AuthProvider>
      <CourseContextProvider>
        <BrowserRouter>
          <AppContent />
        </BrowserRouter>
      </CourseContextProvider>
    </AuthProvider>
  )
}

export default App
