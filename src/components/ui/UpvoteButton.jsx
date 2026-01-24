import { useState, useEffect } from 'react';
import { ThumbsUp } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';

/**
 * UpvoteButton Component
 * 
 * A reusable upvote button that supports both notes and flashcard_decks.
 * Features:
 * - Toggle behavior (upvote/un-upvote)
 * - Optimistic UI updates
 * - Prevents self-upvoting
 * - Shows count
 * 
 * @param {string} contentType - 'note' or 'flashcard_deck'
 * @param {string} targetId - UUID of the content
 * @param {number} initialCount - Initial upvote count (from parent query)
 * @param {string} ownerId - UUID of content owner (to prevent self-upvoting)
 * @param {string} size - 'sm' | 'md' | 'lg' (default: 'md')
 * @param {boolean} showCount - Whether to show the count (default: true)
 * @param {string} className - Additional CSS classes
 */
export default function UpvoteButton({
  contentType,
  targetId,
  initialCount = 0,
  ownerId,
  size = 'md',
  showCount = true,
  className = ''
}) {
  const { user } = useAuth();
  const { toast } = useToast();
  
  const [upvoteCount, setUpvoteCount] = useState(initialCount);
  const [hasUpvoted, setHasUpvoted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isChecking, setIsChecking] = useState(true);

  // Check if user has already upvoted this content
  useEffect(() => {
    if (!user || !targetId) {
      setIsChecking(false);
      return;
    }

    const checkUpvoteStatus = async () => {
      try {
        const { data, error } = await supabase
          .from('upvotes')
          .select('id')
          .eq('content_type', contentType)
          .eq('target_id', targetId)
          .eq('user_id', user.id)
          .maybeSingle();

        if (error) throw error;
        setHasUpvoted(!!data);
      } catch (error) {
        console.error('Error checking upvote status:', error);
      } finally {
        setIsChecking(false);
      }
    };

    checkUpvoteStatus();
  }, [user, contentType, targetId]);

  // Update count when initialCount prop changes
  useEffect(() => {
    setUpvoteCount(initialCount);
  }, [initialCount]);

  const handleUpvote = async (e) => {
    e.stopPropagation(); // Prevent card click events
    e.preventDefault();

    if (!user) {
      toast({
        title: "Login required",
        description: "Please login to upvote content",
        variant: "destructive"
      });
      return;
    }

    // Prevent self-upvoting
    if (ownerId === user.id) {
      toast({
        title: "Cannot upvote",
        description: "You cannot upvote your own content",
        variant: "destructive"
      });
      return;
    }

    if (isLoading) return;

    setIsLoading(true);

    // Optimistic update
    const previousState = hasUpvoted;
    const previousCount = upvoteCount;
    
    setHasUpvoted(!hasUpvoted);
    setUpvoteCount(prev => hasUpvoted ? prev - 1 : prev + 1);

    try {
      // Use the toggle_upvote function
      const { data, error } = await supabase
        .rpc('toggle_upvote', {
          p_content_type: contentType,
          p_target_id: targetId
        });

      if (error) throw error;

      // Update with actual count from server
      if (data && data.length > 0) {
        setUpvoteCount(data[0].new_count);
        setHasUpvoted(data[0].action === 'added');
      }

    } catch (error) {
      console.error('Error toggling upvote:', error);
      
      // Revert optimistic update
      setHasUpvoted(previousState);
      setUpvoteCount(previousCount);

      toast({
        title: "Error",
        description: error.message || "Failed to update upvote",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Size variants
  const sizeClasses = {
    sm: 'h-7 px-2 text-xs gap-1',
    md: 'h-8 px-3 text-sm gap-1.5',
    lg: 'h-10 px-4 text-base gap-2'
  };

  const iconSizes = {
    sm: 'h-3 w-3',
    md: 'h-4 w-4',
    lg: 'h-5 w-5'
  };

  // Don't show button for own content
  if (ownerId === user?.id) {
    return showCount && upvoteCount > 0 ? (
      <div className={cn(
        "inline-flex items-center gap-1 text-gray-500",
        sizeClasses[size],
        className
      )}>
        <ThumbsUp className={iconSizes[size]} />
        <span>{upvoteCount}</span>
      </div>
    ) : null;
  }

  // Show loading skeleton while checking
  if (isChecking) {
    return (
      <div className={cn(
        "inline-flex items-center rounded-md bg-gray-100 animate-pulse",
        sizeClasses[size],
        className
      )}>
        <div className={cn("bg-gray-200 rounded", iconSizes[size])} />
        {showCount && <div className="w-4 h-3 bg-gray-200 rounded" />}
      </div>
    );
  }

  return (
    <button
      onClick={handleUpvote}
      disabled={isLoading}
      className={cn(
        "inline-flex items-center rounded-md font-medium transition-all duration-200",
        "focus:outline-none focus:ring-2 focus:ring-offset-1",
        sizeClasses[size],
        hasUpvoted
          ? "bg-blue-100 text-blue-700 hover:bg-blue-200 focus:ring-blue-500"
          : "bg-gray-100 text-gray-600 hover:bg-gray-200 hover:text-gray-800 focus:ring-gray-400",
        isLoading && "opacity-50 cursor-not-allowed",
        className
      )}
      title={hasUpvoted ? "Remove upvote" : "Upvote this content"}
    >
      <ThumbsUp 
        className={cn(
          iconSizes[size],
          "transition-transform duration-200",
          hasUpvoted && "fill-current",
          isLoading && "animate-pulse"
        )} 
      />
      {showCount && (
        <span className="min-w-[1ch]">
          {upvoteCount}
        </span>
      )}
    </button>
  );
}

/**
 * UpvoteCount Component (Read-only display)
 * 
 * For showing upvote counts without interaction (e.g., in lists)
 */
export function UpvoteCount({ count = 0, size = 'sm', className = '' }) {
  const sizeClasses = {
    sm: 'text-xs gap-1',
    md: 'text-sm gap-1.5',
    lg: 'text-base gap-2'
  };

  const iconSizes = {
    sm: 'h-3 w-3',
    md: 'h-4 w-4',
    lg: 'h-5 w-5'
  };

  if (count === 0) return null;

  return (
    <span className={cn(
      "inline-flex items-center text-gray-500",
      sizeClasses[size],
      className
    )}>
      <ThumbsUp className={iconSizes[size]} />
      <span>{count}</span>
    </span>
  );
}