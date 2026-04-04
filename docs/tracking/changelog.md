# Changelog

---
## [2026-04-04] feat: Sprint 4.1 — Unsaved work protection in FlashcardCreate

### Added
- **Navigation guard (`useBlocker`)** in `FlashcardCreate.jsx` — Intercepts all in-app navigation (Back button, Cancel, browser back swipe) when the form is dirty (any card has content or >1 cards). Shows an inline confirmation modal with "Keep editing" / "Leave anyway" options.
- **`beforeunload` event listener** — Intercepts browser tab close and page reload with the browser's native warning when the form is dirty.
- **localStorage autosave** — Saves card text and image URLs to `localStorage['flashcard_create_draft']` with a 1-second debounce as the user types. `setItem` wrapped in `try/catch` with `console.warn` for graceful degradation in Safari Private Browsing.
- **Draft recovery banner** — Amber banner shown on page mount when a prior draft is detected. Displays card count and relative time ("Auto-saved 5 minutes ago"). Restore / Discard actions.
- **Draft cleared on successful submit** — `localStorage.removeItem(DRAFT_KEY)` called before `navigate('/dashboard')` on successful save.

### Changed
- **Pro Tip card copy** — Updated to inform users upfront: "Your items are auto-saved as you type — if you accidentally leave this page, you can restore your work when you come back."
- **`removeFlashcard` and image remove handlers** — Guard `URL.revokeObjectURL` to only fire on blob URLs, not on Supabase public URLs (which are used as previews when restoring a draft).

### Files Changed
`src/pages/dashboard/Content/FlashcardCreate.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`

---
## [2026-04-04] fix: Sprint 4.0 — Skip Topic (24hr) feature + null topic bug fix

### Added
- **`skip_topic_cards` RPC** (Supabase) — New SECURITY DEFINER function. Bulk-sets `skip_until = tomorrow` on all active review records for cards matching the given `topic_id` or `custom_topic`. Creates review records for cards the user has never seen. Leaves suspended cards untouched. Returns count of snoozed cards.
- **`handleSkipTopic`** in `StudyMode.jsx` — Calls `skip_topic_cards`, fires "Topic snoozed" toast with count, and removes same-topic cards from the current session's in-memory queue.
- **Skip Topic (24hr)** option added to both `...` dropdown menus (question side and answer side) in StudyMode. Only visible when card has a `topic_id` or `custom_topic`. Triggers a confirmation dialog with safe/default button styling.

### Fixed
- **Null topic bug** — Topic-level dropdown items (`Skip Topic`, `Suspend Topic`) were only rendered when `currentCard.topic_id` was truthy. Cards with `custom_topic` (no FK `topic_id`) silently never showed these options. Fixed: condition now checks `topic_id || custom_topic` in both dropdown instances.
- **`handleSuspendTopic` null guard** — Guard `if (!topicId)` would fire for custom-topic cards even after the button was made visible. Fixed: guard now checks `!topicId && !customTopic`. Both `p_topic_id` and `p_custom_topic` are now passed to the updated `suspend_topic_cards` RPC.
- **`suspend_topic_cards` RPC** — Extended signature with `p_custom_topic TEXT DEFAULT NULL`. Handles both named topics (via `topic_id` FK) and free-text topics (via `custom_topic`). Fully backward compatible.

### Changed
- **`...` dropdown restructured** — Safe actions first (Skip Topic 24hr, blue icon), destructive actions below separator (Suspend Card, Suspend Topic, Reset Card all in `text-red-600`). Confirm dialog button is now `destructive` variant for all suspend/reset actions and `default` for Skip Topic.
- **`helpContent.js` `skip-suspend` section** — Title updated to "Skip, Suspend & Reset". Expanded from 3 inaccurate bullets to 5 accurate ones covering all actions at both card and topic level. Added tip block steering students toward Skip over Suspend. FAQ updated from single-suspend question to "What is the difference between Skip and Suspend?" covering all four actions.
- **`guideContent.js` Falling Behind situation** — Added new step "One topic too heavy? Skip it for today." explaining Skip Topic (24hr) with a link to Review Flashcards.

### Files Changed
`src/pages/dashboard/Study/StudyMode.jsx`, `src/data/helpContent.js`, `src/data/guideContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-30] fix: Sprint 3.9 — Push notification CRON_SECRET mismatch (infrastructure)

### Fixed
- **pg_cron job `cron-daily-study-summary`** — Job command had literal placeholder `YOUR_CRON_SECRET_HERE` as the `x-cron-secret` header value since Sprint 3.6 was deployed. Every invocation returned HTTP 401 and the function body never executed. No nightly study summary notification was ever delivered to any user.
- **pg_cron job `daily-review-reminders`** — After rotating `CRON_SECRET` via Supabase CLI to fix the above, this job began returning 401 because it still sent the original hash. Resynced job command to the new secret value.
- Both cron jobs now return HTTP 200. First post-fix nightly summary: 2026-03-29 22:00 IST. First post-fix morning reminder: 2026-03-31 08:00 IST.

### Files Changed
`docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md` (no source code changes — infrastructure fix only)

---
## [2026-03-28] fix: Sprint 3.8 — Study time logging for mid-session exits and iOS force-quits

### Fixed
- **`src/pages/dashboard/Study/StudyMode.jsx`** — Mid-session exits via `handleExit()` never logged study time. `logStudyModeSession()` was only called inside `finishSession()` (triggered when the final card is rated), so students who reviewed cards and then navigated away got 0 study time despite review rows being written card-by-card. This caused widespread `< 1m` study time on the leaderboard for students with 20–30 reviews. Fix: added `logStudyModeSession()` call at the top of `handleExit()`, fire-and-forget, before navigation. Double-logging is prevented by the existing localStorage-clear-before-DB-call pattern in `logStudyModeSession()`.
- **`src/pages/dashboard/Study/StudyMode.jsx`** — Tab closes, iOS app swipe-away, and app backgrounding silently discarded all study time since no button click was possible. Fix: added a `visibilitychange` event listener that fires `logStudyModeSession()` when `document.visibilityState === 'hidden'`. Listener is registered on mount and cleaned up on unmount. Handles iOS force-quit (app switch triggers `hidden` before the process is killed). Same localStorage-based deduplication ensures a subsequent clean exit is a no-op.

### Files Changed
`src/pages/dashboard/Study/StudyMode.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-27] fix: Sprint 3.7b — handleStop 3-tier leaderboard protection + context-aware prompt copy

### Fixed
- **`src/components/dashboard/StudyTimerWidget.jsx`** — `handleStop` had no duration ceiling. A student who kept the browser tab open (bypassing the mount-time stale session check) and pressed Stop after 21h+ would log the full duration, corrupting leaderboard stats. Applied the same 3-tier policy as mount-time stale session recovery: `< 4h` logs normally; `4–16h` routes to the honest-session prompt (localStorage keys intentionally preserved so mount can recover the session if student navigates away mid-prompt); `> 16h` discards and shows a destructive toast. Added `useToast` import.
- **Recovery prompt copy is now source-aware.** Added `source: 'stale' | 'stop'` field to `recoveryPrompt` state. Mount-triggered (stale) prompt keeps original copy: *"Your timer ran for Xh. Were you studying the whole time?"* / *"Yes — log Xh"*. Stop-triggered prompt uses encouraging copy: *"Wow, a Xh session! Just confirming — do you want to log the full time, or did you leave the timer running during a break?"* / *"Log full Xh"*. Tier 3 toast updated to: *"Timers over 16 hours cannot be logged to protect leaderboard integrity."*

### Files Changed
`src/components/dashboard/StudyTimerWidget.jsx`, `docs/tracking/changelog.md`

---
## [2026-03-27] fix: Sprint 3.7 — iOS push banner, study session logging, timer UX

### Fixed
- **`src/components/notifications/PushPermissionBanner.jsx`** — iOS users in a regular Safari tab (not installed as PWA) never saw the "Add to Home Screen" install instructions. `PushManager` is unavailable in iOS Safari in-browser, so `isSupported = false`. The `if (!isSupported) return null` guard was evaluated before the `needsIOSInstall` check, making the iOS instructions dead code. Fix: moved `handleDismiss` above all guards, added the `needsIOSInstall` early return before the `isSupported` guard.
- **`src/pages/dashboard/Study/StudyMode.jsx`** — `handleRating()` handled the last-card completion inline (directly calling `onComplete`/`onExit` without calling `finishSession()`). `logStudyModeSession()` was therefore never called on the primary completion path (rating the final card). Only skip/suspend/reset paths correctly triggered `finishSession()`. Fix: replaced inline last-card completion code in `handleRating` with `finishSession()`.
- **`src/components/dashboard/StudyTimerWidget.jsx`** — After the 4–16h honest-session recovery prompt logs a session, the widget returned to idle showing "Session logged: Xh Ym" but gave no indication the student needed to press Start for a new session. Added `postRecovery` boolean state; when true (set after recovery-prompt log, cleared on Start), a "Tap Start to begin a new session." hint appears below the confirmation text.

### Files Changed
`src/components/notifications/PushPermissionBanner.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/components/dashboard/StudyTimerWidget.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`

---
## [2026-03-25] feat: Sprint 3.6 — Nightly Study Summary Push Notification

### Added
- **`supabase/functions/cron-daily-study-summary/index.ts`** (NEW) — Deno Edge Function. Runs every 15 min via pg_cron. Finds students whose local time is 22:00–22:14, checks 7-day activity, computes today's study seconds, and sends a personalised push. Two message variants: "Great work today 🎯" (≥60s logged, shows formatted duration + leaderboard nudge) vs "Time to open the books 📚" (<60s). Stale subscriptions (410/404) marked `is_active = false` and skipped on subsequent runs. Returns `{ processed, sent, failed, removed_stale }`.
- **pg_cron schedule** `cron-daily-study-summary` on `*/15 * * * *` — see session notes for exact SQL.

### Changed
- **`docs/reference/DATABASE_SCHEMA.md`** — Added `push_subscriptions` table doc, `push_notification_preferences` table doc, and new "Edge Functions" reference section documenting all 6 functions including `cron-daily-study-summary`.
- **`docs/reference/FILE_STRUCTURE.md`** — Added `cron-review-reminders` and `cron-daily-study-summary` entries under `supabase/functions/`.

### Files Changed
`supabase/functions/cron-daily-study-summary/index.ts` (NEW), `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-03-25] fix: Sprint 3.1 patch — Study Timer 3-tier stale session recovery

### Changed
- **`src/components/dashboard/StudyTimerWidget.jsx`** — Replaced single "Log it / Discard" recovery prompt with three-tier mount logic: `< 4h` auto-resumes silently (handles app-switch + page reload); `4–16h` shows honest-session prompt with full-log, custom-hours input (1h to max elapsed), and discard options; `> 16h` silently discards to protect leaderboard integrity. Added `startMsRef` + `useEffect(timerState)` so resumed clock shows correct elapsed immediately, not "00:00".
- **`src/data/helpContent.js`** — `study-timer` help section: old single-line discard tip replaced with a list describing all three tiers, plus a tip encouraging students to press Stop before switching away.

### Files Changed
`src/components/dashboard/StudyTimerWidget.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-24] feat: contextual info modal on all three public share pages

### Added
- **GuideInfoModal.jsx** (NEW) — shared component at `src/components/GuideInfoModal.jsx`. Accepts `situationId` + `triggerLabel` props. Renders a subtle trigger button and a shadcn `<Dialog>` modal populated from `SITUATIONS` in `guideContent.js`. No page navigation, no new tab — postAuthRedirect funnels preserved on all pages.
- **DeckPreview.jsx** — `<GuideInfoModal situationId="studying">` below logged-out CTA. Trigger: "New to Recall? See how Study Sets work →"
- **NotePreview.jsx** — `<GuideInfoModal situationId="content">` below logged-out CTA. Trigger: "New to Recall? See how Notes work →"
- **GroupJoin.jsx** — `<GuideInfoModal situationId="social">` below logged-out CTA. Trigger: "New to Recall? See how Groups work →"

### Files Changed
- `src/components/GuideInfoModal.jsx` (NEW)
- `src/pages/public/DeckPreview.jsx`
- `src/pages/public/NotePreview.jsx`
- `src/pages/public/GroupJoin.jsx`

