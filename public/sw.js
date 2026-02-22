// Recall App — Service Worker
// Handles Web Push notifications and notification click events.
// Offline caching is intentionally omitted — the app is always online.

const APP_NAME = 'Recall';

// ── Install & Activate ────────────────────────────────────────────────────────
// Claim all clients immediately so the SW is active on first load.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

// ── Push event ────────────────────────────────────────────────────────────────
// Fired by the browser when a message arrives from the Web Push Protocol server.
self.addEventListener('push', (event) => {
  if (!event.data) return;

  let data;
  try {
    data = event.data.json();
  } catch {
    data = { title: APP_NAME, body: event.data.text() };
  }

  const title = data.title || APP_NAME;
  const isRenotify = data.renotify !== false; // true by default

  const options = {
    body: data.body || '',
    icon: '/android-chrome-192x192.png',
    badge: '/android-chrome-192x192.png',
    tag: data.tag || 'recall-default',
    renotify: isRenotify,
    // Only vibrate & play sound when genuinely alerting the user
    vibrate: isRenotify ? [200, 100, 200] : [],
    silent: !isRenotify,
    data: data.data || {},
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// ── Notification click ────────────────────────────────────────────────────────
// Fired when the user taps a displayed notification.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  // Navigate to the URL embedded in the notification, falling back to /dashboard
  const url = event.notification.data?.url || '/dashboard';

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // If the app is already open in a tab, focus it and navigate
        for (const client of clientList) {
          if (client.url.startsWith(self.location.origin) && 'focus' in client) {
            client.navigate(url);
            return client.focus();
          }
        }
        // Otherwise open a new window
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
});
