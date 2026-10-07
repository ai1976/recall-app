# T-002 stream B execution plan, v2 (a plan, not SQL)

**Status:** working paper, written 07/10/2026 in T-002 Round 5 as the answer to QA Round 4 (`REVISION REQUIRED`, nine blocking and six non-blocking findings). It supersedes plan v1 (`07a9fd48e4cd`, frozen, committed `91b7080`) in full. It authorizes nothing: no SQL exists, none was run, no gate is requested.

**Scope.** Only stream B parts of T-001 SQL work plan v5 (`docs/database/t001/00_PLAN_sql-work-plan.md`, short sha256 `6961fb55dd69`, unchanged) are replaced. Stream A is not touched. The approved design is brief B v10 `0fe77dec72dc` (Gate 1). This plan changes order, phasing and implementation mechanism, not the design. Three places where a mechanism differs from the *wording* of brief B are flagged **MECHANISM** for QA to rule on (B-07 as a table trigger; B-04b fallback as an insert trigger; B-06a with an anonymous entry point).

**Founder decisions recorded (07/10/2026, in chat; quoted in Round 5):**
- **DEC-1 (report order).** Rule first, then report. Fourteen zero-count days alone are not proof. Required: confirm old clients are closed through deployment/version evidence, test stale and restored pending logs, observe zero new manual NULL rows, then enable and verify enforcement **before** the report ships.
- **DEC-2 (refusal timing).** Update the screens first to enforce the length and control-character rules and to provide a real custom-course input, then enable strict database refusal immediately afterward. Canonicalise only recognised catalogue labels; merely trim genuine custom text.

Evidence labels: VERIFIED (code or saved evidence), PROPOSAL, OPEN, MECHANISM.

## 1. Answers to QA Round 4
| # | Finding | Answer | Section |
|---|---|---|---|
| 1a | missing `study_sessions.discipline_id -> disciplines(id)` | added, `NOT VALID`, with accepted/refused tests | 4.1 |
| 1b | NULL classification could carry payload | compatibility branch: classification NULL requires every payload column NULL | 4.1 |
| 2a | B-06a needs B-04a | added; object, execution and test prerequisites are now listed separately | 2 |
| 2b | report before enforcement mislabels post-change NULL rows | enforcement (P3) now precedes the report (P4), per DEC-1 | 3, 4.2 |
| 2c | B-03 and B-07 reject current writes in P1 | frontend F0 first (validation and real custom input, DEC-2), then strict B-03/B-07; no refusal ships while the old forms are live | 3, 5, 6 |
| 3 | B-04b forms | plain check only if D3 finds no updater; the `created_at` form is **withdrawn**; fallback is a non-forgeable insert-time trigger; NULL `source` handled; stale-writer closure is evidence, not a date | 4.2 |
| 4 | B-03 signup exposure | resolved by DEC-2: F0 first, then strict refusal; named residual for stale tabs | 5 |
| 5 | B-07 rollout, trigger contract | table trigger kept (MECHANISM); follows F0 (no `Other` sentinel); trigger function contract stated; unchanged-value guard | 6 |
| 6 | B-05 completeness | full transition matrix; platform identity by discipline alone; legacy-conflict behaviour declared; due-guard extension in F0; overwrite policy decided, not OPEN | 7 |
| 7 | D1 | two-stage, body reviewed before any call; parameter cases; reconciliation; aggregate-only | 9 |
| 8 | D2 | executable without the new column; closure of trigger bodies; extra prechecks | 9 |
| 9 | D3 | seed-and-closure with a fail-closed unresolved list; auth chain; new D4 code inventory | 9 |
| NB1 to NB6 | hash projection, UI-path ownership, rollback after F1, lock bounds, per-object privileges, labelled prerequisites | sections 4.1, 4.2, 8 | |

## 2. Files, with object, execution and test prerequisites kept apart
`H3`/`H4` = saved live trigger bodies and policies (`FU3-H3`, `FU3-H4`). **Object** = the file calls, indexes or references an object of the other file. **Execution** = the other step must be live first. **Test** = fixtures only.

