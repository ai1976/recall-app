# REVISOP — MASTER BLUEPRINT

**Prepared:** December 2025  
**Last Updated:** July 2, 2026  
**Stack:** React 19 + Vite 7 · TailwindCSS + shadcn/ui · Supabase (PostgreSQL + Auth + RLS + Storage + Edge Functions) · Vercel  
**Live URL:** https://www.revisop.com (redirects from https://www.recallapp.co.in)  
**Repository:** https://github.com/ai1976/recall-app

**Sprint History:**
- **Sprint 0 (Dec 2025):** MVP — auth, flashcards, basic SRS (SuperMemo-2), notes upload, admin dashboard
- **Sprint 1 (Jan 2026):** Content visibility (private/friends/public), friendship system, upvotes, flashcard decks, 4-tier roles
- **Sprint 2 (Feb 2026):** Study groups, notifications (Realtime), achievement badges, push notifications, content flags
- **Sprint 3 (Mar 2026):** Study sessions, leaderboard (friends + following), daily goals, follow graph, batch groups, professor multi-course, card suspension/skip
- **Sprint 4 (Apr 2026):** Author profiles, content flagging UI, professor analytics, following page, admin analytics
- **Sprint 5 (May 2026):** Push notification infrastructure (Edge Functions, VAPID, cron)
- **Sprint 6 (Jun 2026):** 10 question types documented (MCQ, T/F, concept_card, etc.), Gemini import source
- **Sprint R7 (Jun 2026):** Full rebrand Recall → RevisOp — brand colors (#f59e0b amber + #1e1b4b navy), wordmark, PWA icons, domain migration, SMTP moved to hello@revisop.com
- **Phase 5 — Sprint 1 (Jun 2026):** Design-system foundation (presentational only). Additive brand HSL tokens (`brand.navy/amber/success` + `surface.*`) in `index.css` + `tailwind.config.js`; new `StudyItemCard` (deck/study-set card) and controlled `FlipCard` components; 3D flip utilities (reduced-motion aware); dev-only `/__design` QA route. **No DB changes; no existing shadcn token value changed.**
- **Phase 5 — Sprint 2 (Jul 2026):** ✅ *Deployed 2026-07-01* (`docs/database/phase5/03–08`). Adds `is_featured_on_landing` flag to `flashcard_decks`+`notes` (default false, `CHECK (featured => visibility='public')`), a BEFORE UPDATE auto-clear trigger that revokes the flag when content leaves public, partial indexes, and `get_featured_landing_content()` — a SECURITY DEFINER anon RPC returning curated public decks/notes with a **5-card hard cap** (via the 5-grouping-column join, never `deck_id`) and metadata-only notes. Also caps `get_public_deck_preview` teaser at 5 (was 10). **No frontend yet — hard prerequisite for S3/S4.**
- **Phase 5 — Sprint 3 (Jul 2026):** ✅ *Deployed 2026-07-01* (`docs/database/phase5/09–12`). Two-step curation gate layered on S2's flag: professors/admins nominate their own already-public decks/notes; admins/super_admins approve, reject, or unfeature. Adds 4 nullable audit columns (`featured_nominated_by/_at`, `featured_approved_by/_at`, FK → `profiles.id`) to `flashcard_decks`+`notes`; `CREATE OR REPLACE`s the existing S2 auto-clear trigger function (`fn_autoclear_featured_on_visibility_change`) to also null those 4 columns on unpublish — no new trigger. 6 new SECURITY DEFINER RPCs: `nominate_featured_content`, `approve_featured_nomination` (returns the resulting `is_featured_on_landing` boolean), `reject_featured_nomination`, `unfeature_content` (full removal — nulls all four fields so an unfeatured item leaves both the landing and the pending queue; functionally identical to reject, kept separate for UI clarity), `get_pending_featured_nominations`, `get_live_featured_content_admin`. Frontend (SQL deployed 2026-07-01, cleared to push): new `FeatureNominationButton` component (3 states: nominate / pending / featured) wired into `MyFlashcards.jsx` (deck group header, matched via the 5-grouping-column join) and `NoteDetail.jsx` (owner/admin header actions); `AdminDashboard.jsx` gets an always-visible "Landing Page Content" section (Pending Nominations + Currently Live tables) alongside the untouched Flagged Content card. S2 objects (column/CHECK/indexes/`get_featured_landing_content`/`get_public_deck_preview`) unmodified. **09→12 deployed & verified 2026-07-01 (test 12: all PASS); frontend cleared to push.**
- **Phase 5 — Sprint 4 (Jul 2026):** Landing rebuild — "show, don't tell." **SQL:** `docs/database/phase5/13` extends `get_platform_stats()` (`CREATE OR REPLACE`, same signature) to add `public_flashcards`/`public_notes` (visibility='public' counts); existing `student_count`/`educator_count`/`total_flashcards`/`total_notes` fields preserved as-is. **✅ Deployed 2026-07-01 (public_flashcards=693, public_notes=107).** **Frontend:** `Home.jsx` now has **zero direct `.from()` calls** — deleted the two `profiles` role-count reads and the two public-count reads on `flashcards`/`notes` (all were RLS-filtered/unreliable for anon visitors, per the §1.4 tech-debt note this closes). New `src/components/landing/HeroFlipDemo.jsx`: anonymous live card-flip demo driven by the first `get_featured_landing_content()` deck with teaser cards (falls back to 3 hardcoded generic cards if none — hero is never blank); controlled `FlipCard` + cosmetic Hard/Medium/Easy rating buttons styled after `StudyMode.jsx` (no SRS writes, no auth); ends with a "Sign up to save your progress" soft wall → `/signup`. New "Featured Study Sets" rail renders `get_featured_landing_content()` decks+notes as `StudyItemCard`s linking to `/deck/:id`/`/note/:id` with a "Featured" badge; omitted entirely (no empty state) when nothing is curated yet. Removed the 3 fake "— Student / Early Access" testimonial cards and their section wrapper. "For Institutes & Educators" section (mailto: CTA) untouched — real `/educators` route is Sprint 5. **`npm run build` passes; verified in-browser both with live featured content (real "Business Laws" deck, already curated via S3) and with featured content stubbed empty (client-side remount, no full reload) — rail correctly omits itself and hero correctly shows the 3-card fallback.** **13 deployed & verified 2026-07-01; frontend pushed to main.**
- **Phase 5 — Sprint 5 (Jul 2026):** ✅ *Deployed 2026-07-01* (`docs/database/phase5/14–16`). Findable B2B lead path — dedicated `/educators` route with a real lead form, replacing the `mailto:` CTAs. **SQL:** `14_SCHEMA` adds `request_type` (`text NOT NULL DEFAULT 'student_access'`, `CHECK IN ('student_access','institute_inquiry','educator_application')` — third value pre-added for Sprint 6, no re-migration) and `message` (nullable text) to `access_requests`. `15_FUNCTIONS` adds `submit_institute_inquiry()` (SECURITY DEFINER, `GRANT TO anon, authenticated`) mapping the institute lead form onto the existing `access_requests` columns (`name`/`whatsapp_number`/`course`/`email` reused directly; `content_name` reused for institute name since `content_id`/`content_type` stay NULL for institute rows; `message` is the one new column, combining city + optional note — no existing slot fit without contaminating `content_type`'s meaning in the admin UI). Admin notification reuses the existing `'access_request'` `notifications.type` value (its CHECK constraint doesn't include an institute-specific value; extending it was out of scope) — distinguished via `metadata->>'request_type'`. **16_TEST: all 6 PASS** (field mapping, course default, city-only message format, both required-field validations, admin notification fan-out). **Frontend (SQL deployed 2026-07-01, cleared to push):** new `src/pages/public/Educators.jsx` (`/educators`, anonymous, zero direct `.from()` — mirrors `ContentPreviewWall.jsx`'s form pattern) with institute lead form → `submit_institute_inquiry` → "We'll reach out within 1–2 business days" success state. `Home.jsx` gets a secondary nav link ("For Institutes") and the hero/section/footer `mailto:` CTAs are rewired to `/educators` (section content untouched). `AdminDashboard.jsx`'s Access Requests table gets a Type badge (Institute/Student) + filter (All/Student Access/Institute Inquiries); institute rows show institute name + city/message in a "Details" column and skip the signup-link/Grant-Access UI (leads only, no approval action this sprint). **`npm run build` passes; verified in-browser against the live deployed backend — form submit returned 204 and rendered the correct success copy, no console errors.** Educator-application-to-role-grant flow is Sprint 6, not started.
- **Phase 5 — Sprint 6 (Jul 2026):** ✅ *Deployed & verified 2026-07-02* (`docs/database/phase5/17–21`). Final Phase 5 sprint — hybrid educator on-ramp: self-serve application form → admin approval → `professor` role grant (two-step, admin-gated; no self-upgrade). Ground-truth introspection (before any `CREATE OR REPLACE`, per the S4 42P13 lesson) found `access_requests` has no approver/approved-at column and `link_access_request(p_ref_token uuid) RETURNS void` is far simpler than assumed — it only tags `profiles.access_request_ref`, it never touches `access_requests`. **SQL:** `17_SCHEMA` extends `access_requests_status_check` (was `('pending','contacted','enrolled')` — notably missing `'dismissed'` too, a pre-existing gap flagged separately, out of scope) to add `'approved'`/`'rejected'`; no new column added. `18_FUNCTIONS` adds `submit_educator_application()` (SECURITY DEFINER, `GRANT TO anon, authenticated`) — required fields full name/WhatsApp/credential-or-LinkedIn URL (the vetting proof), optional email/institute/course/why; maps onto `access_requests` exactly like `submit_institute_inquiry` (`content_name` reused for institute, `message` combines credential+why); **returns the row's `ref_token` (not void)** so an anonymous applicant's browser can store it into `localStorage['revisop_access_ref']` — the same slot `Signup.jsx`'s `?ref=` param already populates — so a same-browser signup later auto-links. `19_FUNCTIONS` adds `approve_educator_application(p_request_id)` (admin/super_admin only, mirrors the S3 nomination RPCs' role-guard idiom; returns `'role_granted'` if the applicant already has an account — flips `profiles.role` + notifies immediately — or `'approved_pending_signup'` if not, deferring the grant) and `reject_educator_application(p_request_id)`. `20_FUNCTIONS` extends `link_access_request` (`CREATE OR REPLACE`, exact introspected signature/return type preserved, no other request_types affected) so that on first login, if the carried `ref_token` matches an already-approved `educator_application`, it grants `professor` right then — closing the apply-anonymously-then-sign-up path (hardened post-review to a one-time, atomically-claimed grant guarded on `requester_user_id IS NULL`, so a token mints at most one professor and never demotes an admin). **21_TEST: 11 blocks** covering anon submit + field mapping, required-field/course-default validation, admin notification, the admin-only gate, both approve outcomes (linked immediate grant vs. deferred), reject, the link-on-signup flip, and a regression guard that a still-pending application never grants the role, plus a security check that an approved token is one-time (replay by a second account is rejected). **Frontend (deployed & pushed 2026-07-02):** `Educators.jsx` gets a second, clearly-labeled "Apply to Teach on RevisOp" section (distinct from the S5 institute form) — anonymous-safe, zero direct `.from()`, "We'll review and reach out within 1–2 business days" success copy. `AdminDashboard.jsx`'s Access Requests queue gets an "Educator Applications" filter + purple "Educator" badge, a read-only status badge (bypassing the generic pending/contacted/enrolled/dismissed dropdown, which must not be used for this request_type since it would bypass the approval RPCs' role-grant side effects), and Approve/Reject buttons that show the resulting state (role granted / awaiting signup with a copyable signup link / rejected). **`npm run build` passes; verified in-browser against the live (undeployed) backend — the new form renders, submits with exactly the RPC's parameter names, and the resulting PGRST202 "function not found" confirms the wiring is correct pending deployment.** **Phase 5 is COMPLETE — all six sprints deployed & shipped 2026-07-02.** See `now.md`.

---

