# Bug Tracking

## Sprint 6.0 follow-ups — 03/09/2026

### [03/09/2026] Review-session queue had no in-app nav link (any role) — ✅ FIXED
- **Found:** during 6.0 live QA on a professor account. `/dashboard/review-session` was reachable only via the student dashboard's green "Start Review Session" CTA (professors render a different dashboard branch with no review UI) and the push-notification deep link. The **Study** nav dropdown had only "Review Flashcards" + "Browse Notes". So a professor with due personal reviews — or any user not on the dashboard — had no way in.
- **Not a 6.0 regression:** the professor dashboard branch never had a review CTA; 6.0 only swapped the `reviewsDue` *count* computation to `get_study_queue`. `fetchPersonalStats` does run for professors, so `reviewsDue` was computed — just never rendered in that branch.
- **Fix (Option A):** "Today's Reviews" → `/dashboard/review-session` added as the first item in the Study menu, all roles — `NavDesktop.jsx` dropdown + `NavMobile.jsx` Study section. No dashboard restructure (Option B — a professor-dashboard CTA card — was declined to avoid touching the settled professor dashboard).
- **Status:** ✅ RESOLVED (pushed 03/09/2026).

### [03/09/2026] Progress "Due Items Forecast" disagrees with the review queue — 🔧 FIX WRITTEN (SRS Ladder Phase 1, not yet deployed)
- **Symptom:** `/dashboard/progress` "Due Today" showed **24** for a student whose Dashboard CTA + Review Session (both `get_study_queue`-backed) showed **4**. Student on CA Intermediate; the 20-card gap = due reviews on out-of-course cards the queue correctly filters out.
- **Root cause:** `Progress.jsx` "Due Items Forecast" reads a separate `forecast` source (`get_due_forecast`) that was **not** wired to the `get_study_queue` predicate — no course filter, no concept-card exclusion, server date instead of user-tz. A 4th "due" surface off the SSOT.
- **Not a 6.0 regression:** Progress was not among the three call sites 6.0 rewired, and the forecast was always its own query. But it contradicts the sprint objective ("every surface showing 'due' counts reads from one RPC").
- **Fix (SRS Ladder Epic, `docs/database/srs-ladder/02_FUNCTIONS_srs_ladder_engine.sql`):** rewrite the body of `get_due_forecast(p_user_id)` (signature unchanged → no frontend change). `due_today` now uses the **exact** `get_study_queue` due predicate (user-tz today, `status='active'`, `next_review_date <= today`, `skip_until` null/≤today, `question_type <> 'concept_card'`, read-time course filter, L2 visibility guard); `due_next_7`/`due_next_30` = same predicate, forward cumulative window. Auditor decision: Option (a), single source of truth for the "due" predicate.
- **Expected visible effect on deploy:** ~25 CA-Intermediate students see "Due Today" drop (their CA-Foundation review rows get course-filtered — the same 1,648 rows behind the course-"drift" note below). This is the fix working as designed; worth a release note.
- **Status:** 🔧 FIX WRITTEN — deploys with SRS Ladder Phase 1; flip to ✅ RESOLVED after `02_FUNCTIONS` is live and `03_TEST` block 17 passes.

### [03/09/2026] Course "drift" — 1,648 cross-level review rows (CA-Inter students on CA-Foundation cards) — ℹ️ INFORMATIONAL (no action)
- **Found by:** SRS Ladder Phase 0 diagnostics (Q8/Q9/Q10/Q10b, `docs/database/srs-ladder/00_DIAGNOSTIC_srs_ladder_phase0.sql`).
- **Measurement:** 1,659 active reviews across 25 students / 256 cards where `flashcards.target_course <> profiles.course_level`. Q10b: **1,648 are CA-Intermediate students with review history on CA-Foundation cards** (legitimate cross-level revision), + 11 stragglers.
- **Not a data-quality bug:** Q8/Q9 show `course_level` (`CA Foundation`/`CA Intermediate`/`CA Final` + 5 one-off test values) and `target_course` (`CA Intermediate`/`CA Foundation`) are **clean exact-match values with zero spelling variants**. The feared `CA Inter` vs `CA Intermediate` normalization problem does not exist.
- **Interpretation:** this is the Sprint 6.0 read-time course filter working as designed — a CA-Inter student's `get_study_queue` excludes CA-Foundation cards; Custom Course is the accepted escape hatch (per the 6.0 auditor). It is also the mechanism behind the forecast discrepancy above.
- **Status:** ℹ️ INFORMATIONAL — no normalization slice. Recorded for context.

