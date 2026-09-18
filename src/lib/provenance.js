import { supabase } from '@/lib/supabase';

/**
 * Fetches flashcard_batch_provenance rows for a set of batch_ids and returns
 * a Map keyed by batch_id -> { content_source_type, content_source_name }.
 * Missing batch_ids (legacy pre-8.7.1 batches) simply have no entry — callers
 * render nothing for those, never an "Unknown source" placeholder.
 * Requires the authenticated SELECT policy added in Sprint 8.7.4 — degrades
 * to an empty map (no badges) if that policy isn't deployed yet, not an error.
 */
export async function fetchBatchProvenanceMap(batchIds) {
  const distinctIds = [...new Set((batchIds || []).filter(Boolean))];
  if (distinctIds.length === 0) return new Map();

  const { data, error } = await supabase
    .from('flashcard_batch_provenance')
    .select('batch_id, content_source_type, content_source_name')
    .in('batch_id', distinctIds);

  if (error) {
    console.error('Error fetching batch provenance:', error);
    return new Map();
  }

  return new Map((data || []).map(row => [row.batch_id, row]));
}
