# SRS Ladder Epic — Phase 0 Proposal

**Status:** DRAFT — diagnostics landed 03/09/2026 (§1 filled). Awaiting phasebuilder approval. No engine SQL, config table, or migration is written until this proposal is approved.
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
| **Migration mapping** | **`rung = CASE WHEN easiness <= 2.35 THEN LEAST(repetition, 2) ELSE LEAST(repetition, 4) END`.** Nobody enters above rung 4 (30 d) — the ladder must *earn* the 60/120/240-day rungs through real post-migration reviews; cards whose last grade was Hard re-enter at rung 2 (7 d) max. **`next_review_date` is NOT recomputed** — only the new `rung` column is backfilled. The ladder engages on each card's next real `submit_review`. No card is mastered at migration. Single `UPDATE` (7,824 rows / 2.7 MB — no batching). |
| **Progress "Due Items Forecast"** (6.0 deviation 4 / bugs.md OPEN) | **Option (a)** — rewrite the body of the **existing** `get_due_forecast(p_user_id)` RPC to share the exact `get_study_queue` due predicate (course filter, visibility guard, concept-card exclusion, user-tz "today", `skip_until <= today`). Keep its current 3-bucket signature (`due_today`, `due_next_7`, `due_next_30`) — `Progress.jsx` already consumes that shape, so **zero frontend change**. `due_next_7/30` legitimately stay forward-looking. Closes the bug. **Expected visible effect:** ~25 CA-Intermediate students see "Due Today" drop (their CA-Foundation review rows get course-filtered), matching what their Review Session already shows — worth a release note. |

**Deviations from the brief's stated starting points (all data-driven, see §1):**
- Migration cap is **rung 4 / rung 2** (not `LEAST(repetition, 7)`). Q3 + Q4b show 424 rows would land on rung 7 and 164 heavily-reviewed-but-last-failed cards would land on rungs 4–7 under a naive map — exactly the "near-MASTERED" hazard the brief asks the cap to prevent.
- Migration is a **single statement, not batched** — Q5: 7,824 rows / 2.7 MB total. Batching would be theatre.
- Course-value **normalization is dropped** (§7): Q8/Q9 show clean exact-match values with **zero spelling variants**. The "drift" is 1,648 legitimate cross-level review rows, an accepted 6.0 course-filter consequence, not a data-quality bug.

---

## 1. Phase 0 measured numbers (03/09/2026)

### 1.1 `reviews.status` distinct values (Q1)

| status | rows |
|---|---|
| active | 7122 |
| suspended | 702 |

- `'mastered'` currently present? **NO** → safe to add as a new `status` value. ✅

### 1.2 `reviews.status` CHECK constraint (Q2)

```
reviews_status_check  CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])))
reviews_quality_check CHECK (((quality >= 0) AND (quality <= 5)))
```

Phase 1 `ALTER`: drop + recreate `reviews_status_check` as `CHECK (status = ANY (ARRAY['active','suspended','mastered']))`. `reviews_quality_check` is untouched (our qualities are 1/3/5).

### 1.3 `reviews.repetition` histogram (Q3 / Q3b)

| repetition | rows | pct |
|---|---|---|
| 0 | 856 | 10.9 |
| 1 | 3065 | 39.2 |
| 2 | 1650 | 21.1 |
| 3 | 838 | 10.7 |
| 4 | 486 | 6.2 |
| 5 | 329 | 4.2 |
| 6 | 176 | 2.2 |
| 7 | 97 | 1.2 |
| 8+ | 327 | 4.2 (tail out to repetition = 33) |

- Rows that would land on rung 7 under a naive `LEAST(repetition,7)` map: **424** (97 + 327). → the migration caps at rung 4 instead (see §0 deviations).
- `repetition = 1` is 39% of the table because the current INSERT seeds `repetition = 1` on the first grade; it means "graded once".

### 1.4 `reviews.easiness` distribution (Q4 / Q4b)

| easiness | rows | = last grade |
|---|---|---|
| 2.30 | 771 | Hard |
| 2.50 | 2162 | Medium |
| 2.60 | 4891 | Easy |

