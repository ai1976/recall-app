# NOW - Current Development Status

**Last Updated:** 2026-03-30
**Current Phase:** Sprint 3.9 — Push Notification Infrastructure Fix

---

## Just Completed ✅

### Sprint 3.9 — Push notification CRON_SECRET mismatch (Mar 30, 2026)

- **Root cause diagnosed:** All push notifications (nightly study summary + morning review reminder) were silently failing since Sprint 3.6 shipped. Every pg_cron invocation returned HTTP 401 Unauthorized. Two separate issues:
  1. `cron-daily-study-summary` pg_cron job had the placeholder `YOUR_CRON_SECRET_HERE` as the `x-cron-secret` header value — never replaced with the real secret.
  2. Fixing it required setting a new `CRON_SECRET` value via Supabase CLI (`npx supabase secrets set`), which then broke `daily-review-reminders` (that job had the original correct hash). Resynced both jobs to the new secret.
- **Fix — `cron-daily-study-summary`:** Updated pg_cron job command to send correct `x-cron-secret` header. Confirmed 200 response on next invocation (16:45 UTC 2026-03-29).
- **Fix — `daily-review-reminders`:** Resynced pg_cron job to the new `CRON_SECRET` value after CLI secret rotation.
- **No code changes.** All fixes applied in Supabase: secret updated via CLI, cron jobs recreated via SQL.
- **Verification:** `daily-review-reminders` fires at 02:30 UTC daily — first post-fix delivery will be 2026-03-31 08:00 IST. Nightly summary fires tonight at 16:30 UTC (22:00 IST).
- **Affected users:** All students with push subscriptions. No notifications were ever delivered since Sprint 3.6 (2026-03-25). Aryan Pamnani confirmed as test case — active subscription, 224 cards due, all eligibility checks pass.

Files Changed: `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md` (infrastructure fixes only — no source code changes)

---

### Sprint 3.8 — Study time logging for mid-session exits and iOS force-quits (Mar 28, 2026)

- **Root cause diagnosed:** Leaderboard showing `< 1m` study time for students with 20–30 reviews. `logStudyModeSession()` was only called in `finishSession()` (final card rated). Students exiting mid-deck via `handleExit()` had reviews written (card-by-card) but zero study time logged. Visible across the CA Foundation study group.
- **Fix 1 — `handleExit()` now logs the session:** Added `logStudyModeSession()` fire-and-forget at the top of `handleExit()`. Covers all clean mid-session exits (back button, "Choose Different Topic", ReviewSession subject completion via Exit).
- **Fix 2 — `visibilitychange` listener:** Added `useEffect` that calls `logStudyModeSession()` when `document.visibilityState === 'hidden'`. Covers iOS force-quit, app switch, and tab close — all cases where no button is ever clicked. Listener cleaned up on unmount.
- **Double-logging prevention:** Both callers rely on the existing `localStorage.removeItem()` before the DB call inside `logStudyModeSession()`. The first caller clears the keys; the second caller finds empty keys and returns early.

Files Changed: `src/pages/dashboard/Study/StudyMode.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---

### Sprint 3.7 — All bugs resolved (Mar 27, 2026)

- **Bug 1A — iOS push banner never shown in-browser:** `PushPermissionBanner.jsx` had `if (!isSupported) return null` BEFORE the `needsIOSInstall` check. On iOS in regular Safari, `PushManager` is not in `window` → `isSupported = false` → the iOS install instructions were dead code. Fix: moved `handleDismiss` above the `needsIOSInstall` guard and moved the iOS install-instructions render path before the `isSupported` guard.
- **Bug 1B — Study time never logged after flashcard review session:** `handleRating()` in `StudyMode.jsx` handled the last-card completion inline and never called `finishSession()`, which is the only call site for `logStudyModeSession()`. Rating the last card — the primary completion path for every student — silently discarded the session. Fix: replaced inline completion code in `handleRating` with `finishSession()`.
- **Bug 2 — Android 8h "cap" confirmed as UX gap:** SQL diagnostics confirmed no code or RPC cap. `get_study_time_stats` is a clean SUM with no ceiling. Root cause: student didn't press Start after their break. Fix: added `postRecovery` state flag in `StudyTimerWidget`; after a recovery-prompt log, shows "Tap Start to begin a new session." hint. Cleared on Start.
- **Leaderboard protection gap in `handleStop`:** Diagnostic revealed a 76,035s (21.1h) session in the DB — logged via manual Stop with the tab kept open, bypassing the mount-time 16h discard. Fix: applied the same 3-tier policy to `handleStop` as mount (< 4h logs normally; 4–16h shows honest-session prompt; > 16h discards + destructive toast). Added `source: 'stale' | 'stop'` to `recoveryPrompt` state so the prompt uses context-aware copy: Stop-triggered shows encouraging framing (*"Wow, a Xh session! Just confirming…"*), mount-triggered keeps original suspicious-neutral copy.

Files Changed: `src/components/notifications/PushPermissionBanner.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/components/dashboard/StudyTimerWidget.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`

---

### Sprint 3.6 — Nightly Study Summary Push Notification (Mar 25, 2026)

- **New Edge Function** `cron-daily-study-summary` at `supabase/functions/cron-daily-study-summary/index.ts`. Runs every 15 minutes via pg_cron (`*/15 * * * *`). Delivers a personalised study summary push at exactly 22:00 local time for each student — fractional-offset timezones (IST = UTC+5:30) handled correctly via `Intl.DateTimeFormat` bucketing.
- **Eligibility:** `role = 'student'`, local time 22:00–22:14, active in last 7 days (study_sessions OR reviews).
- **Messages:** ≥60s logged → "Great work today 🎯" with formatted time + leaderboard nudge. <60s → "Time to open the books 📚" encouragement.
- **No sw.js changes** — push + notificationclick handlers were already complete.
- **No table changes** — `push_subscriptions` table already existed with all required columns.
- **No frontend changes** — notification is the feature; no preferences UI this sprint.
- **Stale subscriptions** deactivated (is_active = false) on 410/404, never hard-deleted.
- **pg_cron schedule** to be run in Supabase SQL Editor (see session notes below).

Files Changed: `supabase/functions/cron-daily-study-summary/index.ts` (NEW), `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

---

### Sprint 3.1 patch — Study Timer 3-tier recovery (Mar 25, 2026)

- **Root cause:** Students starting manual timer, switching to another app, and the browser reloading the page on return. The old code showed a recovery prompt (asking if they want to log it), which students either dismissed or didn't understand — losing the session.
- **Fix — StudyTimerWidget.jsx:** Replaced the single recovery prompt with three-tier logic evaluated on mount:
  - `< 4h elapsed` → auto-resume the timer from original start time, clock shows correct elapsed immediately (via `startMsRef` + `useEffect` on `timerState`)
  - `4–16h elapsed` → honest-session prompt: "Your timer ran for Xh Ym. Were you studying the whole time?" with three options: [Yes, log full time] | [Log less… → custom hours input, capped at elapsed] | [Discard session]
  - `> 16h elapsed` → silently discard (leaderboard protection — physically impossible as continuous study)
- **helpContent.js:** `study-timer` section updated to describe all three tiers. Old single-line tip replaced with a list + updated tip encouraging students to press Stop before switching away.
- **No SQL changes.** No new files. No schema changes.

Files Changed: `src/components/dashboard/StudyTimerWidget.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`

### Contextual Info Modal on all three public share pages (Mar 24, 2026)

- **GuideInfoModal.jsx:** New shared component at `src/components/GuideInfoModal.jsx`. Renders a subtle trigger button + shadcn `<Dialog>` modal. Pulls content directly from `SITUATIONS` in `guideContent.js` (single source of truth). Accepts `situationId` and `triggerLabel` props. Never navigates away — postAuthRedirect funnel on `/deck` and `/join` is fully preserved. "Got it" button closes the modal.
- **DeckPreview.jsx:** Added `<GuideInfoModal situationId="studying" />` below the "Sign in" line in the logged-out CTA block. Trigger: "New to Recall? See how Study Sets work →"
- **NotePreview.jsx:** Added `<GuideInfoModal situationId="content" />` below the "Sign in" line in the logged-out CTA block. Trigger: "New to Recall? See how Notes work →"
- **GroupJoin.jsx:** Added `<GuideInfoModal situationId="social" />` below the "Sign in" line in the logged-out CTA block. Trigger: "New to Recall? See how Groups work →"

Files Changed: `src/components/GuideInfoModal.jsx` (NEW), `src/pages/public/DeckPreview.jsx`, `src/pages/public/NotePreview.jsx`, `src/pages/public/GroupJoin.jsx`

---

### Sprint P3 — Student Guide discovery, polish & page completion (Mar 23, 2026)

- **Home.jsx:** Added "Student Guide" link to desktop nav (left of Login) and mobile nav. Plain text, matches existing nav link style. Appears on all screen sizes.
- **Home.jsx:** Added Student Guide banner above the footer — full-width muted strip (bg-gray-50, border-gray-200, rounded-lg) with "New to Recall? Browse the Student Guide" text and a blue pill `<Link to="/guide">`. Plain public-to-public navigation, no postAuthRedirect.
- **StudentGuide.jsx:** Added `useEffect` that sets `document.title = 'Student Guide — Recall'` on mount and resets to `'Recall'` on unmount.
- **StudentGuide.jsx:** Added "You are here." intro block (bg-indigo-50, border-indigo-100, rounded-xl) above the two-panel layout. Spans full content width. Includes inline `<Link to="/login">` for returning users.
- **StudentGuide.jsx:** Added "Still need help?" closing block (bg-gray-50, border-gray-200, rounded-xl, mt-10) after the last section in main content. Includes `<Link to="/">` with ArrowLeft icon. Not in sidebar nav.
- **StudentGuide.jsx:** Added "↑ Back to top" `<button>` at the bottom of the desktop sidebar — calls `window.scrollTo({ top: 0, behavior: 'smooth' })`. Styled text-xs text-gray-400 hover:text-gray-600 mt-6 px-3.

Files Changed: `src/pages/Home.jsx`, `src/pages/guide/StudentGuide.jsx`

### Sprint P2 — Student Guide content, step list, links & scroll spy (Mar 23, 2026)

- **guideContent.js:** New data file at `src/data/guideContent.js`. Exports `SITUATIONS` array — 9 situations, each with `id`, `sidebarLabel`, `emoji`, `headline`, and `steps[]`. Steps carry `label`, `detail`, `linkLabel`, `linkTo`, `isSignup`.
- **StudentGuide.jsx:** Replaced inline `situations` array with import from `@/data/guideContent`. Added `useNavigate` + `useState(activeId)`. Each section renders a numbered step list with optional "label →" chip buttons. Chips set `localStorage.postAuthRedirect` and navigate to `/login` (or `/signup` directly for `isSignup: true`).
- **Scroll spy:** `IntersectionObserver` watches all 9 sections (`threshold: 0.2`, `rootMargin: '-20% 0px -60% 0px'`). Active section highlighted in desktop sidebar (blue-50 bg, blue-700 text, border-l-2 border-blue-500) and mobile pill (bg-blue-600 text-white).

Files Changed: `src/data/guideContent.js` (NEW), `src/pages/guide/StudentGuide.jsx`, `docs/reference/FILE_STRUCTURE.md`

### Sprint P1 — Public /guide Student Guide shell (Mar 23, 2026)

- **StudentGuide.jsx:** New public page at `/guide` — no auth, no DB calls. Two-panel layout: sticky 260px sidebar (desktop) listing all 9 situations as clickable nav buttons; horizontal scrollable pill row (mobile). Smooth scroll to each section anchor on click.
- **Header bar:** "Recall" wordmark links to `/`, "Student Guide" tagline below, "Log in" link on the right.
- **9 situation sections:** enrollment, orientation, studying, behind, content, scoring, stats, social, reports — each with emoji + headline + placeholder "Actions coming in Sprint P2."
- **App.jsx:** Added `StudentGuide` lazy import + `/guide` route in the public no-auth-guard block.

Files Changed: `src/pages/guide/StudentGuide.jsx` (NEW), `src/App.jsx`

### Sprint 2.7-B — Help section Option C layout + role-based tabs (Mar 23, 2026)

- **Help.jsx:** Replaced horizontal tab bar with Option C layout — sticky left sidebar nav on desktop (`md:flex`, `w-44 shrink-0`), full-width accordion on mobile (`md:hidden`). Each tab on mobile is a collapsible header (blue when open, gray when closed). Clicking the active mobile tab closes it (`toggleMobileTab`). No more overflow, no clipping, no hidden tabs on any screen size.
- **helpContent.js:** `professor-guide` tab and all its sections updated from `roles: ['professor']` → `roles: ['professor', 'admin', 'super_admin']`. `prof-bulk-csv` section in Content tab updated same way. Admins and super_admins now see the full For Professors guide.
- **Flagging workflow:** Flag button already exists in StudyMode (Content error / Inappropriate / Other). Full backend workflow deferred to Sprint 2.8. Agreed design: Content error routes to professor first (edit or reject with reason); Inappropriate/Spam routes to admin only (conflict of interest). Duplicate flags from 3+ students auto-escalate priority. Student always notified of resolution.

Files Changed: `src/pages/dashboard/Help.jsx`, `src/data/helpContent.js`

### Notification click routing + Professor Analytics charts (Mar 23, 2026)

- **ActivityDropdown.jsx:** Upvote notifications now route to specific content. If `metadata.content_id` + `content_type === 'note'`, navigates to `/dashboard/notes/{id}`. Flashcard deck upvotes fall back to `/dashboard/my-contributions`. Graceful — if metadata not yet populated, falls back cleanly.
- **ProfessorAnalytics.jsx:** "Weakest Cards" renamed to "Challenging Cards" with explanatory note ("students find these harder to recall — not necessarily a content issue"). Added descriptive subtitle to Most Reviewed Cards panel too.
- **ProfessorAnalytics.jsx:** New Quality Distribution donut chart (PieChart from recharts) computed from subject-level averages. Shows Easy (≥4) / Medium (3–4) / Hard (<3) / Not Reviewed card counts. Placed in 2-column grid alongside Weekly New Students chart.

Files Changed: `src/components/layout/ActivityDropdown.jsx`, `src/pages/dashboard/ProfessorAnalytics.jsx`

### Sprint 3.5 — Leaderboard + Goals (Mar 22, 2026)

