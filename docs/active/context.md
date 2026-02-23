# RECALL - Project Context (Source of Truth)

**Last Updated:** January 26, 2026  
**Live URL:** https://recall-app-omega.vercel.app  
**Repository:** https://github.com/ai1976/recall-app

---

## Project Overview

**App Name:** Recall  
**Tagline:** "Remember Everything. Ace Every Exam."  
**Target Users:** CA/CMA/CS students (India) - expanding to JEE/NEET, undergraduate and school section for state and central boards
**Current Phase:** Phase 1 Complete, Phase 0.5 (Professor Content Seeding) in progress  
**Business Model:** Freemium (Free tier with limits → Premium ₹149/month)

---
---

## Study Groups + Invitation Flow + Notifications Backend (2026-02-06)

### Study Groups (Phase 1: Read-Only Sharing)

**Concept:** Users create groups, invite friends, share notes/flashcards with selected people.

#### 4-Tier Visibility Model
| Level | Who Can See |
|-------|-------------|
| **Private** | Only creator |
| **Study Groups** | Creator + group members (stored as 'private' in DB, accessed via content_group_shares) |
| **Friends** | Creator + accepted friends |
| **Public** | Everyone |

#### Database Tables (3 new)
- `study_groups` — Group metadata (name, description, creator). Creator can update/delete.
- `study_group_members` — Membership with roles (admin/member) + invitation status ('invited'/'active') + invited_by. UNIQUE(group_id, user_id). ON DELETE CASCADE from study_groups.
- `content_group_shares` — Links content (notes/decks) to groups. UNIQUE(group_id, content_type, content_id). ON DELETE CASCADE from study_groups (deleting group removes shares, NOT original content).

#### Invitation Flow (Consent-Based)
1. Admin clicks "Invite Members" → searches users → clicks "Invite"
2. `invite_to_group()` inserts with `status = 'invited'` + creates notification with JSONB metadata
3. Invited user sees notification in bell dropdown with inline Accept/Decline buttons
4. Invited user also sees amber "Pending Invitations" section on MyGroups page
5. Accept → `accept_group_invite()` updates status to 'active', marks notification read
6. Decline → `decline_group_invite()` marks notification read, hard DELETEs membership row
7. Admin can cancel pending invitations from GroupDetail members panel

#### Security Rules
- Only **active** members can view group content (`AND sgm.status = 'active'` in all content queries)
- Invited users CANNOT see shared notes/decks until they accept
- No email returned in any group RPC (privacy)
- Strict `IF NOT EXISTS` membership check with 'Access denied' exception
- All arrays use double COALESCE ensuring `[]` never `null`

### Notifications Backend

**Architecture:** `notifications` table was pre-existing (from Phase 1B). We added `title`, `metadata JSONB`, `is_read` columns + updated CHECK constraint to include `group_invite` type.

#### Notification Types (CHECK constraint)
`content_upvoted`, `badge_earned`, `friend_request`, `friend_accepted`, `friend_rejected`, `welcome`, `group_invite`

#### RPCs (6 SECURITY DEFINER functions)
1. `get_unread_notification_count(p_user_id)` → INTEGER
2. `get_recent_notifications(p_user_id, p_limit)` → TABLE (includes metadata JSONB)
3. `mark_notifications_read(p_user_id)` → VOID (mark all)
4. `mark_single_notification_read(p_notification_id)` → VOID
5. `delete_notification(p_notification_id)` → VOID
6. `cleanup_old_notifications()` → INTEGER (deletes > 60 days, for cron)

#### Realtime
- `notifications` table has Supabase Realtime enabled (Replication toggle in Dashboard)
- `useNotifications.js` hook subscribes to INSERT events filtered by `user_id`
- New notifications appear instantly in bell dropdown without page refresh

#### Group Invite Notification Metadata (JSONB)
```json
{
  "group_id": "uuid",
  "group_name": "Study Group Name",
  "inviter_id": "uuid",
  "inviter_name": "John Doe",
  "membership_id": "uuid"
}
```

### Study Group RPCs (14 SECURITY DEFINER functions)
1. `create_study_group(p_name, p_description)` — Creates group + adds creator as admin
2. `invite_to_group(p_group_id, p_user_id)` — Admin invites (status='invited' + notification)
3. `accept_group_invite(p_membership_id)` — User accepts, auto-marks notification read
4. `decline_group_invite(p_membership_id)` — User declines, hard DELETEs row
5. `get_pending_group_invites()` — Returns pending invitations for MyGroups page
6. `leave_group(p_group_id)` — Member leaves (promotes oldest if last admin, deletes group if last member)
7. `share_content_with_groups(p_content_type, p_content_id, p_group_ids)` — Multi-group share
8. `get_user_groups()` — Returns user's ACTIVE groups with member count and role
9. `get_group_shared_content(p_group_id)` — Returns shared notes and decks
10. `get_group_members(p_group_id)` — Returns active members (no email)
11. `get_group_detail(p_group_id)` — Returns group + active members + pending invitations + shared content (single call)
12. `get_browsable_notes()` — All visible notes (own + public + friends + group-shared, active members only)
13. `get_browsable_decks()` — Same for flashcard decks
14. `get_filtered_authors_for_notes/flashcards()` — Author search (pre-existing, not modified)

