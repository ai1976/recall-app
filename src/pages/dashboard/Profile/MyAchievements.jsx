import { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { useBadges } from '@/hooks/useBadges';
import BadgeCard from '@/components/badges/BadgeCard';
import BadgeIcon from '@/components/badges/BadgeIcon';
import { Trophy, Flame, BookOpen, Users } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

export default function MyAchievements() {
  const { user } = useAuth();
  const { badges, allBadgeDefinitions, loading } = useBadges();
  const { toast } = useToast();
  const [progress, setProgress] = useState({});
  const [statsLoading, setStatsLoading] = useState(true);
  const [badgePrivacy, setBadgePrivacy] = useState({}); // Track is_public per badge

  // Initialize badge privacy state from fetched badges
  useEffect(() => {
    if (badges && badges.length > 0) {
      const privacyMap = {};
      badges.forEach(badge => {
        privacyMap[badge.badge_key] = badge.is_public ?? true;
      });
      setBadgePrivacy(privacyMap);
    }
  }, [badges]);

  // Handle privacy toggle for a specific badge
  const handlePrivacyToggle = async (badgeKey, newValue) => {
    if (!user) return;
    
    // Optimistic update
    setBadgePrivacy(prev => ({ ...prev, [badgeKey]: newValue }));
    
    try {
      // Get badge_id from badge_definitions
      const { data: badgeDef } = await supabase
        .from('badge_definitions')
        .select('id')
        .eq('key', badgeKey)
        .single();
      
      if (!badgeDef) throw new Error('Badge not found');
      
      // Update is_public in user_badges
      const { error } = await supabase
        .from('user_badges')
        .update({ is_public: newValue })
        .eq('user_id', user.id)
        .eq('badge_id', badgeDef.id);
      
      if (error) throw error;
      
      toast({
        description: newValue 
          ? "Badge is now visible to others" 
          : "Badge is now hidden from others",
        duration: 2000,
      });
      
    } catch (err) {
      console.error('Error updating badge privacy:', err);
      // Revert on error
      setBadgePrivacy(prev => ({ ...prev, [badgeKey]: !newValue }));
      toast({
        title: "Error",
        description: "Failed to update privacy setting",
        variant: "destructive",
      });
    }
  };

  // Fetch progress stats for locked badges
  useEffect(() => {
    const fetchProgress = async () => {
      if (!user) return;

      try {
        const [notesResult, flashcardsResult, streakResult, upvotesResult] = await Promise.all([
          supabase
            .from('notes')
            .select('id', { count: 'exact', head: true })
            .eq('user_id', user.id),
          
          supabase
            .from('flashcards')
            .select('id', { count: 'exact', head: true })
            .eq('user_id', user.id),
          
          supabase.rpc('get_user_streak', { p_user_id: user.id }),
          
          Promise.all([
            supabase
              .from('notes')
              .select('id')
              .eq('user_id', user.id),
            supabase
              .from('flashcard_decks')
              .select('id')
              .eq('user_id', user.id)
          ]).then(async ([notesRes, decksRes]) => {
            const noteIds = notesRes.data?.map(n => n.id) || [];
            const deckIds = decksRes.data?.map(d => d.id) || [];
            
            let totalUpvotes = 0;
            
            if (noteIds.length > 0) {
              const { count: noteUpvotes } = await supabase
                .from('upvotes')
                .select('id', { count: 'exact', head: true })
                .eq('content_type', 'note')
                .in('target_id', noteIds);
              totalUpvotes += noteUpvotes || 0;
            }
            
            if (deckIds.length > 0) {
              const { count: deckUpvotes } = await supabase
                .from('upvotes')
                .select('id', { count: 'exact', head: true })
                .eq('content_type', 'flashcard_deck')
                .in('target_id', deckIds);
              totalUpvotes += deckUpvotes || 0;
            }
            
            return totalUpvotes;
          })
        ]);

        setProgress({
          digitalizer: notesResult.count || 0,
          memory_architect: flashcardsResult.count || 0,
          streak_master: streakResult.data || 0,
          night_owl: 0,
          rising_star: upvotesResult || 0
        });

      } catch (err) {
        console.error('Error fetching progress:', err);
      } finally {
        setStatsLoading(false);
      }
    };

    fetchProgress();
  }, [user]);

  // Create a map of earned badges for quick lookup
  const earnedBadgesMap = badges.reduce((acc, badge) => {
    acc[badge.badge_key] = badge;
    return acc;
  }, {});

  // Group badges by category
  const groupedBadges = allBadgeDefinitions.reduce((acc, badge) => {
    if (!acc[badge.category]) {
      acc[badge.category] = [];
    }
    acc[badge.category].push(badge);
    return acc;
  }, {});

  const categoryInfo = {
    content: { name: 'Content Creator', icon: BookOpen, color: 'text-blue-600' },
    study: { name: 'Study Habits', icon: Flame, color: 'text-orange-600' },
    social: { name: 'Community', icon: Users, color: 'text-purple-600' }
  };

  // Count public badges
  const publicBadgeCount = Object.values(badgePrivacy).filter(Boolean).length;
  const totalEarned = badges.length;

  if (loading || statsLoading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        </div>
      </div>
    );
  }

  const totalAvailable = allBadgeDefinitions.length;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <div className="h-12 w-12 rounded-full bg-yellow-100 flex items-center justify-center">
            <Trophy className="h-6 w-6 text-yellow-600" />
          </div>
          <div>
            <h1 className="text-3xl font-bold text-gray-900">My Achievements</h1>
            <p className="text-gray-600 mt-1">
              {totalEarned} of {totalAvailable} badges earned
            </p>
          </div>
        </div>

        {/* Privacy Info */}
        <div className="mb-6 p-3 rounded-lg text-sm bg-blue-50 text-blue-700">
          <p>
            🎛️ Toggle visibility for each badge. {publicBadgeCount} of {totalEarned} badges are visible to others in Find Friends.
          </p>
        </div>

        {/* Progress Summary */}
        <div className="bg-white rounded-lg border border-gray-200 p-6 mb-8">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Overall Progress</p>
              <p className="text-2xl font-bold text-gray-900">
                {Math.round((totalEarned / totalAvailable) * 100)}%
              </p>
            </div>
            <div className="flex -space-x-2">
              {badges.slice(0, 5).map((badge, idx) => (
                <div 
                  key={badge.badge_key}
                  className="border-2 border-white rounded-full"
                  style={{ zIndex: 5 - idx }}
                >
                  <BadgeIcon 
                    iconKey={badge.icon_key} 
                    size="lg" 
                    unlocked={true}
                  />
                </div>
              ))}
            </div>
          </div>
          
          <div className="mt-4 h-2 bg-gray-200 rounded-full overflow-hidden">
            <div 
              className="h-full bg-gradient-to-r from-yellow-400 to-orange-500 rounded-full transition-all"
              style={{ width: `${(totalEarned / totalAvailable) * 100}%` }}
            />
          </div>
        </div>

        {/* Badges by Category */}
        {Object.entries(groupedBadges).map(([category, categoryBadges]) => {
          const info = categoryInfo[category] || { 
            name: category, 
            icon: Trophy, 
            color: 'text-gray-600' 
          };
          const IconComponent = info.icon;

          return (
            <div key={category} className="mb-8">
              <div className="flex items-center gap-2 mb-4">
                <IconComponent className={`h-5 w-5 ${info.color}`} />
                <h2 className="text-lg font-semibold text-gray-900">{info.name}</h2>
                <span className="text-sm text-gray-500">
                  ({categoryBadges.filter(b => earnedBadgesMap[b.key]).length}/{categoryBadges.length})
                </span>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {categoryBadges.map(badge => {
                  const earned = earnedBadgesMap[badge.key];
                  const currentProgress = progress[badge.key] || 0;
                  const isPublic = badgePrivacy[badge.key] ?? true;

                  return (
                    <BadgeCard
                      key={badge.key}
                      badge={badge}
                      unlocked={!!earned}
                      earnedAt={earned?.earned_at}
                      showProgress={!earned}
                      currentProgress={currentProgress}
                      isPublic={isPublic}
                      showPrivacyToggle={!!earned}
                      onPrivacyToggle={(newValue) => handlePrivacyToggle(badge.key, newValue)}
                    />
                  );
                })}
              </div>
            </div>
          );
        })}

        {/* Empty state */}
        {totalEarned === 0 && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center mt-8">
            <Trophy className="h-12 w-12 text-blue-400 mx-auto mb-3" />
            <p className="text-blue-800 font-medium mb-1">
              Start earning badges!
            </p>
            <p className="text-sm text-blue-700">
              Upload notes, create flashcards, and study regularly to unlock achievements.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}