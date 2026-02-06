# Study Groups & Notifications — Reference Guide

**Last Updated:** February 6, 2026
**Status:** Production-ready
**SQL Files:** `docs/database/study-groups/` (01-26)

---

## 1. OVERVIEW

Study Groups allow users to create private groups, invite friends, and share notes/flashcards with group members. The feature uses a consent-based invitation flow where invited users must accept before gaining access to shared content.

The Notifications system provides real-time alerts for group invitations (and other events like friend requests, upvotes, badges). It uses Supabase Realtime for instant delivery.

---

## 2. DATABASE TABLES

### 2.1 study_groups

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| name | TEXT NOT NULL | Group name |
| description | TEXT | Optional description |
| created_by | UUID FK → profiles | Group creator |
| created_at | TIMESTAMPTZ | Default NOW() |
| updated_at | TIMESTAMPTZ | Default NOW() |

### 2.2 study_group_members

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| group_id | UUID FK → study_groups | ON DELETE CASCADE |
| user_id | UUID FK → profiles | ON DELETE CASCADE |
| role | TEXT | CHECK: 'admin' or 'member' |
| status | TEXT | CHECK: 'invited' or 'active'. DEFAULT 'active' |
| invited_by | UUID FK → profiles | ON DELETE SET NULL. Who sent the invite. |
| joined_at | TIMESTAMPTZ | Reset to NOW() on accept |

**UNIQUE:** (group_id, user_id)
**Indexes:** group_id, user_id, role, status

### 2.3 content_group_shares

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| group_id | UUID FK → study_groups | ON DELETE CASCADE |
| content_type | TEXT | CHECK: 'note' or 'flashcard_deck' |
| content_id | UUID | ID of the note or flashcard_deck |
| shared_by | UUID FK → profiles | ON DELETE CASCADE |
| shared_at | TIMESTAMPTZ | Default NOW() |

**UNIQUE:** (group_id, content_type, content_id)
**ON DELETE CASCADE:** Deleting group removes shares but NOT original content.

### 2.4 notifications (pre-existing, extended)

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID FK → profiles | ON DELETE CASCADE |
| type | TEXT | CHECK constraint (see below) |
| title | TEXT | Added in this session (ALTERed) |
| message | TEXT | Notification body |
| is_read | BOOLEAN | DEFAULT false. Added in this session. |
| metadata | JSONB | Type-specific data. Added in this session. |
| actor_id | UUID | Pre-existing. Who triggered the notification. |
| target_type | TEXT | Pre-existing. |
| target_id | UUID | Pre-existing. |
| created_at | TIMESTAMPTZ | Default NOW() |

**Type CHECK:** `content_upvoted`, `badge_earned`, `friend_request`, `friend_accepted`, `friend_rejected`, `welcome`, `group_invite`

**Realtime:** ENABLED (Supabase Dashboard → Database → Replication)

---

## 3. INVITATION FLOW

```
Admin clicks "Invite Members"
    → searches users by name/email
    → clicks "Invite" button
    ↓
invite_to_group() RPC
    → INSERT study_group_members (status='invited', invited_by=caller)
    → INSERT notifications (type='group_invite', metadata={group_id, membership_id, ...})
    ↓
Invited user receives notification (Realtime)
    ↓
Option A: Accept (from bell dropdown OR MyGroups page)
    → accept_group_invite(p_membership_id)
    → UPDATE status='active', joined_at=NOW()
    → UPDATE notification is_read=true (auto-cleanup)
    ↓
Option B: Decline (from bell dropdown OR MyGroups page)
    → decline_group_invite(p_membership_id)
    → UPDATE notification is_read=true (auto-cleanup)
    → DELETE study_group_members row (hard delete)
    ↓
Option C: Admin cancels invitation
    → DELETE study_group_members WHERE id=membership_id AND status='invited'
```

---

## 4. SECURITY RULES

