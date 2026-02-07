# NOW - Current Development Status

**Last Updated:** 2026-02-06
**Current Phase:** Study Groups (Phase 1: Read-Only) Complete

---

## Just Completed ✅

### Allow All Members to Share Content in Groups (Feb 7, 2026)
- [x] Updated `share_content_with_groups()` RPC — changed admin check to active member check
- [x] Updated RLS INSERT policy on `content_group_shares` — `cgs_insert_admin` → `cgs_insert_member` (any active member)
- [x] Updated RLS DELETE policy — `cgs_delete_admin` → `cgs_delete_own_or_admin` (admin deletes any, member deletes own)
- [x] Updated GroupDetail.jsx — Share Content button visible to all members (not just admin)
- [x] Updated GroupDetail.jsx — Delete button: admin can delete any shared content, member can delete only their own
- [x] Invite Members button remains admin-only
- [x] **MUST RUN SQL**: `docs/database/study-groups/27_FIX_allow_all_members_to_share_content.sql`

### Group Invitation Flow + Notification Backend (Feb 6, 2026)
- [x] Created `notifications` table with RLS policies, indexes, and JSONB metadata column
- [x] Created 5 notification RPCs + cleanup utility (matches existing useNotifications.js hook)
- [x] Added `status` ('invited'/'active') and `invited_by` columns to `study_group_members`
- [x] Updated `invite_to_group()` — now inserts as 'invited' + creates notification with metadata
- [x] Created `accept_group_invite()` — verifies ownership, updates status, auto-marks notification read
- [x] Created `decline_group_invite()` — marks notification read, hard DELETEs membership row
- [x] Created `get_pending_group_invites()` — for MyGroups pending invitations section
- [x] Updated 5 existing RPCs with `AND status = 'active'` security filter (get_user_groups, get_group_detail, get_browsable_notes, get_browsable_decks, leave_group)
- [x] Updated ActivityDropdown.jsx — group_invite type with inline Accept/Decline buttons
- [x] Updated Navigation.jsx + NavDesktop.jsx + NavMobile.jsx — pass deleteNotification/refetch props
- [x] Updated MyGroups.jsx — pending invitations section with amber-bordered cards + Accept/Decline
- [x] Updated GroupDetail.jsx — "Invite Members" button, "Invitation sent!" toast, pending section in members panel, cancel invite for admins, search excludes pending
- [x] **MUST RUN SQL**: 12 new SQL files (13-24) in `docs/database/study-groups/` in Supabase SQL Editor
- [x] **MUST ENABLE**: Supabase Realtime on `notifications` table (Dashboard → Database → Replication)

### Study Groups - RLS Fix + Server-Side Content Fetching (Feb 6, 2026)
- [x] Fixed infinite recursion in `sgm_select_member` RLS policy → replaced with `sgm_select_own`
- [x] Fixed "Failed to load group" on GroupDetail — replaced 3-query RLS-dependent pattern with single `get_group_detail()` RPC
- [x] Created `get_group_detail()` RPC — returns group info + members + shared content in one call (SECURITY DEFINER)
- [x] Created `get_group_members()` SECURITY DEFINER RPC with membership check
- [x] Created `get_browsable_notes()` RPC — single server-side query for all visible notes (own + public + friends + group-shared)
- [x] Created `get_browsable_decks()` RPC — same for flashcard decks
- [x] Refactored GroupDetail.jsx: single RPC call instead of 3 separate queries
- [x] Refactored BrowseNotes.jsx: removed 3-query client-side merge, now uses single RPC call
- [x] Refactored ReviewFlashcards.jsx: same refactor, single RPC call
- [x] **MUST RUN SQL**: 4 new SQL files (`09`, `10`, `11`, `12`) + updated `02` in `docs/database/study-groups/`

