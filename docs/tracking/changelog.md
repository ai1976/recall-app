# Changelog

---
## [2026-09-17] feat(sprint-8.6c): multi-select MCQ (mcq_multi) — full build, SQL deployed & verified live (✅ committed & pushed `19632fe`)

A new, distinct `question_type`, `mcq_multi` — build-up-then-explicit-submit (checkboxes, mirrors `handleMatchSubmit`), not a flag on single-select `mcq`. Exact-set grading, all-or-none. Part of the professor authoring-toolkit-completeness work (D-20, blueprint.md §3.1) — not direct professor demand, but equipping professors with a broadly capable toolkit ahead of serious content onboarding.

### Deployment corrections (two real bugs found live, both fixed and re-verified — not assumed away)
- `apply_review`'s `CREATE OR REPLACE` with an added parameter left two live overloads instead of replacing in place (`42725 not unique` error) — same class as the `get_browsable_decks` v5 gotcha (blueprint.md §1.11). Fixed with an explicit `DROP FUNCTION` of the old 5-arg signature (`02b_HOTFIX_drop_ambiguous_apply_review_overload.sql`).
- The verification test's RLS impersonation only set `request.jwt.claims`, not the actual Postgres `ROLE` — the Supabase SQL Editor connects as a role that bypasses RLS entirely, producing a false FAIL on the student-rejection check. Fixed by adding `SET LOCAL ROLE authenticated;`, the idiom `sprint7.5/02_TEST` already used. Final result: all 7 checks PASS.

### Added
- **`mcq_multi` question type** — 2-6 options, checkboxes, at least 1 correct required (not "at least 1 incorrect" — a pedagogical preference, not enforced). Marking every option correct shows a non-blocking inline confirmation rather than rejecting.
- **`src/lib/mcq.js`** — `canonicalizeMultiAnswer`/`parseMultiAnswer`/`compactMcqMultiOptions`/`validateMcqMultiOptions`/`deriveMcqMultiBackText`, shared by manual authoring and CSV import so both paths produce byte-identical canonical storage (`correct_answer = "0;2;4"`, sorted ascending, semicolon-joined, no spaces).
- **`review_events.selected_answer`** (nullable jsonb, SQL drafted) — attempt evidence, populated only by `mcq_multi` for now. `apply_review` gains a new trailing `p_selected_answer jsonb DEFAULT NULL` parameter.
- CSV support in `BulkUploadFlashcards.jsx` — semicolon-delimited `correct_option` cell (e.g. `"1;3"`), same 1-based-CSV-to-0-based-DB convention as `mcq`.
- `helpContent.js` — new "Multi-select MCQ" entries across all 5 relevant Help sections, matching the existing 8 types' documentation format.

### Gated (D-10, unchanged mechanism)
- `mcq_multi` added to both D-10 RESTRICTIVE RLS policies (`flashcards_gate_verdict_types_insert`/`_update`) and `chk_flashcards_question_type` (9th live value) — professor/admin/super_admin only, same `is_professor_or_admin()` check every other verdict-bearing type uses.

### SQL — ✅ deployed & verified live (`docs/database/sprint8.6c/`)
- `00_DIAGNOSTIC_preflight.sql`, `01_SCHEMA_add_mcq_multi_type.sql`, `02_FUNCTIONS_apply_review_selected_answer.sql`, `02b_HOTFIX_drop_ambiguous_apply_review_overload.sql`, `03_TEST_verify_sprint8.6c.sql` — all 7 test checks PASS.

### Live browser verification (17/09/2026, dev server → live Supabase, real professor session)
- Manual authoring: partial-correct card (wrong-answer path, auto-Hard) + all-options-correct card (non-blocking confirmation notice, correct-answer path with full self-grade). `back_text` correctly derived as every correct option joined with `•`, matching manual and CSV entry paths byte-for-byte.
- Bonus: the professor dashboard's "Accuracy by question type" widget picked up "Multi-select MCQ" with zero code changes.
- CSV: an out-of-range `correct_option` index correctly rejected the whole file with a row-specific error (0 rows created); a corrected file then uploaded successfully.
- All 4 test artifacts cleaned up and reverified at 0 rows (`04_CLEANUP_remove_verification_test_cards.sql`).
- **✅ Committed and pushed** (`19632fe`, on `main`).

### Files Changed
- `src/lib/mcq.js`, `src/lib/questionTypes.js`, `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/data/helpContent.js`, `docs/database/sprint8.6c/*.sql`, `docs/active/{blueprint,now}.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/tracking/changelog.md`.

---
## [2026-09-17] feat(sprint-8.6b): grouped-row CSV import for match_the_following + concept_card

`BulkUploadFlashcards.jsx` previously deferred bulk upload for these two question types entirely ("create individually instead") — both hold a variable-length list of *pairs* that doesn't fit the flat `option_1..4` CSV convention, and forcing an in-cell delimiter onto real content risked silently mis-splitting text that itself contains colons/commas. Instead, each pair now gets its own CSV row, grouped by an uploader-chosen label column — mirroring `case_study_mcq`'s `case_group` mechanic, but fusing every row in a group into ONE card rather than N separate ones.

### Added
- **`match_group`/`match_left`/`match_right`** CSV columns — one left/right pair per row, `match_group` links rows into one card (2-8 rows), professor/admin/super_admin only (D-10 gate, unchanged from manual authoring).
- **`concept_group`/`concept_term`/`concept_definition`** CSV columns — one key-term/definition pair per row, `concept_group` links rows into one card (1-10 rows), open to every role (D-06, unchanged).
- New "Bulk CSV Upload — Grouped-Row Types" section in `helpContent.js` with full grouped-row examples.

### Fixed (pre-existing doc bugs, found along the way)
- `helpContent.js` had a stale tip claiming an unrecognized `question_type` silently downgrades to a plain flashcard — that's been false since Sprint 8.3's A1 fix, which rejects it outright with a row-specific error. Corrected.

### Confirmed, not assumed
- A standalone Node harness (importing the real `src/lib/matchTheFollowing.js`/`conceptCard.js` modules, outside React/the browser) exercised 5 scenarios before any live testing: valid 3-pair match card, valid 3-term concept card, an orphan group (1 row, rejected by the existing pair-count minimum), a group id reused across two unrelated cards (the genuinely-matching rows still form a valid card; the conflicting row is rejected on its own, never silently absorbed), and a flat plain-flashcard row (unaffected). All 5 passed.

### Verified
- **Live (17/09/2026, dev server → live Supabase, real professor session, operator logged in directly — Claude never saw or entered a password).** The Browser pane's automation has no file-picker action to drive a CSV `<input type="file">` directly, so verification exercised the exact insert path `BulkUploadFlashcards.jsx` uses (same library calls, same row shape) via the authenticated page's own module scope: a 3-pair match_the_following card and a 3-term concept_card both inserted successfully (professor RLS gate confirmed permissive for match_the_following), read back with the exact shape manual authoring produces, appeared correctly in My Study Sets, and the concept_card's existing "Read Concepts" viewer rendered all 3 pairs correctly. Both test rows deleted after verification, reverified at 0 rows.
- No SQL required — both `question_type` values were already live.

### Files Changed
- **Changed:** `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/data/helpContent.js`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-17] feat(sprint-8.6a): offline study-log minimum raised to 10 minutes, server-side

The manual study timer's loggable-session floor was 10 seconds — a sub-threshold stop silently discarded the session with no DB row and no user-facing message. Raised to 10 minutes, mirrored server-side, and given an explicit "too short to log" message instead of silence.

### Added
- **`study_sessions_duration_floor`** — `CHECK (duration_seconds >= 600) NOT VALID` (`docs/database/sprint8.6a/01_SCHEMA_add_duration_floor.sql`). Same `NOT VALID`/prospective-only pattern as `study_sessions_manual_requires_category` (Sprint 8.5) — enforces on every future INSERT without scanning or rewriting existing rows, so no backfill and pre-existing sub-10-minute rows stay exactly as they are.
- **`'too_short'` outcome** on `StudyTimerContext.jsx`'s `stopAndLog()` — replaces the old `{ outcome: 'logged', durationSeconds: 0 }`, which rendered as a misleading "Session logged: 0s" toast for what might have been a real short attempt. `StudyTimerWidget.jsx` and `StudyTimerChip.jsx` (the two independent stop entry points) both gained a matching toast: "RevisOp records offline study sessions of 10 minutes or more — shorter moments aren't included in manual study-time tracking."

### Confirmed, not assumed
- The 4-16h recovery-prompt path (`handleRecoveryFull`/`handleRecoveryCustom`) cannot produce `'too_short'` — its minimum possible duration is 1 hour (the custom-hours input floor) — checked rather than taken for granted.

### Verified
- **SQL deployed & verified live by the operator (17/09/2026).** `00_DIAGNOSTIC` confirmed `duration_seconds` carried only the pre-existing `> 0` check (`NOT NULL`, no floor) — no `IS NULL` guard needed. `01_SCHEMA` added the constraint. `02_TEST` proved all three required cases: a 599s insert rejected (`23514 check_violation` on `study_sessions_duration_floor`), a 600s insert succeeded, and 3 real pre-existing March 2026 manual rows (17s, 49s, 263s) read back unchanged — confirming `NOT VALID`'s prospective-only guarantee.

### Files Changed
- **Added:** `docs/database/sprint8.6a/00_DIAGNOSTIC_confirm_duration_column.sql`, `01_SCHEMA_add_duration_floor.sql`, `02_TEST_verify_duration_floor.sql`.
- **Changed:** `src/contexts/StudyTimerContext.jsx`, `src/components/dashboard/StudyTimerWidget.jsx`, `src/components/layout/StudyTimerChip.jsx`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] fix(sprint-8.5): DB-level enforcement that manual sessions carry a category

Quality-auditor review of the completed sprint found a real integrity gap before commit: the frontend required a category, but the database didn't. `category` is nullable and its own `CHECK` only validates a value when present, so nothing stopped a future write path outside `confirmCategory()` — a bulk import, a different form, a regression — from silently inserting `source='manual', category=NULL` and reopening the exact gap this sprint exists to close.

### Added
- **`study_sessions_manual_requires_category`** — `CHECK (source <> 'manual' OR category IS NOT NULL) NOT VALID` (`docs/database/sprint8.5/04_SCHEMA_manual_requires_category.sql`). `NOT VALID` enforces on every future INSERT/UPDATE without scanning or rewriting rows that already exist — no backfill, no global `NOT NULL`. Chosen over a trigger since every other rule on this table (`source`'s values, `duration_seconds > 0`, `category`'s own value set) is already a plain `CHECK`, and triggers elsewhere in this app are reserved for cross-table side effects, not single-row validation.

### Verified
- **Immutability confirmed live, not just from the doc's claim**, before relying on it (`03_DIAGNOSTIC_confirm_study_sessions_immutable.sql`): no RLS `UPDATE` policy on `study_sessions`, no function in `public` references this table alongside an `UPDATE`, no trigger attached to the table — rows are genuinely write-once, so `NOT VALID`'s "also enforced on future UPDATEs" caveat is a non-issue here.
- **All three required cases proved live** (`05_TEST_verify_manual_requires_category.sql`): a `NULL`-category manual insert is rejected (`23514` on `study_sessions_manual_requires_category`); a valid categorized manual insert still succeeds; 3 real pre-existing March 2026 manual rows with `category IS NULL` read back untouched.
- The one real test row (left by the case that wasn't wrapped in `ROLLBACK`, to see its own `RETURNING` result) was removed via a tightly-scoped preview-then-delete, confirmed to match exactly 1 row before deletion.
- No frontend changes needed — `confirmCategory()` already only ever sends one of the 5 valid category values.

### Logged as backlog (not fixed, not blocking)
- **`sprint7.3/03_TEST_verify_study_time_and_goal_prompt.sql`** likely has the same `auth.uid()`-is-`NULL`-in-the-SQL-Editor issue this sprint's own `02_TEST` hit. Not re-run to confirm; test-harness debt, not a product bug.

### Files Changed
- **Added:** `docs/database/sprint8.5/03_DIAGNOSTIC_confirm_study_sessions_immutable.sql`, `04_SCHEMA_manual_requires_category.sql`, `05_TEST_verify_manual_requires_category.sql`, `06_CLEANUP_remove_test_row.sql`.
- **Changed:** `docs/reference/DATABASE_SCHEMA.md`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] docs(sprint-8.5): SQL deployed & verified live — Group A now fully shipped

Follow-up to the entry below: the operator ran `00_DIAGNOSTIC` (confirmed live `study_sessions` matched docs exactly, `get_study_time_stats` had zero category references) then `01_SCHEMA` (added the column), then `02_TEST` in two parts. Result: valid `reading` insert succeeded, invalid `'not_a_real_category'` correctly hit `23514 check_violation` — both rolled back, nothing persisted. Phase 8 Group A is now fully shipped, SQL and frontend both live.

### Fixed
- **`02_TEST_verify_category_column.sql`'s write checks** — originally used `auth.uid()`, which is always `NULL` in the Supabase SQL Editor's no-session context and caused a `user_id NOT NULL` violation on the first run (caught safely by the existing `BEGIN`/`ROLLBACK` wrapper — nothing left behind). Rewritten to look up the project's existing disposable test account (`anandmore@outlook.com` / TestOutlook) via `profiles.email`, the same pattern Sprint 8.4's `02_FIX_reset_exam_prompt_dismissal_test_account.sql` already uses.

### Verified
- Both `02_TEST` runs passed exactly as expected. No frontend changes needed — it was already built against the final schema.

### Files Changed
- **Changed:** `docs/database/sprint8.5/02_TEST_verify_category_column.sql`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] feat(sprint-8.5): required category picker for offline study-log entries

Phase 8, Group A's last item. A manually-logged offline study session (`source = 'manual'`) now requires a category — one of Reading, Writing Practice, Lecture Viewing, Paper Solving, or Mock Test (timed) — chosen at stop/log time rather than at Start, to keep the Start click frictionless. **SQL not yet deployed** — the frontend is built and live-verified against a real `PGRST204` error confirming it's correctly gated on the schema landing first.

### Added
- **`study_sessions.category`** — nullable `text`, `CHECK`-constrained to the 5 values above, no default, no backfill (`docs/database/sprint8.5/01_SCHEMA_add_study_session_category.sql`). Applies only to `source = 'manual'` rows.
- **Category picker** in `StudyTimerWidget.jsx` — 5 buttons + a Save button disabled until one is selected, shown for both the direct <4h stop path and a resolved recovery-prompt choice (full-time or custom-hours).
- **`StudyTimerContext.jsx`'s new `pendingLog` state** — `stopAndLog()` now finalizes a duration into this state instead of writing to the DB directly; a new `confirmCategory(category)` performs the actual insert once chosen. Persisted to its own `revisop_manual_timer_pending_log` localStorage key so a page reload mid-picker re-shows the picker instead of losing an already-stopped session.

### Changed
- **`StudyTimerChip.jsx`** (nav bar) — a tap that used to stop+log+toast in one motion for a <4h session now navigates to `/dashboard/study-time` when a category is needed, since the chip has no room to host a picker. Same pattern the chip already used for the 4-16h recovery case. This was a gap the sprint brief didn't cover; resolved by asking the operator rather than guessing (chose "navigate to the page" over "build a chip popover").

### Dropped from the brief (deliberate, not an oversight)
- **"Revision/Recap" as a 6th category** — mixed a purpose/timing axis into an activity-type axis, creating real overlap with every other category. Logged as a possible orthogonal flag in `blueprint.md` §3.2, not built.
- **Per-category breakdown UI** — the brief asked for categorization at logging time only, not a new report. Logged as backlog.

### Verified
- `npx eslint` clean on all 3 touched files. Live click-through in the Browser pane (`TestOutlook`): picker renders all 5 options, Save disabled until selected, selection highlighting correct; `pendingLog` confirmed to survive a full page reload (picker re-appears, nothing lost); pre-existing <10s no-op path confirmed unchanged. Tapping Save against the still-undeployed schema correctly surfaced `PGRST204 "category column not found"` and left the picker state intact — proves the write path and the SQL-first gate are both correct. **Frontend requires `00_DIAGNOSTIC` + `01_SCHEMA` deployed in Supabase before this is live** — not yet confirmed done.

### Files Changed
- **Added:** `docs/database/sprint8.5/00_DIAGNOSTIC_confirm_no_category_column.sql`, `01_SCHEMA_add_study_session_category.sql`, `02_TEST_verify_category_column.sql`.
- **Changed:** `src/contexts/StudyTimerContext.jsx`, `src/components/dashboard/StudyTimerWidget.jsx`, `src/components/layout/StudyTimerChip.jsx`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] feat(sprint-8.4): "Exam Runway" reframe replaces the tentative hedge

Audit review of the previous entry's `~{days} days (tentative — assumes the 1st of {Month})` found it still framed the number as an estimate of days-until-exam, just with a caveat attached. Stronger fix: change what the number measures instead of hedging it — days until the stated calendar month begins is exact, unhedged fact, not a guess about an unannounced exam date.

### Changed
- **Dashboard month-only nudge**, restructured from one hedged line into a labeled 3-line "Exam Runway" block:
  ```
  EXAM RUNWAY · May 2027
  227 days until May begins
  Exact exam date not yet set · Update once announced
  ```
  No `~`, no "tentative" — nothing left to hedge, since the count is no longer standing in for the exam date itself. Same underlying `daysUntilExamDate(examMonth)` call as before; only the label and framing changed. Still un-carded, matching the earlier "lower visual weight than the exact-date card" decision.

### Added (backlog, not built)
- **Revision-phase indicator** — a named phase (e.g. "Build & Strengthen" → "Intensive Revision" → "Final Consolidation") derived from the runway length, proposed as a stronger early-warning layer than a bare count. Needs real pedagogical judgment on phase boundaries and per-phase guidance; logged in `blueprint.md` §3.2, not implemented this sprint.

### Verified
- `npm run build` clean. Live-verified against a real month-only profile: renders exactly as designed, day-count unchanged and still correct.

### Files Changed
- **Changed:** `src/pages/Dashboard.jsx`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] feat(sprint-8.4): tentative days-count added to the month-only exam nudge

Follow-up to the same-day month-only nudge (below): the operator asked for the days-count back after all, explicitly labeled "tentative" — a materially different ask from the flat countdown declined earlier, since the original objection was to an unlabeled number implying certainty, not to a labeled estimate.

### Changed
- **Dashboard month-only nudge** — now reads `~{days} days (tentative — assumes the 1st of {Month Year}) · Update once announced`, computed from `exam_month` (already the 1st of the month, so no new date-math needed). The "tentative" qualifier sits directly beside the number, not in a caption underneath, so it can't be skimmed past the way sub-text under a bold number can. Nav chip and the exact-date countdown card are both left untouched by explicit choice — the chip has no room for the caveat, and the real countdown should stay visually distinct from an estimate.

### Verified
- `npm run build` clean. Live-verified against a real month-only profile: `~227 days (tentative — assumes the 1st of May 2027)` rendered correctly, day-count confirmed correct against the calendar.

### Files Changed
- **Changed:** `src/pages/Dashboard.jsx`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] feat(sprint-8.4): month-only exam nudge on the Dashboard

A month-only student (`exam_month` set, no `exam_date`) had no on-Dashboard signal at all beyond the nav chip's text — the countdown card intentionally stays exact-date-only per D-17. Added a slim text line instead of a card, to avoid reintroducing a fabricated countdown.

### Added
- **Dashboard "exam month nudge"** — renders only when `exam_month` is set and `exam_date` is not: "Exam expected [Month Year] — date announced? Update it", linking to Profile Settings. Sits where the countdown card would be; the two are mutually exclusive.

### Declined (same request, evaluated and rejected)
- An assumed-1st-of-month countdown — reverses D-17's own precision rule that a month-level guess must never imply exact-date precision.
- An automated notification when the real date is announced — the app has no way to detect an external exam-board announcement, and this is explicitly out of scope per the Sprint 8.4 brief.

### Verified
- `npm run build` clean. Live-verified in the Browser pane: nudge renders correctly for a month-only profile, "Update it" navigates to `/dashboard/settings`.

### Files Changed
- **Changed:** `src/pages/Dashboard.jsx`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] docs(sprint-8.4): audit follow-up — has_dismissed_exam_prompt recorded as an approved D-17 extension + dismiss lifecycle verified

An audit review of Sprint 8.4's completion report (below) found one material point: `has_dismissed_exam_prompt` plus `ExamDatePromptModal` are a genuine, database-persisted product/schema decision beyond the sprint brief's original two-nullable-column contract — it changes the contract from "student sees the CTA when no date exists" to "student can permanently suppress the popup" — and its lifecycle had been disclosed as untested rather than actually verified. Recommendation: record it as an approved extension to D-17 and verify the lifecycle before commit, reusing the existing test account rather than creating a second one.

### Verified (new this entry)
- Reset `TestOutlook`'s `has_dismissed_exam_prompt`/`exam_date`/`exam_month` to pristine `false`/`NULL`/`NULL` via a new scoped, rerunnable SQL fix (no second account needed). Confirmed live: popup reappears when unset → "Skip for now" dismisses cleanly → reload does **not** bring the popup back (permanent, not per-session) → nav chip's CTA state is shown identically before and after dismissal (the flag gates only the modal, never the chip) → Profile Settings' Exam Date section stays fully reachable/functional throughout → setting an exact date afterward updates cleanly everywhere with no interference from the prior dismissal.

### Changed (docs only, no code)
- `docs/active/blueprint.md` — D-17 gained an explicit "Approved extension" entry recording `has_dismissed_exam_prompt`/`ExamDatePromptModal` as reviewed and approved, with the 6-point lifecycle verification above. Removed the now-resolved "verify dismiss lifecycle" backlog line from §3.2.
- `docs/tracking/changelog.md` — this entry.

### Added
- `docs/database/sprint8.4/02_FIX_reset_exam_prompt_dismissal_test_account.sql` — scoped by email to the one disposable test profile, safe to rerun for future regression checks of this same lifecycle.

