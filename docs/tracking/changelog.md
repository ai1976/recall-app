# Changelog

---
## [2026-02-24] feat: add WebP upload support for notes

### Changed
- **`NoteUpload.jsx`** — Added `image/webp` to `validTypes` array and `<input accept>` attribute. WebP files pass through the same `browser-image-compression` pipeline (maxSizeMB: 0.5, maxWidthOrHeight: 1920). Files already under 500KB and 1920px (e.g. pre-optimised professor mindmaps from XnConverter at WebP lossy 85%) are passed through untouched — no re-compression quality loss.
- **`NoteUpload.jsx`** — Upload hint text updated to include WebP: "JPG, PNG, WebP (auto-compressed to ~500KB) or PDF (max 10MB)".

### Files Changed
- `src/pages/dashboard/Content/NoteUpload.jsx`

---
## [2026-02-23] Fix: Note image compression limits raised for diagram readability

### Changed
- **`NoteUpload.jsx`** — Compression limits raised from `maxSizeMB: 0.2 / maxWidthOrHeight: 1200` to `maxSizeMB: 0.5 / maxWidthOrHeight: 1920`. Reason: at 1200px and 200KB, text-heavy mindmaps and complex diagrams could become illegible (small text nodes blurred by heavy JPEG compression). 1920px gives ~60% more pixels; 500KB budget allows ~70%+ quality at that resolution. PDFs remain the best option for extremely detailed diagrams. Flashcard image limits unchanged (simpler images, 0.2/1200 still appropriate).
- **`NoteUpload.jsx`** — Upload hint text updated: "auto-compressed to ~200KB" → "auto-compressed to ~500KB".

### Files Changed
- `src/pages/dashboard/Content/NoteUpload.jsx`

---
## [2026-02-23] Push Notifications — Daily Review Reminder Cron

### Added
- **`supabase/functions/cron-review-reminders/index.ts`** (NEW) — Scheduled Edge Function for daily 08:00 IST (02:30 UTC) review reminders. Queries `reviews` for cards due today (`status = 'active'`, `next_review_date <= today`, `skip_until IS NULL OR <= today`). Aggregates due count per user, checks `push_notification_preferences.review_reminders` preference, sends one push with fixed tag `review-reminder` (browser-level dedup). Secured via `x-cron-secret` header.
- **`CRON_SECRET`** set as Supabase project secret (32-byte random hex). Deployed the function.
- **pg_cron schedule** — SQL provided to register `daily-review-reminders` job (`cron.schedule` + `net.http_post`). Must be run in Supabase SQL Editor.

### Files Changed
- `supabase/functions/cron-review-reminders/index.ts` (NEW)

---
## [2026-02-23] Docs: Data Migration Architecture Rules

### Added
- **`docs/active/context.md`** — New "Rule #7: Data Migration Architecture Rules" section under "Critical Rules & Patterns". Documents:
  - Pre-migration checklist: measure data budget with `pg_size_pretty(SUM(pg_column_size(...)))` before writing any migration query.
  - PostgreSQL TOAST storage behaviour table: `IS NOT NULL` = safe (reads null-flag only), `LIKE 'data:%'` = dangerous (decompresses every row).
  - Two-phase fetch pattern: SELECT IDs first (`IS NOT NULL`, no TOAST load) → fetch one row at a time by primary key.
  - React migration component pattern: `src/pages/admin/MigrateXxx.jsx` with `@/lib/supabase`, progress log, re-run safety (`upsert: true`), and self-deletion after success.
  - Supabase free plan limits table: 500 MB DB, 5 GB egress/month, separate Disk IO Budget. Documents "EXCEEDING USAGE LIMITS" throttling behaviour and that no query tuning helps — only billing cycle reset unblocks.

- **`docs/active/now.md`** — Added "2026-02-23 Session" notes: TOAST mechanics, two-phase fix, billing throttle diagnosis, Disk IO Budget behaviour, and the core lesson ("scale assumption failure" — quantify bytes before writing migrations).

### Root Cause Documented
The Feb 2026 flashcard migration required 3 iterations because neither the developer nor the AI assistant calculated data volume upfront. `LIKE 'data:%'` on a 167-row TOAST TEXT column triggered ~92 MB of decompression per query. Additionally, the project had exceeded the Supabase free plan 5 GB egress limit, causing DB throttling that made even simple COUNT queries time out. Both failure modes are now documented as architectural rules to prevent recurrence.

### Files Changed
- `docs/active/context.md`
- `docs/active/now.md`

---
## [2026-02-22] Egress Optimisation — Flashcard Image Storage Fix + Migration Tool

### Added
- **`src/pages/admin/MigrateFlashcards.jsx`** (NEW, TEMPORARY) — One-time admin utility at `/admin/migrate-flashcards`. Fetches all flashcards where `front_image_url` or `back_image_url` starts with `data:`, uploads each to `flashcard-images` Storage bucket under `migrated/` prefix (upsert:true, safe to re-run), updates DB row with Storage URL. Processes in batches of 3. Shows progress bar, per-card terminal log (colour-coded), and success card prompting self-deletion after migration is confirmed.
- **`FlashcardCreate.jsx`** — `uploadingImage` state (`{ index, side } | null`) for per-card upload spinner. `X` lucide icon for image removal. `imageCompression` import (`browser-image-compression`).

### Changed
- **`FlashcardCreate.jsx`** — `handleImageUpload` converted from sync FileReader base64 to async compress → upload pipeline: `imageCompression` (`maxSizeMB: 0.2`, `maxWidthOrHeight: 1200`, `useWebWorker: true`) → upload to `flashcard-images` bucket under `{userId}/{timestamp}-{side}-{index}.{ext}` → store public Storage URL. EXIF rotation handled automatically.
- **`FlashcardCreate.jsx`** — Flashcard state shape: `frontImage/backImage` (base64 strings) → `frontImageUrl/frontImagePreview/backImageUrl/backImagePreview` (Storage URL + `URL.createObjectURL()` preview).
- **`FlashcardCreate.jsx`** — `addFlashcard()` uses new state shape.
- **`FlashcardCreate.jsx`** — `removeFlashcard()` now calls `URL.revokeObjectURL()` on both preview URLs before removing card (memory leak prevention).
- **`FlashcardCreate.jsx`** — `handleSubmit` flashcard insert: `card.frontImage/backImage` → `card.frontImageUrl/backImageUrl`.
- **`FlashcardCreate.jsx`** — Front + back image JSX: spinner during upload, "Add Image" → "Change Image" label after upload, ×-button on preview thumbnail to clear image (revokes ObjectURL, nulls both URL fields).
- **`App.jsx`** — Added `MigrateFlashcards` import and `/admin/migrate-flashcards` route. Route comment map updated.

### Files Changed
- `src/pages/admin/MigrateFlashcards.jsx` (NEW)
- `src/pages/dashboard/Content/FlashcardCreate.jsx`
- `src/App.jsx`

---
## [2026-02-22] Egress Optimisation — Lazy Loading + Load More + Image Compression

### Added
- **`BrowseNotes.jsx`** — `NOTES_PER_PAGE = 10` module-level constant. `visibleCount` state (default 10). Render computes `flatFiltered` (flat array from all filtered groups), slices to `visibleCount`, regroups via existing `groupNotesBySubject()`. "Load More" button appends next 10; resets to 10 on any filter change. Groups remain intact as notes are appended.
- **`BrowseNotes.jsx`** — `loading="lazy"` + `decoding="async"` attributes on all note `<img>` tags. Off-screen images not fetched until scrolled into view.
- **`BrowseNotes.jsx`** — `bg-gray-100` on image button wrapper — visible grey placeholder while lazy image loads, prevents CLS.
- **`NoteUpload.jsx`** — `compressing` state. `handleFileChange` made async. Image files compressed via `browser-image-compression` (`maxSizeMB: 0.2`, `maxWidthOrHeight: 1200`, `useWebWorker: true`) before storing in state. EXIF rotation handled automatically by the library. Fallback to original file on compression error.
- **`NoteUpload.jsx`** — Upload label: `htmlFor` unlinked + `cursor-wait opacity-75` during compression (prevents double file-picker open). Spinner + "Compressing image…" shown in upload area.

