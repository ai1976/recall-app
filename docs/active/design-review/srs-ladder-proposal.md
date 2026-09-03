# SRS Ladder Epic — Phase 0 Proposal

**Status:** DRAFT — awaiting (1) diagnostic numbers from `docs/database/srs-ladder/00_DIAGNOSTIC_srs_ladder_phase0.sql` and (2) phasebuilder approval. No engine SQL, config table, or migration is written until this proposal is approved.
**Author:** Claude Code
**Date:** 03/09/2026
**Scope:** deliver the deterministic expanding-ladder engine + a server-side preview function. Grade-button reskin and prominent interval UI are **Sprint 6.4**, not this epic.

---

## 0. TL;DR — the four decisions + the forecast pick

| Decision | Recommendation |
|---|---|
| **Rung table** | 8 rungs, index 0–7, intervals **1 / 3 / 7 / 14 / 30 / 60 / 120 / 240** days. First three rungs deliberately equal today's Hard/Medium/Easy constants (1/3/7) so migration and "no sudden change" are trivial. |
| **Transition rules** | **Easy** → advance +1 rung (cap at 7). **Medium** → **hold** at current rung (re-schedule same interval). **Hard** → **full drop to rung 0** + relearning step `next_review_date = today + 1` (exactly preserves today's "Hard = 1 day"). New card's first grade enters at rung **0 / 1 / 2** for Hard / Medium / Easy respectively (exactly reproduces today's new-card behaviour). |
| **MASTERED** | Threshold = **a successful (Easy) review while already at rung 7**. Mechanism = **new `status = 'mastered'`** value (CHECK `active`→`active,suspended,mastered`). `get_study_queue` filter is already `status = 'active'` → **exclusion is a no-op**. Un-mastering only via an explicit manual review from the Mastered list / Library (never silent); `submit_review` flips `status` back to `'active'`, keeps rung 7. |
| **Migration mapping** | `rung = LEAST(repetition, 7)`, **hardened by easiness**: if `easiness <= 2.35` (last grade was Hard) then `rung = LEAST(repetition, 3)`. **`next_review_date` is NOT recomputed** — only the new `rung` column is backfilled. The ladder engages on each card's next real `submit_review`. A backfilled rung of 7 does **not** auto-master. |
| **Progress "Due Items Forecast"** (6.0 deviation 4 / bugs.md OPEN) | **Option (a)** — rewrite the body of the **existing** `get_due_forecast(p_user_id)` RPC to share the exact `get_study_queue` due predicate (course filter, visibility guard, concept-card exclusion, user-tz "today", `skip_until <= today`). Keep its current 3-bucket signature (`due_today`, `due_next_7`, `due_next_30`) — `Progress.jsx` already consumes that shape, so **zero frontend change**. `due_next_7/30` legitimately stay forward-looking. Closes the bug. |

**Parameters that are provisional until the diagnostics land:** the easiness governor threshold (Q4/Q4b), the migration batch size (Q5), whether `'mastered'` is safe to add (Q1/Q2), and confirmation that `next_review_date` is `DATE` (Q6). Everything else is structural and does not depend on the numbers.

---

## 1. Phase 0 measured numbers

> Fill from `00_DIAGNOSTIC_srs_ladder_phase0.sql`. **Left blank until the founder runs it in the Supabase SQL Editor.**

### 1.1 `reviews.status` distinct values (Q1)

| status | rows |
|---|---|
| _TBD_ | _TBD_ |

- `'mastered'` currently present? **_TBD (must be NO to proceed with the status-value design)_**

### 1.2 `reviews.status` CHECK constraint (Q2)

```
_TBD — paste pg_get_constraintdef output_
```

### 1.3 `reviews.repetition` histogram (Q3 / Q3b)

| repetition | rows | pct |
|---|---|---|
| _TBD_ | | |

- Rows that would land on rung 7 under a naive `LEAST(repetition,7)` map: **_TBD_**

### 1.4 `reviews.easiness` distribution (Q4 / Q4b)

| easiness | rows |
|---|---|
| _TBD_ | |

- High-repetition (`>=7`) **and** low-easiness (`<=2.35`) rows — the ones the easiness governor protects from a false near-MASTERED landing: **_TBD_**

### 1.5 `reviews` volume + size (Q5)

| metric | value |
|---|---|
| total review rows | _TBD_ |
| table total size | _TBD_ |
| indexes size | _TBD_ |

**Backfill cost assessment (to confirm against the number):** the Phase 2 backfill is an in-place `UPDATE reviews SET rung = …` of a single `smallint` column. It generates **no client egress** (egress = bytes leaving the DB to API clients; this is a server-internal write). Free-plan exposure is DB size (500 MB cap) and disk-IO budget — a smallint column across the measured row count adds well under 1 MB and a few seconds of IO. The 2026 image-migration quota incident was a *read*-heavy 110 MB base64 pull; this is not comparable. **Recommended batch size: 2,000 rows per statement, keyed by `id`, `WHERE rung IS NULL`** (resumable) — but a single statement is acceptable if total rows < ~20,000. Final call after Q5.

### 1.6 Course value inventory + drift (Q8 / Q9 / Q10 / Q10b)

- `profiles.course_level` distinct values: **_TBD_**
- `flashcards.target_course` distinct values: **_TBD_**
- Active reviews with `target_course <> course_level` (drift): **_TBD_** across **_TBD_** students
- Most common mismatched pairs: **_TBD_** (this reveals the normalization map, e.g. `CA Inter` ↔ `CA Intermediate`)

### 1.7 `question_type` coverage (Q11)

| question_type | cards |
|---|---|
| _TBD_ | |

Every value here except `concept_card` must resolve to a curve (all fall through to `_default` for now).

### 1.8 `next_review_date` type + uniqueness (Q6 / Q7)

- `reviews.next_review_date` data_type: **_TBD_** (expected `date`)
- Duplicate `(user_id, flashcard_id)` rows: **_TBD_** (expected 0 — one row per user per card)

### 1.9 Per-student due-count baseline (Q12)

> Snapshot table pasted here becomes the Phase 2 "before" side of the migration-safety check.

---

## 2. Current grade-write path (read from code, 03/09/2026)

### 2.1 The single write path: `StudyMode.jsx` → `handleRating(quality)`

`src/pages/dashboard/Study/StudyMode.jsx` lines **244–356**. This one function serves **both** required paths:

- **Review-session grade path** — `ReviewSession.jsx` fetches the due queue via `get_study_queue`, groups by subject, and renders `<StudyMode flashcards={activeSessionCards} onComplete=… onExit=… />` (`ReviewSession.jsx:162`). `ReviewSession.jsx` itself **never writes `reviews`** — it only reads. All grading goes through `StudyMode.handleRating`.
- **New-card first-grade path** — `StudyMode` standalone (subject/topic/deck study). `fetchFlashcards` (`StudyMode.jsx:135`) unions "due" (from `get_study_queue`) with "never-reviewed" cards; grading the never-reviewed ones also calls `handleRating`, which hits the `INSERT` branch below.

**Grep confirms** `StudyMode.jsx` is the only frontend writer to `reviews` (lines 287 SELECT, 297 UPDATE, 314 INSERT). `Progress.jsx`, `Dashboard.jsx`, `ReviewBySubject.jsx`, `SuperAdminDashboard.jsx` all only read. Card-scheduling mutations (`skip_card` / `suspend_card` / `reset_card` / `unsuspend_card` / `skip_topic_cards` / `suspend_topic_cards`) are already server-side RPCs.

### 2.2 Exactly what `handleRating` writes today

Client-side constants (`StudyMode.jsx:261–273`):

| button | `intervalDays` | `quality` | `easiness` (written every time) |
|---|---|---|---|
| Easy | 7 | 5 | 2.6 |
| Medium | 3 | 3 | 2.5 |
| Hard | 1 | 1 | 2.3 |

`nextDate` = local `today + intervalDays`, formatted `YYYY-MM-DD` from local Y/M/D (lines 276–283).

Then **explicit SELECT → UPDATE / INSERT** (no upsert), keyed by `(user_id, flashcard_id)`:

**UPDATE branch** (`:297`) sets: `quality`, `interval = intervalDays`, `repetition = (existing.repetition || 0) + 1`, `easiness`, `next_review_date = dateString`, `last_reviewed_at = now()ISO`, `status = 'active'`, `skip_until = null`.

**INSERT branch** (`:314`) sets: `user_id`, `flashcard_id`, `quality`, `interval = intervalDays`, `repetition = 1`, `easiness`, `next_review_date = dateString`, `last_reviewed_at = now()ISO`, `status = 'active'`.

**Notes carried into the design:**
- `repetition` is incremented on *every* grade today, **including Hard** — so a struggling card can have a high `repetition` with low `easiness`. This is why the migration mapping needs the easiness governor.
- `interval` is written but only ever read back cosmetically. The ladder makes `rung` authoritative; `interval` can keep being written (= the rung's interval) for backward-compat / debugging.
- Hard-coded button sublabels: `"Review in 1 day"` / `"Review in 3 days"` / `"Review in 7 days"` (`:1061`, `:1069`, `:1079`). Phase 3 replaces these with locally-computed values; Sprint 6.4 restyles them.
- The `+7` / `+3` / `+1` constants live **only** in `StudyMode.jsx`. `ReviewSession.jsx` has none (it delegates). The acceptance criterion "constants gone from `StudyMode.jsx` and `ReviewSession.jsx`" is satisfied by editing `StudyMode.jsx` alone; `ReviewSession.jsx` is already clean.

---

## 3. The ladder algorithm

### 3.1 Rungs

| rung | interval (days) | notes |
|---|---|---|
| 0 | 1 | = today's Hard |
| 1 | 3 | = today's Medium |
| 2 | 7 | = today's Easy |
| 3 | 14 | |
| 4 | 30 | |
| 5 | 60 | |
| 6 | 120 | |
| 7 | 240 | top rung; MASTERED candidate |

Deterministic: `next_review_date = today(user tz) + interval_days(resolved_rung)`. No easiness-scaled interval, no randomness. `easiness` stays on the row (written by `submit_review` for continuity / analytics) but **does not affect the interval**.

### 3.2 Transitions

Let `R` = current rung (new card: `R` undefined).

| grade | new card (first ever review) | existing card at rung `R` |
|---|---|---|
| **Hard** | rung **0**, `next_review_date = today + 1` | rung **0**, `next_review_date = today + 1` (relearning step) |
| **Medium** | rung **1**, `next_review_date = today + 3` | **hold**: rung `R`, `next_review_date = today + interval(R)` |
| **Easy** | rung **2**, `next_review_date = today + 7` | rung **min(R+1, 7)**, `next_review_date = today + interval(min(R+1,7))`; if `R == 7` → MASTERED (see 3.3) |

- **Why "hold" for Medium** — it is the meaningful middle: "recalled, but with effort". Advancing it collapses Medium into Easy; dropping it punishes a correct answer. Holding re-tests at the same spacing.
- **Why "full drop" for Hard** — matches the classic SRS lapse→relearn, exactly preserves the current "Hard = review tomorrow", and is trivial to explain to students. A struggling card then oscillates rung 0↔1↔2, which is the correct signal that it is not yet learned.
- **Considered alternative for Hard:** drop to `max(R-2, 0)` (a 2-rung penalty, keeping some history for a card that lapsed once at rung 6). Rejected for the first cut: harder to explain, harder to migrate cleanly, and the relearning step already brings the card back tomorrow regardless. The phasebuilder can override to the 2-rung form — it is a one-line change in `submit_review` and the rules row.

### 3.3 MASTERED

- **Enter:** an **Easy** grade on a card already at **rung 7**. (Medium at rung 7 = hold at 7. Hard at rung 7 = full drop like any lapse.) Optionally require *N* such successes — recommend **N = 1** for the first cut; `master_threshold` is a rules-row value so it can be raised without a code change.
- **Represent:** `reviews.status = 'mastered'` (rung stays 7). Chosen over a separate boolean column because `get_study_queue` **already** filters `status = 'active'`, so mastered cards leave the daily pipeline with **no change to the queue RPC** (epic context §3: "ideally a no-op").
- **Still visible:** the Mastered list (Phase 3), Library / Browse, Subject Mastery. Never silently vanishes.
- **Un-master:** only by an explicit manual review of that card (from the Mastered list or Library). `submit_review` on a `status='mastered'` row flips it back to `'active'`, keeps rung 7, and schedules per the normal rung-7 transition (Easy → 240 d, Medium → hold 240 d, Hard → drop to 0). No automatic un-mastering, ever.
- **Metrics:** `Progress.jsx` "Items Mastered" currently counts *distinct active-review flashcard_ids* (i.e. "cards started" — a placeholder). After this epic it can mean the real thing: `COUNT(*) WHERE status = 'mastered'`. Flagged for Phase 3 / 6.4, not required by the engine.

### 3.4 Per-`question_type` config

**Config table (curves):**

```sql
CREATE TABLE public.srs_ladder_curves (
  question_type text    NOT NULL,      -- real type, or '_default'
  rung_index    smallint NOT NULL CHECK (rung_index >= 0 AND rung_index <= 20),
  interval_days integer  NOT NULL CHECK (interval_days >= 1),
  PRIMARY KEY (question_type, rung_index)
);
```

Seed **only** `question_type = '_default'` with the 8 rows from 3.1. Resolution in `submit_review` / `srs_preview` / the client: **the card's `question_type` curve if present, else `_default`**. Every current type (`flashcard`, `mcq`, `true_false`, `short_answer`, `theory`, `fill_blank`, `match`, `case_study`, `correct_incorrect`) uses `_default`. `concept_card` is excluded from review entirely, so it needs no row. The language-learning future adds rows under its own `question_type` values without touching code.

**Transition rules (single source, shared by client + server):**

```sql
CREATE TABLE public.srs_ladder_rules (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),   -- single row
  rules jsonb NOT NULL
);
-- seed:
-- {
--   "top_rung": 7,
--   "new_card_rung":   { "hard": 0, "medium": 1, "easy": 2 },
--   "advance":         { "hard": "reset", "medium": "hold", "easy": 1 },
--   "relearn_step_days": 1,
--   "master_threshold": 1
-- }
```

`submit_review`, `srs_preview`, and `get_srs_ladder_config()` all read **this same row**. The client never hard-codes any of these numbers — it receives them from `get_srs_ladder_config()` and computes previews from them. One definition, three readers → client and server logic **cannot drift** (the drift-parity test in §6 proves it every build).

---

## 4. Schema + engine (Phase 1 — for reference; built only after approval)

| object | shape | grants |
|---|---|---|
| `reviews.rung` | `smallint NULL`, `CHECK (rung IS NULL OR (rung BETWEEN 0 AND 20))`. `NULL` = not yet on the ladder. **No SRS state on `flashcards`.** | — |
| `reviews_status_check` | `ALTER` → `CHECK (status IN ('active','suspended','mastered'))` (exact superset of Q2 output) | — |
| `srs_ladder_curves` | table above; seed `_default` × 8 | `SELECT` via RPC only; no direct grant |
| `srs_ladder_rules` | single-row jsonb table above | `SELECT` via RPC only |
| `get_srs_ladder_config()` | `RETURNS jsonb` = `{ "curves": [...], "rules": {...} }`. `STABLE`, `SECURITY DEFINER`, `SET search_path TO public, extensions`. | `REVOKE … FROM public, anon; GRANT EXECUTE TO authenticated` |
| `srs_preview(p_rung int, p_question_type text DEFAULT NULL)` | `RETURNS TABLE(rating text, resulting_rung int, interval_days int)` — 3 rows (hard/medium/easy) using the §3.2 rules + §3.4 curve resolution. Pure/`STABLE`, no writes, not user-scoped. The Sprint 6.4 read surface + the drift-parity test target. **Not called in the study loop.** | `REVOKE … FROM public, anon; GRANT EXECUTE TO authenticated` |
| `submit_review(p_review_id uuid, p_rating text, p_question_type text DEFAULT NULL)` | `SECURITY DEFINER`, `SET search_path TO public, extensions`. **IDOR guard verbatim from the L5 idiom** (`security/08`, `get_study_queue`): the review row's `user_id` must equal `auth.uid()` (admins exempt via `public.is_admin()`); a row not owned by the caller **RAISEs**; a `NULL` session **RAISEs**. Computes the rung transition, writes `rung`, `repetition`, `easiness`, `interval`, `quality`, `next_review_date` (kept `DATE`), `last_reviewed_at`, `status` (applies `'mastered'` at threshold; flips `'mastered'`→`'active'` on manual re-review), `skip_until = NULL`. Returns the resulting `{ rung, next_review_date, status }`. | `REVOKE … FROM public, anon; GRANT EXECUTE TO authenticated` |
| `get_study_queue` | **additive only:** add `rung` (and it already returns `status` implicitly via the `status='active'` filter) to the `RETURNS TABLE` so the client preview has the current rung with no extra call. MASTERED exclusion = no-op (filter is already `status='active'`). Row-mapping in `ReviewSession.jsx` is by field name → additive column is safe. | unchanged |
| `get_due_forecast(p_user_id uuid)` | **body rewrite, signature unchanged.** `due_today` adopts the exact `get_study_queue` predicate (user-tz today, `status='active'`, `next_review_date <= today`, `skip_until` null/≤today, `question_type <> 'concept_card'`, course filter, L2 visibility guard). `due_next_7` / `due_next_30` = same filters, `next_review_date <= today + N`. IDOR guard already present (`security/08`). | unchanged |

New / replaced functions → `NOTIFY pgrst, 'reload schema'`. `search_path` **unquoted** (`SET search_path TO public, extensions`) per the L3 17c outage lesson. Every Phase 1 test wrapped `BEGIN … ROLLBACK` **in its own editor run**, never mixed with persistent DDL.

---

## 5. Migration (Phase 2 — for reference; built only after approval)

- **Backfill:** `UPDATE reviews SET rung = CASE WHEN easiness <= 2.35 THEN LEAST(repetition, 3) ELSE LEAST(repetition, 7) END WHERE rung IS NULL;` (the `2.35` governor threshold to be confirmed against Q4/Q4b — it may become `2.4`, or a repetition-only cap if the cross-tab shows the governor is unnecessary).
- **`next_review_date` is never touched.** No card's due date moves. A backfilled `rung = 7` does **not** master the card — mastering requires a successful `submit_review` at rung 7.
- **Batch:** per Q5 — `id`-keyed batches of 2,000 with `WHERE rung IS NULL`, or one statement if < ~20k rows. Report rows processed + wall-clock.
- **Reversibility:** documented in the migration file — `UPDATE reviews SET rung = NULL;` (or `ALTER TABLE reviews DROP COLUMN rung;`) fully reverts; nothing else changed, so schedules are already intact.
- **Verification before "done":**
  1. For ≥10 active students (the Q12 sample + 5 more), capture `get_study_queue(uid)` count **immediately before and immediately after** the backfill — must be materially unchanged.
  2. Diff `next_review_date` for a sample of ≥50 rows before/after — must be byte-identical.
  3. Paste the before/after table into this doc and `now.md`.

---

## 6. Interval preview strategy (Phase 3 — no per-card network cost)

1. On `StudyMode` mount (once per session): `supabase.rpc('get_srs_ladder_config')` → `{ curves, rules }`. Store in React state (or a small `SrsLadderContext` if `ReviewSession` needs it too). One call, ~10 small rows + one jsonb.
2. Per card: read the card's `rung` from the `get_study_queue` row (or `null` for a never-reviewed card). Compute each button's interval **locally** from `curves` + `rules`:
   - Easy → `interval_days` at `min(rung+1, top_rung)` (or `new_card_rung.easy` if `rung == null`)
   - Medium → `interval_days` at `rung` (or `new_card_rung.medium`)
   - Hard → `relearn_step_days` (= 1) (or `new_card_rung.hard`'s interval — both are 1)
3. **Zero** preview/config fetches between cards. `submit_review` is the authoritative enforcer on click; `srs_preview` is its server-side mirror for tests/6.4, **never called in the loop**.
4. **Safe read path:** the `get_srs_ladder_config()` RPC (`GRANT EXECUTE TO authenticated`). Chosen over a direct `SELECT` policy on `srs_ladder_curves` — an RPC keeps the "no new RLS surface, pipeline logic in IDOR-guarded RPCs" pattern (epic context §7) and bundles curves + rules in one round-trip.
5. **Anti-drift:** `get_srs_ladder_config().rules` **is** the `srs_ladder_rules` row that `submit_review` and `srs_preview` read. The §6 acceptance test asserts client-computed preview == `srs_preview` == the value `submit_review` writes, for a ≥3 rung × {Hard,Medium,Easy} matrix.

---

## 7. Course-drift finding (measure only — separate follow-up)

Q10 quantifies it. **Not fixed in this epic.** Proposed follow-up (its own `[DATA]` + `[SCHEMA]` slice):
- `[DATA]` one-time `UPDATE profiles`/`flashcards` mapping the drift pairs Q10b reveals (e.g. `'CA Inter'` → `'CA Intermediate'`), founder-reviewed pair list.
- `[SCHEMA]` optional: a soft FK / trigger check of `course_level` and `target_course` against `disciplines.name` to stop future free-text drift.
- Logged **OPEN** in `bugs.md` with the Q10 number and this plan.

---

## 8. `srs_preview` contract (server-side mirror)

```
srs_preview(p_rung int, p_question_type text DEFAULT NULL)
  RETURNS TABLE (rating text, resulting_rung int, interval_days int)
```

- Input: a rung (0–7, or `NULL` for a never-reviewed card) + optional `question_type`.
- Output: exactly 3 rows — `('hard', …)`, `('medium', …)`, `('easy', …)` — the rung and interval each button would produce, computed from the **same** `srs_ladder_rules` + `srs_ladder_curves` resolution as `submit_review`.
- `STABLE`, no writes, no identity check needed (not user-scoped), `GRANT EXECUTE TO authenticated`.
- Consumers: Sprint 6.4 (button interval text server-side), the §6 drift-parity test. **The study loop never calls it.**

---

## 9. Out of scope / parked

| item | where it goes |
|---|---|
| Exam-date anchor for interval capping | Phase 7+ (needs an exam-date field not yet captured) |
| Grade-button restyle + prominent interval-preview UI | Sprint 6.4 |
| Course-value normalization | separate follow-up (§7); Phase 0 measures only |
| Token / font / wordmark / reskin | Sprint 6.1+ |
| New question types + their curves | Phase 7 |
| `Progress.jsx` "Items Mastered" → real `status='mastered'` count | Phase 3 / 6.4 polish, not engine-critical |

---

## 10. Deployment order (non-negotiable)

```
Phase 1 SQL ([SCHEMA]/[FUNCTIONS] headers) → deploy + confirm in Supabase → run Phase 1 tests
  → Phase 2 migration deploy + due-count stability check
    → Phase 3 frontend push (only after 1–2 confirmed live)
      → verify on https://www.recallapp.co.in
```

If any phase's SQL cannot be deployed during the sprint, hold all downstream frontend and report the epic **blocked at that phase**.

---

## 11. Open questions for the phasebuilder

1. **Hard drop depth** — full reset to rung 0 (recommended) vs `max(R-2,0)` 2-rung penalty?
2. **`master_threshold`** — 1 success at rung 7 (recommended) vs 2?
3. **Medium at rung 7** — hold at 7 (recommended) vs also count toward mastery?
4. **`get_due_forecast`** — confirm option (a) (rewrite body, keep signature) vs (b) (keep separate, document why)?
5. **`get_srs_ladder_config()` grant** — `authenticated` only (recommended) vs also `anon` (would let the landing-page hero demo show real intervals)?
