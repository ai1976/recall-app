# RECALL - Project Context (Source of Truth)

**Last Updated:** January 19, 2026  
**Live URL:** https://recall-app-omega.vercel.app  
**Repository:** https://github.com/ai1976/recall-app

---

## Project Overview

**App Name:** Recall  
**Tagline:** "Remember Everything. Ace Every Exam."  
**Target Users:** CA/CMA/CS students (India) - expanding to JEE/NEET, undergraduate and school section for state and central boards
**Current Phase:** Phase 1 Complete, Phase 0.5 (Professor Content Seeding) in progress  
**Business Model:** Freemium (Free tier with limits → Premium ₹149/month)

---

**Current state**

Recall is in production with 27 registered students and impressive early metrics: 542+ total reviews from top students. The platform features a complete tech stack (React, Supabase, Vercel) with a four-tier role system (super_admin, admin, professor, student), three-tier content visibility (Private/Friends/Public), and comprehensive spaced repetition using SuperMemo-2 methodology.

**CRITICAL FIX (2026-01-19):** Resolved architectural bug in spaced repetition system. The `reviews` table is now the single source of truth for user-specific SR schedules, fixing the issue where students' progress wasn't being saved due to RLS conflicts when trying to update professor-created flashcards. Each user now maintains an independent review schedule.

Recent development has focused on fixing the spaced repetition architecture, implementing proper review progress persistence, and adding subject-based review grouping. The platform successfully handles review data isolation per user, preventing schedule conflicts between students reviewing the same cards.

Current challenges include ongoing testing of the new review system to ensure proper date calculations and timezone handling. The platform's social features (friends system, content sharing) continue to operate as designed.

**CRITICAL FIX (2026-01-19):** Resolved architectural bug in spaced repetition system. The `reviews` table is now the single source of truth for user-specific SR schedules, fixing the issue where students' progress wasn't being saved due to RLS conflicts when trying to update professor-created flashcards. Each user now maintains an independent review schedule.

**POST-DEPLOYMENT REFINEMENT (2026-01-19):** After initial deployment, refined review count logic to separate spaced repetition (scheduled reviews) from new learning (unstudied cards). Dashboard "Reviews Due" now shows only cards with scheduled review dates, aligning with SR best practices and preventing user overwhelm from inflated counts. "My Contributions" dashboard section restored after accidental removal during refactor.

## Tech Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| **Frontend** | React 18 + Vite | With TailwindCSS + shadcn/ui |
| **Backend** | Supabase | PostgreSQL + Auth + Storage + RLS |
| **Hosting** | Vercel | Free tier, auto-deploy from GitHub |
| **OCR** | Tesseract.js | Client-side, free |
| **Email** | Resend | Free tier (3K/month) |
| **Analytics** | PostHog | Free tier |
| **Error Tracking** | Sentry | Free tier |

---

## Database Schema (High-Level)

### Core Tables

```
profiles
├── id (UUID, PK, references auth.users)
├── email (TEXT)
├── full_name (TEXT)
├── role (TEXT: student/professor/admin/super_admin)
├── course_level (TEXT: CA Foundation/CA Intermediate/CA Final/etc.)
├── institution (TEXT)
└── created_at (TIMESTAMP)

notes
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── title (TEXT)
├── content_type (TEXT: Text/Table/Math/Diagram)
├── image_url (TEXT)
├── extracted_text (TEXT, nullable)
├── target_course (TEXT, NOT NULL)
├── visibility (TEXT: private/friends/public)
├── is_verified (BOOLEAN)
├── tags (TEXT[])
└── created_at (TIMESTAMP)

flashcards
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── creator_id (UUID, FK → profiles.id) -- WHO uploaded
├── content_creator_id (UUID, FK → content_creators.id) -- WHO gets revenue
├── front_text (TEXT)
├── back_text (TEXT)
├── target_course (TEXT, NOT NULL)
├── visibility (TEXT: private/friends/public)
├── batch_id (UUID) -- Groups bulk uploads
├── batch_description (TEXT)
├── is_verified (BOOLEAN)
├── difficulty (TEXT: easy/medium/hard)
├── next_review (TIMESTAMP WITH TIME ZONE, NOT NULL)
├── interval (INTEGER, DEFAULT 1)
├── ease_factor (NUMERIC, DEFAULT 2.5)
├── repetitions (INTEGER, DEFAULT 0)
└── created_at (TIMESTAMP)

reviews
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── flashcard_id (UUID, FK → flashcards.id)
├── quality (INTEGER: 1=Hard, 3=Medium, 5=Easy)
└── created_at (TIMESTAMP)

friendships
├── id (UUID, PK)
├── user_id (UUID, FK → profiles.id)
├── friend_id (UUID, FK → profiles.id)
├── status (TEXT: pending/accepted/rejected)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
└── UNIQUE(user_id, friend_id)

content_creators
├── id (UUID, PK)
├── name (TEXT, NOT NULL)
├── type (TEXT: individual/organization)
├── email (TEXT, UNIQUE)
├── revenue_share_percentage (DECIMAL, DEFAULT 30.0)
└── created_at (TIMESTAMP)

admin_audit_log
├── id (UUID, PK)
├── action (TEXT, NOT NULL)
├── admin_id (UUID, FK → profiles.id)
├── target_user_id (UUID, FK → profiles.id)
├── details (JSONB)
├── ip_address (TEXT)
└── created_at (TIMESTAMP)
```