### Study Groups - Phase 1: Read-Only (Feb 6, 2026)
- [x] Created 3 database tables: `study_groups`, `study_group_members`, `content_group_shares`
- [x] All group_id FKs use `ON DELETE CASCADE` (group deletion removes shares, NOT original content)
- [x] 8 RLS policies for member-scoped read, admin-only writes (sgm_select_member → sgm_select_own after fix)
- [x] 6 SECURITY DEFINER RPC functions (create, invite, leave, share, get_groups, get_content)
- [x] MyGroups.jsx - Group list with create/leave/delete
- [x] CreateGroup.jsx - Name + description form, creator becomes admin
- [x] GroupDetail.jsx - Members panel, shared content, invite/share dialogs
- [x] Visibility model: Private | Study Groups | Friends | Public (4-tier)
- [x] NoteUpload + FlashcardCreate - "Study Groups" option + group multi-select checkboxes
- [x] BrowseNotes + ReviewFlashcards - Server-side unified content fetching via RPCs
- [x] Navigation updated in desktop and mobile
- [x] Members can VIEW shared content only, NOT edit
- [x] **MUST RUN SQL**: 11 SQL files in `docs/database/study-groups/` in Supabase SQL Editor

### Card Suspension System - Skip, Suspend, Reset (Feb 6, 2026)
- [x] Added `status` (active/suspended) and `skip_until` (DATE) columns to reviews table
- [x] Created 3 performance indexes on reviews (status, skip_until, composite)
- [x] Created 6 SECURITY DEFINER RPC functions (skip, suspend, suspend_topic, unsuspend, reset, get_suspended)
- [x] Updated StudyMode.jsx with [Skip 24hr] button + [More] dropdown (Suspend Card, Suspend Topic, Reset Card)
- [x] Confirmation dialogs for destructive actions (suspend/reset)
- [x] Updated Progress.jsx with collapsible "Suspended Cards" section + Unsuspend controls
- [x] Updated ReviewSession.jsx and ReviewBySubject.jsx to exclude suspended/skipped cards
- [x] Updated Dashboard.jsx due count and streak to exclude suspended/skipped cards
- [x] **MUST RUN SQL**: Migration + 6 functions in Supabase SQL Editor before features work

### Author Profile Page & Clickable Names (Feb 6, 2026)
- [x] Created `get_author_profile()` RPC function (SECURITY DEFINER) - returns profile + badges + friendship in 1 call
- [x] Created `get_author_content_summary()` RPC function (SECURITY DEFINER) - returns content grouped by course/subject with server-side visibility
- [x] Created `AuthorProfile.jsx` page at `/dashboard/profile/:userId` using 2 RPC calls (not 6 direct queries)
- [x] Shows author name, role badge, institution, course level
- [x] Shows PUBLIC badges (all badges for own profile with hidden indicator)
- [x] Content grouped by Course → Subject with note/flashcard counts
- [x] "Also Creates Content For" section for courses viewer isn't enrolled in
- [x] Add Friend button with full friendship status handling
- [x] "Preview as Visitor" toggle on own profile
- [x] Back button with history-aware navigation
- [x] Made author names clickable `<Link>` in 6 locations:
  - BrowseNotes.jsx (note card footer)
  - ReviewFlashcards.jsx (deck card)
  - NoteDetail.jsx (author badge in header)
  - FindFriends.jsx (user card name)
  - MyFriends.jsx (friend card name)
  - MyContributions.jsx (upvoter names - summary, notes, decks)

### Previous: Grid/Grouped View Toggle & Collapsible Sections (Feb 6, 2026)
- [x] Added Grid/Grouped view toggle to MyNotes.jsx (matching MyFlashcards pattern)
- [x] Implemented Grouped View with Subject → Topic hierarchy
- [x] Notes without subject/topic go into "Uncategorized" section (sorted last)
- [x] View preference persisted in localStorage (`myNotes_viewMode`)
- [x] Collapsible subject and topic sections with chevron icons (both views)
- [x] Added collapsible sections to BrowseNotes.jsx (subject + topic levels)
- [x] Added collapsible sections to ReviewFlashcards.jsx (subject level with Study All button preserved)
- [x] Gradient header styling on subject groups (blue-to-indigo)
- [x] Note/topic counts displayed on group headers