## Resolved — Sprint 6.0 (c) — ✅ FIXED & PUSHED 02/09/2026 (commit under changelog [2026-09-02])

### [02/09/2026] C1 — Admin stat-card user/published counts disagree between Dashboard and Analytics
- **Root cause:** `AdminDashboard.fetchStats` computed `totalUsers = get_platform_stats.student_count + educator_count` — but `get_platform_stats` is the **anon landing** RPC and `student_count`/`educator_count` = `role='student'` + `role='professor'` only (**excludes admin/super_admin**). `AdminAnalytics` "Total Users" reads `get_admin_platform_overview.total_users` (all roles). Two RPCs → two numbers. Separately, *within* AdminAnalytics: the "Published Items" stat card (`overview.published_items`) and the Content-Health table's "Published Items" column (`Σ get_content_health_stats.total_items`) are different things sharing a label.
- **Fix:** `AdminDashboard.fetchStats` now reads `get_admin_platform_overview` for user/public counts (same RPC as `AdminAnalytics` → they agree); `get_platform_stats` removed from admin (landing-only). Raw note/flashcard totals via direct admin `COUNT(*)`. `publicFlashcards` sub (was hardcoded `0`) now real. AdminAnalytics stat card 4 relabelled **"Published Items" → "Public Flashcards"** / sub **"Public flashcards" → "visibility = public"** to kill the collision with the table column.
- **Canonical source:** `get_admin_platform_overview` for all internal admin platform stat cards; `get_platform_stats` for the anon landing page only.
- **Files:** `src/pages/admin/AdminDashboard.jsx` (`fetchStats`), `src/pages/admin/AdminAnalytics.jsx` (overview stat strip).
- **Status:** ✅ RESOLVED (pushed 02/09/2026). Live screenshot comparison of the two dashboards still needs an admin account.

### [02/09/2026] C2 — Quality-tier → colour logic duplicated & inconsistent
- **Root cause:** no shared util. `AdminAnalytics.QualityBadge` tiered a 0–5 value `>=4/>=3/else`; `SuperAdminDashboard` tiered 0–100% active-rate inline ~8 times (daily `>=60/>=40`, weekly `>=80/>=60`).
- **Fix:** new `src/lib/qualityTier.js` — `qualityTier(value, [strongMin, okMin])` → `{key,text,bar,badge,emoji,label}`. Consumers migrated: `AdminAnalytics.QualityBadge` + the `lowQuality` row-highlight; `SuperAdminDashboard` daily/weekly cards extracted to an `ActiveUsersCard` helper that calls `qualityTier`. Distinct thresholds preserved via the arg.
- **Caption:** see C1 (the mislabelled caption was AdminAnalytics stat card 4 "Published Items").
- **Status:** ✅ RESOLVED (pushed 02/09/2026).

### [02/09/2026] C3 — Active-nav highlight matched exact route only
- **Root cause:** `NavDesktop.jsx` `isActive`/`isStudyActive`/`isCreateActive` used `location.pathname === path`. Nested routes (`/dashboard/notes/:id`, `/dashboard/review-session`, `/dashboard/study`, `/dashboard/progress`) never lit their parent.
- **Fix:** `underAny(paths)` prefix matcher. `isCreateActive` checked first so Create wins the tie over Study's broader `/dashboard/notes` + `/dashboard/flashcards` prefixes. Dashboard link stays exact (`isActive`).
- **Status:** ✅ RESOLVED (pushed 02/09/2026). **Sprint 6.2 dependency satisfied.**

### [02/09/2026] C4 — Featured-note "Currently Live" control — NON-ISSUE
- **Verified working.** `AdminDashboard.jsx` `unfeatureContent()` calls the `unfeature_content` RPC and refetches; wired to the "Currently Live" table. No code change.
- **Status:** ✅ NON-ISSUE (no change).