### Changed
- **`NoteUpload.jsx`** — Upload hint text updated: "JPG, PNG (auto-compressed to ~200KB) or PDF (max 10MB)".

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Content/NoteUpload.jsx`

---
## [2026-02-22] Push Notifications — P1 PWA Foundation + P4 Frontend Wiring (COMPLETE)

### Added
- **`public/sw.js`** — Service worker. Handles `push` event (shows notification, respects `renotify`/`silent`), `notificationclick` (focuses open tab or opens `/dashboard`), minimal install/activate with `skipWaiting` + `clients.claim`.
- **`src/lib/notifyEdge.js`** — Two fire-and-forget helpers: `notifyContentCreated(payload)` and `notifyFriendEvent(payload)`. Fetch the user's JWT from `supabase.auth.getSession()`, POST to the deployed Edge Functions. Errors silently logged; never throw.
- **`src/hooks/usePushNotifications.js`** — Hook managing push subscription lifecycle. Detects support, iOS detection, standalone mode, current `Notification.permission`, existing subscription via `pushManager.getSubscription()`. Exports `subscribe()` (register SW → requestPermission → subscribe → POST push-subscribe), `unsubscribe()`, `needsIOSInstall`.
- **`src/components/notifications/PushPermissionBanner.jsx`** — Dismissible banner on Dashboard. `localStorage` key `recall-push-banner-dismissed` prevents re-showing. States: default (Enable button), iOS-not-installed (Add to Home Screen guide), success (auto-dismissed after 2 s).

### Changed
- **`public/site.webmanifest`** — Fixed: `name`, `short_name`, `theme_color: #4f46e5`, `start_url: /dashboard`, `purpose: any maskable` on 512px icon.
- **`src/main.jsx`** — Added SW registration on `window load` (non-blocking).
- **`src/pages/Dashboard.jsx`** — Added `<PushPermissionBanner />` above main content grid.
- **`src/pages/dashboard/Profile/ProfileSettings.jsx`** — Added "Push Notifications" card with enable/disable button, iOS install prompt, denied/unsupported states. Uses `usePushNotifications` hook.
- **`src/pages/dashboard/Content/NoteUpload.jsx`** — Added `notifyContentCreated()` call after successful insert (visibility `public`/`friends` only). Fire-and-forget.
- **`src/pages/dashboard/Content/FlashcardCreate.jsx`** — Same for flashcard deck creates.
- **`src/pages/dashboard/Friends/FindFriends.jsx`** — Added `notifyFriendEvent('friend_request')` after successful send.
- **`src/pages/dashboard/Profile/AuthorProfile.jsx`** — Same for Add Friend button.
- **`src/pages/dashboard/Friends/FriendRequests.jsx`** — Added `notifyFriendEvent('friend_accepted')` after accept. Looks up `user_id` (sender) from `pendingRequests` state before the async call.
- **`src/components/layout/FriendsDropdown.jsx`** — Same accept notification from nav quick-accept.

### Files Changed
- `public/site.webmanifest`
- `public/sw.js` (NEW)
- `src/main.jsx`
- `src/lib/notifyEdge.js` (NEW)
- `src/hooks/usePushNotifications.js` (NEW)
- `src/components/notifications/PushPermissionBanner.jsx` (NEW)
- `src/pages/Dashboard.jsx`
- `src/pages/dashboard/Profile/ProfileSettings.jsx`
- `src/pages/dashboard/Content/NoteUpload.jsx`
- `src/pages/dashboard/Content/FlashcardCreate.jsx`
- `src/pages/dashboard/Friends/FindFriends.jsx`
- `src/pages/dashboard/Profile/AuthorProfile.jsx`
- `src/pages/dashboard/Friends/FriendRequests.jsx`
- `src/components/layout/FriendsDropdown.jsx`

---
## [2026-02-22] Push Notifications — Phase 3: Edge Functions + Phase 2/4 Prep

### Added
- **`supabase/functions/_shared/supabaseAdmin.ts`** — Shared service-role Supabase client (Deno) for all Edge Functions. `SUPABASE_SERVICE_ROLE_KEY` from Supabase secrets; bypasses RLS.
- **`supabase/functions/_shared/sendPush.ts`** — VAPID web-push utility using `npm:web-push@3.6.7`. `sendPushToUsers(userIds[], payload)` fetches active subscriptions, sends concurrently with `Promise.allSettled`, auto-deactivates 410/404 expired subscriptions.
- **`supabase/functions/push-subscribe/index.ts`** — Saves device push subscription (CORS + JWT auth + upsert on `(user_id, endpoint)`). Creates default `push_notification_preferences` row if missing.
- **`supabase/functions/push-unsubscribe/index.ts`** — Soft-deletes subscription on permission revocation.
- **`supabase/functions/notify-friend-event/index.ts`** — Instant push for `friend_request` / `friend_accepted`. No aggregation. Tag = `friend-{actor_id}`, `renotify: true`.
- **`supabase/functions/notify-content-created/index.ts`** — Update-in-place aggregator. 4-hour window per `(creator_id, content_type)`. Professor public → `professor_content` → students with matching `course_level`. Student/friends → `friend_content` → accepted friends. Bulk INSERT for new users; individual UPDATE for existing (increments `metadata.count`). `renotify: true` for first push, `renotify: false` for silent updates. Push `tag = content-{creator_id}-{content_type}` replaces notifications on device.
- **`push_subscriptions` table** — `(id, user_id, endpoint, p256dh, auth, browser, platform, is_active, created_at, last_used_at)`. UNIQUE(user_id, endpoint), RLS, partial index on `is_active = true`.
- **`push_notification_preferences` table** — `(user_id PK, review_reminders, professor_content, friend_content, group_content, friend_requests, friend_accepted, updated_at)`. All defaults `true`. RLS.

### Changed
- **`notifications` table** — Added `actor_id UUID` (grouping key), `updated_at TIMESTAMPTZ` (sort key). Added trigger `trg_notifications_updated_at`. Rebuilt CHECK constraint to include `professor_content`, `friend_content`, `group_content`, `system_announcement`. New indexes: `idx_notifications_grouping` (partial, unread only), `idx_notifications_updated_at`.
- **`get_recent_notifications` RPC** — Rebuilt (DROP + CREATE required due to new return columns). Added `actor_id`, `updated_at` to RETURNS TABLE. Changed `ORDER BY` from `created_at DESC` → `updated_at DESC`.
- **`get_recent_activity_feed` RPC** — Rebuilt with SQL grouping by `(creator_id, creator_name, creator_role, content_type, DATE(created_at))`. Added `count INTEGER` and `subject TEXT` columns. Fixed missing subjects JOIN (subject was always NULL). Bug fixed: navigation for `flashcard_deck` type now works.
- **`src/hooks/useNotifications.js`** — Added UPDATE Realtime subscription. On UPDATE: refetches notifications to re-sort by `updated_at DESC`. Does not increment `unreadCount`.
- **`src/components/dashboard/ActivityFeed.jsx`** — Grouped rendering: `count > 1` shows "30 notes added" / "View 30". Fixed `content_type === 'deck'` → `'flashcard_deck'` navigation bug. Subject hidden for grouped rows. Author-filtered navigation for grouped clicks.
- **`package.json`** — `"supabase": "^2.76.12"` added to devDependencies (CLI via npm).

### Files Changed
- `supabase/functions/_shared/supabaseAdmin.ts` (NEW)
- `supabase/functions/_shared/sendPush.ts` (NEW)
- `supabase/functions/push-subscribe/index.ts` (NEW)
- `supabase/functions/push-unsubscribe/index.ts` (NEW)
- `supabase/functions/notify-friend-event/index.ts` (NEW)
- `supabase/functions/notify-content-created/index.ts` (NEW)
- `src/hooks/useNotifications.js`
- `src/components/dashboard/ActivityFeed.jsx`
- `package.json`

---
## [2026-02-21] Phase A: Professor Multi-Course — Teaching Areas + Course Context Switcher

### Added
- **`src/contexts/CourseContext.jsx`** (NEW) — React context managing `teachingCourses` (from `profile_courses` table) and `activeCourse` (session-only string). Exposes `addCourse(disciplineId)`, `removeCourse(profileCourseId)`, `setPrimaryCourse(id, name)`. `setPrimaryCourse` writes both `profile_courses.is_primary` and `profiles.course_level` (backward compat constraint). Runs for all users; relevant data only populated for `professor/admin/super_admin`.
- **`src/components/layout/CourseSwitcher.jsx`** (NEW) — Compact indigo pill dropdown rendered in the navigation bar. Session-only course switcher for professors/admins with 2+ teaching courses. Shows active/primary status. Renders nothing for students or single-course users.

### Changed
- **`src/App.jsx`** — Added `CourseContextProvider` import. Wrapped app tree inside `<CourseContextProvider>` (nested inside `<AuthProvider>`, outside `<BrowserRouter>`).
- **`src/components/layout/NavDesktop.jsx`** — Added `CourseSwitcher` import. Rendered as first element of the right icon section (before FriendsDropdown).
- **`src/components/layout/NavMobile.jsx`** — Added `GraduationCap` icon import and `useCourseContext` import. Added "Course Context" section in the sheet's scrollable nav area (before Study section). Flat tappable rows — no nested dropdowns on mobile.
- **`src/pages/dashboard/Profile/ProfileSettings.jsx`** — Added `useCourseContext` import + `Plus/X/Star/GraduationCap` icon imports. Added Teaching Areas state (`allDisciplines`, `selectedNewCourse`, `addingCourse`, `removingId`, `settingPrimaryId`). Added `useEffect` to fetch active disciplines for professors/admins. Added `handleAddCourse`, `handleRemoveCourse`, `handleSetPrimary` handlers. Added "My Teaching Areas" card (visible only to `isContentCreator`). `courseLoading` from context included in initial loading gate.
- **`src/pages/dashboard/Profile/AuthorProfile.jsx`** — Added `teachingCourses` state. Extracts `profileData?.teaching_courses` from `get_author_profile` RPC response. Profile header now renders indigo chips for all teaching courses (for professors/admins) or falls back to single `course_level` text (for students).
- **`src/pages/Dashboard.jsx`** — Added `useRef` import + `useCourseContext` import. Added `activeCourse` + `isInitialMount` ref. `fetchClassStats` now uses `activeCourse || profile?.course_level`. Added second `useEffect` that watches `activeCourse` and re-fetches class stats on course switch (skips initial mount to prevent double-fetch).