---
## [2026-03-24] feat: Sprint P3 — Student Guide discovery, polish & page completion

### Added
- **Home.jsx** — "Student Guide" nav link in desktop navbar (left of Login) and mobile nav bar. Plain text, matches existing nav style. Visible on all screen sizes.
- **Home.jsx** — Student Guide banner above the footer. Full-width muted strip (bg-gray-50, border-gray-200) with "New to Recall?" text and a blue pill `<Link to="/guide">`. Public-to-public navigation, no postAuthRedirect.
- **StudentGuide.jsx** — "You are here." intro block (bg-indigo-50, border-indigo-100, rounded-xl) above the two-panel layout. Includes inline login link for returning users.
- **StudentGuide.jsx** — "Still need help?" closing block (bg-gray-50, border-gray-200, rounded-xl) after all situation sections. `<Link to="/">` with ArrowLeft icon. Not shown in sidebar nav.
- **StudentGuide.jsx** — "↑ Back to top" button at the bottom of the desktop sidebar. Calls `window.scrollTo({ top: 0, behavior: 'smooth' })`.

### Changed
- **StudentGuide.jsx** — `useEffect` sets `document.title = 'Student Guide — Recall'` on mount, resets to `'Recall'` on unmount. Imported `ArrowLeft` from lucide-react.

### Files Changed
- `src/pages/Home.jsx`
- `src/pages/guide/StudentGuide.jsx`

---
## [2026-03-23] feat: Sprint P2 — Student Guide full content, step list, links, scroll spy

### Added
- **guideContent.js** — New data file at `src/data/guideContent.js`. Exports `SITUATIONS` array with all 9 situations (enrollment, orientation, studying, behind, content, scoring, stats, social, reports). Each situation has `id`, `sidebarLabel`, `emoji`, `headline`, and a `steps` array. Each step has `label`, `detail`, `linkLabel`, `linkTo`, `isSignup`.
- **Step list rendering** — Each section now renders a numbered `<ol>` of steps. Each step shows a step-number badge, bold label, muted detail text, and an optional "label →" chip button.
- **Navigation chips** — Chips call `handleStepLink(linkTo, isSignup)`. `isSignup: true` routes directly to `/signup`. All other `linkTo` values set `localStorage.postAuthRedirect` and navigate to `/login`.
- **IntersectionObserver scroll spy** — Watches all 9 `<section>` elements with `threshold: 0.2` and `rootMargin: '-20% 0px -60% 0px'`. Active section highlighted in sidebar (blue-50 bg, blue-700 text, blue-500 left border) and mobile pill (blue-600 bg, white text).

### Changed
- **StudentGuide.jsx** — Replaced inline `situations` array with import from `@/data/guideContent`. Added `useNavigate`, `useState`, and scroll spy `useEffect`. Sidebar buttons and mobile pills now reflect `activeId` state.

### Files Changed
- `src/data/guideContent.js` (NEW)
- `src/pages/guide/StudentGuide.jsx`
- `docs/reference/FILE_STRUCTURE.md`

---
## [2026-03-23] feat: Sprint P1 — Public /guide Student Guide shell

### Added
- **StudentGuide.jsx** — New public page at `/guide` (no auth, no DB calls). Two-panel layout: sticky left sidebar (~260px) on desktop listing all 9 situations as clickable nav buttons; horizontal scrollable pill row on mobile (sticky below header). Smooth scroll to section anchors on click.
- **9 situations defined:** enrollment, orientation, studying, behind, content, scoring, stats, social, reports — each with id, sidebarLabel, emoji, headline, tone, and empty `actions` array (filled in Sprint P2).
- **Header bar:** "Recall" wordmark + "Student Guide" tagline linking to `/`; "Log in" link to `/login` on the right.
- **Section shells:** Each situation renders `<section id={situation.id}>` with emoji + headline and placeholder text "Actions coming in Sprint P2." Subtle `<hr>` dividers between sections.

### Changed
- **App.jsx** — Added `StudentGuide` lazy import and `/guide` route in the public no-auth-guard block.

### Files Changed
- `src/pages/guide/StudentGuide.jsx` (NEW)
- `src/App.jsx`

---
## [2026-03-23] feat: Sprint 2.7-B — Role-based Help section + Option C layout

### Added
- **Help.jsx** — Desktop sidebar nav (`w-44` sticky left column, `md:flex` two-column layout). Each tab is a button in the sidebar; active tab highlighted in blue-50.
- **Help.jsx** — Mobile accordion: each tab renders as a collapsible full-width header. Blue background when open, gray when closed. Clicking the open tab closes it. No horizontal scrolling on any screen size.

### Changed
- **helpContent.js** — `professor-guide` tab-level and all section-level `roles` updated from `['professor']` to `['professor', 'admin', 'super_admin']`. Admins now see the full For Professors guide.
- **helpContent.js** — `prof-bulk-csv` section in Content tab roles updated same way.

### Files Changed
- `src/pages/dashboard/Help.jsx`
- `src/data/helpContent.js`

---
## [2026-03-23] feat: Clickable upvote notifications + Professor Analytics charts

### Added
- **ProfessorAnalytics** — Quality Distribution donut chart (PieChart from recharts). Computed from subject-level average quality, bucketed into Easy (≥4) / Medium (3–4) / Hard (<3) / Not Reviewed. Placed in 2-column grid alongside Weekly New Students bar chart.

### Changed
- **ActivityDropdown** — Upvote notifications now route dynamically using `metadata.content_id` + `metadata.content_type`. Notes navigate to `/dashboard/notes/{id}`; flashcard deck upvotes fall back to `/dashboard/my-contributions`. Graceful fallback when metadata is absent.
- **ProfessorAnalytics** — "Weakest Cards" renamed to "Challenging Cards" with explanatory note clarifying this reflects student recall difficulty, not content framing issues.
- **ProfessorAnalytics** — Most Reviewed Cards panel now has descriptive subtitle ("high engagement, likely high importance").

### Files Changed
- `src/components/layout/ActivityDropdown.jsx`
- `src/pages/dashboard/ProfessorAnalytics.jsx`

---
## [2026-03-22] feat: Sprint 3.5 — Leaderboard + Goals

### Added
- **Supabase** — `profiles.daily_review_goal` (integer, nullable, CHECK >0 AND <=200) + `profiles.daily_study_goal_minutes` (integer, nullable, CHECK >0 AND <=480)
- **Supabase** — `get_friends_leaderboard()` SECURITY DEFINER RPC. Mutual friends (students only) + caller, ranked by reviews_this_week DESC / study_time_this_week_seconds as tiebreaker. DENSE_RANK. Fields: rank, user_id, full_name, is_self, reviews_this_week, study_time_this_week_seconds.
- **Supabase** — `get_following_leaderboard()` SECURITY DEFINER RPC. Full followee set ranked, top 20 returned + caller's own row regardless of rank. Same fields as friends leaderboard.
- **Supabase** — `update_daily_goal(p_review_goal, p_study_goal_minutes)` SECURITY DEFINER RPC. Either value can be NULL to clear.
- **`src/components/dashboard/LeaderboardWidget.jsx`** (new) — Isolated widget. Friends tab (fetches on mount) + Following tab (lazy, first-click). Skeleton loading, error+retry, empty states. Caller's row highlighted blue.
- **`src/components/dashboard/GoalProgressWidget.jsx`** (new) — Daily goal widget. States: no goal, editing (inline input), active progress (bar, actual vs target, Edit, goal-reached green). Writes via update_daily_goal RPC.

### Changed
- **`src/pages/Dashboard.jsx`** — Profile select adds `daily_review_goal` + `daily_study_goal_minutes`. New state: `reviewGoal`, `studyGoalMinutes`, `todayReviews`. `fetchPersonalStats` computes `todayReviews` from existing reviews data. GoalProgressWidget added after Study Time section; LeaderboardWidget added after Anonymous Stats.
- **`src/pages/dashboard/Groups/GroupDetail.jsx`** — Batch Performance table: `#` rank column added as first column, derived client-side from sort order.
- **`src/data/helpContent.js`** — `leaderboard` section added to Social tab; `daily-goals` section added to Getting Started tab; `prof-batch-performance` updated with `#` rank column description.

### Files Changed
`src/components/dashboard/LeaderboardWidget.jsx`, `src/components/dashboard/GoalProgressWidget.jsx`, `src/pages/Dashboard.jsx`, `src/pages/dashboard/Groups/GroupDetail.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-03-22] fix: Hide study stats for professors/admins on Following page

### Changed
- **`src/pages/dashboard/Friends/Following.jsx`** — Stats row (streak / reviews / study time) now renders only for `role === 'student'`. For professors and admins, replaced with "Visit their profile to explore notes and flashcards." — avoids the misleading impression that they are inactive.
- **`src/data/helpContent.js`** — follow-system section updated to document the student-only stats behaviour.

### Files Changed
`src/pages/dashboard/Friends/Following.jsx`, `src/data/helpContent.js`

---
## [2026-03-22] feat: Follow system discoverability + label cleanup

### Changed
- **`src/components/layout/FriendsDropdown.jsx`** — Header renamed "Friend Requests" → "Friends & Following". "Find Friends" link renamed "Find People".
- **`src/pages/dashboard/Friends/FindFriends.jsx`** — Page title "Find Friends" → "Find People". Subtitle updated to reflect both friend and follow actions. Follow/Following toggle button added to each card (fetches existing follows on mount via `get_following_with_stats`; optimistic toggle).
- **`src/data/helpContent.js`** — All "Find Friends" references updated to "Find People"; dropdown references updated to "Friends & Following"; follow-system how-to updated to mention Find People as primary discovery surface.

### Files Changed
`src/components/layout/FriendsDropdown.jsx`, `src/pages/dashboard/Friends/FindFriends.jsx`, `src/data/helpContent.js`

---
## [2026-03-22] feat: Sprint 3.4 — Follow System

### Added
- **Supabase** — `follows` table with RLS (INSERT/DELETE own follower_id; SELECT if caller is follower or followee). Indexes on `follower_id` and `followee_id`. UNIQUE constraint and self-follow CHECK.
- **Supabase** — `follow_user(p_followee_id uuid)` SECURITY DEFINER RPC. Idempotent follow. Fires a `'follow'` notification into `notifications` table on new follow only (via `GET DIAGNOSTICS ROW_COUNT`).
- **Supabase** — `unfollow_user(p_followee_id uuid)` SECURITY DEFINER RPC.
- **Supabase** — `get_following_with_stats()` SECURITY DEFINER RPC. Returns followees with `reviews_this_week`, `streak_days` (via `get_user_streak`), `study_time_this_week_seconds`, `following_since`. All stats COALESCE to 0.
- **Supabase** — `get_follow_status(p_target_id uuid)` SECURITY DEFINER RPC. Returns `{ is_following: boolean }`.
- **`src/pages/dashboard/Friends/Following.jsx`** (new) — Following page. Card layout matches MyFriends.jsx exactly. Skeleton loading, optimistic unfollow, empty state.

### Changed
- **`src/pages/dashboard/Profile/AuthorProfile.jsx`** — Follow/Unfollow button added for non-own profiles. Fetches initial state via `get_follow_status` in existing `Promise.all`. Hover state switches "Following ✓" → "Unfollow". Optimistic updates with revert on error.
- **`src/App.jsx`** — `/dashboard/following` route added.
- **`src/components/layout/FriendsDropdown.jsx`** — "Following" link added (after My Friends), `Rss` icon.
- **`src/components/layout/NavMobile.jsx`** — "Following" button added in Groups section, `Rss` icon.
- **`src/data/helpContent.js`** — `follow-system` section added to Social tab explaining one-way follows, no course restriction, stats visibility, how to follow/manage.

### Files Changed
`src/pages/dashboard/Friends/Following.jsx`, `src/pages/dashboard/Profile/AuthorProfile.jsx`, `src/App.jsx`, `src/components/layout/FriendsDropdown.jsx`, `src/components/layout/NavMobile.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-03-22] feat: Sprint 3.3 — Friend System Cleanup + Mutual Stats

