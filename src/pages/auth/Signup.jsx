import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';

export default function Signup() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [courseLevel, setCourseLevel] = useState('');
  const [customCourse, setCustomCourse] = useState('');
  const [allCourses, setAllCourses] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { signUp } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    fetchAllCourses();
  }, []);

  const fetchAllCourses = async () => {
    try {
      const { data: noteCourses, error: noteError } = await supabase
        .from('notes')
        .select('target_course')
        .not('target_course', 'is', null);

      const { data: flashcardCourses, error: flashError } = await supabase
        .from('flashcards')
        .select('target_course')
        .not('target_course', 'is', null);

      const { data: profileCourses, error: profileError } = await supabase
        .from('profiles')
        .select('course_level')
        .not('course_level', 'is', null);

      if (noteError) throw noteError;
      if (flashError) throw flashError;
      if (profileError) throw profileError;

      const predefinedCourses = [
        'CA Foundation',
        'CA Intermediate',
        'CA Final',
        'CMA Foundation',
        'CMA Intermediate',
        'CMA Final',
        'CS Foundation',
        'CS Executive',
        'CS Professional'
      ];

      const customFromNotes = noteCourses?.map(n => n.target_course) || [];
      const customFromFlashcards = flashcardCourses?.map(f => f.target_course) || [];
      const customFromProfiles = profileCourses?.map(p => p.course_level) || [];
      
      const allCustomCourses = [...new Set([
        ...customFromNotes, 
        ...customFromFlashcards,
        ...customFromProfiles
      ])];

      const uniqueCustomCourses = allCustomCourses.filter(
        course => !predefinedCourses.includes(course)
      );

      const mergedCourses = [...predefinedCourses, ...uniqueCustomCourses.sort()];

      setAllCourses(mergedCourses);
    } catch (error) {
      console.error('Error fetching courses:', error);
      setAllCourses([
        'CA Foundation',
        'CA Intermediate',
        'CA Final',
        'CMA Foundation',
        'CMA Intermediate',
        'CMA Final',
        'CS Foundation',
        'CS Executive',
        'CS Professional'
      ]);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    if (!courseLevel) {
      setError('Please select your course');
      return;
    }

    if (courseLevel === 'Other' && !customCourse.trim()) {
      setError('Please specify your course');
      return;
    }

    setLoading(true);

    try {
      const finalCourseLevel = courseLevel === 'Other' ? customCourse : courseLevel;
      
      await signUp(email, password, fullName, finalCourseLevel);
      
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
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-indigo-600 mb-2">Recall</h1>
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
              
              <optgroup label="Chartered Accountancy (CA)">
                {allCourses
                  .filter(course => course.startsWith('CA '))
                  .map(course => (
                    <option key={course} value={course}>
                      {course}
                    </option>
                  ))
                }
              </optgroup>

              <optgroup label="Cost & Management Accountant (CMA)">
                {allCourses
                  .filter(course => course.startsWith('CMA '))
                  .map(course => (
                    <option key={course} value={course}>
                      {course}
                    </option>
                  ))
                }
              </optgroup>

              <optgroup label="Company Secretary (CS)">
                {allCourses
                  .filter(course => course.startsWith('CS '))
                  .map(course => (
                    <option key={course} value={course}>
                      {course}
                    </option>
                  ))
                }
              </optgroup>

              {allCourses.some(course => 
                !course.startsWith('CA ') && 
                !course.startsWith('CMA ') && 
                !course.startsWith('CS ')
              ) && (
                <optgroup label="Other Courses">
                  {allCourses
                    .filter(course => 
                      !course.startsWith('CA ') && 
                      !course.startsWith('CMA ') && 
                      !course.startsWith('CS ')
                    )
                    .map(course => (
                      <option key={course} value={course}>
                        {course}
                      </option>
                    ))
                  }
                </optgroup>
              )}

              <option value="Other">+ Add custom course</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              Don't see your course? Select "Add custom course"
            </p>
          </div>

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
                placeholder="e.g., CFA Level 1, ACCA, JEE, NEET, MSc Economics, etc."
              />
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

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-indigo-600 text-white py-3 rounded-lg font-semibold hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            {loading ? 'Creating Account...' : 'Sign Up'}
          </button>
        </form>

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
  );
}