### [02/09/2026] C5 — Anon "Sign up free" wall shown to logged-in students on share pages
- **Root cause:** `NotePreview.jsx` (`/note/:noteId`, public) rendered the blurred preview + "Sign up free to read the full note" overlay unconditionally; only the CTA block was gated on `!user`. `DeckPreview.jsx` had the sibling issue (public preview shown to logged-in users).
- **Fix:** `NotePreview.jsx` — when `getUser()` returns a user, `navigate('/dashboard/notes/' + noteId, { replace: true })` and skip the preview fetch. `DeckPreview.jsx` — an effect redirects to `/dashboard/review-flashcards?deck=:deckId` when `useAuth().user` is set.
- **Status:** ✅ RESOLVED (pushed 02/09/2026). Live check (logged-in student on a `/note/:id` link) still needs a student account. `NoteDetail.jsx`'s Tier-B `ContentPreviewWall` is the intentional B2C freemium gate — untouched.

### [02/09/2026] C6 — "Due Today: 0" rendered as a red alarm
- **Root cause:** `Progress.jsx` ForecastCard for "Due Today" hardcoded `accent="text-red-600 bg-red-50 border-red-200"` regardless of `forecast.due_today`.
- **Fix:** `accent` is now `text-green-700 bg-green-50 border-green-200` when `due_today === 0`, red only when `> 0` (existing tokens, no new ones). *(Sprint-prompt tension noted: the prompt says "reserve alarm styling for genuine problems"; the coordinator directed "red only when >0" — followed the coordinator. Flip one ternary branch to amber if the >0 case should also be de-alarmed.)*
- **Status:** ✅ RESOLVED (pushed 02/09/2026).

## Resolved Bugs

### [04/07/2026] Unguarded admin/internal writers + a read-guard over-guard regression
- **Found by:** the residual-IDOR sweep (`docs/database/security/12_DIAGNOSTIC...`), run to *prove* the advisor's 116 WARNs harmless. The advisor doesn't detect IDOR — this sweep did.
- **Gaps found & fixed:**
  - `enroll_user_in_batch_group(p_user_id)` + `notify_access_granted(p_user_id)` — SECURITY DEFINER writers taking a *target* user with no auth check; any authenticated user could enroll/notify arbitrary users. Admin-RPC-only (confirmed via `14_DIAGNOSTIC` caller audit) → added `IF NOT is_admin() THEN RAISE` (`15_FUNCTIONS`).
  - `log_review_activity(p_user_id, …)` — internal helper (only the `fn_badge_check_reviews` trigger calls it) but `authenticated`-executable + unguarded → inject-activity-for-anyone. Revoked `authenticated`/`anon` EXECUTE (`16_SCHEMA`); trigger path (runs as owner) unaffected. Verified: `17_TEST` 6/6.
