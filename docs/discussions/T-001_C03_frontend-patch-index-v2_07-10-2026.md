# T-001 · C-03 frontend draft: exact-diff index, revision 2 (07/10/2026; supersedes revision 1, patch 4cbaf7cb5b05)

*Prepared by Claude for QA's exact-diff audit and the Founder's Gate 5 decision. Nothing here is committed to `main` or pushed.*

## The artifact
| Item | Value |
|---|---|
| Patch | `docs/discussions/T-001_C03_frontend-patch-v2_07-10-2026.patch` |
| sha256 | `5dea3daa956c3a8a0e0c3a63b53e0c888ca571732fae14666a45e388ebf8bd4b` (short `5dea3daa956c`) |
| Base | commit `ca2c2e7` (its `src/`, `scripts/` and `package.json` are identical to `main` at `be13e2f`; only `docs/` differs) |
| Size | 46 files, `git diff --binary HEAD` after intent-to-add of new files |
| Apply | `git apply docs/discussions/T-001_C03_frontend-patch-v2_07-10-2026.patch` on a checkout of the base (verified clean: `git apply --check` passed, one harmless trailing-blank-line warning in a new file) |

## Files changed (46)

**A. Guard, manifest and classification (scripts/, package.json)**

| File | + | - |
|---|---|---|
| `package.json` | 2 | 0 |
| `scripts/dueSetGuard.mjs` | 332 | 0 |
| `scripts/dueSetGuard.run.mjs` | 18 | 0 |
| `scripts/dueSetGuard.test.mjs` | 234 | 0 |
| `scripts/dueSetManifest.json` | 1271 | 0 |
| `scripts/dueSetRpcClassification.json` | 1395 | 0 |

**B. Wrapper module and its tests**

| File | + | - |
|---|---|---|
| `src/lib/dueSet.js` | 208 | 0 |
| `src/lib/dueSet.test.js` | 367 | 0 |

**C. One shared due snapshot (context, nav, App, removed hook)**

| File | + | - |
|---|---|---|
| `src/App.jsx` | 3 | 0 |
| `src/contexts/DueSnapshotContext.jsx` | 141 | 0 |
| `src/contexts/DueSnapshotContext.test.jsx` | 172 | 0 |
| `src/contexts/NavDataContext.jsx` | 5 | 5 |
| `src/hooks/useDueForecast.js` | 0 | 42 |

**D. Heatmap (component, date and grid helpers, tests)**

| File | + | - |
|---|---|---|
| `src/components/progress/StudyHeatmap.jsx` | 160 | 128 |
| `src/components/progress/StudyHeatmap.test.jsx` | 196 | 0 |
| `src/lib/heatmapGrid.js` | 129 | 0 |
| `src/lib/heatmapGrid.test.js` | 111 | 0 |

**E. Call sites switched to the wrappers or to the snapshot**

| File | + | - |
|---|---|---|
| `src/components/content/FeatureNominationButton.jsx` | 2 | 2 |
| `src/components/dashboard/GoalProgressWidget.jsx` | 3 | 3 |
| `src/components/layout/NotificationCenter.jsx` | 3 | 8 |
| `src/components/progress/ForecastCard.jsx` | 31 | 0 |
| `src/components/progress/ForecastCard.test.jsx` | 30 | 0 |
| `src/components/ui/ContentPreviewWall.jsx` | 2 | 2 |
| `src/components/ui/UpvoteButton.jsx` | 2 | 2 |
| `src/contexts/AuthContext.jsx` | 2 | 4 |
| `src/contexts/CourseContext.jsx` | 2 | 4 |
| `src/pages/Dashboard.jsx` | 13 | 37 |
| `src/pages/admin/AdminDashboard.jsx` | 12 | 14 |
| `src/pages/admin/SuperAdminDashboard.jsx` | 3 | 3 |
| `src/pages/dashboard/BulkUploadFlashcards.jsx` | 3 | 2 |
| `src/pages/dashboard/Content/FlashcardCreate.jsx` | 3 | 2 |
| `src/pages/dashboard/Content/MyFlashcards.jsx` | 6 | 24 |
| `src/pages/dashboard/Content/MyNotes.jsx` | 2 | 4 |
| `src/pages/dashboard/Content/NoteDetail.jsx` | 2 | 4 |
| `src/pages/dashboard/Friends/FindFriends.jsx` | 6 | 6 |
| `src/pages/dashboard/Friends/FriendRequests.jsx` | 4 | 11 |
| `src/pages/dashboard/Friends/MyFriends.jsx` | 2 | 4 |
| `src/pages/dashboard/Groups/GroupDetail.jsx` | 2 | 1 |
| `src/pages/dashboard/Groups/MyGroups.jsx` | 2 | 1 |
| `src/pages/dashboard/Profile/AuthorProfile.jsx` | 3 | 5 |
| `src/pages/dashboard/Profile/ProfileSettings.jsx` | 8 | 10 |
| `src/pages/dashboard/Study/MyCards.jsx` | 8 | 17 |
| `src/pages/dashboard/Study/PracticeMode.jsx` | 2 | 1 |
| `src/pages/dashboard/Study/Progress.jsx` | 10 | 46 |
| `src/pages/dashboard/Study/StudyMode.jsx` | 12 | 6 |
| `src/pages/public/Educators.jsx` | 3 | 3 |

