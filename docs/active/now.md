# NOW - Current Development Status

**Last Updated:** 2026-02-06
**Current Phase:** Phase 1B Complete - Author Profile Page & Clickable Names

---

## Just Completed ✅

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

---

## Known Issues

None currently.

---

## Session Notes

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
