# CONTEXT FOR CLAUDE - READ THIS FIRST

## Who I Am

- Name: Anand
- Role: CA faculty & coaching institute principal
- Technical Experience: ZERO (never coded before)
- Started: December 2024

---

## CRITICAL: How You Must Communicate With Me

### Always Do This:

- Explain like I'm 5 years old
- Break into smallest possible steps (numbered)
- No technical jargon without explanation
- Tell me WHAT to do AND WHY
- Show me what I should see at each step
- Give exact commands to copy-paste

### Never Do This:

- Assume I know technical terms
- Skip steps
- Give multiple options (just tell me the best one)
- Change approved code without asking me first

### Before Changing ANY Code:

1. Check if it's in "APPROVED_DECISIONS" document
2. If marked ✅ APPROVED, DO NOT change it
3. If change needed, ASK me first with clear explanation

---

## Project Files - What to Use

✅ USE THESE:
1. "Recall - Complete Project Blueprint (REVISED EDITION)" - PRIMARY blueprint (120 pages)
2. Syllabus spreadsheet - Course structure data
3. CONTEXT_FOR_CLAUDE.md (this document)
4. APPROVED_DECISIONS.md
5. SESSION_SUMMARY.md
6. DATABASE_SCHEMA.md
7. FILE_STRUCTURE.md

---

## Current Status

**Phase:** Phase 1 MVP - DEPLOYED ✅  
**Live URL:** https://recall-app-omega.vercel.app  
**Deployment Date:** December 27, 2025  
**Next:** Professor recruitment (Phase 0.5)

### Completed Features:
✅ Authentication & role-based access (4-tier system)  
✅ Note upload with target course selection  
✅ Flashcard creation (manual + bulk upload)  
✅ Dual-mode navigation (Study/Create)  
✅ Dashboard (student-first design with onboarding)  
✅ My Contributions (user-specific stats)  
✅ My Notes (personal notes - public + private)  
✅ Browse Notes (community notes - public only)  
✅ My Progress (analytics with real-time data)  
✅ User attribution (names + professor badges)  
✅ Custom course support (Phase 4 ready)  
✅ Database schema complete (two-tier content model)  
✅ Responsive layout (mobile-first)  
✅ ALL VS Code errors fixed (52 → 20 harmless CSS warnings)  
✅ All runtime bugs fixed (progress.jsx)  
✅ Production-ready codebase  
✅ Deployed to Vercel  
✅ Custom course dynamic dropdown support  
✅ Terms of Service & Privacy Policy pages  
✅ Batch tracking system for flashcards  
✅ Super Admin RLS policies  
✅ User Activity Stats SQL function  
✅ Complete database documentation

### Known Issues:
✅ None critical - All errors resolved!  
🟡 20 CSS warnings in Navigation.jsx (safe to ignore - Tailwind style suggestions)

### Recent Changes (January 2, 2026):
- Created comprehensive DATABASE_SCHEMA.md documentation
- Documented all 14 tables, 24 RLS policies, 1 SQL function
- Added troubleshooting guide for common database issues
- Created query reference for Supabase SQL Editor organization

---

## My Setup

- Computer: Windows 11 Pro
- Browser: Chrome
- VS Code: Yes
- Git: Yes
- Node.js: Yes
- Supabase: Connected
- Vercel: Deployed

---

## Budget

Phase 1: Maximum ₹2,567  
Must use free tiers

---

## Tech Stack (✅ LOCKED)

- Frontend: React 18 + Vite + TailwindCSS + shadcn/ui
- Backend: Supabase (PostgreSQL + Auth + Storage)
- Hosting: Vercel (free tier)
- OCR: Tesseract.js (client-side, free)
- Email: Resend (free tier)
- Analytics: PostHog (free tier)
- Error Tracking: Sentry (free tier)

---

## Project Context

- **App Name:** Recall
- **Tagline:** "Remember Everything. Ace Every Exam."
- **Target Users:** CA students (Foundation, Intermediate, Final) in Phase 1 → Multi-disciplinary students in Final Phase
- **Current Phase:** Phase 1 MVP deployed
- **Live URL:** https://recall-app-omega.vercel.app
- **Next Steps:** Professor recruitment (Phase 0.5) → Student launch

---

## Design Principles

- Mobile-first (most students use phones)
- Clean, modern UI
- Fast load times
- Simple onboarding
- Indian context (pricing, language, examples)
- Student-first, creator-optional model

---

## Important Technical Notes

- No localStorage/sessionStorage (not supported in Claude artifacts)
- Use React state for client-side data
- Keep code simple and well-commented
- Prioritize functionality over fancy features
- Must work on mobile browsers

---

## Database Information

**Reference:** See DATABASE_SCHEMA.md for complete details

**Key Tables:**
- profiles (4-tier role system: super_admin/admin/professor/student)
- notes (with two-tier content model)
- flashcards (with batch tracking)
- reviews (SuperMemo-2 spaced repetition)
- disciplines, subjects, topics (CA syllabus structure)
- admin_audit_log, role_change_log (security audit trails)