Total: +4927 / -401.

## What it does, by brief C v6 requirement
- **C-6.4 wrappers.** `src/lib/dueSet.js` is the only place that changes what is due. Every wrapper returns the same `{ data, error }` as the call it replaces and emits `notifyReviewDataChanged()` only when the call succeeded (graded answers debounced 1.5 s; bulk My Cards once after the last chunk and once after a partial failure; profile writes only for `course_level` or `timezone`).
- **The due-changing RPC set comes from the accepted evidence, not from a hand-written list:** `scripts/dueSetRpcClassification.json` is built from W1 (diagnostic 11 v4, Gate 4 Round 126) and W2 (diagnostic 12, Gate 4 Round 131): 102 of 136 frontend RPC names are not-due-changing and 34 are due-changing: add_batch_to_my_cards, add_to_my_cards, admin_change_role, admin_delete_note, admin_delete_user_data, admin_grant_access, admin_reactivate_user, admin_suspend_user, apply_review, approve_educator_application, approve_featured_nomination, bulk_pause_my_cards, bulk_remove_from_my_cards, bulk_resume_my_cards, create_flashcard_batches, invite_to_group, leave_group, link_access_request, nominate_featured_content, reject_featured_nomination, remove_from_my_cards, reset_card, skip_card, skip_topic_cards, submit_access_request, submit_educator_application, submit_institute_inquiry, suspend_card, suspend_topic_cards, toggle_upvote, unassign_professor_from_batch, unfeature_content, unsuspend_card, update_daily_goal.
- **Fail-closed guard** (`scripts/dueSetGuard.mjs`, run by `npm run guard:due` and `prebuild`): parses every file in `src/` with espree; recognises the Supabase client by binding (including aliases and `createClient`); gives each call a syntax-derived identity (file, enclosing symbol, kind and target, ordinals, no line numbers). It fails on an unclassified call, a stale or duplicate manifest entry, an RPC name with no evidence classification, a manifest entry that disagrees with the name classification, a due-changing RPC outside the wrapper module, an unresolved (variable) target outside it, a client method used as a value or a destructured client, a `profiles` write of `course_level` or `timezone` outside it, a `flashcards` update of `target_course`, `question_type` or `visibility` (or of a payload whose keys cannot be read) outside it, any `friendships` write outside it, a `flashcard_decks` delete outside it, and a card or note delete outside it. **Stated limit (QA Round 78):** the guarantee covers recognised call shapes only; a new backend transport needs a guard and manifest update.
- **Manifest** (`scripts/dueSetManifest.json`): 211 call sites (165 not-due-changing, 45 due-changing, 1 infrastructure), each with a reason of at least 20 characters and a basis from a fixed list; RPC entries cite W1 and W2.
- **C-6.4 one snapshot.** `src/contexts/DueSnapshotContext.jsx`: both RPCs fetched together and published as one object only if both succeed; numbered requests, a stale answer is discarded; a failed refresh keeps the previous numbers and sets `error`; refresh on a wrapper signal, on tab visibility and on entering Dashboard, Progress or Review when older than 60 s. NavDataContext (nav badge, professor own-due count), Progress tiles, the Dashboard zero-state strip and the Forward Load chart read it; `useDueForecast.js` and the separate fetches are removed. **When no snapshot exists (first load failed) `dueToday`, `dueNext7`, `dueNext30` and `forecast` are `null` (never 0): the nav badge is hidden, the professor own-due count and the Progress tiles show a dash (the tile in the neutral tone, never the green calm tone, via the new `ForecastCard` component with its own test) and the strip is hidden. (Revision 2, after QA Round 133.)**
- **C-7.1 to C-7.4 heatmap.** Reads `get_study_heatmap_split` (the old `get_study_heatmap` stays deployed, unused by the frontend). Dates are calendar strings handled as local dates built from parts: no `new Date('YYYY-MM-DD')`, no `toISOString()` (a static test fails if either returns). Each day is a button with an accessible name (date, in-app, offline, total, reviews), one tab stop with arrow keys, Home and End; hover and focus show a card; tap, Enter or Space pins it; Escape, a second tap, focus leaving the heatmap, or a press outside closes it; the native `title` is gone; animation only under `motion-safe`.

