import webPush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

// Inline admin client — the _shared/ path is not resolvable when deployed
// via the Supabase dashboard editor. Functionally identical to _shared/supabaseAdmin.ts.
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false } }
);

// Shared secret — must match the CRON_SECRET Supabase project secret.
// The pg_cron job passes this in the x-cron-secret header so random
// external callers cannot trigger the function.
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

// Configure VAPID once at module load (same keys used by all other push functions)
webPush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT") ?? "mailto:hello@recallapp.co.in",
  Deno.env.get("VAPID_PUBLIC_KEY") ?? "",
  Deno.env.get("VAPID_PRIVATE_KEY") ?? ""
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Format a duration as "1h 23m" or "45m" — matches the Sprint 3.1 display format.
 * Input of 0 is handled by the caller (< 60s = "didn't study" variant).
 */
function formatStudyTime(totalSeconds: number): string {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

/**
 * Return the local hour (0–23) and minute (0–59) for a given timezone.
 * Uses Intl.DateTimeFormat so fractional offsets like UTC+5:30 are handled correctly.
 */
function getLocalHourMinute(
  now: Date,
  timezone: string
): { hour: number; minute: number } {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).formatToParts(now);
    const hour = parseInt(parts.find((p) => p.type === "hour")?.value ?? "0", 10);
    const minute = parseInt(parts.find((p) => p.type === "minute")?.value ?? "0", 10);
    // hour12:false can return 24 for midnight in some locales — normalise to 0
    return { hour: hour === 24 ? 0 : hour, minute };
  } catch {
    return { hour: 0, minute: 0 };
  }
}

/**
 * Return the local date string "YYYY-MM-DD" for a given timezone.
 * Never uses toISOString() — avoids UTC-date-as-local-date bug.
 */
function getLocalDateStr(now: Date, timezone: string): string {
  try {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(now);
    const year = parts.find((p) => p.type === "year")?.value ?? "";
    const month = parts.find((p) => p.type === "month")?.value ?? "";
    const day = parts.find((p) => p.type === "day")?.value ?? "";
    return `${year}-${month}-${day}`;
  } catch {
    // Fallback to Asia/Kolkata if the stored timezone string is invalid
    return getLocalDateStr(now, "Asia/Kolkata");
  }
}

// ── Main handler ──────────────────────────────────────────────────────────────

/**
 * POST /functions/v1/cron-daily-study-summary
 *
 * Scheduled every 15 minutes via pg_cron (*/15 * * * *).
 * 15-minute cadence is required for fractional-offset timezone support (IST = UTC+5:30):
 * an hourly cron at :00 would fire at 10:30 PM IST, not 10:00 PM IST.
 *
 * Each invocation only notifies users whose LOCAL time falls in 22:00–22:14,
 * so each user receives exactly one notification per day regardless of their timezone.
 *
 * Only students active in the last 7 days are included; professors and admins are excluded.
 *
 * Returns: { processed, sent, failed, removed_stale }
 */