**CRITICAL Database Notes:**
- reviews table uses `created_at` column (NOT `reviewed_at`)
- flashcards group by `batch_id` (NOT timestamp)
- Super admin needs specific RLS policies to view all data
- Always check DATABASE_SCHEMA.md before modifying database

---

## CRITICAL RULES

1. Check APPROVED_DECISIONS before suggesting ANY code changes
2. If something is marked ✅ APPROVED, DO NOT modify it
3. If change needed, ASK first with clear explanation
4. Break everything into smallest possible steps
5. Always explain WHY, not just WHAT
6. Check DATABASE_SCHEMA.md before any database changes

---

## Workflow Reminders for Claude

### After Major Decisions:
- Remind Anand to update APPROVED_DECISIONS.md
- Tell him EXACTLY what to add and where

### When Creating New Files/Code:
- Remind Anand to save to GitHub
- Give exact Git commands to copy-paste
- Explain what each command does

### When Progress is Made:
- Suggest updating CONTEXT_FOR_CLAUDE "Current Status" section
- Tell him exactly what to change

### End of Each Session:
- Summarize what was accomplished
- List what needs to be saved/updated
- Give clear next steps for tomorrow

---

## Prompt Anand To:

- "Update APPROVED_DECISIONS with [specific change]"
- "Save this to GitHub with: [exact commands]"
- "Update CONTEXT_FOR_CLAUDE status to: [new status]"
- "Check DATABASE_SCHEMA.md before modifying [table name]"

---

## File Locations Reference

**Documentation:**
- `/CONTEXT_FOR_CLAUDE.md` - This file
- `/APPROVED_DECISIONS.md` - Locked decisions
- `/SESSION_SUMMARY.md` - Session history
- `/DATABASE_SCHEMA.md` - Complete database documentation
- `/FILE_STRUCTURE.md` - File organization

**Code:**
- `/src/` - All source code
- `/src/pages/` - Route components
- `/src/components/` - Reusable components
- `/src/lib/` - Configuration files
- `/src/contexts/` - React Context providers

**Configuration:**
- `/vite.config.js` - Vite configuration
- `/tailwind.config.js` - Tailwind CSS configuration
- `/.env.local` - Environment variables (NOT in Git)

---

## Git Workflow

**Standard commit process:**
```bash
git add [filename]
git commit -m "Clear description of what changed"
git push origin main
```

**Vercel auto-deploys after push to main branch**

---

## Communication Style Examples

**❌ BAD (Too technical):**
"Update the useEffect dependency array to prevent infinite re-renders"