| File | Content | Object prerequisites | Execution prerequisites | Test prerequisites |
|---|---|---|---|---|
| B-01 `[FUNCTIONS]` | `normalize_course_text` (pure `IMMUTABLE`) and `resolve_canonical_course_label` (`STABLE`) | none | none | none |
| B-02a `[SCHEMA]` | `disciplines` guards: unique normalized-name index (all rows), rename trigger, no-hard-delete trigger | B-01, H4 | none | none |
| B-02b `[SCHEMA]` | catalogue write path and privilege closure (`disciplines`, `subjects`, `topics`) | B-02a, H4 | none | none |
| B-03 `[SCHEMA]` | `profiles` trigger: validate and canonicalise on insert and on change of `course_level` | B-01, B-02a, H3 | **F0 live and closure evidence (4.2 list)** | none |
| B-07 `[SCHEMA]` | `access_requests.course` trigger, same contract (6) | B-01, B-02a | **F0 live** | B-03 fixtures |
| B-04a `[SCHEMA]` | `study_sessions` compatibility phase (4.1) | B-01, B-02a | none | none |
| B-05 `[SCHEMA]` | `flashcards` and `notes` derive trigger and `NOT VALID` composite foreign keys (7) | B-01, B-02a, B-04a (unique pair on `subjects`), H3 | **F0 live (due-guard extension)** | none |
| B-06a `[FUNCTIONS]` | course catalogue function and projections (8) | B-01, B-02a, B-04a (earlier custom labels), B-03 (current-course contract) | none | B-02b, B-07 |
| B-04b `[SCHEMA]` | `study_sessions` enforcement (4.2) | B-04a | **F1 live, Gate 7 accepted, closure evidence** | none |
| B-06b `[FUNCTIONS]` | student-only classified breakdown reader | B-04a, B-05, B-06a | **B-04b verified (Gate 4)**, slice 1 baseline | none |

**Frontend steps.** **F0** (no SQL dependency): length, trimming and control-character validation on the Signup custom-course input and Profile Settings; a real custom-course text input on the access form (the literal option `Other` is no longer sent); and the due-guard extension: `subject_id` and `discipline_id` added to the due-relevant flashcard columns in `src/lib/dueSet.js` and `scripts/dueSetGuard.mjs` so a successful subject-only update refreshes the due snapshot (B-05 can rewrite `target_course`). **F1**: `confirmCategory` and the logging picker send classification; Signup, Profile Settings and the access form read the catalogue function; a subject-only transition test. **F2**: Progress by course and the day-detail view.

**Execution order:** F0, then B-01, B-02a, B-02b, B-03, B-07, B-04a, B-05, B-06a, then F1, then B-04b, then B-06b, then F2.

## 3. Phases (each file separately gated; the frontend active in each phase is stated)
| Phase | Content | Gates | Active frontend | Rollback |
|---|---|---|---|---|
| **P0** | F0 | 5, 6, 7 | F0 | revert the frontend commit; no SQL involved |
| **P1** | B-01, B-02a, B-02b, B-03, B-07, B-04a, B-05, B-06a. Claim, stated with its limit: **no write the F0 frontend makes is rejected**. Residual: a browser tab or bundle older than F0 can still send over-length text or the `Other` sentinel and would be refused (closure evidence of 4.2 applies to B-03/B-07 too) | 2, 3, 4 per file hash | F0 | each file's ROLLBACK in reverse order. Rewrites already made by B-03/B-07 (canonical text of a recognised label) stay; they are equivalent text |
| **P2** | F1 | 5, 6, 7 (four manual paths, stale and restored pending logs, 4.2 list) | F1 | revert the frontend; P1 stays |
| **P3** | B-04b alone, after the closure evidence and a final zero count inside the file | 2, 3, 4 | F1 (must stay) | drop the added rule; **never** revert the frontend first (the old frontend would fail to log) |
| **P4** | B-06b, then F2 | 2 to 4, then 5 to 7 | F2 | revert F2; drop B-06b by its ROLLBACK |

