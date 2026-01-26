import BadgeIcon from './BadgeIcon';

export default function BadgeToast({ badge }) {
  return (
    <div className="flex items-center gap-3">
      <BadgeIcon 
        iconKey={badge.icon_key} 
        size="lg" 
        unlocked={true}
      />
      <div>
        <p className="font-semibold text-gray-900">Badge Unlocked!</p>
        <p className="text-sm text-gray-600">{badge.badge_name}</p>
      </div>
    </div>
  );
}