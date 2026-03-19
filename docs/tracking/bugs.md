# Bug Tracking

## Resolved Bugs

### [Mar 19, 2026] DeckPreview Public Page Shows "Preview (0 of N items)"
- **Symptom:** Public deck URL shared via WhatsApp showed correct deck metadata but 0 preview cards ("Preview (0 of 21 items)"). The ContentPreviewWall appeared but no question cards were visible.
- **Root Cause:** `get_public_deck_preview` fetched flashcards using `WHERE fc.deck_id = p_deck_id`. The `deck_id` column on the `flashcards` table exists as a FK to `flashcard_decks.id` but is **never populated** by any write path. The `update_deck_card_count` trigger (which correctly maintains `card_count`) matches flashcards to decks via 5 grouping columns `(user_id, subject_id, topic_id, custom_subject, custom_topic)` — not by `deck_id`.
- **Fix:** Rebuilt `get_public_deck_preview` to join flashcards to the deck using the same 5 grouping columns the trigger uses.
- **Documentation:** Added critical rule to CLAUDE.md and DATABASE_SCHEMA.md — `deck_id` on flashcards is never populated; always join on grouping columns.
- **Why it wasn't caught earlier:** Was tested in localhost with a different (newer) deck whose creation flow happened to populate `deck_id`; or tested while logged in where the ContentPreviewWall appearing masked the 0-card count.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Groups Page — Professor Course Switch Does Not Update Batch Groups
- **Symptom:** Professor with 3 teaching courses (CA Intermediate primary, CA Foundation + CA Final secondary) saw only the CA Intermediate batch group regardless of which course was selected in the top menu.
- **Root Cause:** `get_my_batch_groups` professor path was returning only batch groups for the professor's primary/teaching courses via a course-name match that had an issue (likely matched only primary). All 3 batch groups were confirmed to exist with correct `batch_course` values matching discipline names exactly.
- **Fix:** Rebuilt professor path in `get_my_batch_groups` to return ALL batch groups. Client-side `activeCourse` filter in `MyGroups.jsx` already correctly handles per-course display — no frontend change needed.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] DeckPreview CTA Misleading for Professor Decks
- **Symptom:** CTA on public DeckPreview page said "Sign up free to study all 21 cards." For professor-created decks, Tier B students after signup only get a 10-card preview — the CTA was a false promise.
- **Root Cause:** CTA copy assumed signup = full access, which is true only for student-created public decks.
- **Fix:** CTA changed to "Start studying on Recall — it's free" with subtext about spaced repetition and progress tracking. Card count no longer mentioned in CTA (it's already visible in the deck header). Accurate for both professor and student decks.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Groups Page Shows No Batch Groups for Admin / Super Admin
- **Symptom:** After creating batch groups, admin and super_admin logins showed no batch groups on the Groups page. Personal groups were visible. Batch groups only visible in Admin Dashboard.
- **Root Cause:** Admin/super_admin accounts had `profile_courses` entries left over from when they were originally created as students and later promoted. `CourseContext` reads `profile_courses` and sets `activeCourse` to the primary teaching course. `MyGroups.jsx` filter: `groups.filter(g => !g.is_batch_group || g.batch_course === activeCourse)` then hid all batch groups whose `batch_course` didn't match that stale `activeCourse`. `get_my_batch_groups` RPC was correctly returning all batch groups server-side, but the client-side filter discarded them.
- **Fix:**
  1. SQL: `DELETE FROM profile_courses WHERE user_id IN (SELECT id FROM profiles WHERE role IN ('admin', 'super_admin'))` — clears stale entries → `activeCourse` falls back to `null` → filter skipped → all batch groups visible
  2. Also nulled `course_level` for admin/super_admin since student course data is irrelevant to their role
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Super Admin User Hard Delete — Profile Silently Not Deleted, Auth Deletion Blocked
- **Symptom:** When super_admin clicked Delete on a user in SuperAdminDashboard, the confirmation completed with no error. But going to Supabase Auth dashboard and trying to delete the auth user showed "Database error deleting user". User remained in the system.
- **Root Cause (stage 1):** `deleteUser` called direct `.delete()` on `profiles` from the client. RLS on profiles has no DELETE policy for super_admin → delete was silently blocked (Supabase returns success with 0 rows affected, no error). Profile was never actually deleted.
- **Root Cause (stage 2):** `admin_audit_log.target_user_id` FK referenced `profiles(id)` with `ON DELETE NO ACTION`. Retained audit log entries (from the deletion attempt itself) prevented the profile row from being deleted even when tried manually. And without the profile being deleted, auth user deletion failed due to `profiles.id → auth.users(id)` FK.
- **Fix:**
  1. `ALTER TABLE admin_audit_log` FK changed to `ON DELETE SET NULL` — audit records retained with `target_user_id = null`; user details preserved in `details` JSONB
  2. Created `admin_delete_user_data(p_user_id uuid)` SECURITY DEFINER RPC — bypasses RLS; deletes all related rows (study_group_members, profile_courses, reviews, flashcards, flashcard_decks, notes, profiles) in correct order
  3. `SuperAdminDashboard.jsx` `deleteUser` — replaced direct cascade deletes with single `rpc('admin_delete_user_data')` call
- **Note:** Auth record (`auth.users`) still requires manual deletion from Supabase dashboard. Automating this requires a service-role Edge Function (planned future sprint).
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Profile Creation Silently Fails for All New Signups (9 Orphaned Accounts)
- **Symptom:** Auth users existed in `auth.users` but had no corresponding row in `profiles`. These users could not log in or use the app. 9 affected accounts discovered via `SELECT u.id FROM auth.users u LEFT JOIN profiles p ON p.id = u.id WHERE p.id IS NULL`.
- **Root Cause:** `signUp()` with Supabase email confirmation ON returns no session (user must verify email first). `AuthContext.jsx` then attempted `supabase.from('profiles').insert()` with `auth.uid() = null` → RLS INSERT policy requires `id = auth.uid()` → INSERT silently blocked. No error thrown (code used `console.warn` and continued). Auth user was created; profile was not.
- **Why earlier users were unaffected:** Email confirmation was ON from Day 1. Investigation ongoing — likely a code path change in AuthContext around mid-March caused the direct insert to be reached after the RLS policy was added (Mar 12 RLS sprint).
- **Fix:**
  1. Created `handle_new_user()` SECURITY DEFINER trigger on `auth.users` AFTER INSERT — creates profile from `raw_user_meta_data` at DB level regardless of session state
  2. Bulk backfill: `INSERT INTO profiles SELECT ... FROM auth.users LEFT JOIN profiles WHERE profiles.id IS NULL`
- **Lesson added to CLAUDE.md:** When enabling RLS on a table, audit every existing INSERT path. Any write that must succeed without a client session (signup, email confirmation flows) MUST use a SECURITY DEFINER trigger or RPC.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] ContentPreviewWall Form Submission — HTTP 400 (Two Separate Causes)
- **Symptom:** Submitting the WhatsApp lead capture form returned HTTP 400. Form appeared to submit but nothing was saved.
- **Root Cause 1:** `access_requests.status` and `requested_at` columns had no DEFAULT values. NOT NULL constraint with no DEFAULT → INSERT from RPC failed.
- **Fix 1:** `ALTER TABLE access_requests ALTER COLUMN status SET DEFAULT 'pending', ALTER COLUMN requested_at SET DEFAULT now()`
- **Root Cause 2:** `anon` role lacked EXECUTE permission on `submit_access_request` RPC. SECURITY DEFINER bypasses RLS inside the function but the `anon` role still needs explicit GRANT to call it at all.
- **Fix 2:** `GRANT EXECUTE ON FUNCTION submit_access_request(...) TO anon`
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] DeckPreview Access Request — content_type Check Constraint Violation
- **Symptom:** Submitting the ContentPreviewWall form from a deck preview page returned a check constraint violation error.
- **Root Cause:** `DeckPreview.jsx` passed `contentType = 'deck'` but `access_requests.content_type` CHECK constraint only allows `'flashcard_deck'` and `'note'`.
- **Fix:** Changed `contentType` prop in `DeckPreview.jsx` to `'flashcard_deck'`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Admin/Super Admin Not Receiving Access Request Notifications
- **Symptom:** When a student submitted an access request form, no notification appeared in admin/super admin accounts.
- **Root Cause:** `notify_access_request` function filtered with `WHERE account_type IN ('admin', 'super_admin')`. All profiles have `account_type = 'enrolled'` (or `'self_registered'`). Admin/super admin distinction is stored in the separate `role` column.
- **Fix:** Changed WHERE clause to `WHERE role IN ('admin', 'super_admin')`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Notification INSERT Failing — notifications_type_check Constraint
- **Symptom:** `submit_access_request` RPC failed when trying to insert a notification of type `'access_request'`.
- **Root Cause:** `notifications_type_check` constraint did not include `'access_request'` as an allowed type.
- **Fix:** Dropped and recreated constraint adding `'access_request'` to the allowed values array.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] User Management Tab Shows Empty List
- **Symptom:** Admin Dashboard → User Management tab showed no users despite 141+ accounts existing.
- **Root Cause:** `fetchUsers` query selected `status` column which did not exist on the `profiles` table. Supabase returned an error which was caught silently → empty list rendered.
- **Fix:** `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended'))`
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Blank Course Dropdown in ReviewFlashcards + BrowseNotes
- **Symptom:** For users enrolled in a course that has no public content yet (e.g. CA Final student Aaryaman More), the Course filter dropdown showed a blank selected value instead of "All Courses".
- **Root Cause:** Filter defaulted to the user's `course_level` but no content existed for that course, so the dropdown option was never populated — blank option was selected.
- **Fix:** Frontend fix to default to "All Courses" when the user's course has no content in the available options.
- **Status:** ✅ RESOLVED