### Frontend Pages
- `MyGroups.jsx` — Group list + "Pending Invitations" section with Accept/Decline
- `CreateGroup.jsx` — Name + description form
- `GroupDetail.jsx` — Members panel (with pending section for admins), shared content, invite/share/remove dialogs

### Navigation
- Desktop: `Network` icon + "Groups" link in main nav
- Mobile: Study Groups section in hamburger sheet
- ActivityDropdown: group_invite notifications with inline Accept/Decline buttons

### SQL Files
All in `docs/database/study-groups/` (files 01-26):
- 01-08: Phase 1 schema + RLS + functions
- 09-12: RLS fix + server-side content fetching
- 13-14: Notifications table + RPCs
- 15-19: Invitation flow (status column + invite/accept/decline/pending RPCs)
- 20-24: Updated existing RPCs with status='active' filter
- 25-26: Fixes (missing columns, ambiguous ref, type CHECK constraint)

---

## Phase 1E: Achievement Badges System (2026-01-26)

### New Database Tables

#### badge_definitions
```
badge_definitions
├── id (UUID, PK)
├── key (TEXT, UNIQUE) -- 'digitalizer', 'memory_architect', etc.
├── name (TEXT)
├── description (TEXT)
├── icon_key (TEXT) -- Maps to Lucide icon in frontend
├── category (TEXT) -- 'content', 'study', 'social'
├── threshold (INTEGER)
├── is_active (BOOLEAN, DEFAULT true)
├── order_num (INTEGER)
└── created_at (TIMESTAMP)
```

#### user_badges
```
user_badges
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── badge_id (UUID, FK → badge_definitions.id)
├── earned_at (TIMESTAMP)
├── notified (BOOLEAN, DEFAULT false)
├── is_public (BOOLEAN, DEFAULT true) -- Per-badge privacy
└── UNIQUE(user_id, badge_id)
```

#### user_activity_log
```
user_activity_log
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── activity_type (TEXT) -- 'review', 'flashcard_create', 'note_upload'
├── activity_date (DATE)
├── activity_hour (INTEGER) -- 0-23, IST timezone
├── created_at (TIMESTAMP)
└── UNIQUE(user_id, activity_type, activity_date)
```

### Badge Definitions (Initial Set)

| Key | Name | Icon | Category | Threshold | Trigger |
|-----|------|------|----------|-----------|---------|
| digitalizer | Digitalizer | upload | content | 1 | notes INSERT |
| memory_architect | Memory Architect | brain | content | 10 | flashcards INSERT |
| streak_master | Streak Master | flame | study | 3 | reviews INSERT (streak) |
| night_owl | Night Owl | moon | study | 1 | reviews INSERT (11PM-4AM IST) |
| rising_star | Rising Star | star | social | 5 | upvotes INSERT |

### Database Functions
- `award_badge(p_user_id, p_badge_key)` - Awards badge if not already earned
- `log_review_activity(p_user_id, p_review_timestamp)` - Logs activity with IST conversion
- `get_user_streak(p_user_id)` - Calculates consecutive study days
- `is_night_owl_hour(p_hour)` - Returns true if hour is 23 or 0-4
- `get_user_badges(p_user_id)` - Returns all badges with is_public flag
- `get_public_user_badges(p_user_id)` - Returns only public badges
- `get_unnotified_badges(p_user_id)` - Returns unnotified badges, marks as notified

### Database Triggers
- `trg_badge_note_upload` - On notes INSERT → checks digitalizer
- `trg_badge_flashcard_create` - On flashcards INSERT → checks memory_architect
- `trg_badge_review` - On reviews INSERT → logs activity, checks streak_master & night_owl
- `trg_badge_upvote` - On upvotes INSERT → checks rising_star

### Privacy System
- **Per-badge privacy:** Each badge has `is_public` toggle (default: true)
- Users control visibility of individual badges
- FindFriends only shows badges where `is_public = true`
- No global toggle - granular control per badge

### Frontend Components
- `src/components/badges/BadgeIcon.jsx` - Maps icon_key to Lucide icons
- `src/components/badges/BadgeCard.jsx` - Badge display with privacy toggle
- `src/components/badges/BadgeToast.jsx` - Toast notification for new badges
- `src/hooks/useBadges.js` - Badge data fetching hook
- `src/pages/dashboard/Profile/MyAchievements.jsx` - Achievements page