## TABLE OF CONTENTS

- [Part 1 — Revised Blueprint (Current Truth)](#part-1--revised-blueprint-current-truth)
  - [1.1 Database Schema](#11-database-schema)
  - [1.2 Migration History](#12-migration-history)
  - [1.3 Storage Buckets](#13-storage-buckets)
  - [1.4 Backend Functions & RLS](#14-backend-functions--rls)
  - [1.5 Routes & Screens](#15-routes--screens)
  - [1.6 Page Inventory](#16-page-inventory)
  - [1.7 Component Library](#17-component-library)
  - [1.8 Utility Libraries & Hooks](#18-utility-libraries--hooks)
  - [1.9 Data Flow Diagram](#19-data-flow-diagram)
  - [1.10 Key Relations Map](#110-key-relations-map)
  - [1.11 DB Cleanup Backlog & Landmines](#111-db-cleanup-backlog--landmines)
- [Part 2 — Original vs Revised: What Changed](#part-2--original-vs-revised-what-changed)
  - [2.1 Planned vs Built](#21-planned-vs-built)
  - [2.2 Schema Changes Beyond Original Plan](#22-schema-changes-beyond-original-plan)
  - [2.3 Features Added Beyond Phases](#23-features-added-beyond-phases)
  - [2.4 Design Decisions](#24-design-decisions)
  - [2.5 Scope Explicitly Dropped](#25-scope-explicitly-dropped)
- [Part 3 — Decision Map & Future Work](#part-3--decision-map--future-work)
  - [3.1 Decision Log](#31-decision-log)
  - [3.2 Pending Work & Roadmap](#32-pending-work--roadmap)
  - [3.3 Infrastructure Reference](#33-infrastructure-reference)
  - [3.4 Brand Identity](#34-brand-identity)

---

## Part 1 — Revised Blueprint (Current Truth)

### 1.1 Database Schema

**Total tables: 30 + 1 view (`vw_study_items`) | RLS: enabled on all 30 tables | Triggers: 18 in public schema + 2 on `auth.users` | Functions: 90+**

> **Verified against live DB (Jun 29, 2026)** via `information_schema` / `pg_catalog` introspection. Counts and column lists below reflect actual database state, not intent. Known DB-level problems (duplicate triggers, dead functions, load-bearing legacy columns) are catalogued in **§1.11 DB Cleanup Backlog & Landmines** — read it before any pivot migration.

---

#### profiles
User accounts with 4-tier role system. Created by `handle_new_user()` trigger on `auth.users` — never by client INSERT (email confirmation = no session = RLS blocks client insert).

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | Matches auth.users.id |
| full_name | text | Display name |
| email | text UNIQUE | From Supabase auth |
| role | text NOT NULL | student / professor / admin / super_admin |
| course_level | text | User's primary enrollment (CA Foundation/Inter/Final) |
| institution | text | Coaching institute name |
| account_type | text NOT NULL | self_registered (B2C) or enrolled (B2B) |
| status | text NOT NULL | active / suspended |
| has_seen_onboarding | boolean | Controls first-login modal |
| timezone | text | IANA timezone, auto-detected on login |
| daily_review_goal | integer | CHECK >0 AND <=200; NULL = no goal |
| daily_study_goal_minutes | integer | CHECK >0 AND <=480; NULL = no goal |
| access_request_ref | uuid | B2B lead linkage; set by `link_access_request` RPC (was undocumented) |
| created_at | timestamptz | Account creation |
| updated_at | timestamptz | Last profile update (was undocumented) |

**Key distinction:** `role` = permission level; `account_type` = business relationship (enrolled users see professor public content, self_registered see only their own).

---

#### notes
User-uploaded study notes with optional image and OCR text.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles | Uploader |
| contributed_by | uuid FK→profiles | Professor attribution (separate from uploader) |
| target_course | text | Who this content is FOR (nullable in DB) |
| discipline_id | uuid FK→disciplines | |
| subject_id | uuid FK→subjects | |
| topic_id | uuid FK→topics | |
| custom_subject | text | Free-text for non-taxonomy courses |
| custom_topic | text | Free-text for non-taxonomy courses |
| title | text NOT NULL | |
| description | text | Free-text description (was undocumented) |
| content_type | text | Text / Table / Math / Diagram |
| image_url | text | Supabase Storage URL |
| extracted_text | text | OCR output |
| tags | text[] | #important, #revision |
| is_public | boolean | ⚠️ **LOAD-BEARING** — notes public-read RLS keys SOLELY on this column, NOT on `visibility`. Do not drop. See §1.11. |
| visibility | text | private / friends / public (default 'private'). NOT referenced by the public-read RLS policy. |
| view_count | integer | Engagement metric |
| upvote_count | integer | Auto-maintained by `trigger_update_upvote_counts` |
| course / subject / topic | text | ⚠️ Legacy free-text columns, superseded by FK + custom_* (still present in DB). See §1.11. |
| created_at | timestamptz | |
| updated_at | timestamptz | |

> **⚠️ Correction:** the blueprint previously listed a `notes.is_verified` column — **it does not exist in the database.** Removed.

---

#### flashcards
Spaced repetition cards. `deck_id` column exists but is NEVER populated — do NOT filter by it. Use the 5-column join to associate cards with decks.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles | Owner |
| contributed_by | uuid FK→profiles | Professor attribution |
| creator_id | uuid FK→profiles | Who uploaded (operational) |
| content_creator_id | uuid FK→content_creators | Who gets revenue (financial) |
| target_course | text NOT NULL | Who this content is FOR |
| note_id | uuid FK→notes | Optional source note |
| front_text | text NOT NULL | Question side |
| back_text | text NOT NULL | Answer side |
| front_image_url | text | Optional image |
| back_image_url | text | Optional image |
| discipline_id | uuid FK→disciplines | |
| subject_id | uuid FK→subjects | |
| topic_id | uuid FK→topics | |
| custom_subject | text | Free-text; mutually exclusive with subject_id |
| custom_topic | text | Free-text; mutually exclusive with topic_id |
| batch_id | uuid NOT NULL | Groups cards from same upload (CRITICAL for display) |
| batch_description | text | Optional batch label |
| is_verified | boolean | |
| difficulty | text | easy / medium / hard |
| visibility | text NOT NULL | private / friends / public |
| question_type | text NOT NULL | flashcard / mcq / true_false / correct_incorrect / theory / test_your_understanding / case_study_mcq / integrated_case / match_the_following / fill_in_the_blanks / concept_card |
| options | jsonb | Answer options for MCQ-type questions |
| correct_answer | text | For question types that need it |
| hints | jsonb | Optional hints array |
| points_to_remember | jsonb | Key takeaways shown post-answer |
| scenario | text | Case study / scenario text |
| subtype | text | Sub-classification within question_type |
| source | text NOT NULL | manual / bulk_upload / gemini_import |
| next_review | timestamptz | ⚠️ VESTIGIAL — written at create, never read (see below) |
| interval | integer | ⚠️ VESTIGIAL — written as `1` at create, never read |
| ease_factor | numeric | ⚠️ VESTIGIAL — written as `2.5` at create, never read |
| repetitions | integer | ⚠️ VESTIGIAL — written as `0` at create, never read |
| created_at | timestamptz | |

**Critical rules:**
- Group by `batch_id`, NEVER by timestamp
- `concept_card` items excluded from all review metrics (Items Reviewed, streak, accuracy)
- To fetch cards for a deck: join on 5 columns (user_id, subject_id, topic_id, custom_subject, custom_topic) — NOT by deck_id

**⚠️ Vestigial SRS columns (dual-write artifact — DO NOT use for scheduling):**
`FlashcardCreate.jsx` (~line 468) still writes `next_review`, `interval`, `ease_factor`, `repetitions` into `flashcards` on INSERT as static initialization defaults (`next_review = now()`, `interval = 1`, `ease_factor = 2.5`, `repetitions = 0`). **These are never read back** — all live SRS scheduling reads from the `reviews` table (`reviews.next_review_date`). They are dead schema left over from the pre-Sprint-1 design where SRS state lived on `flashcards` (see D-02). Note the **name divergence** from `reviews`: here it is `ease_factor`/`repetitions`; in `reviews` it is `easiness`/`repetition`. **Cleanup task:** drop these 4 columns from `flashcards` and remove the write block in FlashcardCreate. Until then, treat them as authoritative-looking but stale — never read them.

---

#### reviews
Single source of truth for all spaced repetition state (SuperMemo-2 algorithm).

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles | |
| flashcard_id | uuid FK→flashcards | |
| quality | integer | 1=Hard, 3=Medium, 5=Easy |
| easiness | double precision | SuperMemo-2 EF value (default 2.5) — NOT `easiness_factor`, and the type is `double precision` (float8), NOT numeric |
| interval | integer | Days until next review |
| repetition | integer | Consecutive correct reviews — NOT repetitions |
| next_review_date | date | ⚠️ DATE (not timestamptz) — stored as `YYYY-MM-DD` local-date string. `StudyMode.jsx` builds it from local Y/M/D (~line 289) and compares as a string. Treating it as a timestamp will cause "wrong day" bugs. |
| last_reviewed_at | timestamptz | Timestamp of most recent rating |
| status | text | active / suspended |
| skip_until | date | Card hidden until this date (24h skip) |
| created_at | timestamptz | Used for streak calc — NOT reviewed_at |

**UNIQUE(user_id, flashcard_id)** — one review record per user per card.

---

#### flashcard_decks
Auto-maintained by trigger on `flashcards`. Never created by client INSERT directly.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles | |
| subject_id | uuid FK→subjects | Nullable |
| topic_id | uuid FK→topics | Nullable |
| custom_subject | text | Nullable |
| custom_topic | text | Nullable |
| target_course | text | |
| visibility | text | private / friends / public |
| name | text | Optional custom name |
| description | text | |
| card_count | integer | Auto-maintained by trigger |
| upvote_count | integer | Auto-maintained by trigger |
| created_at | timestamptz | |
| updated_at | timestamptz | |

---

#### disciplines / subjects / topics
Course taxonomy. Pre-loaded with CA Intermediate data (147 topics across 8 subjects). Course-agnostic by design; CA/CMA/CS is current beta content only.

All three tables use `order_num` (NOT `sort_order`). disciplines and subjects both have a secondary `order` column.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | |
| code | text NOT NULL | disciplines only; no default — must be provided |
| discipline_id / subject_id | uuid FK | Parent reference |
| order_num | integer | Display order |
| is_active | boolean | Enable/disable |
| created_at | timestamptz | |

---

#### study_groups
Group metadata. Any group can be joined via `/join/:invite_token`.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | |
| description | text | |
| created_by | uuid FK→profiles ON DELETE CASCADE | |
| is_batch_group | boolean | True = official B2B group; hides Leave/Delete for members |
| batch_course | text | For batch isolation |
| batch_institution | text | For batch isolation |
| invite_token | uuid | Shareable join link |
| group_type | text | batch / system_course / custom |
| linked_course | text | For system_course type |
| created_at | timestamptz | |
| updated_at | timestamptz | |

---

#### study_group_members

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| group_id | uuid FK→study_groups ON DELETE CASCADE | |
| user_id | uuid FK→profiles ON DELETE CASCADE | |
| role | text | admin / member |
| status | text | invited / active |
| invited_by | uuid FK→profiles ON DELETE SET NULL | |
| joined_at | timestamptz | Updated to NOW() on accept |

**UNIQUE(group_id, user_id)**

---

#### content_group_shares
Links notes/decks to groups. CASCADE from group delete removes shares, NOT original content.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| group_id | uuid FK→study_groups ON DELETE CASCADE | |
| content_type | text | note / flashcard_deck |
| content_id | uuid | Points to notes.id or flashcard_decks.id |
| shared_by | uuid FK→profiles ON DELETE CASCADE | |
| shared_at | timestamptz | |

**UNIQUE(group_id, content_type, content_id)**

---

#### notifications
All notification types with JSONB metadata. Realtime enabled on this table.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles ON DELETE CASCADE | |
| type | text | content_upvoted / badge_earned / friend_request / friend_accepted / friend_rejected / welcome / group_invite / follow |
| title | text | |
| message | text | |
| is_read | boolean | Default false |
| metadata | jsonb | Type-specific data (group_id, membership_id, etc.) |
| created_at | timestamptz | |

---

#### friendships
Bidirectional friend connections.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles | Who sent request |
| friend_id | uuid FK→profiles | Who received request |
| status | text | pending / accepted / rejected |
| created_at | timestamptz | |
| updated_at | timestamptz | Status change time |

**UNIQUE(user_id, friend_id)**

---

#### follows
Unilateral follow graph (no mutual consent required).

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| follower_id | uuid FK→auth.users ON DELETE CASCADE | |
| followee_id | uuid FK→auth.users ON DELETE CASCADE | |
| created_at | timestamptz | |

**UNIQUE(follower_id, followee_id)** · **CHECK(follower_id <> followee_id)**

---

#### upvotes
Polymorphic — works for both notes and flashcard_decks.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→profiles | |
| content_type | text | note / flashcard_deck |
| target_id | uuid | Points to notes.id or flashcard_decks.id |
| note_id | uuid | ⚠️ Legacy column (pre-polymorphic), still present in DB. See §1.11. |
| created_at | timestamptz | |

**UNIQUE(user_id, content_type, target_id)**

---

#### badge_definitions / user_badges / user_activity_log / user_stats

**badge_definitions:** Catalogue of achievement badges (key, name, icon_key, category, threshold, order_num, is_active).

**user_badges:** Awarded badges per user (user_id, badge_id, earned_at, notified, is_public). **UNIQUE(user_id, badge_id)**. Per-badge privacy toggle.

**user_activity_log:** Daily activity log for streak and badge calculations (user_id, activity_type, activity_date, activity_hour). **UNIQUE(user_id, activity_type, activity_date)**.

**user_stats:** Counter table for O(1) badge eligibility checks — maintained by `trg_aaa_*` triggers (fires before `trg_badge_*` alphabetically).

---

#### study_sessions
Completed study sessions only. Incomplete sessions live in localStorage and are never written to DB.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK→auth.users ON DELETE CASCADE | |
| started_at | timestamptz NOT NULL | |
| ended_at | timestamptz NOT NULL | |
| duration_seconds | integer NOT NULL | CHECK > 0 |
| session_date | date NOT NULL | User's LOCAL date (YYYY-MM-DD) — not UTC |
| source | text NOT NULL | manual / study_mode |
| created_at | timestamptz | |

---

#### content_flags
User-submitted content reports. Auto-escalates to priority='high' at 3+ flags on same item.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| flagged_by | uuid FK→profiles ON DELETE CASCADE | |
| content_type | text | flashcard / note |
| content_id | uuid | |
| reason | text | content_error / inappropriate / other |
| details | text | Optional description (max 500 chars) |
| status | text | pending / resolved / rejected / removed |
| priority | text | normal / high |
| resolved_by | uuid FK→profiles | |
| resolution_note | text | |
| created_at | timestamptz | |
| resolved_at | timestamptz | |

**Routing:** content_error → professor queue + admin override; inappropriate/other → admin only.

---

#### push_subscriptions / push_notification_preferences
Push subscriptions with soft-delete on expiry. Preferences per-user (all default true).

---

#### admin_audit_log / role_change_log / role_permissions
Append-only audit trails for admin actions and role changes. `role_permissions` stores permission matrix for 4-tier system (public read, admin write).

---

#### content_creators
Revenue attribution for Vivitsu partnership and future creator monetization.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | |
| type | text | individual / organization |
| email | text UNIQUE | |
| revenue_share_percentage | decimal | Default 30.0 |
| created_at | timestamptz | |

---

#### profile_courses
Junction table enabling professors/admins/super_admins to teach multiple disciplines. Students remain on single `course_level`.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| profile_id | uuid FK→profiles | |
| discipline_id | uuid FK→disciplines | |
| is_primary | boolean | TRUE = synced with profiles.course_level |
| created_at | timestamptz | |

**Rule:** `is_primary = TRUE` is always kept in sync with `profiles.course_level` via `setPrimaryCourse()`. The `profiles.course_level` column is kept for backward compatibility.

---

#### access_requests
WhatsApp lead capture and B2B institute access requests (not yet actively used in UI).

---

### 1.2 Migration History

No formal migration files exist (direct Supabase SQL editor). Milestones by sprint:

| Sprint | Date | Changes |
|--------|------|---------|
| 0 — MVP | Dec 2025 | Core tables: profiles, notes, flashcards, reviews, disciplines/subjects/topics, comments, upvotes, role_permissions. Basic CRUD RLS. |
| 0 — Batch | Dec 26, 2025 | batch_id + batch_description on flashcards. Back-filled 52 existing cards. |
| 0 — Super Admin RLS | Jan 2, 2026 | super_admin SELECT policies on profiles, notes, flashcards, reviews. Fixed empty admin dashboard. |
| 1 — Attribution | Jan 9, 2026 | creator_id on flashcards. content_creators table. friendships table. |
| 1 — Visibility | Jan 11, 2026 | visibility column replaces is_public on notes (16 rows migrated) and flashcards (567 rows migrated). |
| 1 — Decks & Upvotes | Jan 24, 2026 | flashcard_decks table. Polymorphic upvotes (content_type + target_id). update_deck_card_count trigger. |
| 1 — Badges | Jan 26, 2026 | badge_definitions, user_badges, user_activity_log, user_stats. trg_badge_* + trg_aaa_counter_* triggers. |
| 2 — Groups | Feb 6, 2026 | study_groups, study_group_members, content_group_shares. 14 group RPCs. |
| 2 — Notifications | Feb 6, 2026 | notifications table (pre-existing columns + metadata JSONB + title + type expansion). |
| 2 — Card Suspension | Feb 6, 2026 | status + skip_until on reviews. Partial composite index. |
| 2 — Flags | Mar 2026 | content_flags table. submit_content_flag, get_my_content_flags, get_admin_flags, resolve_content_flag RPCs. |
| 3 — Sessions | Mar 2026 | study_sessions table. get_study_time_stats RPC. |
| 3 — Groups v2 | Mar 19, 2026 | invite_token, group_type, linked_course on study_groups. handle_new_user trigger for profile creation. |
| 3 — Goals | Mar 22, 2026 | daily_review_goal + daily_study_goal_minutes on profiles. update_daily_goal RPC. |
| 3 — Follows | Sprint 3.4 | follows table. follow_user, unfollow_user, get_follow_status, get_following_with_stats RPCs. |
| 3 — Leaderboard | Sprint 3.5 | get_friends_leaderboard, get_following_leaderboard RPCs. |
| 6 — Question Types | Mar 2026 | 10 content-type columns on flashcards now documented: question_type, options, correct_answer, hints, points_to_remember, scenario, subtype, source, custom_subject, custom_topic. |

---

### 1.3 Storage Buckets

| Bucket | Access | Notes |
|--------|--------|-------|
| `notes` | Public read | Note images. Compressed at upload: max 500 KB / 1920px. |
| `flashcard-images` | Public read | Flashcard images. Compressed at upload: max 200 KB / 1200px. Migrated from base64 in Feb 2026 (167 images, 110 MB). |

---

### 1.4 Backend Functions & RLS

#### SECURITY DEFINER RPCs (70+ functions)

> **Audit note (Jun 2026):** the original blueprint listed ~16 RPCs. A code sweep (`grep -o "\.rpc('...')"`) found **70+ distinct RPCs actually called**. The table below is the original curated set; the **"Additional RPCs found in code"** table that follows it captures everything previously undocumented. Together these are the full inventory as of the current code.

| Function | Purpose | Caller |
|----------|---------|--------|
| `get_user_activity_stats()` | Admin dashboard stats (total users, active today/week, new signups) | SuperAdminDashboard, AdminDashboard |
| `get_filtered_authors_for_notes(p_course, p_subject_id, p_role)` | Authors with public notes matching filters | BrowseNotes.jsx |
| `get_filtered_authors_for_flashcards(p_course, p_subject_id, p_role)` | Authors with public decks matching filters | ReviewFlashcards.jsx |
| `get_anonymous_class_stats()` | "You vs Class" comparison widget (min 5 users) | AnonymousStats.jsx |
| `get_user_streak(p_user_id)` | Consecutive study day streak | Multiple callers |
| `get_discoverable_users()` | Same-course users caller can send friend requests to (masked email) | FindFriends.jsx |
| `get_my_friends_with_stats()` | Accepted friends with weekly stats | MyFriends.jsx |
| `get_batch_group_member_stats(p_group_id)` | Professor view of batch member activity | ProfessorAnalytics.jsx |
| `get_study_time_stats(p_user_id, p_local_date)` | Today/week study time stats | GoalProgressWidget, Dashboard |
| `follow_user(p_followee_id)` | Idempotent follow + fires notification | AuthorProfile.jsx |
| `unfollow_user(p_followee_id)` | DELETE from follows | AuthorProfile.jsx, Following.jsx |
| `get_follow_status(p_target_id)` | Is caller following target? | AuthorProfile.jsx |
| `get_following_with_stats()` | All followees with weekly stats | Following.jsx |
| `get_friends_leaderboard()` | Caller + mutual friends ranked by weekly reviews | LeaderboardWidget.jsx |
| `get_following_leaderboard()` | Top 20 followees + caller by weekly reviews | LeaderboardWidget.jsx |
| `update_daily_goal(p_review_goal, p_study_goal_minutes)` | Set or clear daily goals on profile | GoalProgressWidget.jsx |
| `get_public_note_preview(p_note_id)` | Public note metadata (no auth required) | NotePreview.jsx |
| `get_group_preview(p_token)` | Group metadata for join page (no auth required) | GroupJoin.jsx |
| `join_group_by_token(p_token)` | Join group; redirects unauthenticated to login | GroupJoin.jsx |
| `submit_content_flag(...)` | Flag content; dedup check; priority escalation | ContentFlagModal |
| `get_my_content_flags()` | Professor queue: pending content_error flags on own content | ProfessorTools |
| `get_admin_flags(p_status)` | Admin queue: all flags by status | AdminAnalytics |
| `resolve_content_flag(...)` | Resolve/reject/remove flag | Admin UI |
| Notification RPCs (6) | get/mark/delete notifications | useNotifications.js |
| Group RPCs (14) | create/invite/accept/decline/leave/share groups | MyGroups, GroupDetail |
| `cleanup_old_notifications()` | Delete notifications > 60 days (pg_cron) | cron job |

#### Additional RPCs found in code (previously undocumented)

These were called by the frontend but missing from the blueprint. Grouped by domain; file references are the call sites.

| Function | Purpose | Caller |
|----------|---------|--------|
| **Landing / public (anon)** | | |
| `get_public_educators()` | Public educator list for landing page | Home.jsx |
| `get_platform_stats()` | Public headline stats: `student_count`/`educator_count`/`total_flashcards`/`total_notes`, plus `public_flashcards`/`public_notes` (visibility='public' counts). **✅ Deployed 2026-07-01** (`docs/database/phase5/13`, S4) | Home.jsx, AdminDashboard.jsx |
| `get_public_deck_preview(p_deck_id)` | Public deck metadata + first **5** cards (front_text only) for share page (no auth) | DeckPreview.jsx |
| `get_featured_landing_content()` | Curated featured public decks/notes for landing hero+teaser (anon). 5-card hard cap per deck (front/back/type) via 5-grouping-column join; notes metadata-only. **✅ Deployed 2026-07-01 (`docs/database/phase5/06`)**. Drives `HeroFlipDemo.jsx` + the "Featured Study Sets" rail (S4). | Home.jsx (S4) |
| **Landing / curation — nomination & approval (Phase 5 S3, authenticated)** | | |
| `nominate_featured_content(p_content_type, p_content_id)` | Professor/admin nominates own already-public deck/note for featuring; public-only guard; idempotent. **✅ Deployed 2026-07-01 (`docs/database/phase5/11`)** | `FeatureNominationButton.jsx` (MyFlashcards.jsx, NoteDetail.jsx) |
| `approve_featured_nomination(p_content_type, p_content_id)` | Admin/super_admin approves a pending nomination → sets `is_featured_on_landing=true`; returns the resulting boolean so the caller can detect a non-public race. **✅ Deployed 2026-07-01 (`docs/database/phase5/11`)** | AdminDashboard.jsx |
| `reject_featured_nomination(p_content_type, p_content_id)` | Admin/super_admin clears a pending nomination (all 4 audit fields nulled). **✅ Deployed 2026-07-01 (`docs/database/phase5/11`)** | AdminDashboard.jsx |
| `unfeature_content(p_content_type, p_content_id)` | Admin/super_admin removes live content from the landing; full removal — nulls all four nomination/approval fields (leaves landing + pending queue). **✅ Deployed 2026-07-01 (`docs/database/phase5/11`)** | AdminDashboard.jsx |
| `get_pending_featured_nominations()` | Admin/super_admin queue of nominated-but-not-yet-live decks+notes (UNION ALL). **✅ Deployed 2026-07-01 (`docs/database/phase5/11`)** | AdminDashboard.jsx |
| `get_live_featured_content_admin()` | Admin/super_admin view of currently-live featured decks+notes, for unfeaturing. **✅ Deployed 2026-07-01 (`docs/database/phase5/11`)** | AdminDashboard.jsx |
| **Dashboard / activity** | | |
| `get_recent_activity_feed(...)` | Recent content feed for dashboard widget | useActivityFeed.js |
| `link_access_request(p_ref_token uuid)` | Tags the newly-authenticated user's `profiles.access_request_ref` with the carried ref_token (does NOT touch `access_requests` itself — `AdminDashboard.jsx` separately matches profiles↔requests by this tag). **Extended Phase 5 S6** (`CREATE OR REPLACE`, same signature/return type, introspected first per the S4 42P13 lesson): also atomically claims an already-approved `educator_application` matching the token (one-time: guarded on `requester_user_id IS NULL`, so a token grants `professor` at most once and never demotes an admin) and notifies — closing the apply-anonymously-then-sign-up path. **✅ Deployed 2026-07-02** (`docs/database/phase5/20`) | Dashboard.jsx |
| **Card management (suspend / skip / reset)** | | |
| `skip_card`, `suspend_card`, `reset_card` | Per-card defer / suspend / reset SRS state | StudyMode.jsx |
| `skip_topic_cards`, `suspend_topic_cards` | Bulk skip/suspend all cards in a topic | StudyMode.jsx |
| `get_suspended_cards()`, `unsuspend_card(...)` | List + restore suspended cards | Progress.jsx |
| `get_due_forecast(...)` | Upcoming due-card forecast chart | Progress.jsx |
| `get_question_type_performance(...)` | Accuracy broken down by question_type | Progress.jsx |
| **Upvotes** | | |
| `toggle_upvote(p_content_type, p_target_id)` | Polymorphic upvote toggle (notes + decks) | UpvoteButton.jsx |
| **Author profile** | | |
| `get_author_profile(...)`, `get_author_content_summary(...)` | Public author page data | AuthorProfile.jsx |
| **Badges** | | |
| `get_user_badges(...)`, `get_unnotified_badges(...)` | Badge data + newly-earned badge check | useBadges.js |
| **Heatmaps** | | |
| `get_study_heatmap(...)` | Per-user study activity heatmap | StudyHeatmap.jsx |
| `get_platform_heatmap(...)` | Platform-wide activity heatmap | PlatformHeatmap.jsx |
| **B2B access requests & batch enrollment** | | |
| `submit_access_request(...)` | Capture B2B / paywall access request | ContentPreviewWall.jsx |
| `submit_institute_inquiry(...)` | Capture B2B institute lead (`access_requests.request_type = 'institute_inquiry'`) — anon RPC, `GRANT TO anon, authenticated`. **✅ Deployed 2026-07-01** (Phase 5 S5, `docs/database/phase5/15`) | `Educators.jsx` (`/educators`) |
| `submit_educator_application(...)` | Capture educator application (`access_requests.request_type = 'educator_application'`) — anon RPC, `GRANT TO anon, authenticated`; required full name/WhatsApp/credential-or-LinkedIn, optional email/institute/course/why; returns the row's `ref_token` (not void) so an anonymous applicant's browser can carry it into a future signup via `localStorage['revisop_access_ref']`. **✅ Deployed 2026-07-02** (Phase 5 S6, `docs/database/phase5/18`) | `Educators.jsx` (`/educators`) |
| `approve_educator_application(p_request_id)` | Admin/super_admin approves a pending educator application — flips `profiles.role → 'professor'` + notifies immediately if the applicant already has a linked account (returns `'role_granted'`), else only marks approved and defers the grant to `link_access_request` on first login (returns `'approved_pending_signup'`). **✅ Deployed 2026-07-02** (Phase 5 S6, `docs/database/phase5/19`) | AdminDashboard.jsx |
| `reject_educator_application(p_request_id)` | Admin/super_admin rejects a pending educator application; notifies the applicant if linked. **✅ Deployed 2026-07-02** (Phase 5 S6, `docs/database/phase5/19`) | AdminDashboard.jsx |
| `enroll_user_in_batch_group(...)`, `notify_access_granted(...)` | Admin grants access + notifies user | AdminDashboard.jsx |
| `get_admin_batch_groups()`, `create_batch_group(...)` | Admin batch-group management | AdminDashboard.jsx |
| `get_my_batch_groups()` | User's batch groups | MyGroups.jsx |
| **Professor analytics** | | |
| `get_professor_overview`, `get_professor_subject_engagement`, `get_professor_weak_cards`, `get_professor_top_cards`, `get_professor_weekly_reach` | Professor analytics dashboard | ProfessorAnalytics.jsx |
| **Admin analytics** | | |
| `get_admin_platform_overview`, `get_content_health_stats`, `get_user_onboarding_stats`, `get_weekly_platform_reviews` | Admin analytics dashboard | AdminAnalytics.jsx |
| **Super admin** | | |
| `admin_delete_user_data(...)` | ⚠️ Destructive — wipes all data for a user (super_admin only) | SuperAdminDashboard.jsx |
| `get_content_creation_stats`, `get_study_engagement_stats`, `get_user_retention_stats` | Super-admin dashboard stats | SuperAdminDashboard.jsx |
| `get_super_admin_header_stats`, `get_super_admin_cohort_comparison`, `get_creator_leaderboard` | Super-admin analytics | SuperAdminAnalytics.jsx |
| **Browse content** | | |
| `get_browsable_notes(...)`, `get_browsable_decks(...)` | Own + public + friends + group-shared content lists | BrowseNotes.jsx, ReviewFlashcards.jsx |

> The grouped lines **"Group RPCs (14)"** and **"Notification RPCs (6)"** in the table above expand to: `create_study_group`, `get_user_groups`, `get_group_detail`, `invite_to_group`, `accept_group_invite`, `decline_group_invite`, `remove_group_member`, `leave_group`, `get_pending_group_invites`, `share_content_with_groups`, `get_batch_group_member_stats` (+ batch variants); and `get_unread_notification_count`, `get_recent_notifications`, `mark_notifications_read`, `mark_single_notification_read`, `delete_notification`, `cleanup_old_notifications`.

#### Key Triggers

| Trigger | Table | Purpose |
|---------|-------|---------|
| `trg_create_profile_on_signup` → `fn_create_profile_on_signup()` | auth.users AFTER INSERT | Creates the profiles row on signup. SECURITY DEFINER, `ON CONFLICT (id) DO NOTHING`. Required because email confirmation = no session = client INSERT blocked by RLS. **Sole signup trigger as of Jun 30, 2026** — the former duplicate `on_auth_user_created → handle_new_user()` was dropped (see §1.11 #1, ✅ resolved). |
| `trigger_update_deck_card_count` → `update_deck_card_count()` | flashcards AFTER INSERT/UPDATE/DELETE | Maintains card_count on flashcard_decks (SECURITY INVOKER). Do NOT add a second trigger — causes double-counting. |
| `trg_aaa_counter_*` → `fn_update_*_counter()` | flashcards, notes, reviews, upvotes, friendships | Maintains user_stats counters. Named trg_aaa_ to fire before trg_badge_. |
| `trg_badge_*` → `fn_badge_check_*()` | flashcards, notes, reviews, upvotes, friendships | Awards badges on milestone events. (Note: a parallel `trg_check_badge_*` function set exists but is NOT wired to any trigger — dead code, see §1.11.) |
| `trg_badge_new_profile` → `fn_badge_check_new_profile()` | profiles AFTER INSERT | Initializes user_stats row + awards pioneer badge. |
| `trg_auto_enroll_batch_group` → `fn_auto_enroll_batch_group()` | profiles AFTER INSERT/UPDATE | Auto-enrolls B2B students into their batch study group by course + institution. |
| `trg_auto_resolve_flashcard_flags` / `trg_auto_resolve_note_flags` → `auto_resolve_content_error_flags()` | flashcards, notes AFTER UPDATE | ⚠️ **Corrected:** auto-**CLEARS** open content_error flags when the author edits the flagged card/note. NOT priority escalation, and NOT on the `content_flags` table (the blueprint previously stated both incorrectly). |
| `trg_notifications_updated_at` → `fn_notifications_set_updated_at()` | notifications BEFORE UPDATE | Maintains updated_at (SECURITY INVOKER). |
| `trg_notify_badge_earned` → `notify_badge_earned()` | user_badges AFTER INSERT | Creates a badge_earned notification. |
| `trigger_update_upvote_counts` → `update_upvote_counts()` | upvotes AFTER INSERT/DELETE | Maintains upvote_count on notes / flashcard_decks (separate from the aaa counter trigger). |

#### Edge Functions (Supabase)

| Function | Trigger | Purpose |
|----------|---------|---------|
| `push-subscribe` | Client call | Saves push subscription to push_subscriptions |
| `push-unsubscribe` | Client call | Soft-deletes subscription |
| `notify-friend-event` | DB trigger | Instant push for friend request/accept |
| `notify-content-created` | pg_cron (4-hour aggregated) | Notify followers of new content |
| `cron-review-reminders` | pg_cron 02:30 UTC daily | Daily review reminder push |
| `cron-daily-study-summary` | pg_cron every 15 min | Nightly 22:00 local-time study summary |

**CRON_SECRET** is shared by all pg_cron-triggered Edge Functions. JWT Verification disabled on all Edge Functions — auth handled via `x-cron-secret` header inside each function.

#### RLS Summary

All tables have RLS enabled. Key patterns:
- **Students:** CRUD on own rows only (`user_id = auth.uid()`)
- **Public content:** `visibility = 'public'` for SELECT
- **Friends content:** `visibility = 'friends'` + friendship check
- **Professor/Admin:** content management + analytics
- **Super Admin:** SELECT all rows on profiles, notes, flashcards, reviews via role-check subquery
- **Unauthenticated pages (NotePreview, DeckPreview, GroupJoin):** MUST use SECURITY DEFINER RPCs — direct table queries return 0 rows for anon users

> **✅ RESOLVED (Phase 5 S4, 2026-07-01).** `Home.jsx` no longer issues any direct anon table reads — the `profiles` role-count reads and the `flashcards`/`notes` public-count reads were deleted. `get_platform_stats()` now returns `public_flashcards`/`public_notes` alongside the existing totals (SQL: `docs/database/phase5/13`, **✅ deployed 2026-07-01**). `Home.jsx` has zero direct `.from()` calls as of this sprint.

---

### 1.5 Routes & Screens

| Route | Component | File | Auth |
|-------|-----------|------|------|
| `/` | Home.jsx | `src/pages/Home.jsx` | Public (redirects to /dashboard if logged in) |
| `/login` | Login.jsx | `src/pages/auth/Login.jsx` | Public |
| `/signup` | Signup.jsx | `src/pages/auth/Signup.jsx` | Public |
| `/forgot-password` | ForgotPassword.jsx | `src/pages/auth/ForgotPassword.jsx` | Public |
| `/reset-password` | ResetPassword.jsx | `src/pages/auth/ResetPassword.jsx` | Public (email link) |
| `/terms-of-service` | TermsOfService.jsx | `src/pages/TermsOfService.jsx` | Public |
| `/privacy-policy` | PrivacyPolicy.jsx | `src/pages/PrivacyPolicy.jsx` | Public |
| `/note/:noteId` | NotePreview.jsx | `src/pages/public/NotePreview.jsx` | Public (SECURITY DEFINER) |
| `/deck/:deckId` | DeckPreview.jsx | `src/pages/public/DeckPreview.jsx` | Public (SECURITY DEFINER) |
| `/join/:token` | GroupJoin.jsx | `src/pages/public/GroupJoin.jsx` | Public (SECURITY DEFINER) |
| `/guide` | StudentGuide.jsx | `src/pages/guide/StudentGuide.jsx` | Public |
| `/educators` | Educators.jsx | `src/pages/public/Educators.jsx` | Public (SECURITY DEFINER RPC — zero direct `.from()`) |
| `/dashboard` | Dashboard.jsx | `src/pages/Dashboard.jsx` | Auth |
| `/dashboard/notes` | BrowseNotes.jsx | `src/pages/dashboard/Content/BrowseNotes.jsx` | Auth |
| `/dashboard/notes/new` | NoteUpload.jsx | `src/pages/dashboard/Content/NoteUpload.jsx` | Auth |
| `/dashboard/notes/:id` | NoteDetail.jsx | `src/pages/dashboard/Content/NoteDetail.jsx` | Auth |
| `/dashboard/notes/edit/:id` | NoteEdit.jsx | `src/pages/dashboard/Content/NoteEdit.jsx` | Auth |
| `/dashboard/my-notes` | MyNotes.jsx | `src/pages/dashboard/Content/MyNotes.jsx` | Auth |
| `/dashboard/my-contributions` | MyContributions.jsx | `src/pages/dashboard/Content/MyContributions.jsx` | Auth |
| `/dashboard/flashcards` | MyFlashcards.jsx | `src/pages/dashboard/Content/MyFlashcards.jsx` | Auth |
| `/dashboard/flashcards/new` | FlashcardCreate.jsx | `src/pages/dashboard/Content/FlashcardCreate.jsx` | Auth |
| `/dashboard/review-flashcards` | ReviewFlashcards.jsx | `src/pages/dashboard/Study/ReviewFlashcards.jsx` | Auth |
| `/dashboard/review-session` | ReviewSession.jsx | `src/pages/dashboard/Study/ReviewSession.jsx` | Auth |
| `/dashboard/review-by-subject` | ReviewBySubject.jsx | `src/pages/dashboard/Study/ReviewBySubject.jsx` | Auth |
| `/dashboard/study` | StudyMode.jsx | `src/pages/dashboard/Study/StudyMode.jsx` | Auth |
| `/dashboard/progress` | Progress.jsx | `src/pages/dashboard/Study/Progress.jsx` | Auth |
| `/dashboard/achievements` | MyAchievements.jsx | `src/pages/dashboard/Profile/MyAchievements.jsx` | Auth |
| `/dashboard/profile/:userId` | AuthorProfile.jsx | `src/pages/dashboard/Profile/AuthorProfile.jsx` | Auth |
| `/dashboard/settings` | ProfileSettings.jsx | `src/pages/dashboard/Profile/ProfileSettings.jsx` | Auth |
| `/dashboard/help` | Help.jsx | `src/pages/dashboard/Help.jsx` | Auth |
| `/dashboard/bulk-upload` | BulkUploadFlashcards.jsx | `src/pages/dashboard/BulkUploadFlashcards.jsx` | Auth (Professor+) |
| `/dashboard/professor-analytics` | ProfessorAnalytics.jsx | `src/pages/dashboard/ProfessorAnalytics.jsx` | Auth (Professor+) |
| `/dashboard/groups` | MyGroups.jsx | `src/pages/dashboard/Groups/MyGroups.jsx` | Auth |
| `/dashboard/groups/new` | CreateGroup.jsx | `src/pages/dashboard/Groups/CreateGroup.jsx` | Auth |
| `/dashboard/groups/:groupId` | GroupDetail.jsx | `src/pages/dashboard/Groups/GroupDetail.jsx` | Auth |
| `/dashboard/find-friends` | FindFriends.jsx | `src/pages/dashboard/Friends/FindFriends.jsx` | Auth |
| `/dashboard/friend-requests` | FriendRequests.jsx | `src/pages/dashboard/Friends/FriendRequests.jsx` | Auth |
| `/dashboard/my-friends` | MyFriends.jsx | `src/pages/dashboard/Friends/MyFriends.jsx` | Auth |
| `/dashboard/following` | Following.jsx | `src/pages/dashboard/Friends/Following.jsx` | Auth |
| `/admin` | AdminDashboard.jsx | `src/pages/admin/AdminDashboard.jsx` | Auth (Admin+) |
| `/admin/analytics` | AdminAnalytics.jsx | `src/pages/admin/AdminAnalytics.jsx` | Auth (Admin+) |
| `/admin/bulk-upload-topics` | BulkUploadTopics.jsx | `src/pages/admin/BulkUploadTopics.jsx` | Auth (Admin+) |
| `/admin/migrate-note-images` | MigrateNoteImages.jsx | `src/pages/admin/MigrateNoteImages.jsx` | Auth — TEMP, pending deletion |
| `/super-admin` | SuperAdminDashboard.jsx | `src/pages/admin/SuperAdminDashboard.jsx` | Auth (super_admin) |
| `/super-admin/analytics` | SuperAdminAnalytics.jsx | `src/pages/admin/SuperAdminAnalytics.jsx` | Auth (super_admin) |
| `/professor/tools` | — | redirect → `/dashboard/bulk-upload` | Auth (legacy redirect only) |

**Dead file:** `src/pages/professor/ProfessorTools.jsx` exists on disk but is not imported or routed anywhere — it is orphaned legacy code pending deletion.
| `/notes/edit/:id` | — | redirect → `/dashboard/notes/edit/:id` | Public (legacy) |

---

### 1.6 Page Inventory

Key pages with data flows:

---

**Dashboard.jsx** (`/dashboard`)
- **Reads:** profiles (own), reviews (due count, streak via `get_user_streak`), study_sessions (`get_study_time_stats`), badges (`get_unnotified_badges`), `get_anonymous_class_stats()`
- **Writes:** profiles (timezone sync on login)
- **UI:** Due cards count, streak, study time, class comparison widget, activity feed, quick actions, goal progress, leaderboard widget

---

**ReviewSession.jsx** (`/dashboard/review-session`)
- **Reads:** flashcards (due cards for current user), reviews (to identify due cards by next_review_date)
- **Writes:** none directly — embeds StudyMode as a component and passes cards via props; StudyMode handles all DB writes
- **UI:** Groups due cards by subject; user picks a subject group to start; hands off to StudyMode component for the actual flip/rate session

---

**MyFlashcards.jsx** (`/dashboard/flashcards`)
- **Reads:** flashcards (own), flashcard_decks (grouped by batch_id display; also fetched separately with `is_featured_on_landing`/`featured_nominated_at` for the Phase 5 S3 curation control, matched to each batch group via the 5-grouping-column join)
- **Writes:** flashcards (delete), flashcard_decks (visibility toggle cascades), `nominate_featured_content` RPC (professor/admin, public decks only) **✅ deployed 2026-07-01**
- **UI:** Cards grouped by batch_id; inline edit; visibility toggle; suspend/skip per card; group header shows `FeatureNominationButton` for public decks when professor/admin

---

**FlashcardCreate.jsx** (`/dashboard/flashcards/new`)
- **Reads:** disciplines, subjects, topics (dropdowns)
- **Writes:** flashcards (INSERT with batch_id, source='manual'; question_type defaults to 'flashcard' — no selector in UI yet)
- **UI:** Front/back text fields, subject/topic dropdowns, image upload. No question_type selector — pending Phase 6 UI work.

---

**BrowseNotes.jsx** (`/dashboard/notes`) **/ ReviewFlashcards.jsx** (`/dashboard/review-flashcards`)
- **Reads:** `get_browsable_notes()` or `get_browsable_decks()` (own + public + friends + group-shared), `get_filtered_authors_for_notes/flashcards()` for author dropdown
- **Writes:** upvotes (toggle), content_group_shares (share to group)
- **UI:** Filter bar (course, subject, topic, author, role), content cards with upvote, share, view buttons

---

**NotePreview.jsx** (`/note/:noteId`) **/ DeckPreview.jsx** (`/deck/:deckId`) **/ GroupJoin.jsx** (`/join/:token`) — public share pages
- **Reads:** `get_public_note_preview()` / deck equivalent / `get_group_preview()` — ALL via SECURITY DEFINER RPC (no direct table access)
- **Writes:** None (unauthenticated) or join group (authenticated)
- **UI:** Blurred content preview with signup CTA, two-color RevisOp wordmark, brand amber/navy colors

---

**ProfessorAnalytics.jsx** (`/dashboard/professor-analytics`)
- **Reads:** `get_batch_group_member_stats(p_group_id)` (security gate: role must be professor+)
- **UI:** Recharts bar charts with #f59e0b amber fill; member table with streak, weekly reviews, study time; "Needs Attention" card (always visible — NEVER conditionally hidden)

---

**StudyMode.jsx** (`/dashboard/study` — also used as an embedded component by ReviewSession)
- **Dual role:** Standalone page at `/dashboard/study` (receives cards via searchParams) AND a reusable component imported by ReviewSession (receives cards via props). Same file serves both.
- **Reads:** flashcards (via props or searchParams deck query), reviews (existing SRS state per card)
- **Writes:** reviews (INSERT if first review, UPDATE if existing — explicit SELECT → IF → ELSE), study_sessions (INSERT on session complete with local session_date)
- **UI:** Flip card with TTS (SpeakButton + SpeechSettings); Hard/Medium/Easy rating; FlagButton for content errors; ContentPreviewWall for preview-mode limit; session stats summary on completion; supports `previewMode` param (limits to 10 cards for non-enrolled users)

**ProfileSettings.jsx** (`/dashboard/settings`)
- **Reads:** profiles (own)
- **Writes:** profiles (full_name, institution, daily goals via update_daily_goal RPC)
- **UI:** Name, institution fields; daily review goal and study time goal inputs

**StudentGuide.jsx** (`/guide`)
- **Reads:** None (static content)
- **UI:** Onboarding guide for new students — explains SRS, how to create flashcards, etc.

**Educators.jsx** (`/educators`) — Phase 5 Sprint 5, ✅ deployed 2026-07-01; Sprint 6 addition ✅ deployed 2026-07-02
- **Reads:** None (static value-proposition content)
- **Writes:** `submit_institute_inquiry()` RPC (SECURITY DEFINER, anon-callable); Sprint 6 adds `submit_educator_application()` RPC (same anon-callable pattern) — zero direct `.from()` on either form, per the unauthenticated-page rule
- **UI:** Institute benefits (mirrors the "For Institutes & Educators" copy on `Home.jsx`) + lead form (institute name, contact name, email, WhatsApp, city, course, message). Success state: "We'll reach out within 1–2 business days." Reuses `ContentPreviewWall.jsx`'s form/validation pattern (WhatsApp country-code normalization, trim-and-validate). **Sprint 6:** second, clearly-labeled "Apply to Teach on RevisOp" section below it — full name, WhatsApp, email, institute (optional), credential-or-LinkedIn URL, course(s) taught, why (optional). Same success copy. On submit, an anonymous applicant's browser stores the RPC's returned `ref_token` into `localStorage['revisop_access_ref']` so a same-browser signup later auto-links via the extended `link_access_request`.

**AdminDashboard.jsx** (`/admin`) **/ SuperAdminDashboard.jsx** (`/super-admin`)
- **Reads:** `get_user_activity_stats()`, profiles (all), flashcards (all), notes (all via super_admin RLS), reviews (all), content_flags, admin_audit_log, `get_pending_featured_nominations()` + `get_live_featured_content_admin()` (Phase 5 S3) **✅ deployed 2026-07-01**, `access_requests` (all — `select('*')` now includes `request_type`/`message`, Phase 5 S5) **✅ deployed 2026-07-01**
- **Writes:** profiles (role change, suspend), admin_audit_log (INSERT on every action), `approve_featured_nomination` / `reject_featured_nomination` / `unfeature_content` RPCs (Phase 5 S3) **✅ deployed 2026-07-01**; Sprint 6 adds `approve_educator_application` / `reject_educator_application` RPCs **✅ deployed 2026-07-02**
- **UI:** "Needs Review" content flag card (always visible), "Landing Page Content" section (Pending Nominations + Currently Live tables, both always-visible with zero-state — Phase 5 S3), user management table, stats cards. Access Requests tab (Phase 5 S5): Type badge (Institute/Student) + filter (All/Student Access/Institute Inquiries); institute rows show institute name + city/message in a "Details" column and a "Lead — follow up" label instead of the signup-link/Grant-Access UI (no approval action for institute leads). **Sprint 6 (✅ deployed 2026-07-02):** adds an "Educator Applications" filter + purple "Educator" badge; educator rows show institute/credential-or-why/course in the Details column, a read-only status badge (bypasses the generic pending/contacted/enrolled/dismissed dropdown, which must never touch educator_application rows since it would skip the role-grant RPCs), and Approve/Reject buttons whose outcome renders as "Educator role granted ✓", "Awaiting signup" (+ copyable signup link, reusing the existing `/signup?ref=` mechanism), or "Rejected".

---

### 1.7 Component Library

#### Layout (`src/components/layout/`)
| Component | Purpose |
|-----------|---------|
| Navigation.jsx | Orchestrator — composes desktop + mobile nav; shown only when logged in |
| NavDesktop.jsx | Desktop nav with dropdown menus |
| NavMobile.jsx | Mobile hamburger + Radix Sheet slide-in |
| ActivityDropdown.jsx | Bell icon with notification list + inline accept/decline for group invites |
| FriendsDropdown.jsx | Friends icon with pending request count + inline accept/decline |
| ProfileDropdown.jsx | Avatar dropdown with profile links |
| CourseSwitcher.jsx | Switches active course context (multi-course support for professors) |
| PageContainer.jsx | Width wrapper (full/medium/narrow prop) used on all dashboard pages |

#### Dashboard Widgets (`src/components/dashboard/`)
| Component | Purpose |
|-----------|---------|
| ActivityFeed.jsx | Recent content from last 7 days |
| AnonymousStats.jsx | "You vs Class" comparison (min 5 users privacy gate) |
| LeaderboardWidget.jsx | Friends + Following tabs ranked by weekly reviews |
| GoalProgressWidget.jsx | Daily review + study time goals with ring progress |
| OnboardingModal.jsx | First-login welcome modal (controlled by `has_seen_onboarding` on profile) |
| StudyTimerWidget.jsx | Manual study session timer — writes to study_sessions on stop |

#### Flashcard Components (`src/components/flashcards/`)
| Component | Purpose |
|-----------|---------|
| FlashcardCard.jsx | Single card display (used in MyFlashcards deck view) |
| SpeakButton.jsx | TTS button for reading card text aloud |
| SpeechSettings.jsx | TTS voice and rate settings panel |

**Note:** FlashcardCreate, MyFlashcards, and StudyMode are full pages, not shared components — see Routes section.

#### Content Components (`src/components/content/`)
| Component | Purpose |
|-----------|---------|
| FeatureNominationButton.jsx | 3-state control (nominate / pending review / featured ✓) for the Phase 5 S3 curation gate. Used on public decks (MyFlashcards.jsx group header) and public notes (NoteDetail.jsx header actions) by professors/admins. Calls `nominate_featured_content` RPC. **✅ Backend deployed 2026-07-01 (`docs/database/phase5/09–11`).** |

#### Progress Components (`src/components/progress/`)
| Component | Purpose |
|-----------|---------|
| PlatformHeatmap.jsx | Activity heatmap (amber/navy color scale post-rebrand) |
| StudyHeatmap.jsx | Study session heatmap |
| SubjectMasteryTable.jsx | Per-subject mastery breakdown table |

#### Badge Components (`src/components/badges/`)
| Component | Purpose |
|-----------|---------|
| BadgeIcon.jsx | Maps icon_key to Lucide icons |
| BadgeCard.jsx | Badge display with per-badge privacy toggle |
| BadgeToast.jsx | Toast notification for newly earned badge |

#### Notifications (`src/components/notifications/`)
| Component | Purpose |
|-----------|---------|
| PushPermissionBanner.jsx | Banner prompting user to enable push notifications |

#### Other Components
| Component | Location | Purpose |
|-----------|----------|---------|
| GuideInfoModal.jsx | `src/components/` | Contextual intro tooltip on public share pages (GroupJoin, NotePreview, DeckPreview) |
| FlagButton.jsx | `src/components/ui/` | Content reporting button (triggers content_flags insert) |
| ContentPreviewWall.jsx | `src/components/ui/` | Blurred paywall-style preview for unauthenticated users |
| UpvoteButton.jsx | `src/components/ui/` | Polymorphic upvote toggle (notes + flashcard_decks) |
| SearchableSelect.jsx | `src/components/ui/` | Combobox with search (used in subject/topic dropdowns) |

#### UI Primitives (shadcn/ui, `src/components/ui/`)
`alert, button, card, command, dialog, dropdown-menu, input, label, popover, progress, select, sheet, switch, tabs, textarea, toast, toaster`

**Phase 5 S1 additions (presentational, brand-token-styled):**
- `StudyItemCard` — prop-driven deck/study-set list card (title, subject/topic chips, item count, author, optional Featured/Expert badge, optional lucide icon, optional `onClick`). No data fetching.
- `FlipCard` — controlled 3D flip (`isFlipped` prop) with front=question / back=answer faces. No SRS/rating logic (deferred to a later study-flow sprint). Backed by `@layer utilities` flip helpers in `index.css` (reduced-motion aware).

---

### 1.8 Utility Libraries & Hooks

#### Libraries
| File | Purpose |
|------|---------|
| `src/lib/supabase.js` | Supabase client (singleton). Always import as `import { supabase } from '@/lib/supabase'`. |
| `src/lib/utils.js` | `cn()` utility (clsx + tailwind-merge) |

#### Contexts
| File | Purpose |
|------|---------|
| `src/contexts/AuthContext.jsx` | Auth state, user profile, role helpers, `updateUserTimezone()` |
| `src/contexts/CourseContext.jsx` | Active course selection for multi-course professors; wraps entire app via `CourseContextProvider` |

#### Hooks (all in `src/hooks/`)
| File | Purpose |
|------|---------|
| `useRole.js` | Role check helpers (isAdmin, isProfessor, etc.) |
| `useNotifications.js` | Realtime notification subscription + unread count badge |
| `useFriendRequestCount.js` | Realtime pending friend request count |
| `useActivityFeed.js` | Recent content feed for dashboard ActivityFeed widget |
| `useBadges.js` | Badge data fetching + unnotified badge check |
| `usePushNotifications.js` | Push notification permission request + subscription management |
| `useSpeech.js` | TTS (text-to-speech) for flashcard audio reading. **Critical study-engine logic:** `splitIntoChunks()` splits card text on sentence boundaries (`/(?<=[.!?\n])\s+/`) and speaks each chunk sequentially. This is a deliberate workaround for the **Chrome/Edge ~15-second `speechSynthesis` cutoff bug** that silently truncates long utterances. Do NOT refactor to a single `speak(fullText)` call — long cards will cut off mid-sentence. Falls back to the whole string as one chunk when no punctuation is found. |
| `use-toast.js` | shadcn toast hook |

**Deleted hooks (no longer in codebase):**
- `useOCR.js` — Tesseract.js OCR hook, deleted as dead code. Package `tesseract.js` may still be in `package.json` — pending removal.

---

### 1.9 Data Flow Diagram

```
User action (browser)
  │
  ├─ Direct table query (.from('table').select()/insert()/update()/delete())
  │    └─ RLS filter applies → user sees only their own + permitted rows
  │
  ├─ RPC call (supabase.rpc('function_name', args))
  │    └─ SECURITY DEFINER → function runs as DB owner → can bypass RLS
  │    └─ Used for: cross-user aggregates, unauthenticated public pages, complex joins
  │
  └─ Realtime subscription (supabase.channel().on('INSERT'...))
       └─ notifications table → bell badge updates in real time

Push notification flow:
  User action (new card/note/friend) → Edge Function → push_subscriptions → Web Push API → device

Auth flow:
  signUp() → email confirmation → auth.users INSERT → handle_new_user() trigger → profiles INSERT
  (no client session during email confirmation → trigger required)

Date handling (CRITICAL):
  All date comparisons use new Date().toLocaleDateString('en-CA') — user's local timezone
  session_date stored as local date (not UTC) — critical for India users after 6:30 PM UTC
```

---

### 1.10 Key Relations Map

```
auth.users (Supabase managed)
  └─► profiles (1:1 via handle_new_user trigger)
        ├─► notes (user_id)
        ├─► flashcards (user_id, creator_id)
        ├─► reviews (user_id)
        ├─► study_sessions (user_id)
        ├─► friendships (user_id ↔ friend_id — bidirectional)
        ├─► follows (follower_id → followee_id — unilateral)
        ├─► study_groups (created_by)
        ├─► study_group_members (user_id)
        ├─► user_badges (user_id)
        ├─► user_stats (user_id)
        ├─► notifications (user_id)
        └─► admin_audit_log (admin_id, target_user_id)

flashcards
  ├─► reviews (flashcard_id) — SRS state per student
  ├─► flashcard_decks (5-column join, NOT deck_id)
  └─► content_creators (content_creator_id) — revenue attribution

disciplines → subjects → topics (taxonomy hierarchy)
  └─ Referenced by notes and flashcards for content organization

study_groups
  ├─► study_group_members (group_id)
  └─► content_group_shares (group_id) → notes or flashcard_decks

content_group_shares
  └─ Deleting group cascades to shares but NOT to original notes/decks
```

---

### 1.11 DB Cleanup Backlog & Landmines

Objects that **exist in the live database** but are wrong, duplicated, dead, or dangerous. Verified Jun 29, 2026 via `information_schema` / `pg_catalog` introspection. **Read this before writing any pivot migration** — these are the items most likely to cause silent failures.

#### 🔴 Landmines — resolve in the DB before the pivot

| # | Issue | Evidence | Required action |
|---|-------|----------|-----------------|
| 1 | ✅ **RESOLVED (Jun 30, 2026)** — duplicate profile-creation triggers on `auth.users` | Both `on_auth_user_created → handle_new_user()` AND `trg_create_profile_on_signup → fn_create_profile_on_signup()` fired AFTER INSERT. Root cause: the same orphaned-profile bug was fixed twice (Mar 19 + Mar 20, 2026); the second fix added a duplicate without dropping the first. `handle_new_user` fired first (alphabetical) and won; the second was a silent no-op (both have `ON CONFLICT DO NOTHING`). | **DONE:** dropped trigger `on_auth_user_created` + function `handle_new_user`; kept `fn_create_profile_on_signup` (referenced by app code at AuthContext.jsx). Verified one trigger remains + end-to-end signup creates a correct profile. |
| 2 | **`is_public` is load-bearing, not vestigial** | `notes` public-read RLS uses only `is_public = true` (ignores `visibility`); `flashcards` uses `is_public = true OR visibility = 'public'`. | Rewrite these RLS policies to use `visibility` BEFORE dropping `is_public`. Never drop it first. |
| 3 | ✅ **RESOLVED (Jun 30, 2026)** — overloaded RPCs → PostgREST ambiguity | `delete_notification` and `mark_single_notification_read` each existed as `(uuid)` and `(uuid, uuid)`. Frontend calls only the single-arg `(p_notification_id)` versions. | **DONE:** dropped the unused `(uuid, uuid)` overload of each + `NOTIFY pgrst, 'reload schema'`. Verified one signature each remains. |

**Newly found (Jun 30, 2026) — `profiles` blocks user deletion.** `profiles.id → auth.users.id` is `ON DELETE NO ACTION`, while **every other** user-referencing FK (notes, flashcards, reviews, follows, upvotes, study_sessions, comments) is `ON DELETE CASCADE`. Result: deleting a user from the Supabase Auth dashboard fails ("Database error deleting user") until the `profiles` row is manually deleted first. **Candidate fix:** change to `ON DELETE CASCADE` — but FIRST audit what FK-references `profiles(id)`, so the cascade doesn't hit a downstream `NO ACTION` blocker (same class of problem, one level down). Workaround until then: delete the `profiles` row, then the `auth.users` row.

#### 🟡 Dead / orphaned objects — safe to drop, but actively misleading

| # | Object | Why it's dead |
|---|--------|---------------|
| 4 | `trg_check_badge_flashcard_create`, `trg_check_badge_note_upload`, `trg_check_badge_review`, `trg_check_badge_upvote` | Functions exist but NO trigger is wired to them. The live badge triggers use the `fn_badge_check_*` family instead. |
| 5 | `notify_friend_request`, `notify_friend_accepted`, `notify_content_upvoted` | Trigger-functions with no attached trigger. Notifications are created via RPC / Edge Functions, not these. |
| 6 | `comments` table | RLS-enabled (2 policies referencing `notes.is_public`) but zero frontend `.from('comments')` usage. Likely Sprint-0 dead table. |

#### 🟢 Undocumented legacy columns — present, low-risk, do not rely on

| # | Column(s) | Note |
|---|-----------|------|
| 7 | `notes.course`, `notes.subject`, `notes.topic` | Legacy free-text, superseded by FK + `custom_*`. |
| 8 | `upvotes.note_id` | Legacy, superseded by polymorphic `content_type` + `target_id`. |
| 9 | `profiles.access_request_ref`, `profiles.updated_at` | Real and used (`access_request_ref` by `link_access_request`); were just undocumented. |

#### Type inconsistencies to watch in migrations

- **SRS columns diverge across tables:** `flashcards.ease_factor` (numeric, **vestigial**) vs `reviews.easiness` (double precision, **live**); `flashcards.repetitions` vs `reviews.repetition`; `flashcards.next_review` (timestamptz, vestigial) vs `reviews.next_review_date` (date, live). Always read SRS state from `reviews`.
- **`friendships` and `content_creators`** use `timestamp WITHOUT time zone` for created_at/updated_at; every other table uses `timestamptz`.

#### 🔵 Supabase Advisor findings (surfaced Jun 30, 2026)

From Supabase Dashboard → Advisors → Security. Distinct from the landmines above (these are platform-flagged), but in the same "who can see what" territory — **relevant before the landing-page pivot exposes content to anonymous visitors.**

| Severity | Finding | Detail | Action |
|----------|---------|--------|--------|
| ✅ **RESOLVED (Jun 30, 2026)** — was 🔴 CRITICAL | `vw_study_items` was a **SECURITY DEFINER view with `SELECT` granted to `anon` + `authenticated`** → **actively exposed**: anyone with the public anon key could call `/rest/v1/vw_study_items` via PostgREST and read all flashcards (incl. private), bypassing RLS. Frontend never queried it; sole consumer is `get_anonymous_class_stats` (SECURITY DEFINER). *(Corrects an earlier note here that wrongly said it wasn't leaking.)* | **DONE:** `REVOKE ALL … FROM anon, authenticated` + `ALTER VIEW … SET (security_invoker = on)`. Verified: only `postgres`/`service_role` retain SELECT; `reloptions = security_invoker=on`; consumer RPC unaffected (runs as owner, still bypasses RLS internally). |
| 🟡 Sev 3 | ~80 functions flagged **"Function Search Path Mutable"** | Functions without a fixed `search_path` are a hardening gap (privilege-escalation vector, especially for SECURITY DEFINER functions). | Batch hardening: `ALTER FUNCTION … SET search_path = ''` (or a fixed schema). Prioritize SECURITY DEFINER functions. Non-blocking for the pivot. |

#### Verification provenance

This section and all §1.1 column/type/trigger corrections were reconciled against four read-only introspection queries (`[DIAGNOSTIC] Full Column Dump`, `All Triggers`, `All Functions + Signatures`, `All RLS Policies`) run in the Supabase SQL Editor on 2026-06-29. Re-run them after any schema change to keep this blueprint authoritative. **Still unverified (low-risk):** owner-only RLS policies on `user_badges` / `user_stats` / `user_activity_log`.

---

## Part 2 — Original vs Revised: What Changed

### 2.1 Planned vs Built

| Planned | Built | Status |
|---------|-------|--------|
| Phase 0: Core SRS (flashcards + reviews) | ✅ Shipped Dec 2025 | Complete |
| Phase 1: Social (friends, visibility) | ✅ Shipped Jan 2026 | Complete |
| Phase 1B: Notifications, nav redesign | ✅ Shipped Feb 2026 | Complete |
| Phase 1C: Class stats (anonymous) | ✅ Shipped Jan 2026 | Complete |
| Phase 1D: Upvotes, decks | ✅ Shipped Jan 2026 | Complete |
| Phase 1E: Achievement badges | ✅ Shipped Jan 2026 | Complete |
| Phase 2: Study groups + push notifications | ✅ Shipped Feb–Mar 2026 | Complete |
| Phase 3: Study sessions, goals, leaderboard | ✅ Shipped Mar 2026 | Complete |
| Phase 4: Author profiles, analytics | ✅ Shipped Apr 2026 | Complete |
| Phase 5: Push notification infra | ✅ Shipped May 2026 | Complete |
| Phase 6: Multi question types — DB schema | ✅ Schema columns added Jun 2026 | Backend only |
| Phase 6: Multi question types — Create UI | 🔲 FlashcardCreate has no question_type selector | Pending |
| Phase 6: Multi question types — Bulk upload | 🔲 CSV template has no new columns | Pending |
| Phase 6: Multi question types — Study mode rendering | 🔲 StudyMode renders MCQ/T-F/etc differently | Pending |
| Rebrand: Recall → RevisOp | ✅ Shipped Jun 2026 | Complete |
| Revenue/billing system | 🔲 Not started | Planned Phase 3+ |
| JEE/NEET expansion | 🔲 Not started | Post-beta |
| PostHog analytics integration | 🔲 Listed in Privacy Policy, not in code | Next sprint |
| Sentry error tracking | 🔲 Listed in Privacy Policy, not in code | Next sprint |
| Creator self-onboarding dashboard | 🔲 Not started | Phase 3+ |

---

### 2.2 Schema Changes Beyond Original Plan

1. **`batch_id` on flashcards** (Dec 2025): Added after discovering that toggling visibility merged unrelated card groups. Each manual card gets a unique batch_id; bulk uploads share one.

2. **`contributed_by` + `creator_id`** (Jan 2026): Originally one attribution field. Split into creator_id (who uploaded) and contributed_by (professor for attribution) because revenue and display attribution need to be independent.

3. **`visibility` replaces `is_public`** (Jan 2026): Original boolean was too limiting — "friends-only" sharing was a strong user request. Three-tier system (private/friends/public) required a text column with CHECK constraint.

4. **`flashcard_decks` as auto-maintained table** (Jan 2026): Originally planned as a simple tag/group. Discovered that joins on 5 columns instead of a FK was required because `deck_id` on flashcards was never populated (legacy issue). Trigger-maintained card_count avoids COUNT(*) on every page load.

5. **`follows` separate from `friendships`** (Sprint 3.4): Originally only bidirectional friendships. Added unilateral follow graph for professor tracking and leaderboard visibility without requiring mutual acceptance.

6. **`study_sessions` with local date** (Sprint 3.1): Originally planned to use UTC timestamps. Discovered that UTC midnight creates "wrong day" issues for India users after 6:30 PM IST. `session_date` stores user's local date as text.

7. **`question_type` + 9 content columns** (Sprint 6): Originally flashcards was pure front/back. Expanded to 10 question types to support MCQ, case studies, concept cards, match-the-following, etc. `concept_card` items excluded from SRS metrics.

8. **`profile_courses`** (Sprint 3): Multi-course support for professors. `profiles.course_level` kept as primary course for backward compatibility; `is_primary = TRUE` synced via `setPrimaryCourse()`.

---

### 2.3 Features Added Beyond Phases

- **Card suspension and skip system** (Feb 2026): Not in original scope. Added after students reported frustration with cards they wanted to defer without deleting.
- **Content flags** (Mar 2026): Not planned. Added after professors reported student-submitted typos/errors in public content with no way to report them.
- **Batch study groups** (Mar 2026): B2B-specific group type that auto-enrolls enrolled students by `batch_course + batch_institution`. Enables founder's offline class to have an automatic study group.
- **Gemini import source** (`source='gemini_import'`): Not planned. Added to support AI-assisted card creation workflow.
- **Leaderboard** (Sprint 3.5): Not planned. Added after students informally compared streaks — structured competitive view increased engagement.
- **Professor multi-course** (`profile_courses` table): Not planned. Added when one professor teaches multiple CA levels.
- **GuideInfoModal**: Contextual intro modals on public share pages (GroupJoin, NotePreview, DeckPreview) — added to reduce drop-off on landing from shared links.

---

### 2.4 Design Decisions

1. **SuperMemo-2 quality 1/3/5 (not 0-5)**: Odd numbers only. 2 and 4 are too subtle a distinction. Three options (Hard/Medium/Easy) match CA exam preparation mental model.

2. **`session_date` as local date string**: Stores user's local date as YYYY-MM-DD text rather than UTC timestamp. Prevents "wrong day" bugs for India users who study late at night.

3. **No incomplete session rows in DB**: Abandoned sessions live in localStorage only. DB stores only completed sessions — prevents garbage in analytics and avoids complex cleanup queries.

4. **`trg_aaa_*` naming convention**: Counter triggers are named to fire alphabetically before `trg_badge_*` — badge triggers read user_stats counters that the aaa triggers maintain.

5. **Two-column wordmark (not logo)**: Brand identity is pure typography — `Revis` in amber (#f59e0b) + `Op` in navy (#1e1b4b). No icon. Scales to any size, renders sharp on all devices, no SVG complexity.

6. **`bg-background` as universal page background**: Login, Signup, ForgotPassword, ResetPassword, NotePreview, DeckPreview, GroupJoin all use the shadcn `bg-background` CSS variable (white). Ensures brand consistency.

7. **SECURITY DEFINER for all public share pages**: Unauthenticated visitors cannot hit RLS-protected tables. All data for public pages flows through SECURITY DEFINER RPCs regardless of how simple the query looks.

8. **Email confirmation ON → trigger for profile creation**: With email confirmation enabled, `signUp()` returns no session. Client-side profile INSERT is blocked by RLS. The `handle_new_user()` trigger fires at DB level regardless of session state.

---

### 2.5 Scope Explicitly Dropped

- **Per-role JWT session timeouts** (12h super_admin / 24h admin / 7d student): Supabase does not support per-role expiry. One global JWT expiry applies to all roles. Design was aspirational, never implemented.
- **Resend (transactional email)**: Was in original stack. Removed when Google Workspace SMTP was configured in Supabase — eliminating one paid dependency.
- **Tesseract.js OCR in production**: Package installed, `useOCR.js` hook deleted as dead code. OCR is not actively used. Package may still be in `package.json` — pending cleanup.
- **`MigrateNoteImages.jsx`**: Temporary admin page for image migration (base64 → Storage). Migration complete Jun 2026 — page pending deletion.
- **`is_public` boolean on notes and flashcards**: ⚠️ **NOT safely removable.** A `visibility` text column was added, but the RLS migration was never completed: `notes` public-read RLS keys SOLELY on `is_public = true` (ignores `visibility`), and `flashcards` uses `is_public = true OR visibility = 'public'`. Dropping `is_public` today would break all public notes. The RLS policies must be rewritten to use `visibility` FIRST. See §1.11 landmine #2.

---

## Part 3 — Decision Map & Future Work

### 3.1 Decision Log

**D-01: batch_id for grouping flashcards**
- **What:** Each INSERT gets a `batch_id` UUID (single card = unique UUID, bulk = shared UUID). Display groups by batch_id, never by timestamp.
- **Why:** Toggling visibility from private→public was merging cards from different sessions into one visual group because they shared the same timestamp range.
- **Impact:** All deck display code must group by batch_id. Any SQL that groups by created_at for deck display is wrong.

**D-02: Reviews table as SRS single source of truth**
- **What:** SRS state (easiness, interval, repetition, next_review_date) lives exclusively in `reviews`, not on `flashcards`.
- **Why:** Original design wrote SRS state to `flashcards` — but flashcards are professor-owned, causing RLS failures when students tried to update them.
- **Impact:** `StudyMode.jsx` does explicit SELECT → IF EXISTS UPDATE → ELSE INSERT (not UPSERT) for clarity. Column names: `easiness` (not `easiness_factor`), `repetition` (not `repetitions`), `created_at` (not `reviewed_at`).

**D-03: SECURITY DEFINER triggers for profile creation**
- **What:** Profile creation on signup uses a DB trigger (`handle_new_user`), not a client INSERT.
- **Why:** Email confirmation ON means signUp() returns no session. auth.uid() is null. Any client-side profiles INSERT is silently blocked by RLS.
- **Impact:** Never add client-side profile INSERT code. Always use the trigger path.

**D-04: 5-column join for deck membership**
- **What:** To find flashcards in a deck, join on: user_id, subject_id, topic_id, custom_subject, custom_topic. Do NOT use `WHERE fc.deck_id = fd.id`.
- **Why:** `deck_id` on the `flashcards` table was never populated — it always returns 0 rows. The column exists as a legacy artifact.
- **Impact:** Every SQL query that fetches cards for a deck must use the 5-column join pattern.

**D-05: Local date for session_date and streak**
- **What:** `session_date` stored as user's local date string. Streak calculated in user's local midnight.
- **Why:** India is UTC+5:30. After 6:30 PM UTC, `CURRENT_DATE` at the server is already "tomorrow." A student who studies at 10 PM IST would have their session credited to the next day if UTC was used.
- **Impact:** Frontend always passes `new Date().toLocaleDateString('en-CA')`. Never use `toISOString()` for date comparisons.

**D-06: concept_card exclusion from SRS metrics**
- **What:** Cards with `question_type = 'concept_card'` are excluded from all review metrics (Items Reviewed, Items Mastered, accuracy, streak).
- **Why:** Concept cards are reference material (cheat sheets, summaries) — not meant to be "reviewed" with hard/medium/easy ratings.
- **Impact:** Every RPC that counts reviews or calculates accuracy must include `WHERE question_type != 'concept_card'` or use the `vw_study_items` safety view.

**D-07: trigger_update_deck_card_count is the ONLY counter writer**
- **What:** `card_count` on `flashcard_decks` is maintained exclusively by the `trigger_update_deck_card_count` trigger.
- **Why:** A Feb 2026 bug was caused by the frontend also incrementing `card_count` manually after INSERT, resulting in 2x counts. Adding a second trigger (wrong fix attempt) also caused 2x.
- **Impact:** Before adding any trigger on `flashcards`, run: `SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema='public' AND event_object_table='flashcards'`. Use broad scan (not just event_object_table filter alone).

**D-08: Rebrand localStorage keys**
- **What:** 6 localStorage keys renamed from `recall_*` prefix to `revisop_*`.
- **Why:** Brand migration Recall → RevisOp.
- **Old keys:** `recall_access_ref`, `recall_session_started_at`, `recall_session_source`, `recall-push-banner-dismissed`, `recall-tts-voice-uri`, `recall-tts-rate`
- **Impact:** Fallback reads currently exist in code. One sprint after full rollout, remove fallback reads and old key writes.

**D-09: Complete localStorage inventory (naming is NOT consistent)**
- **What:** Full inventory of every active localStorage key in the code. The rebrand (D-08) only renamed the 6 `recall_*` keys — **3 other active keys were never part of that scheme and use different naming conventions.**
- **Why documented:** A pivot/migration must account for ALL keys, not just the rebranded ones. The inconsistent naming is a real wart.

| Key | Naming style | Owner file | Purpose | Migrated in rebrand? |
|-----|--------------|------------|---------|----------------------|
| `revisop_access_ref` | snake `revisop_` | Dashboard.jsx, Signup.jsx | B2B access-request referral link | ✅ from `recall_access_ref` |
| `revisop_session_started_at` | snake `revisop_` | StudyMode.jsx | In-progress study session start time | ✅ from `recall_session_started_at` |
| `revisop_session_source` | snake `revisop_` | StudyMode.jsx | In-progress session source (`study_mode`/`manual`) | ✅ from `recall_session_source` |
| `revisop-tts-voice-uri` | kebab `revisop-` | useSpeech.js | Saved TTS voice preference | ✅ from `recall-tts-voice-uri` |
| `revisop-tts-rate` | kebab `revisop-` | useSpeech.js | Saved TTS speech rate | ✅ from `recall-tts-rate` |
| `revisop-push-banner-dismissed` | kebab `revisop-` | PushPermissionBanner.jsx | Push-permission banner dismissed flag | ✅ from `recall-push-banner-dismissed` |
| `postAuthRedirect` | camelCase, **no brand prefix** | App.jsx, Login.jsx, StudentGuide.jsx, NotePreview.jsx, DeckPreview.jsx, GroupJoin.jsx | Deep-link target preserved across login/email-confirmation | ❌ never branded |
| `myNotes_viewMode` | camelCase `myNotes_` | MyNotes.jsx | Grid/list view preference on My Notes | ❌ never branded |
| `flashcard_create_draft` | snake, **no brand prefix** | FlashcardCreate.jsx | Auto-save/recovery draft for the card-create form | ❌ never branded |

- **Inconsistency:** Three competing conventions coexist — `revisop_` (snake), `revisop-` (kebab), and unbranded camelCase/snake (`postAuthRedirect`, `myNotes_viewMode`, `flashcard_create_draft`). The last three were never folded into the rebrand and have no `recall_*`/`revisop_*` lineage.
- **Impact:** Any future namespace cleanup or key-migration must enumerate all 9 keys, not the 6 from D-08. The 3 unbranded keys are easy to miss in a `grep recall_`/`grep revisop_` sweep.

---

### 3.2 Pending Work & Roadmap

#### Immediate (next sprint)

| Task | Why | Notes |
|------|-----|-------|
| **PostHog integration** | Listed in Privacy Policy; not in code | Install `posthog-js`; init in `src/main.jsx`; API key from posthog.com |
| **Sentry integration** | Listed in Privacy Policy; not in code | Install `@sentry/react`; init in `src/main.jsx`; DSN from sentry.io |
| **Remove `tesseract.js`** | Dead dependency | Verify no imports; remove from package.json |
| **Delete `MigrateNoteImages.jsx`** | Migration complete | Also remove its route from App.jsx |
| **Delete `ProfessorTools.jsx`** | Dead file — not imported or routed anywhere | `src/pages/professor/ProfessorTools.jsx` |

#### Near-term

| Task | Why |
|------|-----|
| Remove old localStorage key fallback reads | Old `recall_*` keys can be dropped one sprint after full rebrand rollout |
| ~~Delete `public/logo-concepts/` folder~~ | Already gone — folder does not exist |
| Update `docs/reference/DATABASE_SCHEMA.md` header | Still says "RECALL", last updated "Sprint 4.1" |
| Update `docs/active/context.md` | Live URL, email, stack notes still reference Recall/recallapp.co.in |
| FlashcardCreate Data Contract UI | Sprint 6 backlog: enforce question_type-specific required fields in create form |

#### Backlog

| Task | Priority |
|------|----------|
| Billing/subscription system (Razorpay, ₹149/month premium) | High — monetization |
| JEE/NEET/Undergraduate course taxonomy | High — expansion |
| Creator dashboard (Vivitsu revenue tracking) | Medium |
| Student-to-professor self-promotion workflow | Low |

---

### 3.3 Infrastructure Reference

All of the below lives in Supabase Dashboard / Vercel — NOT in code. Update here when changed.

**Email / SMTP**
- Provider: Google Workspace via Supabase SMTP Settings
- From: `hello@revisop.com` | Sender name: RevisOp
- SMTP host: smtp.gmail.com, port 587
- Auth: Google Workspace App Password for `hello@revisop.com` (requires 2-Step Verification ON)
- DNS: SPF, DKIM, DMARC all configured for revisop.com. Email may land in spam during initial reputation period (new domain — reputation builds over weeks).
- Recovery phone: 098207 61284; recovery email: anand@mtcpl.net (Google account recovery for hello@revisop.com)

**Supabase Auth Settings**
- Email confirmation: ON
- Site URL: `https://www.revisop.com`
- Redirect URL whitelist: `https://www.revisop.com/**`
- Password reset email redirect must point to `https://www.revisop.com` (not `recallapp.co.in` or localhost)

**Vercel Domains**
- Primary: `www.revisop.com`
- Old domains redirect to primary: `www.recallapp.co.in`, `recallapp.co.in`, `revisop.com` (apex)

**Supabase Realtime**
- `notifications` table: Realtime replication enabled (Dashboard → Database → Replication)
- If bell icon stops updating live: check this toggle first

**Supabase Secrets**
- `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (= mailto:hello@revisop.com)
- `CRON_SECRET` — shared by all pg_cron-triggered Edge Functions; if rotated, ALL cron jobs must be resynced immediately or they return 401
- `SUPABASE_SERVICE_ROLE_KEY`

**pg_cron Jobs**
- `daily-review-reminders`: `30 2 * * *` (02:30 UTC daily)
- `cron-daily-study-summary`: `*/15 * * * *` (every 15 min)

**Environment Variables (Vercel)**
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_VAPID_PUBLIC_KEY`

---

### 3.4 Brand Identity

**Colors**
- Amber: `#f59e0b` (Tailwind `amber-500`) — primary brand, CTAs, highlights
- Navy: `#1e1b4b` (Tailwind `indigo-950`) — dark text, backgrounds, nav
- Background: `bg-background` (shadcn CSS variable = white/#ffffff) — all auth and public pages

**Wordmark Pattern** (used everywhere a logo appears)
```jsx
<span className="text-2xl font-bold tracking-tight leading-none">
  <span style={{ color: '#f59e0b' }}>Revis</span>
  <span style={{ color: '#1e1b4b' }}>Op</span>
</span>
```

**PWA / Browser**
- `index.html` theme-color: `#1e1b4b` (controls Android browser status bar)
- `public/site.webmanifest` theme_color: `#1e1b4b` (controls installed PWA status bar)
- `short_name`: RevisOp | `name`: RevisOp — CA Study App
- PWA icons: `/android-chrome-192x192.png`, `/android-chrome-512x512.png` (amber + navy)
- Apple touch icon: `/apple-touch-icon.png`
- To see updated PWA icon: uninstall old PWA → reinstall from `www.revisop.com`

**Color Mapping from Rebrand** (for any future reference)
- `bg-blue-*/indigo-*/purple-*` → `bg-amber-*` or `bg-[#1e1b4b]`
- `text-blue-*/indigo-*/purple-*` → `text-amber-*` or `text-[#1e1b4b]`
- Gradient backgrounds → flat `bg-amber-50` or `bg-background`
- Dark buttons → `bg-[#1e1b4b]`
- Recharts bar fill `#6366f1` → `#f59e0b`
- Heatmap blue scale → amber/navy scale