### [Mar 15, 2026] Progress Page "All My Content" Shows Subjects from Non-Enrolled Courses
- **Symptom:** A student enrolled in CA Intermediate saw "Business Laws" (a CA Foundation subject) in their Subject Mastery table on the "All My Content" tab, with 0 reviews and 201 total cards. Similarly, a CA Foundation student saw CA Intermediate subjects.
- **Root Cause:** "All My Content" tab passed `courseLevel={null}` to `get_subject_mastery_v1` and `get_question_type_performance`. The RPCs interpret `null` as "no course filter" → return all public cards across all courses. With 659 total public cards spread across CA Foundation, Intermediate, and Final, any student saw every subject in the system.
- **Fix:** Added `allTabCourseLevel` computed value in `Progress.jsx`. Logic: if user has exactly 1 enrolled course (`courseOptions.length === 1`), scope "All My Content" to that course. Professors with 2+ teaching courses remain unscoped (`null`) — they legitimately own content across all courses.
- **No SQL changes required** — frontend-only fix.
- **Status:** ✅ RESOLVED — commit pending

### [Mar 13, 2026] Progress Page Tabs Broken — Both Tab Contents Always Visible
- **Symptom:** Clicking "All My Content" / "Course: CA Intermediate" tabs had no effect (cursor changed to pointer but nothing happened). Full report appeared twice on the page — once for "All" and once for "Course".
- **Root Cause:** `src/components/ui/tabs.jsx` is a custom stub — `Tabs`, `TabsList`, `TabsTrigger`, `TabsContent` are plain `<div>`/`<button>` elements with no `value`/`onValueChange` wiring and no show/hide logic. Both `TabsContent` elements always rendered. `TabsTrigger` click events were swallowed (no `onClick` passed through).
- **Fix:** Removed `Tabs`/`TabsContent`/`TabsList`/`TabsTrigger` usage from `Progress.jsx`. Replaced with direct conditional rendering: `{tab === 'all' && <div>...</div>}` / `{tab === 'course' && <div>...</div>}`. Tab buttons call `setTab()` directly.
- **Note:** `tabs.jsx` stub remains as-is (other pages may use it or not). The fix is isolated to `Progress.jsx`.
- **Status:** ✅ RESOLVED — commit `eed55c0`



