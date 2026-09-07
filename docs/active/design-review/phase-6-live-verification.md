# Phase 6 — Live Verification Report

**Date:** 07/09/2026
**Environment:** `https://www.revisop.com` (production)
**Commits under test:** `1a94021` (Sprint 6.3) + `7edc31f` (Sprint 6.4), both on `main`
**Viewport:** 390 px mobile emulation (mobile-majority cohort)
**Sessions exercised:** student (TestOutlook), professor (CA Anand More / CA Intermediate), super-admin (Anand)
**Method:** in-app browser driving the live site — DOM + `getComputedStyle` inspection, `performance.getEntriesByType('resource')` for network, a persistent capture for `console.error` / `window.error` / `unhandledrejection` / failed fetches, and ~10 real card grades on the test account (SRS state mutated as expected).

---

## 1. Summary

Phase 6 (Sprint 6.0, the SRS Ladder Epic, and Sprints 6.1–6.4) **passes live verification across all three role sessions.** Every locked design target was confirmed on the live site. No defect found is attributable to any Phase 6 sprint.

Six findings surfaced, all pre-existing or on the one page Phase 6 never migrated (`Progress.jsx`). None block the phase; four route to a short **Sprint 6.5** close-out and two to a Phase 7 infra/perf ticket.

---

## 2. Results by area

### 2.1 Study loop (Sprint 6.4) — PASS

