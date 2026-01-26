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
10. [Maintenance Checklist](#maintenance-checklist)

---

## 1. OVERVIEW

### Quick Stats
- **Total Tables:** 16 ⭐ (was 14, added 2 new tables)
- **Custom Functions:** 1
- **RLS Policies:** 24
- **Indexes:** 53+ ⭐ (was 50+, added 3 indexes)
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

### Supporting Tables
- **comments** - Comments on shared notes
- **upvotes** - Upvote tracking for notes
- **role_permissions** - Permission matrix for roles

---

## 2. DATABASE TABLES

### 2.1 profiles

**Purpose:** User accounts with 4-tier role system (student/professor/admin/super_admin)  
**Created:** December 2025 (Phase 0.5)  
**Columns:** 8

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key, links to auth.users |
| full_name | text | YES | NULL | User's display name |
| email | text | NO | - | Unique, from Supabase auth |
| role | text | NO | 'student' | student/professor/admin/super_admin |
| course_level | text | YES | NULL | User's primary enrollment (CA Foundation/Inter/Final) |
| institution | text | YES | NULL | In-house vs External |
| status | text | NO | 'active' | active/suspended |
| created_at | timestamp | NO | NOW() | Account creation timestamp |

**Why This Structure:**
- `role` column enables 4-tier permission system (critical for security)
- `course_level` is user's enrollment, separate from content `target_course` (two-tier model)
- Foreign key to `auth.users` for Supabase authentication integration
- `status` allows suspending users without deletion

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
**Last Updated:** January 11, 2026 (Added visibility system)  
**Columns:** 24 (was 23, replaced is_public with visibility)

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
| visibility | text | NO | 'private' | Three-tier visibility system ⭐ NEW |
| created_at | timestamp | NO | NOW() | Creation timestamp |

**Visibility System (NEW - January 11, 2026):**
- `visibility` column replaces old `is_public` boolean
- Three levels:
  - **'private'**: Only creator can see (default)
  - **'friends'**: Creator + accepted friends can see
  - **'public'**: Everyone can see
- Constraint: `CHECK (visibility IN ('private', 'friends', 'public'))`
- Index: `idx_flashcards_visibility` for fast filtering

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
| created_at | timestamp | NO | NOW() | When review happened |

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

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| name | text | NO | - | e.g., "CA Intermediate" |
| description | text | YES | NULL | Optional description |
| icon | text | YES | NULL | Icon name for UI |
| sort_order | integer | NO | 0 | Display order |
| is_active | boolean | NO | true | Enable/disable courses |
| created_at | timestamp | NO | NOW() | Creation timestamp |
| updated_at | timestamp | NO | NOW() | Last modified |

**Pre-Loaded Data:**
- CA Foundation
- CA Intermediate (8 subjects, 147 topics)
- CA Final

**Related Tables:** subjects, notes, flashcards  
**Key Indexes:** name, is_active, sort_order  
**RLS Policies:** 1 policy (public read)

---

### 2.6 subjects

**Purpose:** Course subjects (e.g., Taxation, Accounting)  
**Created:** December 2025 (Phase 0.5)  
**Columns:** 8

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| discipline_id | uuid | NO | - | Foreign key to disciplines |
| name | text | NO | - | e.g., "Advanced Accounting" |
| description | text | YES | NULL | Optional description |
| icon | text | YES | NULL | Icon name for UI |
| sort_order | integer | NO | 0 | Display order |
| is_active | boolean | NO | true | Enable/disable subjects |
| created_at | timestamp | NO | NOW() | Creation timestamp |

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
**Key Indexes:** discipline_id, name, is_active, sort_order  
**RLS Policies:** 1 policy (public read)

---

### 2.7 topics

**Purpose:** Granular topics within subjects  
**Created:** December 2025 (Phase 0.5)  
**Columns:** 7

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| subject_id | uuid | NO | - | Foreign key to subjects |
| name | text | NO | - | e.g., "AS 1 Disclosure of Accounting Policies" |
| description | text | YES | NULL | Optional description |
| sort_order | integer | NO | 0 | Display order |
| is_active | boolean | NO | true | Enable/disable topics |
| created_at | timestamp | NO | NOW() | Creation timestamp |

**Pre-Loaded Data:**
- 147 topics across 8 CA Intermediate subjects
- Sourced from official CA syllabus spreadsheet

**Related Tables:** subjects, notes, flashcards  
**Key Indexes:** subject_id, name, is_active, sort_order  
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

## 3. RLS POLICIES

**Total Policies:** 24  
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

**Total Triggers:** 0 (currently)

**Why No Triggers Yet:**
- Phase 1 MVP prioritizes simplicity
- Application logic handles most updates
- Will add triggers in Phase 2 for:
  - Auto-updating `updated_at` timestamps
  - Auto-incrementing view/upvote counts
  - Cascade operations on delete

**Planned Triggers (Phase 2):**
1. `update_updated_at_timestamp` - Auto-update updated_at on UPDATE
2. `increment_view_count` - Auto-increment notes.view_count
3. `update_upvote_count` - Sync upvotes table with notes.upvote_count

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

## 10. MAINTENANCE CHECKLIST

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

### get_anonymous_class_stats(p_course_level TEXT)
**Purpose:** Returns anonymous aggregate statistics for dashboard comparison
**Security:** DEFINER (bypasses RLS to aggregate across users)
**Added:** 2026-01-24 (Phase 1C Dashboard Redesign)

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
```

**Privacy Notes:**
- Returns aggregates only, never individual user data
- Frontend hides comparison when min_users_met = FALSE
- Uses Asia/Kolkata timezone for day boundaries

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

**Indexes:**
- `idx_flashcard_decks_user` (user_id)
- `idx_flashcard_decks_subject` (subject_id)
- `idx_flashcard_decks_topic` (topic_id)
- `idx_flashcard_decks_visibility` (visibility)

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

## Achievement Badges Tables (Phase 1E)

### badge_definitions
Static reference table for all achievement badges.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | uuid_generate_v4() | Primary key |
| key | TEXT | NO | - | Unique identifier (e.g., 'digitalizer') |
| name | TEXT | NO | - | Display name |
| description | TEXT | NO | - | Badge description |
| icon_key | TEXT | NO | - | Maps to Lucide icon |
| category | TEXT | NO | - | 'content', 'study', 'social' |
| threshold | INTEGER | NO | 1 | Target number to earn |
| is_active | BOOLEAN | YES | true | Whether badge is active |
| order_num | INTEGER | YES | 0 | Display order |
| created_at | TIMESTAMP | YES | now() | Created timestamp |

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
| activity_hour | INTEGER | YES | - | Hour 0-23 (IST) for Night Owl |
| created_at | TIMESTAMP | YES | now() | Created timestamp |

**Constraints:** UNIQUE(user_id, activity_type, activity_date)

---

## Badge-Related Functions

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| award_badge | p_user_id, p_badge_key | BOOLEAN | Awards badge, returns true if new |
| log_review_activity | p_user_id, p_review_timestamp | VOID | Logs activity with IST conversion |
| get_user_streak | p_user_id | INTEGER | Consecutive study days |
| is_night_owl_hour | p_hour | BOOLEAN | True if 23 or 0-4 |
| get_user_badges | p_user_id | TABLE | All badges with is_public |
| get_public_user_badges | p_user_id | TABLE | Only public badges |
| get_unnotified_badges | p_user_id | TABLE | Unnotified badges, marks notified |

---

## Badge-Related Triggers

| Trigger | Table | Event | Function |
|---------|-------|-------|----------|
| trg_badge_note_upload | notes | AFTER INSERT | Checks digitalizer |
| trg_badge_flashcard_create | flashcards | AFTER INSERT | Checks memory_architect |
| trg_badge_review | reviews | AFTER INSERT | Logs activity, checks streak_master & night_owl |
| trg_badge_upvote | upvotes | AFTER INSERT | Checks rising_star |

**END OF DATABASE_SCHEMA.md**

*This document saved you 2+ hours of debugging. Keep it updated!* 🎯