### [Mar 12, 2026] Ghost Empty Flashcard Decks Accumulating
- **Symptom:** `flashcard_decks` rows with `card_count = 0` visible to professors in Contributions view; appear as empty deck entries.
- **Root Cause:** `update_deck_card_count` trigger decremented `card_count` with `GREATEST(card_count - 1, 0)` on DELETE but never deleted the deck row when count reached 0.
- **Contributing factor:** Previous bug (Excel drag-fill) created many single-card decks with wrong topic names; when those cards were fixed/deleted, decks were left orphaned at 0.
- **Fix:** Added `DELETE FROM flashcard_decks WHERE ... AND card_count = 0` after the UPDATE in the trigger's DELETE branch. Two pre-existing empty decks deleted manually.
- **Status:** ✅ RESOLVED (DB trigger fix only)

### [Mar 12, 2026] RLS Enabled on Profiles Broke Entire App (Recursive Policy Cascade)
- **Symptom:** After enabling RLS on `profiles`, `subjects`, `topics`, `content_creators`: super admin saw "Access Denied", all students' dashboards showed "new user" state, professor contributions and progress showed zeros.
- **Root Cause:** 25 policies across 13 tables all used `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = ...)` or similar direct subqueries against `profiles`. When `profiles` itself gained RLS, these cross-table references evaluated under RLS context — the policies became recursive and errored. Cascading effects:
  - `useRole.js`: on `profileError`, defaults role to `'student'` — everyone downgraded
  - `Dashboard.jsx`: review/note/flashcard count queries error → undefined treated as 0 → "new user" state
  - `Progress.jsx`: reviews query errors → 0 progress shown