## Visible changes a Founder would notice
1. The heatmap grid now always covers the whole 90-day window, which is 13 or 14 week columns (it used to show 85 to 91 days depending on the weekday, so the oldest days were sometimes missing). Days outside the window are not drawn.
2. The month label is now named after the month that starts in that week (it used to show the previous month when the 1st fell mid-week).
3. Hover shows a small card (in-app, offline, total, reviews) instead of the browser tooltip; tapping a day pins it.
4. The Dashboard "nothing due" strip and the Progress tiles now come from the same numbers as the nav badge; the Progress forecast tile moved to its own file `src/components/progress/ForecastCard.jsx`.

## Verification run by Claude on a clean checkout of the base with the patch applied
- `npx vitest run`: 9 files, **170 tests pass** (wrapper module 57, guard 27, snapshot context 11, heatmap helpers 12, heatmap component 15, forecast tile 3, and the three existing files 6 + 12 + 27).
- `npm run guard:due`: passes (211 database calls, all classified).
- `npx eslint .`: 30 problems (23 errors, 7 warnings), **fewer than `main`, which has 33 (26 errors, 7 warnings)**; none is in code this patch adds; the remaining ones are pre-existing (for example `showCustomSubject` in FlashcardCreate, `friendshipData` in AuthorProfile).
- `npm run build` (including `prebuild`): succeeds.

## What is NOT verified, stated plainly
- **No browser run.** The app needs a signed-in session that Claude does not have; Dashboard, Progress, StudyMode and the other edited pages were checked by lint, build, the guard and reading the diff, not by clicking. The heatmap and the snapshot have component tests in jsdom; Dashboard and Progress edits do not have component tests.
- **Negative-UTC browser time zone.** The helpers use only local date parts and a static test forbids UTC parsing, but this Windows machine ignores the `TZ` variable, so a run under a real negative offset was not possible here. QA can run `TZ=America/Los_Angeles npx vitest run src/lib/heatmapGrid.test.js src/components/progress` on a machine where `TZ` is honoured; Gate 7 includes a live check.
- **Screen reader and touch device.** The accessible names, roles and keyboard behaviour are tested in jsdom; a real screen reader and a real touch tap were not run.
- **Cross-user and cross-device changes** cannot signal this tab (stated in the module header); the snapshot catches up after 60 seconds on visibility or page entry.
- **The classification is bound to the W1 and W2 snapshot** (lexical analysis, not a behavioural proof). Any later routine, policy, trigger, rule, cascade or frontend-call change returns to review.

## Judgement calls QA and the Founder may want to overrule
1. 22 further RPCs became wrappers because W1 flagged them (QA Round 125 ruling 1). Eight of them (`toggle_upvote`, `update_daily_goal`, `invite_to_group`, `leave_group`, `unassign_professor_from_batch`, `submit_access_request`, `submit_educator_application`, `submit_institute_inquiry`) are flagged only because the evidence could not clear them; they signal on a 1.5 s debounce. A later body reading could move them to not-due-changing and remove the extra refresh.
2. `friendships` inserts and upserts, not only updates and deletes, are now wrapper-only, because an upsert can replace an accepted row with a pending one.
3. Flashcard `visibility` updates go through the wrapper and signal, although the owner's own cards stay eligible; other users' due sets cannot be signalled from this tab.
4. `flashcard_decks` deletes (admin) are wrapper-only because they cascade to cards, reviews and enrollments.

## Not in this patch
- Docs updates required by `CLAUDE.md` after a shipped change (changelog, blueprint, now, bugs, file-structure): they belong with Gate 6, not in the exact diff under audit.
- Removal of the old `get_study_heatmap` function; any SQL.
