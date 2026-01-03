# RECALL APP - FILE STRUCTURE

**Last Updated:** December 22, 2025
**Purpose:** Quick reference for file locations to avoid path confusion

---

## 📁 ROOT LEVEL
```
recall-app/
├── node_modules/
├── public/
│   └── vite.svg
├── src/
├── .gitignore
├── package.json
├── vite.config.js
├── index.html
├── README.md
├── CONTEXT_FOR_CLAUDE.md
├── APPROVED_DECISIONS.md
├── SESSION_SUMMARY.md
└── FILE_STRUCTURE.md (this file)
```

---

## 📁 SRC FOLDER STRUCTURE
```
src/
├── assets/
├── components/
│   ├── admin/
│   │   ├── AdminDashboard.jsx
│   │   └── SuperAdminDashboard.jsx
│   ├── flashcards/
│   │   ├── FlashcardCreate.jsx ⭐ (EDITED: Dec 22)
│   │   ├── MyFlashcards.jsx
│   │   └── StudyMode.jsx ⭐ (EDITED: Jan 3 - now accepts flashcards prop)
│   ├── notes/
│   │   ├── index.jsx
│   │   ├── NoteDetails.jsx
│   │   ├── NoteEdit.jsx
│   │   └── NoteUpload.jsx ⭐ (EDITED: Dec 22)
│   ├── professor/
│   │   └── ProfessorTools.jsx
│   ├── ui/ (shadcn components)
│   │   ├── button.jsx
│   │   ├── card.jsx
│   │   ├── input.jsx
│   │   ├── label.jsx
│   │   ├── select.jsx
│   │   ├── switch.jsx
│   │   ├── textarea.jsx
│   │   ├── command.jsx
│   │   ├── popover.jsx
│   │   ├── toast.jsx
│   │   └── ... (other UI components)
│   ├── Login.jsx
│   └── Navigation.jsx
├── contexts/
│   └── AuthContext.jsx
├── data/
├── hooks/
│   └── use-toast.js
├── lib/
│   ├── supabase.js
│   └── utils.js
├─├── pages/
│   ├── Home.jsx
│   ├── Dashboard.jsx ⭐ (EDITED: Jan 3 - button navigation)
│   ├── Login.jsx
│   ├── Signup.jsx
│   ├── ForgotPassword.jsx
│   ├── ResetPassword.jsx
│   ├── TermsOfService.jsx
│   ├── PrivacyPolicy.jsx
│   └── dashboard/
│       ├── my-contributions.jsx
│       ├── my-notes.jsx
│       ├── notes.jsx (Browse Notes)
│       ├── progress.jsx
│       ├── review-flashcards.jsx
│       ├── review-session.jsx ⭐ (NEW: Jan 3 - dedicated review route)
│       └── Review.jsx
├── store/
├── utils/
├── App.jsx
├── main.jsx
└── index.css
```

---

## 🎯 KEY FILE LOCATIONS

### **Authentication:**
- `src/contexts/AuthContext.jsx` - Auth state management
- `src/components/Login.jsx` - Login component
- `src/pages/Login.jsx` - Login page
- `src/pages/Signup.jsx` - Signup page

### **Navigation:**
- `src/components/Navigation.jsx` - Main navigation bar

### **Dashboard:**
- `src/pages/Dashboard.jsx` - Main dashboard (student-first design)
- `src/pages/dashboard/my-contributions.jsx` - User's stats
- `src/pages/dashboard/my-notes.jsx` - User's personal notes
- `src/pages/dashboard/notes.jsx` - Browse public notes
- `src/pages/dashboard/progress.jsx` - Analytics page

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

### **Common Confusion Points:**
- ⚠️ Some components are in `src/components/`
- ⚠️ Some pages are in `src/pages/`
- ⚠️ Dashboard pages are in `src/pages/dashboard/`
- ⚠️ There are TWO Login.jsx files (component vs page)

### **File Naming Convention:**
- Pages (routes): PascalCase or kebab-case (e.g., `Dashboard.jsx`, `my-notes.jsx`)
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

**END OF FILE STRUCTURE DOCUMENT**