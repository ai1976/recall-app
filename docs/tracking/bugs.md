# Bug Tracking

## Resolved Bugs

### [Feb 6, 2026] Groups Link Not Working on Production Vercel — Duplicate HTML in index.html
- **Files:** index.html
- **Issue:** Groups navigation link worked on localhost but refreshed to Dashboard on production Vercel. Hard refresh and browser restart did not help.
- **Root Cause:** `index.html` had duplicate HTML structure — lines 24-29 were a copy of lines 18-23 (`</head>`, `<body>`, `<div id="root">`, `<script>`, `</body>`, `</html>`). This created two `<div id="root">` elements in the DOM. Vite's dev server was forgiving, but the production build copied the malformed HTML into `dist/index.html`, confusing React Router's client-side navigation.
- **Solution:** Removed duplicate lines 24-29 from `index.html`. Rebuilt to verify clean `dist/index.html`.
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Blank Page — NavDesktop/NavMobile Missing Props
- **Files:** NavDesktop.jsx, NavMobile.jsx
- **Issue:** App rendered blank white page after adding notification props to ActivityDropdown
- **Root Cause:** `deleteNotification` and `refetchNotifications` were passed from Navigation.jsx but never destructured in NavDesktop/NavMobile prop definitions
- **Console Error:** `Uncaught ReferenceError: deleteNotification is not defined at NavDesktop (NavDesktop.jsx:203:11)`
- **Solution:** Added `deleteNotification` and `refetchNotifications` to prop destructuring in both components
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Notifications RPC Fails — `column n.title does not exist`
- **Files:** SQL 14 (notification RPCs), SQL 25 (fix)
- **Issue:** `get_recent_notifications` RPC returned 400 error
- **Root Cause:** `notifications` table pre-existed from Phase 1B with different schema (no `title`, `metadata`, `is_read` columns). `CREATE TABLE IF NOT EXISTS` in SQL #13 skipped creation.
- **Solution:** SQL #25 — `ALTER TABLE` to add missing columns + backfill title from message
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Ambiguous `group_id` in `get_pending_group_invites`
- **Files:** SQL 19, SQL 25 (fix)
- **Issue:** MyGroups page error: `column reference "group_id" is ambiguous`
- **Root Cause:** Subquery `WHERE group_id = sg.id` conflicted with `RETURNS TABLE` which also declares `group_id`
- **Solution:** Aliased subquery table as `sub`: `WHERE sub.group_id = sg.id`
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Invitation Fails — `notifications_type_check` Constraint Violation
- **Files:** SQL 26 (fix)
- **Issue:** `invite_to_group()` failed with `new row for relation "notifications" violates check constraint "notifications_type_check"`
- **Root Cause:** Existing CHECK constraint on `type` column only allowed original types, not `group_invite`
- **Solution:** SQL #26 — DROP and recreate constraint with `group_invite` added
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] React Key Warning — Pending Invitations in GroupDetail
- **Files:** GroupDetail.jsx
- **Issue:** Console warning: `Each child in a list should have a unique "key" prop`
- **Root Cause:** JSX used `invite.id` but SQL returns `invite.membership_id` as the field name
- **Solution:** Changed `key={invite.id}` → `key={invite.membership_id}` (and matching cancel/disable refs)
- **Status:** ✅ RESOLVED

### [Feb 5, 2026] Back Button Navigates to Dashboard Instead of Previous Page
- **Files:** NoteDetail.jsx, ReviewBySubject.jsx, ReviewSession.jsx
- **Issue:** Back button always went to `/dashboard` even when user came from another page (e.g., Browse Notes)
- **Root Cause:** Hardcoded `navigate('/dashboard')` instead of browser history navigation
- **Solution:** Changed to `navigate(-1)` with fallback: `if (window.history.length > 1) { navigate(-1) } else { navigate('/dashboard') }`
- **Status:** ✅ RESOLVED

### [Feb 5, 2026] Subject and Topic Filters Are Independent
- **Files:** MyNotes.jsx, MyFlashcards.jsx, BrowseNotes.jsx, ReviewFlashcards.jsx
- **Issue:** Selecting a Subject did not filter the Topic dropdown - users could select topics unrelated to subject
- **Root Cause:** Topic dropdown was populated with all available topics regardless of subject selection
- **Solution:** Added useEffect that filters `availableTopics` based on `filterSubject` selection, resets topic if not in filtered list
- **Status:** ✅ RESOLVED

### [Feb 3, 2026] Cursor Jumping in Inline Flashcard Editing
- **File:** MyFlashcards.jsx
- **Issue:** Cursor would jump to beginning of textarea on every keystroke during inline editing
- **Root Cause:** FlashcardCard component was defined inside MyFlashcards, causing re-creation on every render
- **Solution:** Extracted FlashcardCard to separate file with props and useCallback handlers
- **Status:** ✅ RESOLVED

### [Feb 3, 2026] Cannot Replace Uploaded Image/PDF in Note Edit
- **File:** NoteEdit.jsx
- **Issue:** Once an image/PDF was uploaded to a note, there was no way to replace it
- **Solution:** Added file replacement feature with preview, validation, upload, and old file deletion
- **Status:** ✅ RESOLVED

---
