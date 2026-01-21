# NOW - Current Focus

## Session: 2026-01-21 - Critical Spaced Repetition & Timezone Fixes

### Changes Implemented
**CRITICAL BUG FIX: Spaced repetition infinite loop and timezone issues**

#### Problems Identified
1. **Timezone Bug:** Using `toISOString()` caused cards to reappear immediately
   - UTC conversion made "tomorrow" become "yesterday" for certain timezones
   - Students in Western timezones or late-night India sessions affected
   
2. **Architectural Issue:** Progress writing to wrong table
   - Attempted updates to professor-owned `flashcards` table
   - RLS policies blocked student updates (silent failures)
   
3. **Logic Issue:** Dashboard counting wrong cards
   - Included new (unstudied) cards in "Reviews Due" count
   - Created false "All Caught Up" messages

#### Solution Implemented

**Date Handling Standardization:**
- Replaced ALL `toISOString()` usage with manual local date construction
- Format: `YYYY-MM-DD` built from `getFullYear()`, `getMonth() + 1`, `getDate()`
- Ensures calendar dates are timezone-independent

**Database Architecture:**
- `reviews` table is now exclusive source of truth for student progress
- Explicit SELECT → UPDATE or INSERT logic
- Clear, readable code (no atomic UPSERT confusion)

**Dashboard Logic:**
- "Reviews Due" = cards in `reviews` table with `next_review_date <= today` (local)
- New cards excluded from count
- Accurate representation of actual review workload

#### Technical Standards Established

**ENFORCED RULES (Never Violate):**
1. Date Handling: Never use `toISOString()` for next_review_date
2. Database: Reviews table is single source of truth
3. Logic: Explicit SELECT before UPDATE/INSERT
4. Definition: "Due" = in reviews table + scheduled for today or earlier

#### Files Modified
- `src/components/flashcards/StudyMode.jsx` (date math + DB logic)
- `src/pages/dashboard/Study/ReviewSession.jsx` (query + date comparison)
- `src/pages/Dashboard.jsx` (count logic + date comparison)

#### Testing Required
- [ ] Verify cards don't reappear same day
- [ ] Test timezone independence (IST, PST, GMT)
- [ ] Confirm dashboard count matches review session
- [ ] Check multi-user independence
- [ ] Verify progress persists across sessions

#### Documentation Updated
- context.md: Added "Spaced Repetition & Timezone Standards" section
- changelog.md: Added detailed entry for this fix
- now.md: This session summary

---
## Session: 2026-01-19 - Critical Spaced Repetition System Fix

### Changes Implemented
**CRITICAL BUG FIX: Complete overhaul of spaced repetition architecture**

#### Problem Identified
- Students reported: "Cards reviewed today keep appearing in same session"
- Root cause: Spaced repetition data stored in shared `flashcards` table
- RLS policy blocked students from updating professor-created cards
- `reviews.next_review_date` column existed but was always NULL (unused)
- Multiple students overwriting each other's review schedules

#### Files Modified
1. **src/components/flashcards/StudyMode.jsx**
   - REMOVED: UPDATE to `flashcards` table (lines 164-182)
   - ADDED: UPSERT logic to `reviews` table with proper next_review_date
   - Changed date format from timestamp to DATE (YYYY-MM-DD)
   - Added proper error handling and user feedback

2. **src/pages/dashboard/Study/ReviewSession.jsx**
   - CHANGED: Query from `flashcards.next_review` to `reviews.next_review_date`
   - Fixed date comparison logic (DATE type instead of timestamp)
   - Added comprehensive logging for debugging

3. **src/pages/dashboard/Study/ReviewBySubject.jsx** (NEW FILE)
   - Subject-based review grouping feature
   - Shows due cards organized by subject
   - "Review All" option for comprehensive sessions

4. **Router configuration**
   - Added route: `/dashboard/review-by-subject`

#### Technical Details
- **Architecture Change:** `reviews` table is now single source of truth for SR data
- **Data Format:** `next_review_date` stored as DATE (YYYY-MM-DD), not timestamp
- **User Isolation:** Each user has independent review schedule (no conflicts)
- **RLS Compliance:** Students update their own review records (allowed by policy)

#### Impact
- ✅ Review progress now saves correctly for all users
- ✅ Cards don't reappear until scheduled date
- ✅ Mid-session exit preserves progress
- ✅ Multiple students can review same card independently
- ✅ No database schema changes required

#### Deployment Notes
- No database migrations needed
- Backward compatible (old flashcards.next_review data ignored)
- Can deploy immediately
- Simple rollback if needed (code revert only)

### Post-Deployment Fixes (Same Day)

#### Fix 1: Separate Spaced Repetition from New Learning
**Problem:** Dashboard showed inflated "Reviews Due" count by including never-studied cards
**Impact:** Users felt overwhelmed by large numbers that weren't actually due for review

**Strategic Change:**
- "Reviews Due" now strictly counts cards with `next_review_date <= today`
- "New Cards" (never studied) are excluded from daily review count
- Aligns with spaced repetition best practices (separate new learning from reviews)