- **Fix:** Created `is_super_admin()` and `is_admin()` as `SECURITY DEFINER` functions (bypass RLS). Dropped and recreated all 25 affected policies using these functions instead of inline subqueries. Added INSERT policy on profiles for new signups.
- **Status:** ✅ RESOLVED (DB-only fix)

### [Mar 11, 2026] Bulk Upload Silently Created Custom Topics (Excel Drag-Fill Artefacts)
- **Reported by:** Professor (bulk upload of Companies Act flashcards; Excel auto-incremented "The Companies Act, 2013" to 2014–2033 across rows)
- **Symptom:** 20 variations of the topic name ("The Companies Act, 2014" … "2033") stored as `custom_topic`, bypassing the intended validation that bulk upload cannot create new topics.
- **Root Cause:** `uploadFlashcards()` used `custom_topic: card.topic` as a fallback when a topic name wasn't found in the DB, instead of aborting with an error.
- **Data Fix:** SQL `UPDATE flashcards SET topic_id = <correct_id>, custom_topic = NULL WHERE custom_topic LIKE 'The Companies Act, 20%' AND custom_topic != 'The Companies Act, 2013'`
- **Code Fix:** Added a pre-insert validation loop that collects errors for every row with an unrecognised subject or topic, then aborts the upload and shows per-row error messages. `custom_subject` and `custom_topic` are now always `null` in bulk inserts.
- **Status:** ✅ RESOLVED

