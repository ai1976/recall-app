import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { CheckCircle, Zap, Users, BookOpen, ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

const COURSES = [
  'CA Foundation',
  'CA Intermediate',
  'CA Final',
  'CMA Foundation',
  'CMA Intermediate',
  'CMA Final',
  'CS Foundation',
  'CS Executive',
  'CS Professional',
  'Multiple / All courses',
  'Other',
];

export default function Educators() {
  const { user } = useAuth();
  const { toast } = useToast();

  const [instituteName, setInstituteName] = useState('');
  const [contactName, setContactName] = useState('');
  const [email, setEmail] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [whatsappWarning, setWhatsappWarning] = useState('');
  const [city, setCity] = useState('');
  const [course, setCourse] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Individual educator application (distinct from the institute inquiry form above)
  const [eduFullName, setEduFullName] = useState('');
  const [eduEmail, setEduEmail] = useState('');
  const [eduWhatsapp, setEduWhatsapp] = useState('');
  const [eduWhatsappWarning, setEduWhatsappWarning] = useState('');
  const [eduInstitute, setEduInstitute] = useState('');
  const [eduCredential, setEduCredential] = useState('');
  const [eduCourse, setEduCourse] = useState('');
  const [eduWhy, setEduWhy] = useState('');
  const [eduLoading, setEduLoading] = useState(false);
  const [eduSubmitted, setEduSubmitted] = useState(false);

  useEffect(() => {
    document.title = 'For Institutes & Educators — RevisOp';
    return () => { document.title = 'RevisOp' };
  }, []);

  const normalizeWhatsapp = (raw) => {
    const digits = raw.replace(/\D/g, '');
    if (raw.startsWith('+')) return raw; // already has country code
    if (digits.length === 10) return '+91' + digits; // assume India
    if (digits.startsWith('0') && digits.length === 11) return '+91' + digits.slice(1);
    return raw;
  };

  const handleWhatsappChange = (e) => {
    const val = e.target.value;
    setWhatsapp(val);
    if (val && !val.startsWith('+')) {
      setWhatsappWarning('No country code detected — we\'ll assume +91 (India) on submit.');
    } else {
      setWhatsappWarning('');
    }
  };

  const isValid = instituteName.trim() && contactName.trim() && whatsapp.trim();

  const handleEduWhatsappChange = (e) => {
    const val = e.target.value;
    setEduWhatsapp(val);
    if (val && !val.startsWith('+')) {
      setEduWhatsappWarning('No country code detected — we\'ll assume +91 (India) on submit.');
    } else {
      setEduWhatsappWarning('');
    }
  };

  const isEduValid = eduFullName.trim() && eduWhatsapp.trim() && eduCredential.trim();

  const handleEduSubmit = async (e) => {
    e.preventDefault();
    const normalizedWhatsapp = normalizeWhatsapp(eduWhatsapp.trim());
    if (!isEduValid) return;

    setEduLoading(true);
    try {
      const { data: refToken, error } = await supabase.rpc('submit_educator_application', {
        p_full_name: eduFullName.trim(),
        p_whatsapp_number: normalizedWhatsapp,
        p_credential_or_linkedin: eduCredential.trim(),
        p_email: eduEmail.trim() || null,
        p_institute_name: eduInstitute.trim() || null,
        p_course: eduCourse || null,
        p_why: eduWhy.trim() || null,
        p_requester_user_id: user?.id || null,
      });

      if (error) throw error;

      // Anonymous applicant: carry the ref_token the same way Signup.jsx's ?ref= param does,
      // so if they sign up in this browser later, an approved application auto-grants the role
      // (see link_access_request extension, docs/database/phase5/20_FUNCTIONS).
      if (!user?.id && refToken) {
        localStorage.setItem('revisop_access_ref', refToken);
      }

      setEduSubmitted(true);
    } catch (err) {
      console.error('Error submitting educator application:', err);
      toast({
        title: 'Error',
        description: 'Failed to submit. Please try again.',
        variant: 'destructive',
      });
    } finally {
      setEduLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const normalizedWhatsapp = normalizeWhatsapp(whatsapp.trim());
    if (!isValid) return;

    setLoading(true);
    try {
      const { error } = await supabase.rpc('submit_institute_inquiry', {
        p_institute_name: instituteName.trim(),
        p_contact_name: contactName.trim(),
        p_whatsapp_number: normalizedWhatsapp,
        p_email: email.trim() || null,
        p_city: city.trim() || null,
        p_course: course || null,
        p_message: message.trim() || null,
        p_requester_user_id: user?.id || null,
      });

      if (error) throw error;
      setSubmitted(true);
    } catch (err) {
      console.error('Error submitting institute inquiry:', err);
      toast({
        title: 'Error',
        description: 'Failed to submit. Please try again.',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-amber-50 to-white">
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <span className="text-2xl font-bold tracking-tight leading-none">
              <span style={{ color: '#f59e0b' }}>Revis</span><span style={{ color: '#1e1b4b' }}>Op</span>
            </span>
          </Link>
          <Link
            to="/"
            className="flex items-center gap-1 text-sm font-medium text-gray-600 hover:text-amber-600 transition"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to home
          </Link>
        </div>
      </header>

      {/* Hero */}
      <section className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center">
        <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
          Bring Your Institute onto RevisOp
        </h1>
        <p className="text-xl text-gray-600 max-w-2xl mx-auto">
          Auto-enrol your batch. Curate content once — every student benefits from spaced repetition, free.
        </p>
      </section>

      {/* Benefits + Form */}
      <section className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 pb-20">
        <div className="grid md:grid-cols-2 gap-8">
          {/* Benefits */}
          <div className="bg-[#1e1b4b] text-white p-8 rounded-xl">
            <h2 className="text-2xl font-bold mb-6">What You Get</h2>
            <ul className="space-y-4 mb-8">
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Dedicated Institute Setup</div>
                  <div className="text-amber-100 text-sm">Batch groups auto-created, students auto-enrolled on registration</div>
                </div>
              </li>
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Free for Students</div>
                  <div className="text-amber-100 text-sm">Social features, batch groups, and review tools are free for all enrolled students</div>
                </div>
              </li>
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Curated Content Control</div>
                  <div className="text-amber-100 text-sm">You control which flashcards and notes are visible to your batch</div>
                </div>
              </li>
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Bulk Upload or CSV</div>
                  <div className="text-amber-100 text-sm">Upload your complete study material once via CSV — we handle the rest</div>
                </div>
              </li>
            </ul>

            <div className="space-y-4 pt-6 border-t border-white/20">
              <div className="flex items-start space-x-4">
                <div className="bg-white/20 p-3 rounded-full flex-shrink-0">
                  <Zap className="h-6 w-6" />
                </div>
                <div>
                  <div className="font-semibold">Ready in 48 Hours</div>
                  <div className="text-amber-100 text-sm">Institute onboarding and batch setup done for you</div>
                </div>
              </div>
              <div className="flex items-start space-x-4">
                <div className="bg-white/20 p-3 rounded-full flex-shrink-0">
                  <Users className="h-6 w-6" />
                </div>
                <div>
                  <div className="font-semibold">Students Auto-Enrolled</div>
                  <div className="text-amber-100 text-sm">Students are automatically added to your batch on registration — no manual invites</div>
                </div>
              </div>
              <div className="flex items-start space-x-4">
                <div className="bg-white/20 p-3 rounded-full flex-shrink-0">
                  <BookOpen className="h-6 w-6" />
                </div>
                <div>
                  <div className="font-semibold">Content Pre-loaded</div>
                  <div className="text-amber-100 text-sm">Your CSV becomes your students' spaced repetition queue from Day 1</div>
                </div>
              </div>
            </div>
          </div>

          {/* Lead Form */}
          <div className="bg-white p-8 rounded-xl shadow-sm border border-gray-100">
            {submitted ? (
              <div className="h-full flex flex-col items-center justify-center text-center py-12">
                <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mb-4">
                  <CheckCircle className="h-8 w-8 text-green-600" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">Thanks — we've got it!</h3>
                <p className="text-gray-600 max-w-xs">
                  We'll reach out within 1–2 business days.
                </p>
              </div>
            ) : (
              <>
                <h2 className="text-2xl font-bold text-gray-900 mb-1">Get Your Institute on RevisOp</h2>
                <p className="text-sm text-gray-500 mb-6">
                  Tell us about your institute and we'll be in touch.
                </p>
                <form onSubmit={handleSubmit} className="space-y-4">
                  <div className="space-y-1">
                    <Label htmlFor="edu-institute">Institute / Coaching Name</Label>
                    <Input
                      id="edu-institute"
                      value={instituteName}
                      onChange={(e) => setInstituteName(e.target.value)}
                      placeholder="e.g. ABC Commerce Classes"
                      required
                    />
                  </div>
                  <div className="grid sm:grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <Label htmlFor="edu-contact-name">Contact Name</Label>
                      <Input
                        id="edu-contact-name"
                        value={contactName}
                        onChange={(e) => setContactName(e.target.value)}
                        placeholder="Your name"
                        required
                      />
                    </div>
                    <div className="space-y-1">
                      <Label htmlFor="edu-city">City</Label>
                      <Input
                        id="edu-city"
                        value={city}
                        onChange={(e) => setCity(e.target.value)}
                        placeholder="e.g. Mumbai"
                      />
                    </div>
                  </div>
                  <div className="grid sm:grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <Label htmlFor="edu-email">Email</Label>
                      <Input
                        id="edu-email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="you@example.com"
                      />
                    </div>
                    <div className="space-y-1">
                      <Label htmlFor="edu-whatsapp">WhatsApp Number</Label>
                      <Input
                        id="edu-whatsapp"
                        type="tel"
                        value={whatsapp}
                        onChange={handleWhatsappChange}
                        placeholder="+91 98765 43210"
                        required
                      />
                      {whatsappWarning && (
                        <p className="text-xs text-amber-600">{whatsappWarning}</p>
                      )}
                    </div>
                  </div>
                  <div className="space-y-1">
                    <Label>Course(s) of Interest</Label>
                    <Select value={course} onValueChange={setCourse}>
                      <SelectTrigger>
                        <SelectValue placeholder="Select course..." />
                      </SelectTrigger>
                      <SelectContent>
                        {COURSES.map((c) => (
                          <SelectItem key={c} value={c}>
                            {c}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1">
                    <Label htmlFor="edu-message">Message (optional)</Label>
                    <Textarea
                      id="edu-message"
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                      placeholder="Number of students, batches, anything else we should know..."
                      rows={3}
                    />
                  </div>
                  <Button
                    type="submit"
                    disabled={loading || !isValid}
                    className="w-full bg-[#1e1b4b] hover:bg-[#2d2a6e]"
                  >
                    {loading ? 'Submitting...' : 'Get My Institute on RevisOp'}
                  </Button>
                </form>
              </>
            )}
          </div>
        </div>
      </section>

      {/* Individual Educator Application — distinct from the institute inquiry above */}
      <section className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 pb-20">
        <div className="grid md:grid-cols-2 gap-8">
          {/* Benefits */}
          <div className="bg-[#1e1b4b] text-white p-8 rounded-xl">
            <h2 className="text-2xl font-bold mb-6">Apply to Teach on RevisOp</h2>
            <p className="text-amber-100 mb-6">
              Independent educator? Every Educator on RevisOp is personally vetted — that's what makes the "Educator" badge mean something to students.
            </p>
            <ul className="space-y-4">
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Verified Educator Badge</div>
                  <div className="text-amber-100 text-sm">Approved applicants get the Educator role — a visible trust signal to students</div>
                </div>
              </li>
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Publish Your Own Content</div>
                  <div className="text-amber-100 text-sm">Create and curate flashcards and notes for your students</div>
                </div>
              </li>
              <li className="flex items-start space-x-3">
                <CheckCircle className="h-6 w-6 text-green-300 mt-0.5 flex-shrink-0" />
                <div>
                  <div className="font-semibold">Deliberate, Human Review</div>
                  <div className="text-amber-100 text-sm">We manually review every application — no self-serve upgrades</div>
                </div>
              </li>
            </ul>
          </div>

          {/* Application Form */}
          <div className="bg-white p-8 rounded-xl shadow-sm border border-gray-100">
            {eduSubmitted ? (
              <div className="h-full flex flex-col items-center justify-center text-center py-12">
                <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mb-4">
                  <CheckCircle className="h-8 w-8 text-green-600" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">Application received!</h3>
                <p className="text-gray-600 max-w-xs">
                  We'll review and reach out within 1–2 business days.
                </p>
              </div>
            ) : (
              <>
                <h2 className="text-2xl font-bold text-gray-900 mb-1">Apply to Teach on RevisOp</h2>
                <p className="text-sm text-gray-500 mb-6">
                  Tell us about yourself and we'll review your application.
                </p>
                <form onSubmit={handleEduSubmit} className="space-y-4">
                  <div className="grid sm:grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <Label htmlFor="eduapp-name">Full Name</Label>
                      <Input
                        id="eduapp-name"
                        value={eduFullName}
                        onChange={(e) => setEduFullName(e.target.value)}
                        placeholder="Your name"
                        required
                      />
                    </div>
                    <div className="space-y-1">
                      <Label htmlFor="eduapp-whatsapp">WhatsApp Number</Label>
                      <Input
                        id="eduapp-whatsapp"
                        type="tel"
                        value={eduWhatsapp}
                        onChange={handleEduWhatsappChange}
                        placeholder="+91 98765 43210"
                        required
                      />
                      {eduWhatsappWarning && (
                        <p className="text-xs text-amber-600">{eduWhatsappWarning}</p>
                      )}
                    </div>
                  </div>
                  <div className="grid sm:grid-cols-2 gap-4">
                    <div className="space-y-1">
                      <Label htmlFor="eduapp-email">Email</Label>
                      <Input
                        id="eduapp-email"
                        type="email"
                        value={eduEmail}
                        onChange={(e) => setEduEmail(e.target.value)}
                        placeholder="you@example.com"
                      />
                    </div>
                    <div className="space-y-1">
                      <Label htmlFor="eduapp-institute">Institute / Coaching Name (optional)</Label>
                      <Input
                        id="eduapp-institute"
                        value={eduInstitute}
                        onChange={(e) => setEduInstitute(e.target.value)}
                        placeholder="Leave blank if independent"
                      />
                    </div>
                  </div>
                  <div className="space-y-1">
                    <Label htmlFor="eduapp-credential">Credential or LinkedIn URL</Label>
                    <Input
                      id="eduapp-credential"
                      value={eduCredential}
                      onChange={(e) => setEduCredential(e.target.value)}
                      placeholder="e.g. linkedin.com/in/yourname, or a qualification"
                      required
                    />
                  </div>
                  <div className="space-y-1">
                    <Label>Course(s) You Teach</Label>
                    <Select value={eduCourse} onValueChange={setEduCourse}>
                      <SelectTrigger>
                        <SelectValue placeholder="Select course..." />
                      </SelectTrigger>
                      <SelectContent>
                        {COURSES.map((c) => (
                          <SelectItem key={c} value={c}>
                            {c}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1">
                    <Label htmlFor="eduapp-why">Why do you want to teach on RevisOp? (optional)</Label>
                    <Textarea
                      id="eduapp-why"
                      value={eduWhy}
                      onChange={(e) => setEduWhy(e.target.value)}
                      placeholder="Tell us a bit about your teaching experience..."
                      rows={3}
                    />
                  </div>
                  <Button
                    type="submit"
                    disabled={eduLoading || !isEduValid}
                    className="w-full bg-[#1e1b4b] hover:bg-[#2d2a6e]"
                  >
                    {eduLoading ? 'Submitting...' : 'Submit Application'}
                  </Button>
                </form>
              </>
            )}
          </div>
        </div>
      </section>
    </div>
  );
}
