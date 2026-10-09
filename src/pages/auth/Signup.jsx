import { useState, useEffect } from 'react';
import { useNavigate, Link, useSearchParams } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { validateCourseLabel } from '@/lib/courseLabel';
import { OTHER_OPTION } from '@/lib/courseOptions';
import { useCourseOptions } from '@/hooks/useCourseOptions';

export default function Signup() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [courseLevel, setCourseLevel] = useState('');
  const [customCourse, setCustomCourse] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [alreadyRegistered, setAlreadyRegistered] = useState(false);
  const { signUp } = useAuth();
  // The course list is the database's public catalogue (T-002 F1): active platform courses, then the CMA and CS labels, in the database's order.
  const courseList = useCourseOptions('signup');
  const allCourses = courseList.rows.filter((row) => row.kind === 'platform' || row.kind === 'catalogue').map((row) => row.label);
  const otherRow = courseList.rows.find((row) => row.kind === 'other_action');
  const coursesReady = courseList.status === 'ready';
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  useEffect(() => {
    // Preserve ref token from invite link so Dashboard can link it after login.
    // This is a write-only point (the key is read in Dashboard.jsx, where the
    // recall_* → revisop_* migrate-on-mount lives) — just write the new key here.
    const ref = searchParams.get('ref');
    if (ref) localStorage.setItem('revisop_access_ref', ref);
  }, []);

  // Shown while typing, before submit: the same rule the database applies (an empty box is reported by the form on submit).
  const customCourseError = courseLevel === OTHER_OPTION && customCourse !== '' && !validateCourseLabel(customCourse).ok
    ? validateCourseLabel(customCourse).error
    : '';

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setAlreadyRegistered(false);

    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    if (!coursesReady) {
      setError('The course list could not be loaded. Please refresh the page and try again.');
      return;
    }

    if (!courseLevel) {
      setError('Please select your course');
      return;
    }

    let customCourseValue = null;
    if (courseLevel === OTHER_OPTION) {
      const check = validateCourseLabel(customCourse);
      if (!check.ok) {
        setError(check.error);
        return;
      }
      customCourseValue = check.value;
    }

    setLoading(true);

    try {
      const finalCourseLevel = courseLevel === OTHER_OPTION ? customCourseValue : courseLevel;
      
      const result = await signUp(email, password, fullName, finalCourseLevel);

      // Supabase deliberately returns a success-shaped response for an email that is already
      // registered (anti-enumeration) and sends NO email — the only tell is an empty
      // `identities` array. Without this check the student is told to wait for a mail that
      // will never arrive (Sairaj Kandhare, 29/09/2026).
      if (result?.user && Array.isArray(result.user.identities) && result.user.identities.length === 0) {
        setAlreadyRegistered(true);
        return;
      }

      alert(
        '🎉 Account Created Successfully!\n\n' +
        '📧 Verification Email Sent\n\n' +
        'We\'ve sent a verification link to:\n' + email + '\n\n' +
        '⏰ Please allow 5-10 minutes for the email to arrive.\n\n' +
        '💡 Tip: Check your spam/junk folder if you don\'t see it.\n\n' +
        'You can now go to the login page.'
      );
      
      navigate('/login');
    } catch (err) {
      setError(err.message || 'Failed to create account');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-2">
            <h1 className="text-4xl font-bold tracking-tight leading-none">
              <span style={{ color: '#f59e0b' }}>Revis</span><span style={{ color: '#1e1b4b' }}>Op</span>
            </h1>
          </div>
          <p className="text-gray-600">Create your account</p>
        </div>

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
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-400 focus:border-transparent"
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
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-400 focus:border-transparent"
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
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-400 focus:border-transparent"
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
              disabled={!coursesReady}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-400 focus:border-transparent"
            >
              <option value="">{courseList.status === 'error' ? 'Courses could not be loaded' : 'Select your course...'}</option>
              
              {/* The database's order, as served (T-002 F1): no list or grouping of our own. */}
              {allCourses.map((course) => (
                <option key={course} value={course}>
                  {course}
                </option>
              ))}

              {otherRow && <option value={OTHER_OPTION}>+ Add custom course</option>}
            </select>
            <p className="text-xs text-gray-500 mt-1">
              Don't see your course? Select "Add custom course"
            </p>
            {courseList.status === 'error' && (
              <p role="alert" className="text-xs text-red-600 mt-1">
                The course list could not be loaded. <button type="button" onClick={courseList.reload} className="underline">Try again</button>
              </p>
            )}
          </div>

          {courseLevel === OTHER_OPTION && (
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
                aria-invalid={customCourseError ? 'true' : 'false'}
                aria-describedby={customCourseError ? 'customCourseError' : undefined}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-400 focus:border-transparent"
                placeholder="e.g., CFA Level 1, ACCA, JEE, NEET, MSc Economics, etc."
              />
              {customCourseError && (
                <p id="customCourseError" role="alert" className="text-xs text-red-600 mt-1">{customCourseError}</p>
              )}
              <p className="text-xs text-gray-500 mt-1">
                This course will be saved and available for future users
              </p>
            </div>
          )}

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
              {error}
            </div>
          )}

          {alreadyRegistered && (
            <div className="bg-amber-50 border border-amber-200 text-amber-900 px-4 py-3 rounded-lg text-sm">
              <p className="font-semibold mb-1">This email is already registered.</p>
              <p>
                No new email was sent because an account already exists for {email}.{' '}
                <Link to="/login" className="font-semibold underline">Log in</Link>
                {' '}or{' '}
                <Link to="/forgot-password" className="font-semibold underline">reset your password</Link>.
              </p>
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#1e1b4b] text-white py-3 rounded-lg font-semibold hover:bg-[#2d2a6e] disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            {loading ? 'Creating Account...' : 'Sign Up'}
          </button>
        </form>

        <div className="mt-6 text-center">
          <p className="text-gray-600">
            Already have an account?{' '}
            <Link to="/login" className="text-amber-600 font-semibold hover:text-amber-700">
              Log in
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}