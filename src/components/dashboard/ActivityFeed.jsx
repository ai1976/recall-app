import { useNavigate } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useActivityFeed } from '@/hooks/useActivityFeed';
import { FileText, CreditCard, Clock, Newspaper } from 'lucide-react';

// Helper: Format relative time
const formatRelativeTime = (timestamp) => {
  const now = new Date();
  const date = new Date(timestamp);
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins} min${diffMins > 1 ? 's' : ''} ago`;
  if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays} days ago`;
  return date.toLocaleDateString();
};

// Helper: Format creator name with role prefix
const formatCreatorName = (name, role) => {
  if (!name) return 'Unknown';
  if (role === 'professor') return `Prof. ${name.split(' ')[0]}`;
  // For students, show first name + last initial
  const parts = name.split(' ');
  if (parts.length > 1) {
    return `${parts[0]} ${parts[parts.length - 1].charAt(0)}.`;
  }
  return parts[0];
};

export default function ActivityFeed({ limit = 5 }) {
  const navigate = useNavigate();
  const { activities, loading, error } = useActivityFeed(limit);

  // Handle click on activity item
  const handleActivityClick = (activity) => {
    if (activity.content_type === 'note') {
      navigate(`/dashboard/notes/${activity.id}`);
    } else if (activity.content_type === 'deck') {
      // Navigate to flashcards filtered by subject
      navigate(`/dashboard/review-flashcards?subject=${encodeURIComponent(activity.subject)}`);
    }
  };

  // Loading state
  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
            <Newspaper className="h-4 w-4 sm:h-5 sm:w-5" />
            Recent Activity
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="flex items-center gap-3 p-3 animate-pulse">
                <div className="w-10 h-10 bg-gray-200 rounded-lg" />
                <div className="flex-1 space-y-2">
                  <div className="h-4 bg-gray-200 rounded w-3/4" />
                  <div className="h-3 bg-gray-100 rounded w-1/2" />
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  // Error state
  if (error) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
            <Newspaper className="h-4 w-4 sm:h-5 sm:w-5" />
            Recent Activity
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground text-center py-4">
            Unable to load activity feed
          </p>
        </CardContent>
      </Card>
    );
  }

  // Empty state
  if (!activities || activities.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
            <Newspaper className="h-4 w-4 sm:h-5 sm:w-5" />
            Recent Activity
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-6">
            <Clock className="h-10 w-10 text-gray-300 mx-auto mb-3" />
            <p className="text-sm text-muted-foreground">
              No new content in the past week.
            </p>
            <p className="text-xs text-muted-foreground mt-1">
              Check back soon!
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
          <Newspaper className="h-4 w-4 sm:h-5 sm:w-5" />
          Recent Activity
        </CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <div className="divide-y">
          {activities.map((activity) => (
            <div
              key={`${activity.content_type}-${activity.id}`}
              className="flex items-center justify-between p-3 sm:p-4 hover:bg-accent/50 transition"
            >
              <div className="flex items-center gap-3 min-w-0 flex-1">
                {/* Icon */}
                <div className={`p-2 rounded-lg flex-shrink-0 ${
                  activity.content_type === 'note' 
                    ? 'bg-purple-100' 
                    : 'bg-green-100'
                }`}>
                  {activity.content_type === 'note' ? (
                    <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" />
                  ) : (
                    <CreditCard className="h-4 w-4 sm:h-5 sm:w-5 text-green-600" />
                  )}
                </div>

                {/* Content */}
                <div className="min-w-0 flex-1">
                  <p className="font-medium text-sm sm:text-base truncate">
                    "{activity.title}"
                  </p>
                  <p className="text-xs sm:text-sm text-muted-foreground truncate">
                    by {formatCreatorName(activity.creator_name, activity.creator_role)}
                  </p>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="text-[10px] sm:text-xs text-muted-foreground">
                      {activity.subject}
                    </span>
                    <span className="text-[10px] sm:text-xs text-muted-foreground">•</span>
                    <span className="text-[10px] sm:text-xs text-muted-foreground">
                      {formatRelativeTime(activity.created_at)}
                    </span>
                  </div>
                </div>
              </div>

              {/* Action Button */}
              <Button
                variant="outline"
                size="sm"
                className="ml-2 flex-shrink-0"
                onClick={() => handleActivityClick(activity)}
              >
                {activity.content_type === 'note' ? 'View' : 'Study'}
              </Button>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