---

## Four-Tier Role System

```
SUPER_ADMIN (Founder only - 1 person)
├── All permissions
├── Create/delete admins
├── Financial data access
├── Database/system config
└── 12-hour session timeout

ADMIN (Trusted team members)
├── User management (suspend/activate)
├── Content moderation
├── Promote to professor
├── Analytics access
└── 24-hour session timeout

PROFESSOR (Faculty contributors)
├── Bulk upload (CSV)
├── Verified content badges
├── Profile page
└── 7-day session timeout

STUDENT (Regular users)
├── Create notes/flashcards
├── Review content
├── Share publicly
└── 7-day session timeout
```

---

## Three-Tier Visibility System

| Level | Who Can See |
|-------|-------------|
| **Private** | Only creator |
| **Friends** | Creator + accepted friends |
| **Public** | Everyone |

Applied to: Notes, Flashcards

---

## Spaced Repetition Algorithm (SuperMemo-2)

```javascript
// Intervals based on quality score
Hard (quality=1)   → next_review = NOW + 1 day
Medium (quality=3) → next_review = NOW + 3 days
Easy (quality=5)   → next_review = NOW + 7 days

// Scheduling uses UTC midnight
next_review.setUTCHours(0, 0, 0, 0)
```

**Key Fields on flashcards table:**
- `next_review`: When card is due (TIMESTAMP WITH TIME ZONE, NOT NULL)
- `interval`: Days until next review (INTEGER)
- `ease_factor`: Difficulty multiplier (NUMERIC, DEFAULT 2.5)
- `repetitions`: Times reviewed (INTEGER)

---

## Row Level Security (RLS) Policies

### flashcards table (RLS ENABLED)
```sql
-- Users can view their own flashcards
CREATE POLICY "Users can view own flashcards" ON flashcards
FOR SELECT USING (user_id = auth.uid());

-- Users can view public flashcards
CREATE POLICY "Users can view public flashcards" ON flashcards
FOR SELECT USING (visibility = 'public');

-- Users can view friends' flashcards (visibility='friends')
CREATE POLICY "Users can view friends flashcards" ON flashcards
FOR SELECT USING (
  visibility = 'friends' AND
  EXISTS (
    SELECT 1 FROM friendships
    WHERE status = 'accepted'
    AND ((user_id = auth.uid() AND friend_id = flashcards.user_id)
         OR (friend_id = auth.uid() AND user_id = flashcards.user_id))
  )
);
```

### friendships table (RLS ENABLED)
```sql
-- Users can view their own friendships
CREATE POLICY "Users can view own friendships" ON friendships
FOR SELECT USING (user_id = auth.uid() OR friend_id = auth.uid());
```

---

## Project Structure

```
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
│   │   └── SPACED_REPETITION_PHILOSOPHY.md
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
│   │       └── toaster.jsx
│   ├── contexts
│   │   └── AuthContext.jsx
│   ├── data
│   ├── hooks
│   │   ├── use-toast.js
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

## Critical Rules & Patterns

### 1. Two-Tier Content Model
- **User's Enrollment** (`profiles.course_level`): What they're studying
- **Content's Target** (`notes.target_course`, `flashcards.target_course`): Who it's for
- These are INDEPENDENT - professors can create content for any course

### 2. Batch Tracking for Bulk Uploads
- All cards from one CSV get same `batch_id`
- Manual cards get unique `batch_id`
- Groups survive visibility changes

### 3. Attribution System
- `creator_id`: WHO uploaded (for UI display)
- `content_creator_id`: WHO gets revenue (for Vivitsu partnership)

### 4. UTC Midnight Scheduling
- All `next_review` times set to midnight UTC
- Use `setHours(0,0,0,0)` not `setHours()`

### 5. eslint-disable Pattern for useEffect
```javascript
useEffect(() => {
  // fetch logic
}, [dependency]);
// eslint-disable-next-line react-hooks/exhaustive-deps

### 6. Always use @/ for imports.
```

### 6. Query Pattern for User Attribution
```javascript
// Fetch separately, merge in JS (more reliable than PostgREST joins)
const notes = await fetchNotes();
const profiles = await fetchProfiles(userIds);
const merged = notes.map(n => ({...n, user: profiles.find(p => p.id === n.user_id)}));
```

---

## Environment Variables (Vercel)

```
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxxxxx
```

---

## Key Contacts

- **Developer:** Anand (CA Faculty, Zero coding experience)
- **Support:** recall@moreclassescommerce.com
- **Location:** Pune, Maharashtra, India