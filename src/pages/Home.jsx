import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Brain, Users, TrendingUp, CheckCircle, BookOpen, Award, Zap, Upload, Share2, Camera } from 'lucide-react';
import { supabase } from '../lib/supabase';

export default function Home() {
  // Real-time stats from database
  const [stats, setStats] = useState({
    students: 0,
    educators: 0,
    flashcards: 0,
    notes: 0,
    isLoading: true
  });

  // Store educator data for display
  const [educators, setEducators] = useState([]);
  
  // Fetch real data when page loads
  useEffect(() => {
    async function fetchStats() {
      try {
        // Count students
        const { count: studentCount } = await supabase
          .from('profiles')
          .select('*', { count: 'exact', head: true })
          .eq('role', 'student');
        
        // Count educators (professors)
        const { count: educatorCount } = await supabase
          .from('profiles')
          .select('*', { count: 'exact', head: true })
          .eq('role', 'professor');

        // Fetch educator profiles for display
        const { data: educatorData } = await supabase
          .from('profiles')
          .select('id, full_name, role')
          .eq('role', 'professor')
          .order('created_at', { ascending: true })
          .limit(3);
        
        if (educatorData && educatorData.length > 0) {
          setEducators(educatorData);
        }
        
        // Count public flashcards
        const { count: flashcardCount } = await supabase
          .from('flashcards')
          .select('*', { count: 'exact', head: true })
          .eq('is_public', true);
        
        // Count public notes
        const { count: noteCount } = await supabase
          .from('notes')
          .select('*', { count: 'exact', head: true })
          .eq('is_public', true);
        
        setStats({
          students: studentCount || 0,
          educators: educatorCount || 0,
          flashcards: flashcardCount || 0,
          notes: noteCount || 0,
          isLoading: false
        });
        
      } catch (err) {
        console.error('Error fetching stats:', err);
        setStats({
          students: 0,
          educators: 0,
          flashcards: 0,
          notes: 0,
          isLoading: false
        });
      }
    }
    
    fetchStats();
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      {/* Navigation */}
      <nav className="bg-white shadow-sm sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            {/* Logo */}
            <div className="flex items-center space-x-2">
              <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold text-xl px-3 py-1 rounded">
                R
              </div>
              <span className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                Recall
              </span>
            </div>

            {/* Nav Links */}
            <div className="hidden md:flex items-center space-x-6">
              <a href="#features" className="text-gray-700 hover:text-blue-600 transition">Features</a>
              <a href="#how-it-works" className="text-gray-700 hover:text-blue-600 transition">How It Works</a>
              <a href="#educators" className="text-gray-700 hover:text-blue-600 transition">For Educators</a>
              <Link to="/login" className="text-gray-700 hover:text-blue-600 transition">Login</Link>
              <Link 
                to="/signup" 
                className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-2 rounded-lg hover:shadow-lg transition"
              >
                Get Started Free
              </Link>
            </div>

            {/* Mobile Menu Button */}
            <div className="md:hidden">
              <Link 
                to="/signup" 
                className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-4 py-2 rounded-lg text-sm"
              >
                Sign Up
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
        <div className="max-w-4xl mx-auto">
          {/* Badge - Platform positioning */}
          <div className="inline-flex items-center space-x-2 bg-blue-100 text-blue-800 px-4 py-2 rounded-full mb-6">
            <Users className="h-4 w-4" />
            <span className="text-sm font-semibold">
              {stats.isLoading ? (
                'Join Our Growing Community'
              ) : (
                `Trusted by ${stats.students} Student${stats.students !== 1 ? 's' : ''} & ${stats.educators} Expert${stats.educators !== 1 ? 's' : ''}`
              )}
            </span>
          </div>

          {/* Main Headline - Catchy + Platform-first */}
          <h1 className="text-5xl md:text-6xl font-bold text-gray-900 mb-6 leading-tight">
            Remember Everything.
            <br />
            <span className="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              Ace Every Exam.
            </span>
          </h1>

          {/* Subheadline - Better sequencing */}
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Upload your handwritten notes. Create flashcards. Review with spaced repetition. 
            Build your personal study library. Share with peers.
          </p>

          {/* Social Proof - Platform activity */}
          <div className="flex flex-col sm:flex-row justify-center items-center space-y-4 sm:space-y-0 sm:space-x-8 mb-10">
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">Free to get started</span>
            </div>
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">Upload unlimited notes</span>
            </div>
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">
                {stats.isLoading ? 'Active community' : `${stats.flashcards + stats.notes}+ items shared`}
              </span>
            </div>
          </div>

          {/* Single CTA Button */}
          <div className="flex justify-center mb-4">
            <Link 
              to="/signup" 
              className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              Start Building Your Library
            </Link>
          </div>

          {/* Educator contact link below CTA */}
          <p className="text-gray-600 text-sm">
            Are you an educator?{' '}
            <a 
              href="mailto:recall@moreclassescommerce.com?subject=Interested in Contributing to Recall&body=Hi, I'm interested in becoming a contributing educator for Recall. Please send me more details.%0D%0A%0D%0AMy name: %0D%0AMy subject expertise: %0D%0AMy institution: %0D%0AMy contact number: "
              className="text-blue-600 hover:underline font-medium"
            >
              Join as a contributor
            </a>
          </p>

          {/* Real-time Stats */}
          <div className="mt-16 grid grid-cols-2 md:grid-cols-4 gap-8 max-w-3xl mx-auto">
            <div>
              <div className="text-4xl font-bold text-blue-600">
                {stats.students}
              </div>
              <div className="text-gray-600 mt-2">Active Students</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-purple-600">
                {stats.educators}
              </div>
              <div className="text-gray-600 mt-2">Expert Educators</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-green-600">
                {stats.flashcards}
              </div>
              <div className="text-gray-600 mt-2">Flashcards</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-orange-600">
                {stats.notes}
              </div>
              <div className="text-gray-600 mt-2">Notes</div>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works Section - Platform journey */}
      <section id="how-it-works" className="bg-white py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Get Started in 4 Simple Steps
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Your personal study library in under 10 minutes
            </p>
          </div>

          <div className="grid md:grid-cols-4 gap-8">
            {/* Step 1 - Upload */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-blue-600 to-blue-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <Camera className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                1. Upload Your Notes
              </h3>
              <p className="text-gray-600">
                Scan handwritten notes with your phone camera. We'll digitize them automatically.
              </p>
            </div>

            {/* Step 2 - Create (IMPROVED WORDING) */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-purple-600 to-purple-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <BookOpen className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                2. Create Flashcards
              </h3>
              <p className="text-gray-600">
                Create flashcards from your uploaded notes, or make standalone topic-specific cards. 
                Manual creation or bulk CSV upload.
              </p>
            </div>

            {/* Step 3 - Review */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-green-600 to-green-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <Brain className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                3. Smart Reviews
              </h3>
              <p className="text-gray-600">
                Review with spaced repetition. 5-10 minutes daily. Never forget what you learned.
              </p>
            </div>

            {/* Step 4 - Share (moved to last) */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-orange-600 to-orange-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <Share2 className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                4. Share with Peers
              </h3>
              <p className="text-gray-600">
                Make your notes public or keep them private. Help classmates while you study.
              </p>
            </div>
          </div>

          {/* Quick Start CTA */}
          <div className="text-center mt-12">
            <Link 
              to="/signup" 
              className="inline-flex items-center space-x-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              <Zap className="h-5 w-5" />
              <span>Create Your First Flashcard</span>
            </Link>
            <p className="text-gray-600 mt-3">No credit card required • Free forever</p>
          </div>
        </div>
      </section>

      {/* Features Section - Platform capabilities */}
      <section id="features" className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Everything You Need to Build Your Library
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Powerful tools for creating, organizing, and sharing your study materials
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {/* Feature 1 - Note Upload */}
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-blue-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <Upload className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Upload & Digitize Notes
              </h3>
              <p className="text-gray-600 mb-4">
                Scan your handwritten notes with your phone. We extract text automatically with OCR.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Photo upload from phone</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">PDF document support</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Automatic text extraction</span>
                </li>
              </ul>
            </div>

            {/* Feature 2 - Flashcard Creation */}
            <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-purple-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <BookOpen className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Create Unlimited Flashcards
              </h3>
              <p className="text-gray-600 mb-4">
                Create flashcards from notes or as standalone cards. Manual creation or bulk CSV upload.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Note-linked flashcards</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Standalone topic cards</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Bulk CSV upload</span>
                </li>
              </ul>
            </div>

            {/* Feature 3 - Spaced Repetition */}
            <div className="bg-gradient-to-br from-green-50 to-teal-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-green-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <Brain className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Smart Spaced Repetition
              </h3>
              <p className="text-gray-600 mb-4">
                Review at optimal intervals. Boost retention by 80% with proven science.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">SuperMemo-2 algorithm</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Auto review scheduling</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Track study streaks</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Bonus: Educator Content Section */}
      <section className="bg-blue-50 py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="max-w-3xl mx-auto text-center">
            <div className="inline-flex items-center space-x-2 bg-blue-200 text-blue-900 px-4 py-2 rounded-full mb-6">
              <Award className="h-4 w-4" />
              <span className="text-sm font-semibold">Bonus: Get Started Faster</span>
            </div>
            
            <h2 className="text-3xl font-bold text-gray-900 mb-4">
              Don't Have Notes Yet?
            </h2>
            <p className="text-xl text-gray-600 mb-8">
              Start reviewing {stats.flashcards > 0 ? stats.flashcards : 'expert'} educator-verified flashcards 
              while you build your own library. Quality content from Day 1.
            </p>
            
            <div className="bg-white p-8 rounded-xl shadow-sm">
              <div className="grid md:grid-cols-3 gap-6 mb-6">
                <div>
                  <div className="text-3xl font-bold text-blue-600 mb-2">
                    {stats.educators}
                  </div>
                  <div className="text-gray-600">Expert Educators</div>
                </div>
                <div>
                  <div className="text-3xl font-bold text-purple-600 mb-2">
                    {stats.flashcards}
                  </div>
                  <div className="text-gray-600">Verified Flashcards</div>
                </div>
                <div>
                  <div className="text-3xl font-bold text-green-600 mb-2">
                    {stats.notes}
                  </div>
                  <div className="text-gray-600">Study Notes</div>
                </div>
              </div>
              
              <p className="text-gray-600 italic">
                "Review educator content → Get inspired → Upload your own notes → 
                Become a contributor → Help peers learn"
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* For Educators Section */}
      <section id="educators" className="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-bold mb-4">
              For Educators & Subject Experts
            </h2>
            <p className="text-xl text-blue-100 max-w-2xl mx-auto">
              Share your expertise. Build your profile. Help students succeed.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
            {/* Benefits */}
            <div className="bg-white/10 backdrop-blur-sm p-8 rounded-xl">
              <h3 className="text-2xl font-bold mb-6">What You Get</h3>
              <ul className="space-y-4">
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Featured Profile</div>
                    <div className="text-blue-100 text-sm">Showcase expertise to thousands of students</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Free Premium Access</div>
                    <div className="text-blue-100 text-sm">Lifetime premium account</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Recognition</div>
                    <div className="text-blue-100 text-sm">Your content reaches {stats.students || 'hundreds of'} students</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Easy Upload</div>
                    <div className="text-blue-100 text-sm">Bulk CSV upload (3-4 hours one-time)</div>
                  </div>
                </li>
              </ul>
            </div>

            {/* Current Contributors - RESTORED with "Join" prefix */}
            <div className="bg-white/10 backdrop-blur-sm p-8 rounded-xl">
              <h3 className="text-2xl font-bold mb-6">
                {!stats.isLoading && educators.length > 0 ? (
                  `Join Our Expert Contributors`
                ) : (
                  `Join ${stats.educators} Expert Educator${stats.educators !== 1 ? 's' : ''}`
                )}
              </h3>
              
              {/* Show actual educators if available */}
              {!stats.isLoading && educators.length > 0 ? (
                <div className="space-y-4 mb-6">
                  {educators.map((educator, index) => (
                    <div key={educator.id || index} className="flex items-center space-x-4">
                      <div className="bg-white/20 w-12 h-12 rounded-full flex items-center justify-center text-xl font-semibold">
                        {educator.full_name?.charAt(0) || 'E'}
                      </div>
                      <div>
                        <div className="font-semibold">{educator.full_name || 'Expert Educator'}</div>
                        <div className="text-blue-100 text-sm">Subject Matter Expert</div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="space-y-4 mb-6">
                  <div className="flex items-center space-x-4">
                    <div className="bg-white/20 p-3 rounded-full">
                      <Users className="h-6 w-6" />
                    </div>
                    <div>
                      <div className="font-semibold">Growing Community</div>
                      <div className="text-blue-100 text-sm">{stats.students} active students</div>
                    </div>
                  </div>
                  <div className="flex items-center space-x-4">
                    <div className="bg-white/20 p-3 rounded-full">
                      <BookOpen className="h-6 w-6" />
                    </div>
                    <div>
                      <div className="font-semibold">Quality Platform</div>
                      <div className="text-blue-100 text-sm">{stats.flashcards + stats.notes} items shared</div>
                    </div>
                  </div>
                  <div className="flex items-center space-x-4">
                    <div className="bg-white/20 p-3 rounded-full">
                      <TrendingUp className="h-6 w-6" />
                    </div>
                    <div>
                      <div className="font-semibold">Real Impact</div>
                      <div className="text-blue-100 text-sm">Help students ace exams</div>
                    </div>
                  </div>
                </div>
              )}

              <div className="mt-8 pt-8 border-t border-white/20">
                <a 
                  href="mailto:recall@moreclassescommerce.com?subject=Interested in Contributing as Educator&body=Hi, I'm interested in becoming a contributing educator for Recall. Please send me more details.%0D%0A%0D%0AMy name: %0D%0AMy subject expertise: %0D%0AMy institution: %0D%0AMy contact number: " 
                  className="block w-full bg-white text-blue-600 text-center px-6 py-3 rounded-lg font-semibold hover:bg-blue-50 transition"
                >
                  Become a Contributing Expert
                </a>
                <p className="text-center text-blue-100 text-sm mt-3">
                  Email: recall@moreclassescommerce.com
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              What Students Are Saying
            </h2>
            <p className="text-xl text-gray-600">
              Real feedback from early adopters
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="bg-white p-8 rounded-xl shadow-lg">
              <div className="text-yellow-500 mb-4">★★★★★</div>
              <p className="text-gray-700 italic mb-4">
                "I uploaded my CA notes in 10 minutes and created 20 flashcards. 
                So much easier than Anki!"
              </p>
              <div className="font-semibold text-gray-900">— Student</div>
              <div className="text-sm text-gray-600">Early Access</div>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg">
              <div className="text-yellow-500 mb-4">★★★★★</div>
              <p className="text-gray-700 italic mb-4">
                "Spaced repetition actually works! I'm remembering concepts from 2 weeks ago. 
                Game changer."
              </p>
              <div className="font-semibold text-gray-900">— Student</div>
              <div className="text-sm text-gray-600">Early Access</div>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg">
              <div className="text-yellow-500 mb-4">★★★★★</div>
              <p className="text-gray-700 italic mb-4">
                "The educator flashcards helped me get started. Now I'm creating my own 
                and sharing with classmates."
              </p>
              <div className="font-semibold text-gray-900">— Student</div>
              <div className="text-sm text-gray-600">Early Access</div>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            Ready to Build Your Study Library?
          </h2>
          <p className="text-xl text-blue-100 mb-10">
            Join {stats.students} students • {stats.educators} educators • Free forever
          </p>
          <div className="flex flex-col sm:flex-row justify-center space-y-4 sm:space-y-0 sm:space-x-4">
            <Link 
              to="/signup" 
              className="bg-white text-blue-600 px-8 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              Create Your First Flashcard
            </Link>
            <a 
              href="mailto:recall@moreclassescommerce.com?subject=Questions About Recall&body=Hi, I have a question about Recall:%0D%0A%0D%0A"
              className="bg-transparent border-2 border-white text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-white/10 transition"
            >
              Contact Us
            </a>
          </div>
          <p className="mt-6 text-blue-100">
            No credit card required • Start in 30 seconds
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-400 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-4 gap-8">
            {/* Brand */}
            <div>
              <div className="flex items-center space-x-2 mb-4">
                <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold text-xl px-3 py-1 rounded">
                  R
                </div>
                <span className="text-xl font-bold text-white">Recall</span>
              </div>
              <p className="text-sm">
                Turn your notes into smart flashcards. Build your study library. Ace every exam.
              </p>
            </div>

            {/* Product */}
            <div>
              <h3 className="text-white font-semibold mb-4">Product</h3>
              <ul className="space-y-2 text-sm">
                <li><a href="#features" className="hover:text-white transition">Features</a></li>
                <li><a href="#how-it-works" className="hover:text-white transition">How It Works</a></li>
                <li><Link to="/signup" className="hover:text-white transition">Sign Up</Link></li>
                <li><Link to="/login" className="hover:text-white transition">Login</Link></li>
              </ul>
            </div>

            {/* For Educators */}
            <div>
              <h3 className="text-white font-semibold mb-4">For Educators</h3>
              <ul className="space-y-2 text-sm">
                <li><a href="mailto:recall@moreclassescommerce.com?subject=Become an Educator" className="hover:text-white transition">Become a Contributor</a></li>
                <li><a href="#educators" className="hover:text-white transition">Benefits</a></li>
                <li><a href="mailto:recall@moreclassescommerce.com" className="hover:text-white transition">Contact</a></li>
              </ul>
            </div>

            {/* Legal */}
            <div>
              <h3 className="text-white font-semibold mb-4">Legal</h3>
              <ul className="space-y-2 text-sm">
                <li><Link to="/privacy-policy" className="hover:text-white transition">Privacy Policy</Link></li>
                <li><Link to="/terms-of-service" className="hover:text-white transition">Terms of Service</Link></li>
                <li><a href="mailto:recall@moreclassescommerce.com" className="hover:text-white transition">Support</a></li>
              </ul>
            </div>
          </div>

          <div className="border-t border-gray-800 mt-12 pt-8 text-center text-sm">
            <p>© 2025 Recall. All rights reserved. Built for students who want to remember everything.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}