### [Mar 6, 2026] Blank Study Screen for Student-Created Decks with No Topic
- **Reported by:** CA Foundation student (Shriya Sundaram), Safari on iPhone
- **Symptom:** Self-created flashcard deck visible in Review Flashcards browse page, but clicking it shows "No flashcards to study / No flashcards found for this selection". Cards accessible from My Contributions page.
- **Affected users:** All students who created flashcards without selecting a topic (systemic, not user-specific).
- **Root Cause (confirmed by DB query):** Topic is optional in `FlashcardCreate`. When skipped, both the `flashcard_decks` and `flashcards` rows get `topic_id = null`, `custom_topic = null`. The `get_browsable_decks` RPC returns `"General"` as a fallback `topic_name` for null-topic decks. `ReviewFlashcards.startStudySession` puts this label into the URL as `?topic=General`. `StudyMode` then filters ALL cards (including 78 professor cards) for `topics.name = "General"` OR `custom_topic = "General"` — matching nothing. Result: 0 cards for every user clicking such a deck.
- **Why CA Intermediate student unaffected:** All his cards have `topic_id` properly set via FK. Topic string matching succeeds. He also has one latent null-topic deck (`cca04e35`, 2 cards) that would exhibit the same bug if clicked.
- **Solution:**
  1. Topic made mandatory in `FlashcardCreate` (validation + label)
  2. Individual deck clicks now navigate with `?deck=<uuid>` instead of `?topic=<name>`; `StudyMode` filters by `card.deck_id` when `deck` param present
  3. Null-topic nudge banner in `MyFlashcards` + `handleSaveGroupInfo` now updates `flashcard_decks` record
  4. Topic made required in `MyFlashcards` Edit Info dialog
- **Status:** ✅ RESOLVED

### [Mar 6, 2026] RPC Returns 0 Results — Ambiguous Column "id" (Error 42702)
- **Files:** `get_browsable_decks` v3, `get_browsable_notes` v3
- **Symptom:** After deploying the course-aware v3 RPCs, Review Flashcards and Browse Notes showed 0 results for all students despite correct data in the DB. Browser console showed HTTP 400 with `kode: "42702"`, `message: "column reference \"id\" is ambiguous"`, `details: "It could refer to either a PL/pgSQL variable or a table column."`
- **Root Cause:** Both functions are declared as `RETURNS TABLE(id UUID, ...)`. PostgreSQL treats output column names as PL/pgSQL variables inside the function body. The profile lookup query `WHERE id = v_user_id` was ambiguous — PostgreSQL couldn't determine whether `id` referred to the `RETURNS TABLE` output variable or the `profiles.id` column.
- **Why it wasn't caught at compile time:** `CREATE OR REPLACE FUNCTION` succeeded without error; PostgreSQL only raises 42702 at runtime when the ambiguous column reference is evaluated.
- **Solution:** Qualify the column with the table name: `WHERE profiles.id = v_user_id` in both v3 functions.
- **Lesson:** In PL/pgSQL functions using `RETURNS TABLE(id ...)`, always qualify any SQL column named `id` with its table alias/name to avoid runtime ambiguity.
- **Status:** ✅ RESOLVED



### [Mar 5, 2026] Duplicate Friend Request/Accepted Notifications
- **Location:** DB — triggers on `friendships` table
- **Symptom:** Every friend request and acceptance generated two notification entries in the bell icon — one with no title (e.g. just "Aayodh Inamke sent you a friend request") and one with a proper title ("New Friend Request" / message). Affected all users.
- **Root Cause:** Two undocumented DB triggers (`trg_notify_friend_request` on INSERT, `trg_notify_friend_accepted` on UPDATE) called `create_notification()` directly at the DB level, creating a null-title notification row ~1 second before the frontend's `notifyFriendEvent()` Edge Function call created the proper titled row. Both pathways active simultaneously.
- **Why triggers didn't show initially:** First diagnostic query filtered `WHERE event_object_table = 'friendships'` but missed them; the broader `trigger_schema = 'public'` query revealed them.
- **Solution:** Dropped both triggers (`DROP TRIGGER IF EXISTS trg_notify_friend_request ON friendships` and `trg_notify_friend_accepted ON friendships`). Deleted all existing null-title duplicate rows (`DELETE FROM notifications WHERE type IN ('friend_request','friend_accepted') AND title IS NULL`). Edge Function remains sole notification path.
- **Status:** ✅ RESOLVED (DB-only fix, no code changes)

