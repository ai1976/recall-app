/**
 * Vercel Edge Middleware — OG tag injection for /deck/:deckId
 *
 * Intercepts bot requests (WhatsApp, Slack, etc.) to /deck/:deckId,
 * fetches deck metadata via Supabase service role, and returns an HTML
 * page with Open Graph meta tags so link previews render correctly.
 *
 * Requirements (set in Vercel Dashboard → Environment Variables):
 *   SUPABASE_URL             — your Supabase project URL
 *   SUPABASE_SERVICE_ROLE_KEY — service role key (bypasses RLS)
 */

export const config = { matcher: '/deck/:path*' };

const BOT_UA = /WhatsApp|facebookexternalhit|Twitterbot|LinkedInBot|Slackbot|TelegramBot|Googlebot|bingbot|Applebot/i;
const DECK_PATH = /^\/deck\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;

export default async function middleware(request) {
  const url = new URL(request.url);
  const match = url.pathname.match(DECK_PATH);
  const userAgent = request.headers.get('user-agent') || '';

  // Pass through non-bot requests or non-matching paths
  if (!match || !BOT_UA.test(userAgent)) {
    return; // undefined = pass through to the app
  }

  const deckId = match[1];
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

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
  const pageUrl = url.href;

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