| Check | Evidence |
|---|---|
| Card frame on `r14` | `class="rounded-obj border border-rv-border bg-rv-bg-1 text-rv-ink-900 shadow-rv font-plex …"`; `border-radius` = **14px**; bg `rgb(255,255,255)` = `--rv-bg-1`; border `rgb(226,232,240)` = `--rv-border`; font `IBM Plex Sans`; `rv-forward-in` class present; **no horizontal overflow** (`scrollWidth == clientWidth`) |
| Grade row neutral | 3 buttons, `min-h-[88px]` (rendered 99px) — well above the ≥48px thumb-zone spec. All three **identical**: `border-rv-navy-400` (`rgb(74,69,144)`), `bg-rv-bg-1` (`#fff`), `text-rv-ink-900` (`rgb(10,14,26)`), `border-radius` 14px, `border-[1.5px]`. **Zero red / amber / green** on any option. |
| Computed intervals (client == config) | Observed across 3 cards / 3 rungs: `Hard 1d · Medium 3d · Easy 7d`, `Hard 1d · Medium 1d · Easy 3d`, `Hard 1d · Medium 3d · Easy 7d`. Every value matches the deterministic curve `1 / 3 / 7 / 14 / 30 / 60 / 120 / 240`. **Hard is always `1d`** (relearn step). |
| Interval (client == write) | Graded Easy on a "7d" card → toast **"Progress saved! Next review in 7 days"** (toast text is rendered from the `submit_review` response, so label == RPC response). Raw JSON / `srs_preview` SQL parity not capturable from the browser (`@supabase/supabase-js` holds its own `fetch` reference) — Phase-3 `03_TEST` covered that 30/30. |
| Network discipline | On session mount: `get_study_queue` ×1, `get_srs_ladder_config` ×1. `srs_preview` ×0. **No `get_srs_ladder_config` refetch between cards.** Fonts served same-origin from `revisop.com/fonts/*.woff2`; **zero** `fonts.googleapis.com` / `fonts.gstatic.com`. |
| Post-forward animation | Card class transitions `rv-forward-in` → `rv-forward-out` on grade (captured over 25 ms polls). CSS: `rv-forward-out` = `0.24s cubic-bezier(.4,0,.2,1)` `translateY(-10px) scale(.97)` + fade; `rv-forward-in` = `0.18s` + `0.12s` delay `translateY(8px)→0`. |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` overrides both keyframes to **opacity-only**, `0.1s`, `0ms` delay, linear — exactly the spec. |
| Literata | Never loaded. Checked ~7 flashcard answers (11–149 chars) — all far below the 320-char `LITERATA_MIN_CHARS` threshold, so `document.fonts.check('16px Literata')` stayed `false` and no `literata.woff2` request fired. The CA beta flashcard set contains no reading-body-length answers → zero mobile payload. Correct behaviour; the lazy-load demo is only reachable on `/__design`. |
| Session-complete / "All Caught Up" | Card on white surface + subtle border; clock icon in a **navy-tint** circle (not green); Plex; "Return to Dashboard" navy-filled + "Study New Cards" navy-outline. "Subject Complete! 🎉" toast fires between subjects. |
| Revealed answer | QUESTION / ANSWER chips = `bg-rv-navy-50 text-rv-navy` (navy-tint, **not green**). Progress-strip counters render Check / Minus / X glyphs in neutral ink — no traffic-light colour. |
| No console errors | Zero `console.error` / `window.error` across the entire session (10 grades, 2 subjects, new-card mode, completion states). |

### 2.2 Student dashboard (Sprint 6.3) — PASS

- Section eyebrows uppercase, small, Plex.
- **No `AnonymousStats` / "You vs Class" block** anywhere (gamification parked).
- **"Mastered" tile = 1** — reads `get_mastered_cards` (`reviews.status='mastered'`), sublabel "Items mastered".
- **Forward Ledger macro live** — after a 3-card session the bars read `[0, 2, 0, 1, 0, 0, 0, 0]` = Medium(1d)+Hard(1d) in the 1d lane, Easy(7d) in the 6d lane. Exact match to the grades submitted.
- Dashboard "Reviews / Last 7 days" **==** Progress "Items Reviewed / Last 7 days" **== 10** (sources agree).
- Streak `0 → 1`, Accuracy `0% → 90/100%` after the session (review-completed stats recompute).
- Wordmark two-tone amber `Revis` / navy `Op`, no gradient.

### 2.3 Professor dashboard (Sprint 6.3) — PASS

- Eyebrow computed style: `IBM Plex Sans / 11px / weight 500 / uppercase / 0.77px letter-spacing / rgb(107,114,128)` = `--rv-ink-400` — exact 6.1 `Label` spec.
- Count numerals (`2244`, `1464`, `560`): `IBM Plex Mono`, `font-variant-numeric: tabular-nums` — the `Num` atom.
- **Accuracy by question type:** "Flashcard — 87% · 2244 graded", navy fill bar (`rgb(30,27,75)` = `--rv-navy`) on a `--rv-slate-50` track, footnote "Hit = graded Medium or Easy; Hard = miss. Concept cards excluded."
- **Cohort forward load:** live bars `[1464, 3, 9, 1, 0, 0, 0, 560]` across Today → 6mo+, real cohort data (consistent with the 6.3 thread's `[1465, 1, 7, 0, 0, 0, 0, 560]`, drifted a few days later).
- **"Needs Attention"** renders **unconditionally** ("No flags on your content. All clear!").

### 2.4 Super-admin dashboard (Sprint 6.3) — PASS

- "ADMIN TOOLS" eyebrow: `H2 / IBM Plex Sans / 11px / 500 / uppercase / 0.77px / rgb(107,114,128)` — exact `Label` spec. "SUPER ADMIN TOOLS" rendered in the same style.
- ADMIN TOOLS tiles (Admin Dashboard / Admin Analytics / Manage Topics) + SUPER ADMIN TOOLS tiles (Super Admin Dashboard / SA Analytics).
- **"Elevated" badge:** `bg rgb(254,226,226)` (`red-100`) / `color rgb(185,28,28)` = **#b91c1c** — the sanctioned destructive red, kept as a semantic carve-out.
- **"Needs Review"** renders **unconditionally** ("No pending flags. All clear!").
- Icon chips: `--rv-navy-50` / `--rv-green-50`.
- **Mobile nav sheet:** bg `rgb(255,255,255)`, `font-plex` carried across the portal (the 6.2 fix), role badge `amber-100` bg / `--rv-navy` text, avatar `--rv-navy`, "Sign Out" `red-600` preserved. STUDY / CREATE / GROUPS eyebrows uppercase. **"My Achievements" lives in the drawer** (demoted off the dashboard). Manage/admin section present.
- **Settings `Select` triggers:** `rounded-rec` (4px) / `border border-rv-border` / `bg-transparent` / `font-plex` / `text-rv-ink-900`. (Open-state listbox styles were verified by the 6.3 thread.)

### 2.5 Console-error sweep — PASS

Armed a persistent capture (`console.error`, `console.warn`, `window.error`, `unhandledrejection`, failed fetch), cleared it, then walked:

- study loop — 10 grades, 2 subjects, new-card mode, subject-complete + all-caught-up states
- dashboard ⇄ progress ⇄ notes ⇄ flashcards navigations
- **Browse Notes → click the RevisOp wordmark → `/dashboard`** (the exact path from the earlier bug report)
- `history.back()`

**Result: zero** `console.error` / `window.error` / `unhandledrejection` / failed app fetches. The uncaught `Cannot read properties of undefined (reading 'startTime')` seen earlier **did not reproduce** — it appears to be a one-off timing/bfcache condition, not a reliable defect.

### 2.6 Dev-only route

`/__design` redirects to `/dashboard` in production — correctly `import.meta.env.DEV`-gated, no chunk shipped. (Primitive computed-style checks in dark mode and the Literata lazy-load demo are therefore local-dev-only.)

---

## 3. Findings (ranked) — none are Phase 6 regressions

### Finding 1 — `Progress.jsx` is un-migrated (Medium) → Sprint 6.5

Observed on `/dashboard/progress` (all roles):

1. **"Items Mastered" stat = 28 (professor) / 29 (student)** — contradicts the SSOT (`reviews.status='mastered'` = 1 for the student) **and** the same page's own **"Mastered Items (1)"** list section. The stat tile was never re-pointed when the dashboard "Mastered" tile was in Sprint 6.3.
2. **"Due Items Forecast" tiles use legacy Tailwind** — "Due Today" = `bg rgb(254,242,242)` (`red-50`), `color rgb(220,38,38)` (`red-600`), `border rgb(254,202,202)` (`red-200`); "Next 7/30 Days" = `amber-50 / amber-600 / amber-200`. Not `--rv-*`.
3. **"Due Today" renders red for any count > 0** — professor's `7` shows the red alarm treatment. Student's `0` shows green. Per the Sprint 6.0 note the red alarm should only engage around a genuine backlog (~24), not a normal daily pile.
4. **Stat numerals render in sans**, not the mono `Num` atom.

The *data* on this page is correct — Dashboard ↔ Progress "Items Reviewed" agree, and "Due Items Forecast" already shares the `get_due_forecast` predicate (Sprint 6.0 deviation 4). It is the *presentation* + the *Mastered stat source* that are stale.

### Finding 2 — Leaderboard "Following" tab 400s (Medium) → Sprint 6.5 `[FIX]` → ✅ FIXED, LIVE-VERIFIED & AUDITED FAITHFUL (Task 6.5-D)

`POST …/rpc/get_following_leaderboard` → `400`, Postgres `42702`: `column reference "rank" is ambiguous — could refer to either a PL/pgSQL variable or a table column`. The "Friends" tab works. Pre-existing; no Phase 6 sprint touched any leaderboard RPC. Needs the `rank` reference qualified (or the `RETURNS TABLE` column renamed).

**Sprint 6.5 `[FIX]` (deployed 07/09/2026):** `02_FUNCTIONS` fixes in place — `#variable_conflict use_column` + `DENSE_RANK() … AS rnk` (never `rank`) + every ref table-qualified; RETURNS-TABLE shape / `SECURITY DEFINER` / `STABLE` / `search_path` / `auth.uid()` gate / `authenticated`-only grant all preserved → `LeaderboardWidget.jsx` (`row.rank`) unchanged. `03_TEST` 9/9 PASS. Following tab renders a data row live, no `400`, no `console.error`.

