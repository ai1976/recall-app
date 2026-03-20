/**
 * Vercel Edge Middleware — OG tag injection for /deck/:deckId and /join/:token
 *
 * Intercepts bot requests (WhatsApp, Slack, etc.) to monitored routes,
 * fetches metadata via Supabase service role, and returns an HTML page
 * with Open Graph meta tags so link previews render correctly.
 *
 * Routes handled:
 *   /deck/:deckId  — study set preview (existing)
 *   /join/:token   — group invite preview (new)
 *
 * Requirements (set in Vercel Dashboard → Environment Variables):
 *   SUPABASE_URL             — your Supabase project URL
 *   SUPABASE_SERVICE_ROLE_KEY — service role key (bypasses RLS)
 */

export const config = { matcher: ['/deck/:path*', '/join/:path*'] };

const BOT_UA = /WhatsApp|facebookexternalhit|Twitterbot|LinkedInBot|Slackbot|TelegramBot|Googlebot|bingbot|Applebot/i;
const DECK_PATH = /^\/deck\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;
const JOIN_PATH = /^\/join\/([0-9a-f-]{36})$/i;

export default async function middleware(request) {
  const url = new URL(request.url);
  const { pathname } = url;
  const userAgent = request.headers.get('user-agent') || '';

  const deckMatch = DECK_PATH.exec(pathname);
  const joinMatch = JOIN_PATH.exec(pathname);

  // Pass through non-bot requests or non-matching paths
  if ((!deckMatch && !joinMatch) || !BOT_UA.test(userAgent)) {
    return; // undefined = pass through to the app
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const pageUrl = url.href;

  // ── /deck/:deckId handler ──────────────────────────────────────────────────
  if (deckMatch) {
    const deckId = deckMatch[1];

    let deck = null;
    try {
      const res = await fetch(
        `${supabaseUrl}/rest/v1/rpc/get_public_deck_preview`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({ p_deck_id: deckId }),
        }
      );
      if (res.ok) {
        const json = await res.json();
        deck = json?.deck ?? null;
      }
    } catch {
      // Fall through to generic OG tags
    }

    const title = deck
      ? `${deck.name || 'Study Set'} — ${deck.subject || 'Recall'}`
      : 'Study Set on Recall';
    const description = deck
      ? `${deck.card_count ?? '?'} items · by ${deck.creator_name ?? 'Recall user'} · Study for free on Recall`
      : 'Spaced repetition study sets on Recall';

    return buildOgResponse(title, description, pageUrl);
  }

  // ── /join/:token handler ───────────────────────────────────────────────────
  if (joinMatch) {
    const token = joinMatch[1];

    let groupData = null;
    try {
      const res = await fetch(
        `${supabaseUrl}/rest/v1/rpc/get_group_preview`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({ p_token: token }),
        }
      );
      if (res.ok) {
        const json = await res.json();
        // get_group_preview returns { group: {...}, stats: {...} }
        groupData = json;
      }
    } catch {
      // Fall through to generic OG tags
    }

    let title, description;
    const group = groupData?.group;
    const stats = groupData?.stats;
    if (group?.name) {
      const memberCount = group.member_count ?? 0;
      const weeklyReviews = stats?.total_weekly_reviews ?? 0;

      title = `${group.name} — Recall Study Group`;
      description = memberCount > 0
        ? `${memberCount} ${memberCount === 1 ? 'member' : 'members'} · ${weeklyReviews} items reviewed this week · Join on Recall`
        : 'Study group on Recall · Join free';
    } else {
      title = 'Study Group on Recall';
      description = 'Join a spaced repetition study group on Recall.';
    }

    return buildOgResponse(title, description, pageUrl);
  }
}

function buildOgResponse(title, description, pageUrl) {
  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(title)}</title>
  <meta property="og:title" content="${escapeHtml(title)}" />
  <meta property="og:description" content="${escapeHtml(description)}" />
  <meta property="og:url" content="${escapeHtml(pageUrl)}" />
  <meta property="og:type" content="website" />
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content="${escapeHtml(title)}" />
  <meta name="twitter:description" content="${escapeHtml(description)}" />
  <meta http-equiv="refresh" content="0;url=${escapeHtml(pageUrl)}" />
</head>
<body>
  <p>Redirecting to <a href="${escapeHtml(pageUrl)}">Recall</a>…</p>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, s-maxage=86400, stale-while-revalidate=43200',
    },
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