- **Regression I introduced & fixed same session:** the read-IDOR pass (`08`) guarded `get_user_streak` to self-only, but a streak is **social** data — `get_following_with_stats` / `get_my_friends_with_stats` / `get_batch_group_member_stats` call `get_user_streak(other_user)` to show friends'/members' streaks. The guard broke those 3 pages for non-admins. Reverted (`bugfixes/13_FUNCTIONS`); `bugfixes/14_DIAGNOSTIC` confirmed it was the only misclassification.
- **Key lesson:** **audit internal callers before adding a guard that RAISEs.** The admin-writer fixes did this (`14`) and were clean; the read guards (`08`) didn't and broke a social path. A guard on a SECURITY DEFINER function affects *every* caller, including triggers and other functions — not just the frontend.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] Read-side IDOR — SECURITY DEFINER RPCs let any user read another user's private data
- **Found by:** the read-IDOR audit (`docs/database/security/07_DIAGNOSTIC...`), requested after L5.
- **Symptom:** several SECURITY DEFINER functions took `p_user_id`/`p_professor_id` and returned that user's data **without checking it against `auth.uid()`**. SECURITY DEFINER bypasses RLS, so the param was fully trusted. An authenticated user could pass another person's UUID and read their study stats, notifications, suspended cards (incl. card text), streaks, subject mastery, and professor analytics. **`get_user_badges` was a *live* leak** — the returned data includes **private** badges (no `is_public` filter), and a dead-but-present hook helper (`useBadges.js` `fetchUserBadges`) called it cross-user.
- **Also caught:** **`unsuspend_card`** — a card-scheduling **write** RPC that the L5 IDOR pass missed. Root cause of the miss: the L5 write-guard audit's regex used `update ` with a trailing word-boundary that never matched `UPDATE`-only functions, so UPDATE-only writers (`unsuspend_card`, `get_unnotified_badges`) were misclassified as reads.
- **Confirmed via:** `07_DIAGNOSTIC` (classified secdef reads taking a user-id param by whether they reference `auth.uid()`) + `07b_DIAGNOSTIC` (bodies of the ambiguous/professor fns). `get_unread_notification_count` + `mark_notifications_read` were already guarded (no change).
- **Fix:** `08_FUNCTIONS` (10 group-A self-only guards; 4 `LANGUAGE sql` → `plpgsql` to allow the `RAISE`), `09_FUNCTIONS` (5 professor guards, `p_professor_id = auth.uid() OR is_admin()`), `10_FUNCTIONS` (`get_user_badges` self-only), + removed the dead cross-user `fetchUserBadges` from `useBadges.js` (FindFriends already fetches others' badges via a direct `is_public = true` query; `get_public_user_badges` is the correct cross-user RPC).
- **Verified via:** `11_TEST_verify_read_idor_guards.sql` — 7/7 PASS (cross-user reads/writes RAISE `Access denied`; self-calls work).
- **Key lessons:** (1) SECURITY DEFINER reads taking an identity param must constrain it to `auth.uid()` (or admin) exactly like writes — the READ side leaks too. (2) A write-detection regex must actually match `UPDATE`/`INSERT`/`DELETE` — verify the audit's own coverage, or writers slip through.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] skip_card / suspend_card errored on first-ever skip/suspend of a card (wrong reviews columns)
- **Found by:** L5 SECURITY DEFINER write-guard audit (flagged during IDOR-guard work, fixed in a follow-up pass).
- **Symptom (latent):** `skip_card` / `suspend_card`'s `IF NOT FOUND THEN INSERT INTO reviews (...)` branch — which fires the **first time** a user skips/suspends a card they have **no review row** for — named columns `easiness_factor` and `repetitions`, which don't exist. That path threw `42703 column "easiness_factor" of relation "reviews" does not exist`. The common path (card with an existing review → `UPDATE`) worked, so it went unnoticed.
- **Root Cause:** the reviews table uses `easiness` (double precision) + `repetition` (integer) — same wrong-column-name bug fixed in `skip_topic_cards`/`suspend_topic_cards` on Apr 4, 2026, but these two single-card functions were missed then.
- **Confirmed via:** `docs/database/bugfixes/08_DIAGNOSTIC_reviews_columns_for_skip_suspend_fix.sql` — Block 1 showed `easiness`/`repetition` (not `easiness_factor`/`repetitions`); `next_review_date` is a `date` column (branch passed `NOW()`).
- **Fix:** `docs/database/bugfixes/09_FUNCTIONS_fix_skip_suspend_card_reviews_columns.sql` — `CREATE OR REPLACE` both with `easiness`/`repetition`, and `CURRENT_DATE` for `next_review_date` (matching `skip_topic_cards`). L5 IDOR guard + `search_path` preserved verbatim.
- **Verified via:** `10_TEST_verify_skip_suspend_card_insert.sql` — skip/suspend a card with no prior review → review row created (`active`/`suspended`), no `42703`. 2/2 `[CRITICAL]` PASS.
- **Key lesson:** when fixing a column-name bug in one function, grep for the same wrong names across ALL functions — the Apr 4 fix corrected the topic-scoped RPCs but left the single-card twins with the same defect for ~3 months.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] IDOR — card-scheduling RPCs let any user modify another user's review schedule
- **Found by:** L5 SECURITY DEFINER write-guard audit (`docs/database/security/01_DIAGNOSTIC...`), not a user report.
- **Symptom (latent, not observed in the wild):** `skip_card`, `suspend_card`, `reset_card`, `skip_topic_cards`, `suspend_topic_cards` are SECURITY DEFINER, take `p_user_id`, and wrote to `reviews` **without checking `p_user_id = auth.uid()`**. Any authenticated user could call `/rest/v1/rpc/skip_topic_cards` with another student's UUID and tamper with their spaced-repetition schedule (horizontal privilege escalation). No data theft — unauthorized modification.
- **Root Cause:** the functions trusted the caller-supplied `p_user_id` (frontend always passes `user.id`, but nothing enforced it server-side).
- **Fix:** `docs/database/security/02_FUNCTIONS...` + `02b_FUNCTIONS...` — added `IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN RAISE EXCEPTION 'Access denied'` to all five; bodies otherwise verbatim.
- **Verified via:** `06_TEST_verify_l5_hardening.sql` — cross-user `skip_card`/`suspend_topic_cards` RAISE `[CRITICAL]`; own-card action allowed.
- **Key lesson:** any SECURITY DEFINER function that takes a `p_user_id` (or other identity param) and writes must verify it against `auth.uid()` — SECURITY DEFINER bypasses RLS, so the param is otherwise fully trusted.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] Dashboard deck grid + Recent Activity listed public decks with 0 viewer-visible cards
- **Reported by:** Founder (logged in as CA Anand More, professor) — after a student set their only card to private, the deck still appeared in Review Flashcards ("1 card, by TestOutlook") and in dashboard Recent Activity; clicking it opened an empty study session ("No flashcards to study").
- **Symptom:** a public deck whose only card is now private still leaked its **metadata** (name, author, count, activity) to other users, though the card **content** was correctly hidden. Distinct surface from the public-preview bug above — this is the authenticated dashboard, which was the report's actual context.
- **Root Cause:** `get_browsable_decks` and `get_recent_activity_feed` (its `recent_decks` CTE) gated at the **deck** level (`fd.visibility`) and (for the grid) returned the denormalized `fd.card_count` — neither checked per-**card** visibility. A public deck around private cards therefore listed. `get_browsable_notes` was NOT affected (notes are atomic).
- **Confirmed via:** `docs/database/bugfixes/04_DIAGNOSTIC_listing_surfaces_visibility.sql` — dumped both function bodies; Query 3 showed deck `1e521de5` = public, stored_count 1, **0 public / 1 private**.
- **Fix (SQL only):** `05_FUNCTIONS` (`get_browsable_decks` v4 — `LATERAL` viewer-visible card count, exclude decks with 0, return that as `card_count`) + `06_FUNCTIONS` (`get_recent_activity_feed` — `EXISTS` a viewer-visible card in `recent_decks`).
- **Verified via:** `07_TEST` 4/4 PASS — non-owner professor sees deck `1e521de5` in neither surface `[CRITICAL]`; owner still sees it with `card_count=1`.
- **Key lesson:** for a **container** whose visibility is decoupled from its children (deck→cards), gating the container is not enough — any listing/feed surface must check per-child visibility for the viewer, and denormalized counts (`card_count`) leak child existence. (Atomic content like notes is fine gated on its own visibility.)
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] Public deck preview leaked private/friends cards to anyone (incl. anonymous)
- **Reported by:** Founder — a flashcard created public by a student (TestOutlook), then changed to **private** by the creator, was still visible inside the deck to another user (CA Anand More, professor).
- **Symptom:** After a creator set a card to `private`, its `front_text` still appeared on the public deck preview page (`/deck/:id`). Reproducible by **anyone**, including logged-out visitors — broader than the reported professor case.
- **Root Cause:** `get_public_deck_preview(p_deck_id)` is a `SECURITY DEFINER` RPC (bypasses RLS). It gated the **deck** on `visibility='public'` but its inner `preview_items` subquery selected the first cards **with no per-card visibility filter**. So private/friends cards inside a public deck leaked. The in-app StudyMode view was NOT affected (RLS-protected direct query that also excludes `private` client-side).
- **Confirmed via:** `docs/database/bugfixes/01_DIAGNOSTIC_deck_preview_visibility_leak.sql` — Block 1 showed the live body had no `fc.visibility` predicate in the preview subquery; Block 2 found 1 live public deck (`1e521de5…`) with 1 non-public card being served. Not on `deck_id` (never populated) — the RPC uses the 5-grouping-column join.
- **Fix (SQL only, no frontend change):** `docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql` — `CREATE OR REPLACE` adding `AND fc.visibility = 'public'` to the preview subquery. Also made the public `card_count` count public cards only (was `fd.card_count`, a trigger-maintained total that revealed how many hidden cards exist) and added deterministic `ORDER BY created_at`. Signature unchanged → safe in-place replace; `NOTIFY pgrst`.
- **Verified via:** `docs/database/bugfixes/03_TEST_verify_public_deck_preview_visibility.sql` — public deck with one public + one private card; all 3 assertions PASS (private card NOT in preview `[CRITICAL]`, public card present, `card_count`=1).
- **Key lessons:**
  - Any `SECURITY DEFINER` RPC that returns content on a public/anon surface must filter visibility **explicitly** — RLS does not protect it. The deck-level gate is not enough; per-**card** visibility must be filtered too.
  - The 5-grouping-column flashcards→decks join returns **all** visibility tiers by itself; content-returning RPCs must add `fc.visibility = 'public'` (or the appropriate per-viewer predicate) on top of it.
  - Context of the L2 migration: `is_public` was dropped 03/07/2026; `visibility` is the sole gate.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [Apr 4, 2026] Suspend Topic — "Failed to suspend topic" error after Sprint 4.0 deploy
