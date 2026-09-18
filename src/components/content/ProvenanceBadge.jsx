import { Landmark, PenLine } from 'lucide-react';

/**
 * Content provenance badge (Sprint 8.7.4, D-21 display).
 * Renders nothing when sourceType/sourceName are absent — covers both legacy
 * pre-8.7.1 content (no row ever created) and any case where provenance
 * couldn't be resolved unambiguously (e.g. a deck spanning multiple batches
 * with different sources). No "Unknown source" placeholder — see now.md.
 */
export default function ProvenanceBadge({ sourceType, sourceName, className = '' }) {
  if (!sourceType || !sourceName) return null;

  const isOfficial = sourceType === 'official_body';
  const Icon = isOfficial ? Landmark : PenLine;
  const label = isOfficial ? 'Official source' : 'Original creator';

  return (
    <span
      title={`${label}: ${sourceName}`}
      className={`inline-flex items-center gap-1 text-xs text-gray-600 bg-gray-50 px-2 py-0.5 rounded-full ${className}`}
    >
      <Icon className="h-3 w-3 flex-shrink-0" />
      <span className="truncate max-w-[180px]">{sourceName}</span>
    </span>
  );
}
