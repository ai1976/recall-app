# Bug Tracking

## Resolved Bugs

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