### Previous: Author Search with Server-Side Filtering (Feb 5, 2026)
- [x] Created `get_filtered_authors_for_notes()` RPC function
- [x] Created `get_filtered_authors_for_flashcards()` RPC function
- [x] Split Author filter into Role + Author dropdowns
- [x] Implemented dependent Author filtering (updates based on Course/Subject/Role)
- [x] Updated BrowseNotes.jsx with 5-column filter grid
- [x] Updated ReviewFlashcards.jsx with 5-column filter grid
- [x] Server-side visibility enforcement (only PUBLIC content authors shown)

### Previous: Notifications & Navigation Redesign (Phase 1B)
- [x] Database functions for notifications (get, mark read, delete)
- [x] Database function for activity feed (recent notes/decks)
- [x] useNotifications hook with Supabase Realtime subscription
- [x] useFriendRequestCount hook with Realtime subscription
- [x] useActivityFeed hook for dashboard content feed
- [x] Modular Navigation components (6 files replacing 1)
- [x] Desktop: Friends dropdown with inline Accept/Decline
- [x] Desktop: Activity dropdown with auto mark-as-read
- [x] Desktop: Profile dropdown with user info + links
- [x] Mobile: Sheet-based hamburger menu
- [x] Mobile: Friends + Bell icons with badges
- [x] Dashboard: ActivityFeed component showing recent content
- [x] Sheet UI component for mobile navigation

---

## Next Up 🎯

### Phase 0.5: Professor Content Seeding
- [ ] Recruit professors to upload content
- [ ] Bulk upload flashcards for CA Intermediate subjects

### Phase 2: Expansion (March 2026)
- [ ] Scale to 150 CA Foundation students
- [ ] Add more badge types based on user feedback

---

## Active Decisions

| Decision | Status | Notes |
|----------|--------|-------|
| Grid/Grouped toggle on MyNotes | ✅ Implemented | localStorage persistence, matches MyFlashcards pattern |
| Collapsible groups on BrowseNotes | ✅ Implemented | Subject + Topic levels, chevron icons |
| Server-side author filtering | ✅ Implemented | RPC functions for performance & security |
| Split Author into Role + Author | ✅ Implemented | Better UX for filtering |
| Instant mark-as-read | ✅ Approved | Notifications marked read immediately on dropdown open |
| Modular navigation | ✅ Implemented | 6 component files for maintainability |
| Mobile Sheet (not menu) | ✅ Implemented | Smooth UX with slide-in animation |
| Study Groups Phase 1 | ✅ Implemented | Read-only sharing, 4-tier visibility, ON DELETE CASCADE |
| Group Invitation Flow | ✅ Implemented | Invite → Notify → Accept/Decline. No auto-add. Notification backend active. |

---

## Known Issues

None currently.

---

## Session Notes

### 2026-02-06 Session (Group Invitation Flow + Notification Backend)
- Built full notification backend: `notifications` table + 5 RPCs + cleanup utility
- Added `status` ('invited'/'active') + `invited_by` columns to `study_group_members`
- Follows friendships table pattern (status column, not separate table)
- `invite_to_group()` now inserts as 'invited' and creates notification with JSONB metadata
- Accept/decline RPCs auto-cleanup notifications via metadata->>'membership_id'
- All content-access RPCs updated with `AND status = 'active'` security filter
- ActivityDropdown: group_invite notifications render with inline Accept/Decline (not as links)
- MyGroups: Amber-bordered "Pending Invitations" section above groups grid
- GroupDetail: "Invite Members" button, pending section in members panel, cancel invite for admins
- Search filter in invite dialog excludes both active members AND pending invitations
- 12 SQL files (13-24) must be run in Supabase SQL Editor
- Must enable Supabase Realtime on `notifications` table separately

