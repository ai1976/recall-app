# T-001 brief C, v1 (draft): Review badge and study heatmap (backlog points 6 and 7)

**Status:** draft v1 for QA's audit and the Founder's Gate 1 (06/10/2026). Not approved. A design brief, not SQL and not code: no SQL file, frontend change, migration or deployment is authorized by it.
**Scope:** point 6 (the Review badge and the other "due" numbers) and point 7 (the heatmap's study time). Brief B's day-detail view with course and subject (points 5 and 10) builds on the heatmap shell designed here; it is not part of this brief.
**Labels:** VERIFIED (saved evidence or code at the path and line given), PROPOSAL (Claude's design, needs approval), OPEN (not known). Evidence is cited by thread round (T-001 file) and saved file; code references are `path:line @ 6fc6ceb`.

## 1. What the Founder sees today, in plain words
1. **The red Review badge does not go down after you Pause, Remove or Re-add a card, finish a review, or switch course;** it is only correct after a full reload.
2. **The heatmap shows one number per day for all study time, offline and in-app mixed,** in a native hover title only. It cannot be reached by keyboard, and a phone cannot show it at all.

## 2. What is already agreed (status block of the thread, 02/10/2026; positions, not an approval)
- Point 6: same eligibility semantics as the Review page; refresh after Pause, Resume, Remove, Re-add, review completion and course switch.
- Point 7: split offline (`study_sessions.source = 'manual'`) from in-app (`study_mode`, `practice_mode`); an accessible hover and focus tooltip plus a pinned tap detail.

## 3. Evidence (what is true now)
**Point 6.**
- **P6-E1 (VERIFIED, Round 2 findings 6.1 and 6.2).** The badge number is `dueToday` from `NavDataContext`, fed by `useDueForecast`, which calls RPC `get_due_forecast` once per user and mount (`src/hooks/useDueForecast.js:24`, `src/contexts/NavDataContext.jsx:39,67-71`; drawn at `NavDesktop.jsx:209-211`, `NavBottomTabs.jsx:246-248`). A refetch function exists (`NavDataContext.jsx:71`) but nothing calls it.
- **P6-E2 (VERIFIED live, RUN 1B in the thread).** `get_due_forecast`, `get_due_forecast_buckets` and `get_study_queue` have **no enrollment filter**; `get_my_cards` (used by the Review page to intersect the queue, `ReviewSession.jsx:50-59`) requires an **active** enrollment for own and external cards. Two more screens use the enrollment-blind count: Dashboard `reviewsDue = get_study_queue.length` (`Dashboard.jsx:351-352`), the Progress "due today" tile (`Progress.jsx:205,513`), and the Dashboard Forward Load chart uses `get_due_forecast_buckets` (`Dashboard.jsx:398`).
- **P6-E3 (VERIFIED, RUN 8 and F5).** The normal Remove path already takes a card out of the badge on the next fetch (`remove_from_my_cards` suspends the card). Live snapshot (04/10/2026): 4,138 badge rows across 83 students, 4,079 visible on the Review page, **59 mismatch rows from one student**, all that student's own cards **with no enrollment row at all**; none from `removed` or `course_archived` states. The 59 belong to one account whose platform role is professor (all created 12/2025 and 01/2026, all with a batch id). A wider check (any status, any date) found 103 own reviewed cards without an enrollment row, all `active` (Round 27, finding 9; the thread does not say they all belong to that account). **The cause of the missing enrollment rows is OPEN.**
- **Conclusion (VERIFIED reading, Round 6 and QA):** the Founder-reported "badge stays red" is explained mainly by the **stale client-side badge** (no refetch), not by an enrollment mismatch; the enrollment mismatch is real but small and has a different cause than first assumed.

**Point 7.**
- **P7-E1 (VERIFIED live, RUN 1B).** `get_study_heatmap` (v2) returns one `study_seconds` per date, the sum over all sources, plus `review_count`; no per-source split.
- **P7-E2 (VERIFIED, Round 2 finding 7.2).** Study time appears only in a native `title` (`StudyHeatmap.jsx:41-47,203`); the cells are plain non-focusable `div`s (`:200-206`): no focus, no keyboard, no tap detail. Dates are formatted without `toISOString()` (`:71`); a latent issue: `new Date('YYYY-MM-DD')` parses as UTC (`:91,93,151-152`), harmless in India, an off-by-one risk in negative-UTC time zones.
- **P7-E3 (VERIFIED, RUN 3).** Recorded study time is overwhelmingly offline: `manual` 890 rows, 1,003.3 hours, against in-app `study_mode` 348 rows 25.8 hours and `practice_mode` 157 rows 22.0 hours (about 95 percent of recorded hours are offline). So the split matters.

## 4. Design (PROPOSAL)
### Point 6: one meaning of "due", and a badge that stays correct
- **C-6.1 One definition.** Every "due" number shown to a student (nav badge, Dashboard "Reviews due", Progress "due today", Dashboard Forward Load) counts exactly the cards the Review page would let the student review today: own cards and external cards, each requiring an **active** enrollment, the same course, visibility, question-type and skip rules as `get_study_queue`, and `reviews.status = 'active'`. The definition is stated once in the function, not re-derived in each screen.
- **C-6.2 How (smallest change).** New versions of `get_due_forecast` and `get_due_forecast_buckets` add the enrollment predicate taken from `get_my_cards`; `get_study_queue` is **not** changed (the Review page keeps intersecting it with `get_my_cards`, and the queue is enrollment-blind by design, `ReviewSession.jsx:40-49`, D-41 Area G). The Dashboard "Reviews due" and the Progress tile read the count from the forecast's day-0 bucket (or an equivalent single call) instead of `get_study_queue.length`. Exact bodies, security properties, grants and the rollback are fixed at the SQL stage from the saved RUN 1B bodies; nothing here changes a signature that the frontend has not been prepared for.
- **C-6.3 Refresh.** The badge refetches after: Pause, Resume, Remove and Re-add on My Cards; completing a review (each answered card or at session end, decided at build time to avoid a request per tap); a course switch. One small shared function calls the existing refetch; no polling.
- **C-6.4 The 59 (or 103) own cards without an enrollment row (OPEN, Founder decision).** Under C-6.1 these cards leave the badge (the Review page already hides them). They remain unreviewable until an enrollment exists. Whether to leave them, enroll them by a one-off reviewed data fix, or find the cause first (the SQL path that creates own-card enrollments for batch-created cards) is a separate decision; this brief does not repair data.

### Point 7: an honest, accessible heatmap
- **C-7.1 Data.** A new RPC (name and compatibility decided at the SQL stage; the old one stays until the frontend is verified) returns per date: `review_count`, `in_app_seconds` (`study_mode` plus `practice_mode`), `offline_seconds` (`manual`) and the existing total `study_seconds`; in-app plus offline equals the total. Own rows only.
- **C-7.2 Tooltip.** On hover and on keyboard focus, a concise card: date, in-app time, offline time, total, reviews. Pinned on tap or Enter or Space; closes on Escape, a second tap or focus loss; reachable with the keyboard in reading order; text equivalents for screen readers (an accessible name per cell, not colour alone); respects reduced motion.
- **C-7.3 Dates.** Local-date handling without `toISOString()`; the UTC-parse issue (P7-E2) is removed in the same edit.
- **C-7.4 Not here.** Course and subject in a day-detail view (brief B C4), in-app session classification, professor views (totals only, unchanged).

## 5. Files (inventory only; each later has a ROLLBACK and a real-role TEST)
| File | Kind | Content |
|---|---|---|
| C-01 | `[FUNCTIONS]` | `get_due_forecast` and `get_due_forecast_buckets` with the enrollment-aligned predicate; ROLLBACK restores the saved bodies; TEST: own enrolled, own without enrollment, external removed, paused, archived course, another student's rows, anon refused |
| C-02 | `[FUNCTIONS]` | the new heatmap RPC (in-app, offline, total, reviews); ROLLBACK; TEST: in-app plus offline equals the total, own rows only, the three sources, empty days, anon refused |
| C-03 | frontend | refetch hooks (My Cards actions, review completion, course switch); Dashboard and Progress due counts; heatmap tooltip and pinned detail; accessibility; no `toISOString()` |
Dependencies: C-03 after C-01 and C-02 are deployed (SQL first, then the frontend, then live verification); no dependency on briefs A or B.

## 6. Proof (what "done" means)
1. After Remove, Pause, Resume, Re-add, finishing a review and switching course, the badge changes within one request, without a reload (live check by the Founder).
2. For a sample of students, the badge, the Dashboard "Reviews due", the Progress tile and the Review page's own count agree (a read-only comparison like RUN 8 returns zero mismatches except the open C-6.4 account).
3. The heatmap shows in-app and offline time separately; they add up to the old total for every day (read-only reconciliation); the tooltip opens on hover, focus and tap, and closes on Escape.
4. Automated and manual accessibility checks of the heatmap (keyboard only; a screen reader name for each cell).

## 7. Decisions needed from the Founder
- **D-C1 (recommend yes):** use one meaning of "due" for all four numbers (C-6.1).
- **D-C2 (recommend: find the cause first, no data change yet):** what to do about the own cards without an enrollment row (C-6.4).
- **D-C3 (recommend yes):** the heatmap's offline time is exactly `source = 'manual'`, in-app is `study_mode` and `practice_mode`.

## 8. Out of scope
Course and subject on study logs and Progress by course (brief B), batch groups, admission and access (brief A), 8.8.6, any change to `get_study_queue`, data repair, push to production.
