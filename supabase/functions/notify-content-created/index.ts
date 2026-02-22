import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { sendPushToUsers, PushPayload } from "../_shared/sendPush.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

/** Format a display name based on role */
function formatDisplayName(fullName: string, role: string): string {
  if (!fullName) return "Someone";
  if (role === "professor" || role === "admin" || role === "super_admin") {
    return `Prof. ${fullName.split(" ")[0]}`;
  }
  // Student: "FirstName L."
  const parts = fullName.split(" ");
  if (parts.length > 1) {
    return `${parts[0]} ${parts[parts.length - 1].charAt(0)}.`;
  }
  return parts[0];
}

/** Build the notification message for a given count */
function buildMessage(
  displayName: string,
  contentType: string,
  count: number,
  lastTitle: string,
  subjectName?: string | null
): string {
  const single = contentType === "note" ? "note" : "flashcard deck";
  const plural = contentType === "note" ? "notes" : "flashcard decks";
  const suffix = subjectName ? ` (${subjectName})` : "";

  if (count === 1) {
    return `${displayName} added a new ${single}: "${lastTitle}"${suffix}`;
  }
  return `${displayName} added ${count} ${plural} including "${lastTitle}"${suffix}`;
}

// ─────────────────────────────────────────────
// Main handler
// ─────────────────────────────────────────────