### 2026-02-06 Session (Study Groups Phase 1)
- Created 3 new database tables with ON DELETE CASCADE on group_id FKs
- 8 RLS policies: members read their own groups, admins manage membership/shares
- 6 SECURITY DEFINER RPC functions for all group operations
- 3 new pages: MyGroups, CreateGroup, GroupDetail (with invite, share content, remove member dialogs)
- 4-tier visibility model: Private | Study Groups | Friends | Public
- NoteUpload + FlashcardCreate: "Study Groups" visibility with multi-select group checkboxes
- BrowseNotes + ReviewFlashcards: merge group-shared content with existing visibility-filtered content
- Navigation: Groups link in desktop nav, Study Groups section in mobile sheet
- leave_group() promotes oldest member to admin if last admin leaves
- Content stores as 'private' visibility in DB when shared with groups (access via content_group_shares table)
- SQL files in docs/database/study-groups/ (01-08) must be run in Supabase SQL Editor

### 2026-02-06 Session (Card Suspension System)
- Added `status` TEXT NOT NULL DEFAULT 'active' CHECK (active/suspended) to reviews table
- Added `skip_until` DATE DEFAULT NULL to reviews table
- Created 3 indexes: idx_reviews_status, idx_reviews_skip_until, idx_reviews_user_status_due (partial)
- Created 6 RPC functions: skip_card, suspend_card, suspend_topic_cards, unsuspend_card, reset_card, get_suspended_cards
- All functions use SECURITY DEFINER and respect user timezone from profiles.timezone
- StudyMode.jsx: Added Skip button (no confirmation), More dropdown with Suspend/Reset (with confirmation dialogs)
- Progress.jsx: Added collapsible Suspended Cards section grouped by subject with Unsuspend buttons
- ReviewSession.jsx + ReviewBySubject.jsx: Added `.eq('status', 'active')` and skip_until filtering to due card queries
- Dashboard.jsx: Due count and streak now exclude suspended cards and quality=0 placeholder records
- Streak logic: Only counts reviews where quality > 0 (actual study, not skip/suspend placeholder records)

### 2026-02-06 Session (Author Profile)
- Created 2 SECURITY DEFINER RPC functions: `get_author_profile()` and `get_author_content_summary()`
- Created AuthorProfile.jsx using RPC functions (2 round-trips instead of 6 direct queries)
- Added `/dashboard/profile/:userId` route to App.jsx
- Made author/user names clickable Links in 6 files (BrowseNotes, ReviewFlashcards, NoteDetail, FindFriends, MyFriends, MyContributions)
- Server-side visibility enforcement: public for strangers, public+friends for friends, all for own
- **MUST RUN SQL**: Both functions need to be created in Supabase SQL Editor before page works

### 2026-02-06 Session (Grid/Grouped)
- Added Grid/Grouped view toggle to MyNotes.jsx with localStorage persistence
- Implemented Subject → Topic hierarchy grouping with "Uncategorized" fallback
- Extracted `renderNoteCard` helper for shared card rendering in both views
- Added collapsible chevrons to BrowseNotes.jsx (subject + topic levels)
- Added collapsible chevrons to ReviewFlashcards.jsx (subject level, Study All button uses stopPropagation)
- No database changes required (uses existing subject/topic joins)
- No new files created (modified MyNotes.jsx, BrowseNotes.jsx, ReviewFlashcards.jsx)

### 2026-02-05 Session
- Implemented Author Search with server-side filtering per QA Bot requirements
- Created 2 new Supabase RPC functions
- Split Author filter into Role + Author for better granularity
- Author dropdown now dynamically updates based on other filter selections
- Only authors with PUBLIC content shown (visibility enforcement)

### 2026-02-02 Session
- Rebuilt Navigation into modular components
- Added realtime hooks for notifications and friend requests
- Integrated ActivityFeed into Dashboard
- Fixed ESLint warnings (unused imports)
- Centered desktop nav links (Logo left, Nav center, Icons right)
