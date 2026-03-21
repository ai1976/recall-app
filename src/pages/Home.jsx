import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Brain, Users, TrendingUp, CheckCircle, BookOpen, Award, Zap, Upload, Share2, Camera } from 'lucide-react';
import { supabase } from '../lib/supabase';

export default function Home() {
  // Real-time stats from database
  const [stats, setStats] = useState({
    students: 0,
    educators: 0,
    flashcards: 0,     // public only — used in educator section (what new users can browse)
    notes: 0,          // public only — used in educator section
    totalFlashcards: 0, // all visibility — used in hero grid (platform activity)
    totalNotes: 0,      // all visibility — used in hero grid
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
        
        // Use SECURITY DEFINER RPC for all counts that need to bypass RLS.
        // Direct table queries from unauthenticated context are RLS-filtered,
        // so profiles (student/educator counts) and all-visibility totals must go through RPC.
        const { data: platformStats } = await supabase
          .rpc('get_platform_stats');
        const totalFlashcardCount = platformStats?.total_flashcards ?? 0;
        const totalNoteCount = platformStats?.total_notes ?? 0;
        // student_count and educator_count now returned by the RPC (bypasses RLS for anon users)
        const rpcStudentCount = platformStats?.student_count ?? studentCount ?? 0;
        const rpcEducatorCount = platformStats?.educator_count ?? educatorCount ?? 0;

        // Count PUBLIC flashcards only (what new users can browse — for educator section)
        const { count: flashcardCount } = await supabase
          .from('flashcards')
          .select('*', { count: 'exact', head: true })
          .eq('visibility', 'public');

        // Count PUBLIC notes only (what new users can browse — for educator section)
        const { count: noteCount } = await supabase
          .from('notes')
          .select('*', { count: 'exact', head: true })
          .eq('visibility', 'public');

        setStats({
          students: rpcStudentCount,
          educators: rpcEducatorCount,
          flashcards: flashcardCount || 0,
          notes: noteCount || 0,
          totalFlashcards: totalFlashcardCount || 0,
          totalNotes: totalNoteCount || 0,
          isLoading: false
        });
        
      } catch (err) {
        console.error('Error fetching stats:', err);
        setStats({
          students: 0,
          educators: 0,
          flashcards: 0,
          notes: 0,
          totalFlashcards: 0,
          totalNotes: 0,
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
            <div className="md:hidden flex items-center space-x-3">
              <Link
                to="/login"
                className="text-gray-700 hover:text-blue-600 text-sm font-medium transition"
              >
                Login
              </Link>
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

          {/* Main Headline - Brand name first, tagline second */}
          <h1 className="text-6xl md:text-7xl font-bold mb-3 leading-tight bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            Recall
          </h1>
          <p className="text-2xl md:text-3xl font-bold mb-6 text-gray-900">
            The Revision Operating System.
          </p>

          {/* Subheadline - Better sequencing */}
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Your institute's content, your own notes, and peer study sets — all reviewed with spaced repetition so nothing is forgotten before exam day.
          </p>

          {/* Social Proof - Platform activity */}
          <div className="flex flex-col sm:flex-row justify-center items-center space-y-4 sm:space-y-0 sm:space-x-8 mb-10">
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">Free to get started</span>
            </div>
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">SM-2 spaced repetition</span>
            </div>
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">
                {stats.isLoading ? 'Active community' : `${stats.totalFlashcards + stats.totalNotes}+ flashcards & notes`}
              </span>
            </div>
          </div>

          {/* Primary B2C CTA */}
          <div className="flex justify-center mb-3">
            <Link
              to="/signup"
              className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-10 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              Start free
            </Link>
          </div>

          <p className="text-gray-500 text-sm">
            Already a student?{' '}
            <Link to="/login" className="text-blue-600 hover:underline font-medium">
              Log in
            </Link>
          </p>

          {/* Real-time Stats */}
          <div className="mt-14 grid grid-cols-2 md:grid-cols-4 gap-8 max-w-3xl mx-auto">
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
                {stats.totalFlashcards}
              </div>
              <div className="text-gray-600 mt-2">Flashcards</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-orange-600">
                {stats.totalNotes}
              </div>
              <div className="text-gray-600 mt-2">Notes</div>
            </div>
          </div>

          {/* Institute CTA — separated from student flow */}
          <div className="mt-8 pt-6 border-t border-gray-200 max-w-3xl mx-auto">
            <p className="text-gray-500 text-sm">
              Are you an institute or coaching class?{' '}
              <a
                href="mailto:hello@recallapp.co.in?subject=Get My Institute on Recall&body=Hi, I'd like to get my institute on Recall. Please send me more details.%0D%0A%0D%0AInstitute name: %0D%0ACity: %0D%0AContact number: "
                className="text-blue-600 hover:underline font-medium"
              >
                Get your institute on Recall
              </a>
            </p>
          </div>
        </div>
      </section>

      {/* How It Works Section - Platform journey */}
      <section id="how-it-works" className="bg-white py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              How Recall Works
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              From your first session to exam day — one continuous system
            </p>
          </div>

          <div className="grid md:grid-cols-4 gap-8">
            {/* Step 1 - Review First */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-blue-600 to-blue-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <Brain className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                1. Start Reviewing Now
              </h3>
              <p className="text-gray-600">
                Public flashcard sets are already here. Browse study materials created by educators and peers, and start your first spaced repetition session in under 2 minutes.
              </p>
            </div>

            {/* Step 2 - Upload Notes */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-purple-600 to-purple-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <Camera className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                2. Upload Your Notes
              </h3>
              <p className="text-gray-600">
                Scan handwritten notes with your phone camera. We'll digitize them automatically.
              </p>
            </div>

            {/* Step 3 - Create Flashcards */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-green-600 to-green-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <BookOpen className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                3. Create Flashcards
              </h3>
              <p className="text-gray-600">
                Create flashcards from your uploaded notes, or make standalone topic-specific cards.
                Manual creation or bulk CSV upload.
              </p>
            </div>

            {/* Step 4 - Daily Review */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-orange-600 to-orange-500 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                <TrendingUp className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                4. Never Forget Again
              </h3>
              <p className="text-gray-600">
                5–10 minutes daily. SM-2 algorithm schedules each card at the exact moment before you'd forget it. Permanent recall, not last-minute cramming.
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
              <span>Start Reviewing Now</span>
            </Link>
            <p className="text-gray-600 mt-3">Start free • Upgrade anytime</p>
          </div>
        </div>
      </section>

      {/* Features Section - Platform capabilities */}
      <section id="features" className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Built on the Science of Permanent Memory
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Every feature is designed around one goal: make sure you remember on exam day, not just today
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {/* Feature 1 - Spaced Repetition (moved to position 1) */}
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-blue-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <Brain className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                SM-2 Spaced Repetition
              </h3>
              <p className="text-gray-600 mb-4">
                The gold standard algorithm used by top memory athletes. Recall schedules each item at the exact optimal interval — not too soon, not too late.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">SuperMemo SM-2 algorithm</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Daily review queue, auto-scheduled</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Streak tracking + progress badges</span>
                </li>
              </ul>
            </div>

            {/* Feature 2 - Note Upload */}
            <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-purple-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
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

            {/* Feature 3 - Flashcard Creation */}
            <div className="bg-gradient-to-br from-green-50 to-teal-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-green-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
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
          </div>
        </div>
      </section>

      {/* Bonus: Educator Content Section */}
      <section className="bg-blue-50 py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="max-w-3xl mx-auto text-center">
            <div className="inline-flex items-center space-x-2 bg-blue-200 text-blue-900 px-4 py-2 rounded-full mb-6">
              <Award className="h-4 w-4" />
              <span className="text-sm font-semibold">Free to Browse</span>
            </div>

            <h2 className="text-3xl font-bold text-gray-900 mb-4">
              Start with Our Existing Study Library
            </h2>
            <p className="text-xl text-gray-600 mb-8">
              Even before your institute joins, there are already {stats.flashcards > 0 ? stats.flashcards : 'hundreds of'} educator-verified flashcards and {stats.notes > 0 ? stats.notes : 'dozens of'} notes available to browse. Sign up free and start reviewing today.
            </p>

            <div className="bg-white p-8 rounded-xl shadow-sm">
              <div className="grid md:grid-cols-3 gap-6 mb-6">
                <div>
                  <div className="text-3xl font-bold text-blue-600 mb-2">
                    {stats.educators}
                  </div>
                  <div className="text-gray-600">Educators</div>
                </div>
                <div>
                  <div className="text-3xl font-bold text-purple-600 mb-2">
                    {stats.flashcards}
                  </div>
                  <div className="text-gray-600">Flashcards</div>
                </div>
                <div>
                  <div className="text-3xl font-bold text-green-600 mb-2">
                    {stats.notes}
                  </div>
                  <div className="text-gray-600">Notes</div>
                </div>
              </div>

              <p className="text-gray-600 italic">
                "Browse public content → Create your own → Share with peers"
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
              For Institutes & Educators
            </h2>
            <p className="text-xl text-blue-100 max-w-2xl mx-auto">
              Bring your institute onto Recall. Auto-enrol your batch. Curate content once — every student benefits.
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
                    <div className="font-semibold">Dedicated Institute Setup</div>
                    <div className="text-blue-100 text-sm">Batch groups auto-created, students auto-enrolled on registration</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Free for Students</div>
                    <div className="text-blue-100 text-sm">Social features, batch groups, and review tools are free for all enrolled students</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Curated Content Control</div>
                    <div className="text-blue-100 text-sm">You control which flashcards and notes are visible to your batch</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Bulk Upload or CSV</div>
                    <div className="text-blue-100 text-sm">Upload your complete study material once via CSV — we handle the rest</div>
                  </div>
                </li>
              </ul>
            </div>

            {/* Why Institutes Choose Recall */}
            <div className="bg-white/10 backdrop-blur-sm p-8 rounded-xl">
              <h3 className="text-2xl font-bold mb-2">Why Institutes Choose Recall</h3>
              <p className="text-blue-100 text-sm mb-6">
                When your institute is on Recall, all study sets are pre-loaded into your students' accounts. No setup. No waiting.
              </p>

              <div className="space-y-4 mb-6">
                <div className="flex items-start space-x-4">
                  <div className="bg-white/20 p-3 rounded-full flex-shrink-0">
                    <Zap className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="font-semibold">Ready in 48 Hours</div>
                    <div className="text-blue-100 text-sm">Institute onboarding and batch setup done for you</div>
                  </div>
                </div>
                <div className="flex items-start space-x-4">
                  <div className="bg-white/20 p-3 rounded-full flex-shrink-0">
                    <Users className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="font-semibold">Students Auto-Enrolled</div>
                    <div className="text-blue-100 text-sm">Students are automatically added to your batch on registration — no manual invites</div>
                  </div>
                </div>
                <div className="flex items-start space-x-4">
                  <div className="bg-white/20 p-3 rounded-full flex-shrink-0">
                    <BookOpen className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="font-semibold">Content Pre-loaded</div>
                    <div className="text-blue-100 text-sm">Your CSV becomes your students' spaced repetition queue from Day 1</div>
                  </div>
                </div>
              </div>

              <div className="mt-8 pt-8 border-t border-white/20">
                <a
                  href="mailto:hello@recallapp.co.in?subject=Get My Institute on Recall&body=Hi, I'd like to get my institute on Recall.%0D%0A%0D%0AInstitute name: %0D%0ACity: %0D%0AContact number: "
                  className="block w-full bg-white text-blue-600 text-center px-6 py-3 rounded-lg font-semibold hover:bg-blue-50 transition"
                >
                  Get My Institute on Recall
                </a>
                <p className="text-center text-blue-100 text-sm mt-3">
                  Email: hello@recallapp.co.in
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
            Ready to Never Forget Again?
          </h2>
          <p className="text-xl text-blue-100 mb-10">
            Join {stats.students} students already using spaced repetition • Start free today
          </p>
          <div className="flex flex-col sm:flex-row justify-center space-y-4 sm:space-y-0 sm:space-x-4">
            <Link
              to="/signup"
              className="bg-white text-blue-600 px-8 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              Start free
            </Link>
            <a
              href="mailto:hello@recallapp.co.in?subject=Questions About Recall&body=Hi, I have a question about Recall:%0D%0A%0D%0A"
              className="bg-transparent border-2 border-white text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-white/10 transition"
            >
              Contact Us
            </a>
          </div>
          <p className="mt-6 text-blue-100">
            Free for students • Institute plans available
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
                The revision operating system for serious exam preparation.
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
                <li><a href="mailto:hello@recallapp.co.in?subject=Get My Institute on Recall" className="hover:text-white transition">Get My Institute on Recall</a></li>
                <li><a href="#educators" className="hover:text-white transition">Benefits</a></li>
                <li><a href="mailto:hello@recallapp.co.in" className="hover:text-white transition">Contact</a></li>
              </ul>
            </div>

            {/* Legal */}
            <div>
              <h3 className="text-white font-semibold mb-4">Legal</h3>
              <ul className="space-y-2 text-sm">
                <li><Link to="/privacy-policy" className="hover:text-white transition">Privacy Policy</Link></li>
                <li><Link to="/terms-of-service" className="hover:text-white transition">Terms of Service</Link></li>
                <li><a href="mailto:hello@recallapp.co.in" className="hover:text-white transition">Support</a></li>
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