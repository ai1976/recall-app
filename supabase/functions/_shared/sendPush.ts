import webPush from "npm:web-push@3.6.7";
import { supabaseAdmin } from "./supabaseAdmin.ts";

// Configure VAPID once at module load
webPush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT") ?? "mailto:recall@moreclassescommerce.com",
  Deno.env.get("VAPID_PUBLIC_KEY") ?? "",
  Deno.env.get("VAPID_PRIVATE_KEY") ?? ""
);

export interface PushPayload {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  /** Same tag = browser replaces the previous notification (same "slot") */
  tag?: string;
  /** true  = re-rings/vibrates even when replacing; false = silent update */
  renotify?: boolean;
  data?: Record<string, unknown>;
}

/**
 * Send a push notification to all active subscriptions for the given user IDs.
 * Automatically deactivates subscriptions that return HTTP 410/404 (expired).
 */
export async function sendPushToUsers(
  userIds: string[],
  payload: PushPayload
): Promise<void> {
  if (userIds.length === 0) return;

  // Fetch all active push subscriptions for these users in one query
  const { data: subscriptions, error } = await supabaseAdmin
    .from("push_subscriptions")
    .select("id, user_id, endpoint, p256dh, auth")
    .in("user_id", userIds)
    .eq("is_active", true);

  if (error) {
    console.error("[sendPush] Failed to fetch subscriptions:", error.message);
    return;
  }

  if (!subscriptions || subscriptions.length === 0) return;

  const expiredIds: string[] = [];

  // Send to all subscriptions concurrently
  await Promise.allSettled(
    subscriptions.map(async (sub) => {
      try {
        await webPush.sendNotification(
          {
            endpoint: sub.endpoint,
            keys: { p256dh: sub.p256dh, auth: sub.auth },
          },
          JSON.stringify(payload),
          {
            TTL: 86400, // 24-hour time-to-live
          }
        );
      } catch (err: unknown) {
        const status = (err as { statusCode?: number }).statusCode;
        if (status === 410 || status === 404) {
          // Subscription is no longer valid — mark for deactivation
          expiredIds.push(sub.id);
        } else {
          console.error(
            `[sendPush] Push failed for subscription ${sub.id}:`,
            (err as Error).message
          );
        }
      }
    })
  );

  // Deactivate expired subscriptions in one batch
  if (expiredIds.length > 0) {
    await supabaseAdmin
      .from("push_subscriptions")
      .update({ is_active: false })
      .in("id", expiredIds);
    console.log(`[sendPush] Deactivated ${expiredIds.length} expired subscription(s)`);
  }
}
