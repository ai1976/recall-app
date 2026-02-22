/**
 * PushPermissionBanner.jsx
 *
 * A one-time dismissible banner shown on the Dashboard to invite the user
 * to enable push notifications. Disappears permanently once dismissed.
 *
 * Rules:
 *  - Only shown when permission is 'default' (never asked before)
 *  - Not shown if already subscribed
 *  - Not shown once the user has dismissed it (stored in localStorage)
 *  - iOS: shows install-app instructions instead of an Enable button
 */
import { useState, useEffect } from 'react';
import { Bell, X, Smartphone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { usePushNotifications } from '@/hooks/usePushNotifications';
import { useAuth } from '@/contexts/AuthContext';

const DISMISSED_KEY = 'recall-push-banner-dismissed';

export default function PushPermissionBanner() {
  const { user } = useAuth();
  const { isSupported, isSubscribed, permission, needsIOSInstall, isLoading, subscribe } =
    usePushNotifications(user);

  const [isDismissed, setIsDismissed] = useState(
    () => localStorage.getItem(DISMISSED_KEY) === 'true'
  );
  const [justEnabled, setJustEnabled] = useState(false);

  // Don't render during SSR / before hydration
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  if (!mounted) return null;

  // Hide if: not supported, already subscribed, already dismissed, permission denied
  if (!isSupported) return null;
  if (isSubscribed) return null;
  if (isDismissed) return null;
  if (permission === 'denied') return null;
  // Already asked and granted but not yet subscribed (edge case) — let ProfileSettings handle it
  if (permission === 'granted' && !isSubscribed) return null;

  const handleDismiss = () => {
    localStorage.setItem(DISMISSED_KEY, 'true');
    setIsDismissed(true);
  };

  const handleEnable = async () => {
    const success = await subscribe();
    if (success) {
      setJustEnabled(true);
      // Auto-hide after 2 s
      setTimeout(handleDismiss, 2000);
    } else if (Notification.permission === 'denied') {
      // User blocked — dismiss so we don't keep nagging
      handleDismiss();
    }
  };

  // Success state
  if (justEnabled) {
    return (
      <div className="flex items-center gap-3 px-4 py-3 mb-4 bg-green-50 border border-green-200 rounded-lg text-sm text-green-800">
        <Bell className="h-4 w-4 flex-shrink-0" />
        <span>Push notifications enabled! You'll be notified when new content is added.</span>
      </div>
    );
  }

  // iOS: must install PWA first
  if (needsIOSInstall) {
    return (
      <div className="flex items-start gap-3 px-4 py-3 mb-4 bg-indigo-50 border border-indigo-200 rounded-lg text-sm text-indigo-800">
        <Smartphone className="h-4 w-4 mt-0.5 flex-shrink-0" />
        <div className="flex-1">
          <p className="font-medium">Get push notifications on iPhone</p>
          <p className="text-indigo-600 mt-0.5">
            Tap <strong>Share</strong> → <strong>Add to Home Screen</strong>, then open the app
            from your home screen.
          </p>
        </div>
        <button onClick={handleDismiss} className="text-indigo-400 hover:text-indigo-600 flex-shrink-0">
          <X className="h-4 w-4" />
        </button>
      </div>
    );
  }

  // Default: Android / Desktop prompt
  return (
    <div className="flex items-center gap-3 px-4 py-3 mb-4 bg-indigo-50 border border-indigo-200 rounded-lg text-sm text-indigo-800">
      <Bell className="h-4 w-4 flex-shrink-0" />
      <span className="flex-1">
        Get notified when your professor adds new notes or flashcards.
      </span>
      <div className="flex items-center gap-2 flex-shrink-0">
        <Button
          size="sm"
          className="h-7 px-3 text-xs bg-indigo-600 hover:bg-indigo-700 text-white"
          onClick={handleEnable}
          disabled={isLoading}
        >
          {isLoading ? 'Enabling…' : 'Enable'}
        </Button>
        <button onClick={handleDismiss} className="text-indigo-400 hover:text-indigo-600">
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