### Files Changed
- **New:** `docs/database/sprint8.4/02_FIX_reset_exam_prompt_dismissal_test_account.sql`.
- **Changed:** `docs/active/blueprint.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] feat(sprint-8.4): exam date field (chip, dashboard countdown, first-login popup, Profile Settings) + group_type/is_batch_group pre-flight audit

Pre-flight Step 0 (carried in from Sprint 8.3): audited every `group_type`/`is_batch_group` read/write on `study_groups`. No second instance of the bug Sprint 8.3 fixed was found. Did not collapse the two columns — two live RPCs the frontend calls (`create_study_group`, `get_user_groups`) have no matching definition anywhere in the repo's SQL docs, so a blind schema change was out of scope per the sprint's own capped-scope rule.

Exam-date feature scope changed twice during pre-flight, both by explicit operator decision: (1) dropped the planned `Signup.jsx` picker entirely — signup profile creation goes through a `handle_new_user()` DB trigger with no client session available, so capture instead happens via a dismissible popup on first login (new or pre-existing student); (2) popup dismissal is permanent, matching the existing `has_dismissed_goal_prompt` pattern.

### Added
- **SQL** (`docs/database/sprint8.4/`) — `exam_date`/`exam_month` (nullable, `exam_month` CHECK'd to the 1st of the month) + `has_dismissed_exam_prompt` (boolean, default false) on `profiles`.
- **`src/contexts/ExamDateContext.jsx`** — fetch-once + mutators (`saveExamDate`, `dismissPrompt`), same shape as `CourseContext.jsx`; wired into `App.jsx`.
- **`src/components/dashboard/ExamDatePromptModal.jsx`** — dismissible first-login popup (month/year or exact date), shown from `Dashboard.jsx` only after the onboarding/profile-completion modals have both cleared so dialogs never stack.
- **`src/components/layout/ExamDateChip.jsx`** — nav pill beside `StudyTimerChip` in `NavDesktop.jsx`/`NavMobile.jsx`, student-only, three states (countdown days / month text / "Set exam date" CTA), taps through to Profile Settings.
- **Dashboard "Days Until Your Exam" card** — self-gates on an exact `exam_date` only; a month-level guess never gets a fabricated days-count.
- **Exam Date section in `ProfileSettings.jsx`** — set/refine indefinitely, month↔exact toggle, pre-fills from existing value.
- **`src/lib/examDate.js`** — `daysUntilExamDate`/`formatExamMonth`/`buildExamMonthValue`, parses `YYYY-MM-DD` date-only values directly and does UTC-anchored day-count arithmetic, never `toISOString()` or a timezone-local `Date` read.

### Fixed (unrelated, found while verifying)
- **`.claude/launch.json`** — `vite`'s own port-increment logic ignored the harness's assigned proxy port whenever the default port was already taken (by another session), so the dev-server preview silently never loaded. Pinned an explicit `--port 5183 --strictPort`.

### Verified
- `npm run build` clean across all new/changed files, including lazy-loaded route chunks.
- Live click-through in the Browser pane, logged in as a pre-existing student with no exam info set: popup appeared on first login (confirms no-backfill CTA behavior); set month-only → chip showed month text, no dashboard card; upgraded to an exact date via Profile Settings → chip updated to a days-remaining count immediately with no reload, dashboard card appeared with the matching count and date; changed the exact date again → clean update everywhere, no stale cache; mobile nav (375px) checked, no overflow. Day-count math verified correct against the calendar.
- **Not live-verified:** the "dismiss without setting, never reappears" path — needs a second student account, which this session can't create (account-creation/credential restriction). Code-reviewed instead.

### Files Changed
- **New:** `docs/database/sprint8.4/00_DIAGNOSTIC_confirm_no_exam_date_columns.sql`, `docs/database/sprint8.4/01_SCHEMA_add_exam_date_tracking.sql`, `src/contexts/ExamDateContext.jsx`, `src/components/dashboard/ExamDatePromptModal.jsx`, `src/components/layout/ExamDateChip.jsx`, `src/lib/examDate.js`.
- **Changed:** `src/App.jsx`, `src/pages/Dashboard.jsx`, `src/pages/dashboard/Profile/ProfileSettings.jsx`, `src/components/layout/NavDesktop.jsx`, `src/components/layout/NavMobile.jsx`, `.claude/launch.json`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/active/now.md`, `docs/active/blueprint.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] docs(sprint-8.3): Quality Auditor follow-up — B1 malformed-input test + audit disposition recorded

A Quality Auditor review of Sprint 8.3's completion report (below) found one material issue: the report characterized 2 of the originally-planned 5 help screenshots as satisfied by a "native browser dialog" technical finding, when the correct disposition is deferred (a real UX fix needed first), not waived. Also flagged: B1's malformed-input handling was only shown via a happy-path click, and A1's test-plan gap (extracted-logic testing instead of a live file-upload) should be recorded as a limitation, not implied full verification.

### Verified (new this entry)
- B1's exact `renderInlineLinks` parser extracted and run against 17 cases — unclosed brackets, external URLs, reversed/nested brackets, empty label/target, non-string inputs (`null`/`undefined`/a number), and a string mixing valid links with a broken tail. All 17 degraded to plain text or partial-link output with zero crashes.

### Changed (docs only, no code)
- `docs/active/blueprint.md` — Sprint 8.3 entry corrected: "Dropped" screenshots 4-5 reworded to "Deferred, not waived"; the `create_batch_group` bug fix framed explicitly as independently-documented, out-of-scope; status changed from a flat ✅ SHIPPED to "implementation complete, audit close pending 2 housekeeping items"; A1's test limitation stated plainly rather than only implied. New Pending Work (§3.2) item: replace the native `confirm()`/`prompt()` dialogs in `SuperAdminDashboard.jsx` (role-change, Hard Delete) with real accessible in-app dialogs, then capture the 2 remaining screenshots against those.
- `docs/active/now.md` — added a "Quality Auditor follow-up" section recording the full disposition.

### Added
- `docs/database/sprint8.3/04_CLEANUP_delete_test_batches.sql` — preview-then-delete script for the operator to remove the 2 disposable Sprint 8.3 test batch groups, required before the sprint is considered operationally closed.

### Files Changed
- **New:** `docs/database/sprint8.3/04_CLEANUP_delete_test_batches.sql`.
- **Changed:** `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md` (this entry).

---
## [2026-09-16] feat(sprint-8.3): bug fixes + Help renderer (hyperlinks & screenshots) + a real batch-approval bug found and fixed

Content-only-looking sprint that turned up a real production bug along the way. Part A: two isolated `BulkUploadFlashcards.jsx` fixes. Part B: extended `Help.jsx`'s renderer with an internal link syntax and an image block, then used both on the Sprint 8.2 batch-lifecycle sections. While staging a disposable test batch group to capture screenshots, discovered `create_batch_group` never set `group_type='batch'`, silently disabling the D-15 student-approval gate for any batch created through the live function — fixed and verified same session.

### Added
- **`Help.jsx` `ContentBlock`** — inline `[label](/route)` link syntax (regex-based, only matches a `/`-prefixed target inside well-formed brackets; anything else — external URLs, a stray `[label](`, unbalanced brackets — never matches, so it degrades to plain text rather than crashing) applied to `paragraph`/`list`/`steps`/`tip` blocks. New `case 'image'` block type (`{ src, alt, caption?, annotations?: [{x, y, label}] }`) with numbered CSS-positioned callout markers over the image (percentage `x`/`y`) and a matching numbered caption list.
- **`public/help-screenshots/`** (new folder) — 3 screenshots wired into `admin-batch-groups`: batch creation + Copy Invite Link, Pending Batch Requests approve/reject, and the Active/Archived filter. All use a disposable, clearly-labeled test batch and a dummy student test account — no real student/professor data. Captured via the operator's own screenshot tool (the session's Browser pane has no file-export capability), then resized/recompressed with `sharp` to 10-20KB each.
- **`docs/database/sprint8.3/`** — 2 diagnostic scripts, 1 fix, 1 verification script for the `group_type` bug (see Fixed below).

### Fixed
- **A1 (`BulkUploadFlashcards.jsx`):** a non-blank, unrecognized `question_type` (e.g. `match_the_following`, a typo) is now rejected with a specific row error instead of silently downgrading to a plain `flashcard`. A blank cell is unchanged — still silently defaults to `flashcard`.
- **A2 (`BulkUploadFlashcards.jsx`):** `downloadTemplate()`'s own example rows carried real, budget-year-dependent tax figures (₹2.5 lakhs exemption limit, Rs 10000 u/s 80TTA) — the same class of issue Sprint 8.2 fixed in `helpContent.js`'s prose but missed here since it's a different file. Replaced with timeless structural facts.
- **`create_batch_group` (SQL, live production bug):** never included `group_type` in its INSERT, so every batch group created through the Admin Dashboard's "Create Batch Group" button since whichever change last replaced this function silently got `group_type='custom'` instead of `'batch'` — which disabled `join_group_by_token`'s D-15 approval gate entirely for that batch (any caller, student or staff, joined instantly active, no pending step). All 3 real production batches (CA Final, CA Foundation, CA Intermediate) were confirmed unaffected — already `group_type='batch'`, predating the regression. Fixed to set `group_type='batch'` alongside `is_batch_group=true`; the one bad test row was backfilled.

### Verified
- `npm run build` + `npx eslint` clean on all 4 touched files.
- A1's gate logic verified via a standalone extraction test (8 cases, all passed) — not a live file-upload click-through (the Browser pane tool has no file-upload capability this session).
- A2's corrected template rows re-parsed with the app's own `parseCSVLine` (copied verbatim) — all 10 rows still produce exactly 18 columns.
- B1 live-verified in the Browser pane: the new `/dashboard/groups` link actually navigates there; checked at desktop and 375px mobile width, no overflow, console clean.
- The `group_type` fix live-verified end-to-end: after the fix, a fresh test batch + dummy student account correctly produced a "Pending Batch Requests" row (previously skipped straight to active membership).
- All 3 screenshots manually checked for PII by both the session and the operator before commit.

### Dropped from original scope
- 2 of the originally-planned 5 screenshots (role-change confirmation, Hard Delete confirmation) — both are native browser `confirm()`/`prompt()` dialogs, not custom app UI; not click-through-able by browser automation and not meaningfully screenshot-able even by hand (generic OS chrome, not RevisOp UI).

### Files Changed
- **New:** `public/help-screenshots/admin-batch-create-invite-link.png`, `public/help-screenshots/admin-batch-pending-requests.png`, `public/help-screenshots/admin-batch-archive-filter.png`, `docs/database/sprint8.3/00_DIAGNOSTIC_batch_join_instant_approve.sql`, `docs/database/sprint8.3/01_DIAGNOSTIC_batch_group_type_scope.sql`, `docs/database/sprint8.3/02_FIX_create_batch_group_type.sql`, `docs/database/sprint8.3/03_TEST_verify_batch_group_type_fix.sql`.
- **Changed:** `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/pages/dashboard/Help.jsx`, `src/data/helpContent.js`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/bugs.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`.
- **Database (deployed live by operator):** `create_batch_group` function replaced; 1 row backfilled.

---
## [2026-09-16] chore: repo file cleanup — dead files removed, GuideInfoModal/checklist relocated

Audited the repo for deadweight, duplicates, and misplaced files. Every deletion/move was verified with a fresh repo-wide grep run immediately before acting (not reused from an earlier check), per the project's stated bar for this kind of change: proving nothing imports/links to a file before removing it. `MigrateNoteImages.jsx` was explicitly excluded — a separate SQL check found its migration still incomplete.

### Removed (confirmed zero references, `git rm`)
- `src/pages/professor/ProfessorTools.jsx` — 944-line page, not imported or routed anywhere in `App.jsx`; the `/professor/tools` redirect route itself is unrelated and untouched. Empty `src/pages/professor/` folder went with it.
- `src/assets/react.svg` — default Vite scaffold asset, zero references.
- `recall-favicon.svg` (repo root) — pre-rebrand "Recall" asset, superseded by the RevisOp favicon set; not linked from `index.html` or any code.
- `scripts/export-favicon.js` — reads from `public/logo-concepts/icon-dark-bg.svg`, confirmed missing; superseded by `scripts/export-favicon.cjs`.
- `repomix-output.xml` (repo root, untracked/gitignored) — stale generated dump, plain `rm`, no git action needed.

### Moved
- `src/components/GuideInfoModal.jsx` → `src/components/shared/GuideInfoModal.jsx` — was the only component sitting loose at the `components/` root instead of a themed subfolder. Updated all 3 import sites (`NotePreview.jsx`, `GroupJoin.jsx`, `DeckPreview.jsx`).
- `docs/active/design-review-screenshot-checklist.md` → `docs/active/design-review/screenshot-checklist.md` — grouped with the review outputs it describes, rather than sitting one level up.

### Verified
- `npm run build` and `npx eslint` on all touched files: clean.
- A stale doc claim caught in passing: `blueprint.md`'s pending-work list said `MigrateNoteImages.jsx`'s migration was "complete" — it isn't (12 live notes still have oversized images per an earlier SQL check). Corrected in place rather than left to mislead a future session.

### Files Changed
- **Deleted:** `src/pages/professor/ProfessorTools.jsx`, `src/assets/react.svg`, `recall-favicon.svg`, `scripts/export-favicon.js`.
- **Moved:** `src/components/GuideInfoModal.jsx` → `src/components/shared/GuideInfoModal.jsx`, `docs/active/design-review-screenshot-checklist.md` → `docs/active/design-review/screenshot-checklist.md`.
- **Changed:** `src/pages/public/NotePreview.jsx`, `src/pages/public/GroupJoin.jsx`, `src/pages/public/DeckPreview.jsx`, `docs/active/blueprint.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/active/now.md`.

---
## [2026-09-16] fix: note deletion now cleans up its Storage image (both delete paths)

Discovered during an unrelated file-cleanup audit: deleting a note never removed its image from the `notes` Storage bucket, in either the student (`MyNotes.jsx`) or admin (`AdminDashboard.jsx`) delete path. Confirmed via a `storage.objects`-vs-`notes.image_url` diagnostic (8 orphans, ~47MB) and a trigger audit (no DB trigger covers it either).

### Added
- **`src/lib/noteStorage.js`** — `extractNoteStoragePath(imageUrl)` + `deleteNoteStorageImage(imageUrl)` (best-effort; warns on failure rather than throwing, so it never blocks a note delete that already succeeded).

### Changed
- **`src/pages/dashboard/Content/MyNotes.jsx`** — `handleDelete` now looks up the note's `image_url` before the DB delete, then calls `deleteNoteStorageImage()` after it succeeds.
- **`src/pages/admin/AdminDashboard.jsx`** — `fetchContent()`'s notes query now selects `image_url` (previously omitted); `deleteNote` cleans up storage the same way as `MyNotes.jsx`.

### Verified
- `npm run build` and `npx eslint` on all three files: clean.
- **Not done:** in-browser click-through delete of a real note — destructive against production data, not attempted this session. Operator should confirm on a throwaway note.
- **Not retroactive:** the 8 pre-existing orphaned images require a manual one-time Supabase Dashboard cleanup (no Storage trash/versioning exists — Claude does not perform permanent deletion itself).

### Files Changed
- **New:** `src/lib/noteStorage.js`.
- **Changed:** `src/pages/dashboard/Content/MyNotes.jsx`, `src/pages/admin/AdminDashboard.jsx`, `docs/active/blueprint.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/tracking/bugs.md`, `docs/active/now.md`.

---
## [2026-09-16] docs(sprint-8.2): Help — batch lifecycle corrections + question-type guidance (content-only)

`src/data/helpContent.js` still described the pre-Sprint-8.0 batch-enrollment model (automatic course+institution matching, "Grant Access" auto-enrolling into a batch) and had no real guidance for 7 of the app's 8 question types. Corrected the seven affected sections to match the live Sprint 8.0/8.1 approval + archive/restore flow, and added question-type and CSV documentation that didn't exist before. No product behavior changed — data file only.

### Added
- **`question-types-guide`** (Content tab, all roles) — purpose, one CA example, creator role, dos/don'ts, and how-to-answer for all 8 question types.
- **`prof-question-type-authoring`** (Content tab, professor/admin/super_admin) — manual-authoring field reference for the 5 D-10-gated types (MCQ, Correct/Incorrect, Case study MCQ, Match the following, Fill in the Blank).
- **`bulk-csv-basics`** (Content tab, all roles) — what a CSV is, the real 18-column template, quoting/blank/multiline rules, and which types Bulk Upload does and doesn't support, for any role.

### Changed
- **`prof-welcome`, `prof-profile-setup`, `prof-batch-groups`, `prof-batch-performance`** (professor-guide tab) and **`admin-dashboard-overview`, `admin-access-requests`, `admin-batch-groups`** (admin-guide tab) — removed every "automatic enrollment matches course+institution" claim; now describe the real invite-link + approve/reject + direct-add flow (D-15) and archive/restore lifecycle (D-16). Corrected the Admin Dashboard's tab names to the real ones (Content Moderation / User Management / Access Requests / Batch Groups).
- **`flashcard-creation`** (renamed "Creating Study Items") — rescoped to the 3 open-to-everyone types (Flashcard, Theory, Concept Card), pointing to the new sections for the rest.
- **`prof-bulk-csv`** — rewritten from a stale 2-column "front,back" description (with a fabricated "Maximum 200 cards per upload" limit) to the 4 professor/admin-gated CSV types' real columns, with example rows copied verbatim from the app's own downloadable template.
- **`superadmin-user-roles`, `superadmin-hard-delete`, `superadmin-sa-analytics`** — spot-checked against current `SuperAdminDashboard.jsx`/`SuperAdminAnalytics.jsx` and corrected real drift (wrong button labels/dialogs, wrong deleted-data list, wrong analytics columns/misplaced bullets) — see `bugs.md` for the itemized list.

### Verified
- `npm run build` and `npx eslint src/data/helpContent.js` both clean; 53 sections across 8 tabs, no duplicate ids.
- Every button label, tab name, and behavior claim checked against live component source (`AdminDashboard.jsx`, `GroupJoin.jsx`, `FlashcardCreate.jsx`, `BulkUploadFlashcards.jsx`, `StudyMode.jsx`, `SuperAdminDashboard.jsx`, `SuperAdminAnalytics.jsx`, `src/lib/{mcq,fitb,matchTheFollowing,caseStudyMcq,conceptCard,questionTypes}.js`), not assumed from the prior help text.
- **Live role-based click-through completed same day**, once the operator supplied credentials in the Browser pane (Claude never saw or entered a password) — all four roles confirmed correct, gated sections don't leak, consoles clean.
- **One real bug caught during that live check:** the raw CSV example rows had no spaces after their commas, causing horizontal page overflow (1520px content in a 985px viewport). Fixed same session (see the Quality Auditor follow-up entry above/below for the full correction, since the header-row example needed a different fix than the data rows).

### Files Changed
- **Changed:** `src/data/helpContent.js`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/bugs.md`.

---
## [2026-09-16] fix(sprint-8.2): Quality Auditor follow-up — 6 corrections to Help content (content-only)

A plain-language report of Sprint 8.2 (including the live four-role click-through above) was sent to the operator's Quality Auditor. Six corrections came back and were fixed the same day — three were real factual/functional bugs in the new help text, not just wording preferences.

### Fixed
- **CSV header-row example would have broken on copy-paste.** The wrapping fix applied to the header-row example added a space after every comma — but `BulkUploadFlashcards.jsx`'s parser never trims header names (only cell values), so a literal copy-paste would have produced unmatched keys like `" subject"`. Removed that one raw line (the column list is already covered by prose bullets; the exact header is one click away via "Download the Template"). Data-row examples were untouched — those values *are* trimmed, so they were never actually broken.
- **`prof-question-type-authoring` wrongly implied `match_the_following` supports Bulk Upload.** Its opening sentence grouped all 5 gated types under "manual creation and Bulk Upload" — false for Match the following, which CSV has never supported for any role. Reworded to carve it out.
- **A tip overgeneralized Fill in the Blank's grading.** "These five types... a wrong verdict automatically marks the card Hard" is true for the other four gated types but false for FITB, which never has a "wrong" verdict (D-13) — only a match or a self-graded fallback. Split into two sentences so FITB's real mechanism isn't misdescribed.
- **Hard Delete claimed an unverified guarantee.** "so a record survives even if the delete itself fails partway" was never actually confirmed (a shared transaction could roll both operations back together). Replaced with the Auditor's suggested wording: "The system attempts to record the action before deletion runs." Also dropped the `admin_audit_log` table-name reference from user-facing text.
- **`admin-batch-groups` never said where to view a batch's actual performance report.** It covered membership/lifecycle management only; added a cross-reference to the report-viewing surface (Study Groups → the batch → GroupDetail, shared with professors).
- **Tax examples with no year/regime.** Swapped every example that was original prose (not copied from the app) to timeless alternatives (a percentage question, an "AS 1" reference) already used elsewhere in the app's own template. The literal CSV example rows genuinely copied verbatim from the real downloadable template were left as-is (changing them would break the "guaranteed to match the real download" property) — added a caveat tip next to them instead. The app's own template carrying the same unqualified tax figures is logged separately in `bugs.md` as a small future fix, out of scope here.

### Deferred, not skipped
- Annotated screenshots (Auditor recommendation) and in-app navigation hyperlinks (operator request) both require extending `Help.jsx`'s renderer (no image block, no link parsing today) — real feature work, not a content edit. Bundled into one follow-up sprint per the operator's decision; logged in `blueprint.md`'s Pending Work (Immediate).

### Verified
- `npm run build` and `npx eslint src/data/helpContent.js` clean. Re-checked all four roles live again in the Browser pane after the fixes — no leaks, corrected CSV examples still parse, no overflow at desktop or 375px mobile.

### Files Changed
- **Changed:** `src/data/helpContent.js`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/bugs.md`.

---
## [2026-09-15] test(sprint-8.1): Quality Auditor follow-up — snapshot atomicity + frozen-report verification (✅ 7/7 PASS)

Quality Auditor review of the Sprint 8.1 completion report asked whether three specific scenarios were verified before sign-off: simultaneous actions during archiving, snapshot-capture failure leaving no partial state, and real later student activity not leaking into an archived batch's frozen report. Honest answer: the first two were genuinely untested despite the original 33 checks looking thorough. Closed the two closeable ones same day.

### Added
- **`docs/database/sprint8.1/08_TEST_auditor_followup.sql`** — new test, 7/7 PASS:
  - **Snapshot-capture failure → no partial state.** A transaction-scoped fault-injection trigger (same proven pattern as `sprint7.4/04_TEST`) forces the snapshot `INSERT` to fail; confirms the batch stays active, the membership is untouched, and no orphaned snapshot row is created.
  - **Frozen report vs. genuine later activity — not a proxy.** Real `reviews` rows inserted for a real student: one before archiving is captured in the snapshot; a second inserted strictly after archiving does not change the already-saved snapshot, while the live reporting path (unaffected by archiving) correctly reflects both.

### Not resolved, disclosed as a residual
- **Genuine concurrent-session locking** — still not completed. True concurrency needs two independently-open database connections; the two-tab manual approach (`05_TEST_concurrency_manual.sql`) already failed repeatedly on human-timing coordination, never on a code bug. An automated single-script alternative via `dblink` was considered and rejected — it would require embedding a database password. The `FOR UPDATE` lock-first pattern used throughout is standard and correct by construction, but has not been demonstrated against a real race.

### Files Changed
- **New:** `docs/database/sprint8.1/08_TEST_auditor_followup.sql` (✅ run, 7/7 PASS).
- **Changed:** `docs/active/blueprint.md`, `docs/active/now.md`.

---
## [2026-09-15] feat(sprint-8.1): batch group Active/Archived lifecycle (✅ SQL deployed & verified 33/33 PASS; committed `6bc1796`)

Complete Active/Archived workflow for institution batch groups: archiving stops new requests/invitations/approvals/direct-adds and drops the batch from active monitoring, while approved memberships, shared-content access, and student accounts/progress are untouched, and the batch's report is frozen as a server-side snapshot rather than left to keep following live activity. Restore reopens the same batch without rebuilding memberships. Full design decision: blueprint.md §3.1 D-16.

### Added
- **`study_groups.archived_at timestamptz`** (NULL = active) + `archived_by`. Set/cleared exclusively by the two new RPCs below — RLS narrowed to block direct client writes.
- **`study_group_members.status`** gains `'closed'` (alongside `invited`/`active`/`requested`), plus `closed_at`/`closed_reason` — archiving closes outstanding `requested`/`invited` rows to this status instead of deleting them or leaving them live.
- **`batch_group_archives`** table — one jsonb snapshot row per archive event (group metadata + `get_batch_group_member_stats`'s own rows, reused rather than reimplemented). RLS enabled, zero client-facing policies — read only through the new RPC below. A restore-then-re-archive cycle adds a new row; earlier snapshots are retained.
- **`archive_batch_group(p_group_id)` / `restore_batch_group(p_group_id)`** — admin-only, `SECURITY DEFINER`, both lock the batch row (`FOR UPDATE`) before acting, both idempotent. Archive captures the snapshot, sets `archived_at`, and closes outstanding requests/invitations, all in one transaction.
- **`get_batch_group_archive(p_group_id)`** — reads the snapshot for the batch's current archive event. Gated identically to `get_batch_group_member_stats` (professor/admin/super_admin only).
- **`AdminDashboard.jsx`** — Active/Archived pill filter on the batch tab, per-row Archive/Restore buttons with confirmation dialogs, disabled while saving.
- **`GroupDetail.jsx`** — archived batches show the frozen snapshot (via `get_batch_group_archive`) instead of live stats, with an "Archived on [date]" label.
- **`GroupJoin.jsx`** — "This batch has ended" replaces the join CTA for an archived batch's invite link; the RPC already suppresses stats in that case.

### Changed
- **`join_group_by_token`, `enroll_user_in_batch_group`, `approve_batch_join_request`, `reject_batch_join_request`** — each now locks the target batch row under the same convention as archive/restore and refuses once `archived_at` is set. `join_group_by_token`'s `'requested'` insert now reactivates a `'closed'` row (post-restore explicit re-request) instead of only ever no-op'ing.
- **`get_group_preview`** — additive `is_batch_group`/`archived_at`; `stats` returns `null` when the batch is archived (public previews never expose activity data for an ended batch).
- **`get_admin_batch_groups()`** — additive `archived_at` (still returns both, AdminDashboard filters client-side). **`get_my_batch_groups()`** — now excludes archived batches (a monitoring list, not the management view).
- **`get_group_detail`** — additive `archived_at` on the returned group object.
- **`leave_group`** — its last-active-member cascade-delete no longer applies to batch groups (previously true for any group); ordinary-group behavior unchanged.

### Fixed (pre-existing gaps found during pre-flight, unrelated to this sprint's own design but directly relevant to "prevent bypasses")
- **`sg_delete_creator`, `sg_update_creator` (RLS on `study_groups`)** — neither had an `is_batch_group` clause; a batch group's creating admin could delete it directly, or write `archived_at` via a plain client `.update()`, bypassing the snapshot transaction entirely. Both narrowed to `is_batch_group = false` — safe, since batch groups have no direct-edit UI to lose.
- **`sgm_insert_admin` (RLS INSERT on `study_group_members`)** — no archived check; a client with local group-admin rights could insert a member into an archived batch past `enroll_user_in_batch_group`'s own guard. Closed with an `archived_at IS NOT NULL` exclusion.

### Files Changed
- **New:** `docs/database/sprint8.1/{00_DIAGNOSTIC_preflight,01_SCHEMA_add_archiving,02_FUNCTIONS_archive_restore,03_FUNCTIONS_guard_enrollment_paths,04_TEST_verify_archiving,06_FIX_archive_timestamp_precision,07_DIAGNOSTIC_rls_delete_investigation}.sql` (✅ deployed, `04_TEST` 33/33 PASS). `05_TEST_concurrency_manual.sql` attempted but not completed — the manual two-tab live-session procedure proved too fragile to coordinate reliably; not pursued further given `04_TEST`'s coverage of the same guards.
- **Changed:** `src/pages/admin/AdminDashboard.jsx`, `src/pages/dashboard/Groups/GroupDetail.jsx`, `src/pages/public/GroupJoin.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`.

---
## [2026-09-15] fix(sprint-8.0): Quality Auditor follow-up — monitoring disclosure + retire auto-enroll trigger (⏳ SQL not yet deployed)

Same-day follow-up after the Sprint 8.0 completion report was reviewed by the operator's Quality Auditor. Three points raised, all addressed:

### Added
- **`GroupJoin.jsx`** — batch groups only: a notice that joining shares the student's study activity and progress with that batch's institution. Not shown for custom (non-batch) groups, which carry no monitoring relationship.

### Removed
- **`fn_auto_enroll_batch_group` trigger and function** — fully dropped (`docs/database/sprint8.0/04_SCHEMA_retire_auto_enroll_trigger.sql`). Its last remaining branch (removing a student from their old matched batch group on a course-level change) used the same course+institution guessing the "add" branch was already stripped of earlier today — a course change could have silently removed a student from the wrong batch. With both branches gone the function did nothing, so it was retired rather than patched. Batch membership removal is now exclusively the pre-existing explicit `remove_group_member`/`leave_group` action.

### Noted, not built
- Automated "inactive student" nudges were never part of this sprint. Recorded in blueprint.md D-15: any future nudge feature must not equate "no recorded activity in RevisOp" with "not studying."

### Files Changed
- **New:** `docs/database/sprint8.0/{04_SCHEMA_retire_auto_enroll_trigger,05_TEST_verify_trigger_retired}.sql` (⏳ not yet run by operator).
- **Changed:** `src/pages/public/GroupJoin.jsx`, `docs/active/blueprint.md`, `docs/active/now.md`.

---
## [2026-09-15] feat(sprint-8.0): batch invite-link joining with admin approval (SQL deployed & verified 20/20 PASS; ⏳ not yet committed)

Replaces guess-based batch enrollment (matching a student's `course_level`+`institution` to "the" batch group) with explicit approval, after a pre-flight found this could enroll a student into the wrong batch once multiple batches share a course+institution (real scenario for multi-cohort B2B classes, e.g. separate May/Sept attempt batches). Full design decision: blueprint.md §3.1 D-15.

### Added
- **`study_group_members.status`** gains `'requested'` (student self-requested via batch invite link, awaiting admin approval — opposite direction from `'invited'`).
- **`approve_batch_join_request(p_membership_id)`, `reject_batch_join_request(p_membership_id)`** — admin approves/rejects one pending request. `is_admin()` guard.
- **`get_admin_pending_batch_requests()`** — admin's pending-request queue across all batch groups. `is_admin()` guard.
- **AdminDashboard.jsx** — "Pending Batch Requests" table (Approve/Reject), "Copy Invite Link" per batch group, `BatchGroupPicker` (explicit student+batch dropdown, no guessing) next to enrolled users.
- **GroupJoin.jsx** — shows batch course/institution, "Request to Join" wording + pending-approval message for batch groups.

### Changed
- **`join_group_by_token(p_token)`** — return type `uuid` → `jsonb` (`{group_id, status}`). For a batch group joined by a student, inserts `status='requested'` (idempotent) instead of activating; a pre-existing `'invited'` row flips straight to `'active'`. Never writes `profiles.course_level`/`institution`. Unchanged for non-batch groups and non-student callers.
- **`get_group_preview(p_token)`** — additive fields `group_type`/`batch_course`/`batch_institution`/`viewer_status`.
- **`get_admin_batch_groups()`** — additive `invite_token` column (wasn't returned before).
- **`create_batch_group(...)`** — now creates the `study_groups` row only, no bulk auto-add of matching students (pending or active). Also gained an `is_admin()` guard it was missing entirely (any authenticated user could previously call it — same bug class already fixed for `enroll_user_in_batch_group`/`notify_access_granted`, security/15).
- **`enroll_user_in_batch_group(...)`** — signature changed to `(p_user_id, p_group_id)`, explicit group instead of guessed from course+institution; raises `'Not a batch group'` if `p_group_id` isn't one. Admin's explicit pick activates `status='active'` immediately.
- **`fn_auto_enroll_batch_group()`** (the `profiles` trigger) — no longer creates any membership. Cleanup-only now: still removes membership from a student's *old* matched batch group on a course-level change (kept — removes real membership, doesn't generate a guessed one; flagged as carrying the same theoretical wrong-group risk on that removal lookup, not fixed this sprint).

### ✅ Verified — `03_TEST_verify_batch_approval_workflow.sql`, 20/20 PASS
Every `[CRITICAL]` check included: join never writes `profiles.course_level`/`institution`; repeated self-request idempotent (1 row); approve/reject atomic + admin-gated; an unapproved (`'requested'`) member blocked from `get_group_detail`; explicit admin-add activates immediately with no guessing; a bogus `p_group_id` raises rather than silently matching; old-group cleanup still works; `create_batch_group` creates zero membership rows; non-admin callers blocked on every admin-only RPC.

### Files Changed
- **New:** `docs/database/sprint8.0/{01_SCHEMA_add_requested_status,02_FUNCTIONS_batch_join_approval,03_TEST_verify_batch_approval_workflow}.sql` (all 3 ✅ run against production).
- **Changed:** `src/pages/public/GroupJoin.jsx`, `src/pages/admin/AdminDashboard.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`.

---
## [2026-09-14] fix: skip_card/suspend_card atomic upsert — closes a live 23505 race condition (SQL deployed & verified 7/7 PASS; ⏳ not yet committed)

Found live while verifying Sprint 7.12 (unrelated). `StudyMode.jsx`'s "Skip 24hr" threw `23505 duplicate key value violates reviews_user_flashcard_unique` on a never-reviewed card. Both `skip_card` and `suspend_card` wrote `reviews` via a non-atomic `UPDATE ...; IF NOT FOUND THEN INSERT ...` — safe for one call, but a TOCTOU race under concurrent calls (none of StudyMode's 5 "Skip 24hr" buttons disable while the RPC is in flight). Fixed by rewriting both as a single atomic `INSERT ... ON CONFLICT (user_id, flashcard_id) DO UPDATE`. Pure SQL fix — no frontend change needed, the race lived entirely in the RPC.

### Fixed
- **`skip_card(p_user_id, p_flashcard_id)`, `suspend_card(p_user_id, p_flashcard_id)`** (`docs/database/bugfixes/17_FUNCTIONS_skip_suspend_card_atomic_upsert.sql`) — atomic `ON CONFLICT DO UPDATE` upsert replaces the non-atomic `UPDATE`/`IF NOT FOUND INSERT` pair. IDOR guard, timezone logic, search_path reproduced verbatim from the live body (confirmed via `16_DIAGNOSTIC` before deploying — matched `docs/database/bugfixes/09_FUNCTIONS_fix_skip_suspend_card_reviews_columns.sql` exactly, no undocumented drift).

### ✅ Verified — `18_TEST_verify_skip_suspend_atomic_upsert.sql`, 7/7 PASS
Calling each function twice in a row on the same never-reviewed card (the deterministic path a real race's "loser" call takes) — no error, exactly one `reviews` row survives. IDOR regression re-confirmed (cross-user call still rejected).

### Files Changed
- **New:** `docs/database/bugfixes/{16_DIAGNOSTIC_skip_card_race_condition,17_FUNCTIONS_skip_suspend_card_atomic_upsert,18_TEST_verify_skip_suspend_atomic_upsert}.sql` (all 3 ✅ run against production).
- **Changed:** `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/tracking/bugs.md`.

---
## [2026-09-14] feat(sprint-7.12): concept_card structured authoring + browse-only viewer + StudyMode leak fix (get_browsable_decks v6 deployed & verified 5/5 PASS; frontend live-verified end to end; ⏳ not yet committed)

Phase 7, last type in the roster. Concept cards are browse-only reference material — no grade, no rung, no `reviews` row, ever (D-06). `npm run build` clean; `npx eslint` clean on every changed file (same 2 pre-existing `FlashcardCreate.jsx` baseline errors reconfirmed).

### Fixed — StudyMode leak (D-06 violation, closed before it ever hit real content)
`get_study_queue` already excluded `concept_card` from the *due*-set (since Sprint 6.0). The actual gap was `StudyMode.jsx`'s separate "due OR never-reviewed" fallback filter, which didn't check `question_type` — since a concept card by definition has no `reviews` row, it passed the "never-reviewed → new card" fallback and could reach a student in the plain flashcard flip UI, gradeable via `apply_review`. Pre-flight confirmed 0 `reviews`/`review_events` rows ever existed for `concept_card` — a live gap, not a live incident. Fixed with one added `c.question_type !== 'concept_card'` clause in the same filter. Live-verified by replaying the exact fetch pipeline against the live DB: the test concept card was present in the deck's raw card set (never-due, never-reviewed — exactly the leak condition) but absent from the final filtered study list.

### Added
- **`src/lib/conceptCard.js`** (new) — `buildConceptOptions()` (drops any `{term, definition}` row missing either half), `validateConceptTerms()`, `emptyConceptTerm()`/`emptyConceptTerms()`. `CONCEPT_MIN_TERMS`=1, `CONCEPT_MAX_TERMS`=10.
- **"Concept Card" question-type option** in `FlashcardCreate.jsx`, **ungated** (open to all users, like flashcard/theory — nothing is ever graded, so there's no authoring-judgment risk to gate against). Front label "Concept Name", Back label "Summary", plus a repeatable Key Terms (term + definition) list editor. No "Why" field.
- **`src/components/flashcards/ConceptCardViewer.jsx`** (new) — read-only accordion modal (heading always visible, click expands to summary + keyTerms), fetched via the 5-column deck-membership join (D-04) scoped to `question_type='concept_card'`. Zero grade buttons, zero `apply_review` calls.
- **"Read Concepts" button** on `ReviewFlashcards.jsx` (Browse Study Sets) deck tiles with `has_concept_card=true`, opening the new viewer.

### Changed
- **`src/lib/questionTypes.js`** — `concept_card` added to `BROWSABLE_QUESTION_TYPES` and `formatQuestionType()`. Deliberately NOT added to `GRADED_QUESTION_TYPES`.
- **`get_browsable_decks` v6** (`docs/database/sprint7.12/01_FUNCTIONS_get_browsable_decks_v6_has_concept_card.sql`) — additive `has_concept_card BOOLEAN` return column, computed in the same visibility-filtered lateral subquery that already computes `visible_card_count`. DROP+CREATE (return-shape change). ✅ Deployed; `02_TEST` — 5/5 PASS.
- **`BulkUploadFlashcards.jsx`** — comment-only: documents why `concept_card` bulk upload is explicitly deferred (variable-length `{term, definition}` pairs don't fit the flat CSV convention cleanly, same call as `match_the_following` in 7.8-C).

### ✅ Live verification — done 14/09/2026 (dev server → live Supabase, professor session)
Authored a real concept card (Auditing & Ethics → Audit Evidence, same topic as 28 pre-existing gradeable cards) with 2 key terms. Confirmed representation via direct REST read (`options` = `[{term,definition}, ...]`, `correct_answer`/`explanation`/`scenario`/`subtype` all null). "Study" on that deck served only the 24 due/new gradeable cards (verified via pipeline replay, not just UI click-through — the Skip-24hr button hit an unrelated pre-existing bug, flagged separately). "Read Concepts" opened correctly with both key terms rendered (including a colon inside a definition, validating the bulk-upload-deferral reasoning). Zero `reviews` rows ever created for the concept card, confirmed via direct REST read before and after all testing. Console clean aside from the unrelated skip-card bug. QA row deleted after verification (operator confirmed).

### Out-of-scope bug found, fixed same day as a dedicated follow-up
`StudyMode.jsx`'s Skip-24hr action threw `23505 duplicate key value violates reviews_user_flashcard_unique`. Discovered incidentally during this sprint's live verification; unrelated to concept_card. Root cause and fix: see the `fix: skip_card/suspend_card atomic upsert` entry above.

### Files Changed
- **New:** `src/lib/conceptCard.js`, `src/components/flashcards/ConceptCardViewer.jsx`, `docs/database/sprint7.12/{00_DIAGNOSTIC_preflight,01_FUNCTIONS_get_browsable_decks_v6_has_concept_card,02_TEST_verify_get_browsable_decks_v6}.sql`.
- **Changed:** `src/lib/questionTypes.js`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/pages/dashboard/Study/ReviewFlashcards.jsx`, `docs/active/blueprint.md`, `docs/reference/{DATABASE_SCHEMA,FILE_STRUCTURE}.md`, `docs/active/now.md`, `docs/tracking/bugs.md`.

---
## [2026-09-14] feat(sprint-7.11): fitb authoring + confidence-gated grading (zero SQL needed; frontend live-verified end to end; ⏳ not yet committed)

Phase 7, the last of the 5 D-10-gated types (`mcq`/`correct_incorrect`/`case_study_mcq`/`match_the_following`/`fitb`) to get a real authoring path. `fitb`'s verdict is confidence-gated, not binary (D-13) — a matching typed answer is confident-correct (`is_correct=true`), a non-matching one is NEVER treated as wrong, falling back to a full free-recall self-grade (`is_correct=NULL`). There is no "confident-wrong" state; no code path submits `is_correct=false` for this type. `npm run build` clean; `npx eslint` clean on every changed file (same 2 pre-existing `FlashcardCreate.jsx` baseline errors + 1 warning reconfirmed).

### Task 0 — verified the 7.10 bulk-upload gap first
Uploaded a real 3-row/1-`case_group` `case_study_mcq` CSV through `BulkUploadFlashcards.jsx` as a professor. Confirmed live: all 3 rows shared one `batch_id`, one byte-identical `scenario`, correct per-row `correct_answer`/`options`/`back_text`. **The 7.10 bulk-upload path was not broken.** Bonus find: the template's `descriptive_case_study` example row had a pre-existing unquoted-comma bug in its `back` field, corrupting that row's CSV column count — fixed by quoting it.

### Added
- **`src/lib/fitb.js`** (new) — `normalizeFitbAnswer()` (trim/lowercase/strip punctuation/collapse whitespace — the one function called identically on the student's typed answer and every authored acceptable answer), `isFitbMatch()`, `deriveFitbBackText()`, `validateFitbBlank()`/`validateFitbOptions()`/`compactFitbOptions()`, `splitFitbSentence()`. `FITB_BLANK_PATTERN`/`FITB_BLANK_PLACEHOLDER` (`______`, 3+ underscores), `FITB_MIN_ANSWERS`/`FITB_MAX_ANSWERS` (1/6).
- **"Fill in the Blank" question-type option** in `FlashcardCreate.jsx`, gated professor/admin/super_admin (D-10) — sentence-with-blank textarea (blank-marker validated at submit time) + a repeatable 1-6-row acceptable-answers list editor + Why textarea.
- **Bulk upload support** in `BulkUploadFlashcards.jsx` — built, not deferred: new `fitb_answers` CSV column, semicolon-delimited within one cell.
- **fitb render branch** in `StudyMode.jsx`, checked before `GRADED_QUESTION_TYPES` (same reasoning as `match_the_following` in 7.8): sentence rendered with an inline `<input>` where the blank goes, a Submit action running the match check, then either grading path (match/no-match) converging on the same unmodified `GradeButtonRow`.

### Changed
- **`src/lib/questionTypes.js`** — `fitb` added to `BROWSABLE_QUESTION_TYPES` only, deliberately NOT `GRADED_QUESTION_TYPES` (its three-way confidence-gated verdict isn't the clean binary that array assumes).
- **`FlashcardCreate.jsx`** — `isD10GatedType()` extended with `|| qt === 'fitb'` (fitb isn't in `GRADED_QUESTION_TYPES`, so a role-downgraded draft restore needed the explicit check, same gap `match_the_following` already had a fix for).
- **`BulkUploadFlashcards.jsx`** — new `isCsvGradedType()` helper (`GRADED_QUESTION_TYPES.includes(qt) || qt === 'fitb'`) drives the `options`/`explanation` row-building; `correct_answer` deliberately stays keyed off `GRADED_QUESTION_TYPES` alone so fitb's stays NULL, not a stringified `"null"`. The `42501` RLS-rejection error message now names `fitb` too.

### ✅ Live verification — done 14/09/2026 (dev server → live Supabase, professor session)
Authored a real fitb card (Income Tax → Overview and Basic Concepts). **Match path:** typed a differently-cased/punctuated variant of an accepted answer → revealed in navy (matched), graded Easy → `reviews.rung` advanced normally (7-day interval) and `get_question_type_performance` returned `graded_count=1, answer_accuracy_pct=100`, confirming `is_correct=true` was actually written. **No-match path** (after `reset_card`): typed a non-matching answer → revealed underlined with an "ACCEPTED ANSWERS" box, same full self-grade, graded Medium → `reviews.rung` still advanced normally (3-day interval, **not forced to rung 0**). The analytics aggregate's unchanged `graded_count=1`/`answer_accuracy_pct=100` after this second review is mathematically only consistent with the second event's `is_correct` being `NULL`, not `false` — a `false` second event would have pushed accuracy to 50%, which did not happen. Console clean. All 4 QA rows (3 case_study_mcq + 1 fitb) deleted after verification.

### Files Changed
- **New:** `src/lib/fitb.js`.
- **Changed:** `src/lib/questionTypes.js`, `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx` (+ one incidental template-CSV bugfix predating this sprint), `src/pages/dashboard/Study/StudyMode.jsx`, `docs/active/blueprint.md`, `docs/reference/{DATABASE_SCHEMA,FILE_STRUCTURE}.md`, `docs/active/now.md`.

---
## [2026-09-14] feat(sprint-7.10): case_study_mcq authoring + StudyMode rendering (zero SQL needed, pre-flight confirmed live 3/3; frontend live-verified end to end; ⏳ not yet committed)

Phase 7, first genuinely new feature-building sprint since 7.8 (7.9 was pure hygiene). `case_study_mcq`: a shared scenario narrative followed by 2-8 independently-gradeable mcq questions — each its own `flashcards` row (own SRS card, own rung, own schedule), scenario text duplicated across every row sharing the case's `batch_id` (D-01 pattern) so it renders on any review day without a JOIN. Renders through the **same shared `AnswerOption`/hybrid-grading branch as mcq** (`case_study_mcq` added to `GRADED_QUESTION_TYPES`), not a new mechanic — the only new UI is a collapsible "CASE SCENARIO" block above the question. `npm run build` clean; `npx eslint` clean on every changed file (same 2 pre-existing `FlashcardCreate.jsx` baseline errors + 1 warning reconfirmed via `git stash` to predate this sprint).

### Pre-flight — `docs/database/sprint7.10/00_DIAGNOSTIC_preflight.sql` — ✅ run by the operator, all 3 checks PASS
Live `chk_flashcards_question_type`: the 8-value enum docs already claimed, `case_study_mcq` included. Both `flashcards_gate_verdict_types_insert`/`_update` RESTRICTIVE policies' `with_check`: `case_study_mcq` present in both IN-lists (D-12's Sprint 7.9 migration only removed `integrated_case`, confirmed not to have touched `case_study_mcq`). `scenario` non-null count: 0 — confirmed genuinely unused before this sprint activated it. This session has only the anon key — no `pg_catalog`/`pg_policy` introspection access — so the operator ran this in the Supabase SQL Editor.

### Real finding: zero SQL needed
Same outcome as `true_false`/`correct_incorrect` (7.7) and `match_the_following` (7.8) — `case_study_mcq` was already a live CHECK-constraint value and already in the D-10 gate's IN-list since Sprint 7.5, before any authoring UI existed for it. This sprint only builds the authoring surface + StudyMode rendering.

### Added
- **`src/lib/caseStudyMcq.js`** (new) — `emptyCaseQuestion()`, `validateCaseStudy()` (scenario + 2-8 mcq-shaped question blocks, each validated via `validateMcqOptions()` from `src/lib/mcq.js`), `CASE_MIN_QUESTIONS`/`CASE_MAX_QUESTIONS`/`CASE_DEFAULT_QUESTIONS` (2/8/3).
- **"Case study MCQ" question-type option** in `FlashcardCreate.jsx`, gated professor/admin/super_admin (D-10) — one shared Scenario textarea + a repeatable mcq-shaped question-block editor. On save, one authoring block fans out into N `INSERT` rows sharing one `batch_id`/`scenario`/`subject_id`/`topic_id`.
- **Bulk upload support** in `BulkUploadFlashcards.jsx` — built, not deferred (unlike match_the_following's 7.8-C deferral): new `scenario` + `case_group` CSV columns. Rows sharing a `case_group` value (unique per case within the file) resolve client-side into one shared `batch_id`, separate from the file-wide `batch_id` every other bulk-uploaded row in the same CSV shares.
- **Collapsible "CASE SCENARIO" block** in `StudyMode.jsx`, rendered above the question when `currentCard.scenario` is present, open by default, reset to open on every card change.

### Changed
- **`src/lib/questionTypes.js`** — `GRADED_QUESTION_TYPES` → `['mcq','correct_incorrect','case_study_mcq']`; `case_study_mcq` added to `BROWSABLE_QUESTION_TYPES` (already had a `formatQuestionType` label — "Case study MCQ" — from Sprint 6's original type-documentation pass).
- **`FlashcardCreate.jsx`** — toast now counts actual inserted rows (`flashcardsToInsert.length`) instead of authoring blocks (`flashcards.length`), so a 1-block/3-question case correctly reports "3 study item(s) created" — a pre-existing accuracy gap this sprint's fan-out made visible, fixed for all types, not just case_study_mcq. `isD10GatedType()` on draft-restore already covers `case_study_mcq` via the widened `GRADED_QUESTION_TYPES`.

### Files Changed
- **New:** `src/lib/caseStudyMcq.js`, `docs/database/sprint7.10/00_DIAGNOSTIC_preflight.sql`.
- **Changed:** `src/lib/questionTypes.js`, `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `docs/active/blueprint.md`, `docs/reference/{DATABASE_SCHEMA,FILE_STRUCTURE}.md`, `docs/active/now.md`.

---
## [2026-09-14] fix(sprint-7.9): Schema hygiene — test_your_understanding collapse, explanation column split, integrated_case removal, true_false removal (SQL deployed & verified live, 30/30 PASS across two test files; frontend live-verified end to end; ⏳ not yet committed)

Phase 7, schema hygiene sprint. Four small, independent items — three resolved as decisions during earlier Phase 7 design work, a fourth (item 4) raised by Anand mid-session, right after items 1-3 had already shipped: `test_your_understanding` never was a real distinct type (duplicated `theory`+`subtype`, same fix the CA Revision Portal's own D14 already made); grading-rationale text and free-recall "key takeaways" were sharing one column (`points_to_remember`) since Sprint 7.5/7.8; `integrated_case` was a live CHECK-constraint value with no authoring UI or StudyMode rendering ever built for it; `true_false` and `correct_incorrect` were mechanically-identical siblings (CA Revision Portal's own schema docs say so explicitly) with a 6-vs-0 real-usage skew toward `correct_incorrect` in that project's live content. `npm run build` clean; `npx eslint` clean on every changed file (same 2 pre-existing `FlashcardCreate.jsx` baseline errors reconfirmed).

### Pre-flight — ✅ run by the operator 14/09/2026, all 7 checks with real numbers
This session has only the anon key — no `pg_catalog`/`pg_policy` introspection access — so `docs/database/sprint7.9/00_DIAGNOSTIC_preflight.sql` was run by the operator in the Supabase SQL Editor. Live CHECK constraint had 11 values; `test_your_understanding` had 2 rows, `integrated_case` had 0; `points_to_remember` was non-null on 10 more rows (4 mcq, 2 true_false, 2 correct_incorrect, 2 match_the_following); `subtype` was 0 non-null; both D-10 RESTRICTIVE policies' IN-lists still listed `integrated_case`. **The operator confirmed all 12 affected rows (2 + 10) were Claude-authored QA/testing artifacts from Sprints 7.5-7.8's live verification passes, not real content**, and chose (via AskUserQuestion) to delete them rather than classify-and-migrate — real IDs were pulled live and hardcoded into the DELETE.

### SQL — `docs/database/sprint7.9/{01_SCHEMA_sprint7.9_hygiene,02_TEST_verify_sprint7.9}.sql`
One migration: `DELETE` the 12 known rows by explicit ID → `DROP`/re-`ADD CONSTRAINT chk_flashcards_question_type` without `test_your_understanding`/`integrated_case` (9 remaining values) → `ALTER POLICY` both D-10 RESTRICTIVE policies to drop the stale `integrated_case` mention → `ADD COLUMN explanation jsonb`. No backfill needed — every row that would have needed migrating was one of the 12 deleted. `02_TEST` mirrors Sprint 7.5's self-contained `BEGIN...ROLLBACK` + role-impersonation pattern: **17/17 PASS**, including a D-10 regression re-check (student `mcq` insert still rejected, professor's still succeeds) since the `ALTER POLICY` rewrote the whole `WITH CHECK` expression rather than just removing a substring.

### ✅ Live verification (items 1-3) — done 14/09/2026 (dev server → live Supabase, professor session)
Question Type selector confirmed exactly 6 options with `test_your_understanding` gone. Authored one `theory` card per subtype value (`pure_theory`, `descriptive_case_study`) — required-field validation held, both persisted correctly (confirmed via a direct Supabase client read). Authored a fresh `mcq` card with a "Why" explanation — confirmed `explanation` populated and `points_to_remember: null` on the row, then studied it live: the WHY block rendered the explanation text correctly post-reveal. `integrated_case` uninsertability confirmed via `02_TEST`'s CHECK-violation assertion (no UI path ever existed to it). Console clean. The 3 rows created during this verification pass were themselves QA artifacts and were deleted afterward, same as the earlier 12.

### Item 4 — `true_false` removed, merged into `correct_incorrect` (D-14)
Raised by Anand mid-session, noticing `true_false`/`correct_incorrect` look like the same type twice. CA Revision Portal's own `docs/SCHEMA.md` documents `correct_incorrect`'s renderer as "Identical to `true_false`, with Correct/Incorrect buttons instead" — a real-usage census of that project's live chapter files found `correct_incorrect` used 6× vs `true_false`'s 0× (its only occurrence sat in an orphaned legacy file no page loads). D-14 drafted in `blueprint.md` §3.1. Pre-flight (`03_DIAGNOSTIC_preflight_true_false_removal.sql`) confirmed 0 rows for both types, no `srs_ladder_curves` rows for either, no RPC hardcoding the string — a pure narrowing migration. `04_SCHEMA_true_false_removal.sql` deployed: narrows the CHECK constraint to 8 values, drops `true_false` from both D-10 RESTRICTIVE policies. `05_TEST_verify_true_false_removal.sql` — **13/13 PASS**, including a D-10 regression re-check post-`ALTER POLICY`. Frontend: `isTwoWayVerdictType()` retired (only one member left, collapsed to a direct equality check at 6 call sites) in `FlashcardCreate.jsx`/`BulkUploadFlashcards.jsx`. Live-verified: selector shows exactly 5 options, a fresh `correct_incorrect` card authored and studied end-to-end (reveal, WHY block, grading), console clean; test row deleted afterward.

### Added
- **`flashcards.explanation`** (jsonb, nullable) — grading-rationale text for graded types, split off `points_to_remember`.
- **`THEORY_SUBTYPE_LABELS`** (`src/lib/questionTypes.js`) — `pure_theory`/`descriptive_case_study`, activating the previously-inert `subtype` column.
- **Subtype `<Select>`** in `FlashcardCreate.jsx`, required for `question_type='theory'`, rendered below the Back textarea.
- **`subtype` CSV column** in `BulkUploadFlashcards.jsx`'s template, required for `theory` rows.

### Changed
- **`chk_flashcards_question_type`** — narrowed from 11 to 8 values (`test_your_understanding`, `integrated_case`, `true_false` all removed).
- **`flashcards_gate_verdict_types_insert`/`_update`** — `integrated_case` and `true_false` both dropped from both RESTRICTIVE policies' IN-lists (cosmetic; the CHECK constraint alone already made each uninsertable).
- **`FlashcardCreate.jsx`/`BulkUploadFlashcards.jsx`** — graded types (`mcq`/`correct_incorrect`/`match_the_following`) now write their "Why"/explanation text to `explanation` instead of `points_to_remember` (same `toPointsToRemember()` helper, different target field). `test_your_understanding` and `true_false` both removed from the type selector / `RECOGNIZED_QUESTION_TYPES`; a stale pre-7.9 draft carrying `test_your_understanding` now restores to `theory`. `isTwoWayVerdictType()` retired.
- **`StudyMode.jsx`** — both post-reveal WHY blocks (`GRADED_QUESTION_TYPES` branch, `match_the_following`'s `MatchZone` branch) now read `currentCard.explanation` instead of `currentCard.points_to_remember`.
- **`src/lib/questionTypes.js`** — `test_your_understanding`/`integrated_case`/`true_false` all removed from `formatQuestionType`/`BROWSABLE_QUESTION_TYPES` (all now-uninsertable, no fallback label worth carrying); `GRADED_QUESTION_TYPES` → `['mcq','correct_incorrect']`; `VERDICT_OPTION_LABELS` down to one entry.

### Files Changed
- **New:** `docs/database/sprint7.9/{00_DIAGNOSTIC_preflight,01_SCHEMA_sprint7.9_hygiene,02_TEST_verify_sprint7.9,03_DIAGNOSTIC_preflight_true_false_removal,04_SCHEMA_true_false_removal,05_TEST_verify_true_false_removal}.sql`.
- **Changed:** `src/lib/questionTypes.js`, `src/lib/mcq.js` (doc comment), `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`.

---
## [2026-09-14] feat(sprint-7.8): Match the following (SQL confirmed needing zero changes; frontend live-verified end to end; ✅ committed `b85afe0`)

Phase 7, sprint 9 — the first genuinely new interaction mechanic since mcq: left-item/right-item pairing, not a collapse into the shared mcq/true_false/correct_incorrect machinery the way Sprint 7.7's types were. Verdict is still deterministic (fully correct or not), so the hybrid-grading contract is unchanged; `apply_review`/`review_events`/both analytics RPCs needed zero changes. `npm run build` clean; `npx eslint` clean on every changed file (pre-existing `FlashcardCreate.jsx` baseline errors reconfirmed via `git stash` to predate this sprint).

### Pre-flight — ✅ run by the operator 14/09/2026, real finding: zero SQL needed
This session has only the anon key (`VITE_SUPABASE_ANON_KEY` in `.env.local`) — no service-role key or direct Postgres connection string — so `docs/database/sprint7.8/00_DIAGNOSTIC_preflight.sql` had to be run by the operator in the Supabase SQL Editor rather than by this session. Result: live `pg_get_constraintdef(chk_flashcards_question_type)` includes `'match_the_following'::text` exactly; both `flashcards_gate_verdict_types_insert`/`_update` RESTRICTIVE policies' `with_check` list it exactly in their `<> ALL (ARRAY[...])` clause; zero pre-existing `match_the_following` rows. `match_the_following` was already added to both the CHECK constraint and the D-10 gate back in Sprint 7.5, exactly as documented — no `fitb`-style naming drift this time. Same "needed zero SQL" outcome as true_false/correct_incorrect in Sprint 7.7.

### ✅ Live verification — done 14/09/2026 (dev server → live Supabase, real professor + student accounts, account owner typing credentials directly into the driven browser)
Authored a 4-pair card and a 3-pair card as professor (`back_text` derivation, auto-generated letters, independent left/right add/remove editors — including mid-authoring row removal — all confirmed exact). Graded the wrong path (2-of-4 rows deliberately swapped): session ledger incremented "Hard 1" before Continue, proving `apply_review('hard', false)` fires on Check Answers; per-row reveal showed correct/incorrect simultaneously regardless of overall verdict. Graded the correct path (all rows matched): `GradeButtonRow` appeared with real interval previews and no pre-selected default. Confirmed the due-filter excludes an already-graded card on re-entry (zero special-casing in `get_study_queue`), the student Create page shows no type leak, Browse Study Sets' filter narrows correctly, and both analytics widgets (`get_question_type_performance`, `get_educator_accuracy_by_qtype`) show real two-measure data with the exact expected math (1 wrong + 1 correct → 50%/50%). Console clean.

### Changed (naming follow-up, same session)
- **`FlashcardCreate.jsx`** per-block heading — was `{formatQuestionType(card.questionType)} {index + 1}` (e.g. "Flashcard 1"), now **`Item {index + 1} — {formatQuestionType(card.questionType)}`** (e.g. "Item 1 — Flashcard", "Item 1 — Match the following"). Type names themselves are unchanged everywhere else (Question Type dropdown, Progress/Dashboard widgets, Browse Study Sets filter) — this only clarifies that "1" counts items, not decks.

### Fixed (bonus, found during live verification)
- **`Progress.jsx`** had its own stale, independently-maintained question-type label map (`QT_LABELS` — keys `match`/`fill_blank`/`short_answer`/`case_study`, none ever real `chk_flashcards_question_type` values) instead of the shared `formatQuestionType()` Sprint 7.6 built specifically to prevent this class of drift (the same bug Sprint 7.5 already fixed once in `Dashboard.jsx`). Live-observed rendering the new `match_the_following` row as its raw db key. Fixed by deleting the local map and delegating to the shared helper — re-verified live, `npx eslint` clean.

### Added
- **`src/lib/matchTheFollowing.js`** (new) — `keyForRightIndex()` (auto-generates A/B/C... right-item keys by list position, never professor-typed), `buildMatchOptions()` (assembles the `{left,right,correct}` options jsonb shape), `deriveMatchBackText()`, `validateMatchPairs()`. Same shared-helper pattern as `src/lib/mcq.js`.
- **`src/components/revisop/MatchZone.jsx`** (new) — the pick-a-left-row/assign-a-right-badge interaction, translated from the design reference's interaction logic (`docs/active/design-review/revisop-pass2-reference.jsx` `MatchZone`, lines 649-730) into the project's real tokens (`rounded-rec`, `--rv-navy`/`--rv-slate`, `font-plex-mono`) rather than its inline-style/green-for-correct treatment. The one revisop primitive actually wired into a production page (`StudyMode.jsx`), unlike its `/__design`-only siblings.
- **`docs/database/sprint7.8/00_DIAGNOSTIC_preflight.sql`** (✅ run against production 14/09/2026) — live `chk_flashcards_question_type` definition, D-10 RESTRICTIVE policy IN-list, existing-row sanity check. All three confirmed clean.

### Changed
- **Representation (locked):** `question_type='match_the_following'` uses `options` = `{ left: string[], right: {k,v}[], correct: {[leftIndex]: k} }` — deliberately different from mcq's flat array, since the correct mapping needs to live colocated with the `right` list it references. `correct_answer` stays NULL (no single scalar "the answer"). Left/right locked to the same length this sprint (no distractor right-options — explicit future refinement).
- **`FlashcardCreate.jsx`** — new "Match the following" question-type option (role-gated like mcq/true_false/correct_incorrect). Left items and right items are two independent add/remove editors (2-8 rows each), not paired rows; a "Correct Mapping" section renders one `<Select>` per left item. Draft autosave/restore extended to carry `matchLeft`/`matchRight`/`matchCorrect`; the restore-time role-downgrade check now uses a local `isD10GatedType()` (previously `GRADED_QUESTION_TYPES.includes(...)` alone would have missed this type).
- **`StudyMode.jsx`** — new top-level render branch, checked *before* `GRADED_QUESTION_TYPES.includes(...)`, with its own `matchPairs`/`matchRevealed`/`matchIsCorrect` state (reset every card change). A "Check Answers" button (enabled only once every left row is assigned) is the explicit commit action, since the answer builds up across multiple taps rather than one. On submit, every row reveals its own correctness regardless of the overall verdict; **overall verdict is all-or-nothing** (3-of-4 correct still grades as wrong) — a deliberate simplification, not an oversight. Hybrid grading unchanged: wrong → immediate `apply_review('hard', false)` + single Continue; correct → reveal + the existing unmodified `GradeButtonRow`.
- **`src/lib/questionTypes.js`** — `BROWSABLE_QUESTION_TYPES` gains `match_the_following` (one-line addition). `GRADED_QUESTION_TYPES` deliberately left unchanged — it drives the shared single-tap list branch that this type does not use.
- **`Progress.jsx`** — `qtLabel()` now delegates to the shared `formatQuestionType()` instead of its own stale local map (see Fixed, above).

### Files Changed
- **New:** `src/lib/matchTheFollowing.js`, `src/components/revisop/MatchZone.jsx`, `docs/database/sprint7.8/00_DIAGNOSTIC_preflight.sql`.
- **Changed:** `src/lib/questionTypes.js`, `src/components/revisop/index.js`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/Study/Progress.jsx`, `docs/active/blueprint.md`, `docs/reference/{DATABASE_SCHEMA,FILE_STRUCTURE}.md`, `docs/active/now.md`.

---
## [2026-09-13] feat(sprint-7.7): True/False, Correct/Incorrect + free-recall labels + Create-page naming sweep (SQL deployed & verified live; frontend live-verified end to end; ✅ committed `1693e1a`)

Phase 7, sprint 8 — second and third proof that the question-type architecture generalizes cheaply. `true_false`/`correct_incorrect` reuse the mcq machinery end-to-end (representation, StudyMode rendering, hybrid grading); `theory`/`test_your_understanding` reuse the plain-flashcard front/back path with zero new StudyMode code. Mid-session, a naming inconsistency was raised and folded in as a copy-only rename. `npm run build` clean; `npx eslint` clean on every changed file (pre-existing baseline errors confirmed via `git stash` to predate this sprint).

### Added
- **`docs/database/sprint7.7/00_DIAGNOSTIC_preflight.sql`** (✅ run) — confirmed exactly one live `get_browsable_decks` signature + that the live `chk_flashcards_question_type`/D-10-policy definitions matched the drafted `01_SCHEMA` exactly.
- **`docs/database/sprint7.7/01_SCHEMA_add_test_your_understanding_type.sql`** (✅ **deployed to production**) — widens `chk_flashcards_question_type` to add `test_your_understanding`. Purely additive, no RLS change. Was a hard prerequisite — this value could not be inserted by anyone before this ran.
- **`docs/database/sprint7.7/02_TEST_verify_new_question_types.sql`** (✅ **run against production — 6/6 rows PASS**) — confirmed test_your_understanding now insertable, theory unaffected, and (regression check) true_false/correct_incorrect still gated exactly as they were before this sprint.
- **`GRADED_QUESTION_TYPES`** and **`VERDICT_OPTION_LABELS`** in `src/lib/questionTypes.js` — the former drives StudyMode.jsx's shared rendering branch for all 3 graded types; the latter auto-populates true_false/correct_incorrect's `options` (never professor-typed, unlike mcq).

### Changed
- **`BROWSABLE_QUESTION_TYPES`** (`src/lib/questionTypes.js`) — extended from `['flashcard','mcq']` to include `true_false`, `correct_incorrect`, `theory`, `test_your_understanding`.
- **`StudyMode.jsx`** — the mcq-only render condition (`question_type === 'mcq'`) generalized to `GRADED_QUESTION_TYPES.includes(question_type)` in both places it appeared. No other change — the existing `AnswerOption`-list render and hybrid-grading (wrong→auto-hard+Continue, correct→reveal+GradeButtonRow) work unmodified for a 2-option array. theory/test_your_understanding fall through to the existing front/back/self-grade path unchanged (confirmed by reading the render chain, not assumed).
- **`FlashcardCreate.jsx`** — question-type selector now shown to ALL users (previously hidden entirely unless professor/admin/super_admin); only the 3 graded options within it (Multiple Choice/True-False/Correct-Incorrect) stay role-conditional, since theory/test_your_understanding are ungated free-recall types. True/False and Correct/Incorrect authoring uses a 2-way toggle-button pair instead of mcq's free-text options editor.
- **`BulkUploadFlashcards.jsx`** — CSV template gains one example row per new type + rewritten column docs; parser's recognized `question_type` values extended from mcq-only to all 4 new types; `42501` RLS-rejection message generalized to name all 3 gated types.

### Added (naming sweep)
- **"Create Flashcards" → "Create Study Item"** page title/subtitle (`FlashcardCreate.jsx`), matching the "Study Sets" terminology Sprint 7.6 already established for the browse/list pages — flashcard is one item type among six, not the umbrella term.
- Every "Create Flashcard" nav-trigger label renamed sitewide: `NavDesktop.jsx`, `NavMenuSheet.jsx`, `NavBottomTabs.jsx` (+ doc-comment), `DesignShowcase.jsx`'s `/__design` mockup.
- Every empty-state/quick-link button pointing at `/dashboard/flashcards/new` renamed: `MyFlashcards.jsx`, `MyContributions.jsx` (×2), `ReviewFlashcards.jsx`, `NoteDetail.jsx`.
- `BulkUploadFlashcards.jsx`: page title/subtitle, upload/success toasts, CSV-instruction prose, "Create Flashcard" cross-references, "Upload Flashcards" button — all → "Study Item(s)".
- `guideContent.js`/`helpContent.js`'s nav-instruction lines, `Home.jsx`'s public landing-page step 3, `PageContainer.jsx`'s doc-comment.
- `FlashcardCreate.jsx`'s own toast/validation copy: "N study item(s) created successfully", "Item N: Front side cannot be empty" (was "Flashcard N: ..."), "Add Another Item", "Create N Items".
- **Deliberately left alone:** `helpContent.js`'s "Creating Flashcards" section title/prose (a real content rewrite describing all 6 types, not a label swap — flagged, not fixed) and `ProfessorTools.jsx` (confirmed dead/unrouted per blueprint backlog).
- Routes, file names, DB table/column names, and internal identifiers (`flashcards` state, `.from('flashcards')`, `flashcard_decks`, etc.) all untouched — copy-only, same scope discipline as Sprint 7.6's rename.

### Verification status
- **SQL: ✅ deployed & verified live (13/09/2026).** All 3 files run against production in order; `02_TEST`'s 6 assertion rows all returned PASS.
- **✅ Live frontend verification DONE (13/09/2026, dev server → live Supabase, real professor + student accounts):** authored true_false/correct_incorrect/theory/test_your_understanding manually as professor; bulk-uploaded a 6-row CSV mixing all 6 types (`back_text` derived correctly for every row); graded a true_false wrong (auto-hard + single Continue) and a correct_incorrect right (reveal + full grade row) — professor Dashboard's "Accuracy by question type" widget confirmed showing real two-measure data for all 6 types, correctly distinguishing verdict-bearing from free-recall; student's question-type selector confirmed showing only the 3 ungated types; Browse Study Sets filter narrowed correctly for both new graded types; naming sweep confirmed live across desktop nav, mobile ＋ sheet, and mobile Menu drawer. Console clean (one non-critical, pre-existing `admin_audit_log` 403 on bulk upload, unrelated, not chased).
- **Real finding, not assumed:** re-verified against the live D-10 RLS policy (not just the docs) that `true_false`/`correct_incorrect` were already gated correctly since Sprint 7.5 — this sprint's authoring UI needed zero RLS changes for those two types, and `02_TEST` proves it held after this sprint's changes too.
- **✅ Committed and pushed** (`1693e1a`, on `main`) — SQL deployed + verified, frontend live-verified end to end.

---
## [2026-09-13] feat(sprint-7.6): Browse/My Study Sets rename + question-type filter (SQL deployed + frontend live-verified; ✅ committed `c629ed3`)

Phase 7, sprint 7 — small, focused fix for the naming confusion raised at the end of 7.5: `ReviewFlashcards.jsx` browses ALL question types now (flashcard + mcq, more coming), so "Review Flashcards" no longer matched what the page does. Copy + one filter, not a redesign. `npm run build` clean; `npx eslint` clean on every changed file.

### Added
- **`src/lib/questionTypes.js`** (new) — `formatQuestionType()` (moved out of a `Dashboard.jsx`-local const so both pages share identical display strings) + `BROWSABLE_QUESTION_TYPES` (`['flashcard', 'mcq']` — the types with a real authoring path; extend this array, not JSX, as later sprints add types).
- **Question Type filter, `ReviewFlashcards.jsx`** — 6th single-select dropdown alongside Course/Subject/Topic/Role/Author, same `filterX`/`setFilterX` + `applyFilters()`/`clearAllFilters()` pattern. Narrows which decks show (≥1 visible card of that type) — does not change `card_count` or what a study session serves once a student clicks into a deck.
- **`docs/database/sprint7.6/01_FUNCTIONS_get_browsable_decks_v5_question_type_filter.sql`** (✅ deployed) — adds `p_question_type text DEFAULT NULL` to `get_browsable_decks`, additive, `NULL` reproduces v4 exactly.

### Changed
- **`get_browsable_decks` → v5.** Same `TABLE` return shape as v4, one new parameter and one new `EXISTS` clause narrowing by question type using the same visibility predicate as the existing per-viewer `card_count` lateral.
- **`ReviewFlashcards.jsx`** — `<h1>` "Review Flashcards" → **"Browse Study Sets"**, subtitle no longer flashcard-specific. Fetch effect now depends on the new filter and passes `p_question_type` to the RPC (the one filter of the six that round-trips to the server rather than filtering the already-fetched dataset client-side, since deck-level type membership isn't otherwise in the payload).
- **`MyFlashcards.jsx`** — `<h1>` "My Flashcards" → **"My Study Sets"**.
- **`NavDesktop.jsx` / `NavMenuSheet.jsx`** — Study menu item "Review Flashcards" → **"Browse Study Sets"** (desktop dropdown + mobile Menu drawer).
- **`Dashboard.jsx`** — student quick-link card "My Flashcards" → "My Study Sets"; `formatQuestionType` now imported from `@/lib/questionTypes` instead of a local const.
- **`BulkUploadFlashcards.jsx`** — post-upload "View My Flashcards" button → "View My Study Sets".
- **`helpContent.js` / `guideContent.js`** — every "Review Flashcards" reference to these two pages (help-content list item, 4 `guideContent.js` `linkLabel`s) updated to "Browse Study Sets" for consistency with the renamed nav/heading. `linkTo` values in `guideContent.js` were left untouched — see Known Issues.

### Fixed (deployment gotcha, caught live)
- **`get_browsable_decks` first deploy attempt used a plain `CREATE OR REPLACE FUNCTION get_browsable_decks(p_question_type TEXT DEFAULT NULL)`**, which did NOT replace the old zero-arg function — Postgres treats a changed parameter list (even one added with a `DEFAULT`) as a distinct overload, not a replacement. Left both the zero-arg and one-arg versions live simultaneously; every unparameterized call became ambiguous (`ERROR 42725: function get_browsable_decks() is not unique`). Fixed with an explicit `DROP FUNCTION IF EXISTS get_browsable_decks();` before the `CREATE OR REPLACE`.
- **`02_TEST` initially ran as the SQL Editor's default `postgres` role**, which has no `auth.uid()` — hit `RAISE EXCEPTION 'Not authenticated'` (correct behavior, not a function bug). Rewritten to impersonate a real profile via `SET LOCAL ROLE authenticated` + `request.jwt.claims`, matching `docs/database/sprint7.5/02_TEST_verify_d10_role_gate.sql`'s existing pattern.

### Fixed (same-day follow-up, after the sprint's own flag came back)
- **`guideContent.js`** — 3 onboarding-guide steps ("Open your Review queue", "Don't panic — start small", "One topic too heavy? Skip it for today.") described the due-today review queue but linked to `/dashboard/review-flashcards` (Browse Study Sets) instead of `/dashboard/review-session` (Today's Reviews) — confirmed by reading `ReviewSession.jsx` (calls `get_study_queue`, embeds `StudyMode` directly). `linkTo` corrected to `/dashboard/review-session` and `linkLabel` to "Today's Reviews" on all 3; the 4th "Review Flashcards"-turned-"Browse Study Sets" occurrence (orientation section's "Do your first review") was left as-is — a never-reviewed card has no due-queue entry, so that step genuinely means "go find a deck," not "open the due queue." Live-verified on `/guide`: exactly 3 buttons read "Today's Reviews →", 1 reads "Browse Study Sets →"; clicking a "Today's Reviews" button set `localStorage.postAuthRedirect` to `/dashboard/review-session`. Full writeup in `bugs.md`.

### Investigated, confirmed not a bug (real UX gap flagged, not fixed — out of scope for this sprint)
- **"No flashcards to study" clicking directly into a deck whose cards are all already graded.** The Income Tax → Deductions from Gross Total Income deck returned this for the live-test account, with and without the question-type filter — ruling out this sprint's own changes as the cause. Root cause confirmed live via `docs/database/bugfixes/15_DIAGNOSTIC_deductions_deck_no_cards_to_study.sql`: `StudyMode.jsx`'s `fetchFlashcards` applies the same due/never-reviewed filter regardless of entry path, and this deck's 3 visible cards were all graded during Sprint 7.5's own live MCQ testing earlier the same day, so they're scheduled forward (09-14/09-16/09-20) and correctly excluded from "due" — confirmed against the real `get_study_queue` RPC returning zero of these 3 ids. Not a bug — `StudyMode.jsx` is working as designed. Real gap: the empty state doesn't distinguish "deck has 0 cards" from "you already reviewed everything here today," which would be a `StudyMode.jsx` change and stays out of scope for this sprint. Full writeup in `bugs.md`.

### Live Verification (13/09/2026, dev server → `revisop.com`'s live Supabase, real student account "TestOutlook")
- Nav shows "Browse Study Sets" (desktop Study dropdown + mobile Menu drawer); page heading/subtitle correct.
- Question Type dropdown renders exactly "All Types" / "Flashcard" / "MCQ" via `formatQuestionType`.
- Selecting MCQ narrowed 464→3 cards to the one deck known (from SQL testing) to mix flashcard+mcq — at this student's own per-viewer visible `card_count` (3, vs. 4 for the more-privileged SQL-test profile, confirming per-viewer visibility is respected).
- Clicking the filtered deck's "Study All" produced `/dashboard/study?deck=...` with no question-type param — filter confirmed not to leak into the study session.
- `clearAllFilters()` reset Question Type to "All" alongside the other five, restoring all 464 cards.
- Console clean aside from one pre-existing, self-recovering `refresh_token_not_found` warning on hard reload (reproduces without this sprint's changes).

### SQL Verification (13/09/2026, impersonated real profile via `SET LOCAL ROLE authenticated`)
35 unfiltered decks; 35 with a flashcard; 1 with an mcq (`Income Tax → Deductions from Gross Total Income`) — that deck appeared under all three filters with unchanged `card_count=4`; `theory` (an unused type) correctly returned 0 decks without erroring.

### Files Changed
- **New:** `src/lib/questionTypes.js`, `docs/database/sprint7.6/{01_FUNCTIONS,02_TEST}*.sql`
- **Changed:** `src/pages/dashboard/Study/ReviewFlashcards.jsx`, `src/pages/dashboard/Content/MyFlashcards.jsx`, `src/components/layout/{NavDesktop,NavMenuSheet}.jsx`, `src/pages/Dashboard.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/data/{guideContent,helpContent}.js`, `docs/active/blueprint.md`, `docs/reference/{DATABASE_SCHEMA,FILE_STRUCTURE}.md`, `docs/active/now.md`

---
## [2026-09-13] feat(sprint-7.5): MCQ-single vertical slice — authoring, bulk import, hybrid grading (SQL deployed + frontend live-verified end to end; ✅ committed `797629d`)

Phase 7, sprint 6 — the architectural proof for the whole question-type epic: representation → authoring → bulk import → rendering → verdict → hybrid scheduling, end to end, for `question_type='mcq'`. The engine underneath (`apply_review`, `review_events`, both analytics RPCs from Sprint 7.4) needed zero changes — confirmed `get_study_queue` only excludes `concept_card`, so mcq rows flow through the due queue with no special-casing. `npm run build` clean; `npx eslint` clean on every changed file.

**✅ D-10's role-gate SQL is deployed and verified live**, both at the SQL level (`02_TEST` — all 5 rows PASS) and at the UI level: a real student's bulk-upload attempt with an `mcq` row was rejected live with the friendly `42501` error, a real professor's identical attempt succeeded. **✅ Full frontend loop live-verified end to end** — authoring (manual create, questiontype selector absent for students), bulk upload (CSV, both roles), and both StudyMode grading paths (wrong → auto-hard + Continue; correct → GradeButtonRow, no default) — against `revisop.com`'s live Supabase via a real professor and a real student account. **The payoff:** both `Progress.jsx` and `Dashboard.jsx` "Answer accuracy" widgets now show real graded data (50%) instead of "No graded answers yet," for the first time since Sprint 7.4 built the two-measure contract.

### Added
- **`src/lib/mcq.js`** (new) — shared authoring helpers so back_text derivation can't drift between the manual-create and bulk-upload entry paths: `compactMcqOptions` (drops blank option rows, remaps the correct index by original position — not by text, since two options can be identical), `deriveMcqBackText`, `toPointsToRemember`, `validateMcqOptions`.
- **`docs/database/sprint7.5/01_SCHEMA_d10_role_gate.sql`** (✅ deployed) — `is_professor_or_admin()` (mirrors the existing `is_admin()` pattern) + two RESTRICTIVE RLS policies on `flashcards` (INSERT + UPDATE) blocking any non-professor/admin/super_admin row whose `question_type` is one of the 7 verdict-bearing types (`mcq`, `true_false`, `correct_incorrect`, `case_study_mcq`, `integrated_case`, `match_the_following`, `fitb`). Free-recall types unaffected. **Corrected after running `00_DIAGNOSTIC_preflight.sql`:** the live `chk_flashcards_question_type` CHECK constraint uses `fitb`, not `fill_in_the_blanks` as the sprint kickoff and `blueprint.md` had assumed — the wrong string would have left that one type completely ungated (a row `NOT IN` the list passes the RESTRICTIVE check unconditionally). Also confirmed `test_your_understanding` isn't a live value at all. `02_TEST` extended with explicit `fitb`/`true_false` rejection assertions on top of the required mcq ones — **all 5 assertions PASS against real profiles.**
- **`FlashcardCreate.jsx`** — question-type selector (Flashcard / Multiple Choice), visible only to professor/admin/super_admin. Per-card options editor (2-6 rows, mark-correct radio), optional "Why" explanation textarea. Draft autosave/recovery extended to cover the new fields.
- **`BulkUploadFlashcards.jsx`** — CSV template gains `question_type`, `option_1..option_4`, `correct_option` (1-based), `explanation`; existing front/back-only rows unaffected. A student-authored `mcq` row is rejected server-side by D-10 regardless of client checks (friendlier error message added for the Postgres `42501` RLS-violation case).
- **`StudyMode.jsx`** — third rendering branch (alongside the untouched flashcard `!showAnswer`/`showAnswer` JSX) for `question_type === 'mcq'`, using the already-built `AnswerOption` primitive. Hybrid grading: a wrong answer auto-submits `apply_review(..., p_rating: 'hard', p_is_correct: false)` immediately on reveal, then a single Continue button just advances (no second RPC call); a correct answer reveals then shows the existing unchanged `GradeButtonRow`, where the tap is both the `apply_review(..., p_is_correct: true)` call and the advance.

### Changed
- **`StudyMode.jsx` `handleRating`** — split into `submitReview` (the `apply_review` call) + `advanceCard` (the forward-animation timer), previously one function. Needed because MCQ's wrong-answer path must submit immediately but wait for the student to tap Continue before advancing, while the flashcard path (and MCQ-correct) still submit-and-advance together in one tap. `handleRating(quality, isCorrect = null)` now accepts an optional second argument instead of always passing `p_is_correct: null`.

### Fixed
- **`Dashboard.jsx` `formatQuestionType`** — label map keyed on `fill_in_the_blanks`, same wrong string the D-10 diagnostic caught in the RLS policy draft; corrected to `fitb` (display text unchanged, "Fill in the blanks"). No live impact yet (no fitb rows exist), but would have shown a generic "Fitb" label once a future sprint builds that type. Confirmed via repo-wide grep this was the only occurrence.
- **`FlashcardCreate.jsx`** — per-card form heading still read "Flashcard N" even when Question Type was set to Multiple Choice; now shows "Multiple Choice N".
- **`update_deck_card_count()` trigger — flashcard_decks.visibility desync (platform-wide, pre-existing, unrelated to MCQ).** Caught during live testing: a deck's `visibility` was set once at creation and never re-widened, so a deck created `private` that later gained `public` cards stayed invisible to `get_browsable_decks`/`get_recent_activity_feed` forever, even though the member cards' own visibility was correct — while `notifyContentCreated()` still fired (it uses the current submission's visibility, not the stale deck row), producing exactly the symptom that surfaced this: a notification bell firing for content Recent Activity/Browse never showed. Fix: the trigger's INSERT-existing-deck branch now widens `visibility` in the same UPDATE (private < friends < public, never narrows) when the new card is more permissive. One-time backfill applied to the 4 live decks already desynced (3 belonging to other users — confirms this predates this session). Deployed and verified: 0 desynced decks remain. Full writeup in `bugs.md`.
- **`update_deck_card_count()` trigger — flashcard_decks.target_course NULL on auto-created decks (platform-wide, pre-existing, unrelated to MCQ).** Found as a follow-up to the visibility bug above, while reading the same trigger's live body: the auto-create-deck branch never set `target_course`, contradicting a `bugs.md` entry that had described this as already fixed since March. Live impact measured, not assumed: 2 decks, 34 public cards total, one professor, dating to 07/04/2026 — invisible to every student for 5 months (`get_browsable_decks`/`get_recent_activity_feed` both filter on course match, which a NULL never satisfies; professors/admins bypass that gate, which is why nobody noticed). Fixed by adding `target_course` to the auto-create INSERT; backfilled both affected decks from their own member flashcards. Deployed and verified: 0 rows remain NULL. Full writeup in `bugs.md`.

### Live Verification (13/09/2026, dev server → `revisop.com`'s live Supabase, real professor + student accounts)
- Professor `Dashboard.jsx` "Accuracy by question type" widget — carried-over 7.4 gap, now click-tested live.
- Manual authoring: MCQ card created correctly, `back_text` auto-derived, question-type selector absent for the student account.
- Bulk upload: professor's 2-row CSV (1 plain + 1 mcq) both created correctly with derived `back_text`; student's 1-row mcq CSV rejected server-side.
- StudyMode both grading paths exercised on two separate real mcq cards: wrong answer (auto-hard submitted on reveal, before Continue tap — confirmed via review-count increment; single Continue button; regression-free plain-flashcard grading in the same session) and correct answer (no auto-submit, unchanged GradeButtonRow with no pre-selected default, submit+advance together).
- `get_question_type_performance` and `get_educator_accuracy_by_qtype` both confirmed rendering real "Answer accuracy: 50%" (student and cohort-wide professor view respectively) — the first real data either RPC has ever served since Sprint 7.4 built the two-measure contract.
- Console clean throughout; the only errors observed were the deliberate RLS-rejection test and pre-existing dev-environment ServiceWorker noise unrelated to this sprint.

### Files Changed
- **New:** `src/lib/mcq.js`, `docs/database/sprint7.5/{00_DIAGNOSTIC,01_SCHEMA,02_TEST,03_DIAGNOSTIC,04_FUNCTIONS,05_FIX,06_DIAGNOSTIC,07_FUNCTIONS,08_FIX}*.sql`
- **Changed:** `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/Dashboard.jsx`, `update_deck_card_count()` DB trigger function, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/tracking/bugs.md`, `docs/active/now.md`

---
## [2026-09-13] feat(sprint-7.4): review_events history + apply_review write SSOT + two-measure analytics semantics (SQL deployed)

Phase 7, sprint 5 — the architectural de-risk gate for the whole question-type epic (Sprint 7.5 MCQ-single onward). No question-type rendering here — StudyMode stays pure front/back; this is data/engine layer only. `npm run build` clean; `npx eslint` clean on every changed file. **4 SQL files deployed + confirmed live** (`01_SCHEMA`, `02_FUNCTIONS`, `03_FUNCTIONS`, `04_TEST` — 29/29 real assertions PASS), plus 2 read-only diagnostic scripts (`00`, `05`) for pre/post-deploy introspection (`docs/database/sprint7.4/`). Frontend live-verified against production via a real student account (both new-card and review-session grading paths, 200 OK with correct rung/interval each time); Progress.jsx's widget confirmed rendering the two-measure layout correctly. Dashboard.jsx's professor widget was code-reviewed but not click-tested live (no professor account this session).

**Phase 0 introspection (`00_DIAGNOSTIC`, run first per this project's introspect-before-DDL standing practice) changed the delivered SQL from the sprint's own draft twice:** `reviews.user_id` actually references `auth.users(id)`, not `profiles(id)` as drafted — `review_events.user_id` matches the real thing, and the same stale claim in `DATABASE_SCHEMA.md`'s `reviews` row was corrected along the way; and both analytics RPCs needed DROP+CREATE (not `CREATE OR REPLACE`) since their `RETURNS TABLE` shape changed — same constraint this project already hit with `get_study_queue`.

### Added
- **`review_events` table** (new) — append-only per-review history, one row per grade ever. `reviews` stays the current-state SSOT, unchanged shape/semantics. RLS enabled, zero policies/grants — every access is through a SECURITY DEFINER RPC. Columns include `rating`, `is_correct` (NULL until Sprint 7.5's graded question types exist), `question_type`/`topic_id` (snapshots), `rung_before`/`rung_after`, `status_after`, `interval_days`, `next_review_date`, `source` (`'new_card'`/`'review_session'`/NULL), reserved `study_session_id`.
- **`apply_review(p_user_id, p_flashcard_id, p_rating, p_is_correct DEFAULT NULL, p_source DEFAULT NULL)`** — the new write SSOT for review scheduling, superseding `submit_review`. Absorbs `submit_review`'s live body verbatim (confirmed byte-identical before extending) and adds a `review_events` INSERT in the same transaction as the `reviews` write — atomic by construction, proven with a real forced-failure trigger test (not just asserted).
- **`graded_count` / `answer_accuracy_pct`** columns on both `get_question_type_performance` and `get_educator_accuracy_by_qtype` — objective graded-correctness measure alongside the existing self-rated one. NULL/0 until graded question types exist (Sprint 7.5).

### Changed
- **`submit_review`** — now a thin `LANGUAGE sql` compat wrapper delegating to `apply_review(..., NULL, NULL)`, so a stale cached client bundle calling the old 3-arg signature during the deploy window keeps working (and logs `is_correct=NULL`). No longer called by current frontend code.
- **`get_question_type_performance` / `get_educator_accuracy_by_qtype`** — `accuracy_pct` renamed `recall_success_pct` (computation byte-for-byte unchanged, pure rename). Both queries pre-aggregate `review_events` into a one-row-per-key CTE before joining it in, specifically to avoid fanning out the pre-existing accuracy arithmetic (`review_events` is append-only/many-rows-per-card, unlike the existing at-most-one-row-per-card joins in those queries).
- **`StudyMode.jsx` `handleRating`** — calls `apply_review` instead of `submit_review`, with `p_is_correct: null` (no verdict exists yet — StudyMode is still pure front/back) and `p_source` derived from the existing `rung === undefined` new-card convention already used for the grade-preview memo.
- **`Progress.jsx` `QuestionTypeRow`** and **`Dashboard.jsx`'s professor "Accuracy by question type" widget** — both now show two labeled rows per question type: "Recall success" (always populated, same number as before the rename) and "Answer accuracy" ("No graded answers yet" until `graded_count>0`). Footnotes updated to name both measures plainly.

### Storage (7.4-E, measured not guessed)
~142 bytes/row (`pg_column_size` on real inserted rows). Current DB 53MB vs. the Supabase Free-plan 500MB limit; even a generous 10×-of-observed daily rate projects to low-single-digit MB/year. No archival/rollup/partitioning built — the projection shows no near-term problem worth solving yet.

### Files Changed
- **New:** `docs/database/sprint7.4/{00_DIAGNOSTIC,01_SCHEMA,02_FUNCTIONS,03_FUNCTIONS,04_TEST,05_DIAGNOSTIC}*.sql`
- **Changed:** `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/dashboard/Study/Progress.jsx`, `src/pages/Dashboard.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`

---
## [2026-09-12] feat(sprint-7.3): Dashboard reporting surface & study-time split — goal progress two-state, app-wide study timer, in-app/offline split (SQL deployed)

Phase 7, sprint 4 — inserted ahead of the `review_events`/`apply_review` engine sprint (now **7.4**), final dashboard/nav polish before 100+ new students land. `npm run build` clean; `npx eslint` clean on every changed file. **2 SQL migrations deployed + confirmed live** (`docs/database/sprint7.3/`): `profiles.has_dismissed_goal_prompt` (additive column) and `get_study_time_stats` DROP+CREATE (4 additive in-app/offline split columns, existing 4 columns/IDOR guard/search_path unchanged, grants re-applied to `authenticated`). Live-verified dev server → live Supabase, student (TestOutlook), desktop + 375px mobile — including, in a same-session follow-up pass: the mobile ＋ sheet and desktop Create dropdown contents, and both the 4-16h recovery-prompt and >16h silent-discard stale-session paths (faked timestamps, confirmed classification happens app-wide at whichever page reloads, not re-derived per page).

### Added
- **`src/contexts/StudyTimerContext.jsx`** (new) — app-wide home for the manual study timer. Owns the 3-tier stale-session policy (<4h auto-resume / 4-16h honest-session prompt / >16h silent discard), classified once on provider mount via lazy `useState` initializers (not an effect) instead of being gated behind whichever page hosts the timer widget. Own localStorage key `revisop_manual_timer_started_at` — no longer shares `revisop_session_started_at`/`revisop_session_source` with `StudyMode.jsx` (fixes a real collision: a concurrent manual timer + in-app review session used to clobber whichever wrote last). Cross-tab sync via `window.addEventListener('storage', …)`. Exposes `{ isRunning, startedAt, elapsedMs, recoveryPrompt, start(), stop(), stopAndLog(durationSeconds), discard() }`.
- **`src/pages/dashboard/Study/StudyTimePage.jsx`** (new) — dedicated route `/dashboard/study-time` hosting `StudyTimerWidget`; reachable from the desktop Create dropdown and the mobile ＋ sheet.
- **`src/components/layout/StudyTimerChip.jsx`** (new) — nav-bar pill beside the notification bell (both `NavDesktop`/`NavMobile`), hidden unless a timer is running. Tap: <4h logs immediately + toasts; 4-16h navigates to the dedicated route (recovery prompt already showing via context state); >16h defensively discards + toasts.
- **`ProfileSettings.jsx`** — new "Daily Goal" Card (students only) — review/study-minute goal type toggle + Save/Clear, via the existing `update_daily_goal` RPC (no new RPC).
- **`OnboardingModal.jsx`** — 4th step, "Set your daily goal" → `/dashboard/settings`, same shape/skip semantics as the existing 3 steps.
- **`get_study_time_stats`** — 4 additive columns (`today_seconds_in_app`, `today_seconds_offline`, `week_seconds_in_app`, `week_seconds_offline`) splitting the existing combined totals by `study_sessions.source`.
- **`profiles.has_dismissed_goal_prompt`** — one-time dismissal flag for the dashboard "no goal set" prompt line.
- **`src/pages/dashboard/Profile/MyReports.jsx`** (new, same-session follow-up) — "Report History" page at `/dashboard/my-reports`: status list of content the student has personally flagged (`content_flags`, `flagged_by = you`) — unrelated to My Progress/study stats. Linked from `ProfileDropdown.jsx` + `NavMenuSheet.jsx`.

### Changed
- **`Dashboard.jsx` (student branch)** — removed the Streak/Accuracy/Mastered/Reviews "Your Week" stat-tile grid (duplicated the Progress tab); `fetchPersonalStats` trimmed accordingly (dead `calculateStreak` helper deleted). **Same-session follow-up:** also removed Quick Actions (redundant with the Create dropdown/sheet) and My Contributions (duplicated the dedicated `/dashboard/my-contributions` page) so Recent Activity is always the last card; the conditional "My Reports" card moved to the new `/dashboard/my-reports` page (its `myReports` state + `content_flags` fetch removed from `Dashboard.jsx`). Final section order: Goal Progress → Leaderboard → Forward Load → Study Time (report only, no interactive control) → Recent Activity. `StudyTimerWidget` no longer mounted here (moved to the dedicated route).
- **`GoalProgressWidget.jsx`** — renamed "Goal Progress". Goal set → progress bar + de-emphasized "Revise target" link below the numbers (was a prominent top-right "Edit"). No goal set → no card/header, single dismissible line ("Set a daily goal →" / "Not now"); dismissing persists `has_dismissed_goal_prompt` + shows a one-time toast.
- **`StudyTimerWidget.jsx`** — rewritten as a thin consumer of `StudyTimerContext` (no more owned state); still renders Start/Stop/recovery-prompt/Log-less UI, with its own local per-second DOM-ref clock.
- **`NavBottomTabs.jsx`** — Bulk Upload removed from the ＋ action-sheet for ALL roles (`canBulkUpload` gate deleted, not narrowed); "Log Study Time" added below a divider.
- **`NavDesktop.jsx`** — Create dropdown gains a "Log Study Time" entry (divider-separated); Bulk Upload stays unconditional for all roles, unchanged.
- **`App.jsx`** — new `StudyTimerProvider` mounted beside `StudySessionProvider`; new route `/dashboard/study-time`.
- **`Dashboard.jsx` header (same-session follow-up)** — removed the subtitle line under "Welcome back" entirely (`"You have N items ready for review"` / `"All caught up! 🎉"` for returning users, the onboarding blurb for new users) — duplicated the Review-tab due badge and took up space. Header is now just the `<h1>`.
- **`NavBottomTabs.jsx` (bug fix)** — the mobile ＋ sheet's sr-only `SheetDescription` still said "…or a bulk upload" after 7.3-D removed that item; updated to match the actual items (note, flashcard, study group, log study time).

### Files Changed
- New: `src/contexts/StudyTimerContext.jsx`, `src/pages/dashboard/Study/StudyTimePage.jsx`, `src/components/layout/StudyTimerChip.jsx`, `src/pages/dashboard/Profile/MyReports.jsx`, `docs/database/sprint7.3/{01_SCHEMA,02_FUNCTIONS,03_TEST}*.sql`
- Changed: `src/pages/Dashboard.jsx`, `src/components/dashboard/{GoalProgressWidget,StudyTimerWidget,OnboardingModal}.jsx`, `src/pages/dashboard/Profile/ProfileSettings.jsx`, `src/components/layout/{NavDesktop,NavMobile,NavBottomTabs,ProfileDropdown,NavMenuSheet}.jsx`, `src/App.jsx`

---
## [2026-09-11] feat(sprint-7.2): Pre-onboarding dashboard & nav polish — student/professor dashboard restructure, unified notification center, due badge (NO SQL)

Phase 7, sprint 3 — inserted ahead of the `review_events`/`apply_review` engine sprint (renumbered **7.3**) because ~100+ students onboard this week. **Frontend only — NO SQL.** `npm run build` clean; `npx eslint` clean on every changed file. Both dashboard restructures (7.2-D, 7.2-C) were checkpointed live with Anand mid-sprint (student + professor sessions, desktop + 390px mobile) before further polish, per the kickoff instructions.

### Added
- **`src/hooks/useDueForecast.js`** (new) — wraps the existing `get_due_forecast` RPC (the same lightweight 3-int call `Progress.jsx` already used; deliberately not `get_study_queue`). Returns `{ dueToday, dueNext7, dueNext30, loading, refetch }`.
- **`src/components/layout/NotificationCenter.jsx`** (new) — unified bell icon/dropdown merging the former `FriendsDropdown` + `ActivityDropdown`. Pending friend requests (inline Accept/Decline, unchanged logic) render above content notifications when present; Find People / My Friends / Following / View All Requests kept as a footer. Badge = `unreadCount + pendingCount`, capped `"9+"`. Shared by `NavDesktop.jsx` and `NavMobile.jsx`.
- **`NavDataContext.jsx`** — `useDueForecast()` wired in as a fourth singleton (`dueToday`/`dueNext7`/`dueNext30`/`refetchDueForecast`) alongside role/notifications/friend-count.
- **`NavBottomTabs.jsx`** — Review tab gets a small amber due-count pill (`bg-rv-amber-50 text-rv-amber-ink`), hidden at 0, capped `"9+"`. ＋ action-sheet gains a "Create Group" entry (`Network` icon → `/dashboard/groups/new`).
- **`Dashboard.jsx` professor branch** — new "Analytics Snapshot" section: the `get_professor_overview` row (Cards Published / Students Reached / Total Reviews / Avg Quality) + top-5 "Challenging Cards" from `get_professor_weak_cards`, plus a "View full analytics →" link. Own `--rv-*` markup (light duplicate of the relevant `ProfessorAnalytics.jsx` sections, not a shared component — that page is still on pre-reskin gray tokens). `fetchEducatorWidgets()` now fires these 2 RPCs alongside the existing Sprint 6.3 pair, all 4 in one `Promise.all`, once per mount / once per course switch.

### Changed
- **`Dashboard.jsx` student branch (7.2-D)** — "Your Week" stat tiles (Streak/Accuracy/Mastered/Reviews) moved above the review CTA. The CTA/"All caught up" card is REMOVED (not just shrunk — a post-checkpoint correction) since the header subtitle and the 7.2-F nav badge already carry the same "N items ready"/"all caught up" message; the all-caught-up state's "Browse Study Sets"/"Browse Notes" links kept as a small link row.
- **Due badge (7.2-F)** — solid `bg-red-500 text-white rounded-full` (post-checkpoint correction; first cut used a pale amber tint that didn't read as a badge), matching the existing notification/friend-request badge styling. Extended from `NavBottomTabs.jsx`'s Review tab to `NavDesktop.jsx`'s "Study" dropdown trigger + "Today's Reviews" item, for cross-device consistency (Anand's follow-up ask) — same `dueToday` context value, no new fetch.
- **`Dashboard.jsx` professor branch (7.2-A, 7.2-C)** — "Quick Actions" grid removed entirely (redundant since 7.1's Create dropdown/sheet). "Cohort forward load" heading relabelled "— all students in your course"; the professor's own due count (from the `NavDataContext` singleton, no extra RPC) now sits beside it for contrast. "Needs Attention" moved to the top of the page (still fully unconditional — no new render gate). "Your Content" pushed down to just above "Accuracy by question type."
- **`NavMobile.jsx` / `NavDesktop.jsx` (7.2-B)** — both now render `<NotificationCenter>` in place of `<FriendsDropdown>` + `<ActivityDropdown>`. Mobile top bar is now Wordmark (left) · Bell (right); desktop nav's right-side icon row lost one icon.

### Removed
- **`src/components/layout/FriendsDropdown.jsx`, `src/components/layout/ActivityDropdown.jsx`** — deleted. Merged into `NotificationCenter.jsx`; no other importers.

### Notes
- **No SQL.** Every RPC used already existed and was already user-scoped (`get_due_forecast`, `get_professor_overview`, `get_professor_weak_cards`, `get_recent_notifications`, `get_unread_notification_count`).
- **Verification gap:** the in-session network-request tool did not capture the underlying Supabase REST/RPC calls this session (tool-side limitation, no app error reproduced) — the "4 RPCs once per mount" claim for 7.2-C rests on code review + the visual confirmation of a single clean load, not a captured trace. Click-testing of the ＋ sheet's "Create Group" entry and the merged bell's friend-request accept/decline was cut short by a transient Browser-pane click-tool hiccup late in the session — worth a quick manual pass before pushing.

### Docs updated
- `docs/active/blueprint.md` (SSOT — Sprint 7.2 entry; §1.7 component table; Contexts/Hooks tables), `docs/active/now.md` (Just Completed + follow-ups), `docs/reference/FILE_STRUCTURE.md` (new/deleted files). No `DATABASE_SCHEMA.md` change (no SQL).

---
## [2026-09-08] feat(sprint-7.1): Mobile bottom navigation — bottom-tab bar, shared active-route module, safe-area (NO SQL)

Phase 7, sprint 2 (kickoff item G). Ships the mobile bottom-tab bar on top of the 7.0 nav refactor. **Frontend only — NO SQL, no new data fetching. Desktop (`md:` and up) visually unchanged.** `npm run build` clean (7.0s); `npx eslint` clean on every file authored or structurally changed. **Layout A** decided with Anand (bottom bar = Dashboard · Review · ＋ · Progress · Menu; top mobile bar slims to Wordmark · Friends · Bell; the hamburger drawer moves to the "Menu" tab). **Live-verified across all three roles** (student / professor / super-admin, dev server → live Supabase) — two issues found & fixed during that pass (see *Fixed after verification* below). Committed + pushed to `main` → Vercel auto-deploy.

### Added
- **`src/components/layout/NavBottomTabs.jsx`** (new) — mobile bottom-tab bar. `md:hidden`, `fixed inset-x-0 bottom-0 z-50`, full-width (rendered by `Navigation.jsx` as a sibling of the top `<nav>`, outside `max-w-7xl`). `bg-rv-bg-1 border-t border-rv-border shadow-rv-bar font-plex`; row `h-14`; targets `min-h-[48px]`. Data-driven `TABS` array (a later top-level destination is a one-line add). Consumes the `navProps` bundle from `Navigation.jsx` only — **no `useRole`/`useNotifications`/`useFriendRequestCount` call, no fetch of its own** (no 7.0 over-fetch regression). ＋ opens a `<Sheet side="bottom">` action-sheet (Upload Note / Create Flashcard / Bulk Upload — Bulk Upload hidden unless professor+). Self-gates on `!user` and on `useStudySession().inStudySession`.
- **`src/components/layout/NavMenuSheet.jsx`** (new) — the former `NavMobile` hamburger `<Sheet side="right">` and all its content, moved verbatim (Study/Create/Groups/Following/Progress/Contributions/Achievements/Help/Settings + course-context switcher + professor/admin/super-admin sections + Sign Out). Trigger relocated to the bottom bar's "Menu" tab.
- **`src/lib/navActive.js`** (new) — pure `(pathname) => boolean` active-route predicates shared by `NavDesktop` + `NavBottomTabs`: `isExact`, `underAny`, `isCreateActive`, `isStudyActive`, `isManageActive`, `isGroupsActive` (behaviour locked to the Sprint 6.0/6.2 output), plus `isReviewTabActive` (bottom "Review" tab — study-session cluster only). No Supabase, no React.
- **`src/contexts/StudySessionContext.jsx`** (new) — `<StudySessionProvider>` (in `App.jsx`, above the router) + `useStudySession()` → `{ inStudySession, setInStudySession }` (no-op outside the provider). `StudyMode` flips `inStudySession` on mount/unmount so `NavBottomTabs` hides during the full-screen card loop regardless of entry route.
- **`/__design`** — new "Mobile bottom nav" block in `ReskinGallery` (the bar with active/inactive tabs + the ＋ action-sheet, light + dark).

### Changed
- **`src/App.jsx`** — `<StudySessionProvider>` added to the provider tree (above `<BrowserRouter>`).
- **`src/components/layout/Navigation.jsx`** — returns a fragment: the top `<nav>` (unchanged) + `<NavBottomTabs {...navProps} />` as a sibling.
- **`src/components/layout/NavMobile.jsx`** — slimmed to Wordmark (left) + `<FriendsDropdown>` + `<ActivityDropdown>` (right). The hamburger `<Sheet>`, `useCourseContext`, `useState`, and helper fns moved to `NavMenuSheet.jsx`. Friends + Bell (and their unread/pending badges) stay in the top bar.
- **`src/components/layout/NavDesktop.jsx`** — active-route helpers now import from `@/lib/navActive` via thin wrappers. **Behaviour byte-identical** — re-verified against a re-implementation of the old inline logic: 20 routes × 5 predicates, 0 mismatches (incl. the 7/7 nested-route tie-break).
- **`src/components/layout/PageContainer.jsx`** — outer wrapper gains `pb-[calc(3.5rem+env(safe-area-inset-bottom))] md:pb-0` (mobile bottom-bar clearance; computed 56px on a non-notched emulator, real inset added on a notched device via `viewport-fit=cover`). Ride-along: `bg-gray-50` → `bg-rv-bg-0` (`#f9fafb` → `#f9f9fb`, no visible regression).
- **`index.html`** — viewport meta gains `viewport-fit=cover`.
- **Content-clearance class appended to the root div** of pages not using `PageContainer` (additive class only, `bg-gray-50` left as-is): `src/pages/dashboard/Content/{BrowseNotes,MyFlashcards,MyNotes,MyContributions,NoteDetail,NoteUpload,NoteEdit,FlashcardCreate}.jsx`, `src/pages/dashboard/Study/{ReviewFlashcards,ReviewBySubject}.jsx`, `src/pages/admin/{AdminDashboard,SuperAdminDashboard,SuperAdminAnalytics}.jsx`.

### Fixed after verification (same 3-role live pass)
- **Review-session picker lost the bottom bar (7.1 regression).** `/dashboard/review-session` is a subject-picker LIST until the user taps Start; the first cut hid the bar on any `/dashboard/review-session` path → the user was stranded with no nav. Replaced the route match with a mounted-component signal: `StudySessionContext` + `StudyMode` sets `inStudySession` true on mount / false on unmount (covers both the `/dashboard/study` route and ReviewSession's embedded view). The picker keeps the bar; tapping Start (mounts `StudyMode`) removes it; "Back to Selection" restores it. `isFullScreenStudyRoute` helper removed from `navActive.js`.
- **`StudyMode` card clipped on the right at 390px (pre-existing, not a 7.1 regression — `StudyMode` was otherwise untouched).** Cause: `overflow-hidden` card + a no-wrap `Skip 24hr · Show Answer · ⋮` action row + `p-8` padding. Presentation-only fix in `src/pages/dashboard/Study/StudyMode.jsx`: card inner padding `p-8` → `p-5 sm:p-8 md:p-12` + `min-w-0` on the flex child; both action rows → `flex-wrap`; `Show Answer` button `px-8` → `px-6 sm:px-8`. No SRS / behaviour change.

### Notes
- **No SQL.** `DATABASE_SCHEMA.md` unchanged. No SRS / question-type / renderer work; the only `StudyMode` edit is the responsive fix above + the `inStudySession` mount flag.
- **Badge deviation:** the kickoff's "unread/pending badge on the bar" line assumed the bar might carry Friends/Bell. Under Layout A those stay in the top bar with their badges; no bottom tab maps to a counted entity without a new fetch. Noted in the /__design block.
- **Desktop:** the bar is `md:hidden` and the top nav is untouched at `md`+ — desktop pixel-identical by construction; confirmed in the per-role live sweep.

### Docs updated
- `docs/active/blueprint.md` (SSOT — Sprint 7.1 entry in Sprint History; §1.7 `NavBottomTabs`/`NavMenuSheet`; §1.8 `navActive.js`; Contexts table `StudySessionContext.jsx`), `docs/active/now.md` (Just Completed + live-verification result), `docs/reference/FILE_STRUCTURE.md` (4 new files). No `DATABASE_SCHEMA.md` change (no SQL).

---
## [2026-09-08] perf(sprint-7.0): Global Perf & Correctness — nav over-fetch, 400 race, cn() merge, forecast tone hierarchy (NO SQL)

Phase 7, sprint 1. Clears the isolated perf/correctness debt the Phase 6 live-verification report surfaced (Findings 3, 5, 6), before any question-type feature work. **Frontend only — no SQL, `docs/reference/DATABASE_SCHEMA.md` §1.4 unchanged. No study-loop behaviour change.** `npm run build` clean (7.2s); `npx eslint` clean on every changed file. **Verified per-role (student + professor + super-admin) on the dev server → live Supabase, 08/09/2026:** `/dashboard/notes` `profiles` 17→3 all roles, four nav RPCs 6→1 each; nav sweeps 0 fetch-4xx / 0 `console.error` / 0 `window.error`; role gating identical; 7.0-E inversion live (professor Progress "Due Today: 7" → amber, was neutral). SHIPPED `6c78f73` → `main` → Vercel. Operator follow-ups: disable Speed Insights in Vercel (7.0-C); optional cold-load spot-check on `revisop.com` (7.0-B, production-only path).

### Added
- **`src/contexts/NavDataContext.jsx`** (new) — `<NavDataProvider>` owns `useRole()` / `useNotifications(5)` / `useFriendRequestCount()` as ONE app-wide instance (mounted in `App.jsx`, above `<BrowserRouter>`, inside `CourseContextProvider`). Exports `useNavData()` (full bundle) and a drop-in `useRole` shim with the same return shape as `@/hooks/useRole`.

### Fixed
- **Finding 5 — nav / notification over-fetch.** Root cause: `AuthContext` called `setUser(session?.user ?? null)` on every supabase-js auth event with a fresh object reference, so every `[user]`-keyed effect app-wide re-fired ~12×/load. Fixes: (1) `AuthContext` `applySession()` sets `user` via a functional updater that returns the previous reference when `prev?.id === next?.id` (React bails — `user` identity stable across token refreshes / repeat SIGNED_IN); (2) the three nav hooks hoisted into `NavDataProvider`; `Navigation.jsx` + 9 former `useRole()` consumers read the context shim; (3) `updateUserTimezone` gated by a module-scoped `tzSyncedThisSession` → ≤1 `profiles` read/session; (4) `ProfileDropdown` reads the name from `user.user_metadata.full_name` first; (5) `CourseContext` exposes `role` + `courseLevel`, `BrowseNotes` consumes them instead of its own `profiles` read. **`/dashboard/notes` (super-admin, dev): `profiles` 17 → 3; `get_recent_notifications` / `get_unread_notification_count` / `friendships` / `role_permissions` 6 → 1 each.** (Prod Phase-6 baseline: `profiles` ×46, those four ×12.) Realtime subscriptions unaffected. → `docs/tracking/bugs.md` Finding 5 RESOLVED.
- **Finding 6 — 2× `400` on every authed page.** Root cause: `get_recent_notifications` / `get_unread_notification_count` `RAISE EXCEPTION 'Not authenticated'` (→ HTTP 400 `P0001`) when fired in the auth-init window with `auth.uid()` still NULL server-side — a frontend timing race, **not** an RPC defect (direct calls with a valid session all return 200; no grant / overload / signature issue). Fixed at the frontend layer by the Finding-5 `user`-identity stabilisation (removes the ×12 churn that kept the race landing). **No SQL.** Post-fix: zero 4xx across a 9-route soft-nav sweep (super-admin). → `docs/tracking/bugs.md` Finding 6 RESOLVED.
- **Finding 3 — web-vitals `startTime` TypeError.** Not in the repo (no `web-vitals` / `@vercel/speed-insights` / `@vercel/analytics` dep, no import, nothing in `index.html` / `vercel.json`). Injected by **Vercel Speed Insights** at the edge — not version-pinnable by us. Known upstream web-vitals soft-nav / bfcache issue; benign, 0/6 Phase-6 reproductions. **Resolution:** operator to disable Speed Insights in the Vercel project dashboard (RUM unused). → `docs/tracking/bugs.md` Finding 3 CLOSED (documented benign-upstream).
- **`<Num>` / `rv-*` class override (7.0-D).** `src/lib/utils.js` `cn()` now uses `extendTailwindMerge` registering `rounded → rec|obj`, `shadow → rv|rv-bar`, and the `text/bg/border-rv-*` colour scale. `rounded-rec`/`rounded-obj` and `shadow-rv`/`shadow-rv-bar` were genuinely un-merged (twMerge kept both — latent, no live collision); the `text-rv-*` half of the old `reference_rv_num_atom_tailwind_ordering` memo was already stale (tailwind-merge@3.4.0 resolved those via its permissive fallback). Regression-checked on `/__design` light + dark — computed radii/shadows/colours identical before/after. Sprint 6.5 `NUM_TYPE` workaround reverted in `Progress.jsx` `ForecastCard` → `<Num className={t.text}>`.

### Changed — Due / forecast tone hierarchy (7.0-E; Anand's product call: invert — "Due Today" is the loudest)
- **`src/pages/dashboard/Study/Progress.jsx`** `ForecastCard` `FORECAST_TONES`: `calm` (Due Today 0) / `amber` (1..`DUE_TODAY_ALARM_THRESHOLD` — "do these now") / `danger` (> threshold) / **new `quiet`** (`bg-rv-bg-1` / `border-rv-border` / `text-rv-ink-600`). "Next 7 / 30 Days" moved from `amber` → `quiet` (the softest — context, not a to-do). `DUE_TODAY_ALARM_THRESHOLD` unchanged (24). The pre-7.0 `neutral` tone removed.
- **`src/pages/Dashboard.jsx`** student "N items ready" CTA: legacy `bg-gradient-to-r from-green-50 to-emerald-50 border-green-200` + `text-green-*` + `bg-green-600` button → `bg-rv-amber-50 border-rv-amber-edge`, icon on amber, text on `--rv-ink-*`, button drops the override (default navy). "All caught up" card: legacy `bg-amber-50 border-amber-200` + `text-rv-navy` → `bg-rv-green-50 border-rv-border` + `text-rv-green` / `text-rv-ink-600` (calm, matches Progress "Due Today: 0"). No `red-50` / `amber-50` / `green-50` legacy Tailwind left on these surfaces. `ForwardLedgerMacro` already a navy magnitude ramp — unchanged.

### Changed — Finding 5 plumbing
- **`src/contexts/AuthContext.jsx`** — `applySession()` helper; identity-stable `setUser`; `tzSyncedThisSession` module guard (folds in the Sprint 6.5 `tzAlreadySetLogged` log-gate — the whole function now runs ≤1×/session).
- **`src/contexts/CourseContext.jsx`** — exposes `role` + `courseLevel` (already-fetched state, additive to the context value).
- **`src/App.jsx`** — `<NavDataProvider>` in the provider tree.
- **`src/components/layout/Navigation.jsx`** — one `useNavData()` call replaces the three hook calls.
- **`src/components/layout/ProfileDropdown.jsx`** — `user_metadata.full_name` first, `profiles` read only as fallback (also fixes a `react-hooks/set-state-in-effect` lint the naive version tripped).
- **`src/pages/dashboard/Content/BrowseNotes.jsx`** — role + enrolled course from `useCourseContext()` instead of a duplicate `profiles.select('role, course_level')`.
- **Import-path swap** (`@/hooks/useRole` → `@/contexts/NavDataContext`), no logic change: `AdminAnalytics`, `AdminDashboard`, `BulkUploadTopics`, `SuperAdminAnalytics`, `SuperAdminDashboard`, `BulkUploadFlashcards`, `ProfessorAnalytics`, `MyFlashcards`, `NoteDetail`. `Help.jsx` left on `@/hooks/useRole` (swap surfaced a pre-existing unrelated lint error at `Help.jsx:192`); `professor/ProfessorTools.jsx` dead/unrouted, left as-is.

### Notes
- **No SQL shipped.** `get_recent_notifications` / `get_unread_notification_count` / `role_permissions` / `friendships` / `profiles` unchanged. §1.4 / DATABASE_SCHEMA.md untouched.
- **Sentry:** 7.0 is a reasonable home for an init (error visibility before the epic sprints) — flagged, **not added** (needs Anand + a DSN).

### Docs updated
- `docs/active/blueprint.md` (SSOT — Sprint 7.0 entry in Sprint History; "Last Updated" → Sep 8, 2026), `docs/active/now.md` (Just Completed + session notes), `docs/tracking/bugs.md` (Findings 3/5/6 → resolved with evidence), `docs/reference/FILE_STRUCTURE.md` (`NavDataContext.jsx`), memory `reference_rv_num_atom_tailwind_ordering`.

---
## [2026-09-07] audit(db): Task 6.5-D — `get_following_leaderboard` reconstruction audit — FAITHFUL, Finding 2 fully closed (no fix)

Bounded follow-up to the Sprint 6.5 `[FIX]`. The 6.5 thread replaced the *whole* body of `get_following_leaderboard` with a reconstruction templated off `get_friends_leaderboard` (01_DIAGNOSTIC's capture of the live pre-fix body was lost before 02_FUNCTIONS overwrote the function), and `03_TEST`'s parity check validates the weekly-stat math, not the membership set — so the follow-scope was unverified.

**Outcome: faithful. No `[FIX]` shipped — no divergence found.**

### Added
- `docs/database/sprint6.5/04_AUDIT_current_definition.sql` — `[DIAGNOSTIC]`. Re-captures the current (reconstructed) live definition (`pg_get_functiondef`) so it is committed, plus a focused three-point diff (follow-join / population filter / result window) against the Sprint 3.5 behavioural contract. Documents that the original body is **unrecoverable from git**.
- `docs/database/sprint6.5/04_AUDIT_membership_test.sql` — `[TEST]`. The decisive membership check `03_TEST` lacked: builds the expected set independently (caller ∪ followed-students), impersonates the account, and asserts `get_following_leaderboard()`'s `user_id` set is **exactly** equal (no extras → scope not too wide; nothing missing → scope not too narrow / not collapsed to just the caller), one `is_self`, rank ordered by `reviews_this_week DESC`. `BEGIN/ROLLBACK`, no persisted writes. **RUN 07/09/2026 — 5/5 PASS** (see Findings).

### Findings
- **Current live body — captured 07/09/2026** (`pg_get_functiondef('public.get_following_leaderboard()'::regprocedure)`, pasted verbatim into `04_AUDIT_current_definition.sql`): **byte-identical to `02_FUNCTIONS`** — the deployed reconstruction is confirmed live, no out-of-band hand-edit. `SECURITY DEFINER` / `STABLE` / `proconfig = {search_path=public, extensions}`. (`pg_get_functiondef` renders `SET search_path TO 'public', 'extensions'` — two separately-quoted identifiers, equivalent to unquoted `public, extensions`; not the single-string outage form. Sibling `get_friends_leaderboard` is `VOLATILE` not `STABLE` — immaterial, `STABLE` is stricter for a pure read.)
- **Original definition — unrecoverable from git.** `git log -S 'get_following_leaderboard' --all` → 3 commits (`071395d` create, `4c5c884` doc, `72693fe` fix); Sprint 3.5 ran the `CREATE` directly in Supabase, no `.sql` ever committed; `git log --all --diff-filter=A/D` over `*leaderboard*` confirms `sprint6.5/01–03` are the only leaderboard SQL files that ever existed. Supabase backup restore not exercised. **Reference used:** the original behavioural contract documented in `DATABASE_SCHEMA.md` @ `071395d`.
- **Follow-graph join — MATCH.** `cohort` CTE = `SELECT auth.uid() UNION SELECT f.followee_id FROM public.follows f WHERE f.follower_id = auth.uid()`. Table `public.follows`, predicate `follower_id = auth.uid()`, projects `followee_id` → **directional** ("users the caller follows"), correct for a "Following" leaderboard. No `friendships` join; no reciprocal `AND EXISTS (reverse follow)` clause (that mutual semantic is `get_friends_leaderboard`'s, and was the primary risk vector — it did not materialise).
- **Population filter — MATCH.** `JOIN public.profiles p ON p.id = c.uid AND p.role = 'student'` — students-only, applied to the caller row too; no course / `account_type` filter. Matches the `071395d` contract ("Students only.") and both siblings.
- **Result window — MATCH.** `DENSE_RANK() OVER (ORDER BY reviews_this_week DESC, study_time_this_week_seconds DESC)` computed over the **full** cohort, then `WHERE rnk <= 20 OR uid = auth.uid()` → N = 20, caller always included regardless of rank, caller's rank exact; `is_self = (uid = auth.uid())` true on exactly one row. Matches the contract verbatim ("top 20 followees + the caller's own row regardless of rank", "Aggregates full followee set before applying top-20 limit — caller's rank is exact").
- Incidental checks also match: RETURNS TABLE shape (`rank, user_id, full_name, is_self, reviews_this_week, study_time_this_week_seconds`); week boundary `date_trunc('week', CURRENT_DATE)::date`; both weekly stats `COALESCE(…, 0)`; `SECURITY DEFINER` + `STABLE` + `search_path=public, extensions` + `auth.uid()` gate + `REVOKE FROM PUBLIC, anon` / `GRANT EXECUTE TO authenticated`.
- **Live membership set-equality — RUN 07/09/2026, 5/5 PASS.** The live follow graph is sparse (6 `follows` rows, 4 distinct followers, **max 1 followed-student per student** — no account follows ≥2), so `04_AUDIT_membership_test.sql` ran on the richest available account `f9377860-0991-4cdc-9679-f347c61d71b4` (follows 1 student → 2 expected rows): **exact set equality PASS** (RPC `user_id` set == caller ∪ followed-students, no extras / nothing missing — rules out both a too-wide join and a board collapsed to the caller), **one `is_self` PASS**, **rank ordered by `reviews_this_week DESC` PASS**. The >20 top-N cutoff and multi-followee ordering are unexercised on live data (contract-trivial, code matches). Also explains the earlier ambiguous "TestOutlook (you)"-only row — almost nobody follows anyone.

### Verdict
- Finding 2 (`docs/tracking/bugs.md`) — **FULLY CLOSED: FIXED, LIVE-VERIFIED & AUDITED FAITHFUL.** Live body captured (`pg_get_functiondef`) is byte-identical to `02_FUNCTIONS`; the three focus areas match the Sprint 3.5 contract; the live membership set-equality assertion passes on real data. No `[FIX]` shipped — no divergence. No frontend change (`row.rank` mapping unchanged).

### Docs updated
- `docs/tracking/bugs.md` (Finding 2 audit outcome), `docs/reference/DATABASE_SCHEMA.md` (`get_following_leaderboard` — audited follow-join predicate / filter / window now documented), `docs/active/blueprint.md` (SSOT — Task D flipped to RESOLVED/faithful), `docs/active/now.md`.

---
## [2026-09-07] fix(reskin): Sprint 6.5 — Verification Fixes (Phase 6 close-out) — LIVE-VERIFIED

Clears the two actionable findings from the 07/09/2026 Phase 6 live-verification report. **All of A/B/C/E + D live-verified per-role (student + professor + super-admin) on the dev server against live Supabase, 07/09/2026** — see "Verified" below. **Phase 6 reskin is fully closed once this is committed.**

Original scope: `Progress.jsx` (the last un-migrated high-traffic authed page) + its two progress sub-components move onto `--rv-*` + Plex + the mono `Num` atom; the "Items Mastered" stat is re-pointed to the SSOT (`get_mastered_cards`); the "Due Today" red alarm now engages only past a genuine backlog; the pre-existing `get_following_leaderboard` `42702` (Leaderboard "Following" tab 400) gets a `[FIX]` SQL set; the 77×/page timezone `console.log` is gated to once per session. Frontend-only for A/B/C/E — `npm run build` clean (18.1s); `npx eslint` clean on every changed file. **Task D: `02_FUNCTIONS` DEPLOYED to Supabase 07/09/2026** (`CREATE OR REPLACE` + `REVOKE`/`GRANT` + `NOTIFY` ran clean — the reconstructed body compiled against the live schema, so every referenced column resolved). `03_TEST` re-issued after a `text || "char"` cast error (`p.provolatile`) + switched to the repo `request.jwt.claims` JSON impersonation idiom + a semantic-parity assertion vs `get_friends_leaderboard` — **9/9 PASS** (shape identical, `SECURITY DEFINER`/`STABLE`/unquoted `search_path` preserved, grant = `authenticated`, no `42702`, rank monotonic, exactly one `is_self`, students-only, null-session rejected, and **weekly stats match `get_friends_leaderboard` for shared users → 0 mismatches**). **Live-verified 07/09/2026** — the student Leaderboard → Following tab renders a data row with no `400` and no `console.error`. D done.

### Added
- `src/pages/dashboard/Study/Progress.jsx` — `DUE_TODAY_ALARM_THRESHOLD = 24` module const (the "Due Today" tile only becomes a `--rv-danger` surface above this; a normal daily pile renders neutral, `0` renders calm-green).
- `docs/database/sprint6.5/01_DIAGNOSTIC_get_following_leaderboard_ambiguous_rank.sql` — pulls the live `get_following_leaderboard` + `get_friends_leaderboard` source, signatures, security metadata and EXECUTE grants so the fix can be ported onto the real body. Read-only.
- `docs/database/sprint6.5/02_FUNCTIONS_fix_get_following_leaderboard_ambiguous_rank.sql` — `[FIX]`. In-place fix, **no OUT-column rename** (so `LeaderboardWidget.jsx` `row.rank` is untouched and the SQL ships alone): `#variable_conflict use_column` pragma + the `DENSE_RANK()` result aliased `rnk` (never `rank`) + every reference table-qualified. RETURNS TABLE shape, `SECURITY DEFINER`, `STABLE`, unquoted `search_path TO public, extensions`, the `auth.uid()` gate and the `authenticated`-only grant are all preserved. Body carries a ⚠️ note to diff against `01` before running.
- `docs/database/sprint6.5/03_TEST_get_following_leaderboard.sql` — `BEGIN/ROLLBACK`. Shape parity with `get_friends_leaderboard`, security-metadata + grant preservation, no-`42702` behavioural run (impersonated student with a followee), `DENSE_RANK` monotonicity, exactly-one `is_self` row, students-only, null-session rejection.

### Changed — Progress page migration (`src/pages/dashboard/Study/Progress.jsx`, class-reference swaps only — no DOM/layout change)
- `<PageContainer>` gains `className="font-plex"`.
- Top stat tiles (`StatCard`): container `bg-white shadow-sm border-gray-200` → `bg-rv-bg-1 shadow-rv border-rv-border`; the `text-2xl font-bold text-gray-900` value span → the `<Num>` atom (`IBM Plex Mono`, `tabular-nums`); labels/subs → `text-rv-ink-600` / `text-rv-ink-400`. The four decorative accent icons (orange/amber/green `lucide` glyphs) left as-is — decorative, not status, matches the 6.3 Dashboard precedent (`Award text-amber-500`).
- **"Items Mastered" stat re-pointed** — the lifetime-stats effect no longer computes `mastered` as `new Set(activeReviews.map(r => r.flashcard_id)).size` ("distinct cards ever reviewed"); it now reads `supabase.rpc('get_mastered_cards', { p_user_id }).length` — the exact SSOT the Sprint 6.3 dashboard "Mastered" tile and this page's own "Mastered Items (N)" list use (`reviews.status='mastered'`). Same `lifetimeLoading` gate; one added RPC call on mount, no schema change.
- **"Due Items Forecast" tiles** — `ForecastCard` refactored from a raw `accent` class string to a `tone` prop (`calm` / `neutral` / `amber` / `danger`), all on `--rv-*`: `calm` = `text-rv-green bg-rv-green-50`, `neutral` = `text-rv-ink-900 bg-rv-bg-1`, `amber` = `text-rv-amber-ink bg-rv-amber-50 border-rv-amber-edge`, `danger` = `text-rv-danger border-rv-danger`. **"Due Today" logic:** `0` → `calm`; `1..24` → `neutral` (no alarm — the Sprint 6.0 "no red for a normal pile" note); `> 24` → `danger`. "Next 7 / 30 Days" → `amber`. The tile numeral is now `<Num className="text-inherit">` so it takes the tone colour. No `red-50` / `amber-50` legacy Tailwind left.
- Section eyebrows (`<h2 class="text-sm font-semibold text-gray-500 uppercase tracking-wide">`) → the 6.1 `<Label>` primitive.
- Window/tab pill groups: track `bg-gray-100` → `bg-rv-bg-2`, active `bg-white text-gray-900 shadow-sm` → `bg-rv-bg-1 text-rv-ink-900 shadow-rv`, inactive `text-gray-500 hover:text-gray-700` → `text-rv-ink-400 hover:text-rv-ink-600`.
- "Performance by Question Type" (`QuestionTypeRow`): card `bg-white border-gray-200` → `bg-rv-bg-1 border-rv-border`; the progress bar `bg-gray-100` track + `bg-amber-500` fill → `bg-rv-slate-50` + `bg-rv-navy` (matches the 6.3 educator accuracy-bar); counts + `%` → `<Num>`; `divide-gray-50` → `divide-rv-border`; skeleton `bg-gray-100` → `bg-rv-bg-2`.
- Suspended Items collapsible: amber theme (`bg-amber-50 border-amber-200 text-amber-900/700/600`) → navy-tint (`bg-rv-navy-50 border-rv-border`, `text-rv-ink-900` heading, `text-rv-ink-400` sub, `text-rv-navy` icons/chevrons); inner subject cards `bg-white`/`bg-gray-50`/`divide-gray-100` → `bg-rv-bg-1`/`bg-rv-bg-2`/`divide-rv-border`. The green **Unsuspend** button override kept (semantic positive action, 6.3 precedent).
- Mastered Items collapsible: green theme → `--rv-green` tokens (`bg-rv-green-50`, `text-rv-green` heading/icons, `border-rv-border`); the "Mastered" pill → `text-rv-green bg-rv-green-50 border-rv-border`. Green kept as the genuine "mastered" success semantic, now on-token.
- Empty states + "No course set" card: `bg-amber-50 border-amber-200` + `text-[#1e1b4b]` + `text-amber-700` + amber `BookOpen` + amber outline button → `bg-rv-navy-50 border-rv-border` + `text-rv-ink-900` + `text-rv-ink-400` + `border-rv-navy-400 text-rv-navy` button.
- Unsuspend dialog quote text `text-gray-700` → `text-rv-ink-600`; the `bg-green-600` confirm button kept (semantic).
- "By Course" selected-course button `bg-[#1e1b4b] text-white` → `bg-rv-navy text-white`; unselected `hover:border-amber-400 hover:text-amber-600` → `hover:border-rv-navy-400 hover:text-rv-navy`.

### Changed — progress sub-components
- `src/components/progress/StudyHeatmap.jsx` — container/skeleton/error `bg-white border-gray-200` + `bg-gray-200/100` → `bg-rv-bg-1 border-rv-border` + `bg-rv-bg-2`; all `text-gray-400/700` labels → `text-rv-ink-400/600`. The 4-step activity ramp `bg-green-200/400/600/800` → a single-hue navy ramp `bg-rv-navy/20 · /40 · /70 · bg-rv-navy` (magnitude encoding, not a status colour — green now carries "mastered" on this page); empty cell `bg-gray-100` → `bg-rv-bg-2`. The `text-red-500` load-error kept.
- `src/components/progress/SubjectMasteryTable.jsx` — all `bg-white`/`bg-gray-50`/`border-gray-*`/`divide-gray-*`/`text-gray-*` → `--rv-*`; the `bg-amber-500` mastery bar + `bg-gray-100` track → `bg-rv-navy` + `bg-rv-slate-50`; the `bg-amber-100 text-amber-700` due-count badge → `bg-rv-amber-50 text-rv-amber-ink`, wrapped in `<Num>`; `total` / `reviewed` / `mastery %` figures → `<Num>`. `text-red-500` load-error kept.

### Changed — timezone log (`src/contexts/AuthContext.jsx`)
- Module-scoped `tzAlreadySetLogged` guard: the `⏰ Timezone already set: …` `console.log` (previously fired on every `getSession` resolve + `SIGNED_IN` event, ~77×/page) now logs at most once per session. The `updated` / `could-not-detect` / error branches are untouched.

### Deviations
- **Task D `02_FUNCTIONS` is a reconstruction** — built in the no-DB-access build session from `DATABASE_SCHEMA.md` + the live `get_friends_leaderboard` sibling. Deployed 07/09/2026; `03_TEST` 9/9 PASS. **Audited faithful — Task 6.5-D, 07/09/2026** (see the audit entry dated 2026-09-07 above): the current live body was captured via `pg_get_functiondef` and is **byte-identical to `02_FUNCTIONS`**; the original body is unrecoverable from git (Sprint 3.5 ran the `CREATE` directly in Supabase — no `.sql` ever committed); the reconstruction was diffed against the Sprint 3.5 behavioural contract in `DATABASE_SCHEMA.md` @ `071395d` — follow-graph join (directional, no `friendships`, no reciprocal clause), population filter (students-only) and result window (`DENSE_RANK` over full cohort → top-20 + self, exact rank) **all MATCH**; and the live membership set-equality assertion (`04_AUDIT_membership_test.sql`) **passed 5/5** on a real followee-bearing account (RPC `user_id` set == caller ∪ followed-students exactly, one `is_self`, rank by reviews DESC). No `[FIX]` beyond the `42702` resolution — no divergence found.
- **OUT column NOT renamed** — `get_following_leaderboard` keeps `rank` as its return column, so `LeaderboardWidget.jsx` needs no change.
- **Due Today threshold N = 24** — matches the Sprint 6.0 note ("~24"). Band model: `0` calm / `1..24` neutral / `>24` danger. Implemented as the recommendation; flagged here for review.
- **StudyHeatmap ramp** converted green → navy rather than kept as a data-viz carve-out, because green is now the "mastered" semantic on the same page and a green calendar would read as noise.
- Stat-tile accent icons and container `rounded-lg` radii left unchanged (colour/type/border/bg swaps only, matching the 6.3 "shadcn Card radius left" precedent).

### Verified — local + live per-role (dev server → live Supabase, inline browser, 07/09/2026)
- `npm run build` clean (18.1s); `npx eslint` clean on `Progress.jsx`, `StudyHeatmap.jsx`, `SubjectMasteryTable.jsx`, `AuthContext.jsx`.
- **Student (TestOutlook)** `/dashboard/progress` computed styles: container `IBM Plex Sans`; eyebrows Plex / 11px / 500 / uppercase / `0.77px` / `rgb(107,114,128)` = `--rv-ink-400` (exact `Label` spec); every stat / forecast / Subject-Mastery / Question-Type numeral `IBM Plex Mono` + `tabular-nums`; Subject-Mastery + Question-Type bars `bg-rv-navy` `rgb(30,27,75)` on `bg-rv-slate-50` `rgb(241,245,249)`; heatmap ramp `bg-rv-navy/20·/40·/70·navy` → `rgba(30,27,75,x)` (green ramp gone); "Mastered Items (1)" collapsible `bg-rv-green-50` / `text-rv-green`.
  - **B — three-way Mastered equality:** Progress "Items Mastered" tile **1** == Progress "Mastered Items **(1)**" list == Dashboard "Mastered" tile **1** (was **29** pre-fix). Dashboard Reviews/7d **10** == Progress "Items Reviewed" **10**.
  - **C — "Due Today: 0"** → `bg-rv-green-50 border-rv-border text-rv-green` (`rgb(22,163,74)`), mono numeral — calm, not red. "Next 7/30 Days" → `bg-rv-amber-50 border-rv-amber-edge` (token classes, no legacy `amber-50`/`red-50`).
  - **D — Leaderboard → Following tab** renders a data row, no `400`, no error state, no `console.error`.
- **Professor (CA Anand More / CA Intermediate)** `/dashboard/progress`: same `--rv-*` / Plex / mono confirmations; **Suspended Items (1)** collapsible migrated — wrap `bg-rv-navy-50` `rgb(240,240,248)` / border `--rv-border` / `text-rv-ink-900` header / `text-rv-navy` icon (was amber); inner subject card `bg-rv-bg-1` / `--rv-border`, group header on `bg-rv-bg-2`; **Unsuspend button green kept** (`text-green-700 border-green-300`, semantic positive action).
  - **B — "Items Mastered" 0** (was **28** pre-fix); the "Mastered Items" collapsible correctly hidden (0 rows).
  - **C — "Due Today: 7"** → `bg-rv-bg-1 border-rv-border text-rv-ink-900` (`rgb(10,14,26)`) — **NEUTRAL, not the red alarm** (the exact regression the report flagged: professor's `7` showed red pre-fix).
- **Super-admin (Anand)** `/dashboard/progress`: `--rv-*` / Plex / mono confirmed; "Due Today: 0" → calm-green; all sections render (no Suspended/Mastered rows for this account). **`danger` branch proof:** a cloned forecast tile with `border-rv-danger text-rv-danger` computes `rgb(185,28,28)` (`#b91c1c`) — so `dueToday > 24` renders red border + red numeral; the `>24` path is a one-line ternary, unexercised live only because no test account currently has a >24 daily backlog.
- **E — `⏰ Timezone already set`:** exactly **1× per page load** across all three sessions and ~6 page loads (console tail shows one `⏰` per `[vite] connecting` block; the pre-auth login page has none). Was 77+/load.
- **Console:** zero `console.error` / warnings on `/dashboard/progress` + `/dashboard` + the Leaderboard Following tab, all three roles.
- Transient `—` / skeleton flashes on the forecast + question-type sections during interaction are pre-existing re-render churn (the `user`-dependency effects re-run when the auth/course context re-creates `user` — Finding 5 territory), not a 6.5 regression; data always settles.

### Deferred to Phase 7 (infra/perf ticket)
- Finding 3 — web-vitals `startTime` TypeError (instrumentation, did not recur).
- Finding 4 — now partially addressed (the timezone log); the rest of the console-debug audit.
- Finding 5 — nav/notification over-fetch (`profiles` ×46, four RPCs ×12 per page load).
- Finding 6 — the 2× `400` nav/notification RPC family on every authed page.
- Nav-shell rebuild (left-rail / bottom-tab); question-type epic; exam-date anchor; streak + weekly-accuracy `created_at` → `last_reviewed_at`.

---
## [2026-09-05] feat(reskin): Sprint 6.4 — Study Loop UI Reskin (Phase 6 close-out)

The front/back review loop migrates onto the unified frame: the card under review on the 6.1 `Card` primitive at `r14` / `--rv-bg-1` / Plex; the grade row is now the neutral `GradeButtonRow` (three equal navy-outline ≥48px targets, mono interval, `ForwardLedgerMicro`, slate miss — no traffic-light colour) wired to the session-cached `get_srs_ladder_config`; the revealed answer is neutralised (navy `ANSWER` chip, `AnswerOption` `correct` state de-greened); `VerifiedEdge` renders once answered; a subtle post-forward animation plays on grade submit (reduced-motion → fast fade); the session-complete / "All Caught Up" states move onto tokens. Literata activates for long flashcard answers (≥ 320 chars) via lazy load. **No SRS behaviour change** — same `submit_review`, same queue, same skip/suspend semantics; presentation + interval display only. `npm run build` clean (7.6s); `npx eslint` clean on every changed file. **No core-reskin SQL.**

### Pre-work findings
- **Study-loop map.** `src/pages/dashboard/Study/ReviewSession.jsx` is a subject-picker wrapper that delegates the entire card UI to `<StudyMode>` via the `flashcards` prop. `src/pages/dashboard/Study/StudyMode.jsx` (one 1189-line file) renders the card, Show Answer, grade row, skip/suspend/reset menu, progress bar, and both session-complete states — there is no separate front/back component (the flip is inline JSX gated on `showAnswer`). **One reskin covers both entry paths;** ReviewSession keeps only a light tokenisation of its own chrome (subject list, "All Caught Up", active-session banner).
- **Interval computation.** Unchanged from the live SRS-Ladder Phase-3 `gradePreview` `useMemo`: one-time `get_srs_ladder_config()` on mount, zero per-card network; `qt = card.question_type || 'flashcard'`; new card (`rung` null) → Hard `relearn_step_days` (1) · Medium `intervalFor(new_card_rung.medium=1)` · Easy `intervalFor(new_card_rung.easy=2)`; rung `r` → Hard `1` · Medium `intervalFor(min(r,7))` · Easy `intervalFor(min(r+1,7))`. Mirrors `srs_preview` / `submit_review` by construction (single `srs_ladder_rules` row read by all three).
- **Items-Reviewed (7d) fix — approved, no schema/function SQL.** `reviews.last_reviewed_at` already exists (timestamptz, `DEFAULT now()`) **and has always been maintained** — pre-ladder `handleRating` set it on every UPDATE/INSERT, and `submit_review` sets it too. The bug is purely that the stat *queries* filter on `reviews.created_at` (the card's FIRST review — never moves, since `submit_review` UPDATEs the one `UNIQUE(user_id, flashcard_id)` row). Fix = re-point the "Items Reviewed" recency filter to `last_reviewed_at ?? created_at`. Streak + weekly-accuracy left on `created_at` for a Phase 7 analytics pass (operator decision). One-off `[DATA]` backfill provided for NULL rows (expected empty; frontend `?? created_at` fallback means it is not a deploy-order blocker).
- **Literata trigger.** No note/case-study bodies exist in the front/back loop (Phase 7). The only reading-length content is a long flashcard answer (`back_text`). Trigger: lazy-load Literata + apply `--rv-font-read` to the revealed answer body only when `back_text.trim().length >= 320` (`LITERATA_MIN_CHARS`). Never on session start, never on chrome. `REVISOP_LITERATA_ENABLED` flipped `true`.
- **Post-forward animation spec.** Answered card "files forward" — `translateY(-10px) scale(.97)` + fade over 240ms `cubic-bezier(.4,0,.2,1)`; next card rises in from `translateY(8px)` + fade over 180ms (120ms delay). `prefers-reduced-motion: reduce` → 100ms opacity-only crossfade, no transform. Additive `@keyframes` in `index.css`.
- **Before-screenshots + live full-session run: pending an operator-supplied student session on `revisop.com`** (no login available in the build session).

### Added
- `src/index.css` — `@keyframes rv-forward-out` / `rv-forward-in` + `.rv-forward-out` / `.rv-forward-in` utilities, with a `prefers-reduced-motion` override collapsing both to a 100ms linear opacity fade.
- `src/lib/revisop-tokens.js` — `LITERATA_MIN_CHARS = 320` + `isReadingBody(text)` helper (guarded by `REVISOP_LITERATA_ENABLED`); `REVISOP_LITERATA_ENABLED` flipped `false → true`.
- `docs/database/sprint6.4/01_DIAGNOSTIC_items_reviewed_recency.sql` — `last_reviewed_at` NULL coverage + `< created_at` sanity + re-point impact + created→last-reviewed gap distribution. Read-only, no ordering constraint.
- `docs/database/sprint6.4/02_DATA_backfill_last_reviewed_at.sql` — `UPDATE reviews SET last_reviewed_at = created_at WHERE last_reviewed_at IS NULL` (idempotent; expected 0 rows; run only if `01` reports NULLs).

### Changed — study loop (`src/pages/dashboard/Study/StudyMode.jsx`)
- Card frame `bg-white rounded-xl shadow-xl` → `<Card elevated>` from `@/components/revisop` at `rounded-obj` (r14) / `--rv-bg-1` / `--rv-border` / `font-plex`, with a leading `<VerifiedEdge on={showAnswer && currentCard.is_verified} />` rail and `key={currentIndex}` + `rv-forward-in` / `rv-forward-out` animation classes driven by a new `transitioning` state.
- Grade row: the three shadcn `<Button variant="outline">` with `border-red-300`/`border-yellow-300`/`border-green-300` + `XCircle`/`AlertCircle`/`CheckCircle` icons + `fmtInterval` sublabels → one `<GradeButtonRow>` fed by a new `gradeButtons` `useMemo` (`{label, rating, iv:'Nd', bucket:bucketForDays(days)}` from `gradePreview`). `handleRating` unchanged except the advance now waits out the animation (`prefersReducedMotion() ? 100 : 240` ms). `fmtInterval` + the `CheckCircle`/`XCircle`/`AlertCircle` imports removed (now unused).
- Revealed answer: `ANSWER` chip `bg-green-100 text-green-700` → `bg-rv-navy-50 text-rv-navy`; `QUESTION` chips → `bg-rv-bg-2 text-rv-ink-600`; answer body gains `font-literata font-normal leading-relaxed text-[1.35rem]` when `isReadingBody(back_text)`.
- Progress bar track `bg-gray-200` → `bg-rv-bg-2`, fill `bg-[#1e1b4b]` → `bg-rv-navy`; the Easy/Medium/Hard session counters de-coloured — `CheckCircle`/`AlertCircle`/`XCircle` green/yellow/red → `Check`/`Minus`/`X` in `text-rv-ink-400`, mono tabular counts.
- Session-complete (normal + preview-wall) + "No flashcards" empty + loading spinner → `<Card>` / `--rv-*` / Plex; the green/yellow/red result tiles → neutral `--rv-border` tiles with mono `Num` figures (Hard tile keeps a subtle slate tint, never red). Header + progress strip `bg-white border-gray-200` → `bg-rv-bg-1 border-rv-border`; page ground `bg-amber-50` → `bg-rv-bg-0`. Show Answer button → full-width, `min-h-[48px]`.
- Skip button loses its `hover:text-orange-600 hover:border-orange-300`; the `text-red-600` Suspend/Reset dropdown items kept (semantic destructive affordance, 6.2 precedent).

### Changed — review-session chrome (`src/pages/dashboard/Study/ReviewSession.jsx`)
- Subject-list `Card`s, "All Caught Up! 🎉" empty state (green circle → `bg-rv-navy-50` / `text-rv-navy`), "Reviewing: N cards due" banner (`bg-amber-100 border-amber-300` → `bg-rv-navy-50 border-rv-navy-100`), loading state, and page grounds → `--rv-*` + `font-plex`; "items due" counts → mono tabular. shadcn `Card` radius left (6.3 precedent); border → `border-rv-border`.

### Changed — primitives + "Items Reviewed" re-point
- `src/components/revisop/AnswerOption.jsx` — `correct` state de-greened: `border-rv-green bg-rv-green-50` → `border-rv-navy bg-rv-navy-50`, badge `bg-rv-green` → `bg-rv-navy`, "Correct answer" label `text-rv-green` → `text-rv-navy`. Correctness now reads via the check/cross glyph + label alone. `missed` (slate) unchanged. Only consumer is `/__design`.
- `src/pages/Dashboard.jsx` — `fetchPersonalStats` reviews `.select()` adds `last_reviewed_at`; the "Reviews / Last 7 days" tile count + the GoalProgressWidget today-count now filter on `last_reviewed_at || created_at`; `weeklyReviews` (accuracy basis) + streak left on `created_at`.
- `src/pages/dashboard/Study/Progress.jsx` — window-stats query `.select('quality')` + `.gte('created_at', …)` → `.select('quality, last_reviewed_at, created_at')` with client-side `last_reviewed_at || created_at` window filter; the streak helper left on `created_at`.

### Changed — QA route (`src/pages/dev/DesignShowcase.jsx`)
- New Sprint 6.4 "Study loop" block in `ReskinGallery` (inherits the light/dark toggle + both-themes view): the reskinned review card on r14 with `VerifiedEdge`, a question/answer toggle, the long-answer body in Literata with the ≥320-char note, `GradeButtonRow` with sample computed intervals (`→ 1d / 7d / 14d`), the neutral `AnswerOption` correct/missed/dim row, a "Replay post-forward animation" control, and a compact session-complete card. Type-system Literata caption updated (gate now ON).

### Verified
- `npm run build` clean (7.6s); no `DesignShowcase` chunk in `dist/`. `npx eslint` clean on all changed files.
- `/__design` **light + dark** (dev server, computed styles): review card `border-radius 14px` / `bg #fff` (`#171a35` dark) / `border #e2e8f0` (`#2e3355` dark) / `IBM Plex Sans`; `VerifiedEdge` `width 3px`, transparent when off, `--rv-navy` when on; `GradeButtonRow` `min-height 88px`, `border-color #4a4590` (`#8b96e8` dark), mono label `IBM Plex Mono` `#1e1b4b` (`#a5b4fc` dark), no red/amber/green; `AnswerOption` `correct` = `border #1e1b4b` / `bg #f0f0f8` / label `#1e1b4b` (no green); answer body computes `font-family: Literata…` at ≥320 chars and `document.fonts.check('16px Literata')` = true (lazy fetch fired on reveal); `rv-forward-out` / `rv-forward-in` `@keyframes` registered.
- Green-removal grep: zero `green-`/`yellow-`/`border-red-`/`orange-` colour-coded correctness left in `StudyMode.jsx` / `ReviewSession.jsx` / `GradeButtonRow.jsx` / `AnswerOption.jsx`.
- **Pending (needs an operator student session on `revisop.com`):** genuine before-screenshots; the full live review-session run; the ≥3-rung × {Hard,Medium,Easy} parity matrix (client preview == `srs_preview` == what `submit_review` writes); the per-card `read_network_requests` trace (one `get_srs_ladder_config` on mount, one `submit_review` per grade, one `get_study_queue`, zero `srs_preview`/config refetches between cards); reduced-motion emulation; Literata load trace on a real long back; the "Items Reviewed (7d) goes non-zero after a re-review" check.

### Deferred to Phase 7
- New question types (MCQ multi / FITB / match / case-study) + the full unified question frame beyond front/back; exam-date anchor; nav-shell rebuild (left-rail / bottom-tab); the pre-existing 4× `401` console noise; streak + weekly-accuracy `created_at` → `last_reviewed_at` re-point; any un-migrated semantic palette (`IntervalChip` `tone="green"`, study-loop dropdown `text-red-600`).

---
## [2026-09-05] feat(reskin): Sprint 6.3 — Dashboards Reskin + Forward Ledger live + gamification parked + overlay-surface family

Dashboards migrated onto `--rv-*` + Plex; the Forward Ledger macro ships for the first time against real scheduled data; the "You vs Class" widget is removed from the student dashboard; the educator dashboard gains an accuracy-by-question-type widget + a cohort forward-load ledger; the overlay/dropdown atom family + the four nav right-side dropdowns finish the colour migration deferred from 6.2. `npm run build` clean (17.4s); `npx eslint` clean on every changed file. **3 new RPCs ✅ deployed & verified 05/09/2026** — `02_TEST` 12/12 real assertions PASS incl. every `[CRITICAL]`; one check FAILed as a test-fixture bug only (summed all 8 lanes assuming the real test student had no pre-existing reviews) → rewritten delta-based.

### Pre-work findings
- **One file renders all four dashboards** — `src/pages/Dashboard.jsx`, role branch on `userRole` (`professor` / `admin` / `super_admin` / else student). `src/pages/admin/AdminDashboard.jsx` + `SuperAdminDashboard.jsx` are the `/admin` · `/super-admin` management consoles and are **out of scope** (the "admin/super-admin dashboard" with "Needs Review" is the `Dashboard.jsx` branch).
- **No gamified widget exists on any dashboard** to remove — the dashboard only fires a transient badge *toast* (`useBadges` → `unnotifiedBadges`), and the "My Achievements" link already lives in the nav `ProfileDropdown`, not on the dashboard. Operator decision (asked): **park the `AnonymousStats` "You vs Class" widget** (remove from the student dashboard; component + `get_anonymous_class_stats` RPC left in the repo, DB untouched). `LeaderboardWidget` + the Streak tile kept (reskinned as normal tiles). Achievements link left where it is.
- **Due-number trace: already clean.** Student `reviewsDue` reads `get_study_queue` (Sprint 6.0); `get_due_forecast` is not called on any dashboard; the dashboard widgets do zero `next_review_date`/`skip_until`/due arithmetic. Nothing to migrate — the "no client-side due math" grep already passes.
- **Educator accuracy data-check: CLEARS.** `reviews.quality` (1=Hard / 3=Medium / 5=Easy; 0=skip) ⋈ `flashcards.question_type` via the established `get_professor_*` cohort join supports "accuracy by question type." Accuracy definition (operator-confirmed): **hit = graded Medium or Easy (`quality IN (3,5)`), miss = Hard (`quality = 1`)**, `quality = 0` excluded from the denominator, `question_type = 'concept_card'` excluded entirely.
- **Forward Ledger data gap.** `get_due_forecast` returns only 3 cumulative scalars (`due_today` / `due_next_7` / `due_next_30`); `get_study_queue` has no future rows. Neither can drive the 8-lane `ForwardLedgerMacro`. Operator decision (asked): **add a small forecast-buckets RPC** rather than ship a 3-lane adaptation or defer.
- **Items-Mastered re-point** (carried from 6.4): operator approved the ride-along since the "Mastered" tile is being rebuilt. Before → distinct cards ever reviewed (`new Set(actualReviews.map(r => r.flashcard_id)).size`, a misnomer). After → real mastered count (`get_mastered_cards(p_user_id).length`, `reviews.status='mastered'` via the SRS ladder). Sublabel "Unique items" → "Items mastered".

### Added — SQL (`docs/database/sprint6.3/`)
- **`01_FUNCTIONS_dashboard_reskin_rpcs.sql`** — three SECURITY DEFINER read RPCs, established L5 IDOR idiom (self-or-admin / professor-or-admin), unquoted `search_path`, `REVOKE public/anon` + `GRANT authenticated`:
  - `get_due_forecast_buckets(p_user_id)` → 8 rows `(bucket_index, bucket_label, scheduled_count)`, the student forward-scheduled load keyed to `REVISOP_BUCKETS`/`BUCKET_DAYS` (`Today · 1d · 3d · 6d · 2w · 1mo · 3mo · 6mo+` at centre-day `[0,1,3,6,14,30,90,180]`, nearest-centre assignment; overdue folds into lane 0). Same "counts as a scheduled review row" predicate as `get_due_forecast` (active · not concept_card · course-filtered · visibility-guarded · `skip_until` not in the future).
  - `get_educator_accuracy_by_qtype(p_professor_id, p_course_level)` → one row per `question_type` with `total_graded` / `hits` / `accuracy_pct`, using the ladder's own hit/miss mapping; `concept_card` excluded; `HAVING` ≥ 1 graded review.
  - `get_educator_cohort_forecast_buckets(p_professor_id, p_course_level)` → the cohort variant of the first RPC, summed across every student with an active review on one of the educator's course cards.
- **`02_TEST_dashboard_reskin_rpcs.sql`** — BEGIN/ROLLBACK, impersonation idiom: 8-lane shape, overdue→lane-0, +30d→lane-5, +400d→lane-7, concept-card exclusion `[CRITICAL]`, accuracy hit/miss + skip-excluded-from-denominator, `concept_card` never returned `[CRITICAL]`, IDOR raises for a non-owned cohort `[CRITICAL]` (×2), cohort 8-lane shape.

### Changed — dashboards (`src/pages/Dashboard.jsx`)
- `<PageContainer>` gains `className="font-plex"`; the 8 section eyebrows restyled to the 6.1 `Label` spec (`font-plex text-[11px] font-medium uppercase tracking-[0.07em] text-rv-ink-400`); all 6 stat-tile numerals → mono tabular figures (`font-plex-mono … [font-variant-numeric:tabular-nums] text-rv-ink-900`, i.e. inline `Num`).
- Palette migration (colour-only, no DOM/layout change): `text-muted-foreground`→`text-rv-ink-400` (30), `hover:border-primary`→`hover:border-rv-navy-400` (21), `hover:bg-accent`→`hover:bg-rv-bg-2` (20), `text-amber-600`→`text-rv-navy` (17, icon accents), `p-2 bg-amber-100 rounded-lg`→`p-2 bg-rv-navy-50 rounded-rec` (12 icon chips), `p-2 bg-green-100 rounded-lg`→`p-2 bg-rv-green-50 rounded-rec` (4), `text-gray-{900,800,700,500,400}`→`text-rv-ink-{900,900,600,400,400}`, `border-gray-200`→`border-rv-border`, `text-primary`→`text-rv-navy`, `text-[#1e1b4b]`→`text-rv-navy`. **Left on their own palette (semantic, per the 6.2 precedent):** the green "Start Review" CTA gradient + button, the amber status surfaces (`bg-amber-50 border-amber-200` "All caught up" / "Get Started" / "Needs Attention"), the red "Needs Review" surfaces, the red "Elevated" badge, `text-red-*` sign-out/high-priority, `text-green-500`/`text-orange-500` lucide accents, the "My Reports" status-pill config map.
- **Student:** new "Forward load" section — `<ForwardLedgerMacro data={forecastSeries} unit="items" />` inside a `Card`, gated on `forecastSeries.some(v => v > 0)`; fed by `get_due_forecast_buckets` folded to `number[8]`. `<AnonymousStats>` removed (+ its import, `classStats` state, `fetchClassStats`, `hasUserActivity` state/setter, the `activeCourse` effect's `fetchClassStats` call). "Mastered" tile re-pointed to `get_mastered_cards` (see pre-work).
- **Educator:** new "Accuracy by question type" widget (`get_educator_accuracy_by_qtype` → per-type navy bar on a `--rv-slate-50` track, `Num` numerals, footnote "Hit = graded Medium or Easy; Hard = miss. Concept cards excluded.") and a new "Cohort forward load" ledger (`get_educator_cohort_forecast_buckets` → `<ForwardLedgerMacro … unit="reviews" />`), both before the Activity Feed, both self-gating on non-empty data. `activeCourse` effect repurposed to re-fetch these on course switch. New `formatQuestionType()` slug→label helper.
- **Settled-card rule honoured:** `git diff` shows **no new conditional** around "Needs Attention" (educator) or "Needs Review" (admin/super-admin) — the pre-existing `length > 0 ? … : …` ternaries *inside* their classNames are unchanged; both still render unconditionally.

### Changed — overlay-surface family (`src/components/ui/`)
- `select.jsx` / `dropdown-menu.jsx` / `popover.jsx` / `command.jsx` / `switch.jsx` migrated onto `--rv-*` (no shadcn token *value* edited — only class references swapped, same method as 6.2): surface `bg-popover`→`bg-rv-bg-1`, `text-popover-foreground`/`text-foreground`→`text-rv-ink-900`, bare `border`/`border-input`→`border-rv-border`, `bg-muted`/`bg-border` separators→`bg-rv-border`, `text-muted-foreground`→`text-rv-ink-400`, active/selected `bg-accent`+`text-accent-foreground`→`bg-rv-navy-50`+`text-rv-navy` (menu/command items) or `bg-rv-bg-2` (sub-trigger hover), `rounded-md`/`rounded-sm`→`rounded-rec`, `shadow-md`/`-lg`→`shadow-rv`, added `font-plex`. `select` trigger mirrors the 6.2 `Input` shell (navy focus ring + `border-rv-navy-400`). `switch`: `bg-blue-600`/`ring-blue-500`→`bg-rv-navy`/`ring-rv-navy`, off-state `bg-gray-200`→`bg-rv-border-strong`, thumb `bg-white`→`bg-rv-bg-1`, `ring-offset-white`→`ring-offset-rv-bg-1`.
- Verified on `/__design` (computed styles): `SelectContent` bg `#fff` (`--rv-bg-1`) / border `#e2e8f0` (`--rv-border`) / radius `4px` / `IBM Plex Sans`; `SelectTrigger` same; `Switch` on = `rgb(30,27,75)` (`--rv-navy`); dark frame gallery bg `#0d0f24` (`--rv-bg-0` dark) + navy swatch `#a5b4fc` (accent lavender).

### Changed — nav right-side dropdowns (`src/components/layout/`)
- `ProfileDropdown` / `FriendsDropdown` / `ActivityDropdown` / `CourseSwitcher` — trigger buttons + portaled menu bodies finish the colour migration (they already inherit `font-plex` from the reskinned `DropdownMenuContent`): `text-gray-*`→`text-rv-ink-*`, `hover:bg-gray-50`/`bg-gray-50`→`hover:bg-rv-bg-2`/`bg-rv-bg-2`, `border`/`border-b`→`+ border-rv-border`, `bg-[#1e1b4b]` avatar→`bg-rv-navy`, `ActivityDropdown` unread row tint `bg-amber-50`→`bg-rv-navy-50` + dot `bg-amber-500`→`bg-rv-navy` + "Mark all read" `text-amber-600`→`text-rv-navy`. **Left deliberately (semantic, per 6.2 precedent):** role badges (`getRoleBadgeClass` — `super_admin`/`professor` amber-tint remapped to `bg-rv-amber-50 text-rv-navy`, `admin` red + student green kept), sign-out red, Friends accept-green/decline-red, `ActivityDropdown` per-notification-type lucide icon accent colours, and **`CourseSwitcher`'s `COURSE_COLORS` per-course identity array** (a functional "distinguish courses at a glance" system, same carve-out class — only the structural grays around it were migrated).

### Changed — QA route (`src/pages/dev/DesignShowcase.jsx`)
- New Sprint 6.3 blocks inside `ReskinGallery` (inherits the light/dark toggle + both-themes view): reskinned stat tiles (shadcn `Card` shell + mono `Num`), the `ForwardLedgerMacro` live-shaped from sample `number[8]`, an open-state reproduction of the dropdown/popover surface (exact atom classes), and live interactive `Select` / `DropdownMenu` / `Popover` / `Switch` instances.

### Deferred / deviations
- **`get_educator_cohort_forecast_buckets` is a 3rd RPC** beyond the "one forecast RPC" the operator approved — included because it's the same pattern the sprint asks for ("cohort ledger where the data supports it") and the data supports it; shipped as its own function so it can be dropped at deploy time with no impact on the other two.
- `CourseSwitcher.COURSE_COLORS` left un-migrated (see above).
- **Per-role live verification ✅ DONE 05/09/2026** (dev server → live Supabase, inline browser): **student** — eyebrow/numeral computed styles exact, Forward Ledger `[2,1,0…]` == `get_study_queue().length` 2, `AnonymousStats` gone, Mastered tile = real `get_mastered_cards` count; **professor** — "Accuracy by question type" (`Flashcard 87% · 2240 graded`, navy bar on `--rv-slate-50`) + "Cohort forward load" `[1465,1,7,0,0,0,0,560]` both live, "Needs Attention" unconditional, `CourseSwitcher`/`ProfileDropdown` open = reskinned surfaces; **super_admin** — "Needs Review" unconditional, `Manage` dropdown + a `<Select>` on `/dashboard/settings` open = `--rv-bg-1`/`--rv-border`/`4px`/Plex, highlighted option on `--rv-navy-50`/`--rv-navy`. Console: only a **pre-existing** 4× `401` that also fires on the untouched `/dashboard/notes` — not a 6.3 regression. Zero study-loop files touched.
- Study loop untouched (6.4 owns it); the shared `Button` restyle was not extended into study-loop components.

### Files Changed
`docs/database/sprint6.3/01_FUNCTIONS_dashboard_reskin_rpcs.sql` (new), `docs/database/sprint6.3/02_TEST_dashboard_reskin_rpcs.sql` (new), `src/pages/Dashboard.jsx`, `src/components/ui/select.jsx`, `src/components/ui/dropdown-menu.jsx`, `src/components/ui/popover.jsx`, `src/components/ui/command.jsx`, `src/components/ui/switch.jsx`, `src/components/layout/ProfileDropdown.jsx`, `src/components/layout/FriendsDropdown.jsx`, `src/components/layout/ActivityDropdown.jsx`, `src/components/layout/CourseSwitcher.jsx`, `src/pages/dev/DesignShowcase.jsx`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/tracking/bugs.md`

---
## [2026-09-04] feat(reskin): Sprint 6.2 — Shared Chrome Reskin (nav shell + Button/Input/Textarea/Label atoms onto --rv-*)

First sprint that intentionally changes shipped UI — **chrome skin only: same DOM, same layout, same behaviour, new skin.** No SQL. `npm run build` clean (6.80s); `npx eslint` clean on every changed file — `src/components/ui/button.jsx`'s one `react-refresh/only-export-components` error is **pre-existing on HEAD** (the shadcn atom also exports `buttonVariants`), same baseline class as the `tailwind.config.js` `require` error. **Pushed to `main` (`a858e3b`) + live-verified on revisop.com (super_admin + student sessions).**

### Pre-work — shared-atom inventory
- Import counts: `Button` 55 files · `Input` 24 · `Label` 16 · `select` 15 · `Textarea` 7 · `switch` 1 · `checkbox` 0. Button variant usage across `src/`: `outline` 108 · `ghost` 56 · `destructive` 20 · `link` 5 · explicit `default` 2 (most `<Button>` use the `default` defaultVariant) · `secondary` 0.
- **In scope (genuine app-wide chrome):** `Button`, `Input`, `Textarea`, `Label`.
- **Deferred:** `select.jsx` → 6.3 (Radix portal dropdown — trigger shares the input shell but content/item is a popover *surface*; migrate with `dropdown-menu`/`popover`/`command` as one unit); `switch.jsx` (1 file, not app-wide); all overlay/feedback primitives (`dialog`/`sheet`/`alert`/`card`/`progress`/`toast`) → 6.3/6.4.

### Changed — nav
- **`src/components/layout/Navigation.jsx`** — shell `bg-white border-b border-gray-200` → `bg-rv-bg-1 border-b border-rv-border` + `font-plex` (cascades Plex Sans to the whole visible bar).
- **`src/components/layout/NavDesktop.jsx`** — inline two-tone `#f59e0b`/`#1e1b4b` `<span>` wordmark → shared **`<Wordmark />`** (`@/components/revisop`). Active nav item `bg-amber-50 text-amber-700` → `bg-rv-navy-50 text-rv-navy` (×6); inactive `text-gray-700 hover:bg-gray-50 hover:text-gray-900` → `text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900` (×6); nav-pill `rounded-md` → `rounded-rec`. **Sprint 6.0's `underAny`/`isStudyActive`/`isCreateActive` route-prefix logic is byte-for-byte unchanged — only the className strings it selects were restyled.** `DropdownMenuContent`/`DropdownMenuItem` (shadcn dropdown-menu surface) left for 6.3.
- **`src/components/layout/NavMobile.jsx`** — same `<Wordmark />` swap. `SheetContent` gains `font-plex bg-rv-bg-1 text-rv-ink-900` (the sheet portals out of the `<nav>` subtree, so it can't inherit the shell's `font-plex`). Sheet interior migrated **colour-only**: `text-gray-{900,700,500,400}` → `text-rv-ink-{900,600,400,400}`, `hover:bg-gray-50`/`bg-gray-50` → `hover:bg-rv-bg-2`/`bg-rv-bg-2`, `border-gray-200` → `border-rv-border`, `bg-[#1e1b4b]` avatar → `bg-rv-navy`, active course-switcher tint `bg-amber-50`/`text-amber-700`/`text-amber-600`/`bg-amber-500` → `bg-rv-navy-50`/`text-rv-navy`/`bg-rv-navy`, inactive dot `bg-gray-300` → `bg-rv-border-strong`, super-admin icon `text-amber-400` → `text-rv-amber`. **Left deliberately:** `getRoleBadgeClass()` role badges (`bg-amber-100`/`bg-red-100`/`bg-green-100` — semantic role indicators) and the sign-out `text-red-600 hover:bg-red-50` affordance (semantic, not a chrome-palette or `Button` destructive concern).

### Changed — shared atoms (`src/components/ui/`)
- **`button.jsx`** — `cva` base: `rounded-md` → `rounded-rec`, added `font-plex`, focus ring `ring-ring` → `ring-2 ring-rv-navy` (navy in light / accent lavender in dark — one token). Variants: `default` `bg-primary` → `bg-rv-navy text-rv-bg-1 hover:bg-rv-navy-400`; `secondary` → `bg-rv-navy-50 text-rv-navy`; `outline` → `border-rv-navy-400 bg-rv-bg-1 text-rv-ink-900 hover:bg-rv-navy-50 hover:text-rv-navy`; `ghost` → `text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900`; `link` → `text-rv-navy`; `destructive` → `bg-rv-danger text-white` (`#b91c1c` light / `#ef4444` dark) — delete-confirmations only. `sm`/`lg` size `rounded-md` → `rounded-rec`. **Ripples to every `Button` on every page — intended.** `GradeButtonRow` is NOT affected (raw `<button>`).
- **`input.jsx`** — `rounded-md` → `rounded-rec`, `border-input` → `border-rv-border` (identical HSL in light — border colour visually unchanged), added `font-plex text-rv-ink-900`, `placeholder:text-muted-foreground` → `placeholder:text-rv-ink-400`, focus `ring-ring` → `border-rv-navy-400 ring-2 ring-rv-navy`, `disabled:bg-rv-bg-2`, `aria-[invalid=true]:border-rv-danger`. `bg-transparent` kept (regression-safe on tinted containers).
- **`textarea.jsx`** — same treatment as `input.jsx`.
- **`label.jsx`** — `labelVariants` gains `font-plex text-rv-ink-900`. (This is the shadcn form-field label; `src/components/revisop/Label.jsx` — the uppercase section eyebrow — is a different component and unchanged.)

### Changed — QA route & docs
- **`src/pages/dev/DesignShowcase.jsx`** — new "Chrome" section inside `ReskinGallery` (so it inherits the page's light↔dark toggle + both-themes view): representative reskinned nav strip (Wordmark + active/inactive pills), all six `Button` variants + sizes + disabled, and `Input`/`Textarea`/shadcn-`Label` in default / simulated-focus / disabled / `aria-invalid` states. Imports `Button`/`Input`/`Textarea` and `Label as UiLabel` from `@/components/ui/*`.
- **`docs/active/context.md`** — the "⚠️ STALE (do not use)" blue→purple gradient tombstone bullet (Sprint 6.2 step 6) replaced with a positive description of the current two-tone typographic mark (flat Plex text, `Revis` `--rv-amber` / `Op` `--rv-navy`→accent in dark, no gradient anywhere), pointing at blueprint §1041/§1209 and noting `<Wordmark />` is live in the nav since 6.2.

### Verification
- `npm run build` clean, 6.80s, no new warnings.
- `npx eslint` clean on all changed files except the pre-existing `button.jsx` `react-refresh` baseline error (confirmed present on HEAD via `git stash`).
- **`/__design` Chrome section, local dev, light + dark:** nav strip active item = navy tint + navy ink; `Op` legible in dark (accent lavender on dark navy bg); all six Button variants render correctly (`destructive` = `#b91c1c` light / `#ef4444` dark); Input default/simulated-focus/disabled(`bg-rv-bg-2`)/error(`border-rv-danger`) + Textarea + Label all on tokens. Console clean.
- **`/login`** (public page, a `Button`/`Input` ripple target) renders with the navy `default` Sign-In button + reskinned fields; console clean.
- **✅ Live-verified on `https://www.revisop.com`** (deploy `a858e3b`) with **both** a super_admin session (Anand) and a real **student** session (TestOutlook):
  - Desktop nav computed styles: shell `bg #fff` (`--rv-bg-1`) / border `#e2e8f0` (`--rv-border`) / `font-family "IBM Plex Sans"`; active item `bg #f0f0f8` (`--rv-navy-50`) / ink `#1e1b4b` (`--rv-navy`) / radius `4px`. Student nav has no "Manage" item (correct).
  - **Nested-route active state 7/7:** notes→Study, flashcards→Study, flashcards/new→**Create**, notes/new→**Create**, progress→Study, review-session→Study, /dashboard→Dashboard; every highlight = `--rv-navy-50`. Sprint 6.0 prefix logic + Create/Study tie-break intact.
  - Mobile sheet (student): `bg #fff`, Plex Sans across the portal, header `#f0f0f8`, avatar `#1e1b4b`, inks `--rv-ink-*`, no admin sections, green "student" badge + red Sign Out preserved.
  - `Button` ripple confirmed: `default` → navy `#1e1b4b` `rounded-rec`; `outline` → `border-rv-navy-400` `rounded-rec` (study loop, note-detail, review-session, dashboard).
  - **Study loop NOT touched:** opened a real due card (TestOutlook) → QUESTION/ANSWER card + red/amber/green Hard/Medium/Easy grade buttons are exactly the pre-6.2 design; the shared `Button` restyle did not leak into `GradeButtonRow` / the study-loop grade UI. Not graded (no test-account mutation).
  - Non-chrome pixel-identical to baselines (dashboard / note-detail / study-loop empty state); console clean on every page.
- **Note:** the authenticated app has **no dark-mode toggle** — `.dark` is only ever applied on `/__design` — so authed dark verification is not reachable; nav dark styling is proven on `/__design` only.

### Deferred / follow-ups
- **6.3:** dashboard content / cards / stat tiles / charts / badges; the dropdown-surface atom family (`select`/`dropdown-menu`/`popover`/`command`).
- **6.4:** study-loop primitives (`GradeButtonRow`/`AnswerOption`), reading bodies + Literata activation, `AnswerOption` correct-state green removal, the three carried items (Items-Mastered stat re-point, seeded test card, Items-Reviewed `created_at`).

### Files Changed
`src/components/layout/Navigation.jsx`, `src/components/layout/NavDesktop.jsx`, `src/components/layout/NavMobile.jsx`, `src/components/ui/button.jsx`, `src/components/ui/input.jsx`, `src/components/ui/textarea.jsx`, `src/components/ui/label.jsx`, `src/pages/dev/DesignShowcase.jsx`, `docs/active/context.md`, `docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`.

---
## [2026-09-04] feat(reskin): Sprint 6.1 — Design Foundation (additive token layer + self-hosted fonts + RevisOp primitives)

Phase 6 reskin foundation. **Additive only — zero existing pages migrated, zero behaviour change, zero SQL.** `npm run build` passes clean (no new warnings); `npx eslint` on all new files clean. Not yet pushed.

### Added
- **`docs/active/design-review/revisop-pass2-reference.jsx`** — the Pass 2 reference artifact (committed input; source for the LIGHT/DARK token objects + primitive specs). Its blue→purple gradient wordmark is NOT followed — the locked two-tone spec is.
- **`src/index.css` — `--rv-*` token layer** (additive): full LIGHT + DARK objects from the reference translated to precise HSL triplets. `--rv-bg-0/1/2`, `--rv-border(-strong)`, `--rv-ink-900/600/400`, `--rv-navy(/-400/-100/-50)`, `--rv-amber(/-ink/-50/-edge)`, `--rv-green(/-50)`, `--rv-slate(/-50)`, `--rv-danger`, two-tier radius `--rv-radius-rec` (4px) / `--rv-radius-obj` (14px), `--rv-shadow` / `--rv-shadow-bar`, `--rv-font-sans/mono/read`. Dark values under the existing `.dark` selector. **No shadcn or Phase-5 `--brand-*`/`--surface-*` value changed.**
- **`src/index.css` — `@font-face` block**: self-hosted, Latin-subset `woff2`, `font-display: swap`, served same-origin from `/fonts/` (no font-CDN request). IBM Plex Sans (variable, wght 100–700) + IBM Plex Mono 400/500 (static) + Literata (variable, gated off). Applied only by the new primitives — no global `body`/base rule.
- **`public/fonts/`** — `plex-sans.woff2` (45.7 KB), `plex-mono-400.woff2` (14.7 KB), `plex-mono-500.woff2` (14.9 KB), `literata.woff2` (85.7 KB). UI faces total ≈ 75 KB; Literata adds ≈ 85.7 KB (woff2 barely gzips further).
- **`tailwind.config.js`** (`theme.extend`, new keys only): `colors.rv.*` → `hsl(var(--rv-*))`, `borderRadius.rec`/`.obj`, `fontFamily.plex`/`plex-mono`/`literata`, `boxShadow.rv`/`rv-bar`.
- **`src/components/revisop/`** — design-language primitives (presentational, isolated, NOT imported by any prod page): `Wordmark` (two-tone, token-driven, no gradient — light-mode output byte-identical to the current `NavDesktop.jsx` inline mark), `IntervalChip`, `Card` (r14), `Row` (r4, optional verified edge), `VerifiedEdge`, `AnswerOption` (glyph + label, slate miss, no red/green), `ForwardLedgerMicro`, `ForwardLedgerMacro` (consumes `get_study_queue`/`get_due_forecast` shapes; sample data on QA route), `GradeButtonRow` (≥48px targets @ 88px, navy-outline equal weight, mono interval, slate miss), plus `Label` / `Num` type atoms and an `index.js` barrel.
- **`src/lib/revisop-tokens.js`** — `REVISOP_LITERATA_ENABLED` (the trivial on/off — **OFF**), `REVISOP_BUCKETS` (the 8-lane forward-ledger scale), `bucketForDays()` / `ledgerFromForecast()` helpers for wiring the ledger primitives to real RPC data in 6.3/6.4.

### Changed
- **`src/pages/dev/DesignShowcase.jsx`** (`/__design` QA route) — extended with the full reskin section: every `--rv-*` swatch, every primitive, in light **and** dark via a theme toggle (`.dark`-class wrapper), plus a collapsible both-themes-side-by-side view. Phase 5 S1 sections kept.
- **`src/App.jsx`** — the `/__design` route **and** its lazy import are now gated on `import.meta.env.DEV`, so a production build registers no route and emits no chunk for it (verified: `dist/` has no `DesignShowcase-*.js`).
- **`docs/active/context.md`** — the stale Recall blue→purple gradient branding line was **already corrected 30/08/2026** (lines 13–17 now flag it as "⚠️ STALE — do not use"). No change needed; Sprint 6.1 step 7 verified already satisfied.

### Literata verdict
**Keep the files + `@font-face`, apply to nothing until 6.4.** An unmatched `@font-face` costs 0 bytes over the wire, so keeping it is free while unused. Measured cost when 6.4 wires it to reading bodies (note / case-study / long passages): **≈ 85.7 KB** (Latin-subset woff2, ~identical gzipped). That is larger than all three UI faces combined (~75 KB), so 6.4 should lazy-trigger the download when a reading body mounts rather than put it in the critical path.

### Verification
- `npm run build` clean, no new warnings. Dev-route chunk absent from `dist/`.
- `/__design` renders every primitive in light + dark (theme toggle works; `.dark` scope contained — Phase 5 sections stay light). Screenshots captured.
- `read_network_requests` on a dev page load: fonts served from `http://localhost:5173/fonts/*.woff2` (200), **zero `fonts.googleapis.com` / `fonts.gstatic.com`**.
- No-regression: `/login` and `/` (landing) pixel-identical with the layer stashed vs applied; default fonts still in use on un-migrated pages (no Plex leak); no console errors. `git diff src/index.css` = 100% additions; `tailwind.config.js` only gains a trailing comma on the `sm` radius line + new keys (no value changed). *(Auth'd dashboard / study-loop pages not screenshotted this session — no test session available — but they consume the identical CSS/Tailwind output and import none of the new code.)*
- Wordmark renders two-tone (amber `Revis` + navy `Op`), no gradient, both themes.

### Follow-ups
- **6.2:** swap `<Wordmark />` into `NavDesktop.jsx` / `NavMobile.jsx` (deferred — kept this sprint additive; output is byte-identical in light so the swap is low-risk).
- **6.3:** wire `ForwardLedgerMacro` to live `get_study_queue` / `get_due_forecast`; dashboards onto the token layer.
- **6.4:** wire `GradeButtonRow` to `get_srs_ladder_config`; flip `REVISOP_LITERATA_ENABLED` on with a lazy-load trigger; study loop onto the token layer.

### Files Changed
`docs/active/design-review/revisop-pass2-reference.jsx` (new), `src/index.css`, `tailwind.config.js`, `src/App.jsx`, `src/pages/dev/DesignShowcase.jsx`, `src/components/revisop/*` (new, 12 files), `src/lib/revisop-tokens.js` (new), `public/fonts/*.woff2` (new, 4 files), `docs/active/now.md`, `docs/active/blueprint.md`, `docs/tracking/changelog.md`, `docs/reference/FILE_STRUCTURE.md`.

---
## [2026-09-03] feat(srs-ladder): Phase 3 frontend — StudyMode/ReviewSession/Progress on the ladder (✅ 06 SQL deployed; pushed 8323ee3; ⏳ live-verify)

Phase 3 wires the frontend to the deployed ladder engine. `npm run build` + `npx eslint` clean. **Not pushed** — `06_FUNCTIONS_get_mastered_cards.sql` deploys first, then the push, then live-verify.

### Added (SQL)
- `docs/database/srs-ladder/06_FUNCTIONS_get_mastered_cards.sql` — `get_mastered_cards(p_user_id uuid)` (SECURITY DEFINER, L5 self-guard, mirrors `get_suspended_cards`; returns card content + `rung` / `next_review_date` / `mastered_at`). `GRANT EXECUTE TO authenticated`. **Hard prerequisite for the Progress.jsx Mastered list.**

### Changed (frontend)
- `src/pages/dashboard/Study/StudyMode.jsx`:
  - `handleRating` — removed the client interval constants (`+7 / +3 / +1`), the `easinessFactor` map, the local `YYYY-MM-DD` date build, and the `reviews` SELECT→UPDATE/INSERT. Now one `supabase.rpc('submit_review', { p_user_id, p_flashcard_id, p_rating })`. Covers the review-session grade path and the new-card first-grade path (same function). Toast uses the server `interval_days`; shows "Mastered! 🎓" when `new_status === 'mastered'`.
  - Added a one-time `get_srs_ladder_config()` fetch on mount + a `gradePreview` `useMemo` that computes each grade button's interval locally from `curves` + `rules` + the current card's `rung`. Zero per-card network. Replaced the hardcoded "Review in N days" sublabels (old literals kept only as a config-fetch-failure fallback).
  - `fetchFlashcards` step 2 attaches `rung` (from `get_study_queue`) to standalone session cards.
- `src/pages/dashboard/Study/ReviewSession.jsx` — passes `rung` + `question_type` through in the `get_study_queue` → card mapping. Still read-only.
- `src/pages/dashboard/Study/Progress.jsx` — new "Mastered Items" collapsible section in `ProgressBody` (mirrors "Suspended Items"; green/`Award`; display-only, grouped by subject), fed by `get_mastered_cards`. Headline "Items Mastered" stat unchanged (deferred to 6.4).

### Files Changed
`docs/database/srs-ladder/06_FUNCTIONS_get_mastered_cards.sql` (new), `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/dashboard/Study/ReviewSession.jsx`, `src/pages/dashboard/Study/Progress.jsx`, `docs/active/now.md`, `docs/active/blueprint.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`.

---
## [2026-09-03] feat(srs-ladder): Phase 0 proposal + Phase 1 engine + Phase 2 migration — ✅ DEPLOYED & VERIFIED

SRS Ladder Epic. Replaces the flat client-side per-rating interval (`StudyMode.jsx`: Easy +7 / Medium +3 / Hard +1) with a deterministic server-side expanding ladder. Phase 0 approved by the quality auditor (all 5 open questions + Phase 1/2 authorization). **Phase 1 + Phase 2 SQL deployed & verified in Supabase 03/09/2026. Phase 3 (frontend) NOT started — next.**

### Deploy + verification (03/09/2026, Supabase SQL Editor)
- `01_SCHEMA` + `02_FUNCTIONS` live; `03_TEST` **30/30 PASS** (every `[CRITICAL]`; preview parity across 9 rung×rating combos; IDOR cross-user + null-session RAISE; MASTERED graduate + un-master; forecast course-filter parity).
- `04_MIGRATION` backfill applied — `reviews_still_null_rung = 0`, rung distribution `0:856 / 1:3065 / 2:1871 / 3:781 / 4:1251` (matches the Phase 0 Q3/Q4b prediction exactly; nobody above rung 4, nobody mastered).
- `05_TEST` — platform `get_study_queue` due total **4830 → 4830 (delta 0)** across all 175 students; schedule columns (`next_review_date`/`status`/`skip_until`) untouched. `get_due_forecast` rewrite is live → the Progress "Due Items Forecast" off-SSOT bug is RESOLVED.

### Added (docs)
- `docs/active/design-review/srs-ladder-proposal.md` — Phase 0 proposal, diagnostics filled (commit `d96559f` / `b99dbc1`).
- `docs/database/srs-ladder/00_DIAGNOSTIC_srs_ladder_phase0.sql` — 12 read-only measurement blocks.

### Added (SQL — ✅ deployed & verified 03/09/2026)
- `docs/database/srs-ladder/01_SCHEMA_srs_ladder_engine.sql` — `reviews.rung smallint NULL` (+ CHECK 0..20); `reviews_status_check` extended with `'mastered'`; `idx_reviews_user_mastered`; `srs_ladder_curves(question_type, rung_index, interval_days)` + `srs_ladder_rules(id, rules jsonb)` config tables (RLS on, `SELECT` to anon+authenticated, no client write) + seed (`_default` curve 1/3/7/14/30/60/120/240; rules row).
- `docs/database/srs-ladder/02_FUNCTIONS_srs_ladder_engine.sql`:
  - `submit_review(p_user_id uuid, p_flashcard_id uuid, p_rating text)` → `(new_rung, next_review_date, new_status, interval_days)` — **the write SSOT for review scheduling.** SECURITY DEFINER, L5 IDOR idiom (`p_user_id` must equal `auth.uid()`; admins exempt; NULL session RAISEs), `search_path` unquoted. SELECT-or-INSERT on `(user_id, flashcard_id)`; deterministic rung transition (Easy +1 cap 7 / Medium hold / Hard → 0 + 1-day relearn; new card → rung 0/1/2); graduates to `status='mastered'` on Easy at rung 7; un-masters on any other grade. `GRANT EXECUTE TO authenticated`.
  - `srs_preview(p_rung integer, p_question_type text DEFAULT NULL)` → 3 rows (hard/medium/easy) of `(resulting_rung, interval_days)`. Server-side mirror for Sprint 6.4 + the drift-parity test; not called in the study loop. `GRANT EXECUTE TO anon, authenticated`.
  - `get_srs_ladder_config()` → `jsonb {curves, rules}`. Client's one-time mount fetch; returns the same `srs_ladder_rules` row the server enforces. `GRANT EXECUTE TO anon, authenticated`.
  - `srs_interval_for_rung(p_rung, p_question_type)` — internal calculator (card's curve else `_default`); EXECUTE revoked from anon/authenticated.
  - `get_study_queue(p_user_id)` — **DROP + CREATE** to append `rung smallint` to the return shape (Phase 3 needs it for local preview). Body otherwise byte-identical to `sprint6/01`. MASTERED excluded automatically (`status='active'` filter). Grants re-issued, `NOTIFY pgrst`.
  - `get_due_forecast(p_user_id)` — **body rewrite, signature unchanged.** `due_today` now uses the exact `get_study_queue` due predicate (user-tz today, `status='active'`, `next_review_date <= today`, `skip_until` null/≤today, `question_type <> 'concept_card'`, read-time course filter, L2 visibility guard); `due_next_7`/`due_next_30` = same predicate with a forward cumulative window. Closes the bugs.md "Due Items Forecast disagrees with the review queue" follow-up. **Zero frontend change** (`Progress.jsx` already consumes the 3-bucket shape).
- `docs/database/srs-ladder/03_TEST_srs_ladder_engine.sql` — Phase 1 verification (25+ checks incl. preview parity + IDOR), BEGIN/ROLLBACK.
- `docs/database/srs-ladder/04_MIGRATION_backfill_rung.sql` — Phase 2 single `UPDATE` backfill of `reviews.rung` from `repetition`, capped by `easiness` (rung 4 / rung 2). `next_review_date` untouched. Reversible.
- `docs/database/srs-ladder/05_TEST_migration_safety.sql` — before/after due-count stability + schedule-integrity check (impersonates every student via `get_study_queue`).

### Changed
- Migration mapping deviates from the epic's `LEAST(repetition, 7)` starting point → `LEAST(repetition, 4)` (rung 2 for last-Hard cards). Phase 0 Q3/Q4b: prevents 424 rows piling on rung 7 and 164 struggling cards landing rungs 4–7.
- Course-value normalization **dropped** — Phase 0 Q8/Q9 proved no spelling drift exists.

### Deploy order (non-negotiable)
`01_SCHEMA` → `02_FUNCTIONS` → `03_TEST` → `05_TEST PART A` → `04_MIGRATION` → `05_TEST PART B`, each its own SQL Editor submission. Report back BEFORE any Phase 3 frontend push.

---
## [2026-09-03] feat: Sprint 6.0 follow-up — "Today's Reviews" nav entry + friends/private RPC test (✅ PUSHED)

Post-6.0 QA follow-ups. No SQL. Frontend + docs only.

### Added
- **"Today's Reviews" nav item** → `/dashboard/review-session`, first item in the **Study** menu (`NavDesktop.jsx` dropdown + `NavMobile.jsx` Study section). Closes a pre-existing gap: the review-session queue had **no in-app link for any role** — students reached it only via the dashboard green CTA, professors only via the push-notification deep link (found during 6.0 QA on a professor account). `fetchPersonalStats` already computed `reviewsDue` for professors; it was just never rendered in the professor dashboard branch.
- **`docs/database/sprint6/03_TEST_verify_get_study_queue_visibility.sql`** — covers the friends / private / reverse-direction-friendship / friendship-downgrade branches of `get_study_queue`'s visibility guard that `02_TEST` did not. **6/6 PASS** in Supabase (all `[CRITICAL]`).

### Verified on live (revisop.com, logged-in student)
- **C3** — nav highlight correct on 6 nested routes incl. the Create-vs-Study tie-break; console clean.
- **C5** — logged-in student on `/note/:id` redirects to `/dashboard/notes/:id`, full content, no wall; anon still walled.
- **C6** — code conditional confirmed (`due_today > 0 ? red : green`); live showed red at `due_today = 24` (intended). Zero-state green not reproducible on the test account.

### Known follow-up (NOT a 6.0 regression — logged, not fixed)
- **`Progress.jsx` "Due Items Forecast" is a 4th "due" surface not on the SSOT.** It reads its own `forecast` source, bypassing `get_study_queue`'s course filter + concept-card exclusion → showed **"Due Today: 24"** where the Dashboard/ReviewSession queue showed **4** (student on CA Intermediate; the 20-card gap is out-of-course cards the queue correctly drops). Recommend pointing the forecast's "Due Today" at the `get_study_queue` count in a later slice (keep "Next 7 / Next 30 Days" on a forward-looking query). Relevant to the SRS Ladder Epic — another "due" consumer.

### Files Changed
`src/components/layout/NavDesktop.jsx`, `src/components/layout/NavMobile.jsx`, `docs/database/sprint6/03_TEST_verify_get_study_queue_visibility.sql` (new), `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/active/now.md`, `docs/active/blueprint.md`

---
## [2026-09-02] feat: Sprint 6.0 — single "what's due" RPC + read-time course filter + (c) bug fixes (✅ DEPLOYED & PUSHED)

Sprint 6.0 (Correctness). One RPC is now the single source of truth for the review queue, the queue is course-aware at read time, and the six logged-in-experience bugs are addressed. SQL deployed & verified in Supabase (`02_TEST` 9/9 PASS incl. every `[CRITICAL]`); frontend then applied and pushed to main.

### Added
- **`get_study_queue(p_user_id uuid)`** — `docs/database/sprint6/01_FUNCTIONS_get_study_queue.sql` (+ `02_TEST`). SECURITY DEFINER, `STABLE`, `SET search_path TO public, extensions` (unquoted, L3 lesson), `REVOKE FROM public/anon` + `GRANT EXECUTE TO authenticated`, L5 read-IDOR guard (`p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin()` → RAISE; null session also RAISEs). Returns the due flashcard rows (content + `subject_name`/`topic_name` + `next_review_date`/`skip_until`/`last_reviewed_at`).
  - "Due" = review row exists AND `status='active'` AND `next_review_date <= today` AND (`skip_until IS NULL OR skip_until <= today`); *today* computed in `profiles.timezone`. Concept cards excluded. Never-reviewed cards are out of scope (StudyMode-standalone adds those client-side).
  - **Read-time course filter:** row returned only when `course_level IS NULL OR target_course IS NULL OR target_course = course_level`. Writes nothing to `reviews` → switching course back restores the old queue automatically (verified: `02_TEST` block 9, reviews row unchanged before/after). Null policy: student with no course set → sees everything; card with no `target_course` → treated as matching.
  - Visibility guard re-asserts the L2 read predicates (own / public / accepted-friend) since SECURITY DEFINER bypasses RLS. `vw_study_items` NOT reintroduced.
- **`src/lib/qualityTier.js`** — shared "score/rate → colour tier" util (`qualityTier(value, [strongMin, okMin])` → `{key,text,bar,badge,emoji,label}`). Replaces ~8 copy-pasted, inconsistently-thresholded ternaries.

### Changed
- **Single "what's due" RPC wired into all three call sites; no client-side `next_review_date`/`skip_until` comparison remains in any of them:**
  - `src/pages/Dashboard.jsx` — `fetchPersonalStats` `dueCount` date-math removed; `reviewsDue` now `= rpc('get_study_queue').length`. Weekly/streak/accuracy/mastered math untouched.
  - `src/pages/dashboard/Study/ReviewSession.jsx` — `fetchDueCards` collapsed to one `rpc('get_study_queue')` call; RPC rows mapped to the existing card shape; `groupCardsBySubject` consumes `subject_name`.
  - `src/pages/dashboard/Study/StudyMode.jsx` — `fetchFlashcards` Step 2: `dueIds` from the RPC + a fieldless `reviews(flashcard_id)` fetch for `reviewedIds`, then `filter(c => dueIds.has(c.id) || !reviewedIds.has(c.id))`.
- **(c) bugs:**
  - C1 — `AdminDashboard.fetchStats` now reads `get_admin_platform_overview` (same RPC as `AdminAnalytics`) for user/public counts; `get_platform_stats` removed from admin (landing-only); raw note/flashcard totals via direct admin `COUNT(*)`. `publicFlashcards` sub was hardcoded `0` → now real. `AdminAnalytics` "Published Items" stat card relabelled to remove the card-vs-table-column collision.
  - C2 — `AdminAnalytics.QualityBadge` + the `lowQuality` row-highlight + `SuperAdminDashboard` daily/weekly active-user cards (extracted to `ActiveUsersCard`) all use `qualityTier`.
  - C3 — `NavDesktop.jsx` `isStudyActive`/`isCreateActive` now match on route prefix (`underAny`); Dashboard link stays exact. Sprint 6.2 dependency.
  - C4 — NON-ISSUE (the "Currently Live" `unfeature_content` control already works). No change.
  - C5 — `NotePreview.jsx` + `DeckPreview.jsx` redirect logged-in users to `/dashboard/notes/:id` / `/dashboard/review-flashcards?deck=:id` instead of showing the anonymous "sign up" wall.
  - C6 — `Progress.jsx` "Due Today" ForecastCard: green when `0`, red only when `> 0` (was hardcoded red).

### Caption fix (C2)
`src/pages/admin/AdminAnalytics.jsx` overview stat card 4 — **before:** `label="Published Items"` / `sub="Public flashcards"` (collided with the Content-Health table's "Published Items" column, which is per-course notes+flashcards). **after:** `label="Public Flashcards"` / `sub="visibility = public"`.

### Files Changed
`docs/database/sprint6/01_FUNCTIONS_get_study_queue.sql` (new), `docs/database/sprint6/02_TEST_verify_get_study_queue.sql` (new), `src/lib/qualityTier.js` (new), `src/pages/Dashboard.jsx`, `src/pages/dashboard/Study/ReviewSession.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/dashboard/Study/Progress.jsx`, `src/components/layout/NavDesktop.jsx`, `src/pages/public/NotePreview.jsx`, `src/pages/public/DeckPreview.jsx`, `src/pages/admin/AdminDashboard.jsx`, `src/pages/admin/AdminAnalytics.jsx`, `src/pages/admin/SuperAdminDashboard.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-07-04] fix(db): admin-writer guards + read-IDOR follow-through (✅ deployed & verified)

Closes the remaining gaps the residual-IDOR sweep (`security/12`) found after the read-IDOR pass, and fixes one over-guard regression from that pass.

### Admin/internal writers (from the sweep)
- **`15_FUNCTIONS`** — `enroll_user_in_batch_group` + `notify_access_granted` were SECURITY DEFINER writers taking a *target* `p_user_id` with **no** authorization check (any authenticated user could enroll/notify arbitrary users). `14_DIAGNOSTIC` confirmed both are admin-RPC-only (no signup/trigger caller — `fn_auto_enroll_batch_group` enrolls directly), so added `IF NOT is_admin() THEN RAISE`.
- **`16_SCHEMA`** — `log_review_activity` (no frontend caller; invoked only by the `fn_badge_check_reviews` trigger, which runs as owner) had `authenticated` EXECUTE + no guard → a user could inject activity for anyone. Revoked `authenticated`/`anon` EXECUTE (internal-only); trigger path unaffected.
- `17_TEST` 6/6 PASS: non-admin enroll/notify blocked, admin allowed, anon/authenticated can't exec `log_review_activity`, and a review insert (self session) still fires the trigger chain.

### Regression fixed — `get_user_streak` over-guard
- The read-IDOR pass (`08`) wrongly guarded `get_user_streak` to self-only, but a streak is **social** data: `get_following_with_stats`, `get_my_friends_with_stats`, and `get_batch_group_member_stats` all call `get_user_streak(other_user)` to show friends'/members' streaks. The guard broke those three pages for non-admins.
- **`bugfixes/13_FUNCTIONS`** reverts `get_user_streak` to unguarded (verbatim original). `bugfixes/14_DIAGNOSTIC` full caller sweep confirmed `get_user_streak` was the **only** misclassification — no other guarded function is called cross-user internally.
- **Root-cause lesson:** the admin-writer fixes did a caller audit *before* guarding (`14`); the read guards (`08`) didn't. Always audit internal callers before adding a guard that RAISEs.

### Files Changed
`docs/database/security/12–17` (12–14 diagnostics, 15/16/17 fix+test), `docs/database/bugfixes/13_*.sql`, `14_*.sql`, `docs/tracking/bugs.md`, `docs/tracking/changelog.md`, `docs/active/now.md`

---
## [2026-07-04] fix(db): read-side IDOR guards on SECURITY DEFINER RPCs (✅ deployed & verified)

Follow-up to L5, from a requested read-IDOR audit. Several SECURITY DEFINER functions took `p_user_id`/`p_professor_id` and returned that user's private data without checking it against `auth.uid()` — SECURITY DEFINER bypasses RLS, so the param was trusted. Closes a **live** leak (`get_user_badges` returned private badges cross-user) and a **write** IDOR L5 missed (`unsuspend_card`).

### Deployed (live, verified 04/07/2026)
- **`08_FUNCTIONS`** — group A: 10 self-only guards (`get_due_forecast`, `get_recent_notifications`, `get_suspended_cards`, `get_study_heatmap`, `get_study_time_stats`, `get_subject_mastery_v1`, `get_question_type_performance`, `get_user_streak`, `get_unnotified_badges`, `unsuspend_card`). Four `LANGUAGE sql` → `plpgsql` so a `RAISE` guard could be added (signature/return unchanged).
- **`09_FUNCTIONS`** — 5 professor-analytics guards (`p_professor_id = auth.uid() OR is_admin()`; frontend passes self).
- **`10_FUNCTIONS`** — `get_user_badges` self-only (was returning private badges to any caller).
- **Frontend** — removed the dead cross-user `fetchUserBadges` from `src/hooks/useBadges.js` (no consumer; FindFriends fetches others' badges via a direct `is_public = true` query; `get_public_user_badges` is the correct cross-user RPC).
- `11_TEST` 7/7 PASS. `get_unread_notification_count` + `mark_notifications_read` were already guarded (no change).

### Note
- Root cause `unsuspend_card` was missed in L5: the L5 write-guard regex (`update ` + word boundary) never matched `UPDATE`-only functions. Lesson recorded in `bugs.md`.

### Files Changed
`docs/database/security/07_*.sql`, `07b_*.sql`, `08_*.sql`, `09_*.sql`, `10_*.sql`, `11_*.sql` (07b–11 new), `src/hooks/useBadges.js`, `docs/tracking/bugs.md`, `docs/tracking/changelog.md`, `docs/active/now.md`

---
## [2026-07-04] fix(db): skip_card + suspend_card wrong reviews columns (✅ deployed & verified)

Closes `task_95bdea3d` (spun off from L5). SQL-only.

- **Bug:** `skip_card` / `suspend_card`'s `IF NOT FOUND THEN INSERT INTO reviews` branch (first-ever skip/suspend of a card with no review row) used `easiness_factor` / `repetitions` — nonexistent columns → `42703`. Same defect the Apr 4 fix corrected in the topic-scoped twins but missed here.
- **Verified schema first** (`08_DIAGNOSTIC`): reviews uses `easiness` (double precision) + `repetition` (integer); `next_review_date` is a `date`.
- **Fix** (`09_FUNCTIONS`): `CREATE OR REPLACE` both with `easiness`/`repetition` and `CURRENT_DATE` for `next_review_date`; L5 IDOR guard + `search_path` preserved verbatim. `10_TEST` 2/2 `[CRITICAL]` PASS — skip/suspend a never-reviewed card creates the row (`active`/`suspended`), no `42703`.

### Files Changed
`docs/database/bugfixes/08_*.sql`, `09_*.sql`, `10_*.sql` (new), `docs/tracking/bugs.md`, `docs/tracking/changelog.md`

---
## [2026-07-04] chore(db): L5 — API surface hardening (✅ deployed & verified)

Least-privilege pass over the PostgREST API surface, from the Supabase advisor CSV + the SECURITY DEFINER write-guard audit. SQL-only; no frontend change. Classification driven entirely by the frontend `.rpc()` grep + `03_DIAGNOSTIC` (RLS function-ref scan).

### Deployed (live, verified 04/07/2026)
- **IDOR guards** (`02_FUNCTIONS` + `02b_FUNCTIONS`) — `skip_card`, `suspend_card`, `reset_card`, `skip_topic_cards`, `suspend_topic_cards` now hard-block `p_user_id <> auth.uid()` (unless `is_admin()`) with `RAISE 'Access denied'`. Previously any authenticated user could tamper with another student's review schedule (horizontal IDOR).
- **EXECUTE revokes** (`04_SCHEMA`) — robust `REVOKE FROM PUBLIC[, anon, authenticated]` + `GRANT` back:
  - **Revoked anon+authenticated** on 21 internal/trigger functions (`award_badge`, `create_notification`, `fn_*`, counters, etc.) — never meant as RPCs; internal/trigger callers run as owner/definer, unaffected.
  - **Revoked anon** on ~70 authenticated-only RPCs (defense-in-depth; they already guard on `auth.uid()`/role).
  - **Kept anon** on the 10-function public allowlist (landing/preview/lead-capture) + `is_admin`/`is_super_admin` (RLS depends on them — the key non-obvious exclusion).
- **Storage** (`05_SCHEMA`) — dropped the broad "list all files" SELECT policies on `flashcard-images` + `note-files`. Public buckets still serve objects by URL; only API enumeration is removed.

### Verified
- `06_TEST` 9/9 PASS — cross-user skip/suspend blocked `[CRITICAL]`, own-card allowed, anon can't reach internal/authenticated fns, allowlist + `is_admin` retained.
- Live smoke (anon): landing `get_public_educators` / `get_platform_stats` / `get_featured_landing_content` all 200 — allowlist survived the revokes.

### Still pending (founder / follow-up)
- **Leaked-password protection** — Dashboard → Auth → Passwords toggle (non-SQL; not yet enabled).
- **Latent bug spun off** (`task_95bdea3d`): `skip_card`/`suspend_card` `NOT FOUND` INSERT branch uses `easiness_factor`/`repetitions` (reviews table uses `easiness`/`repetition`) — reproduced verbatim in L5 (guard-only), fix tracked separately.
- Two trigger helpers (`fn_autoclear_featured_on_visibility_change`, `fn_notifications_set_updated_at`) landed in revoke-anon not revoke-both — harmless (RETURN trigger → not RPC-callable), optional tidy.

### Files Changed
`docs/database/security/01_*.sql` through `06_*.sql` (02, 02b, 03, 04, 05, 06 new this sprint), `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/active/now.md`, `docs/active/blueprint.md`

---
## [2026-07-04] fix(db): deck listing + activity feed hide zero-visible decks (✅ deployed & verified)

Follow-up to the `get_public_deck_preview` fix. The founder confirmed (logged-in, as a professor) that a public deck whose only card was made private still appeared in the **authenticated dashboard** — the Review Flashcards grid and Recent Activity — even though the card *content* was correctly hidden (empty study session). Root cause: those surfaces gate at the **deck** level, not per card. The earlier public-preview fix was a real but *different* surface (anon `/deck/:id`); this addresses the dashboard surfaces the report was actually about.

### Root cause
- **`get_browsable_decks`** gated on `fd.visibility='public'` and returned the denormalized `fd.card_count` → a public shell around private cards showed as "1 card" and opened an empty session.
- **`get_recent_activity_feed`** (`recent_decks` CTE) gated only on `fd.visibility` → same leak in the feed.
- **`get_browsable_notes`** — NOT affected (a note is atomic, gated by its own `visibility`); no change.

### Deployed (live, verified 04/07/2026)
- **`05_FUNCTIONS`** — `get_browsable_decks` v4: `LATERAL` count of cards **visible to the viewer** (public / own / accepted-friend / admin / group-shared), returned as `card_count`; decks with 0 visible cards excluded. Owner view unchanged (sees own private cards).
- **`06_FUNCTIONS`** — `get_recent_activity_feed`: `recent_decks` now requires `EXISTS` a viewer-visible card. `recent_notes` untouched.
- `07_TEST` 4/4 PASS: non-owner professor sees deck `1e521de5` in **neither** surface `[CRITICAL]`; owner still sees it with `card_count=1`.

### Notes
- Behavioral change: `card_count` now reflects **viewer-visible** cards, so mixed-visibility decks show smaller counts to non-owners (and Review Flashcards subject totals become viewer-accurate). No frontend change — the UI renders the corrected numbers.
- Signatures unchanged → no PostgREST reload. Diagnostic: `docs/database/bugfixes/04_DIAGNOSTIC_listing_surfaces_visibility.sql`.

### Files Changed
`docs/database/bugfixes/04_*.sql`, `05_*.sql`, `06_*.sql`, `07_*.sql` (all new), `docs/tracking/changelog.md`, `docs/tracking/bugs.md`, `docs/active/now.md`

---
## [2026-07-04] fix(db): L4 profiles cascade COMPLETE + L3 search_path hotfix (✅ deployed & verified)

Closes the landmine phase (L1–L4 all done). Two items, same session.

### L4 — profiles FK → ON DELETE CASCADE (closes §1.11 "profiles blocks user deletion")
- **`20_SCHEMA`** (one transaction): the 8 `NO ACTION` attribution FKs on `notes`/`flashcards`/`flashcard_decks`/`content_flags` (`contributed_by`, `creator_id`, `featured_approved_by`, `featured_nominated_by`, `resolved_by`) → **`SET NULL`**; then `profiles_id_fkey` → **`CASCADE`**. Rationale: attribution columns credit a user for action on *someone else's* content, so a deleted user nulls the credit, never deletes that content (owner = `user_id`, already CASCADE).
- `19_DIAGNOSTIC` mapped the full FK graph first (16 already-CASCADE, 5 already-SET NULL, 8 blockers). `21_TEST` 12/12 PASS incl. a live end-to-end `auth.users` delete (profile cascaded, attribution nulled, other user's card preserved). Deleting a user from the Auth dashboard now works with no manual `profiles`-row step. Pure schema, no frontend change.

### L3 search_path — two-bug hotfix (production write-path incident, resolved same day)
- **Bug 1:** `17_SCHEMA` emitted the pin **single-quoted** (`SET search_path TO 'public, extensions'`). For the `search_path` GUC a quoted comma-string is ONE schema named `"public, extensions"` — `public` fell out of the path, breaking every unqualified reference in the 50 pinned functions. Impact: flashcard/note/review **writes** failed (trigger `update_deck_card_count` → `relation "flashcard_decks" does not exist`). Reads and existing data unaffected. `18_TEST`'s execution smoke missed it (sampled an already-correctly-pinned function).
- **Bug 2:** first hotfix `17b` re-pinned correctly but appended a `BEGIN…ROLLBACK` write-smoke in the same editor submission; the Supabase editor wraps the whole script in one transaction, so the `ROLLBACK` reverted the `ALTER`s too (false-positive PASS, pin still broken).
- **Fix:** **`17c_HOTFIX`** (apply-only, no rollback) re-pinned all functions with correct **unquoted** `SET search_path TO public, extensions`; committed. Verified: 0 pinned fns missing standalone `public`; live flashcard insert succeeds; `21_TEST` (which exercises a real write) fully green.
- **Source hardened:** `17_SCHEMA` fixed to emit unquoted syntax (+ warning comment); `18_TEST` Block 3 replaced with a deterministic check that `public` is a standalone element of each pinned path (would have caught Bug 1).
- **Lessons banked** (blueprint §1.11 + memory): never single-quote a multi-schema `search_path`; never mix persistent DDL with a verification `ROLLBACK` in one Supabase-editor run; search_path tests must exercise a real write.

### Added — SQL
- `docs/database/landmines/19_DIAGNOSTIC_profiles_fk_cascade_audit.sql`, `20_SCHEMA_profiles_fk_on_delete_cascade.sql`, `21_TEST_verify_profiles_cascade.sql` (L4, new)
- `docs/database/landmines/17b_HOTFIX_*.sql` (superseded), `17c_HOTFIX_repin_search_path_APPLY_ONLY.sql` (the live fix)
- `docs/database/security/01_DIAGNOSTIC_securitydefiner_write_guard_audit.sql` (L5 pre-check — `admin_delete_user_data` confirmed guarded; IDOR/internal-helper worklist captured for L5)

### Files Changed
`docs/database/landmines/17_SCHEMA_*.sql`, `18_TEST_*.sql` (corrected), `17b/17c/19/20/21` (new), `docs/database/security/01_*.sql` (new), `docs/active/blueprint.md`, `docs/tracking/changelog.md`, `docs/active/now.md`

---
## [2026-07-04] chore(db): Landmine Cleanup Sprint L3 — function search_path hardening (✅ deployed & verified)

Resolves the Supabase Advisor "Function Search Path Mutable" finding (blueprint §1.11 Advisor). SQL-only, zero frontend impact, behavior-preserving.

### Why
A function with no pinned `search_path` inherits the CALLER's at run time — a privilege-escalation vector for SECURITY DEFINER functions (an attacker who prepends a schema can make unqualified names resolve to their own objects, executed with definer rights). Pinning each function closes it.

### Deployed (live, verified 04/07/2026)
- **`17_SCHEMA`** — pinned **50 our-owned unpinned functions** (44 SECURITY DEFINER + 6 not) to `SET search_path TO 'public, extensions'`, SECDEF-first, in one transaction. Generator-built (`ALTER` per exact signature) so the full list was reviewed before applying. Signatures unchanged → no PostgREST reload.
- Diagnostic (`16`) confirmed: the pin value matches the live role default (Block 1); **zero** functions call an extension routine unqualified so nothing can break (Block 3 empty); `anon`/`authenticated` cannot `CREATE` in `public` (Block 4 false/false). Test (`18`) 3/3 PASS.

### Decision
Chose **behavior-preserving `'public, extensions'`** over strict `SET search_path = ''`. The strict form maximises hardening but requires rewriting ~50 function bodies to schema-qualify every reference (much larger, higher-risk); the pinned form closes the *mutable* hole with no body changes and no runtime change. `extensions` is included as future-proofing (no current dep). Explicitly out of scope: the `''` + full-qualify pass.

### Added — SQL
- **`docs/database/landmines/16_DIAGNOSTIC_search_path_audit.sql`** — role search_path, unpinned-function inventory (SECDEF-first, extension-owned excluded), extension-dependency scan, `public`-CREATE safety check. Read-only.
- **`docs/database/landmines/17_SCHEMA_pin_search_path.sql`** — Block A generates + Block B applies the `ALTER … SET search_path` batch. Rollback via `RESET search_path`.
- **`docs/database/landmines/18_TEST_verify_search_path.sql`** — verdict test (0 unpinned, extension-pin `[CRITICAL]`, SECDEF execution smoke).

### Notes
- Trigger functions (`update_deck_card_count`, `notify_badge_earned`, `log_review_activity`, etc.) were included — they benefit from the pin too.
- Landmine phase: L1 ✅, L2 ✅, deck-preview bug ✅, L3 ✅. Remaining: L4 (`profiles` FK → CASCADE), then Phase 6.

### Files Changed
`docs/database/landmines/16_*.sql`, `17_*.sql`, `18_*.sql` (all new), `docs/active/blueprint.md`, `docs/tracking/changelog.md`, `docs/active/now.md`

---
## [2026-07-04] fix(db): Public deck preview no longer leaks non-public cards (✅ deployed & verified)

Fixes a content-visibility leak surfaced by the founder after L2: a card set to `private` by its creator was still visible inside the public deck preview to other users (and, in fact, to anonymous visitors). SQL-only fix — no frontend change.

### Root cause
`get_public_deck_preview(p_deck_id)` (SECURITY DEFINER, powers the public `/deck/:id` page via `src/pages/public/DeckPreview.jsx`) gated the **deck** on `visibility='public'` but its inner card subquery had **no per-card visibility filter**. SECURITY DEFINER bypasses RLS, so private/friends cards inside a public deck leaked their `front_text`. The in-app StudyMode study view was not affected (RLS-protected direct query that also excludes `private` client-side).

### Deployed (live, verified 04/07/2026)
- **`02_FUNCTIONS`** — `CREATE OR REPLACE get_public_deck_preview`: added `AND fc.visibility = 'public'` to the preview subquery (the leak fix); made the public `card_count` count public cards only (was `fd.card_count`, which revealed hidden-card totals); added deterministic `ORDER BY created_at`. Signature unchanged; `NOTIFY pgrst`.
- Diagnostic (`01`) confirmed the live body matched the repo copy and found 1 live leaking deck (`1e521de5…`, the founder's test deck). Test (`03`) — 3/3 PASS incl. the `[CRITICAL]` "private card NOT in preview".

### Added — SQL
- **`docs/database/bugfixes/01_DIAGNOSTIC_deck_preview_visibility_leak.sql`** — dumps the live function body + lists every public deck holding non-public cards (proves the leak with live data). Read-only.
- **`docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql`** — the fix (above). Rollback = re-run `docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql`.
- **`docs/database/bugfixes/03_TEST_verify_public_deck_preview_visibility.sql`** — `BEGIN…ROLLBACK` verdict test: public deck with one public + one private card, asserts the private card is absent from the preview, the public present, `card_count`=1.

### Notes
- No frontend change and no live-URL step — the React page renders whatever the RPC returns.
- Reusable lesson (also added to `DATABASE_SCHEMA.md` join section + `bugs.md`): any SECURITY DEFINER RPC returning content on a public/anon surface must filter `fc.visibility` explicitly; the 5-grouping-column deck join returns all visibility tiers on its own.

### Files Changed
`docs/database/bugfixes/01_*.sql`, `02_*.sql`, `03_*.sql` (all new), `docs/tracking/bugs.md`, `docs/tracking/changelog.md`, `docs/active/now.md`, `docs/reference/DATABASE_SCHEMA.md`

---
## [2026-07-04] fix(db): Landmine Cleanup Sprint L2 — COMPLETE, is_public dropped (✅ deployed & verified)

Closes blueprint §1.11 landmine #2. All stages deployed live and verified; `is_public` is gone from `notes` and `flashcards`; all read RLS now keys solely on `visibility`. This entry records what **actually** shipped — the plan in the `[2026-07-03]` entry below diverged in three material ways once `09_DIAGNOSTIC` returned live ground truth (corrections noted).

### Corrections vs the prepared plan (03/07)
- **Stage A used `ALTER POLICY`, not DROP/CREATE.** `09` showed live policy names have spaces (`"Users can view public notes"`, not snake_case `users_view_public_notes`), and role targeting is `TO public`. `ALTER POLICY … USING (…)` swaps only the predicate in place — name/roles/cmd preserved, `TO public` kept (anon reads public content directly, as it did pre-migration).
- **No friends-tier policy was created.** The "friends tier has never been enforced in RLS" claim was **wrong** — `09` found live `"Users can view friends notes/flashcards"` policies already exist (`visibility='friends' AND EXISTS(accepted friendship)`). Stage A therefore only touched the two public-read predicates.
- **A hidden function dependency was caught before the drop.** `14_DIAGNOSTIC`'s function-body scan found `skip_topic_cards` + `suspend_topic_cards` still referenced `fc.is_public` (a redundant clause — `fc.visibility='public'` was already in the same `OR`). `09` Block 5 proved `is_public=true ⟺ visibility='public'` with zero drift, so removing it is data-equivalent. Migrated in `15_FUNCTIONS`. Same audit-gap class as L1's `vw_study_items` trap — **column drops need a function-body scan, not just pg_depend + grep.**

### Deployed (live, verified)
- **Stage A** — `10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql` (`ALTER POLICY` × 2 onto `visibility='public'`). Verified: `11_TEST` matrix, 24/24 cells PASS incl. `[CRITICAL]` stranger/anon-vs-friends/private.
- **Frontend** — commit `ca044d9`, pushed live: 8 files stripped of `is_public` (`FlashcardCreate`, `MyFlashcards`, `ProfessorTools`, `BulkUploadFlashcards`, `NoteUpload`, `NoteEdit`, `StudyMode` `.or()` filter, `MyNotes` filter + icon).
- **Function migration** — `15_FUNCTIONS_migrate_skip_suspend_topic_cards_off_is_public.sql`. Post-deploy gate: `14` q1 returns only `user_badges.is_public` hits (different column, not dropped); `09` q2 returns zero policies on `is_public`.
- **Stage B** — `12_SCHEMA_drop_is_public_notes_flashcards.sql` dropped the column from both tables (indexes auto-dropped). Verified: `13_TEST` all blocks PASS (column gone; note + flashcard insert succeed on `visibility` alone).

### Added — SQL (new this sprint, on top of the 09–13 set below)
- **`docs/database/landmines/14_DIAGNOSTIC_is_public_function_dependency_audit.sql`** — function-body `is_public` scan + table-alias classifier (`ub.`=user_badges safe, `fc.`/`n.`=must-migrate) + full-body dump of the two offenders. Read-only.
- **`docs/database/landmines/15_FUNCTIONS_migrate_skip_suspend_topic_cards_off_is_public.sql`** — `CREATE OR REPLACE` both RPCs verbatim minus the redundant `fc.is_public = true` line; `NOTIFY pgrst`.

### Changed — SQL corrected from the prepared drafts
- **`10_SCHEMA`** rewritten to `ALTER POLICY` (was DROP/CREATE + friends policies); **`11_TEST`** fixtures fixed (schema-valid `content_type`, student-only actors so `is_admin()` doesn't mask results, detail rows last so fails surface); **`13_TEST`** note fixture self-sources a CHECK-valid `content_type`.

### Files Changed
`docs/database/landmines/14_*.sql` (new), `docs/database/landmines/15_*.sql` (new), `docs/database/landmines/10_*.sql`, `11_*.sql`, `13_*.sql` (corrected), `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`

---
## [2026-07-03] chore(db): Landmine Cleanup Sprint L2 — is_public → visibility RLS rewrite (⏳ SQL not yet deployed)

### Added — SQL, saved to repo, not run against live DB
- **`docs/database/landmines/09_DIAGNOSTIC_landmine_l2_rls_audit.sql`** — ground-truth introspection: exact live `pg_policies` predicate/roles for `notes`/`flashcards`, any other policy referencing `is_public`, a `pg_depend` view/rule check (the L1 audit-gap lesson applied here), `friendships` column shape, `is_public` nullability/defaults, and an `is_public`-vs-`visibility` drift count across every row (catches content that is public today via `is_public=true` but would lose that status under a `visibility`-only policy). Read-only.
- **`docs/database/landmines/10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql`** — Stage A. Rewrites `users_view_public_notes`/`users_view_public_flashcards` from `is_public`-keyed to `visibility = 'public'`, and adds the first-ever `friends`-tier RLS policies (`users_view_friends_notes`/`users_view_friends_flashcards`, bidirectional accepted-`friendships` join). Every dropped policy has its exact rollback `CREATE POLICY` in a comment. Does not touch `is_public`, INSERT/UPDATE/DELETE policies, or role targeting (§1.11 landmine #2).
- **`docs/database/landmines/11_TEST_verify_visibility_rls_matrix.sql`** — self-contained `BEGIN...ROLLBACK` matrix. Fixtures 3 real profiles as owner/friend/stranger (no fabricated `auth.users` rows, following the L1 `06_TEST` precedent), tags one content row per visibility tier per table, then impersonates each actor (`SET LOCAL ROLE` + `set_config('request.jwt.claims', ...)`, the same mechanism PostgREST uses) to assert exact read access. 24 verdict rows; the stranger/anon-vs-friends/private cells are marked `[CRITICAL]`.
- **`docs/database/landmines/12_SCHEMA_drop_is_public_notes_flashcards.sql`** — Stage B. Drops `is_public` from both tables once Stage A is live-verified and the frontend change below is deployed and verified. Hard-gated in-file on a fresh `pg_depend` re-check. Rollback comment reconstructs the column from `visibility` (cannot recover pre-drop drift).
- **`docs/database/landmines/13_TEST_verify_insert_without_is_public.sql`** — post-drop check: column is gone, and a note/flashcard insert shaped like the post-migration frontend payload still succeeds.

### Changed — Frontend (written, NOT pushed — hard prerequisite for `12_SCHEMA`, reversed deploy order same as L1's SRS drop)
- **`src/pages/dashboard/Content/FlashcardCreate.jsx`, `MyFlashcards.jsx`, `ProfessorTools.jsx`, `BulkUploadFlashcards.jsx`, `NoteUpload.jsx`, `NoteEdit.jsx`** — removed `is_public` from every insert/update payload; `visibility` is now the sole field written.
- **`src/pages/dashboard/Study/StudyMode.jsx`** — fetch filter `.or('is_public.eq.true,user_id.eq.…,visibility.eq.friends')` → `.or('visibility.eq.public,user_id.eq.…,visibility.eq.friends')`. The `visibility.eq.friends` clause has been in this query since the visibility system shipped but RLS has always silently blocked those rows for non-owners — the friends-tier gap this sprint fixes was live, not hypothetical.
- **`src/pages/dashboard/Content/MyNotes.jsx`** — the visibility filter dropdown and the public/private list icon now read `note.visibility === 'public'` instead of `note.is_public`. Literal parity swap — friends-tier notes still fall into the "private"/lock-icon bucket, same as before; no UI/behavior change.
- Grepped all of `src/` for `is_public` first: 11 files matched. 3 (`MyAchievements.jsx`, `AuthorProfile.jsx`, `FindFriends.jsx`) reference the unrelated `user_badges.is_public` per-badge privacy toggle and were correctly left untouched.

### Notes
- **Deploy order (non-negotiable):** founder runs `09_DIAGNOSTIC` and reviews the drift check → `10_SCHEMA` (Stage A) deploys → `11_TEST` full matrix run, every cell PASS including `[CRITICAL]` stranger/anon rows, founder explicitly re-verifies those → frontend deploys + live create/edit verified → `12_SCHEMA` (Stage B) deploys → `13_TEST` → re-run `11_TEST`.
- **Docs gap found and fixed in passing:** `DATABASE_SCHEMA.md`'s notes section had two stale "⏳ pending drop" callouts (legacy `course`/`subject`/`topic` columns, `comments` table) left over from L1, which actually deployed and verified 02/07/2026 (commit `0bb966d`) — flipped to ✅ Resolved. Also flagged that `is_public` is missing from both `notes`' and `flashcards`' per-table column dumps in that doc (pre-existing gap, not introduced by this sprint).
- `blueprint.md` §1.11 #2 marked ⏳ SQL PREPARED (02/07/2026), pending founder deploy confirmation of both stages before flipping to ✅ RESOLVED.
- `npm run build` passes clean. No live-DB verification yet — the current live RLS is still `is_public`-keyed, so exercising the create/edit flows now (against the still-unmigrated live policy) would produce a real regression, not a valid test. Deferred to the founder's post-Stage-A checks per the gate order.

### Files Changed
`docs/database/landmines/09_DIAGNOSTIC_landmine_l2_rls_audit.sql` (new), `docs/database/landmines/10_SCHEMA_rewrite_notes_flashcards_rls_to_visibility.sql` (new), `docs/database/landmines/11_TEST_verify_visibility_rls_matrix.sql` (new), `docs/database/landmines/12_SCHEMA_drop_is_public_notes_flashcards.sql` (new), `docs/database/landmines/13_TEST_verify_insert_without_is_public.sql` (new), `src/pages/dashboard/Content/FlashcardCreate.jsx`, `src/pages/dashboard/Content/MyFlashcards.jsx`, `src/pages/dashboard/Content/MyNotes.jsx`, `src/pages/dashboard/Content/NoteUpload.jsx`, `src/pages/dashboard/Content/NoteEdit.jsx`, `src/pages/dashboard/Study/StudyMode.jsx`, `src/pages/professor/ProfessorTools.jsx`, `src/pages/dashboard/BulkUploadFlashcards.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`

---
## [2026-07-02] chore(db): Landmine Cleanup Sprint L1 — safe drops & schema de-clutter (⏳ SQL not yet deployed)

### Added — SQL, saved to repo, not run against live DB
- **`docs/database/landmines/01_DIAGNOSTIC_landmine_l1_audit.sql`** — ground-truth introspection for every drop target: trigger wiring, FK references into `comments`, RLS policies, indexes, column defaults, non-null row counts per target column, and the most-recent-write timestamp for the flashcards SRS columns (to sanity-check that `FlashcardCreate.jsx` was the sole writer, not a DB-side default/trigger). Read-only.
- **`docs/database/landmines/02_CLEANUP_drop_dead_trigger_functions.sql`** — drops `trg_check_badge_flashcard_create/note_upload/review/upvote` and `notify_friend_request/accepted`, `notify_content_upvoted` (blueprint.md §1.11 #4, #5). No trigger wired to any of them; live badge/notification paths (`fn_badge_check_*`, RPC/Edge Functions) are untouched.
- **`docs/database/landmines/03_CLEANUP_drop_comments_table.sql`** — `DROP TABLE IF EXISTS public.comments CASCADE` (§1.11 #6). Zero frontend usage. Removes the one non-notes/flashcards RLS dependency on `notes.is_public`, unblocking the future L2 `is_public`→`visibility` RLS migration (L2 itself not started).
- **`docs/database/landmines/04_SCHEMA_drop_legacy_free_text_columns.sql`** — drops `notes.course`/`subject`/`topic` and `upvotes.note_id` (§1.11 #7, #8). Superseded by FK + `custom_*` columns and the polymorphic `content_type`/`target_id` pair respectively. Zero client reads/writes found.
- **`docs/database/landmines/05_SCHEMA_drop_flashcards_srs_columns.sql`** — drops `flashcards.next_review`/`interval`/`ease_factor`/`repetitions` (vestigial pre-`reviews`-table SRS fields). **Frontend-gated** — see below.
- **`docs/database/landmines/06_TEST_verify_landmine_l1_drops.sql`** — row-returning verdict pattern (matches `docs/database/phase5/12`): confirms dropped objects/columns are gone, a flashcard insert still succeeds post-SRS-drop, badge/counter triggers still fire, and notes/upvotes remain readable.

### Changed — Frontend (written, NOT pushed — hard prerequisite for `05_SCHEMA`)
- **`src/pages/dashboard/Content/FlashcardCreate.jsx`** — removed `next_review`, `interval`, `ease_factor`, `repetitions` from the single-card insert payload. These were a hardcoded seed value (`new Date().toISOString()`, `1`, `2.5`, `0`) written on every insert and never subsequently updated — live SRS state has always been read from `reviews`, never `flashcards`. `BulkUploadFlashcards.jsx` and `ProfessorTools.jsx` (the other two flashcard-insert paths) never wrote these columns, so this is the only frontend change needed.

### Notes
- **Audit-before-drop:** codebase-side evidence (grep across all of `src/`) is complete for every target — see `docs/active/now.md` for the full per-target breakdown. The DB-side half (trigger wiring, FK references, RLS predicates) requires the founder to run `01_DIAGNOSTIC` in the Supabase SQL Editor before any of `02`–`05` deploy — that output has not been reviewed yet in this session.
- **Deploy order:** `02`/`03`/`04` are immediately deployable (no frontend dependency) once `01_DIAGNOSTIC` confirms zero live references. `05_SCHEMA` is reversed — frontend-first: deploy the `FlashcardCreate.jsx` change, verify a flashcard create in production, **then** run `05_SCHEMA`. Run `06_TEST` after each deploy.
- **Out of scope for L1:** `is_public`, `visibility`, and all public-read RLS policies on `notes`/`flashcards` — untouched. That rewrite is L2, not started.
- `blueprint.md` §1.11 items #4–#8 (and the SRS type-inconsistency note) marked ⏳ SQL PREPARED (2026-07-02), pending founder deploy confirmation.
- `npm run build` / dev-server compile clean after the `FlashcardCreate.jsx` change (no in-browser DB write test — that requires the live Supabase project and is deferred to the founder's post-deploy verification per the deploy order above).

### Files Changed
`docs/database/landmines/01_DIAGNOSTIC_landmine_l1_audit.sql` (new), `docs/database/landmines/02_CLEANUP_drop_dead_trigger_functions.sql` (new), `docs/database/landmines/03_CLEANUP_drop_comments_table.sql` (new), `docs/database/landmines/04_SCHEMA_drop_legacy_free_text_columns.sql` (new), `docs/database/landmines/05_SCHEMA_drop_flashcards_srs_columns.sql` (new), `docs/database/landmines/06_TEST_verify_landmine_l1_drops.sql` (new), `src/pages/dashboard/Content/FlashcardCreate.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`

---
## [2026-07-02] fix(db): access_requests 'dismissed' status CHECK (⏳ SQL not yet deployed)

- **`docs/database/phase5/22_SCHEMA_add_dismissed_to_access_requests_status_check.sql`** (new) — extends `access_requests_status_check` to add `'dismissed'` (now `('pending','contacted','enrolled','approved','rejected','dismissed')`), closing a pre-existing bug where the admin status dropdown offered "Dismissed" but the CHECK rejected it (Postgres 23514). Idempotent DROP/ADD, mirrors script 17. No frontend change — dropdown already offers the option. ⏳ Deploy in Supabase; no frontend push needed.

---
## [2026-07-02] feat(landing): Phase 5 Sprint 6 (FINAL) — educator-application → admin-approve → role grant (SQL written, NOT yet deployed)

### Added — SQL, saved to repo, not run against live DB
- **`docs/database/phase5/17_SCHEMA_extend_access_requests_status_check_for_approval.sql`** — extends `access_requests_status_check` (was `('pending','contacted','enrolled')`, confirmed via introspection — notably missing `'dismissed'` too, a separate pre-existing bug, out of scope) to add `'approved'`/`'rejected'`. No new column — introspection confirmed no approver/approved-at column exists and none was needed.
- **`docs/database/phase5/18_FUNCTIONS_submit_educator_application.sql`** — new SECURITY DEFINER RPC (`GRANT TO anon, authenticated`) capturing educator applications. Required: full name, WhatsApp, credential-or-LinkedIn URL. Optional: email, institute name, course(s) taught, why. Maps onto `access_requests` (mirrors `submit_institute_inquiry`'s style: `content_name` reused for institute, `message` combines credential+why). **Returns the row's `ref_token` (uuid)**, not void — lets an anonymous applicant's browser carry it into `localStorage['revisop_access_ref']` for auto-linking on a later same-browser signup.
- **`docs/database/phase5/19_FUNCTIONS_approve_reject_educator_application.sql`** — `approve_educator_application(p_request_id)` (admin/super_admin only) grants `professor` + notifies immediately if the applicant has a linked account (returns `'role_granted'`), else defers the grant (returns `'approved_pending_signup'`). `reject_educator_application(p_request_id)` marks rejected, notifies if linked.
- **`docs/database/phase5/20_FUNCTIONS_extend_link_access_request_educator_role_grant.sql`** — `CREATE OR REPLACE` of the existing `link_access_request(p_ref_token uuid)` (exact introspected signature/return type preserved; ground-truth introspection showed it only tags `profiles.access_request_ref` and never touches `access_requests`). Adds: on first login, if the ref_token matches an approved `educator_application`, grants `professor` + notifies right then. All other request_types unaffected.
- **`docs/database/phase5/21_TEST_verify_educator_application_flow.sql`** — 11 BEGIN/ROLLBACK blocks: anon submit + full field mapping, missing-credential validation, course default, admin notification, non-admin approve gate, linked approve (role+notify), unlinked approve (no role flip), reject, link-on-signup flip, and a regression guard that a still-pending application never grants the role.

### Added — Frontend (written, NOT pushed — SQL deploy is a hard prerequisite)
- **`src/pages/public/Educators.jsx`** — new "Apply to Teach on RevisOp" section, distinct from the S5 institute form (separate state, own `eduapp-*` element ids). Calls `submit_educator_application`; anonymous submitters get the returned `ref_token` stored into `localStorage['revisop_access_ref']`. Same "1–2 business days" success copy.
- **`src/pages/admin/AdminDashboard.jsx`** — "Educator Applications" filter + purple "Educator" badge in the Access Requests queue. Read-only status badge for these rows (the generic status `<select>` is intentionally bypassed — it would skip the role-grant RPCs). Approve/Reject buttons; outcome renders as "Educator role granted ✓", "Awaiting signup" (+ copyable `/signup?ref=` link), or "Rejected".

### Notes
- **Ground-truth blocker:** no `psql`/`pg_dump`/Docker available in this session, so the founder ran three `[DIAGNOSTIC]` introspection queries in the SQL Editor instead of a direct dump. This surfaced that `access_requests` has no approver/approved-at column and that `link_access_request` is simpler than assumed — both would have risked a failed deploy (per the S4 42P13 lesson) if guessed instead of confirmed.
- Pre-existing bug found in passing: `access_requests_status_check` never included `'dismissed'` despite `AdminDashboard.jsx`'s dropdown offering it for every request type. Flagged as a separate background task, not fixed in this sprint.
- Verified in-browser (dev server) against the live Supabase project with the SQL NOT yet deployed: filled and submitted the new form, network capture confirmed the RPC call used the exact 8 parameter names the SQL defines, and got the expected `PGRST202` "function not found" — proof the frontend↔RPC contract is correct pending deployment.
- `AdminDashboard.jsx` changes verified by code review + `npm run build` only (no admin credentials available in this session for in-browser testing).
- `npm run build` passes.
- **Frontend written but NOT pushed** — SQL 17–21 must be deployed and confirmed by the founder first, per the Deployment Order Rule.
- **This is the final Phase 5 sprint.**

### Files Changed
`docs/database/phase5/17_SCHEMA_extend_access_requests_status_check_for_approval.sql` (new), `docs/database/phase5/18_FUNCTIONS_submit_educator_application.sql` (new), `docs/database/phase5/19_FUNCTIONS_approve_reject_educator_application.sql` (new), `docs/database/phase5/20_FUNCTIONS_extend_link_access_request_educator_role_grant.sql` (new), `docs/database/phase5/21_TEST_verify_educator_application_flow.sql` (new), `src/pages/public/Educators.jsx`, `src/pages/admin/AdminDashboard.jsx`, `.claude/launch.json`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`

---
## [2026-07-01] feat(landing): Phase 5 Sprint 5 — B2B /educators route + lead-capture RPC (SQL deployed, frontend awaiting verification)

### Added — SQL, deployed & verified against live DB (2026-07-01)
- **`docs/database/phase5/14_SCHEMA_add_request_type_and_message_columns.sql`** — adds `request_type` (`text NOT NULL DEFAULT 'student_access'`, `CHECK IN ('student_access','institute_inquiry','educator_application')` — third value pre-added for Sprint 6) and `message` (nullable text) to `access_requests`. Idempotent.
- **`docs/database/phase5/15_FUNCTIONS_submit_institute_inquiry.sql`** — new SECURITY DEFINER RPC (`GRANT TO anon, authenticated`) capturing B2B institute leads. Maps the lead form onto existing `access_requests` columns (`name`/`whatsapp_number`/`course`/`email` reused directly; `content_name` reused for institute name; `message` combines city + optional note — the one genuinely new column). Admin notification reuses the existing `'access_request'` `notifications.type` (its CHECK constraint doesn't include an institute-specific value; extending it was out of scope), distinguished via `metadata->>'request_type'`.
- **`docs/database/phase5/16_TEST_verify_institute_inquiry_rpc.sql`** — 6 BEGIN/ROLLBACK blocks. **All 6 PASS**: full field mapping, course default (`'General inquiry'`), city-only message formatting, both required-field validations (institute name, WhatsApp), admin notification fan-out.

### Added — Frontend
- **`src/pages/public/Educators.jsx`** (new) — `/educators`, anonymous, zero direct `.from()`. Institute value-proposition (mirrors `Home.jsx`'s "For Institutes & Educators" copy) + lead form (institute name, contact name, email, WhatsApp, city, course, message) calling `submit_institute_inquiry`. Mirrors `ContentPreviewWall.jsx`'s form/validation pattern (WhatsApp country-code normalization). Success state: "We'll reach out within 1–2 business days."
- **`src/App.jsx`** — `/educators` route added to the public no-auth-guard block (lazy import).

### Changed
- **`src/pages/Home.jsx`** — added a secondary nav link ("For Institutes" → `/educators`). Rewired the hero, "For Institutes & Educators" section CTA, and footer `mailto:` links to `/educators` (section content untouched — same copy, just a real form instead of a mailto).
- **`src/pages/admin/AdminDashboard.jsx`** — Access Requests table gets a Type badge (Institute/Student) + filter (All/Student Access/Institute Inquiries). Institute rows show institute name + city/message in a new "Details" column and a "Lead — follow up" label in place of the signup-link/Grant-Access UI (institute inquiries need no approval action this sprint — that's Sprint 6's educator-application-to-role-grant flow).

### Notes
- Verified in-browser (dev server) against the live deployed Supabase backend: filled and submitted the `/educators` form, `submit_institute_inquiry` returned `204`, success state rendered correctly, no console errors. This created one real test row (`content_name = 'Test Preview Institute'`) — dismiss/delete when convenient.
- `AdminDashboard.jsx` changes verified by code review + `npm run build` only (no admin credentials available in this session for in-browser testing).
- `npm run build` passes.
- **Frontend committed but NOT pushed** — reporting back to the phasebuilder for verification per sprint instructions; push authorized only after that confirmation.

### Files Changed
`docs/database/phase5/14_SCHEMA_add_request_type_and_message_columns.sql` (new), `docs/database/phase5/15_FUNCTIONS_submit_institute_inquiry.sql` (new), `docs/database/phase5/16_TEST_verify_institute_inquiry_rpc.sql` (new), `src/pages/public/Educators.jsx` (new), `src/App.jsx`, `src/pages/Home.jsx`, `src/pages/admin/AdminDashboard.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/active/now.md`

---
## [2026-07-01] feat(landing): Phase 5 Sprint 4 — hero live-demo + featured rail + stats consolidation (SQL written, NOT yet deployed)

### Added — SQL, saved to repo, not run against live DB
- **`docs/database/phase5/13_FUNCTIONS_extend_get_platform_stats_public_counts.sql`** — `CREATE OR REPLACE` of `get_platform_stats()` (same signature) adding `public_flashcards`/`public_notes` (`visibility = 'public'` counts). Existing `student_count`/`educator_count`/`total_flashcards`/`total_notes` fields preserved as-is.

### Added — Frontend
- **`src/components/landing/HeroFlipDemo.jsx`** (new) — anonymous, no-DB-write hero demo. Fetches `get_featured_landing_content()` via `Home.jsx`; drives the flip from the first featured deck with teaser cards, falling back to 3 hardcoded generic cards if none exist so the hero is never blank. `FlipCard` (controlled) → Hard/Medium/Easy rating buttons styled after `StudyMode.jsx`'s rating UI (cosmetic only) → advances to next card → soft wall ("Sign up to save your progress" → `/signup`) after the last card.
- **`src/pages/Home.jsx`** — new "Featured Study Sets" rail renders `get_featured_landing_content()` decks + notes as `StudyItemCard`s (badge "Featured") linking to `/deck/:id` / `/note/:id`; omitted entirely when nothing is curated (no broken empty state).

### Changed
- **`src/pages/Home.jsx`** — **deleted all direct `.from()` table reads**: the two `profiles` role-count queries and the two `flashcards`/`notes` public-count queries. Replaced with `get_platform_stats()`'s new `public_flashcards`/`public_notes` fields (gated on SQL 13 deployment) and the RPC's existing `student_count`/`educator_count`. Home.jsx now has zero direct `.from()` calls — closes the Technical Debt item flagged in `blueprint.md` §1.4.

### Removed
- **`src/pages/Home.jsx`** — deleted the 3 placeholder "— Student / Early Access" testimonial cards and their section wrapper (no replacement copy invented).

### Notes
- **SQL 13 is a hard prerequisite for pushing this sprint's frontend.** Until deployed, `get_platform_stats()` returns `undefined` for the two new fields, so the "Free to Browse" section renders `0`/`0` instead of real public counts (not a crash, but visibly wrong — do not push until deployed).
- Verified in-browser: the real already-curated "Business Laws — ICA 1872" deck (live via S3) exercised the has-featured-content path end-to-end (flip → rate → advance × 5 → soft wall; rail rendered correctly). The no-featured-content fallback was verified by stubbing the RPC response and remounting client-side (no full reload) — rail disappeared, hero showed the 3-card fallback. No console errors in either state. `npm run build` passes.
- "For Institutes & Educators" section + its `mailto:` CTA left untouched — real `/educators` route is Sprint 5, not this sprint.

### Files Changed
`docs/database/phase5/13_FUNCTIONS_extend_get_platform_stats_public_counts.sql` (new), `src/components/landing/HeroFlipDemo.jsx` (new), `src/pages/Home.jsx`, `.claude/launch.json` (new, dev-server preview config), `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/active/now.md`

---
## [2026-07-01] feat(landing): Phase 5 Sprint 3 — curation UI: nominate → admin-approve (SQL written, NOT yet deployed)

### Added — SQL (Part A), saved to repo, not run against live DB
- **`docs/database/phase5/09_SCHEMA_add_featured_nomination_columns.sql`** — 4 new nullable columns on `flashcard_decks` + `notes`: `featured_nominated_by`/`featured_nominated_at`, `featured_approved_by`/`featured_approved_at` (FK → `profiles.id`). Additive on top of the deployed S2 `is_featured_on_landing` flag.
- **`docs/database/phase5/10_SCHEMA_featured_autoclear_nomination_reset.sql`** — `CREATE OR REPLACE` of the existing `fn_autoclear_featured_on_visibility_change()` so the S2 auto-clear trigger also nulls the 4 new columns when a row's visibility leaves `'public'`. No new trigger — the S2 triggers already point at this function.
- **`docs/database/phase5/11_FUNCTIONS_featured_nomination_rpcs.sql`** — 6 new SECURITY DEFINER RPCs: `nominate_featured_content(p_content_type, p_content_id)` (professor/admin/super_admin, own row or admin, public-only, idempotent), `approve_featured_nomination(...)` (admin/super_admin only, returns the resulting `is_featured_on_landing` boolean), `reject_featured_nomination(...)`, `unfeature_content(...)` (full removal — nulls all four fields so the item leaves both the landing and the Pending queue), `get_pending_featured_nominations()`, `get_live_featured_content_admin()` (both UNION ALL decks + notes into one shape for the admin queues).
- **`docs/database/phase5/12_TEST_verify_featured_nomination_curation.sql`** — verifies role gates, the public-only nomination guard, the approve→live transition, the non-public-mid-flight guard, the unpublish reset, and the unfeature full-removal behavior — all wrapped in `BEGIN`/`ROLLBACK`.

### Added — Frontend (Part B), gated on Part A SQL deployment
- **`src/components/content/FeatureNominationButton.jsx`** (new) — shared 3-state control (not nominated → "Feature on landing" button; pending → non-interactive "Pending review" badge; live → "Featured ✓" badge). Calls `nominate_featured_content` and optimistically reflects the pending state.
- **`src/pages/dashboard/Content/MyFlashcards.jsx`** — grouped-view deck header now fetches the caller's `flashcard_decks` rows (id, visibility, `is_featured_on_landing`, `featured_nominated_at`) and matches each batch group to its deck via the standard 5-grouping-column join (never `deck_id`, which is never populated). Renders `FeatureNominationButton` for public decks when `isProfessor || isAdmin`.
- **`src/pages/dashboard/Content/NoteDetail.jsx`** — header actions render `FeatureNominationButton` for public notes when the caller is admin, or is the professor owner.
- **`src/pages/admin/AdminDashboard.jsx`** — new "Landing Page Content" section in Content Moderation: **Pending Nominations** (Approve/Reject; Approve checks the RPC's returned boolean and shows an error toast if the content went non-public mid-click) and **Currently Live** (Unfeature). Both are always-visible with a zero-state message, matching the existing Flagged Content card's pattern — that card is untouched.

### Notes
- **Part A SQL is a hard prerequisite for Part B going live.** The frontend calls RPCs (`nominate_featured_content`, etc.) that do not exist on the live DB until 09→11 are deployed and 12 is run to verify. Do not push/deploy the frontend until the founder confirms.
- S2 objects (`is_featured_on_landing` column/CHECK, partial indexes, `get_featured_landing_content()`, capped `get_public_deck_preview`) are unmodified.

### Files Changed
`docs/database/phase5/09_SCHEMA_add_featured_nomination_columns.sql` (new), `docs/database/phase5/10_SCHEMA_featured_autoclear_nomination_reset.sql` (new), `docs/database/phase5/11_FUNCTIONS_featured_nomination_rpcs.sql` (new), `docs/database/phase5/12_TEST_verify_featured_nomination_curation.sql` (new), `src/components/content/FeatureNominationButton.jsx` (new), `src/pages/dashboard/Content/MyFlashcards.jsx`, `src/pages/dashboard/Content/NoteDetail.jsx`, `src/pages/admin/AdminDashboard.jsx`, `docs/active/blueprint.md`, `docs/reference/DATABASE_SCHEMA.md`, `docs/active/now.md`, `docs/reference/FILE_STRUCTURE.md`

---
## [2026-07-01] feat(db): Phase 5 Sprint 2 — featured-flag schema + get_featured_landing_content RPC (SQL written, NOT yet deployed)

### Added — SQL only, saved to repo, not run against live DB
- **`docs/database/phase5/01_DIAGNOSTIC_introspect_preview_rpcs.sql`** — read-only `pg_get_functiondef` calls, run by founder; confirmed `get_public_deck_preview` (jsonb, deck + `preview_items` capped at 10) and `get_public_note_preview` (TABLE, incl. an undocumented `description` column) exact bodies.
- **`docs/database/phase5/02_DIAGNOSTIC_trigger_collision_scan.sql`** — confirmed `flashcard_decks` has zero existing triggers and `notes` has no `BEFORE UPDATE` trigger, so the new auto-clear triggers below have no collision risk.
- **`docs/database/phase5/03_SCHEMA_add_is_featured_on_landing_column.sql`** — `is_featured_on_landing boolean NOT NULL DEFAULT false` on `flashcard_decks` and `notes`, with inline `CHECK (is_featured_on_landing = false OR visibility = 'public')`. Safe on live data (all rows default false).
- **`docs/database/phase5/04_SCHEMA_featured_landing_autoclear_triggers.sql`** — shared `fn_autoclear_featured_on_visibility_change()` + `BEFORE UPDATE` triggers on both tables (`trg_autoclear_featured_flashcard_decks`, `trg_autoclear_featured_notes`) that clear the flag the moment `visibility <> 'public'`.
- **`docs/database/phase5/05_SCHEMA_featured_landing_partial_indexes.sql`** — partial indexes `idx_flashcard_decks_featured` / `idx_notes_featured` on `(is_featured_on_landing) WHERE is_featured_on_landing = true`.
- **`docs/database/phase5/06_FUNCTIONS_get_featured_landing_content.sql`** — new `get_featured_landing_content()` SECURITY DEFINER RPC, `GRANT EXECUTE TO anon, authenticated`. Returns `{ decks: [...], notes: [...] }`; decks capped at 12, each with a `cards` array hard-capped at exactly 5 (`front_text`, `back_text`, `question_type`) fetched via the 5-grouping-column join (never `fc.deck_id`); notes capped at 12, metadata + a 200-char `description` snippet only (no note body). Double-guards `visibility = 'public'` even though the trigger already enforces it.
- **`docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql`** — `CREATE OR REPLACE` of `get_public_deck_preview`, dropping its `preview_items` cap from 10 to 5 to match the locked teaser-depth decision. Signature unchanged; rest of the body reproduced verbatim.
- **`docs/database/phase5/08_TEST_verify_featured_landing.sql`** — verification: CHECK rejects featured+non-public, trigger clears flag on visibility downgrade, baseline + populated RPC calls (wrapped in `BEGIN`/`ROLLBACK`, no data left committed).

### Notes
- **SQL-only sprint — nothing was deployed.** ⚠️ This SQL must be run in Supabase (in file order 03→07, then 08 to verify) before any Sprint 3/4 frontend work begins.
- No frontend changes this sprint.

### Files Changed
`docs/database/phase5/01_DIAGNOSTIC_introspect_preview_rpcs.sql` (new), `docs/database/phase5/02_DIAGNOSTIC_trigger_collision_scan.sql` (new), `docs/database/phase5/03_SCHEMA_add_is_featured_on_landing_column.sql` (new), `docs/database/phase5/04_SCHEMA_featured_landing_autoclear_triggers.sql` (new), `docs/database/phase5/05_SCHEMA_featured_landing_partial_indexes.sql` (new), `docs/database/phase5/06_FUNCTIONS_get_featured_landing_content.sql` (new), `docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql` (new), `docs/database/phase5/08_TEST_verify_featured_landing.sql` (new), `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/DATABASE_SCHEMA.md`

---
## [2026-06-30] feat(design-system): Phase 5 Sprint 1 — brand tokens + StudyItemCard + FlipCard

### Added
- **Additive brand token layer** in `src/index.css` (`:root` + `.dark`) and wired into `tailwind.config.js` `theme.extend.colors`:
  - `brand.navy` (#1e1b4b → `243.8 47.1% 20%`), `brand.amber` (#f59e0b → `37.7 92.1% 50.2%`), `brand.success` (green-600 #16a34a → `142.1 76.2% 36.3%`), each with a `*-foreground` pair.
  - `surface.card` / `surface.muted` / `surface.border` / `surface.amber` (amber-50 #fffbeb) / `surface.navy` (light navy tint).
  - **No existing shadcn token VALUE changed** — purely additive, so existing pages render byte-identically.
- **`StudyItemCard`** (`src/components/ui/StudyItemCard.jsx`) — presentational, prop-driven deck/study-set list card (title, subject/topic chips, item count, author, optional Featured/Expert badge, optional lucide icon, optional `onClick`). Matches the shadcn `card.jsx` pattern (`forwardRef`, `cn`, `displayName`).
- **`FlipCard`** (`src/components/ui/FlipCard.jsx`) — presentational 3D flip with a **controlled `isFlipped` prop** (front=question, back=answer). No SRS/rating logic (Sprint 4's job).
- **3D flip utilities** in `src/index.css` `@layer utilities` (`perspective-1000`, `preserve-3d`, `backface-hidden`, `rotate-y-180`, `flip-transition`) with `prefers-reduced-motion` respected.
- **DEV-ONLY showcase** `src/pages/dev/DesignShowcase.jsx` at route `/__design` (no auth, no DB, not in any nav) for QA of tokens + components. Sprint 4 may remove/keep.

### Notes
- **Zero DB/SQL prerequisites and zero anon-data paths** — the SQL-before-frontend deployment gate is N/A for this sprint.
- `npm run build` passes; existing pages visually unchanged (tokens are additive only).

### Files Changed
`src/index.css`, `tailwind.config.js`, `src/components/ui/StudyItemCard.jsx` (new), `src/components/ui/FlipCard.jsx` (new), `src/pages/dev/DesignShowcase.jsx` (new), `src/App.jsx`, `docs/active/now.md`, `docs/tracking/changelog.md`, `docs/reference/FILE_STRUCTURE.md`, `docs/active/blueprint.md`

---
## [2026-06-30] fix: Closed vw_study_items SECURITY DEFINER view exposure (was CRITICAL)

### Fixed (live DB) — active data leak
- **`vw_study_items` was actively exposed.** The SECURITY DEFINER view had `SELECT` granted to `anon` and `authenticated`, so anyone with the public anon key could query `/rest/v1/vw_study_items` via PostgREST and read **all flashcards including private ones**, bypassing RLS. Confirmed via `information_schema.role_table_grants`.
- **Fix:** `REVOKE ALL ON public.vw_study_items FROM anon, authenticated` + `ALTER VIEW public.vw_study_items SET (security_invoker = on)`. Verified only `postgres`/`service_role` retain SELECT and `reloptions = security_invoker=on`. Sole consumer `get_anonymous_class_stats` (SECURITY DEFINER) is unaffected — it runs as the owner, so the view still returns all rows inside it.
- This was the Phase-1 security prerequisite ahead of the "show don't tell" landing-page pivot. (`search_path` hardening on ~80 functions remains as deferred, lower-priority batch work.)

### Files Changed
`docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-06-30] docs: Logged Supabase Advisor findings + started landing-page pivot scoping

### Added (blueprint.md §1.11)
- **Supabase Advisor (Security) findings logged:** 🔴 CRITICAL — `vw_study_items` is a SECURITY DEFINER view (bypasses caller RLS; currently used only server-side, not client-facing). 🟡 Sev 3 — ~80 functions flagged "Function Search Path Mutable" (batch hardening). Both relevant to the upcoming public-content pivot; fixes deferred (need dependency checks first).

### Context
- **Pivot under exploration (not finalized):** "show don't tell" landing page — let content creators opt in to display work to anonymous visitors; separate value tracks for students vs B2B educators. Leans toward a dedicated public-facing opt-in flag rather than reusing `is_public`/`visibility`. This makes Landmine #2 (notes RLS) and the `vw_study_items` view part of the pivot foundation.

### Files Changed
`docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-06-30] fix: Pre-pivot cleanup — dropped duplicate notification RPC overloads (Landmine #3)

### Fixed (live DB)
- **Removed duplicate overloads of `delete_notification` and `mark_single_notification_read`.** Each existed in `(uuid)` and `(uuid, uuid)` signatures — a PostgREST ambiguity risk (same class as the `suspend_topic_cards` outage). The frontend (`useNotifications.js`) calls only the single-arg `(p_notification_id)` versions, so dropped the `(uuid, uuid)` overload of each and ran `NOTIFY pgrst, 'reload schema'`. Verified one signature each remains.

### Files Changed
`docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-06-30] fix: Pre-pivot cleanup — removed duplicate signup trigger (Landmine #1)

### Fixed (live DB)
- **Duplicate profile-creation trigger on `auth.users` removed.** Two triggers (`on_auth_user_created → handle_new_user()` and `trg_create_profile_on_signup → fn_create_profile_on_signup()`) both created a profile on every signup. Dropped `on_auth_user_created` + `handle_new_user()`; kept `fn_create_profile_on_signup` (referenced by `AuthContext.jsx`). Root cause: same orphaned-profile bug fixed twice (Mar 19 + Mar 20, 2026) without dropping the first fix. Dormant (both had `ON CONFLICT DO NOTHING`; the first-firing one won), but a hazard for any pivot touching signup.
- **Verification:** confirmed a single signup trigger remains, then validated end-to-end — a fresh signup auto-creates a correct profile (`role=student`, `account_type=self_registered`, `status=active`).

### Found (logged, not yet fixed)
- **`profiles.id → auth.users.id` is `ON DELETE NO ACTION`** while every other user-referencing FK is `CASCADE`. Deleting a user from the Supabase Auth dashboard fails until the `profiles` row is deleted first. Catalogued in blueprint §1.11; fix deferred pending a `profiles(id)` reference audit.

### Files Changed
`docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-06-29] docs: Blueprint DB Verification — reconciled against live database

### Summary
Completed the verification the previous entry could not: the blueprint's backend half was reconciled against the **live Supabase database** (4 read-only `[DIAGNOSTIC]` introspection queries — columns, triggers, functions, RLS policies). This closes the "frontend-only verification" gap. The blueprint is now an evidence-backed Single Source of Truth for both frontend AND database layers, with all known DB-level problems explicitly catalogued.

### Changed (blueprint.md)
- **Header counts corrected:** 24 → **30 tables + 1 view**; triggers 10+ → 18 public + 2 on `auth.users`; functions 16+ → 90+.
- **§1.1 schema fixes:** Removed non-existent `notes.is_verified`. Added undocumented columns: `notes.description/course/subject/topic`, `profiles.access_request_ref/updated_at`, `upvotes.note_id` (legacy). Corrected `reviews.easiness` type (numeric → **double precision**). Confirmed flashcards vestigial SRS columns + `reviews.next_review_date = date` against DB.
- **§1.4 trigger table rewritten:** Corrected the `auto_resolve_content_error_flags` trigger (fires on flashcards/notes to CLEAR flags on edit — NOT escalation on content_flags). Added 4 previously undocumented triggers. Flagged the duplicate `auth.users` profile-creation triggers.
- **New §1.11 DB Cleanup Backlog & Landmines:** Catalogues 3 🔴 landmines (duplicate signup triggers, load-bearing `is_public`, overloaded RPCs), 3 🟡 dead/orphaned object groups, undocumented legacy columns, and type inconsistencies. Includes verification provenance.
- **§2.5 corrected:** `is_public` reclassified from "removable backward-compat column" to load-bearing (notes public RLS depends on it).

### Action items surfaced for the user (DB changes, not doc changes)
- 🔴 Resolve duplicate profile-creation triggers on `auth.users` before pivot (signup risk).
- 🔴 Rewrite notes/flashcards public RLS onto `visibility` before dropping `is_public`.
- 🔴 Drop the unused overloads of `delete_notification` / `mark_single_notification_read`.

### Files Changed
`docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-06-29] docs: Foundation Reconciliation & Documentation Sync

### Summary
The master blueprint (`docs/active/blueprint.md`) was audited line-by-line against the actual source code (via repomix export of the full repo) and corrected so it now serves as the **100% reliable Single Source of Truth for the upcoming pivot**. Several discrepancies where the blueprint described intent rather than the shipped code have been reconciled to "as-built, warts and all."

### Changed (blueprint.md)
- **Schema (§1.1)** — Documented the 4 **vestigial SRS columns** still written to the `flashcards` table on INSERT (`next_review`, `interval`, `ease_factor`, `repetitions`) — write-only initialization defaults that are never read for scheduling (all live SRS reads come from `reviews`). Flagged the `ease_factor`/`repetitions` (flashcards) vs `easiness`/`repetition` (reviews) name divergence. Corrected `reviews.next_review_date` data type from `timestamptz` → **`date`** (stored as `YYYY-MM-DD` local-date string; treating it as a timestamp causes "wrong day" bugs).
- **RPC Inventory (§1.4)** — Header corrected from "16+" to **70+ functions**. Added a complete "Additional RPCs found in code" table (domain-grouped) capturing ~50 previously undocumented SECURITY DEFINER RPCs found via a full `.rpc()` sweep — incl. `get_public_educators`, `get_platform_stats`, `admin_delete_user_data`, card suspend/skip/reset family, professor/admin/super-admin analytics, heatmaps, author profile, upvote, and B2B batch-enrollment RPCs. Expanded the previously-collapsed "Group RPCs (14)" / "Notification RPCs (6)" lines.
- **localStorage keys (§3.1, new D-09)** — Added a complete 9-key inventory. Documented that the rebrand (D-08) only renamed the 6 `recall_*` → `revisop_*` keys, and that **3 active keys use inconsistent naming and were never branded**: `postAuthRedirect`, `myNotes_viewMode`, `flashcard_create_draft`.
- **Security / Tech Debt (§1.4 RLS)** — Flagged that `Home.jsx` mixes correct RPC use with **direct anon `.from()` count reads** (RLS-filtered, unreliable) as Technical Debt to resolve.
- **Utility logic (§1.8)** — Documented `useSpeech.js` `splitIntoChunks()` sentence-chunking as a deliberate workaround for the Chrome/Edge ~15s `speechSynthesis` cutoff bug.

### Verified (no change needed)
- **Routes (§1.5)** — Audited all 47 routes in `App.jsx`; the table was already complete, incl. `/dashboard/friend-requests` and `/dashboard/profile/:userId` (the audit flagged these as missing, but the blueprint had already been updated). Left existing correct content untouched.

### Files Changed
`docs/active/blueprint.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

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
## [2026-04-04] fix: Sprint 4.0 hotfix 3 — Wrong column names in topic RPCs + schema doc corrected

### Fixed
- **`suspend_topic_cards` + `skip_topic_cards` column names** — Both RPCs used `easiness_factor` (actual: `easiness`) and `repetitions` (actual: `repetition`) sourced from an incorrect DATABASE_SCHEMA.md. Error 42703 only surfaced when the INSERT path was triggered by real data (cards with an existing topic). Deployed via `CREATE OR REPLACE` of both functions with correct column names + `NOTIFY pgrst, 'reload schema'`.
- **`DATABASE_SCHEMA.md` reviews table** — Corrected `easiness_factor` → `easiness`, `repetitions` → `repetition`. Added missing `last_reviewed_at` column and `reviews_user_flashcard_unique` UNIQUE constraint. Column count corrected from 10 to 12. CRITICAL section expanded with all three known column name traps and a rule to cross-check against `StudyMode.jsx` handleRating before deploying any SQL against the reviews table.

### Files Changed
`docs/reference/DATABASE_SCHEMA.md`, `docs/tracking/bugs.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

---
## [2026-04-04] fix: Sprint 4.0 hotfix — Suspend Topic PostgREST ambiguity

### Fixed
- **`suspend_topic_cards` stale overload** — Sprint 4.0 added a `p_custom_topic TEXT DEFAULT NULL` parameter to `suspend_topic_cards`, which PostgreSQL treated as a new function rather than replacing the original `(UUID, UUID)` version. PostgREST could not resolve which overload to call and returned an error on every Suspend Topic attempt. Fix: `DROP FUNCTION IF EXISTS public.suspend_topic_cards(UUID, UUID)` in Supabase SQL Editor. No frontend changes required.

### Files Changed
`docs/tracking/bugs.md`, `docs/active/now.md`, `docs/tracking/changelog.md`

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