### [Mar 5, 2026] Student Cannot Filter to Study Only Own Cards
- **File:** `ReviewFlashcards.jsx`
- **Symptom:** A student with only private flashcard decks could not see their own name in the Author dropdown. Even switching the Role filter to "Student" did not surface them. Students had no way to study exclusively their own cards without professor cards mixing in.
- **Root Cause:** `get_filtered_authors_for_flashcards()` RPC inner-joins `flashcard_decks fd` and filters `fd.visibility = 'public'`. Authors with only private (`is_public = false`) decks are excluded from the result set entirely.
- **Solution:** Added a hardcoded "My Cards (Private & Public)" `SelectItem` pinned at the top of the Author dropdown with `value={user.id}`. No DB changes needed — StudyMode already fetches the current user's private cards via the visibility OR clause (`user_id.eq.${user.id}`) and applies `card.user_id === authorParam` correctly for any UUID.
- **Status:** ✅ RESOLVED

### [Mar 5, 2026] StudyMode Mixes Cards from All Authors + Ignores Review History
- **Files:** `ReviewFlashcards.jsx`, `StudyMode.jsx`
- **Symptom (Bug 1):** When a student filtered by a specific professor in ReviewFlashcards and clicked "Study All", the session showed all visible cards for the subject — including the student's own cards — not just the professor's. Studying a professor's deck of ~30 cards would show 50+ cards.
- **Root Cause (Bug 1):** `startStudySession()` built the URL with only `subject` and `topic` params; `filterAuthor` was never forwarded. `StudyMode.fetchFlashcards` had no author filter.
- **Solution (Bug 1):** `startStudySession()` now appends `author=<userId>` when `filterAuthor !== 'all'`. `StudyMode` reads this param and filters `card.user_id === authorParam` after the visibility fetch.
- **Symptom (Bug 2):** Exiting a session partway through and returning would reload all cards from scratch (including those already reviewed that session). No way to "continue from where you left off".
- **Root Cause (Bug 2):** `fetchFlashcards` had no awareness of the user's `reviews` table — every session was stateless and returned the full matching card set.
- **Solution (Bug 2):** Added a second query fetching `reviews` for the candidate card IDs. Cards are excluded if `status = 'suspended'`, `next_review_date > today`, or `skip_until > today`. Cards with no review record (first-time/new) are always included — no cold-start problem. Equivalent to LEFT JOIN WHERE r.id IS NULL OR next_review_date <= today.
- **Status:** ✅ RESOLVED

### [Mar 4, 2026] Subject Dropdown Not Filtered by Course in Study Section
- **Files:** `ReviewFlashcards.jsx`, `BrowseNotes.jsx`
- **Symptom:** Selecting "CA Foundation" in the Course filter still showed subjects from all courses (e.g., CA Intermediate subjects) in the Subject dropdown.
- **Root Cause:** `availableSubjects` was built from all decks/notes at initial load and never recomputed when `filterCourse` changed. Topic dropdown cascaded correctly from Subject, but Course→Subject cascade was never implemented.
- **Solution:** Added `allSubjectsFrom*` state storing `{name, course}` pairs. New `useEffect` (mirroring the existing topic cascade pattern) filters `availableSubjects` when `filterCourse` changes and auto-resets `filterSubject` if it's no longer valid (which then cascades to reset topics).
- **Status:** ✅ RESOLVED

