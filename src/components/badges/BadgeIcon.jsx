import { Upload, Brain, Flame, Moon, Star } from 'lucide-react';

// Maps icon_key from database to Lucide icons and colors
const BADGE_CONFIG = {
  upload: { 
    icon: Upload, 
    color: 'text-blue-600', 
    bg: 'bg-blue-100',
    bgUnlocked: 'bg-blue-500'
  },
  brain: { 
    icon: Brain, 
    color: 'text-purple-600', 
    bg: 'bg-purple-100',
    bgUnlocked: 'bg-purple-500'
  },
  flame: { 
    icon: Flame, 
    color: 'text-orange-600', 
    bg: 'bg-orange-100',
    bgUnlocked: 'bg-orange-500'
  },
  moon: { 
    icon: Moon, 
    color: 'text-indigo-600', 
    bg: 'bg-indigo-100',
    bgUnlocked: 'bg-indigo-500'
  },
  star: { 
    icon: Star, 
    color: 'text-yellow-600', 
    bg: 'bg-yellow-100',
    bgUnlocked: 'bg-yellow-500'
  }
};

// Size variants
const SIZES = {
  xs: 'h-4 w-4',
  sm: 'h-5 w-5',
  md: 'h-6 w-6',
  lg: 'h-8 w-8',
  xl: 'h-10 w-10'
};

const CONTAINER_SIZES = {
  xs: 'h-6 w-6',
  sm: 'h-7 w-7',
  md: 'h-8 w-8',
  lg: 'h-10 w-10',
  xl: 'h-12 w-12'
};

export default function BadgeIcon({ 
  iconKey, 
  size = 'md', 
  unlocked = true,
  showBackground = true,
  className = ''
}) {
  const config = BADGE_CONFIG[iconKey];
  
  if (!config) {
    console.warn(`Unknown badge icon key: ${iconKey}`);
    return null;
  }
  
  const IconComponent = config.icon;
  const iconSize = SIZES[size] || SIZES.md;
  const containerSize = CONTAINER_SIZES[size] || CONTAINER_SIZES.md;
  
  if (!showBackground) {
    return (
      <IconComponent 
        className={`${iconSize} ${unlocked ? config.color : 'text-gray-400'} ${className}`}
      />
    );
  }
  
  return (
    <div 
      className={`
        ${containerSize} 
        rounded-full 
        flex items-center justify-center
        ${unlocked ? config.bgUnlocked : 'bg-gray-200'}
        ${className}
      `}
    >
      <IconComponent 
        className={`${iconSize} ${unlocked ? 'text-white' : 'text-gray-400'}`}
      />
    </div>
  );
}
