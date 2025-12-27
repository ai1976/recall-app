import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

export default function TermsOfService() {
  return (
    <div className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Back to Home */}
        <Link 
          to="/" 
          className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-8"
        >
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to Home
        </Link>

        {/* Header */}
        <div className="bg-white rounded-lg shadow-sm p-8 mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-4">Terms of Service</h1>
          <p className="text-sm text-gray-600">
            Last Updated: December 27, 2025
          </p>
          <p className="text-sm text-gray-600 mt-2">
            Effective Date: December 27, 2025
          </p>
        </div>

        {/* Content */}
        <div className="bg-white rounded-lg shadow-sm p-8 space-y-8">
          
          {/* 1. Agreement to Terms */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">1. Agreement to Terms</h2>
            <p className="text-gray-700 leading-relaxed">
              By accessing or using Recall ("the Platform", "Service", "we", "us", or "our"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, you may not access or use the Service.
            </p>
            <p className="text-gray-700 leading-relaxed mt-4">
              These Terms constitute a legally binding agreement between you ("User", "you", or "your") and Recall, operated by More Classes Commerce, located in Pune, Maharashtra, India.
            </p>
          </section>

          {/* 2. Description of Service */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">2. Description of Service</h2>
            <p className="text-gray-700 leading-relaxed">
              Recall is a web-based study platform designed for professional students, competitive exam aspirants, and lifelong learners across various disciplines including but not limited to professional certifications (CA, CMA, CS, CFA, ACCA), competitive exams (JEE, NEET, UPSC), and other educational programs.
            </p>
            <p className="text-gray-700 leading-relaxed mt-4">
              The platform provides:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-4 space-y-2 ml-4">
              <li>Digital note management and organization across multiple subjects and courses</li>
              <li>Flashcard creation and spaced repetition learning tools</li>
              <li>Content sharing and collaboration features</li>
              <li>Progress tracking and analytics</li>
              <li>Access to faculty-contributed and peer-created educational content</li>
              <li>Multi-course and multi-discipline support</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              The Service is provided on a freemium basis with optional paid subscription tiers offering enhanced features, increased storage, and access to premium content across various courses and subjects.
            </p>
          </section>

          {/* 3. Account Registration and Security */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">3. Account Registration and Security</h2>
            <h3 className="text-lg font-semibold text-gray-800 mb-2">3.1 Account Creation</h3>
            <p className="text-gray-700 leading-relaxed">
              To access certain features, you must create an account by providing accurate, current, and complete information. You agree to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Provide truthful and accurate registration information</li>
              <li>Maintain and update your information to keep it accurate</li>
              <li>Not create accounts for anyone other than yourself without permission</li>
              <li>Not create multiple accounts for yourself</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">3.2 Account Security</h3>
            <p className="text-gray-700 leading-relaxed">
              You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Use a strong, unique password</li>
              <li>Not share your account credentials with others</li>
              <li>Notify us immediately of any unauthorized access or security breach</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">3.3 Account Termination</h3>
            <p className="text-gray-700 leading-relaxed">
              We reserve the right to suspend or terminate your account if we determine, in our sole discretion, that you have violated these Terms or engaged in fraudulent, abusive, or illegal activity.
            </p>
          </section>

          {/* 4. Subscription Plans and Pricing */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">4. Subscription Plans and Pricing</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">4.1 Freemium Model</h3>
            <p className="text-gray-700 leading-relaxed">
              Recall operates on a freemium model with the following structure:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li><strong>Free Tier:</strong> Basic access to core features with certain limitations on content, storage, or functionality</li>
              <li><strong>Paid Subscriptions:</strong> Enhanced access with additional features, premium content, increased storage, and advanced tools</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">4.2 Pricing</h3>
            <p className="text-gray-700 leading-relaxed">
              Subscription pricing is displayed on our pricing page and may vary based on:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Course or program selected (professional certifications, competitive exams, etc.)</li>
              <li>Course level or difficulty (Foundation, Intermediate, Advanced, etc.)</li>
              <li>Subscription duration (monthly, quarterly, annual)</li>
              <li>Number of courses or subjects included</li>
              <li>Promotional offers or discounts</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              All prices are listed in Indian Rupees (INR) and are inclusive of applicable taxes unless otherwise stated. We reserve the right to modify pricing at any time, with advance notice to existing subscribers for changes affecting their current subscription.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">4.3 Free Trial (If Applicable)</h3>
            <p className="text-gray-700 leading-relaxed">
              We may offer free trial periods for paid subscriptions. At the end of the trial period, your subscription will automatically convert to a paid subscription unless you cancel before the trial expires. Payment information must be provided to start a trial.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">4.4 No Free-Forever Guarantee</h3>
            <p className="text-gray-700 leading-relaxed">
              While we offer a free tier with access to basic features and limited content, <strong>no course, subject, or content is guaranteed to remain free forever</strong>. We reserve the right to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Move free content to paid subscription tiers</li>
              <li>Introduce subscription requirements for previously free courses or subjects</li>
              <li>Modify feature availability and storage limits across different tiers</li>
              <li>Add new paid courses, subjects, or content at any time</li>
              <li>Discontinue or archive certain courses or content</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              Users will be notified in advance of any significant changes to content accessibility or pricing that affects their current subscription.
            </p>
          </section>

          {/* 5. Payment and Billing */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">5. Payment and Billing</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">5.1 Payment Processing</h3>
            <p className="text-gray-700 leading-relaxed">
              Payments are processed securely through Razorpay, our third-party payment processor. By subscribing, you authorize us to charge your provided payment method. You agree to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Provide current, complete, and accurate payment information</li>
              <li>Update your payment information promptly if it changes</li>
              <li>Pay all charges incurred at the prices in effect when such charges are incurred</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">5.2 Automatic Renewal</h3>
            <p className="text-gray-700 leading-relaxed">
              Paid subscriptions automatically renew at the end of each billing period (monthly, quarterly, or annually) unless cancelled before the renewal date. You will be charged the then-current subscription fee unless you cancel your subscription.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">5.3 Cancellation</h3>
            <p className="text-gray-700 leading-relaxed">
              You may cancel your subscription at any time through your account settings or by contacting customer support. Upon cancellation:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>You will retain access to paid features until the end of your current billing period</li>
              <li>No charges will be applied for subsequent billing periods</li>
              <li>Your account will revert to the free tier at the end of the paid period</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">5.4 Failed Payments</h3>
            <p className="text-gray-700 leading-relaxed">
              If your payment fails, we will notify you and attempt to process payment again. If payment continues to fail, your subscription may be suspended or downgraded to the free tier.
            </p>
          </section>

          {/* 6. Refund Policy */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">6. Refund Policy</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">6.1 No Refunds</h3>
            <p className="text-gray-700 leading-relaxed">
              <strong>All subscription payments are final and non-refundable.</strong> This policy applies to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Monthly, quarterly, and annual subscriptions</li>
              <li>Partial billing periods (no pro-rata refunds)</li>
              <li>Early cancellations (you retain access until period end but receive no refund)</li>
              <li>Unused portions of subscriptions</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">6.2 Platform-as-a-Service Nature</h3>
            <p className="text-gray-700 leading-relaxed">
              Recall is provided as a platform-as-a-service (PaaS). Upon payment, you receive immediate access to the subscribed features and content. Due to the nature of digital services and instant access provision, <strong>we do not offer refunds, returns, or exchanges</strong> under any circumstances, including but not limited to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Change of mind or dissatisfaction with content</li>
              <li>Lack of use or engagement with the platform</li>
              <li>Technical difficulties on your end (device compatibility, internet connectivity)</li>
              <li>Failure to cancel before automatic renewal</li>
              <li>Academic performance or exam outcomes</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">6.3 Exceptional Circumstances</h3>
            <p className="text-gray-700 leading-relaxed">
              In rare cases of technical errors resulting in duplicate charges or overcharging, we may issue refunds at our sole discretion. Such requests must be submitted to <a href="mailto:support@recallapp.in" className="text-blue-600 hover:underline">support@recallapp.in</a> within 7 days of the charge with supporting evidence.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">6.4 Free Trial Conversion</h3>
            <p className="text-gray-700 leading-relaxed">
              If you do not cancel before your free trial ends, you will be charged for the subscription. This charge is non-refundable. We recommend setting a reminder to cancel before the trial period expires if you do not wish to continue with a paid subscription.
            </p>
          </section>

          {/* 7. User Content and Conduct */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">7. User Content and Conduct</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">7.1 Your Content</h3>
            <p className="text-gray-700 leading-relaxed">
              You retain ownership of all content you upload, create, or share on Recall ("User Content"). By uploading User Content, you grant us a non-exclusive, worldwide, royalty-free license to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Store, display, and transmit your content within the platform</li>
              <li>Allow other users to view content you've marked as public or shared</li>
              <li>Create backups and ensure platform functionality</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">7.2 Content Restrictions</h3>
            <p className="text-gray-700 leading-relaxed">
              You agree not to upload or share content that:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Infringes on intellectual property rights of others</li>
              <li>Contains malicious code, viruses, or harmful software</li>
              <li>Is illegal, defamatory, obscene, or offensive</li>
              <li>Violates the privacy or rights of others</li>
              <li>Contains spam, advertising, or promotional material (unless authorized)</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">7.3 Content Moderation</h3>
            <p className="text-gray-700 leading-relaxed">
              We reserve the right to review, moderate, or remove any User Content that violates these Terms or is otherwise objectionable, without prior notice.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">7.4 Prohibited Conduct</h3>
            <p className="text-gray-700 leading-relaxed">
              You agree not to:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Use the Service for any illegal purpose</li>
              <li>Attempt to gain unauthorized access to other accounts or systems</li>
              <li>Interfere with or disrupt the Service or servers</li>
              <li>Use automated systems (bots, scrapers) without permission</li>
              <li>Share your account credentials or allow account sharing</li>
              <li>Reverse engineer, decompile, or modify the platform</li>
            </ul>
          </section>

          {/* 8. Intellectual Property Rights */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">8. Intellectual Property Rights</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">8.1 Platform Ownership</h3>
            <p className="text-gray-700 leading-relaxed">
              All content, features, functionality, software, and materials on Recall (excluding User Content) are owned by us or our licensors and are protected by copyright, trademark, and other intellectual property laws.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">8.2 Limited License</h3>
            <p className="text-gray-700 leading-relaxed">
              We grant you a limited, non-exclusive, non-transferable, revocable license to access and use the Service for personal, non-commercial educational purposes, subject to these Terms.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">8.3 Restrictions</h3>
            <p className="text-gray-700 leading-relaxed">
              You may not:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Copy, reproduce, or distribute platform content without permission</li>
              <li>Create derivative works from our content</li>
              <li>Use our trademarks, logos, or branding without authorization</li>
              <li>Remove or alter any copyright or proprietary notices</li>
            </ul>
          </section>

          {/* 9. Privacy and Data Protection */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">9. Privacy and Data Protection</h2>
            <p className="text-gray-700 leading-relaxed">
              Your use of the Service is also governed by our <Link to="/privacy-policy" className="text-blue-600 hover:underline">Privacy Policy</Link>, which explains how we collect, use, and protect your personal information. By using Recall, you consent to the practices described in the Privacy Policy.
            </p>
          </section>

          {/* 10. Third-Party Services */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">10. Third-Party Services</h2>
            <p className="text-gray-700 leading-relaxed">
              Our Service may integrate with third-party services (e.g., Razorpay for payments, Supabase for data storage). Your use of these third-party services is subject to their respective terms and privacy policies. We are not responsible for the practices or content of third-party services.
            </p>
          </section>

          {/* 11. Disclaimers and Limitations of Liability */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">11. Disclaimers and Limitations of Liability</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">11.1 "As Is" Basis</h3>
            <p className="text-gray-700 leading-relaxed">
              THE SERVICE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">11.2 No Guarantee of Results</h3>
            <p className="text-gray-700 leading-relaxed">
              We do not guarantee that use of Recall will result in improved academic performance, exam success, or any specific learning outcomes. Your success depends on various factors including personal effort, study habits, and inherent ability.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">11.3 Service Availability</h3>
            <p className="text-gray-700 leading-relaxed">
              We do not guarantee uninterrupted, secure, or error-free operation of the Service. The platform may be unavailable due to maintenance, technical issues, or circumstances beyond our control.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">11.4 Limitation of Liability</h3>
            <p className="text-gray-700 leading-relaxed">
              TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, REVENUE, DATA, OR USE, ARISING OUT OF OR RELATED TO YOUR USE OF THE SERVICE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
            </p>
            <p className="text-gray-700 leading-relaxed mt-4">
              Our total liability to you for all claims arising from or related to the Service shall not exceed the amount you paid us in the twelve (12) months preceding the claim, or ₹1,000, whichever is greater.
            </p>
          </section>

          {/* 12. Indemnification */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">12. Indemnification</h2>
            <p className="text-gray-700 leading-relaxed">
              You agree to indemnify, defend, and hold harmless Recall, More Classes Commerce, and our officers, directors, employees, and agents from any claims, liabilities, damages, losses, costs, or expenses (including reasonable attorneys' fees) arising from:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Your use or misuse of the Service</li>
              <li>Your violation of these Terms</li>
              <li>Your violation of any rights of another person or entity</li>
              <li>Your User Content</li>
            </ul>
          </section>

          {/* 13. Modifications to Terms */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">13. Modifications to Terms</h2>
            <p className="text-gray-700 leading-relaxed">
              We reserve the right to modify these Terms at any time. We will notify users of material changes by:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Posting updated Terms on this page with a new "Last Updated" date</li>
              <li>Sending email notification to registered users (for significant changes)</li>
              <li>Displaying a notice within the platform</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              Your continued use of the Service after changes become effective constitutes acceptance of the modified Terms. If you do not agree to the modified Terms, you must stop using the Service and cancel your subscription.
            </p>
          </section>

          {/* 14. Termination */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">14. Termination</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">14.1 Termination by You</h3>
            <p className="text-gray-700 leading-relaxed">
              You may terminate your account at any time by contacting customer support or using account deletion features. Upon termination, your access to paid features will continue until the end of your current billing period.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">14.2 Termination by Us</h3>
            <p className="text-gray-700 leading-relaxed">
              We may suspend or terminate your account immediately, without prior notice or liability, if:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>You breach these Terms</li>
              <li>Your conduct harms or could harm other users or us</li>
              <li>You engage in fraudulent, illegal, or abusive activity</li>
              <li>Required by law or legal process</li>
            </ul>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">14.3 Effect of Termination</h3>
            <p className="text-gray-700 leading-relaxed">
              Upon termination:
            </p>
            <ul className="list-disc list-inside text-gray-700 mt-2 space-y-1 ml-4">
              <li>Your right to access the Service ceases immediately</li>
              <li>We may delete your User Content and account data (subject to legal requirements)</li>
              <li>No refunds will be provided for unused subscription periods</li>
              <li>Provisions of these Terms that by their nature should survive (indemnification, disclaimers, limitations of liability) will continue to apply</li>
            </ul>
          </section>

          {/* 15. Dispute Resolution and Governing Law */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">15. Dispute Resolution and Governing Law</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">15.1 Governing Law</h3>
            <p className="text-gray-700 leading-relaxed">
              These Terms shall be governed by and construed in accordance with the laws of India, without regard to conflict of law principles.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">15.2 Jurisdiction</h3>
            <p className="text-gray-700 leading-relaxed">
              Any disputes arising out of or related to these Terms or the Service shall be subject to the exclusive jurisdiction of the courts located in Pune, Maharashtra, India.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">15.3 Informal Resolution</h3>
            <p className="text-gray-700 leading-relaxed">
              Before filing a legal claim, you agree to first contact us at <a href="mailto:support@recallapp.in" className="text-blue-600 hover:underline">support@recallapp.in</a> to attempt to resolve the dispute informally. We will make a good faith effort to resolve disputes amicably.
            </p>
          </section>

          {/* 16. Miscellaneous */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">16. Miscellaneous</h2>
            
            <h3 className="text-lg font-semibold text-gray-800 mb-2">16.1 Entire Agreement</h3>
            <p className="text-gray-700 leading-relaxed">
              These Terms, together with our Privacy Policy, constitute the entire agreement between you and us regarding the Service and supersede all prior agreements and understandings.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">16.2 Severability</h3>
            <p className="text-gray-700 leading-relaxed">
              If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions will remain in full force and effect.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">16.3 Waiver</h3>
            <p className="text-gray-700 leading-relaxed">
              Our failure to enforce any right or provision of these Terms will not be deemed a waiver of such right or provision.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">16.4 Assignment</h3>
            <p className="text-gray-700 leading-relaxed">
              You may not assign or transfer these Terms or your account to any third party without our prior written consent. We may assign these Terms without restriction.
            </p>

            <h3 className="text-lg font-semibold text-gray-800 mb-2 mt-4">16.5 Force Majeure</h3>
            <p className="text-gray-700 leading-relaxed">
              We shall not be liable for any delay or failure to perform resulting from causes beyond our reasonable control, including but not limited to natural disasters, war, terrorism, riots, embargoes, acts of civil or military authorities, fire, floods, accidents, pandemics, strikes, or shortages of transportation, facilities, fuel, energy, labor, or materials.
            </p>
          </section>

          {/* Contact Information */}
          <section>
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">17. Contact Information</h2>
            <p className="text-gray-700 leading-relaxed">
              If you have any questions, concerns, or complaints regarding these Terms or the Service, please contact us:
            </p>
            <div className="bg-gray-50 p-6 rounded-lg mt-4">
              <p className="text-gray-700"><strong>Recall</strong></p>
              <p className="text-gray-700">Operated by: More Classes Commerce</p>
              <p className="text-gray-700">Location: Pune, Maharashtra, India</p>
              <p className="text-gray-700 mt-2">
                Email: <a href="mailto:support@recallapp.in" className="text-blue-600 hover:underline">support@recallapp.in</a>
              </p>
              <p className="text-gray-700">
                Website: <a href="https://recallapp.in" className="text-blue-600 hover:underline">https://recallapp.in</a>
              </p>
            </div>
          </section>

          {/* Acceptance */}
          <section className="border-t pt-8">
            <p className="text-gray-700 leading-relaxed">
              <strong>By creating an account and using Recall, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.</strong>
            </p>
          </section>
        </div>

        {/* Footer */}
        <div className="mt-8 text-center">
          <Link 
            to="/" 
            className="inline-flex items-center text-blue-600 hover:text-blue-800"
          >
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Home
          </Link>
        </div>
      </div>
    </div>
  );
}