# Changelog

---
## [2026-02-07] Help & Guide Documentation Page

### Added
- **`src/data/helpContent.js`** — Structured help content data file with 6 tabs (Getting Started, Content, Study System, Social, Study Groups, More), 24 collapsible sections, and 10 FAQ items. Data-driven architecture separates content from rendering.
- **`src/pages/dashboard/Help.jsx`** — Full Help page component with tabbed navigation, cross-tab search, collapsible Card sections, back-to-top button, and URL deep linking via `useSearchParams`.
- **`scrollbar-hide` CSS utility** — Added to `src/index.css` for hiding scrollbars on the tab bar (mobile horizontal scroll).

### Changed
- **`src/components/layout/ProfileDropdown.jsx`** — Added "Help & Guide" menu item with HelpCircle icon above the Sign Out separator.
- **`src/components/layout/NavMobile.jsx`** — Added "Help & Guide" button after My Achievements in the mobile navigation sheet.
- **`src/App.jsx`** — Added import and protected route for `/dashboard/help`.

### Files Changed
- `src/data/helpContent.js` (NEW)
- `src/pages/dashboard/Help.jsx` (NEW)
- `src/App.jsx`
- `src/components/layout/ProfileDropdown.jsx`
- `src/components/layout/NavMobile.jsx`
- `src/index.css`

---
## [2026-02-07] Allow All Members to Share Content in Groups

### Changed
- **`share_content_with_groups()`** — Changed admin-only check to active member check. Any group member can now share their own content.
- **RLS INSERT policy on `content_group_shares`** — Renamed `cgs_insert_admin` → `cgs_insert_member`. Any active group member can insert shares (must be `shared_by = auth.uid()`).
- **RLS DELETE policy on `content_group_shares`** — Renamed `cgs_delete_admin` → `cgs_delete_own_or_admin`. Admins can delete any share; regular members can only delete their own (`shared_by = auth.uid()`).
- **GroupDetail.jsx** — "Share Content" button visible to all members (previously admin-only). Delete icons on shared content: admin sees all, member sees only their own. "Invite Members" remains admin-only.

### Files Changed
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `docs/database/study-groups/27_FIX_allow_all_members_to_share_content.sql` (NEW)

---
## [2026-02-06] Group Invitation Flow + Notification Backend

### Added
- **`notifications` table** — Full notification system backend (id, user_id, type, title, message, is_read, metadata JSONB, created_at). RLS policies for own-row access. Indexes including composite unread index.
- **5 Notification RPCs** — `get_unread_notification_count`, `get_recent_notifications`, `mark_notifications_read`, `mark_single_notification_read`, `delete_notification`. All SECURITY DEFINER with auth.uid() ownership checks.
- **`cleanup_old_notifications()`** — Utility function for cron-based retention (deletes notifications > 60 days old).
- **`status` column on `study_group_members`** — `TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('invited', 'active'))`. Zero migration risk — existing rows default to 'active'.
- **`invited_by` column on `study_group_members`** — `UUID REFERENCES profiles(id) ON DELETE SET NULL`. Tracks who sent the invitation.
- **`accept_group_invite(p_membership_id)`** RPC — Verifies invitation belongs to caller, updates status → 'active', auto-marks related notification as read.
- **`decline_group_invite(p_membership_id)`** RPC — Marks notification as read, then hard DELETEs membership row.
- **`get_pending_group_invites()`** RPC — Returns pending invitations for MyGroups page with group info, inviter name, member count.
- **Pending Invitations section on MyGroups.jsx** — Amber-bordered cards above groups grid with Accept/Decline buttons.
- **Pending Invitations in GroupDetail.jsx members panel** — Admin-only section showing invited users with Cancel button.
- **Inline Accept/Decline in ActivityDropdown** — Group invite notifications render with action buttons (following FriendsDropdown pattern).

