import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, Flame, TrendingUp, Trophy } from 'lucide-react';

/**
 * AnonymousStats Component
 * Displays anonymous class comparison and milestones
 * 
 * @param {Object} props
 * @param {number} props.userReviewsThisWeek - Current user's reviews in rolling 7 days
 * @param {number} props.classAverage - Class average reviews (from SQL function)
 * @param {number} props.studentsStudiedToday - Count of students who studied today
 * @param {number} props.studentsWithStreak - Count of students with 7-day streak
 * @param {boolean} props.showComparison - Whether to show comparison (min 5 users)
 * @param {boolean} props.hasUserActivity - Whether current user has any reviews
 */
export default function AnonymousStats({
  userReviewsThisWeek = 0,
  classAverage = 0,
  studentsStudiedToday = 0,
  studentsWithStreak = 0,
  showComparison = false,
  hasUserActivity = false
}) {
  // Calculate comparison metrics
  const maxValue = Math.max(userReviewsThisWeek, classAverage, 1);
  const userPercentage = (userReviewsThisWeek / maxValue) * 100;
  const avgPercentage = (classAverage / maxValue) * 100;
  
  // Determine comparison message
  const getComparisonMessage = () => {
    if (!hasUserActivity || userReviewsThisWeek === 0) {
      return {
        text: `Your classmates are already building their streaks. Start your first review session today — even 5 cards makes a difference!`,
        color: 'text-indigo-600'
      };
    }

    if (!showComparison) return null;

    const difference = userReviewsThisWeek - classAverage;
    const reviewsNeeded = Math.ceil(classAverage - userReviewsThisWeek);
    const percentAhead = classAverage > 0
      ? Math.round((difference / classAverage) * 100)
      : 100;

    if (difference > 0) {
      return {
        text: `You're ${percentAhead}% ahead of the class this week. Keep your lead — don't give classmates a chance to catch up! 🏆`,
        color: 'text-green-600'
      };
    } else if (difference < 0) {
      return {
        text: `Just ${reviewsNeeded} more review${reviewsNeeded !== 1 ? 's' : ''} to reach the class average. You can close the gap in one session today! 💪`,
        color: 'text-amber-600'
      };
    } else {
      return {
        text: `You're right at the class average. One more session today and you'll be ahead of the pack. 🚀`,
        color: 'text-blue-600'
      };
    }
  };

  const comparisonMessage = getComparisonMessage();

  return (
    <div className="space-y-4">
      {/* You vs Class Comparison */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
            <TrendingUp className="h-4 w-4 sm:h-5 sm:w-5 text-indigo-600" />
            You vs Class
          </CardTitle>
        </CardHeader>
        <CardContent>
          {!hasUserActivity ? (
            // Zero Data State
            <div className="text-center py-4">
              {comparisonMessage && (
                <p className={`text-sm sm:text-base font-medium ${comparisonMessage.color}`}>
                  {comparisonMessage.text}
                </p>
              )}
              <p className="text-xs text-muted-foreground mt-2">
                Your classmates are already studying. Join them! 📚
              </p>
            </div>
          ) : !showComparison ? (
            // Not enough users for comparison
            <div className="text-center py-4">
              <p className="text-sm text-muted-foreground">
                Comparison stats will appear when more classmates join.
              </p>
              <p className="text-xs text-muted-foreground mt-1">
                Your reviews this week: <span className="font-semibold">{userReviewsThisWeek}</span>
              </p>
            </div>
          ) : (
            // Full comparison view
            <div className="space-y-4">
              {/* Progress bars */}
              <div className="space-y-3">
                {/* User's progress */}
                <div>
                  <div className="flex justify-between text-xs sm:text-sm mb-1">
                    <span className="font-medium">You</span>
                    <span className="font-semibold">{userReviewsThisWeek} reviews</span>
                  </div>
                  <div className="h-3 bg-gray-100 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-indigo-500 rounded-full transition-all duration-500"
                      style={{ width: `${userPercentage}%` }}
                    />
                  </div>
                </div>
                
                {/* Class average progress */}
                <div>
                  <div className="flex justify-between text-xs sm:text-sm mb-1">
                    <span className="font-medium text-muted-foreground">Class Average</span>
                    <span className="text-muted-foreground">{classAverage} reviews</span>
                  </div>
                  <div className="h-3 bg-gray-100 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-gray-400 rounded-full transition-all duration-500"
                      style={{ width: `${avgPercentage}%` }}
                    />
                  </div>
                </div>
              </div>
              
              {/* Comparison message */}
              {comparisonMessage && (
                <p className={`text-sm sm:text-base font-medium text-center ${comparisonMessage.color}`}>
                  {comparisonMessage.text}
                </p>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Class Milestones */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
            <Trophy className="h-4 w-4 sm:h-5 sm:w-5 text-amber-500" />
            Class Milestones
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-3 sm:gap-4 grid-cols-1 sm:grid-cols-2">
            {/* Students studied today */}
            <div className="flex items-center gap-3 p-3 bg-green-50 rounded-lg border border-green-100">
              <div className="p-2 bg-green-100 rounded-full">
                <Users className="h-4 w-4 text-green-600" />
              </div>
              <div>
                <p className="text-lg sm:text-xl font-bold text-green-700">
                  {studentsStudiedToday}
                </p>
                <p className="text-xs sm:text-sm text-green-600">
                  {studentsStudiedToday === 1 ? 'student' : 'students'} studied today
                </p>
              </div>
            </div>
            
            {/* 7-day streak achievers */}
            <div className="flex items-center gap-3 p-3 bg-orange-50 rounded-lg border border-orange-100">
              <div className="p-2 bg-orange-100 rounded-full">
                <Flame className="h-4 w-4 text-orange-600" />
              </div>
              <div>
                <p className="text-lg sm:text-xl font-bold text-orange-700">
                  {studentsWithStreak}
                </p>
                <p className="text-xs sm:text-sm text-orange-600">
                  {studentsWithStreak === 1 ? 'student has' : 'students have'} 7-day streak
                </p>
              </div>
            </div>
          </div>
          
          {/* Motivational footer */}
          {studentsStudiedToday > 0 && (
            <p className="text-xs text-center text-muted-foreground mt-3">
              {userReviewsThisWeek > 0
                ? `${studentsStudiedToday} ${studentsStudiedToday === 1 ? 'classmate has' : 'classmates have'} studied today — you're one of them. Keep it up! 👍`
                : `${studentsStudiedToday} ${studentsStudiedToday === 1 ? 'classmate is' : 'classmates are'} studying today — don't fall behind! 🔥`
              }
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}