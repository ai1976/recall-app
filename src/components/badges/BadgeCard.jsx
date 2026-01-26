import BadgeIcon from './BadgeIcon';
import { Switch } from '@/components/ui/switch';
import { Lock, Eye, EyeOff } from 'lucide-react';

export default function BadgeCard({ 
  badge, 
  unlocked = false, 
  earnedAt = null,
  showProgress = false,
  currentProgress = 0,
  isPublic = true,
  onPrivacyToggle = null,  // Function to handle toggle
  showPrivacyToggle = false
}) {
  const progressPercent = showProgress && badge.threshold > 0
    ? Math.min((currentProgress / badge.threshold) * 100, 100)
    : 0;

  return (
    <div 
      className={`
        relative p-4 rounded-lg border transition-all
        ${unlocked 
          ? 'bg-white border-gray-200 shadow-sm' 
          : 'bg-gray-50 border-gray-200 opacity-75'
        }
      `}
    >
      {/* Lock overlay for locked badges */}
      {!unlocked && (
        <div className="absolute top-2 right-2">
          <Lock className="h-4 w-4 text-gray-400" />
        </div>
      )}
      
      {/* Privacy toggle for unlocked badges */}
      {unlocked && showPrivacyToggle && onPrivacyToggle && (
        <div className="absolute top-3 right-3 flex items-center gap-2">
          {isPublic ? (
            <Eye className="h-3.5 w-3.5 text-green-600" />
          ) : (
            <EyeOff className="h-3.5 w-3.5 text-gray-400" />
          )}
          <Switch
            checked={isPublic}
            onCheckedChange={onPrivacyToggle}
            className="scale-75"
          />
        </div>
      )}
      
      <div className="flex items-start gap-3">
        {/* Badge Icon */}
        <BadgeIcon 
          iconKey={badge.icon_key} 
          size="lg" 
          unlocked={unlocked}
        />
        
        {/* Badge Details */}
        <div className="flex-1 min-w-0 pr-16">
          <h3 className={`font-semibold ${unlocked ? 'text-gray-900' : 'text-gray-500'}`}>
            {badge.name}
          </h3>
          <p className={`text-sm mt-0.5 ${unlocked ? 'text-gray-600' : 'text-gray-400'}`}>
            {badge.description}
          </p>
          
          {/* Earned date + visibility status for unlocked badges */}
          {unlocked && earnedAt && (
            <div className="flex items-center gap-2 mt-2">
              <p className="text-xs text-green-600">
                ✓ Earned {new Date(earnedAt).toLocaleDateString('en-IN', {
                  day: 'numeric',
                  month: 'short',
                  year: 'numeric'
                })}
              </p>
              {showPrivacyToggle && (
                <span className={`text-xs ${isPublic ? 'text-green-600' : 'text-gray-400'}`}>
                  • {isPublic ? 'Public' : 'Private'}
                </span>
              )}
            </div>
          )}
          
          {/* Progress bar for locked badges */}
          {!unlocked && showProgress && (
            <div className="mt-2">
              <div className="flex justify-between text-xs text-gray-500 mb-1">
                <span>Progress</span>
                <span>{currentProgress} / {badge.threshold}</span>
              </div>
              <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                <div 
                  className="h-full bg-blue-500 rounded-full transition-all"
                  style={{ width: `${progressPercent}%` }}
                />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}