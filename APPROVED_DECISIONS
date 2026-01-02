# APPROVED DECISIONS - DO NOT CHANGE WITHOUT EXPLICIT APPROVAL

**Last Updated:** January 2, 2026

---

## ✅ APPROVED & LOCKED - DO NOT MODIFY

### Tech Stack

**Status:** ✅ LOCKED  
**Approved:** December 2025

- Frontend: React 18 + Vite
- Backend: Supabase (PostgreSQL + Auth + Storage)
- Hosting: Vercel (free tier)
- OCR: Tesseract.js (client-side, free)
- Email: Resend (free tier)
- Analytics: PostHog (free tier)
- Error Tracking: Sentry (free tier)

**REASON:** These use free tiers, work well together, and don't require coding experience to set up.

---

### Four-Tier Role System

**Status:** ✅ LOCKED  
**Approved:** December 2025

**Hierarchy:**
1. Super Admin (You - only one person)
2. Admin (Trusted team members - Phase 2+)
3. Professor (Faculty contributors)
4. Student (Regular users)

**REASON:** Security, scalability, proper delegation as platform grows.

---

### Two-Tier Content Model

**Status:** ✅ LOCKED  
**Approved:** December 2025

- User has `primary_course_level` (what they're studying)
- Content has `target_course` (who it's for)
- These are INDEPENDENT

**REASON:** Allows professors to contribute to multiple courses, seniors to help juniors.

---

### Phase 0.5: Professor-Seeded Content

**Status:** ✅ LOCKED  
**Approved:** December 2025

- 220 flashcards minimum
- 35 notes minimum
- 2-3 professors
- Budget: ₹1,800
- Happens BEFORE student launch

**REASON:** Solves cold start problem - students see value immediately on Day 1.

---

### Budget for Phase 1

**Status:** ✅ LOCKED  
**Maximum:** ₹2,567

**Breakdown:**
- Professor incentives: ₹1,500
- Domain: ₹67
- Student incentives: ₹1,000
- Everything else: Free tiers

**REASON:** Bootstrapped launch, prove concept before spending more.

---

### Search and Filter in Super Admin Dashboard

**Status:** ✅ LOCKED  
**Approved:** December 2025

**Features:**
- Search by name or email
- Filter by role (all/student/professor/admin/super_admin)
- Real-time filtering with result count
- Works seamlessly with existing user management

**REASON:** Essential for managing 100+ users efficiently. Scales from Phase 1 (20 users) to Phase 4 (4200+ users).

---

### Bulk Upload Feature Access

**Status:** ✅ LOCKED  
**Approved:** December 2025

- Feature name: "Bulk Upload" (not "Professor Tools")
- Available to: ALL authenticated users (student/professor/admin/super_admin)
- Location: Top navigation + link at bottom of Create Flashcard page

**REASON:** Students creating content for juniors benefit from bulk upload. Democratizes content creation while maintaining quality.

---

### Course Selection in Signup

**Status:** ✅ LOCKED  
**Approved:** December 2025

**Pre-defined options:**
- CA: Foundation, Intermediate, Final
- CMA: Foundation, Intermediate, Final
- CS: Foundation, Executive, Professional
- "Other (Custom)" with text field

**REASON:** Covers 90% of users with pre-defined list, 10% with custom option. Flexible without being overwhelming.

---

### Dual-Mode Navigation (Study/Create)

**Status:** ✅ LOCKED  
**Approved:** December 16, 2025

**Structure:**
- Dashboard (overview)
- Study dropdown:
  - Review Flashcards
  - Browse Notes
  - My Progress
- Create dropdown:
  - Upload Note
  - Create Flashcard
  - Bulk Upload
  - My Contributions
- Admin tools (role-based: Admin Dashboard, Super Admin)

**Navigation Type:** Dropdown menus (desktop), Expandable sections (mobile)

**REASON:** Matches student-first, creator-optional philosophy. Clear separation between consuming content (Study) and creating content (Create). Scales well as features are added.

---

### Real-Time Dashboard Statistics

**Status:** ✅ LOCKED  
**Approved:** December 16, 2025

**Features:**
- Notes count: Fetched from database in real-time
- Flashcards count: Fetched from database in real-time
- Study streak: Calculated from reviews table
- All stats update automatically when data changes

**Implementation:**
- Dashboard.jsx fetches counts on component mount
- Uses Supabase queries with user_id filter
- Loading state while fetching
- Error handling for failed queries

**REASON:** Users see actual progress, not fake numbers. Builds trust, motivation, and accountability. Essential for gamification features.

---

### Study Streak Calculation Algorithm

**Status:** ✅ LOCKED  
**Approved:** December 16, 2025

**Algorithm:**
1. Fetch all review dates for user
2. Extract unique dates (ignore time)
3. Check if most recent review was today OR yesterday
4. If no: streak = 0 (broken)
5. If yes: count consecutive days backward
6. Return streak count

**Example:**
- Reviews on: Dec 16, Dec 15, Dec 14, Dec 13
- Today: Dec 16
- Result: 4-day streak

- Reviews on: Dec 14, Dec 13, Dec 12
- Today: Dec 16 (last review 2 days ago)
- Result: 0 (streak broken)

**Grace Period:** 1 day (if last review was yesterday, streak continues)

**REASON:** Industry standard approach (Duolingo, Anki). 1-day grace period prevents unfair streak loss for users who study late at night.

---

### Accuracy Calculation Method

**Status:** ✅ LOCKED  
**Approved:** December 16, 2025

**Formula:**
```
Accuracy = (Easy + Medium) / Total Reviews × 100
```

**Quality Score Mapping:**
- Easy (quality = 5): Counts as correct (100% weight)
- Medium (quality = 3): Counts as correct (100% weight)
- Hard (quality = 1): Counts as incorrect (0% weight)

**Time Period:** Last 7 days (rolling window)

**Display:**
- My Progress page: Shows accuracy percentage
- Study session: Shows Easy/Medium/Hard counts
- Dashboard: Not shown (would clutter)

**Alternative (Phase 2):** Weighted accuracy
- Easy = 100% weight
- Medium = 75% weight
- Hard = 0% weight
- Formula: `(Easy × 1.0 + Medium × 0.75) / Total × 100`

**REASON:** Simple method is easier to understand for students. Matches Quizlet/Anki approach. Medium reviews still count as "remembered" since student recalled with effort. Weighted method available for Phase 2 if needed.

---

### Student-First, Creator-Optional Model

**Status:** ✅ LOCKED  
**Approved:** December 16, 2025

**Philosophy:**
- Users are STUDENTS by default (consume content first)
- Creator mode is OPTIONAL and PROGRESSIVE
- Navigation reflects this: Study features prominent, Create features accessible but secondary

**User Journey:**
1. Student signs up → Sees 220 professor flashcards
2. Reviews flashcards (Student Mode)
3. Gets inspired by quality content
4. Switches to Creator Mode
5. Uploads own notes/flashcards
6. Becomes active contributor

**Navigation Implementation:**
- Study menu = Primary (left side, prominent)
- Create menu = Secondary (middle, accessible)
- Clear visual separation

**Why This Works:**
- Solves cold start problem (professor content on Day 1)
- Reduces cognitive load (don't overwhelm with creation options)
- Natural progression: Consume → Inspired → Create
- Matches actual student behavior (study daily, create weekly)

**REASON:** Strategic pivot after identifying professor-seeded content solves cold start problem. Users no longer face empty platform. This model scales as content library grows.

---

### Dashboard Student-First Design

**Status:** ✅ LOCKED  
**Approved:** December 20, 2025

**Design Philosophy:**
- Users are STUDENTS by default (consume content first)
- Creator mode is OPTIONAL and PROGRESSIVE
- Dashboard priority: Review → Stats → Discover → Create

**Dashboard States:**
1. New User (0 reviews): Welcome onboarding with 3-step guide
2. Has Reviews Due: "Ready to Review" hero card with CTA
3. All Caught Up: Celebration state with practice options

**Stats Displayed (Student-Focus):**
- Cards Reviewed This Week (not created)
- Study Streak (days)
- Accuracy % (last 7 days)
- Total Cards Mastered (unique cards reviewed)
- Creator stats moved to small footer section

**Visual Hierarchy:**
1. Primary: "Start Review Session" or "All Caught Up!"
2. Secondary: Stats cards (student metrics)
3. Tertiary: Professor content discovery
4. Quaternary: "Want to Contribute?" section
5. Footer: Your Contributions (minimal)

**File Location:** src/pages/Dashboard.jsx (NOT components/)

**REASON:** Solves cold start problem with professor content. Students see value immediately. Matches product vision of student-first, creator-optional platform. Creates clear user journey: Consume → Inspired → Create.

---

### My Notes vs Browse Notes Separation

**Status:** ✅ LOCKED  
**Approved:** December 21, 2025

**Two distinct note browsing experiences:**

**My Notes (/dashboard/my-notes):**
- Shows ALL user's own notes (public + private)
- Accessible from My Contributions page
- Displays lock/globe icons for visibility status
- Full CRUD access to own notes

**Browse Notes (/dashboard/notes):**
- Shows ONLY public notes from all users
- Discovery and learning feature
- Professor attribution with 👨‍🏫 badge
- Read-only view of community content

**Navigation Flow:**
- My Contributions → "X Notes" card → My Notes (personal)
- Study dropdown → Browse Notes → Browse Notes (public)

**REASON:** Separates personal content management from community discovery. Users can manage their own notes privately while discovering public content from others.

---

### User Attribution System

**Status:** ✅ LOCKED  
**Approved:** December 21, 2025

**Implementation:**
- Navigation fetches `full_name` from profiles table via useEffect
- Browse Notes fetches notes + profiles separately, merges in JavaScript
- Display format: "👨‍🏫 {full_name}" for professors, "{full_name}" for students

**Database:**
- Foreign key: notes.user_id → profiles.id
- Join approach: Fetch separately + merge (more reliable than PostgREST joins)

**UI Display:**
- Top right: "{full_name} [role badge] Sign Out"
- Note cards: "{role emoji} {full_name} {date}"
- Mobile: Avatar with first letter + full name

**REASON:** Two-query approach more reliable than complex PostgREST join syntax. Provides proper attribution for professor-seeded content.

---

### Custom Course Support

**Status:** ✅ LOCKED  
**Approved:** December 21, 2025

**Features:**
- Default: Dropdown with 9 predefined courses (CA/CMA/CS x 3 levels)
- Toggle: "+ Add custom course" link reveals text input
- Validation: Requires either dropdown selection OR custom input
- Database: Stores in same `target_course` field

**UI Flow:**
1. User sees dropdown with predefined courses
2. Clicks "+ Add custom course" link
3. Dropdown hides, text input appears
4. "← Back to course list" returns to dropdown

**REASON:** Enables Phase 4 expansion to JEE/NEET/CFA/ACCA without database changes. 90% of users use predefined list, 10% need custom option.

---

### Navigation User Display

**Status:** ✅ LOCKED  
**Approved:** December 21, 2025

**Implementation:**
- Fetches user's full_name from profiles table on mount
- Desktop: Shows "{full_name} [role badge] Sign Out"
- Mobile: Shows avatar (first letter) + full_name + role
- Fallback: Shows email if full_name not available

**File:** src/components/Navigation.jsx
- Added useState for userName
- Added useEffect to fetch from profiles
- Added supabase import

**REASON:** Users should see their name, not just their role or email. Provides personalized experience.

---

### Filter Standardization Across All Pages

**Status:** ✅ LOCKED  
**Approved:** December 25, 2025

**Uniform filter layout pattern:**
- Search bar (full width at top)
- "Filters" label with icon
- Filter dropdowns in single row (2-3 columns responsive)
- Labels above each dropdown (not inline)
- Result count + "Clear All Filters" button
- Smart visibility (only show filters if options exist)

**Applied to:**
- Review Flashcards: 3 filters (Course, Subject, Author)
- Browse Notes: 3 filters (Course, Subject, Author)
- My Flashcards: 4 filters (Course, Subject, Topic, Date)
- My Notes: 5 filters (Course, Subject, Topic, Visibility, Date)

**REASON:** Consistent UX across entire app. Users learn pattern once, applies everywhere.

---

### Inline Edit for Flashcards

**Status:** ✅ LOCKED  
**Approved:** December 25, 2025

**Implementation:**
- Click Edit button → Card enters edit mode
- Editable text areas for front/back
- Save/Cancel buttons appear
- Blue ring visual feedback
- Toast notifications on success/error
- No separate edit page needed

**File:** src/components/flashcards/MyFlashcards.jsx

**REASON:** Fast, intuitive UX. No page navigation needed. Matches flashcard simplicity.

---

### Delete Functionality

**Status:** ✅ LOCKED  
**Approved:** December 25, 2025

**Features:**
- My Notes: Delete button with confirmation + cascade warning
- My Flashcards: Delete button with confirmation
- Toast notifications
- Optimistic UI updates (instant removal from display)

**Files:**
- src/pages/dashboard/my-notes.jsx
- src/components/flashcards/MyFlashcards.jsx

**REASON:** Essential CRUD operation. Users need ability to remove their content.

---

### Course Filter on Public Pages

**Status:** ✅ LOCKED  
**Approved:** December 25, 2025

**Added Course filter to:**
- Review Flashcards (Study → Review Flashcards)
- Browse Notes (Study → Browse Notes)

Previously only had Subject + Author filters.

**REASON:** Users studying multiple courses need to filter public content by course level. Matches filter pattern on My pages.

---

### Batch Tracking System

**Status:** ✅ LOCKED  
**Approved:** December 26, 2025

**Database Changes:**
- Added `batch_id` (UUID) column to flashcards table
- Added `batch_description` (TEXT) column to flashcards table
- Indexed on batch_id for performance

**Implementation:**
- Bulk Upload: All cards in one CSV get same batch_id + optional description
- Manual Create: Each card gets unique batch_id (no description)
- Grouped View: Groups flashcards by batch_id (not timestamp)
- Merge Feature: Select 2+ batches to combine into one

**REASON:** Solves the problem where toggling public/private caused batches to merge. Batch_id provides permanent, stable grouping that survives visibility changes.

**Migration Files:**
- 001_add_batch_tracking.sql (backfill existing cards)
- 002_split_52_cards_SIMPLE.sql (split user's old cards)

**Features:**
- Batch selection with checkboxes
- Merge dialog with optional renaming
- Batch description display
- Upload timestamp per batch
- "Make All Public/Private" per batch

---

### Terms of Service & Privacy Policy Pages

**Status:** ✅ LOCKED  
**Approved:** December 26, 2025

**Features:**
- Two separate legal pages (/terms-of-service, /privacy-policy)
- Razorpay payment gateway compliant
- GDPR/India IT Act 2000 compliant
- SEO optimized (separate pages, proper structure)
- Location: Pune, Maharashtra, India
- Email: recall@moreclassescommerce.com

**Content:**
- Terms: 14 sections (subscription, payments, refunds, user rights, etc.)
- Privacy: 14 sections (data collection, usage, security, user rights, etc.)

**Files:**
- src/pages/TermsOfService.jsx
- src/pages/PrivacyPolicy.jsx
- Routes added to App.jsx
- Footer links updated in Home.jsx

**REASON:** Required for Razorpay integration, legal compliance, and professional credibility. SEO-friendly separate pages instead of modals.

---

### VS Code Error Resolution Pattern

**Status:** ✅ LOCKED  
**Approved:** December 27, 2025

**React Hook Dependency Warnings:**
- Problem: Functions in useEffect dependency array cause infinite loops
- Solution: Add `// eslint-disable-next-line react-hooks/exhaustive-deps` comment
- Placement: Right before closing `}, [dependencies]);` line
- Industry standard pattern, not a code smell

**Files with eslint-disable comments:**
- AdminDashboard.jsx (Line 27)
- SuperAdminDashboard.jsx (Lines 32, 36)
- FlashcardCreate.jsx (Lines 46, 74)
- MyFlashcards.jsx (Lines 50, 54)
- NoteDetail.jsx (Line 18)
- NoteEdit.jsx (Lines 46, 52)
- Dashboard.jsx (Line 34)
- my-contributions.jsx (Line 14)
- my-notes.jsx (Lines 35, 39)
- notes.jsx (Lines 27, 31)
- progress.jsx (Line 73)
- review-flashcards.jsx (Lines 29, 33)

**REASON:** Prevents infinite re-render loops while maintaining clean code. Adding functions to dependency array recreates them on every render, triggering useEffect infinitely.

---

### Database Column Naming Convention

**Status:** ✅ LOCKED  
**Approved:** December 27, 2025

**reviews table:**
- Timestamp column: `created_at` (NOT `reviewed_at`)
- All review queries must use `created_at`

**Fixed in:**
- progress.jsx: Changed all `reviewed_at` references to `created_at`

**REASON:** Matches actual database schema. Runtime errors revealed the mismatch. Always verify database column names before coding.

---

### File Organization Structure

**Status:** ✅ LOCKED  
**Approved:** December 27, 2025

**Folder purposes:**
- `src/lib/`: Configuration files only (supabase.js, utils.js)
- `src/contexts/`: React Context providers (AuthContext.jsx)
- `src/components/`: Reusable UI components
- `src/pages/`: Route/page components
- `src/hooks/`: Custom React hooks

**AuthContext.jsx location:**
- Current: `src/contexts/AuthContext.jsx` ✅
- Deleted: `src/lib/AuthContext.jsx` (duplicate removed)

**Import pattern:**
```javascript
import { supabase } from '@/lib/supabase';  // Use @ alias
```

**REASON:** Follows React community best practices. Prevents import path confusion. Deleted duplicate from lib/ folder.

---

### HTML Structure Standards

**Status:** ✅ LOCKED  
**Approved:** December 27, 2025

**index.html:**
- Single DOCTYPE declaration
- Single <html> tag
- Single <head> tag
- No duplicate tags

**SEO meta tags:**
- Description tag added for Google search results
- Proper HTML5 structure

**REASON:** Eliminates parse5 warnings, improves SEO, follows W3C standards.

---

### CSS Warning Policy

**Status:** ✅ LOCKED  
**Approved:** December 27, 2025

**Tailwind CSS conflicts (block vs flex):**
- Status: Safe to ignore
- Count: ~20 warnings in Navigation.jsx
- Impact: Zero functional impact
- Action: No fix required

**REASON:** These are style suggestions from Tailwind, not actual errors. Every major production app has these. Fixing provides zero benefit and takes hours. App works perfectly as-is.

---

### Dynamic Custom Course Support

**Status:** ✅ LOCKED  
**Approved:** December 28, 2025

**Implementation:**
- All course dropdowns fetch custom courses from database (notes + flashcards + profiles tables)
- Signup.jsx: Groups courses by type (CA/CMA/CS/Other)
- NoteUpload.jsx: Shows all courses alphabetically
- FlashcardCreate.jsx: Shows all courses alphabetically
- Custom courses automatically available to all users once added

**Files modified:**
- src/pages/Signup.jsx
- src/components/notes/NoteUpload.jsx
- src/components/flashcards/FlashcardCreate.jsx

**REASON:** Enables Phase 4 multi-discipline expansion without code changes. Users can select existing custom courses (MSc Economics, JEE, NEET, etc.) without re-entering. Scalable solution that grows with platform.

---

### Freemium Pricing Model

**Status:** ✅ LOCKED  
**Approved:** December 31, 2025

**Business Model:**
- Platform is FREEMIUM for ALL courses (CA Foundation, Intermediate, Final, CMA, CS, etc.)
- NO course is "free forever"
- Free tier has limitations to encourage upgrades

**Free Tier Limits:**
- Limited note uploads (e.g., 10 notes/month)
- Limited flashcard creation (e.g., 50 flashcards/month)
- Limited review sessions
- Public sharing disabled (optional)

**Paid Tier (Premium):**
- Unlimited note uploads
- Unlimited flashcard creation
- Unlimited reviews
- Public sharing enabled
- Export features
- Priority support

**Pricing Structure:**
- Monthly: ₹149/month (example for CA Intermediate)
- Exam bundles: ₹499/6 months (discounted)
- Course-specific pricing (CA Inter ≠ CA Final ≠ CMA)

**Landing Page Messaging:**
- ✅ "Start free • Upgrade anytime"
- ✅ "Start free • Upgrade for unlimited access"
- ❌ NEVER: "Free forever"
- ❌ NEVER: "Always free"

**REASON:**
Sustainable business model. Free tier attracts users, premium tier generates revenue.
Common SaaS pattern. Allows testing before commitment while ensuring platform sustainability.

**Phase 1 Note:**
For first 20 CA Inter students (pilot), all features unlocked for free during testing period (Month 1).
Paid tiers introduced in Phase 2 (Month 2-3).

---

### Database Documentation

**Status:** ✅ LOCKED  
**Approved:** January 2, 2026

**Complete database documentation created:**
- DATABASE_SCHEMA.md file (comprehensive)
- All 14 tables documented with WHY explanations
- All 24 RLS policies documented
- 1 SQL function documented
- 50+ indexes listed
- Troubleshooting section with 7 common issues
- Migration history tracked
- Query reference for Supabase organization
- Maintenance checklist

**REASON:** Saves 2+ hours debugging time. Single source of truth for all database information. Professional-grade documentation standard. Prevents recurring issues like missing RLS policies.

---

## 🔄 PENDING DECISIONS

[Nothing here yet - we'll add as we go]

---

## ❌ REJECTED IDEAS

### Idea: Use localStorage for data

**Rejected:** December 2025  
**Reason:** Not supported in Claude artifacts

---

## VERSION HISTORY

- **v1.0** - December 2025 - Initial approved decisions
- **v1.1** - December 16, 2025 - Added search/filter, bulk upload access, course selection
- **v1.2** - December 20, 2025 - Added dashboard student-first design
- **v1.3** - December 21, 2025 - Added my notes separation, user attribution, custom course
- **v1.4** - December 25, 2025 - Added filter standardization, inline edit, delete, course filter
- **v1.5** - December 26, 2025 - Added batch tracking, legal pages
- **v1.6** - December 27, 2025 - Added VS Code error patterns, database naming, file organization
- **v1.7** - December 28, 2025 - Added dynamic custom course support
- **v1.8** - December 31, 2025 - Added freemium pricing model
- **v1.9** - January 2, 2026 - Added database documentation

---

**Last Updated:** January 2, 2026  
**Current Version:** v1.9  
**Total Approved Decisions:** 32

---

**END OF APPROVED_DECISIONS.md**
