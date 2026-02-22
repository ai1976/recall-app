# RECALL APP - FILE STRUCTURE
**Structure as on 22 Feb 2026** (last updated: Push Notifications Phase 3)
recall-app
├── supabase
│   └── functions
│       ├── _shared                        ← shared helpers (NOT deployed as functions)
│       │   ├── supabaseAdmin.ts           ← service-role Supabase client
│       │   └── sendPush.ts                ← VAPID web-push utility (sendPushToUsers)
│       ├── push-subscribe
│       │   └── index.ts                   ← save device push subscription
│       ├── push-unsubscribe
│       │   └── index.ts                   ← soft-delete push subscription
│       ├── notify-friend-event
│       │   └── index.ts                   ← instant push for friend_request/accepted
│       └── notify-content-created
│           └── index.ts                   ← update-in-place aggregation + push
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
│   │   ├── badges
│   │   │   ├── BadgeCard.jsx
│   │   │   ├── BadgeIcon.jsx
│   │   │   └── BadgeToast.jsx
│   │   ├── dashboard
│   │   │   ├── ActivityFeed.jsx
│   │   │   └── AnonymousStats.jsx
│   │   ├── flashcards
│   │   │   ├── FlashcardCard.jsx
│   │   │   ├── SpeakButton.jsx
│   │   │   └── SpeechSettings.jsx
│   │   ├── layout
│   │   │   ├── ActivityDropdown.jsx
│   │   │   ├── FriendsDropdown.jsx
│   │   │   ├── NavDesktop.jsx
│   │   │   ├── Navigation.jsx
│   │   │   ├── NavMobile.jsx
│   │   │   ├── PageContainer.jsx
│   │   │   └── ProfileDropdown.jsx
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
│   │   └── helpContent.js
│   ├── hooks
│   │   ├── use-toast.js
│   │   ├── useActivityFeed.js
│   │   ├── useBadges.js
│   │   ├── useFriendRequestCount.js
│   │   ├── useNotifications.js
│   │   ├── useOCR.js
│   │   ├── useRole.js
│   │   └── useSpeech.js
│   ├── index.css
│   ├── lib
│   │   ├── supabase.js
│   │   └── utils.js
│   ├── main.jsx
│   ├── pages
│   │   ├── admin
│   │   │   ├── AdminDashboard.jsx
│   │   │   ├── BulkUploadTopics.jsx
│   │   │   └── SuperAdminDashboard.jsx
│   │   ├── auth
│   │   │   ├── ForgotPassword.jsx
│   │   │   ├── Login.jsx
│   │   │   ├── ResetPassword.jsx
│   │   │   └── Signup.jsx
│   │   ├── dashboard
│   │   │   ├── Content
│   │   │   │   ├── BrowseNotes.jsx
│   │   │   │   ├── FlashcardCreate.jsx
│   │   │   │   ├── MyContributions.jsx
│   │   │   │   ├── MyFlashcards.jsx
│   │   │   │   ├── MyNotes.jsx
│   │   │   │   ├── NoteDetail.jsx
│   │   │   │   ├── NoteEdit.jsx
│   │   │   │   └── NoteUpload.jsx
│   │   │   ├── Friends
│   │   │   │   ├── FindFriends.jsx
│   │   │   │   ├── FriendRequests.jsx
│   │   │   │   └── MyFriends.jsx
│   │   │   ├── Groups
│   │   │   │   ├── CreateGroup.jsx
│   │   │   │   ├── GroupDetail.jsx
│   │   │   │   └── MyGroups.jsx
│   │   │   ├── Profile
│   │   │   │   ├── AuthorProfile.jsx
│   │   │   │   ├── MyAchievements.jsx
│   │   │   │   └── ProfileSettings.jsx
│   │   │   ├── BulkUploadFlashcards.jsx
│   │   │   ├── Help.jsx
│   │   │   └── Study
│   │   │       ├── Progress.jsx
│   │   │       ├── ReviewBySubject.jsx
│   │   │       ├── ReviewFlashcards.jsx
│   │   │       ├── ReviewSession.jsx
│   │   │       └── StudyMode.jsx
│   │   ├── professor
│   │   │   └── ProfessorTools.jsx
│   │   │   (legacy — /professor/tools redirects to /dashboard/bulk-upload)
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

## 🎯 KEY FILE LOCATIONS