**Task 6.5-D reconstruction audit (07/09/2026 — `docs/database/sprint6.5/04_AUDIT_*`):** the 6.5 thread replaced the *whole* body (01_DIAGNOSTIC's live-body capture was lost before 02 overwrote it) with a reconstruction templated off `get_friends_leaderboard`, so the follow-scope was unverified — `03_TEST` checks the stat math, not the membership set. Audit outcome:
- **Original body unrecoverable from git** (Sprint 3.5 ran the `CREATE` directly in Supabase; no `.sql` ever committed). **Current live body captured via `pg_get_functiondef` → byte-identical to `02_FUNCTIONS`.**
- Diffed against the Sprint 3.5 behavioural contract in `DATABASE_SCHEMA.md` @ `071395d` — **three focus areas all MATCH**: (1) **follow-graph join** `cohort` = `SELECT auth.uid() UNION SELECT f.followee_id FROM public.follows f WHERE f.follower_id = auth.uid()` — directional, no `friendships`, no reciprocal clause (the friends-style mutual join, the primary risk vector, did *not* materialize); (2) **population filter** students-only, no course filter; (3) **result window** `DENSE_RANK` over the full cohort → `WHERE rnk <= 20 OR uid = auth.uid()`, N=20, self always in, exact rank.
- **Live membership set-equality — `04_AUDIT_membership_test.sql` run, 5/5 PASS** on account `f9377860…` (the richest available; live follow graph is sparse — 6 rows, 4 followers, **max 1 followed-student per student**, which also explains this report's original ambiguous "TestOutlook (you)"-only row): RPC `user_id` set == caller ∪ followed-students exactly (no extras, nothing missing), one `is_self`, rank by `reviews_this_week DESC`. The >20 top-N cutoff is unexercised on live data (contract-trivial).

**Verdict: reconstruction is faithful. No `[FIX]` beyond the ambiguity resolution. Finding 2 fully closed.**

### Finding 3 — web-vitals `startTime` TypeError (Low / watch) → Phase 7

`Uncaught TypeError: Cannot read properties of undefined (reading 'startTime')` with `reportAllChanges` / `n.timeout` in the stack (web-vitals signature, likely bundled via Vercel Speed Insights). Seen once on a soft navigation; **did not recur** across the full verification sweep. Instrumentation-level, not application code.

### Finding 4 — Console debug spam (Low) → Phase 7

`⏰ Timezone already set: Asia/Calcutta` logs **77+ times per page**. Harmless but noisy; should be gated or removed.

### Finding 5 — Nav / notification over-fetch (Low) → Phase 7

On a single `/dashboard/notes` load: `profiles` queried **46×**; `get_recent_notifications`, `friendships`, `role_permissions`, `get_unread_notification_count` each **12×**. Pre-existing; wasteful on the Supabase Free plan.

### Finding 6 — `400` on every authenticated page (Low) → Phase 7

2× `Failed to load resource: 400` on essentially every authed page (nav/notification RPC family — the "4× 401" flagged in the Sprint 6.3 report, now presenting as 400).

---

## 4. Verdict

**Phase 6 — Sprint 6.0, the SRS Ladder Epic, and Sprints 6.1–6.4 — passes live verification on `revisop.com` across student, professor, and super-admin sessions.**

Confirmed live: the additive `--rv-*` token layer, self-hosted IBM Plex (Sans + Mono), the two-tone `<Wordmark />`, reskinned nav chrome + overlay atoms, dashboards with a live Forward Ledger macro and educator accuracy-by-question-type, gamification parked (AnonymousStats removed, achievements demoted to the drawer), and the study loop on the `r14` unified frame with a neutral navy-outline grade row showing engine-computed ladder intervals, the post-forward animation, a reduced-motion fallback, and zero per-card preview network cost.

No regression attributable to any Phase 6 sprint. Settled always-visible cards ("Needs Attention", "Needs Review") render unconditionally on the reskin.

**Recommended before full close:** Sprint 6.5 — verification fixes (Findings 1 & 2). Findings 3–6 → Phase 7 infra/perf ticket.

**Update (07/09/2026):** Sprint 6.5 shipped — Findings 1 & 2 cleared and live-verified per-role. **Finding 2 additionally passed the Task 6.5-D reconstruction audit** (see above): the `02_FUNCTIONS` body that replaced the lost original is confirmed faithful — live body byte-identical to the reviewed reconstruction, three focus areas match the Sprint 3.5 contract, live membership set-equality 5/5 PASS. No further fix. Findings 3–6 remain open → Phase 7.
