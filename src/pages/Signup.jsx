import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function Signup() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [courseLevel, setCourseLevel] = useState('')
  const [customCourse, setCustomCourse] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { signUp } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      return
    }

    if (!courseLevel) {
      setError('Please select your course')
      return
    }

    if (courseLevel === 'Other' && !customCourse.trim()) {
      setError('Please specify your course')
      return
    }

    setLoading(true)

    try {
      // Use custom course if "Other" is selected, otherwise use selected course
      const finalCourseLevel = courseLevel === 'Other' ? customCourse : courseLevel
      
      await signUp(email, password, fullName, finalCourseLevel)
      alert('Account created! Please check your email to verify your account.')
      navigate('/login')
    } catch (err) {
      setError(err.message || 'Failed to create account')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
        {/* Logo/Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-indigo-600 mb-2">Recall</h1>
          <p className="text-gray-600">Create your account</p>
        </div>

        {/* Signup Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="fullName" className="block text-sm font-medium text-gray-700 mb-2">
              Full Name
            </label>
            <input
              id="fullName"
              type="text"
              required
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              placeholder="Rahul Kumar"
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
              Email Address
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              placeholder="your.email@example.com"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              placeholder="••••••••"
            />
            <p className="text-xs text-gray-500 mt-1">Minimum 6 characters</p>
          </div>

          <div>
            <label htmlFor="courseLevel" className="block text-sm font-medium text-gray-700 mb-2">
              Which course are you studying?
            </label>
            <select
              id="courseLevel"
              value={courseLevel}
              onChange={(e) => setCourseLevel(e.target.value)}
              required
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            >
              <option value="">Select your course...</option>
              
              {/* CA Courses */}
              <optgroup label="Chartered Accountancy (CA)">
                <option value="CA Foundation">CA Foundation</option>
                <option value="CA Intermediate">CA Intermediate</option>
                <option value="CA Final">CA Final</option>
              </optgroup>

              {/* CMA Courses */}
              <optgroup label="Cost & Management Accountant (CMA)">
                <option value="CMA Foundation">CMA Foundation</option>
                <option value="CMA Intermediate">CMA Intermediate</option>
                <option value="CMA Final">CMA Final</option>
              </optgroup>

              {/* CS Courses */}
              <optgroup label="Company Secretary (CS)">
                <option value="CS Foundation">CS Foundation</option>
                <option value="CS Executive">CS Executive</option>
                <option value="CS Professional">CS Professional</option>
              </optgroup>

              {/* Other Option */}
              <option value="Other">Other (Custom)</option>
            </select>
          </div>

          {/* Custom Course Input (shown only when "Other" is selected) */}
          {courseLevel === 'Other' && (
            <div>
              <label htmlFor="customCourse" className="block text-sm font-medium text-gray-700 mb-2">
                Specify your course
              </label>
              <input
                id="customCourse"
                type="text"
                required
                value={customCourse}
                onChange={(e) => setCustomCourse(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                placeholder="e.g., CFA Level 1, ACCA, JEE, NEET, etc."
              />
            </div>
          )}

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-indigo-600 text-white py-3 rounded-lg font-semibold hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            {loading ? 'Creating Account...' : 'Sign Up'}
          </button>
        </form>

        {/* Login Link */}
        <div className="mt-6 text-center">
          <p className="text-gray-600">
            Already have an account?{' '}
            <Link to="/login" className="text-indigo-600 font-semibold hover:text-indigo-700">
              Log in
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}