### Added
- **Supabase** — `get_discoverable_users()` SECURITY DEFINER RPC. Filters to caller's `course_level`; excludes self, pending requests (both directions), accepted friends. Server-side email masking: `first_char***@domain`. Returns `user_id`, `full_name`, `masked_email`, `course_level`, `institution`, `role`.
- **Supabase** — `get_my_friends_with_stats()` SECURITY DEFINER RPC. Confirmed friends only, no N+1. Returns `friendship_id`, `user_id`, `full_name`, `masked_email`, `course_level`, `role`, `reviews_this_week`, `streak_days` (via `get_user_streak`), `study_time_this_week_seconds` (from `study_sessions`), `friends_since`. All stats COALESCE to 0.

### Changed
- **`src/pages/dashboard/Friends/FindFriends.jsx`** — Replaced direct `profiles` table query with `.rpc('get_discoverable_users')`. Removed `maskEmail`, `friendships` state, `fetchFriendships`, `getFriendshipStatus`. Action buttons simplified to single "Add Friend" (excluded users never appear). After send, list auto-refreshes via re-fetch.
- **`src/pages/dashboard/Friends/MyFriends.jsx`** — Replaced two-step N+1 fetch with `.rpc('get_my_friends_with_stats')`. Added skeleton loading (3 cards). Added per-friend stats row: streak, reviews this week, study time. Updated empty state with course_level interpolation. Unfriend uses `friendship_id` from RPC.
- **`src/pages/dashboard/Friends/FriendRequests.jsx`** — Dropped `email` from profiles select (was fetched but never rendered). Avatar fallback updated.
- **`src/data/helpContent.js`** — `finding-friends` steps updated (server-side filtering noted, stale manual-filter step removed). New `friend-stats` section added explaining streak / reviews / study time display.

### Files Changed
`src/pages/dashboard/Friends/FindFriends.jsx`, `src/pages/dashboard/Friends/MyFriends.jsx`, `src/pages/dashboard/Friends/FriendRequests.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/reference/DATABASE_SCHEMA.md`

---
## [2026-03-22] feat: Sprint 3.2 — Batch Group as Professor Tool

### Added
- **Supabase** — `get_batch_group_member_stats(p_group_id uuid)` SECURITY DEFINER RPC: returns `user_id`, `full_name`, `reviews_this_week`, `streak_days` (via `get_user_streak`), `study_time_this_week_seconds`, `last_active_date` per active student member. Two security gates: caller role check, batch group check. Week: `date_trunc('week', CURRENT_DATE)`. Zero-activity values coalesced to 0.
- **`src/pages/dashboard/Groups/GroupDetail.jsx`** — Batch Performance view for professors/admins on batch groups: sortable table (Name, Reviews This Week, Streak, Study Time, Last Active), loading skeleton, error + retry, empty state. Student safety redirect. `fetchBatchStats` function. `formatStudyTime`, `formatLastActive`, `handleSort`, `SortHeader` helpers. New imports: `Shield`, `ChevronUp`, `ChevronDown`, `RefreshCw`.
- **`src/data/helpContent.js`** — `prof-batch-performance` section in For Professors tab: navigation steps, column explanations, Last Active caveat, batch group creation note.

### Changed
- **`src/pages/dashboard/Groups/MyGroups.jsx`** — Students: batch groups excluded at query level via `.rpc('get_user_groups').eq('is_batch_group', false)` + `get_my_batch_groups` skipped. Role fetched from profiles in `fetchGroups`. Professors/admins unchanged.
- **`src/components/dashboard/AnonymousStats.jsx`** — Added `courseLevel` prop. "Class Average" bar label now reads `"vs all Recall students studying [course_level]"` or `"vs all Recall students"` when null.
- **`src/pages/Dashboard.jsx`** — Added `userCourseLevel` state from `profile.course_level`. Passed to `<AnonymousStats>` as `courseLevel`.

### Files Changed
`src/pages/dashboard/Groups/MyGroups.jsx`, `src/pages/dashboard/Groups/GroupDetail.jsx`, `src/components/dashboard/AnonymousStats.jsx`, `src/pages/Dashboard.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`

---
## [2026-03-22] feat: Sprint 3.1 — Study Timer

### Added
- **Supabase** — `study_sessions` table: `id`, `user_id`, `started_at`, `ended_at` (NOT NULL), `duration_seconds` (NOT NULL, CHECK > 0), `session_date` (date), `source` (CHECK 'manual'|'study_mode'), `created_at`. Only completed sessions stored — DB never holds incomplete rows.
- **Supabase** — RLS on `study_sessions`: authenticated INSERT + SELECT own rows (`auth.uid() = user_id`). Index `idx_study_sessions_user_date` on `(user_id, session_date)`.
- **Supabase** — `get_study_time_stats(p_user_id uuid, p_local_date date)` SECURITY DEFINER RPC: returns `today_seconds`, `week_seconds`, `today_sessions`, `week_sessions`. Uses `p_local_date` for correct timezone handling.
- **`src/components/dashboard/StudyTimerWidget.jsx`** — New isolated manual timer component. Clock via DOM ref (zero Dashboard re-renders per tick). Idle / running / saving states. Stale session recovery (< 4h prompt, ≥ 4h silent discard). `onSessionLogged` callback.
- **`src/data/helpContent.js`** — `study-timer` section in Getting Started tab.

### Changed
- **`src/pages/Dashboard.jsx`** — Student section: "⏱ Study Time" 3-col grid (Today, This Week, StudyTimerWidget). `fetchStudyTimeStats` RPC. `formatStudyTime` helper. `authUserId` state. `Clock` + `StudyTimerWidget` imports.
- **`src/pages/dashboard/Study/StudyMode.jsx`** — Session start to localStorage on load; `logStudyModeSession()` fire-and-forget from `finishSession()`.
- **`src/pages/dashboard/Help.jsx`** — `Timer` added to lucide imports and `ICON_MAP`.

### Files Changed
`src/components/dashboard/StudyTimerWidget.jsx` (new), `src/pages/Dashboard.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/data/helpContent.js`, `src/pages/dashboard/Help.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-03-21] fix: Dashboard placeholder card consistency (post-Sprint 2.9)

### Changed
- **`src/pages/Dashboard.jsx`** — Professor "Needs Attention" card now always visible (was hidden when `needsAttentionItems.length === 0`); zero-state shows "No flags on your content. All clear!" in gray; active state shows amber styling with flag list unchanged
- **`src/pages/Dashboard.jsx`** — Admin and Super Admin "Needs Review" card zero-state title changed from `'Flagged Content'` to `'Needs Review'` for label consistency

### Files Changed
`src/pages/Dashboard.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-21] feat: Sprint 2.9 — flagged content workflow completion

### Added
- **Supabase** — `auto_resolve_content_error_flags()` trigger function (SECURITY DEFINER): auto-resolves pending `content_error` flags when a note or flashcard is updated by its creator; sets `resolution_note = 'Content updated by creator'`
- **Supabase** — `trg_auto_resolve_note_flags` AFTER UPDATE trigger on `notes`
- **Supabase** — `trg_auto_resolve_flashcard_flags` AFTER UPDATE trigger on `flashcards`
- **`src/pages/Dashboard.jsx`** — Student "My Reports" card: fetches student's own `content_flags` rows (up to 10); shows content_type, reason label, status pill (Under review / Resolved / Dismissed / Content removed); hidden when no reports submitted

### Changed
- **`src/pages/Dashboard.jsx`** — Professor Needs Attention card: "Review" button replaced with "Edit" + "Mark resolved" buttons; "Mark resolved" calls `resolve_content_flag` RPC and refreshes list in place
- **`src/data/helpContent.js`** — `flagging-content` section: second tip added about tracking report status via dashboard "My Reports"

### Files Changed
`src/pages/Dashboard.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-21] feat: Sprint 2.8-B — full flagged content workflow

### Added
- **Supabase** — `content_flags` table with RLS (flagged_by, content_type, content_id, reason, details, status, priority, resolved_by, resolution_note, resolved_at, created_at); CHECK constraints on content_type/reason/status/priority; indexes on (content_type, content_id) and (status, priority, created_at)
- **Supabase** — `submit_content_flag(p_content_type, p_content_id, p_reason, p_details)` v2: dedup check returns `{error:'already_flagged'}`, priority auto-escalates to 'high' at 3+ flags, returns `jsonb`, preserves creator + admin notifications, fixes flashcard lookup (user_id direct, not deck_id join)
- **Supabase** — `get_my_content_flags()` SECURITY DEFINER: returns pending content_error flags on professor's own notes/flashcards with flag_count window function
- **Supabase** — `get_admin_flags(p_status)` SECURITY DEFINER: returns all flags filtered by status with flagged_by name, creator name, flag_count
- **Supabase** — `resolve_content_flag(p_flag_id, p_action, p_resolution_note)`: sets status (resolved/rejected/removed), resolved_by, resolved_at
- **`src/data/helpContent.js`** — `flagging-content` section in Content tab (student-visible); `prof-needs-attention` section in For Professors tab; `admin-flagged-content` section in For Admins tab

### Changed
- **`src/components/ui/FlagButton.jsx`** — Details Textarea added; SelectItem values fixed to `content_error`/`inappropriate`/`other`; `already_flagged` toast handling; `p_details` passed to RPC; details reset on close
- **`src/pages/Dashboard.jsx`** — Professor: Needs Attention card wired to `get_my_content_flags` (live flag list with Review buttons); Admin/super_admin: Needs Review card wired to pending flag count + navigate to `/admin`; `AlertTriangle` added to imports
- **`src/pages/admin/AdminDashboard.jsx`** — Flagged Content section added at top of Content tab; status filter dropdown; Dismiss and Remove actions; `AlertTriangle` added to imports; `fetchFlaggedContent` added to `fetchAll`
- **`src/pages/dashboard/Help.jsx`** — `Flag` and `AlertTriangle` added to lucide-react imports and ICON_MAP

### Files Changed
`src/components/ui/FlagButton.jsx`, `src/pages/Dashboard.jsx`, `src/pages/admin/AdminDashboard.jsx`, `src/data/helpContent.js`, `src/pages/dashboard/Help.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`

---
## [2026-03-21] feat: Sprint 2.8-A — public note sharing + WhatsApp OG previews

### Added
- **Supabase** — `get_public_note_preview(p_note_id uuid)` SECURITY DEFINER RPC; returns note metadata only when `visibility = 'public'`; joins profiles, subjects, topics; safe for anonymous callers
- **`src/pages/public/NotePreview.jsx`** — new public page at `/note/:noteId`; fetches via RPC (anon-safe); subject/topic pills, blurred content preview, auth-aware CTA with `postAuthRedirect`
- **`src/App.jsx`** — lazy import + `/note/:noteId` public route
- **`src/data/helpContent.js`** — `sharing-whatsapp` section added to Social tab (all roles): steps for sharing notes and decks via WhatsApp

### Changed
- **`middleware.js`** — `NOTE_PATH` regex + `noteMatch`; guard updated to include noteMatch; `/note/:path*` added to matcher config; note OG handler fetches `get_public_note_preview` and returns title/description HTML for bots
- **`src/pages/dashboard/Content/NoteDetail.jsx`** — `Share2` added to lucide-react import; `handleShare()` added (Web Share API + WhatsApp fallback); Share button rendered when `note.visibility === 'public'`
- **`src/data/helpContent.js`** — `prof-share-content` section in For Professors tab rewritten with specific WhatsApp sharing steps and tip

### Files Changed
`middleware.js`, `src/pages/public/NotePreview.jsx`, `src/App.jsx`, `src/pages/dashboard/Content/NoteDetail.jsx`, `src/data/helpContent.js`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-03-21] feat: Sprint 2.7-B — role-based Help section (professor and admin tabs)

### Added
- **`src/data/helpContent.js`** — `prof-bulk-csv` section (professor-only) in Content tab
- **`src/data/helpContent.js`** — "For Professors" tab (`roles: ['professor']`) with 5 sections: Welcome, Profile Setup, Analytics Dashboard, Batch Groups, Sharing Content Publicly
- **`src/data/helpContent.js`** — "For Admins" tab (`roles: ['admin', 'super_admin']`) with 7 sections (3 are `super_admin`-only): Dashboard Overview, Access Requests, Batch Groups, Bulk Topics, Admin Analytics, User Roles (SA), Hard Delete (SA), SA Analytics (SA)
- **`src/pages/dashboard/Help.jsx`** — `useRole` import; `visibleTabs` useMemo filtering tabs and sections by role

### Changed
- **`src/pages/dashboard/Help.jsx`** — All 4 logical `HELP_TABS` references replaced with `visibleTabs`; `GraduationCap` and `Shield` added to lucide-react import and ICON_MAP; `searchResults` dependency array includes `visibleTabs`

### Files Changed
`src/data/helpContent.js`, `src/pages/dashboard/Help.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-21] feat: Sprint 2.7-A — admin and super_admin role dashboards + visible placeholders