### **Authentication:**
- `src/contexts/AuthContext.jsx` - Auth state management
- `src/components/pages/auth/Login.jsx` - Login page
- `src/components/pages/auth/Signup.jsx` - Signup page

### **Navigation:**
- `src/components/layout/Navigation.jsx` - Main navigation bar

### **Dashboard:**
- `src/pages/Dashboard.jsx` - Main dashboard (student-first design)
- `src/pages/dashboard/Content/MyContributions.jsx` - User's stats
- `src/pages/dashboard/Content/MyNotes.jsx` - User's personal notes
- `src/pages/dashboard/Content/BrowseNotes.jsx` - Browse public notes
- `src/pages/dashboard/Study/Progress.jsx` - Analytics page

### **Notes:**
- `src/pages/dashboard/Content/NoteUpload.jsx` - Upload note page
- `src/pages/dashboard/Content/NoteDetail.jsx` - View note details
- `src/pages/dashboard/Content/NoteEdit.jsx` - Edit note

### **Flashcards:**
- `src/pages/dashboard/Content/FlashcardCreate.jsx` - Create flashcard
- `src/pages/dashboard/Content/MyFlashcards.jsx` - User's flashcards
- `src/pages/dashboard/Study/StudyMode.jsx` - Review session
- `src/components/flashcards/FlashcardCard.jsx` - Reusable flashcard display card
- `src/components/flashcards/SpeakButton.jsx` - TTS volume icon button
- `src/components/flashcards/SpeechSettings.jsx` - Voice/speed settings popover
- `src/hooks/useSpeech.js` - Web Speech API hook (TTS)

### **Admin:**
- `src/pages/admin/AdminDashboard.jsx` - Admin panel
- `src/pages/admin/SuperAdminDashboard.jsx` - Super admin panel
- `src/pages/admin/BulkUploadTopics.jsx` - Bulk upload subjects & topics (admin only)

### **Bulk Upload:**
- `src/pages/dashboard/BulkUploadFlashcards.jsx` - Bulk upload flashcards via CSV (all users)
- `src/pages/professor/ProfessorTools.jsx` - Legacy (redirects to BulkUploadFlashcards)

### **Configuration:**
- `src/lib/supabase.js` - Supabase client setup
- `vite.config.js` - Vite configuration
- `package.json` - Dependencies

---

## 📝 NOTES

### **Recent Changes (Dec 22, 2025):**
- ✅ Fixed topic dropdown scrolling in:
  - `src/components/notes/NoteUpload.jsx`
  - `src/components/flashcards/FlashcardCreate.jsx`

### **File Naming Convention:**
- Pages (routes): PascalCase (e.g., `Dashboard.jsx`, `MyNotes.jsx`)
- Components: PascalCase (e.g., `Navigation.jsx`, `NoteUpload.jsx`)
- Utilities: camelCase (e.g., `supabase.js`, `use-toast.js`)

---

## 🔄 HOW TO UPDATE THIS FILE

When you add/move files:
1. Open this file in VS Code
2. Find the relevant section
3. Add the new file with appropriate emoji/marker
4. Add date in "Recent Changes" section
5. Save and commit to Git

Example:
```markdown
### **Recent Changes (Dec 23, 2025):**
- ✅ Added new component: `src/components/flashcards/BulkUpload.jsx`
```

---

## 💾 GIT COMMANDS FOR THIS FILE

**After updating:**
```bash
git add FILE_STRUCTURE.md
git commit -m "Update file structure documentation"
git push
```
## 🔧 RECENTLY MODIFIED (Jan 2, 2026)

### **Critical Bug Fixes & Feature Additions:**
- ✅ src/components/flashcards/MyFlashcards.jsx (Delete Group + Edit Group Info)
- ✅ src/components/professor/ProfessorTools.jsx (UTF-8 CSV encoding)

### **New Features:**
- ✅ Delete entire group button (cascade delete all cards in batch)
- ✅ Edit group info dialog (update course/subject/topic/description)
- ✅ UTF-8 CSV encoding support (₹ symbol displays correctly)

### **Bug Fixes:**
- ✅ Fixed shadcn Select crash (replaced with native HTML select)
- ✅ Fixed CSV encoding (UTF-8 BOM + explicit FileReader encoding)
- ✅ Fixed Edit dialog blank screen issue

