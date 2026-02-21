import {
  Upload, Brain, Flame, Moon, Star,
  FileText, Layers, GraduationCap, Footprints,
  CalendarCheck, CalendarRange, Sunrise, Award, Medal,
  Users, HeartHandshake, ThumbsUp, Flag,
} from 'lucide-react';

// Maps icon_key from database to Lucide icons and colors
const BADGE_CONFIG = {
  // Phase 1E badges
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
  },
  // Phase 1F - Content Creator badges
  'file-text': {
    icon: FileText,
    color: 'text-teal-600',
    bg: 'bg-teal-100',
    bgUnlocked: 'bg-teal-500'
  },
  layers: {
    icon: Layers,
    color: 'text-cyan-600',
    bg: 'bg-cyan-100',
    bgUnlocked: 'bg-cyan-500'
  },
  'graduation-cap': {
    icon: GraduationCap,
    color: 'text-violet-600',
    bg: 'bg-violet-100',
    bgUnlocked: 'bg-violet-500'
  },
  // Phase 1F - Study Habit badges
  footprints: {
    icon: Footprints,
    color: 'text-green-600',
    bg: 'bg-green-100',
    bgUnlocked: 'bg-green-500'
  },
  'calendar-check': {
    icon: CalendarCheck,
    color: 'text-emerald-600',
    bg: 'bg-emerald-100',
    bgUnlocked: 'bg-emerald-500'
  },
  'calendar-range': {
    icon: CalendarRange,
    color: 'text-amber-600',
    bg: 'bg-amber-100',
    bgUnlocked: 'bg-amber-500'
  },
  sunrise: {
    icon: Sunrise,
    color: 'text-rose-600',
    bg: 'bg-rose-100',
    bgUnlocked: 'bg-rose-500'
  },
  award: {
    icon: Award,
    color: 'text-sky-600',
    bg: 'bg-sky-100',
    bgUnlocked: 'bg-sky-500'
  },
  medal: {
    icon: Medal,
    color: 'text-amber-700',
    bg: 'bg-amber-200',
    bgUnlocked: 'bg-amber-600'
  },
  // Phase 1F - Social badges
  users: {
    icon: Users,
    color: 'text-blue-400',
    bg: 'bg-blue-50',
    bgUnlocked: 'bg-blue-400'
  },
  'heart-handshake': {
    icon: HeartHandshake,
    color: 'text-pink-600',
    bg: 'bg-pink-100',
    bgUnlocked: 'bg-pink-500'
  },
  'thumbs-up': {
    icon: ThumbsUp,
    color: 'text-lime-600',
    bg: 'bg-lime-100',
    bgUnlocked: 'bg-lime-500'
  },
  // Phase 1F - Special badges
  flag: {
    icon: Flag,
    color: 'text-red-600',
    bg: 'bg-red-100',
    bgUnlocked: 'bg-red-500'
  },
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
