import { Settings2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';

export default function SpeechSettings({
  voices,
  selectedVoice,
  onSelectVoice,
  rate,
  onRateChange,
  isSupported,
}) {
  if (!isSupported) return null;

  // Group voices by language for easier browsing
  const groupedVoices = voices.reduce((groups, voice) => {
    const lang = voice.lang?.split('-')[0] || 'unknown';
    if (!groups[lang]) groups[lang] = [];
    groups[lang].push(voice);
    return groups;
  }, {});

  const sortedLangs = Object.keys(groupedVoices).sort();

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="h-7 w-7 text-gray-400 hover:text-purple-600"
          title="Speech settings"
          aria-label="Speech settings"
        >
          <Settings2 className="h-4 w-4" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="start" className="w-72">
        <div className="space-y-4">
          <div>
            <h4 className="text-sm font-semibold text-gray-900 mb-1">Speech Settings</h4>
            <p className="text-xs text-gray-500">Choose a voice and speed for reading flashcards aloud.</p>
          </div>

          {/* Voice selector */}
          <div>
            <label className="text-xs font-medium text-gray-700 block mb-1">Voice</label>
            <select
              value={selectedVoice?.voiceURI || ''}
              onChange={(e) => {
                const voice = voices.find(v => v.voiceURI === e.target.value) || null;
                onSelectVoice(voice);
              }}
              className="w-full px-2 py-1.5 border border-gray-300 rounded text-sm bg-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            >
              <option value="">Browser Default</option>
              {sortedLangs.map(lang => (
                <optgroup key={lang} label={lang.toUpperCase()}>
                  {groupedVoices[lang].map(voice => (
                    <option key={voice.voiceURI} value={voice.voiceURI}>
                      {voice.name} ({voice.lang})
                    </option>
                  ))}
                </optgroup>
              ))}
            </select>
          </div>

          {/* Speed slider */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-xs font-medium text-gray-700">Speed</label>
              <span className="text-xs text-gray-500">{rate.toFixed(1)}x</span>
            </div>
            <input
              type="range"
              min="0.5"
              max="2.0"
              step="0.1"
              value={rate}
              onChange={(e) => onRateChange(parseFloat(e.target.value))}
              className="w-full h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-purple-600"
            />
            <div className="flex justify-between text-xs text-gray-400 mt-0.5">
              <span>0.5x</span>
              <span>1.0x</span>
              <span>2.0x</span>
            </div>
          </div>
        </div>
      </PopoverContent>
    </Popover>
  );
}