### Database Migration — Run manually in Supabase SQL Editor (SQL provided in chat)

---
## [2026-02-21] UX: Consistent Notes → Flashcards Ordering in Dashboard Quick Actions

### Changed
- **`Dashboard.jsx`** — Quick Actions section: swapped "Create Flashcard" and "Upload Note" cards so create actions follow the same Notes-first order as browse actions. New order: Browse Notes → Browse Flashcards → Upload Note → Create Flashcard.

### Design Decision Documented
- **Notes-first standard:** All sections (Create Menu in nav, Quick Actions, My Contributions) use Notes → Flashcards order. Notes are foundational content; flashcards are derived from them.
- **Study Menu exception:** Intentionally keeps Flashcards-first ("Review Flashcards" → "Browse Notes") because the Study menu is for active spaced-repetition study — reviewing flashcards is the primary action. Browsing notes is passive reference. See `docs/active/now.md` Active Decisions for full rationale.

### Files Changed
- `src/pages/Dashboard.jsx`

---
## [2026-02-21] Fix: Private Badges Showing on Author Profile Page

### Fixed
- **`AuthorProfile.jsx`** — Private badges were visible on the Author Profile page for all viewers including the badge owner. The `get_author_profile` RPC returns all badges (including private) for own-profile views; the frontend was rendering them all with only a cosmetic EyeOff icon on private ones.

### Changed
- Computed `publicBadges = badges.filter(b => b.is_public !== false)` before rendering
- Replaced `badges.map(...)` with `publicBadges.map(...)` in the badge pills section
- Removed the EyeOff indicator inside badge pills (no longer needed — private badges are not shown at all)
- Badge section now only renders if at least one public badge exists

### Files Changed
- `src/pages/dashboard/Profile/AuthorProfile.jsx`

---
## [2026-02-21] Phase 1F - Extended Badge System with Performance Optimizations

### Added
- **`user_stats` table** — Integer counters (total_notes, total_flashcards, total_reviews, total_upvotes_given, total_upvotes_received, total_friends) per user. O(1) badge checks vs O(n) COUNT(*). RLS: users read own row only; all writes via SECURITY DEFINER triggers.
- **5 counter triggers** (`trg_aaa_counter_notes/flashcards/reviews/upvotes/friendships`) — Increment/decrement counters on INSERT/DELETE. Named `trg_aaa_*` to fire before `trg_badge_*` alphabetically.
- **13 new badge definitions** — prolific_writer (5 notes), deck_builder (50 flashcards), subject_expert (20 cards/subject), first_steps (1 review), committed_learner (7-day streak), monthly_master (30-day streak), early_bird (5-7 AM review), century_club (100 reviews), review_veteran (500 reviews), social_learner (3 friends), community_pillar (10 friends), helpful_peer (10 upvotes given), pioneer (pre-March 2026 signup).
- **`trg_badge_friendship`** — New trigger on friendships UPDATE → awards social_learner and community_pillar for both users when friendship becomes accepted.
- **`trg_badge_new_profile`** — New trigger on profiles INSERT → initializes user_stats row + awards pioneer badge if registered before March 2026.
- **`BadgeIcon.jsx`** — 13 new icon mappings: FileText (teal), Layers (cyan), GraduationCap (violet), Footprints (green), CalendarCheck (emerald), CalendarRange (amber), Sunrise (rose), Award (sky), Medal (amber-700), Users (blue-400), HeartHandshake (pink), ThumbsUp (lime), Flag (red).

### Changed
- **`award_badge()` DB function** — night_owl and early_bird now default to `is_public = FALSE`. Uses `RETURNING id` pattern for accurate new-badge detection.
- **`fn_badge_check_notes()`** — Reads `user_stats.total_notes` instead of `COUNT(notes)`. Adds prolific_writer check.
- **`fn_badge_check_flashcards()`** — Reads `user_stats.total_flashcards` instead of `COUNT(flashcards)`. Adds deck_builder and subject_expert (subject-scoped COUNT only).
- **`fn_badge_check_reviews()`** — Full rewrite: reads `user_stats.total_reviews`, adds first_steps/century_club/review_veteran/committed_learner/monthly_master/early_bird. Timezone from `profiles.timezone`.
- **`fn_badge_check_upvotes()`** — Reads `user_stats.total_upvotes_given/received` instead of subquery COUNT. Adds helpful_peer check.
- **`MyAchievements.jsx`** — Added `special` category to `categoryInfo` (Star icon). Replaced 5 parallel COUNT queries with single `user_stats` read + streak call + subject grouping.

### Files Changed
- `src/components/badges/BadgeIcon.jsx`
- `src/pages/dashboard/Profile/MyAchievements.jsx`

---
## [2026-02-20] Fix: Content Type Selector Missing on Upload Note

### Fixed
- **NoteUpload.jsx** — Content Type buttons (Text, Table, Math, Diagram, Mixed) were available in Edit Note but missing from Upload Note. Added the selector to the "Note Details" card after the Description field. The `contentType` state and DB write already existed — only the UI was missing.

### Files Changed
- `src/pages/dashboard/Content/NoteUpload.jsx`

---
## [2026-02-20] Revert: Dark Mode / Theme Toggle

### Reverted
- Dark mode feature reverted (commit `1af9c61` reverts `a716938`). Root cause: app uses a mix of hardcoded Tailwind color classes (e.g. `bg-gray-900`) and semantic CSS variable classes (e.g. `bg-background`). Applying `dark` class to `<html>` only flips the semantic classes, leaving hardcoded colors unchanged — resulting in an inconsistent half-dark appearance. Proper implementation requires a full component audit to replace hardcoded colors with semantic tokens. Deferred to a future dedicated effort.

---
## [2026-02-20] Landing Page Stats — Total Counts + Visibility Fix

### Added
- **DB Function** `get_platform_stats()` — SECURITY DEFINER function that returns total flashcard and note counts across all visibility levels. Bypasses RLS so unauthenticated landing page visitors see true platform totals (1383 flashcards, 38 notes) instead of public-only counts (458 / 34).

```sql
CREATE OR REPLACE FUNCTION get_platform_stats()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_total_flashcards INTEGER;
  v_total_notes INTEGER;
BEGIN
  SELECT COUNT(*)::INTEGER INTO v_total_flashcards FROM flashcards;
  SELECT COUNT(*)::INTEGER INTO v_total_notes FROM notes;
  RETURN json_build_object('total_flashcards', v_total_flashcards, 'total_notes', v_total_notes);
END; $$;
```

### Changed
- **Home.jsx** — Hero 4-stat grid now calls `get_platform_stats()` RPC for true total counts. Relabeled "Flashcards Created" / "Notes Uploaded".
- **Home.jsx** — Educator section retains direct public-only queries. Relabeled "Flashcards to Browse" / "Notes to Browse".
- **Home.jsx** — Hero social proof line updated from "X+ items shared" to "X+ items created".

### Fixed
- **Home.jsx** — Public count queries were using legacy `is_public = true` column. Changed to `visibility = 'public'`.

### Files Changed
- `src/pages/Home.jsx`

---
## [2026-02-20] Fix: Activity Feed "View" Button Crash

### Fixed
- **ActivityFeed.jsx** — Clicking "View" on a note in the Recent Activity section navigated to `/dashboard/notes/undefined`, causing a Supabase UUID parse error ("invalid input syntax for type uuid: 'undefined'"). Root cause: component used `activity.content_id` but the `get_recent_activity_feed` RPC returns the identifier as `id`. Changed to `activity.id` in both the navigation handler and the React `key` prop.

### Files Changed
- `src/components/dashboard/ActivityFeed.jsx`

---
## [2026-02-12] Fix: card_count Double-Counting + DB Trigger

### Fixed
- **FlashcardCreate.jsx** — Removed manual `card_count` increment logic (both existing deck update and new deck insert). `card_count` is now maintained exclusively by a database trigger, eliminating double-counting.

### Added
- **DB Trigger** (`flashcards_count_trigger`) — Auto-increments `card_count` on `flashcards` INSERT, decrements on DELETE. Single source of truth for deck size.

### Changed
- **FlashcardCreate.jsx** — Existing deck lookup no longer fetches `card_count` (no longer needed). New deck inserts with `card_count: 0` (trigger populates it).
- **DB (one-time fix)** — Ran SQL to recalculate all `card_count` values from actual `flashcards` rows, fixing ~46 decks across 6 students that had inflated counts.

### Files Changed
- `src/pages/dashboard/Content/FlashcardCreate.jsx`

---
## [2026-02-09] Fix: Flashcard Deck Names in Share Content Dialog

### Fixed
- **GroupDetail.jsx** — Share Content dialog showed generic "Flashcard Deck" for all decks instead of actual subject/topic names. Root cause: `subject_id` and `topic_id` were missing from the Supabase select query, so subject/topic name lookups always returned undefined and fell back to "Flashcard Deck". Added both columns to query, added topic name lookup, and decks now display as "Subject - Topic".