### Added
- **`src/pages/Dashboard.jsx`** — Admin view: 3 navigation cards (Admin Dashboard, Admin Analytics, Manage Topics) + Needs Review placeholder + Activity Feed
- **`src/pages/Dashboard.jsx`** — Super Admin view: same 3 admin cards + elevated SA section (red border, "Elevated" badge) with SA Dashboard and SA Analytics cards + Needs Review placeholder + Activity Feed
- **`src/pages/Dashboard.jsx`** — imports for `Shield`, `BarChart3`, `Users`, `Flag` icons

### Changed
- **`src/pages/Dashboard.jsx`** — role conditional extended from 2-way (professor/student) to 4-way (professor/admin/super_admin/student)
- **`src/pages/Dashboard.jsx`** — Professor "Needs Attention" changed from commented-out code to a visible amber placeholder card

### Files Changed
`src/pages/Dashboard.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-21] feat: Sprint 2.6 — nav consolidation, professor dashboard, educator RLS fix, dynamic motivation tips

### Added
- **`src/components/layout/NavDesktop.jsx`** — `isManageActive()` helper for active state on `/admin` and `/super-admin` routes
- **`src/pages/Dashboard.jsx`** — `userRole` state; professor-conditional dashboard render with content summary, quick actions, and activity feed
- **Supabase** — `get_public_educators()` SECURITY DEFINER function deployed; returns top 3 professor profiles for unauthenticated landing page access

### Changed
- **`src/components/layout/NavDesktop.jsx`** — 5 standalone admin/super_admin nav links collapsed into single "Manage ▾" dropdown (Admin Dashboard, Admin Analytics, Manage Topics, Super Admin, SA Analytics)
- **`src/pages/Dashboard.jsx`** — `profile.role` now stored in state via `setUserRole`; professor role gets dedicated dashboard UI instead of student stats
- **`src/components/dashboard/AnonymousStats.jsx`** — `getComparisonMessage()` rewritten with 4 context-aware states; zero-state shows dynamic message; Class Milestones footer is context-aware based on whether student studied today
- **`src/pages/Home.jsx`** — educator fetch replaced from direct `.from('profiles')` (silently RLS-blocked for anonymous users) to `.rpc('get_public_educators')`; educator names now correctly appear on landing page

### Files Changed
`src/components/layout/NavDesktop.jsx`, `src/pages/Dashboard.jsx`, `src/components/dashboard/AnonymousStats.jsx`, `src/pages/Home.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-21] fix: hero gradient swap — brand name Recall gets gradient, tagline goes solid dark

### Changed
- **`src/pages/Home.jsx`** — swapped colour treatment in hero: `h1 "Recall"` now has `bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent`; tagline "The Revision Operating System." now `text-gray-900 font-bold` (solid dark). Deliberate branding decision: gradient = attention magnet, must land on brand name first, not the tagline. Do NOT revert.

### Files Changed
`src/pages/Home.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/active/context.md`

---
## [2026-03-20] feat: Sprint 2.5 + refinements — Landing page redesign: The Revision Operating System

### Changed
- **`src/pages/Home.jsx`** (Sprint 2.5) — complete copy and structure overhaul; hero headline/subheadline/pills updated; dual CTA replaces single button; How It Works reordered (Review First, Upload, Create, Daily Review); Features reordered (SM-2 first) with updated copy; Educator Content repositioned as institute pitch; For Educators renamed to For Institutes & Educators with all 4 bullets rewritten; Final CTA heading/body/buttons updated; footer tagline updated; all 7 email occurrences replaced with hello@recallapp.co.in
- **`src/pages/Home.jsx`** (refinements) — B2C/B2B CTA hierarchy fixed (Start free primary, institute CTA text link below stats with divider); stat labels clarified (Flashcards/Notes); blue section reframed as browseable library; For Institutes right panel replaced with benefit statements; hero branding fixed (Recall as h1, tagline as subtitle); step 1 heading shortened + made B2C-agnostic; step 4 heading shortened to "Never Forget Again"

### Files Changed
`src/pages/Home.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-20] feat: Sprint 2.4 — middleware /join OG tags + AuthContext signup cleanup

### Changed
- **`middleware.js`** — extended to handle `/join/:token` in addition to `/deck/:deckId`; config.matcher now covers both routes; join handler calls `get_group_preview` RPC and builds OG tags from `group.name`, `group.member_count`, `stats.total_weekly_reviews`; shared `buildOgResponse()` helper extracted; all deck logic, bot detection, and cache headers unchanged
- **`AuthContext.jsx`** — removed redundant client-side `profiles` INSERT from `signUp()`; removed 100ms delay that preceded it; profile creation is now handled exclusively by `trg_create_profile_on_signup` DB trigger

### Fixed
- **AuthContext signUp 401** — client-side `profiles.insert()` always failed during email-confirmation flow because `signUp()` returns a user object but no session; `auth.uid()` is null so RLS silently blocked the insert; new users sometimes had no profile row depending on timing

### SQL Deployed
- `fn_create_profile_on_signup` + `trg_create_profile_on_signup` — SECURITY DEFINER trigger on `auth.users` INSERT; reads `full_name` and `course_level` from `raw_user_meta_data`; timezone defaults to `Asia/Kolkata` and is synced on first login by `updateUserTimezone()`

### Files Changed
`middleware.js`, `src/contexts/AuthContext.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`

---
## [2026-03-19f] feat: Sprint 2.3 — group invite links, auto-batch trigger, group types

### Added
- **`study_groups.invite_token`** — uuid, gen_random_uuid(); used in `/join/:token` public URL
- **`study_groups.group_type`** — text CHECK ('batch'|'system_course'|'custom'); backfilled 'batch' for existing batch groups
- **`study_groups.linked_course`** — nullable text; stores enrolled course for 'system_course' groups
- **`create_study_group` RPC** — updated signature: `p_group_type` and `p_linked_course` params
- **`CreateGroup.jsx`** — group type selector card: fetches user's `course_level`, radio options for system course vs custom; passes new params to RPC
- **`fn_auto_enroll_batch_group` trigger** — fixed 3 bugs: role exclusion, account_type exclusion, institution matching

### Changed
- **`get_group_preview` RPC** — removed `is_batch_group = false` filter; fixed broken `p.current_streak` ref (column doesn't exist); fixed `badges` → `badge_definitions` table name
- **`join_group_by_token` RPC** — removed `is_batch_group = false` filter; batch group invite links now work
- **`GroupJoin.jsx`** — postAuthRedirect: replaced URL params with `localStorage` pattern
- **`Login.jsx`** — postAuthRedirect: reads+removes localStorage BEFORE `signIn()` to prevent AppContent useEffect race condition; navigates to redirect or `/dashboard`; restores key on error
- **`App.jsx`** — added AppContent `useEffect` for email-confirmation postAuthRedirect path

### Fixed
- **Group join links returning "not found" for batch groups** — `get_group_preview` and `join_group_by_token` both had `AND is_batch_group = false`; removed
- **postAuthRedirect race condition** — Supabase `onAuthStateChange` fires synchronously inside `signIn()` before the Promise resolves; AppContent useEffect was consuming `localStorage` before Login.jsx could read it; fixed by capturing the value before `signIn()`

### Files Changed
`src/pages/auth/Login.jsx`, `src/App.jsx`, `src/pages/public/GroupJoin.jsx`, `src/pages/dashboard/Groups/CreateGroup.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/reference/DATABASE_SCHEMA.md`

---
## [2026-03-19e] feat: postAuthRedirect — login after DeckPreview share deep-links to target deck

### Added
- **`Login.jsx`** — reads `localStorage.getItem('postAuthRedirect')` after successful `signIn`; clears key; navigates to stored URL or `/dashboard` as fallback; enables the WhatsApp share → signup → study session flow end-to-end

### Changed
- **`DeckPreview.jsx`** (already in 2026-03-19d) — "Sign up free" and "Sign in" links set `localStorage.postAuthRedirect` to `/dashboard/review-flashcards?deck=:deckId` on click

### User Flow
WhatsApp share link → DeckPreview (anonymous) → "Sign up free" → localStorage stores redirect → signup → email confirm → login → Login.jsx reads redirect → ReviewFlashcards auto-launches study session for that deck

### Files Changed
`src/pages/auth/Login.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-03-19d] feat: DeckPreview deep-link — logged-in users go directly to study session

### Changed
- **`DeckPreview.jsx`** — logged-in user CTA changed from "Study All Sets on Recall" (generic) to "Study this set on Recall" (deep-linked); navigates to `/dashboard/review-flashcards?deck=:deckId`
- **`ReviewFlashcards.jsx`** — reads `?deck=:deckId` query param; once decks are loaded, auto-launches `startStudySession` for the matching deck; falls through silently if deck is not accessible (private/wrong course); `targetDeckId` const extracted from `searchParams`

---
## [2026-03-19c] fix: Public deck preview + groups course filter + DeckPreview CTA redesign

### Changed
- **`DeckPreview.jsx`** — removed `ContentPreviewWall` (WhatsApp lead capture); anonymous visitors shown "Sign up free" CTA instead; CTA copy does not promise full card access (would be misleading for professor decks where Tier B students only get 10-card preview); `showWall` state removed; `ContentPreviewWall` import removed
- **`CLAUDE.md`** — added critical database rule: `deck_id` on `flashcards` is never populated; always join on 5 grouping columns `(user_id, subject_id, topic_id, custom_subject, custom_topic)` to fetch flashcards for a deck
- **`DATABASE_SCHEMA.md`** — added explicit warning + exact join SQL pattern in flashcard_decks section; documents that `deck_id` FK exists but is never set, and that `batch_id` is for client-side upload grouping only — not a deck FK

### Fixed
- **Groups page — professor course switching** — `get_my_batch_groups` professor path previously returned only the primary course's batch group (likely filtered by `batch_course IN (teaching courses)` which had a matching issue); rebuilt to return ALL batch groups for professors; client-side `activeCourse` filter in `MyGroups.jsx` correctly handles per-course display
- **DeckPreview showing 0 of N items** — `get_public_deck_preview` fetched preview flashcards via `WHERE deck_id = p_deck_id` which always returns 0 rows because `deck_id` on `flashcards` is never populated; fixed to join on the 5 grouping columns that `update_deck_card_count` trigger uses; root cause documented in CLAUDE.md and DATABASE_SCHEMA.md to prevent recurrence

### SQL Deployed
- `DROP FUNCTION IF EXISTS get_my_batch_groups()` + rebuilt (return type changed)
- `CREATE OR REPLACE FUNCTION get_public_deck_preview(p_deck_id uuid)` — fixed flashcard join logic

### Files Changed
`src/pages/public/DeckPreview.jsx`, `CLAUDE.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`

---
## [2026-03-19b] fix: Admin role management + batch group enrolment + super admin delete

### Added
- **`admin_delete_user_data(p_user_id uuid)` RPC** — SECURITY DEFINER; super_admin-only; deletes study_group_members, profile_courses, reviews, flashcards, flashcard_decks, notes, profiles in correct cascade order; bypasses RLS which was silently blocking client-side profile deletion
- **`remove_group_member` SQL function** — allows group admin to remove a member from a group via GroupDetail UI
- **CA Foundation batch group** — created by super_admin; all enrolled Foundation students bulk-enrolled
- **CA Intermediate batch group** — created by admin; all enrolled Intermediate students bulk-enrolled

