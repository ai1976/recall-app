# DATABASE SCHEMA DOCUMENTATION - RECALL

**Last Updated:** June 2026 (Sprint 4.1)
**Database:** PostgreSQL (Supabase)  
**Project:** Recall - The Revision Operating System (course-agnostic spaced repetition platform)
**Version:** Production (Phase 1 complete + ongoing sprints)

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
- **Triggers:** 10+ active (trg_create_profile_on_signup / handle_new_user, trigger_update_deck_card_count, trg_aaa_counter_flashcards, trg_badge_flashcard_create, trg_badge_note_upload, trg_badge_review, trg_badge_upvote, trg_badge_friendship, trg_auto_resolve_note_flags, trg_auto_resolve_flashcard_flags)
- **Database Size:** ~50 MB (estimated for 20 users)

### Core Tables
- **profiles** - User accounts with 4-tier role system
- **notes** - Student notes with optional OCR text extraction
- **flashcards** - Spaced repetition cards with batch tracking and full creator attribution
- **reviews** - Per-student SRS progress (single source of truth for all spaced repetition state)
- **flashcard_decks** - Auto-maintained deck groups (trigger-created, joined via 5 grouping columns NOT deck_id)
- **disciplines, subjects, topics** - Course taxonomy (course-agnostic; CA/CMA/CS pre-loaded for beta)
- **admin_audit_log** - Audit trail for admin actions

### Social Tables
- **friendships** - Bidirectional friend connections (pending/accepted/rejected)
- **follows** - One-way follow graph (separate from friendships)
- **upvotes** - Polymorphic upvotes for notes and flashcard_decks
- **study_groups** - Group metadata (name, type: batch/system_course/custom, invite_token)
- **study_group_members** - Membership with invitation status (invited/active/requested — 'requested' added Sprint 8.0)
- **content_group_shares** - Links notes/decks to groups (cascade-deletes on group delete, NOT original content)
- **notifications** - All notification types with JSONB metadata and Realtime enabled

### Achievement & Activity
- **badge_definitions** - Badge catalogue (key, icon_key, category, threshold)
- **user_badges** - Awarded badges per user with per-badge privacy toggle
- **user_activity_log** - Daily activity log used for streak and badge calculations
- **user_stats** - Counter table (O(1) badge threshold checks; maintained by trg_aaa_counter_* triggers)

### Study Tracking
- **study_sessions** - Completed manual + auto-captured study time sessions (only completed rows stored)

### Push Notifications
- **push_subscriptions** - Device subscriptions with soft-delete on expiry
- **push_notification_preferences** - Per-user boolean preferences (all default true)

### Access Control
- **access_requests** - WhatsApp lead capture + B2B institute access requests + educator applications. `request_type` (`student_access` default / `institute_inquiry` / `educator_application`, ✅ deployed 2026-07-01, Phase 5 Sprint 5) distinguishes the three flows; `message` (nullable) carries institute city + optional note, or (educator_application) the credential/LinkedIn + why. `status` CHECK ✅ Phase 5 Sprint 6 (deployed 2026-07-02) extends `('pending','contacted','enrolled')` to add `'approved'`/`'rejected'` for educator applications — `'dismissed'` (offered in `AdminDashboard.jsx`'s status dropdown) was historically missing from the CHECK (selecting it threw 23514); closed by `22_SCHEMA` (✅ deployed 2026-07-02), CHECK now also allows `'dismissed'`. See `submit_access_request()` / `submit_institute_inquiry()` / `submit_educator_application()` / `approve_educator_application()` / `reject_educator_application()` in §4.
- **content_flags** - Content reporting (auto-escalates to 'high' at 3+ flags)

### Revenue Tracking
- **content_creators** - Revenue sharing attribution (Vivitsu partnership)

### Multi-Course Teaching
- **profile_courses** - Junction table: professors/admins/super_admins → multiple disciplines
  - `profiles.course_level` kept as "primary course" for backward compat
  - `is_primary = TRUE` always synced with `profiles.course_level` via `setPrimaryCourse()`

---

## 2. DATABASE TABLES

### 2.1 profiles

**Purpose:** User accounts with 4-tier role system (student/professor/admin/super_admin)
**Created:** December 2025 (Phase 0.5)
**Last Updated:** 16/09/2026 (Sprint 8.4 — added exam_date/exam_month/has_dismissed_exam_prompt, corrected column count against live schema)
**Columns:** 19 (was documented as 13 — `access_request_ref`/`updated_at` were live but undocumented; both confirmed and added below, alongside the 3 new Sprint 8.4 columns)

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
| has_dismissed_goal_prompt | boolean | NO | false | One-time dismissal of the dashboard "no goal set" prompt line. Sprint 7.3-B. Same self-service update pattern as has_seen_onboarding. |
| access_request_ref | uuid | YES | NULL | Previously undocumented — confirmed live via Sprint 8.4 pre-flight diagnostic (16/09/2026). Links a signup to the `access_requests` row that referred them. |
| updated_at | timestamptz | YES | now() | Previously undocumented — confirmed live via Sprint 8.4 pre-flight diagnostic (16/09/2026). |
| exam_date | date | YES | NULL | ⭐ NEW (Sprint 8.4, 16/09/2026). Exact exam date, once known. No default, no backfill — every pre-existing student sees the CTA/popup exactly like a new student who skipped it. Editable indefinitely from Profile Settings. Takes precedence over `exam_month` for display (countdown) once set. |
| exam_month | date | YES | NULL | ⭐ NEW (Sprint 8.4, 16/09/2026). 1st-of-month placeholder used only before an exact date is announced (e.g. "sometime in November 2026"). `CHECK (exam_month IS NULL OR EXTRACT(DAY FROM exam_month) = 1)`. Displayed as text only ("Exam: November 2026") — never a fabricated days-count, since a month-level guess doesn't earn one. |
| has_dismissed_exam_prompt | boolean | NO | false | ⭐ NEW (Sprint 8.4, 16/09/2026). One-time dismissal of the post-first-login exam-date popup. Same self-service pattern as `has_dismissed_goal_prompt`. The nav chip / dashboard CTA still shows regardless — this only gates the modal. |

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
**Columns:** 23 (`is_public` dropped 03/07/2026 via Landmine L2 — `visibility` is now the sole visibility column)

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
| description | text | YES | NULL | Short note description/snippet. Previously undocumented — confirmed live via `pg_get_functiondef('get_public_note_preview')` on 2026-07-01 (Phase 5 Sprint 2 introspection). Distinct from `extracted_text` (full OCR body). |
| is_verified | boolean | NO | false | Professor-verified content badge |
| view_count | integer | NO | 0 | Engagement tracking |
| upvote_count | integer | NO | 0 | Quality signal |
| is_featured_on_landing | boolean | NO | false | ⭐ (Phase 5 Sprint 2, ✅ deployed 2026-07-01 — see `docs/database/phase5/03_SCHEMA_add_is_featured_on_landing_column.sql`). `CHECK (is_featured_on_landing = false OR visibility = 'public')`. Set to `true` only by `approve_featured_nomination()` (Sprint 3). Auto-cleared to false by `fn_autoclear_featured_on_visibility_change()` (BEFORE UPDATE, `trg_autoclear_featured_notes`) the moment `visibility` leaves `'public'`. Partial index `idx_notes_featured` on `WHERE is_featured_on_landing = true`. |
| featured_nominated_by | uuid | YES | NULL | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01 — see `docs/database/phase5/09_SCHEMA_add_featured_nomination_columns.sql`). FK → `profiles.id`. Set by `nominate_featured_content()`. Nulled by the auto-clear trigger on unpublish, and by `reject_featured_nomination()` / `unfeature_content()`. |
| featured_nominated_at | timestamptz | YES | NULL | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01). Set alongside `featured_nominated_by`. A non-NULL value with `is_featured_on_landing = false` is what makes a row appear in `get_pending_featured_nominations()`. |
| featured_approved_by | uuid | YES | NULL | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01). FK → `profiles.id`. Set by `approve_featured_nomination()`. Nulled by `reject_featured_nomination()` and `unfeature_content()`. |
| featured_approved_at | timestamptz | YES | NULL | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01). Set alongside `featured_approved_by`. |
| created_at | timestamp | NO | NOW() | Upload timestamp |
| updated_at | timestamp | NO | NOW() | Last modified |
| content_source_type | text | YES | NULL | ⭐ NEW (Sprint 8.7.1, 18/09/2026, ✅ deployed & verified live; frontend-populated since Sprint 8.7.3, 18/09/2026). `official_body` or `original_creator` (`CHECK`, NULL allowed at column level). Required only on INSERT via `trg_require_note_provenance` (see §3.2 `users_insert_notes`) — legacy rows stay NULL forever, never backfilled, and stay editable (trigger is `BEFORE INSERT` only). `NoteUpload.jsx` now collects and inserts this on every new note; `NoteEdit.jsx` never reads or writes it. |
| content_source_name | text | YES | NULL | ⭐ NEW (Sprint 8.7.1, 18/09/2026; frontend-populated since Sprint 8.7.3). Free-text source name, paired with `content_source_type`, same INSERT-only enforcement, same `NoteUpload.jsx`-only write path. |

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
- Old `is_public` boolean ✅ **DROPPED 03/07/2026** (Landmine L2) — read RLS re-keyed onto `visibility`
- Existing data migrated: `is_public=true` → `visibility='public'` (16 notes)
- Existing data migrated: `is_public=false` → `visibility='private'` (1 note)
- Migration SQL: `[SCHEMA] Add Visibility to Notes`; drop: `docs/database/landmines/12_SCHEMA_drop_is_public_notes_flashcards.sql`

**Related Tables:** profiles, disciplines, subjects, topics, comments, upvotes, friendships ⭐  
**Key Indexes:** user_id, target_course, visibility ⭐, created_at, discipline_id, subject_id, topic_id  
**RLS Policies:** 5 policies (see RLS section)

✅ **Resolved 02/07/2026:** the legacy free-text columns `course`, `subject`, `topic` (superseded by `subject_id`/`topic_id` FKs + `custom_subject`/`custom_topic`) were dropped via `docs/database/landmines/04_SCHEMA_drop_legacy_free_text_columns.sql` and verified live (Landmine Cleanup Sprint L1).

✅ **Resolved 02/07/2026:** the `comments` table (zero frontend usage) was dropped via `docs/database/landmines/03_CLEANUP_drop_comments_table.sql` and verified live (Landmine Cleanup Sprint L1). Removed from Related Tables above; §2.11 below is stale and should be deleted in a future docs pass.

