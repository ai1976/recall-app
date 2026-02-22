import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

export function useNotifications(limit = 10) {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch unread count
  const fetchUnreadCount = useCallback(async () => {
    if (!user) return;

    try {
      const { data, error: countError } = await supabase
        .rpc('get_unread_notification_count', { p_user_id: user.id });

      if (countError) throw countError;
      setUnreadCount(data || 0);
    } catch (err) {
      console.error('Error fetching unread count:', err);
    }
  }, [user]);

  // Fetch recent notifications
  const fetchNotifications = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    try {
      setError(null);

      const { data, error: fetchError } = await supabase
        .rpc('get_recent_notifications', { 
          p_user_id: user.id, 
          p_limit: limit 
        });

      if (fetchError) throw fetchError;

      setNotifications(data || []);
      
      // Also update unread count
      await fetchUnreadCount();

    } catch (err) {
      console.error('Error fetching notifications:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [user, limit, fetchUnreadCount]);

  // Mark all notifications as read
  const markAllRead = useCallback(async () => {
    if (!user) return;

    try {
      const { error: markError } = await supabase
        .rpc('mark_notifications_read', { p_user_id: user.id });

      if (markError) throw markError;

      // Update local state
      setNotifications(prev => 
        prev.map(n => ({ ...n, is_read: true }))
      );
      setUnreadCount(0);

    } catch (err) {
      console.error('Error marking notifications read:', err);
    }
  }, [user]);

  // Mark single notification as read
  const markOneRead = useCallback(async (notificationId) => {
    if (!user) return;

    try {
      const { error: markError } = await supabase
        .rpc('mark_single_notification_read', { p_notification_id: notificationId });

      if (markError) throw markError;

      // Update local state
      setNotifications(prev =>
        prev.map(n => 
          n.id === notificationId ? { ...n, is_read: true } : n
        )
      );
      setUnreadCount(prev => Math.max(0, prev - 1));

    } catch (err) {
      console.error('Error marking notification read:', err);
    }
  }, [user]);

  // Delete a notification
  const deleteNotification = useCallback(async (notificationId) => {
    if (!user) return;

    try {
      const { error: deleteError } = await supabase
        .rpc('delete_notification', { p_notification_id: notificationId });

      if (deleteError) throw deleteError;

      // Update local state
      const deletedNotification = notifications.find(n => n.id === notificationId);
      setNotifications(prev => prev.filter(n => n.id !== notificationId));
      
      // Update unread count if deleted notification was unread
      if (deletedNotification && !deletedNotification.is_read) {
        setUnreadCount(prev => Math.max(0, prev - 1));
      }

    } catch (err) {
      console.error('Error deleting notification:', err);
    }
  }, [user, notifications]);

  // Initial fetch
  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

  // Subscribe to realtime INSERT and UPDATE events on notifications table
  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel('notifications-realtime')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        (payload) => {
          // New notification arrived — prepend to list and bump unread count
          setNotifications(prev => [payload.new, ...prev].slice(0, limit));
          setUnreadCount(prev => prev + 1);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          // An existing notification was updated in-place by the aggregation logic
          // (e.g. "Prof added 1 note" → "Prof added 5 notes").
          // Re-fetch so the list is re-sorted by updated_at DESC and shows the
          // latest message. unreadCount stays unchanged — the row was already unread.
          fetchNotifications();
        }
      )
      .subscribe();

    // Cleanup subscription on unmount
    return () => {
      supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, limit]);

  return {
    notifications,
    unreadCount,
    loading,
    error,
    markAllRead,
    markOneRead,
    deleteNotification,
    refetch: fetchNotifications
  };
}