### Files Changed
- `src/pages/dashboard/Groups/GroupDetail.jsx`

---
## [2026-02-09] Dependent subject dropdown + skipped duplicates report

### Added
- **FlashcardCreate + NoteUpload** — Subject dropdown now filters by selected course via `discipline_id` lookup
- **BulkUploadTopics** — Skipped duplicates now listed by name (`Subject → Topic`) in success report

### Changed
- **FlashcardCreate + NoteUpload** — Disciplines loaded on mount; course name matched to discipline for subject filtering
- **FlashcardCreate + NoteUpload** — Subject & topic selections reset when course changes
- Custom courses (no discipline match) show all subjects as fallback

### Fixed
- **BulkUploadTopics** — Removed `description` column from topics insert and select (column doesn't exist)
- **BulkUploadTopics** — All subjects/topics queries now use `order_num` instead of `sort_order`

### Files Changed
- `src/pages/dashboard/Content/FlashcardCreate.jsx` (dependent subject dropdown)
- `src/pages/dashboard/Content/NoteUpload.jsx` (dependent subject dropdown)
- `src/pages/admin/BulkUploadTopics.jsx` (skipped entries report, order_num fix, description removal)

---
## [2026-02-09] Fix: disciplines table — correct column names + required code column

### Fixed
- **Both bulk upload pages** — `loadCourses()` now uses correct columns: `.eq('is_active', true).order('order_num').order('name')` (disciplines uses `order_num`, not `sort_order`)
- **BulkUploadTopics.jsx** — Create New Course insert now includes required `code` column (auto-generated from name, e.g., "CA Final" → "CAFIN")
- **DATABASE_SCHEMA.md** — Disciplines section rewritten with verified live DB schema (8 columns including `code`, `level`, `order_num`, `order`)

### Added
- `generateCode()` utility in BulkUploadTopics — creates short uppercase code from course name (first 2-3 chars per word, max 8 chars)

### Root Cause
- `DATABASE_SCHEMA.md` was inaccurate for disciplines table — listed `sort_order`/`description`/`icon`/`updated_at` which don't exist, missed `code`/`level`/`order_num`/`order` which do exist

### Files Changed
- `src/pages/dashboard/BulkUploadFlashcards.jsx` (loadCourses query: correct column names)
- `src/pages/admin/BulkUploadTopics.jsx` (loadCourses query + insert with code + generateCode utility)
- `docs/reference/DATABASE_SCHEMA.md` (disciplines section rewritten from live DB)

---
## [2026-02-09] Bulk Upload QA Refinements

### Changed
- **Both Bulk Upload pages** — Removed forced download gate. All stepper steps are now freely clickable. Returning users can skip directly to Step 2 without re-downloading templates.
- **Both Bulk Upload pages** — Added `is_active` filter to disciplines query (future-proofing for soft-deleted courses)
- **Step component** — Removed `disabled` prop; all steps are always interactive
- **First-timer nudge** — Amber Info box appears in Step 2 when Step 1 hasn't been completed, with link back to Step 1
- **Step 3 guards** — Shows contextual amber nudge when course/file not selected, with links to relevant steps

### Added (BulkUploadTopics)
- **`[+ New Course]` button** — Inline form next to course dropdown for creating new disciplines without leaving the page
- **Course creation validation** — Case-insensitive duplicate check, Title Case enforcement, DB unique constraint handling
- **`subject_sort_order` column** (optional) — Explicit display order for subjects
- **`sort_order` column** (optional) — Explicit display order for topics within a subject
- **Sort order logic** — If blank/0, falls back to alphabetical. If provided, items sorted by number first (sort_order ASC, name ASC)
- **Existing subject sort update** — If CSV provides non-zero sort_order for an existing subject with default 0, the DB is updated
- **Generic template** — Example rows use language learning (Grammar/Vocabulary) instead of CA-specific entries
- **Current Entries download** — Now includes Subject Sort Order and Topic Sort Order columns, sorted by sort_order

### Files Changed
- `src/pages/dashboard/BulkUploadFlashcards.jsx` (step gates removed, is_active filter, first-timer nudge, Step 3 guard)
- `src/pages/admin/BulkUploadTopics.jsx` (major overhaul: step gates, is_active, sort_order, Create New Course, generic template)

---
## [2026-02-09] Streamlined Bulk Upload Pages

### Added
- **`BulkUploadFlashcards.jsx`** — New stepper-based bulk upload replacing 4-card ProfessorTools layout. 3 collapsible steps: Download Files → Prepare & Select CSV → Upload. Available to all users.
- **`BulkUploadTopics.jsx`** — Admin-only page for bulk-adding subjects & topics to a course via CSV. Case-insensitive matching (prevents duplicates), Title Case enforcement for new entries, automatic duplicate skipping.
- **"Manage Topics" nav link** — Visible to admin/super_admin in both desktop and mobile navigation
- **"Required columns" hint** in Step 2 of both bulk upload pages (saves users from opening template just to check headers)

### Changed
- **Bulk Upload nav link** — Now visible to ALL users (was restricted to professor/admin/super_admin)
- **`/professor/tools` route** — Now redirects to `/dashboard/bulk-upload` (legacy support)
- **FlashcardCreate.jsx** — "Try Bulk Upload" link updated from `/professor/tools` to `/dashboard/bulk-upload`
- **NavDesktop.jsx** — Removed role gate on Bulk Upload link; added "Manage Topics" admin link
- **NavMobile.jsx** — Same changes as NavDesktop

### Files Changed
- `src/pages/dashboard/BulkUploadFlashcards.jsx` (NEW)
- `src/pages/admin/BulkUploadTopics.jsx` (NEW)
- `src/App.jsx` (new routes, import, legacy redirect)
- `src/pages/dashboard/Content/FlashcardCreate.jsx` (link update)
- `src/components/layout/NavDesktop.jsx` (role gate removal, admin link)
- `src/components/layout/NavMobile.jsx` (role gate removal, admin link)

---
## [2026-02-09] Profile Completion Modal & Course Label Update

### Added
- **Non-dismissible profile completion modal** on Dashboard — shown when `course_level` or `institution` is NULL
- Modal uses same curated institution SearchableSelect and course dropdown as ProfileSettings
- Modal blocks interaction (no close button, no escape, no click-outside) until both fields are saved
- `hideCloseButton` prop added to `DialogContent` component for non-dismissible dialogs

### Changed
- **ProfileSettings.jsx** — Course field label changed from "Course Level" to "Primary Course" (implies changeable, prepares for future multi-course support)
- **Dashboard.jsx** — Profile query now fetches `institution` alongside `full_name` and `course_level`
- Dashboard re-fetches data after modal save to reflect updated course in class stats

### Files Changed
- `src/pages/Dashboard.jsx` (profile completion modal + imports)
- `src/pages/dashboard/Profile/ProfileSettings.jsx` (label change)
- `src/components/ui/dialog.jsx` (added `hideCloseButton` prop)

---
## [2026-02-08] FindFriends Privacy Fix & Profile Settings Page

### Added
- **`ProfileSettings.jsx` page** — New `/dashboard/settings` route allowing users to edit Full Name, Course Level, and Institution
- **Institution dropdown** with 12 curated options (ICAI, major coaching centers) + "Other" for custom input, using `SearchableSelect` for searchable alphabetical list
- **Settings link** in ProfileDropdown (desktop) and NavMobile hamburger menu (mobile)
- **"Joined {year}"** display on FindFriends cards for user disambiguation

### Changed
- **FindFriends.jsx** — Email addresses are now masked (`an***@gmail.com`) instead of shown in full
- **FindFriends.jsx** — Institution and "Joined {year}" now displayed alongside masked email and course level
- **FindFriends.jsx** — Search now filters by name only (removed email search to prevent email enumeration)
- **FindFriends.jsx** — Search placeholder updated to "Search by name..."
- **FindFriends.jsx** — Avatar fallback changed from email initial to `?` when no name exists

### Security
- Client-side email masking with code comment acknowledging cosmetic-only limitation
- Input sanitization: Institution custom text is trimmed and Title Cased before save
- Email search removed to prevent confirming whether an email exists in the system

### Files Changed
- `src/pages/dashboard/Friends/FindFriends.jsx` (modified — privacy + disambiguation)
- `src/pages/dashboard/Profile/ProfileSettings.jsx` (NEW)
- `src/App.jsx` (added import + route for ProfileSettings)
- `src/components/layout/ProfileDropdown.jsx` (added Settings menu item)
- `src/components/layout/NavMobile.jsx` (added Settings link to mobile hamburger menu)

---
## [2026-02-08] Flashcard Text-to-Speech (Read Aloud)

### Added
- **`useSpeech.js` hook** — Wraps browser Web Speech API with sentence chunking (prevents Chrome 15-second cutoff bug), localStorage persistence for voice and speed preferences
- **`SpeakButton.jsx` component** — Reusable volume icon button (Volume2/VolumeX from Lucide) with pulse animation while speaking, graceful degradation on unsupported browsers
- **`SpeechSettings.jsx` component** — Popover with voice selector (grouped by language) and speed slider (0.5x–2.0x), persisted to localStorage
- **TTS in StudyMode.jsx** — Volume icon next to QUESTION badge (question side) and both QUESTION + ANSWER badges (answer side), with settings gear icon for voice/speed

### Changed
- `StudyMode.jsx` — Added speech auto-cancel on card advance, answer reveal, skip, suspend, and reset actions

### Files Changed
- `src/hooks/useSpeech.js` (NEW)
- `src/components/flashcards/SpeakButton.jsx` (NEW)
- `src/components/flashcards/SpeechSettings.jsx` (NEW)
- `src/pages/dashboard/Study/StudyMode.jsx` (modified)

---
## [2026-02-08] File Structure Refactor — Pages out of Components

### Changed
- **Moved 9 page-level components** from `src/components/` to `src/pages/`:
  - Notes pages (NoteUpload, NoteDetail, NoteEdit) → `pages/dashboard/Content/`
  - Flashcard pages (FlashcardCreate, MyFlashcards) → `pages/dashboard/Content/`
  - StudyMode → `pages/dashboard/Study/`
  - Admin pages (AdminDashboard, SuperAdminDashboard) → `pages/admin/`
  - ProfessorTools → `pages/professor/`
- **Fixed NoteEdit route**: `/notes/edit/:id` → `/dashboard/notes/edit/:id` (was the only route missing `/dashboard` prefix)
- **Added legacy redirect** for `/notes/edit/:id` → `/dashboard/notes/edit/:id` to preserve bookmarks
- **Added route-to-file mapping** comment block in App.jsx for developer reference
- **Deleted** dead `components/notes/index.jsx` placeholder file
- **Updated imports** in App.jsx, ReviewSession.jsx, NoteDetail.jsx

### Files Changed
- `src/App.jsx` (imports + route fix + mapping comment)
- `src/pages/dashboard/Study/ReviewSession.jsx` (StudyMode import path)
- `src/pages/dashboard/Content/NoteDetail.jsx` (edit route path)
- 9 files moved (see FILE_STRUCTURE.md)
- 1 file deleted (`src/components/notes/index.jsx`)

---
## [2026-02-08] Clickable Content in Author Profile

### Added
- **URL Deep-Linking for BrowseNotes & ReviewFlashcards:**
  - Both pages now read `author` and `subject` query params from URL on mount
  - Enables pre-filtered navigation from Author Profile and any future deep links

### Changed
- `AuthorProfile.jsx` - Note/flashcard counts in subject rows are now clickable `<Link>` elements
  - Notes count → navigates to `/dashboard/notes?author=<id>&subject=<name>`
  - Flashcards count → navigates to `/dashboard/review-flashcards?author=<id>&subject=<name>`
- `BrowseNotes.jsx` - Added `useSearchParams` to initialize `filterAuthor` and `filterSubject` from URL
- `ReviewFlashcards.jsx` - Added `useSearchParams` to initialize `filterAuthor` and `filterSubject` from URL

### Files Changed
- `src/pages/dashboard/Profile/AuthorProfile.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`

---
## [2026-02-07] Help & Guide Documentation Page

### Added
- **`src/data/helpContent.js`** — Structured help content data file with 6 tabs (Getting Started, Content, Study System, Social, Study Groups, More), 24 collapsible sections, and 10 FAQ items. Data-driven architecture separates content from rendering.
- **`src/pages/dashboard/Help.jsx`** — Full Help page component with tabbed navigation, cross-tab search, collapsible Card sections, back-to-top button, and URL deep linking via `useSearchParams`.
- **`scrollbar-hide` CSS utility** — Added to `src/index.css` for hiding scrollbars on the tab bar (mobile horizontal scroll).

### Changed
- **`src/components/layout/ProfileDropdown.jsx`** — Added "Help & Guide" menu item with HelpCircle icon above the Sign Out separator.
- **`src/components/layout/NavMobile.jsx`** — Added "Help & Guide" button after My Achievements in the mobile navigation sheet.
- **`src/App.jsx`** — Added import and protected route for `/dashboard/help`.

### Files Changed
- `src/data/helpContent.js` (NEW)
- `src/pages/dashboard/Help.jsx` (NEW)
- `src/App.jsx`
- `src/components/layout/ProfileDropdown.jsx`
- `src/components/layout/NavMobile.jsx`
- `src/index.css`

---
## [2026-02-07] Allow All Members to Share Content in Groups

### Changed
- **`share_content_with_groups()`** — Changed admin-only check to active member check. Any group member can now share their own content.
- **RLS INSERT policy on `content_group_shares`** — Renamed `cgs_insert_admin` → `cgs_insert_member`. Any active group member can insert shares (must be `shared_by = auth.uid()`).
- **RLS DELETE policy on `content_group_shares`** — Renamed `cgs_delete_admin` → `cgs_delete_own_or_admin`. Admins can delete any share; regular members can only delete their own (`shared_by = auth.uid()`).
- **GroupDetail.jsx** — "Share Content" button visible to all members (previously admin-only). Delete icons on shared content: admin sees all, member sees only their own. "Invite Members" remains admin-only.

### Files Changed
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `docs/database/study-groups/27_FIX_allow_all_members_to_share_content.sql` (NEW)

---
## [2026-02-06] Group Invitation Flow + Notification Backend

### Added
- **`notifications` table** — Full notification system backend (id, user_id, type, title, message, is_read, metadata JSONB, created_at). RLS policies for own-row access. Indexes including composite unread index.
- **5 Notification RPCs** — `get_unread_notification_count`, `get_recent_notifications`, `mark_notifications_read`, `mark_single_notification_read`, `delete_notification`. All SECURITY DEFINER with auth.uid() ownership checks.
- **`cleanup_old_notifications()`** — Utility function for cron-based retention (deletes notifications > 60 days old).
- **`status` column on `study_group_members`** — `TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('invited', 'active'))`. Zero migration risk — existing rows default to 'active'.
- **`invited_by` column on `study_group_members`** — `UUID REFERENCES profiles(id) ON DELETE SET NULL`. Tracks who sent the invitation.
- **`accept_group_invite(p_membership_id)`** RPC — Verifies invitation belongs to caller, updates status → 'active', auto-marks related notification as read.
- **`decline_group_invite(p_membership_id)`** RPC — Marks notification as read, then hard DELETEs membership row.
- **`get_pending_group_invites()`** RPC — Returns pending invitations for MyGroups page with group info, inviter name, member count.
- **Pending Invitations section on MyGroups.jsx** — Amber-bordered cards above groups grid with Accept/Decline buttons.
- **Pending Invitations in GroupDetail.jsx members panel** — Admin-only section showing invited users with Cancel button.
- **Inline Accept/Decline in ActivityDropdown** — Group invite notifications render with action buttons (following FriendsDropdown pattern).

### Changed
- **`invite_to_group()`** — Now inserts with `status = 'invited'` instead of `'active'`. Creates notification with `type = 'group_invite'` and JSONB metadata.
- **`get_user_groups()`** — Now filters `AND sgm.status = 'active'` so pending invites don't appear as groups.
- **`get_group_detail()`** — Members query filters `status = 'active'`. Returns new `pending_invitations` key for admin view.
- **`get_browsable_notes()`** — Added `AND sgm.status = 'active'` in group-shared EXISTS subquery (security: invited users can't see content).
- **`get_browsable_decks()`** — Same security filter as notes.
- **`leave_group()`** — Member count/admin count queries now filter `AND status = 'active'`. Only active members can leave.
- **GroupDetail.jsx** — Button text "Add Members" → "Invite Members", toast "Member added!" → "Invitation sent!", search excludes pending invitations.
- **ActivityDropdown.jsx** — Added group_invite notification type with Users icon (indigo), inline Accept/Decline buttons.
- **Navigation.jsx** — Passes `deleteNotification` and `refetchNotifications` to ActivityDropdown via NavDesktop/NavMobile.

### Files Changed
- `src/components/layout/ActivityDropdown.jsx` (REWRITTEN)
- `src/components/layout/Navigation.jsx`
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`
- `src/pages/dashboard/Groups/MyGroups.jsx`
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `docs/database/study-groups/13_SCHEMA_notifications_table.sql` (NEW)
- `docs/database/study-groups/14_FUNCTIONS_notification_rpcs.sql` (NEW)
- `docs/database/study-groups/15_SCHEMA_add_invitation_status.sql` (NEW)
- `docs/database/study-groups/16_FUNCTION_invite_to_group_v2.sql` (NEW)
- `docs/database/study-groups/17_FUNCTION_accept_group_invite.sql` (NEW)
- `docs/database/study-groups/18_FUNCTION_decline_group_invite.sql` (NEW)
- `docs/database/study-groups/19_FUNCTION_get_pending_group_invites.sql` (NEW)
- `docs/database/study-groups/20_FUNCTION_get_user_groups_v2.sql` (NEW)
- `docs/database/study-groups/21_FUNCTION_get_group_detail_v2.sql` (NEW)
- `docs/database/study-groups/22_FUNCTION_get_browsable_notes_v2.sql` (NEW)
- `docs/database/study-groups/23_FUNCTION_get_browsable_decks_v2.sql` (NEW)
- `docs/database/study-groups/24_FUNCTION_leave_group_v2.sql` (NEW)

### Manual Step Required
- Enable Supabase Realtime on `notifications` table: Dashboard → Database → Replication → Enable for `notifications`

---
## [2026-02-06] Study Groups - RLS Fix + Server-Side Content Fetching

### Fixed
- **Infinite Recursion Bug**: `sgm_select_member` RLS policy on `study_group_members` self-referenced its own table, causing PostgreSQL infinite recursion. Replaced with `sgm_select_own` using simple `USING (user_id = auth.uid())` — no subquery, no recursion.
- **"Failed to load group" on GroupDetail**: The direct `study_groups` SELECT went through RLS which depended on `study_group_members` RLS — fragile chain. Replaced 3-query pattern (group SELECT + get_group_members RPC + get_group_shared_content RPC) with single `get_group_detail(p_group_id)` SECURITY DEFINER RPC that returns group info, members, and shared content in one call. Zero RLS dependency.

### Changed
- **GroupDetail.jsx** - Replaced 3 separate DB calls with single `get_group_detail` RPC call. Eliminates RLS chain failure.
- **BrowseNotes.jsx** - Replaced 3-query client-side merge (visibility query + group shares + missing items → JS array merge) with single `get_browsable_notes()` RPC call. Fixes pagination compatibility and reduces DB round-trips from 3 to 1.
- **ReviewFlashcards.jsx** - Same refactor: replaced 3-query client-side merge with single `get_browsable_decks()` RPC call.

### Security & Privacy
- **Privacy**: `get_group_detail` and `get_group_members` do NOT return member emails. Only safe public fields: user_id, full_name, role, joined_at.
- **Security**: All group RPCs use strict `IF NOT EXISTS (...) THEN RAISE EXCEPTION 'Access denied'` pattern.
- **Null safety**: All arrays in `get_group_detail` use double COALESCE — both in the subquery and in the final `json_build_object` — ensuring `[]` never `null`.

### Added
- **`get_group_detail(p_group_id)`** RPC - Returns group info + members + shared content in one call. SECURITY DEFINER with membership check. Replaces 3 separate queries. No email in member data.
- **`get_group_members(p_group_id)`** RPC - Returns all members of a group with profiles. SECURITY DEFINER with explicit membership check. No email in output.
- **`get_browsable_notes()`** RPC - Single query returning all notes visible to the user (own + public + friends + group-shared) with profile/subject/topic JOINs. Server-side visibility enforcement.
- **`get_browsable_decks()`** RPC - Same for flashcard decks. Single query with full visibility logic.

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `docs/database/study-groups/02_RLS_study_groups_policies.sql` (FIXED)
- `docs/database/study-groups/09_FUNCTION_get_group_members.sql` (NEW)
- `docs/database/study-groups/10_FUNCTION_get_browsable_notes.sql` (NEW)
- `docs/database/study-groups/11_FUNCTION_get_browsable_decks.sql` (NEW)
- `docs/database/study-groups/12_FUNCTION_get_group_detail.sql` (NEW)

---
## [2026-02-06] Study Groups (Phase 1: Read-Only)

### Added
- **Database Tables** (3 new):
  - `study_groups` - Group metadata (name, description, creator)
  - `study_group_members` - Membership with roles (admin/member), UNIQUE(group_id, user_id)
  - `content_group_shares` - Content-to-group sharing links (note/flashcard_deck)
  - All group_id foreign keys use `ON DELETE CASCADE` (deleting group removes shares, NOT original content)

- **Database RLS Policies** (8 new):
  - `sg_select_member`, `sg_insert`, `sg_update_creator`, `sg_delete_creator` on study_groups
  - `sgm_select_member`, `sgm_insert_admin`, `sgm_delete` on study_group_members
  - `cgs_select_member`, `cgs_insert_admin`, `cgs_delete_admin` on content_group_shares

- **Database Functions** (6 new SECURITY DEFINER RPCs):
  - `create_study_group(p_name, p_description)` - Creates group + adds creator as admin
  - `invite_to_group(p_group_id, p_user_id)` - Admin adds member
  - `leave_group(p_group_id)` - Member leaves (promotes oldest member if last admin)
  - `share_content_with_groups(p_content_type, p_content_id, p_group_ids)` - Multi-group share
  - `get_user_groups()` - Returns user's groups with member count and role
  - `get_group_shared_content(p_group_id)` - Returns shared notes and decks for a group

- **MyGroups.jsx** - List user's study groups with create/leave/delete actions
- **CreateGroup.jsx** - Form to create a new study group
- **GroupDetail.jsx** - Group page with members panel, shared content, invite members, share content dialogs
- **Navigation** - Added "Groups" link in desktop nav and "Study Groups" section in mobile menu

### Changed
- **App.jsx** - Added 3 routes: `/dashboard/groups`, `/dashboard/groups/new`, `/dashboard/groups/:groupId`
- **NavDesktop.jsx** - Added Groups nav link with active state
- **NavMobile.jsx** - Added Groups section in mobile sheet menu
- **NoteUpload.jsx** - Added "Study Groups" visibility option with group multi-select checkboxes, shares note with groups after upload
- **FlashcardCreate.jsx** - Added "Study Groups" visibility option with group multi-select checkboxes, shares deck with groups after creation
- **BrowseNotes.jsx** - Fetches and merges group-shared notes alongside public/friends notes
- **ReviewFlashcards.jsx** - Fetches and merges group-shared decks alongside public/friends decks

### Files Changed
- `src/App.jsx`
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`
- `src/components/notes/NoteUpload.jsx`
- `src/components/flashcards/FlashcardCreate.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Groups/MyGroups.jsx` (NEW)
- `src/pages/dashboard/Groups/CreateGroup.jsx` (NEW)
- `src/pages/dashboard/Groups/GroupDetail.jsx` (NEW)
- `docs/database/study-groups/` (8 SQL files - NEW)

---
## [2026-02-06] Card Suspension System (Skip, Suspend, Reset)

### Added
- **Database Migration**: `status` (active/suspended) and `skip_until` (DATE) columns on reviews table
- **Database Indexes**: `idx_reviews_status`, `idx_reviews_skip_until`, `idx_reviews_user_status_due` (partial composite)
- **Database Functions** (6 new SECURITY DEFINER RPCs):
  - `skip_card(p_user_id, p_flashcard_id)` - Hides card for 24 hours (timezone-aware)
  - `suspend_card(p_user_id, p_flashcard_id)` - Suspends card indefinitely
  - `suspend_topic_cards(p_user_id, p_topic_id)` - Bulk suspends all cards in a topic
  - `unsuspend_card(p_user_id, p_flashcard_id)` - Reactivates suspended card (due today)
  - `reset_card(p_user_id, p_flashcard_id)` - Deletes review record (card becomes New)
  - `get_suspended_cards(p_user_id)` - Returns suspended cards with details for Progress page

- **StudyMode.jsx** - Card management during study:
  - [Skip 24hr] button on question side (no confirmation needed)
  - [More] dropdown menu with Suspend Card, Suspend Topic, Reset Card
  - Skip/More actions also available on answer side
  - Confirmation dialogs for all destructive actions (suspend/reset)
  - Topic suspension removes matching cards from current session

- **Progress.jsx** - Suspended Cards section:
  - Collapsible "Suspended Cards" section with amber styling
  - Cards grouped by subject with Unsuspend button per card
  - Confirmation dialog for unsuspend with card preview

### Changed
- **ReviewSession.jsx** - Filters out suspended (`status='suspended'`) and skipped (`skip_until > today`) cards from due queue
- **ReviewBySubject.jsx** - Same suspension/skip filtering
- **Dashboard.jsx** - Due count excludes suspended/skipped cards; streak only counts actual reviews (quality > 0)
- **Progress.jsx** - Stats queries filter by `status='active'`; streak calculation excludes suspended reviews

### Files Changed
- `src/components/flashcards/StudyMode.jsx` (rewritten with skip/suspend/reset)
- `src/pages/dashboard/Study/Progress.jsx` (rewritten with suspended cards section)
- `src/pages/dashboard/Study/ReviewSession.jsx` (due cards query updated)
- `src/pages/dashboard/Study/ReviewBySubject.jsx` (due cards query updated)
- `src/pages/Dashboard.jsx` (stats filtering updated)

---
## [2026-02-06] Author Profile Page & Clickable Names

### Added
- **Database RPC Functions** for author profile (SECURITY DEFINER):
  - `get_author_profile(p_author_id, p_viewer_id)` - Returns profile + badges + friendship in 1 call
  - `get_author_content_summary(p_author_id, p_viewer_id)` - Returns content grouped by course/subject with server-side visibility

- **AuthorProfile.jsx** - New page at `/dashboard/profile/:userId`:
  - Uses 2 RPC calls instead of 6 direct queries (performance + security)
  - Displays author name, role badge, institution, course level
  - Shows public badges (own profile shows all badges with hidden indicator)
  - Content grouped by Course → Subject with note/flashcard counts
  - "Also Creates Content For" section listing other courses (upsell hook)
  - Add Friend button with full friendship lifecycle (pending/accepted/rejected)
  - "Preview as Visitor" toggle on own profile
  - Back button with history-aware navigation

- **Clickable Author Names** - All author/user names now link to profile page:
  - `BrowseNotes.jsx` - Note card footer author name
  - `ReviewFlashcards.jsx` - Deck card author name (moved outside study button)
  - `NoteDetail.jsx` - Author badge in note header
  - `FindFriends.jsx` - User card name
  - `MyFriends.jsx` - Friend card name
  - `MyContributions.jsx` - Upvoter names (summary list, note upvoters, deck upvoters)

### Changed
- `App.jsx` - Added AuthorProfile import and `/dashboard/profile/:userId` route
- `BrowseNotes.jsx` - Added `Link` import, wrapped author name in `<Link>`
- `ReviewFlashcards.jsx` - Added `Link` import, extracted author name outside study button as separate clickable `<Link>`
- `NoteDetail.jsx` - Added `Link` import, wrapped author badge `<div>` with `<Link>`
- `FindFriends.jsx` - Added `Link` import, wrapped user name in `<Link>`
- `MyFriends.jsx` - Added `Link` import, wrapped friend name in `<Link>`
- `MyContributions.jsx` - Added `Link` import, replaced upvoter `<span>` with `<Link>` in 3 locations

### Files Changed
- `src/pages/dashboard/Profile/AuthorProfile.jsx` (NEW)
- `src/App.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/components/notes/NoteDetail.jsx`
- `src/pages/dashboard/Friends/FindFriends.jsx`
- `src/pages/dashboard/Friends/MyFriends.jsx`
- `src/pages/dashboard/Content/MyContributions.jsx`

---
## [2026-02-06] Grid/Grouped View Toggle & Collapsible Sections

### Added
- **MyNotes.jsx - Grid/Grouped View Toggle:**
  - `[Grid] [Grouped]` toggle buttons in header area (matches MyFlashcards pattern)
  - Grouped View organizes notes by Subject → Topic hierarchy
  - Notes without subject/topic fall into "Uncategorized" section (sorted last)
  - View preference persisted in localStorage (`myNotes_viewMode` key)
  - Extracted `renderNoteCard` helper for shared card rendering in both views
  - `useMemo` for efficient grouped notes computation

- **BrowseNotes.jsx - Collapsible Sections:**
  - Subject headers now collapsible with ChevronDown/ChevronRight icons
  - Topic sub-headers now collapsible with note count display
  - Gradient background on subject headers (blue-to-indigo)
  - `collapsedGroups` state tracks open/closed sections independently

- **ReviewFlashcards.jsx - Collapsible Sections:**
  - Subject headers now collapsible with ChevronDown/ChevronRight icons
  - Gradient background on subject headers (blue-to-indigo)
  - "Study All" button preserved with `e.stopPropagation()` to avoid triggering collapse
  - `collapsedGroups` state tracks open/closed sections independently

### Changed
- `MyNotes.jsx` - Added `useMemo`, `ChevronDown`, `ChevronRight` imports
- `BrowseNotes.jsx` - Added `ChevronDown`, `ChevronRight` imports, collapsible state
- `ReviewFlashcards.jsx` - Added `ChevronDown` import, collapsible state

### Technical Details
- No database changes required (uses existing `subject_id`/`topic_id` joins)
- No new files created (only modified 3 existing files)
- Grouped view sorts alphabetically with "Uncategorized" always last
- Both subject and topic levels independently collapsible

### Files Changed
- `src/pages/dashboard/Content/MyNotes.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`

---
## [2026-02-05] Author Search with Server-Side Filtering

### Added
- **Database RPC Functions** for server-side author filtering:
  - `get_filtered_authors_for_notes(p_course, p_subject_id, p_role)` - Returns authors with public notes
  - `get_filtered_authors_for_flashcards(p_course, p_subject_id, p_role)` - Returns authors with public flashcard decks
  
- **Split Author Filter into Role + Author:**
  - Role dropdown: All Roles / Professor / Student
  - Author dropdown: Dynamically populated from server based on filters
  
- **Dependent Author Filtering:**
  - Author dropdown updates when Course, Subject, or Role changes
  - Only shows authors who have PUBLIC content matching current filters
  - Loading state while fetching authors from server

### Changed
- `BrowseNotes.jsx` - 5-column filter grid (Course, Subject, Topic, Role, Author)
- `ReviewFlashcards.jsx` - 5-column filter grid (Course, Subject, Topic, Role, Author)

### Technical Details
- Uses `supabase.rpc()` for server-side author queries
- Subject name-to-ID mapping for RPC calls (subjects stored by name in UI)
- Author filter auto-resets when parent filter makes current selection invalid
- Added `useCallback` for memoized fetch function

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- Database: 2 new RPC functions

---
## [2026-02-05] Back Button & Dependent Dropdown Filters

### Fixed
- **Back Button Navigation** - All pages now use `navigate(-1)` with fallback to dashboard
  - `NoteDetail.jsx` - Back button returns to actual previous page
  - `ReviewBySubject.jsx` - Both back buttons (empty state + main view)
  - `ReviewSession.jsx` - Back button in empty state

### Added
- **Dependent Dropdown Filters** - Topic dropdown now filters based on selected Subject
  - `MyNotes.jsx` - Topic shows only topics from selected subject
  - `MyFlashcards.jsx` - Topic shows only topics from selected subject
  - `BrowseNotes.jsx` - Added Topic filter with dependent behavior
  - `ReviewFlashcards.jsx` - Added Topic filter with dependent behavior

### Technical Details
- New state: `allTopicsFromNotes`, `allTopicsFromFlashcards`, `allTopicsFromDecks`
- New state: `allNotesFlat`, `allDecksFlat` for efficient filtering
- useEffect hook resets topic to "All Topics" when subject changes and current topic not in new list
- Filter grid changed from 3 columns to 4 columns on BrowseNotes and ReviewFlashcards

### Files Changed

## [2026-02-02] UI Fix - Desktop Navigation Centering

### Changed
- Desktop nav links now centered between Logo (left) and Icons (right)
- Dropdown menus aligned to center for better positioning

---

## [Feb 3, 2026] - UX Bug Fixes

### Fixed
- **NoteEdit.jsx**: Added image/PDF replacement feature
  - File picker to select new image/PDF
  - Preview of new file before saving
  - Automatic deletion of old file from Supabase storage
  - File validation (type and size limits)
  
- **MyFlashcards.jsx**: Fixed cursor jumping to beginning during inline editing
  - Extracted FlashcardCard to separate component file
  - Implemented isolated edit state pattern
  - Used useCallback for stable handler references

### Added
- **FlashcardCard.jsx**: New standalone component for flashcard display/editing
  - Moved from inline definition to prevent re-mounting on parent re-render
  - Props-based architecture for better performance

---

## [2026-02-02] Phase 1B - Notifications & Navigation Redesign

### Added
- `useNotifications` hook with Supabase Realtime subscription
- `useFriendRequestCount` hook with Realtime subscription  
- `useActivityFeed` hook for dashboard content feed
- `ActivityFeed` component for Dashboard
- `Sheet` UI component (Radix Dialog-based)
- Modular navigation: NavDesktop, NavMobile, FriendsDropdown, ActivityDropdown, ProfileDropdown

### Changed
- Navigation.jsx refactored from 566 lines to 55 lines (orchestrator pattern)
- Dashboard.jsx now includes ActivityFeed section

### Technical
- Friends icon shows red badge with pending count
- Bell icon shows red badge with unread notification count
- Notifications auto-marked as read when dropdown opens
- Mobile navigation uses Sheet with auto-close on navigate

---

## 2026-02-02: FlashcardCreate Duplicate Deck Fix

### Fixed
- **FlashcardCreate duplicate deck constraint error**
  - Creating 2nd+ flashcard for same subject/topic caused unique constraint violation
  - Now checks for existing deck before creating (SELECT before INSERT)
  - Reuses existing deck_id when match found
  - Uses `.is()` for NULL comparisons and `.maybeSingle()` for safe queries

### Files Changed
- `src/components/flashcards/FlashcardCreate.jsx`

---

## 2026-01-30: User Timezone Storage

### Added
- **Database:** `profiles.timezone` column (TEXT, default 'Asia/Kolkata')
- **Database:** Index `idx_profiles_timezone`
- **Frontend:** `updateUserTimezone()` helper in AuthContext.jsx

### Changed
- **`log_review_activity()`** - Now uses stored user timezone
- **`check_night_owl_badge()`** - Checks 11 PM - 4 AM in user's local time
- **`get_user_streak()`** - Calculates streak in user's local timezone
- **`get_anonymous_class_stats()`** - Uses per-user timezone for "studied today"
- **AuthContext.jsx** - Auto-syncs browser timezone on login/signup

### Impact
- Night Owl badge now works correctly for international users
- Streak calculations respect user's local midnight
- "Studied today" is accurate regardless of user location
- Timezone auto-updates when user travels

### Migration
- Run `[SCHEMA] Add User Timezone Support` in Supabase SQL Editor
- Existing users get default 'Asia/Kolkata' until they log in again

---

## 2026-01-30: Universal Timezone Fix

### Changed
- **FIXED:** All date calculations now use user's LOCAL timezone instead of hardcoded `Asia/Kolkata`
- **Files Updated:**
  - `Dashboard.jsx` - Streak calculation, due cards count
  - `Progress.jsx` - Streak calculation
  - `ReviewBySubject.jsx` - Due cards filtering
- **Pattern:** Use `toLocaleDateString('en-CA')` without timezone parameter
- **Impact:** App now works correctly for students in any country/timezone

### Documentation Updated
- `docs/active/context.md` - Updated Spaced Repetition & Timezone Standards
- `docs/design/ACHIEVEMENT_BADGES.md` - Updated timezone handling section
- `docs/reference/DATABASE_SCHEMA.md` - Updated SQL function notes

---

## 2026-01-26: Achievement Badges System (Phase 1E)

### Added
- **Badge System Core**
  - 3 new tables: `badge_definitions`, `user_badges`, `user_activity_log`
  - 5 badge types: Digitalizer, Memory Architect, Streak Master, Night Owl, Rising Star
  - Auto-award via database triggers on INSERT events
  - IST timezone handling for Night Owl badge (11PM-4AM)

- **Frontend Components**
  - `BadgeIcon.jsx` - Icon mapping component
  - `BadgeCard.jsx` - Badge display with privacy toggle
  - `BadgeToast.jsx` - Unlock notification
  - `useBadges.js` - Data fetching hook
  - `MyAchievements.jsx` - Full achievements page

- **Privacy Features**
  - Per-badge `is_public` toggle (default: true)
  - Users control visibility of each badge individually
  - FindFriends respects badge privacy settings

- **Navigation**
  - "My Achievements" link in Study dropdown
  - Toast notifications on Dashboard for new badges

### Changed
- Renamed "The Grinder" badge to "Streak Master"
- Updated `FindFriends.jsx` to display user badges

### Removed
- Yellow badge count indicator from navigation (confusing UX)
- Global `badges_public` column from profiles (replaced with per-badge)

### Database Migrations
- `badges_tables_and_seed.sql` - Tables + seed data
- `badges_rls_policies.sql` - Row Level Security
- `badges_core_functions.sql` - 6 SQL functions
- `badges_triggers.sql` - 4 triggers
- `badges_backfill_existing_users.sql` - Backfilled 14 badges
- `badges_per_badge_privacy.sql` - Added is_public column
- `rename_grinder_badge.sql` - Renamed badge

---

## 2026-01-24: Phase 1D - Upvote System

### Database
- **NEW TABLE:** `flashcard_decks` - Solidifies flashcard groups as first-class entities
- **MODIFIED:** `upvotes` table now polymorphic (content_type + target_id)
- **MODIFIED:** `flashcards` table has new `deck_id` column
- **NEW TRIGGERS:** Auto-update `upvote_count` on notes and decks
- **NEW TRIGGERS:** Auto-update `card_count` on decks
- **NEW FUNCTIONS:** `toggle_upvote()`, `get_upvote_details()`, `has_user_upvoted()`
- **NEW RLS:** Comprehensive policies for flashcard_decks and upvotes

### Frontend
- **NEW:** `UpvoteButton.jsx` - Reusable upvote component with toggle behavior
- **MODIFIED:** `BrowseNotes.jsx` - Added upvote buttons to note cards
- **MODIFIED:** `ReviewFlashcards.jsx` - Now queries flashcard_decks, added upvote buttons
- **MODIFIED:** `MyContributions.jsx` - Added Community Feedback section:
  - Impact message ("Your content helped X students!")
  - Upvoter names summary
  - Top Performing Notes/Decks with expandable upvoter lists
- **MODIFIED:** `NoteDetail.jsx` - Added upvote button in header, author badge

### Migration
- Existing flashcards grouped into decks via backfill script
- Existing upvotes migrated to polymorphic structure (content_type='note')

### Files Changed
```
src/components/ui/UpvoteButton.jsx (NEW)
src/pages/dashboard/Content/BrowseNotes.jsx
src/pages/dashboard/Content/MyContributions.jsx
src/pages/dashboard/Study/ReviewFlashcards.jsx
src/components/notes/NoteDetail.jsx
```
## 2026-01-24: Dashboard Redesign with Anonymous Class Stats (Phase 1C)

### Added
- **NEW Component:** `src/components/dashboard/AnonymousStats.jsx`
  - "You vs Class" comparison with Tailwind progress bars (no chart libraries)
  - Class Milestones: Students studied today, 7-day streak count
  - Privacy-first: Hides comparison if < 5 active users
  - Zero data state: Motivating text for users with no reviews

- **NEW SQL Function:** `get_anonymous_class_stats(p_course_level TEXT)`
  - SECURITY DEFINER (bypasses RLS for aggregation)
  - Returns: avg_reviews_this_week, total_active_students, students_with_7day_streak, students_studied_today, min_users_met
  - Filters by course_level (CA Inter vs CA Inter only)
  - Uses rolling 7-day window (today - 6 days)
  - Timezone: Uses user's local timezone for accurate day boundaries

### Changed
- **REFACTORED:** `src/pages/Dashboard.jsx`
  - Removed unused `courseLevel` state variable
  - Quick Actions: 3 buttons → 4 buttons (added "Browse Flashcards")
  - Grid layout: `grid-cols-2 lg:grid-cols-4`
  - Integrated AnonymousStats component

### Quick Actions (Updated)
| Button | Route |
|--------|-------|
| Browse Notes | `/dashboard/notes` |
| Browse Flashcards | `/dashboard/review-flashcards` |
| Create Flashcard | `/dashboard/flashcards/new` |
| Upload Note | `/dashboard/notes/new` |

### Privacy Safeguards Implemented
- Minimum 5 active users required to show class average
- No individual names shown in milestones
- Course-level filtering prevents cross-course comparison
- SQL function returns aggregates only, never individual data

## 2026-01-21: Critical Spaced Repetition & Timezone Bug Fixes

### Issue
Multiple critical bugs in spaced repetition system causing:
- Cards reappearing immediately after review (timezone issue)
- Progress not saving for professor-created cards (RLS conflict)
- Inflated "Reviews Due" count including new cards (logic mismatch)

### Root Causes

**1. Timezone Mismatch**
- Using `toISOString()` converted local dates to UTC
- For users in Western timezones or late-night India users, "tomorrow" became "yesterday"
- Example: Review at 11 PM IST → next_review_date = "today" UTC → card appears immediately

**2. Architectural Conflict**
- Original code wrote progress to `flashcards` table (professor-owned)
- RLS policy blocked student updates
- Silent failures, progress lost

**3. Logic Mismatch**
- Dashboard counted ALL accessible cards as "due"
- Included cards never studied (no entry in reviews table)
- Users saw inflated counts, then "All Caught Up" in Review Session

### Solution

**Date Handling Standardization**
- Replaced `toISOString()` with manual local date construction
- Format: `YYYY-MM-DD` using `getFullYear()`, `getMonth() + 1`, `getDate()`
- Ensures timezone-independent calendar date calculations

**Database Architecture**
- Moved student progress tracking to `reviews` table exclusively
- Explicit SELECT → UPDATE or INSERT logic (no atomic UPSERT)
- Each student maintains independent review schedule

**Dashboard Logic**
- "Reviews Due" = COUNT from `reviews` table WHERE `next_review_date <= today`
- Excludes new cards (never studied)
- Accurate representation of review workload

### Changes

**Modified Files:**
- `src/components/flashcards/StudyMode.jsx`
  - Replaced `toISOString()` with manual date string construction
  - Explicit SELECT before UPDATE/INSERT for reviews
  - Added detailed logging for debugging

- `src/pages/dashboard/Study/ReviewSession.jsx`
  - Query `reviews` table instead of `flashcards` table
  - Local date comparison for due cards
  - Proper handling of empty review queue

- `src/pages/Dashboard.jsx`
  - Count reviews from `reviews` table only
  - Local date calculation for "today"
  - Excludes new cards from "Reviews Due" count

### Technical Standards Established

**Enforced Rules (DO NOT VIOLATE):**
1. **Date Handling:** Never use `toISOString()` for `next_review_date` calculations
2. **Database Operations:** Reviews table is single source of truth for student progress
3. **Explicit Logic:** Use clear SELECT → UPDATE/INSERT flow (not atomic UPSERT)
4. **Definition of "Due":** Only cards in reviews table with `next_review_date <= today`

### Testing Verified
- [x] Cards reviewed today don't reappear until scheduled date
- [x] Timezone independence (works in IST, PST, GMT)
- [x] Dashboard count accuracy (matches Review Session)
- [x] Multi-user independence (students don't interfere with each other)
- [x] Progress persistence across sessions

### Impact
- ✅ Spaced repetition system now works reliably
- ✅ Student progress saves correctly regardless of card ownership
- ✅ Dashboard shows accurate review workload
- ✅ Timezone-independent (works globally)
- ✅ No duplicate reviews within same day

### Deployment
- Committed: 2026-01-21
- Status: Production
- Student Feedback: Pending verification

---
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