---
## 🔧 RECENTLY MODIFIED (Jan 3, 2026 - Evening)

### **Review Session Route & StudyMode Props:**
- ✅ src/pages/dashboard/review-session.jsx (NEW - dedicated review route)
- ✅ src/components/flashcards/StudyMode.jsx (accepts flashcards prop)
- ✅ src/pages/Dashboard.jsx (button navigation updated)
- ✅ src/App.jsx (added ReviewSession route)

### **New Features:**
- ✅ Dedicated review session for due cards only
- ✅ StudyMode flexible: accepts props OR fetches data
- ✅ Backwards compatible with existing routes
- ✅ Clean separation: Review Session vs Browse Flashcards

## 🗄️ DATABASE DOCUMENTATION (NEW)

### **Root Level Files:**
- DATABASE_SCHEMA.md (NEW - Jan 9, 2026)
  - Complete schema reference
  - Table relationships
  - Column definitions
  - Schema change log

### **Supabase SQL Folders:**
- SCHEMA/ (12 queries)
  - All Database Tables
  - All Columns for Major Tables
  - Add Creator ID to Flashcards (NEW)
  - Backfill Creator ID for Existing Flashcards (NEW)
  - Create Friendships Table (NEW)
  - Add Indexes for Friendships Table (NEW)
  - Create Content Creators Table (NEW)
  - Link Flashcards to Content Creators (NEW)

- DATA/ (queries for viewing data)
- DIAGNOSTIC/ (troubleshooting queries)
- FIX/ (one-time data corrections)
- REPORTS/ (analytics queries)

---

## 📋 RECENT ADDITIONS (Jan 9, 2026)

### Database:
- ✅ friendships table (social features)
- ✅ content_creators table (revenue tracking)
- ✅ flashcards.creator_id (user attribution)
- ✅ flashcards.content_creator_id (financial attribution)

### Documentation:
- ✅ DATABASE_SCHEMA.md (new file)
- ✅ APPROVED_DECISIONS.md (3 new entries)
- ✅ CONTEXT_FOR_CLAUDE.md (updated status)

---
---
## 🔧 RECENTLY MODIFIED (Feb 3, 2026)

### **Bug Fixes:**
- ✅ src/components/notes/NoteEdit.jsx (Image/PDF replacement feature)
- ✅ src/components/flashcards/MyFlashcards.jsx (Cursor jumping fix)

### **New Files:**
- ✅ src/components/flashcards/FlashcardCard.jsx (NEW - extracted component)

### **Changes:**
- ✅ NoteEdit.jsx: Added ability to replace uploaded image/PDF with preview, validation, and old file cleanup
- ✅ MyFlashcards.jsx: Refactored to use external FlashcardCard component with isolated edit state
- ✅ FlashcardCard.jsx: Standalone flashcard display/edit component (fixes cursor jumping anti-pattern)

---


---
## 🔧 RECENTLY MODIFIED (Feb 6, 2026) - Study Groups

### **New Files:**
- ✅ src/pages/dashboard/Groups/MyGroups.jsx (NEW - Study groups list)
- ✅ src/pages/dashboard/Groups/CreateGroup.jsx (NEW - Create group form)
- ✅ src/pages/dashboard/Groups/GroupDetail.jsx (NEW - Group detail with members/content)
- ✅ docs/database/study-groups/ (8 SQL files - schema, RLS, functions)

### **Changes:**
- ✅ src/App.jsx (Added 3 Groups routes)
- ✅ src/components/layout/NavDesktop.jsx (Added Groups nav link)
- ✅ src/components/layout/NavMobile.jsx (Added Study Groups section)
- ✅ src/pages/dashboard/Content/NoteUpload.jsx (Study Groups visibility + group multi-select)
- ✅ src/pages/dashboard/Content/FlashcardCreate.jsx (Study Groups visibility + group multi-select)
- ✅ src/pages/dashboard/Content/BrowseNotes.jsx (Merge group-shared notes)
- ✅ src/pages/dashboard/Study/ReviewFlashcards.jsx (Merge group-shared decks)

---
## 🔧 RECENTLY MODIFIED (Feb 7, 2026) - Allow All Members to Share Content

### **New SQL Files:**
- ✅ docs/database/study-groups/27_FIX_allow_all_members_to_share_content.sql (NEW)

### **Changes:**
- ✅ src/pages/dashboard/Groups/GroupDetail.jsx (Share button for all members, delete own/admin logic)

