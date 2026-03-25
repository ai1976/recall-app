# DATABASE SCHEMA DOCUMENTATION - RECALL MVP

**Last Updated:** January 2, 2026  
**Database:** PostgreSQL (Supabase)  
**Project:** Recall - AI-Powered Study Platform for CA Students  
**Version:** Phase 1 MVP

---

## 📋 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Database Tables](#database-tables)
3. [RLS Policies](#rls-policies)
4. [SQL Functions](#sql-functions)
5. [Indexes](#indexes)
6. [Triggers](#triggers)
7. [Migration History](#migration-history)
8. [Common Issues & Troubleshooting](#common-issues--troubleshooting)
9. [Query Reference](#query-reference)
10. [Schema Roadmap](#schema-roadmap)
11. [Maintenance Checklist](#maintenance-checklist)

---

## 1. OVERVIEW

### Quick Stats
- **Total Tables:** 24 ⭐ (was 23, added follows — Sprint 3.4)
- **Custom Functions:** 16 ⭐ (was 13, added get_friends_leaderboard + get_following_leaderboard + update_daily_goal — Sprint 3.5)
- **RLS Policies:** 29 ⭐ (was 26, added 3 for follows — Sprint 3.4)
- **Indexes:** 56+ ⭐ (was 54+, added follows_follower_id_idx + follows_followee_id_idx — Sprint 3.4)
- **Triggers:** 0 (currently)
- **Database Size:** ~50 MB (estimated for 20 users)

### Core Tables
- **profiles** - User accounts with 4-tier role system
- **notes** - Student notes with OCR
- **flashcards** - Spaced repetition cards with batch tracking ⭐ (now with creator attribution)
- **reviews** - Review history for SuperMemo-2 algorithm
- **disciplines, subjects, topics** - Course structure (CA Inter pre-loaded)
- **admin_audit_log** - Audit trail for admin actions
- **role_change_log** - Role promotion/demotion history

### Social Tables ⭐ NEW
- **friendships** - Friend connections between users (pending/accepted/rejected)
- **upvotes** - Upvote tracking for notes (already existed, moved here for clarity)
- **comments** - Comments on shared notes (already existed, moved here for clarity)

### Revenue Tracking ⭐ NEW
- **content_creators** - Content creators for revenue sharing (Vivitsu, professors)

### Multi-Course Teaching ⭐ NEW (Feb 21, 2026)
- **profile_courses** - Junction table: professors/admins/super_admins → multiple disciplines
  - `profiles.course_level` kept as "primary course" for backward compat with all RLS
  - `profile_courses` is additive — extends, does not replace, `course_level`
  - `is_primary = TRUE` row always synced with `profiles.course_level` via `setPrimaryCourse()`
  - SQL: run manually in Supabase SQL Editor (provided in chat)

### Supporting Tables
- **comments** - Comments on shared notes
- **upvotes** - Upvote tracking for notes
- **role_permissions** - Permission matrix for roles

---

## 2. DATABASE TABLES

### 2.1 profiles

**Purpose:** User accounts with 4-tier role system (student/professor/admin/super_admin)
**Created:** December 2025 (Phase 0.5)
**Last Updated:** March 22, 2026 (added daily_review_goal, daily_study_goal_minutes — Sprint 3.5)
**Columns:** 13

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key, links to auth.users |
| full_name | text | YES | NULL | User's display name |
| email | text | NO | - | Unique, from Supabase auth |
| role | text | NO | 'student' | student/professor/admin/super_admin |
| course_level | text | YES | NULL | User's primary enrollment (CA Foundation/Inter/Final) |
| institution | text | YES | NULL | Student's coaching institute name |
| account_type | text | NO | 'self_registered' | B2C=self_registered / B2B=enrolled. Controls public content access. |
| status | text | NO | 'active' | active/suspended |
| has_seen_onboarding | boolean | NO | false | Set to true when user dismisses OnboardingModal. Controls first-login modal. |
| created_at | timestamp | NO | NOW() | Account creation timestamp |
| timezone | text | YES | 'Asia/Kolkata' | IANA timezone identifier (e.g., 'Asia/Kolkata', 'America/New_York'). Auto-detected from browser. |
| daily_review_goal | integer | YES | NULL | Student's daily review target. CHECK >0 AND <=200. NULL = no goal set. Sprint 3.5. |
| daily_study_goal_minutes | integer | YES | NULL | Student's daily study time target in minutes. CHECK >0 AND <=480. NULL = no goal set. Sprint 3.5. |

**Key distinction — role vs account_type:**
- `role` = permission level (student/professor/admin/super_admin)
- `account_type` = business relationship (self_registered=B2C / enrolled=B2B). All users have role=student by default. Admins have role=admin but account_type=enrolled.

**Why This Structure:**
- `role` column enables 4-tier permission system (critical for security)
- `account_type` gates public content access — self_registered users see infrastructure only; enrolled users see public professor content
- `course_level` is user's enrollment, separate from content `target_course` (two-tier model)
- Foreign key to `auth.users` for Supabase authentication integration
- `status` allows suspending users without deletion
- `has_seen_onboarding` prevents repeat display of first-login modal

**Profile creation:** Handled by `handle_new_user()` SECURITY DEFINER trigger on `auth.users`. Never via direct client INSERT (would fail when email confirmation is ON and session is null).

**Related Tables:** notes, flashcards, reviews, admin_audit_log  
**Key Indexes:** email (unique), role, created_at  
**RLS Policies:** 4 policies (see RLS section)

---

### 2.2 notes

**Purpose:** User-uploaded study notes with OCR text extraction  
**Created:** December 2025  
**Last Updated:** January 11, 2026 (Added visibility system)  
**Columns:** 24 (was 23, replaced is_public with visibility)

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to profiles.id |
| contributed_by | uuid | YES | NULL | For professor attribution |
| target_course | text | NO | - | Who is this content FOR? |
| discipline_id | uuid | YES | NULL | Foreign key to disciplines |
| subject_id | uuid | YES | NULL | Foreign key to subjects |
| topic_id | uuid | YES | NULL | Foreign key to topics |
| custom_course | text | YES | NULL | For Phase 4 expansion (JEE/NEET/CFA) |
| custom_subject | text | YES | NULL | User-defined subject |
| custom_topic | text | YES | NULL | User-defined topic |
| title | text | NO | - | Note title |
| content_type | text | NO | - | Text/Table/Math/Diagram |
| image_url | text | YES | NULL | Supabase Storage URL |
| extracted_text | text | YES | NULL | OCR extracted text |
| tags | text[] | YES | NULL | Array of tags (#important, #revision) |
| visibility | text | NO | 'private' | Three-tier visibility system ⭐ NEW |
| is_verified | boolean | NO | false | Professor-verified content badge |
| view_count | integer | NO | 0 | Engagement tracking |
| upvote_count | integer | NO | 0 | Quality signal |
| created_at | timestamp | NO | NOW() | Upload timestamp |
| updated_at | timestamp | NO | NOW() | Last modified |

**Visibility System (NEW - January 11, 2026):**
- `visibility` column replaces old `is_public` boolean
- Three levels:
  - **'private'**: Only creator can see (default)
  - **'friends'**: Creator + accepted friends can see
  - **'public'**: Everyone can see
- Constraint: `CHECK (visibility IN ('private', 'friends', 'public'))`
- Index: `idx_notes_visibility` for fast filtering

**Why This Structure:**
- `target_course` separate from `user_id.course_level` (two-tier content model - allows professors to contribute to multiple courses)
- Both pre-defined (discipline/subject/topic) AND custom (custom_course/subject/topic) supported
- `contributed_by` for professor attribution (different from uploader)
- `is_verified` badge for quality content
- `extracted_text` stored separately from image for searchability
- **NEW:** Three-tier visibility enables friend-only sharing for small study groups

**Migration Notes (January 11, 2026):**
- Old `is_public` boolean deprecated (kept for backwards compatibility)
- Existing data migrated: `is_public=true` → `visibility='public'` (16 notes)
- Existing data migrated: `is_public=false` → `visibility='private'` (1 note)
- Migration SQL: `[SCHEMA] Add Visibility to Notes`

**Related Tables:** profiles, disciplines, subjects, topics, comments, upvotes, friendships ⭐  
**Key Indexes:** user_id, target_course, visibility ⭐, created_at, discipline_id, subject_id, topic_id  
**RLS Policies:** 5 policies (see RLS section)

---

### 2.3 flashcards

**Purpose:** Spaced repetition flashcards with batch tracking
**Created:** December 2025
**Last Updated:** 2026-03-16 (Sprint 6 — added 10 undocumented content-type columns)
**Columns:** 34 (was 24; +10 content-type columns now documented)

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to profiles.id |
| contributed_by | uuid | YES | NULL | For professor attribution |
| target_course | text | NO | - | Who is this content FOR? |
| note_id | uuid | YES | NULL | Optional link to source note |
| front_text | text | NO | - | Question side |
| front_image_url | text | YES | NULL | Optional image on front |
| back_text | text | NO | - | Answer side |
| back_image_url | text | YES | NULL | Optional image on back |
| discipline_id | uuid | YES | NULL | Foreign key to disciplines |
| subject_id | uuid | YES | NULL | Foreign key to subjects |
| topic_id | uuid | YES | NULL | Foreign key to topics |
| batch_id | uuid | NO | uuid_generate_v4() | Groups cards from same upload |
| batch_description | text | YES | NULL | Optional batch label |
| creator_id | uuid | YES | NULL | Foreign key to profiles.id (who uploaded) |
| content_creator_id | uuid | YES | NULL | Foreign key to content_creators.id (who gets paid) |
| is_verified | boolean | NO | false | Professor-verified badge |
| difficulty | text | YES | NULL | easy/medium/hard |
| visibility | text | NO | 'private' | Three-tier visibility system |
| created_at | timestamp | NO | NOW() | Creation timestamp |
| custom_subject | text | YES | NULL | Free-text subject for custom/personal courses. Mutually exclusive with subject_id — exactly one should be set. |
| custom_topic | text | YES | NULL | Free-text topic for custom/personal courses. Mutually exclusive with topic_id. |
| question_type | text | NO | 'flashcard' | Type of study item. Values: 'flashcard', 'mcq', 'true_false', 'correct_incorrect', 'theory', 'test_your_understanding', 'case_study_mcq', 'integrated_case', 'match_the_following', 'fill_in_the_blanks', 'concept_card'. |
| options | jsonb | YES | NULL | Answer options for MCQ and similar types. |
| correct_answer | text | YES | NULL | Correct answer identifier for question types that need it. |
| hints | jsonb | YES | NULL | Optional hints array. |
| points_to_remember | jsonb | YES | NULL | Key takeaways, displayed post-answer. |
| scenario | text | YES | NULL | Case study / scenario text for case-based question types. |
| subtype | text | YES | NULL | Sub-classification within a question_type. |
| source | text | NO | 'manual' | How the card was created: 'manual', 'bulk_upload', 'gemini_import'. |

**Visibility System (NEW - January 11, 2026):**
- `visibility` column replaces old `is_public` boolean
- Three levels:
  - **'private'**: Only creator can see (default)
  - **'friends'**: Creator + accepted friends can see
  - **'public'**: Everyone can see
- Constraint: `CHECK (visibility IN ('private', 'friends', 'public'))`
- Index: `idx_flashcards_visibility` for fast filtering

**Concept Card Exclusion Rule:**
- `concept_card` items are **excluded from all review metrics** (Items Reviewed, Items Mastered, accuracy, streak). They are reference material only.
- All analytics RPCs must use `WHERE question_type != 'concept_card'` or the `vw_study_items` safety view.
- This applies to every RPC that counts reviews, calculates accuracy, or computes streaks.

**Why This Structure:**
- `batch_id` provides permanent grouping (solves issue where toggling public/private merged batches)
- Each manual card gets unique `batch_id`, bulk uploads share one `batch_id`
- `difficulty` helps professors tag question complexity
- `front_image_url` and `back_image_url` support visual learning
- `contributed_by` enables professor attribution separate from uploader
- `creator_id` tracks WHO uploaded the content (operational attribution)
- `content_creator_id` tracks WHO gets revenue credit (financial attribution)
- Example: Prof. Anand uploads flashcards on behalf of Vivitsu
  - creator_id = Prof. Anand (shows in UI)
  - content_creator_id = Vivitsu (gets 30% revenue share)
- **NEW:** Three-tier visibility enables friend-only sharing for small study groups

**Migration Notes (January 11, 2026):**
- Old `is_public` boolean deprecated (kept for backwards compatibility)
- Existing data migrated: `is_public=true` → `visibility='public'` (340 cards)
- Existing data migrated: `is_public=false` → `visibility='private'` (227 cards)
- Migration SQL: `[FIX] Migrate flashcard visibility from is_public`

**Related Tables:** profiles, notes, reviews, disciplines, subjects, topics, friendships ⭐  
**Key Indexes:** user_id, batch_id (critical for grouping), target_course, visibility ⭐, created_at  
**RLS Policies:** 5 policies (see RLS section)

**CRITICAL:** Always group by `batch_id`, NOT by timestamp or created_at

---

### 2.4 reviews

**Purpose:** Spaced repetition review history (SuperMemo-2 algorithm)  
**Created:** December 2025  
**Columns:** 10

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to profiles.id |
| flashcard_id | uuid | NO | - | Foreign key to flashcards.id |
| quality | integer | NO | - | 1=Hard, 3=Medium, 5=Easy |
| easiness_factor | numeric | NO | 2.5 | SuperMemo-2 EF value |
| interval | integer | NO | 1 | Days until next review |
| repetitions | integer | NO | 0 | Consecutive correct reviews |
| next_review_date | timestamp | NO | NOW() | When card is due next |
| status | text | NO | 'active' | active/suspended (card suspension system) |
| skip_until | date | YES | NULL | Date until which card is hidden (skip 24hr) |
| created_at | timestamp | NO | NOW() | When review happened |

**Card Suspension System (NEW - February 6, 2026):**
- `status` column enables indefinite card suspension ('active' or 'suspended')
- `skip_until` enables temporary 24-hour skip (card reappears after date)
- Suspended cards don't count as "due" and don't affect streak
- Skipped cards are filtered out of due queries when `skip_until > today`
- Constraint: `CHECK (status IN ('active', 'suspended'))`

**Why This Structure:**
- Implements SuperMemo-2 algorithm for optimal retention
- `quality` maps to: 1=Hard (review soon), 3=Medium (review later), 5=Easy (review much later)
- `easiness_factor` adjusts based on performance (2.5 default)
- `interval` grows exponentially for correctly answered cards
- `created_at` used for study streak calculation (NOT reviewed_at)

**Related Tables:** profiles, flashcards  
**Key Indexes:** user_id, flashcard_id, next_review_date (for due cards), created_at (for streak calculation)  
**RLS Policies:** 4 policies (see RLS section)

**CRITICAL:** Column is `created_at`, NOT `reviewed_at` (caused runtime error on 2025-12-27)

---

### 2.5 disciplines

**Purpose:** Top-level course categories (CA, CMA, CS)
**Created:** December 2025 (Phase 0.5)
**Columns:** 8
**Verified against live DB:** 2026-02-09

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| name | text | NO | - | e.g., "CA Intermediate" |
| code | text | NO | - | Short code e.g., "CAINT" (**REQUIRED** on insert, no default) |
| level | text | YES | NULL | e.g., "Intermediate" |
| order_num | integer | YES | 0 | Display order |
| is_active | boolean | YES | true | Enable/disable courses |
| created_at | timestamptz | YES | now() | Creation timestamp |
| order | integer | YES | 1 | Secondary ordering |

**⚠️ Key differences from `subjects`/`topics` tables:**
- Uses `order_num` and `order` columns (NOT `sort_order`)
- `code` is NOT NULL with no default — must be provided on insert
- `is_active` defaults to `true` but is nullable (not NOT NULL like in subjects/topics)

**Pre-Loaded Data:**
- CA Intermediate (code: CAINT, level: Intermediate, 8 subjects, 147 topics)

**Related Tables:** subjects, notes, flashcards
**Key Indexes:** name
**RLS Policies:** 2 policies (public read, admin insert)

---

### 2.6 subjects

**Purpose:** Course subjects (e.g., Taxation, Accounting)
**Created:** December 2025 (Phase 0.5)
**Columns:** 7 (assumed same pattern as topics — verified via error message)
**Verified against live DB:** 2026-02-09 (inferred from topics + error confirmation)

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| discipline_id | uuid | YES | NULL | Foreign key to disciplines |
| name | text | NO | - | e.g., "Advanced Accounting" |
| order_num | integer | YES | 0 | Display order (**NOT** `sort_order`) |
| is_active | boolean | YES | true | Enable/disable subjects |
| created_at | timestamptz | YES | now() | Creation timestamp |
| order | integer | YES | 1 | Secondary ordering |

**⚠️ Note:** Uses `order_num` (NOT `sort_order`). Same column naming as `disciplines` and `topics`.

**Pre-Loaded Data (CA Intermediate):**
1. Advanced Accounting
2. Corporate & Other Laws
3. Income Tax Law
4. Indirect Taxes
5. Cost & Management Accounting
6. Auditing & Ethics
7. Financial Management
8. Strategic Management

**Related Tables:** disciplines, topics, notes, flashcards
**Key Indexes:** discipline_id, name, is_active, order_num
**RLS Policies:** 1 policy (public read)

---

### 2.7 topics

**Purpose:** Granular topics within subjects
**Created:** December 2025 (Phase 0.5)
**Columns:** 7
**Verified against live DB:** 2026-02-09

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| subject_id | uuid | YES | NULL | Foreign key to subjects |
| name | text | NO | - | e.g., "AS 1 Disclosure of Accounting Policies" |
| order_num | integer | YES | 0 | Display order (**NOT** `sort_order`) |
| is_active | boolean | YES | true | Enable/disable topics |
| created_at | timestamptz | YES | now() | Creation timestamp |
| order | integer | YES | 1 | Secondary ordering |

**⚠️ All three structure tables (disciplines, subjects, topics) use `order_num`, NOT `sort_order`.**

**Pre-Loaded Data:**
- 147 topics across 8 CA Intermediate subjects
- Sourced from official CA syllabus spreadsheet

**Related Tables:** subjects, notes, flashcards
**Key Indexes:** subject_id, name, is_active, order_num
**RLS Policies:** 1 policy (public read)

---

### 2.8 admin_audit_log

**Purpose:** Audit trail for all admin/super_admin actions  
**Created:** December 2025 (Phase 0.5)  
**Columns:** 7

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| action | text | NO | - | e.g., "suspend_user", "delete_content" |
| admin_id | uuid | NO | - | Foreign key to profiles.id (who did it) |
| target_user_id | uuid | YES | NULL | Foreign key to profiles.id (to whom) |
| details | jsonb | YES | NULL | Additional context (reason, duration, etc.) |
| ip_address | text | YES | NULL | Request IP for security |
| created_at | timestamp | NO | NOW() | When action occurred |

**Why This Structure:**
- Every admin action is logged (security requirement)
- `details` JSONB stores flexible metadata (reason, duration, etc.)
- `ip_address` for security auditing
- Cannot be deleted (append-only log)

**Common Actions Logged:**
- suspend_user
- promote_to_professor
- delete_content
- verify_content
- change_role

**Related Tables:** profiles  
**Key Indexes:** admin_id, target_user_id, created_at  
**RLS Policies:** 2 policies (super_admin only)

**Review Schedule:** Weekly review of last 7 days of admin actions

---

### 2.9 role_change_log

**Purpose:** Audit trail for role promotions/demotions  
**Created:** December 2025 (Phase 0.5)  
**Columns:** 7

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to profiles.id (who changed) |
| old_role | text | NO | - | Previous role |
| new_role | text | NO | - | New role |
| changed_by | uuid | NO | - | Foreign key to profiles.id (who changed it) |
| reason | text | YES | NULL | Why role was changed |
| created_at | timestamp | NO | NOW() | When change occurred |

**Why This Structure:**
- Critical for security (tracks who promoted whom)
- `reason` field documents justification
- Cannot be deleted (append-only log)

**Common Role Changes:**
- student → professor (top contributor promotion)
- student → admin (Phase 2 hiring)
- admin → student (rogue admin demotion)

**Related Tables:** profiles  
**Key Indexes:** user_id, changed_by, created_at  
**RLS Policies:** 2 policies (super_admin only)

---

### 2.10 role_permissions

**Purpose:** Permission matrix for 4-tier role system  
**Created:** December 2025 (Phase 0.5)  
**Columns:** 11

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| role | text | NO | - | Primary key (student/professor/admin/super_admin) |
| can_manage_users | boolean | NO | false | Suspend/activate users |
| can_manage_content | boolean | NO | false | Approve/reject content |
| can_assign_roles | boolean | NO | false | Promote users (except create admins) |
| can_view_analytics | boolean | NO | false | Access analytics dashboard |
| can_view_financials | boolean | NO | false | Revenue/billing data (super_admin only) |
| can_create_admins | boolean | NO | false | Create admin accounts (super_admin only) |
| can_delete_users | boolean | NO | false | Delete user accounts (super_admin only) |
| can_bulk_upload | boolean | NO | false | CSV bulk upload access |
| can_configure_system | boolean | NO | false | Platform settings (super_admin only) |

**Pre-Loaded Data:**
```sql
INSERT INTO role_permissions VALUES
  ('super_admin', true, true, true, true, true, true, true, true, true),
  ('admin', true, true, true, true, false, false, false, true, false),
  ('professor', false, true, false, false, false, false, false, true, false),
  ('student', false, false, false, false, false, false, false, false, false);
```

**Why This Structure:**
- Centralized permission management
- Easy to add new permissions
- Queryable for UI (show/hide features based on role)

**Related Tables:** profiles  
**Key Indexes:** role (primary key)  
**RLS Policies:** 1 policy (public read)

---

### 2.11 comments

**Purpose:** Comments on shared notes  
**Created:** December 2025  
**Columns:** 5

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| note_id | uuid | NO | - | Foreign key to notes.id |
| user_id | uuid | NO | - | Foreign key to profiles.id |
| content | text | NO | - | Comment text |
| created_at | timestamp | NO | NOW() | Comment timestamp |

**Related Tables:** notes, profiles  
**Key Indexes:** note_id, user_id, created_at  
**RLS Policies:** Standard CRUD policies

---

### 2.12 upvotes

**Purpose:** Upvote tracking for quality notes  
**Created:** December 2025  
**Columns:** 4

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| note_id | uuid | NO | - | Foreign key to notes.id |
| user_id | uuid | NO | - | Foreign key to profiles.id |
| created_at | timestamp | NO | NOW() | Upvote timestamp |

**Why This Structure:**
- Unique constraint on (note_id, user_id) prevents duplicate upvotes
- Simple count aggregation for note rankings

**Related Tables:** notes, profiles  
**Key Indexes:** note_id, user_id, UNIQUE(note_id, user_id)  
**RLS Policies:** Standard CRUD policies

---

### 2.13 friendships ⭐ NEW

**Purpose:** Friend connections between users (social features)  
**Created:** January 9, 2026  
**Columns:** 6

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to profiles.id (who sent request) |
| friend_id | uuid | NO | - | Foreign key to profiles.id (who received request) |
| status | text | NO | 'pending' | pending/accepted/rejected |
| created_at | timestamp | NO | NOW() | When request was sent |
| updated_at | timestamp | NO | NOW() | When status changed |

**Why This Structure:**
- Bidirectional friendship model (A → B request, B accepts)
- `status` tracks request lifecycle (pending → accepted OR rejected)
- UNIQUE constraint on (user_id, friend_id) prevents duplicate requests
- Cascade delete: If user deleted, their friendships removed

**Friendship States:**
```
User A sends request → INSERT with status='pending'
User B accepts → UPDATE status='accepted'
User B rejects → UPDATE status='rejected'
```

**Use Cases:**
- Find Friends page (search by name/email)
- Friend Requests (list pending requests)
- My Friends (list accepted friends)
- Friends-only sharing (share note with specific friends)

**Related Tables:** profiles  
**Key Indexes:** user_id, friend_id, status  
**RLS Policies:** Standard CRUD policies (users manage own friendships)

**UNIQUE Constraint:**
```sql
UNIQUE(user_id, friend_id)
```
Prevents: User A sending multiple requests to User B

---

### 2.14 study_groups ⭐ UPDATED

**Purpose:** Study group metadata (name, description, creator)
**Created:** February 6, 2026
**Last Updated:** March 19, 2026 (added invite_token, group_type, linked_course)
**Columns:** 12

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| name | text | NO | - | Group name |
| description | text | YES | - | Optional description |
| created_by | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| is_batch_group | boolean | NO | false | True = official batch group created by admin; hides Leave/Delete for members |
| batch_course | text | YES | NULL | Course level this batch group belongs to (e.g. 'CA Foundation') |
| batch_institution | text | YES | NULL | Institution this batch group belongs to (e.g. 'More Classes Commerce'). Isolates groups per B2B client. |
| invite_token | uuid | YES | gen_random_uuid() | Shareable join link token — used in `/join/:token` public URL |
| group_type | text | NO | 'custom' | CHECK: 'batch' \| 'system_course' \| 'custom'. 'batch' = official B2B group; 'system_course' = linked to user's enrolled course; 'custom' = free-form group |
| linked_course | text | YES | NULL | For group_type='system_course': the course level the group is linked to (e.g. 'CA Inter') |
| created_at | timestamptz | NO | NOW() | When created |
| updated_at | timestamptz | NO | NOW() | When last updated |

**Batch group isolation:** `batch_course` + `batch_institution` together uniquely identify a batch. `create_batch_group` RPC auto-enrolls enrolled students matching both fields. Prevents students from different institutes sharing the same batch group.

**Join links:** Any group (batch or personal) can be joined via `/join/:invite_token`. `get_group_preview` and `join_group_by_token` RPCs both work for all group types — the old `is_batch_group = false` filter has been removed.

**Key Indexes:** created_by, created_at
**RLS Policies:** Members can read, creator can update/delete, authenticated can insert own

---

### 2.15 study_group_members ⭐ UPDATED

**Purpose:** Group membership with roles (admin/member) and invitation status
**Created:** February 6, 2026
**Updated:** February 6, 2026 (added status + invited_by for invitation flow)
**Columns:** 7

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| group_id | uuid | NO | - | FK to study_groups.id, ON DELETE CASCADE |
| user_id | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| role | text | NO | 'member' | CHECK: admin or member |
| joined_at | timestamptz | NO | NOW() | When joined (updated to NOW() on accept) |
| status | text | NO | 'active' | CHECK: 'invited' or 'active'. Default 'active' for backward compat. |
| invited_by | uuid | YES | NULL | FK to profiles.id, ON DELETE SET NULL. Who sent the invitation. |

**UNIQUE Constraint:** `UNIQUE(group_id, user_id)` - prevents duplicate membership
**Key Indexes:** group_id, user_id, role, status
**RLS Policies:** Members read own groups, admins insert/delete, user can delete self

---

### 2.16 content_group_shares ⭐ NEW

**Purpose:** Links content (notes/decks) to study groups for shared access
**Created:** February 6, 2026
**Columns:** 6

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| group_id | uuid | NO | - | FK to study_groups.id, ON DELETE CASCADE |
| content_type | text | NO | - | CHECK: 'note' or 'flashcard_deck' |
| content_id | uuid | NO | - | ID of the note or flashcard_deck |
| shared_by | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| shared_at | timestamptz | NO | NOW() | When shared |

**UNIQUE Constraint:** `UNIQUE(group_id, content_type, content_id)` - prevents duplicate shares
**Key Indexes:** group_id, (content_type, content_id), shared_by
**RLS Policies:** Members read, admins insert/delete
**ON DELETE CASCADE:** Deleting group removes shares but NOT the original notes/decks

---

### 2.18 content_flags ⭐ NEW

**Purpose:** Stores user-submitted flags on notes and flashcards. Routes content_error flags to the content creator (professor) and inappropriate/other flags to admin.
**Created:** March 2026 (Sprint 2.8-B)
**Columns:** 12

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| flagged_by | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| content_type | text | NO | - | CHECK IN ('flashcard', 'note') |
| content_id | uuid | NO | - | ID of the flagged note or flashcard |
| reason | text | NO | - | CHECK IN ('content_error', 'inappropriate', 'other') |
| details | text | YES | NULL | Optional student description of the issue (max 500 chars) |
| status | text | NO | 'pending' | CHECK IN ('pending', 'resolved', 'rejected', 'removed') |
| priority | text | NO | 'normal' | CHECK IN ('normal', 'high') — auto-escalates to 'high' when 3+ flags |
| resolved_by | uuid | YES | NULL | FK to profiles.id — who resolved/dismissed the flag |
| resolution_note | text | YES | NULL | Admin/professor note on resolution |
| created_at | timestamptz | NO | now() | When flagged |
| resolved_at | timestamptz | YES | NULL | When resolved/rejected/removed |

**Key Indexes:**
- `idx_content_flags_content` on (content_type, content_id) — fast item lookup
- `idx_content_flags_status` on (status, priority, created_at DESC) — queue ordering

**RLS Policies:**
- `flags_insert` — authenticated users can INSERT where flagged_by = auth.uid()
- `flags_select_own` — users can SELECT their own flags (for "already flagged" state)
- `flags_select_admin` — admins/super_admins can SELECT all flags
- Professors and admins can read all flags (existing policy from original table)
- Admins can update flag status (existing policy)

**RPCs using this table:**
- `submit_content_flag(p_content_type, p_content_id, p_reason, p_details)` — inserts flag, dedup check, priority escalation, notifies creator + admins, returns jsonb
- `get_my_content_flags()` — professor queue: pending content_error flags on own content
- `get_admin_flags(p_status)` — admin queue: all flags filtered by status
- `resolve_content_flag(p_flag_id, p_action, p_resolution_note)` — sets status to resolved/rejected/removed

**Flag Routing:**
- `content_error` → Professor (creator of flagged item) + admin can see/override
- `inappropriate` → Admin/super_admin only (creator cannot self-resolve — conflict of interest)
- `other` → Admin first, escalate to creator if needed

**Priority Escalation:** When 3+ users flag the same content_id, all pending flags for that item auto-set to priority = 'high'.

---

### 2.17 notifications ⭐ NEW

**Purpose:** User notifications (group invites, friend requests, etc.) with JSONB metadata
**Created:** February 6, 2026
**Columns:** 8

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| user_id | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| type | text | NO | - | Notification type (e.g., 'group_invite', 'friend_request') |
| title | text | NO | - | Notification title |
| message | text | YES | NULL | Notification body/description |
| is_read | boolean | NO | false | Read/unread status |
| metadata | jsonb | YES | NULL | Type-specific data (group_id, membership_id, etc.) |
| created_at | timestamptz | NO | NOW() | When notification was created |

**Key Indexes:** user_id, is_read, created_at DESC, composite unread (user_id WHERE is_read=false)
**RLS Policies:** Users can SELECT/UPDATE/DELETE own rows only. INSERT allowed for authenticated.
**Realtime:** Must enable Supabase Realtime on this table (Dashboard → Database → Replication)

---

### 2.14 content_creators ⭐ NEW

**Purpose:** Track content creators (Vivitsu, professors) for revenue attribution  
**Created:** January 9, 2026  
**Columns:** 6

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| name | text | NO | - | Display name (e.g., "Vivitsu", "Prof. Sharma") |
| type | text | NO | 'individual' | individual/organization |
| email | text | YES | NULL | Contact email (unique if provided) |
| revenue_share_percentage | decimal | NO | 30.0 | Default 30% (configurable per creator) |
| created_at | timestamp | NO | NOW() | When creator was added |

**Why This Structure:**
- Flexible system supports both individual professors AND organizations (Vivitsu)
- `revenue_share_percentage` configurable per creator:
  - Vivitsu (organization): 30%
  - Professors (individual): 40%
  - Student creators (individual): 40% (future)
- `type` enables different handling for orgs vs individuals

**Creator Types:**

**Organization Example (Vivitsu):**
```sql
INSERT INTO content_creators (name, type, email, revenue_share_percentage)
VALUES ('Vivitsu', 'organization', 'contact@vivitsu.com', 30.0);
```

**Individual Example (Professor):**
```sql
INSERT INTO content_creators (name, type, email, revenue_share_percentage)
VALUES ('Prof. Sharma', 'individual', 'sharma@example.com', 40.0);
```

**Revenue Attribution Flow:**
1. Student reviews flashcard
2. System checks flashcard.content_creator_id
3. Monthly: Calculate usage per creator
4. Payout: creator_revenue = total_revenue × usage_percentage × revenue_share_percentage

**Use Cases:**
- Vivitsu partnership (revenue sharing)
- Professor contributor payments
- Student creator monetization (Phase 3+)

**Related Tables:** flashcards (content_creator_id), profiles  
**Key Indexes:** email (unique), type  
**RLS Policies:** Public read, admin write

**Phase 1-2 Usage:**
- Manual entry (you create rows via SQL)
- Track Vivitsu partnership

**Phase 3+ Usage:**
- Self-service creator onboarding
- Automated revenue tracking
- Creator dashboard

---

## study_sessions (Sprint 3.1)

Stores completed study sessions only. Incomplete/abandoned sessions are held in localStorage and never written to the DB.

| Column | Type | Constraints |
|---|---|---|
| `id` | uuid | PK, default gen_random_uuid() |
| `user_id` | uuid | NOT NULL, FK → auth.users ON DELETE CASCADE |
| `started_at` | timestamptz | NOT NULL |
| `ended_at` | timestamptz | NOT NULL |
| `duration_seconds` | integer | NOT NULL, CHECK > 0 |
| `session_date` | date | NOT NULL — stored as user's LOCAL date (YYYY-MM-DD), passed from frontend |
| `source` | text | NOT NULL, CHECK IN ('manual', 'study_mode') |
| `created_at` | timestamptz | DEFAULT now() |

**RLS:** Enabled. INSERT and SELECT for own rows only (`auth.uid() = user_id`). No UPDATE or DELETE — sessions are immutable.

**Index:** `idx_study_sessions_user_date` on `(user_id, session_date)` — optimises the stats RPC.

**Design decision — no incomplete rows:** The single INSERT pattern means the DB stores only sessions that actually completed. Abandoned sessions are recovered client-side via localStorage on next app load (< 4h recovery prompt, ≥ 4h silent discard).

**Design decision — local date:** `session_date` is the user's local date (`new Date().toLocaleDateString('en-CA')`), not UTC. This is critical for users in UTC+5:30 and later — after 6:30 PM UTC the DB's `CURRENT_DATE` would already be "tomorrow".

---

## follows (Sprint 3.4)

Unilateral follow relationships. A follower can follow any user without mutual consent.

| Column | Type | Constraints |
|---|---|---|
| `id` | uuid | PK, default gen_random_uuid() |
| `follower_id` | uuid | NOT NULL, FK → auth.users ON DELETE CASCADE |
| `followee_id` | uuid | NOT NULL, FK → auth.users ON DELETE CASCADE |
| `created_at` | timestamptz | DEFAULT now() |

**Constraints:** `UNIQUE(follower_id, followee_id)`, `CHECK(follower_id <> followee_id)`

**RLS:** Enabled.
- INSERT: `auth.uid() = follower_id`
- DELETE: `auth.uid() = follower_id`
- SELECT: `auth.uid() = follower_id OR auth.uid() = followee_id`

**Indexes:** `follows_follower_id_idx` on `follower_id`, `follows_followee_id_idx` on `followee_id`

**Design note:** Asymmetric by design — followee does not gain access to follower stats. Stats shown on Following.jsx are public to all followers.

---

## follow_user (Sprint 3.4)

```sql
follow_user(p_followee_id uuid)
RETURNS jsonb  -- { success: boolean }
SECURITY DEFINER
```

**Purpose:** Idempotent follow. Prevents self-follow. Fires a `'follow'` notification to followee only on a genuinely new row (checked via `GET DIAGNOSTICS ROW_COUNT`).
**Caller:** `AuthorProfile.jsx`

---

## unfollow_user (Sprint 3.4)

```sql
unfollow_user(p_followee_id uuid)
RETURNS jsonb  -- { success: boolean }
SECURITY DEFINER
```

**Purpose:** DELETE from follows where `follower_id = auth.uid()`.
**Caller:** `AuthorProfile.jsx`, `Following.jsx`

---

## get_friends_leaderboard (Sprint 3.5)

```sql
get_friends_leaderboard()
RETURNS TABLE (
  rank                          integer,
  user_id                       uuid,
  full_name                     text,
  is_self                       boolean,
  reviews_this_week             bigint,
  study_time_this_week_seconds  bigint
)
```

**Purpose:** Returns the caller + all mutual friends who are students, ranked for the leaderboard widget (Friends tab).
**Security:** SECURITY DEFINER. Caller must be authenticated (`auth.uid()` checked). Students only (`profiles.role = 'student'`).
**Ranking:** DENSE_RANK — `reviews_this_week DESC`, `study_time_this_week_seconds DESC` as tiebreaker. Tied rows share same rank integer. No streak.
**Week boundary:** `date_trunc('week', CURRENT_DATE)` (Monday, server UTC). All stats COALESCE to 0.
**Caller:** `LeaderboardWidget.jsx` (Friends tab). Fetches on mount.

---

## get_following_leaderboard (Sprint 3.5)

```sql
get_following_leaderboard()
RETURNS TABLE (
  rank                          integer,
  user_id                       uuid,
  full_name                     text,
  is_self                       boolean,
  reviews_this_week             bigint,
  study_time_this_week_seconds  bigint
)
```

**Purpose:** Returns top 20 followees (students only) + the caller's own row regardless of rank, for the leaderboard widget (Following tab).
**Security:** SECURITY DEFINER. Caller must be authenticated. Students only.
**Ranking:** Aggregates full followee set before applying top-20 limit — caller's rank is exact, not an approximation. Same DENSE_RANK logic as friends leaderboard.
**Caller:** `LeaderboardWidget.jsx` (Following tab). Fetches lazily on first tab click.

---

## update_daily_goal (Sprint 3.5)

```sql
update_daily_goal(
  p_review_goal        integer DEFAULT NULL,
  p_study_goal_minutes integer DEFAULT NULL
)
RETURNS void
```

**Purpose:** Updates `daily_review_goal` and `daily_study_goal_minutes` on the caller's profile row. Either argument can be NULL to clear that goal type. Passing both as NULL clears all goals.
**Security:** SECURITY DEFINER. `auth.uid()` checked before UPDATE.
**Caller:** `GoalProgressWidget.jsx` — on Set and on Clear goal.

---

## get_following_with_stats (Sprint 3.4)

```sql
get_following_with_stats()
RETURNS TABLE (
  user_id                      uuid,
  full_name                    text,
  course_level                 text,
  role                         text,
  reviews_this_week            bigint, -- COUNT from reviews.created_at >= date_trunc('week', CURRENT_DATE)
  streak_days                  integer,-- from get_user_streak(followee_id)
  study_time_this_week_seconds bigint, -- SUM from study_sessions.session_date >= week start
  following_since              timestamptz
)
SECURITY DEFINER
```

**Purpose:** All users the caller follows with public weekly stats. No cross-follow check — stats are public to all followers by design.
**Caller:** `Following.jsx`
- `reviews_this_week` — COUNT from `reviews` where `created_at >= date_trunc('week', CURRENT_DATE::timestamptz)`
- `streak_days` — result of `get_user_streak(followee_id)`
- `study_time_this_week_seconds` — SUM of `duration_seconds` from `study_sessions` where `session_date >= date_trunc('week', CURRENT_DATE)::date`
- All stats COALESCE to 0. Ordered by `created_at DESC`.

---

## get_follow_status (Sprint 3.4)

```sql
get_follow_status(p_target_id uuid)
RETURNS jsonb  -- { is_following: boolean }
SECURITY DEFINER
```

**Purpose:** EXISTS check — is the caller currently following `p_target_id`? Used to initialise the Follow button state on `AuthorProfile.jsx`.
**Caller:** `AuthorProfile.jsx`

---

## get_discoverable_users (Sprint 3.3)

```sql
get_discoverable_users()
RETURNS TABLE (
  user_id       uuid,
  full_name     text,
  masked_email  text,   -- first_char***@domain — raw email never returned
  course_level  text,
  institution   text,
  role          text
)
SECURITY DEFINER
```

**Purpose:** Returns users the caller can send friend requests to.
**Security:** Caller must be authenticated (`auth.uid()` not null). Bypasses RLS to read profiles but never returns raw email.
**Filtering:** Same `course_level` as caller; excludes self; excludes any user with a `pending` or `accepted` friendship in either direction. Rejected friendships are not excluded (re-adding is allowed).
**Caller:** `FindFriends.jsx` — replaces direct `profiles` table query.

---

## get_my_friends_with_stats (Sprint 3.3)

```sql
get_my_friends_with_stats()
RETURNS TABLE (
  friendship_id                uuid,
  user_id                      uuid,
  full_name                    text,
  masked_email                 text,   -- first_char***@domain
  course_level                 text,
  role                         text,
  reviews_this_week            bigint, -- COUNT from reviews.created_at >= date_trunc('week', CURRENT_DATE)
  streak_days                  integer,-- from get_user_streak(user_id)
  study_time_this_week_seconds bigint, -- SUM from study_sessions.session_date >= week start
  friends_since                timestamp without time zone  -- friendships.updated_at (acceptance time)
)
SECURITY DEFINER
```

**Purpose:** Returns confirmed friends with weekly activity stats in one call.
**Security:** Caller must be authenticated. Confirmed (`status = 'accepted'`) friendships only — no stat leakage for pending requests.
**Stats:** All stat fields COALESCE to 0 for friends with no activity. Week boundary: `date_trunc('week', CURRENT_DATE)` (Monday, server UTC).
**Caller:** `MyFriends.jsx` — replaces two-step N+1 fetch (friendships → profiles).

---

## get_batch_group_member_stats (Sprint 3.2)

```sql
get_batch_group_member_stats(p_group_id uuid)
RETURNS TABLE (
  user_id                      uuid,
  full_name                    text,
  reviews_this_week            bigint,
  streak_days                  integer,
  study_time_this_week_seconds bigint,
  last_active_date             date
)
SECURITY DEFINER
```

- **Security gate 1:** Caller's `role` in `profiles` must be `professor`, `admin`, or `super_admin` — otherwise raises exception `'Access denied'`
- **Security gate 2:** `p_group_id` must resolve to a `study_groups` row with `is_batch_group = true` — otherwise raises `'Not a batch group'`
- `reviews_this_week` — COUNT of reviews rows where `created_at >= date_trunc('week', CURRENT_DATE)`
- `streak_days` — result of `get_user_streak(user_id)` (existing function)
- `study_time_this_week_seconds` — SUM of `duration_seconds` from `study_sessions` where `session_date >= date_trunc('week', CURRENT_DATE)::date`
- `last_active_date` — `MAX(created_at)::date` from reviews for that user
- All aggregates use `COALESCE(..., 0)` — students with zero activity return `0`, not NULL
- Week boundary: `date_trunc('week', CURRENT_DATE)` (Monday start, server UTC — acceptable for aggregated batch data)
- Filters `study_group_members` on `group_id = p_group_id AND status = 'active'`

---

## get_study_time_stats (Sprint 3.1)

```sql
get_study_time_stats(p_user_id uuid, p_local_date date)
RETURNS TABLE (today_seconds bigint, week_seconds bigint, today_sessions bigint, week_sessions bigint)
SECURITY DEFINER
```

- `p_local_date` — today's date in the user's local timezone, passed from frontend as `new Date().toLocaleDateString('en-CA')`
- Week bounds: Monday–Sunday of the ISO week containing `p_local_date` (Postgres `date_trunc('week', ...)`)
- Filters strictly by `p_user_id` — no cross-user access
- Called by authenticated users for their own stats only

---

## 3. RLS POLICIES

**Total Policies:** 26 ⭐ (was 24 — added 2 for study_sessions)
**Last Updated:** January 2, 2026

### 3.1 profiles Table Policies

#### Policy: super_admin_select_profiles
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `(SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin'`
- **Purpose:** Super admins can view ALL user profiles
- **Created:** January 2, 2026 (after 2-hour debugging session)
- **Why Needed:** Admin dashboard requires full user list for management

#### Policy: users_select_own_profile
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `id = auth.uid()`
- **Purpose:** Users can view their own profile
- **Why Needed:** User settings page, profile display

#### Policy: users_update_own_profile
- **Command:** UPDATE
- **Roles:** authenticated
- **Condition:** `id = auth.uid()`
- **Purpose:** Users can update their own profile
- **Why Needed:** Change name, course level, settings

#### Policy: users_insert_own_profile
- **Command:** INSERT
- **Roles:** authenticated
- **Condition:** `id = auth.uid()`
- **Purpose:** Users can create their own profile during signup
- **Why Needed:** Signup flow creates profile after auth

---

### 3.2 notes Table Policies

#### Policy: super_admin_view_all_notes
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `(SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin'`
- **Purpose:** Super admins can view ALL notes (public + private)
- **Created:** January 2, 2026
- **Why Needed:** Content moderation, admin dashboard statistics

#### Policy: users_view_public_notes
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `is_public = true`
- **Purpose:** All users can view public notes
- **Why Needed:** Browse Notes page, community learning

#### Policy: users_view_own_notes
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can view their own notes (public + private)
- **Why Needed:** My Notes page

#### Policy: users_insert_notes
- **Command:** INSERT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can create notes
- **Why Needed:** Note upload feature

#### Policy: users_update_own_notes
- **Command:** UPDATE
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can edit their own notes
- **Why Needed:** Note editing, toggle public/private

#### Policy: users_delete_own_notes
- **Command:** DELETE
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can delete their own notes
- **Why Needed:** My Notes delete button

---

### 3.3 flashcards Table Policies

#### Policy: super_admin_view_all_flashcards
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `(SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin'`
- **Purpose:** Super admins can view ALL flashcards (public + private)
- **Created:** January 2, 2026
- **Why Needed:** Content moderation, analytics

#### Policy: users_view_public_flashcards
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `is_public = true`
- **Purpose:** All users can view public flashcards
- **Why Needed:** Review Flashcards page (browse professor/peer content)

#### Policy: users_view_own_flashcards
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can view their own flashcards
- **Why Needed:** My Flashcards page

#### Policy: users_insert_flashcards
- **Command:** INSERT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can create flashcards
- **Why Needed:** Create Flashcard, Bulk Upload

#### Policy: users_update_own_flashcards
- **Command:** UPDATE
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can edit their own flashcards
- **Why Needed:** Inline edit, toggle public/private

#### Policy: users_delete_own_flashcards
- **Command:** DELETE
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can delete their own flashcards
- **Why Needed:** My Flashcards delete button

---

### 3.4 reviews Table Policies

#### Policy: super_admin_view_all_reviews
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `(SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin'`
- **Purpose:** Super admins can view ALL review history
- **Created:** January 2, 2026
- **Why Needed:** Analytics, study pattern analysis

#### Policy: users_view_own_reviews
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can view their own review history
- **Why Needed:** My Progress page, streak calculation

#### Policy: users_insert_reviews
- **Command:** INSERT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can create review records
- **Why Needed:** Review session creates review records

#### Policy: users_update_own_reviews
- **Command:** UPDATE
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can update their own review records
- **Why Needed:** SuperMemo-2 algorithm updates next_review_date

---

### 3.5 Other Tables (Public Read)

#### disciplines, subjects, topics
- **Policy:** Enable read access for all users
- **Condition:** `true` (public read)
- **Why:** Course structure is public data, needed for dropdowns

#### role_permissions
- **Policy:** Enable read access for all users
- **Condition:** `true` (public read)
- **Why:** UI needs to check permissions for show/hide features

---

### 3.6 Audit Logs (Super Admin Only)

#### admin_audit_log
- **SELECT Policy:** Super admin only
- **INSERT Policy:** Admin/super_admin only
- **Why:** Security audit trail, sensitive data

#### role_change_log
- **SELECT Policy:** Super admin only
- **INSERT Policy:** Admin/super_admin only
- **Why:** Security audit trail, role changes are sensitive

---

## 4. SQL FUNCTIONS

**Total Functions:** 1

### 4.1 get_user_activity_stats()

**Purpose:** Calculate user activity statistics for admin dashboard  
**Created:** January 2, 2026  
**Return Type:** TABLE (record)

**Function Definition:**
```sql
CREATE OR REPLACE FUNCTION get_user_activity_stats()
RETURNS TABLE (
  total_users bigint,
  active_today bigint,
  active_this_week bigint,
  new_users_today bigint,
  new_users_this_week bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM profiles)::bigint as total_users,
    (SELECT COUNT(DISTINCT user_id) FROM reviews 
     WHERE created_at >= CURRENT_DATE)::bigint as active_today,
    (SELECT COUNT(DISTINCT user_id) FROM reviews 
     WHERE created_at >= CURRENT_DATE - INTERVAL '7 days')::bigint as active_this_week,
    (SELECT COUNT(*) FROM profiles 
     WHERE created_at >= CURRENT_DATE)::bigint as new_users_today,
    (SELECT COUNT(*) FROM profiles 
     WHERE created_at >= CURRENT_DATE - INTERVAL '7 days')::bigint as new_users_this_week;
END;
$$ LANGUAGE plpgsql;
```

**Returns:**
- `total_users` - Total user count
- `active_today` - Users who reviewed flashcards today
- `active_this_week` - Users who reviewed in last 7 days
- `new_users_today` - Signups today
- `new_users_this_week` - Signups in last 7 days

**Used By:**
- Super Admin Dashboard (statistics cards)
- Admin Dashboard (user activity overview)

**Performance:** Efficient with proper indexes on `created_at` columns

**Testing Query:**
```sql
-- [TEST] User Activity Function
SELECT * FROM get_user_activity_stats();
```

**Why This Function:**
- Centralized logic for dashboard statistics
- Single query vs 5 separate queries (performance)
- Consistent calculation across admin views
- Easy to update if metrics change

### 4.2 get_filtered_authors_for_notes()

**Purpose:** Return authors with PUBLIC notes matching filter criteria (server-side author filtering)  
**Created:** February 5, 2026  
**Return Type:** TABLE (id UUID, full_name TEXT, role TEXT)

**Function Definition:**
```sql
CREATE OR REPLACE FUNCTION get_filtered_authors_for_notes(
  p_course TEXT DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_role TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    p.id,
    p.full_name,
    p.role
  FROM profiles p
  INNER JOIN notes n ON n.user_id = p.id
  WHERE 
    n.visibility = 'public'
    AND (p_course IS NULL OR n.target_course = p_course)
    AND (p_subject_id IS NULL OR n.subject_id = p_subject_id)
    AND (p_role IS NULL OR p.role = p_role)
  ORDER BY p.full_name;
END;
$$;

Parameters:

p_course (TEXT, optional) - Filter by target_course
p_subject_id (UUID, optional) - Filter by subject_id
p_role (TEXT, optional) - Filter by role ('professor' or 'student')
Returns:

id - Author's profile UUID
full_name - Author's display name
role - Author's role (professor/student)
Used By:

BrowseNotes.jsx - Dynamic Author dropdown filtering
Why This Function:

Server-side filtering prevents client from fetching all authors
Only returns authors with PUBLIC content (visibility enforcement)
Enables dependent filter behavior (Author list updates when Course/Subject/Role changes)

4.3 get_filtered_authors_for_flashcards()
Purpose: Return authors with PUBLIC flashcard decks matching filter criteria
Created: February 5, 2026
Return Type: TABLE (id UUID, full_name TEXT, role TEXT)

Function Definition:

CREATE OR REPLACE FUNCTION get_filtered_authors_for_flashcards(
  p_course TEXT DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_role TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    p.id,
    p.full_name,
    p.role
  FROM profiles p
  INNER JOIN flashcard_decks fd ON fd.user_id = p.id
  WHERE 
    fd.visibility = 'public'
    AND fd.card_count > 0
    AND (p_course IS NULL OR fd.target_course = p_course)
    AND (p_subject_id IS NULL OR fd.subject_id = p_subject_id)
    AND (p_role IS NULL OR p.role = p_role)
  ORDER BY p.full_name;
END;
$$;

Parameters:

p_course (TEXT, optional) - Filter by target_course
p_subject_id (UUID, optional) - Filter by subject_id
p_role (TEXT, optional) - Filter by role ('professor' or 'student')
Returns:

id - Author's profile UUID
full_name - Author's display name
role - Author's role (professor/student)
Used By:

ReviewFlashcards.jsx - Dynamic Author dropdown filtering
Why This Function:

Server-side filtering for performance and security
Only returns authors with PUBLIC decks containing cards
Enables dependent filter behavior (Author list updates when filters change)
---

## 5. INDEXES

**Total Indexes:** 50+ (automatic + custom)

### 5.1 Primary Key Indexes (Automatic)
Every table has automatic B-tree index on primary key (id column).

### 5.2 Foreign Key Indexes (Automatic)
Automatic indexes on all foreign key columns for join performance.

### 5.3 Custom Indexes

#### profiles Table
```sql
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_created_at ON profiles(created_at);
CREATE INDEX idx_profiles_course_level ON profiles(course_level);
CREATE INDEX idx_profiles_timezone ON profiles(timezone);  -- ✅ NEW (2026-01-30) 
**Key Indexes:** email (unique), role, created_at, course_level, timezone

```

#### notes Table
```sql
CREATE INDEX idx_notes_user_id ON notes(user_id);
CREATE INDEX idx_notes_target_course ON notes(target_course);
CREATE INDEX idx_notes_is_public ON notes(is_public);
CREATE INDEX idx_notes_created_at ON notes(created_at);
CREATE INDEX idx_notes_discipline_id ON notes(discipline_id);
CREATE INDEX idx_notes_subject_id ON notes(subject_id);
CREATE INDEX idx_notes_topic_id ON notes(topic_id);
CREATE INDEX idx_notes_is_verified ON notes(is_verified);
```

#### flashcards Table
```sql
CREATE INDEX idx_flashcards_user_id ON flashcards(user_id);
CREATE INDEX idx_flashcards_batch_id ON flashcards(batch_id); -- CRITICAL
CREATE INDEX idx_flashcards_target_course ON flashcards(target_course);
CREATE INDEX idx_flashcards_is_public ON flashcards(is_public);
CREATE INDEX idx_flashcards_created_at ON flashcards(created_at);
CREATE INDEX idx_flashcards_discipline_id ON flashcards(discipline_id);
CREATE INDEX idx_flashcards_subject_id ON flashcards(subject_id);
CREATE INDEX idx_flashcards_topic_id ON flashcards(topic_id);
CREATE INDEX idx_flashcards_creator_id ON flashcards(creator_id); -- ⭐ NEW (Jan 9, 2026)
```

**CRITICAL:** `idx_flashcards_batch_id` is essential for MyFlashcards.jsx grouping performance.

#### friendships Table ⭐ NEW
```sql
CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);
```

**Why These Indexes:**
- `user_id` index: Find all requests sent by a user
- `friend_id` index: Find all requests received by a user
- `status` index: Filter by pending/accepted/rejected
- All three enable fast "Find Friends", "Friend Requests", "My Friends" pages

#### reviews Table
```sql
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_flashcard_id ON reviews(flashcard_id);
CREATE INDEX idx_reviews_next_review_date ON reviews(next_review_date);
CREATE INDEX idx_reviews_created_at ON reviews(created_at); -- For streak calculation
CREATE INDEX idx_reviews_status ON reviews(status); -- ⭐ NEW (Feb 6, 2026) - Card suspension
CREATE INDEX idx_reviews_skip_until ON reviews(skip_until); -- ⭐ NEW (Feb 6, 2026) - Skip filtering
CREATE INDEX idx_reviews_user_status_due ON reviews(user_id, status, next_review_date) WHERE status = 'active'; -- ⭐ NEW (Feb 6, 2026) - Composite partial
```

#### subjects Table
```sql
CREATE INDEX idx_subjects_discipline_id ON subjects(discipline_id);
CREATE INDEX idx_subjects_name ON subjects(name);
CREATE INDEX idx_subjects_is_active ON subjects(is_active);
```

#### topics Table
```sql
CREATE INDEX idx_topics_subject_id ON topics(subject_id);
CREATE INDEX idx_topics_name ON topics(name);
CREATE INDEX idx_topics_is_active ON topics(is_active);
```

#### admin_audit_log Table
```sql
CREATE INDEX idx_admin_audit_admin_id ON admin_audit_log(admin_id);
CREATE INDEX idx_admin_audit_target_user ON admin_audit_log(target_user_id);
CREATE INDEX idx_admin_audit_created_at ON admin_audit_log(created_at);
```

#### role_change_log Table
```sql
CREATE INDEX idx_role_change_user_id ON role_change_log(user_id);
CREATE INDEX idx_role_change_changed_by ON role_change_log(changed_by);
CREATE INDEX idx_role_change_created_at ON role_change_log(created_at);
```

### 5.4 Performance Notes

**Query Performance:**
- Dashboard loads: <500ms (with indexes)
- Filter operations: <200ms (indexed columns)
- Review session: <100ms (indexed next_review_date)

**Index Maintenance:**
- PostgreSQL auto-maintains indexes
- VACUUM runs automatically on Supabase
- No manual maintenance required for Phase 1

---

## 6. TRIGGERS

**Active Triggers (as of March 2026):**

### `on_auth_user_created` → `handle_new_user()`
- **Table:** `auth.users` AFTER INSERT
- **Function:** `handle_new_user()` SECURITY DEFINER
- **Purpose:** Creates a `profiles` row for every new auth user. Uses `raw_user_meta_data` for `full_name` and `course_level`. Defaults: `role='student'`, `account_type='self_registered'`, `status='active'`.
- **Why trigger instead of client INSERT:** With email confirmation ON, `signUp()` returns no session. `auth.uid()` is null. Any client-side `profiles.insert()` is silently blocked by RLS. The trigger fires at the DB level regardless of session state.
- **ON CONFLICT DO NOTHING** — safe to re-run; won't overwrite existing profiles.
- **Added:** March 19, 2026

### `trigger_update_deck_card_count` → `update_deck_card_count()`
- **Table:** `flashcards` AFTER INSERT, UPDATE, DELETE
- **Purpose:** Maintains `card_count` on `flashcard_decks`. On INSERT: increments or creates deck row. On DELETE: decrements; deletes deck row if count reaches 0.
- **⚠️ CRITICAL:** Do NOT add a second trigger on `flashcards` — causes double-counting. Always check first: `SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema='public' AND event_object_table='flashcards'`

### `trg_aaa_counter_notes/flashcards/reviews/upvotes/friendships`
- **Purpose:** Maintain `user_stats` integer counters for O(1) badge eligibility checks. Named `trg_aaa_*` to fire before `trg_badge_*` alphabetically.

### `trg_badge_*` (multiple)
- **Purpose:** Award badges on milestone events (deck_builder, social_learner, etc.). Read from `user_stats` counters, not COUNT(*).

### `trg_badge_new_profile`
- **Table:** `profiles` AFTER INSERT
- **Purpose:** Initializes `user_stats` row for new user + awards pioneer badge.

---

## 7. MIGRATION HISTORY

### Migration 001: Initial Schema (December 2025)
**File:** `001_initial_schema.sql`  
**Created:** December 15, 2025  
**Purpose:** Create all core tables for Phase 1 MVP

**Tables Created:**
- profiles
- notes
- flashcards
- reviews
- disciplines
- subjects
- topics
- comments
- upvotes
- role_permissions

**RLS Policies:** Basic CRUD policies for all tables

---

### Migration 002: Batch Tracking (December 26, 2025)
**File:** `001_add_batch_tracking.sql`  
**Created:** December 26, 2025  
**Purpose:** Add batch_id and batch_description to flashcards table

**Changes:**
```sql
ALTER TABLE flashcards ADD COLUMN batch_id UUID DEFAULT uuid_generate_v4();
ALTER TABLE flashcards ADD COLUMN batch_description TEXT;
CREATE INDEX idx_flashcards_batch_id ON flashcards(batch_id);
```

**Why:** Solved issue where toggling public/private merged batches unintentionally

**Backfill:** Assigned batch_id to existing 52 flashcards (27 public + 25 private)

---

### Migration 003: Super Admin RLS Policies (January 2, 2026)
**File:** `002_super_admin_rls_policies.sql`  
**Created:** January 2, 2026  
**Purpose:** Add RLS policies for super_admin to view all data

**Policies Created:**
- super_admin_select_profiles
- super_admin_view_all_notes
- super_admin_view_all_flashcards
- super_admin_view_all_reviews

**Why:** Admin dashboard was empty because super_admin couldn't view other users' data

**Debugging Time Saved:** 2+ hours (this is why this documentation exists!)

---

### Migration 004: User Activity Function (January 2, 2026)
**File:** `003_user_activity_function.sql`  
**Created:** January 2, 2026  
**Purpose:** Create get_user_activity_stats() function for admin dashboard

**Function:** `get_user_activity_stats()`

**Why:** Centralized statistics calculation, improved performance

---

---

### Migration 005: Content Creator Attribution (January 9, 2026)
**File:** `005_content_creator_attribution.sql`  
**Created:** January 9, 2026  
**Purpose:** Add creator attribution and prepare for Vivitsu partnership

**Changes:**
```sql
-- 1. Add creator_id to flashcards (user attribution)
ALTER TABLE flashcards ADD COLUMN creator_id UUID REFERENCES profiles(id);

-- 2. Backfill existing flashcards
UPDATE flashcards SET creator_id = user_id WHERE creator_id IS NULL;

-- 3. Create content_creators table
CREATE TABLE content_creators (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  type TEXT CHECK (type IN ('individual', 'organization')) DEFAULT 'individual',
  email TEXT UNIQUE,
  revenue_share_percentage DECIMAL DEFAULT 30.0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 4. Link flashcards to content creators
ALTER TABLE flashcards ADD COLUMN content_creator_id UUID REFERENCES content_creators(id);

-- 5. Create friendships table
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  friend_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('pending', 'accepted', 'rejected')) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- 6. Add indexes
CREATE INDEX idx_flashcards_creator_id ON flashcards(creator_id);
CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);
```

**Why:**
- Enables Vivitsu partnership with clear revenue tracking
- Separates operational attribution (who uploaded) from financial attribution (who gets paid)
- Prepares for February social features (friend requests)
- Future-proofs for B2B expansion and student creator monetization

**Backfill Note:** All existing flashcards got creator_id = user_id (original uploader)

---

## 8. COMMON ISSUES & TROUBLESHOOTING

### Issue 1: Admin Dashboard Shows "No Users Found"

**Symptom:** Super admin logs in, dashboard shows 0 users

**Cause:** Missing RLS policy on profiles table for super_admin role

**Fix:**
```sql
-- Run this in Supabase SQL Editor
CREATE POLICY super_admin_select_profiles ON profiles
FOR SELECT
TO authenticated
USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin');
```

**Prevention:** Always test RLS policies for each role after creating tables

**How to Test:**
1. Log in as super_admin
2. Open browser console
3. Run: `supabase.from('profiles').select('*')`
4. Should return all profiles, not empty array

---

### Issue 2: Flashcard Batches Merge After Toggling Public/Private

**Symptom:** User toggles flashcard from public → private, batches merge into one

**Cause:** MyFlashcards.jsx was grouping by `created_at` timestamp, which doesn't change when toggling visibility

**Fix:** Group by `batch_id` instead of timestamp

**Code Fix:**
```javascript
// WRONG (old code)
const grouped = flashcards.reduce((acc, card) => {
  const key = card.created_at;
  // ...
}, {});

// CORRECT (new code)
const grouped = flashcards.reduce((acc, card) => {
  const key = card.batch_id;
  // ...
}, {});
```

**Prevention:** Use `batch_id` for ALL flashcard grouping operations

**Database Fix (if needed):**
See Migration 002 for adding batch_id column and backfilling existing data

---

### Issue 3: "reviewed_at column doesn't exist" Runtime Error

**Symptom:** My Progress page crashes with database error

**Cause:** Code referenced `reviewed_at` column, but actual column name is `created_at`

**Fix:** Update all queries to use `created_at` instead of `reviewed_at`

**Where to Check:**
- src/pages/dashboard/progress.jsx
- src/components/flashcards/StudyMode.jsx
- Any query selecting from `reviews` table

**Prevention:** Always verify database column names before coding

**How to Check Actual Column Names:**
```sql
-- Run in Supabase SQL Editor
SELECT column_name FROM information_schema.columns
WHERE table_name = 'reviews';
```

---

### Issue 4: Subject Dropdown Empty for Super Admin

**Symptom:** Super admin can't see subjects in Note Upload dropdown

**Cause:** Code filtered subjects by user's course level, but super_admin has no course_level

**Fix:** Make course level filter conditional:
```javascript
// CORRECT
const query = supabase.from('subjects').select('*');
if (user.role !== 'super_admin' && user.role !== 'admin') {
  query.eq('discipline_id', userCourseLevel);
}
```

**Prevention:** Always consider super_admin/admin special cases in filters

---

### Issue 5: CSV Bulk Upload Fails Silently

**Symptom:** Professor uploads CSV, no error, but flashcards don't appear

**Cause:** CSV column headers don't match expected format

**Fix:** Provide exact CSV template with proper column names:
- subject (not Subject)
- topic (not Topic Name)
- front (not question)
- back (not answer)

**Prevention:** Validate CSV headers before processing

**Template Location:** src/components/professor/ProfessorTools.jsx line 450+

---

### Issue 6: OCR Text Extraction Not Working

**Symptom:** Notes uploaded but extracted_text is null

**Cause:** Tesseract.js not loaded properly on client

**Fix:** Check browser console for errors, ensure Tesseract CDN accessible

**Temporary Workaround:** Skip OCR for tables/diagrams (content_type filter)

**Future Fix:** Server-side OCR in Phase 2 (more reliable)

---

### Issue 7: Duplicate "Untitled query" Entries

**Symptom:** Supabase SQL Editor cluttered with 10+ "Untitled query"

**Cause:** Not naming queries before saving

**Fix:** 
1. Click "Untitled query" 
2. Rename using format: `[CATEGORY] Descriptive Name`
3. Delete old untitled queries

**Prevention:** Always name queries BEFORE first save

**Categories:** REPORT, SCHEMA, DATA, FIX, TEST, FUNCTION

---

## 9. QUERY REFERENCE

### Where Queries are Stored in Supabase

**Location:** Supabase → SQL Editor → Left Panel → Private (88 queries)

**Folder Organization:**

```
PRIVATE (88)
├── FUNCTIONS (2 queries)
│   └── [FUNCTION] Get User Activity Stats
│   └── [FUNCTION] Get User Activity Stats (duplicate?)
│
├── REPORTS (1 query)
│   └── [REPORT] User Activity Stats
│
├── SCHEMA (10 queries)
│   ├── [SCHEMA] All Triggers
│   ├── [SCHEMA] All Indexes
│   ├── [SCHEMA] All SQL Functions
│   ├── [SCHEMA] All RLS Policies
│   ├── [SCHEMA] All Columns for Major Tables
│   ├── [SCHEMA] All Database Tables
│   ├── [SCHEMA] Add Super Admin View All Reviews Policy
│   ├── [SCHEMA] Add Super Admin View All Flashcards Policy
│   ├── [SCHEMA] Add Super Admin View All Notes Policy
│   └── [SCHEMA] Add Super Admin View All Profiles Policy
│
└── TEST (8 queries)
    ├── [TEST] Verify Activity Stats Match Dashboard
    ├── Inspect RLS policies for profiles table
    ├── Student Count Test
    ├── [TEST] User Activity Function
    ├── [TEST] Check Weekly Activity Data
    ├── [TEST] Check Today's Activity Data
    ├── [TEST] Check Function Exists
    └── [TEST] User Activity Function

```

**Cleanup Needed:**
- Delete 10+ "Untitled query" entries
- Delete duplicate "[FUNCTION] Get User Activity Stats"
- Organize remaining queries into folders

---

### Most Useful Queries for Development

#### 1. Check User Role
```sql
-- Quick check of current user's role
SELECT role, full_name, email 
FROM profiles 
WHERE id = auth.uid();
```

#### 2. View All Super Admins
```sql
-- Security audit: Who has super_admin access?
SELECT id, full_name, email, created_at
FROM profiles
WHERE role = 'super_admin'
ORDER BY created_at;
```

#### 3. Count Content by User
```sql
-- See who's creating content
SELECT 
  p.full_name,
  COUNT(DISTINCT n.id) as notes,
  COUNT(DISTINCT f.id) as flashcards
FROM profiles p
LEFT JOIN notes n ON p.id = n.user_id
LEFT JOIN flashcards f ON p.id = f.user_id
GROUP BY p.id, p.full_name
ORDER BY notes DESC, flashcards DESC;
```

#### 4. Recent Admin Actions
```sql
-- Last 7 days of admin activity
SELECT 
  aal.created_at,
  aal.action,
  u1.full_name as admin_name,
  u2.full_name as target_user,
  aal.details
FROM admin_audit_log aal
JOIN profiles u1 ON aal.admin_id = u1.id
LEFT JOIN profiles u2 ON aal.target_user_id = u2.id
WHERE aal.created_at > NOW() - INTERVAL '7 days'
ORDER BY aal.created_at DESC;
```

#### 5. Study Streak Leaders
```sql
-- Top 10 users by consecutive days studied
WITH daily_reviews AS (
  SELECT 
    user_id,
    DATE(created_at) as review_date
  FROM reviews
  GROUP BY user_id, DATE(created_at)
)
SELECT 
  p.full_name,
  COUNT(DISTINCT dr.review_date) as total_days_studied
FROM daily_reviews dr
JOIN profiles p ON dr.user_id = p.id
GROUP BY p.id, p.full_name
ORDER BY total_days_studied DESC
LIMIT 10;
```

---

## 10. SCHEMA ROADMAP

### Planned Tables (not yet built)

#### `institutions` table — **Priority: Before second B2B client**
- **Why needed:** Currently, institution names are stored as free text in `profiles.institution` and `study_groups.batch_institution`. The Create Batch Group form populates the Institution dropdown from distinct `profiles.institution` values — functional for a single client but fragile at scale.
- **Risk without it:** A typo in institution name during onboarding creates a ghost institution that won't match any batch group. A new B2B client must have at least one enrolled student before their institution appears in the dropdown.
- **Proposed schema:**
  ```
  institutions
  ├── id          uuid  PK
  ├── name        text  NOT NULL UNIQUE
  ├── slug        text  NOT NULL UNIQUE  (URL-safe identifier)
  ├── is_active   bool  DEFAULT true
  └── created_at  timestamptz DEFAULT now()
  ```
- **Migration path when built:**
  1. Create table, insert existing institution names
  2. Add `institution_id` FK to `profiles` and `study_groups`
  3. Backfill FKs by name match
  4. Update `fetchBatchFormOptions()` in AdminDashboard to query `institutions` table instead of distinct profiles
  5. Optionally keep `institution` text column for legacy compatibility or drop it

#### `b2b_clients` table — **Priority: Before first paying B2B client**
- **Why needed:** Tracks B2B deals, contract status, admin contacts, and billing. Currently no table separates institutional clients from individual users.
- **Proposed schema:** `id, institution_id (FK), contact_name, contact_email, contract_start, contract_end, status (active/trial/expired), razorpay_subscription_id`
- **Depends on:** `institutions` table

---

## 11. MAINTENANCE CHECKLIST

### Daily
- [ ] No critical errors in Supabase logs
- [ ] Database size < 80% of free tier limit (1 GB)
- [ ] No failed RLS policy errors

### Weekly
- [ ] Review admin_audit_log (last 7 days)
- [ ] Check for suspicious role changes
- [ ] Verify backup ran successfully
- [ ] Clean up "Untitled query" entries

### Monthly
- [ ] Review database performance metrics
- [ ] Optimize slow queries (if any)
- [ ] Archive old audit logs (if >10k rows)
- [ ] Update this documentation with schema changes

### Before Each Deployment
- [ ] Run all [SCHEMA] queries to verify structure
- [ ] Test RLS policies for each role
- [ ] Verify all migrations applied
- [ ] Check for missing indexes on new columns

---

## 11. FUTURE ENHANCEMENTS

### Phase 2 Additions (Month 2-3)
- Triggers for auto-updating timestamps
- Full-text search indexes on notes.extracted_text
- Materialized views for analytics
- Partition reviews table by date (if >100k rows)

### Phase 3 Additions (Month 4-6)
- Read replicas for analytics queries
- Point-in-time recovery setup
- Database monitoring dashboards
- Automated backup verification

---

## 12. USEFUL LINKS

- **Supabase Dashboard:** https://supabase.com/dashboard/project/ai1976's-project
- **SQL Editor:** https://supabase.com/dashboard/project/ai1976's-project/sql
- **Table Editor:** https://supabase.com/dashboard/project/ai1976's-project/editor
- **Supabase Docs:** https://supabase.com/docs
- **PostgreSQL Docs:** https://www.postgresql.org/docs/

---

**Last Updated:** January 2, 2026  
**Document Version:** 1.0  
**Maintainer:** Anand (ai1976)  
**Next Review:** February 1, 2026

---
---

## 13. SCHEMA CHANGE LOG ⭐ NEW

**Purpose:** Quick reference for what changed and when

### February 21, 2026 (Phase 1F - Extended Badge System)
- ✅ Created `user_stats` table (user_id PK, total_notes, total_flashcards, total_reviews, total_upvotes_given, total_upvotes_received, total_friends, updated_at) — O(1) counter lookups replace O(n) COUNT(*) in badge triggers
- ✅ RLS on user_stats: users SELECT own row; all writes via SECURITY DEFINER triggers
- ✅ Initialized user_stats rows for all existing users; backfilled counters from live data
- ✅ Created 5 counter triggers (trg_aaa_counter_notes/flashcards/reviews/upvotes/friendships) — named trg_aaa_* to fire before trg_badge_* alphabetically
- ✅ Updated badge_definitions.category CHECK constraint to include 'special' (was content/study/social only)
- ✅ Inserted 13 new badge definitions (order_num 10–22): prolific_writer, deck_builder, subject_expert, first_steps, committed_learner, monthly_master, early_bird, century_club, review_veteran, social_learner, community_pillar, helpful_peer, pioneer
- ✅ Updated award_badge(): night_owl + early_bird default to is_public=FALSE; uses RETURNING id for idempotency
- ✅ Updated 4 badge trigger functions (fn_badge_check_notes/flashcards/reviews/upvotes) to read user_stats instead of COUNT(*)
- ✅ Created 2 new badge trigger functions: fn_badge_check_friendships (social_learner, community_pillar), fn_badge_check_new_profile (initializes user_stats + awards pioneer)
- ✅ Created 2 new triggers: trg_badge_friendship (friendships AFTER UPDATE), trg_badge_new_profile (profiles AFTER INSERT)
- ✅ Awarded retroactive badges to qualifying existing users via backfill
- ✅ Total tables: 20 → 21 (added user_stats)

### February 6, 2026 (Group Invitation Flow + Notification Backend)
- ✅ Created `notifications` table (id, user_id, type, title, message, is_read, metadata JSONB, created_at)
- ✅ Created 5 notification RPCs (get_unread_count, get_recent, mark_all_read, mark_single_read, delete) + cleanup utility
- ✅ Added `status` column to study_group_members (CHECK: 'invited'/'active', DEFAULT 'active')
- ✅ Added `invited_by` column to study_group_members (FK → profiles.id ON DELETE SET NULL)
- ✅ Updated invite_to_group() → inserts as 'invited' + creates notification with JSONB metadata
- ✅ Created accept_group_invite() and decline_group_invite() RPCs with auto notification cleanup
- ✅ Created get_pending_group_invites() RPC for MyGroups page
- ✅ Updated 5 existing RPCs with `AND status = 'active'` filter (get_user_groups, get_group_detail, get_browsable_notes, get_browsable_decks, leave_group)
- ✅ Total tables: 19 → 20 (added notifications)
- ✅ Total indexes: 60+

### February 6, 2026 (Study Groups + Card Suspension)
- ✅ Added `status` column to reviews table (active/suspended)
- ✅ Added `skip_until` column to reviews table (skip 24hr)
- ✅ Added 3 indexes (status, skip_until, composite partial)
- ✅ Created 6 RPC functions (skip, suspend, suspend_topic, unsuspend, reset, get_suspended)
- ✅ Created 3 Study Groups tables (study_groups, study_group_members, content_group_shares)
- ✅ Created 8 Study Groups RPC functions (create_study_group, invite_to_group, leave_group, share_content_with_groups, get_user_groups, get_group_shared_content, get_group_members)
- ✅ Created 2 unified content RPCs (get_browsable_notes, get_browsable_decks) — server-side visibility logic
- ✅ Fixed infinite recursion in sgm_select_member RLS policy → replaced with sgm_select_own
- ✅ Total tables: 16 → 19 (added 3 study group tables)
- ✅ Total indexes: 56+

### January 9, 2026
- ✅ Added `creator_id` to flashcards table (user attribution)
- ✅ Added `content_creator_id` to flashcards table (revenue attribution)
- ✅ Created `friendships` table (social features)
- ✅ Created `content_creators` table (Vivitsu partnership)
- ✅ Added 4 indexes (3 for friendships, 1 for creator_id)
- ✅ Total tables: 14 → 16
- ✅ Total indexes: 50+ → 53+

**Ready For:**
- ✅ February friend request feature
- ✅ March Vivitsu partnership (revenue tracking)
- ✅ Future B2B expansion (organization support)
- ✅ Future student creator monetization

### December 26, 2025
- Added batch_id and batch_description to flashcards
- Created indexes for batch_id

### December 15, 2025
- Initial schema created (12 core tables)

---

## 📝 DOCUMENT HISTORY

## 📝 DOCUMENT HISTORY

- **v1.1** (Jan 9, 2026) - Added friendships + content_creators tables, updated flashcards with creator attribution
- **v1.0** (Jan 2, 2026) - Initial documentation created after 2-hour RLS debugging session

---

## friendships

**Purpose:** Store friend relationships between users with pending/accepted/rejected status

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique friendship ID |
| user_id | UUID | NOT NULL, REFERENCES profiles(id) ON DELETE CASCADE | User who sent friend request |
| friend_id | UUID | NOT NULL, REFERENCES profiles(id) ON DELETE CASCADE | User who received friend request |
| status | TEXT | NOT NULL, CHECK (status IN ('pending', 'accepted', 'rejected')) | Request status |
| created_at | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | When request was sent |
| updated_at | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | When status last changed |

**Indexes:**
- `idx_friendships_user_id` on user_id
- `idx_friendships_friend_id` on friend_id
- `idx_friendships_status` on status

**Constraints:**
- UNIQUE(user_id, friend_id) - Prevents duplicate friend requests

**Relationships:**
- `user_id` → profiles.id (CASCADE DELETE)
- `friend_id` → profiles.id (CASCADE DELETE)

**Usage:**
```sql
-- Send friend request
INSERT INTO friendships (user_id, friend_id, status)
VALUES ('user-uuid', 'friend-uuid', 'pending');

-- Accept friend request
UPDATE friendships 
SET status = 'accepted', updated_at = NOW()
WHERE id = 'friendship-uuid';

-- Get all friends for a user
SELECT * FROM friendships
WHERE (user_id = 'user-uuid' OR friend_id = 'user-uuid')
AND status = 'accepted';
```
---

## SQL Functions

## SQL Functions


### get_anonymous_class_stats(p_course_level TEXT)
**Purpose:** Returns anonymous aggregate statistics for dashboard comparison
**Security:** DEFINER (bypasses RLS to aggregate across users)
**Added:** 2026-01-24 (Phase 1C Dashboard Redesign)
**Updated:** 2026-01-30
**Changes:**
- `students_studied_today` now uses each user's stored timezone
- More accurate for classes with students in different timezones

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| p_course_level | TEXT | Filter by course (e.g., 'CA Intermediate') |

**Returns:**
| Column | Type | Description |
|--------|------|-------------|
| avg_reviews_this_week | NUMERIC | Class average reviews (rolling 7 days) |
| total_active_students | INTEGER | Count of students who reviewed this week |
| students_with_7day_streak | INTEGER | Count with perfect 7-day streak |
| students_studied_today | INTEGER | Count who studied today |
| min_users_met | BOOLEAN | TRUE if >= 5 active users (privacy threshold) |

**Usage:**
```sql
SELECT * FROM get_anonymous_class_stats('CA Intermediate');

Privacy Notes:

Returns aggregates only, never individual user data
Frontend hides comparison when min_users_met = FALSE
Note: Day boundaries are calculated server-side using UTC. For accurate user-facing stats, frontend should use toLocaleDateString('en-CA') for local timezone handling.

### get_author_profile(p_author_id UUID, p_viewer_id UUID)
**Purpose:** Returns author profile, public badges, and friendship status in one call
**Security:** DEFINER (bypasses RLS to read profiles, badges, friendships)
**Added:** 2026-02-06 (Author Profile Page)

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| p_author_id | UUID | The user whose profile to view |
| p_viewer_id | UUID | The logged-in user viewing the profile |

**Returns:** JSON object with:
| Key | Type | Description |
|-----|------|-------------|
| profile | JSON | full_name, email, role, course_level, institution, created_at |
| badges | JSON[] | Array of badges (all for own profile, public-only for others) |
| friendship | JSON or null | Friendship record between viewer and author (null if own profile or no friendship) |
| is_own | BOOLEAN | Whether viewer is viewing their own profile |

**Usage:**
```sql
SELECT get_author_profile('author-uuid', 'viewer-uuid');
```

---

### get_author_content_summary(p_author_id UUID, p_viewer_id UUID)
**Purpose:** Returns content grouped by course/subject with server-side visibility enforcement
**Security:** DEFINER (bypasses RLS to read notes, flashcard_decks, friendships, profiles)
**Added:** 2026-02-06 (Author Profile Page)

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| p_author_id | UUID | The user whose content to summarize |
| p_viewer_id | UUID | The logged-in user viewing the profile |

**Returns:** JSON object with:
| Key | Type | Description |
|-----|------|-------------|
| accessible | JSON[] | Courses matching viewer's course_level (or all for own profile) |
| other_courses | JSON[] | Courses not matching viewer's course_level (upsell section) |

Each course entry: `{ name, subjects: [{ name, notes, flashcards }], totalNotes, totalFlashcards }`

**Visibility Logic:**
- Own profile: ALL content (private + friends + public)
- Friend: public + friends visibility
- Stranger: public only

**Usage:**
```sql
SELECT get_author_content_summary('author-uuid', 'viewer-uuid');
```

---

### skip_card(p_user_id UUID, p_flashcard_id UUID)
**Purpose:** Skips a card for 24 hours by setting skip_until to tomorrow (user's local timezone)
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** VOID

### suspend_card(p_user_id UUID, p_flashcard_id UUID)
**Purpose:** Suspends a card indefinitely by setting status='suspended'
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** VOID

### suspend_topic_cards(p_user_id UUID, p_topic_id UUID)
**Purpose:** Bulk suspends all cards in a topic. Creates review records for cards without one.
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** INTEGER (count of suspended cards)

### unsuspend_card(p_user_id UUID, p_flashcard_id UUID)
**Purpose:** Reactivates a suspended card, scheduling it for review today
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** VOID

### reset_card(p_user_id UUID, p_flashcard_id UUID)
**Purpose:** Deletes review record, making card "New" again. Destructive action.
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** VOID

### get_suspended_cards(p_user_id UUID)
**Purpose:** Returns all suspended cards for a user with flashcard details for Progress page
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** TABLE (review_id, flashcard_id, front_text, back_text, subject_name, topic_name, suspended_at)

### get_user_streak(p_user_id UUID)
**Purpose:** Calculate consecutive study days in user's local timezone
**Security:** DEFINER
**Updated:** 2026-01-30 (Now uses stored user timezone)

**Returns:** INTEGER (number of consecutive days)

**Logic:**
1. Gets user's timezone from profiles
2. Calculates today/yesterday in user's local timezone
3. Gets all review dates converted to user's local timezone
4. Counts consecutive days starting from today or yesterday

---

## flashcard_decks (Added 2026-01-24)

Groups flashcards into logical decks by user/subject/topic. Enables upvoting at deck level.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| user_id | UUID | FK → profiles.id, NOT NULL | Deck owner |
| subject_id | UUID | FK → subjects.id, nullable | |
| custom_subject | TEXT | nullable | For custom subjects |
| topic_id | UUID | FK → topics.id, nullable | |
| custom_topic | TEXT | nullable | For custom topics |
| target_course | TEXT | | Course context |
| visibility | TEXT | CHECK (private/friends/public) | |
| name | TEXT | nullable | Optional custom deck name |
| description | TEXT | nullable | |
| card_count | INTEGER | DEFAULT 0 | Auto-updated by trigger |
| upvote_count | INTEGER | DEFAULT 0 | Auto-updated by trigger |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | |

**Unique Constraint:** `(user_id, subject_id, topic_id, custom_subject, custom_topic)` NULLS NOT DISTINCT

⚠️ **CRITICAL — How to join flashcards → flashcard_decks (READ THIS BEFORE WRITING ANY RPC)**
- The `deck_id` column on the `flashcards` table EXISTS as a FK to `flashcard_decks.id` but is **NEVER POPULATED**. Do NOT use `WHERE fc.deck_id = p_deck_id` — it will always return 0 rows.
- The `batch_id` column on `flashcards` is for grouping cards from the same upload session — it is **NOT** the deck ID and does **NOT** link to `flashcard_decks.id`.
- **The only correct way to fetch flashcards for a deck** is to join on the 5 grouping columns, exactly as the trigger does:
```sql
SELECT fc.*
FROM flashcards fc
JOIN flashcard_decks fd ON
    fc.user_id = fd.user_id
  AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
  AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
  AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
  AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
WHERE fd.id = p_deck_id
```
This pattern is used in `get_public_deck_preview` and must be used in any future RPC that reads flashcards by deck.

**Indexes:**
- `idx_flashcard_decks_user` (user_id)
- `idx_flashcard_decks_subject` (subject_id)
- `idx_flashcard_decks_topic` (topic_id)
- `idx_flashcard_decks_visibility` (visibility)

**Trigger: `trigger_update_deck_card_count`** — fires AFTER INSERT, UPDATE, DELETE on `flashcards`
Function: `update_deck_card_count()` (SECURITY DEFINER)
- **INSERT:** Tries `UPDATE card_count + 1` on matching deck row. If `NOT FOUND` (no deck exists yet), inserts a new deck row with `card_count = 1`, copying `target_course` and `visibility` from the new flashcard. This means deck rows are **auto-created on first flashcard insert** — no application code or manual SQL needed for new courses or subjects.
- **DELETE:** Decrements `card_count` (floor 0) on matching deck row.
- **UPDATE:** No-op (card count unchanged).

⚠️ **CRITICAL — do not add a second trigger on `flashcards`** — would cause double-counting. Always check existing triggers first: `SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'flashcards';`

---

## upvotes (Modified 2026-01-24 - Polymorphic)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK → profiles.id, NOT NULL | Who upvoted |
| content_type | TEXT | CHECK ('note', 'flashcard_deck') | Type of content |
| target_id | UUID | NOT NULL | notes.id or flashcard_decks.id |
| note_id | UUID | nullable, DEPRECATED | Legacy column |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | |

**Unique Constraint:** `(user_id, content_type, target_id)`

**Indexes:**
- `idx_upvotes_content_type` (content_type)
- `idx_upvotes_target` (target_id)
- `idx_upvotes_content_target` (content_type, target_id)
- `idx_upvotes_user` (user_id)

---

## Achievement Badges Tables (Phase 1E + 1F)

### user_stats ⭐ NEW (Phase 1F)
Per-user integer counters for O(1) badge eligibility checks. Eliminates COUNT(*) aggregations from badge triggers, preventing bulk upload crashes.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| user_id | UUID | NO | - | PK + FK → profiles.id ON DELETE CASCADE |
| total_notes | INTEGER | NO | 0 | Total notes uploaded |
| total_flashcards | INTEGER | NO | 0 | Total flashcards created |
| total_reviews | INTEGER | NO | 0 | Total reviews completed |
| total_upvotes_given | INTEGER | NO | 0 | Total upvotes the user has given |
| total_upvotes_received | INTEGER | NO | 0 | Total upvotes received on user's content |
| total_friends | INTEGER | NO | 0 | Accepted friendships count |
| updated_at | TIMESTAMPTZ | NO | NOW() | Last counter update |

**RLS Policies:** Users can SELECT own row only. All writes via SECURITY DEFINER trigger functions (bypass RLS).
**Maintained by:** Counter triggers `trg_aaa_counter_*` (fire before badge triggers alphabetically).
**Initialized:** Row created on profiles INSERT via `trg_badge_new_profile`. Backfilled for existing users.

---

### badge_definitions
Static reference table for all achievement badges.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | uuid_generate_v4() | Primary key |
| key | TEXT | NO | - | Unique identifier (e.g., 'digitalizer') |
| name | TEXT | NO | - | Display name |
| description | TEXT | NO | - | Badge description |
| icon_key | TEXT | NO | - | Maps to Lucide icon |
| category | TEXT | NO | - | 'content', 'study', 'social', 'special' ⭐ |
| threshold | INTEGER | NO | 1 | Target number to earn |
| is_active | BOOLEAN | YES | true | Whether badge is active |
| order_num | INTEGER | YES | 0 | Display order |
| created_at | TIMESTAMP | YES | now() | Created timestamp |

**⭐ Phase 1F:** category CHECK constraint updated to include 'special' (was only content/study/social).

### user_badges
Tracks which badges each user has earned.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | uuid_generate_v4() | Primary key |
| user_id | UUID | NO | - | FK → profiles.id |
| badge_id | UUID | NO | - | FK → badge_definitions.id |
| earned_at | TIMESTAMP | YES | now() | When badge was earned |
| notified | BOOLEAN | YES | false | Has user seen toast? |
| is_public | BOOLEAN | YES | true | Visible to others? |

**Constraints:** UNIQUE(user_id, badge_id)

### user_activity_log
Logs daily activity for streak and time-based badge calculations.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | uuid_generate_v4() | Primary key |
| user_id | UUID | NO | - | FK → profiles.id |
| activity_type | TEXT | NO | - | 'review', 'flashcard_create', 'note_upload' |
| activity_date | DATE | NO | - | Local date (IST) |
| activity_hour | INTEGER | YES | - | Hour 0-23 (UTC, used for Night Owl approximation)
| created_at | TIMESTAMP | YES | now() | Created timestamp |
| activity_hour | INTEGER | YES | - | Hour 0-23 in user's LOCAL timezone (from profiles.timezone) |


**Constraints:** UNIQUE(user_id, activity_type, activity_date)

---

## Badge-Related Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| award_badge | p_user_id, p_badge_key | BOOLEAN | Awards badge idempotently. night_owl + early_bird default private. ⭐ Updated Phase 1F |
| log_review_activity | p_user_id, p_review_timestamp | VOID | Logs activity with user's stored timezone |
| get_user_streak | p_user_id | INTEGER | Consecutive study days in user's local timezone |
| is_night_owl_hour | p_hour | BOOLEAN | True if hour is 23 or 0-4 |
| get_user_badges | p_user_id | TABLE | All badges with is_public flag |
| get_public_user_badges | p_user_id | TABLE | Only public badges |
| get_unnotified_badges | p_user_id | TABLE | Unnotified badges, marks as notified |
| fn_update_notes_counter | — | TRIGGER | Increments/decrements user_stats.total_notes ⭐ Phase 1F |
| fn_update_flashcards_counter | — | TRIGGER | Increments/decrements user_stats.total_flashcards ⭐ Phase 1F |
| fn_update_reviews_counter | — | TRIGGER | Increments/decrements user_stats.total_reviews ⭐ Phase 1F |
| fn_update_upvotes_counter | — | TRIGGER | Increments upvotes_given (upvoter) + upvotes_received (owner) ⭐ Phase 1F |
| fn_update_friendships_counter | — | TRIGGER | Increments/decrements total_friends for both users ⭐ Phase 1F |
| fn_badge_check_notes | — | TRIGGER | Reads user_stats; awards digitalizer + prolific_writer ⭐ Phase 1F |
| fn_badge_check_flashcards | — | TRIGGER | Reads user_stats; awards memory_architect + deck_builder + subject_expert ⭐ Phase 1F |
| fn_badge_check_reviews | — | TRIGGER | Reads user_stats; awards all review + streak + time-based badges ⭐ Phase 1F |
| fn_badge_check_upvotes | — | TRIGGER | Reads user_stats; awards helpful_peer + rising_star ⭐ Phase 1F |
| fn_badge_check_friendships | — | TRIGGER | Reads user_stats; awards social_learner + community_pillar ⭐ Phase 1F |
| fn_badge_check_new_profile | — | TRIGGER | Initializes user_stats row; awards pioneer if pre-March 2026 ⭐ Phase 1F |

### award_badge(p_user_id UUID, p_badge_key TEXT)
**Updated:** 2026-02-21 (Phase 1F)
**Key changes:**
- night_owl and early_bird badges awarded with `is_public = FALSE` by default
- Uses `INSERT ... ON CONFLICT DO NOTHING RETURNING id` — race-condition safe, returns TRUE only on new award

---

## Badge-Related Triggers

### Counter Triggers (fire FIRST — named trg_aaa_* for alphabetical priority)

| Trigger | Table | Event | Function |
|---------|-------|-------|----------|
| trg_aaa_counter_notes | notes | AFTER INSERT OR DELETE | fn_update_notes_counter |
| trg_aaa_counter_flashcards | flashcards | AFTER INSERT OR DELETE | fn_update_flashcards_counter |
| trg_aaa_counter_reviews | reviews | AFTER INSERT OR DELETE | fn_update_reviews_counter |
| trg_aaa_counter_upvotes | upvotes | AFTER INSERT OR DELETE | fn_update_upvotes_counter |
| trg_aaa_counter_friendships | friendships | AFTER UPDATE OR DELETE | fn_update_friendships_counter |

### Badge Award Triggers (fire SECOND — named trg_badge_*)

| Trigger | Table | Event | Function | Badges Checked |
|---------|-------|-------|----------|----------------|
| trg_badge_note_upload | notes | AFTER INSERT | fn_badge_check_notes | digitalizer, prolific_writer |
| trg_badge_flashcard_create | flashcards | AFTER INSERT | fn_badge_check_flashcards | memory_architect, deck_builder, subject_expert |
| trg_badge_review | reviews | AFTER INSERT | fn_badge_check_reviews | first_steps, streak_master, committed_learner, monthly_master, night_owl, early_bird, century_club, review_veteran |
| trg_badge_upvote | upvotes | AFTER INSERT | fn_badge_check_upvotes | helpful_peer, rising_star |
| trg_badge_friendship | friendships | AFTER UPDATE | fn_badge_check_friendships | social_learner, community_pillar ⭐ NEW |
| trg_badge_new_profile | profiles | AFTER INSERT | fn_badge_check_new_profile | pioneer ⭐ NEW |

**Trigger ordering:** PostgreSQL fires triggers alphabetically by name within the same table/event. `trg_aaa_*` always fires before `trg_badge_*`, ensuring counters are updated before badge checks read them.

---

## Badge Catalogue (Phase 1E + 1F)

| Key | Name | Category | Threshold | Icon | Default Privacy |
|-----|------|----------|-----------|------|----------------|
| digitalizer | Digitalizer | content | 1 note | upload | public |
| memory_architect | Memory Architect | content | 10 flashcards | brain | public |
| prolific_writer | Prolific Writer | content | 5 notes | file-text | public |
| deck_builder | Deck Builder | content | 50 flashcards | layers | public |
| subject_expert | Subject Expert | content | 20 cards/subject | graduation-cap | public |
| streak_master | Streak Master | study | 3-day streak | flame | public |
| first_steps | First Steps | study | 1 review | footprints | public |
| committed_learner | Committed Learner | study | 7-day streak | calendar-check | public |
| monthly_master | Monthly Master | study | 30-day streak | calendar-range | public |
| night_owl | Night Owl | study | review 11PM-4AM | moon | **private** |
| early_bird | Early Bird | study | review 5-7AM | sunrise | **private** |
| century_club | Century Club | study | 100 reviews | award | public |
| review_veteran | Review Veteran | study | 500 reviews | medal | public |
| rising_star | Rising Star | social | 5 upvotes received | star | public |
| helpful_peer | Helpful Peer | social | 10 upvotes given | thumbs-up | public |
| social_learner | Social Learner | social | 3 friends | users | public |
| community_pillar | Community Pillar | social | 10 friends | heart-handshake | public |
| pioneer | Pioneer | special | pre-March 2026 | flag | public |

---

## push_subscriptions (Sprint 3.x — Push Phase)

Stores Web Push API subscriptions per device. One user can have multiple rows (one per browser/device). Soft-deleted on 410/404 response from push server.

| Column | Type | Constraints |
|---|---|---|
| `id` | uuid | PK, default gen_random_uuid() |
| `user_id` | uuid | NOT NULL, FK → auth.users ON DELETE CASCADE |
| `endpoint` | text | NOT NULL |
| `p256dh` | text | NOT NULL |
| `auth` | text | NOT NULL |
| `browser` | text | nullable — Chrome, Firefox, Edge, Safari |
| `platform` | text | nullable — Android, iOS, Windows, macOS |
| `is_active` | boolean | DEFAULT true — set false on 410/404, never hard-deleted |
| `created_at` | timestamptz | DEFAULT now() |
| `last_used_at` | timestamptz | updated on each successful send |

**RLS:** Enabled. `USING (auth.uid() = user_id)` — users manage own rows only.

**Unique constraint:** `(user_id, endpoint)` — one row per browser per user.

**Usage:** Queried by `_shared/sendPush.ts` (filters `is_active = true`). Written by `push-subscribe` Edge Function. Stale rows deactivated (not deleted) by `sendPushToUsers` helper and `cron-daily-study-summary`.

---

## push_notification_preferences (Sprint 3.x — Push Phase)

Per-user opt-in/out flags for each notification type. Defaults to all `true` if no row exists.

| Column | Type | Constraints |
|---|---|---|
| `user_id` | uuid | PK, FK → auth.users ON DELETE CASCADE |
| `review_reminders` | boolean | DEFAULT true |
| `professor_content` | boolean | DEFAULT true |
| `friend_content` | boolean | DEFAULT true |
| `group_content` | boolean | DEFAULT true |
| `friend_requests` | boolean | DEFAULT true |
| `friend_accepted` | boolean | DEFAULT true |
| `updated_at` | timestamptz | DEFAULT now() |

**Note:** `daily_summary` preference column is not yet added — Sprint 3.6 notifies all active students without an opt-out (future scope).

---

## Edge Functions (Supabase Deno runtime)

All functions live in `supabase/functions/`. Shared helpers in `_shared/` are not deployed as standalone functions.

| Function | Trigger | Purpose |
|---|---|---|
| `push-subscribe` | User action (POST) | Upsert push subscription into `push_subscriptions` |
| `push-unsubscribe` | User action (POST) | Mark subscription `is_active = false` |
| `notify-friend-event` | DB trigger / server | Instant push for friend_request / accepted events |
| `notify-content-created` | DB trigger / server | Push when professor posts new notes or flashcards |
| `cron-review-reminders` | pg_cron — 02:30 UTC daily | Push to students with cards due today (08:00 IST) |
| `cron-daily-study-summary` | pg_cron — `*/15 * * * *` | Nightly 22:00 local-time study summary push (Sprint 3.6) |

### cron-daily-study-summary (Sprint 3.6)

Runs every 15 minutes. Notifies students whose local time is **22:00–22:14** with a personalised study summary for the day.

**15-minute cadence rationale:** IST is UTC+5:30 (fractional offset). An hourly cron at :00 UTC fires at 10:30 PM IST, not 10:00 PM IST. Running every 15 min and filtering `MINUTE < 15` delivers at exactly 22:00 local time for all fractional timezones without duplicates.

**Eligibility filters:**
- `profiles.role = 'student'` only
- Local time: hour = 22 AND minute < 15 (computed via `Intl.DateTimeFormat`, timezone from `profiles.timezone`)
- Active in last 7 days: at least one row in `study_sessions` OR `reviews` with `created_at >= NOW() - 7 days`

**Message variants:**
- `today_seconds >= 60`: "Great work today 🎯" — logged study time formatted as `Xh Ym` / `Ym`
- `today_seconds < 60`: "Time to open the books 📚" — encourages first session

**Stale subscription handling:** 410/404 responses set `is_active = false` on the subscription row; execution continues for remaining users.

**pg_cron job name:** `cron-daily-study-summary`

---

**END OF DATABASE_SCHEMA.md**

*This document saved you 2+ hours of debugging. Keep it updated!* 🎯