**Code Changes:**
- `Dashboard.jsx`: Removed logic that fetched and counted new cards in "Reviews Due"
- `ReviewSession.jsx`: Removed logic that added new cards to review sessions
- Result: Review count now reflects only scheduled reviews, not new content

**Rationale:**
- Spaced repetition systems should distinguish between:
  - **Review Mode:** Cards you've studied before that are due for reinforcement
  - **Learning Mode:** Brand new cards you've never seen
- Mixing these creates confusion and reduces effectiveness

---

#### Fix 2: Restore Missing UI Section in Dashboard
**Problem:** "My Contributions" card accidentally removed during refactor
**Impact:** Users couldn't see their upload counts (notes, flashcards)

**Code Changes:**
- `Dashboard.jsx`: Restored "My Contributions" card
- Fixed ESLint warnings for unused `notesCount` and `flashcardsCount` variables

**Files Modified:**
- `src/pages/dashboard/Dashboard.jsx` (both fixes)
- `src/pages/dashboard/Study/ReviewSession.jsx` (Fix 1 only)

---

### Testing Status (Updated)
- [x] Basic review save functionality verified
- [x] Mid-session persistence working
- [x] Review count accuracy confirmed (excludes new cards)
- [x] Dashboard UI completeness verified
- [ ] Multi-user testing pending
- [ ] Subject-based grouping testing pending

---

**Last Updated:** January 18, 2026  
**Status:** Phase 3 (Social Features) COMPLETE → Ready for Phase 0.5 Professor Recruitment

---

## Current State

✅ **Phase 3 Complete:** Friends-only visibility working end-to-end
- RLS policies deployed and tested
- Three-tier visibility (private/friends/public) functional
- Friend request flow working (send/accept/reject)

---

## Immediate Next Steps

### Priority 1: Deploy Phase 3 to Production
```bash
git add .
git commit -m "Phase 3: Social features complete - friends visibility"
git push origin main
# Vercel auto-deploys
```

### Priority 2: Cleanup Console Logs
Remove debug statements from:
- [ ] `src/pages/dashboard/notes.jsx`
- [ ] `src/pages/dashboard/review-flashcards.jsx`
- [ ] `src/components/flashcards/StudyMode.jsx`

### Priority 3: Begin Phase 0.5 - Professor Recruitment
1. Create professor outreach email (template in Blueprint Section 15)
2. Identify 3-4 CA Inter faculty candidates
3. Schedule 30-min demo calls
4. Target: 220 flashcards + 35 notes seeded before student launch

---

## Known Issues (Non-Critical)

| Issue | Status | Priority |
|-------|--------|----------|
| 20 CSS warnings in Navigation.jsx | Safe to ignore | Low |
| Tailwind block vs flex conflicts | Style suggestions only | Low |

---

## Files Modified in Last Session (Jan 15, 2026)

### Database (Supabase)
- Enabled RLS on `flashcards` table
- Enabled RLS on `friendships` table
- Created 4 new RLS policies for friends visibility

### Frontend
- `src/components/flashcards/StudyMode.jsx` - Simplified query (RLS handles filtering)
- `src/components/flashcards/MyFlashcards.jsx` - 3-tier visibility dropdown

---

## Testing Checklist

### Friends-Only Visibility (Verified ✅)
- [x] Public notes from anyone: Visible in Browse Notes
- [x] Own notes (any visibility): Visible in My Notes
- [x] Friends-only notes from accepted friends: Visible
- [x] Public flashcards: Reviewable in Study Mode
- [x] Own flashcards: Visible regardless of visibility setting
- [x] Friends-only flashcards from accepted friends: Reviewable

### Friend Request Flow (Verified ✅)
- [x] Send friend request → status='pending'
- [x] Accept request → status='accepted'
- [x] Reject request → status='rejected'
- [x] View pending requests
- [x] View accepted friends list

---

## Blocked By

Nothing currently blocked. Ready to proceed with:
1. Production deployment
2. Professor recruitment (Phase 0.5)
3. CA Foundation content creation (150 flashcards target)

---

## Notes for Next Session (Consider only notes numberd as 1 & ignore notes from number 2 onwards)

1. Navigation & Width Consistency
    1.1 Create Page Width Utility
    1.2 Apply Width Consistency - Full Width Pages
    1.3 Apply Width Consistency - Medium Width Pages
    1.4 Update Navigation - Add "My Activity" Menu

2. Dashboard Redesign
    2.1 Create Anonymous Stats Queries
    2.2 Create Dashboard Stats Components
    2.3 Redesign Dashboard Page
3. Upvote system
    4.1 Database Schema - Upvotes
    4.2 Upvote Button Component
    4.3 Add Upvotes to Browse Notes
    4.4 Add Upvotes to Review Flashcards
    4.5 Update My Contributions - Show Upvotes Received
4. Achievement System
    4.1 Database Schema - Badges
    4.2 Badge Check Logic
    4.3 My Achievements Page
    4.5 Badge Notifications
5. Personal Goals
    5.1 Database Schema - Goals
    5.2 Goal Setting UI
    5.3 Add Goals to My Progress Page
6. My Progress Enhancements
    6.1 Study Patterns Section
    6.2 Weekly Breakdown Graph
    6.3 Comparative Stats (Anonymous)