## 4. `study_sessions`
### 4.1 B-04a, compatibility
- **Columns (all nullable):** `classification`, `discipline_id`, `subject_id`, `custom_course_label`, stored generated `custom_course_key`, `custom_subject_label`, stored generated `custom_subject_key`.
- **Keys:** single-column `discipline_id -> disciplines(id)` (`NOT VALID`); composite `(discipline_id, subject_id) -> subjects (discipline_id, id)` (`NOT VALID`) against a new unique constraint on `subjects (discipline_id, id)`, same column order both sides (brief B 4.1). Because a MATCH SIMPLE composite key is skipped when `subject_id` is NULL, the single-column key is what protects a course-only platform row. Tests: accepted course-only row with a valid discipline; refused course-only row with a non-existent discipline; accepted valid pair; refused mismatched pair.
- **Shape constraints (`NOT VALID`):** `classification` is `platform`, `custom`, `general` or NULL. **NULL classification requires `discipline_id`, `subject_id`, `custom_course_label` and `custom_subject_label` all NULL** (old writers send none of these). `platform`: `discipline_id` required, custom labels NULL. `custom`: `custom_course_label` required, `discipline_id` and `subject_id` NULL. `general`: all NULL. `source` in (`study_mode`, `practice_mode`) requires NULL classification. **Not here:** "`manual` requires classification" (B-04b).
- **Labels:** the insert trigger trims and refuses a label that is empty, over 120 characters or contains a control character; a custom label whose `normalize_course_text` equals the name of **any** discipline (active or inactive) is refused; a match to a CMA/CS catalogue label is stored in canonical text (brief B 5.3a).
- **Compatibility, with limit.** VERIFIED in code: the only frontend `study_sessions` writers are `src/contexts/StudyTimerContext.jsx:214` and `src/lib/studyTracker.js:120`, neither sends a classification or payload column. This is a code statement at one commit. B-04a-TEST replays each exact column list as a real `authenticated` insert. DB-side and edge-function writers come from D3 and D4.
- **Lock and bounds (NB4).** Adding stored generated columns rewrites the table under `ACCESS EXCLUSIVE`. The file sets `lock_timeout` and `statement_timeout` at its top; on timeout the single transaction aborts with nothing applied and is retried at a quiet time. D2 supplies the relation size, not a stale row count.
- **No-backfill proof (NB1).** A hash over an explicitly ordered projection of the pre-existing columns, keyed by `id`, for rows created before the run starts, taken before and after; the new columns are asserted NULL separately. The same wording applies to B-04b.
- **Ownership of proofs (NB2).** B-04a-TEST proves the database contract only. The four UI paths (normal stop, recovery log-full and log-less, restored pending log) are proved at Gate 5 (diff) and Gate 7 (live), not by SQL.
- **Rollback after F1 (NB3).** Dropping the columns after F1 would discard captured identity. B-04a ROLLBACK first copies `id` and every classification column into an archive table (no client privileges, RLS on), and refuses to drop if the archive write fails. The accepted loss otherwise is none; the archive is an addition and is named in the rollback TEST.

### 4.2 B-04b, enforcement (only after F1; DEC-1)
- **Rule:** a `source = 'manual'` row requires a non-NULL classification.
- **Form, chosen by D3.** (i) If D2 shows `source` is NOT NULL or closed by a CHECK and D3 finds **no** routine that updates `study_sessions`: `CHECK (source IS DISTINCT FROM 'manual' OR classification IS NOT NULL) NOT VALID`. A legacy manual/NULL row can then never be updated by anyone; clients hold INSERT and SELECT only (brief B section 2, item 5, RUN 3). The TEST states this and proves it. The expression is written so a NULL `source` yields true or false, never UNKNOWN; the TEST attempts a NULL-`source` insert. (ii) If an updater exists: **MECHANISM** a BEFORE INSERT trigger that applies the same rule to **new rows only**. It is not forgeable (no client-supplied date is consulted) and leaves legacy rows updatable. It deviates from the brief's wording "constraint" and, if QA rules it needs a design change, it returns for a new brief hash before any file is authored. The `created_at` cutover form of plan v1 is withdrawn.
- **Closure of old writers (DEC-1), all required before the file is presented for Gate 2:**
  1. Deployment evidence: the F1 commit SHA, the production deployment record, and the time it became the served version.
  2. Version evidence for stale clients: the code at that commit (VERIFIED so far: `public/sw.js` registers install/activate handlers and has no fetch or cache handler, so it does not hold an old app shell; the bundle is replaced on reload). A tab that is never reloaded is not covered by this: it is named as the residual and its consequence (a refused log) is shown to the Founder, who accepts or defers.
  3. Tests at Gate 7: a log made in a tab opened before the F1 deploy; a pending log stored by the old version and restored after the upgrade (it must pass through the picker); each recorded.
  4. Observation: zero `manual` rows with NULL classification created after the F1 deploy time, over a window the Founder sets (14 days is a minimum, not a proof).
  5. A final zero count executed **inside** the B-04b run (a `DO` block that raises and aborts if any such row exists).