- **Reported by:** Aryan Pamnani (iOS, live session)
- **Symptom:** Tapping "Suspend Topic" in the `...` dropdown showed the red "Failed to suspend topic." error toast immediately. Affected all cards regardless of topic type.
- **Root Cause:** PostgreSQL's `CREATE OR REPLACE FUNCTION` only replaces a function if the parameter signature is identical. The Sprint 4.0 SQL for `suspend_topic_cards` changed the signature from `(UUID, UUID)` to `(UUID, UUID DEFAULT NULL, TEXT DEFAULT NULL)` — a different signature. PostgreSQL created a second overloaded version rather than replacing the original. PostgREST then found two functions with the same name and refused to resolve the call, returning an ambiguity error. The frontend's `catch` block displayed "Failed to suspend topic."
- **Confirmed via:** `SELECT pg_get_function_arguments(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'suspend_topic_cards'` — returned two rows.
- **Fix (step 1):** `DROP FUNCTION IF EXISTS public.suspend_topic_cards(UUID, UUID)` — removed the stale 2-param overload. The new 3-param version handles all existing callers via `DEFAULT NULL` on the added parameter.
- **Fix (step 2):** `NOTIFY pgrst, 'reload schema'` — PostgREST caches function signatures and continued serving the stale two-function schema even after the DROP. The NOTIFY forces an immediate schema reload, resolving the ambiguity error for live users.
- **Fix (step 3):** Wrong column names in both RPC bodies — `easiness_factor` (actual: `easiness`) and `repetitions` (actual: `repetition`). Both RPCs were written from DATABASE_SCHEMA.md which itself had the wrong column names. The error only surfaced when Aryan triggered an INSERT path (cards with no existing review record). The SQL Editor diagnostic passed silently because the test student+topic combination had zero matching flashcards — the INSERT never ran. Confirmed via browser console: `code 42703 — column "easiness_factor" of relation "reviews" does not exist`. Fixed by `CREATE OR REPLACE` of both functions with correct column names + `NOTIFY pgrst, 'reload schema'` in same execution.
- **Root cause of the root cause:** DATABASE_SCHEMA.md had wrong column names for the `reviews` table (`easiness_factor` instead of `easiness`, `repetitions` instead of `repetition`). The schema doc was the single source of truth used to write the SQL. DATABASE_SCHEMA.md has been corrected and the CRITICAL section updated with a rule: any SQL against `reviews` must be cross-checked against the actual column names in `StudyMode.jsx` handleRating before deploying.
- **Key lessons:**
  - When adding parameters to an existing RPC, always explicitly DROP the old signature before or after the `CREATE OR REPLACE`. Never assume `CREATE OR REPLACE` replaces across signature changes — in PostgreSQL it does not.
  - After any DROP FUNCTION or signature change, always run `NOTIFY pgrst, 'reload schema'` immediately. Without it, PostgREST continues to serve the stale cache and users continue to see the error even though the database is already correct.
  - SQL Editor diagnostics that return "Success" on a function with zero matching rows DO NOT validate the INSERT body. Always test with data that actually triggers the INSERT path.
  - Never trust schema docs alone for column names. Cross-check against the working frontend code (handleRating in StudyMode.jsx is the ground truth for `reviews` column names).