### Navigation Updates
- Added "My Achievements" link under Study dropdown
- Badge toast notifications on Dashboard when new badge earned

---
## Phase 1B: Notifications & Navigation Redesign (2026-02-02)

### New Database Functions
- `get_unread_notification_count(p_user_id)` → Returns integer count
- `get_recent_notifications(p_user_id, p_limit)` → Returns notifications array
- `mark_notifications_read(p_user_id)` → Marks all as read, returns count
- `mark_single_notification_read(p_notification_id)` → Marks one as read
- `delete_notification(p_notification_id)` → Deletes notification
- `get_recent_activity_feed(p_user_id, p_course_level, p_limit)` → Returns recent notes/decks

### New Frontend Hooks
- `src/hooks/useNotifications.js` - Realtime notifications with Supabase subscription
- `src/hooks/useFriendRequestCount.js` - Realtime pending friend request count
- `src/hooks/useActivityFeed.js` - Recent content feed for dashboard

### Navigation Redesign
Modular component structure replacing monolithic Navigation.jsx:
src/components/layout/
├── Navigation.jsx (orchestrator - 55 lines)
├── NavDesktop.jsx (desktop layout with dropdowns)
├── NavMobile.jsx (mobile hamburger + Sheet)
├── FriendsDropdown.jsx (friends icon + pending requests)
├── ActivityDropdown.jsx (bell icon + notifications)
└── ProfileDropdown.jsx (avatar dropdown with profile links)

#### Desktop Layout
`[RECALL Logo] ...spacer... [Dashboard] [Study▾] [Create▾] [Super Admin*] ...spacer... [Friends 👥] [Bell 🔔] [Avatar ▼]`


#### Mobile Layout
`[RECALL Logo] ...spacer... [Friends 👥] [Bell 🔔] [Hamburger ☰]`

### New UI Component
- `src/components/ui/sheet.jsx` - Radix Dialog-based Sheet for mobile navigation

### Dashboard Activity Feed
- `src/components/dashboard/ActivityFeed.jsx` - Shows recent notes/decks from past 7 days
- Displays content type icon (FileText for notes, CreditCard for decks)
- Shows creator with "Prof." prefix for professors
- Relative time formatting (2 hours ago, Yesterday, 3 days ago)
- View/Study buttons linking to content

### Key Features
- **Realtime badges:** Red dot with count on Friends/Bell icons
- **Auto mark-as-read:** Notifications marked read when dropdown opens
- **Accept/Decline inline:** Friend requests manageable from dropdown
- **Mobile Sheet:** Smooth slide-in navigation with auto-close on navigate



## Phase 1D: Upvote System (2026-01-24)

### New Database Tables