- **Report meaning.** After B-04b is verified, manual/NULL rows are exactly the pre-change rows (items 4 and 5), so "Unassigned / legacy" keeps the meaning of brief B I3. Only then does B-06b ship.
- **B-04b-TEST:** manual with NULL classification refused; every classified manual insert accepted; `study_mode`/`practice_mode` NULL accepted; NULL `source` attempt; the `UPDATE` behaviour of a legacy manual/NULL row exactly as its form states; row count and projection hash unchanged.

## 5. B-03 `profiles` (DEC-2)
- F0 is live first (Signup custom input validated and trimmed, Profile Settings validated). Then B-03 is strict from its first day: BEFORE INSERT OR UPDATE OF `course_level`, acting only when the value is inserted or `OLD.course_level IS DISTINCT FROM NEW.course_level`. It refuses a non-NULL value that is empty after trimming, over 120 characters, or contains a control character (whether a NULL `course_level` is legitimate for non-student profiles, such as professors or administrators, is OPEN and is decided from D2 before the file is authored; NULL is not refused unless D2 shows every current writer sends a value); it rewrites to canonical text **only** a normalized match to a discipline name (exact stored name) or to a CMA/CS catalogue label; any other text is stored **trimmed only**.
- The signup path (profile created without a client session through the auth trigger chain) must be a Gate 7 real-account test and a B-03-TEST case through the actual chain captured by D3. D3 also records how an error in that chain reaches the user.
- Residual named for the Founder: a signup from a bundle older than F0 with over-length text fails generically. Closure evidence as in 4.2 items 1 to 2 applies.
- Coexistence: with `trg_guard_profiles_protected_columns` and the AFTER `trg_course_change_archive_restore` (which then sees the canonical value), proved by exercising each path.

## 6. B-07 `access_requests.course`
- **MECHANISM:** BEFORE INSERT OR UPDATE OF `course` table trigger, same contract as B-03, acting only when inserted or `OLD.course IS DISTINCT FROM NEW.course` (the test includes `UPDATE OF course` with an equal value). It survives A-10c's rewrite of `submit_access_request`; QA Round 4 prefers it (finding 5). It also refuses the exact normalized sentinel `other` (the old form option, `src/components/ui/ContentPreviewWall.jsx:27,69`); D2 counts existing `Other` values (untouched, legacy).
- **Trigger function contract (all trigger functions of B-03, B-04a, B-05, B-07):** `SECURITY DEFINER`, owner = the migration owner, `search_path` pinned (unquoted, exact value fixed at authoring from D2), `EXECUTE` revoked from `PUBLIC`, `anon`, `authenticated`, `service_role` (a trigger needs no caller EXECUTE; the TEST proves this by exercising the trigger from each role and by a direct call being refused). Definer is needed because `disciplines` is RLS-protected and the writer may be `anon` through the RPC.
- Every writer found by D3 and D4 (not only `submit_access_request`) is exercised in B-07-TEST. Existing triggers (from D2) and A-10a's later triggers coexist by name order; the same test is added to A-10a/A-10c.
- Compatibility: rows are written from the frontend only through the RPC (VERIFIED: `src/lib/dueSet.js:103`); `AdminDashboard.jsx:271` reads and `:305` updates `status` only.

## 7. B-05 `flashcards` and `notes`
- **Decided policy (no longer OPEN).** Brief B 6.3 makes `target_course` a derived label for platform rows, so deriving it is the design, not a risk. A platform row is any row with a `subject_id` or a `discipline_id`.
- **Transition matrix** (S = subject, D = discipline, T = target_course; DS = discipline of S; the trigger fires only when S, D or T is inserted or `IS DISTINCT FROM` its old value). Every row of this matrix is a TEST case:
  | Operation | Result |
  |---|---|
  | INSERT, S set, D NULL | D = DS, T = name(DS) (a client T is overwritten) |
  | INSERT, S set, D set, D <> DS | refused |
  | INSERT, S NULL, D set | T = name(D); D must exist |
  | INSERT, S NULL, D NULL | untouched (custom or unassigned, including the 3 legacy notes) |
  | UPDATE, only S changes | D = new DS, T = name(new DS); NEW.D carrying the old value is **not** treated as explicit |
  | UPDATE, only S changes to NULL, D set | stays platform by D: T = name(D) |
  | UPDATE, only D changes | S set and D <> DS: refused; S NULL: T = name(D); D to NULL with S set: D = DS |
  | UPDATE, only T changes | platform row: T = name(derived), the batch edit of the current screen (`MyFlashcards.jsx:463` sends T and S together) therefore keeps working; non-platform row: untouched |
  | UPDATE, S and D both change | D must equal DS, else refused |
  | UPDATE, same values, or none of S, D, T in the SET list | not fired; legacy rows untouched |