⏳ **`is_public`** (not in the column table above — omission in this doc; it is a real, currently load-bearing column, see blueprint.md §1.11 landmine #2 and §2.2 there for the live-verified column list): SQL to rewrite the public-read RLS policy onto `visibility` and drop `is_public` is prepared but not yet deployed — see the `users_view_public_notes` / `users_view_friends_notes` policies above and `docs/database/landmines/10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql` / `12_SCHEMA_drop_is_public_notes_flashcards.sql`.

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
| question_type | text | NO | 'flashcard' | Type of study item. **Live values (Sprint 8.6c, 17/09/2026, ✅ deployed & verified live):** 'flashcard', 'mcq', 'correct_incorrect', 'theory', 'case_study_mcq', 'match_the_following', 'fitb', 'concept_card', 'mcq_multi' (9 values) — Sprint 7.9 dropped `test_your_understanding` (collapsed into `theory`+`subtype`, D-10 correction), `integrated_case` (never had an authoring path, D-12), and `true_false` (merged into `correct_incorrect`, D-14) from `chk_flashcards_question_type`; Sprint 8.6c added `mcq_multi` (see its own Representation section below, and D-20, blueprint.md §3.1). 'fill_in_the_blanks' is not and never was a live value (live value is 'fitb'). |
| options | jsonb | YES | NULL | Answer options for MCQ and similar types. |
| correct_answer | text | YES | NULL | Correct answer identifier for question types that need it. |
| hints | jsonb | YES | NULL | Optional hints array. |
| points_to_remember | jsonb | YES | NULL | Key takeaways, displayed post-answer. **Free-recall types only as of Sprint 7.9** (`flashcard`/`theory`/`concept_card`) — see `explanation` below for the graded-type sibling this was split from. |
| explanation | jsonb | YES | NULL | **New, Sprint 7.9 (14/09/2026).** Grading-rationale text ("Why") for graded types (`mcq`/`correct_incorrect`/`match_the_following`) — same shape as `points_to_remember` (jsonb array of strings), split off because the two concepts were sharing one column since Sprint 7.5/7.8. Additive, no backfill needed. `StudyMode.jsx`'s post-reveal WHY block reads this column for these types. |
| scenario | text | YES | NULL | Case study / scenario text for `case_study_mcq` rows. **Activated Sprint 7.10 (14/09/2026)** — declared since Sprint 6, genuinely unused (0 non-null rows) until this sprint. The same value is duplicated across every row sharing a case's `batch_id` (not normalized into a separate table) so it renders on any review day for any question in the case without a JOIN. |
| subtype | text | YES | NULL | Sub-classification within a question_type. **Activated Sprint 7.9 (14/09/2026)** — was declared but genuinely unused (0 non-null rows) until now. Required for `question_type='theory'`: `pure_theory` \| `descriptive_case_study` (mirrors CA Revision Portal's D14). Classification metadata only, no StudyMode.jsx rendering change. |
| source | text | NO | 'manual' | How the card was created: 'manual', 'bulk_upload', 'gemini_import'. No CHECK constraint — free text, the column default only applies if a writer omits it. **Sprint 8.7.2 (18/09/2026):** written explicitly by `create_flashcard_batches()`'s `p_creation_channel` parameter on every row, never left to the default. Before this, `BulkUploadFlashcards.jsx` never set it at all, so every bulk-uploaded row silently took the `'manual'` default — confirmed live pre-fix (100% of production rows were `'manual'`) and post-fix (bulk rows now show `'bulk_upload'`); see §4.0b and `docs/tracking/bugs.md`. |

**Visibility System (NEW - January 11, 2026):**
- `visibility` column replaces old `is_public` boolean
- Three levels:
  - **'private'**: Only creator can see (default)
  - **'friends'**: Creator + accepted friends can see
  - **'public'**: Everyone can see
- Constraint: `CHECK (visibility IN ('private', 'friends', 'public'))`
- Index: `idx_flashcards_visibility` for fast filtering

**MCQ Representation (Sprint 7.5, 13/09/2026 — ✅ SQL deployed & verified live):**
- `question_type='mcq'` uses only existing columns above, no schema change.
- `options` = jsonb array of option strings (2-6, default 4 in the create form).
- `correct_answer` = text, the **0-based INDEX** of the correct option as a string (`"0".."5"`) — NOT the option text, NOT a letter. Index-based because two options can have identical text.
- `back_text` (NOT NULL) is never typed directly for mcq — auto-derived as `options[correct_answer]` at save time.
- `explanation` = jsonb array, one entry per non-blank line of the "Why" textarea; shown post-reveal (**was `points_to_remember` until Sprint 7.9's column split** — see `question_type`/`explanation` rows above).
- `hints`/`scenario`/`subtype` stay NULL for this type.
- Authorship gated server-side by two new RESTRICTIVE RLS policies — see "RLS Policies" section below and blueprint.md D-10 (§3.1). **Deployed and verified live 13/09/2026** (`docs/database/sprint7.5/`, `02_TEST` — 5/5 PASS against real profiles).

**mcq_multi Representation (Sprint 8.6c, 17/09/2026, D-20 — ✅ SQL deployed & verified live):**
- `question_type='mcq_multi'` reuses `options`/`correct_answer`, no schema change to `flashcards` — same idiom as every other verdict-bearing type.
- `options` = jsonb array of option strings, 2-6, same shape as `mcq`.
- `correct_answer` = text, a **canonicalized SET of 0-based indices**, not a single index — unique, sorted ascending, joined with a single semicolon and no spaces (`"0;2;4"`, never `"4;0;2"` or `"0; 2; 4"`). Both `FlashcardCreate.jsx` (manual authoring) and `BulkUploadFlashcards.jsx` (CSV import) call the same `src/lib/mcq.js` helpers (`compactMcqMultiOptions`/`canonicalizeMultiAnswer`) so the two entry paths cannot drift. Parsed back into a set (`parseMultiAnswer`) and compared as a set at grading time in `StudyMode.jsx` — never string-compared.
- `back_text` (NOT NULL) is never typed directly — auto-derived as every correct option's text joined with `" • "` (`deriveMcqMultiBackText`).
- Grading is exact-set, all-or-none — no partial credit. Renders through its own StudyMode.jsx branch (build-up-then-submit via checkboxes, mirrors `match_the_following`'s `handleMatchSubmit` shape), **not** added to `GRADED_QUESTION_TYPES` (that array is specifically the shared single-tap `AnswerOption` list `mcq`/`correct_incorrect`/`case_study_mcq` use).
- `explanation` = jsonb array, same convention as `mcq`. `hints`/`scenario`/`subtype` stay NULL.
- Authorship gated by the same D-10 RESTRICTIVE RLS pair as every other verdict-bearing type, extended to include `mcq_multi` (`docs/database/sprint8.6c/01_SCHEMA_add_mcq_multi_type.sql`, not yet deployed).
- **Attempt evidence:** `review_events.selected_answer` (new nullable jsonb column, see 2.4A below) is populated only for this type, via a new `apply_review` trailing parameter `p_selected_answer` — every other question type passes `NULL` (unchanged call sites).
- **Deployment correction:** the first deploy attempt of `apply_review`'s new signature left two live overloads (5-arg + 6-arg) instead of replacing in place — `CREATE OR REPLACE FUNCTION` only replaces an exact parameter-signature match, so adding a parameter is always a distinct overload to Postgres, same lesson as `get_browsable_decks` v5 (§1.11). Fixed with an explicit `DROP FUNCTION public.apply_review(uuid,uuid,text,boolean,text);` (`docs/database/sprint8.6c/02b_HOTFIX_drop_ambiguous_apply_review_overload.sql`) before re-verifying. Confirmed post-fix: exactly one `apply_review` function exists.

**correct_incorrect Representation (Sprint 7.7, 13/09/2026; `true_false` merged into it Sprint 7.9 D-14) — identical rendering to mcq, only the option-label pair differs:**
- Uses the exact same columns as `mcq` above — `options`, `correct_answer`, `back_text` derivation, `explanation` — no schema change, no new StudyMode.jsx rendering branch (the existing mcq `AnswerOption`-list render is shared by both types via `GRADED_QUESTION_TYPES` in `src/lib/questionTypes.js`).
- **The one real difference from mcq:** `options` is **auto-populated, never professor-typed** — `["Correct","Incorrect"]` (`VERDICT_OPTION_LABELS` in `src/lib/questionTypes.js`). Authoring UI shows a 2-way toggle (which side is correct) instead of MCQ's free-text options editor.
- `correct_answer` = "0" or "1", same index convention as mcq.
- Already covered by the existing D-10 RESTRICTIVE RLS gate before Sprint 7.7 (Sprint 7.5's `01_SCHEMA_d10_role_gate.sql` IN-list already included it) — 7.7 added the authoring/bulk-upload UI, zero RLS changes.
- **⚠️ Correction (Sprint 7.9, 14/09/2026, D-14):** `true_false` was originally built alongside `correct_incorrect` in this same sprint as a mechanically-identical sibling (only the option-label pair — `["True","False"]` vs `["Correct","Incorrect"]` — differed). CA Revision Portal's own `docs/SCHEMA.md` documents `correct_incorrect`'s renderer as "Identical to `true_false`, with Correct/Incorrect buttons instead," and a real-usage census of that project's live content found `correct_incorrect` used 6× vs `true_false`'s 0× (its only occurrence sat in an orphaned legacy file no page loads). **`true_false` removed from `chk_flashcards_question_type`** (`docs/database/sprint7.9/04_SCHEMA_true_false_removal.sql`) — 0 rows existed, no data migration needed. `isTwoWayVerdictType()` (the helper that used to group both types) was retired in `FlashcardCreate.jsx`/`BulkUploadFlashcards.jsx`, collapsed to a direct `question_type === 'correct_incorrect'` check now that only one member remains.

**theory Representation (Sprint 7.7, 13/09/2026; subtype added Sprint 7.9) — free-recall, identical to plain `flashcard` except for a required classification field:**
- Render through the existing front/back path — no `options`, no verdict, no hybrid grading, full self-grade via `GradeButtonRow` exactly like `flashcard` today.
- Ungated — selectable by all users, not just professor/admin/super_admin (D-10 only gates the verdict-bearing types, and `theory` is not in that list).
- `theory` was already a live `chk_flashcards_question_type` value as of Sprint 7.5.
- **`subtype` required as of Sprint 7.9 (14/09/2026):** `pure_theory` | `descriptive_case_study`. Classification metadata only — does not change StudyMode.jsx rendering. Mirrors the CA Revision Portal's own D14, which solved the same "is this a distinct question_type or a subtype of theory" question this project had briefly answered the other way with `test_your_understanding` (Sprint 7.7).
- **⚠️ Correction (Sprint 7.9, 14/09/2026):** `test_your_understanding` was added to the CHECK constraint in Sprint 7.7 (`docs/database/sprint7.7/01_SCHEMA_add_test_your_understanding_type.sql`) but never should have been a distinct type — it duplicated what `theory`+`subtype` now does. **Removed from `chk_flashcards_question_type`** (`docs/database/sprint7.9/01_SCHEMA_sprint7.9_hygiene.sql`); the 2 rows that existed (both confirmed QA/testing artifacts from Sprint 7.7's own live verification) were deleted rather than migrated. The value is no longer insertable.

**match_the_following Representation (Sprint 7.8) — genuinely new interaction, deliberately different `options` shape:**
- `front_text` = the instructional stem (e.g. "Match each X with its Y").
- `options` = **ONE cohesive object, not a flat array like mcq's**: `{ left: string[], right: {k,v}[], correct: {[leftIndex]: k} }` — the correct mapping lives INSIDE `options`, colocated with the `right` list it references, avoiding double-encoding JSON inside `correct_answer`. Right-item keys (`k`, "A"/"B"/"C"...) are auto-generated by list position at save time — never professor-typed.
- `correct_answer` — **UNUSED for this type, stays NULL.** There is no single scalar "the answer"; the verdict is computed entirely from `options.correct`.
- `back_text` (NOT NULL) — auto-derived flattened summary, e.g. `"Machine hour rate — A; Direct labour hour rate — B; ..."` (`src/lib/matchTheFollowing.js` `deriveMatchBackText`).
- `explanation` = optional "why", same convention as mcq/correct_incorrect (**was `points_to_remember` until Sprint 7.9's column split**).
- **Locked for this slice:** `left` and `right` are always the same length (clean 1:1 bijection, no distractor right-options). Distractor rights and partial-credit scoring are explicit future refinements, not built this sprint.
- StudyMode renders this through its **own** `MatchZone` component (`src/components/revisop/MatchZone.jsx`) — a build-up-then-submit pick/assign interaction, not the shared `AnswerOption` single-tap list — so it is deliberately **not** added to `GRADED_QUESTION_TYPES`. Overall verdict is all-or-nothing (every row must match); same hybrid-grading contract as every other D-10 type (wrong → auto `apply_review('hard', false)` + single Continue; correct → reveal + `GradeButtonRow`, no pre-selected default).
- Authorship gated by the **same** D-10 RESTRICTIVE RLS pair already covering all 7 verdict-bearing types since Sprint 7.5 (`flashcards_gate_verdict_types_insert`/`_update`) — `match_the_following` was already in that policy's IN-list. **✅ Re-verified live 14/09/2026** via `docs/database/sprint7.8/00_DIAGNOSTIC_preflight.sql` (run by the operator, since this session has only the anon key): `chk_flashcards_question_type`'s live `pg_get_constraintdef` includes `'match_the_following'::text` exactly, and both RESTRICTIVE policies' `pg_get_expr(polwithcheck, ...)` list it exactly in their `<> ALL (ARRAY[...])` clause — same "introspect, don't assume the docs" practice that caught the `fitb` naming drift in Sprint 7.5. **Real finding: this sprint needed zero SQL**, same outcome as true_false/correct_incorrect in 7.7. Zero pre-existing `match_the_following` rows confirmed (query 3 returned no rows).
- **Bulk upload was deferred in Sprint 7.8-C, built in Sprint 8.6b** (17/09/2026): the variable-length left/right list doesn't fit the flat `option_1..4`/`correct_option` CSV convention mcq/correct_incorrect use, so instead of forcing it into flat columns, each row of the CSV carries ONE left/right pair — `match_left`/`match_right` — plus a `match_group` label the uploader chooses, identical across every row belonging to the same card and unique to it within the file (mirrors `case_study_mcq`'s `case_group` mechanic exactly). **Unlike `case_group`, which keeps each row its own separate card**, every row sharing a `match_group` is fused client-side into ONE `flashcards` row before insert — `BulkUploadFlashcards.jsx` accumulates rows per group (`target_course`/`subject`/`topic`/`front` must match across the group or the row is rejected), then builds `options` positionally (`buildMatchOptions(left, right, correctByIndex)` where `correctByIndex[i] = i` — the CSV never authors distractor right-items, that still needs the arbitrary-remapping dropdown UI, manual authoring only) and derives `back_text` via the same `deriveMatchBackText` manual authoring uses. 2-8 rows per group (`MATCH_MIN_PAIRS`/`MATCH_MAX_PAIRS`), enforced by the same `validateMatchPairs` manual authoring calls. Gated professor/admin/super_admin per D-10, same as manual authoring — confirmed live (a professor-account insert of a 3-pair grouped card succeeded; DB shape byte-identical to `FlashcardCreate.jsx`'s own insert).

**case_study_mcq Representation (Sprint 7.10, 14/09/2026) — a shared scenario fanning out into N independently-gradeable mcq rows, not a new grading mechanic:**
- Each question in a case is its **own `flashcards` row** — its own SRS card, own rung, reviewed on its own schedule — not one row with a nested question array. Per-question representation is **identical to `mcq`**: `options` (jsonb array, 2-6 strings), `correct_answer` (0-based index as text), `back_text` auto-derived as `options[correct_answer]`, `explanation` (jsonb array, one entry per non-blank "Why" line).
- `scenario` = the shared case narrative, **duplicated verbatim across every row belonging to the case** — not normalized into a separate table. This is a deliberate read-time-vs-write-time tradeoff: the scenario renders correctly on any review day for any question in the case with zero JOIN, at the cost of N-way duplication (acceptable — case scenarios are short/medium text, not large blobs).
- All rows in one case **share one `batch_id`** (generated once per case, `crypto.randomUUID()`), the D-01 grouping pattern (`src/lib/caseStudyMcq.js` doc-comment) — this is what lets My Study Sets' "Grouped" view show the case as one batch card, and is orthogonal to deck grouping (which is the existing 5-column subject/topic join, D-01/D-04 — a case's rows share `subject_id`/`topic_id` like any other row, so they fall into the deck for that topic "for free," no new grouping code needed for Browse Study Sets).
- `subject_id`/`topic_id`: **one shared anchor topic for the whole case** (D-12's authoring clarification, extended to `case_study_mcq`'s own authoring UI in this sprint) — the chapter the case exercise belongs to, via the same Course→Subject→Topic flow as every other type. No multi-topic tagging.
- StudyMode renders this through the **same shared `AnswerOption`/hybrid-grading branch as `mcq`** (`GRADED_QUESTION_TYPES` now includes `case_study_mcq` — `src/lib/questionTypes.js`), not a new render branch — the only addition is a collapsible "CASE SCENARIO" block rendered above the question when `currentCard.scenario` is present, open by default, reset to open on every card change. Grading is byte-for-byte the same hybrid contract as mcq (wrong → immediate `apply_review('hard', false)` + single Continue; correct → reveal + `GradeButtonRow`, no pre-selected default).
- **Authoring (`FlashcardCreate.jsx`):** one shared Scenario textarea + a repeatable question-block editor (2-8 questions per case, default 3 — `CASE_MIN_QUESTIONS`/`CASE_MAX_QUESTIONS`/`CASE_DEFAULT_QUESTIONS` in `src/lib/caseStudyMcq.js`), each question block a full mcq-shaped editor (question text, 2-6 options, correct-option radio, own "Why"). On save, one authoring block fans out into N `INSERT` rows sharing the case's `batch_id`/`scenario`/`subject_id`/`topic_id`. Gated professor/admin/super_admin per D-10, same as mcq/correct_incorrect/match_the_following.
- **Bulk upload (`BulkUploadFlashcards.jsx`) — built, not deferred** (unlike match_the_following 7.8-C): the flat CSV convention fits fine, since each case question is still naturally one row. Two new columns: `scenario` (repeated verbatim on every row of the case) and `case_group` (an uploader-chosen label, unique per case within the file, linking rows into one case — resolved client-side into a shared `batch_id` per distinct `case_group` value, separate from the file-wide `batch_id` every other bulk-uploaded row in the same CSV shares).
- Authorship gated by the **same** D-10 RESTRICTIVE RLS pair already covering `case_study_mcq` since Sprint 7.5 (`flashcards_gate_verdict_types_insert`/`_update` — `case_study_mcq` was in that policy's IN-list from the start; D-12, Sprint 7.9, removed `integrated_case` from the list but explicitly left `case_study_mcq` in place). **Re-confirmed live 14/09/2026** via `docs/database/sprint7.10/00_DIAGNOSTIC_preflight.sql` — see D-10 (blueprint.md §3.1) for the result.

**fitb Representation (Sprint 7.11, 14/09/2026) — confidence-gated verdict, not a binary one (D-13):**
- The only question type whose `is_correct` can be `true` or `NULL` but **never `false`** — a non-match is never proof of wrongness, only proof the author didn't anticipate that phrasing.
- `options` = jsonb array of acceptable-answer strings (1-6), reusing the same "answer options" column mcq/case_study_mcq use, with a generalized meaning (per D-13's impact line — not a new column).
- `front_text` = the blank-containing sentence, validated at authoring time to contain a blank marker (`______`, 3+ consecutive underscores) — `src/lib/fitb.js` `validateFitbBlank`/`FITB_BLANK_PATTERN`.
- `correct_answer` — **UNUSED for this type, stays NULL**, same pattern as `match_the_following`: there's no single scalar "the answer." The verdict is computed at grading time by normalizing the student's typed answer and checking it against every normalized `options` entry.
- **Normalization must be identical on both sides of the comparison** — one shared function (`src/lib/fitb.js` `normalizeFitbAnswer`: trim → lowercase → strip punctuation → collapse whitespace) is called on both the student's typed answer and every authored acceptable answer, at both authoring-compaction time and grading time. Never two similar-but-different implementations.
- `back_text` (NOT NULL) — auto-derived as the first accepted answer (`deriveFitbBackText`), same "derive, don't ask" convention as mcq/match_the_following.
- `explanation` = jsonb array, same shape/convention as every other graded type since Sprint 7.9 (was `points_to_remember` pre-split).
- **StudyMode.jsx renders through its own branch**, checked before `GRADED_QUESTION_TYPES` (deliberately NOT added to that array — same reasoning as `match_the_following` in 7.8: the confidence-gated three-way verdict isn't the clean binary that array assumes). Sentence renders with an inline `<input>` where the blank goes (`splitFitbSentence`); a Submit action runs the match check. **Match** → confident-correct styling (navy), reveal + unmodified `GradeButtonRow`, `apply_review(p_is_correct=true)` on whichever rating the student picks. **No match** → free-recall fallback styling (underlined, not navy), reveal shows an "ACCEPTED ANSWERS" box listing every `options` entry instead of a single correct answer, same full self-grade, `apply_review(p_is_correct=null)`. Both paths converge on the identical `GradeButtonRow` — there is no code path that calls `apply_review` with `is_correct=false` for this type.
- **Authoring (`FlashcardCreate.jsx`):** sentence-with-blank textarea (blank-marker validated at submit time) + a repeatable 1-6-row acceptable-answers list editor (`FITB_MIN_ANSWERS`/`FITB_MAX_ANSWERS`) + Why textarea. Gated professor/admin/super_admin per D-10, same as mcq/correct_incorrect/match_the_following/case_study_mcq.
- **Bulk upload (`BulkUploadFlashcards.jsx`) — built, not deferred:** new `fitb_answers` CSV column, semicolon-delimited within one cell (e.g. `"Rs 2.5 lakhs;2.5 lakhs;250000"`) — unlike `case_study_mcq`, fitb has no multi-row fan-out problem, so a flat multi-value cell is enough; no reason to defer like match_the_following's 7.8-C did.
- Authorship gated by the same D-10 RESTRICTIVE RLS pair already covering `fitb` since Sprint 7.5 (it was already in both policies' IN-lists before this sprint's authoring UI existed) — zero SQL needed this sprint, confirmed live via the same introspection discipline as every prior question-type sprint.

**concept_card Representation (Sprint 7.12, 14/09/2026) — browse-only reference material, never graded, last type in the roster:**
- `front_text` (NOT NULL) = heading (concept name). `back_text` (NOT NULL) = summary (2-3 sentence explanation), typed directly like a plain flashcard's back — **not derived**.
- `options` = jsonb array of `{term, definition}` objects (keyTerms, min 1) — a third reuse of the same column mcq/fitb use, this time as object pairs rather than scalar strings.
- `correct_answer`/`hints`/`scenario`/`subtype`/`explanation` all stay **NULL** — there is no verdict, ever, for this type (D-06).
- **Ungated** — open to all users (like `flashcard`/`theory`), unlike the 5 D-10-gated verdict-bearing types. There's no authoring-judgment risk to gate against when nothing is ever graded.
- `src/lib/conceptCard.js`: `buildConceptOptions()` drops any row missing either half of a term/definition pair; `validateConceptTerms()` enforces at least one complete pair. `CONCEPT_MIN_TERMS`=1, `CONCEPT_MAX_TERMS`=10.
- **Bulk upload was deferred at launch (Sprint 7.12), built in Sprint 8.6b** (17/09/2026), same mechanic as `match_the_following` above: keyTerms is a variable-length list of `{term, definition}` **pairs**, not a flat list like fitb's `fitb_answers` — a second-level CSV-cell delimiter would silently mis-split real content, since terms/definitions routinely contain their own colons and commas. Instead, each row carries ONE `concept_term`/`concept_definition` pair plus a `concept_group` label; every row sharing a `concept_group` is fused into ONE card (`front`/`back`/`target_course`/`subject`/`topic` must match across the group, including `back` — unlike every other bulk-uploadable type, concept_card's `back_text` is typed directly, not derived, so it has to be repeated verbatim on every row and is checked for consistency same as `front`). 1-10 rows per group (`CONCEPT_MIN_TERMS`/`CONCEPT_MAX_TERMS`), built via the same `buildConceptOptions`/`validateConceptTerms` manual authoring uses. **Still ungated** — unlike `match_the_following`, any account can bulk-upload it (D-06, no authoring-judgment risk to gate). Confirmed live (a 3-term grouped card inserted and rendered correctly through `ConceptCardViewer.jsx`'s existing accordion, unmodified by this sprint).
- **Browse-only viewer:** `ReviewFlashcards.jsx` (Browse Study Sets) renders a "Read Concepts" button on any deck tile whose `get_browsable_decks` row has `has_concept_card=true` (v6, below) — opens `src/components/flashcards/ConceptCardViewer.jsx`, a read-only accordion (heading always visible, click expands to summary + keyTerms), fetched directly via the 5-column deck-membership join (D-04). Zero grade buttons, zero `apply_review` calls anywhere in that component.
- **StudyMode leak closed this sprint:** `get_study_queue` had already excluded `concept_card` from the due-set since Sprint 6.0, but `StudyMode.jsx`'s separate "never-reviewed → new card" fallback filter didn't check `question_type` — since a concept card has no `reviews` row by definition, it passed that fallback and could reach a student, gradeable through the plain flashcard flip UI. Fixed with an explicit `question_type !== 'concept_card'` clause in the same filter. See the Concept Card Exclusion Rule below and blueprint.md D-06.

**Concept Card Exclusion Rule:**
- `concept_card` items are **excluded from all review metrics** (Items Reviewed, Items Mastered, accuracy, streak) — and, as of Sprint 7.12, from ever entering a study session at all, at any point in the client-side fetch pipeline (not just the RPC's due-set). They are reference material only.
- All analytics RPCs must use `WHERE question_type != 'concept_card'` inline (the `vw_study_items` safety view was dropped 02/07/2026 as dead/unconsumed — do not reintroduce it).
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
- Old `is_public` boolean ✅ **DROPPED 03/07/2026** (Landmine L2) — read RLS re-keyed onto `visibility`
- Existing data migrated: `is_public=true` → `visibility='public'` (340 cards)
- Existing data migrated: `is_public=false` → `visibility='private'` (227 cards)
- Migration SQL: `[FIX] Migrate flashcard visibility from is_public`; drop: `docs/database/landmines/12_SCHEMA_drop_is_public_notes_flashcards.sql`

**Related Tables:** profiles, notes, reviews, disciplines, subjects, topics, friendships ⭐  
**Key Indexes:** user_id, batch_id (critical for grouping), target_course, visibility ⭐, created_at  

⏳ **`is_public`** (not in the column table above — omission in this doc; it is a real, currently load-bearing column, see blueprint.md §1.11 landmine #2): SQL to rewrite the public-read RLS policy onto `visibility` and drop `is_public` is prepared but not yet deployed — see the `users_view_public_flashcards` / `users_view_friends_flashcards` policies above and `docs/database/landmines/10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql` / `12_SCHEMA_drop_is_public_notes_flashcards.sql`.

✅ **Dropped 02/07/2026 (L1, `05_SCHEMA`):** the four undocumented legacy SRS columns — `next_review`, `interval`, `ease_factor`, `repetitions` — were removed from `flashcards`. Superseded by `reviews.next_review_date`/`interval`/`easiness`/`repetition` (always read SRS state from `reviews`, never `flashcards`). Sole writer was `FlashcardCreate.jsx`'s hardcoded seed payload, stripped in commit `921280b`. Required dropping the dead `vw_study_items` view first (`08_CLEANUP` — it `SELECT`ed these columns; see blueprint §1.11 audit-gap note).
**RLS Policies:** 5 policies (see RLS section) **+ 2 more (Sprint 7.5 D-10, ✅ deployed & verified live 13/09/2026)** — `flashcards_gate_verdict_types_insert`/`_update`, RESTRICTIVE, block non-professor/admin/super_admin authorship of verdict-bearing question types.

**CRITICAL:** Always group by `batch_id`, NOT by timestamp or created_at

---

### 2.3A-i Sprint 8.7.6 triggers on flashcards (21/09/2026, ✅ deployed, test ALL PASS)
- `fn_guard_flashcard_batch_move()` + `trg_guard_flashcard_batch_move` — BEFORE UPDATE OF batch_id, FOR EACH ROW, WHEN (OLD.batch_id IS DISTINCT FROM NEW.batch_id). SECURITY DEFINER, search_path pg_catalog, public. Blocks provenance mismatch (strict type+name), NULL moves, non-existent/foreign-owner targets. SQLSTATE `RV601`; prefixes `MERGE_PROVENANCE_MISMATCH:`, `MERGE_TARGET_INVALID:`.
- `fn_cleanup_orphan_batch_provenance()` + `trg_cleanup_orphan_batch_provenance` — AFTER UPDATE, FOR EACH STATEMENT, transition tables old_rows/new_rows. SECURITY DEFINER. Deletes provenance rows of source batches left with zero flashcards.
- Rollback: `docs/database/sprint8.7.6/03_ROLLBACK_merge_provenance_guard.sql`.

### 2.3A flashcard_batch_provenance ⭐ NEW (Sprint 8.7.1, 18/09/2026, ✅ deployed & verified live)

**Purpose:** D-21 content provenance (blueprint.md §3.1) — one row per flashcard `batch_id` declaring its content source. Provenance belongs to the batch, not the individual card, because a bulk upload's cards within one batch always share one source document.

**Legacy-absence semantics:** the table is only ever populated by `create_flashcard_batches()` (§4.0b) going forward. Pre-8.7.1 `batch_id`s get no row — **never backfilled**. Any read joining against this table must use `LEFT JOIN` and treat a missing row as "unknown/legacy provenance," never as an error or a value to fill in.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| batch_id | uuid | NO | - | Primary key. Not a foreign key to `flashcards.batch_id` (that column carries no FK constraint either — confirmed live, Step 0 diagnostic). |
| content_source_type | text | NO | - | `CHECK (content_source_type IN ('official_body', 'original_creator'))` |
| content_source_name | text | NO | - | `CHECK (btrim(content_source_name) <> '')` |
| created_by | uuid | YES | NULL | FK → `profiles.id` |
| created_at | timestamptz | NO | now() | |

**Why `NOT NULL` on every column except `created_by`/`created_at`'s FK nullability:** a row exists only when provenance exists — there is no partially-populated state. Legacy batches are represented by the *absence* of a row, not by a row with NULL source fields.

**RLS:** enabled, **zero policies** for `authenticated`/`anon` on INSERT/UPDATE/DELETE — direct writes are impossible; only `create_flashcard_batches()` (SECURITY DEFINER, owner `postgres`, bypasses RLS as table owner) can write. `GRANT SELECT ... TO authenticated` exists (added by `04_HOTFIX_grants.sql`) — originally not paired with any SELECT *policy*, so it alone unlocked 0 rows; it existed solely so the `EXISTS(...)` subquery inside the `flashcards` INSERT policy (§3.3) could execute at all without a hard "permission denied for table" error.

**Sprint 8.7.4 — read policy added (D-21 display):** `authenticated_read_flashcard_batch_provenance`, `FOR SELECT TO authenticated USING (true)` — unconditional, not an attempt to mirror flashcards' own visibility rules inside a subquery here (`docs/database/sprint8.7.4/01_SCHEMA_provenance_select_policy.sql`; reasoning recorded in that file's header and in now.md). Provenance (a source type + name) is not sensitive per-batch content the way flashcard text is — this policy does not touch `flashcards`' own RLS. `anon` still has no table-level grant at all (unchanged from 8.7.1), so this remains `authenticated`-only.

**SQL:** `docs/database/sprint8.7/01_SCHEMA_provenance_foundation.sql`, `04_HOTFIX_grants.sql`, `docs/database/sprint8.7.4/01_SCHEMA_provenance_select_policy.sql`. Test: `03_TEST_verify_sprint8.7.1.sql` (T2/T2b/T2c: direct INSERT/UPDATE/DELETE all denied to `authenticated`; T5: duplicate-`batch_id` reuse rejected; T6/T6b/T6c: happy-path row creation correct; 18/18 PASS live 18/09/2026); `docs/database/sprint8.7.4/05_TEST_verify_sprint8.7.4.sql` (T1: exactly one SELECT policy; T2: authenticated can now read; T3: writes still denied; T7: anon still denied).

---

### 2.4 reviews

**Purpose:** Spaced repetition review history (SuperMemo-2 algorithm)
**Created:** December 2025
**Columns:** 12

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to **auth.users.id** (`ON DELETE CASCADE`) — ⚠️ NOT `profiles.id`; corrected 13/09/2026 (Sprint 7.4 Phase 0 introspection) after this doc had it wrong |
| flashcard_id | uuid | NO | - | Foreign key to flashcards.id, `ON DELETE CASCADE` |
| quality | integer | NO | - | 1=Hard, 3=Medium, 5=Easy |
| easiness | double precision | YES | 2.5 | SuperMemo-2 EF value — ⚠️ column is `easiness` NOT `easiness_factor`; type is `double precision` (float8) NOT numeric. **Legacy-cosmetic after the SRS Ladder Epic** — still written by `apply_review` (Sprint 7.4; was `submit_review`), no longer drives scheduling. |
| interval | integer | YES | 0 | Days until next review. **Legacy-cosmetic after the SRS Ladder Epic** (= the resolved rung interval). Reserved word — quote as `"interval"` in raw SQL. |
| repetition | integer | YES | 0 | Times graded (incremented every grade, incl. Hard) — ⚠️ column is `repetition` NOT `repetitions`. **Legacy-cosmetic after the SRS Ladder Epic**; also the source column for the one-time `rung` backfill. |
| next_review_date | **date** | YES | NULL | When the card is due next. ⚠️ **DATE, not timestamp** — stored as `YYYY-MM-DD` (`StudyMode.jsx` / `apply_review` build it from local Y/M/D). Treating it as a timestamp causes "wrong day" bugs. *(Prior versions of this doc said `timestamp NOT NULL DEFAULT NOW()` — that was stale; verified `date` NULLable via Phase 0 Q6, 03/09/2026.)* |
| last_reviewed_at | timestamptz | YES | now() | Timestamp of most recent rating |
| status | text | NO | 'active' | `active` / `suspended` / **`mastered`** (the last added by the SRS Ladder Epic — see below). CHECK: `status IN ('active','suspended','mastered')`. |
| skip_until | date | YES | NULL | Date until which card is hidden (skip 24hr) |
| rung | smallint | YES | NULL | **SRS Ladder Epic (✅ deployed 03/09/2026).** Ladder position (0..7 for the `_default` curve; CHECK 0..20). `NULL` = not yet on the ladder. Authoritative scheduling state — `apply_review` (Sprint 7.4; was `submit_review`) computes it, `get_study_queue` returns it. |
| created_at | timestamptz | YES | now() | When the review row was first created (first-ever grade of the card). Used for streak calc. NOT touched on re-grade. |

**Card Suspension System (NEW - February 6, 2026):**
- `status` column enables indefinite card suspension ('active' or 'suspended')
- `skip_until` enables temporary 24-hour skip (card reappears after date)
- Suspended cards don't count as "due" and don't affect streak
- Skipped cards are filtered out of due queries when `skip_until > today`
- Constraint: `CHECK (status IN ('active', 'suspended'))`
- Unique constraint: `reviews_user_flashcard_unique UNIQUE (user_id, flashcard_id)` — one review record per user per card

**Why This Structure:**
- Implements SuperMemo-2 algorithm for optimal retention
- `quality` maps to: 1=Hard (review soon), 3=Medium (review later), 5=Easy (review much later)
- `easiness` adjusts based on performance (2.5 default)
- `interval` grows exponentially for correctly answered cards
- `created_at` used for study streak calculation (NOT reviewed_at)

**Related Tables:** profiles, flashcards
**Key Indexes:** user_id, flashcard_id, next_review_date (for due cards), created_at (for streak calculation)
**RLS Policies:** 4 policies (see RLS section)

---

### 2.4A review_events

**Purpose:** Append-only per-review history — one row per grade, ever. `reviews` (2.4) stays the current-state SSOT (unchanged shape/semantics); this table exists because `reviews` is updated in place, so it cannot answer "how many times was this graded, and with what verdict, over time." Written atomically with the `reviews` write, inside `apply_review` (same transaction — a failure in either write rolls back both).
**Created:** 13/09/2026 (Sprint 7.4)
**Columns:** 15 (`selected_answer` added Sprint 8.6c, 17/09/2026, ✅ deployed & verified live)

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | bigint | NO | GENERATED ALWAYS AS IDENTITY | Primary key |
| user_id | uuid | NO | - | Foreign key to **auth.users.id**, `ON DELETE CASCADE`. ⚠️ NOT `profiles.id` — confirmed against the live `reviews.user_id` FK (which also targets `auth.users`, not `profiles`) rather than assumed. |
| flashcard_id | uuid | NO | - | Foreign key to flashcards.id, `ON DELETE CASCADE` |
| reviewed_at | timestamptz | NO | now() | |
| rating | text | NO | - | `hard` / `medium` / `easy`. CHECK constrained. |
| is_correct | boolean | YES | NULL | NULL = no deterministic verdict (self-graded flashcard/theory/etc — everything before Sprint 7.5's graded question types). Populated only by graded question types going forward. |
| question_type | text | NO | - | Snapshot at review time (not a live join to `flashcards`) |
| topic_id | uuid | YES | NULL | Snapshot; NULL for custom_topic cards |
| rung_before | smallint | YES | NULL | NULL = card was brand-new (no prior ladder position) at the moment of this grade |
| rung_after | smallint | NO | - | |
| status_after | text | NO | - | `active` / `suspended` / `mastered`. CHECK constrained. |
| interval_days | integer | NO | - | |
| next_review_date | date | NO | - | |
| source | text | YES | NULL | `NULL` \| `'review_session'` \| `'new_card'` \| `'exam_final_pass'` |
| study_session_id | uuid | YES | NULL | Reserved — stays NULL. Session-logging rework is a later sprint, not Sprint 7.4. |
| selected_answer | jsonb | YES | NULL | **New, Sprint 8.6c (17/09/2026, ✅ deployed & verified live).** Student's actual selected answer set, as attempt evidence alongside `is_correct`. Populated only by `mcq_multi` for now — every other question_type leaves this NULL, no backfill. Written via `apply_review`'s new `p_selected_answer` parameter. |

**Access:** RLS enabled, **zero policies, zero grants** (`REVOKE ALL FROM PUBLIC, anon, authenticated`). Every read/write goes through a SECURITY DEFINER RPC — `apply_review` writes it, analytics RPCs (`get_question_type_performance`, `get_educator_accuracy_by_qtype`) read it. No client `.from('review_events')` call should ever exist.
**Measured cost (13/09/2026, live, real rows):** ~142 bytes/row (`pg_column_size`). Current total DB size 53MB against the Supabase Free-plan 500MB limit — no near-term storage concern at current or projected volume; re-measure after real (non-test) usage accumulates. See blueprint.md D-11 for the full projection.
**Related Tables:** reviews (shadows it), flashcards, auth.users
**Key Indexes:** `(user_id, reviewed_at DESC)`, `(flashcard_id, reviewed_at DESC)`
**RLS Policies:** 0 (intentional — SECURITY DEFINER RPC access only)

**CRITICAL — COLUMN NAME TRAPS (both caused production bugs):**
- Column is `created_at`, NOT `reviewed_at` (caused runtime error on 2025-12-27)
- Column is `easiness`, NOT `easiness_factor` (caused error 42703 on 2026-04-04)
- Column is `repetition`, NOT `repetitions` (caused error 42703 on 2026-04-04)
- Any SQL written against this table MUST be verified against `StudyMode.jsx` handleRating INSERT before deploying

**SRS Ladder Epic additions (✅ `docs/database/srs-ladder/01`–`05`, DEPLOYED & VERIFIED 03/09/2026):**
- `reviews.rung smallint NULL` (CHECK 0..20) — the ladder position; authoritative scheduling state.
- `reviews_status_check` extended: `('active','suspended')` → `('active','suspended','mastered')`.
- `idx_reviews_user_mastered` — partial index `ON reviews(user_id) WHERE status = 'mastered'` (Mastered list).
- New table `srs_ladder_curves(question_type text, rung_index smallint, interval_days integer, PK(question_type, rung_index))` — per-type rung→interval. `_default` curve seeded 1/3/7/14/30/60/120/240. RLS on, `SELECT` to anon+authenticated, no client write.
- New table `srs_ladder_rules(id smallint PK DEFAULT 1 CHECK(id=1), rules jsonb)` — single row of the transition rules, read by `submit_review` / `srs_preview` / `get_srs_ladder_config` so client + server cannot drift.
- New RPCs: `submit_review(p_user_id,p_flashcard_id,p_rating)` (write SSOT), `srs_preview(p_rung,p_question_type)`, `get_srs_ladder_config()`, `get_mastered_cards(p_user_id)` (Phase 3, `06`), internal `srs_interval_for_rung(p_rung,p_question_type)`.
- Changed: `get_study_queue` return shape gains `rung smallint`; `get_due_forecast` body rewritten to share the exact `get_study_queue` due predicate (signature unchanged).

---

### 2.4B my_cards_enrollment

**Purpose:** Durable "this external (not-own) card belongs to this student's My Cards" marker — the enrollment layer in front of the frozen SRS engine (My Cards Enrollment epic, Sprint 8.7.8b). Independent of `reviews.status`: a membership row survives Pause/Resume on the paired review, and Remove soft-deletes (`status='removed'`) rather than hard-deleting — the Pause-vs-Remove distinction on a `reviews.status='suspended'` row is resolved entirely by THIS table's own `status` column, never by a new `reviews.status` value (design-review/my-cards-enrollment-proposal.md §8).
**Created:** 22/09/2026 (Sprint 8.7.8b), ✅ SQL deployed & test-verified (44/44 PASS) & live-verified (disposable-data round trip, residue confirmed 0).
**Columns:** 5

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | uuid_generate_v4() | Primary key |
| user_id | uuid | NO | - | Foreign key to **auth.users.id**, `ON DELETE CASCADE` — matches `reviews.user_id`/`review_events.user_id` convention, not `profiles.id`. |
| flashcard_id | uuid | NO | - | Foreign key to flashcards.id, `ON DELETE CASCADE` |
| added_at | timestamptz | NO | now() | Last-meaningful-transition timestamp — refreshed on genuine re-add after Remove, left unchanged on a redundant re-add of an already-active row. |
| status | text | NO | 'active' | `active` / `removed`. CHECK constrained. |

**Constraints:** `UNIQUE (user_id, flashcard_id)` — exactly one row per (student, card) pair, same precedent as `reviews`' own unique constraint.
**Access:** RLS enabled, **zero policies, zero grants** (`REVOKE ALL FROM PUBLIC, anon, authenticated`) — reproduces `review_events`' precedent exactly. All reads/writes go through `add_to_my_cards` / `remove_from_my_cards` / `get_my_cards` (SECURITY DEFINER). No client `.from('my_cards_enrollment')` call should ever exist.
**Key Indexes:** partial index `(user_id) WHERE status = 'active'`.
**⚠️ Superseded by Sprint 8.7.10 (25/09/2026), see §2.4E below.** The line that used to read here ("own content never needs a row here — it auto-enters My Cards via `flashcards.user_id = viewer`") was the pre-8.7.10 behavior. As of `get_my_cards` v2, own content requires an active row here too, identical to external content — authorship no longer implies enrollment. 1084 own-authored cards with genuine prior SRS history were backfilled into this table during the migration (see §2.4E and blueprint.md D-32).
**Enrollment expresses intent, not access:** every read re-applies the live visibility predicate (own/public/accepted-friends — `get_study_queue`'s predicate, see below) at read time, so a card that goes private/unfriended after being added simply stops appearing, with zero enrollment-specific code.

### 2.4C practice_attempts

**Purpose:** Append-only log of Practice/Explore interactions — zero SRS side effect by design. Exists because `review_events` (2.4A) has ladder-derived columns (`rung_before/after`, `status_after`, `interval_days`, `next_review_date`) that have no valid value for an attempt that never touches the SRS ladder.
**Created:** 22/09/2026 (Sprint 8.7.8b), ✅ SQL deployed & test-verified (44/44 PASS) & live-verified.
**Columns:** 4

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | bigint | NO | GENERATED ALWAYS AS IDENTITY | Primary key — matches `review_events.id`'s convention for this schema's append-only event/log tables. |
| user_id | uuid | NO | - | Foreign key to **auth.users.id**, `ON DELETE CASCADE`. |
| flashcard_id | uuid | NO | - | Foreign key to flashcards.id, `ON DELETE CASCADE` |
| attempted_at | timestamptz | NO | now() | |
| is_correct | boolean | YES | NULL | Nullable — see `log_practice_attempt`'s question-type integrity rules below. |

**Access:** RLS enabled, **zero policies, zero grants** — same posture as `my_cards_enrollment`/`review_events`. All writes go through `log_practice_attempt` (SECURITY DEFINER). No trigger exists on this table, and none may be added that writes to `reviews`/`review_events`/badge tables/streak tables/`user_stats` — this is an explicit guardrail from the sprint brief, not an oversight to "fix" later.
**Key Indexes:** `(user_id, attempted_at DESC)`.

---

### 2.4D Sprint 8.7.8b RPCs (My Cards enrollment)

All four follow the established hardened-RPC convention: `plpgsql`, `SECURITY DEFINER`, `SET search_path TO public, extensions` (unquoted), self-only IDOR guard (`p_user_id IS DISTINCT FROM auth.uid() AND NOT is_admin()` → RAISE), explicit `REVOKE ... FROM PUBLIC, anon` + `GRANT EXECUTE ... TO authenticated`.

| RPC | Purpose | Visibility predicate used | Notes |
|-----|---------|---------------------------|-------|
| `add_to_my_cards(p_user_id, p_flashcard_id)` | Add or re-add an external card to My Cards. | `get_study_queue`'s (own/public/accepted-friends only — no admin override, no group-share). | Atomic `INSERT ... ON CONFLICT DO UPDATE` (never SELECT-then-INSERT). Distinguishes a genuine re-add after Remove (`old_status='removed'` → calls `unsuspend_card`, preserving rung/repetition/easiness) from an already-active call (the Pause case — must NOT resume). Never calls `reset_card`. Rejects `concept_card`. |
| `remove_from_my_cards(p_user_id, p_flashcard_id)` | Soft-remove membership (`status='removed'`), preserving SRS history. | N/A (acts only on the caller's own enrollment row). | No-op if no membership row exists for the pair. If a `reviews` row exists with `status IN ('active','mastered')`, calls `suspend_card` in the same call — never creates a bare `reviews` row for a never-graded card. |
| `get_my_cards(p_user_id)` | Returns own ∪ actively-enrolled-and-still-visible external cards. `RETURNS SETOF public.flashcards` (not a hand-enumerated column list, so the shape always tracks the live table). | `get_study_queue`'s, re-applied at READ time per card. | Does not touch or wrap `get_study_queue` (frozen, unchanged). Wired into `StudyMode.jsx`'s step-1 fetch (Sprint 8.7.8c) — live-verified: a subject with 197 visible/0-enrolled cards now shows exactly the viewer's own card in Study Mode. |
| `log_practice_attempt(p_user_id, p_flashcard_id, p_is_correct)` | Logs a Practice/Explore attempt. Writes only to `practice_attempts`. | Browse/Practice predicate (own/public/accepted-friends/admin override/group-shared) — matches `get_browsable_decks` v8's card-level predicate verbatim. Deliberately WIDER than `add_to_my_cards`'s (Anand's explicit decision, 22/09/2026). | Enforces question-type integrity (8.7.8a confirmed semantics): `flashcard`/`theory` require `is_correct IS NULL`; `mcq`/`mcq_multi`/`case_study_mcq`/`match_the_following` require non-NULL boolean; `fitb` allows `TRUE`/`NULL` only (D-13 — never a hard `FALSE`, unmatched wording is non-conclusive); `concept_card` is rejected outright. |

**Known compatibility gap, recorded not fixed:** `add_to_my_cards`/`get_my_cards` cannot enroll a card that is visible only via a study-group share, because `get_study_queue` (frozen, out of scope for 8.7.8b) does not know about group shares. `log_practice_attempt` correctly allows practicing such a card. Once `get_study_queue`'s own visibility is ever extended to group-shared content, `add_to_my_cards`/`get_my_cards`'s predicate should be widened to match in a later sprint.

**Files:** `docs/database/sprint8.7.8b/01`–`05`.

---

### 2.4E get_practice_cards (Sprint 8.7.8c, ✅ SQL deployed & test-verified 15/15 PASS incl. eligibility parity)

**Purpose:** Batched Practice-card retrieval + proactive enrollment-eligibility RPC. Replaces the frontend's only remaining direct, narrow, eligibility-blind card fetch (`StudyMode.jsx`'s old step-1 query, now itself replaced by `get_my_cards` — see 2.4D). Chosen over extending an existing RPC because the old fetch was client-side and had the wrong (non-Practice) predicate — Step 0's own decision tree, Option B.

`get_practice_cards(p_user_id uuid, p_deck_ids uuid[], p_question_type text DEFAULT NULL)` — `plpgsql`, `STABLE`, `SECURITY DEFINER`, `SET search_path TO public, extensions`, same self-only IDOR guard + ACL convention as every RPC in this section.

**⚠️ Signature changed, Sprint 8.7.10 Scope C (25/09/2026):** `p_deck_id uuid` → `p_deck_ids uuid[]`, to support subject-wide "Practice All" (see D-32 addendum, blueprint.md). Required `DROP FUNCTION` first (different arg identity, same lesson `apply_review`'s Sprint 8.6c parameter addition already taught). Single-deck behavior preserved exactly by always passing a 1-element array from `PracticeMode.jsx`'s existing `?deck=` entry point.

| Step | Behavior |
|------|----------|
| 1. Deck validation | Re-checks every id in `p_deck_ids` against `get_browsable_decks` v8's exact deck-level VISIBILITY GATE + COURSE GATE (`docs/database/sprint8.7.7/11_...sql:166-196`, reproduced verbatim) **before** resolving any deck's five grouping columns. If **zero** decks in the array validate, raises `42501` ("Study Set not accessible") — preserves the single-deck contract exactly (a 1-element array that fails the gate still errors). If **some but not all** validate (only possible with more than one id), the invalid ones are silently skipped rather than erroring the whole call — a stale-visibility race shouldn't block practicing the still-accessible majority. |
| 2. Card selection | 5-grouping-column `EXISTS` match (never `flashcards.deck_id`, which is NULL for bulk-uploaded cards) against the validated decks' `(user_id, subject_id, topic_id, custom_subject, custom_topic)` tuples, unioned via a single query (not a client-side loop). `question_type = 'concept_card'` is excluded unconditionally (D-06). `SELECT DISTINCT` guards against a card matching more than one validated deck tuple. |
| 3. Practice visibility | `log_practice_attempt`'s predicate, verbatim (own/public/accepted-friends/admin override/group-shared) — re-checked per card, independent of the deck-level gate (defense in depth: a deck can contain mixed-visibility cards). |
| 4. Returned flags | `is_own` (`user_id = p_user_id`); `is_enrolled` (active `my_cards_enrollment` row only — the signal Practice Mode uses to show "Added to My Cards" instead of re-offering Add); `can_add_to_my_cards` computed with `add_to_my_cards`'s exact predicate (own/public/accepted-friends only, no admin/group-share). A card can be Practice-visible via admin override or group-share while `can_add_to_my_cards=false` — the intended, documented gap (2.4D). |

**Scope C live verification (25/09/2026):** a real 11-deck, 197-card subject ("Practice All") correctly unioned cards across multiple sampled decks with zero console errors, My Study enrollment count unchanged (34→34) after browsing, existing single-deck Practice and unrelated per-deck Study paths both unaffected, and a single-deck subject (1-element array) also confirmed working.

**Eligibility parity is a live-verified test, not an assumption**: `docs/database/sprint8.7.8c/02_TEST_verify_get_practice_cards.sql` proves a card `get_practice_cards` marks `can_add_to_my_cards=false` (group-share-only fixture) is *actually* rejected by `add_to_my_cards` itself, and that `is_enrolled` flips `false → true` after a real `add_to_my_cards` call on the same card, within the same test transaction.

**Hotfix (23/09/2026) — ✅ deployed, test-verified, live-verified:** `RETURNS TABLE` originally omitted `scenario`, so `case_study_mcq` cards in Practice Mode rendered with no case narrative — `PracticeMode.jsx`'s scenario display block existed but silently had nothing to show. `scenario text` (verbatim `fc.scenario`) added to the return shape; `NULL` for every non-case-study row, unaffected. `docs/database/sprint8.7.8c/10_FIX_add_scenario_to_get_practice_cards.sql` (`DROP`+`CREATE`, not `CREATE OR REPLACE`, since the return shape changed). Live browser verification used a disposable fixture card (`13_DATA_create_scenario_fixture_card.sql`) since the real live case_study_mcq content's course scope was inaccessible to the test account — fixture deleted afterward, 0 residue confirmed.

**Files:** `docs/database/sprint8.7.8c/01`–`03` (function, test, rollback), `10`–`14` (scenario-column hotfix, verification, test-id diagnostic, disposable fixture + cleanup).

---

### 2.4F My Study Semantic Cleanup (Sprint 8.7.10, ✅ SQL deployed & live-verified 25/09/2026 — see blueprint.md D-32)

**Purpose:** Closes D-27's deliberate 8.7.8b gap — own-authored cards no longer bypass `my_cards_enrollment`. `get_my_cards()`'s own-card branch now requires the same active enrollment row as external content; `apply_review()` gained a defense-in-depth enrollment + not-suspended guard.

- **`get_my_cards(p_user_id)` v2** — same signature, in-place `CREATE OR REPLACE`. Own-card branch changed from unconditional `f.user_id = p_user_id` to requiring `EXISTS (... my_cards_enrollment ... status='active' ...)`, identical predicate shape to the not-own branch. Not-own branch itself unchanged.
- **`apply_review(...)` guard** — same 6-arg signature (unchanged since Sprint 8.6c), same in-place `CREATE OR REPLACE`. Two new checks inserted right after the existing `reviews` row lookup, before the new-card/existing-card branch: (1) `RAISE EXCEPTION ... ERRCODE '42501'` if no active `my_cards_enrollment` row exists for `(p_user_id, p_flashcard_id)`; (2) same ERRCODE if the existing `reviews.status = 'suspended'`. Both are defense-in-depth — confirmed via full codebase grep that `apply_review` has exactly one live caller (`StudyMode.jsx`), which only ever grades cards already filtered through `get_my_cards`/`get_study_queue`, so neither guard changes any real reachable flow.
- **`add_batch_to_my_cards(p_user_id, p_flashcard_ids uuid[])`** (new RPC) — `RETURNS TABLE(out_flashcard_id uuid, enrollment_status text)`. Atomic, set-based `INSERT ... ON CONFLICT DO UPDATE` over an array, same idempotent upsert semantics as `add_to_my_cards` but for N cards in one round trip — justified because bulk upload can enroll hundreds of cards at once and looping the single-card RPC would mean hundreds of round trips with real partial-failure risk. Reuses `add_to_my_cards`'s exact visibility predicate (own/public/accepted-friends, `concept_card` excluded). Does **not** reproduce `add_to_my_cards`'s re-add-after-Remove → `unsuspend_card` branch — acceptable because its only live callers (`FlashcardCreate.jsx`, `BulkUploadFlashcards.jsx`) only ever pass freshly-created flashcard ids, never a pre-existing card id that could have prior enrollment history.
  - **⚠️ Output column name is `out_flashcard_id`, not `flashcard_id`** — a first attempt named it `flashcard_id`, which collided with the unqualified `flashcard_id` inside the function's own `ON CONFLICT (user_id, flashcard_id)` target list (PL/pgSQL implicitly declares every `RETURNS TABLE` column as a body-scoped variable — the exact gotcha this doc's `get_practice_cards` entry already documents), causing a live `42702 ambiguous column` error caught during acceptance testing. Fixed via `DROP FUNCTION` + `CREATE FUNCTION` (required — Postgres will not `CREATE OR REPLACE` a changed `RETURNS TABLE` shape) with the renamed column. No caller reads the RPC's returned columns (both call sites only check for an error), so this needed no frontend change.
- **Migration (`01_DATA` + `08_CLEANUP`)** — backfilled `my_cards_enrollment` for own-authored cards with genuine prior SRS history. Evidence rule: a `reviews` row alone is *not* sufficient — `skip_card`/`suspend_card` also write a bare `reviews` row (`rung` never set) independent of real grading. The unambiguous signal is `review_events` (written only by `apply_review`) or a populated `rung` (legacy grading that predates `review_events`). Final reconciled population: **1084** own cards backfilled `active` (6 with a `review_events` row, 1078 legacy pre-`review_events` with populated `rung`, varied 0–4); **1721** own cards (never reviewed, or only ever skipped/paused with no real grade) correctly excluded. `reviews`/`review_events` history itself was never touched by either migration file — only `my_cards_enrollment` rows were inserted/deleted.
- **Frontend:** `FlashcardCreate.jsx` (Save only / Save & Add to My Study) and `BulkUploadFlashcards.jsx` (Upload only / Upload & Add to My Study, confirmed with the real parsed count first) call `add_batch_to_my_cards` as a separate, recoverable step after creation succeeds — a failed enrollment never presents as a failed save/upload, and its Retry only re-runs the idempotent enrollment call.

**Scope C (subject-wide Practice All) shipped 25/09/2026 — see §2.4E's signature-change note.**

**Scope D (My Study page redesign) shipped 25/09/2026 — Sprint 8.7.10 now fully complete.** `MyCards.jsx` rebuilt around Subject → Topic grouping with New/Active/Paused counts; Mastered/Removed moved to a History tab. New RPC:

**`get_removed_my_cards(p_user_id uuid) RETURNS SETOF public.flashcards`** — `plpgsql`, `STABLE`, `SECURITY DEFINER`, same IDOR guard/ACL convention as every RPC in this section. Mirrors `get_my_cards`' own-card-requires-enrollment predicate exactly, filtered to `my_cards_enrollment.status = 'removed'` instead of `'active'`. Same live visibility re-check as `get_my_cards` (a removed card that's since gone private/unfriended won't show up here either). Justified as a new RPC because no existing path exposed removed-status enrollment to the client at all — `get_my_cards` only ever returns active enrollment, and `my_cards_enrollment` itself has zero client grants. Lazy-loaded by `MyCards.jsx` only on first History tab open, so the default My Study page load pays zero extra cost. `docs/database/sprint8.7.10/13_FUNCTIONS_get_removed_my_cards.sql`.

**"Remove from My Study" is now universal** (own or external) — the pre-Scope-A restriction blocking Remove on own content no longer applies, since own content is enrollment-based too under D-32. Removing only ends the study relationship (`my_cards_enrollment.status → 'removed'`); it never touches `flashcards` — deleting content remains a My Contributions-only action.

**Files:** `docs/database/sprint8.7.10/00` (Step 0 diagnostic) through `11b` (`add_batch_to_my_cards` hotfix) — `01_DATA`/`08_CLEANUP` (migration + correction), `02_FUNCTIONS`/`03_FUNCTIONS` (`get_my_cards` v2, `apply_review` guard), `10_FUNCTIONS`/`11b_HOTFIX` (`add_batch_to_my_cards`), `04`/`05`/`09` (test/verification files).

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

⏳ **Pending drop (SQL prepared 2026-07-02, not yet deployed):** zero frontend `.from('comments')` usage found anywhere in `src/` — no comment creation/read/delete UI exists in the app. Drop SQL: `docs/database/landmines/03_CLEANUP_drop_comments_table.sql`. Delete this entire §2.11 section once deployed.

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
**Last Updated:** 15/09/2026 (Sprint 8.1 — added archived_at, archived_by)
**Columns:** 14

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| name | text | NO | - | Group name |
| description | text | YES | - | Optional description |
| created_by | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| is_batch_group | boolean | NO | false | True = official batch group created by admin; hides Leave/Delete for members. **The canonical batch flag** for D-16 archiving and every admin/report/guard RPC — but `join_group_by_token`'s approval-queue branch (D-15) keys off `group_type = 'batch'` instead (see below); as of Sprint 8.3 both are written together by `create_batch_group`, so they stay 1:1. |
| batch_course | text | YES | NULL | Course level this batch group belongs to (e.g. 'CA Foundation') |
| batch_institution | text | YES | NULL | Institution this batch group belongs to (e.g. 'More Classes Commerce'). Isolates groups per B2B client. |
| invite_token | uuid | YES | gen_random_uuid() | Shareable join link token — used in `/join/:token` public URL |
| group_type | text | NO | 'custom' | CHECK: 'batch' \| 'system_course' \| 'custom'. 'batch' = official B2B group; 'system_course' = linked to user's enrolled course; 'custom' = free-form group. **Not the canonical batch flag** (see `is_batch_group` above) — but load-bearing anyway: `join_group_by_token`'s D-15 approval-queue branch (`IF v_group_type = 'batch' AND v_caller_role = 'student'`) and `GroupJoin.jsx`'s "Request to Join" copy both key off this column, not `is_batch_group`. **Sprint 8.1 pre-flight flagged `create_batch_group` never set this column** but judged it "orthogonal to archiving" and left it — the real consequence went undetected until Sprint 8.3: every batch group created through the live function since then had `group_type='custom'`, so the D-15 approval gate silently never fired for it (any caller, student or staff, joined instantly active). Fixed Sprint 8.3 — `create_batch_group` now sets `group_type='batch'` explicitly alongside `is_batch_group=true`. See `docs/tracking/bugs.md` Sprint 8.3. |
| linked_course | text | YES | NULL | For group_type='system_course': the course level the group is linked to (e.g. 'CA Inter') |
| created_at | timestamptz | NO | NOW() | When created |
| updated_at | timestamptz | NO | NOW() | When last updated |
| archived_at | timestamptz | YES | NULL | **Sprint 8.1 (D-16).** NULL = active. Batch groups only. Set/cleared exclusively by `archive_batch_group`/`restore_batch_group` — RLS blocks direct client writes to this column (`sg_update_creator` narrowed to `is_batch_group = false`). |
| archived_by | uuid | YES | NULL | **Sprint 8.1 (D-16).** FK to profiles.id, ON DELETE SET NULL. Admin who archived; cleared on restore. |

**Batch group isolation:** `batch_course` + `batch_institution` together uniquely identify a batch. Membership is never auto-enrolled from these fields — `create_batch_group` (Sprint 8.0/D-15) creates only the group row; every membership change is an explicit action (invite-link self-request, admin direct-add, approve/reject). See D-15/D-16 in blueprint.md.

**Join links:** Any group (batch or personal) can be joined via `/join/:invite_token`. `get_group_preview` and `join_group_by_token` RPCs both work for all group types — the old `is_batch_group = false` filter has been removed. **Sprint 8.1:** an archived batch's link shows "This batch has ended" — no join/request action.

**Key Indexes:** created_by, created_at, `archived_at WHERE is_batch_group = true` (Sprint 8.1)
**RLS Policies:** Members can read (`sg_select_member`). Creator can update/delete **only non-batch groups** (`sg_update_creator`/`sg_delete_creator`, both narrowed to `is_batch_group = false` in Sprint 8.1 — previously had no batch clause at all, a real bypass: the creating admin could delete a batch group or write `archived_at` directly). Authenticated can insert own (`sg_insert`).

---

### 2.15 study_group_members ⭐ UPDATED

**Purpose:** Group membership with roles (admin/member) and invitation status
**Created:** February 6, 2026
**Updated:** 15/09/2026 (Sprint 8.1 — added 'closed' status, closed_at, closed_reason)
**Columns:** 9

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| group_id | uuid | NO | - | FK to study_groups.id, ON DELETE CASCADE |
| user_id | uuid | NO | - | FK to profiles.id, ON DELETE CASCADE |
| role | text | NO | 'member' | CHECK: admin or member |
| joined_at | timestamptz | NO | NOW() | When joined (updated to NOW() on accept) |
| status | text | NO | 'active' | CHECK: 'invited', 'active', 'requested', or 'closed'. Default 'active' for backward compat. **'requested' added Sprint 8.0** — a student's own self-request via a batch invite link, awaiting admin approval (opposite direction from 'invited'). **'closed' added Sprint 8.1** — an outstanding 'requested'/'invited' row closed out by `archive_batch_group`, not deleted; `join_group_by_token` reactivates a 'closed' row back to 'requested' on an explicit re-request after restore, preserving the prior closure as history. |
| invited_by | uuid | YES | NULL | FK to profiles.id, ON DELETE SET NULL. Who sent the invitation. |
| closed_at | timestamptz | YES | NULL | **Sprint 8.1.** Set when status transitions to 'closed'. |
| closed_reason | text | YES | NULL | **Sprint 8.1.** e.g. `'batch_archived'`. |

**UNIQUE Constraint:** `UNIQUE(group_id, user_id)` - prevents duplicate membership
**Key Indexes:** group_id, user_id, role, status
**RLS Policies:** Members read own groups (`sgm_select_own`). Group admins insert (`sgm_insert_admin` — **Sprint 8.1:** now also excludes any group with `archived_at IS NOT NULL`, closing a direct-add bypass past `enroll_user_in_batch_group`'s own guard). User can delete self, or a group admin can delete any member (`sgm_delete`, unchanged — member removal is not blocked by archiving).

---

### 2.16a batch_group_archives ⭐ NEW (Sprint 8.1)

**Purpose:** Frozen report/roster snapshot captured at the moment a batch group is archived — `get_batch_group_member_stats` computes everything live relative to `CURRENT_DATE`, so a snapshot is the only way an archived batch's report can stop following new student activity.
**Created:** 15/09/2026
**Columns:** 6

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | uuid | NO | gen_random_uuid() | Primary key |
| group_id | uuid | NO | - | FK to study_groups.id, ON DELETE CASCADE |
| archived_at | timestamptz | NO | - | Matches `study_groups.archived_at` at the moment of this archive event — used to resolve the *current* snapshot after a restore-then-re-archive cycle |
| archived_by | uuid | YES | NULL | FK to profiles.id, ON DELETE SET NULL |
| report | jsonb | NO | - | `{ group: {name, description, batch_course, batch_institution}, member_count, members: [...one row per active member, same shape as get_batch_group_member_stats] }` |
| created_at | timestamptz | NO | NOW() | |

**UNIQUE Constraint:** `UNIQUE(group_id, archived_at)` — one row per archive event. A restore-then-re-archive cycle adds a new row rather than overwriting; earlier snapshots are retained as historical records (no history-browser UI built this sprint, just the data).
**RLS Policies:** Enabled, **zero client-facing policies** — no direct table access at all. All reads go through `get_batch_group_archive(p_group_id)`, gated identically to `get_batch_group_member_stats` (professor/admin/super_admin only).

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
| `source` | text | NOT NULL, CHECK IN ('manual', 'study_mode', 'practice_mode') — widened Sprint 8.7.8c (D-28), see below |
| `category` | text | NULLABLE, CHECK IN ('reading', 'writing_practice', 'lecture_viewing', 'paper_solving', 'mock_test') or NULL. Sprint 8.5 (D-18). Applies only to `source = 'manual'` rows — chosen by the student at stop/log time, required for a manual log to complete. No default, no backfill: every row logged before Sprint 8.5 has `category IS NULL`. `get_study_time_stats` does not reference this column (confirmed additive via `pg_get_functiondef` before adding). |
| `created_at` | timestamptz | DEFAULT now() |

**RLS:** Enabled. INSERT and SELECT for own rows only (`auth.uid() = user_id`). No UPDATE or DELETE — sessions are immutable (live-confirmed 16/09/2026: no RLS UPDATE policy, no function anywhere references this table with an UPDATE, no trigger attached to the table itself — `docs/database/sprint8.5/03_DIAGNOSTIC_confirm_study_sessions_immutable.sql`).

**Constraint — `study_sessions_manual_requires_category` (Sprint 8.5, D-18 addendum):** `CHECK (source <> 'manual' OR category IS NOT NULL) NOT VALID`. Added after a quality-auditor review found the frontend-only "category is required" rule was a DB integrity gap — nothing stopped a future write path from inserting `source='manual', category=NULL`. `NOT VALID` enforces this on every future INSERT (and UPDATE, though none exist) without validating pre-existing rows, so no backfill and no rewrite of history. Live-verified: a `NULL`-category manual insert is rejected (`23514`), a valid categorized one still succeeds, and pre-existing historical `NULL`-category rows read back untouched.

**Constraint — `study_sessions_duration_floor` (Sprint 8.6a, re-scoped Sprint 8.7.7 / D-25, ✅ deployed & test-verified 21/09/2026):** now `CHECK (source <> 'manual' OR duration_seconds >= 600) NOT VALID`. The 10-minute floor applies to offline/manual sessions only; in-app RevisOp study (`source = 'study_mode'`) has no minimum and records its real duration (still subject to `duration_seconds > 0`). The original 8.6a version had no `source` clause and rejected every in-app session under 600s (400 / 23514, proven live 21/09/2026). `NOT VALID` = enforced on new INSERT/UPDATE, existing rows never re-validated (245 pre-existing rows under 600s untouched: 34 manual, 211 study_mode). Files: `docs/database/sprint8.7.7/03–06`.

**Constraint — `study_sessions_source_check` widened to add `'practice_mode'` (Sprint 8.7.8c / D-28, ✅ deployed & live-verified 23/09/2026):** `CHECK (source = ANY (ARRAY['manual','study_mode','practice_mode']))`. Sprint 8.7.8c's Step 0 initially (incorrectly) concluded `source` had no value-enum CHECK — this was wrong, caught live when Practice Mode's first study-time insert failed with `23514`. Purely additive widening (no existing row touched; 433 `manual` + 245 `study_mode` rows confirmed untouched before the change). `practice_mode` automatically inherits the same no-minimum treatment as `study_mode` from the duration-floor CHECK above (it only singles out `source='manual'`), so no further change was needed there. Files: `docs/database/sprint8.7.8c/00` (diagnostic), `04` (schema), `05` (rollback), `06` (live verification).

**Index:** `idx_study_sessions_user_date` on `(user_id, session_date)` — optimises the stats RPC.

**Design decision — no incomplete rows:** The single INSERT pattern means the DB stores only sessions that actually completed. Abandoned sessions are recovered client-side via localStorage on next app load (< 4h recovery prompt, ≥ 4h silent discard). Sprint 8.5 added a second, distinct in-flight state: a session whose duration is finalized (Stop tapped, or a recovery choice made) but whose required `category` hasn't been chosen yet — held client-side as `pendingLog` in `StudyTimerContext.jsx`, persisted to its own `revisop_manual_timer_pending_log` localStorage key so a reload mid-picker doesn't lose it, and never written to `study_sessions` until `confirmCategory()` succeeds.

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
**Security:** SECURITY DEFINER. Caller must be authenticated (`IF auth.uid() IS NULL THEN RAISE`). Students only. Unquoted `SET search_path TO public, extensions`; `STABLE`; `REVOKE … FROM PUBLIC, anon` + `GRANT EXECUTE … TO authenticated`.
**Follow-graph join (audited 07/09/2026):** directional. `cohort` CTE = `SELECT auth.uid() UNION SELECT f.followee_id FROM public.follows f WHERE f.follower_id = auth.uid()` — the caller plus every user the caller **follows**. Table `public.follows`, predicate `follower_id = auth.uid()`, projects `followee_id`. **Not** `friendships`, and **no** reciprocal `AND EXISTS (reverse follow)` clause — that mutual semantic belongs to `get_friends_leaderboard`, not here.
**Population filter (audited):** `JOIN profiles p ON p.id = c.uid AND p.role = 'student'` — students only, applied to the caller row too (a non-student caller gets an empty board). No course / `account_type` filter.
**Result window (audited):** `DENSE_RANK() OVER (ORDER BY reviews_this_week DESC, study_time_this_week_seconds DESC)` computed over the **full** cohort, then `WHERE rnk <= 20 OR uid = auth.uid()` → N = 20, caller always included regardless of rank, caller's rank exact (not an approximation). `is_self = (uid = auth.uid())`, true on exactly one row. `ORDER BY rnk, full_name`.
**Week boundary:** `date_trunc('week', CURRENT_DATE)::date` (Monday, server UTC), `created_at >= start`. Both weekly stats `COALESCE(…, 0)`; reviews counted on `reviews.created_at`, study time = `SUM(study_sessions.duration_seconds)`.
**Caller:** `LeaderboardWidget.jsx` (Following tab). Fetches lazily on first tab click. Maps `row.rank` / `row.user_id` / `row.is_self` / `row.full_name` / `row.reviews_this_week` / `row.study_time_this_week_seconds`.

**Sprint 6.5 [FIX] + Task 6.5-D audit — RESOLVED, faithful.** The pre-6.5 live body threw Postgres `42702` `column reference "rank" is ambiguous` (the `RETURNS TABLE (rank …)` OUT column shadowing a body-level `DENSE_RANK() … AS rank`) → the Following tab 400'd. Fixed **in place, no signature change** (`02_FUNCTIONS`, deployed 07/09/2026): `#variable_conflict use_column` + the window result aliased `rnk` (never `rank`) + every reference table-qualified. `03_TEST` 9/9 PASS. The 6.5 thread replaced the whole body with a reconstruction (01_DIAGNOSTIC's live-body capture was lost before 02 overwrote it); the **original body is unrecoverable from git** (Sprint 3.5 ran the `CREATE` directly in Supabase — no `.sql` ever committed). Task 6.5-D (`04_AUDIT_current_definition.sql`, 07/09/2026): the current live body was captured via `pg_get_functiondef` and is **byte-identical to `02_FUNCTIONS`**, then diffed against the Sprint 3.5 behavioural contract in this doc's own git history (@ commit `071395d`): **follow-join, population filter and result window all MATCH** — the three specifics above are the audited-confirmed behaviour. `04_AUDIT_membership_test.sql` (a live caller-∪-followed-students set-equality assertion) was **run 07/09/2026 — 5/5 PASS** on account `f9377860…` (the richest available; live follow graph is sparse — 6 rows, max 1 followed-student per student): RPC `user_id` set == caller ∪ followed-students exactly, one `is_self`, rank by `reviews_this_week DESC`. No `[FIX]` shipped — no divergence found. Finding 2 fully closed. `get_friends_leaderboard` was never affected (its body never collides on `rank`). SQL: `docs/database/sprint6.5/01_DIAGNOSTIC` · `02_FUNCTIONS` · `03_TEST` · `04_AUDIT_current_definition` · `04_AUDIT_membership_test`.

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
- **Sprint 8.1:** unchanged — reused as-is by `archive_batch_group` to build its snapshot (called internally; `auth.uid()` still reflects the real caller, so the two security gates above still apply and pass since only admins can call `archive_batch_group`).

---

## archive_batch_group / restore_batch_group / get_batch_group_archive (Sprint 8.1, D-16)

```sql
archive_batch_group(p_group_id uuid) RETURNS jsonb  -- {group_id, archived_at, already_archived}
restore_batch_group(p_group_id uuid) RETURNS jsonb  -- {group_id, archived_at, already_active}
get_batch_group_archive(p_group_id uuid) RETURNS jsonb  -- {archived_at, report}
```
All three `SECURITY DEFINER`, `SET search_path TO public, extensions`.

- **`archive_batch_group`** — `is_admin()` guard. Locks the `study_groups` row (`FOR UPDATE`) first — the same convention every enrollment-adjacent function below follows, so a concurrent request/invite/approve/direct-add either commits before this lock is acquired (honored) or blocks until this transaction commits and then sees `archived_at` set (refused). Raises `'Group not found'` / `'Not a batch group'` as appropriate. **Idempotent:** already-archived returns `{already_archived: true}` with the original timestamp — no snapshot replacement. On first archive, in one transaction: builds the snapshot jsonb (group metadata + `get_batch_group_member_stats` rows), inserts it into `batch_group_archives`, sets `archived_at`/`archived_by`, then updates `study_group_members` to `status='closed', closed_at=<same timestamp>, closed_reason='batch_archived'` for every row still `'requested'` or `'invited'`. If the snapshot build fails, the whole call raises and the transaction rolls back — no partial state (default plpgsql exception propagation, no special-case handling needed).
- **`restore_batch_group`** — same guard + lock convention. Clears `archived_at`/`archived_by`. Does **not** touch `study_group_members` at all — active memberships stay active, closed rows stay closed (a student must explicitly re-request; `join_group_by_token` handles reactivating a closed row — see below). Idempotent: already-active returns `{already_active: true}`.
- **`get_batch_group_archive`** — gated identically to `get_batch_group_member_stats` (professor/admin/super_admin). Resolves the snapshot by matching `batch_group_archives.archived_at` to the batch's *current* `study_groups.archived_at`, so a restore-then-re-archive cycle always returns the latest snapshot. Raises `'Batch is not archived'` if called on an active batch.
- **Explicit grants:** `GRANT EXECUTE TO authenticated`, `REVOKE ALL FROM PUBLIC, anon` on all three (project convention — unlike several of the Sprint 8.0 D-15 functions, which rely on default/broader grants; not changed this sprint).

### Archived-state guards added to existing functions (Sprint 8.1, `CREATE OR REPLACE`, additive diffs only)
- **`join_group_by_token`** — locks the resolved group row first; raises `'This batch has ended'` if `archived_at` is set, before any status change. The `'requested'`-status `INSERT ... ON CONFLICT` now does `DO UPDATE SET status='requested', joined_at=NOW() WHERE study_group_members.status = 'closed'` (reactivates a closed row) instead of always `DO NOTHING` — still a no-op for an existing active/requested/invited row.
- **`enroll_user_in_batch_group`** (admin direct-add) — locks the group row; raises `'This batch has been archived'` if archived.
- **`approve_batch_join_request` / `reject_batch_join_request`** — resolve the request's group, lock that row, raise `'This batch has been archived'` if archived (mostly moot since archiving already closes outstanding requests, but keeps the same lock convention as every other path).
- **`get_group_preview`** — additive `is_batch_group`/`archived_at` fields; `stats` returns `NULL` (not the live aggregate) when the batch is archived.
- **`get_admin_batch_groups`** — additive `archived_at` column, still returns both active and archived rows.
- **`get_my_batch_groups`** — added `AND archived_at IS NULL` to both role branches (excludes archived from the monitoring list).
- **`get_group_detail`** — additive `archived_at` on the returned group object.
- **`leave_group`** — the last-active-member cascade-delete of the group row is now `IF v_member_count = 1 AND NOT v_is_batch` (previously unconditional) — a batch group's lifecycle is exclusively archive/restore now; ordinary-group behavior unchanged.

---

## get_study_time_stats (Sprint 3.1, split by source Sprint 7.3-C)

```sql
get_study_time_stats(p_user_id uuid, p_local_date date)
RETURNS TABLE (
  today_seconds bigint, week_seconds bigint, today_sessions bigint, week_sessions bigint,
  today_seconds_in_app bigint, today_seconds_offline bigint,
  week_seconds_in_app bigint, week_seconds_offline bigint
)
SECURITY DEFINER
```

- `p_local_date` — today's date in the user's local timezone, passed from frontend as `new Date().toLocaleDateString('en-CA')`
- Week bounds: Monday–Sunday of the ISO week containing `p_local_date` (Postgres `date_trunc('week', ...)`)
- Filters strictly by `p_user_id` — no cross-user access
- Called by authenticated users for their own stats only
- Sprint 7.3-C: the 4 new columns split the existing combined totals by `study_sessions.source` — `_in_app` = `source = 'study_mode'` (StudyMode.jsx), `_offline` = `source = 'manual'` (StudyTimerWidget/StudyTimerContext). The 4 original columns/values are unchanged; the in_app+offline pair always sums back to the combined column for the same window. Deployed via DROP+CREATE (adding output columns to a `RETURNS TABLE` function isn't possible with a plain `CREATE OR REPLACE`) — see `docs/database/sprint7.3/02_FUNCTIONS_split_study_time_stats_by_source.sql`; grants re-applied (`authenticated` only, same as before)

---

## Sprint 6.3 — dashboard reskin RPCs (✅ deployed & verified 05/09/2026 — `docs/database/sprint6.3/01_FUNCTIONS`, `02_TEST` 12/12 PASS)

All three: `LANGUAGE plpgsql`, `STABLE`, `SECURITY DEFINER`, `SET search_path TO public, extensions` (unquoted), established L5 IDOR guard (`p_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin()` → `RAISE EXCEPTION`), `REVOKE ALL FROM PUBLIC` + `REVOKE ALL FROM anon` + `GRANT EXECUTE TO authenticated`, `NOTIFY pgrst, 'reload schema'`. Verified by `docs/database/sprint6.3/02_TEST` (BEGIN/ROLLBACK). Consumed by `src/pages/Dashboard.jsx`.

```sql
get_due_forecast_buckets(p_user_id uuid)
RETURNS TABLE (bucket_index integer, bucket_label text, scheduled_count integer)
```
- Guard: **self-or-admin.** Always returns exactly **8 rows** (0-count lanes included), ordered by `bucket_index` 0..7.
- Lanes keyed to `REVISOP_BUCKETS` / `BUCKET_DAYS` in `src/lib/revisop-tokens.js`: `Today · 1d · 3d · 6d · 2w · 1mo · 3mo · 6mo+` at centre-day `[0,1,3,6,14,30,90,180]`. Assignment is nearest-centre via a `CASE` on `(next_review_date - today)`; overdue / today fold into lane 0; anything ≥ 135 days out lands in lane 7.
- Row-inclusion predicate is identical to `get_due_forecast` (`reviews.status='active'` · `flashcards.question_type <> 'concept_card'` · course filter `course_level IS NULL OR target_course IS NULL OR target_course = course_level` · visibility guard own/public/accepted-friend · `skip_until IS NULL OR skip_until <= today`) — only the date-threshold filter is replaced by bucketing. *today* = `(now() AT TIME ZONE COALESCE(profiles.timezone,'Asia/Kolkata'))::date`.
- Frontend folds the 8 rows to `number[8]` for `<ForwardLedgerMacro>` (student "Forward load" section).

```sql
get_educator_accuracy_by_qtype(p_professor_id uuid, p_course_level text)
RETURNS TABLE (question_type text, total_graded integer, hits integer, accuracy_pct numeric)
```
- Guard: **professor-or-admin** (same idiom as the `get_professor_*` analytics family).
- `prof_cards` = `flashcards WHERE user_id = p_professor_id AND target_course = p_course_level AND question_type <> 'concept_card'`, joined to `reviews`.
- **`total_graded`** = `COUNT(*) FILTER (WHERE quality > 0)` (skip/suspend rows `quality = 0` excluded). **`hits`** = `COUNT(*) FILTER (WHERE quality IN (3,5))` (SRS ladder mapping: Medium/Easy = hit, Hard = miss). **`accuracy_pct`** = `ROUND(100.0 * hits / NULLIF(total_graded,0), 1)`.
- One row per `question_type` with `HAVING total_graded > 0`, ordered by `total_graded DESC`.
- Powers the educator dashboard "Accuracy by question type" widget.

```sql
get_educator_cohort_forecast_buckets(p_professor_id uuid, p_course_level text)
RETURNS TABLE (bucket_index integer, bucket_label text, scheduled_count integer)
```
- Guard: **professor-or-admin.** Same 8-lane shape / centre-day bucketing as `get_due_forecast_buckets`, but summed across **every student** with an active review on one of this educator's `target_course` cards (`question_type <> 'concept_card'`, `skip_until` not in the future). No per-viewer visibility guard — an educator's cohort content is their own. *today* = `CURRENT_DATE`. Powers the educator "Cohort forward load" ledger.

---

## Sprint 7.4 — review_events, apply_review, two-measure analytics semantics (✅ deployed & verified 13/09/2026 — `docs/database/sprint7.4/`, `04_TEST` 29/29 real assertions PASS)

Architectural de-risk gate for the question-type epic — see `review_events` (2.4A) and blueprint.md D-11. No question-type rendering changed; StudyMode stays pure front/back.

```sql
apply_review(
  p_user_id uuid, p_flashcard_id uuid, p_rating text,
  p_is_correct boolean DEFAULT NULL, p_source text DEFAULT NULL,
  p_selected_answer jsonb DEFAULT NULL  -- Sprint 8.6c, ✅ deployed & verified live 17/09/2026
)
RETURNS TABLE (new_rung smallint, next_review_date date, new_status text, interval_days integer)
```
- **The write SSOT for review scheduling**, superseding `submit_review`. `LANGUAGE plpgsql`, `SECURITY DEFINER`, `SET search_path TO public, extensions` (unquoted), same L5 IDOR idiom as `submit_review` (`auth.uid() IS NULL` → RAISE; `p_user_id IS DISTINCT FROM auth.uid() AND NOT is_admin()` → RAISE). `GRANT EXECUTE TO authenticated` only.
- Body is `submit_review`'s live body **verbatim** (confirmed byte-identical via introspection before extending — same rules fetch, same today-in-tz calc, same quality/easiness mapping, same new-card-vs-existing-card transition branches), plus: captures `f.topic_id` alongside `f.question_type`; computes `v_rung_before` right after the existing defensive rung clamp (`NULL` for a brand-new card, else the clamped pre-transition rung); and, in the **same transaction** as the `reviews` INSERT/UPDATE, inserts one `review_events` row using the same final `v_new_rung`/`v_new_status`/`v_next` variables the transition logic already computed (not duplicated per branch).
- **Sprint 8.6c (17/09/2026, ✅ deployed & verified live):** added exactly one new trailing parameter, `p_selected_answer jsonb DEFAULT NULL`, via `CREATE OR REPLACE` against the exact live 5-parameter signature (confirmed unchanged since Sprint 7.4 by `docs/database/sprint8.6c/00_DIAGNOSTIC_preflight.sql`). **Real deployment gotcha, not just a documented risk:** the plain `CREATE OR REPLACE` did NOT replace the old 5-arg overload in place — it left both live simultaneously (`ERROR 42725: function public.apply_review(...) is not unique`, hit for real when `03_TEST` called the old shape) — same overloaded-RPC/PostgREST-ambiguity class as `get_browsable_decks` v5 (§1.11). Fixed with an explicit `DROP FUNCTION public.apply_review(uuid,uuid,text,boolean,text);` (`02b_HOTFIX_drop_ambiguous_apply_review_overload.sql`), confirmed post-fix via `03_TEST`: exactly one `apply_review` function exists. Threaded straight into the `review_events` INSERT as `selected_answer`. Every pre-existing caller (all 7 other question types' `StudyMode.jsx` calls, `submit_review`'s compat wrapper) is a 5-arg call and is unaffected — the new parameter simply defaults to `NULL`, live-verified.
- Atomic by construction (one function body, one transaction) — proven with a real forced-failure trigger test in `04_TEST`, not just asserted: a `pg_temp` BEFORE INSERT trigger on `review_events` raises mid-call, and the `reviews` write from the same call is confirmed rolled back too (PL/pgSQL's implicit EXCEPTION-block savepoint).
- `p_is_correct` stays NULL until Sprint 7.5's graded question types exist. `p_source`: `'new_card'` | `'review_session'` | `NULL` (preview mode).

```sql
submit_review(p_user_id uuid, p_flashcard_id uuid, p_rating text)
RETURNS TABLE (new_rung smallint, next_review_date date, new_status text, interval_days integer)
```
- **Sprint 7.4: now a thin `LANGUAGE sql` compat wrapper** — `SELECT * FROM apply_review(p_user_id, p_flashcard_id, p_rating, NULL, NULL)`. Kept only so a stale cached client bundle calling the old 3-arg signature during the deploy window keeps working; logs `review_events.is_correct = NULL`. Grants unchanged (`GRANT EXECUTE TO authenticated`). `StudyMode.jsx` no longer calls this — it calls `apply_review` directly.

```sql
get_question_type_performance(p_user_id uuid, p_course_level text DEFAULT NULL)
RETURNS TABLE (
  question_type text, total_cards_available bigint, reviewed_count bigint,
  recall_success_pct numeric, graded_count integer, answer_accuracy_pct numeric
)
```
- Deployed via **DROP + CREATE** (adding + renaming `RETURNS TABLE` columns isn't a plain `CREATE OR REPLACE`, same reasoning as `get_study_queue`/Sprint 7.3's `get_study_time_stats`) — grants re-applied (`authenticated` only).
- `accuracy_pct` renamed **`recall_success_pct`** — computation byte-for-byte unchanged (same `available_cards`/`all_reviews` CTEs, same IDOR guard, same `concept_card` exclusion).
- New: **`graded_count`** = count of this user's `review_events` rows (for cards in `available_cards`) with `is_correct IS NOT NULL`; **`answer_accuracy_pct`** = `NULL` when `graded_count = 0`, else `% is_correct = true`. `review_events` is pre-aggregated into a one-row-per-`flashcard_id` CTE before joining — `review_events` is append-only (many rows per card over time) and joining it directly would have fanned out the existing `recall_success_pct` COUNT()s.
- Powers `Progress.jsx` "Performance by Question Type" (two rows per type: Recall success / Answer accuracy).

```sql
get_educator_accuracy_by_qtype(p_professor_id uuid, p_course_level text)
RETURNS TABLE (
  question_type text, total_graded integer, hits integer,
  recall_success_pct numeric, graded_count integer, answer_accuracy_pct numeric
)
```
- Same DROP+CREATE / rename / two-new-columns treatment as above; `total_graded`/`hits`/`HAVING total_graded > 0` logic (Sprint 6.3) unchanged.
- Here `review_events` is pre-aggregated **by `question_type`** (not by card), since the base query already fans out one row per student-reviewer per card (`prof_cards JOIN reviews`, cohort-wide) — the per-type aggregate is computed independently, then broadcast-joined back via `MAX()` so it isn't inflated by that fan-out.
- Powers `Dashboard.jsx`'s professor "Accuracy by question type" widget.

---

## Sprint 8.7.7 — get_browsable_decks v8, matching_card_count (✅ deployed & test-verified 21/09/2026 — `docs/database/sprint8.7.7/10–13`, D-26)

- **v8** adds ONE trailing return column, `matching_card_count integer`: the number of cards in the deck the VIEWER may see (same visibility predicate as `visible_card_count`) that have `question_type = p_question_type`; equals `card_count` when `p_question_type` is NULL. `card_count` is unchanged (the deck's whole visible total). Inclusion rule, provenance columns, ordering, `SECURITY DEFINER`, `search_path = public, extensions` and ACL unchanged (ACL identical before/after: PUBLIC, postgres, anon, authenticated, service_role EXECUTE).
- **Why:** with a type filter on, Browse summed `card_count`, so counts were deck totals and mixed-type decks were counted under every filter (professor account: 1,225 vs 1,091).
- **Verification:** `12_TEST` T1–T7 all PASS (student viewer, 24 decks, 1,351 hidden private cards excluded; note that viewer's decks are single-type so the mixed-deck case was proven separately on the dev build: nine per-type counts sum to 1,091 = All Types; theory 348 = independent direct count). Rollback: `13` (v7 verbatim).
- **Frontend:** `ReviewFlashcards.jsx` derives `displayCount = matching_card_count ?? card_count` and uses it for every count.

---

## Sprint 7.6 — get_browsable_decks question type filter (✅ deployed & verified live 13/09/2026 — `docs/database/sprint7.6/`, `02_TEST` verified via impersonated real profile)

```sql
get_browsable_decks(p_question_type text DEFAULT NULL)
RETURNS TABLE (
  id uuid, user_id uuid, subject_id uuid, custom_subject text, topic_id uuid, custom_topic text,
  target_course text, visibility text, card_count integer, upvote_count integer, created_at timestamptz,
  author_name text, author_role text, subject_name text, topic_name text
)
```
- **v5.** Adds one additive, nullable parameter to the existing v4 (`docs/database/bugfixes/05_FUNCTIONS_get_browsable_decks_v4_per_viewer_cards.sql`). `NULL` (default) reproduces v4 exactly — every pre-7.6 caller is unaffected. When set, a deck is included only if it has ≥1 card of that `question_type` visible to the viewer (same visibility predicate as the existing per-viewer `card_count` lateral: owner sees own private cards, public visible to all, friends-visibility to accepted friends, admin override, group-shared decks to group members). Narrows which **decks** are returned — does NOT narrow the returned `card_count` (stays whole-deck) and does not affect what a study session serves once a student clicks into a deck.
- **Deployment gotcha (hit live, 13/09/2026):** a plain `CREATE OR REPLACE FUNCTION get_browsable_decks(p_question_type TEXT DEFAULT NULL)` does **not** replace the old zero-arg `get_browsable_decks()` — Postgres treats a changed parameter list (even one added with a `DEFAULT`) as a distinct overload, not a replacement of the old signature. This left both the zero-arg and one-arg versions live simultaneously, and every unparameterized call became ambiguous: `ERROR 42725: function get_browsable_decks() is not unique`. Fixed with an explicit `DROP FUNCTION IF EXISTS get_browsable_decks();` immediately before the `CREATE OR REPLACE` for the new signature. **Applies to any future RPC that adds a parameter to an existing function — `CREATE OR REPLACE` alone is only safe when the parameter list is unchanged.**
- `SECURITY DEFINER` retained, same `auth.uid()` requirement as v4 (raises `Not authenticated` under an unauthenticated caller — including the SQL Editor's default `postgres` role, which has no `auth.uid()`; test accordingly via `SET LOCAL ROLE authenticated` + `request.jwt.claims` impersonation, same technique as `docs/database/sprint7.5/02_TEST_verify_d10_role_gate.sql`).
- Powers `ReviewFlashcards.jsx`'s ("Browse Study Sets" since Sprint 7.6) Question Type filter — options limited to the types with a real authoring path, built from `BROWSABLE_QUESTION_TYPES` in `src/lib/questionTypes.js` (`flashcard`, `mcq` as of 7.6; `true_false`/`correct_incorrect`/`theory`/`test_your_understanding` added Sprint 7.7; `match_the_following` added Sprint 7.8; `test_your_understanding` removed Sprint 7.9 (collapsed into `theory`+`subtype`, D-10); `true_false` removed Sprint 7.9 (merged into `correct_incorrect`, D-14); `concept_card` added Sprint 7.12).

---

## Sprint 7.12 — get_browsable_decks v6, has_concept_card flag (✅ deployed & verified live 14/09/2026 — `docs/database/sprint7.12/`, `02_TEST` — 5/5 PASS)

```sql
get_browsable_decks(p_question_type text DEFAULT NULL)
RETURNS TABLE (
  id uuid, user_id uuid, subject_id uuid, custom_subject text, topic_id uuid, custom_topic text,
  target_course text, visibility text, card_count integer, upvote_count integer, created_at timestamptz,
  author_name text, author_role text, subject_name text, topic_name text,
  has_concept_card boolean
)
```
- **v6.** Adds one additive return column, `has_concept_card`, to v5's signature (`docs/database/sprint7.6/01_FUNCTIONS_get_browsable_decks_v5_question_type_filter.sql`). `true` when the deck has ≥1 `concept_card` row visible to the viewer — computed via `bool_or(fc.question_type = 'concept_card')` inside the SAME visibility-filtered lateral subquery that already computes `card_count` (`visible_card_count`), not a second table scan. Every existing caller that doesn't read the new column sees no behavior change.
- **Return-shape change → DROP+CREATE required**, same lesson as v5's own deployment gotcha (a plain `CREATE OR REPLACE` cannot alter an existing function's return type). Only one overload existed at the time (`p_question_type text` — confirmed via pre-flight `pg_proc` introspection), so no arity-ambiguity risk this time.
- Powers `ReviewFlashcards.jsx`'s ("Browse Study Sets") conditional "Read Concepts" button — rendered only on a deck tile whose row has `has_concept_card=true`, opening `ConceptCardViewer.jsx` (read-only accordion, no grading).

## Sprint 8.7.4 — get_browsable_decks v7, provenance badge columns (D-21 display)

```sql
get_browsable_decks(p_question_type text DEFAULT NULL)
RETURNS TABLE (
  id uuid, user_id uuid, subject_id uuid, custom_subject text, topic_id uuid, custom_topic text,
  target_course text, visibility text, card_count integer, upvote_count integer, created_at timestamptz,
  author_name text, author_role text, subject_name text, topic_name text,
  has_concept_card boolean, provenance_source_type text, provenance_source_name text
)
```
- **v7.** Adds two additive return columns to v6's signature (`docs/database/sprint8.7.4/02_FUNCTIONS_get_browsable_decks_v7_provenance.sql`). Both `NULL` unless every visible card in the deck shares exactly one `batch_id` AND that `batch_id` has a `flashcard_batch_provenance` row — computed via `CASE WHEN count(DISTINCT fc.batch_id) = 1 THEN (array_agg(fc.batch_id))[1] ELSE NULL END` inside the same visibility-filtered lateral that already computes `card_count`/`has_concept_card`, then `LEFT JOIN flashcard_batch_provenance`. **Deliberate design choice:** a deck is a 5-grouping-column bucket, not a batch — it routinely spans many `batch_id`s, so a deck-level badge is only shown when unambiguous (single-batch deck); a multi-batch or legacy deck renders no badge, same "absence = render nothing" rule as everywhere else in D-21, not a new "mixed sources" treatment.
- **Real deployment bug, found live 18/09/2026:** the first deploy used `min(fc.batch_id)` instead of `array_agg()[1]` — Postgres has no default ordering operator class for `uuid`, so `min()`/`max()` over a uuid column raises `42883: function min(uuid) does not exist` at call time. The `DROP FUNCTION`+`CREATE` itself succeeded (no syntax error), so the function existed but every call to `get_browsable_decks()` failed until the operator's live verification run surfaced it. Fixed to `(array_agg(fc.batch_id))[1]` — safe because the surrounding `CASE` already gates on `count(DISTINCT fc.batch_id) = 1`, so every array element is identical. Re-deployed and live-verified correct: 1/20 sampled decks resolved real provenance, 19/20 correctly `NULL`.
- **Cross-user isolation, proven by construction (per auditor request, not just tested):** `sole_batch_id` is computed inside the exact same `LATERAL` subquery, over the exact same `fc` row set, gated by the exact same visibility predicate, as `visible_card_count`. Since the subquery's own `WHERE` clause requires `fc.user_id = fd.user_id` (a deck row belongs to exactly one owner), a different user's batch can never enter the aggregate at all — decks are inherently single-owner in this schema. For a non-owner viewer, the same visibility `OR` chain (public / accepted-friend / admin / group-shared) that filters `visible_card_count` also filters which of that one owner's batches `sole_batch_id` can see — a same-owner private batch invisible to this particular viewer is excluded before `sole_batch_id` ever aggregates over it, so it cannot skew the badge for that viewer. `flashcards.batch_id` is `NOT NULL` (confirmed, column table above), so `count(DISTINCT fc.batch_id)` can never silently drop a row due to a NULL batch_id — the concern that a legacy/untracked card could masquerade as part of a "single-batch" deck does not apply, because no such untracked-batch row can exist. Live-confirmed empirically too: a genuine multi-batch deck (3 real batch_ids, all owned by the same test account) correctly resolved to `NULL`/no badge.
- **Return-shape change → DROP+CREATE required**, same lesson as v5/v6.
- Runs inside this SECURITY DEFINER function (owner `postgres`), so the `LEFT JOIN flashcard_batch_provenance` does **not** depend on the new `authenticated_read_flashcard_batch_provenance` SELECT policy (§2.3A) — that policy is only needed for direct client queries (`MyFlashcards.jsx`, `StudyMode.jsx`, `NoteDetail.jsx`'s linked-flashcards list all query the table directly via `src/lib/provenance.js`'s `fetchBatchProvenanceMap`).
- Powers `ReviewFlashcards.jsx`'s ("Browse Study Sets") deck-tile provenance badge.

## Sprint 8.7.4 — get_browsable_notes v4, provenance passthrough (D-21 display)

```sql
get_browsable_notes()
RETURNS TABLE (
  id uuid, user_id uuid, title text, description text, image_url text, target_course text,
  subject_id uuid, topic_id uuid, custom_subject text, custom_topic text, tags text[],
  visibility text, upvote_count integer, created_at timestamptz,
  author_name text, author_role text, subject_name text, topic_name text,
  content_source_type text, content_source_name text
)
```
- **v4.** Adds `content_source_type`/`content_source_name` straight off the `notes` row (`docs/database/sprint8.7.4/03_FUNCTIONS_get_browsable_notes_v4_provenance.sql`) — no ambiguity/LEFT JOIN needed here, unlike the flashcards side: a note IS its own unit of provenance (row-level, set once at creation by `trg_require_note_provenance`, 8.7.1), not an aggregation of many creation events.
- **Also fixed while reproducing this function for the return-type change:** v3 (`docs/database/study-groups/30_FUNCTION_get_browsable_notes_v3.sql`) had **no `SET search_path` clause at all** — every other `SECURITY DEFINER` function in this codebase pins it, per the L3 `17c` outage lesson (§1.11). v4 adds `SET search_path TO public, extensions`, closing that gap.
- Powers `BrowseNotes.jsx`'s note-card provenance badge.

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

#### Policy: "Users can view public notes"
- **Command:** SELECT
- **Roles:** public (live policy targets `TO public`, not `authenticated` — anon reads public content directly)
- **Condition:** `visibility = 'public'` — ✅ **DEPLOYED 03/07/2026** (Landmine L2 Stage A, `ALTER POLICY` in `docs/database/landmines/10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql`). Was `is_public = true`; `is_public` since dropped (Stage B).
- **Purpose:** All users can view public notes
- **Why Needed:** Browse Notes page, community learning

#### Policy: users_view_friends_notes ⏳ NEW (not yet deployed)
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `visibility = 'friends' AND EXISTS (accepted friendship with notes.user_id, either direction)`
- **Purpose:** Friends-tier content is readable by accepted friends, not just the owner
- **Why Needed:** The `friends` visibility tier has existed on this column since Jan 2026 but was never enforced in RLS — this is the first policy that actually grants friends-tier access. See blueprint.md §1.11 landmine #2.

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
- **Provenance enforcement (Sprint 8.7.1, 18/09/2026, ✅ deployed & verified live) — trigger, not RLS/CHECK:** `notes.content_source_type`/`content_source_name` columns added (both nullable at the column level — legacy rows stay NULL forever, no backfill). A new `BEFORE INSERT` trigger, `trg_require_note_provenance` → `fn_require_note_provenance()`, rejects any INSERT where either is NULL/blank. Deliberately a trigger and not a `CHECK`: a `CHECK` re-evaluates on every UPDATE too, so one strict enough to force provenance on insert would also block a harmless edit to a pre-8.7.1 legacy note (still NULL), and one loose enough to permit that edit would equally permit `NULL` provenance on a brand-new insert. `BEFORE INSERT` is the only mechanism that distinguishes "new row" from "editing an old one." `NoteUpload.jsx` is NOT migrated to populate these columns this sprint (explicit non-goal) — direct note creation will start failing the same way flashcards did until a later sprint migrates it.
- **SQL:** `docs/database/sprint8.7/01_SCHEMA_provenance_foundation.sql`. Test: `docs/database/sprint8.7/03_TEST_verify_sprint8.7.1.sql` (T3: missing-provenance insert rejected; T4/T4b: legacy NULL-provenance note stays editable, provenance stays NULL after the edit — trigger correctly does not fire on UPDATE; 18/18 PASS live 18/09/2026).

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

#### Policy: "Users can view public flashcards"
- **Command:** SELECT
- **Roles:** public (live policy targets `TO public`, not `authenticated`)
- **Condition:** `visibility = 'public'` — ✅ **DEPLOYED 03/07/2026** (Landmine L2 Stage A, `ALTER POLICY` in `docs/database/landmines/10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql`). Was `is_public = true OR visibility = 'public'`; `is_public` since dropped (Stage B).
- **Purpose:** All users can view public flashcards
- **Why Needed:** Review Flashcards page (browse professor/peer content)

#### Policy: users_view_friends_flashcards ⏳ NEW (not yet deployed)
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `visibility = 'friends' AND EXISTS (accepted friendship with flashcards.user_id, either direction)`
- **Purpose:** Friends-tier content is readable by accepted friends, not just the owner
- **Why Needed:** Same gap as notes — `StudyMode.jsx` has queried with `visibility.eq.friends` since the visibility system shipped, but RLS never actually granted that access. See blueprint.md §1.11 landmine #2.

#### Policy: users_view_own_flashcards
- **Command:** SELECT
- **Roles:** authenticated
- **Condition:** `user_id = auth.uid()`
- **Purpose:** Users can view their own flashcards
- **Why Needed:** My Flashcards page

#### Policy: users_insert_flashcards (live name: `"Users can insert their own flashcards"` — confirmed via Sprint 8.7.1 Step 0 diagnostic; this doc's alias predates the live rename and was never corrected until now)
- **Command:** INSERT
- **Roles:** authenticated
- **Condition (Sprint 8.7.1, 18/09/2026, ✅ deployed & verified live):** `user_id = auth.uid() AND EXISTS (SELECT 1 FROM flashcard_batch_provenance p WHERE p.batch_id = flashcards.batch_id)` — extended via `ALTER POLICY`, original `user_id = auth.uid()` condition preserved unchanged inside the AND. See §"flashcard_batch_provenance" below for why. The separate RESTRICTIVE `flashcards_gate_verdict_types_insert` policy still ANDs with this one unchanged.
- **⚠️ Breaking change, intentional, RESOLVED 8.7.2:** as of this policy change (8.7.1), a direct client `INSERT` into `flashcards` requires a pre-existing provenance row for that `batch_id` — impossible for any write path that inserts directly. Both `FlashcardCreate.jsx` and `BulkUploadFlashcards.jsx` no longer insert directly as of Sprint 8.7.2 — both call `create_flashcard_batches()` (§4.0b), which creates the provenance row and the flashcard rows atomically in one call. `notes` (a separate mechanism, unaffected by this policy) remain on `NoteUpload.jsx`'s pre-existing path, deferred to Sprint 8.7.3.
- **Purpose:** Users can create flashcards, and (as of 8.7.1) only as part of a provenanced batch
- **Why Needed:** Create Flashcard, Bulk Upload; provenance requirement added for D-21 (content-source tagging, blueprint.md §3.1)
- **SQL:** `docs/database/sprint8.7/01_SCHEMA_provenance_foundation.sql`. Test: `docs/database/sprint8.7/03_TEST_verify_sprint8.7.1.sql` (T1, T5–T7 exercise this condition; 18/18 PASS live 18/09/2026).

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

#### Policy: flashcards_gate_verdict_types_insert / flashcards_gate_verdict_types_update ✅ NEW (Sprint 7.5 D-10, deployed & verified live 13/09/2026)
- **Command:** INSERT / UPDATE (mirrored pair)
- **Roles:** authenticated
- **Type:** RESTRICTIVE (ANDs with `users_insert_flashcards`/`users_update_own_flashcards` above, rather than replacing them)
- **Condition (as of Sprint 7.9, 14/09/2026, after both item 1-3's and item 4's migrations):** `question_type NOT IN ('mcq','correct_incorrect','case_study_mcq','match_the_following','fitb') OR is_professor_or_admin()` — `'fitb'`, not `'fill_in_the_blanks'` (00_DIAGNOSTIC caught the live `chk_flashcards_question_type` CHECK using the shorter name; the wrong string would have left that type completely ungated since a row NOT IN the list passes unconditionally). `integrated_case` (D-12) and `true_false` (D-14) were both in this IN-list through Sprint 7.8; **Sprint 7.9 dropped both**, in two separate `ALTER POLICY ... WITH CHECK (...)` statements (`docs/database/sprint7.9/{01_SCHEMA_sprint7.9_hygiene,04_SCHEMA_true_false_removal}.sql`) — cosmetic in both cases, since dropping the value from `chk_flashcards_question_type` in the same migration already made it uninsertable regardless. Re-verified after each `ALTER POLICY` that the surviving list still correctly gates (student `mcq`/`correct_incorrect` insert rejected, professor's succeeds) — an `ALTER POLICY` rewrites the whole `WITH CHECK` expression, not just the changed substring, so this needed re-checking both times (`02_TEST_verify_sprint7.9.sql` 17/17 PASS; `05_TEST_verify_true_false_removal.sql` 13/13 PASS).
- **Unchanged by Sprint 7.7:** `true_false`/`correct_incorrect` were already in this IN-list from Sprint 7.5 (the policy always covered all verdict-bearing types at once, even before any of them had a real authoring UI) — 7.7 built the authoring/bulk-upload surfaces for two of them, this policy needed zero changes. Regression-confirmed in `docs/database/sprint7.7/02_TEST_verify_new_question_types.sql`.
- **Purpose:** Only professor/admin/super_admin may author or edit a row into one of the 5 verdict-bearing question types (7 through Sprint 7.8, before `integrated_case`'s and `true_false`'s Sprint 7.9 removals). Free-recall types (flashcard/theory/concept_card) unaffected. The UPDATE mirror prevents a student inserting as `'flashcard'` then editing `question_type` to `'mcq'` afterward.
- **Why Needed:** D-10 (blueprint.md §3.1) — a bad `correct_answer` under the Phase 7 hybrid grading model doesn't just mislabel a review, it actively corrects a competent student's SRS state backward; a review queue for student-authored graded content doesn't scale against ~3 educators for 150+ students.
- **New helper function:** `is_professor_or_admin()` — `SECURITY DEFINER`, mirrors `is_admin()`'s pattern, `GRANT EXECUTE TO authenticated` only.
- **SQL:** `docs/database/sprint7.5/01_SCHEMA_d10_role_gate.sql`. Test: `docs/database/sprint7.5/02_TEST_verify_d10_role_gate.sql` (impersonates a real student + professor via `SET LOCAL ROLE authenticated` + `request.jwt.claims`, asserts student mcq insert rejected / student flashcard insert unaffected / professor mcq insert succeeds).
- **Sprint 8.6c (17/09/2026, D-20, ✅ deployed & verified live):** `mcq_multi` added to both IN-lists — `question_type NOT IN ('mcq','mcq_multi','correct_incorrect','case_study_mcq','match_the_following','fitb') OR is_professor_or_admin()` (`docs/database/sprint8.6c/01_SCHEMA_add_mcq_multi_type.sql`). Same `ALTER POLICY` mechanism as every prior IN-list change. Live-verified via `03_TEST_verify_sprint8.6c.sql` (real `SET LOCAL ROLE authenticated` impersonation, not just `request.jwt.claims` — see the `apply_review` correction note above for why that distinction matters): professor insert succeeds, student insert genuinely RLS-rejected.

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

### 4.0 get_study_queue(p_user_id uuid) — ✅ Sprint 6.0 (deployed & verified 02/09/2026)

**Purpose:** The single source of truth for the "what's due" spaced-repetition queue. Replaced three duplicated client-side date-math implementations (`Dashboard.jsx` `fetchPersonalStats`, `ReviewSession.jsx` `fetchDueCards`, `StudyMode.jsx` `fetchFlashcards` Step-2).
**Created:** 02/09/2026 (Sprint 6.0) — `docs/database/sprint6/01_FUNCTIONS_get_study_queue.sql` (+ `02_TEST` — 9/9 PASS in Supabase incl. every `[CRITICAL]`).
**Security:** `SECURITY DEFINER`, `STABLE`, `SET search_path TO public, extensions` (unquoted — L3 lesson).
**Grants:** `REVOKE ALL FROM PUBLIC` + `REVOKE ALL FROM anon`; `GRANT EXECUTE TO authenticated`.
**IDOR guard (L5 read idiom):** `IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN RAISE EXCEPTION 'Access denied: cannot read another user''s study queue'` — a NULL session also RAISEs; admins/super_admins may read any user's queue.
**Return Type:** `TABLE(flashcard_id uuid, card_user_id uuid, contributed_by uuid, target_course text, subject_id uuid, subject_name text, topic_id uuid, topic_name text, custom_subject text, custom_topic text, front_text text, front_image_url text, back_text text, back_image_url text, difficulty text, is_verified boolean, question_type text, next_review_date date, skip_until date, last_reviewed_at timestamptz, rung smallint, batch_id uuid, options jsonb, correct_answer text, explanation jsonb, scenario text, subtype text)` — `rung` added by the SRS Ladder Epic; `batch_id` added Sprint 8.7.4 (`docs/database/sprint8.7.4/04_FUNCTIONS_get_study_queue_batch_id.sql`) so `StudyMode.jsx` can resolve a D-21 provenance badge for cards reached via `ReviewSession.jsx`'s due-queue path. **`options`/`correct_answer`/`explanation`/`scenario`/`subtype` added Sprint 8.7.8e** (`docs/database/sprint8.7.8e/01_FUNCTIONS_get_study_queue_payload_parity.sql`, D-30) — payload parity with `get_practice_cards`: `StudyMode.jsx` already reads the first four by name, so any `mcq`/`mcq_multi`/`correct_incorrect`/`case_study_mcq`/`fitb`/`match_the_following` card reaching Review through the normal due-queue path had rendered with no options/scenario/explanation until this fix. `subtype` is carried through for 8.7.9's renderer even though `StudyMode.jsx` doesn't yet consume it. Every addition to this function has been additive, non-breaking for every existing caller — DROP+CREATE required each time (return-shape change), grants re-applied identically.

**What it returns:** one row per flashcard that is **due** for `p_user_id`, where "due" =
- a `reviews` row exists for `(p_user_id, flashcard_id)` AND `reviews.status = 'active'`
- AND `reviews.next_review_date <= today` AND (`reviews.skip_until IS NULL OR reviews.skip_until <= today`)
- where `today = (now() AT TIME ZONE COALESCE(profiles.timezone,'Asia/Kolkata'))::date`
- AND `flashcards.question_type <> 'concept_card'` (concept cards are reference-only, excluded from every review metric)
- AND the **read-time course filter**: `profiles.course_level IS NULL OR flashcards.target_course IS NULL OR flashcards.target_course = profiles.course_level`
- AND a visibility guard mirroring the L2 read RLS (SECURITY DEFINER bypasses RLS): `f.user_id = p_user_id OR f.visibility='public' OR (f.visibility='friends' AND EXISTS accepted friendship)`

Ordered by `subject_name NULLS LAST, custom_subject NULLS LAST, created_at`.

**Never-reviewed ("new") cards are NOT returned** — that is a StudyMode-standalone concern; StudyMode adds new cards for a subject from its own visible-card fetch and uses this RPC only for the due set.

**Course filter is read-time and non-destructive:** the function performs **no writes**. A student who switches `course_level` stops seeing the old course's cards in the queue; switching back restores the previous queue with `next_review_date` values untouched (their previous-course cards remain fully browsable in Library the whole time). Confirmed by `02_TEST` block 9 (reviews row unchanged after call) + blocks 5–6 (course filter on/off).

**Do not reintroduce `vw_study_items`** or any SECURITY DEFINER view — that was an anon-leak surface dropped 02/07/2026 (L1). Authenticated pipeline logic belongs in this guarded RPC.

---

### 4.0b create_flashcard_batches(p_source_type text, p_source_name text, p_batches jsonb, p_creation_channel text) — ✅ Sprint 8.7.1 DB foundation + Sprint 8.7.2 signature change (deployed & verified live 18/09/2026)

**Purpose:** D-21 content provenance (blueprint.md §3.1). Atomically creates one or more flashcard batches (each with its own `batch_id`) sharing one declared content source, plus a `flashcard_batch_provenance` row per `batch_id`. This is the ONLY way to create a flashcard batch with valid provenance — a direct client `INSERT` into `flashcards` requires a pre-existing provenance row for its `batch_id` (see §3.3 `users_insert_flashcards`). As of 8.7.2, this is also the live path both `FlashcardCreate.jsx` and `BulkUploadFlashcards.jsx` call — the direct-insert code they previously used no longer exists in either file.

**Created:** 18/09/2026 — `docs/database/sprint8.7/02_FUNCTIONS_create_flashcard_batches.sql` (+ hotfix `04_HOTFIX_grants.sql`). **Signature changed:** 18/09/2026 — `docs/database/sprint8.7.2/01_FUNCTIONS_creation_channel.sql`, adding `p_creation_channel` and fixing a `scenario` column omission (see below). Test: `03_TEST_verify_sprint8.7.1.sql` (18/18 PASS, pre-8.7.2 signature), `docs/database/sprint8.7.2/02_TEST_verify_signature.sql` (post-8.7.2 signature/grant checks) plus live browser + direct-RPC verification recorded in blueprint.md D-21.

**Migration safety note (8.7.2):** adding a parameter changes the function's identity arguments — Postgres overload identity is by parameter *types*, not names or defaults, so `CREATE OR REPLACE` with a 4th parameter does **not** replace a 3-arg function of the same name, it creates a second overload. The 8.7.2 migration explicitly `DROP FUNCTION IF EXISTS`'d the 3-arg signature before creating the 4-arg one, rather than leaving both live — safe because nothing in production could call the RPC successfully at the time (frontend was still on the broken direct-insert path, i.e. the active outage 8.7.2 fixed). Live-verified post-deploy via a direct PostgREST call with the anon key: the 4-arg signature resolves (denied with `42501 permission denied for function`, i.e. found and correctly grant-checked), the old 3-arg call returns `PGRST202` (schema-cache miss, confirming it's gone from the API surface, not just from `pg_proc`).

**Security:** `SECURITY DEFINER`, owner `postgres`, `SET search_path = pg_catalog, public`.

**⚠️ RLS does not apply to this function at all.** `FORCE ROW LEVEL SECURITY` is not set on `flashcards`/`notes` (confirmed live, Step 0 diagnostic), and the function owner (`postgres`) owns both tables — so as `SECURITY DEFINER` running as table owner, every RLS policy on `flashcards` (including the D-10 verdict-type gate) is invisible to this function. It manually reproduces both guarantees a direct insert would have gotten from RLS:
- `user_id` is derived from `auth.uid()` server-side. A card payload containing `user_id`/`contributed_by`/`creator_id`/`content_creator_id`/`is_verified` is rejected outright (not silently overridden) — proven live by T7b (8.7.1) and re-confirmed live in 8.7.2's direct-RPC atomicity/D-10 probes.
- Any card whose `question_type` is in the D-10 verdict-bearing list (`mcq`, `mcq_multi`, `match_the_following`, `case_study_mcq`, `correct_incorrect`, `fitb`) is rejected unless `is_professor_or_admin()` — proven live by T7 (8.7.1) and again in 8.7.2 (student session directly probed the RPC: `P0001` / `"Only professors/admins may author verdict-bearing question_type \"mcq\""`).

**Grants:** `REVOKE ALL FROM PUBLIC, anon` (both needed explicitly — `anon` had its own default-privileges EXECUTE grant not routed through `PUBLIC`, confirmed live by T8b before the 8.7.1 hotfix, and re-applied to the new 4-arg signature in 8.7.2); `GRANT EXECUTE TO authenticated` only.

**Return Type:** `TABLE(batch_id uuid, card_count integer)` — one row per batch processed. Callers needing only a total card count (e.g. `BulkUploadFlashcards.jsx`'s results panel) sum `card_count` across the returned rows client-side; the RPC does not echo full inserted-row data the way the old `.insert(...).select()` did.

**Input contract (`p_batches`):** `[{ "batch_id": "<uuid>", "cards": [ { "question_type": ..., "front_text": ..., "back_text": ..., "options": ..., "correct_answer": ..., "scenario": ..., "batch_description": ..., ... } ] }, ...]` — mirrors the pre-8.7.2 direct-insert field set (`deck_id`, `note_id`, `discipline_id`, `target_course`, `subject_id`, `topic_id`, `custom_subject`, `custom_topic`, `front_text`, `back_text`, `front_image_url`, `back_image_url`, `tags`, `visibility`, `difficulty`, `batch_description`, `question_type`, `options`, `correct_answer`, `points_to_remember`, `explanation`, `subtype`, `scenario`), minus the server-derived ownership fields above and minus `source` (now a call-level parameter, not a per-card field — see below). **`batch_description` is read per-card** (`c->>'batch_description'` inside the per-batch `INSERT ... SELECT`), not at the batch-object level — a caller that puts it only on the outer `{batch_id, ...}` object rather than on each card silently gets `NULL` for every row (a real bug this project shipped and fixed during 8.7.2's own live verification: both frontend pages' batching step destructured `batch_description` off each card onto the batch object before this was caught by code review, since it reads naturally as "one label per batch" — it is one label per batch semantically, but the RPC still expects it repeated on every card in that batch, same as `p_source_type`/`p_source_name` conceptually apply once per call but `source`/provenance is written once per call while `batch_description` is written per-row). `p_source_type` is `official_body` or `original_creator`; `p_source_name` non-blank. A card-level `batch_id`, if present, must match its enclosing batch's `batch_id` (derived from the batch, never trusted from the card).

**`p_creation_channel` (added 8.7.2):** `'manual' | 'bulk_upload' | 'gemini_import'`, validated inside the function body (Postgres has no column-style `CHECK` for function parameters, so this is an explicit `IF ... RAISE EXCEPTION`, not a declarative constraint). Applies once per RPC call, not per card — every row inserted by that call gets `flashcards.source = p_creation_channel` explicitly, never the column default. `FlashcardCreate.jsx` always passes `'manual'`; `BulkUploadFlashcards.jsx` always passes `'bulk_upload'`; `'gemini_import'` is accepted but not yet sent by any frontend path (reserved). This closes the bug logged in 8.7.1 (`docs/tracking/bugs.md`): pre-8.7.2, `BulkUploadFlashcards.jsx` never set `source` at all, so every row — including bulk-uploaded ones — silently took the `flashcards.source` column default of `'manual'`. Live-confirmed pre-fix: 100% of production `flashcards.source` values were `'manual'` (00_DIAGNOSTIC_pre_restore.sql §5b). Live-confirmed post-fix via a real bulk CSV upload: bulk-created rows show `source='bulk_upload'`.

**`scenario` column (added to the INSERT list in 8.7.2, not part of 8.7.1's original deployed body):** the 8.7.1 version of this function's `INSERT INTO flashcards` column list omitted `scenario` even though it's a real, actively-used column (§2.1, `case_study_mcq`, Sprint 7.10). Found during 8.7.2's Step 0 live diagnostic before either frontend page was migrated — had it shipped unfixed, every `case_study_mcq` card created through the RPC would have silently lost its scenario text. Live-confirmed fixed via a real bulk CSV upload containing a 2-question `case_study_mcq` case: both rows carry the scenario text correctly.

**`deck_id` (unchanged in 8.7.2, contradiction resolved not redesigned):** accepted per-card exactly as in 8.7.1 (`NULLIF(c->>'deck_id', '')::uuid`). Sprint 8.7.2's diagnostic resolved an apparent doc/code contradiction: `deck_id` is NOT "never populated" — it's populated for every manually-created card (`FlashcardCreate.jsx` resolves/creates the deck client-side, then includes `deck_id` on each card) and left null for bulk-uploaded cards (`BulkUploadFlashcards.jsx` has never set it, before or after 8.7.2). Live sample (500 most recent rows): 377/500 populated, 100% match rate against the 5-column-join resolution on a 100-row spot check of the populated ones. `StudyMode.jsx` and `MyFlashcards.jsx` both read `card.deck_id` directly; `StudyMode.jsx` falls back to the 5-column join only when it's null. This is an existing, tolerated inconsistency between the two creation paths, not dead data — the 5-column join fallback (§2.7 `flashcard_decks`) remains the correct general-purpose lookup for any path that doesn't populate `deck_id`.

**Atomicity:** single function invocation = single implicit transaction — any `RAISE EXCEPTION` (validation failure or a table `CHECK`/constraint violation) aborts and rolls back the entire call, including any provenance rows already inserted earlier in the same call. Proven live by T6d/T6e (8.7.1) and re-proven in 8.7.2 via a direct RPC call (bypassing both frontend pages' own client-side validation, which would otherwise catch a malformed row before it ever reached the RPC and so wouldn't actually exercise this guarantee): a 2-batch call with one valid batch and one batch containing a card missing `front_text` was rejected, leaving zero rows in both `flashcards` and `flashcard_batch_provenance` — including from the individually-valid batch.

**One provenance per batch, no overwrite:** `flashcard_batch_provenance.batch_id` is the primary key; the function additionally checks `EXISTS(...)` before insert and raises a clear error rather than hitting a raw unique-violation. Calling the RPC again against an already-provenanced `batch_id` fails — proven live by T5.

**`is_verified` (hotfix, `docs/database/sprint8.7.2/08_HOTFIX_bulk_verified_badge.sql`, same 4-arg signature, `CREATE OR REPLACE` — no identity-argument change):** `is_verified = (p_creation_channel = 'bulk_upload' AND v_is_prof_admin)`, not a hardcoded `false`. Restores pre-8.7.1 `BulkUploadFlashcards.jsx` behavior (`is_verified: isProfessor || isAdmin || isSuperAdmin`) that the original 8.7.1/8.7.2 RPC body silently dropped — found by a `/code-review` pass before shipping, not by the manual test matrix. Still fully server-derived (`v_is_prof_admin` is computed inside the function from `is_professor_or_admin()`, never a caller-supplied value) — does not reopen the privilege-escalation concern this function's SECURITY-CRITICAL comment warns about. `p_creation_channel = 'manual'` rows always get `is_verified = false`, matching pre-8.7.1 manual-creation behavior (which never set it true for any role). Live-verified: professor bulk upload → `is_verified = true`; professor manual `mcq` → `is_verified = false`.

**Non-goals (explicit, Sprint 8.7.2):** no `notes` migration (`NoteUpload.jsx` unaffected, separate mechanism, deferred to 8.7.3 regardless), no provenance read policy/UI display (deferred to 8.7.4), no `content_creator_id` handling (separate revenue-attribution concern, untouched), no D-10 authorization redesign (verdict-type list and professor/admin gate unchanged).

---

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
-- idx_notes_is_public dropped 03/07/2026 with the is_public column (Landmine L2)
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
-- idx_flashcards_is_public dropped 03/07/2026 with the is_public column (Landmine L2)
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
- **✅ Sprint 7.5 (13/09/2026):** the INSERT branch's UPDATE (existing-deck case) now also widens `visibility` in the same statement — private < friends < public, never narrows — when the new flashcard's visibility is more permissive than the deck's stored value. Fixes a real bug: a deck's visibility was previously frozen at whatever its first-ever card had, so a deck created `private` that later gained `public` cards stayed invisible to `get_browsable_decks`/`get_recent_activity_feed` forever, even though the individual cards were correctly public. One-time backfill widened the 4 live decks already desynced (see `bugs.md`). The auto-create (`NOT FOUND`) branch is unchanged — it already sets `visibility = NEW.visibility` correctly for a deck's first card.

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

### July 2, 2026 (Phase 5 Sprint 6 — educator-application → admin-approve → role grant) ✅ Deployed & verified 2026-07-02
- ✅ Extended `access_requests_status_check` CHECK to add `'approved'`/`'rejected'` (was `('pending','contacted','enrolled')` — noted `'dismissed'` was never in the CHECK despite the admin UI offering it; pre-existing, unfixed here) — see `docs/database/phase5/17_SCHEMA_extend_access_requests_status_check_for_approval.sql`
- ✅ Created `submit_educator_application()` RPC (SECURITY DEFINER, `GRANT TO anon, authenticated`, returns the row's `ref_token` uuid) — see `docs/database/phase5/18_FUNCTIONS_submit_educator_application.sql`
- ✅ Created `approve_educator_application()` / `reject_educator_application()` RPCs (admin/super_admin only) — see `docs/database/phase5/19_FUNCTIONS_approve_reject_educator_application.sql`
- ✅ Extended `link_access_request()` (`CREATE OR REPLACE`, exact introspected signature/return type preserved) to grant `professor` on first login when the carried ref_token matches an already-approved `educator_application` — see `docs/database/phase5/20_FUNCTIONS_extend_link_access_request_educator_role_grant.sql`
- ✅ Deployed & verified 2026-07-02 (`docs/database/phase5/21_TEST`: 11/11 PASS, including the one-time-claim security check)
- Frontend (written, not pushed): `Educators.jsx` gets a second "Apply to Teach on RevisOp" section; `AdminDashboard.jsx` access-requests table gets an Educator Applications filter + Approve/Reject actions

### July 1, 2026 (Phase 5 Sprint 5 — B2B /educators route)
- ✅ Added `request_type` column to `access_requests` (`text NOT NULL DEFAULT 'student_access'`, `CHECK IN ('student_access','institute_inquiry','educator_application')` — third value reserved for Sprint 6, no re-migration needed) — see `docs/database/phase5/14_SCHEMA_add_request_type_and_message_columns.sql`
- ✅ Added `message` column to `access_requests` (`text`, nullable) — carries institute city + optional note for `institute_inquiry` rows; no existing column fit without repurposing `content_type`'s meaning (rendered directly in `AdminDashboard.jsx`'s "Content Seen"/"Details" column)
- ✅ Created `submit_institute_inquiry()` RPC (SECURITY DEFINER, `GRANT TO anon, authenticated`) — see `docs/database/phase5/15_FUNCTIONS_submit_institute_inquiry.sql`
- ✅ Deployed & verified 2026-07-01 (`docs/database/phase5/16_TEST`, all 6 PASS)
- Frontend: new `src/pages/public/Educators.jsx` (`/educators`, anonymous, zero direct `.from()`), `AdminDashboard.jsx` access-requests table gets a Type badge + filter

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
**Write path (fixed 14/09/2026, `docs/database/bugfixes/17_FUNCTIONS_skip_suspend_card_atomic_upsert.sql`):** a single atomic `INSERT ... ON CONFLICT (user_id, flashcard_id) DO UPDATE SET skip_until = ...`. Previously a two-statement `UPDATE; IF NOT FOUND THEN INSERT` — safe for a single call, but non-atomic under concurrent calls (no in-flight guard on the frontend's "Skip 24hr" button): two near-simultaneous calls on the same never-reviewed card could both see "NOT FOUND" and both attempt the INSERT, the second throwing `23505 reviews_user_flashcard_unique`. See `docs/tracking/bugs.md`.

### suspend_card(p_user_id UUID, p_flashcard_id UUID)
**Purpose:** Suspends a card indefinitely by setting status='suspended'
**Security:** DEFINER
**Added:** 2026-02-06 (Card Suspension System)
**Returns:** VOID
**Write path:** same atomic-upsert fix as `skip_card` above (identical pre-fix race, same 14/09/2026 migration).

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

### get_platform_stats()
**Purpose:** Public headline stats for the unauthenticated landing page (and AdminDashboard, which hits the same RLS wall)
**Security:** DEFINER — `GRANT EXECUTE TO anon, authenticated`
**Added:** 2026-02-20 (all-visibility totals). **Extended:** 2026-07-01 (Phase 5 Sprint 4) — added `public_flashcards`/`public_notes`. ✅ **Deployed 2026-07-01** (verified: public_flashcards=693, public_notes=107). See `docs/database/phase5/13_FUNCTIONS_extend_get_platform_stats_public_counts.sql`.
**Returns:** `json` (LANGUAGE sql) — `{ student_count, educator_count, total_flashcards, total_notes, public_flashcards, public_notes }`. `total_*` counts all visibility levels (bypasses RLS); `public_*` counts `visibility = 'public'` rows only (added S4 to remove Home.jsx's direct anon `.from()` count reads, which were RLS-filtered/unreliable — see blueprint.md §1.4).
**Caller:** `Home.jsx` (hero badge/grid stats use `total_*`; "Free to Browse" educator section uses `public_*`), `AdminDashboard.jsx` (uses `total_*` — direct table counts undercounted vs this RPC, see changelog 2026-06-XX admin stat fix)

---

### get_featured_landing_content()
**Purpose:** Curated public decks + notes for the unauthenticated landing page (hero demo / teaser section)
**Security:** DEFINER — `GRANT EXECUTE TO anon, authenticated`
**Added:** 2026-07-01 (Phase 5 Sprint 2) — ✅ deployed 2026-07-01. See `docs/database/phase5/06_FUNCTIONS_get_featured_landing_content.sql`.
**Caller:** `Home.jsx` (Phase 5 Sprint 4) — drives `HeroFlipDemo.jsx` (first deck with teaser cards; falls back to hardcoded cards if none) and the "Featured Study Sets" rail (`StudyItemCard`s linking to `/deck/:id`/`/note/:id`)

**Returns:** `jsonb` — `{ decks: [...], notes: [...] }`
- `decks` (max 12, ordered `upvote_count DESC, created_at DESC`): `id, name, subject, topic, card_count, upvote_count, creator_name, cards`. `cards` is hard-capped at exactly 5 items (`front_text, back_text, question_type`), fetched via the 5-grouping-column join (see ⚠️ CRITICAL join block above) — never `fc.deck_id`.
- `notes` (max 12, ordered `upvote_count DESC, created_at DESC`): `id, title, subject, topic, author_name, upvote_count, description` (description truncated to 200 chars). Metadata only — never the note body.

**Guards:** `WHERE is_featured_on_landing = true AND visibility = 'public'` on both queries (double-guard — `visibility = 'public'` is also enforced by the auto-clear trigger, see `flashcard_decks`/`notes` column docs).

**Related:** `get_public_deck_preview` was also re-capped from 10 → 5 `preview_items` in the same sprint (`docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql`) to match the locked "teaser depth = 5" decision. **Updated 04/07/2026** (`docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql`): preview subquery now filters `fc.visibility = 'public'` (was leaking private/friends cards — SECURITY DEFINER bypasses RLS), and `card_count` counts public cards only. See `docs/tracking/bugs.md` [04/07/2026].

---

### nominate_featured_content(p_content_type text, p_content_id uuid)
**Purpose:** Professor/admin nominates their own already-public deck/note for landing-page featuring (step 1 of the two-step curation gate)
**Security:** DEFINER. Role gate: caller must be `professor`/`admin`/`super_admin`, AND must own the row unless caller is admin/super_admin. Public-only guard: raises if `visibility <> 'public'`.
**Added:** 2026-07-01 (Phase 5 Sprint 3) — ✅ **Deployed 2026-07-01.** See `docs/database/phase5/11_FUNCTIONS_featured_nomination_rpcs.sql`.
**Returns:** `void`. Sets `featured_nominated_by = auth.uid()`, `featured_nominated_at = now()`. Does NOT set `is_featured_on_landing`. Idempotent.
**Caller:** `FeatureNominationButton.jsx` (used in `MyFlashcards.jsx`, `NoteDetail.jsx`)

---

### approve_featured_nomination(p_content_type text, p_content_id uuid)
**Purpose:** Admin/super_admin approves a pending nomination (step 2) — puts the content live on the landing
**Security:** DEFINER. Role gate: `admin`/`super_admin` only. Requires a pending nomination (`featured_nominated_at IS NOT NULL`) and `visibility = 'public'`.
**Added:** 2026-07-01 (Phase 5 Sprint 3) — ✅ deployed 2026-07-01.
**Returns:** `boolean` — the resulting `is_featured_on_landing` value. The caller must check this: if the row went non-public between page load and click, the CHECK/trigger keep it `false` even though no exception is raised at the boundary that matters to the UI.
**Caller:** `AdminDashboard.jsx` (Landing Page Content → Pending Nominations → Approve)

---

### reject_featured_nomination(p_content_type text, p_content_id uuid)
**Purpose:** Admin/super_admin dismisses a pending nomination
**Security:** DEFINER, `admin`/`super_admin` only.
**Added:** 2026-07-01 (Phase 5 Sprint 3) — ✅ deployed 2026-07-01.
**Returns:** `void`. Nulls all four nomination/approval fields; `is_featured_on_landing` stays `false`.
**Caller:** `AdminDashboard.jsx` (Landing Page Content → Pending Nominations → Reject)

---

### unfeature_content(p_content_type text, p_content_id uuid)
**Purpose:** Admin/super_admin removes live content from the landing page
**Security:** DEFINER, `admin`/`super_admin` only.
**Added:** 2026-07-01 (Phase 5 Sprint 3) — ✅ deployed 2026-07-01.
**Returns:** `void`. Full removal — sets `is_featured_on_landing = false` and nulls all four nomination/approval fields, so the item leaves both the landing and `get_pending_featured_nominations()`. Functionally identical to `reject_featured_nomination()` (kept as a separate name for UI/audit clarity: Live vs Pending). Re-featuring requires a fresh nomination by the creator/admin.
**Caller:** `AdminDashboard.jsx` (Landing Page Content → Currently Live → Unfeature)

---

### get_pending_featured_nominations()
**Purpose:** Admin/super_admin queue of nominated-but-not-yet-live decks + notes
**Security:** DEFINER, `admin`/`super_admin` only.
**Added:** 2026-07-01 (Phase 5 Sprint 3) — ✅ deployed 2026-07-01.
**Returns:** `TABLE (content_type, content_id, title, subject, topic, card_count, owner_name, nominated_by_name, nominated_at)` — `UNION ALL` of decks + notes (`card_count` NULL for notes), ordered `nominated_at ASC`.
**Caller:** `AdminDashboard.jsx`

---

### get_live_featured_content_admin()
**Purpose:** Admin/super_admin view of currently-live featured decks + notes, for unfeaturing
**Security:** DEFINER, `admin`/`super_admin` only.
**Added:** 2026-07-01 (Phase 5 Sprint 3) — ✅ deployed 2026-07-01.
**Returns:** `TABLE (content_type, content_id, title, subject, topic, card_count, owner_name, nominated_by_name, nominated_at, approved_at, approved_by_name)` — `UNION ALL` of decks + notes, ordered `approved_at DESC`.
**Caller:** `AdminDashboard.jsx`

---

### submit_institute_inquiry(p_institute_name text, p_contact_name text, p_whatsapp_number text, p_email text DEFAULT NULL, p_city text DEFAULT NULL, p_course text DEFAULT NULL, p_message text DEFAULT NULL, p_requester_user_id uuid DEFAULT NULL)
**Purpose:** Capture a B2B institute lead from the anonymous `/educators` page (mirrors `submit_access_request`'s pattern for the student WhatsApp lead form)
**Security:** DEFINER, `SET search_path TO 'public'` — `GRANT EXECUTE TO anon, authenticated`
**Added:** 2026-07-01 (Phase 5 Sprint 5) — ✅ **Deployed 2026-07-01** (verified via `docs/database/phase5/16_TEST`, all 6 PASS). See `docs/database/phase5/15_FUNCTIONS_submit_institute_inquiry.sql`.
**Returns:** `void`. Inserts into `access_requests` with `request_type = 'institute_inquiry'`. Field mapping onto the existing shape (no institute-specific columns exist): `p_contact_name → name`, `p_whatsapp_number → whatsapp_number`, `p_course → course` (defaults to `'General inquiry'` if blank), `p_email → email`, `p_institute_name → content_name` (reused — `content_id`/`content_type` stay `NULL` since there's no associated content preview), `p_city` + `p_message → message` (new column, combined as `"City: X" + "\n\n" + message`). Also inserts a `notifications` row (`type = 'access_request'` — reused, since `notifications_type_check` doesn't include an institute-specific value and extending it was out of scope; `metadata->>'request_type' = 'institute_inquiry'` distinguishes it) for every `admin`/`super_admin`.
**Caller:** `Educators.jsx` (`/educators`)

---

### submit_educator_application(p_full_name text, p_whatsapp_number text, p_credential_or_linkedin text, p_email text DEFAULT NULL, p_institute_name text DEFAULT NULL, p_course text DEFAULT NULL, p_why text DEFAULT NULL, p_requester_user_id uuid DEFAULT NULL)
**Purpose:** Capture an educator application from the anonymous "Apply to Teach on RevisOp" section of `/educators` — the self-serve half of the hybrid educator on-ramp (admin approval is the gate, see `approve_educator_application` below).
**Security:** DEFINER, `SET search_path TO 'public'` — `GRANT EXECUTE TO anon, authenticated`
**Added:** 2026-07-02 (Phase 5 Sprint 6) — ✅ **Deployed 2026-07-02**. See `docs/database/phase5/18_FUNCTIONS_submit_educator_application.sql`.
**Returns:** `uuid` — the inserted row's `ref_token` (not void, unlike the other two `submit_*` RPCs). An anonymous applicant has no account yet; the frontend stores this token into `localStorage['revisop_access_ref']`, the same slot `Signup.jsx`'s `?ref=` query param populates, so a same-browser signup later auto-links via the extended `link_access_request()`. Inserts into `access_requests` with `request_type = 'educator_application'`. Required: `p_full_name`, `p_whatsapp_number`, `p_credential_or_linkedin` (the applicant's proof of expertise — the vetted-educator trust moat is core to the brand, so an application with no verifiable credential is rejected). Field mapping: `p_full_name → name`, `p_whatsapp_number → whatsapp_number`, `p_course → course` (defaults to `'Not specified'` if blank), `p_email → email`, `p_institute_name → content_name` (reused — same slot `submit_institute_inquiry` uses), `p_credential_or_linkedin` + `p_why → message` (combined as `"Credential/LinkedIn: <url>"` + optional `"\n\n<why>"`). Also inserts a `notifications` row (`type = 'access_request'`, `metadata->>'request_type' = 'educator_application'`) for every `admin`/`super_admin`.
**Caller:** `Educators.jsx` (`/educators`)

---

### approve_educator_application(p_request_id uuid)
**Purpose:** Admin/super_admin decides a pending educator application — grants the `professor` role.
**Security:** DEFINER, `admin`/`super_admin` only (role-guard idiom mirrors `approve_featured_nomination`).
**Added:** 2026-07-02 (Phase 5 Sprint 6) — ✅ **Deployed 2026-07-02**. Requires `17_SCHEMA`'s `access_requests_status_check` extension (deployed first) (else the `UPDATE ... SET status = 'approved'` fails the CHECK). See `docs/database/phase5/19_FUNCTIONS_approve_reject_educator_application.sql`.
**Returns:** `text` — `'role_granted'` if the application already has a `requester_user_id` (applicant was logged in when they applied, or a prior signup already linked it): flips that account's `profiles.role → 'professor'` immediately and notifies them. `'approved_pending_signup'` if `requester_user_id IS NULL`: only marks the row `status = 'approved'`; the role grant is deferred to first login via the extended `link_access_request()`. Raises if the row isn't a pending `educator_application` or the caller isn't admin/super_admin.
**Caller:** `AdminDashboard.jsx`

---

### reject_educator_application(p_request_id uuid)
**Purpose:** Admin/super_admin rejects a pending educator application.
**Security:** DEFINER, `admin`/`super_admin` only.
**Added:** 2026-07-02 (Phase 5 Sprint 6) — ✅ **Deployed 2026-07-02**. See `docs/database/phase5/19_FUNCTIONS_approve_reject_educator_application.sql`.
**Returns:** `void`. Sets `status = 'rejected'`; notifies the applicant only if `requester_user_id` is set (an anonymous applicant has no way to receive an in-app notification).
**Caller:** `AdminDashboard.jsx`

---

### link_access_request(p_ref_token uuid) — extended Phase 5 Sprint 6
**Purpose:** Tags the newly-authenticated user's `profiles.access_request_ref` with the carried ref_token (unchanged from its original behavior — it does NOT touch `access_requests` itself; `AdminDashboard.jsx` separately matches profiles↔requests by this tag for the student-access Grant-Access flow).
**Security:** DEFINER (signature/return type preserved exactly as introspected — `CREATE OR REPLACE`, no `SET search_path` added, since none existed originally).
**Added:** original date undocumented (pre-Phase-5, no saved migration script existed — ground-truth pulled via `pg_get_functiondef` for this sprint). **Extended:** 2026-07-02 (Phase 5 Sprint 6) — ✅ **Deployed 2026-07-02**. See `docs/database/phase5/20_FUNCTIONS_extend_link_access_request_educator_role_grant.sql`.
**Returns:** `void`. New behavior: after the existing tagging, checks whether `p_ref_token` matches an `access_requests` row with `request_type = 'educator_application' AND status = 'approved'`; if so, atomically claims that application (one-time — the claim UPDATE is guarded on `requester_user_id IS NULL`, so a token mints at most one professor even though this RPC is granted to `authenticated`), grants `profiles.role → 'professor'` (never demoting an existing admin/super_admin), and notifies the user right then. Closes the apply-anonymously-then-sign-up path (the applicant applied before having an account, and an admin approved it before they signed up). All other `request_type`s are unaffected.
**Caller:** `Dashboard.jsx` (on first mount, replaying `localStorage['revisop_access_ref']`)

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
| is_featured_on_landing | BOOLEAN | NOT NULL, DEFAULT false | ⭐ (Phase 5 Sprint 2, ✅ deployed 2026-07-01 — see `docs/database/phase5/03_SCHEMA_add_is_featured_on_landing_column.sql`). `CHECK (is_featured_on_landing = false OR visibility = 'public')`. Set to `true` only by `approve_featured_nomination()` (Sprint 3). Auto-cleared to false by `fn_autoclear_featured_on_visibility_change()` (BEFORE UPDATE, `trg_autoclear_featured_flashcard_decks`) the moment `visibility` leaves `'public'`. Partial index `idx_flashcard_decks_featured` on `WHERE is_featured_on_landing = true`. |
| featured_nominated_by | UUID | FK → profiles.id, nullable | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01 — see `docs/database/phase5/09_SCHEMA_add_featured_nomination_columns.sql`). Set by `nominate_featured_content()`. Nulled by the auto-clear trigger on unpublish, and by `reject_featured_nomination()` / `unfeature_content()`. |
| featured_nominated_at | TIMESTAMPTZ | nullable | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01). Non-NULL + `is_featured_on_landing = false` is what makes a deck appear in `get_pending_featured_nominations()`. |
| featured_approved_by | UUID | FK → profiles.id, nullable | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01). Set by `approve_featured_nomination()`. Nulled by `reject_featured_nomination()` and `unfeature_content()`. |
| featured_approved_at | TIMESTAMPTZ | nullable | ⭐ NEW (Phase 5 Sprint 3, ✅ deployed 2026-07-01). |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | |

**Unique Constraint:** `(user_id, subject_id, topic_id, custom_subject, custom_topic)` NULLS NOT DISTINCT

⚠️ **CRITICAL — How to join flashcards → flashcard_decks (READ THIS BEFORE WRITING ANY RPC)**
- **Correction, Sprint 8.7.2 (18/09/2026):** the claim below that `deck_id` is "NEVER POPULATED" was stale and wrong — live diagnostic (500 most recent rows) showed 377/500 populated, 100% match rate against the 5-column-join resolution on a 100-row spot check. `deck_id` **is** populated for manually-created cards (`FlashcardCreate.jsx` resolves/creates the deck client-side, then includes `deck_id` on every card it writes — now via `create_flashcard_batches()`, previously via direct insert) and **is** read directly by `StudyMode.jsx` and `MyFlashcards.jsx`. It is left NULL only for bulk-uploaded cards (`BulkUploadFlashcards.jsx` has never set it). **Do not write a query that assumes `deck_id` is always populated** — `StudyMode.jsx`'s own pattern (try `deck_id` first, fall back to the 5-column join when null) is the correct general-purpose approach, not "ignore `deck_id` entirely."
- The `batch_id` column on `flashcards` is for grouping cards from the same upload session — it is **NOT** the deck ID and does **NOT** link to `flashcard_decks.id`.
- **The fallback for a NULL `deck_id`** (or any RPC/query that can't rely on it being populated) is to join on the 5 grouping columns, exactly as the trigger does:
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

⚠️ **VISIBILITY — the grouping join alone returns ALL tiers.** The 5-column join matches every card in the deck regardless of each card's `visibility` (private/friends/public). Any `SECURITY DEFINER` RPC returning card **content** on a public/anon surface MUST add an explicit `AND fc.visibility = 'public'` (or the appropriate per-viewer predicate) — RLS does NOT protect SECURITY DEFINER function bodies. Gating only the deck (`fd.visibility='public'`) is insufficient: a public deck can contain private cards. This was a live leak in `get_public_deck_preview`, fixed 04/07/2026 (`docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql`; bug in `docs/tracking/bugs.md`).

**`get_public_deck_preview(p_deck_id uuid) RETURNS jsonb` — provenance added Sprint 8.7.5 (18/09/2026, ✅ deployed & live-verified):** `deck` object gained `provenance_source_type`/`provenance_source_name`, resolved via the identical `sole_batch_id` pattern `get_browsable_decks` v7 established (§ above) — computed over **all public cards in the deck** (the same grouping-column join `card_count` uses, not just the 5 `preview_items` rows): `count(DISTINCT fc.batch_id) = 1` among those public cards → that batch's `LEFT JOIN flashcard_batch_provenance`; anything else (mixed batches among public cards, or a legacy batch with no provenance row) → `NULL`, same "render nothing" rule as every other D-21 surface. Does not grant `anon` any table-level access to `flashcard_batch_provenance` — resolved inside this `SECURITY DEFINER` function, which already sits on the project's anon-allowlist. See `docs/database/sprint8.7.5/01_FUNCTIONS_public_deck_preview_provenance.sql`.

**Indexes:**
- `idx_flashcard_decks_user` (user_id)
- `idx_flashcard_decks_subject` (subject_id)
- `idx_flashcard_decks_topic` (topic_id)
- `idx_flashcard_decks_visibility` (visibility)

**Trigger: `trigger_update_deck_card_count`** — fires AFTER INSERT, UPDATE, DELETE on `flashcards`
Function: `update_deck_card_count()` (SECURITY DEFINER)
- **INSERT (existing deck):** `UPDATE card_count + 1`, and — **Sprint 7.5 (13/09/2026)** — widens `visibility` in the same statement if the new flashcard is more permissive (private < friends < public; never narrows). Fixes a real bug where a deck's visibility was frozen at whatever its first card had, silently hiding later public cards from Browse/Recent Activity — see `bugs.md`.
- **INSERT (`NOT FOUND` — no deck exists yet):** inserts a new deck row with `card_count = 1`, copying `target_course` and `visibility` from the new flashcard. **Sprint 7.5 fix (13/09/2026):** `target_course` was NOT actually in this branch's INSERT column list — confirmed via live `pg_get_functiondef`, contradicting this doc's own prior claim and the `bugs.md` "[Mar 2, 2026]" entry that first documented this branch. Live impact measured: 2 decks (34 public cards total, one professor, dating to 07/04/2026) had `target_course = NULL`, making them permanently undiscoverable to every student via `get_browsable_decks`/`get_recent_activity_feed` (both filter `fd.target_course = <course>`) — professors/admins bypass that gate, which is why it went unnoticed for 5 months. Fixed and backfilled; see `bugs.md`. This means deck rows are **auto-created on first flashcard insert** — no application code or manual SQL needed for new courses or subjects.
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
| note_id | UUID | nullable, DEPRECATED | Legacy column. ⏳ **Pending drop (SQL prepared 2026-07-02, not yet deployed):** zero client reads/writes found — `UpvoteButton.jsx` and `MyContributions.jsx` use only `content_type`/`target_id`. Drop SQL: `docs/database/landmines/04_SCHEMA_drop_legacy_free_text_columns.sql`. Remove this row once deployed. |
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