- **Status:** ✅ RESOLVED

### [Apr 4, 2026] FlashcardCreate — Back button discards all unsaved cards with no warning
- **Symptom:** User creates multiple flashcards using "Add Another Flashcard", then accidentally taps the Back button. All card content is lost immediately. No confirmation, no recovery. Reported by Pareesa after losing 45 cards in a single session.
- **Root Cause:** The Back button and Cancel button both called `navigate(-1)` directly with no navigation guard. No autosave existed.
- **Fix:** Three-layer protection added to `FlashcardCreate.jsx`: (1) `useBlocker` intercepts in-app navigation when dirty and shows a confirmation modal; (2) `beforeunload` event intercepts tab close/reload; (3) localStorage autosave (1s debounce) persists card content, with a recovery banner shown on next visit. See Sprint 4.1 in changelog for full details.
- **Status:** ✅ RESOLVED

### [Mar 30, 2026] Push notifications never delivered since Sprint 3.6 — CRON_SECRET mismatch
- **Symptom:** No student received any push notification (nightly study summary or morning review reminder) since Sprint 3.6 shipped on 2026-03-25. Edge Function invocations all returned HTTP 401.
- **Root Cause (primary):** `cron-daily-study-summary` pg_cron job was created with the literal placeholder `YOUR_CRON_SECRET_HERE` as the `x-cron-secret` header value, never replaced with the real secret. Function's auth guard rejected every call.
- **Root Cause (secondary):** Fixing required rotating `CRON_SECRET` via Supabase CLI (`npx supabase secrets set`). `daily-review-reminders` was correctly configured with the original hash but that hash no longer matched after rotation → also broke until resynced.
- **Fix:** Recreated both pg_cron jobs via `cron.unschedule()` + `cron.schedule()` with correct matching secret. Confirmed 200 response on next invocation.
- **Key lesson:** `CRON_SECRET` is shared by all cron-triggered Edge Functions. Before rotating it, audit every cron job command that sends it in an `x-cron-secret` header — resync all jobs atomically.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] iOS 16.7.5 — Push notification install instructions never shown
- **Symptom:** iOS users in regular Safari saw neither the push enable button nor the "Add to Home Screen" instructions.
- **Root Cause:** `PushPermissionBanner.jsx` evaluated `if (!isSupported) return null` before the `needsIOSInstall` check. On iOS in-browser, `PushManager` is not in `window`, so `isSupported = false` and the component returned `null` before reaching the iOS-specific render path. The iOS instructions were dead code.
- **Fix:** Moved `handleDismiss` above all guards; inserted the `needsIOSInstall` early return (with `isDismissed` guard) before the `isSupported` guard.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] Study time not updating after flashcard review session
- **Symptom:** Completing a flashcard study session did not add time to the "Study time today" dashboard stat. Affected all platforms (not just iOS).
- **Root Cause:** `handleRating()` in `StudyMode.jsx` handled the last-card completion inline: `if (onComplete) onComplete(sessionStats); else { toast(); onExit(); }`. This code path never called `finishSession()` or `logStudyModeSession()`. Only the skip/suspend/reset-on-last-card paths called `finishSession()`. The rating path — the primary completion path for all students — silently discarded the session.
- **Fix:** Replaced the inline last-card completion block in `handleRating` with a single `finishSession()` call.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] handleStop — 21h+ sessions bypass leaderboard protection
- **Symptom:** A student who kept the browser tab open (never reloading the page) and manually pressed Stop after 21+ hours would have the full duration logged to the DB, bypassing leaderboard integrity protection. Confirmed via diagnostic: a 76,035s (21.1h) session existed in `study_sessions`.
- **Root Cause:** The 16h discard threshold only ran on page **mount** (stale session recovery). `handleStop` had no duration check at all — it passed any elapsed time directly to `insertSession`.
- **Fix:** Applied the same 3-tier policy to `handleStop` as mount-time stale session recovery: `< 4h` logs normally; `4–16h` routes to the honest-session prompt (localStorage keys preserved for mount recovery if student navigates away); `> 16h` discards and shows a destructive toast. Added `useToast` import to `StudyTimerWidget.jsx`.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] Android — After recovery prompt, second study session not started (UX gap)
- **Symptom:** After the 4–16h stale-session recovery prompt logged a session, students did not realize they needed to press Start again for a new session. Total study time appeared lower than actual.
- **Root Cause:** No code-level cap found in `insertSession`, `GoalProgressWidget`, or `get_study_time_stats` (RPC diagnostic pending). The UX gap: post-recovery idle state showed "Session logged: Xh Ym" + Start button but no guidance linking the two.
- **Fix:** Added `postRecovery` boolean state in `StudyTimerWidget`. Set to `true` after recovery-prompt log, cleared on Start. When true, a "Tap Start to begin a new session." hint appears below the confirmation text.
- **Status:** ✅ UX fixed. SQL diagnostic for RPC cap still pending — run `[DIAGNOSTIC] Inspect get_study_time_stats for duration cap` in Supabase to confirm no server-side filter exists.

