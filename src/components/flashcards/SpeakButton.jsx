import { Volume2, VolumeX } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

export default function SpeakButton({
  onClick,
  isSpeaking = false,
  isSupported = true,
  className,
  size = 'icon',
  variant = 'ghost',
}) {
  if (!isSupported) return null;

  return (
    <Button
      variant={variant}
      size={size}
      onClick={(e) => {
        e.stopPropagation();
        onClick?.(e);
      }}
      className={cn(
        'h-7 w-7 text-gray-400 hover:text-purple-600',
        isSpeaking && 'text-purple-600 animate-pulse',
        className
      )}
      title={isSpeaking ? 'Stop reading' : 'Read aloud'}
      aria-label={isSpeaking ? 'Stop reading aloud' : 'Read aloud'}
    >
      {isSpeaking ? (
        <VolumeX className="h-4 w-4" />
      ) : (
        <Volume2 className="h-4 w-4" />
      )}
    </Button>
  );
}
