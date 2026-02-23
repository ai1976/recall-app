import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { sendPushToUsers } from "../_shared/sendPush.ts";

// A shared secret set as a Supabase project secret (CRON_SECRET).
// The pg_cron job passes this in the x-cron-secret header so random
// external callers cannot trigger the function.
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

/**
 * GET/POST /functions/v1/cron-review-reminders
 *
 * Scheduled daily at 08:00 AM IST (02:30 UTC) via pg_cron.
 * Finds every user with at least one card due for review today,
 * checks their push preference, and sends one push notification.
 *
 * Uses the exact same due-card logic as Dashboard.jsx:
 *   status = 'active'
 *   next_review_date <= today
 *   skip_until IS NULL OR skip_until <= today
 */
Deno.serve(async (req: Request) => {
  // ── Auth check ────────────────────────────────────────────────────────────
  if (CRON_SECRET) {
    const incoming = req.headers.get("x-cron-secret");
    if (incoming !== CRON_SECRET) {
      console.warn("[cron-review-reminders] Unauthorized call rejected");
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  try {
    // Today in YYYY-MM-DD (UTC). Cron fires at 02:30 UTC = 08:00 IST,
    // so UTC date == IST date at that moment.
    const today = new Date().toISOString().split("T")[0];

    // ── 1. Find all active due cards ─────────────────────────────────────────
    // Mirrors the Dashboard.jsx filter exactly (status active, not skipped).
    const { data: dueRows, error: dueError } = await supabaseAdmin
      .from("reviews")
      .select("user_id")
      .eq("status", "active")
      .lte("next_review_date", today)
      .or(`skip_until.is.null,skip_until.lte.${today}`);

    if (dueError) throw dueError;

    if (!dueRows || dueRows.length === 0) {
      console.log("[cron-review-reminders] No due cards today — nothing to send");
      return new Response(JSON.stringify({ success: true, notified: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // ── 2. Count due cards per user ──────────────────────────────────────────
    const userCounts = new Map<string, number>();
    for (const row of dueRows) {
      userCounts.set(row.user_id, (userCounts.get(row.user_id) ?? 0) + 1);
    }

    const userIds = [...userCounts.keys()];

    // ── 3. Check push preferences ────────────────────────────────────────────
    const { data: prefs } = await supabaseAdmin
      .from("push_notification_preferences")
      .select("user_id, review_reminders")
      .in("user_id", userIds);

    // Default to true if the user has no preferences row yet
    const prefMap = new Map(
      (prefs ?? []).map((p) => [p.user_id, p.review_reminders !== false])
    );

    // ── 4. Send one push per eligible user ───────────────────────────────────
    let notified = 0;

    for (const [userId, count] of userCounts.entries()) {
      const enabled = prefMap.get(userId) ?? true;
      if (!enabled) continue;

      const body =
        count === 1
          ? "You have 1 card due for review. Keep your streak alive! 🔥"
          : `You have ${count} cards due for review. Keep your streak alive! 🔥`;

      await sendPushToUsers([userId], {
        title: "📚 Cards Due for Review",
        body,
        // Fixed tag → only ONE review reminder slot on the device per day.
        // If somehow triggered twice, the second silently replaces the first.
        tag: "review-reminder",
        renotify: true,
        data: {
          type: "review_reminder",
          url: "/dashboard/review-session",
        },
      });

      notified++;
    }

    console.log(
      `[cron-review-reminders] Done. Users with due cards: ${userIds.length}, ` +
        `Reminders sent: ${notified}, Opted-out: ${userIds.length - notified}`
    );

    return new Response(
      JSON.stringify({ success: true, notified, total_users: userIds.length }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[cron-review-reminders] Error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