---
## 🔧 RECENTLY MODIFIED (Feb 6, 2026) - Invitation Flow + Notifications Backend

### **New SQL Files:**
- ✅ docs/database/study-groups/13_SCHEMA_notifications_table.sql (NEW)
- ✅ docs/database/study-groups/14_FUNCTIONS_notification_rpcs.sql (NEW - 5 RPCs + cleanup)
- ✅ docs/database/study-groups/15_SCHEMA_add_invitation_status.sql (NEW)
- ✅ docs/database/study-groups/16_FUNCTION_invite_to_group_v2.sql (NEW)
- ✅ docs/database/study-groups/17_FUNCTION_accept_group_invite.sql (NEW)
- ✅ docs/database/study-groups/18_FUNCTION_decline_group_invite.sql (NEW)
- ✅ docs/database/study-groups/19_FUNCTION_get_pending_group_invites.sql (NEW)
- ✅ docs/database/study-groups/20_FUNCTION_get_user_groups_v2.sql (NEW)
- ✅ docs/database/study-groups/21_FUNCTION_get_group_detail_v2.sql (NEW)
- ✅ docs/database/study-groups/22_FUNCTION_get_browsable_notes_v2.sql (NEW)
- ✅ docs/database/study-groups/23_FUNCTION_get_browsable_decks_v2.sql (NEW)
- ✅ docs/database/study-groups/24_FUNCTION_leave_group_v2.sql (NEW)
- ✅ docs/database/study-groups/25_FIX_notifications_missing_columns_and_ambiguous_ref.sql (NEW)
- ✅ docs/database/study-groups/26_FIX_notifications_type_check_constraint.sql (NEW)

### **New Reference Doc:**
- ✅ docs/reference/STUDY_GROUPS.md (NEW - Complete groups + notifications logic reference)

### **Changes:**
- ✅ src/components/layout/ActivityDropdown.jsx (REWRITTEN - group_invite with inline Accept/Decline)
- ✅ src/components/layout/Navigation.jsx (Added deleteNotification, refetchNotifications props)
- ✅ src/components/layout/NavDesktop.jsx (Added new props + Network icon for Groups)
- ✅ src/components/layout/NavMobile.jsx (Added new props + Network icon for Groups)
- ✅ src/pages/dashboard/Groups/MyGroups.jsx (Added pending invitations section)
- ✅ src/pages/dashboard/Groups/GroupDetail.jsx (Invite flow, pending section, cancel invite)

---
## 🔧 RECENTLY MODIFIED (Feb 6, 2026) - Author Profile

### **New Files:**
- ✅ src/pages/dashboard/Profile/AuthorProfile.jsx (NEW - Author profile page)

### **Changes:**
- ✅ src/App.jsx (Added AuthorProfile route)
- ✅ src/pages/dashboard/Content/BrowseNotes.jsx (Clickable author names)
- ✅ src/pages/dashboard/Study/ReviewFlashcards.jsx (Clickable author names)
- ✅ src/pages/dashboard/Content/NoteDetail.jsx (Clickable author badge)
- ✅ src/pages/dashboard/Friends/FindFriends.jsx (Clickable user names)
- ✅ src/pages/dashboard/Friends/MyFriends.jsx (Clickable friend names)
- ✅ src/pages/dashboard/Content/MyContributions.jsx (Clickable upvoter names)

---

## 🔧 RECENTLY MODIFIED (Feb 7, 2026) - Help & Guide Page

### **New Files:**
- ✅ src/data/helpContent.js (NEW - Structured help content data)
- ✅ src/pages/dashboard/Help.jsx (NEW - Help & Guide page)

### **Changes:**
- ✅ src/App.jsx (Added Help import + route)
- ✅ src/components/layout/ProfileDropdown.jsx (Added Help & Guide menu item)
- ✅ src/components/layout/NavMobile.jsx (Added Help & Guide button)
- ✅ src/index.css (Added scrollbar-hide utility)

---

## 🔧 RECENTLY MODIFIED (Feb 8, 2026) - File Structure Refactor