### Changed
- **`SuperAdminDashboard.jsx` — `deleteUser`** — replaced direct `.delete()` cascade (silently failed due to RLS) with `rpc('admin_delete_user_data')`; profile deletion now works correctly; success alert simplified; manual auth record deletion step retained (requires service role)
- **`Dashboard.jsx`** — profile completion modal now skipped for admin/super_admin roles; `role` field added to profile fetch; `isAdminRole` check prevents modal loop after `course_level` was nulled for those accounts
- **`MyGroups.jsx`** — `fetchGroups` now calls `get_user_groups` and `get_my_batch_groups` in parallel; results merged with deduplication by ID; `useEffect` dependency simplified to `[]`; activeCourse filter preserved for student batch groups; server-side role resolution in `get_my_batch_groups` eliminates all frontend timing issues with `isAdmin`/`isSuperAdmin`

### Fixed
- **Groups page blank for admin/super_admin** — admin/super_admin accounts had leftover `profile_courses` entries from when they were students; CourseContext set `activeCourse` from those entries → MyGroups filter hid all batch groups not matching that course; fixed by deleting `profile_courses` for admin/super_admin (SQL) → `activeCourse` falls back to null → no filter applied → all batch groups visible
- **Super admin hard delete silently failing** — `deleteUser` called direct `.delete()` on profiles which RLS blocked silently; profile was never deleted; going to Supabase Auth dashboard to delete auth user then failed due to FK constraint from profiles; fixed via `admin_delete_user_data` SECURITY DEFINER RPC
- **Audit log blocking profile deletion** — `admin_audit_log.target_user_id` FK was `NO ACTION`; retained audit log entries prevented profile deletion; fixed by altering FK to `ON DELETE SET NULL` — audit records are kept with `target_user_id = null` and user details preserved in `details` JSONB

### SQL Deployed
- `DELETE FROM profile_courses WHERE user_id IN (SELECT id FROM profiles WHERE role IN ('admin', 'super_admin'))`
- `UPDATE profiles SET course_level = NULL WHERE role IN ('admin', 'super_admin')`
- `ALTER TABLE admin_audit_log DROP CONSTRAINT admin_audit_log_target_user_id_fkey`
- `ALTER TABLE admin_audit_log ADD CONSTRAINT admin_audit_log_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES profiles(id) ON DELETE SET NULL`
- `CREATE OR REPLACE FUNCTION admin_delete_user_data(p_user_id uuid)` — SECURITY DEFINER cascade delete
- `CREATE OR REPLACE FUNCTION remove_group_member(...)` — group admin member removal
- Bulk enrolment: `INSERT INTO study_group_members ... WHERE p.course_level = sg.batch_course AND sg.batch_course IN ('CA Foundation', 'CA Intermediate')`

### Files Changed
`src/pages/admin/SuperAdminDashboard.jsx`, `src/pages/Dashboard.jsx`, `src/pages/dashboard/Groups/MyGroups.jsx`

---
## [2026-03-19] fix: Sprint 2 QA — bug fixes + batch group institution isolation

### Added
- **`profiles.status`** (new column) — `TEXT NOT NULL DEFAULT 'active'` with CHECK `('active','suspended')`; required for User Management tab to load
- **`profiles.has_seen_onboarding`** (new column) — `BOOLEAN NOT NULL DEFAULT false`; controls first-login OnboardingModal display
- **`access_requests.email`** (new column) — `TEXT`; enables admin to match access requests to signed-up profiles by email; Grant Access button shown in Access Requests tab
- **`study_groups.batch_institution`** (new column) — `TEXT`; isolates batch groups per institution so multiple B2B clients don't share a group
- **`handle_new_user()` trigger** — `SECURITY DEFINER` trigger on `auth.users` AFTER INSERT; creates profile from `raw_user_meta_data`; permanent fix for profile creation failing when email confirmation is ON (RLS blocks client-side insert when session is null)
- **`enroll_user_in_batch_group(p_user_id uuid)` RPC** — called on Grant Access; adds newly enrolled student to batch group matching their `course_level` + `institution`
- **`AdminDashboard.jsx` — Access Requests "Account" column** — matches requests to profiles by email; shows "Grant Access" / "Enrolled ✓" / "Not signed up"

### Changed
- **`submit_access_request` RPC** — rebuilt with `email` parameter; fixed missing DEFAULT on `status` and `requested_at` (INSERT was failing with HTTP 400)
- **`create_batch_group` RPC** — now accepts `p_institution`; auto-enrolls enrolled students matching course + institution (not course alone)
- **`notify_access_request` function** — fixed WHERE clause: `account_type IN ('admin','super_admin')` → `role IN ('admin','super_admin')` (admins were not receiving notifications)
- **`notifications_type_check` constraint** — added `'access_request'` to allowed types
- **`AdminDashboard.jsx` — `grantAccess`** — now calls `enroll_user_in_batch_group` after setting `account_type = 'enrolled'`
- **`AdminDashboard.jsx` — Create Batch form** — Course Level and Institution changed from free-text inputs to dropdowns; Course populated from `disciplines` table; Institution populated from distinct `profiles.institution` values; `fetchBatchFormOptions()` loads both lists lazily when Batch Groups tab is opened; prevents data integrity issues from typos/mismatches
- **`DeckPreview.jsx`** — `contentType` changed `'deck'` → `'flashcard_deck'` (was violating `access_requests.content_type` CHECK constraint)

