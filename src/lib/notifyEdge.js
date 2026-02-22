/**
 * notifyEdge.js
 *
 * Fire-and-forget helpers for calling the notification Edge Functions.
 * NEVER await these from upload flows — a notification failure must never
 * block or break the user's primary action.
 */
import { supabase } from '@/lib/supabase';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

async function getAuthHeaders() {
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) return null;
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${session.access_token}`,
    apikey: SUPABASE_ANON_KEY,
  };
}

/**
 * Trigger the update-in-place content notification (aggregated, 4-hour window).
 *
 * @param {{ content_type: 'note'|'flashcard_deck', content_id: string,
 *           creator_id: string, title: string, subject_name?: string|null,
 *           visibility: 'public'|'friends', target_course: string }} payload
 */
export function notifyContentCreated(payload) {
  getAuthHeaders()
    .then((headers) => {
      if (!headers) return;
      fetch(`${SUPABASE_URL}/functions/v1/notify-content-created`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      }).catch((err) => console.warn('[notify] content-created failed:', err));
    })
    .catch((err) => console.warn('[notify] auth error:', err));
}

/**
 * Trigger an instant friend-event notification (not aggregated).
 *
 * @param {{ event_type: 'friend_request'|'friend_accepted',
 *           actor_id: string, target_user_id: string }} payload
 */
export function notifyFriendEvent(payload) {
  getAuthHeaders()
    .then((headers) => {
      if (!headers) return;
      fetch(`${SUPABASE_URL}/functions/v1/notify-friend-event`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      }).catch((err) => console.warn('[notify] friend-event failed:', err));
    })
    .catch((err) => console.warn('[notify] auth error:', err));
}