#### flashcard_decks
```
flashcard_decks
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── subject_id (UUID, FK → subjects.id, nullable)
├── custom_subject (TEXT, nullable)
├── topic_id (UUID, FK → topics.id, nullable)
├── custom_topic (TEXT, nullable)
├── target_course (TEXT)
├── visibility (TEXT: private/friends/public)
├── name (TEXT, optional custom name)
├── description (TEXT)
├── card_count (INTEGER, auto-updated by trigger)
├── upvote_count (INTEGER, auto-updated by trigger)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

### Modified Tables

#### upvotes (Polymorphic Design)
```
upvotes
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id) -- WHO upvoted
├── content_type (TEXT: 'note' | 'flashcard_deck') -- NEW
├── target_id (UUID) -- NEW: points to notes.id or flashcard_decks.id
├── note_id (UUID, nullable, deprecated - kept for migration)
└── created_at (TIMESTAMP)
└── UNIQUE(user_id, content_type, target_id)
```

#### flashcards (Added Column)
- `deck_id` (UUID, FK → flashcard_decks.id) - Links cards to their deck

### Database Functions
- `toggle_upvote(p_content_type, p_target_id)` - Toggle upvote with validation
- `get_upvote_details(p_content_type, p_target_id)` - Get upvoter names for creators
- `has_user_upvoted(p_content_type, p_target_id)` - Check if user upvoted
- `update_upvote_counts()` - Trigger function for auto-updating counts
- `update_deck_card_count()` - Trigger function for deck card counts

### RLS Policies

#### flashcard_decks
- SELECT: Own, public, friends (with friendship check), admin
- INSERT/UPDATE/DELETE: Own or admin

#### upvotes
- SELECT: All authenticated users (for counting)
- INSERT: Only on content user can view AND not own content
- DELETE: Own upvotes only

### Frontend Components

#### New: UpvoteButton.jsx (`src/components/ui/UpvoteButton.jsx`)
- Reusable toggle button for notes and flashcard_decks
- Optimistic UI updates
- Prevents self-upvoting
- Size variants: sm, md, lg

#### Modified Files
- `BrowseNotes.jsx` - Upvote button on note cards
- `ReviewFlashcards.jsx` - Upvote button on deck cards (queries flashcard_decks)
- `MyContributions.jsx` - Community Feedback section with upvoter names
- `NoteDetail.jsx` - Upvote button in header

### Upvote Rules
1. One upvote per user per content (enforced by UNIQUE constraint)
2. Cannot upvote own content (enforced by RLS + frontend)
3. Can only upvote content you can view (visibility rules apply)
4. Toggle behavior: click again to remove upvote
5. Creators see WHO upvoted; students see counts only
----
**Current state**

Recall is in production with 27 registered students and impressive early metrics: 542+ total reviews from top students. The platform features a complete tech stack (React, Supabase, Vercel) with a four-tier role system (super_admin, admin, professor, student), three-tier content visibility (Private/Friends/Public), and comprehensive spaced repetition using SuperMemo-2 methodology.

**DASHBOARD REDESIGN (2026-01-24):** Implemented Phase 1C with anonymous class statistics. New `AnonymousStats` component shows "You vs Class" comparison using Tailwind progress bars, class milestones (students studied today, 7-day streaks), with privacy-first design (min 5 users for averages, course-level filtering). SQL function `get_anonymous_class_stats()` uses SECURITY DEFINER to aggregate across users while respecting privacy. Quick Actions expanded to 4 buttons for better UX.

Recent development has focused on fixing the spaced repetition architecture, implementing proper review progress persistence, and adding subject-based review grouping. The platform successfully handles review data isolation per user, preventing schedule conflicts between students reviewing the same cards.


## Spaced Repetition & Timezone Standards

### Critical Bug Fix (2026-01-21)

#### Root Causes Identified
1. **Timezone Mismatch:** Using `toISOString()` (UTC) caused "Next Review Date" to be calculated as "Yesterday" for users in Western timezones (or late night in India), causing cards to reappear immediately.
2. **Architectural Conflict:** Progress was originally writing to `flashcards` table (Professor-owned), causing RLS failures.
3. **Logic Mismatch:** Dashboard counted "New Cards" as "Due", creating "All Caught Up" false positives when entering Review Session.

#### Enforced Technical Rules

**Date Handling (CRITICAL - NEVER VIOLATE):**
**Date Handling (CRITICAL - NEVER VIOLATE):**
- ❌ **NEVER** use `date.toISOString()` for user-facing date comparisons
- ❌ **NEVER** hardcode a specific timezone (e.g., `Asia/Kolkata`)
- ✅ **ALWAYS** use `toLocaleDateString('en-CA')` WITHOUT timezone parameter
- **Reason:** This uses the user's browser/device timezone automatically, works globally for all users

**Example (Correct Implementation):**
```javascript
// ============================================================
// HELPER: Format date as YYYY-MM-DD in user's LOCAL timezone
// Using 'en-CA' locale gives us ISO format (YYYY-MM-DD) which
// allows correct string comparison for dates.
// ============================================================
const formatLocalDate = (date) => {
  return new Date(date).toLocaleDateString('en-CA');
};

// ✅ CORRECT: Get today in user's local timezone
const today = formatLocalDate(new Date());  // e.g., "2026-01-30"

// ✅ CORRECT: Get yesterday in user's local timezone
const yesterdayDate = new Date();
yesterdayDate.setDate(yesterdayDate.getDate() - 1);
const yesterday = formatLocalDate(yesterdayDate);

// ✅ CORRECT: Convert database timestamp to user's local date
const reviewDate = formatLocalDate(review.created_at);

// ❌ WRONG: UTC conversion
const wrong = new Date().toISOString().split('T')[0];
// Problem: May return different date than user's calendar date

// ❌ WRONG: Hardcoded timezone
const alsoWrong = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
// Problem: Only works for users in India

Why 'en-CA' locale?

Canadian English formats dates as YYYY-MM-DD (ISO format)
This format allows correct string comparison ("2026-01-30" > "2026-01-29")
Works for sorting and database queries
NOT about Canada - just about the date format!

**Database Operations (StudyMode.jsx):**
- **Source of Truth:** Student progress stored EXCLUSIVELY in `reviews` table
- **Explicit Logic:** Use explicit `SELECT → IF exists UPDATE → ELSE INSERT` flow
- **Reason:** Do not use single-command atomic UPSERTs to ensure code readability and stability

**Dashboard & Review Logic:**
- **Definition of "Due":** A card is due ONLY if it exists in `reviews` table AND `next_review_date <= Today` (Local)
- **Separation:** "New Cards" (never studied) are excluded from Dashboard count
- **Access:** New cards accessible via Library (ReviewFlashcards.jsx), not Review Session