### [Mar 2, 2026] CA Foundation Flashcards Invisible in Study Page and Author Profile
- **Files:** DB only (`update_deck_card_count` trigger function)
- **Symptom:** CA Foundation flashcards visible in My Contributions (flashcard count) but absent from Study Page course filter, deck list, and Author Profile flashcard counts/links. Notes for CA Foundation were unaffected.
- **Root Cause:** `update_deck_card_count()` trigger only ran `UPDATE flashcard_decks SET card_count = card_count + 1 WHERE ...`. When flashcards were bulk-uploaded and no matching `flashcard_decks` row existed, the UPDATE matched 0 rows and silently did nothing — no deck row was ever created. Both `get_browsable_decks` RPC (Study Page) and `get_author_content_summary` RPC (Author Profile) query `flashcard_decks`, not the `flashcards` table directly. My Contributions used a direct `COUNT(*) FROM flashcards` query, which is why the count was visible there but nowhere else.
- **Why notes were unaffected:** Notes don't use a separate aggregation table — they are queried directly from `notes` table in all contexts.
- **Solution:** Changed trigger function to UPDATE-then-INSERT: attempts `UPDATE card_count + 1`; if `NOT FOUND` (no deck row yet), inserts a new `flashcard_decks` row with `card_count = 1`, `target_course`, and `visibility` from the new flashcard row. One-time backfill ran to create missing deck entries for already-uploaded CA Foundation flashcards.
- **Prevention:** The trigger now self-heals for all future courses and all insertion paths (single card, bulk upload, professor tools). No manual SQL needed for new courses.
- **Status:** ✅ RESOLVED

### [Feb 20, 2026] Activity Feed "View" Button — Invalid UUID Error
- **Files:** `ActivityFeed.jsx`
- **Issue:** Clicking "View" on any note in the Dashboard Recent Activity section showed "Page Not Found" with Supabase error "invalid input syntax for type uuid: 'undefined'"
- **Root Cause:** `ActivityFeed.jsx` accessed `activity.content_id` for both the React key and the navigate call, but the `get_recent_activity_feed` RPC returns the note/deck UUID as `id` (consistent with all other RPCs in the codebase). `activity.content_id` was always `undefined`, so the URL became `/dashboard/notes/undefined`.
- **Solution:** Changed `activity.content_id` → `activity.id` in two places: the `handleActivityClick` navigate call and the `key` prop on the activity row.
- **Status:** ✅ RESOLVED

### [Feb 24, 2026] card_count Double-Counting in flashcard_decks — FULLY RESOLVED
- **Files:** `FlashcardCreate.jsx`, `flashcard_decks` table, `flashcards` table
- **Issue:** Study mode showed ~2x actual card count (e.g., 46 shown when 23 created). Recurred after initial fix attempt.
- **True Root Cause:** `trigger_update_deck_card_count` (existing DB trigger) was already correctly maintaining `card_count`. The frontend was ALSO manually incrementing it — double-counting on every save.
- **Feb 12 mis-fix:** Removed frontend increment (correct) but added a second trigger `flashcards_count_trigger` (wrong) — replaced app+trigger with trigger+trigger. Issue recurred identically.
- **Feb 24 final fix:**
  1. Dropped `flashcards_count_trigger` (the duplicate added Feb 12)
  2. SQL recalculated all `card_count` values from actual `flashcards` rows
  3. `trigger_update_deck_card_count` remains as sole source of truth
- **Frontend:** No `card_count` logic in `FlashcardCreate.jsx`. New decks insert with `card_count: 0`.
- **Prevention rule:** Before adding any DB trigger, always run: `SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = '<table>';`
- **Status:** ✅ RESOLVED (final)

