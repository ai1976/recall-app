import { Clock } from 'lucide-react';
import { Num } from '@/components/revisop';

// Due Items Forecast tile. `tone` drives colour (see the hierarchy note in Progress.jsx):
//   calm   → nothing due today (positive, muted green)
//   amber  → today's pile — the loudest surface, it's the only call to action
//   danger → Due Today past the alarm threshold (genuine backlog)
//   quiet  → the 7 / 30-day forecast — context, deliberately the softest
// T-001 brief C v6: when the value is unknown (`null`: no snapshot yet, or the first load failed) the tile shows a dash in the quiet tone, never the green "calm" tone.
const FORECAST_TONES = {
  calm:   { box: 'bg-rv-green-50 border-rv-border',     text: 'text-rv-green' },
  amber:  { box: 'bg-rv-amber-50 border-rv-amber-edge', text: 'text-rv-amber-ink' },
  danger: { box: 'bg-rv-bg-1 border-rv-danger',         text: 'text-rv-danger' },
  quiet:  { box: 'bg-rv-bg-1 border-rv-border',         text: 'text-rv-ink-600' },
};

export default function ForecastCard({ label, value, tone }) {
  const unknown = value === null || value === undefined;
  const t = FORECAST_TONES[unknown ? 'quiet' : tone] ?? FORECAST_TONES.quiet;
  return (
    <div className={`rounded-lg border p-4 text-center ${t.box} ${t.text}`} data-tone={unknown ? 'quiet' : tone}>
      <div className="flex items-center justify-center gap-1 mb-1">
        <Clock className="h-4 w-4 opacity-70" />
      </div>
      <Num className={`block text-2xl leading-none mb-1 ${t.text}`}>
        {unknown ? <span className="animate-pulse">—</span> : value}
      </Num>
      <p className="text-xs font-medium opacity-80">{label}</p>
    </div>
  );
}