**✅ GOOD (Explain like I'm 5):**
"We need to fix a small issue in the code. 

**What's happening:** The code is running too many times (like a loop)

**Why it's happening:** We told it to run whenever something changes, but that thing changes every time it runs

**How to fix:** Add one comment that tells the computer 'it's okay to ignore this warning'

**Copy this:** `// eslint-disable-next-line react-hooks/exhaustive-deps`

**Paste it:** Right before the closing `}, [dependencies]);` line"

---

## REMINDER FOR CLAUDE

I have ZERO coding experience. If I don't understand something, explain it differently or more simply.

Always:
- Break into tiny steps
- Show what I should see at each step
- Give exact commands to copy-paste
- Explain WHY we're doing each step

Never:
- Use jargon without explanation
- Assume I know shortcuts or commands
- Skip steps
- Give multiple options (just tell me the best one)

---

## Session Template

At end of each session, update SESSION_SUMMARY.md with:

```markdown
## 🎯 SESSION SUMMARY - [DATE]

### ✅ COMPLETED:
- List all completed tasks

### 📊 VERIFIED WORKING:
- List tested features

### 💾 FILES MODIFIED:
- List all changed files

### 📋 NEXT SESSION:
- List priorities for next time

### 🐛 KNOWN ISSUES:
- List any remaining issues
```

---

**Last Updated:** January 2, 2026  
**Version:** 2.4  
**Status:** Phase 1 MVP deployed, ready for Phase 0.5

---

## Current Status

Phase: Phase 1 MVP - COMPLETE ✅ + Bug Fixes Deployed ✅
Live URL: https://recall-app-omega.vercel.app
Next: Professor recruitment (Phase 0.5)

### Completed Features:  
✅ Authentication & role-based access (4-tier system)  
✅ Note upload with target course selection  
✅ Flashcard creation (manual + bulk upload)  
✅ Dual-mode navigation (Study/Create)  
✅ Dashboard (student-first design with onboarding)  
✅ My Contributions (user-specific stats)  
✅ My Notes (personal notes - public + private)  
✅ Browse Notes (community notes - public only)  
✅ My Progress (analytics with real-time data)  
✅ User attribution (names + professor badges)  
✅ Custom course support (Phase 4 ready)  
✅ Database schema complete (two-tier content model)  
✅ Responsive layout (mobile-first)  
✅ Deployed to production (Vercel)
✅ **Delete entire group functionality (Jan 2, 2026)**
✅ **Edit group info (course/subject/topic/description) (Jan 2, 2026)**
✅ **UTF-8 CSV encoding for special characters like ₹ (Jan 2, 2026)**

### Known Issues:  
✅ None critical - All errors resolved!

### Recent Changes (Jan 2, 2026):
- Added Delete Group button to remove entire batches at once
- Added Edit Group Info dialog to update course/subject/topic/description
- Fixed UTF-8 encoding in CSV parser (₹ symbol now displays correctly)
- Replaced shadcn Select with native HTML select in Edit dialog (better stability)
- All features tested locally and deployed to production

## Current Status

Phase: Phase 1 MVP - COMPLETE ✅ + Spaced Repetition FIXED ✅
Live URL: https://recall-app-omega.vercel.app
Next: Verify midnight fix tomorrow (Jan 4) → Professor recruitment (Phase 0.5)

### Completed Features:
✅ Authentication & role-based access (4-tier system)
✅ Note upload with target course selection
✅ Flashcard creation (manual + bulk upload)
✅ Dual-mode navigation (Study/Create)
✅ Dashboard (student-first design with onboarding)
✅ My Contributions (user-specific stats)
✅ My Notes (personal notes - public + private)
✅ Browse Notes (community notes - public only)
✅ My Progress (analytics with real-time data)
✅ User attribution (names + professor badges)
✅ Custom course support (Phase 4 ready)
✅ **Spaced repetition system (SuperMemo-2 with midnight scheduling)** 🆕
✅ Database schema complete (two-tier content model)
✅ Responsive layout (mobile-first)
✅ Deployed to production (Vercel)

### Known Issues:
✅ None critical - All errors resolved!

### Recent Changes (Jan 3, 2026):
- Fixed spaced repetition scheduling to use midnight instead of exact 24 hours
- Diagnosed and confirmed time zone issue (not RLS policy)
- Deployed midnight fix to production
- Ready for testing tomorrow morning

## UPDATE YOUR CONTEXT_FOR_CLAUDE.md FILE

Find the "Current Status" section and replace with:

---

## Current Status

Phase: Phase 1 MVP - COMPLETE ✅ + Review Session Route ✅
Live URL: https://recall-app-omega.vercel.app
Next: Deploy review session fix → Professor recruitment (Phase 0.5)

### Completed Features:
✅ Authentication & role-based access (4-tier system)
✅ Note upload with target course selection
✅ Flashcard creation (manual + bulk upload)
✅ Dual-mode navigation (Study/Create)
✅ Dashboard (student-first design with onboarding)
✅ My Contributions (user-specific stats)
✅ My Notes (personal notes - public + private)
✅ Browse Notes (community notes - public only)
✅ My Progress (analytics with real-time data)
✅ User attribution (names + professor badges)
✅ Custom course support (Phase 4 ready)
✅ **Spaced repetition system (SuperMemo-2 with midnight scheduling)** 🆕
✅ **Review Session route (/dashboard/review-session)** 🆕
✅ **StudyMode accepts flashcards prop (flexible usage)** 🆕
✅ Database schema complete (two-tier content model)
✅ Responsive layout (mobile-first)
✅ Deployed to production (Vercel)

### Known Issues:
✅ None critical - All errors resolved!

### Recent Changes (Jan 3, 2026 - Evening):
- Fixed midnight scheduling for spaced repetition
- Created dedicated review session route
- Fixed StudyMode to accept flashcards prop
- Review session now shows ONLY due cards
- Dashboard "Start Review Session" button works correctly
- Deployed successfully to production

---

## Current Status

Phase: Phase 1 MVP - DEPLOYED ✅ + Schema Enhanced ✅
Live URL: https://recall-app-omega.vercel.app
Next: February features (friends, profile, dashboard) → March launch (150 students)

### Completed Features:
✅ Authentication & role-based access (4-tier system)
✅ Note upload with target course selection
✅ Flashcard creation (manual + bulk upload)
✅ Dual-mode navigation (Study/Create)
✅ Dashboard (student-first design with onboarding)
✅ My Contributions (user-specific stats)
✅ My Notes (personal notes - public + private)
✅ Browse Notes (community notes - public only)
✅ My Progress (analytics with real-time data)
✅ User attribution (names + professor badges)
✅ Custom course support (Phase 4 ready)
✅ Database schema complete (two-tier content model)
✅ **Content creator attribution (creator_id + content_creator_id)** 🆕
✅ **Friendships table (social features ready)** 🆕
✅ **Revenue tracking infrastructure (Vivitsu-ready)** 🆕
✅ Responsive layout (mobile-first)
✅ Deployed to production (Vercel)

### Known Issues:
✅ Spaced repetition for medium/easy cards - needs fixing

### Recent Changes (Jan 9, 2026):
- Added creator_id to flashcards (user attribution)
- Added content_creator_id to flashcards (revenue attribution)
- Created friendships table with indexes
- Created content_creators table
- Database ready for Vivitsu partnership
- Schema ready for B2C → B2B expansion

### February Priorities:
1. Fix spaced repetition (medium/easy cards)
2. Build friend request system (UI)
3. Build user profile page
4. Redesign dashboard (class stats, milestones)
5. Create 200 CA Foundation flashcards
6. Friends-only sharing feature
```
**END OF CONTEXT_FOR_CLAUDE.md**