#### Files Modified
- `src/components/flashcards/StudyMode.jsx` - Fixed date math + explicit DB logic
- `src/pages/dashboard/Study/ReviewSession.jsx` - Query reviews table + local date comparison
- `src/pages/Dashboard.jsx` - Count reviews table + local date comparison

#### Impact
- ✅ Cards no longer reappear immediately after review
- ✅ Timezone-independent behavior (works globally)
- ✅ Accurate "Reviews Due" count on Dashboard
- ✅ Student progress saves reliably regardless of card ownership

## User Timezone Storage (2026-01-30)

### Overview
User's IANA timezone is stored in `profiles.timezone` and auto-synced from browser on every login.

### Database Changes
- **New Column:** `profiles.timezone` (TEXT, default 'Asia/Kolkata')
- **Updated Functions:**
  - `log_review_activity()` - Uses stored timezone for local date/hour
  - `check_night_owl_badge()` - Checks 11 PM - 4 AM in user's local time
  - `get_user_streak()` - Calculates streak based on user's local days
  - `get_anonymous_class_stats()` - Uses per-user timezone for "studied today"

### Frontend Changes
- **AuthContext.jsx:** New `updateUserTimezone()` helper
  - Runs on session init, `SIGNED_IN` event, and manual sign in
  - Detects browser timezone via `Intl.DateTimeFormat().resolvedOptions().timeZone`
  - Only updates if timezone changed (optimization)
  - Sets timezone on new user signup

### How It Works

User logs in → Browser timezone detected → Compared with profiles.timezone
→ If different, UPDATE profiles SET timezone = 'America/New_York'
→ All DB functions now use this for local time calculations


### Benefits
- Night Owl badge works correctly for users worldwide
- Streak calculations respect user's local midnight
- "Studied today" is accurate regardless of server timezone
- Timezone auto-updates if user travels

---
**Current state**

**Current state**

Recall is in production with 27 registered students and impressive early metrics: 542+ total reviews from top students. The platform features a complete tech stack (React, Supabase, Vercel) with a four-tier role system (super_admin, admin, professor, student), three-tier content visibility (Private/Friends/Public), and comprehensive spaced repetition using SuperMemo-2 methodology.

**DASHBOARD REDESIGN (2026-01-24):** Implemented Phase 1C with anonymous class statistics. New `AnonymousStats` component shows "You vs Class" comparison using Tailwind progress bars, class milestones (students studied today, 7-day streaks), with privacy-first design (min 5 users for averages, course-level filtering). SQL function `get_anonymous_class_stats()` uses SECURITY DEFINER to aggregate across users while respecting privacy. Quick Actions expanded to 4 buttons for better UX.

Recent development has focused on fixing the spaced repetition architecture, implementing proper review progress persistence, and adding subject-based review grouping. The platform successfully handles review data isolation per user, preventing schedule conflicts between students reviewing the same cards.

## Tech Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| **Frontend** | React 18 + Vite | With TailwindCSS + shadcn/ui |
| **Backend** | Supabase | PostgreSQL + Auth + Storage + RLS |
| **Hosting** | Vercel | Free tier, auto-deploy from GitHub |
| **OCR** | Tesseract.js | Client-side, free |
| **Email** | Resend | Free tier (3K/month) |
| **Analytics** | PostHog | Free tier |
| **Error Tracking** | Sentry | Free tier |

---

## Database Schema (High-Level)

### Core Tables

```
profiles
├── id (UUID, PK, references auth.users)
├── email (TEXT)
├── full_name (TEXT)
├── role (TEXT: student/professor/admin/super_admin)
├── course_level (TEXT: CA Foundation/CA Intermediate/CA Final/etc.)
├── institution (TEXT)
└── created_at (TIMESTAMP)

notes
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── title (TEXT)
├── content_type (TEXT: Text/Table/Math/Diagram)
├── image_url (TEXT)
├── extracted_text (TEXT, nullable)
├── target_course (TEXT, NOT NULL)
├── visibility (TEXT: private/friends/public)
├── is_verified (BOOLEAN)
├── tags (TEXT[])
└── created_at (TIMESTAMP)

flashcards
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── creator_id (UUID, FK → profiles.id) -- WHO uploaded
├── content_creator_id (UUID, FK → content_creators.id) -- WHO gets revenue
├── front_text (TEXT)
├── back_text (TEXT)
├── target_course (TEXT, NOT NULL)
├── visibility (TEXT: private/friends/public)
├── batch_id (UUID) -- Groups bulk uploads
├── batch_description (TEXT)
├── is_verified (BOOLEAN)
├── difficulty (TEXT: easy/medium/hard)
├── next_review (TIMESTAMP WITH TIME ZONE, NOT NULL)
├── interval (INTEGER, DEFAULT 1)
├── ease_factor (NUMERIC, DEFAULT 2.5)
├── repetitions (INTEGER, DEFAULT 0)
└── created_at (TIMESTAMP)

reviews
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── flashcard_id (UUID, FK → flashcards.id)
├── quality (INTEGER: 1=Hard, 3=Medium, 5=Easy)
└── created_at (TIMESTAMP)

friendships
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── friend_id (UUID, FK → profiles.id)
├── status (TEXT: pending/accepted/rejected)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
└── UNIQUE(user_id, friend_id)

content_creators
├── id (UUID, PK)
├── name (TEXT, NOT NULL)
├── type (TEXT: individual/organization)
├── email (TEXT, UNIQUE)
├── revenue_share_percentage (DECIMAL, DEFAULT 30.0)
└── created_at (TIMESTAMP)

admin_audit_log
├── id (UUID, PK)
├── action (TEXT, NOT NULL)
├── admin_id (UUID, FK → profiles.id)
├── target_user_id (UUID, FK → profiles.id)
├── details (JSONB)
├── ip_address (TEXT)
└── created_at (TIMESTAMP)
```