### Fixed
- **ContentPreviewWall form — HTTP 400 (missing DEFAULTs)** — `access_requests.status` and `requested_at` had no DEFAULT; INSERT from RPC failed
- **ContentPreviewWall form — HTTP 400 (anon permissions)** — `anon` role lacked EXECUTE on `submit_access_request`, `get_public_deck_preview`, `get_group_preview`, `join_group_by_token`
- **Access request notifications not delivered** — `notify_access_request` was filtering by `account_type` instead of `role`; all admin/super_admin profiles have `account_type = 'enrolled'`, not `'admin'`
- **User Management empty list** — `fetchUsers` selected `status` column which didn't exist; Supabase returned error caught silently
- **9 orphaned accounts** — auth users existed but profiles were never created; root cause: `signUp()` with email confirmation ON returns no session → `auth.uid() = null` → profile INSERT blocked by RLS silently; fixed permanently via `handle_new_user` trigger; bulk backfill run for existing 9 orphaned accounts
- **Blank Course dropdown** — `ReviewFlashcards.jsx` + `BrowseNotes.jsx` showed blank selected value for users enrolled in a course with no content yet
- **Access Requests date "Invalid Date"** — query was selecting `created_at` (doesn't exist); correct column is `requested_at`

### SQL Deployed
- `ALTER TABLE access_requests ALTER COLUMN status SET DEFAULT 'pending', ALTER COLUMN requested_at SET DEFAULT now()`
- `ALTER TABLE access_requests ADD COLUMN IF NOT EXISTS email text`
- `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended'))`
- `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS has_seen_onboarding BOOLEAN NOT NULL DEFAULT false`
- `ALTER TABLE study_groups ADD COLUMN IF NOT EXISTS batch_institution TEXT`
- `UPDATE study_groups SET batch_institution = 'More Classes Commerce' WHERE is_batch_group = true`
- `UPDATE profiles SET institution = 'More Classes Commerce' WHERE account_type = 'enrolled' AND (institution IS NULL OR institution = '')`
- `GRANT EXECUTE ON FUNCTION submit_access_request(...) TO anon` + `TO authenticated`
- `GRANT EXECUTE ON FUNCTION get_public_deck_preview(uuid), get_group_preview(uuid), join_group_by_token(uuid) TO anon`
- Rebuilt `notifications_type_check` constraint (added `'access_request'`)
- Rebuilt `submit_access_request` RPC with email param
- Rebuilt `create_batch_group` RPC with institution param
- Created `enroll_user_in_batch_group` RPC
- Created `handle_new_user()` trigger on `auth.users`
- Bulk backfill: 9 orphaned profiles inserted from `auth.users`

### Files Changed
`src/pages/admin/AdminDashboard.jsx`, `src/pages/public/DeckPreview.jsx`, `src/pages/dashboard/Study/ReviewFlashcards.jsx`, `src/pages/dashboard/Content/BrowseNotes.jsx`

---
## [2026-03-18] feat: Sprint 2 — Batch groups, WhatsApp invite links, public deck preview, onboarding modal

### Added
- **`src/pages/public/GroupJoin.jsx`** (new) — Public `/join/:token` page; shows group preview stats via `get_group_preview` RPC; logged-in users can join via `join_group_by_token` RPC; logged-out users see sign-in CTA
- **`src/pages/public/DeckPreview.jsx`** (new) — Public `/deck/:deckId` page; shows deck metadata + first 5 questions via `get_public_deck_preview` RPC; ContentPreviewWall after preview for non-members
- **`src/components/dashboard/OnboardingModal.jsx`** (new) — 3-step onboarding modal (batch groups → create group → share study set); triggered on Dashboard when `has_seen_onboarding = false`; dismissal sets flag in DB
- **`middleware.js`** (new, project root) — Vercel Edge Middleware; intercepts bot requests to `/deck/:deckId`; injects OG meta tags from `get_public_deck_preview`; `Cache-Control: public, s-maxage=86400, stale-while-revalidate=43200`
- **Admin Dashboard — Batch Groups tab** — lists existing batch groups per course; create form (course level, name, description) calls `create_batch_group` RPC; backfills all matching students

### Changed
- **`MyGroups.jsx`** — Batch groups shown with "Official" badge (Shield icon, blue) + course label; Leave/Delete buttons hidden for batch groups; batch groups sorted to top by RPC
- **`GroupDetail.jsx`** — Added WhatsApp invite link section inside Members panel (Copy Link + WhatsApp share button) for admins of self-selected groups; hidden for batch groups
- **`ReviewFlashcards.jsx`** — Share button (Share2 icon) on public deck tiles; Web Share API primary, `wa.me` fallback with pre-filled message
- **`Dashboard.jsx`** — Profile fetch now includes `has_seen_onboarding`; shows OnboardingModal when profile is complete but onboarding not seen
- **`ContentPreviewWall.jsx`** — Fixed anon-insert RLS bug: replaced direct `.from('access_requests').insert()` with `.rpc('submit_access_request', {...})` SECURITY DEFINER call
- **`App.jsx`** — Added public routes `/join/:token` (GroupJoin) and `/deck/:deckId` (DeckPreview) without auth guard

### Files Changed
`src/pages/dashboard/Groups/MyGroups.jsx`, `src/pages/admin/AdminDashboard.jsx`, `src/pages/dashboard/Groups/GroupDetail.jsx`, `src/pages/public/GroupJoin.jsx` (new), `src/pages/public/DeckPreview.jsx` (new), `src/components/dashboard/OnboardingModal.jsx` (new), `src/App.jsx`, `src/pages/dashboard/Study/ReviewFlashcards.jsx`, `src/components/ui/ContentPreviewWall.jsx`, `src/pages/Dashboard.jsx`, `middleware.js` (new)

---
## [2026-03-17] feat: Sprint 7 — Content access tiers, flagging, lead capture + preview bug fixes

### Added
- **`ContentPreviewWall.jsx`** (new) — WhatsApp lead capture form (name/WhatsApp/course) shown to Tier B users after 10-card preview or on professor note detail. Submits to `access_requests` table.
- **`FlagButton.jsx`** (new) — "Report" button with reason select (Content error / Inappropriate / Other); calls `submit_content_flag` RPC. Shown on note tiles, note detail, and flashcard study view (non-owner only).
- **Admin Dashboard — "Access Requests" tab** — table with Name, WhatsApp, Course, Content Seen, Date, Status; inline status dropdown (pending/contacted/enrolled/dismissed).
- **Admin nav link** — "Admin" link to `/admin` added to NavDesktop and "Dashboard" button added to NavMobile admin section.

### Changed
- **`ReviewFlashcards.jsx`** — Tier B users see "Preview: first 10 of N items" on professor deck tiles; `startStudySession` passes `previewMode=true` and `totalCards=N` URL params for professor content.
- **`StudyMode.jsx`** — Preview mode: slices cards to 10, shows proportional progress bar (10/total fills purple, remainder grey), amber banner "PREVIEW MODE — first 10 of N items"; `handleRating` and `advanceOrFinish` now set `currentIndex = flashcards.length` on last preview card (triggers ContentPreviewWall) instead of calling `onExit`.
- **`NoteDetail.jsx`** — Tier B viewers of professor notes see ContentPreviewWall instead of note image/text/flashcards; FlagButton shown for non-owners.
- **`BrowseNotes.jsx`** — FlagButton added to non-owner note tiles.
- **`AdminDashboard.jsx`** — `fetchStats` now uses `get_platform_stats` SECURITY DEFINER RPC (fixes undercounting vs landing page); users table shows Tier A/B badges; Access Requests tab added.

### Fixed
- **Admin stat cards** showed ~1000 flashcards vs landing page 1913 — RLS was filtering direct table queries even for admins. Fixed by routing through `get_platform_stats` RPC.
- **Preview deck tile** showed "Preview only (first 10 items)" with no total — now shows "Preview: first 10 of N items".
- **Preview progress bar** filled 100% at card 10 — now fills proportionally (e.g. 22% for a 45-card deck) using `totalCards` URL param as denominator.
- **ContentPreviewWall never appeared** after 10 preview cards — `handleRating` was calling `onExit()` on last card, navigating away before `isComplete` could render the wall. Fixed in both `handleRating` and `advanceOrFinish`.

### Files Changed
- `src/pages/dashboard/Study/StudyMode.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Content/NoteDetail.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`
- `src/pages/admin/AdminDashboard.jsx`
- `src/components/ui/ContentPreviewWall.jsx` (new)
- `src/components/ui/FlagButton.jsx` (new)
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`
- `docs/active/now.md`
- `docs/tracking/changelog.md`

---
## [2026-03-17] feat: Sprint 6 — Data contract UI enforcement + schema documentation

### Added
- **`isSystemCourse` derived boolean** in `FlashcardCreate.jsx` — computed from `disciplines` state, no new React state.
- **System course path:** FK subject combobox (no "Add custom subject" option) + FK topic combobox. Helper text below subject with "Switch to custom course →" escape hatch.
- **Custom course path:** Plain text inputs for subject (required) and topic (optional, labeled "Topic (Optional)" per QA review).
- **Defense-in-depth submit logic:** `handleSubmit` explicitly nulls out the opposite field type on each path — system course clears `customSubject`/`customTopic`; custom course clears `subjectId`/`topicId`.
- **10 undocumented flashcards columns documented** in `DATABASE_SCHEMA.md`: `custom_subject`, `custom_topic`, `question_type`, `options`, `correct_answer`, `hints`, `points_to_remember`, `scenario`, `subtype`, `source`.
- **Concept Card exclusion rule** added to `DATABASE_SCHEMA.md`.
- **3 SQL backfill scripts** provided for existing dirty data (user-deployed): diagnostic + fix + manual-review-needed.

### Changed
- **`fetchAllCourses()` removed** — was downloading all rows from notes, flashcards, and profiles for client-side dedup. Course dropdown now reads from `disciplines` (already loaded by `fetchDisciplines()`).
- **`allCourses` state removed** — no longer needed.
- **targetCourse `useEffect`** now also resets `showCustomSubject`, `customSubject`, `showCustomTopic`, `customTopic` when course changes.
- **`DATABASE_SCHEMA.md` flashcards table**: column count 24 → 34, last updated date updated to 2026-03-17.

### Files Changed
- `src/pages/dashboard/Content/FlashcardCreate.jsx`
- `docs/reference/DATABASE_SCHEMA.md`
- `docs/active/now.md`
- `docs/tracking/changelog.md`

---
## [2026-03-17] fix: Remove duplicate Admin Activity Feed from SuperAdminAnalytics

### Changed
- **`SuperAdminAnalytics.jsx`** — removed Section 5 (Admin Activity Feed). Full audit log already exists as a dedicated tab in `SuperAdminDashboard.jsx`. Analytics page is now pure strategic insight (cohort health, creator growth, platform heatmap). Removed `fetchActivityFeed()`, `activityFeed`/`activityError` state, and `Activity` icon import.

### Files Changed
- `src/pages/admin/SuperAdminAnalytics.jsx`

---
## [2026-03-16] feat: Sprint 5 — Super Admin Analytics page + SuperAdminDashboard tab fix

### Added
- **`SuperAdminAnalytics.jsx`** — new page at `/super-admin/analytics` (super_admin only). 5 sections: header stat strip (4 cards), course cohort comparison table (sortable, amber rows for zero-review courses), creator leaderboard (top 20, Professor vs Student Contributor badges), 52-week platform activity heatmap, admin activity feed (last 20 audit log entries with JS-side attribution).
- **`PlatformHeatmap.jsx`** — 52-week platform-wide heatmap component. Blue color scale. Separate from student `StudyHeatmap.jsx` (13-week, green). Fetches `get_platform_heatmap` RPC internally.
- **4 Supabase RPCs:** `get_super_admin_header_stats`, `get_super_admin_cohort_comparison`, `get_creator_leaderboard`, `get_platform_heatmap(INT)`. All `LANGUAGE sql` (avoids 42702 plpgsql column ambiguity with RETURNS TABLE names).
- **Route `/super-admin/analytics`** added to `App.jsx`.
- **Nav links** — "SA Analytics" added for `isSuperAdmin` in `NavDesktop.jsx` and `NavMobile.jsx`.

### Fixed
- **`SuperAdminDashboard.jsx` broken tabs** — `<Tabs>` from `tabs.jsx` stub had no state, both panels always rendered, clicks did nothing. Replaced with `const [dashboardTab, setDashboardTab] = useState('users')` + `TabButton` component + conditional rendering. `scrollToUserManagement()` now calls `setDashboardTab('users')` directly instead of `document.querySelector('[value="users"]').click()`.

### Files Changed
- `src/pages/admin/SuperAdminAnalytics.jsx` (new)
- `src/components/progress/PlatformHeatmap.jsx` (new)
- `src/pages/admin/SuperAdminDashboard.jsx`
- `src/App.jsx`
- `src/components/layout/NavDesktop.jsx`
- `src/components/layout/NavMobile.jsx`

---
## [2026-03-15] fix: NoteDetail back button returns to Admin Dashboard when opened from /admin

### Fixed
- **Back button on NoteDetail went to `/dashboard` instead of `/admin`** — note links in AdminDashboard open in a new tab (`target="_blank"`), so `window.history.length` is always 1 in that tab. The `navigate(-1)` branch never ran; the hardcoded `/dashboard` fallback always fired.

### Changed
- **`AdminDashboard.jsx`** — note title `href` updated to `/dashboard/notes/:id?ref=admin`
- **`NoteDetail.jsx`** — reads `?ref` search param via `useSearchParams`; if `ref=admin`, back button navigates to `/admin`. Falls back to `navigate(-1)` → `/dashboard` for all other entry points (unchanged behaviour).

### Files Changed
- `src/pages/admin/AdminDashboard.jsx`
- `src/pages/dashboard/Content/NoteDetail.jsx`

---
## [2026-03-15] fix: Deck auto-naming — bulk upload sets name, historical data backfilled

### Fixed
- **Bulk-uploaded flashcard decks showing as untitled** — `flashcard_decks.name` is never set by the `update_deck_card_count` trigger that auto-creates deck rows. Admins could not identify decks in AdminDashboard without an inline preview.
- **AdminDashboard preview broken** — `togglePreview` was querying `flashcards` with `.eq('deck_id', deckId)` but `flashcards` has no `deck_id` column. Preview always returned 0 cards.

### Changed
- **`BulkUploadFlashcards.jsx`** — during upload, collects unique (subject_id, topic_id) groups from the validated card set; after flashcards are inserted (trigger creates decks), runs `UPDATE flashcard_decks SET name = [derived] WHERE name IS NULL` per group. Name = user's batch label if provided, else `Subject — Topic` or `Subject`.
- **`AdminDashboard.jsx`** — deck select now fetches `subject_id, topic_id, custom_subject, custom_topic` needed for preview; `togglePreview` now builds query using deck's `(user_id, subject_id, topic_id, custom_subject, custom_topic)` attributes with null-safe `.is()` calls.

### SQL Deployed
- `[DATA] Backfill flashcard_decks.name from first card subject/topic` — one-time UPDATE using subquery on flashcards → subjects/topics JOIN with `COALESCE` for custom fields; `IS NOT DISTINCT FROM` for null-safe matching; only touches rows where `name IS NULL OR name = ''`.

### Files Changed
- `src/pages/dashboard/BulkUploadFlashcards.jsx`
- `src/pages/admin/AdminDashboard.jsx`

---
## [2026-03-15] feat: Sprint 4 — Admin Analytics page

### Added
- **`/admin/analytics`** — new page for **admin and super_admin** roles with platform-wide health metrics
- **4-card overview stat strip** — Total Users, Active This Week, Pending Review (amber highlight when > 0), Published Items
- **Content Health by Course table** — per-discipline: published item count, verified count, pending note review queue, avg student quality score; sortable by any column; red row highlight when pending notes > 0, amber when avg quality < 3; red AlertCircle icon on rows with pending reviews
- **Student Onboarding section** — 5 funnel cards: New This Week, Never Studied (amber border when > 0), Review Coverage %, Total Students, Incomplete Profiles (amber border when > 0)
- **Weekly Platform Reviews bar chart** — Recharts `BarChart`; 8-week Monday-anchored rolling window; `generate_series` date spine guarantees zero weeks show; custom tooltip; timezone-safe week labels (string-split, no Date constructor)
- **4 Supabase RPCs deployed:** `get_admin_platform_overview`, `get_content_health_stats`, `get_user_onboarding_stats`, `get_weekly_platform_reviews`
- **NavDesktop** — Analytics link (BarChart3 icon) for `isAdmin || isSuperAdmin`, below professor Analytics link
- **NavMobile** — "Admin" section in hamburger sheet with Analytics + Manage Topics buttons

### Files Changed
- `src/pages/admin/AdminAnalytics.jsx` *(new)*
- `src/App.jsx` — lazy import + `/admin/analytics` route
- `src/components/layout/NavDesktop.jsx` — Admin Analytics nav link
- `src/components/layout/NavMobile.jsx` — Admin section with Analytics button

---
## [2026-03-15] fix: Progress page cross-course bleed on All My Content tab

### Fixed
- **Cross-course subject bleed on "All My Content" tab** — students enrolled in one course (e.g. CA Intermediate) were seeing subjects from unrelated courses (e.g. Business Laws from CA Foundation). Root cause: `courseLevel={null}` was passed to `get_subject_mastery_v1` and `get_question_type_performance`, returning all public cards system-wide.

### Changed
- **`allTabCourseLevel` derived value** — for users with exactly 1 enrolled course, "All My Content" now scopes to that course. Professors with multiple teaching courses continue to see combined view (`null`). No SQL changes.

### Files Changed
- `src/pages/dashboard/Study/Progress.jsx`

---
## [2026-03-14] feat: Sprint 3 — Professor Analytics page

### Added
- **`/dashboard/professor-analytics`** — new page for **professors only** to see content engagement data (admins/super_admins have their own dedicated dashboards)
- **4-card stat strip** — Cards Published, Students Reached, Total Reviews, Avg Quality (all server-side via RPCs)
- **Course selector pills** — visible when professor has 2+ courses via `profile_courses`; all 5 RPCs re-fetch on course change
- **Subject Engagement table** — sortable by any column (client-side); amber row highlight for avg quality < 3; AlertTriangle icon on struggling subjects
- **Weak Cards panel** — bottom 10 cards by avg quality, min 3 reviews noise filter, Copy ID button with toast
- **Top Cards panel** — top 10 cards by total review count, shows avg quality alongside
- **Weekly Reach bar chart** — Recharts `BarChart` with custom tooltip; 8 Monday-anchored weeks; "new students" = first-time reviewers only; guaranteed 8-bar spine via SQL `generate_series`
- **Two-tier empty states** — (1) zero cards published → Bulk Upload prompt; (2) cards exist but zero reviews → amber notice; engagement sections hidden when no reviews
- **5 Supabase RPCs:** `get_professor_overview`, `get_professor_subject_engagement`, `get_professor_weak_cards`, `get_professor_top_cards`, `get_professor_weekly_reach`
- **Recharts** added to dependencies (`npm install recharts` — lazy-loaded with analytics page)
- **NavDesktop** — Analytics link (BarChart3 icon) for **professor role only**, between Groups and Super Admin
- **NavMobile** — "Professor" section in hamburger sheet with Analytics button, **professor role only**

### Files Changed
- `src/pages/dashboard/ProfessorAnalytics.jsx` (new)
- `src/App.jsx` — lazy import + route for `/dashboard/professor-analytics`
- `src/components/layout/NavDesktop.jsx` — BarChart3 import + Analytics link
- `src/components/layout/NavMobile.jsx` — Professor section + Analytics button
- `package.json` / `package-lock.json` — recharts added

---
## [2026-03-13] feat: multi-course selector on Progress page + tab fix

### Fixed
- **Progress page tabs non-functional** — `tabs.jsx` was a plain-div stub with no show/hide or event logic. Both tab contents rendered simultaneously; clicking did nothing. Replaced Tabs abstraction with direct `{tab === 'all' && ...}` / `{tab === 'course' && ...}` conditional rendering.
- **Content duplicated on Progress page** — consequence of the same tabs stub bug; resolved with conditional rendering fix.

### Added
- **Multi-course pill selector on "By Course" tab** — reads all enrolled courses from `CourseContext` (`profile_courses` table). Users with 2+ courses (e.g. professors) see pill buttons to switch between courses. Subject Mastery and Question Type Performance re-fetch on course change. Single-course users see no change.

### Changed
- **"Course: [primary]" tab label** — renamed to "By Course" to reflect that it now shows any enrolled course, not just the primary.
- **`activeCourseLevel` derivation** — now uses `selectedCourse` state (initialised from `profiles.course_level`, overridable by pill picker) instead of always reading `profile.course_level`.

### Files Changed
- `src/pages/dashboard/Study/Progress.jsx`

**Commits:** `eed55c0`, `84e6110`

---
## [2026-03-13] feat: Sprint 2 — enhanced student Progress page

### Added
- **Time-window selector** — Last 7 Days / Last 30 Days / All Time toggle on Progress page; drives Items Reviewed + Accuracy stat cards
- **Content partition tabs** — "All My Content" and "Course: [level]" tabs; null `course_level` shows empty state with Settings link
- **Due Items Forecast section** — Today / Next 7 Days / Next 30 Days using `get_due_forecast` RPC
- **Study Calendar Heatmap** — 90-day GitHub-style grid via `StudyHeatmap.jsx`; uses `get_study_heatmap` RPC backed by `user_activity_log`
- **Subject Mastery Table** — per-subject mastery % with progress bar via `SubjectMasteryTable.jsx`; uses `get_subject_mastery_v1` RPC
- **Question Type Performance strip** — accuracy % bars per question type via `get_question_type_performance` RPC
- **4 new Supabase RPCs:** `get_due_forecast`, `get_study_heatmap`, `get_subject_mastery_v1`, `get_question_type_performance`
- **2 new components:** `src/components/progress/StudyHeatmap.jsx`, `src/components/progress/SubjectMasteryTable.jsx`

### Changed
- **`Progress.jsx`** — full rewrite; now uses `PageContainer`, tabs, window selector; suspended cards section preserved
- **Stat cards** — Items Reviewed and Accuracy now reflect selected time window; Streak and Mastered remain lifetime metrics

### Files Changed
- `src/pages/dashboard/Study/Progress.jsx` (rewritten)
- `src/components/progress/StudyHeatmap.jsx` (new)
- `src/components/progress/SubjectMasteryTable.jsx` (new)

---
## [2026-03-13] fix: align inactive users filter with DB function definition

### Fixed
- **Inactive users card count mismatch** — card showed 22, drill-down showed 50+. Client filter had no time restriction; now matches `get_user_retention_stats`: students signed up >30 days ago with zero reviews only (content check removed)
- **Filter pill label** — updated to "signed up 30+ days ago, never reviewed"

### Files Changed
- `src/pages/admin/SuperAdminDashboard.jsx`

**Commit:** `140da52`

---
## [2026-03-13] fix: SuperAdmin retention card drill-down filters

### Added
- **`fetchActivitySets()`** — parallel fetch on SuperAdmin Dashboard mount; builds `usersWithReviews` Set (from `reviews` table) and `usersWithContent` Set (from `notes` + `flashcards` tables) for client-side filtering
- **`activeFilter` state** (`null | 'new_this_week' | 'inactive' | 'retained'`) — drives three new filter modes in `filterUsers()`, integrates with existing `searchTerm` + `roleFilter` logic
- **Filter pill UI** — shows active filter label with × to clear; appears above user table in User Management section
- **`scrollToUserManagement()`** helper — clicks Users tab and smooth-scrolls to user management section

### Changed
- **Retention card click handlers** — replaced three `alert()` stubs (`handleNewUsersClick`, `handleInactiveUsersClick`, `handleRetentionClick`) with real filter setters + tab navigation
- **Search and role dropdown** — both now call `setActiveFilter(null)` on change so manual filtering clears the card-driven filter
- **`useEffect` for `filterUsers()`** — dependency array extended to include `activeFilter`, `usersWithReviews`, `usersWithContent`

### Fixed
- **SuperAdmin Dashboard — retention cards showed alert() placeholder** — "New This Week", "Inactive Users", "7-Day Retention" cards now apply real drill-down filters to the user list
- **`Dashboard.jsx` — nested ternary syntax error** — double `:` (missing `?`) caused `npx vite build` to fail with "Expected } but found :". Corrected to `? ... ? ... :`

### Files Changed
- `src/pages/admin/SuperAdminDashboard.jsx`
- `src/pages/Dashboard.jsx`

---
## [2026-03-12] feat: Analytics Blueprint Sprint 1 — nomenclature, bug fixes, DB scaffolding

### Added
- **`vw_study_items` safety view** (SQL ready to deploy) — `SELECT * FROM flashcards WHERE question_type != 'concept_card'`. All review-based analytics must use this view.
- **`get_user_retention_stats()` DB function** (SQL ready to deploy) — 30/60/90-day cohort retention, SECURITY DEFINER.
- **`get_content_creation_stats()` DB function** (SQL ready to deploy) — creator activity trends, SECURITY DEFINER.
- **`get_study_engagement_stats()` DB function** (SQL ready to deploy) — peak hours, session length, SECURITY DEFINER.
- **`get_anonymous_class_stats()` partition fix** (SQL ready to deploy) — JOINs flashcards, filters to registered courses via `SELECT name FROM disciplines WHERE is_active = true` (no hardcoded names).
- **`flashcards` table schema extension** (SQL ready to deploy) — adds `question_type` (DEFAULT 'flashcard'), `options_json`, `correct_answer`, `explanation`, `difficulty_level`, `estimated_time_seconds`, `source`, `portal_metadata` columns + constraints + indexes.
- **SuperAdminDashboard.jsx error banners** — `reportErrors` state now renders descriptive Alert per report section when an RPC function isn't deployed, with exact SQL script name to run.

### Changed
- **Nomenclature — "Cards" → "Items", "Flashcard Decks" → "Study Sets"** across all UI copy (DB names, JS variables, RPC names unchanged):
  - `Dashboard.jsx` — "card/cards ready for review" → "item/items ready for review"; "Study New Cards" button → "Browse Study Sets"; "Unique cards" → "Unique items"
  - `Progress.jsx` — "Cards Reviewed" → "Items Reviewed"; "Cards Mastered" → "Items Mastered"; "Unique cards reviewed" → "Unique items reviewed"
  - `ReviewSession.jsx` — "scheduled cards due" → "scheduled items due"; "cards due" → "items due"
  - `GroupDetail.jsx` — "Shared Flashcard Decks" → "Shared Study Sets" (header, empty state, modal label, fallback display_name)
  - `MyContributions.jsx` — "Flashcards Created" → "Items Created"; "Flashcard Decks" → "Study Sets"; "Flashcard Deck Upvotes" → "Study Set Upvotes"
  - `Home.jsx` — "Flashcards Created" → "Items Created"
  - `FlashcardCreate.jsx` — default fallback title `'Flashcard Deck'` → `'Study Set'`
  - `ActivityFeed.jsx` — `'flashcard decks'` → `'study sets'` in grouped activity label
  - `AdminDashboard.jsx` — "Study Items" card (was "Flashcards")
  - `SuperAdminDashboard.jsx` — "due items reviewed today"; "Items reviewed today..."

### Fixed
- **Progress.jsx — `totalMastered` was scoped to 7-day window** — was counting unique `flashcard_id` from the same 7-day review fetch. Now uses a separate lifetime query (no date filter) to count truly unique items ever reviewed.
- **AdminDashboard.jsx — Pending Review card was hardcoded to 0** — now queries `notes WHERE visibility='public' AND is_verified=false` with exact count. Label uses singular/plural.
- **SuperAdminDashboard.jsx — RPC calls failed silently** — when `get_content_creation_stats`, `get_study_engagement_stats`, `get_user_retention_stats` weren't deployed, the Reports section rendered zeros with no explanation. Now catches errors and renders descriptive Alert banners.

### Files Changed
- `src/pages/Dashboard.jsx`
- `src/pages/dashboard/Study/Progress.jsx`
- `src/pages/dashboard/Study/ReviewSession.jsx`
- `src/pages/dashboard/Groups/GroupDetail.jsx`
- `src/pages/dashboard/Content/MyContributions.jsx`
- `src/pages/Home.jsx`
- `src/pages/dashboard/Content/FlashcardCreate.jsx`
- `src/components/dashboard/ActivityFeed.jsx`
- `src/pages/admin/AdminDashboard.jsx`
- `src/pages/admin/SuperAdminDashboard.jsx`
- `CLAUDE.md` (bash git commit syntax fix)
- DB only (SQL scripts ready to deploy): `vw_study_items` view, `flashcards` schema extension, 4 SECURITY DEFINER functions

---
## [2026-03-12] security: Enable RLS on all flagged tables + ghost deck auto-deletion

### Fixed
- **RLS enabled on 4 tables** — `profiles`, `subjects`, `topics`, `content_creators` now have Row Level Security enabled. Supabase Security Advisor shows 0 errors.
- **Recursive RLS cascade** — 25 policies across 13 tables (`admin_audit_log`, `badge_definitions`, `content_creators`, `disciplines`, `flashcard_decks`, `flashcards`, `notes`, `notifications`, `profile_courses`, `profiles`, `reviews`, `role_change_log`, `role_permissions`) all directly queried `profiles` in their USING/WITH_CHECK clauses. Enabling RLS on `profiles` caused all these policies to error, cascading to: super admin "Access Denied", students seeing "new user" dashboard, professor contributions/progress showing zeros.
- **Fix:** Created `is_super_admin()` and `is_admin()` SECURITY DEFINER functions that check roles without triggering RLS. Dropped and recreated all 25 affected policies using these functions.
- **INSERT policy on profiles** — Added so that new signups (which call `profiles.insert()` from `AuthContext.jsx signUp()`) can create their own profile row.
- **NULL `creator_id` backfill** — 335 flashcards had `creator_id = NULL` (uploaded before the column existed). Backfilled with `UPDATE flashcards SET creator_id = user_id WHERE creator_id IS NULL`.
- **Ghost empty deck prevention** — `update_deck_card_count` trigger now auto-deletes `flashcard_decks` rows when `card_count` reaches 0 after a card deletion. Two pre-existing empty decks cleaned up manually.

### Files Changed
- DB only: `is_super_admin()` function, `is_admin()` function, 25 RLS policies, `update_deck_card_count` trigger

---
## [2026-03-11] fix: Bulk upload no longer silently creates custom topics/subjects

### Fixed
- **Root cause:** `uploadFlashcards()` mapped unrecognised subject/topic names to `custom_subject`/`custom_topic` columns instead of rejecting the row. This allowed Excel drag-fill artefacts (e.g. "The Companies Act, 2014" through "The Companies Act, 2033") to be inserted as custom entries rather than being caught as errors.
- **Validation step added** — after fetching subjects/topics from the DB, all rows are now checked before any insert. If any row references a subject that doesn't exist, or a topic that doesn't exist under that subject, the entire upload is aborted and each bad row is reported with an actionable error message.
- `custom_subject` and `custom_topic` are now always `null` in bulk uploads (subject/topic must already exist in DB).

### Files Changed
- `src/pages/dashboard/BulkUploadFlashcards.jsx`

---
## [2026-03-06] fix: Blank study screen for student-created decks with no topic

### Fixed
- **Root cause:** Students who created flashcards without selecting a topic got cards with `topic_id = null` and `custom_topic = null`. The `get_browsable_decks` RPC returned `"General"` as a fallback label for these decks. When clicked, the URL became `?topic=General` — a phantom label matching nothing in the DB. StudyMode returned 0 cards for all users of such decks (including the 78 professor cards alongside them).
- **Topic is now mandatory in FlashcardCreate** — validation added alongside existing course/subject checks; label updated to show required indicator.
- **Deck-ID navigation for individual deck clicks** — `ReviewFlashcards` now passes `?deck=<uuid>` instead of `?topic=<name>` when clicking a specific deck. `StudyMode` filters by `card.deck_id` when `deck` param is present, bypassing topic string matching entirely.
- **Null-topic nudge in MyFlashcards** — existing users with null-topic cards see an amber warning banner with a "Fix Now →" link that opens the Edit Info dialog. Saving now also updates the `flashcard_decks` record so the browse view reflects the correct topic.
- **Topic made required in MyFlashcards Edit Info dialog** — validation updated; label changed from "Topic (Optional)" to "Topic *".

### Added
- `deck` URL param support in `StudyMode` for precise deck-level filtering

### Files Changed
- `src/pages/dashboard/Content/FlashcardCreate.jsx`
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Study/StudyMode.jsx`
- `src/pages/dashboard/Content/MyFlashcards.jsx`

---
## [2026-03-06] fix: Browse Notes back navigation after "View all" filtered view

### Fixed
- **Browser back now resets filters** — URL sync `useEffect` previously used `if (param)` guards, so navigating back to the clean URL left `filterSubject` and `filterTopic` stuck at their filtered values. Now sets both unconditionally (`|| 'all'`), so back navigation correctly resets to the full list.
- **"← Back to all notes" button** — Added above the page title, visible only when `?topic=` URL param is present. Navigates to `/dashboard/notes` (clean URL), which triggers the filter reset via the URL sync effect.

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`

---
## [2026-03-06] ux: Browse Notes subject-accordion layout with View All per topic

### Changed
- **All subject accordions collapsed by default** — users see the full subject list at a glance instead of a long scroll of expanded content
- **Pagination replaced with View All** — removed `Load More` (note-count pagination). Topics with ≤6 notes render all inline; topics with >6 notes show 6 thumbnails + "View all X notes →" button
- **"View all" navigates to filtered view** — navigates to `/dashboard/notes?subject=X&topic=Y`, reusing the existing BrowseNotes page with pre-set filters
- **`topic` URL param support added** — BrowseNotes now reads `topic` from URL on mount and syncs filter state via `useEffect` when URL changes (for same-page "View all" navigation)
- **Subject accordion auto-expands when subject filter is active** — navigating via "View all" link auto-expands the relevant subject

### Files Changed
- `src/pages/dashboard/Content/BrowseNotes.jsx`

---

## [2026-03-06] fix: resolve ambiguous column "id" in course-aware RPC functions

### Fixed
- **`get_browsable_decks` v3 and `get_browsable_notes` v3** returned HTTP 400 with PostgreSQL error 42702 ("column reference 'id' is ambiguous") for all users. Both functions are declared as `RETURNS TABLE(id UUID, ...)`, making bare `id` ambiguous between the output column (PL/pgSQL variable) and `profiles.id` in the profile lookup. Fixed by qualifying as `WHERE profiles.id = v_user_id`.

### Files Changed
- `docs/database/study-groups/29_FUNCTION_get_browsable_decks_v3.sql`
- `docs/database/study-groups/30_FUNCTION_get_browsable_notes_v3.sql`

---

## [2026-03-06] feat: course-aware browsing — students see only their enrolled course

### Added
- **`get_browsable_decks` RPC (v3)** — Added course gate: students see only `target_course = their course_level` OR their own authored content. Professors/admins/super_admins bypass the course gate entirely.
- **`get_browsable_notes` RPC (v3)** — Same course gate applied.
- **Composite DB indexes** — `idx_flashcard_decks_course_user (target_course, user_id)` and `idx_notes_course_user (target_course, user_id)` to optimise the course gate clause at scale.
- **Course dropdown locked for students** — Disabled `<Select>` with label "(Current Syllabus)". Course initialises from `profiles.course_level` via a profile fetch on mount. "Clear All Filters" respects the lock (does not reset to "All Courses" for students).
- **Dependent empty states** — "No content available for [course] yet / Check back soon" when no data exists; "No results match your filters / Try adjusting your selections" when filters hide results.

### Changed
- `hasActiveFilters` no longer counts the Course filter as active for students (it's locked).
- Author exception: client-side course filter passes through subjects containing the student's own decks/notes from any course.

### Files Changed
- `docs/database/study-groups/28_SCHEMA_composite_course_user_indexes.sql` (NEW)
- `docs/database/study-groups/29_FUNCTION_get_browsable_decks_v3.sql` (NEW)
- `docs/database/study-groups/30_FUNCTION_get_browsable_notes_v3.sql` (NEW)
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`

---
## [2026-03-05] fix: duplicate friend notifications from undocumented DB triggers

### Fixed
- **DB** — Dropped `trg_notify_friend_request` (friendships AFTER INSERT) and `trg_notify_friend_accepted` (friendships AFTER UPDATE). Both triggers called `create_notification()` directly, creating a null-title notification row for every friend event. The `notify-friend-event` Edge Function (called from frontend) was also running, producing a second properly-titled row. Result: every friend request/accept showed twice in the notification bell.
- **DB** — Deleted all existing duplicate null-title rows: `DELETE FROM notifications WHERE type IN ('friend_request','friend_accepted') AND title IS NULL`.

### Root Cause
Two triggers were created early in development before the Edge Function existed and were never removed. They ran in parallel with the Edge Function for every friend event.

### No code changes — DB-only fix.

---
## [2026-03-05] fix: add "My Cards" pinned option in Author dropdown

### Fixed
- **`ReviewFlashcards.jsx`** — Added a hardcoded "My Cards (Private & Public)" `SelectItem` pinned at the top of the Author dropdown (after "All Authors"). Uses `user.id` as value, bypassing the `get_filtered_authors_for_flashcards` RPC which only returns authors with public decks. Students with exclusively private decks were previously invisible in the dropdown and had no way to filter for their own cards.

### Root Cause
`get_filtered_authors_for_flashcards()` filters `fd.visibility = 'public'` — only authors with at least one public deck appear. A student who has only private/friends-visibility flashcards would never appear in the dropdown.

### Files Changed
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`

---
## [2026-03-05] fix: author mixing and SRS cold-start in StudyMode

### Fixed
- **`ReviewFlashcards.jsx`** — `startStudySession()` now forwards the active `filterAuthor` as an `author` URL param. Previously the author filter was ignored when launching a session, causing all users' cards for the subject to appear regardless of who the student had filtered by.
- **`StudyMode.jsx`** — Added `authorParam` URL read and client-side filter (`card.user_id === authorParam`) so only the selected author's cards appear in the session.
- **`StudyMode.jsx`** — Added SRS-aware second query (LEFT JOIN equivalent in two steps): fetches the user's review records for the candidate card set and excludes any card where `status = 'suspended'`, `next_review_date > today`, or `skip_until > today`. Cards with no review record (new/cold-start) are always included. A student who exits mid-session and returns will only see unreviewed cards + any rated Hard (due tomorrow), not the full deck again.

### Root Cause
`startStudySession` never passed the author filter to the URL. `fetchFlashcards` in StudyMode used a broad OR filter (public + own + friends) with no author constraint and no awareness of the user's review history — every session reloaded the full visible card set from scratch.

### Files Changed
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Study/StudyMode.jsx`

---
## [2026-03-05] Fix: cron-review-reminders returning 401 (JWT verification)

### Fixed
- **Supabase Edge Function config** — `cron-review-reminders` had "Verify JWT with legacy secret" enabled by default. pg_cron sends no JWT token (only the `x-cron-secret` header), so every cron invocation was rejected with HTTP 401 before the function code ran. Disabled JWT verification in the Edge Function Details tab. Auth is handled internally by the `x-cron-secret` header check.

### Root Cause
Supabase enables JWT verification by default on all new Edge Functions. Cron-triggered functions called via `pg_net.http_post` cannot include a JWT (no user session exists), so this gate must be disabled. Custom header-based auth (`x-cron-secret`) is the correct pattern for cron functions.

### No code changes — Supabase dashboard configuration only.

---
## [2026-03-04] fix: cascade Subject dropdown from Course in Study section filters

### Fixed
- **`ReviewFlashcards.jsx`** — Subject dropdown now shows only subjects belonging to the selected Course. Previously showed all subjects regardless of Course selection. Auto-resets Subject (and cascades to reset Topic) when Course changes.
- **`BrowseNotes.jsx`** — Same fix applied identically.

### Root Cause
`availableSubjects` was extracted from all decks/notes at load time and never updated when Course filter changed. Topic dropdown already cascaded from Subject correctly — Course→Subject link was simply missing.

### Files Changed
- `src/pages/dashboard/Study/ReviewFlashcards.jsx`
- `src/pages/dashboard/Content/BrowseNotes.jsx`

---
## [2026-03-02] fix: auto-create flashcard_decks on bulk upload (trigger UPSERT)

### Fixed
- **DB** — `update_deck_card_count()` trigger function now auto-creates a `flashcard_decks` row when a flashcard is inserted and no matching deck exists. Previously it only ran `UPDATE card_count`, which silently did nothing if no deck row was present — causing bulk-uploaded flashcards to be invisible in the Study Page, Course filter, and Author Profile.
- **DB (data fix)** — Backfilled missing `flashcard_decks` entries for CA Foundation flashcards that were uploaded before this fix.

### Root Cause
Bulk upload inserts directly into `flashcards`. The trigger tried to `UPDATE card_count` on `flashcard_decks`, but if no deck row existed yet, the UPDATE matched 0 rows and did nothing. Fix: trigger now does UPDATE first; if `NOT FOUND`, it INSERTs the deck row with `card_count = 1`. Going forward, any course/subject/topic combination will get a deck entry automatically on the first flashcard insert.

### Files Changed
- DB only (`update_deck_card_count` function)

---
## [2026-02-24] Fix: card_count double-counting — final resolution

### Fixed
- **DB** — Dropped `flashcards_count_trigger` (added Feb 12 in error). `trigger_update_deck_card_count` was already in the DB correctly maintaining `card_count`. Two triggers = 2x counting.
- **DB (data fix)** — Recalculated all `card_count` values from actual `flashcards` rows.

### Root Cause (corrected from Feb 12 entry)
Original bug was frontend manual increment + existing trigger = 2x. Feb 12 fix removed the frontend increment (correct) but added a second trigger (wrong) — still 2x. Feb 24: dropped the duplicate trigger. `trigger_update_deck_card_count` is now the sole source of truth.

### Files Changed
- DB only

---
## [2026-02-24] perf: lazy-load all pages to fix slow initial load

### Changed
- **`App.jsx`** — Converted all 35+ static page imports to `React.lazy()` / `Suspense`. Pages now load on-demand per route instead of all upfront.
- **`App.jsx`** — Extracted `AppContent` component inside `AuthProvider` so it can use `useAuth()`. Removed duplicate `supabase.auth.getSession()` call (was running in both `App` and `AuthContext`, adding ~200ms latency).
- **`AuthContext.jsx`** — Removed `{!loading && children}` blocking gate; `AppContent` now owns the auth loading spinner. Removed 30+ debug `console.log` statements from `signIn`.
- **`vite.config.js`** — Added `manualChunks` for `vendor-react`, `vendor-supabase`, `vendor-radix` — browser can cache these separately between deploys.
- **`index.html`** — Added `<link rel="preconnect">` for Supabase to reduce first-auth RTT.
- **`src/hooks/useOCR.js`** — Deleted dead code (was never imported; referenced tesseract.js).

### Files Changed
- `src/App.jsx`
- `src/contexts/AuthContext.jsx`
- `vite.config.js`
- `index.html`
- `src/hooks/useOCR.js` (deleted)

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
- ✅ Live URL: https://recall-app-omega.vercel.app → migrated to https://www.recallapp.co.in (Mar 2026)
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