- **SQL:** `ALTER TABLE profiles ADD COLUMN daily_review_goal integer CHECK (>0 AND <=200)` + `daily_study_goal_minutes integer CHECK (>0 AND <=480)`. Both nullable — NULL means no goal set.
- **SQL:** `get_friends_leaderboard()` SECURITY DEFINER RPC. Returns caller + mutual friends (role='student' only) ranked by `reviews_this_week DESC`, `study_time_this_week_seconds` as tiebreaker. DENSE_RANK ties. Caller's own row always included. Week boundary: `date_trunc('week', CURRENT_DATE)`. All stats COALESCE to 0. Fields: `rank`, `user_id`, `full_name`, `is_self`, `reviews_this_week`, `study_time_this_week_seconds`.
- **SQL:** `get_following_leaderboard()` SECURITY DEFINER RPC. Same fields and ranking as friends leaderboard. Aggregates full followee set first (no pre-limit), then returns top 20 by rank + caller's own row regardless of rank — so caller's actual rank is always exact.
- **SQL:** `update_daily_goal(p_review_goal integer, p_study_goal_minutes integer)` SECURITY DEFINER RPC. Updates both columns on caller's profile row. Either value can be NULL to clear that type. Auth.uid() check before UPDATE.
- **LeaderboardWidget.jsx:** New isolated component at `src/components/dashboard/LeaderboardWidget.jsx`. Two tabs: Friends | Following. Friends tab fetches on mount; Following tab fetches lazily (first click only). Per row: rank, name (bold + blue bg for caller), reviews this week, study time. Skeleton loading (4 rows), error state with Retry, empty states. Manages own state — zero Dashboard re-renders.
- **GoalProgressWidget.jsx:** New component at `src/components/dashboard/GoalProgressWidget.jsx`. Three display states: no-goal (two buttons), editing (inline input, no modal), active goal (progress bar, today actual vs target, Edit link, green "Goal reached ✓" at 100%). Updates via `update_daily_goal` RPC; calls `onGoalUpdated` prop to sync parent state. Progress resets at midnight (derived from today's actual passed as prop).
- **Dashboard.jsx:** Profile select extended to fetch `daily_review_goal` + `daily_study_goal_minutes`. Added `reviewGoal`, `studyGoalMinutes`, `todayReviews` state. `fetchPersonalStats` now computes `todayReviews` (quality > 0, local date = today) from already-fetched reviews data — no extra network call. `GoalProgressWidget` inserted after Study Time section. `LeaderboardWidget` inserted after Anonymous Stats.
- **GroupDetail.jsx:** Batch Performance table — `#` rank column added as first column (non-sortable `<th>`). Rank = `idx + 1` from current `sortedStats` order — re-ranks live when any column header is clicked. Minor: `(row)` → `(row, idx)` in map.
- **helpContent.js:** New `leaderboard` section added to Social tab (after `follow-system`). New `daily-goals` section added to Getting Started tab (after `study-timer`). `prof-batch-performance` list updated to include `#` rank column description.

Files Changed: `src/components/dashboard/LeaderboardWidget.jsx` (new), `src/components/dashboard/GoalProgressWidget.jsx` (new), `src/pages/Dashboard.jsx`, `src/pages/dashboard/Groups/GroupDetail.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

### Sprint 3.4 — Follow System (Mar 22, 2026)

- **SQL:** `follows` table — `follower_id`, `followee_id` (both FK → `auth.users` ON DELETE CASCADE), `UNIQUE(follower_id, followee_id)`, `CHECK(follower_id <> followee_id)`. RLS enabled: INSERT (own follower_id), DELETE (own follower_id), SELECT (caller is follower OR followee). Indexes on both FKs.
- **SQL:** `follow_user(p_followee_id uuid)` SECURITY DEFINER RPC — idempotent INSERT ON CONFLICT DO NOTHING. Prevents self-follow. On new follow only (`GET DIAGNOSTICS ROW_COUNT`): inserts a `'follow'` notification into the `notifications` table for the followee.
- **SQL:** `unfollow_user(p_followee_id uuid)` SECURITY DEFINER RPC — DELETE from follows where `follower_id = auth.uid()`.
- **SQL:** `get_following_with_stats()` SECURITY DEFINER RPC — all users caller follows, with `user_id`, `full_name`, `course_level`, `role`, `reviews_this_week` (COUNT from `reviews.created_at >= date_trunc('week', CURRENT_DATE)`), `streak_days` (via `get_user_streak`), `study_time_this_week_seconds` (SUM from `study_sessions.session_date >= week start`), `following_since`. All stats COALESCE to 0. Ordered by `created_at DESC`.
- **SQL:** `get_follow_status(p_target_id uuid)` SECURITY DEFINER RPC — returns `{ is_following: boolean }` for profile page button initialisation.
- **Following.jsx:** New page at `src/pages/dashboard/Friends/Following.jsx`. Calls `get_following_with_stats`. Card style matches MyFriends.jsx exactly (avatar, name link, role badge, course, following-since, stats row). Unfollow button: calls `unfollow_user`, removes card optimistically, reverts on error. Loading: 3-card skeleton. Empty state with Users2 icon.
- **AuthorProfile.jsx:** Follow/Unfollow button added to action area for non-own profiles. Initial state from `get_follow_status` (fetched in the same `Promise.all` as existing profile/content calls). Follow: `UserPlus` icon, primary outline style. Following: `UserCheck ✓` (outline) → hover → `UserMinus Unfollow` (destructive). Both optimistic with revert on error. New imports: `UserCheck`, `UserMinus`.
- **App.jsx:** `/dashboard/following` route added, lazy-imports `Following.jsx`.
- **FriendsDropdown.jsx:** "Following" link added after "My Friends" (`Rss` icon). Header renamed "Friends & Following". "Find Friends" link renamed "Find People".
- **NavMobile.jsx:** "Following" button added in Groups section (after Study Groups), uses `Rss` icon.
- **helpContent.js:** `follow-system` section added to Social tab. All "Find Friends" references updated to "Find People"; dropdown references updated to "Friends & Following"; follow-system how-to updated to mention Find People as primary discovery surface.

Files Changed: `src/pages/dashboard/Friends/Following.jsx` (new), `src/pages/dashboard/Profile/AuthorProfile.jsx`, `src/App.jsx`, `src/components/layout/FriendsDropdown.jsx`, `src/components/layout/NavMobile.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

### Sprint 3.3 — Friend System Cleanup + Mutual Stats (Mar 22, 2026)

- **SQL:** `get_discoverable_users()` SECURITY DEFINER RPC — replaces direct `profiles` query in FindFriends. Filters to caller's `course_level`, excludes self + pending/accepted friends in both directions. Server-side email masking (first char + `***@` + domain). Returns: `user_id`, `full_name`, `masked_email`, `course_level`, `institution`, `role`.
- **SQL:** `get_my_friends_with_stats()` SECURITY DEFINER RPC — replaces two-step N+1 fetch in MyFriends. Confirmed friends only. Returns: `friendship_id`, `user_id`, `full_name`, `masked_email`, `course_level`, `role`, `reviews_this_week` (COUNT from `reviews.created_at >= date_trunc('week', CURRENT_DATE)`), `streak_days` (via `get_user_streak`), `study_time_this_week_seconds` (SUM from `study_sessions.session_date >= week start`), `friends_since` (`updated_at`). All stats COALESCE to 0.
- **FindFriends.jsx:** Removed `maskEmail` function, `friendships` state, `fetchFriendships`, and `getFriendshipStatus`. Replaced direct `.from('profiles')` query with `.rpc('get_discoverable_users')`. Uses `person.user_id` throughout. Action buttons simplified to single "Add Friend" (RPC already excludes pending/accepted). After sending, re-fetches and sender disappears from list automatically.
- **MyFriends.jsx:** Replaced two-step fetch with `.rpc('get_my_friends_with_stats')`. Added `loadingFriends` state with 3-card skeleton. Added stats row per friend card: streak (`Xd` / `—`), reviews this week, study time (`< 1m` / `45m` / `1h 23m`). Stats separated by a border-top row with colored icons. Empty state updated: "No friends yet — find people studying [course_level] to connect with" (course_level fetched from profiles in parallel on mount). Unfriend button still functional via `friendship_id` from RPC.
- **FriendRequests.jsx:** Audit — email was fetched but never rendered. Dropped `email` from profiles select. Avatar fallback changed from `email.charAt(0)` to `'?'`.
- **helpContent.js:** Updated `finding-friends` steps (removed stale "Filter by course level" step, added note that filtering is automatic and server-side). Added new `friend-stats` section explaining streak, reviews this week, and study time display.
- **Bugs closed:** FindFriends email exposure (raw email in network payload) + FindFriends no course filter (showed all users regardless of course).

Files Changed: `src/pages/dashboard/Friends/FindFriends.jsx`, `src/pages/dashboard/Friends/MyFriends.jsx`, `src/pages/dashboard/Friends/FriendRequests.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/reference/DATABASE_SCHEMA.md`

### Sprint 3.2 — Batch Group as Professor Tool (Mar 22, 2026)

- **SQL:** `get_batch_group_member_stats(p_group_id uuid)` SECURITY DEFINER RPC deployed. Returns one row per active student member: `user_id`, `full_name`, `reviews_this_week`, `streak_days` (via `get_user_streak`), `study_time_this_week_seconds` (from `study_sessions`), `last_active_date` (MAX review `created_at`). Two security checks inside: caller must be professor/admin/super_admin; group must have `is_batch_group = true`. Week boundary: `date_trunc('week', CURRENT_DATE)` (Monday start, server UTC). All zero-activity fields return `0` via COALESCE.
- **MyGroups.jsx:** Students now see zero batch groups — server-side filter via `.rpc('get_user_groups').eq('is_batch_group', false)` means batch group data never hits the network for students. `get_my_batch_groups` is skipped entirely for students. Role fetched from profiles at the start of `fetchGroups`. Professors/admins unchanged.
- **GroupDetail.jsx:** Added `role` state (fetched in parallel with `get_group_detail`). Added `fetchBatchStats` calling `get_batch_group_member_stats`. When `group.is_batch_group && role === 'student'`: redirects to `/dashboard/groups` (safety guard). When `group.is_batch_group && role is professor/admin/super_admin`: renders Batch Performance view — group name + "Batch Performance" badge + member count header; sortable table (click header to toggle asc/desc) with columns: Name, Reviews This Week, Streak (`Xd` / `—`), Study Time This Week (`< 1m` / `45m` / `1h 23m`), Last Active (`Today` / `X days ago` / date). Loading skeleton, error state with Retry, empty state. Added `formatStudyTime` (matching Sprint 3.1), `formatLastActive`, `handleSort`, `SortHeader` inner component. New lucide imports: `Shield`, `ChevronUp`, `ChevronDown`, `RefreshCw`.
- **AnonymousStats.jsx:** Added `courseLevel` prop. "Class Average" progress bar label now reads `"vs all Recall students studying [course_level]"` when course_level is known, or `"vs all Recall students"` when null/empty.
- **Dashboard.jsx:** Added `userCourseLevel` state. Set from `profile.course_level` in `fetchDashboardData`. Passed as `courseLevel={userCourseLevel}` to `<AnonymousStats>`.
- **helpContent.js:** New `prof-batch-performance` section added to For Professors tab (between `prof-batch-groups` and `prof-needs-attention`). Explains: what the view is, why students don't see it, how to navigate to it, column explanations, Last Active caveat (reflects review only, not manual timer), batch group creation note (admin only).

Files Changed: `src/pages/dashboard/Groups/MyGroups.jsx`, `src/pages/dashboard/Groups/GroupDetail.jsx`, `src/components/dashboard/AnonymousStats.jsx`, `src/pages/Dashboard.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`

### Sprint 3.1 — Study Timer (Mar 22, 2026)

- **SQL:** `study_sessions` table — `ended_at` and `duration_seconds` NOT NULL by design (only completed sessions stored). RLS: authenticated INSERT/SELECT own rows. Index on `(user_id, session_date)`. `get_study_time_stats(p_user_id uuid, p_local_date date)` SECURITY DEFINER RPC returns `today_seconds`, `week_seconds`, `today_sessions`, `week_sessions`. `p_local_date` is required because `session_date` is stored as the user's local date — DB cannot derive "today" in UTC correctly for users in UTC+5:30.
- **StudyTimerWidget.jsx:** New isolated component at `src/components/dashboard/StudyTimerWidget.jsx`. Manual start/stop timer for offline study. Clock ticks via `clockRef.current.textContent` (direct DOM) — zero Dashboard re-renders per second. States: idle → running → saving → idle. On mount: checks `recall_session_started_at` + `recall_session_source = 'manual'` in localStorage; if ≤ 4h old, shows recovery prompt ("Unfinished session from X ago — Log it?"); if > 4h, silently discards. On stop: single INSERT into `study_sessions`. `onSessionLogged` callback triggers Dashboard stats refresh.
- **Dashboard.jsx:** Student dashboard gets new "⏱ Study Time" section — 3-col grid (Today card, This Week card, StudyTimerWidget). Stats fetched via `get_study_time_stats` RPC. `formatStudyTime` helper: `< 1m` / `45m` / `1h 23m`. Stats refresh immediately after each manual session via `onSessionLogged`. `authUserId` state added to make callback stable. `Clock` added to lucide imports.
- **StudyMode.jsx:** Session start written to localStorage (`recall_session_started_at`, `recall_session_source = 'study_mode'`) via `useEffect` that fires when `loading` becomes `false` and cards are ready. Preview mode excluded. `logStudyModeSession()` called fire-and-forget from `finishSession()` — single INSERT, clears localStorage first to prevent double-logging, silent fail on error.
- **helpContent.js:** `study-timer` section added to Getting Started tab. Explains auto-capture vs manual, stale session recovery, and why study time matters (leaderboard, goals, friend comparison).
- **Help.jsx:** `Timer` added to lucide imports and `ICON_MAP`.

Files Changed: `src/components/dashboard/StudyTimerWidget.jsx` (new), `src/pages/Dashboard.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/data/helpContent.js`, `src/pages/dashboard/Help.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

### Fix — Dashboard placeholder card consistency (Mar 21, 2026)

- **Professor "Needs Attention" card:** Sprint 2.7A settled this as always-visible. Sprint 2.9 wrapped it in `{needsAttentionItems.length > 0 && (...)}` without approval, hiding it when empty. Fix restores the settled 2.7A design — gray "No flags on your content. All clear!" when empty, amber with flag list when active. All other 2.9 changes (Edit/Mark resolved buttons, student My Reports card) are approved and unchanged.
- **Admin + Super Admin "Needs Review" card:** Zero-state title was `'Flagged Content'` — changed to `'Needs Review'` so the placeholder label is consistent with section intent.

Files Changed: `src/pages/Dashboard.jsx`

### Sprint 2.9 — Flagged content workflow completion (Mar 21, 2026)

- **SQL:** Deployed `auto_resolve_content_error_flags()` SECURITY DEFINER trigger function. Fires on UPDATE of `notes` (as `'note'`) or `flashcards` (as `'flashcard'`); resolves all matching pending `content_error` flags automatically with `resolution_note = 'Content updated by creator'`. Triggers: `trg_auto_resolve_note_flags` (notes), `trg_auto_resolve_flashcard_flags` (flashcards).
- **Dashboard.jsx:** Professor Needs Attention card — "Review" button replaced with "Edit" + "Mark resolved" pair. "Edit" navigates to edit page; "Mark resolved" calls `resolve_content_flag` RPC and refreshes the list in place.
- **Dashboard.jsx:** Student dashboard — "My Reports" card added. Fetches up to 10 of the student's own submitted flags directly from `content_flags` (RLS allows `flagged_by = auth.uid()`). Shows content_type, reason label, and status pill (Under review / Resolved / Dismissed / Content removed). Hidden if no reports submitted. `myReports` state + fetch scoped to non-professor/admin roles.
- **helpContent.js:** Added second tip to `flagging-content` section: students can track report status via dashboard "My Reports".

### Sprint 2.8-B — Full flagged content workflow (Mar 21, 2026)

- **SQL:** Migrated `content_flags` table (renamed `reporter_id` → `flagged_by`, added `details`, `priority`, `resolved_by`, `resolution_note`, `resolved_at`, CHECK constraints, indexes). Replaced `submit_content_flag` (v2: `p_details` param, dedup check, priority auto-escalation at 3+ flags, `jsonb` return). Deployed `get_my_content_flags` (professor queue — content_error flags on own content), `get_admin_flags` (admin queue with status filter), `resolve_content_flag` (resolve/reject/remove with note).
- **FlagButton.jsx:** Added details `Textarea`. Fixed `SelectItem` values to match DB CHECK constraint (`content_error`/`inappropriate`/`other`). Handles `already_flagged` jsonb response with toast. Resets details on close/success.
- **Dashboard.jsx:** Professor "Needs Attention" placeholder replaced with live card from `get_my_content_flags` — shows flag count, priority badge, details snippet, Review button. Admin/super_admin "Needs Review" placeholder replaced with wired card showing pending flag count; links to Admin Dashboard Content tab.
- **AdminDashboard.jsx:** Flagged Content section added at top of Content Moderation tab. Status filter (Pending/Resolved/Rejected/Removed). Dismiss (reject) and Remove (delete content + mark removed) actions call `resolve_content_flag`. High-priority items show red border.
- **helpContent.js + Help.jsx:** Student flagging guide added to Content tab. Professor "Responding to Content Flags" guide added to For Professors tab. Admin "Reviewing Flagged Content" guide added to For Admins tab. `Flag` and `AlertTriangle` added to ICON_MAP.

### Sprint 2.8-A — Public note sharing + WhatsApp OG previews (Mar 21, 2026)

- **SQL:** Deployed `get_public_note_preview()` SECURITY DEFINER RPC (returns note metadata only for `visibility = 'public'`). Fixed column name: `n.user_id` not `n.created_by`.
- **middleware.js:** Added `NOTE_PATH` regex, `noteMatch` variable, extended guard condition, added `/note/:path*` to matcher config. Note handler fetches via `get_public_note_preview` RPC and returns OG-tagged HTML for bots.
- **NotePreview.jsx:** New public page at `/note/:noteId`. Fetches via RPC (anonymous-safe). Shows note title, subject/topic pills, author, description, blurred content preview. Auth-aware CTA (sign up / log in / open note). `postAuthRedirect` set before navigation.
- **App.jsx:** Added `/note/:noteId` public route + lazy import for `NotePreview`.
- **NoteDetail.jsx:** Added `Share2` to lucide-react import, `handleShare()` handler (Web Share API with WhatsApp fallback), Share button visible only when `note.visibility === 'public'`.
- **helpContent.js:** Added `sharing-whatsapp` section to Social tab (all roles). Replaced `prof-share-content` section body in For Professors tab with specific WhatsApp sharing steps.

### Sprint 2.7-B — Role-based Help section (Mar 21, 2026)

- **helpContent.js:** Added `prof-bulk-csv` professor-only section to the Content tab. Appended two new role-gated tabs: "For Professors" (`roles: ['professor']`, 5 sections) and "For Admins" (`roles: ['admin', 'super_admin']`, 7 sections including 3 super_admin-only sub-sections).
- **Help.jsx:** Imported `useRole`, added `visibleTabs` useMemo that filters tabs and sections by role. All 4 `HELP_TABS` references replaced with `visibleTabs`. Added `GraduationCap` and `Shield` to lucide-react import and `ICON_MAP`. `searchResults` dependency array updated to include `visibleTabs`.
- No SQL. No new files. No new routes.

**Role visibility:**
- Student: 6 tabs (existing) — professor and admin tabs hidden
- Professor: 7 tabs (existing 6 + For Professors)
- Admin: 7 tabs (existing 6 + For Admins, without super_admin-only sections)
- Super Admin: 7 tabs (existing 6 + For Admins, all sections including super_admin-only)

### Sprint 2.7-A — Admin & super_admin role dashboards (Mar 21, 2026)

- **Dashboard.jsx:** Extended role conditional from binary (professor/student) to 4-way (professor / admin / super_admin / student).
- **Admin view:** 3 navigation cards — Admin Dashboard (`/admin`), Admin Analytics (`/admin/analytics`), Manage Topics (`/admin/bulk-upload-topics`) — plus "Needs Review" flagged content placeholder (amber/red card, Sprint 2.8 marker) + Activity Feed.
- **Super Admin view:** Same 3 admin cards + a visually distinct "Super Admin Tools" section (red border, "Elevated" badge) with SA Dashboard (`/super-admin`) and SA Analytics (`/super-admin/analytics`) + "Needs Review" placeholder + Activity Feed.
- **Professor view:** "Needs Attention" placeholder is now a visible amber card (was a commented-out code comment). Will wire to `content_flags` table in Sprint 2.8.
- **New imports:** `Shield`, `BarChart3`, `Users`, `Flag` added to Dashboard.jsx.

### Sprint 2.6 — Nav consolidation, professor dashboard, educator RLS fix, motivation tips (Mar 21, 2026)

- **Part A — NavDesktop.jsx:** Replaced 5 standalone admin/super_admin nav links with a single "Manage ▾" dropdown. Added `isManageActive()` helper. Max 5 top-level nav items for admin/super_admin.
- **Part B — Dashboard.jsx:** Added `userRole` state set from `profile.role`. Professor role renders dedicated dashboard (Your Content + Quick Actions + Activity Feed).
- **Part C — Home.jsx:** Educator fetch replaced from direct `.from('profiles')` (RLS-blocked for anon users) to `.rpc('get_public_educators')`. SQL function `get_public_educators()` deployed in Supabase first (SECURITY DEFINER). Educator names now appear on landing page.
- **Part D — AnonymousStats.jsx:** `getComparisonMessage()` rewritten with 4 context-aware states. "Below average" shows exact review count needed. Zero-state shows dynamic message. Class Milestones footer varies by whether student studied today.

### Sprint 2.5 + Refinements — Landing Page (Mar 20, 2026)

**All changes in `src/pages/Home.jsx` — no SQL, no new files.**

**Sprint 2.5 (initial):**
- Hero headline: "Remember Everything. Ace Every Exam." → "The Revision Operating System."
- Hero subheadline: updated to institute/spaced-repetition positioning
- Hero pill 2: "Upload unlimited notes" → "SM-2 spaced repetition"
- Hero CTAs: single button → dual CTA (B2B + B2C); educator link → "Already a student? Log in"
- How It Works: renamed, reordered 4 steps, TrendingUp replaces Share2 in step 4
- Features: renamed section, SM-2 card moved to position 1 with updated copy
- Educator Content: repositioned as institute pitch
- For Educators: renamed to For Institutes & Educators, all 4 bullets rewritten
- Final CTA: heading/body/buttons updated; footer tagline updated
- Email: all 7 occurrences replaced with hello@recallapp.co.in

**Post-sprint refinements:**
- Stats: hero pill 3 → "flashcards & notes" (not "items created"); grid labels → "Flashcards" / "Notes"
- Hero CTAs: B2C "Start free" promoted to primary gradient button; B2B demoted to text link below stats with horizontal divider separator
- Blue section: reframed as browseable library ("Free to Browse" badge, B2C-neutral description, simplified stat labels, updated quote)
- For Institutes right panel: replaced misleading stat cards with 3 benefit statements (Ready in 48 Hours / Students Auto-Enrolled / Content Pre-loaded); "When your institute is on Recall..." pitch moved here
- Hero branding: "Recall" promoted to h1 (text-7xl); "The Revision Operating System." demoted to gradient subtitle — product name now leads
- How It Works step 1: heading shortened to "Start Reviewing Now"; description made B2C-agnostic (removed "your institute" framing)
- How It Works step 4: heading shortened to "Never Forget Again" (fits one line)
- Features: renamed section, SM-2 card moved to position 1 with updated copy
- Educator Content section: repositioned as institute pitch ("For Institutes & Coaching Classes")
- For Educators section: renamed "For Institutes & Educators", all 4 bullets updated, CTA updated
- Final CTA: new heading, new body, "Start free" button, footer note updated
- Footer tagline: updated to revision OS positioning
- Email: all 7 occurrences of `recall@moreclassescommerce.com` replaced with `hello@recallapp.co.in`
- **Hero colour swap (intentional design decision):** "Recall" h1 gets the gradient (from-blue-600 to-purple-600 bg-clip-text text-transparent); "The Revision Operating System." is solid text-gray-900 font-bold — this is deliberate so the eye lands on the brand name first. Do NOT revert.

**RLS note (diagnostic, not fixed):** Lines 37–47 fetch educator profiles via direct `.from('profiles')` query in an unauthenticated context. This silently returns 0 rows for anonymous users due to RLS. The educator list in the right panel of the "For Institutes & Educators" section will not display — it falls back to the static "Growing Community" / "Quality Platform" cards. Not fixed in Sprint 2.5.

**Email used:** `hello@recallapp.co.in` (Google Workspace, domain verification in progress)

### Sprint 2.4 — Middleware Extension + AuthContext Cleanup (Mar 20, 2026)

**SQL deployed:**
- `fn_create_profile_on_signup` + `trg_create_profile_on_signup` — SECURITY DEFINER trigger on `auth.users` INSERT; creates profile row from `raw_user_meta_data`; replaces broken client-side insert; timezone defaults to `Asia/Kolkata` and is synced on first login

**Frontend changes:**
- `middleware.js` — extended to handle `/join/:token` OG tags alongside existing `/deck/:deckId`; matcher updated to `['/deck/:path*', '/join/:path*']`; calls `get_group_preview` RPC (the only join preview RPC that exists); parses nested `{ group, stats }` response; `buildOgResponse()` helper extracted to eliminate duplication; all deck logic unchanged
- `AuthContext.jsx` — removed client-side `profiles.insert()` from `signUp()` and the 100ms delay; DB trigger is now the authoritative profile creation path

**Key diagnostic finding (Sprint 2.4 pre-flight):**
- Sprint prompt stated a profile-creation trigger was deployed in a prior sprint — this was incorrect. Pre-flight Diagnostic 1 confirmed no such trigger existed. The client-side insert was the only profile creation mechanism and was silently failing for email-confirmation signups. Trigger was created fresh in this sprint before removing the client-side insert.
- `get_group_join_preview` RPC mentioned in sprint spec does not exist — only `get_group_preview` exists; middleware updated accordingly.

### Sprint 2.3 — Group Invite Infrastructure, Auto-Batch Trigger, Group Types (Mar 19, 2026 — session 5)

**SQL deployed:**
- `study_groups` table: added `invite_token` (uuid, gen_random_uuid()), `group_type` (text CHECK 'batch'|'system_course'|'custom'), `linked_course` (text nullable); backfilled `group_type = 'batch'` for existing batch groups
- `create_study_group` RPC: updated signature with `p_group_type` and `p_linked_course` params
- `fn_auto_enroll_batch_group` trigger: fixed 3 bugs — role exclusion (admin/super_admin/professor skip), account_type exclusion (self_registered skips), institution matching added
- `get_group_preview` RPC: removed `is_batch_group = false` filter (batch group tokens now work); fixed `p.current_streak` (column doesn't exist — hardcoded 0); fixed `badges` table name → `badge_definitions`
- `join_group_by_token` RPC: removed `is_batch_group = false` filter

**Frontend changes:**
- `CreateGroup.jsx` — added group type selector: fetches user's `course_level`, shows radio options (system course or custom); passes `p_group_type` and `p_linked_course` to RPC
- `GroupJoin.jsx` — postAuthRedirect: replaced URL params (`?redirect=`) with `localStorage` pattern matching DeckPreview
- `App.jsx` — postAuthRedirect architecture: added `AppContent` useEffect for email confirmation path; PostAuthRedirect component tried and removed (React 18 StrictMode double-invocation bug)
- `Login.jsx` — postAuthRedirect: reads and removes `localStorage.getItem('postAuthRedirect')` BEFORE `signIn()` call (prevents AppContent useEffect race); navigates to redirect or `/dashboard` after success; restores key on error

**postAuthRedirect flow (confirmed working end-to-end):**
1. Unauthenticated user visits `/join/:token` → sees group preview
2. Clicks "Sign in" → `localStorage.setItem('postAuthRedirect', '/join/:token')` → `/login`
3. Logs in → Login.jsx reads redirect (captured before signIn to beat AppContent race) → navigate to `/join/:token`
4. GroupJoin loads again, user authenticated → "Join Group" button → `join_group_by_token` RPC → navigate to `/dashboard/groups/:groupId`

**Root cause of postAuthRedirect race (documented for future reference):**
- AppContent `useEffect` fires during `await signIn()` (Supabase triggers onAuthStateChange synchronously before the Promise resolves)
- Reading localStorage BEFORE `signIn()` prevents the race — AppContent finds nothing and does nothing; Login.jsx holds the redirect value in a local variable

### postAuthRedirect — Login deep-link after signup/login from DeckPreview (Mar 19, 2026 — session 4)

**Feature complete:**
- `DeckPreview.jsx` (already done) — "Sign up free" and "Sign in" buttons store `postAuthRedirect` key in `localStorage` pointing to `/dashboard/review-flashcards?deck=:deckId`
- `Login.jsx` — after successful `signIn`, reads `localStorage.getItem('postAuthRedirect')`, clears it, and navigates to that URL (or `/dashboard` as fallback)

**Full user flow (WhatsApp share → signup → study session):**
1. Professor/student shares deck URL (`/deck/:deckId`) on WhatsApp
2. Anonymous visitor opens link → sees `DeckPreview` page with front-side preview + "Sign up free" CTA
3. Clicks "Sign up free" → redirect target stored in `localStorage`
4. Completes signup → email confirmation → returns to app, logs in
5. `Login.jsx` reads redirect from `localStorage` → navigates to `/dashboard/review-flashcards?deck=:deckId`
6. `ReviewFlashcards.jsx` reads `?deck` param → auto-launches study session for that specific deck

**Note:** For professor decks, Tier B students land on the study session but only access the 10-card preview (same as dashboard experience). The deep-link is honest — it takes the user to the right place; access tier governs what they see.

### Post-Deploy Bug Fixes — Public Deck Preview + Groups Page (Mar 19, 2026 — session 3)

**Bugs fixed (SQL):**
- `get_my_batch_groups` RPC — professor path was only returning primary course batch group; rebuilt to return ALL batch groups for professors; client-side `activeCourse` filter in MyGroups already handles per-course display correctly
- `get_public_deck_preview` RPC — was fetching preview flashcards via `WHERE deck_id = p_deck_id` which always returns 0 rows (`deck_id` on flashcards is never populated); fixed to join on `(user_id, subject_id, topic_id, custom_subject, custom_topic)` — same logic as `update_deck_card_count` trigger

**Bugs fixed (frontend):**
- `DeckPreview.jsx` — removed `ContentPreviewWall` (WhatsApp lead capture form); anonymous visitors should be shown a "Sign up free" CTA, not a WhatsApp form — signing up is free and immediately available, not "coming soon"; CTA updated to honest copy that doesn't promise full access (misleading for professor decks where Tier B students only get 10 card preview)

**Documentation updated:**
- `CLAUDE.md` — added critical rule: `deck_id` on `flashcards` is never populated; always join on 5 grouping columns to fetch flashcards for a deck
- `DATABASE_SCHEMA.md` — added warning + exact join SQL pattern under flashcard_decks section

**Sprint backlog added:**
- WhatsApp share button for notes — requires public `/note/:noteId` page first (same pattern as DeckPreview); without it, sharing `/dashboard/notes/:noteId` only works for logged-in users

**Pending before deploy:**
- Commit and push this session's changes

### Admin Role Fixes + Batch Group Enrolment (Mar 19, 2026 — session 2)
Continued from Sprint 2 QA session. All batch groups created and students enrolled. Admin/super_admin role management finalised.

**Bugs fixed (SQL):**
- `profile_courses` — deleted entries for admin/super_admin; was causing CourseContext to set `activeCourse` → MyGroups filter hid all batch groups not matching that course
- `admin_audit_log` FK on `target_user_id` — changed from `NO ACTION` to `ON DELETE SET NULL`; retains audit records when a user profile is deleted
- Created `admin_delete_user_data` SECURITY DEFINER RPC — super_admin user hard delete was silently failing (direct `.delete()` on profiles blocked by RLS → profile remained → FK blocked auth user deletion from Supabase dashboard)
- Created `remove_group_member` SQL function — allows group admins to remove members from GroupDetail

**Bugs fixed (frontend):**
- `SuperAdminDashboard.jsx` — `deleteUser` replaced broken direct delete cascade with `rpc('admin_delete_user_data')`; deletion now works correctly; auth record still requires manual deletion from Supabase dashboard (service role required)
- `Dashboard.jsx` — profile completion modal no longer loops for admin/super_admin after `course_level` was nulled; modal skipped when role is admin or super_admin
- `MyGroups.jsx` — parallel fetch of `get_user_groups` + `get_my_batch_groups`; server-side role logic in `get_my_batch_groups` replaces fragile client-side `isAdmin` timing check; activeCourse filter scoped correctly (batch groups from server not re-filtered)

**Data deployed:**
- CA Foundation batch group created
- CA Intermediate batch group created
- All enrolled students bulk-enrolled into matching batch groups (CA Foundation + CA Intermediate in single SQL pass)
- `course_level` nulled for all admin/super_admin profiles
- `profile_courses` cleared for all admin/super_admin profiles

**Role management design finalised:**
- Super Admin: hard delete + promote/demote all roles (Professor, Admin)
- Admin: suspend + grant/revoke access only — no role changes, no hard delete
- Professor promotion: stays in SuperAdminDashboard (student self-registers → super admin promotes via ↑ Prof button)
- Admin creation: future invite-only route via SuperAdminDashboard (separate sprint)

**Pending before deploy:**
- Commit all changes (Sprint 2 + QA session 1 + session 2)
- Push to Vercel + verify on live URL
- Set env vars in Vercel Dashboard: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (for middleware)

### Sprint 2 QA + Batch Group Institution Logic (Mar 19, 2026)
Full end-to-end testing of Sprint 2 features. Multiple bugs found and fixed. Batch group isolation by institution added.

**Bugs fixed (SQL):**
- `access_requests` — added DEFAULT `'pending'` on `status`, `now()` on `requested_at` (INSERT was failing)
- `access_requests` — added `email` column; rebuilt `submit_access_request` RPC with email param
- Granted `anon` EXECUTE on `submit_access_request`, `get_public_deck_preview`, `get_group_preview`, `join_group_by_token`
- `notifications_type_check` constraint — added `'access_request'` type
- `notify_access_request` function — fixed WHERE clause (`account_type` → `role`) so admins actually receive notifications
- `profiles` — added `status TEXT NOT NULL DEFAULT 'active'` column (User Management was showing empty list)
- `profiles` — added `has_seen_onboarding BOOLEAN NOT NULL DEFAULT false` column
- Created `handle_new_user()` SECURITY DEFINER trigger on `auth.users` — permanent fix for profile creation with email confirmation ON
- Bulk-fixed 9 orphaned accounts (auth users with no profile row)

**Bugs fixed (frontend):**
- `DeckPreview.jsx` — `contentType` changed from `'deck'` to `'flashcard_deck'` (check constraint violation)
- `ReviewFlashcards.jsx` + `BrowseNotes.jsx` — blank Course dropdown fixed for users with no content in their registered course

**Batch group institution logic (new):**
- Added `batch_institution` column to `study_groups`; backfilled existing batch groups with `'More Classes Commerce'`
- Rebuilt `create_batch_group` RPC — now accepts `p_institution`; auto-enrolls enrolled students matching course + institution
- Created `enroll_user_in_batch_group` RPC — called when Grant Access is clicked; adds student to matching batch group
- Backfilled `institution = 'More Classes Commerce'` for all enrolled students
- `AdminDashboard.jsx` — create batch form now includes Institution field (required, pre-filled)
- `AdminDashboard.jsx` — `grantAccess` now calls `enroll_user_in_batch_group` after setting `account_type = 'enrolled'`

**Pending before deploy:**
- Create CA Foundation + CA Intermediate batch groups in local/prod (user doing this now)
- Commit all Sprint 2 + QA changes
- Push to Vercel + verify on live URL
- Set env vars in Vercel Dashboard: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (for middleware)

### Sprint 2 — Batch Groups, WhatsApp Invite Links, Public Deck Preview, Onboarding Modal (Mar 18, 2026)
All SQL deployed in previous session. Frontend complete this session:
- **MyGroups.jsx** — "Official" badge + course label for batch groups; Leave/Delete hidden for batch groups
- **AdminDashboard.jsx** — Batch Groups tab with list + create form (calls `create_batch_group` RPC)
- **GroupDetail.jsx** — WhatsApp invite link section (Copy Link + WhatsApp share); hidden for batch groups
- **GroupJoin.jsx** (new) — Public `/join/:token` page with group stats from `get_group_preview` RPC
- **DeckPreview.jsx** (new) — Public `/deck/:deckId` page with first 5 items from `get_public_deck_preview` RPC
- **ReviewFlashcards.jsx** — Share button on public deck tiles (Web Share API + wa.me fallback)
- **ContentPreviewWall.jsx** — Fixed anon-insert RLS bug (now calls `submit_access_request` RPC)
- **Dashboard.jsx + OnboardingModal.jsx** — 3-step onboarding modal on first login
- **middleware.js** (new) — Vercel Edge Middleware for OG tag injection on `/deck/:deckId` bot requests
- **App.jsx** — Public routes `/join/:token` and `/deck/:deckId` added without auth guard

### Sprint 7 — Content Access Tiers, Flagging, WhatsApp Lead Capture + Preview Bug Fixes (Mar 17, 2026)
Implemented Tier A/B access control for professor content, content flagging ("Report" button), and WhatsApp lead capture form. Fixed three Tier B flashcard preview bugs: deck tile count, progress bar visual, and ContentPreviewWall not appearing after 10 cards.

**Delivered:**
1. **Content Access Tiers:** `self_registered` (Tier B) users see first 10 cards of professor decks (preview mode), then hit ContentPreviewWall lead capture. Full access for `enrolled` (Tier A) users.
2. **ContentPreviewWall component:** Name/WhatsApp/course lead capture form; submits to `access_requests` table.
3. **FlagButton component:** "Report" button with reason dropdown (Content error / Inappropriate / Other); calls `submit_content_flag` RPC.
4. **Admin Dashboard — Access Requests tab:** Full table with status dropdown (pending/contacted/enrolled/dismissed).
5. **Admin nav links:** Added Admin Dashboard link to NavDesktop and NavMobile.
6. **Admin stat fix:** Switched `fetchStats` to use `get_platform_stats` SECURITY DEFINER RPC — matches landing page counts.
7. **Preview bug fixes:**
   - Deck tile shows "Preview: first 10 of N items" (was "Preview only (first 10 items)")
   - Progress bar fills proportionally (10/total) leaving grey remainder as visual cue — denominator passed via `totalCards` URL param
   - ContentPreviewWall now correctly appears after all 10 preview cards are rated (handleRating + advanceOrFinish now set `currentIndex = flashcards.length` instead of calling onExit when previewModeParam is true)
   - Preview mode banner shows "PREVIEW MODE — first 10 of N items"

**Files changed:**
- `src/pages/dashboard/Study/StudyMode.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Content/NoteDetail.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/admin/AdminDashboard.jsx`
- `src/components/ui/ContentPreviewWall.jsx` (new)
- `src/components/ui/FlagButton.jsx` (new)
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`

---

### Sprint 6 — Data Contract UI Enforcement + Schema Documentation (Mar 17, 2026)
Enforced the data contract in `FlashcardCreate.jsx`: system course → FK-only subject/topic dropdowns; custom course → free-text only. Removed the raw-row-download `fetchAllCourses()` function. Updated `DATABASE_SCHEMA.md` with 10 previously undocumented columns.

**Delivered:**
1. **`FlashcardCreate.jsx` — data contract enforcement:**
   - Removed `fetchAllCourses()` (was downloading all notes + flashcards + profiles rows for client-side dedup). Course dropdown now sources directly from the `disciplines` state already loaded by `fetchDisciplines()`.
   - Removed `allCourses` state.
   - Added `isSystemCourse` derived const (no new state).
   - System course selected → FK subject combobox only (no "Add custom subject" option); helper text with "Switch to custom course →" escape hatch.
   - Custom course selected → plain text inputs for subject (required) and topic (optional).
   - Extended targetCourse `useEffect` to reset `showCustomSubject`, `customSubject`, `showCustomTopic`, `customTopic` on course switch.
   - `handleSubmit` split into two paths: system course enforces FK fields + nulls out free-text; custom course enforces free-text + nulls out FK fields. Defense in depth at both UI and submit layers.
2. **3 SQL scripts provided for dirty data backfill** (user deploys at own discretion):
   - `[DIAGNOSTIC] custom_subject rows that match a system subject`
   - `[FIX] Backfill subject_id from custom_subject where match exists`
   - `[DIAGNOSTIC] custom_subject rows with no subject match (manual review needed)`
3. **`docs/reference/DATABASE_SCHEMA.md`** — flashcards table updated:
   - 10 undocumented columns added: `custom_subject`, `custom_topic`, `question_type`, `options`, `correct_answer`, `hints`, `points_to_remember`, `scenario`, `subtype`, `source`.
   - Column count updated: 24 → 34.
   - Concept Card exclusion rule documented.

### Sprint 5 — Super Admin Analytics Page (Mar 16, 2026)
New dedicated analytics page for super_admins at `/super-admin/analytics`, plus a fix for the broken tab stub in `SuperAdminDashboard`.

**Delivered:**
1. **Tabs bug fix — `SuperAdminDashboard.jsx`:** Replaced broken `<Tabs>` (stub with no state/logic) with `const [dashboardTab, setDashboardTab] = useState('users')` + conditional rendering. `scrollToUserManagement()` now calls `setDashboardTab('users')` directly instead of `document.querySelector('[value="users"]').click()`. Added `TabButton` component matching AdminDashboard styling.
2. **4 Supabase RPCs deployed:**
   - `get_super_admin_header_stats` — total users, content creators, reviews this month, active courses (1 row)
   - `get_super_admin_cohort_comparison` — per active discipline: student count, published items, reviews this week, avg reviews/student, 7-day retention rate; fixed `LANGUAGE sql` to avoid 42702 ambiguous column error
   - `get_creator_leaderboard` — top 20 creators by published public items; returns user_id only (no profile join in SQL); fixed `LANGUAGE sql` for same reason
   - `get_platform_heatmap(p_days INT)` — platform-wide daily review counts via `generate_series` date spine; call with `p_days = 365`
3. **`PlatformHeatmap.jsx`** (`src/components/progress/`): 52-week heatmap, blue color scale (platform-wide counts), separate from student `StudyHeatmap.jsx`
4. **`SuperAdminAnalytics.jsx`** (`src/pages/admin/`): 5 sections — header strip, cohort comparison table (client-side sortable, amber rows for zero-review courses), creator leaderboard (Student Contributor vs Professor badge), platform heatmap, admin activity feed (bounded 20-row query + JS-side attribution)
5. **Routing + nav:** Route `/super-admin/analytics` added to `App.jsx`; SA Analytics links added to `NavDesktop.jsx` and `NavMobile.jsx` (isSuperAdmin only)

**Files:**
- `src/pages/admin/SuperAdminDashboard.jsx` (tabs fix)
- `src/pages/admin/SuperAdminAnalytics.jsx` (new)
- `src/components/progress/PlatformHeatmap.jsx` (new)
- `src/App.jsx`
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`

---

### Deck Auto-Naming Fix (Mar 15, 2026)
Fixed bulk-uploaded flashcard decks showing as untitled in AdminDashboard.

**Delivered:**
1. **Code fix (future uploads):** `BulkUploadFlashcards.jsx` — after inserting cards, loops over unique (subject_id, topic_id) groups found in the batch and runs `UPDATE flashcard_decks SET name = [derived] WHERE name IS NULL`. Name format: user's batch label if provided, otherwise `Subject — Topic` (or just `Subject` if no topic). Never overwrites an existing name.
2. **SQL migration (historical data):** One-time `UPDATE flashcard_decks` run in Supabase SQL Editor — backfills `name` from first card's `subjects.name` + `topics.name`, with `COALESCE` for `custom_subject`/`custom_topic` edge cases. Idempotent (safe to re-run).
3. **Admin Dashboard preview fix:** `togglePreview` was using `.eq('deck_id', deckId)` — `deck_id` column does not exist on `flashcards`. Corrected to match via `(user_id, subject_id, topic_id, custom_subject, custom_topic)` — the actual unique constraint. Added those columns to the deck select query.

**Files:** `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/pages/admin/AdminDashboard.jsx`

---

### Sprint 4 — Admin Analytics Page (Mar 15, 2026)
New dedicated analytics page for admins and super_admins at `/admin/analytics`.

**Delivered:**
1. **4 Supabase RPCs deployed:**
   - `get_admin_platform_overview` — 4 header stats (total users, active this week, pending reviews, published items)
   - `get_content_health_stats` — per-course: item counts, verified/unverified, pending note queue, avg quality
   - `get_user_onboarding_stats` — student funnel: new this week/month, never studied, review coverage, incomplete profiles
   - `get_weekly_platform_reviews` — 8-week rolling review count, Monday-anchored, generate_series date spine
2. **New page:** `src/pages/admin/AdminAnalytics.jsx`
   - Role-gated to admin + super_admin (professors have their own page)
   - 4-card stat strip with amber border highlight for actionable items
   - Content Health table (sortable, red/amber row highlights, pending notes badge)
   - Student Onboarding funnel (5 cards — new users, never studied, coverage %, incomplete profiles)
   - Weekly platform review BarChart (8-week, same Recharts pattern as Sprint 3)
3. **Nav:** Analytics link for `isAdmin || isSuperAdmin` in NavDesktop + "Admin" section in NavMobile

**Files:** `src/pages/admin/AdminAnalytics.jsx` *(new)*, `src/App.jsx`, `src/components/layout/NavDesktop.jsx`, `src/components/layout/NavMobile.jsx`

---

### Progress Page — Cross-Course Bleed Fix (Mar 15, 2026)
Students enrolled in one course were seeing subjects from other courses on the "All My Content" tab.

**Bug:** "All My Content" passed `courseLevel={null}` to `get_subject_mastery_v1` and `get_question_type_performance`, meaning "all public cards in the system." A CA Intermediate student could see Business Laws (CA Foundation) because 201 public CA Foundation cards exist.

**Fix:** Added `allTabCourseLevel` derived value in Progress.jsx. For users with exactly 1 enrolled course, "All My Content" now scopes to that course. Professors with multiple teaching courses still see combined view (`null`).

**No SQL changes** — frontend-only fix.

**Files:** `src/pages/dashboard/Study/Progress.jsx`

---

### Sprint 3 — Professor Analytics Page (Mar 14, 2026)
New dedicated analytics page for professors to understand how students engage with their content.

**Delivered:**
1. **5 Supabase RPCs deployed:**
   - `get_professor_overview` — 4 header stats (cards, students, reviews, avg quality)
   - `get_professor_subject_engagement` — per-subject breakdown, sortable
   - `get_professor_weak_cards` — bottom 10 cards by avg quality (min 3 reviews noise filter)
   - `get_professor_top_cards` — top 10 cards by review count
   - `get_professor_weekly_reach` — 8-week new-student trend (3-CTE optimized, no correlated subqueries)
2. **New page:** `src/pages/dashboard/ProfessorAnalytics.jsx`
   - Role-gated to **professor only** (admins/super_admins have their own dedicated dashboards)
   - Course selector pills (multi-course professors via CourseContext)
   - 4 stat cards · sortable subject table (amber highlight for avg quality < 3) · Weak + Top card panels with Copy ID · Recharts bar chart for weekly reach
   - Two-tier empty states: zero cards → prompt to Bulk Upload; cards but zero reviews → notice
3. **Nav updated:** Analytics link added to NavDesktop + NavMobile hamburger for **professor role only**
4. **Recharts installed** (lazy-loaded with page, no impact on main student bundle)

**Route:** `/dashboard/professor-analytics`

---

### Progress Page Bug Fixes + Multi-Course Selector (Mar 13, 2026)
Post-Sprint-2 fixes to the Progress page discovered during live demo.

**Bugs fixed:**
1. **Tab switching broken** — `tabs.jsx` was a stub (plain divs, no show/hide logic). Both `TabsContent` divs always rendered simultaneously; clicking tabs did nothing. Fixed by replacing Tabs abstraction with direct conditional rendering (`{tab === 'all' && ...}`).
2. **Content duplicated** — caused by same bug above; both "All My Content" and "Course" sections were always visible. Resolved with the conditional rendering fix.

**Feature added:**
3. **Multi-course selector on "By Course" tab** — Progress.jsx now reads `teachingCourses` from `CourseContext` (`profile_courses` table). When a user has 2+ courses (e.g. professor with CA Foundation + CA Intermediate + CA Final), pill buttons appear inside the "By Course" tab to switch between them. Subject Mastery table and Question Type Performance re-fetch automatically when course selection changes. Students with one course see no extra UI.

**Commits:** `eed55c0` (tab fix), `84e6110` (multi-course selector)

---

### Sprint 2 — Enhanced Student Progress Page (Mar 13, 2026)
Full rebuild of `src/pages/dashboard/Study/Progress.jsx` with 6 new features.

**Features delivered:**
1. **Time-window selector** — Last 7 Days / Last 30 Days / All Time pill toggle; drives Items Reviewed + Accuracy stat cards
2. **Content partition tabs** — "All My Content" vs "Course: [level]" (uses `profiles.course_level`); null course_level shows friendly empty state with Settings link
3. **Subject Mastery Table** — per-subject: total items, reviewed count, mastery %, due count; uses `get_subject_mastery_v1` RPC
4. **Question Type Performance strip** — accuracy % per question type bar chart; uses `get_question_type_performance` RPC
5. **Study Calendar Heatmap** — 90-day GitHub-style contribution grid; uses `get_study_heatmap` RPC (backed by `user_activity_log`)
6. **Due Items Forecast** — today / next 7 days / next 30 days counts; uses `get_due_forecast` RPC

**New DB RPCs deployed (all SECURITY DEFINER, granted to authenticated):**
- `get_due_forecast(p_user_id)` — 1-row forecast with 3 cumulative due counts
- `get_study_heatmap(p_user_id, p_days)` — date × count rows using `user_activity_log`
- `get_subject_mastery_v1(p_user_id, p_course_level)` — handles both FK subjects + custom_subject (COALESCE fix)
- `get_question_type_performance(p_user_id, p_course_level)` — accuracy % per question type

**New component files:**
- `src/components/progress/StudyHeatmap.jsx` — self-contained 90-day heatmap
- `src/components/progress/SubjectMasteryTable.jsx` — responsive table + mobile card list

**Architecture note:** All new analytics sections use server-side RPCs (no raw row downloads to client). Stat cards still use bounded client queries (existing behaviour, acceptable). `calculateStudyStreak` preserved as-is.

**Files:** `src/pages/dashboard/Study/Progress.jsx`, `src/components/progress/StudyHeatmap.jsx`, `src/components/progress/SubjectMasteryTable.jsx`

---

### Inactive Users Filter Count Fix (Mar 13, 2026)
Card showed 22, drill-down showed 50+. Root cause: client filter had no time restriction, showing all students with no activity regardless of signup date. DB function only counts students signed up >30 days ago with no reviews.

**Fix:** Added 30-day threshold to `filterUsers()` `inactive` branch; removed content check (DB only checks reviews, not notes/flashcards). Updated filter pill label to match.

**Files:** `src/pages/admin/SuperAdminDashboard.jsx`
**Commit:** `140da52`

---

### SuperAdmin Retention Card Drill-Down (Mar 13, 2026)
Replaced three `alert()` placeholder stubs on the "User Growth & Retention" cards in SuperAdmin Dashboard with real filtering logic.

**Three filter modes implemented:**
1. **New this week** (🆕) — students whose `created_at >= 7 days ago`
2. **Inactive** (💤) — students signed up >30 days ago with zero reviews (matches `get_user_retention_stats`)
3. **7-day retained** (✅) — new students who also have at least 1 review

**Implementation details:**
- New `fetchActivitySets()` loads `usersWithReviews` Set at page mount (from `reviews` table); also loads `usersWithContent` for potential future use
- `activeFilter` state (`null | 'new_this_week' | 'inactive' | 'retained'`) drives filter logic in `filterUsers()`
- Clicking a card sets the filter and scrolls/switches to the Users tab (`scrollToUserManagement()`)
- Filter pill rendered above user table with × to clear; changing the search box or role dropdown also clears the filter
- Also fixed a pre-existing `Dashboard.jsx` nested ternary syntax error (double `:` instead of `? :`) that blocked the Vite build

**Files:** `src/pages/admin/SuperAdminDashboard.jsx`, `src/pages/Dashboard.jsx`
**Commit:** `df805b4`

---

### Analytics Blueprint: Sprint 1 — Foundation (Mar 12, 2026)
Comprehensive analytics/reports overhaul across all four roles (Student, Professor, Admin, Super Admin). Sprint 1 covers nomenclature standardisation, frontend bug fixes, and DB schema/function scaffolding.

**Nomenclature changes (10 files):**
- "Cards" → "Items" and "Flashcard Decks" → "Study Sets" across all UI copy. DB column names, JS variable names, and RPC function names are unchanged.
- Files: `Dashboard.jsx`, `Progress.jsx`, `ReviewSession.jsx`, `GroupDetail.jsx`, `MyContributions.jsx`, `Home.jsx`, `FlashcardCreate.jsx`, `ActivityFeed.jsx`, `AdminDashboard.jsx`, `SuperAdminDashboard.jsx`

**Frontend bug fixes (3 bugs):**
1. **Progress.jsx — `totalMastered` was scoped to 7-day window** — now uses a separate lifetime query (`SELECT flashcard_id FROM reviews WHERE user_id = X AND status = 'active'`) with no date filter. Unique flashcard_id count is now a true lifetime total.
2. **AdminDashboard.jsx — Pending Review card was hardcoded to 0** — now queries `notes WHERE visibility='public' AND is_verified=false` with exact count; label uses singular/plural correctly.
3. **SuperAdminDashboard.jsx — RPC calls failed silently** — `get_content_creation_stats`, `get_study_engagement_stats`, `get_user_retention_stats` returned no data when DB functions weren't deployed; UI showed zeros with no explanation. Fixed with `reportErrors` state and descriptive Alert banners per section, telling the admin exactly which SQL script to run.

**6 SQL scripts written and ready to deploy in Supabase SQL Editor:**
1. `[SCHEMA] Extend flashcards for multi-format question types` — adds `question_type`, `options_json`, `correct_answer`, `explanation`, `difficulty_level`, `estimated_time_seconds`, `source`, `portal_metadata` columns + constraints + indexes
2. `[SCHEMA] Create vw_study_items safety view` — `WHERE question_type != 'concept_card'`; all review-based analytics must use this view, never raw `flashcards` table
3. `[FUNCTIONS] get_user_retention_stats` — 30/60/90-day cohort retention (SECURITY DEFINER)
4. `[FUNCTIONS] get_content_creation_stats` — creator activity trends (SECURITY DEFINER)
5. `[FUNCTIONS] get_study_engagement_stats` — peak hours, session length, engagement (SECURITY DEFINER)
6. `[FUNCTIONS] get_anonymous_class_stats (updated)` — partition fix: JOINs flashcards, filters to registered courses via `SELECT name FROM disciplines WHERE is_active = true` — no hardcoded course names

**Architecture decisions locked:**
- `vw_study_items` safety view is the mandatory layer for all analytics (no raw `flashcards` access)
- Registered Course / My Course partition is automatic: if `target_course` exists in `disciplines (is_active=true)` → Registered Course; else → My Course
- Concept Cards log views to `user_activity_log` with `activity_type = 'concept_card_read'` — no separate table
- Dynamic partitioning: always query `disciplines WHERE is_active = true` — never hardcode course names

**Commits:** `4f181e1` (bug fixes), `ba17f24` (nomenclature), `5e90edb` (CLAUDE.md bash fix)

---

### Security Fix: RLS enabled on all flagged tables + ghost deck prevention (Mar 12, 2026)
Resolved Supabase Security Advisor vulnerabilities and cleaned up ghost flashcard decks:

1. **RLS enabled on 4 tables** — `profiles`, `subjects`, `topics`, `content_creators` now have Row Level Security enabled. Supabase Security Advisor shows 0 errors.
2. **Recursive RLS policies fixed** — 25 policies across 13 tables all referenced `profiles` directly via subqueries. Enabling RLS on `profiles` cascaded failures everywhere (super admin "Access Denied", students saw "new user" state, professor contributions showed zeros). Fixed by creating two `SECURITY DEFINER` helper functions (`is_super_admin()`, `is_admin()`) that bypass RLS when checking roles, then dropped and recreated all 25 policies.
3. **INSERT policy added on profiles** — frontend `signUp` inserts a profile row after auth signup; without an INSERT policy new signups silently failed to create their profile.
4. **NULL `creator_id` backfill** — 335 flashcards uploaded before `creator_id` column existed had `NULL` values. Fixed with `UPDATE flashcards SET creator_id = user_id WHERE creator_id IS NULL`.
5. **Ghost empty deck prevention** — `update_deck_card_count` trigger updated to auto-delete `flashcard_decks` rows when `card_count` reaches 0 after a card deletion. Two remaining empty decks also cleaned up manually.

**DB changes only — no frontend files changed.**

---

### Bug Fix: Bulk upload silently created custom topics (Mar 11, 2026)
Two-part fix for professor bulk upload creating phantom deck entries via Excel drag-fill:
1. **DB data fix** — SQL UPDATE reset all `custom_topic` values in the 2014–2033 series back to `topic_id` for "The Companies Act, 2013"; then 20 wrong `flashcard_decks` rows were deleted and the correct deck's `card_count` was recalculated.
2. **Code fix in BulkUploadFlashcards** — added pre-insert validation loop that checks every row's subject and topic against the DB before allowing any insert. Unknown subject or topic → entire upload blocked with per-row error messages. `custom_subject` and `custom_topic` are now always `null` in bulk inserts.

**Files changed:**
- `src/pages/dashboard/BulkUploadFlashcards.jsx`

---

### Bug Fix: Blank study screen for student decks with no topic (Mar 6, 2026)
Three-part fix for a systemic bug affecting all students who created flashcards without selecting a topic:
1. **Topic mandatory in FlashcardCreate** — validation added, label updated to "Topic *"
2. **Deck-ID navigation** — `ReviewFlashcards` passes `?deck=<uuid>` for individual deck clicks; `StudyMode` filters by `card.deck_id` when present (immune to null/fallback topic names)
3. **Null-topic nudge in MyFlashcards** — amber banner with "Fix Now →" for existing null-topic groups; Edit Info dialog now updates `flashcard_decks` record + topic made required

**Files changed:**
- `src/pages/dashboard/Content/FlashcardCreate.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Study/StudyMode.jsx`
- `src/pages/dashboard/Content/MyFlashcards.jsx`

---

### UX: Browse Notes — back navigation fix for "View all" (Mar 6, 2026)
Fixed two issues with browser back navigation after clicking "View all X notes →":
1. URL sync `useEffect` now unconditionally sets both filters (removes `if` guards), so navigating back to the clean URL correctly resets `filterSubject` and `filterTopic` to `'all'`.
2. Added "← Back to all notes" button above the page title, visible only when `?topic=` URL param is present. Clicking it navigates to `/dashboard/notes` (clean URL), triggering the filter reset.

**Files changed:**
- `src/pages/dashboard/Content/BrowseNotes.jsx`

---

### UX: Browse Notes pagination refactor — subject-first with View All (Mar 6, 2026)
Replaced confusing note-count "Load More" with subject-accordion-first layout. All subjects collapse by default so users see the full subject list at a glance. Topics >6 notes show 6 inline + "View all X notes →" navigating to `?subject=X&topic=Y`. BrowseNotes now reads `topic` from URL params and syncs filter state on URL change (for within-page "View all" navigation).

**Files changed:**
- `src/pages/dashboard/Content/BrowseNotes.jsx`

---

### Bug Fix: RPC ambiguous column "id" in course-aware browsing (Mar 6, 2026)
Both `get_browsable_decks` v3 and `get_browsable_notes` v3 threw PostgreSQL error 42702 ("column reference 'id' is ambiguous") because both are declared as `RETURNS TABLE(id UUID, ...)` — making `id` both an output column (PL/pgSQL variable) and the column referenced in `WHERE id = v_user_id`. Fixed by qualifying as `WHERE profiles.id = v_user_id` in both functions.

**Files changed:**
- `docs/database/study-groups/29_FUNCTION_get_browsable_decks_v3.sql` — `WHERE profiles.id = v_user_id`
- `docs/database/study-groups/30_FUNCTION_get_browsable_notes_v3.sql` — same fix

---

### Feature: Course-aware browsing for students (Mar 6, 2026)
Students were seeing content from all courses on the Review Flashcards and Browse Notes pages. The RPCs had no course gate — they only enforced visibility (public/friends/groups/own). Added a course gate to both RPCs and locked the Course filter dropdown for students.

**SQL (run in Supabase SQL Editor in order):**
- `28_SCHEMA_composite_course_user_indexes.sql` — composite indexes on `(target_course, user_id)` for both tables
- `29_FUNCTION_get_browsable_decks_v3.sql` — updated RPC with course gate
- `30_FUNCTION_get_browsable_notes_v3.sql` — updated RPC with course gate

**Logic:**
- Professors/admins/super_admins: bypass course gate, see all courses
- Students: see content where `target_course = their course_level` OR they are the author
- Course dropdown: locked (disabled) for students with label "(Current Syllabus)", free for professors
- Empty states distinguish "no content for your course yet" vs "no results match your filters"
- `clearAllFilters` does not reset the course for students

**Files changed:**
- [x] `docs/database/study-groups/28_SCHEMA_composite_course_user_indexes.sql` — NEW
- [x] `docs/database/study-groups/29_FUNCTION_get_browsable_decks_v3.sql` — NEW
- [x] `docs/database/study-groups/30_FUNCTION_get_browsable_notes_v3.sql` — NEW
- [x] `src/pages/dashboard/Study/ReviewFlashcards.jsx` — profile fetch, locked dropdown, empty states
- [x] `src/pages/dashboard/Content/BrowseNotes.jsx` — same

### Fix: "My Cards" pinned option in Author dropdown (Mar 5, 2026)
Students with only private flashcard decks were invisible in the Author filter (the RPC `get_filtered_authors_for_flashcards` only returns authors with public decks). Added a hardcoded "My Cards (Private & Public)" option pinned at the top of the Author dropdown using `user.id` as the value. No DB changes required — compatible with existing StudyMode `authorParam` filter and SRS two-step query (student's own private cards are already fetched via the visibility `user_id.eq.${user.id}` OR clause).
- [x] **`ReviewFlashcards.jsx`** — Added pinned `<SelectItem value={user.id}>My Cards (Private & Public)</SelectItem>` after "All Authors", before dynamic RPC-sourced authors list.
- [x] **`StudyMode.jsx`** — No changes needed; `authorParam` filter already handles any UUID including the current user's ID.
- [x] **Empty state** — Already handled: StudyMode shows "No flashcards to study" with "Choose Different Subject" button when card list is empty after all filters applied.
- [x] **`docs/tracking/changelog.md`** — Entry added.
- [x] **`docs/tracking/bugs.md`** — Bug entry added.

### Fix: Author mixing + SRS-aware session in StudyMode (Mar 5, 2026)
Student reported: studying a professor's deck also showed the student's own cards mixed in; no way to pause mid-session and resume sensibly.
- [x] **`ReviewFlashcards.jsx`** — `startStudySession()` now passes `author` URL param when a specific author is selected in the filter. "Study All" and per-deck study both respect the active author filter.
- [x] **`StudyMode.jsx`** — Reads `authorParam` from URL and filters cards client-side (`card.user_id === authorParam`), scoped on top of the existing visibility fetch.
- [x] **`StudyMode.jsx`** — Added SRS-aware two-step query (LEFT JOIN equivalent): after fetching matching cards, fetches `reviews` records for this user and excludes cards where `status = 'suspended'`, `next_review_date > today`, or `skip_until > today`. First-time cards (no review record) pass through — no cold-start problem.
- [x] **`docs/tracking/changelog.md`** — Entry added.
- [x] **`docs/tracking/bugs.md`** — Bug entries added.

### Fix: Course→Subject cascade filter in Study section (Mar 4, 2026)
Both Review Flashcards and Browse Notes pages showed all subjects in the Subject dropdown regardless of Course selection. Selecting "CA Foundation" showed subjects from all courses.
- [x] **`ReviewFlashcards.jsx`** — Added `allSubjectsFromDecks` state (array of `{name, course}`) populated at fetch time. New `useEffect` filters `availableSubjects` when `filterCourse` changes; auto-resets `filterSubject` if selection no longer valid (which cascades to reset topics via existing effect).
- [x] **`BrowseNotes.jsx`** — Same fix with `allSubjectsFromNotes`.
- [x] **`docs/tracking/changelog.md`** — Entry added.
- [x] **`docs/tracking/bugs.md`** — Bug entry added.

### DB Trigger Fix: flashcard_decks auto-creation on bulk upload (Mar 2, 2026)
Root cause: `update_deck_card_count()` trigger only ran `UPDATE card_count` on existing deck rows. When flashcards were bulk-uploaded (or uploaded via any path that didn't pre-create a deck row), no deck row existed yet — the UPDATE matched 0 rows, silently did nothing, and no `flashcard_decks` entry was ever created. Result: flashcards were invisible in Study Page (Course filter, deck list) and Author Profile.
- [x] **DB** — Replaced `UPDATE` in trigger with UPDATE-then-INSERT pattern: tries to increment existing deck; if `NOT FOUND`, inserts a new deck row with `card_count = 1`, `target_course`, and `visibility` copied from the flashcard. Permanent fix — covers all insertion paths for all future courses automatically.
- [x] **DB (data fix)** — Backfilled missing `flashcard_decks` rows for CA Foundation flashcards already in `flashcards` table. Card counts set from actual row counts, visibility set to most permissive found among cards in each subject/topic group.
- [x] **`docs/tracking/changelog.md`** — Entry added with root cause.
- [x] **`docs/tracking/bugs.md`** — Bug entry added.
- [x] **`docs/reference/DATABASE_SCHEMA.md`** — `update_deck_card_count` function doc updated.

### Performance: App Load Time Fix (Feb 24, 2026)
Root cause: entire JS bundle (all 55 pages) downloaded on first load, plus two sequential Supabase auth calls blocking render.
- [x] **`App.jsx`** — Converted all page imports to `React.lazy()`. Pages now download on-demand (only the current route).
- [x] **`App.jsx`** — Extracted `AppContent` component that reads auth from `useAuth()`. Eliminated the duplicate `supabase.auth.getSession()` call that was running in parallel with AuthContext's own call.
- [x] **`App.jsx`** — Wrapped `<Routes>` in `<Suspense>` with spinner fallback.
- [x] **`AuthContext.jsx`** — Removed `{!loading && children}` blocking gate (AppContent now owns the loading spinner). Removed 30+ debug `console.log` statements from `signIn`.
- [x] **`vite.config.js`** — Added `manualChunks` to split vendor-react, vendor-supabase, vendor-radix into separate cacheable chunks.
- [x] **`index.html`** — Added `<link rel="preconnect">` for Supabase URL to reduce auth latency.
- [x] **`src/hooks/useOCR.js`** — Deleted dead code (never imported anywhere, was pulling in tesseract.js).



### Egress Optimisation: Flashcard Image Storage Fix + Migration (Feb 22–23, 2026)
Root cause: 167 flashcard images (110 MB) stored as raw base64 TEXT in DB columns — every study session downloaded the full blobs from the database.
- [x] **`FlashcardCreate.jsx`** — Replaced `FileReader.readAsDataURL` (base64 → DB) with async compress + Storage upload pipeline. `imageCompression` (same settings as NoteUpload: `maxSizeMB: 0.2, maxWidthOrHeight: 1200`) → upload to `flashcard-images` Storage bucket → store public URL in DB. EXIF-safe via `browser-image-compression`.
- [x] **`FlashcardCreate.jsx`** — Card state shape changed: `frontImage/backImage` (base64) → `frontImageUrl/frontImagePreview/backImageUrl/backImagePreview` (URL + ObjectURL).
- [x] **`FlashcardCreate.jsx`** — Per-card upload spinner (`uploadingImage` state tracks `{ index, side }`). Label shows "Change Image" after upload. ×-button on preview to remove image. ObjectURLs revoked on card removal (memory leak prevention).
- [x] **Migration completed 23 Feb 2026 06:55 AM** — 167 images migrated, 0 failed. All base64 blobs removed from DB and uploaded to `flashcard-images` Storage bucket under `migrated/` prefix.
- [x] **`MigrateFlashcards.jsx` deleted** — temporary admin page removed after successful migration. Route removed from `App.jsx`.
- [x] **Build verified clean** — 1975 modules, 5.64s, no errors.

### Egress Optimisation: Lazy Loading + Load More + Image Compression (Feb 22, 2026)
Root cause: 14+ GB Supabase egress from 26 users — all note images loading at full resolution simultaneously.
- [x] **`BrowseNotes.jsx`** — Added `loading="lazy"` + `decoding="async"` to all note `<img>` tags. Off-screen images no longer fetched on page load (~90% egress reduction).
- [x] **`BrowseNotes.jsx`** — Added `bg-gray-100` to image button wrapper as CLS placeholder (grey box visible while images load — prevents layout shift).
- [x] **`BrowseNotes.jsx`** — Added `NOTES_PER_PAGE = 10` constant + `visibleCount` state. Render computes `flatFiltered` → slices → regroups via existing `groupNotesBySubject()`. Only 10 notes rendered in DOM on load.
- [x] **`BrowseNotes.jsx`** — "Load More" button appends next 10 notes. `visibleCount` resets to 10 on any filter change. Groups remain intact (new notes tuck into existing headers — no fragmented group split across pages).
- [x] **`NoteUpload.jsx`** — Imported `browser-image-compression` (already installed v2.0.2). Made `handleFileChange` async.
- [x] **`NoteUpload.jsx`** — Images compressed client-side before upload: `maxSizeMB: 0.5`, `maxWidthOrHeight: 1920`, `useWebWorker: true`. Handles EXIF rotation automatically (iPhone portrait photos stay upright). Fallback to original file if compression throws. (Limits raised from 0.2/1200 to preserve readability of text-heavy mindmaps and diagrams.)
- [x] **`NoteUpload.jsx`** — `compressing` state: label gains `cursor-wait opacity-75` + `htmlFor` unlinked during compression (prevents double file picker open). Spinner shown in upload area with "Compressing image…" text.
- [x] **`NoteUpload.jsx`** — Updated upload hint text: "JPG, PNG (auto-compressed to ~500KB) or PDF (max 10MB)".
- [x] **Build verified clean** — 1974 modules, 5.42s, no errors.

### Push Notifications — Review Reminders Cron (Feb 23 + Mar 5, 2026)
- [x] **`supabase/functions/cron-review-reminders/index.ts`** (NEW) — Scheduled Edge Function that fires daily at 08:00 IST (02:30 UTC) via pg_cron. Queries `reviews` table for cards with `status = 'active'`, `next_review_date <= today`, and `skip_until IS NULL OR <= today` — exactly matching Dashboard.jsx due-card logic. Aggregates count per user, checks `push_notification_preferences.review_reminders`, sends one push per user. Fixed tag `review-reminder` (browser replaces instead of stacking). Auth via `x-cron-secret` header.
- [x] **Deployed** to project `ztxguiujzirburxpjujf` via `npx supabase functions deploy cron-review-reminders`.
- [x] **`CRON_SECRET`** set in Supabase secrets (32-byte random hex).
- [x] **pg_cron job registered** — `daily-review-reminders` at `30 2 * * *` (active = true, confirmed via SQL).
- [x] **Fix: JWT verification disabled** (Mar 5) — Supabase "Verify JWT with legacy secret" was ON by default, blocking pg_cron calls with HTTP 401 before function code ran. Turned OFF in Edge Function Details tab. Auth is handled by `x-cron-secret` header inside the function. Manually tested and confirmed delivery after fix.

### Push Notifications — P1 PWA Foundation + P4 Frontend Wiring (Feb 22, 2026)
- [x] **`public/site.webmanifest`** — Fixed `name`, `short_name`, `theme_color` (#4f46e5), `start_url: /dashboard`, `purpose: maskable` on 512px icon.
- [x] **`public/sw.js`** — Service worker: handles `push` event (shows notification, respects `renotify`/`silent` flags), `notificationclick` (focuses existing tab or opens `/dashboard`), `install`/`activate` with `skipWaiting` + `clients.claim`.
- [x] **`src/main.jsx`** — Registers `/sw.js` on `window load` event (non-blocking, doesn't delay first render).
- [x] **`src/lib/notifyEdge.js`** — Fire-and-forget helpers `notifyContentCreated()` and `notifyFriendEvent()` that call the deployed Edge Functions. Never block the primary user action.
- [x] **`src/hooks/usePushNotifications.js`** — Hook: detects browser support, iOS + standalone status, current permission, existing subscription. Exports `subscribe()` (requests permission → subscribes → POSTs to push-subscribe), `unsubscribe()`, `needsIOSInstall`.
- [x] **`src/components/notifications/PushPermissionBanner.jsx`** — One-time dismissible banner on Dashboard. Android/desktop: "Enable" button. iOS + not installed: "Add to Home Screen" guide. Permission denied: hidden. Dismissed permanently via `localStorage`.
- [x] **`src/pages/Dashboard.jsx`** — Added `<PushPermissionBanner />` just above the main content grid.
- [x] **`src/pages/dashboard/Profile/ProfileSettings.jsx`** — Added "Push Notifications" card at bottom. Shows: enable button (default) / enabled + disable button (subscribed) / install prompt (iOS) / browser settings message (denied) / unsupported message.
- [x] **`src/pages/dashboard/Content/NoteUpload.jsx`** — Calls `notifyContentCreated()` after successful note insert (only for `public`/`friends` visibility). Fire-and-forget.
- [x] **`src/pages/dashboard/Content/FlashcardCreate.jsx`** — Calls `notifyContentCreated()` after successful flashcard create (only for `public`/`friends` visibility). Fire-and-forget.
- [x] **`src/pages/dashboard/Friends/FindFriends.jsx`** — Calls `notifyFriendEvent('friend_request')` after successful send.
- [x] **`src/pages/dashboard/Profile/AuthorProfile.jsx`** — Same as FindFriends for the Add Friend button.
- [x] **`src/pages/dashboard/Friends/FriendRequests.jsx`** — Calls `notifyFriendEvent('friend_accepted')` after accept, notifying the original sender.
- [x] **`src/components/layout/FriendsDropdown.jsx`** — Same accept notification from the nav dropdown quick-accept.
- [x] **Build verified clean** — 1973 modules, 5.68s, no errors.

### Push Notifications — Phase 3: Edge Functions (Feb 22, 2026)
- [x] **`supabase/functions/_shared/supabaseAdmin.ts`** — Shared service-role Supabase client for all Edge Functions. Bypasses RLS; never sent to browser.
- [x] **`supabase/functions/_shared/sendPush.ts`** — VAPID-configured web-push utility. `sendPushToUsers(userIds[], payload)` fetches all active subscriptions, sends concurrently, auto-deactivates expired (HTTP 410/404) subscriptions in one batch UPDATE.
- [x] **`supabase/functions/push-subscribe/index.ts`** — Saves device subscription (`endpoint, p256dh, auth`) via upsert on `(user_id, endpoint)` conflict key. Creates default `push_notification_preferences` row (all opted-in) if missing.
- [x] **`supabase/functions/push-unsubscribe/index.ts`** — Soft-deletes subscription (`is_active = false`) when user revokes permission. Preserves row for debugging.
- [x] **`supabase/functions/notify-friend-event/index.ts`** — Instant (non-aggregated) notification for `friend_request` and `friend_accepted` events. Checks push prefs, INSERTs notification row, sends push with `renotify: true`. Tag = `friend-{actor_id}`.
- [x] **`supabase/functions/notify-content-created/index.ts`** — Main update-in-place aggregator. 4-hour grouping window per `(creator_id, content_type)` pair. Professor public uploads → `professor_content` type → notifies all students with matching `course_level`. Student/friend uploads → `friend_content` type → notifies accepted friends only. Bulk-INSERTs new notifications; individually UPDATEs existing ones (count in metadata). New notifications → `renotify: true`; updates → `renotify: false` (silent badge bump). Same push `tag` per creator+type causes browser to replace (not stack) notifications.
- [x] **Deployed all 4 Edge Functions** to project `ztxguiujzirburxpjujf` via `npx supabase functions deploy`.
- [x] **React build verified clean** after all changes (4.86s, no errors).

### Previously — Push Notifications Setup (Feb 22, 2026 — earlier)
- [x] **`notifications` schema** — Added `actor_id UUID`, `updated_at TIMESTAMPTZ`, trigger `trg_notifications_updated_at`, CHECK constraint updated with 4 new types (`professor_content`, `friend_content`, `group_content`, `system_announcement`), two new indexes (`idx_notifications_grouping` partial, `idx_notifications_updated_at`).
- [x] **`get_recent_notifications` RPC** — Rebuilt (DROP + CREATE): returns `actor_id` + `updated_at`, sorts by `updated_at DESC` so aggregated notifications bubble to top.
- [x] **`get_recent_activity_feed` RPC** — Added SQL grouping by `(creator_id, creator_name, creator_role, content_type, DATE(created_at))`. Added `count INTEGER` and `subject TEXT` columns. Fixed missing subjects JOIN (subject was always blank). Verified: 59 professor uploads correctly grouped into 2 rows (37 + 22).
- [x] **`useNotifications.js`** — Added UPDATE Realtime subscription alongside existing INSERT subscription. On UPDATE calls `fetchNotifications()` to re-sort by `updated_at DESC`. Does not increment `unreadCount` (row was already unread).
- [x] **`ActivityFeed.jsx`** — Grouped rendering (`count > 1` → "30 notes added", `"View 30"` button). Fixed long-standing bug: was checking `content_type === 'deck'` but RPC returns `'flashcard_deck'`. Subject hidden for grouped rows. Author-filtered navigation for grouped clicks.
- [x] **`push_subscriptions` table** — Created with RLS, UNIQUE(user_id, endpoint), partial index on `is_active = true`.
- [x] **`push_notification_preferences` table** — Created with RLS, one row per user, all boolean prefs default `true`.
- [x] **Supabase CLI** — Installed via `npm install supabase --save-dev`, linked to project, initialized. VAPID keys generated via `npx web-push generate-vapid-keys`. Secrets set: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT=mailto:recall@moreclassescommerce.com`.
- [x] **`.env.local`** — `VITE_VAPID_PUBLIC_KEY` added.

### Phase A: Professor Multi-Course — Teaching Areas + Course Context Switcher (Feb 21, 2026)
- [x] **`profile_courses` table** — Junction table linking users to multiple disciplines. `is_primary` flag, `UNIQUE(user_id, discipline_id)`, full RLS, two indexes. Additive to `profiles.course_level` (backward compat preserved).
- [x] **Backfill** — One-time migration seeds `profile_courses` from existing `profiles.course_level` for all professors/admins/super_admins.
- [x] **`CourseContext.jsx`** (NEW) — React context that fetches `profile_courses`, manages `activeCourse` session state, exposes `addCourse`, `removeCourse`, `setPrimaryCourse`. `setPrimaryCourse` syncs `profiles.course_level` atomically for backward compat.
- [x] **`CourseSwitcher.jsx`** (NEW) — Compact indigo pill dropdown in the nav bar (desktop: right section; mobile: Course Context section in hamburger sheet). Session-only, no DB write. Renders only when `isContentCreator && teachingCourses.length >= 2`.
- [x] **`App.jsx`** — Wrapped with `<CourseContextProvider>` inside `<AuthProvider>`.
- [x] **`NavDesktop.jsx`** — CourseSwitcher added to right icon section.
- [x] **`NavMobile.jsx`** — Course Context section added to sheet (tappable rows, flat list, no nested dropdowns).
- [x] **`ProfileSettings.jsx`** — "My Teaching Areas" card added (visible to professor/admin/super_admin). Add course from disciplines dropdown, set primary (star button), remove (X button, disabled for primary). Disciplines fetched from DB — always up to date.
- [x] **`AuthorProfile.jsx`** — Profile header now shows all teaching courses as indigo chips (from updated RPC). Falls back to single `course_level` for students.
- [x] **`Dashboard.jsx`** — Class stats use `activeCourse` from context. Reactive `useEffect` re-fetches class stats when professor switches course (initial mount skipped via `useRef`).
- [x] **Updated `get_author_profile()` RPC** — Added `teaching_courses` JSON array (primary first). All existing keys unchanged. SQL provided in chat.

### SQL Execution Order (run in Supabase SQL Editor — SQL provided in chat)
1. Diagnostic: verify CA Foundation/Inter/Final are `is_active = TRUE`
2. Create `profile_courses` table + RLS + indexes
3. Backfill from `profiles.course_level` for professors/admins/super_admins
4. `CREATE OR REPLACE FUNCTION get_author_profile(...)` — adds `teaching_courses` key

### UX: Consistent Notes → Flashcards Ordering Across Dashboard (Feb 21, 2026)
- [x] **Issue:** Quick Actions section had Notes → Flashcards for browse items, but then Flashcards → Notes for create items (Create Flashcard before Upload Note), inconsistent with all other sections
- [x] **Fix:** Swapped "Create Flashcard" and "Upload Note" cards in Quick Actions so the order is now: Browse Notes → Browse Flashcards → **Upload Note → Create Flashcard**
- [x] All sections now follow Notes-first order for consistency: Create Menu (nav), Quick Actions, My Contributions
- [x] Study Menu intentionally keeps Flashcards-first — see Active Decisions for rationale
- [x] No database changes — frontend-only fix in `Dashboard.jsx`

### Fix: Private Badges Showing on Author Profile Page (Feb 21, 2026)
- [x] **Bug:** Badges marked private in My Achievements were still visible on the Author Profile page (own + others' profiles)
- [x] **Root Cause:** `AuthorProfile.jsx` rendered `badges.map(...)` over all badges returned by `get_author_profile` RPC. For own profile the RPC returns ALL badges (including private); the old code only added a 🔒 icon but never hid the badge.
- [x] **Fix:** Computed `publicBadges = badges.filter(b => b.is_public !== false)` and replaced `badges.map` with `publicBadges.map`. Removed the now-redundant EyeOff indicator inside badge pills.
- [x] No database changes — frontend-only fix in `AuthorProfile.jsx`
- [x] Privacy now consistent across the full app: My Achievements = manage privacy; Author Page = public-only view

### Phase 1F - Extended Badge System with Performance Optimizations (Feb 21, 2026)
- [x] **Scalability fix:** Created `user_stats` table with integer counters — badge checks now O(1) instead of O(n) COUNT(*). Prevents bulk upload crash.
- [x] **Counter triggers:** 5 new triggers (`trg_aaa_counter_*`) on notes/flashcards/reviews/upvotes/friendships — alphabetically before badge triggers.
- [x] **13 new badges:** prolific_writer, deck_builder, subject_expert, first_steps, committed_learner, monthly_master, early_bird, century_club, review_veteran, social_learner, community_pillar, helpful_peer, pioneer.
- [x] **Timezone support:** Night Owl + Early Bird use `profiles.timezone` (already existed). No IST hardcoding.
- [x] **Race condition fix:** `award_badge` uses `INSERT ... ON CONFLICT DO NOTHING` — safe for concurrent calls.
- [x] **Default privacy:** night_owl and early_bird are private by default in updated `award_badge`.
- [x] **Pioneer badge:** Awarded via profile INSERT trigger for new users + backfill for all existing users.
- [x] **Friendship trigger:** `trg_badge_friendship` on friendships UPDATE for social badges.
- [x] **Frontend — BadgeIcon.jsx:** Added 13 new icon mappings (FileText, Layers, GraduationCap, Footprints, CalendarCheck, CalendarRange, Sunrise, Award, Medal, Users, HeartHandshake, ThumbsUp, Flag).
- [x] **Frontend — MyAchievements.jsx:** Added `special` category, replaced 5 separate COUNT queries with single `user_stats` read + streak call.
- [x] SQL scripts in `docs/sql/phase1f/` (6 files, run in order 01→06).

### SQL Execution Order
1. `01_schema.sql` — Create user_stats table + RLS + initialize rows
2. `05_award_badge.sql` — Update award_badge (badge triggers depend on it)
3. `02_counter_triggers.sql` — Counter trigger functions + triggers
4. `03_badge_definitions.sql` — Insert 13 new badge definitions
5. `04_badge_triggers.sql` — Updated badge trigger functions + triggers
6. `06_backfill.sql` — Populate user_stats + award retroactive badges

### Fix: Content Type Selector Missing on Upload Note (Feb 20, 2026)
- [x] **Bug:** Content Type buttons (Text, Table, Math, Diagram, Mixed) were only shown in Edit Note, not in Upload Note
- [x] **Fix:** Added Content Type selector to the "Note Details" card in `NoteUpload.jsx`, after the Description field
- [x] `contentType` state already existed and was already saved to DB — only the UI was missing
- [x] No database changes — frontend-only fix

### Landing Page Stats — Total Counts + Visibility Fix (Feb 20, 2026)
- [x] **Hero 4-stat grid:** Now shows true platform-wide totals (1383 flashcards, 38 notes) via `get_platform_stats()` SECURITY DEFINER RPC — bypasses RLS so unauthenticated visitors see real counts, not just public content
- [x] **Educator section:** Keeps public-only counts (458 flashcards, 34 notes) so new users see what they can actually browse. Relabeled "Flashcards to Browse" and "Notes to Browse"
- [x] **Hero social proof line:** Updated from "X+ items shared" → "X+ items created"
- [x] **Bug fix:** Public queries were using legacy `is_public = true` column — changed to `visibility = 'public'`
- [x] **MUST RUN SQL:** `get_platform_stats()` function in Supabase SQL Editor (see changelog for full SQL)

### Fix: Activity Feed "View" Button UUID Error (Feb 20, 2026)
- [x] **Bug:** Clicking "View" on a note in the Recent Activity section caused "Page Not Found" with error "Invalid input syntax for type uuid: 'undefined'"
- [x] **Root Cause:** `ActivityFeed.jsx` referenced `activity.content_id` but the `get_recent_activity_feed` RPC returns the UUID as `id` (consistent with all other RPCs). `activity.content_id` was always `undefined`, producing the URL `/dashboard/notes/undefined`.
- [x] **Fix:** Changed `activity.content_id` → `activity.id` in both the `handleActivityClick` navigate call and the React `key` prop
- [x] No database changes — frontend-only fix in `ActivityFeed.jsx`

### Fix: card_count Double-Counting — Full Resolution (Feb 24, 2026)
- [x] **True Root Cause (confirmed via trigger audit):** `trigger_update_deck_card_count` was already in the DB and correctly maintaining `card_count`. The frontend was ALSO manually incrementing it — so every card creation fired twice: once from the trigger, once from the app code. That was the original 2x bug.
- [x] **Feb 12 mis-fix:** Removed frontend increment (correct) but added a second DB trigger `flashcards_count_trigger` (redundant) — simply replaced app+trigger with trigger+trigger. Still 2x.
- [x] **Feb 24 final fix:** Dropped `flashcards_count_trigger`. Only `trigger_update_deck_card_count` remains — the original trigger that was always correct. Data recalculated via SQL.
- [x] **Frontend state:** `FlashcardCreate.jsx` has no manual `card_count` logic (correct — stays as-is). New decks insert with `card_count: 0`; trigger maintains it automatically.
- [x] **Lesson:** Always audit existing triggers before adding new ones (`SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'flashcards'`).

### Fix: Flashcard Deck Names in Share Content Dialog (Feb 9, 2026)
- [x] **Fixed:** Share Content dialog showed "Flashcard Deck" for all decks instead of actual subject/topic names
- [x] Root cause: `subject_id` and `topic_id` were not included in the Supabase select query, so name lookups always failed
- [x] Added `subject_id, topic_id` to flashcard_decks query in `fetchUserContent()`
- [x] Added topic name lookup (fetches from `topics` table, same pattern as subjects)
- [x] Added `display_topic` field using `custom_topic || topicsMap[topic_id]`
- [x] Decks now show as "Subject - Topic" (e.g., "Auditing & Ethics - Audit of Items of Financial Statements")
- [x] No database changes — frontend-only fix

### Dependent Subject Dropdowns + Skipped Duplicates Report (Feb 9, 2026)
- [x] **FlashcardCreate + NoteUpload:** Subject dropdown now filters by selected course (`discipline_id`)
- [x] Disciplines loaded on mount; course name matched to discipline for subject filtering
- [x] Subject & topic selections reset when course changes (prevents stale cross-course selections)
- [x] Custom courses (no discipline match) show all subjects as fallback
- [x] **Fixed:** `description` column removed from topics insert/select — column doesn't exist in DB
- [x] **Fixed:** `sort_order` → `order_num` for all subjects/topics DB queries (same as disciplines)
- [x] **BulkUploadTopics:** Skipped duplicates now listed by name (`Subject → Topic`) in success report
- [x] DATABASE_SCHEMA.md updated for all 3 structure tables (disciplines, subjects, topics) with verified live DB columns
- [x] Build verified clean

### Bulk Upload QA Refinements + Disciplines Fix (Feb 9, 2026)
- [x] Removed forced download gate — all stepper steps freely clickable (returning users skip to Step 2)
- [x] Added first-timer nudge (amber Info box in Step 2 when Step 1 not done) on both pages
- [x] Step 3 shows contextual amber nudge when prerequisites missing (links back to relevant step)
- [x] **Fixed:** disciplines queries now use correct column names (`is_active`, `order_num` — NOT `sort_order`)
- [x] **Fixed:** Create New Course insert now includes required `code` column (auto-generated from name)
- [x] BulkUploadTopics: Added `[+ New Course]` inline form next to course dropdown
- [x] Course creation: Title Case enforcement + case-insensitive duplicate check + DB unique constraint catch
- [x] BulkUploadTopics: Added `subject_sort_order` and `sort_order` (topic) optional CSV columns
- [x] Sort logic: 0 = alphabetical fallback, explicit integers sorted first (sort_order ASC, name ASC)
- [x] Existing subjects with sort_order=0 get updated if CSV provides a non-zero value
- [x] Template changed to generic examples (language learning) instead of CA-specific
- [x] Current Entries download now includes sort_order columns and respects sort_order in output
- [x] CSV parser handles both `sort_order` and `topic_sort_order` header names
- [x] No database schema changes — uses existing sort_order columns on subjects/topics tables
- [x] **Note:** `disciplines` table uses `order_num` (not `sort_order`), has required `code` column. Schema verified against live DB.
- [x] Build verified clean

### Streamlined Bulk Upload Pages (Feb 9, 2026)
- [x] Created `BulkUploadFlashcards.jsx` — new stepper-based UI replacing old ProfessorTools 4-card layout
- [x] 3-step collapsible stepper: Download Files → Prepare & Select CSV → Upload
- [x] "Required columns" hint in Step 2 so users don't need to open template to check headers
- [x] Success state replaces stepper with "Upload More" / "View My Flashcards" buttons
- [x] Created `BulkUploadTopics.jsx` — admin-only page for bulk-adding subjects & topics to a course
- [x] Case-insensitive matching: "taxation" maps to existing "Taxation" (no duplicates)
- [x] Title Case enforcement: "income tax" → "Income Tax" for new entries
- [x] Duplicate detection: existing subject+topic combos are skipped automatically
- [x] Same stepper design pattern as flashcard bulk upload (consistent UX)
- [x] Route: `/dashboard/bulk-upload` (flashcards, all users), `/admin/bulk-upload-topics` (admin only)
- [x] `/professor/tools` now redirects to `/dashboard/bulk-upload`
- [x] Nav links updated: Bulk Upload visible to all users (was professor/admin only), "Manage Topics" link for admin/super_admin
- [x] FlashcardCreate.jsx "Try Bulk Upload" link updated to new route
- [x] All CSV parsing/upload logic preserved from original ProfessorTools
- [x] No database schema changes
- [x] Build verified clean

### Profile Completion Modal & Course Label Update (Feb 9, 2026)
- [x] Non-dismissible modal on Dashboard when `course_level` or `institution` is NULL
- [x] Uses same SearchableSelect institution list and course dropdown as ProfileSettings
- [x] Blocks interaction: no close button, no escape, no click-outside dismiss
- [x] Added `hideCloseButton` prop to `DialogContent` component (reusable for other non-dismissible dialogs)
- [x] ProfileSettings course label changed to "Primary Course" (future multi-course prep)
- [x] Dashboard re-fetches after modal save for updated class stats
- [x] No database changes — reads existing `course_level` and `institution` columns
- [x] Build verified clean

### FindFriends Privacy Fix & Profile Settings Page (Feb 8, 2026)
- [x] Masked emails in FindFriends (`an***@gmail.com`) — cosmetic client-side masking, code comment added
- [x] Added institution + "Joined {year}" display on FindFriends cards for user disambiguation
- [x] Removed email from search filter (name-only search prevents email enumeration)
- [x] Created `ProfileSettings.jsx` — edit Full Name, Course Level, Institution
- [x] Institution field: dropdown (In-house / External / Other) with custom text input for "Other"
- [x] Input sanitization: trim whitespace + Title Case for custom institution names
- [x] Added `/dashboard/settings` route in App.jsx
- [x] Added Settings link with gear icon in ProfileDropdown.jsx (desktop) and NavMobile.jsx (mobile)
- [x] No database changes — uses existing `institution` column in profiles table
- [x] Build verified clean: `npx vite build` passes with no errors

### Flashcard Text-to-Speech / Read Aloud (Feb 8, 2026)
- [x] Created `useSpeech.js` hook — wraps Web Speech API with sentence chunking (Chrome 15-sec bug fix), localStorage for voice URI + speed
- [x] Created `SpeakButton.jsx` — reusable volume icon (Volume2/VolumeX) with pulse animation, hidden on unsupported browsers or empty text
- [x] Created `SpeechSettings.jsx` — popover with voice selector (grouped by language) + speed slider (0.5x–2.0x)
- [x] Integrated into `StudyMode.jsx` — volume icon on QUESTION side, volume icons on both QUESTION recap + ANSWER side after reveal, settings gear next to first volume icon
- [x] Auto-cancel speech on card advance, answer reveal, skip, suspend, reset, and component unmount
- [x] No database changes — pure client-side feature using browser-native Web Speech API
- [x] No new dependencies — zero external packages added

### File Structure Refactor — Pages out of Components (Feb 8, 2026)
- [x] Moved 9 page-level components from `src/components/` to `src/pages/` (enforces pages=routed, components=reusable convention)
- [x] Notes pages (NoteUpload, NoteDetail, NoteEdit) → `pages/dashboard/Content/`
- [x] Flashcard pages (FlashcardCreate, MyFlashcards) → `pages/dashboard/Content/`
- [x] StudyMode → `pages/dashboard/Study/`
- [x] Admin pages → `pages/admin/`
- [x] ProfessorTools → `pages/professor/`
- [x] Fixed NoteEdit route: `/notes/edit/:id` → `/dashboard/notes/edit/:id` (was only route missing `/dashboard` prefix)
- [x] Added legacy redirect for old `/notes/edit/:id` path
- [x] Added route-to-file mapping comment block in App.jsx
- [x] Deleted dead `components/notes/index.jsx` placeholder
- [x] Removed empty `components/notes/`, `components/admin/`, `components/professor/` directories
- [x] Updated imports in App.jsx, ReviewSession.jsx, NoteDetail.jsx

### Clickable Content in Author Profile (Feb 8, 2026)
- [x] Made note/flashcard counts in AuthorProfile subject rows clickable `<Link>` elements
- [x] Notes count links to `/dashboard/notes?author=<id>&subject=<name>`
- [x] Flashcards count links to `/dashboard/review-flashcards?author=<id>&subject=<name>`
- [x] Added `useSearchParams` URL param reading to BrowseNotes.jsx (initializes `filterAuthor` + `filterSubject` from URL)
- [x] Added `useSearchParams` URL param reading to ReviewFlashcards.jsx (same pattern)
- [x] Deep-linking now supported: `/dashboard/notes?author=xxx&subject=Income Tax` auto-filters

### Help & Guide Page (Feb 7, 2026)
- [x] Created `src/data/helpContent.js` — Structured content data (6 tabs, 24 sections, 10 FAQs)
- [x] Created `src/pages/dashboard/Help.jsx` — Help page with tabs, search, collapsible sections, back-to-top
- [x] URL deep linking via `useSearchParams` (e.g., `/dashboard/help?tab=study-groups`)
- [x] Search filters across all tabs and FAQs simultaneously
- [x] Custom expand/collapse sections using Card components (no accordion dependency)
- [x] Added "Help & Guide" to ProfileDropdown.jsx (above Sign Out separator)
- [x] Added "Help & Guide" to NavMobile.jsx (after My Achievements)
- [x] Added route in App.jsx (`/dashboard/help`)
- [x] Added `scrollbar-hide` CSS utility to index.css

### Allow All Members to Share Content in Groups (Feb 7, 2026)
- [x] Updated `share_content_with_groups()` RPC — changed admin check to active member check
- [x] Updated RLS INSERT policy on `content_group_shares` — `cgs_insert_admin` → `cgs_insert_member` (any active member)
- [x] Updated RLS DELETE policy — `cgs_delete_admin` → `cgs_delete_own_or_admin` (admin deletes any, member deletes own)
- [x] Updated GroupDetail.jsx — Share Content button visible to all members (not just admin)
- [x] Updated GroupDetail.jsx — Delete button: admin can delete any shared content, member can delete only their own
- [x] Invite Members button remains admin-only
- [x] **MUST RUN SQL**: `docs/database/study-groups/27_FIX_allow_all_members_to_share_content.sql`

### Group Invitation Flow + Notification Backend (Feb 6, 2026)
- [x] Created `notifications` table with RLS policies, indexes, and JSONB metadata column
- [x] Created 5 notification RPCs + cleanup utility (matches existing useNotifications.js hook)
- [x] Added `status` ('invited'/'active') and `invited_by` columns to `study_group_members`
- [x] Updated `invite_to_group()` — now inserts as 'invited' + creates notification with metadata
- [x] Created `accept_group_invite()` — verifies ownership, updates status, auto-marks notification read
- [x] Created `decline_group_invite()` — marks notification read, hard DELETEs membership row
- [x] Created `get_pending_group_invites()` — for MyGroups pending invitations section
- [x] Updated 5 existing RPCs with `AND status = 'active'` security filter (get_user_groups, get_group_detail, get_browsable_notes, get_browsable_decks, leave_group)
- [x] Updated ActivityDropdown.jsx — group_invite type with inline Accept/Decline buttons
- [x] Updated Navigation.jsx + NavDesktop.jsx + NavMobile.jsx — pass deleteNotification/refetch props
- [x] Updated MyGroups.jsx — pending invitations section with amber-bordered cards + Accept/Decline
- [x] Updated GroupDetail.jsx — "Invite Members" button, "Invitation sent!" toast, pending section in members panel, cancel invite for admins, search excludes pending
- [x] **MUST RUN SQL**: 12 new SQL files (13-24) in `docs/database/study-groups/` in Supabase SQL Editor
- [x] **MUST ENABLE**: Supabase Realtime on `notifications` table (Dashboard → Database → Replication)

### Study Groups - RLS Fix + Server-Side Content Fetching (Feb 6, 2026)
- [x] Fixed infinite recursion in `sgm_select_member` RLS policy → replaced with `sgm_select_own`
- [x] Fixed "Failed to load group" on GroupDetail — replaced 3-query RLS-dependent pattern with single `get_group_detail()` RPC
- [x] Created `get_group_detail()` RPC — returns group info + members + shared content in one call (SECURITY DEFINER)
- [x] Created `get_group_members()` SECURITY DEFINER RPC with membership check
- [x] Created `get_browsable_notes()` RPC — single server-side query for all visible notes (own + public + friends + group-shared)
- [x] Created `get_browsable_decks()` RPC — same for flashcard decks
- [x] Refactored GroupDetail.jsx: single RPC call instead of 3 separate queries
- [x] Refactored BrowseNotes.jsx: removed 3-query client-side merge, now uses single RPC call
- [x] Refactored ReviewFlashcards.jsx: same refactor, single RPC call
- [x] **MUST RUN SQL**: 4 new SQL files (`09`, `10`, `11`, `12`) + updated `02` in `docs/database/study-groups/`

### Study Groups - Phase 1: Read-Only (Feb 6, 2026)
- [x] Created 3 database tables: `study_groups`, `study_group_members`, `content_group_shares`
- [x] All group_id FKs use `ON DELETE CASCADE` (group deletion removes shares, NOT original content)
- [x] 8 RLS policies for member-scoped read, admin-only writes (sgm_select_member → sgm_select_own after fix)
- [x] 6 SECURITY DEFINER RPC functions (create, invite, leave, share, get_groups, get_content)
- [x] MyGroups.jsx - Group list with create/leave/delete
- [x] CreateGroup.jsx - Name + description form, creator becomes admin
- [x] GroupDetail.jsx - Members panel, shared content, invite/share dialogs
- [x] Visibility model: Private | Study Groups | Friends | Public (4-tier)
- [x] NoteUpload + FlashcardCreate - "Study Groups" option + group multi-select checkboxes
- [x] BrowseNotes + ReviewFlashcards - Server-side unified content fetching via RPCs
- [x] Navigation updated in desktop and mobile
- [x] Members can VIEW shared content only, NOT edit
- [x] **MUST RUN SQL**: 11 SQL files in `docs/database/study-groups/` in Supabase SQL Editor

### Card Suspension System - Skip, Suspend, Reset (Feb 6, 2026)
- [x] Added `status` (active/suspended) and `skip_until` (DATE) columns to reviews table
- [x] Created 3 performance indexes on reviews (status, skip_until, composite)
- [x] Created 6 SECURITY DEFINER RPC functions (skip, suspend, suspend_topic, unsuspend, reset, get_suspended)
- [x] Updated StudyMode.jsx with [Skip 24hr] button + [More] dropdown (Suspend Card, Suspend Topic, Reset Card)
- [x] Confirmation dialogs for destructive actions (suspend/reset)
- [x] Updated Progress.jsx with collapsible "Suspended Cards" section + Unsuspend controls
- [x] Updated ReviewSession.jsx and ReviewBySubject.jsx to exclude suspended/skipped cards
- [x] Updated Dashboard.jsx due count and streak to exclude suspended/skipped cards
- [x] **MUST RUN SQL**: Migration + 6 functions in Supabase SQL Editor before features work

### Author Profile Page & Clickable Names (Feb 6, 2026)
- [x] Created `get_author_profile()` RPC function (SECURITY DEFINER) - returns profile + badges + friendship in 1 call
- [x] Created `get_author_content_summary()` RPC function (SECURITY DEFINER) - returns content grouped by course/subject with server-side visibility
- [x] Created `AuthorProfile.jsx` page at `/dashboard/profile/:userId` using 2 RPC calls (not 6 direct queries)
- [x] Shows author name, role badge, institution, course level
- [x] Shows PUBLIC badges only (private badges hidden via frontend filter — managed in My Achievements)
- [x] Content grouped by Course → Subject with note/flashcard counts
- [x] "Also Creates Content For" section for courses viewer isn't enrolled in
- [x] Add Friend button with full friendship status handling
- [x] "Preview as Visitor" toggle on own profile
- [x] Back button with history-aware navigation
- [x] Made author names clickable `<Link>` in 6 locations:
  - BrowseNotes.jsx (note card footer)
  - ReviewFlashcards.jsx (deck card)
  - NoteDetail.jsx (author badge in header)
  - FindFriends.jsx (user card name)
  - MyFriends.jsx (friend card name)
  - MyContributions.jsx (upvoter names - summary, notes, decks)

### Previous: Grid/Grouped View Toggle & Collapsible Sections (Feb 6, 2026)
- [x] Added Grid/Grouped view toggle to MyNotes.jsx (matching MyFlashcards pattern)
- [x] Implemented Grouped View with Subject → Topic hierarchy
- [x] Notes without subject/topic go into "Uncategorized" section (sorted last)
- [x] View preference persisted in localStorage (`myNotes_viewMode`)
- [x] Collapsible subject and topic sections with chevron icons (both views)
- [x] Added collapsible sections to BrowseNotes.jsx (subject + topic levels)
- [x] Added collapsible sections to ReviewFlashcards.jsx (subject level with Study All button preserved)
- [x] Gradient header styling on subject groups (blue-to-indigo)
- [x] Note/topic counts displayed on group headers

### Previous: Author Search with Server-Side Filtering (Feb 5, 2026)
- [x] Created `get_filtered_authors_for_notes()` RPC function
- [x] Created `get_filtered_authors_for_flashcards()` RPC function
- [x] Split Author filter into Role + Author dropdowns
- [x] Implemented dependent Author filtering (updates based on Course/Subject/Role)
- [x] Updated BrowseNotes.jsx with 5-column filter grid
- [x] Updated ReviewFlashcards.jsx with 5-column filter grid
- [x] Server-side visibility enforcement (only PUBLIC content authors shown)

### Previous: Notifications & Navigation Redesign (Phase 1B)
- [x] Database functions for notifications (get, mark read, delete)
- [x] Database function for activity feed (recent notes/decks)
- [x] useNotifications hook with Supabase Realtime subscription
- [x] useFriendRequestCount hook with Realtime subscription
- [x] useActivityFeed hook for dashboard content feed
- [x] Modular Navigation components (6 files replacing 1)
- [x] Desktop: Friends dropdown with inline Accept/Decline
- [x] Desktop: Activity dropdown with auto mark-as-read
- [x] Desktop: Profile dropdown with user info + links
- [x] Mobile: Sheet-based hamburger menu
- [x] Mobile: Friends + Bell icons with badges
- [x] Dashboard: ActivityFeed component showing recent content
- [x] Sheet UI component for mobile navigation

---

## Next Up 🎯

### Professor Content Seeding (Unblocked by Phase A)
- [ ] Add CA Foundation as teaching area in Profile Settings → Teaching Areas
- [ ] Add CA Final as teaching area
- [ ] Switch to CA Foundation context in CourseSwitcher → create content
- [ ] Recruit other professors to add teaching areas

### Phase B: Student Multi-Course (Deferred — Needs Business Decisions First)
- [ ] Decision needed: Upgrade-within-discipline vs cross-discipline enrollment
- [ ] Decision needed: Free tier per course or shared?
- [ ] Decision needed: Dashboard with multiple courses — tab/switch or aggregate?
- [ ] Build `student_enrollments` table + billing integration when decisions are made

### Phase 2: Expansion (March 2026)
- [ ] Scale to 150 CA Foundation students
- [ ] Add more badge types based on user feedback

---

## Active Decisions

| Decision | Status | Notes |
|----------|--------|-------|
| Notes → Flashcards ordering standard | ✅ Decided | All sections use Notes-first order: Create Menu (nav), Quick Actions, My Contributions. Rationale: notes are foundational content; flashcards are derived from them. |
| Study Menu: Flashcards-first (intentional exception) | ✅ Decided | Study Menu keeps Flashcards first ("Review Flashcards" → "Browse Notes") because reviewing flashcards is the primary, active study action (spaced repetition core). Browsing notes is passive reference. The menu's purpose — active study — overrides the general Notes-first standard. |
| Grid/Grouped toggle on MyNotes | ✅ Implemented | localStorage persistence, matches MyFlashcards pattern |
| Collapsible groups on BrowseNotes | ✅ Implemented | Subject + Topic levels, chevron icons |
| Server-side author filtering | ✅ Implemented | RPC functions for performance & security |
| Split Author into Role + Author | ✅ Implemented | Better UX for filtering |
| Instant mark-as-read | ✅ Approved | Notifications marked read immediately on dropdown open |
| Modular navigation | ✅ Implemented | 6 component files for maintainability |
| Mobile Sheet (not menu) | ✅ Implemented | Smooth UX with slide-in animation |
| Study Groups Phase 1 | ✅ Implemented | Read-only sharing, 4-tier visibility, ON DELETE CASCADE |
| Group Invitation Flow | ✅ Implemented | Invite → Notify → Accept/Decline. No auto-add. Notification backend active. |

---

## Known Issues

None currently.

---

## Session Notes

### 2026-02-23 Session (Egress Optimisation — Architecture Learnings)
- **Root cause of migration timeouts:** `LIKE 'data:%'` on TOAST TEXT columns forces PostgreSQL to fully decompress every stored value before scanning — 167 rows × 570 KB = ~92 MB of decompression per query, even if zero rows match. This caused SQL Editor timeouts and Supabase API 504s.
- **Fix that worked:** Two-phase approach — `SELECT id WHERE column IS NOT NULL` (reads null-flag only, zero TOAST load) → loop and fetch one row at a time by primary key (one TOAST decompression per request).
- **`IS NOT NULL` is fast because** it only reads the null-flag stored in the heap tuple; it never touches the TOAST table at all.
- **Supabase billing cycle throttling:** When monthly egress (DB + Storage) exceeds 5 GB, Supabase throttles DB connections. Even `SELECT COUNT(*)` queries with `IS NOT NULL` hung while the project was over-limit (15.5 GB vs 5 GB). Unblock = wait for billing cycle reset. No query tuning can help once throttled.
- **Disk IO Budget** is a separate Supabase quota from egress. Large failed LIKE queries that decompress 92 MB count against it. Expect warnings for ~1 hour after heavy failed queries; it self-recovers.
- **Migration component pattern confirmed:** React component with `@/lib/supabase` is the correct approach — Vite apps don't expose `supabase` as a browser global; console scripts fail silently.
- **Key lesson — "scale assumption failure":** We reasoned about operation *logic* correctly but never quantified bytes. Rule added: always run `pg_size_pretty(SUM(pg_column_size(col)))` before writing any migration. See `context.md` → "Data Migration Architecture Rules" for full checklist.
- **DB size result:** 154 MB → 36 MB (76% reduction) after 167 base64 images migrated to `flashcard-images` Storage bucket.

### 2026-02-08 Session (Flashcard Text-to-Speech)
- Created `useSpeech.js` hook using Web Speech API with sentence chunking to prevent Chrome/Edge 15-second TTS cutoff bug
- Text is split by sentence-ending punctuation (. ! ? \n) and spoken sequentially; fallback to full text if no punctuation
- Voice and speed preferences persisted to localStorage (`recall-tts-voice-uri`, `recall-tts-rate`)
- `SpeakButton` uses `e.stopPropagation()` (established pattern for nested clickable elements)
- `SpeechSettings` uses existing Radix Popover component with voice grouped by language code
- Voices loaded via `voiceschanged` event listener (Chrome loads voices async)
- Speech auto-cancels via `useEffect` on `[currentIndex, showAnswer]` — covers all card transitions
- No database changes needed — future language-per-deck feature would add `language` column to `flashcard_decks`
- Build verified clean: `npx vite build` passes with no errors

### 2026-02-08 Session (File Structure Refactor)
- Root cause: `/dashboard/browse-notes` bug from mismatched file name (`BrowseNotes.jsx`) vs route path (`/dashboard/notes`)
- Moved 9 page-level components from `src/components/` to `src/pages/` to enforce convention: pages=routed, components=reusable
- Fixed only route missing `/dashboard` prefix: `/notes/edit/:id` → `/dashboard/notes/edit/:id`
- Added `LegacyNoteEditRedirect` component for old bookmark compatibility
- Added route-to-file mapping comment (27 routes) in App.jsx for quick reference
- Deleted dead `components/notes/index.jsx` (old "Coming Soon" placeholder, never imported)
- Only 3 files needed import path updates: App.jsx, ReviewSession.jsx, NoteDetail.jsx
- All moved files use `@/` alias imports so internal imports didn't break
- `FlashcardCard.jsx` stays in `components/flashcards/` (reusable component, not a page)
- Empty directories removed: `components/notes/`, `components/admin/`, `components/professor/`
- Build verified clean: `npx vite build` passes with no errors

### 2026-02-06 Session (Group Invitation Flow + Notification Backend)
- Built full notification backend: `notifications` table + 5 RPCs + cleanup utility
- Added `status` ('invited'/'active') + `invited_by` columns to `study_group_members`
- Follows friendships table pattern (status column, not separate table)
- `invite_to_group()` now inserts as 'invited' and creates notification with JSONB metadata
- Accept/decline RPCs auto-cleanup notifications via metadata->>'membership_id'
- All content-access RPCs updated with `AND status = 'active'` security filter
- ActivityDropdown: group_invite notifications render with inline Accept/Decline (not as links)
- MyGroups: Amber-bordered "Pending Invitations" section above groups grid
- GroupDetail: "Invite Members" button, pending section in members panel, cancel invite for admins
- Search filter in invite dialog excludes both active members AND pending invitations
- 12 SQL files (13-24) must be run in Supabase SQL Editor
- Must enable Supabase Realtime on `notifications` table separately

### 2026-02-06 Session (Study Groups Phase 1)
- Created 3 new database tables with ON DELETE CASCADE on group_id FKs
- 8 RLS policies: members read their own groups, admins manage membership/shares
- 6 SECURITY DEFINER RPC functions for all group operations
- 3 new pages: MyGroups, CreateGroup, GroupDetail (with invite, share content, remove member dialogs)
- 4-tier visibility model: Private | Study Groups | Friends | Public
- NoteUpload + FlashcardCreate: "Study Groups" visibility with multi-select group checkboxes
- BrowseNotes + ReviewFlashcards: merge group-shared content with existing visibility-filtered content
- Navigation: Groups link in desktop nav, Study Groups section in mobile sheet
- leave_group() promotes oldest member to admin if last admin leaves
- Content stores as 'private' visibility in DB when shared with groups (access via content_group_shares table)
- SQL files in docs/database/study-groups/ (01-08) must be run in Supabase SQL Editor

### 2026-02-06 Session (Card Suspension System)
- Added `status` TEXT NOT NULL DEFAULT 'active' CHECK (active/suspended) to reviews table
- Added `skip_until` DATE DEFAULT NULL to reviews table
- Created 3 indexes: idx_reviews_status, idx_reviews_skip_until, idx_reviews_user_status_due (partial)
- Created 6 RPC functions: skip_card, suspend_card, suspend_topic_cards, unsuspend_card, reset_card, get_suspended_cards
- All functions use SECURITY DEFINER and respect user timezone from profiles.timezone
- StudyMode.jsx: Added Skip button (no confirmation), More dropdown with Suspend/Reset (with confirmation dialogs)
- Progress.jsx: Added collapsible Suspended Cards section grouped by subject with Unsuspend buttons
- ReviewSession.jsx + ReviewBySubject.jsx: Added `.eq('status', 'active')` and skip_until filtering to due card queries
- Dashboard.jsx: Due count and streak now exclude suspended cards and quality=0 placeholder records
- Streak logic: Only counts reviews where quality > 0 (actual study, not skip/suspend placeholder records)

### 2026-02-06 Session (Author Profile)
- Created 2 SECURITY DEFINER RPC functions: `get_author_profile()` and `get_author_content_summary()`
- Created AuthorProfile.jsx using RPC functions (2 round-trips instead of 6 direct queries)
- Added `/dashboard/profile/:userId` route to App.jsx
- Made author/user names clickable Links in 6 files (BrowseNotes, ReviewFlashcards, NoteDetail, FindFriends, MyFriends, MyContributions)
- Server-side visibility enforcement: public for strangers, public+friends for friends, all for own
- **MUST RUN SQL**: Both functions need to be created in Supabase SQL Editor before page works

### 2026-02-06 Session (Grid/Grouped)
- Added Grid/Grouped view toggle to MyNotes.jsx with localStorage persistence
- Implemented Subject → Topic hierarchy grouping with "Uncategorized" fallback
- Extracted `renderNoteCard` helper for shared card rendering in both views
- Added collapsible chevrons to BrowseNotes.jsx (subject + topic levels)
- Added collapsible chevrons to ReviewFlashcards.jsx (subject level, Study All button uses stopPropagation)
- No database changes required (uses existing subject/topic joins)
- No new files created (modified MyNotes.jsx, BrowseNotes.jsx, ReviewFlashcards.jsx)

### 2026-02-05 Session
- Implemented Author Search with server-side filtering per QA Bot requirements
- Created 2 new Supabase RPC functions
- Split Author filter into Role + Author for better granularity
- Author dropdown now dynamically updates based on other filter selections
- Only authors with PUBLIC content shown (visibility enforcement)

### 2026-02-02 Session
- Rebuilt Navigation into modular components
- Added realtime hooks for notifications and friend requests
- Integrated ActivityFeed into Dashboard
- Fixed ESLint warnings (unused imports)
- Centered desktop nav links (Logo left, Nav center, Icons right)
