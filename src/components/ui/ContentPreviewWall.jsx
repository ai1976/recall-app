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
  const [whatsapp, setWhatsapp] = useState('');
  const [course, setCourse] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim() || !whatsapp.trim() || !course) return;

    setLoading(true);
    try {
      const { error } = await supabase.from('access_requests').insert({
        name: name.trim(),
        whatsapp_number: whatsapp.trim(),
        course,
        content_id: contentId || null,
        content_type: contentType || null,
        content_name: contentName || null,
        requester_user_id: user?.id || null,
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
            <Label htmlFor="preview-whatsapp">WhatsApp Number</Label>
            <Input
              id="preview-whatsapp"
              type="tel"
              value={whatsapp}
              onChange={(e) => setWhatsapp(e.target.value)}
              placeholder="+91 98765 43210"
              required
            />
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
            disabled={loading || !name.trim() || !whatsapp.trim() || !course}
            className="w-full"
          >
            {loading ? 'Submitting...' : 'Notify me when available'}
          </Button>
        </form>
      )}
    </div>
  );
}
