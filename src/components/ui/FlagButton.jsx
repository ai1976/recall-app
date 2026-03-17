import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useToast } from '@/hooks/use-toast';
import { Flag } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Label } from '@/components/ui/label';

export default function FlagButton({ contentType, contentId }) {
  const { toast } = useToast();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!reason) return;
    setLoading(true);
    try {
      const { error } = await supabase.rpc('submit_content_flag', {
        p_content_type: contentType,
        p_content_id: contentId,
        p_reason: reason,
      });
      if (error) throw error;
      setOpen(false);
      setReason('');
      toast({ title: "Thanks, we'll review this." });
    } catch (err) {
      console.error('Error submitting flag:', err);
      toast({
        title: 'Error',
        description: err.message || 'Failed to submit flag',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Button
        variant="ghost"
        size="sm"
        className="text-gray-500 hover:text-red-600 hover:bg-red-50 h-7 px-2 gap-1 text-xs"
        onClick={(e) => {
          e.stopPropagation();
          setOpen(true);
        }}
      >
        <Flag className="h-3 w-3" />
        Report
      </Button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Flag this content</DialogTitle>
            <DialogDescription>
              Help us maintain quality. Select a reason and our team will review it.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <Label>Reason</Label>
            <Select value={reason} onValueChange={setReason}>
              <SelectTrigger>
                <SelectValue placeholder="Select a reason..." />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="Content error">Content error</SelectItem>
                <SelectItem value="Inappropriate">Inappropriate</SelectItem>
                <SelectItem value="Other">Other</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleSubmit} disabled={!reason || loading}>
              {loading ? 'Submitting...' : 'Submit Flag'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
