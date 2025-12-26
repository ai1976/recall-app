import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Shield, Lock, Eye, Database, UserX } from 'lucide-react';

export default function PrivacyPolicy() {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <Link 
            to="/" 
            className="inline-flex items-center text-blue-600 hover:text-blue-700 mb-4"
          >
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Home
          </Link>
          <h1 className="text-3xl font-bold text-gray-900">Privacy Policy</h1>
          <p className="text-gray-600 mt-2">Last updated: December 26, 2025</p>
        </div>
      </div>

      {/* Quick Summary */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
          <h2 className="text-xl font-bold text-blue-900 mb-4 flex items-center">
            <Shield className="h-5 w-5 mr-2" />
            Privacy at a Glance
          </h2>
          <div className="grid md:grid-cols-2 gap-4 text-sm text-blue-900">
            <div className="flex items-start space-x-2">
              <Lock className="h-4 w-4 mt-0.5 flex-shrink-0" />
              <div>
                <strong>Data Security:</strong> Your data is encrypted and securely stored
              </div>
            </div>
            <div className="flex items-start space-x-2">
              <Eye className="h-4 w-4 mt-0.5 flex-shrink-0" />
              <div>
                <strong>No Selling:</strong> We never sell your personal information
              </div>
            </div>
            <div className="flex items-start space-x-2">
              <Database className="h-4 w-4 mt-0.5 flex-shrink-0" />
              <div>
                <strong>Limited Collection:</strong> We only collect what's necessary
              </div>
            </div>
            <div className="flex items-start space-x-2">
              <UserX className="h-4 w-4 mt-0.5 flex-shrink-0" />
              <div>
                <strong>Your Control:</strong> Delete your account and data anytime
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
        <div className="bg-white rounded-lg shadow-sm p-8 prose prose-blue max-w-none">
          
          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">1. Introduction</h2>
            <p className="text-gray-700 mb-4">
              Welcome to Recall's Privacy Policy. This document explains how More Classes Commerce 
              ("we," "us," or "our") collects, uses, stores, and protects your personal information 
              when you use our platform at recall.moreclassescommerce.com ("Service").
            </p>
            <p className="text-gray-700 mb-4">
              We are committed to protecting your privacy and complying with applicable data 
              protection laws, including:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2">
              <li>Information Technology Act, 2000 (India)</li>
              <li>Information Technology (Reasonable Security Practices and Procedures and 
                  Sensitive Personal Data or Information) Rules, 2011</li>
              <li>General Data Protection Regulation (GDPR) principles</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">2. Information We Collect</h2>
            
            <h3 className="text-xl font-semibold text-gray-900 mb-3">2.1 Information You Provide</h3>
            <p className="text-gray-700 mb-4">
              When you register and use Recall, we collect:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>Account Information:</strong> Name, email address, password (encrypted)</li>
              <li><strong>Profile Information:</strong> Course level, institution, study preferences</li>
              <li><strong>User Content:</strong> Notes, flashcards, comments, and uploads</li>
              <li><strong>Payment Information:</strong> Billing details processed through Razorpay 
                  (we do not store credit card numbers)</li>
              <li><strong>Communications:</strong> Emails and messages you send us</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">2.2 Automatically Collected Information</h3>
            <p className="text-gray-700 mb-4">
              When you use our Service, we automatically collect:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>Usage Data:</strong> Study sessions, flashcard reviews, progress metrics</li>
              <li><strong>Device Information:</strong> Browser type, operating system, device model</li>
              <li><strong>Log Data:</strong> IP address, access times, pages viewed</li>
              <li><strong>Analytics:</strong> Aggregated usage statistics via PostHog</li>
              <li><strong>Cookies:</strong> Session management and preferences (see Section 8)</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">2.3 Information from Third Parties</h3>
            <p className="text-gray-700">
              We may receive information from:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2">
              <li><strong>Razorpay:</strong> Payment confirmation and transaction details</li>
              <li><strong>PostHog:</strong> Anonymous analytics data</li>
              <li><strong>Supabase:</strong> Authentication and database services</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">3. How We Use Your Information</h2>
            <p className="text-gray-700 mb-4">
              We use your information to:
            </p>
            
            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.1 Provide the Service</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Create and manage your account</li>
              <li>Deliver flashcards, notes, and study materials</li>
              <li>Calculate spaced repetition schedules</li>
              <li>Track your progress and study streaks</li>
              <li>Enable content sharing with other users</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.2 Process Payments</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Process subscription payments via Razorpay</li>
              <li>Send payment confirmations and receipts</li>
              <li>Manage billing and refunds</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.3 Improve the Service</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Analyze usage patterns to improve features</li>
              <li>Identify and fix technical issues</li>
              <li>Develop new features based on user behavior</li>
              <li>Train machine learning models for OCR and recommendations</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.4 Communicate with You</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Send account-related notifications</li>
              <li>Provide customer support</li>
              <li>Send service updates and feature announcements</li>
              <li>Marketing emails (with your consent, opt-out available)</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.5 Legal Compliance</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2">
              <li>Comply with legal obligations</li>
              <li>Enforce our Terms of Service</li>
              <li>Protect against fraud and abuse</li>
              <li>Respond to law enforcement requests</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">4. How We Share Your Information</h2>
            <p className="text-gray-700 mb-4">
              We do not sell your personal information. We may share your information with:
            </p>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.1 Service Providers</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>Supabase:</strong> Database hosting and authentication (USA, GDPR compliant)</li>
              <li><strong>Razorpay:</strong> Payment processing (India)</li>
              <li><strong>PostHog:</strong> Analytics (self-hosted, data stays in India)</li>
              <li><strong>Vercel:</strong> Web hosting (USA, GDPR compliant)</li>
              <li><strong>Resend:</strong> Email delivery (USA)</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.2 Other Users</h3>
            <p className="text-gray-700 mb-4">
              When you share content publicly:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Your name and shared flashcards/notes are visible to other users</li>
              <li>Your profile information (if public) can be viewed by other students</li>
              <li>Comments and upvotes are publicly visible</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.3 Legal Requirements</h3>
            <p className="text-gray-700 mb-4">
              We may disclose information if required to:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Comply with legal obligations or court orders</li>
              <li>Protect our rights and property</li>
              <li>Prevent fraud or security issues</li>
              <li>Protect users' safety</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.4 Business Transfers</h3>
            <p className="text-gray-700">
              If we are acquired or merged, your information may be transferred to the new entity. 
              We will notify you before your information is transferred and becomes subject to a 
              different privacy policy.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">5. Data Security</h2>
            <p className="text-gray-700 mb-4">
              We implement industry-standard security measures to protect your information:
            </p>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">5.1 Technical Safeguards</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>Encryption:</strong> All data transmitted via HTTPS/TLS encryption</li>
              <li><strong>Password Security:</strong> Passwords hashed using bcrypt</li>
              <li><strong>Database Security:</strong> Row-level security policies in Supabase</li>
              <li><strong>Access Control:</strong> Role-based permissions (student/professor/admin)</li>
              <li><strong>Regular Backups:</strong> Daily automated backups</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">5.2 Organizational Safeguards</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Limited employee access to personal data</li>
              <li>Regular security audits</li>
              <li>Incident response procedures</li>
              <li>Staff training on data protection</li>
            </ul>

            <p className="text-gray-700">
              <strong>Note:</strong> While we strive to protect your information, no method of 
              transmission or storage is 100% secure. We cannot guarantee absolute security.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">6. Your Rights and Choices</h2>
            <p className="text-gray-700 mb-4">
              You have the following rights regarding your personal information:
            </p>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">6.1 Access and Portability</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>View your account information in settings</li>
              <li>Request a copy of your data (email recall@moreclassescommerce.com)</li>
              <li>Download your flashcards and notes anytime</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">6.2 Correction and Update</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Update your profile information anytime in settings</li>
              <li>Edit or delete your flashcards and notes</li>
              <li>Request corrections by emailing us</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">6.3 Deletion</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Delete your account and all associated data from settings</li>
              <li>Request deletion by emailing recall@moreclassescommerce.com</li>
              <li>We will delete your data within 30 days (some backup copies may persist up to 90 days)</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">6.4 Marketing Communications</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Opt out of marketing emails via the unsubscribe link</li>
              <li>Manage email preferences in account settings</li>
              <li>Note: We may still send essential service emails (receipts, password resets)</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">6.5 Objection and Restriction</h3>
            <p className="text-gray-700">
              You can object to certain data processing activities or request restricted 
              processing by contacting us at recall@moreclassescommerce.com.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">7. Data Retention</h2>
            <p className="text-gray-700 mb-4">
              We retain your information for as long as your account is active or as needed to 
              provide services. Retention periods:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>Account Data:</strong> Until you delete your account + 30 days</li>
              <li><strong>User Content:</strong> Until you delete it or close your account</li>
              <li><strong>Payment Records:</strong> 7 years (tax compliance requirement)</li>
              <li><strong>Analytics Data:</strong> Aggregated, anonymized, retained indefinitely</li>
              <li><strong>Backup Copies:</strong> Up to 90 days after deletion</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">8. Cookies and Tracking</h2>
            
            <h3 className="text-xl font-semibold text-gray-900 mb-3">8.1 Types of Cookies We Use</h3>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>Essential Cookies:</strong> Required for login and security (cannot be disabled)</li>
              <li><strong>Functional Cookies:</strong> Remember your preferences and settings</li>
              <li><strong>Analytics Cookies:</strong> Help us understand how you use the Service (PostHog)</li>
              <li><strong>Performance Cookies:</strong> Monitor errors and performance issues (Sentry)</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">8.2 Managing Cookies</h3>
            <p className="text-gray-700 mb-4">
              You can control cookies through your browser settings. Note that disabling cookies 
              may limit some functionality.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">9. Children's Privacy</h2>
            <p className="text-gray-700 mb-4">
              Our Service is intended for users aged 13 and above. We do not knowingly collect 
              personal information from children under 13.
            </p>
            <p className="text-gray-700 mb-4">
              If you are under 18, you must have permission from a parent or guardian to use 
              the Service.
            </p>
            <p className="text-gray-700">
              If we discover we have collected information from a child under 13, we will delete 
              it immediately. Parents can contact us at recall@moreclassescommerce.com.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">10. International Data Transfers</h2>
            <p className="text-gray-700 mb-4">
              Your information may be transferred to and stored on servers located outside India, 
              including:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>USA:</strong> Supabase, Vercel, Resend (GDPR-compliant)</li>
              <li><strong>India:</strong> Razorpay (primary payment processor)</li>
            </ul>
            <p className="text-gray-700">
              We ensure that any international transfers comply with applicable data protection 
              laws and use Standard Contractual Clauses approved by regulatory authorities.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">11. Third-Party Links</h2>
            <p className="text-gray-700">
              Our Service may contain links to third-party websites (e.g., Razorpay payment pages). 
              We are not responsible for the privacy practices of these sites. We encourage you to 
              read their privacy policies.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">12. Changes to This Policy</h2>
            <p className="text-gray-700 mb-4">
              We may update this Privacy Policy from time to time. Changes will be posted on this 
              page with an updated "Last updated" date.
            </p>
            <p className="text-gray-700 mb-4">
              For material changes, we will notify you via:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Email to your registered email address</li>
              <li>In-app notification</li>
              <li>Prominent notice on our website</li>
            </ul>
            <p className="text-gray-700">
              Continued use of the Service after changes constitutes acceptance of the updated policy.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">13. Contact Us</h2>
            <p className="text-gray-700 mb-4">
              If you have questions, concerns, or requests regarding your privacy or this policy, 
              please contact us:
            </p>
            <div className="bg-gray-50 p-6 rounded-lg">
              <p className="text-gray-900 font-semibold mb-2">Data Protection Officer</p>
              <p className="text-gray-700 mb-2">More Classes Commerce</p>
              <p className="text-gray-700">Email: recall@moreclassescommerce.com</p>
              <p className="text-gray-700">Location: Pune, Maharashtra, India</p>
              <p className="text-gray-700">Website: recall.moreclassescommerce.com</p>
              <p className="text-gray-700 mt-3">
                <strong>Response Time:</strong> We aim to respond within 48 hours
              </p>
            </div>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">14. Your Consent</h2>
            <p className="text-gray-700">
              By using Recall, you consent to the collection, use, and sharing of your information 
              as described in this Privacy Policy. If you do not agree, please do not use our Service.
            </p>
          </section>

          <div className="border-t pt-8 mt-12">
            <p className="text-sm text-gray-600">
              This Privacy Policy is effective as of December 26, 2025, and applies to all 
              information collected by Recall before and after this date.
            </p>
          </div>

        </div>
      </div>
    </div>
  );
}