---

## Four-Tier Role System

```
SUPER_ADMIN (Founder only - 1 person)
├── All permissions
├── Create/delete admins
├── Financial data access
├── Database/system config
└── 12-hour session timeout

ADMIN (Trusted team members)
├── User management (suspend/activate)
├── Content moderation
├── Promote to professor
├── Analytics access
└── 24-hour session timeout

PROFESSOR (Faculty contributors)
├── Bulk upload (CSV)
├── Verified content badges
├── Profile page
└── 7-day session timeout

STUDENT (Regular users)
├── Create notes/flashcards
├── Review content
├── Share publicly
└── 7-day session timeout
```

---

## Four-Tier Visibility System

| Level | Who Can See |
|-------|-------------|
| **Private** | Only creator |
| **Study Groups** | Creator + active group members (stored as 'private', accessed via content_group_shares) |
| **Friends** | Creator + accepted friends |
| **Public** | Everyone |

Applied to: Notes, Flashcards

---

## Spaced Repetition Algorithm (SuperMemo-2)

```javascript
// Intervals based on quality score
Hard (quality=1)   → next_review = NOW + 1 day
Medium (quality=3) → next_review = NOW + 3 days
Easy (quality=5)   → next_review = NOW + 7 days

// Scheduling uses UTC midnight
next_review.setUTCHours(0, 0, 0, 0)
```

**Key Fields on flashcards table:**
- `next_review`: When card is due (TIMESTAMP WITH TIME ZONE, NOT NULL)
- `interval`: Days until next review (INTEGER)
- `ease_factor`: Difficulty multiplier (NUMERIC, DEFAULT 2.5)
- `repetitions`: Times reviewed (INTEGER)

---

## Row Level Security (RLS) Policies

### flashcards table (RLS ENABLED)
```sql
-- Users can view their own flashcards
CREATE POLICY "Users can view own flashcards" ON flashcards
FOR SELECT USING (user_id = auth.uid());

-- Users can view public flashcards
CREATE POLICY "Users can view public flashcards" ON flashcards
FOR SELECT USING (visibility = 'public');

-- Users can view friends' flashcards (visibility='friends')
CREATE POLICY "Users can view friends flashcards" ON flashcards
FOR SELECT USING (
  visibility = 'friends' AND
  EXISTS (
    SELECT 1 FROM friendships
    WHERE status = 'accepted'
    AND ((user_id = auth.uid() AND friend_id = flashcards.user_id)
         OR (friend_id = auth.uid() AND user_id = flashcards.user_id))
  )
);
```

### friendships table (RLS ENABLED)
```sql
-- Users can view their own friendships
CREATE POLICY "Users can view own friendships" ON friendships
FOR SELECT USING (user_id = auth.uid() OR friend_id = auth.uid());
```

---

## Project Structure