- **Legacy conflicts (declared).** A row that is already a conflict stays one until a client update touches S, D or T; the touch makes the row consistent by the rules above. This is the declared effect of the approved derived-label rule, not a separate data fix; reconciliation of any other row remains a separately reviewed task (brief B 6.2). F6 measured 0 conflicts; D2 recounts, including the omitted case S NULL and D set. A fixture conflict row, if the count is 0, is built inside the TEST transaction by disabling the trigger and rolled back; its technique is for QA to approve, otherwise the case is `NOT COVERED`.
- **Due invalidation.** The trigger can change `flashcards.target_course` after an S-only or D-only update. `DUE_FLASHCARD_COLUMNS` (`src/lib/dueSet.js:191`, `scripts/dueSetGuard.mjs:35`) lists only `target_course`, `question_type`, `visibility`; F0 adds `subject_id` and `discipline_id`, with a guard test that a subject-only update outside the wrapper fails the build and a wrapper test that it notifies. B-05 does not execute before F0 is live.
- **Writers.** The writer-and-column matrix is produced by D3 (database side) and D4 (code and edge functions) before the file is authored; it can add rows to the matrix above but cannot reopen the overwrite policy.
- **Foreign keys:** composite `NOT VALID` keys on both tables. TEST proves legacy rows (NULL D) are skipped and that updates not touching the key columns skip the check (brief B 6.3).
- Coexistence with `trg_guard_flashcards_is_verified`, `trg_guard_flashcard_batch_move`, `trg_guard_notes_privileged_columns` and the AFTER counters `trg_aaa_counter_flashcards`, `trg_badge_flashcard_create`, `trigger_update_deck_card_count` by exercised paths and name order.

## 8. Catalogue function and object-level privileges (B-06a, NB5)
- The Signup screen is unauthenticated, so its list cannot come from a direct table read (CLAUDE.md pre-push check 1). **MECHANISM:** B-06a has two entry points, an anonymous one returning only the Signup and access-form projections (active platform courses and catalogue labels, no caller overlays) and an authenticated one returning all four projections with the caller's overlays. The authenticated entry reads only the caller's own earlier custom labels from `study_sessions`.
- **Object-level ceilings (to be fixed exactly in each file and compared in TEST):**
  | Object | Intended callers |
  |---|---|
  | `normalize_course_text` | `authenticated` and the owner. It runs inside the generated columns and the `disciplines` index expression, so the inserting role needs EXECUTE; the TEST inserts as a real `authenticated` caller after the revoke/regrant to prove it, and does not assume |
  | `resolve_canonical_course_label` | owner only (called from definer triggers) |
  | trigger functions (B-03, B-04a, B-05, B-07) | nobody (6) |
  | catalogue function, anonymous entry | `anon`, `authenticated` |
  | catalogue function, authenticated entry | `authenticated` |
  | B-06b reader | `authenticated` students only; professors refused; `anon` none |
  Every ceiling is a complete, deterministically ordered grantee set; no global default privilege changes.
- All binding conditions of QA Round 2 stay (definer `search_path`, the measured `get_study_time_stats` nuance, trigger coexistence by exercised paths, `NOT COVERED` for absent live cases, normalised rollback comparison, slice 1 preservation surface and due-set guard manifest, parser-level read).