### Changed
- **`invite_to_group()`** — Now inserts with `status = 'invited'` instead of `'active'`. Creates notification with `type = 'group_invite'` and JSONB metadata.
- **`get_user_groups()`** — Now filters `AND sgm.status = 'active'` so pending invites don't appear as groups.
- **`get_group_detail()`** — Members query filters `status = 'active'`. Returns new `pending_invitations` key for admin view.
- **`get_browsable_notes()`** — Added `AND sgm.status = 'active'` in group-shared EXISTS subquery (security: invited users can't see content).
- **`get_browsable_decks()`** — Same security filter as notes.
- **`leave_group()`** — Member count/admin count queries now filter `AND status = 'active'`. Only active members can leave.
- **GroupDetail.jsx** — Button text "Add Members" → "Invite Members", toast "Member added!" → "Invitation sent!", search excludes pending invitations.
- **ActivityDropdown.jsx** — Added group_invite notification type with Users icon (indigo), inline Accept/Decline buttons.
- **Navigation.jsx** — Passes `deleteNotification` and `refetchNotifications` to ActivityDropdown via NavDesktop/NavMobile.

### Files Changed
- `src/components/layout/ActivityDropdown.jsx` (REWRITTEN)
- `src/components/layout/Navigation.jsx`
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`
- `src/pages/dashboard/Groups/MyGroups.jsx`
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `docs/database/study-groups/13_SCHEMA_notifications_table.sql` (NEW)
- `docs/database/study-groups/14_FUNCTIONS_notification_rpcs.sql` (NEW)
- `docs/database/study-groups/15_SCHEMA_add_invitation_status.sql` (NEW)
- `docs/database/study-groups/16_FUNCTION_invite_to_group_v2.sql` (NEW)
- `docs/database/study-groups/17_FUNCTION_accept_group_invite.sql` (NEW)
- `docs/database/study-groups/18_FUNCTION_decline_group_invite.sql` (NEW)
- `docs/database/study-groups/19_FUNCTION_get_pending_group_invites.sql` (NEW)
- `docs/database/study-groups/20_FUNCTION_get_user_groups_v2.sql` (NEW)
- `docs/database/study-groups/21_FUNCTION_get_group_detail_v2.sql` (NEW)
- `docs/database/study-groups/22_FUNCTION_get_browsable_notes_v2.sql` (NEW)
- `docs/database/study-groups/23_FUNCTION_get_browsable_decks_v2.sql` (NEW)
- `docs/database/study-groups/24_FUNCTION_leave_group_v2.sql` (NEW)

### Manual Step Required
- Enable Supabase Realtime on `notifications` table: Dashboard → Database → Replication → Enable for `notifications`

---
## [2026-02-06] Study Groups - RLS Fix + Server-Side Content Fetching

### Fixed
- **Infinite Recursion Bug**: `sgm_select_member` RLS policy on `study_group_members` self-referenced its own table, causing PostgreSQL infinite recursion. Replaced with `sgm_select_own` using simple `USING (user_id = auth.uid())` — no subquery, no recursion.
- **"Failed to load group" on GroupDetail**: The direct `study_groups` SELECT went through RLS which depended on `study_group_members` RLS — fragile chain. Replaced 3-query pattern (group SELECT + get_group_members RPC + get_group_shared_content RPC) with single `get_group_detail(p_group_id)` SECURITY DEFINER RPC that returns group info, members, and shared content in one call. Zero RLS dependency.

### Changed
- **GroupDetail.jsx** - Replaced 3 separate DB calls with single `get_group_detail` RPC call. Eliminates RLS chain failure.
- **BrowseNotes.jsx** - Replaced 3-query client-side merge (visibility query + group shares + missing items → JS array merge) with single `get_browsable_notes()` RPC call. Fixes pagination compatibility and reduces DB round-trips from 3 to 1.
- **ReviewFlashcards.jsx** - Same refactor: replaced 3-query client-side merge with single `get_browsable_decks()` RPC call.

### Security & Privacy
- **Privacy**: `get_group_detail` and `get_group_members` do NOT return member emails. Only safe public fields: user_id, full_name, role, joined_at.
- **Security**: All group RPCs use strict `IF NOT EXISTS (...) THEN RAISE EXCEPTION 'Access denied'` pattern.
- **Null safety**: All arrays in `get_group_detail` use double COALESCE — both in the subquery and in the final `json_build_object` — ensuring `[]` never `null`.

### Added
- **`get_group_detail(p_group_id)`** RPC - Returns group info + members + shared content in one call. SECURITY DEFINER with membership check. Replaces 3 separate queries. No email in member data.
- **`get_group_members(p_group_id)`** RPC - Returns all members of a group with profiles. SECURITY DEFINER with explicit membership check. No email in output.
- **`get_browsable_notes()`** RPC - Single query returning all notes visible to the user (own + public + friends + group-shared) with profile/subject/topic JOINs. Server-side visibility enforcement.
- **`get_browsable_decks()`** RPC - Same for flashcard decks. Single query with full visibility logic.

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `docs/database/study-groups/02_RLS_study_groups_policies.sql` (FIXED)
- `docs/database/study-groups/09_FUNCTION_get_group_members.sql` (NEW)
- `docs/database/study-groups/10_FUNCTION_get_browsable_notes.sql` (NEW)
- `docs/database/study-groups/11_FUNCTION_get_browsable_decks.sql` (NEW)
- `docs/database/study-groups/12_FUNCTION_get_group_detail.sql` (NEW)

---
## [2026-02-06] Study Groups (Phase 1: Read-Only)

### Added
- **Database Tables** (3 new):
  - `study_groups` - Group metadata (name, description, creator)
  - `study_group_members` - Membership with roles (admin/member), UNIQUE(group_id, user_id)
  - `content_group_shares` - Content-to-group sharing links (note/flashcard_deck)
  - All group_id foreign keys use `ON DELETE CASCADE` (deleting group removes shares, NOT original content)

- **Database RLS Policies** (8 new):
  - `sg_select_member`, `sg_insert`, `sg_update_creator`, `sg_delete_creator` on study_groups
  - `sgm_select_member`, `sgm_insert_admin`, `sgm_delete` on study_group_members
  - `cgs_select_member`, `cgs_insert_admin`, `cgs_delete_admin` on content_group_shares

- **Database Functions** (6 new SECURITY DEFINER RPCs):
  - `create_study_group(p_name, p_description)` - Creates group + adds creator as admin
  - `invite_to_group(p_group_id, p_user_id)` - Admin adds member
  - `leave_group(p_group_id)` - Member leaves (promotes oldest member if last admin)
  - `share_content_with_groups(p_content_type, p_content_id, p_group_ids)` - Multi-group share
  - `get_user_groups()` - Returns user's groups with member count and role
  - `get_group_shared_content(p_group_id)` - Returns shared notes and decks for a group

- **MyGroups.jsx** - List user's study groups with create/leave/delete actions
- **CreateGroup.jsx** - Form to create a new study group
- **GroupDetail.jsx** - Group page with members panel, shared content, invite members, share content dialogs
- **Navigation** - Added "Groups" link in desktop nav and "Study Groups" section in mobile menu

### Changed
- **App.jsx** - Added 3 routes: `/dashboard/groups`, `/dashboard/groups/new`, `/dashboard/groups/:groupId`
- **NavDesktop.jsx** - Added Groups nav link with active state
- **NavMobile.jsx** - Added Groups section in mobile sheet menu
- **NoteUpload.jsx** - Added "Study Groups" visibility option with group multi-select checkboxes, shares note with groups after upload
- **FlashcardCreate.jsx** - Added "Study Groups" visibility option with group multi-select checkboxes, shares deck with groups after creation
- **BrowseNotes.jsx** - Fetches and merges group-shared notes alongside public/friends notes
- **ReviewFlashcards.jsx** - Fetches and merges group-shared decks alongside public/friends decks

### Files Changed
- `src/App.jsx`
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`
- `src/components/notes/NoteUpload.jsx`
- `src/components/flashcards/FlashcardCreate.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Groups/MyGroups.jsx` (NEW)
- `src/pages/dashboard/Groups/CreateGroup.jsx` (NEW)
- `src/pages/dashboard/Groups/GroupDetail.jsx` (NEW)
- `docs/database/study-groups/` (8 SQL files - NEW)

---
## [2026-02-06] Card Suspension System (Skip, Suspend, Reset)

### Added
- **Database Migration**: `status` (active/suspended) and `skip_until` (DATE) columns on reviews table
- **Database Indexes**: `idx_reviews_status`, `idx_reviews_skip_until`, `idx_reviews_user_status_due` (partial composite)
- **Database Functions** (6 new SECURITY DEFINER RPCs):
  - `skip_card(p_user_id, p_flashcard_id)` - Hides card for 24 hours (timezone-aware)
  - `suspend_card(p_user_id, p_flashcard_id)` - Suspends card indefinitely
  - `suspend_topic_cards(p_user_id, p_topic_id)` - Bulk suspends all cards in a topic
  - `unsuspend_card(p_user_id, p_flashcard_id)` - Reactivates suspended card (due today)
  - `reset_card(p_user_id, p_flashcard_id)` - Deletes review record (card becomes New)
  - `get_suspended_cards(p_user_id)` - Returns suspended cards with details for Progress page

- **StudyMode.jsx** - Card management during study:
  - [Skip 24hr] button on question side (no confirmation needed)
  - [More] dropdown menu with Suspend Card, Suspend Topic, Reset Card
  - Skip/More actions also available on answer side
  - Confirmation dialogs for all destructive actions (suspend/reset)
  - Topic suspension removes matching cards from current session

- **Progress.jsx** - Suspended Cards section:
  - Collapsible "Suspended Cards" section with amber styling
  - Cards grouped by subject with Unsuspend button per card
  - Confirmation dialog for unsuspend with card preview

### Changed
- **ReviewSession.jsx** - Filters out suspended (`status='suspended'`) and skipped (`skip_until > today`) cards from due queue
- **ReviewBySubject.jsx** - Same suspension/skip filtering
- **Dashboard.jsx** - Due count excludes suspended/skipped cards; streak only counts actual reviews (quality > 0)
- **Progress.jsx** - Stats queries filter by `status='active'`; streak calculation excludes suspended reviews

### Files Changed
- `src/components/flashcards/StudyMode.jsx` (rewritten with skip/suspend/reset)
- `src/pages/dashboard/Study/Progress.jsx` (rewritten with suspended cards section)
- `src/pages/dashboard/Study/ReviewSession.jsx` (due cards query updated)
- `src/pages/dashboard/Study/ReviewBySubject.jsx` (due cards query updated)
- `src/pages/Dashboard.jsx` (stats filtering updated)

---
## [2026-02-06] Author Profile Page & Clickable Names

### Added
- **Database RPC Functions** for author profile (SECURITY DEFINER):
  - `get_author_profile(p_author_id, p_viewer_id)` - Returns profile + badges + friendship in 1 call
  - `get_author_content_summary(p_author_id, p_viewer_id)` - Returns content grouped by course/subject with server-side visibility

- **AuthorProfile.jsx** - New page at `/dashboard/profile/:userId`:
  - Uses 2 RPC calls instead of 6 direct queries (performance + security)
  - Displays author name, role badge, institution, course level
  - Shows public badges (own profile shows all badges with hidden indicator)
  - Content grouped by Course → Subject with note/flashcard counts
  - "Also Creates Content For" section listing other courses (upsell hook)
  - Add Friend button with full friendship lifecycle (pending/accepted/rejected)
  - "Preview as Visitor" toggle on own profile
  - Back button with history-aware navigation

- **Clickable Author Names** - All author/user names now link to profile page:
  - `BrowseNotes.jsx` - Note card footer author name
  - `ReviewFlashcards.jsx` - Deck card author name (moved outside study button)
  - `NoteDetail.jsx` - Author badge in note header
  - `FindFriends.jsx` - User card name
  - `MyFriends.jsx` - Friend card name
  - `MyContributions.jsx` - Upvoter names (summary list, note upvoters, deck upvoters)

### Changed
- `App.jsx` - Added AuthorProfile import and `/dashboard/profile/:userId` route
- `BrowseNotes.jsx` - Added `Link` import, wrapped author name in `<Link>`
- `ReviewFlashcards.jsx` - Added `Link` import, extracted author name outside study button as separate clickable `<Link>`
- `NoteDetail.jsx` - Added `Link` import, wrapped author badge `<div>` with `<Link>`
- `FindFriends.jsx` - Added `Link` import, wrapped user name in `<Link>`
- `MyFriends.jsx` - Added `Link` import, wrapped friend name in `<Link>`
- `MyContributions.jsx` - Added `Link` import, replaced upvoter `<span>` with `<Link>` in 3 locations

### Files Changed
- `src/pages/dashboard/Profile/AuthorProfile.jsx` (NEW)
- `src/App.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/components/notes/NoteDetail.jsx`
- `src/pages/dashboard/Friends/FindFriends.jsx`
- `src/pages/dashboard/Friends/MyFriends.jsx`
- `src/pages/dashboard/Content/MyContributions.jsx`

---
## [2026-02-06] Grid/Grouped View Toggle & Collapsible Sections

### Added
- **MyNotes.jsx - Grid/Grouped View Toggle:**
  - `[Grid] [Grouped]` toggle buttons in header area (matches MyFlashcards pattern)
  - Grouped View organizes notes by Subject → Topic hierarchy
  - Notes without subject/topic fall into "Uncategorized" section (sorted last)
  - View preference persisted in localStorage (`myNotes_viewMode` key)
  - Extracted `renderNoteCard` helper for shared card rendering in both views
  - `useMemo` for efficient grouped notes computation

- **BrowseNotes.jsx - Collapsible Sections:**
  - Subject headers now collapsible with ChevronDown/ChevronRight icons
  - Topic sub-headers now collapsible with note count display
  - Gradient background on subject headers (blue-to-indigo)
  - `collapsedGroups` state tracks open/closed sections independently

- **ReviewFlashcards.jsx - Collapsible Sections:**
  - Subject headers now collapsible with ChevronDown/ChevronRight icons
  - Gradient background on subject headers (blue-to-indigo)
  - "Study All" button preserved with `e.stopPropagation()` to avoid triggering collapse
  - `collapsedGroups` state tracks open/closed sections independently

### Changed
- `MyNotes.jsx` - Added `useMemo`, `ChevronDown`, `ChevronRight` imports
- `BrowseNotes.jsx` - Added `ChevronDown`, `ChevronRight` imports, collapsible state
- `ReviewFlashcards.jsx` - Added `ChevronDown` import, collapsible state

### Technical Details
- No database changes required (uses existing `subject_id`/`topic_id` joins)
- No new files created (only modified 3 existing files)
- Grouped view sorts alphabetically with "Uncategorized" always last
- Both subject and topic levels independently collapsible

### Files Changed
- `src/pages/dashboard/Content/MyNotes.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`

---
## [2026-02-05] Author Search with Server-Side Filtering

### Added
- **Database RPC Functions** for server-side author filtering:
  - `get_filtered_authors_for_notes(p_course, p_subject_id, p_role)` - Returns authors with public notes
  - `get_filtered_authors_for_flashcards(p_course, p_subject_id, p_role)` - Returns authors with public flashcard decks
  
- **Split Author Filter into Role + Author:**
  - Role dropdown: All Roles / Professor / Student
  - Author dropdown: Dynamically populated from server based on filters
  
- **Dependent Author Filtering:**
  - Author dropdown updates when Course, Subject, or Role changes
  - Only shows authors who have PUBLIC content matching current filters
  - Loading state while fetching authors from server

### Changed
- `BrowseNotes.jsx` - 5-column filter grid (Course, Subject, Topic, Role, Author)
- `ReviewFlashcards.jsx` - 5-column filter grid (Course, Subject, Topic, Role, Author)

### Technical Details
- Uses `supabase.rpc()` for server-side author queries
- Subject name-to-ID mapping for RPC calls (subjects stored by name in UI)
- Author filter auto-resets when parent filter makes current selection invalid
- Added `useCallback` for memoized fetch function

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- Database: 2 new RPC functions

---
## [2026-02-05] Back Button & Dependent Dropdown Filters

### Fixed
- **Back Button Navigation** - All pages now use `navigate(-1)` with fallback to dashboard
  - `NoteDetail.jsx` - Back button returns to actual previous page
  - `ReviewBySubject.jsx` - Both back buttons (empty state + main view)
  - `ReviewSession.jsx` - Back button in empty state

### Added
- **Dependent Dropdown Filters** - Topic dropdown now filters based on selected Subject
  - `MyNotes.jsx` - Topic shows only topics from selected subject
  - `MyFlashcards.jsx` - Topic shows only topics from selected subject
  - `BrowseNotes.jsx` - Added Topic filter with dependent behavior
  - `ReviewFlashcards.jsx` - Added Topic filter with dependent behavior

### Technical Details
- New state: `allTopicsFromNotes`, `allTopicsFromFlashcards`, `allTopicsFromDecks`
- New state: `allNotesFlat`, `allDecksFlat` for efficient filtering
- useEffect hook resets topic to "All Topics" when subject changes and current topic not in new list
- Filter grid changed from 3 columns to 4 columns on BrowseNotes and ReviewFlashcards

### Files Changed

## [2026-02-02] UI Fix - Desktop Navigation Centering

### Changed
- Desktop nav links now centered between Logo (left) and Icons (right)
- Dropdown menus aligned to center for better positioning

---

## [Feb 3, 2026] - UX Bug Fixes

### Fixed
- **NoteEdit.jsx**: Added image/PDF replacement feature
  - File picker to select new image/PDF
  - Preview of new file before saving
  - Automatic deletion of old file from Supabase storage
  - File validation (type and size limits)
  
- **MyFlashcards.jsx**: Fixed cursor jumping to beginning during inline editing
  - Extracted FlashcardCard to separate component file
  - Implemented isolated edit state pattern
  - Used useCallback for stable handler references

### Added
- **FlashcardCard.jsx**: New standalone component for flashcard display/editing
  - Moved from inline definition to prevent re-mounting on parent re-render
  - Props-based architecture for better performance

---

## [2026-02-02] Phase 1B - Notifications & Navigation Redesign

### Added
- `useNotifications` hook with Supabase Realtime subscription
- `useFriendRequestCount` hook with Realtime subscription  
- `useActivityFeed` hook for dashboard content feed
- `ActivityFeed` component for Dashboard
- `Sheet` UI component (Radix Dialog-based)
- Modular navigation: NavDesktop, NavMobile, FriendsDropdown, ActivityDropdown, ProfileDropdown

### Changed
- Navigation.jsx refactored from 566 lines to 55 lines (orchestrator pattern)
- Dashboard.jsx now includes ActivityFeed section

### Technical
- Friends icon shows red badge with pending count
- Bell icon shows red badge with unread notification count
- Notifications auto-marked as read when dropdown opens
- Mobile navigation uses Sheet with auto-close on navigate

---

## 2026-02-02: FlashcardCreate Duplicate Deck Fix

### Fixed
- **FlashcardCreate duplicate deck constraint error**
  - Creating 2nd+ flashcard for same subject/topic caused unique constraint violation
  - Now checks for existing deck before creating (SELECT before INSERT)
  - Reuses existing deck_id when match found
  - Uses `.is()` for NULL comparisons and `.maybeSingle()` for safe queries

### Files Changed
- `src/components/flashcards/FlashcardCreate.jsx`

---

## 2026-01-30: User Timezone Storage

### Added
- **Database:** `profiles.timezone` column (TEXT, default 'Asia/Kolkata')
- **Database:** Index `idx_profiles_timezone`
- **Frontend:** `updateUserTimezone()` helper in AuthContext.jsx

### Changed
- **`log_review_activity()`** - Now uses stored user timezone
- **`check_night_owl_badge()`** - Checks 11 PM - 4 AM in user's local time
- **`get_user_streak()`** - Calculates streak in user's local timezone
- **`get_anonymous_class_stats()`** - Uses per-user timezone for "studied today"
- **AuthContext.jsx** - Auto-syncs browser timezone on login/signup

### Impact
- Night Owl badge now works correctly for international users
- Streak calculations respect user's local midnight
- "Studied today" is accurate regardless of user location
- Timezone auto-updates when user travels

### Migration
- Run `[SCHEMA] Add User Timezone Support` in Supabase SQL Editor
- Existing users get default 'Asia/Kolkata' until they log in again

---

## 2026-01-30: Universal Timezone Fix

### Changed
- **FIXED:** All date calculations now use user's LOCAL timezone instead of hardcoded `Asia/Kolkata`
- **Files Updated:**
  - `Dashboard.jsx` - Streak calculation, due cards count
  - `Progress.jsx` - Streak calculation
  - `ReviewBySubject.jsx` - Due cards filtering
- **Pattern:** Use `toLocaleDateString('en-CA')` without timezone parameter
- **Impact:** App now works correctly for students in any country/timezone

### Documentation Updated
- `docs/active/context.md` - Updated Spaced Repetition & Timezone Standards
- `docs/design/ACHIEVEMENT_BADGES.md` - Updated timezone handling section
- `docs/reference/DATABASE_SCHEMA.md` - Updated SQL function notes

---

## 2026-01-26: Achievement Badges System (Phase 1E)

### Added
- **Badge System Core**
  - 3 new tables: `badge_definitions`, `user_badges`, `user_activity_log`
  - 5 badge types: Digitalizer, Memory Architect, Streak Master, Night Owl, Rising Star
  - Auto-award via database triggers on INSERT events
  - IST timezone handling for Night Owl badge (11PM-4AM)

- **Frontend Components**
  - `BadgeIcon.jsx` - Icon mapping component
  - `BadgeCard.jsx` - Badge display with privacy toggle
  - `BadgeToast.jsx` - Unlock notification
  - `useBadges.js` - Data fetching hook
  - `MyAchievements.jsx` - Full achievements page

- **Privacy Features**
  - Per-badge `is_public` toggle (default: true)
  - Users control visibility of each badge individually
  - FindFriends respects badge privacy settings

- **Navigation**
  - "My Achievements" link in Study dropdown
  - Toast notifications on Dashboard for new badges

### Changed
- Renamed "The Grinder" badge to "Streak Master"
- Updated `FindFriends.jsx` to display user badges

### Removed
- Yellow badge count indicator from navigation (confusing UX)
- Global `badges_public` column from profiles (replaced with per-badge)

### Database Migrations
- `badges_tables_and_seed.sql` - Tables + seed data
- `badges_rls_policies.sql` - Row Level Security
- `badges_core_functions.sql` - 6 SQL functions
- `badges_triggers.sql` - 4 triggers
- `badges_backfill_existing_users.sql` - Backfilled 14 badges
- `badges_per_badge_privacy.sql` - Added is_public column
- `rename_grinder_badge.sql` - Renamed badge

---

## 2026-01-24: Phase 1D - Upvote System

### Database
- **NEW TABLE:** `flashcard_decks` - Solidifies flashcard groups as first-class entities
- **MODIFIED:** `upvotes` table now polymorphic (content_type + target_id)
- **MODIFIED:** `flashcards` table has new `deck_id` column
- **NEW TRIGGERS:** Auto-update `upvote_count` on notes and decks
- **NEW TRIGGERS:** Auto-update `card_count` on decks
- **NEW FUNCTIONS:** `toggle_upvote()`, `get_upvote_details()`, `has_user_upvoted()`
- **NEW RLS:** Comprehensive policies for flashcard_decks and upvotes

### Frontend
- **NEW:** `UpvoteButton.jsx` - Reusable upvote component with toggle behavior
- **MODIFIED:** `BrowseNotes.jsx` - Added upvote buttons to note cards
- **MODIFIED:** `ReviewFlashcards.jsx` - Now queries flashcard_decks, added upvote buttons
- **MODIFIED:** `MyContributions.jsx` - Added Community Feedback section:
  - Impact message ("Your content helped X students!")
  - Upvoter names summary
  - Top Performing Notes/Decks with expandable upvoter lists
- **MODIFIED:** `NoteDetail.jsx` - Added upvote button in header, author badge

### Migration
- Existing flashcards grouped into decks via backfill script
- Existing upvotes migrated to polymorphic structure (content_type='note')

### Files Changed
```
src/components/ui/UpvoteButton.jsx (NEW)
src/pages/dashboard/Content/BrowseNotes.jsx
src/pages/dashboard/Content/MyContributions.jsx
src/pages/dashboard/Study/ReviewFlashcards.jsx
src/components/notes/NoteDetail.jsx
```
## 2026-01-24: Dashboard Redesign with Anonymous Class Stats (Phase 1C)

### Added
- **NEW Component:** `src/components/dashboard/AnonymousStats.jsx`
  - "You vs Class" comparison with Tailwind progress bars (no chart libraries)
  - Class Milestones: Students studied today, 7-day streak count
  - Privacy-first: Hides comparison if < 5 active users
  - Zero data state: Motivating text for users with no reviews

- **NEW SQL Function:** `get_anonymous_class_stats(p_course_level TEXT)`
  - SECURITY DEFINER (bypasses RLS for aggregation)
  - Returns: avg_reviews_this_week, total_active_students, students_with_7day_streak, students_studied_today, min_users_met
  - Filters by course_level (CA Inter vs CA Inter only)
  - Uses rolling 7-day window (today - 6 days)
  - Timezone: Uses user's local timezone for accurate day boundaries

### Changed
- **REFACTORED:** `src/pages/Dashboard.jsx`
  - Removed unused `courseLevel` state variable
  - Quick Actions: 3 buttons → 4 buttons (added "Browse Flashcards")
  - Grid layout: `grid-cols-2 lg:grid-cols-4`
  - Integrated AnonymousStats component

### Quick Actions (Updated)
| Button | Route |
|--------|-------|
| Browse Notes | `/dashboard/notes` |
| Browse Flashcards | `/dashboard/review-flashcards` |
| Create Flashcard | `/dashboard/flashcards/new` |
| Upload Note | `/dashboard/notes/new` |

### Privacy Safeguards Implemented
- Minimum 5 active users required to show class average
- No individual names shown in milestones
- Course-level filtering prevents cross-course comparison
- SQL function returns aggregates only, never individual data

## 2026-01-21: Critical Spaced Repetition & Timezone Bug Fixes

### Issue
Multiple critical bugs in spaced repetition system causing:
- Cards reappearing immediately after review (timezone issue)
- Progress not saving for professor-created cards (RLS conflict)
- Inflated "Reviews Due" count including new cards (logic mismatch)

### Root Causes

**1. Timezone Mismatch**
- Using `toISOString()` converted local dates to UTC
- For users in Western timezones or late-night India users, "tomorrow" became "yesterday"
- Example: Review at 11 PM IST → next_review_date = "today" UTC → card appears immediately

**2. Architectural Conflict**
- Original code wrote progress to `flashcards` table (professor-owned)
- RLS policy blocked student updates
- Silent failures, progress lost

**3. Logic Mismatch**
- Dashboard counted ALL accessible cards as "due"
- Included cards never studied (no entry in reviews table)
- Users saw inflated counts, then "All Caught Up" in Review Session

### Solution

**Date Handling Standardization**
- Replaced `toISOString()` with manual local date construction
- Format: `YYYY-MM-DD` using `getFullYear()`, `getMonth() + 1`, `getDate()`
- Ensures timezone-independent calendar date calculations

**Database Architecture**
- Moved student progress tracking to `reviews` table exclusively
- Explicit SELECT → UPDATE or INSERT logic (no atomic UPSERT)
- Each student maintains independent review schedule

**Dashboard Logic**
- "Reviews Due" = COUNT from `reviews` table WHERE `next_review_date <= today`
- Excludes new cards (never studied)
- Accurate representation of review workload

### Changes

**Modified Files:**
- `src/components/flashcards/StudyMode.jsx`
  - Replaced `toISOString()` with manual date string construction
  - Explicit SELECT before UPDATE/INSERT for reviews
  - Added detailed logging for debugging

- `src/pages/dashboard/Study/ReviewSession.jsx`
  - Query `reviews` table instead of `flashcards` table
  - Local date comparison for due cards
  - Proper handling of empty review queue

- `src/pages/Dashboard.jsx`
  - Count reviews from `reviews` table only
  - Local date calculation for "today"
  - Excludes new cards from "Reviews Due" count

### Technical Standards Established

**Enforced Rules (DO NOT VIOLATE):**
1. **Date Handling:** Never use `toISOString()` for `next_review_date` calculations
2. **Database Operations:** Reviews table is single source of truth for student progress
3. **Explicit Logic:** Use clear SELECT → UPDATE/INSERT flow (not atomic UPSERT)
4. **Definition of "Due":** Only cards in reviews table with `next_review_date <= today`

### Testing Verified
- [x] Cards reviewed today don't reappear until scheduled date
- [x] Timezone independence (works in IST, PST, GMT)
- [x] Dashboard count accuracy (matches Review Session)
- [x] Multi-user independence (students don't interfere with each other)
- [x] Progress persistence across sessions

### Impact
- ✅ Spaced repetition system now works reliably
- ✅ Student progress saves correctly regardless of card ownership
- ✅ Dashboard shows accurate review workload
- ✅ Timezone-independent (works globally)
- ✅ No duplicate reviews within same day

### Deployment
- Committed: 2026-01-21
- Status: Production
- Student Feedback: Pending verification

---
## 2026-01-19: Spaced Repetition System Architecture Fix

### Critical Bug Fix
**Issue:** Students' review progress not being saved - cards appearing repeatedly
**Root Cause:** Architectural flaw with SR data stored in shared flashcards table

### Changes
#### Modified Files
- `src/components/flashcards/StudyMode.jsx`
  - Removed flashcards table UPDATE (caused RLS conflicts)
  - Implemented reviews table UPSERT with next_review_date
  - Changed date format: timestamp → DATE (YYYY-MM-DD)
  
- `src/pages/dashboard/Study/ReviewSession.jsx`
  - Query changed: flashcards.next_review → reviews.next_review_date
  - Fixed date comparison logic
  
#### New Files
- `src/pages/dashboard/Study/ReviewBySubject.jsx`
  - Subject-based review grouping
  - Route: `/dashboard/review-by-subject`

### Technical Impact
- **Before:** Students updated shared flashcard records (RLS blocked)
- **After:** Students update personal review records (RLS allows)
- **Result:** Each user gets independent spaced repetition schedule

### Database Impact
- No schema changes required
- reviews.next_review_date column now properly utilized
- Old flashcards.next_review data remains but is unused

### Deployment
- Committed: 2026-01-19
- Deployed to: Vercel (production)
- Status: Live

### Testing Status
- Manual testing with student accounts: Required
- Expected behavior: Cards don't reappear until scheduled date
- Mid-session persistence: Verified needed

---
## Phase 3: Social Features & Friends-Only Content (January 15, 2026) ✅

## January 18, 2026
## Bug Fix ✅
"Fix: Spaced repetition timezone bug - use local midnight instead of UTC"

## Modular project documentation restructuring ✅
- Detached Google Drive from Project Documents
- Created these four files from the past documents
  - docs/active/context.md (how app works)
  - docs/active/now.md (current task)
  - docs/tracking/changelog.md (if needed for history)
  - docs/tracking/ideas.md (if planning new features)

## January 17, 2026
### Refactor: Organize project structure for scalability ✅
- Batch 1 - Dashboard Pages:
- Created subfolders: Friends/, Content/, Study/
- Moved and renamed files to PascalCase
- FindFriends, FriendRequests, MyFriends -> Friends/
- MyNotes, BrowseNotes, MyContributions -> Content/
- ReviewFlashcards, ReviewSession, Progress -> Study/

Batch 2 - Layout Components:
- Created src/components/layout/
- Moved Navigation.jsx to layout folder

Batch 3 - Auth Pages:
- Created src/pages/auth/
- Consolidated all auth pages: Login, Signup, ForgotPassword, ResetPassword
- Moved Login.jsx from components to pages/auth

Code Updates:
- Standardized all imports to use @/ alias (absolute paths)
- Updated App.jsx with organized import sections
- Fixed relative imports in all moved files


## January 15, 2026
### Features Added
- ✅ Friendships system (pending/accepted/rejected)
- ✅ Friend request pages (Find Friends, Friend Requests, My Friends)
- ✅ Three-tier visibility (Private/Friends/Public)
- ✅ Friends-only content filtering (notes + flashcards)
- ✅ RLS policies for security (4 comprehensive policies)
- ✅ Group visibility operations (3-tier dropdown)

### Database Changes
- Created `friendships` table with status tracking
- Added `visibility` column to `notes` table
- Added `visibility` column to `flashcards` table
- Enabled RLS on `flashcards` and `friendships` tables
- Created 4 RLS policies:
  1. Users can view friends flashcards
  2. Users can view their own flashcards
  3. Users can view public flashcards
  4. Users can view their own friendships

### Frontend Changes
- MyFlashcards.jsx: Added 3-tier visibility dropdown (single + group)
- StudyMode.jsx: Simplified query to rely on database RLS
- NoteEdit.jsx: Added 3-tier visibility dropdown
- NoteUpload.jsx: Added 3-tier visibility dropdown (already existed)
- FlashcardCreate.jsx: Added 3-tier visibility dropdown (already existed)
- ProfessorTools.jsx: Added 3-tier bulk upload visibility (already existed)
- notes.jsx: Friends-only filtering via RLS
- review-flashcards.jsx: Friends-only filtering via RLS

### Bugs Fixed
- Fixed: Friends-only flashcards visible but not reviewable
- Fixed: Public/Personal cards disappearing when RLS enabled
- Fixed: Visibility badge not updating after edit
- Fixed: Group dropdown not resetting after visibility change
- Fixed: Ghost directory issue (Vite cache)

### Technical Improvements
- Removed client-side friendship filtering (now database-side)
- Simplified queries to trust RLS policies
- Improved UI refresh after visibility changes
- Added proper error handling and toast notifications

---

# CHANGELOG - Completed Features

**Project:** Recall  
**Started:** December 2024

---

## Phase 2: Audit & Attribution (January 2026) ✅

### January 11, 2026
- ✅ Audit logging system (Phase 1 implementation)
- ✅ User deletion logging (logs BEFORE deletion)
- ✅ Admin/super_admin login tracking
- ✅ Role change logging

### January 10, 2026
- ✅ Spaced repetition system completely fixed
- ✅ FlashcardCreate.jsx: Added 6 initialization fields
- ✅ StudyMode.jsx: Fixed UTC midnight scheduling (setUTCHours)
- ✅ Database: 284 cards backfilled with next_review values
- ✅ Added NOT NULL constraint to next_review column

### January 9, 2026
- ✅ Added `creator_id` to flashcards (user attribution)
- ✅ Added `content_creator_id` to flashcards (revenue attribution)
- ✅ Created `content_creators` table for Vivitsu partnership
- ✅ Backfilled creator_id for existing flashcards

---

## Phase 1: MVP Complete (December 2025 - January 2026) ✅

### January 3, 2026
- ✅ Created dedicated `/dashboard/review-session` route
- ✅ Review session fetches ONLY due cards (next_review <= NOW)
- ✅ StudyMode accepts flashcards prop (flexible usage)
- ✅ Fixed midnight scheduling (changed setHours → setUTCHours)

### January 2, 2026
- ✅ Delete entire group functionality (cascade delete)
- ✅ Edit group info dialog (course/subject/topic/description)
- ✅ UTF-8 CSV encoding for special characters (₹ symbol)
- ✅ Native HTML select elements (replaced shadcn Select for stability)
- ✅ Spaced repetition verified working (Hard/Medium/Easy intervals)

### January 1, 2026
- ✅ 22 CA Inter students enrolled as pilot batch

### December 28, 2025
- ✅ Dynamic custom course support
- ✅ Signup shows custom courses in "Other Courses" group
- ✅ All dropdowns fetch custom courses from database (notes + flashcards + profiles)

### December 27, 2025
- ✅ Deployed to Vercel production
- ✅ Live URL: https://recall-app-omega.vercel.app
- ✅ All VS Code errors fixed (52 → 20 CSS warnings)
- ✅ Fixed runtime error in progress.jsx (reviewed_at → created_at)
- ✅ Removed duplicate AuthContext.jsx from lib/ folder

### December 26, 2025
- ✅ Terms of Service page (14 sections, Razorpay compliant)
- ✅ Privacy Policy page (14 sections, GDPR/India IT Act)
- ✅ Batch tracking system (batch_id + batch_description)
- ✅ Split 52 old cards into logical batches
- ✅ Merge functionality for batches

### December 25, 2025
- ✅ Filter standardization across all 4 pages
- ✅ Added Course filter to Review Flashcards
- ✅ Added Course filter to Browse Notes
- ✅ Inline edit for flashcards
- ✅ Delete functionality for notes and flashcards
- ✅ Clear All Filters button
- ✅ Result count display

### December 21, 2025
- ✅ Fixed Navigation to show user's full name
- ✅ Fixed Browse Notes attribution (professor badges)
- ✅ Created My Notes page (separate from Browse Notes)
- ✅ User attribution using two-query approach

### December 20, 2025
- ✅ Dashboard redesigned (student-first approach)
- ✅ Three dashboard states: New user / Has reviews / All caught up
- ✅ Student-focused stats (Cards Reviewed, Streak, Accuracy)
- ✅ Professor content discovery section

### December 19, 2025
- ✅ Dual-mode navigation (Study/Create dropdowns)
- ✅ My Progress page with real-time analytics
- ✅ My Contributions page with real stats
- ✅ Study streak calculation algorithm
- ✅ Accuracy percentage calculation (Easy+Medium/Total)

---

## Core Features Implemented ✅

### Authentication & Roles
- ✅ Email/password authentication via Supabase
- ✅ Four-tier role system (super_admin/admin/professor/student)
- ✅ Role-based session timeouts
- ✅ Role-based permissions matrix

### Notes System
- ✅ Photo/PDF upload with compression
- ✅ Target course selection (two-tier content model)
- ✅ Three-tier visibility (private/friends/public)
- ✅ Search and filter (Course, Subject, Topic, Visibility, Date)
- ✅ Delete with cascade warning

### Flashcards System
- ✅ Manual flashcard creation
- ✅ Bulk CSV upload (ProfessorTools.jsx)
- ✅ Batch tracking (batch_id groups uploads)
- ✅ Three-tier visibility
- ✅ Inline edit
- ✅ Delete functionality
- ✅ Difficulty tagging (easy/medium/hard)

### Spaced Repetition
- ✅ SuperMemo-2 algorithm implementation
- ✅ Hard = 1 day, Medium = 3 days, Easy = 7 days
- ✅ UTC midnight scheduling
- ✅ Review history tracking (reviews table)
- ✅ Dedicated review session route

### Social Features
- ✅ Friendships table with status tracking
- ✅ Friend request flow (send/accept/reject)
- ✅ Friends-only content visibility
- ✅ RLS policies for security

### Admin Features
- ✅ Super Admin Dashboard (user management, role assignment)
- ✅ Admin Dashboard (content moderation)
- ✅ Audit logging (deletions, logins, role changes)
- ✅ Search and filter users

### UI/UX
- ✅ Mobile-first responsive design
- ✅ TailwindCSS + shadcn/ui components
- ✅ Toast notifications
- ✅ Loading states
- ✅ Error handling

---

## Database Migrations Applied ✅

1. `001_add_batch_tracking.sql` - Added batch_id, batch_description
2. `002_split_52_cards_SIMPLE.sql` - Split old cards into batches
3. Added creator_id column to flashcards
4. Added content_creator_id column to flashcards
5. Created friendships table with indexes
6. Added visibility column to notes (replaced is_public)
7. Added visibility column to flashcards (replaced is_public)
8. Added NOT NULL constraint to next_review
9. Enabled RLS on flashcards table
10. Enabled RLS on friendships table
11. Created 4 RLS policies for friends visibility

## Previous Phases

### Phase 2: CA Foundation Scale (Month 2-3) - Planned
- Target: 150 in-house CA Foundation students
- Status: Not started

### Phase 1: CA Inter Pilot (Month 1) - Complete ✅
- Launched: December 2025
- Users: 20 CA Intermediate students
- Status: Success - 75% adoption rate

### Phase 0.5: Professor Content Seeding - Complete ✅
- Completed: December 2025
- Content: 220 flashcards, 35 notes
- Professors: 2-3 faculty contributors