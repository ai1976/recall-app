import React from 'react';
import { Link } from 'react-router-dom';
import { Brain, Users, TrendingUp, CheckCircle, BookOpen, Award, Zap } from 'lucide-react';

export default function Home() {
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
              <a href="#professors" className="text-gray-700 hover:text-blue-600 transition">For Professors</a>
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
          {/* Badge */}
          <div className="inline-flex items-center space-x-2 bg-blue-100 text-blue-800 px-4 py-2 rounded-full mb-6">
            <Award className="h-4 w-4" />
            <span className="text-sm font-semibold">220+ Expert-Verified Flashcards Ready</span>
          </div>

          {/* Main Headline */}
          <h1 className="text-5xl md:text-6xl font-bold text-gray-900 mb-6 leading-tight">
            Remember Everything.
            <br />
            <span className="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              Ace Every Exam.
            </span>
          </h1>

          {/* Subheadline */}
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Learn from expert-curated flashcards. Review at the perfect time. 
            Add your own notes. Never forget again.
          </p>

          {/* Social Proof */}
          <div className="flex flex-col sm:flex-row justify-center items-center space-y-4 sm:space-y-0 sm:space-x-8 mb-10">
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">Faculty-verified content</span>
            </div>
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">Spaced repetition proven to work</span>
            </div>
            <div className="flex items-center space-x-2">
              <CheckCircle className="h-5 w-5 text-green-600" />
              <span className="text-gray-700">100% free during beta</span>
            </div>
          </div>

          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row justify-center space-y-4 sm:space-y-0 sm:space-x-4">
            <Link 
              to="/signup" 
              className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              Start Learning Now
            </Link>
            <a 
              href="mailto:recall@moreclassescommerce.com?subject=Interested in Contributing to Recall&body=Hi, I'm interested in becoming a contributing expert for Recall. Please send me more details.%0D%0A%0D%0AMy name: %0D%0AMy subject expertise: %0D%0AMy institution: %0D%0AMy contact number: "
              className="bg-white text-blue-600 border-2 border-blue-600 px-8 py-4 rounded-lg text-lg font-semibold hover:bg-blue-50 transition"
            >
              I'm an Educator
            </a>
          </div>

          {/* Stats */}
          <div className="mt-16 grid grid-cols-3 gap-8 max-w-2xl mx-auto">
            <div>
              <div className="text-4xl font-bold text-blue-600">220+</div>
              <div className="text-gray-600 mt-2">Expert Flashcards</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-purple-600">35+</div>
              <div className="text-gray-600 mt-2">Study Notes</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-green-600">8+</div>
              <div className="text-gray-600 mt-2">Subjects Covered</div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="bg-white py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Everything You Need to Excel
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Powerful features designed for serious students across all disciplines
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {/* Feature 1 */}
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-blue-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <Award className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Expert-Verified Content
              </h3>
              <p className="text-gray-600 mb-4">
                Learn from faculty-curated flashcards created by subject experts. 
                Quality content from Day 1.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">220+ verified flashcards</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Multiple subjects covered</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Updated by experts regularly</span>
                </li>
              </ul>
            </div>

            {/* Feature 2 */}
            <div className="bg-gradient-to-br from-purple-50 to-pink-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-purple-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <Brain className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Spaced Repetition System
              </h3>
              <p className="text-gray-600 mb-4">
                Review at scientifically-proven intervals. Boost retention by 80% compared 
                to traditional studying.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">SuperMemo-2 algorithm</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Automatic review scheduling</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Track your study streaks</span>
                </li>
              </ul>
            </div>

            {/* Feature 3 */}
            <div className="bg-gradient-to-br from-green-50 to-teal-50 p-8 rounded-xl hover:shadow-lg transition">
              <div className="bg-green-600 text-white p-3 rounded-lg w-12 h-12 flex items-center justify-center mb-4">
                <BookOpen className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Build Your Own Library
              </h3>
              <p className="text-gray-600 mb-4">
                Upload your notes, create flashcards, and share with classmates. 
                Your study material, digitized and organized.
              </p>
              <ul className="space-y-2">
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Photo upload with OCR</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Create unlimited flashcards</span>
                </li>
                <li className="flex items-start space-x-2">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span className="text-gray-700">Share notes with peers</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section id="how-it-works" className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Get Started in 3 Simple Steps
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Start learning smarter in under 10 minutes
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-12">
            {/* Step 1 */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                1
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Review Expert Flashcards
              </h3>
              <p className="text-gray-600">
                Sign up and immediately start reviewing 220+ expert flashcards. 
                Takes just 5 minutes to see value.
              </p>
            </div>

            {/* Step 2 */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-purple-600 to-pink-600 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                2
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Upload Your Notes
              </h3>
              <p className="text-gray-600">
                Take photos of your handwritten notes or upload PDFs. 
                Our OCR extracts text automatically.
              </p>
            </div>

            {/* Step 3 */}
            <div className="text-center">
              <div className="bg-gradient-to-r from-green-600 to-teal-600 text-white w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold mb-6 mx-auto">
                3
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">
                Build Daily Habit
              </h3>
              <p className="text-gray-600">
                Review due cards daily (5-10 min). Create flashcards. 
                Track your progress and maintain your streak!
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
              <span>Start Your Free Trial</span>
            </Link>
            <p className="text-gray-600 mt-3">No credit card required • 100% free during beta</p>
          </div>
        </div>
      </section>

      {/* For Professors Section */}
      <section id="professors" className="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-bold mb-4">
              For Educators & Subject Experts
            </h2>
            <p className="text-xl text-blue-100 max-w-2xl mx-auto">
              Help students learn better. Get recognized. Build your profile.
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
                    <div className="font-semibold">Featured Expert Profile</div>
                    <div className="text-blue-100 text-sm">Showcase your expertise to thousands of students</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Free Premium Access</div>
                    <div className="text-blue-100 text-sm">Lifetime premium account (₹2,000/year value)</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Recognition & Impact</div>
                    <div className="text-blue-100 text-sm">Help thousands of students succeed</div>
                  </div>
                </li>
                <li className="flex items-start space-x-3">
                  <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                  <div>
                    <div className="font-semibold">Easy Contribution</div>
                    <div className="text-blue-100 text-sm">Bulk upload via CSV (3-4 hours one-time)</div>
                  </div>
                </li>
              </ul>
            </div>

            {/* Current Contributors */}
            <div className="bg-white/10 backdrop-blur-sm p-8 rounded-xl">
              <h3 className="text-2xl font-bold mb-6">Join Our Expert Contributors</h3>
              <div className="space-y-4">
                <div className="flex items-center space-x-4">
                  <div className="bg-white/20 p-3 rounded-full">
                    <Users className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="font-semibold">Subject Matter Experts</div>
                    <div className="text-blue-100 text-sm">Multiple disciplines covered</div>
                  </div>
                </div>
                <div className="flex items-center space-x-4">
                  <div className="bg-white/20 p-3 rounded-full">
                    <Users className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="font-semibold">Quality Content</div>
                    <div className="text-blue-100 text-sm">220+ verified flashcards</div>
                  </div>
                </div>
                <div className="flex items-center space-x-4">
                  <div className="bg-white/20 p-3 rounded-full">
                    <Users className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="font-semibold">Growing Community</div>
                    <div className="text-blue-100 text-sm">Expanding across disciplines</div>
                  </div>
                </div>
              </div>

              <div className="mt-8 pt-8 border-t border-white/20">
                <a 
                  href="mailto:recall@moreclassescommerce.com?subject=Interested in Contributing to Recall&body=Hi, I'm interested in becoming a contributing faculty member for Recall. Please send me more details.%0D%0A%0D%0AMy name: %0D%0AMy subject expertise: %0D%0AMy institution: %0D%0AMy contact number: " 
                  className="block w-full bg-white text-blue-600 text-center px-6 py-3 rounded-lg font-semibold hover:bg-blue-50 transition"
                >
                  Become a Contributing Expert
                </a>
                <p className="text-center text-blue-100 text-sm mt-3">
                  Or email us at: recall@moreclassescommerce.com
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
              Join our beta program and be among the first to experience Recall
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {/* Testimonial Placeholder */}
            <div className="bg-white p-8 rounded-xl shadow-lg">
              <div className="text-yellow-500 mb-4">★★★★★</div>
              <p className="text-gray-700 italic mb-4">
                "The expert flashcards were a game-changer. I started reviewing immediately 
                instead of spending hours creating cards."
              </p>
              <div className="font-semibold text-gray-900">— Student</div>
              <div className="text-sm text-gray-600">Beta Testing</div>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg">
              <div className="text-yellow-500 mb-4">★★★★★</div>
              <p className="text-gray-700 italic mb-4">
                "Spaced repetition actually works! I remember concepts I learned weeks ago. 
                My retention has improved dramatically."
              </p>
              <div className="font-semibold text-gray-900">— Student</div>
              <div className="text-sm text-gray-600">Beta Testing</div>
            </div>

            <div className="bg-white p-8 rounded-xl shadow-lg">
              <div className="text-yellow-500 mb-4">★★★★★</div>
              <p className="text-gray-700 italic mb-4">
                "Finally, a study tool built by educators who understand what students need. 
                This is exactly what we were looking for."
              </p>
              <div className="font-semibold text-gray-900">— Student</div>
              <div className="text-sm text-gray-600">Beta Testing</div>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            Ready to Transform Your Study Routine?
          </h2>
          <p className="text-xl text-blue-100 mb-10">
            Join the beta program. Get access to 220+ expert-verified flashcards. 
            100% free during beta testing.
          </p>
          <div className="flex flex-col sm:flex-row justify-center space-y-4 sm:space-y-0 sm:space-x-4">
            <Link 
              to="/signup" 
              className="bg-white text-blue-600 px-8 py-4 rounded-lg text-lg font-semibold hover:shadow-xl transition transform hover:-translate-y-1"
            >
              Start Learning Now
            </Link>
            <a 
              href="mailto:recall@moreclassescommerce.com?subject=Interested in Contributing to Recall&body=Hi, I'm interested in becoming a contributing expert for Recall. Please send me more details.%0D%0A%0D%0AMy name: %0D%0AMy subject expertise: %0D%0AMy institution: %0D%0AMy contact number: "
              className="bg-transparent border-2 border-white text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-white/10 transition"
            >
              I'm an Educator
            </a>
          </div>
          <p className="mt-6 text-blue-100">
            No credit card required • Takes 30 seconds to sign up
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
                AI-powered study platform for serious students. Remember everything. Ace every exam.
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

            {/* For Faculty */}
            <div>
              <h3 className="text-white font-semibold mb-4">For Educators</h3>
              <ul className="space-y-2 text-sm">
                <li><a href="mailto:recall@moreclassescommerce.com?subject=Become a Contributor" className="hover:text-white transition">Become a Contributor</a></li>
                <li><a href="#professors" className="hover:text-white transition">Faculty Benefits</a></li>
                <li><a href="mailto:recall@moreclassescommerce.com" className="hover:text-white transition">Contact Us</a></li>
              </ul>
            </div>

            {/* Legal */}
            <div>
              <h3 className="text-white font-semibold mb-4">Legal</h3>
              <ul className="space-y-2 text-sm">
                <li><a href="#" className="hover:text-white transition">Privacy Policy</a></li>
                <li><a href="#" className="hover:text-white transition">Terms of Service</a></li>
                <li><a href="mailto:recall@moreclassescommerce.com" className="hover:text-white transition">Support</a></li>
              </ul>
            </div>
          </div>

          <div className="border-t border-gray-800 mt-12 pt-8 text-center text-sm">
            <p>© 2025 Recall. All rights reserved. Built with love for students everywhere.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}