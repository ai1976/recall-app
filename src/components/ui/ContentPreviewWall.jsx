import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { submitAccessRequest } from '@/lib/dueSet';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { Lock } from 'lucide-react';
import { validateCourseLabel, COURSE_LABEL_MAX } from '@/lib/courseLabel';
import { OTHER_OPTION, describeCourseRow, matchTypedCourse } from '@/lib/courseOptions';
import { useCourseOptions } from '@/hooks/useCourseOptions';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

export default function ContentPreviewWall({ contentId, contentType, contentName }) {
  const { user, loading: authLoading } = useAuth();
  const { toast } = useToast();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [whatsappWarning, setWhatsappWarning] = useState('');
  const [chosenCourse, setChosenCourse] = useState('');
  // T-002 F1: the course list is the database's catalogue: the public list for a visitor, the student's own list (current course first-class,
  // "no longer offered" marked) for a signed-in student. The student's current course is preselected until they choose another.
  const courseList = useCourseOptions('access');
  const currentRow = courseList.rows.find((row) => row.is_current) || null;
  const course = chosenCourse !== '' ? chosenCourse : (currentRow ? currentRow.label : '');
  const setCourse = setChosenCourse;
  const [savedCourseTooLong, setSavedCourseTooLong] = useState(false);
  const [customCourse, setCustomCourse] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // A saved course longer than the limit is never listed (brief B 5.4): the field stays empty and the student is told why.
  useEffect(() => {
    if (authLoading || !user) return undefined;
    let cancelled = false;
    supabase.from('profiles').select('course_level').eq('id', user.id).single().then(({ data }) => {
      if (!cancelled) setSavedCourseTooLong(typeof data?.course_level === 'string' && Array.from(data.course_level.trim()).length > COURSE_LABEL_MAX);
    });
    return () => {
      cancelled = true;
    };
  }, [user, authLoading]);

  // Shown while typing, before submit (an empty box keeps the button disabled).
  const customCourseError = course === OTHER_OPTION && customCourse !== '' && !validateCourseLabel(customCourse).ok
    ? validateCourseLabel(customCourse).error
    : '';

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

  const handleSubmit = async (e) => {
    e.preventDefault();
    const normalizedWhatsapp = normalizeWhatsapp(whatsapp.trim());
    if (courseList.status !== 'ready' || !name.trim() || !email.trim() || !normalizedWhatsapp || !course) return;

    // The course sent is either a listed course or the typed text, trimmed and checked by the same rule as Signup (never the dropdown's own entry).
    let courseToSend = course;
    if (course === OTHER_OPTION) {
      const check = validateCourseLabel(customCourse);
      if (!check.ok) return;
      // A typed course that is already in the list is sent as that listed course.
      const listed = courseList.status === 'ready' ? matchTypedCourse(courseList.rows, check.value) : null;
      courseToSend = listed ? listed.label : check.value;
    }

    setLoading(true);
    try {
      const { error } = await submitAccessRequest({
        p_name: name.trim(),
        p_whatsapp_number: normalizedWhatsapp,
        p_course: courseToSend,
        p_email: email.trim() || null,
        p_content_id: contentId || null,
        p_content_type: contentType || null,
        p_content_name: contentName || null,
        p_requester_user_id: user?.id || null,
      });

      if (error) throw error;
      setSubmitted(true);
    } catch (err) {
      console.error('Error submitting access request:', err);
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
    <div className="flex flex-col items-center justify-center py-12 px-6 bg-gradient-to-b from-gray-50 to-white border-t border-gray-100">
      <div className="w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center mb-4">
        <Lock className="h-8 w-8 text-gray-400" />
      </div>
      <h3 className="text-lg font-semibold text-gray-900 mb-1">Full access coming soon</h3>
      <p className="text-sm text-gray-500 mb-8 text-center max-w-xs">
        Leave your WhatsApp number to get notified when full access is available.
      </p>

      {submitted ? (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 text-center max-w-xs">
          <p className="text-green-800 font-medium text-sm">
            Thanks, we&apos;ll review this and reach out!
          </p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="w-full max-w-xs space-y-4">
          <div className="space-y-1">
            <Label htmlFor="preview-name">Name</Label>
            <Input
              id="preview-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Your name"
              required
            />
          </div>
          <div className="space-y-1">
            <Label htmlFor="preview-email">Email</Label>
            <Input
              id="preview-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              required
            />
          </div>
          <div className="space-y-1">
            <Label htmlFor="preview-whatsapp">WhatsApp Number</Label>
            <Input
              id="preview-whatsapp"
              type="tel"
              value={whatsapp}
              onChange={handleWhatsappChange}
              placeholder="+91 98765 43210"
              required
            />
            {whatsappWarning ? (
              <p className="text-xs text-amber-600">{whatsappWarning}</p>
            ) : (
              <p className="text-xs text-gray-400">Include country code, e.g. +91 for India</p>
            )}
          </div>
          <div className="space-y-1">
            <Label>Course preparing for</Label>
            <Select value={course} onValueChange={setCourse} disabled={courseList.status !== 'ready'}>
              <SelectTrigger>
                <SelectValue placeholder={courseList.status === 'error' ? 'Courses could not be loaded' : 'Select course...'} />
              </SelectTrigger>
              <SelectContent>
                {courseList.rows.map((row) => (row.kind === 'other_action'
                  ? <SelectItem key="other-action" value={OTHER_OPTION}>{row.label}</SelectItem>
                  : <SelectItem key={`${row.kind}-${row.label}`} value={row.label}>{describeCourseRow(row)}</SelectItem>))}
              </SelectContent>
            </Select>
            {courseList.status === 'error' && (
              <p role="alert" className="text-xs text-red-600">
                The course list could not be loaded.{' '}
                <button type="button" onClick={courseList.reload} className="underline">Try again</button>
              </p>
            )}
            {savedCourseTooLong && !currentRow && chosenCourse === '' && (
              <p role="status" className="text-xs text-amber-700">
                Your saved course is too long to use as a name. Choose a course or type a shorter one.
              </p>
            )}
          </div>
          {course === OTHER_OPTION && (
            <div className="space-y-1">
              <Label htmlFor="preview-custom-course">Your course</Label>
              <Input
                id="preview-custom-course"
                value={customCourse}
                onChange={(e) => setCustomCourse(e.target.value)}
                placeholder="e.g. CFA Level 1"
                aria-invalid={customCourseError ? 'true' : 'false'}
                aria-describedby={customCourseError ? 'preview-custom-course-error' : undefined}
              />
              {customCourseError && (
                <p id="preview-custom-course-error" role="alert" className="text-xs text-red-600">{customCourseError}</p>
              )}
            </div>
          )}
          <Button
            type="submit"
            disabled={loading || courseList.status !== 'ready' || !name.trim() || !email.trim() || !whatsapp.trim() || !course || (course === OTHER_OPTION && !validateCourseLabel(customCourse).ok)}
            className="w-full"
          >
            {loading ? 'Submitting...' : 'Notify me when available'}
          </Button>
        </form>
      )}
    </div>
  );
}
