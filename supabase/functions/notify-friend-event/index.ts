import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { sendPushToUsers } from "../_shared/sendPush.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * POST /functions/v1/notify-friend-event
 *
 * Creates an instant (non-aggregated) notification for friend lifecycle events.
 * Called from the frontend after a friend request is sent or accepted.
 *
 * Body: {
 *   event_type: "friend_request" | "friend_accepted",
 *   actor_id:        UUID  — user who triggered the event
 *   target_user_id:  UUID  — user who should receive the notification
 * }
 */
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const { event_type, actor_id, target_user_id } = body;

    // --- Input validation ---
    if (!event_type || !actor_id || !target_user_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: event_type, actor_id, target_user_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!["friend_request", "friend_accepted"].includes(event_type)) {
      return new Response(
        JSON.stringify({ error: "event_type must be 'friend_request' or 'friend_accepted'" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // --- Get actor's display name ---
    const { data: actor, error: actorError } = await supabaseAdmin
      .from("profiles")
      .select("full_name")
      .eq("id", actor_id)
      .single();

    if (actorError || !actor) {
      return new Response(JSON.stringify({ error: "Actor profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const actorName = actor.full_name ?? "Someone";

    // --- Build notification content ---
    const isRequest = event_type === "friend_request";
    const title = isRequest ? "New Friend Request" : "Friend Request Accepted";
    const message = isRequest
      ? `${actorName} sent you a friend request`
      : `${actorName} accepted your friend request`;

    // --- Check target user's push preferences ---
    const { data: prefs } = await supabaseAdmin
      .from("push_notification_preferences")
      .select("friend_requests, friend_accepted")
      .eq("user_id", target_user_id)
      .single();

    // Default to true if no preference row exists yet
    const prefKey = isRequest ? "friend_requests" : "friend_accepted";
    const pushEnabled = prefs ? (prefs[prefKey] !== false) : true;

    // --- Insert notification into DB ---
    const { data: notification, error: insertError } = await supabaseAdmin
      .from("notifications")
      .insert({
        user_id: target_user_id,
        actor_id,
        type: event_type,           // 'friend_request' or 'friend_accepted'
        title,
        message,
        is_read: false,
        metadata: {
          actor_name: actorName,
          count: 1,
        },
      })
      .select("id")
      .single();

    if (insertError) throw insertError;

    // --- Send push notification if enabled ---
    if (pushEnabled) {
      await sendPushToUsers([target_user_id], {
        title,
        body: message,
        // tag format: "friend-{actor_id}" so repeat requests from same person
        // update the same notification slot on the device
        tag: `friend-${actor_id}`,
        renotify: true,  // Always re-alert for friendship events (no batching)
        data: {
          type: event_type,
          actor_id,
          notification_id: notification.id,
          url: "/dashboard/friends",
        },
      });
    }

    console.log(
      `[notify-friend-event] ${event_type} from ${actor_id} → ${target_user_id}. ` +
        `Push: ${pushEnabled ? "sent" : "skipped (preference off)"}`
    );

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[notify-friend-event] Error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