1. **Content access:** Only `status = 'active'` members can view group-shared content. All content-access RPCs enforce `AND sgm.status = 'active'`.
2. **No email exposure:** No group RPC returns member email addresses. Only: user_id, full_name, role, joined_at.
3. **Strict membership check:** All group RPCs use `IF NOT EXISTS (...) THEN RAISE EXCEPTION 'Access denied'`.
4. **Null safety:** All JSON arrays use double COALESCE: `COALESCE(json_agg(...), '[]'::json)` in subquery AND in `json_build_object`.
5. **Admin-only actions:** Only admins can invite, remove members, share/unshare content.
6. **Invite ownership:** Only the invited user can accept/decline their own invitation (verified by auth.uid()).

---

## 5. RPC REFERENCE

### Study Group RPCs

| RPC | Parameters | Returns | Description |
|-----|-----------|---------|-------------|
| `create_study_group` | p_name, p_description | UUID | Creates group, creator becomes admin |
| `invite_to_group` | p_group_id, p_user_id | VOID | Admin invites user (status='invited' + notification) |
| `accept_group_invite` | p_membership_id | VOID | Accept invite, mark notification read |
| `decline_group_invite` | p_membership_id | VOID | Decline invite, delete membership, mark notification read |
| `get_pending_group_invites` | (none) | TABLE | Pending invitations for current user |
| `leave_group` | p_group_id | VOID | Leave group (auto-promote if last admin) |
| `share_content_with_groups` | p_content_type, p_content_id, p_group_ids | VOID | Share content to multiple groups |
| `get_user_groups` | (none) | TABLE | User's active groups with role & count |
| `get_group_detail` | p_group_id | JSON | Group + active members + pending + shared content |
| `get_group_members` | p_group_id | TABLE | Active members (no email) |
| `get_group_shared_content` | p_group_id | JSON | Shared notes and decks |
| `get_browsable_notes` | (none) | TABLE | All visible notes (own+public+friends+group) |
| `get_browsable_decks` | (none) | TABLE | All visible decks (own+public+friends+group) |

### Notification RPCs

| RPC | Parameters | Returns | Description |
|-----|-----------|---------|-------------|
| `get_unread_notification_count` | p_user_id | INTEGER | Count of unread notifications |
| `get_recent_notifications` | p_user_id, p_limit | TABLE | Recent notifications with metadata |
| `mark_notifications_read` | p_user_id | VOID | Mark all as read |
| `mark_single_notification_read` | p_notification_id | VOID | Mark one as read |
| `delete_notification` | p_notification_id | VOID | Delete a notification |
| `cleanup_old_notifications` | (none) | INTEGER | Delete >60 days old (cron utility) |

---

## 6. FRONTEND COMPONENTS

### Pages
| File | Purpose |
|------|---------|
| `src/pages/dashboard/Groups/MyGroups.jsx` | Group list + pending invitations with Accept/Decline |
| `src/pages/dashboard/Groups/CreateGroup.jsx` | Create group form (name + description) |
| `src/pages/dashboard/Groups/GroupDetail.jsx` | Members panel, shared content, invite/share dialogs |

### Layout Components (modified)
| File | Change |
|------|--------|
| `ActivityDropdown.jsx` | Added group_invite type with inline Accept/Decline buttons |
| `Navigation.jsx` | Passes deleteNotification, refetchNotifications to children |
| `NavDesktop.jsx` | Receives new props, Network icon for Groups |
| `NavMobile.jsx` | Receives new props, Network icon for Groups |

### Hooks
| File | Purpose |
|------|---------|
| `src/hooks/useNotifications.js` | Fetches notifications, Realtime subscription, exports refetch + deleteNotification |

---

## 7. GROUP INVITE NOTIFICATION FORMAT

**Metadata (JSONB):**
```json
{
  "group_id": "uuid-of-the-group",
  "group_name": "CA Inter Study Group",
  "inviter_id": "uuid-of-the-admin",
  "inviter_name": "Anand",
  "membership_id": "uuid-of-the-membership-row"
}
```

**Title:** `"Anand invited you to \"CA Inter Study Group\""`
**Message:** `"Accept to start viewing shared notes and flashcards."`
**Type:** `group_invite`

The `membership_id` in metadata is used by accept/decline RPCs for automatic notification cleanup:
```sql
UPDATE notifications SET is_read = true
WHERE metadata->>'membership_id' = p_membership_id::TEXT;
```

---

## 8. SQL FILE INDEX

