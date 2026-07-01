import { useState, useEffect } from 'react';
import { Star } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';

export default function FeatureNominationButton({ contentType, contentId, isFeatured, isNominated }) {
  const { toast } = useToast();
  const [status, setStatus] = useState(isFeatured ? 'live' : isNominated ? 'pending' : 'none');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setStatus(isFeatured ? 'live' : isNominated ? 'pending' : 'none');
  }, [isFeatured, isNominated]);

  const handleNominate = async () => {
    setLoading(true);
    try {
      const { error } = await supabase.rpc('nominate_featured_content', {
        p_content_type: contentType,
        p_content_id: contentId,
      });
      if (error) throw error;
      setStatus('pending');
      toast({
        title: 'Nominated for landing page',
        description: 'An admin will review this submission.',
      });
    } catch (error) {
      console.error('nominate_featured_content:', error);
      toast({
        title: 'Nomination failed',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  if (status === 'live') {
    return (
      <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full bg-amber-100 text-[#1e1b4b] font-medium">
        <Star className="h-3 w-3 fill-amber-500 text-amber-500" />
        Featured
      </span>
    );
  }

  if (status === 'pending') {
    return (
      <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full bg-gray-100 text-gray-600 font-medium">
        Pending review
      </span>
    );
  }

  return (
    <Button
      size="sm"
      variant="outline"
      className="text-xs h-7 px-2 text-amber-700 border-amber-300 hover:bg-amber-50"
      onClick={handleNominate}
      disabled={loading}
    >
      <Star className="h-3 w-3 mr-1" />
      {loading ? 'Nominating…' : 'Feature on landing'}
    </Button>
  );
}