```
recall-app
├── .env.local
├── .gitignore
├── components.json
├── dist
│   ├── android-chrome-192x192.png
│   ├── android-chrome-512x512.png
│   ├── apple-touch-icon.png
│   ├── assets
│   │   ├── index-DHW_aIga.css
│   │   └── index-FtNB4Wrq.js
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── favicon.ico
│   ├── index.html
│   ├── site.webmanifest
│   └── vite.svg
├── docs
│   ├── active
│   │   ├── context.md
│   │   ├── git-guide.md
│   │   └── now.md
│   ├── archive
│   │   ├── APPROVED_DECISIONS.md
│   │   ├── CONTEXT_FOR_CLAUDE.md
│   │   └── FEATURE_PRIORITY.md
│   ├── database
│   │   └── Reviews_Table_Usage.md
│   ├── design
│   │   ├── ACHIEVEMENT_BADGES.md
│   │   ├── SPACED_REPETITION_PHILOSOPHY.md
│   │   └── UPVOTE_SYSTEM.md
│   ├── reference
│   │   ├── DATABASE_SCHEMA.md
│   │   └── FILE_STRUCTURE.md
│   └── tracking
│       ├── bugs.md
│       ├── changelog.md
│       └── ideas.md
├── eslint.config.js
├── index.html
├── jsconfig.json
├── package-lock.json
├── package.json
├── postcss.config.js
├── public
│   ├── android-chrome-192x192.png
│   ├── android-chrome-512x512.png
│   ├── apple-touch-icon.png
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── favicon.ico
│   ├── site.webmanifest
│   └── vite.svg
├── README.md
├── recall-favicon.svg
├── src
│   ├── App.css
│   ├── App.jsx
│   ├── assets
│   │   └── react.svg
│   ├── components
│   │   ├── admin
│   │   │   ├── AdminDashboard.jsx
│   │   │   └── SuperAdminDashboard.jsx
│   │   ├── badges
│   │   │   ├── BadgeCard.jsx
│   │   │   ├── BadgeIcon.jsx
│   │   │   └── BadgeToast.jsx
│   │   ├── dashboard
│   │   │   ├── ActivityFeed.jsx
│   │   │   └── AnonymousStats.jsx
│   │   ├── flashcards
│   │   │   ├── FlashcardCard.jsx
│   │   │   ├── FlashcardCreate.jsx
│   │   │   ├── MyFlashcards.jsx
│   │   │   └── StudyMode.jsx
│   │   ├── layout
│   │   │   ├── ActivityDropdown.jsx
│   │   │   ├── FriendsDropdown.jsx
│   │   │   ├── NavDesktop.jsx
│   │   │   ├── Navigation.jsx
│   │   │   ├── NavMobile.jsx
│   │   │   ├── PageContainer.jsx
│   │   │   └── ProfileDropdown.jsx
│   │   ├── notes
│   │   │   ├── index.jsx
│   │   │   ├── NoteDetail.jsx
│   │   │   ├── NoteEdit.jsx
│   │   │   └── NoteUpload.jsx
│   │   ├── professor
│   │   │   └── ProfessorTools.jsx
│   │   └── ui
│   │       ├── alert.jsx
│   │       ├── button.jsx
│   │       ├── card.jsx
│   │       ├── command.jsx
│   │       ├── dialog.jsx
│   │       ├── dropdown-menu.jsx
│   │       ├── input.jsx
│   │       ├── label.jsx
│   │       ├── popover.jsx
│   │       ├── progress.jsx
│   │       ├── SearchableSelect.jsx
│   │       ├── select.jsx
│   │       ├── sheet.jsx
│   │       ├── switch.jsx
│   │       ├── tabs.jsx
│   │       ├── textarea.jsx
│   │       ├── toast.jsx
│   │       ├── toaster.jsx
│   │       └── UpvoteButton.jsx
│   ├── contexts
│   │   └── AuthContext.jsx
│   ├── data
│   ├── hooks
│   │   ├── use-toast.js
│   │   ├── useActivityFeed.js
│   │   ├── useBadges.js
│   │   ├── useFriendRequestCount.js
│   │   ├── useNotifications.js
│   │   ├── useOCR.js
│   │   └── useRole.js
│   ├── index.css
│   ├── lib
│   │   ├── supabase.js
│   │   └── utils.js
│   ├── main.jsx
│   ├── pages
│   │   ├── auth
│   │   │   ├── ForgotPassword.jsx
│   │   │   ├── Login.jsx
│   │   │   ├── ResetPassword.jsx
│   │   │   └── Signup.jsx
│   │   ├── dashboard
│   │   │   ├── Content
│   │   │   │   ├── BrowseNotes.jsx
│   │   │   │   ├── MyContributions.jsx
│   │   │   │   └── MyNotes.jsx
│   │   │   ├── Friends
│   │   │   │   ├── FindFriends.jsx
│   │   │   │   ├── FriendRequests.jsx
│   │   │   │   └── MyFriends.jsx
│   │   │   ├── Profile
│   │   │   │   └── MyAchievements.jsx
│   │   │   └── Study
│   │   │       ├── Progress.jsx
│   │   │       ├── ReviewBySubject.jsx
│   │   │       ├── ReviewFlashcards.jsx
│   │   │       └── ReviewSession.jsx
│   │   ├── Dashboard.jsx
│   │   ├── Home.jsx
│   │   ├── PrivacyPolicy.jsx
│   │   └── TermsOfService.jsx
│   ├── store
│   └── utils
├── tailwind.config.js
├── vercel.json
└── vite.config.js


---

## Critical Rules & Patterns

### 1. Two-Tier Content Model
- **User's Enrollment** (`profiles.course_level`): What they're studying
- **Content's Target** (`notes.target_course`, `flashcards.target_course`): Who it's for
- These are INDEPENDENT - professors can create content for any course

### 2. Batch Tracking for Bulk Uploads
- All cards from one CSV get same `batch_id`
- Manual cards get unique `batch_id`
- Groups survive visibility changes

### 3. Attribution System
- `creator_id`: WHO uploaded (for UI display)
- `content_creator_id`: WHO gets revenue (for Vivitsu partnership)

### 4. UTC Midnight Scheduling
- All `next_review` times set to midnight UTC
- Use `setHours(0,0,0,0)` not `setHours()`

### 5. eslint-disable Pattern for useEffect
```javascript
useEffect(() => {
  // fetch logic
}, [dependency]);
// eslint-disable-next-line react-hooks/exhaustive-deps