Deno.serve(async (req: Request) => {
  // ── Auth ───────────────────────────────────────────────────────────────────
  if (CRON_SECRET) {
    const incoming = req.headers.get("x-cron-secret");
    if (incoming !== CRON_SECRET) {
      console.warn("[cron-daily-study-summary] Unauthorized call rejected");
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  try {
    const now = new Date();

    // ── 1. Fetch all students with their timezones ──────────────────────────
    const { data: students, error: studentsError } = await supabaseAdmin
      .from("profiles")
      .select("id, timezone")
      .eq("role", "student");

    if (studentsError) throw studentsError;
    if (!students || students.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, sent: 0, failed: 0, removed_stale: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 2. Filter: only students whose local time is 22:00–22:14 ──────────
    // 15-minute bucketing: cron fires at :00, :15, :30, :45.
    // For IST (UTC+5:30): 4:30 UTC → IST 22:00 → hour=22, minute=0 → 0 < 15 ✅
    // Next fire 4:45 UTC → IST 22:15 → minute=15 → 15 < 15 is FALSE ✅ no duplicate
    const windowStudents = students.filter((s) => {
      const tz = s.timezone || "Asia/Kolkata";
      const { hour, minute } = getLocalHourMinute(now, tz);
      return hour === 22 && minute < 15;
    });

    if (windowStudents.length === 0) {
      console.log(
        "[cron-daily-study-summary] No users in 22:00–22:14 window this cycle"
      );
      return new Response(
        JSON.stringify({ processed: 0, sent: 0, failed: 0, removed_stale: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const windowIds = windowStudents.map((s) => s.id);

    // ── 3. Filter: only students active in the last 7 days ─────────────────
    // "Active" = at least one study session OR review in the past 7 days.
    // We use an absolute epoch offset (not toISOString of CURRENT_DATE) because
    // we are comparing against timestamptz columns — this is a point-in-time check.
    const sevenDaysAgoMs = now.getTime() - 7 * 24 * 60 * 60 * 1000;
    const sevenDaysAgoISO = new Date(sevenDaysAgoMs).toISOString();

    const [{ data: activeSessions }, { data: activeReviews }] =
      await Promise.all([
        supabaseAdmin
          .from("study_sessions")
          .select("user_id")
          .in("user_id", windowIds)
          .gte("created_at", sevenDaysAgoISO),
        supabaseAdmin
          .from("reviews")
          .select("user_id")
          .in("user_id", windowIds)
          .gte("created_at", sevenDaysAgoISO),
      ]);

    const activeUserIds = new Set([
      ...(activeSessions ?? []).map((r) => r.user_id),
      ...(activeReviews ?? []).map((r) => r.user_id),
    ]);

    const activeStudents = windowStudents.filter((s) =>
      activeUserIds.has(s.id)
    );

    if (activeStudents.length === 0) {
      console.log(
        "[cron-daily-study-summary] No active users found in window — skipping"
      );
      return new Response(
        JSON.stringify({ processed: 0, sent: 0, failed: 0, removed_stale: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 4. Get each student's study time for TODAY (in their local timezone) ─
    // session_date is stored as the user's local date (type: date, YYYY-MM-DD).
    // Group users by their local date string to batch the query efficiently.
    const userLocalDate = new Map<string, string>(); // userId → "YYYY-MM-DD"
    for (const s of activeStudents) {
      userLocalDate.set(s.id, getLocalDateStr(now, s.timezone || "Asia/Kolkata"));
    }

    // Group user IDs by their local date (typically one group since all IST users share the same date)
    const dateGroups = new Map<string, string[]>(); // dateStr → [userId, ...]
    for (const [userId, dateStr] of userLocalDate.entries()) {
      if (!dateGroups.has(dateStr)) dateGroups.set(dateStr, []);
      dateGroups.get(dateStr)!.push(userId);
    }

    const studySecondsMap = new Map<string, number>(); // userId → total seconds today
    for (const [dateStr, userIds] of dateGroups.entries()) {
      const { data: sessions } = await supabaseAdmin
        .from("study_sessions")
        .select("user_id, duration_seconds")
        .in("user_id", userIds)
        .eq("session_date", dateStr);

      for (const row of sessions ?? []) {
        studySecondsMap.set(
          row.user_id,
          (studySecondsMap.get(row.user_id) ?? 0) + (row.duration_seconds ?? 0)
        );
      }
    }

    // ── 5. Fetch active push subscriptions for all qualifying students ──────
    // TODO: When user base exceeds 1,000, chunk in batches of 200 using
    // Promise.allSettled to avoid timeout.
    const activeIds = activeStudents.map((s) => s.id);
    const { data: subscriptions, error: subError } = await supabaseAdmin
      .from("push_subscriptions")
      .select("id, user_id, endpoint, p256dh, auth")
      .in("user_id", activeIds)
      .eq("is_active", true);

    if (subError) throw subError;

    if (!subscriptions || subscriptions.length === 0) {
      console.log(
        `[cron-daily-study-summary] ${activeStudents.length} qualifying users but no active subscriptions`
      );
      return new Response(
        JSON.stringify({
          processed: activeStudents.length,
          sent: 0,
          failed: 0,
          removed_stale: 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Group subscriptions by user_id (one user may have multiple devices)
    const subsByUser = new Map<string, typeof subscriptions>();
    for (const sub of subscriptions) {
      if (!subsByUser.has(sub.user_id)) subsByUser.set(sub.user_id, []);
      subsByUser.get(sub.user_id)!.push(sub);
    }

    // ── 6. Send one notification per device per qualifying user ────────────
    let sent = 0;
    let failed = 0;
    const staleSubIds: string[] = [];

    for (const student of activeStudents) {
      const subs = subsByUser.get(student.id);
      if (!subs || subs.length === 0) continue; // subscribed on no devices

      const todaySeconds = studySecondsMap.get(student.id) ?? 0;

      // Message variants based on whether the student studied today
      const payload =
        todaySeconds >= 60
          ? {
              title: "Great work today 🎯",
              body: `You logged ${formatStudyTime(todaySeconds)} of study time today. Check how you rank against your friends.`,
              icon: "/android-chrome-192x192.png",
              badge: "/android-chrome-192x192.png",
              tag: "daily-study-summary",
              renotify: false,
              data: { url: "/dashboard" },
            }
          : {
              title: "Time to open the books 📚",
              body: "No study time logged yet today. Even 15 minutes keeps the streak going.",
              icon: "/android-chrome-192x192.png",
              badge: "/android-chrome-192x192.png",
              tag: "daily-study-summary",
              renotify: false,
              data: { url: "/dashboard" },
            };

      const payloadStr = JSON.stringify(payload);

      for (const sub of subs) {
        try {
          await webPush.sendNotification(
            { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
            payloadStr,
            { TTL: 3600 } // 1-hour TTL — discard if undelivered after 1h
          );
          sent++;
        } catch (err: unknown) {
          const status = (err as { statusCode?: number }).statusCode;
          if (status === 410 || status === 404) {
            // Subscription expired or revoked — mark stale, continue to next user
            staleSubIds.push(sub.id);
          } else {
            console.error(
              `[cron-daily-study-summary] Push failed for sub ${sub.id}:`,
              (err as Error).message
            );
            failed++;
          }
        }
      }
    }

    // ── 7. Deactivate stale subscriptions in one batch ─────────────────────
    if (staleSubIds.length > 0) {
      await supabaseAdmin
        .from("push_subscriptions")
        .update({ is_active: false })
        .in("id", staleSubIds);
      console.log(
        `[cron-daily-study-summary] Deactivated ${staleSubIds.length} stale subscription(s)`
      );
    }

    const result = {
      processed: activeStudents.length,
      sent,
      failed,
      removed_stale: staleSubIds.length,
    };

    console.log("[cron-daily-study-summary] Done:", JSON.stringify(result));

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[cron-daily-study-summary] Fatal error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