### [Mar 22, 2026] FindFriends — Raw email exposed in network payload (client-side masking only)
- **Symptom:** `FindFriends.jsx` queried `profiles` with `email` in the select. `maskEmail()` hid the address in the UI but any user with DevTools could read the full email of every user on the platform in the network response.
- **Root Cause:** No server-side filtering. The function `maskEmail()` was purely cosmetic. The comment at line 14 acknowledged this explicitly: "NOTE: Email masking is cosmetic only. Full email is present in data payload."
- **Fix:** Replaced direct `.from('profiles')` query with `.rpc('get_discoverable_users')` SECURITY DEFINER function. Masking now happens inside PostgreSQL — `left(email, 1) || '***@' || domain`. Raw email never appears in the RPC response.
- **Status:** ✅ RESOLVED

### [Mar 22, 2026] FindFriends — No course-level filtering (all users shown to all users)
- **Symptom:** `FindFriends.jsx` returned every user on the platform regardless of course. A CA Foundation student saw CA Final, CMA, and all other users.
- **Root Cause:** The direct `profiles` query had no `course_level` filter. There was a stale help section entry ("Filter by course level") but no such client-side filter existed in the code.
- **Fix:** `get_discoverable_users()` RPC filters `WHERE p.course_level = v_course_level` server-side. Cross-institute same-course connections are still allowed (intentional product design).
- **Status:** ✅ RESOLVED