### 6. Always use @/ for imports.
```

### 6. Query Pattern for User Attribution
```javascript
// Fetch separately, merge in JS (more reliable than PostgREST joins)
const notes = await fetchNotes();
const profiles = await fetchProfiles(userIds);
const merged = notes.map(n => ({...n, user: profiles.find(p => p.id === n.user_id)}));
```

### 7. Data Migration Architecture Rules (CRITICAL — learned Feb 2026)

These rules exist because a migration of 167 flashcard images (110 MB base64 → Storage) caused repeated timeouts and billing quota exhaustion before succeeding. Root cause: nobody quantified data volume before writing the migration query.

#### Pre-Migration Checklist (run BEFORE writing any migration)

**Step 1: Measure the data budget**
```sql
-- [DIAGNOSTIC] Data size before migration
-- Run this FIRST. Know your numbers before writing the migration.
SELECT
  COUNT(*) AS row_count,
  pg_size_pretty(SUM(pg_column_size(the_column))) AS total_column_size,
  pg_size_pretty(AVG(pg_column_size(the_column))::BIGINT) AS avg_per_row
FROM your_table
WHERE the_column IS NOT NULL;
```
If `total_column_size > 10 MB`, treat the migration as high-risk — plan for one-row-at-a-time processing.

**Step 2: Identify TOAST columns**
Any TEXT or JSONB column where individual values exceed ~2 KB is stored in PostgreSQL TOAST (The Oversized-Attribute Storage Technique). TOAST values are:
- Stored compressed in a separate internal table
- **NOT** loaded unless the column is explicitly selected
- **Fully decompressed** when used in a LIKE / regex pattern match — even for non-matching rows

| Filter type | TOAST behaviour | Safe for large data? |
|---|---|---|
| `IS NOT NULL` | Reads null-flag only (heap tuple) — TOAST never touched | ✅ Yes |
| `= 'exact_value'` | Decompresses only matching rows | ✅ Yes (if few matches) |
| `LIKE 'data:%'` | Decompresses **every row** to scan content | ❌ No |
| `SELECT *` | Decompresses all TOAST columns for every selected row | ❌ No for bulk |

**Step 3: Plan a two-phase fetch — never one big query**
```
Phase 1: SELECT id WHERE column IS NOT NULL  ← returns UUID list only, zero TOAST loading
Phase 2: For each id → fetch one row at a time  ← one TOAST decompression per round-trip
```
Never use `SELECT *` or `LIKE` patterns on TOAST columns in bulk. Always fetch IDs first, then rows individually.

#### Migration Component Pattern (React)
- ❌ **Never** run migrations from the browser console (Vite apps don't expose `supabase` as a global)
- ✅ **Always** create a temporary `src/pages/admin/MigrateXxx.jsx` React component with `@/lib/supabase` import
- ✅ Show a progress counter + per-item log (color-coded ✅/❌) so you can monitor without guessing
- ✅ Make it safe to re-run (`upsert: true` on uploads, skip already-migrated rows)
- ✅ Delete the component and its route from `App.jsx` immediately after migration is confirmed complete

#### Supabase Free Plan Limits to Watch
| Resource | Limit | Impact when exceeded |
|---|---|---|
| Database size | 500 MB | Writes blocked |
| Egress (DB + Storage) | 5 GB / month | DB connections throttled |
| Disk IO Budget | Separate quota | Queries slow/fail |

If you see "EXCEEDING USAGE LIMITS" banner in Supabase Dashboard → billing cycle reset date is your unblock date. Do not retry large queries until the cycle resets.

---

## Environment Variables (Vercel)

```
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxxxxx
```

---

## Key Contacts

- **Developer:** Anand (CA Faculty, Zero coding experience)
- **Support:** recall@moreclassescommerce.com
- **Location:** Pune, Maharashtra, India