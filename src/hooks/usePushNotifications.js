/**
 * usePushNotifications.js
 *
 * Manages Web Push subscription state for the current user.
 * Handles permission requests, VAPID subscription, backend sync,
 * and iOS "install first" detection.
 */
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';

const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY;
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

/** Convert a base64url VAPID public key to the Uint8Array format required by the Push API */
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  return Uint8Array.from([...rawData].map((c) => c.charCodeAt(0)));
}

function getBrowserName() {
  const ua = navigator.userAgent;
  if (/Edg/.test(ua)) return 'Edge';
  if (/Chrome/.test(ua)) return 'Chrome';
  if (/Firefox/.test(ua)) return 'Firefox';
  if (/Safari/.test(ua)) return 'Safari';
  return 'Unknown';
}

function getPlatformName() {
  const ua = navigator.userAgent;
  if (/Android/.test(ua)) return 'Android';
  if (/iPhone|iPad|iPod/.test(ua)) return 'iOS';
  if (/Windows/.test(ua)) return 'Windows';
  if (/Mac/.test(ua)) return 'macOS';
  return 'Unknown';
}

export function usePushNotifications(user) {
  // Is the Push API available in this browser at all?
  const [isSupported, setIsSupported] = useState(false);
  // Is a push subscription currently active?
  const [isSubscribed, setIsSubscribed] = useState(false);
  // Notification permission: 'default' | 'granted' | 'denied'
  const [permission, setPermission] = useState('default');
  const [isLoading, setIsLoading] = useState(false);
  // iOS-specific: push requires PWA to be installed (added to home screen)
  const [isIOS, setIsIOS] = useState(false);
  const [isStandalone, setIsStandalone] = useState(false);

  useEffect(() => {
    const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
    setIsIOS(ios);
    setIsStandalone(
      window.matchMedia('(display-mode: standalone)').matches ||
        window.navigator.standalone === true
    );

    const supported =
      'serviceWorker' in navigator &&
      'PushManager' in window &&
      'Notification' in window;
    setIsSupported(supported);

    if (supported) {
      setPermission(Notification.permission);
      // Check if already subscribed
      navigator.serviceWorker.ready
        .then((reg) => reg.pushManager.getSubscription())
        .then((sub) => setIsSubscribed(!!sub))
        .catch(() => {});
    }
  }, []);

  /**
   * Request push permission and save the subscription to the backend.
   * Returns true on success, false if denied or an error occurred.
   */
  const subscribe = useCallback(async () => {
    if (!user || !isSupported || !VAPID_PUBLIC_KEY) return false;
    setIsLoading(true);
    try {
      // Ensure the service worker is registered and ready
      await navigator.serviceWorker.register('/sw.js');
      const reg = await navigator.serviceWorker.ready;

      // Ask for permission
      const perm = await Notification.requestPermission();
      setPermission(perm);
      if (perm !== 'granted') return false;

      // Subscribe via the Push API using our VAPID public key
      const subscription = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
      });

      const subJson = subscription.toJSON();

      // Persist the subscription on the backend
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) return false;

      const res = await fetch(`${SUPABASE_URL}/functions/v1/push-subscribe`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
          apikey: SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({
          endpoint: subJson.endpoint,
          p256dh: subJson.keys?.p256dh,
          auth: subJson.keys?.auth,
          browser: getBrowserName(),
          platform: getPlatformName(),
        }),
      });

      if (!res.ok) throw new Error('Backend save failed');

      setIsSubscribed(true);
      return true;
    } catch (err) {
      console.error('[usePushNotifications] subscribe error:', err);
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [user, isSupported]);

  /**
   * Remove the push subscription locally and notify the backend.
   */
  const unsubscribe = useCallback(async () => {
    if (!user) return;
    setIsLoading(true);
    try {
      const reg = await navigator.serviceWorker.ready;
      const sub = await reg.pushManager.getSubscription();
      if (sub) {
        const endpoint = sub.endpoint;
        await sub.unsubscribe();

        const {
          data: { session },
        } = await supabase.auth.getSession();
        if (session) {
          await fetch(`${SUPABASE_URL}/functions/v1/push-unsubscribe`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${session.access_token}`,
              apikey: SUPABASE_ANON_KEY,
            },
            body: JSON.stringify({ endpoint }),
          });
        }
      }
      setIsSubscribed(false);
    } catch (err) {
      console.error('[usePushNotifications] unsubscribe error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [user]);

  return {
    isSupported,
    isSubscribed,
    permission,
    isLoading,
    isIOS,
    isStandalone,
    /** iOS users must install the PWA before push is possible */
    needsIOSInstall: isIOS && !isStandalone,
    subscribe,
    unsubscribe,
  };
}
