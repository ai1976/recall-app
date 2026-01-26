# RECALL APP - FILE STRUCTURE
**Structure as on 17 Jan 2026**
recall-app
├── .env.local
├── .gitignore
├── components.json
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
│   │   │   └── AnonymousStats.jsx
│   │   ├── flashcards
│   │   │   ├── FlashcardCreate.jsx
│   │   │   ├── MyFlashcards.jsx
│   │   │   └── StudyMode.jsx
│   │   ├── layout
│   │   │   └── Navigation.jsx
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
│   │   ├── useBadges.js
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
- `src/components/notes/NoteUpload.jsx` - Upload note page ⭐
- `src/components/notes/NoteDetails.jsx` - View note details
- `src/components/notes/NoteEdit.jsx` - Edit note

### **Flashcards:**
- `src/components/flashcards/FlashcardCreate.jsx` - Create flashcard ⭐
- `src/components/flashcards/MyFlashcards.jsx` - User's flashcards
- `src/components/flashcards/StudyMode.jsx` - Review session

### **Admin:**
- `src/components/admin/AdminDashboard.jsx` - Admin panel
- `src/components/admin/SuperAdminDashboard.jsx` - Super admin panel

### **Professor:**
- `src/components/professor/ProfessorTools.jsx` - Bulk upload, etc.

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

**END OF FILE STRUCTURE DOCUMENT**