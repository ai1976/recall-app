# NOW - Current Development Status

**Last Updated:** 2026-02-21
**Current Phase:** Phase 1F - Extended Badge System

---

## Just Completed ✅

### Fix: Private Badges Showing on Author Profile Page (Feb 21, 2026)
- [x] **Bug:** Badges marked private in My Achievements were still visible on the Author Profile page (own + others' profiles)
- [x] **Root Cause:** `AuthorProfile.jsx` rendered `badges.map(...)` over all badges returned by `get_author_profile` RPC. For own profile the RPC returns ALL badges (including private); the old code only added a 🔒 icon but never hid the badge.
- [x] **Fix:** Computed `publicBadges = badges.filter(b => b.is_public !== false)` and replaced `badges.map` with `publicBadges.map`. Removed the now-redundant EyeOff indicator inside badge pills.
- [x] No database changes — frontend-only fix in `AuthorProfile.jsx`
- [x] Privacy now consistent across the full app: My Achievements = manage privacy; Author Page = public-only view

### Phase 1F - Extended Badge System with Performance Optimizations (Feb 21, 2026)
- [x] **Scalability fix:** Created `user_stats` table with integer counters — badge checks now O(1) instead of O(n) COUNT(*). Prevents bulk upload crash.
- [x] **Counter triggers:** 5 new triggers (`trg_aaa_counter_*`) on notes/flashcards/reviews/upvotes/friendships — alphabetically before badge triggers.
- [x] **13 new badges:** prolific_writer, deck_builder, subject_expert, first_steps, committed_learner, monthly_master, early_bird, century_club, review_veteran, social_learner, community_pillar, helpful_peer, pioneer.
- [x] **Timezone support:** Night Owl + Early Bird use `profiles.timezone` (already existed). No IST hardcoding.
- [x] **Race condition fix:** `award_badge` uses `INSERT ... ON CONFLICT DO NOTHING` — safe for concurrent calls.
- [x] **Default privacy:** night_owl and early_bird are private by default in updated `award_badge`.
- [x] **Pioneer badge:** Awarded via profile INSERT trigger for new users + backfill for all existing users.
- [x] **Friendship trigger:** `trg_badge_friendship` on friendships UPDATE for social badges.
- [x] **Frontend — BadgeIcon.jsx:** Added 13 new icon mappings (FileText, Layers, GraduationCap, Footprints, CalendarCheck, CalendarRange, Sunrise, Award, Medal, Users, HeartHandshake, ThumbsUp, Flag).
- [x] **Frontend — MyAchievements.jsx:** Added `special` category, replaced 5 separate COUNT queries with single `user_stats` read + streak call.
- [x] SQL scripts in `docs/sql/phase1f/` (6 files, run in order 01→06).

### SQL Execution Order
1. `01_schema.sql` — Create user_stats table + RLS + initialize rows
2. `05_award_badge.sql` — Update award_badge (badge triggers depend on it)
3. `02_counter_triggers.sql` — Counter trigger functions + triggers
4. `03_badge_definitions.sql` — Insert 13 new badge definitions
5. `04_badge_triggers.sql` — Updated badge trigger functions + triggers
6. `06_backfill.sql` — Populate user_stats + award retroactive badges

### Fix: Content Type Selector Missing on Upload Note (Feb 20, 2026)
- [x] **Bug:** Content Type buttons (Text, Table, Math, Diagram, Mixed) were only shown in Edit Note, not in Upload Note
- [x] **Fix:** Added Content Type selector to the "Note Details" card in `NoteUpload.jsx`, after the Description field
- [x] `contentType` state already existed and was already saved to DB — only the UI was missing
- [x] No database changes — frontend-only fix

### Landing Page Stats — Total Counts + Visibility Fix (Feb 20, 2026)
- [x] **Hero 4-stat grid:** Now shows true platform-wide totals (1383 flashcards, 38 notes) via `get_platform_stats()` SECURITY DEFINER RPC — bypasses RLS so unauthenticated visitors see real counts, not just public content
- [x] **Educator section:** Keeps public-only counts (458 flashcards, 34 notes) so new users see what they can actually browse. Relabeled "Flashcards to Browse" and "Notes to Browse"
- [x] **Hero social proof line:** Updated from "X+ items shared" → "X+ items created"
- [x] **Bug fix:** Public queries were using legacy `is_public = true` column — changed to `visibility = 'public'`
- [x] **MUST RUN SQL:** `get_platform_stats()` function in Supabase SQL Editor (see changelog for full SQL)

### Fix: Activity Feed "View" Button UUID Error (Feb 20, 2026)
- [x] **Bug:** Clicking "View" on a note in the Recent Activity section caused "Page Not Found" with error "Invalid input syntax for type uuid: 'undefined'"
- [x] **Root Cause:** `ActivityFeed.jsx` referenced `activity.content_id` but the `get_recent_activity_feed` RPC returns the UUID as `id` (consistent with all other RPCs). `activity.content_id` was always `undefined`, producing the URL `/dashboard/notes/undefined`.
- [x] **Fix:** Changed `activity.content_id` → `activity.id` in both the `handleActivityClick` navigate call and the React `key` prop
- [x] No database changes — frontend-only fix in `ActivityFeed.jsx`

### Fix: card_count Double-Counting Bug + DB Trigger (Feb 12, 2026)
- [x] **Diagnosed:** `card_count` in `flashcard_decks` was ~2x actual flashcard count for multiple students
- [x] **Root Cause:** Frontend was manually incrementing `card_count` on every save; a prior code change caused the save to fire twice, doubling the counter
- [x] **Data Fix:** SQL ran to recalculate all `card_count` values from actual `flashcards` rows (ground truth)
- [x] **Prevention:** Added DB trigger `flashcards_count_trigger` — auto-increments/decrements `card_count` on INSERT/DELETE to `flashcards` table
- [x] **Frontend:** Removed manual `card_count` increment from `FlashcardCreate.jsx` (existing deck update + new deck insert). New decks start at `card_count: 0`; trigger maintains accuracy automatically
- [x] `card_count` no longer fetched in existing deck lookup (was only needed for manual math)

### Fix: Flashcard Deck Names in Share Content Dialog (Feb 9, 2026)
- [x] **Fixed:** Share Content dialog showed "Flashcard Deck" for all decks instead of actual subject/topic names
- [x] Root cause: `subject_id` and `topic_id` were not included in the Supabase select query, so name lookups always failed
- [x] Added `subject_id, topic_id` to flashcard_decks query in `fetchUserContent()`
- [x] Added topic name lookup (fetches from `topics` table, same pattern as subjects)
- [x] Added `display_topic` field using `custom_topic || topicsMap[topic_id]`
- [x] Decks now show as "Subject - Topic" (e.g., "Auditing & Ethics - Audit of Items of Financial Statements")
- [x] No database changes — frontend-only fix

### Dependent Subject Dropdowns + Skipped Duplicates Report (Feb 9, 2026)
- [x] **FlashcardCreate + NoteUpload:** Subject dropdown now filters by selected course (`discipline_id`)
- [x] Disciplines loaded on mount; course name matched to discipline for subject filtering
- [x] Subject & topic selections reset when course changes (prevents stale cross-course selections)
- [x] Custom courses (no discipline match) show all subjects as fallback
- [x] **Fixed:** `description` column removed from topics insert/select — column doesn't exist in DB
- [x] **Fixed:** `sort_order` → `order_num` for all subjects/topics DB queries (same as disciplines)
- [x] **BulkUploadTopics:** Skipped duplicates now listed by name (`Subject → Topic`) in success report
- [x] DATABASE_SCHEMA.md updated for all 3 structure tables (disciplines, subjects, topics) with verified live DB columns
- [x] Build verified clean

### Bulk Upload QA Refinements + Disciplines Fix (Feb 9, 2026)
- [x] Removed forced download gate — all stepper steps freely clickable (returning users skip to Step 2)
- [x] Added first-timer nudge (amber Info box in Step 2 when Step 1 not done) on both pages
- [x] Step 3 shows contextual amber nudge when prerequisites missing (links back to relevant step)
- [x] **Fixed:** disciplines queries now use correct column names (`is_active`, `order_num` — NOT `sort_order`)
- [x] **Fixed:** Create New Course insert now includes required `code` column (auto-generated from name)
- [x] BulkUploadTopics: Added `[+ New Course]` inline form next to course dropdown
- [x] Course creation: Title Case enforcement + case-insensitive duplicate check + DB unique constraint catch
- [x] BulkUploadTopics: Added `subject_sort_order` and `sort_order` (topic) optional CSV columns
- [x] Sort logic: 0 = alphabetical fallback, explicit integers sorted first (sort_order ASC, name ASC)
- [x] Existing subjects with sort_order=0 get updated if CSV provides a non-zero value
- [x] Template changed to generic examples (language learning) instead of CA-specific
- [x] Current Entries download now includes sort_order columns and respects sort_order in output
- [x] CSV parser handles both `sort_order` and `topic_sort_order` header names
- [x] No database schema changes — uses existing sort_order columns on subjects/topics tables
- [x] **Note:** `disciplines` table uses `order_num` (not `sort_order`), has required `code` column. Schema verified against live DB.
- [x] Build verified clean

### Streamlined Bulk Upload Pages (Feb 9, 2026)
- [x] Created `BulkUploadFlashcards.jsx` — new stepper-based UI replacing old ProfessorTools 4-card layout
- [x] 3-step collapsible stepper: Download Files → Prepare & Select CSV → Upload
- [x] "Required columns" hint in Step 2 so users don't need to open template to check headers
- [x] Success state replaces stepper with "Upload More" / "View My Flashcards" buttons
- [x] Created `BulkUploadTopics.jsx` — admin-only page for bulk-adding subjects & topics to a course
- [x] Case-insensitive matching: "taxation" maps to existing "Taxation" (no duplicates)
- [x] Title Case enforcement: "income tax" → "Income Tax" for new entries
- [x] Duplicate detection: existing subject+topic combos are skipped automatically
- [x] Same stepper design pattern as flashcard bulk upload (consistent UX)
- [x] Route: `/dashboard/bulk-upload` (flashcards, all users), `/admin/bulk-upload-topics` (admin only)
- [x] `/professor/tools` now redirects to `/dashboard/bulk-upload`
- [x] Nav links updated: Bulk Upload visible to all users (was professor/admin only), "Manage Topics" link for admin/super_admin
- [x] FlashcardCreate.jsx "Try Bulk Upload" link updated to new route
- [x] All CSV parsing/upload logic preserved from original ProfessorTools
- [x] No database schema changes
- [x] Build verified clean

### Profile Completion Modal & Course Label Update (Feb 9, 2026)
- [x] Non-dismissible modal on Dashboard when `course_level` or `institution` is NULL
- [x] Uses same SearchableSelect institution list and course dropdown as ProfileSettings
- [x] Blocks interaction: no close button, no escape, no click-outside dismiss
- [x] Added `hideCloseButton` prop to `DialogContent` component (reusable for other non-dismissible dialogs)
- [x] ProfileSettings course label changed to "Primary Course" (future multi-course prep)
- [x] Dashboard re-fetches after modal save for updated class stats
- [x] No database changes — reads existing `course_level` and `institution` columns
- [x] Build verified clean

### FindFriends Privacy Fix & Profile Settings Page (Feb 8, 2026)
- [x] Masked emails in FindFriends (`an***@gmail.com`) — cosmetic client-side masking, code comment added
- [x] Added institution + "Joined {year}" display on FindFriends cards for user disambiguation
- [x] Removed email from search filter (name-only search prevents email enumeration)
- [x] Created `ProfileSettings.jsx` — edit Full Name, Course Level, Institution
- [x] Institution field: dropdown (In-house / External / Other) with custom text input for "Other"
- [x] Input sanitization: trim whitespace + Title Case for custom institution names
- [x] Added `/dashboard/settings` route in App.jsx
- [x] Added Settings link with gear icon in ProfileDropdown.jsx (desktop) and NavMobile.jsx (mobile)
- [x] No database changes — uses existing `institution` column in profiles table
- [x] Build verified clean: `npx vite build` passes with no errors

### Flashcard Text-to-Speech / Read Aloud (Feb 8, 2026)
- [x] Created `useSpeech.js` hook — wraps Web Speech API with sentence chunking (Chrome 15-sec bug fix), localStorage for voice URI + speed
- [x] Created `SpeakButton.jsx` — reusable volume icon (Volume2/VolumeX) with pulse animation, hidden on unsupported browsers or empty text
- [x] Created `SpeechSettings.jsx` — popover with voice selector (grouped by language) + speed slider (0.5x–2.0x)
- [x] Integrated into `StudyMode.jsx` — volume icon on QUESTION side, volume icons on both QUESTION recap + ANSWER side after reveal, settings gear next to first volume icon
- [x] Auto-cancel speech on card advance, answer reveal, skip, suspend, reset, and component unmount
- [x] No database changes — pure client-side feature using browser-native Web Speech API
- [x] No new dependencies — zero external packages added

### File Structure Refactor — Pages out of Components (Feb 8, 2026)
- [x] Moved 9 page-level components from `src/components/` to `src/pages/` (enforces pages=routed, components=reusable convention)
- [x] Notes pages (NoteUpload, NoteDetail, NoteEdit) → `pages/dashboard/Content/`
- [x] Flashcard pages (FlashcardCreate, MyFlashcards) → `pages/dashboard/Content/`
- [x] StudyMode → `pages/dashboard/Study/`
- [x] Admin pages → `pages/admin/`
- [x] ProfessorTools → `pages/professor/`
- [x] Fixed NoteEdit route: `/notes/edit/:id` → `/dashboard/notes/edit/:id` (was only route missing `/dashboard` prefix)
- [x] Added legacy redirect for old `/notes/edit/:id` path
- [x] Added route-to-file mapping comment block in App.jsx
- [x] Deleted dead `components/notes/index.jsx` placeholder
- [x] Removed empty `components/notes/`, `components/admin/`, `components/professor/` directories
- [x] Updated imports in App.jsx, ReviewSession.jsx, NoteDetail.jsx

### Clickable Content in Author Profile (Feb 8, 2026)
- [x] Made note/flashcard counts in AuthorProfile subject rows clickable `<Link>` elements
- [x] Notes count links to `/dashboard/notes?author=<id>&subject=<name>`
- [x] Flashcards count links to `/dashboard/review-flashcards?author=<id>&subject=<name>`
- [x] Added `useSearchParams` URL param reading to BrowseNotes.jsx (initializes `filterAuthor` + `filterSubject` from URL)
- [x] Added `useSearchParams` URL param reading to ReviewFlashcards.jsx (same pattern)
- [x] Deep-linking now supported: `/dashboard/notes?author=xxx&subject=Income Tax` auto-filters

### Help & Guide Page (Feb 7, 2026)
- [x] Created `src/data/helpContent.js` — Structured content data (6 tabs, 24 sections, 10 FAQs)
- [x] Created `src/pages/dashboard/Help.jsx` — Help page with tabs, search, collapsible sections, back-to-top
- [x] URL deep linking via `useSearchParams` (e.g., `/dashboard/help?tab=study-groups`)
- [x] Search filters across all tabs and FAQs simultaneously
- [x] Custom expand/collapse sections using Card components (no accordion dependency)
- [x] Added "Help & Guide" to ProfileDropdown.jsx (above Sign Out separator)
- [x] Added "Help & Guide" to NavMobile.jsx (after My Achievements)
- [x] Added route in App.jsx (`/dashboard/help`)
- [x] Added `scrollbar-hide` CSS utility to index.css

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
- [x] Shows PUBLIC badges only (private badges hidden via frontend filter — managed in My Achievements)
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

### 2026-02-08 Session (Flashcard Text-to-Speech)
- Created `useSpeech.js` hook using Web Speech API with sentence chunking to prevent Chrome/Edge 15-second TTS cutoff bug
- Text is split by sentence-ending punctuation (. ! ? \n) and spoken sequentially; fallback to full text if no punctuation
- Voice and speed preferences persisted to localStorage (`recall-tts-voice-uri`, `recall-tts-rate`)
- `SpeakButton` uses `e.stopPropagation()` (established pattern for nested clickable elements)
- `SpeechSettings` uses existing Radix Popover component with voice grouped by language code
- Voices loaded via `voiceschanged` event listener (Chrome loads voices async)
- Speech auto-cancels via `useEffect` on `[currentIndex, showAnswer]` — covers all card transitions
- No database changes needed — future language-per-deck feature would add `language` column to `flashcard_decks`
- Build verified clean: `npx vite build` passes with no errors

### 2026-02-08 Session (File Structure Refactor)
- Root cause: `/dashboard/browse-notes` bug from mismatched file name (`BrowseNotes.jsx`) vs route path (`/dashboard/notes`)
- Moved 9 page-level components from `src/components/` to `src/pages/` to enforce convention: pages=routed, components=reusable
- Fixed only route missing `/dashboard` prefix: `/notes/edit/:id` → `/dashboard/notes/edit/:id`
- Added `LegacyNoteEditRedirect` component for old bookmark compatibility
- Added route-to-file mapping comment (27 routes) in App.jsx for quick reference
- Deleted dead `components/notes/index.jsx` (old "Coming Soon" placeholder, never imported)
- Only 3 files needed import path updates: App.jsx, ReviewSession.jsx, NoteDetail.jsx
- All moved files use `@/` alias imports so internal imports didn't break
- `FlashcardCard.jsx` stays in `components/flashcards/` (reusable component, not a page)
- Empty directories removed: `components/notes/`, `components/admin/`, `components/professor/`
- Build verified clean: `npx vite build` passes with no errors

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