### [Feb 9, 2026] Flashcard Deck Names Missing in Share Content Dialog
- **Files:** GroupDetail.jsx
- **Issue:** Share Content dialog showed "Flashcard Deck" for every deck instead of actual subject/topic names, making it impossible to identify which deck to share
- **Root Cause:** `fetchUserContent()` query selected `custom_subject, custom_topic` but NOT `subject_id, topic_id`. The subject name lookup used `d.subject_id` which was always `undefined` (never fetched). Topic names were never looked up at all.
- **Solution:** Added `subject_id, topic_id` to the select query. Added topic name lookup from `topics` table. Created `display_topic` field. Updated display to show "Subject - Topic".
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Groups Link Not Working on Production Vercel — Duplicate HTML in index.html
- **Files:** index.html
- **Issue:** Groups navigation link worked on localhost but refreshed to Dashboard on production Vercel. Hard refresh and browser restart did not help.
- **Root Cause:** `index.html` had duplicate HTML structure — lines 24-29 were a copy of lines 18-23 (`</head>`, `<body>`, `<div id="root">`, `<script>`, `</body>`, `</html>`). This created two `<div id="root">` elements in the DOM. Vite's dev server was forgiving, but the production build copied the malformed HTML into `dist/index.html`, confusing React Router's client-side navigation.
- **Solution:** Removed duplicate lines 24-29 from `index.html`. Rebuilt to verify clean `dist/index.html`.
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Blank Page — NavDesktop/NavMobile Missing Props
- **Files:** NavDesktop.jsx, NavMobile.jsx
- **Issue:** App rendered blank white page after adding notification props to ActivityDropdown
- **Root Cause:** `deleteNotification` and `refetchNotifications` were passed from Navigation.jsx but never destructured in NavDesktop/NavMobile prop definitions
- **Console Error:** `Uncaught ReferenceError: deleteNotification is not defined at NavDesktop (NavDesktop.jsx:203:11)`
- **Solution:** Added `deleteNotification` and `refetchNotifications` to prop destructuring in both components
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Notifications RPC Fails — `column n.title does not exist`
- **Files:** SQL 14 (notification RPCs), SQL 25 (fix)
- **Issue:** `get_recent_notifications` RPC returned 400 error
- **Root Cause:** `notifications` table pre-existed from Phase 1B with different schema (no `title`, `metadata`, `is_read` columns). `CREATE TABLE IF NOT EXISTS` in SQL #13 skipped creation.
- **Solution:** SQL #25 — `ALTER TABLE` to add missing columns + backfill title from message
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Ambiguous `group_id` in `get_pending_group_invites`
- **Files:** SQL 19, SQL 25 (fix)
- **Issue:** MyGroups page error: `column reference "group_id" is ambiguous`
- **Root Cause:** Subquery `WHERE group_id = sg.id` conflicted with `RETURNS TABLE` which also declares `group_id`
- **Solution:** Aliased subquery table as `sub`: `WHERE sub.group_id = sg.id`
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Invitation Fails — `notifications_type_check` Constraint Violation
- **Files:** SQL 26 (fix)
- **Issue:** `invite_to_group()` failed with `new row for relation "notifications" violates check constraint "notifications_type_check"`
- **Root Cause:** Existing CHECK constraint on `type` column only allowed original types, not `group_invite`
- **Solution:** SQL #26 — DROP and recreate constraint with `group_invite` added
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] React Key Warning — Pending Invitations in GroupDetail
- **Files:** GroupDetail.jsx
- **Issue:** Console warning: `Each child in a list should have a unique "key" prop`
- **Root Cause:** JSX used `invite.id` but SQL returns `invite.membership_id` as the field name
- **Solution:** Changed `key={invite.id}` → `key={invite.membership_id}` (and matching cancel/disable refs)
- **Status:** ✅ RESOLVED

### [Feb 5, 2026] Back Button Navigates to Dashboard Instead of Previous Page
- **Files:** NoteDetail.jsx, ReviewBySubject.jsx, ReviewSession.jsx
- **Issue:** Back button always went to `/dashboard` even when user came from another page (e.g., Browse Notes)
- **Root Cause:** Hardcoded `navigate('/dashboard')` instead of browser history navigation
- **Solution:** Changed to `navigate(-1)` with fallback: `if (window.history.length > 1) { navigate(-1) } else { navigate('/dashboard') }`
- **Status:** ✅ RESOLVED

### [Feb 5, 2026] Subject and Topic Filters Are Independent
- **Files:** MyNotes.jsx, MyFlashcards.jsx, BrowseNotes.jsx, ReviewFlashcards.jsx
- **Issue:** Selecting a Subject did not filter the Topic dropdown - users could select topics unrelated to subject
- **Root Cause:** Topic dropdown was populated with all available topics regardless of subject selection
- **Solution:** Added useEffect that filters `availableTopics` based on `filterSubject` selection, resets topic if not in filtered list
- **Status:** ✅ RESOLVED

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
