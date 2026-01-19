# Changelog

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