### [Mar 20, 2026] AuthContext signUp — profile INSERT fails with 401 (no session during email-confirmation flow)
- **Symptom:** New user signs up → email confirmed → logs in → intermittent missing profile rows; browser console showed 401 on `profiles` INSERT during signup.
- **Root Cause:** `AuthContext.signUp()` called `supabase.from('profiles').insert(...)` client-side immediately after `supabase.auth.signUp()`. With email confirmation ON, `signUp()` returns a `user` object but **no session** — `auth.uid()` is null. RLS blocked the insert silently (returned a `profileError` but the code only logged a warning and continued). Users who signed up could sometimes land in a state with no profile row.
- **Discovery:** Pre-flight diagnostic in Sprint 2.4 confirmed no `auth.users` trigger existed for profile creation — the client-side insert was the only write path, and it was unreliable.
- **Fix:** Deployed `trg_create_profile_on_signup` — a SECURITY DEFINER trigger on `auth.users` INSERT that creates the profile row server-side using `raw_user_meta_data`. Removed the client-side insert and the 100ms delay from `AuthContext.signUp()`. Timezone defaults to `Asia/Kolkata` and is overwritten on first login by `updateUserTimezone()`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Group Invite Links Return "Link not found" for Batch Groups
- **Symptom:** Visiting `/join/:token` for a batch group token showed "This invite link is invalid or the group no longer exists."
- **Root Cause:** `get_group_preview` had `AND is_batch_group = false` in the token lookup query. Batch group tokens always returned `{ group: null, stats: null }`. GroupJoin set `notFound = true` and showed the error screen.
- **Fix:** Removed `is_batch_group = false` filter from both `get_group_preview` and `join_group_by_token` RPCs. Also fixed two bugs in `get_group_preview` stats query: (1) `p.current_streak` column doesn't exist anywhere in the DB — hardcoded `0` for avg_streak; (2) `badges` table doesn't exist — corrected to `badge_definitions`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] postAuthRedirect Race Condition — Always Lands on /dashboard Instead of Join Page
- **Symptom:** User visits `/join/:token` → clicks "Sign in" → logs in → lands at `/dashboard` instead of back at the join page. `localStorage` was confirmed to be set correctly before login, but was `null` by the time Login.jsx or AppContent read it post-login.
- **Root Cause:** Supabase's `onAuthStateChange` fires synchronously inside `signIn()` (before the Promise resolves). This triggers React's auth state update, which fires AppContent's `useEffect([user, loading])`. That effect reads AND removes `localStorage.postAuthRedirect`, then navigates to `/join/:token`. Then `signIn()` Promise resolves and Login.jsx's code continues — reads localStorage (now null) — navigates to `/dashboard`, overriding AppContent's navigation. Last `navigate()` wins.
- **Secondary issue:** PostAuthRedirect component (tried as intermediate solution) suffered from React 18 StrictMode double-invocation: effects run twice in development. First run navigated correctly; second run found empty localStorage and navigated to `/dashboard`.
- **Fix:** Read and remove `localStorage.postAuthRedirect` BEFORE calling `signIn()` in Login.jsx. Store in a local variable. AppContent's useEffect fires during signIn() but finds nothing (already cleared) and does nothing. After signIn() resolves, Login.jsx navigates using the local variable. On error, key is restored to localStorage.
- **Status:** ✅ RESOLVED

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