| # | File | Type | Purpose |
|---|------|------|---------|
| 01 | 01_SCHEMA_study_groups_tables.sql | SCHEMA | 3 tables + indexes + constraints |
| 02 | 02_RLS_study_groups_policies.sql | SCHEMA | 8 RLS policies (sgm_select_own after fix) |
| 03 | 03_FUNCTION_create_study_group.sql | FUNCTION | Create group + admin membership |
| 04 | 04_FUNCTION_invite_to_group.sql | FUNCTION | Original auto-add (REPLACED by #16) |
| 05 | 05_FUNCTION_leave_group.sql | FUNCTION | Original leave (REPLACED by #24) |
| 06 | 06_FUNCTION_share_content.sql | FUNCTION | Share content to groups |
| 07 | 07_FUNCTION_get_user_groups.sql | FUNCTION | Original get groups (REPLACED by #20) |
| 08 | 08_FUNCTION_get_shared_content.sql | FUNCTION | Get shared content for a group |
| 09 | 09_FUNCTION_get_group_members.sql | FUNCTION | Get members (no email) |
| 10 | 10_FUNCTION_get_browsable_notes.sql | FUNCTION | Original browsable notes (REPLACED by #22) |
| 11 | 11_FUNCTION_get_browsable_decks.sql | FUNCTION | Original browsable decks (REPLACED by #23) |
| 12 | 12_FUNCTION_get_group_detail.sql | FUNCTION | Original group detail (REPLACED by #21) |
| 13 | 13_SCHEMA_notifications_table.sql | SCHEMA | Notifications table (skipped if exists) |
| 14 | 14_FUNCTIONS_notification_rpcs.sql | FUNCTION | 5 notification RPCs + cleanup |
| 15 | 15_SCHEMA_add_invitation_status.sql | SCHEMA | Add status + invited_by columns |
| 16 | 16_FUNCTION_invite_to_group_v2.sql | FUNCTION | Invite with notification + consent |
| 17 | 17_FUNCTION_accept_group_invite.sql | FUNCTION | Accept invite + auto-cleanup notification |
| 18 | 18_FUNCTION_decline_group_invite.sql | FUNCTION | Decline invite + hard delete row |
| 19 | 19_FUNCTION_get_pending_group_invites.sql | FUNCTION | Pending invites for MyGroups |
| 20 | 20_FUNCTION_get_user_groups_v2.sql | FUNCTION | Active groups only |
| 21 | 21_FUNCTION_get_group_detail_v2.sql | FUNCTION | With pending invitations |
| 22 | 22_FUNCTION_get_browsable_notes_v2.sql | FUNCTION | With status='active' filter |
| 23 | 23_FUNCTION_get_browsable_decks_v2.sql | FUNCTION | With status='active' filter |
| 24 | 24_FUNCTION_leave_group_v2.sql | FUNCTION | Active-only member/admin counts |
| 25 | 25_FIX_notifications_missing_columns.sql | FIX | Add title/metadata/is_read + fix ambiguous ref |
| 26 | 26_FIX_notifications_type_check.sql | FIX | Update CHECK constraint for group_invite |

---

## 9. COMMON ISSUES & TROUBLESHOOTING

### `cannot change return type of existing function`
**Cause:** `CREATE OR REPLACE` cannot change return signatures.
**Fix:** Add `DROP FUNCTION IF EXISTS function_name(param_types);` before CREATE.

### `CREATE TABLE IF NOT EXISTS` doesn't add new columns
**Cause:** Table already exists — Postgres skips the entire CREATE.
**Fix:** Use `ALTER TABLE ADD COLUMN IF NOT EXISTS` for new columns.

### `column reference "X" is ambiguous`
**Cause:** Column name in subquery conflicts with RETURNS TABLE column name.
**Fix:** Alias the subquery table: `FROM table_name sub WHERE sub.column = ...`

### `violates check constraint "notifications_type_check"`
**Cause:** New notification type not included in existing CHECK constraint.
**Fix:** DROP and recreate constraint with new type added.

### Notifications not appearing in real-time
**Cause:** Supabase Realtime not enabled for notifications table.
**Fix:** Dashboard → Database → Replication → Toggle ON for `notifications`.
