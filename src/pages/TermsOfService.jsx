import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

export default function TermsOfService() {
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
          <h1 className="text-3xl font-bold text-gray-900">Terms of Service</h1>
          <p className="text-gray-600 mt-2">Last updated: December 26, 2025</p>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="bg-white rounded-lg shadow-sm p-8 prose prose-blue max-w-none">
          
          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">1. Acceptance of Terms</h2>
            <p className="text-gray-700 mb-4">
              Welcome to Recall. By accessing or using our platform at recall.moreclassescommerce.com 
              ("Service"), you agree to be bound by these Terms of Service ("Terms"). If you do not 
              agree to these Terms, please do not use our Service.
            </p>
            <p className="text-gray-700">
              These Terms constitute a legally binding agreement between you and Recall 
              (operated by More Classes Commerce, Pune, Maharashtra, India).
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">2. Description of Service</h2>
            <p className="text-gray-700 mb-4">
              Recall is an AI-powered study platform that provides:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Digital flashcard creation and spaced repetition learning</li>
              <li>Note upload and OCR text extraction</li>
              <li>Expert-curated study content</li>
              <li>Community sharing and collaboration features</li>
              <li>Progress tracking and analytics</li>
            </ul>
            <p className="text-gray-700">
              We reserve the right to modify, suspend, or discontinue any part of the Service 
              at any time with or without notice.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">3. User Accounts</h2>
            
            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.1 Eligibility</h3>
            <p className="text-gray-700 mb-4">
              You must be at least 13 years old to use this Service. If you are under 18, 
              you must have permission from a parent or guardian.
            </p>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.2 Account Registration</h3>
            <p className="text-gray-700 mb-4">
              You must provide accurate, current, and complete information during registration. 
              You are responsible for:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Maintaining the confidentiality of your account credentials</li>
              <li>All activities that occur under your account</li>
              <li>Notifying us immediately of any unauthorized access</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">3.3 Account Termination</h3>
            <p className="text-gray-700">
              We reserve the right to suspend or terminate accounts that violate these Terms 
              or engage in fraudulent, abusive, or illegal activities.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">4. Subscription and Payments</h2>
            
            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.1 Pricing</h3>
            <p className="text-gray-700 mb-4">
              Our pricing plans are as follows:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li><strong>CA Foundation:</strong> Free</li>
              <li><strong>CA Intermediate:</strong> ₹149/month</li>
              <li><strong>CA Final:</strong> ₹499/6 months</li>
            </ul>
            <p className="text-gray-700 mb-4">
              Prices are in Indian Rupees (INR) and include applicable taxes.
            </p>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.2 Payment Processing</h3>
            <p className="text-gray-700 mb-4">
              Payments are processed securely through Razorpay. By making a payment, you agree to:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Provide accurate payment information</li>
              <li>Razorpay's terms and conditions</li>
              <li>Authorize recurring charges for subscription plans</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.3 Automatic Renewal</h3>
            <p className="text-gray-700 mb-4">
              Subscriptions automatically renew unless cancelled before the renewal date. 
              You will be charged the then-current subscription rate.
            </p>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">4.4 Refund Policy</h3>
            <p className="text-gray-700 mb-4">
              We offer a <strong>7-day money-back guarantee</strong> for new subscriptions. 
              Refund requests must be submitted within 7 days of purchase via email to 
              recall@moreclassescommerce.com.
            </p>
            <p className="text-gray-700">
              Refunds are processed within 7-10 business days to the original payment method.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">5. User Content</h2>
            
            <h3 className="text-xl font-semibold text-gray-900 mb-3">5.1 Your Content</h3>
            <p className="text-gray-700 mb-4">
              You retain ownership of all content you upload, create, or share on Recall 
              ("User Content"). By uploading User Content, you grant us a worldwide, 
              non-exclusive, royalty-free license to:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Store, display, and distribute your content within the Service</li>
              <li>Make your content available to other users if you choose to share it publicly</li>
              <li>Use your content to improve our Service and algorithms</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">5.2 Content Restrictions</h3>
            <p className="text-gray-700 mb-4">
              You may not upload content that:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Violates any copyright, trademark, or intellectual property rights</li>
              <li>Contains harmful, threatening, abusive, or defamatory material</li>
              <li>Promotes illegal activities or violates any laws</li>
              <li>Contains viruses, malware, or malicious code</li>
              <li>Impersonates any person or entity</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-900 mb-3">5.3 Content Moderation</h3>
            <p className="text-gray-700">
              We reserve the right to review, remove, or modify any User Content that 
              violates these Terms without prior notice.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">6. Intellectual Property</h2>
            <p className="text-gray-700 mb-4">
              The Recall platform, including its design, features, functionality, and content 
              (excluding User Content), is owned by More Classes Commerce and protected by 
              copyright, trademark, and other intellectual property laws.
            </p>
            <p className="text-gray-700">
              You may not copy, modify, distribute, sell, or reverse engineer any part of 
              the Service without our express written permission.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">7. Prohibited Activities</h2>
            <p className="text-gray-700 mb-4">
              You agree not to:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2">
              <li>Share your account credentials with others</li>
              <li>Use automated tools (bots, scrapers) to access the Service</li>
              <li>Attempt to hack, disrupt, or compromise the Service's security</li>
              <li>Engage in any activity that interferes with other users' access</li>
              <li>Use the Service for commercial purposes without authorization</li>
              <li>Violate any applicable local, state, national, or international law</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">8. Limitation of Liability</h2>
            <p className="text-gray-700 mb-4">
              To the maximum extent permitted by law, Recall and More Classes Commerce shall not be 
              liable for any indirect, incidental, special, consequential, or punitive damages, 
              including:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Loss of profits, data, or goodwill</li>
              <li>Service interruptions or failures</li>
              <li>Inaccuracy of content or study materials</li>
              <li>Third-party actions or content</li>
            </ul>
            <p className="text-gray-700">
              Our total liability shall not exceed the amount you paid for the Service in 
              the 12 months preceding the claim.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">9. Disclaimer of Warranties</h2>
            <p className="text-gray-700 mb-4">
              The Service is provided "as is" and "as available" without warranties of any kind, 
              either express or implied, including but not limited to:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
              <li>Merchantability or fitness for a particular purpose</li>
              <li>Accuracy, reliability, or completeness of content</li>
              <li>Uninterrupted or error-free operation</li>
              <li>Security or freedom from viruses</li>
            </ul>
            <p className="text-gray-700">
              <strong>Educational Disclaimer:</strong> Recall is a study tool and does not 
              guarantee exam success. Results depend on individual effort and preparation.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">10. Indemnification</h2>
            <p className="text-gray-700">
              You agree to indemnify and hold harmless Recall, More Classes Commerce, and their 
              affiliates from any claims, damages, losses, or expenses arising from:
            </p>
            <ul className="list-disc pl-6 text-gray-700 space-y-2">
              <li>Your use of the Service</li>
              <li>Your User Content</li>
              <li>Your violation of these Terms</li>
              <li>Your violation of any rights of another party</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">11. Governing Law and Jurisdiction</h2>
            <p className="text-gray-700 mb-4">
              These Terms shall be governed by and construed in accordance with the laws of India. 
              Any disputes arising from these Terms or your use of the Service shall be subject to 
              the exclusive jurisdiction of the courts in Pune, Maharashtra, India.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">12. Changes to Terms</h2>
            <p className="text-gray-700 mb-4">
              We reserve the right to modify these Terms at any time. Changes will be effective 
              immediately upon posting. Your continued use of the Service after changes constitutes 
              acceptance of the modified Terms.
            </p>
            <p className="text-gray-700">
              We will notify users of material changes via email or in-app notification.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">13. Severability</h2>
            <p className="text-gray-700">
              If any provision of these Terms is found to be unenforceable or invalid, that 
              provision will be limited or eliminated to the minimum extent necessary, and the 
              remaining provisions will remain in full force and effect.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">14. Contact Information</h2>
            <p className="text-gray-700 mb-4">
              For questions about these Terms, please contact us:
            </p>
            <div className="bg-gray-50 p-6 rounded-lg">
              <p className="text-gray-900 font-semibold mb-2">More Classes Commerce</p>
              <p className="text-gray-700">Email: recall@moreclassescommerce.com</p>
              <p className="text-gray-700">Location: Pune, Maharashtra, India</p>
              <p className="text-gray-700">Website: recall.moreclassescommerce.com</p>
            </div>
          </section>

          <div className="border-t pt-8 mt-12">
            <p className="text-sm text-gray-600">
              By using Recall, you acknowledge that you have read, understood, and agree to be 
              bound by these Terms of Service.
            </p>
          </div>

        </div>
      </div>
    </div>
  );
}