/**
 * POST /functions/v1/notify-content-created
 *
 * Update-in-place notification aggregator for note and flashcard deck uploads.
 * Implements a 4-hour grouping window per (creator, type) pair.
 *
 * Business rules:
 *  - Professor/Admin + public content → type = 'professor_content'
 *    → notify all students with matching course_level
 *  - Student content OR any friends-only content → type = 'friend_content'
 *    → notify only accepted friends of creator
 *  - Private content → function should NOT be called (nothing to notify)
 *
 * Body: {
 *   content_type:  "note" | "flashcard_deck"
 *   content_id:    UUID
 *   creator_id:    UUID
 *   title:         string  (note title or deck name)
 *   subject_name:  string | null  (resolved subject name)
 *   visibility:    "public" | "friends"
 *   target_course: string  (e.g. "CA Intermediate")
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
    const { content_type, content_id, creator_id, title, subject_name, visibility, target_course } =
      body;

    // ── Validation ──────────────────────────────
    if (!content_type || !content_id || !creator_id || !title || !visibility) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields: content_type, content_id, creator_id, title, visibility",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!["note", "flashcard_deck"].includes(content_type)) {
      return new Response(
        JSON.stringify({ error: "content_type must be 'note' or 'flashcard_deck'" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!["public", "friends"].includes(visibility)) {
      // Private content — nothing to do
      return new Response(JSON.stringify({ success: true, notified: 0 }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── 1. Get creator's profile ─────────────────
    const { data: creator, error: creatorError } = await supabaseAdmin
      .from("profiles")
      .select("full_name, role, course_level")
      .eq("id", creator_id)
      .single();

    if (creatorError || !creator) {
      return new Response(JSON.stringify({ error: "Creator profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const displayName = formatDisplayName(creator.full_name ?? "", creator.role);

    // ── 2. Determine notification type ──────────
    // Professor/Admin/SuperAdmin uploading PUBLIC content → professor_content
    // Everyone else (student, or anyone with friends-only) → friend_content
    const isProfessorPublic =
      ["professor", "admin", "super_admin"].includes(creator.role) && visibility === "public";
    const notifType = isProfessorPublic ? "professor_content" : "friend_content";

    // ── 3. Find target user IDs ──────────────────
    let targetUserIds: string[] = [];

    if (isProfessorPublic) {
      // Notify all STUDENTS whose course_level matches the content's target_course
      const courseFilter = target_course ?? creator.course_level;
      if (!courseFilter) {
        console.warn("[notify-content-created] No course level available, skipping");
        return new Response(JSON.stringify({ success: true, notified: 0 }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: students, error: studentsError } = await supabaseAdmin
        .from("profiles")
        .select("id")
        .eq("role", "student")
        .eq("course_level", courseFilter)
        .neq("id", creator_id);

      if (studentsError) throw studentsError;
      targetUserIds = (students ?? []).map((s) => s.id);
    } else {
      // Notify only ACCEPTED FRIENDS of the creator
      const { data: friendships, error: friendshipsError } = await supabaseAdmin
        .from("friendships")
        .select("user_id, friend_id")
        .or(`user_id.eq.${creator_id},friend_id.eq.${creator_id}`)
        .eq("status", "accepted");

      if (friendshipsError) throw friendshipsError;

      targetUserIds = (friendships ?? []).map((f) =>
        f.user_id === creator_id ? f.friend_id : f.user_id
      );
    }

    if (targetUserIds.length === 0) {
      console.log("[notify-content-created] No target users — nothing to do");
      return new Response(JSON.stringify({ success: true, notified: 0 }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── 4. Fetch push preferences for all targets ──
    const { data: prefsRows } = await supabaseAdmin
      .from("push_notification_preferences")
      .select("user_id, professor_content, friend_content")
      .in("user_id", targetUserIds);

    // Map: userId → preference boolean for this notifType
    const pushPrefMap = new Map<string, boolean>();
    for (const p of prefsRows ?? []) {
      pushPrefMap.set(
        p.user_id,
        notifType === "professor_content"
          ? (p.professor_content !== false)
          : (p.friend_content !== false)
      );
    }

    // ── 5. Find existing unread notifications within 4-hour window ──
    // (one per user for this actor+type combination)
    const windowStart = new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString();

    const { data: existingNotifs, error: existingError } = await supabaseAdmin
      .from("notifications")
      .select("id, user_id, message, metadata")
      .in("user_id", targetUserIds)
      .eq("actor_id", creator_id)
      .eq("type", notifType)
      .eq("is_read", false)
      .gte("created_at", windowStart);

    if (existingError) throw existingError;

    // Map: userId → existing notification row
    const existingMap = new Map(
      (existingNotifs ?? []).map((n) => [n.user_id, n])
    );

    // ── 6. Process each target user ─────────────
    // We split users into:
    //   newUsers    → INSERT + renotify:true
    //   updateUsers → UPDATE + renotify:false (silent badge count bump)
    const pushQueue: Array<{
      userIds: string[];
      payload: PushPayload;
    }> = [];

    const newUserIds: string[] = [];
    const newMessage = buildMessage(displayName, content_type, 1, title, subject_name);
    const newTitle = `New content from ${displayName}`;

    const updateOps: Array<{ id: string; message: string; metadata: Record<string, unknown> }> = [];
    const updatePushMap = new Map<string, PushPayload>(); // userId → push payload

    for (const userId of targetUserIds) {
      const existing = existingMap.get(userId);

      if (existing) {
        // ── UPDATE in-place ──────────────────────
        const currentCount: number = (existing.metadata?.count as number) ?? 1;
        const newCount = currentCount + 1;
        const updatedMessage = buildMessage(
          displayName,
          content_type,
          newCount,
          title,
          subject_name
        );

        updateOps.push({
          id: existing.id,
          message: updatedMessage,
          metadata: {
            ...(existing.metadata ?? {}),
            count: newCount,
            last_title: title,
            last_subject: subject_name ?? null,
          },
        });

        // Push: same tag → browser replaces silently
        const pushEnabled = pushPrefMap.get(userId) ?? true;
        if (pushEnabled) {
          updatePushMap.set(userId, {
            title: newTitle,
            body: updatedMessage,
            tag: `content-${creator_id}-${content_type}`,
            renotify: false,  // silent update — don't re-alert
            data: {
              type: notifType,
              creator_id,
              content_type,
              url: content_type === "note"
                ? "/dashboard/notes"
                : "/dashboard/review-flashcards",
            },
          });
        }
      } else {
        // ── INSERT new ───────────────────────────
        const pushEnabled = pushPrefMap.get(userId) ?? true;
        newUserIds.push(userId);
        if (pushEnabled) {
          // All new users get the same payload (renotify:true, count=1)
          // They're batched together in sendPushToUsers
        }
      }
    }

    // ── 7. Bulk-INSERT new notifications ────────
    if (newUserIds.length > 0) {
      const insertRows = newUserIds.map((userId) => ({
        user_id: userId,
        actor_id: creator_id,
        type: notifType,
        title: newTitle,
        message: newMessage,
        is_read: false,
        metadata: {
          count: 1,
          last_title: title,
          last_subject: subject_name ?? null,
          content_type,
        },
      }));

      const { error: insertError } = await supabaseAdmin
        .from("notifications")
        .insert(insertRows);

      if (insertError) throw insertError;

      // Send ONE batched push to all new users (renotify:true)
      const newPushUsers = newUserIds.filter((uid) => (pushPrefMap.get(uid) ?? true));
      if (newPushUsers.length > 0) {
        pushQueue.push({
          userIds: newPushUsers,
          payload: {
            title: newTitle,
            body: newMessage,
            tag: `content-${creator_id}-${content_type}`,
            renotify: true,
            data: {
              type: notifType,
              creator_id,
              content_type,
              url: content_type === "note"
                ? "/dashboard/notes"
                : "/dashboard/review-flashcards",
            },
          },
        });
      }
    }

    // ── 8. Apply updates one-by-one (Supabase JS doesn't support bulk UPDATE) ──
    await Promise.all(
      updateOps.map(({ id, message, metadata }) =>
        supabaseAdmin
          .from("notifications")
          .update({ message, metadata })
          .eq("id", id)
      )
    );

    // ── 9. Send update pushes (one call per user since each has unique body) ──
    for (const [userId, payload] of updatePushMap.entries()) {
      pushQueue.push({ userIds: [userId], payload });
    }

    // ── 10. Dispatch all push sends ──────────────
    await Promise.all(
      pushQueue.map(({ userIds, payload }) => sendPushToUsers(userIds, payload))
    );

    const totalNotified = newUserIds.length + updateOps.length;
    console.log(
      `[notify-content-created] ${content_type} by ${creator_id}. ` +
        `Type: ${notifType}. New: ${newUserIds.length}, Updated: ${updateOps.length}`
    );

    return new Response(
      JSON.stringify({ success: true, notified: totalNotified }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[notify-content-created] Error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
