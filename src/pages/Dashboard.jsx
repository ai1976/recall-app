import { useAuth } from '../lib/AuthContext'
import { useNavigate } from 'react-router-dom'

export default function Dashboard() {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()

  const handleSignOut = async () => {
    try {
      await signOut()
      navigate('/login')
    } catch (error) {
      alert('Error signing out')
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8 flex justify-between items-center">
          <h1 className="text-3xl font-bold text-indigo-600">Recall</h1>
          <button
            onClick={handleSignOut}
            className="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition"
          >
            Sign Out
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        <div className="bg-white rounded-lg shadow p-8">
          <h2 className="text-2xl font-bold text-gray-800 mb-4">
            Welcome, {user?.user_metadata?.full_name || user?.email}! 🎉
          </h2>
          <p className="text-gray-600 mb-6">
            Your dashboard is ready! We'll add note upload, flashcards, and review features next.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Stats Cards */}
            <div className="bg-indigo-50 p-6 rounded-lg border border-indigo-100">
              <h3 className="text-lg font-semibold text-indigo-900 mb-2">Notes Uploaded</h3>
              <p className="text-3xl font-bold text-indigo-600">0</p>
            </div>

            <div className="bg-green-50 p-6 rounded-lg border border-green-100">
              <h3 className="text-lg font-semibold text-green-900 mb-2">Flashcards Created</h3>
              <p className="text-3xl font-bold text-green-600">0</p>
            </div>

            <div className="bg-purple-50 p-6 rounded-lg border border-purple-100">
              <h3 className="text-lg font-semibold text-purple-900 mb-2">Study Streak</h3>
              <p className="text-3xl font-bold text-purple-600">0 days</p>
            </div>
          </div>

          <div className="mt-8 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <p className="text-blue-800">
              <strong>Coming soon:</strong> Note upload, OCR text extraction, flashcard creation, and spaced repetition review system!
            </p>
          </div>
        </div>
      </main>
    </div>
  )
}