## 9. Diagnostics (proposal; SQL file written only after QA accepts this section; one Founder run per stage; results saved raw and unchanged)
Each says how it moves the finish line.
- **D1 Subject Mastery, two stages.**
  - **D1a (catalogue only, no call):** every overload of `get_subject_mastery_v1`: body and body hash, owner, security mode, volatility, configuration, ACL; its callees and referenced relations and views (closure); a conservative flag for any write or dynamic SQL. *Finish line:* establishes that calling it is read-only before anything executes it.
  - **Code trace (Claude, no database):** how `selectedCourse` and the one-course fallback reach `p_course_level` (`src/components/progress/SubjectMasteryTable.jsx:22`), so function behaviour is separated from frontend state or races.
  - **D1b (after D1a is reviewed):** inside `SET TRANSACTION READ ONLY`, as the `TestOutlook` account, three parameter cases: `CA Intermediate`, a comparison course, and NULL; for each, the returned rows (platform subject names, counts) and an independent reconciliation reproducing the body's card, enrollment and due-eligibility predicates, with parts reconciled to the returned totals; aggregates only, no user or card identifiers; errors saved unchanged. *Finish line:* decides whether the 7-subject, Business Laws 24-due result is a function bug B-06b must not copy, a missing course scope, or expected data. No cause is stated before it.
- **D2 Live state, executable before B-04a.** Uses `to_regclass` and `information_schema` checks so it never references the missing column; counts `study_sessions` by `source` only. Captures for `study_sessions`, `flashcards`, `notes`, `profiles`, `access_requests`, `disciplines`, `subjects`, `topics`: trigger definitions **and the bodies, owner, security mode, configuration and ACL of the functions they call**; constraints (including the exact `source` constraint and nullability); columns (types, defaults, `created_at` nullability and default, generated); table and column privileges; policies; relation size and row count; normalized discipline-name collisions and invalid names; card/note conflict counts including S NULL and D set; existing `Other` values in `profiles.course_level` and `access_requests.course`; shape counts of `access_requests.course`. The `auth.users` trigger chain is in D3. *Finish line:* B-04a, B-05, B-07 and B-03 are written once against real names, order and sizes.
- **D3 Writer closure, seed-and-closure, fail-closed.** Seeds: relation dependencies (views, rules, triggers, policies, foreign keys) on the target relations and on the three catalogue tables; text leads over routine bodies in every non-system schema (aliases, quoted names, `MERGE`, `EXECUTE`); trigger, rule and view writers; the transitive callee closure; scheduled jobs (names and schedule; commands reduced to the routine names they call, never emitted raw, so no secret is saved). Anything not resolvable (non-SQL language without readable body, dynamic command, unmatched callee) is listed as **unresolved**, never as clean. Includes the full `auth.users` signup-to-profile chain with its error handling, every writer to `access_requests` and to `disciplines`/`subjects`/`topics`, and the body of `submit_access_request`. FU4-J2 results are reused only where their saved hash and relation closure prove they cover a relation. *Finish line:* chooses the form of B-04b, finds any writer B-04a/B-05/B-07 would reject, and shows how a B-03 error reaches signup.
- **D4 Code inventory (Claude, no database, at an exact commit):** every direct write and RPC call in the frontend and in `supabase/functions` that touches the target relations, with the columns each sends, saved as a table. *Finish line:* the other half of the compatibility matrices; also resolves the form-limit question for `course`. Note: a single-quote grep of `supabase/functions/*/index.ts` found no `.from('<target>')` write on today's check; D4 repeats it with both quote forms and non-literal table names.

## 10. Follow-ups outside this plan
- Stream A (later thread): A-10a drops the `access_requests.course` duty (now B-07) and must re-run B-07-TEST; plan v5 is not edited.
- Brief B is not reported complete until B-07 has its Gate 4.
- T-001 Round 51 D-labels belong to the brief A thread.

## 11. Accuracy checklist run before hand-off
Checked against: QA Round 4 line by line; brief B 4.1, 4.2, 5.1 to 5.5, 6.1 to 6.4; code at `StudyTimerContext.jsx:214`, `studyTracker.js:120`, `dueSet.js:103,189-199`, `dueSetGuard.mjs:35`, `MyFlashcards.jsx:463`, `ContentPreviewWall.jsx:27,69`, `SubjectMasteryTable.jsx:22`, `public/sw.js`. No SQL is presented, so no parser-level read applies; Claude has no database engine and nothing was run. Corrections to my own v1: the single-column key was missing; the "legacy" meaning was broken by the phase order; the `created_at` form was forgeable; `T`-only updates would have been refused by the current batch edit; the Signup projection needed an anonymous entry point; the due guard did not list `subject_id`. Not measured, so not asserted: updaters of `study_sessions`; the `source` constraint; existing `access_requests` and auth triggers; the signup function's error handling; the body of `get_subject_mastery_v1`; whether edge functions write the target tables.