### **Moved Files (pages out of components/):**
- ✅ `src/components/notes/NoteUpload.jsx` → `src/pages/dashboard/Content/NoteUpload.jsx`
- ✅ `src/components/notes/NoteDetail.jsx` → `src/pages/dashboard/Content/NoteDetail.jsx`
- ✅ `src/components/notes/NoteEdit.jsx` → `src/pages/dashboard/Content/NoteEdit.jsx`
- ✅ `src/components/flashcards/FlashcardCreate.jsx` → `src/pages/dashboard/Content/FlashcardCreate.jsx`
- ✅ `src/components/flashcards/MyFlashcards.jsx` → `src/pages/dashboard/Content/MyFlashcards.jsx`
- ✅ `src/components/flashcards/StudyMode.jsx` → `src/pages/dashboard/Study/StudyMode.jsx`
- ✅ `src/components/admin/SuperAdminDashboard.jsx` → `src/pages/admin/SuperAdminDashboard.jsx`
- ✅ `src/components/admin/AdminDashboard.jsx` → `src/pages/admin/AdminDashboard.jsx`
- ✅ `src/components/professor/ProfessorTools.jsx` → `src/pages/professor/ProfessorTools.jsx`

### **Deleted:**
- ✅ `src/components/notes/index.jsx` (dead placeholder)

### **Route Fix:**
- ✅ `/notes/edit/:id` → `/dashboard/notes/edit/:id` (added missing `/dashboard` prefix)
- ✅ Legacy redirect from old path preserved

---

## 🔧 RECENTLY MODIFIED (Feb 8, 2026) - Flashcard Text-to-Speech

### **New Files:**
- ✅ src/hooks/useSpeech.js (NEW - Web Speech API hook with sentence chunking + localStorage persistence)
- ✅ src/components/flashcards/SpeakButton.jsx (NEW - Reusable volume icon button with pulse animation)
- ✅ src/components/flashcards/SpeechSettings.jsx (NEW - Voice/speed settings popover)

### **Changes:**
- ✅ src/pages/dashboard/Study/StudyMode.jsx (Added TTS: SpeakButton on question + answer sides, SpeechSettings popover)

---

## 🔧 RECENTLY MODIFIED (Feb 9, 2026) - Profile Completion Modal

### **Changes:**
- ✅ src/pages/Dashboard.jsx (Non-dismissible profile completion modal when course/institution is NULL)
- ✅ src/pages/dashboard/Profile/ProfileSettings.jsx (Course label → "Primary Course")
- ✅ src/components/ui/dialog.jsx (Added `hideCloseButton` prop to DialogContent)

---

## 🔧 RECENTLY MODIFIED (Feb 8, 2026) - FindFriends Privacy & Profile Settings

### **New Files:**
- ✅ src/pages/dashboard/Profile/ProfileSettings.jsx (NEW - Profile settings page: name, course, institution)

### **Changes:**
- ✅ src/pages/dashboard/Friends/FindFriends.jsx (Masked emails, added institution + joined year, name-only search)
- ✅ src/App.jsx (Added ProfileSettings import + /dashboard/settings route)
- ✅ src/components/layout/ProfileDropdown.jsx (Added Settings menu item with gear icon)
- ✅ src/components/layout/NavMobile.jsx (Added Settings link to mobile hamburger menu)

---

---
## 🔧 RECENTLY MODIFIED (Feb 21, 2026) - Phase A: Professor Multi-Course

### New Files:
- ✅ `src/contexts/CourseContext.jsx` (NEW — multi-course teaching context for professors/admins)
- ✅ `src/components/layout/CourseSwitcher.jsx` (NEW — indigo pill dropdown in nav bar)

### Changes:
- ✅ `src/App.jsx` (Added CourseContextProvider import + wrapping)
- ✅ `src/components/layout/NavDesktop.jsx` (Added CourseSwitcher to right section)
- ✅ `src/components/layout/NavMobile.jsx` (Added Course Context section in hamburger sheet)
- ✅ `src/pages/dashboard/Profile/ProfileSettings.jsx` (Added Teaching Areas card for professors/admins)
- ✅ `src/pages/dashboard/Profile/AuthorProfile.jsx` (Shows teaching courses as indigo chips)
- ✅ `src/pages/Dashboard.jsx` (Class stats use activeCourse from context; reactive useEffect for course switch)

### New Key File Locations:
- **Course Context:** `src/contexts/CourseContext.jsx`
- **Course Switcher UI:** `src/components/layout/CourseSwitcher.jsx`

**END OF FILE STRUCTURE DOCUMENT**