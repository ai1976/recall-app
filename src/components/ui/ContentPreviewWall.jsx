import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { Lock } from 'lucide-react';
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
  'Other',
];

export default function ContentPreviewWall({ contentId, contentType, contentName }) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [whatsappWarning, setWhatsappWarning] = useState('');
  const [course, setCourse] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);

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
    if (!name.trim() || !email.trim() || !normalizedWhatsapp || !course) return;

    setLoading(true);
    try {
      const { error } = await supabase.rpc('submit_access_request', {
        p_name: name.trim(),
        p_whatsapp_number: normalizedWhatsapp,
        p_course: course,
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
          <Button
            type="submit"
            disabled={loading || !name.trim() || !email.trim() || !whatsapp.trim() || !course}
            className="w-full"
          >
            {loading ? 'Submitting...' : 'Notify me when available'}
          </Button>
        </form>
      )}
    </div>
  );
}