`easiness` holds **exactly 3 discrete values** — it is a faithful "last grade" flag, so it is a reliable governor input.

- Heavily-reviewed (`repetition >= 4`) **and** last-graded-Hard (`easiness <= 2.35`) rows — the false-near-MASTERED hazard the cap removes: **164** (rep4:56 + rep5:32 + rep6:14 + rep7+:62). Under the migration map these land at **rung 2** (7 d), not rungs 4–7.
- Last-graded-Hard at `repetition` 1–3: another 421 + 129 + 57 = 607 rows, also capped at rung 2.

### 1.5 `reviews` volume + size (Q5)

| metric | value |
|---|---|
| total review rows | **7824** |
| table total size | 2768 kB |
| heap size | 1112 kB |
| indexes size | 1616 kB |

**Backfill cost:** negligible. 7,824 rows, in-place `UPDATE` of one `smallint` column → **single statement**, sub-second, **zero client egress** (server-internal write), well under any Free-plan size/IO concern. No batching, no resumable-chunk scaffolding. (The 2026 image-migration quota incident was a *read*-heavy 110 MB base64 pull — not comparable.)

### 1.6 Course value inventory + "drift" (Q8 / Q9 / Q10 / Q10b)

- `profiles.course_level`: **CA Foundation 98, CA Intermediate 53, CA Final 22**, NULL 2, plus 5 one-off free-text values (one user each: `Technical Analysis`, `Class 9. CBSE`, `AI and Data science`, `MBA`, `SSC CGL`).
- `flashcards.target_course`: **CA Intermediate 1736, CA Foundation 419** — only two values, both clean.
- **No spelling variants anywhere** (`CA Inter` vs `CA Intermediate` etc. do not occur). The originally-feared normalization problem does not exist.
- Q10: 1659 active reviews across 25 students, 256 cards, where `target_course <> course_level`. Q10b: **1648 of those are CA-Intermediate students with review history on CA-Foundation cards** (legitimate cross-level revision), + 11 stragglers.
- **Interpretation:** this is not data drift — it is the Sprint 6.0 read-time course filter working as designed (a CA-Inter student's queue excludes CA-Foundation cards; Custom Course is the accepted escape hatch, per the 6.0 auditor). It is also the mechanism behind the Progress "24 vs 4" forecast discrepancy. Aligning `get_due_forecast` (§0, option a) will make Progress agree with the queue for these 25 students. **No normalization slice needed** — logged informational in `bugs.md`, not OPEN.
- Side note: the 5 one-off `course_level` users have no matching `target_course` cards → their `get_study_queue` is always empty today. Pre-existing 6.0 consequence, out of scope here.

### 1.7 `question_type` coverage (Q11)

| question_type | cards |
|---|---|
| flashcard | 2155 |

**Only one type exists.** `srs_ladder_curves` seeds just `_default` × 8; every card resolves to `_default`. No `concept_card` rows exist yet (the `get_study_queue` exclusion is a correct no-op). New types + curves are Phase 7.

### 1.8 `next_review_date` type + uniqueness (Q6 / Q7)

- `reviews.next_review_date` = **`date`** ✅ (confirms blueprint §185; **DATABASE_SCHEMA.md §298 "timestamp" is stale — fix in the Phase 1 doc-sync**). `skip_until` = `date`. `interval` nullable default 0. `easiness` = `double precision` nullable default 2.5. `status` NOT NULL default `'active'`.
- Q7 output came back as the column list again (query mis-run). One-row-per-`(user_id, flashcard_id)` is taken as confirmed from the documented `reviews_user_flashcard_unique` constraint + `handleRating`'s `.maybeSingle()` dependence. **Optional belt-and-braces: re-run the Q7 dup-check** before Phase 2.

### 1.9 Per-student due-count baseline (Q12)

Captured — 15 heaviest students, `due_today_raw` 137–410 (server-date, **no** course/visibility filter, so higher than `get_study_queue` for the CA-Inter students). This is the Phase 2 "before" snapshot; the Phase 2 script re-runs it **plus** an inline replica of the `get_study_queue` predicate per student, before and after the backfill — both must be materially unchanged.

| full_name | course_level | due_today_raw | active_rows_total |
|---|---|---|---|
| Chinmay Pansare | CA Intermediate | 410 | 445 |
| Aryan Pamnani | CA Intermediate | 301 | 314 |
| Mohak Agrawal | CA Intermediate | 223 | 223 |
| Jayesh Pande | CA Intermediate | 210 | 210 |
| Avanti Soman | CA Intermediate | 206 | 315 |
| Shashwat Amit Randive | CA Intermediate | 204 | 211 |
| Shreyas Dhaygude | CA Intermediate | 179 | 179 |
| Aayodh Inamke | CA Foundation | 174 | 174 |
| Mitesh Aher | CA Intermediate | 161 | 296 |
| Aryan Pargaonkar | CA Intermediate | 161 | 188 |
| Chaitanya Bhide | CA Foundation | 160 | 160 |
| arjun sathe | CA Foundation | 152 | 152 |
| Chinmay Bhave | CA Intermediate | 148 | 148 |
| Ananya | CA Foundation | 146 | 146 |
| Shardul Karnik | CA Intermediate | 137 | 137 |

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

- **Backfill (single statement):**
  ```sql
  UPDATE reviews
  SET rung = CASE WHEN easiness <= 2.35 THEN LEAST(repetition, 2)
                  ELSE LEAST(repetition, 4) END
  WHERE rung IS NULL;
  ```
  `easiness <= 2.35` catches exactly the `easiness = 2.30` (last = Hard) rows (Q4 confirms only 3 discrete values). Cap 4 = 30 d max on entry for everyone; cap 2 = 7 d max for last-failed cards. Nobody enters rungs 5–7; nobody is near MASTERED. Expected post-backfill rung spread (from Q3, before the low-easiness re-cap): rung 0 ≈ 856, rung 1 ≈ 3065, rung 2 ≈ 1650 (+ ~600 pulled down by the governor), rung 3 ≈ 838, rung 4 ≈ ~1000 (486 + the 5–33 tail collapsed in). Exact numbers reported at deploy.
- **`next_review_date` is never touched.** No card's due date moves. No card is mastered.
- **Batch:** none — Q5 is 7,824 rows / 2.7 MB. One `UPDATE`, `WHERE rung IS NULL`. Report rows processed + wall-clock.
- **Reversibility:** documented in the migration file — `UPDATE reviews SET rung = NULL;` (or `ALTER TABLE reviews DROP COLUMN rung;`) fully reverts; nothing else changed, so schedules are already intact.
- **Verification before "done":**
  1. For the Q12 15 students + 5 more, capture **(a)** `due_today_raw` (the Q12 query) and **(b)** an inline replica of the `get_study_queue` due predicate (status/date/skip + course + visibility + concept) **immediately before and immediately after** the backfill — both must be materially unchanged.
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

## 7. Course-"drift" finding (no action — measured only)

Q8/Q9/Q10b resolve this: **there are no misspelled or variant course values.** `course_level` is `CA Foundation` / `CA Intermediate` / `CA Final` (+ NULL ×2, + 5 one-off free-text test users); `target_course` is `CA Intermediate` / `CA Foundation`. Every value is a clean exact match to its counterpart set.

The 1,659 "mismatched" active reviews (Q10) are **1,648 CA-Intermediate students reviewing CA-Foundation cards** + 11 stragglers — legitimate cross-level revision history that the Sprint 6.0 read-time course filter intentionally excludes from the queue (Custom Course being the accepted escape hatch, per the 6.0 auditor). It is also the mechanism behind the Progress "24 vs 4" discrepancy, which §0 option (a) fixes.

**No normalization slice.** No `[DATA]` mapping, no `[SCHEMA]` FK. Logged **informational** in `bugs.md` (with the Q10b numbers) alongside the resolved forecast entry — not OPEN.

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
| Course-value normalization | **no action** — Phase 0 proved no drift exists (§7) |
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
