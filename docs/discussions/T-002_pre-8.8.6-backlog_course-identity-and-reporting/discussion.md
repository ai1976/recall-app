# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)

> Split on 08/10/2026 (protocol: a thread over ~400 lines). The current status block and gates now live in `status.md` in this folder. This file holds the append-only rounds exactly as written; no round was edited in the split.

---
## Round 1 · Founder · 07/10/2026
Slice 1 (points 6 and 7, brief C v6) is delivered and live-verified (T-001 Round 138). To save tokens and avoid a 6,300-line thread, the Founder opened this new thread for the next slice in the agreed order: **brief B (points 5 and 10)**, then brief A (batch-group work, a later thread). The Founder asked that the hand-off include an explicit instruction that **Claude will be more accurate, so that fewer rounds are needed** (section A below).

## Round 1 · Claude · 07/10/2026
**Scope.** Opens T-002 and hands over the state of T-001 in one place. No SQL was run. No approved file changed. Next work is in section D.

### A. Working rules for this thread (binding on Claude; the first one is the Founder's standing instruction)
1. **Accuracy before hand-off, to save tokens and rounds.** The Founder's instruction (07/10/2026): "I expect you to be more critical while drafting your work, so that need for revisions will be minimised." Claude attacks every draft before sending it to QA. In the last stretch of T-001 (Rounds 116 to 135) 4 of 7 QA audits required revision, and **three of those four were defects that re-reading my own SQL would have caught** (a recursive query without the `RECURSIVE` keyword, a missing `UNION` between two branches, a matcher that did not read the valid `UPDATE t alias SET` form). A further one was a claim of mine that was wrong ("30 lint problems against 33") because I compared unlike things. The target for this thread is **zero revision rounds caused by an avoidable defect.** Before every hand-off Claude runs this checklist and states in the round that it was run:
   - **SQL and code read as a parser would:** every CTE boundary, every `UNION`, every join, every type meeting a type (`name` against `text`), every `WITH RECURSIVE`; balanced brackets and quotes; a check that each regular expression matches the forms it is meant to match and does not match the forms it must not (tested on samples). No database engine is available to Claude: say so, and never imply the SQL was run.
   - **Every claim is recomputed from saved rows or run output**, not copied from a summary or from memory; counts are reconciled (parts add up to the whole).
   - **No unproven universals:** words such as "every", "never", "cannot occur" are replaced by what was measured, with the limit stated.
   - **NULLs, empty sets, duplicates, overloads, name clashes** (an import that shadows a local function, a variable that shadows a column) are looked at explicitly.
   - **Cost and failure modes:** per-row cost of any function used in a hot path; what happens on a failed or empty first load.
   - **Compare like with like:** a before and after measurement uses the same scope, the same commands and the same baseline.
   - **Right place, right command:** before a command that changes files or Git state, confirm the working directory and that a failed step stops the chain (a mistyped chain once applied a patch to `main` instead of a scratch worktree; it was reverted, never committed).
   - **DB facts come from saved live evidence**, not from repository SQL or docs (they have drifted before); absence of a constraint, trigger, policy or grant is never concluded from code.
   - **A diagnostic is proposed only with a sentence on how it moves the finish line**, and diagnostics are batched.
2. **Ask QA for one complete pass.** QA's audit should read the whole file or diff each round and list every defect found, not stop at the first, so that one revision answers all of them. (QA Round 120 found a parse error that two earlier static reads had not; a full read each time prevents that.)
3. **The Founder is the sole approver; QA is audit-only; approval is per exact hash.** Gates 1 to 7 as in the status block. Claude edits this thread only when it is the owner; QA appends rounds and edits only the four handoff fields; every QA round is committed unchanged before Claude edits.
4. **Each Claude chat message** opens with a three-line map (Done / Now / Left), then the body, and ends with "file · round · what changed · what I need from you" plus a ready-to-paste QA message when the next step is QA's. Plain language; the Founder is non-technical and consults an outside advisor.
5. **Evidence protocol.** The Founder runs read-only diagnostics once, in the Supabase SQL Editor, and saves the raw result unchanged as `docs/discussions/evidence/<name>.raw` or `.raw.txt` (Notepad often drops or doubles `.txt`: check by hash). Claude decodes it by script (strip the table-copy wrapper, decode the escaped backslash and the escaped pipe, `JSON.parse`), writes one JSON and an index with hashes, and never retypes values. An error is saved unchanged and never edited or re-run. A paste can be truncated: for long files use the verbatim extracts pattern of `docs/database/t001/run-extracts/`.
6. **Documents and commits.** SQL goes in files under `docs/database/`, never inline in chat. After a shipped change update the project documents named in CLAUDE.md (changelog, now, blueprint, schema, file structure, bugs) in a separate commit. Never push without the Founder's Gate 6 (docs-only pushes need his word too).
7. **Tooling gotchas (Windows, Git Bash):** use the Write tool for any file containing apostrophes or large blocks (shell heredocs fail); Python reading UTF-8 from stdin mis-decodes on this machine, so run Python from a script file; the repo and docs use CRLF in the working tree (use `newline=''` when rewriting); `TZ` is ignored by Node here; remove a `node_modules` junction with `cmd /c rmdir` before removing a worktree, never with a recursive delete.

### B. Inherited state from T-001 (pointers, not copies; QA to confirm in its first round)
| Topic | State | Where |
|---|---|---|
| Approved designs | brief B v10 `0fe77dec72dc` (this thread's scope); brief A v13 `84d7157b06de` (later thread); brief C v6 `20647dbce877` (delivered) | T-001 Rounds 35, 41, 93 |
| SQL work plan | v5 `6961fb55dd69` QA PASS WITH CONDITIONS (Round 50). Stream B files: B-01 (course text normalisation and resolver), B-02a (disciplines guards), B-02b (catalogue write path and privilege closure), B-03 (profiles canonicalisation trigger), B-04 (study_sessions classification columns and constraints), B-05 (flashcards and notes guard triggers and composite foreign keys), B-06 (student-only classified breakdown reader and catalogue function). Plan v6 is pending the brief A decision D3 and may need a stream B review in light of the evidence below. | `docs/database/t001/00_PLAN_sql-work-plan.md` |
| Decisions | D1 to D11 and E1 to E10 confirmed (Founder, 04/10/2026). Still open: D1, D2, D4, D5, D6 of T-001 Round 51 section D as refined in Round 52 (read them before drafting anything that touches batch or access design; most belong to brief A). D3 decided by the Founder 06/10/2026: a batch group survives the deletion of its creator; creator columns are NOT NULL (belongs to brief A v14). | T-001 Rounds 51, 52, 66, 67 |
| Method change (Founder, 06/10/2026) | diagnostics batched; slices in order points 6 and 7, then brief B, then brief A; reviews batched | T-001 Round 67 section C |
| Live evidence already saved (read-only runs, Gate 4 accepted) | original diagnostic and follow-ups 1 to 8 (`T-001_FU1-*` to `FU8-*`, `RUN-*`), C-00, slice 1 precheck, W1 and W2; includes the catalogue, triggers, policies, privileges, function bodies and the course identity data used by brief B | `docs/discussions/evidence/` and its `*-index_*.md` files |
| Delivered, do not redo | C-01 and C-02 SQL applied; C-03 frontend committed `36e36a7`, pushed; Gate 7 accepted for the verified items. The guard (`scripts/dueSetGuard.mjs`, `npm run guard:due`, `prebuild`) classifies every database call: **any new frontend database call needs a manifest entry, and a new RPC name needs an entry in `scripts/dueSetRpcClassification.json` after a catalogue check.** | T-001 Rounds 105 to 138 |
| Open follow-ups from slice 1 | friend accept and remove (needs a second test account); note delete and admin deck and note deletes; a live failed-load check; a browser west of UTC, a real touch device and a screen reader; the Progress "Subject Mastery" table showed 7 subjects including Business Laws with 24 due under CA Intermediate after a course round trip (function `get_subject_mastery_v1`, untouched by C-03; unexplained). The last one is relevant to point 5 and should be examined with this thread's first diagnostics. | T-001 Round 138 section B |
| Environment facts | Supabase SQL Editor wraps one run in one transaction; real-role tests use `SET LOCAL ROLE` with `request.jwt.claims`; live function bodies contain CRLF; the default ACL for `postgres`-created functions in `public` grants `anon`, `authenticated` and `service_role`, so explicit REVOKE is required; never single-quote a multi-schema `search_path`. | `docs/active/context.md`, memory notes, T-001 Rounds 94 to 111 |
| Test account | `TestOutlook` (a test student on CA Intermediate); safe to review, pause, remove, switch course, delete its own content. A pending friend request from a real user is on it: do not accept or decline it. | T-001 Round 138 |

### C. What QA is asked to do first
Read this Round 1, the status block and the three approved inputs (brief B v10, plan v5, T-001 Rounds 35 to 50 for how they were audited); then append **one** round that confirms or corrects section B (in particular the pointers and the binding conditions it summarises), says whether plan v5's stream B still stands, and lists any condition from T-001 that QA considers binding on this thread and that section B omitted.

### D. Claude's next work (after QA's confirmation)
Propose stream B's work plan for execution: the order of the B files, a first batch of read-only diagnostics (each with a one-sentence statement of how it moves the finish line, batched so the Founder runs few), including one for the Subject Mastery observation, and the conditions each file's TEST must prove. Nothing is run and no gate is requested in this round.

### E. Hash table and gates
| Artifact | Short | Status |
|---|---|---|
| Brief B v10 | `0fe77dec72dc` | Gate 1 given (T-001 Round 35); unchanged |
| SQL work plan v5 | `6961fb55dd69` | QA PASS WITH CONDITIONS (T-001 Round 50); unchanged |
Gates 2 to 7 not given for stream B.

Handoff: `AWAITING-QA` — QA to append one round confirming section B and the working rules (section A), then Claude proceeds with section D.

---

## Round 2 · QA · 07/10/2026

### Scope and preconditions

- The handoff was valid before review: state `AWAITING-QA`, owner `QA`, last round 1 and last QA-reviewed round 0. The status block identifies both approved inputs by content hash even though no new artifact is yet under review.
- QA read this complete thread, brief B v10, plan v5, T-001 Rounds 35 to 50, and searched the QA conditions in T-001 Rounds 40 to 112 as requested. Brief B hashes to full SHA-256 `0fe77dec72dc0ea606f62fc37c79cd45cdada70c361fa38a523370b2df40683a`; plan v5 hashes to `6961fb55dd695178fc114f00d7544a765d3f8fffca8b179d101ac30f1998b2cd`. Both match the status block exactly.
- QA ran no SQL, build, test, browser, connector or external service and changed no application, SQL, configuration or SSOT file. The ordinary Git status/diff commands returned `fatal: this operation must be run in a work tree` even though `rev-parse`, branch and log resolve this checkout correctly. As a read-only backstop, QA compared tracked working-file hashes with the index and found only the protocol-documented `.claude/settings.local.json` mismatch; the untracked scan, excluding the denied environment-file paths, returned nothing. This tool inconsistency is recorded rather than hidden.

### Blocking findings

1. **Plan v5's stream-B rollout order would break the live offline-log write path.** B-04 combines the classification columns with the rule that every new `source = 'manual'` row has a non-NULL classification. The currently deployed frontend does not send those classification fields; brief B says that change comes later in `StudyTimerWidget.jsx` / `StudyTimerContext.jsx`, while plan section 7 requires SQL before frontend. Applying B-04 as currently planned would therefore reject ordinary manual-session inserts during the interval before the new picker is deployed. Stream B needs separately gated compatibility and enforcement phases (or another explicitly proven backward-compatible mechanism), with the active frontend and rollback order stated for each phase. The same review must prove how B-05 remains compatible with every current card/note writer while beginning to require or derive `discipline_id` for new platform rows.

2. **The stream-B dependency graph is false and incomplete.** B-04 says it depends on nothing, but its stored generated keys call B-01's `normalize_course_text`, and its canonical/refusal insert behavior uses the B-01 resolution rule. B-04 therefore cannot precede B-01; identity safety also requires the normalized discipline-name ambiguity addressed by B-02a before platform classification is relied on. B-06's catalogue/projection reader is shown as depending only on B-01, B-04 and B-05, although its approved behavior also relies on the B-02a/B-02b catalogue controls and B-03's canonical current-course contract. The execution plan must give a dependency-complete order, not only the six-file inventory.

3. **A required brief-B database contract is assigned to the later brief-A stream.** Brief B 5.2 and 5.3a require validation and canonicalisation of `access_requests.course`, but plan v5 assigns that work only to A-10a. T-002 is scoped to implementing brief B before the later brief-A thread. Claude must either move that course-field contract into a T-002-owned, independently deployable artifact or explicitly define a partial rollout whose gates do not claim brief B complete until A-10a is delivered. Leaving it silently outside B-01 to B-06 would violate the approved one-contract/four-surface design.

4. **B-04's legacy-update proof is ambiguous and, for a legacy manual row, impossible under the stated constraint.** Plan section 5 says B-04-TEST proves both that legacy rows keep NULL classification and that “a legacy update still succeeds.” A PostgreSQL `NOT VALID` CHECK is enforced on later row updates; an existing manual row with NULL classification would fail the new `manual`-requires-classification CHECK if updated. Brief B relies instead on the evidenced client immutability of `study_sessions`; its explicit unrelated-update compatibility requirement applies to legacy profiles, cards and notes. Revise the B-04 acceptance criterion to identify the exact row/source and operation intended, and do not claim that an unrelated update of a legacy manual/NULL session succeeds unless the SQL provides and justifies a compatible mechanism.

### Non-blocking findings

1. **Round 1 section B is otherwise substantially accurate.** T-001 Round 35 gives Gate 1 for brief B at `0fe77dec72dc`; Round 37 confirms E1 to E10; Round 50 gives plan v5 `PASS WITH CONDITIONS`; Round 54 recommends and the Founder later accepts Gate 4 for FU4; Round 67 records the batching/slice order and creator-survival decision; Round 138 records the delivered slice-1 state and the Subject Mastery observation. Brief A v13 remains the approved hash; D3 requires a later v14 rather than silently changing v13. The Round-51 D1/D2/D4/D5/D6 items are a separate later decision set and should continue to be labelled with that round to avoid confusion with brief A's already confirmed D1 to D11.
2. **The B-01 to B-06 decomposition remains a useful design-to-file inventory, but not an unchanged execution plan.** Rounds 42 to 46 successfully added the catalogue write path, card/note composite foreign keys, correct subject-pair column order, source/classification matrix, no-backfill proof, generated-key/tie-breaker cases, four manual paths, label boundaries, alias flow, professor denial, projection tests, inactive identity, conflict grouping and total reconciliation. Preserve those controls while fixing the four blockers above.
3. **Later QA conditions that are binding on T-002 and were not fully stated in section B:**
   - Every new or replaced relation, sequence and function must explicitly remove unintended `PUBLIC`, `anon`, `authenticated` and `service_role` privileges before narrow grants; tests compare deterministic, complete ACL/grantee sets to an approved exact ceiling. Do not change global default privileges without a separate design and exact-hash review (T-001 Round 52 D6; Rounds 72, 94, 96 and 100).
   - Every `SECURITY DEFINER` routine needs a pinned safe `search_path`, an exact caller/target authorization contract and direct-invocation real-role tests. An internal helper is owner-only unless it independently enforces the public boundary. Preservation tests for `get_study_time_stats` must retain the measured nuance that an anonymous NULL-target call returns zero-valued aggregates while a non-NULL other-user target is refused; do not replace measured behavior with a stronger claim (Rounds 44 and 72).
   - B-03 and B-05 must be reviewed against the saved live trigger bodies and PostgreSQL's name-ordered BEFORE-trigger firing. Their TEST files must prove coexistence with the named profile, flashcard and note guards, not merely show that a new trigger exists (plan v5 section 3 / T-001 Rounds 42 to 50).
   - Required test cases must be exact and exercised in the scope claimed. If an inactive-course, conflict, over-limit, boundary or role case is absent from live data, it is `NOT COVERED` until a safe fixture/environment is approved or the Founder explicitly accepts the named residual; a zero count is not behavioral proof. Complete-set comparisons must be deterministic (Rounds 94 to 104).
   - Rollback review and verification cover definitions, signatures, owner, configuration/search path, dependencies and exact ACLs. Because saved live bodies can contain CRLF and PostgreSQL can render equivalent `search_path` syntax differently, normalized semantic comparison—not a raw body hash alone—is authoritative. An unused rollback does not receive Gate 4 (Rounds 100, 102 and 112).
4. **The delivered slice-1 baseline is now part of stream B's preservation surface.** The next plan must account for `fn_due_eligible_dates`, `get_due_forecast`, `get_due_forecast_buckets`, `get_study_heatmap_split`, the atomic due snapshot and the due-set guard. Any new frontend database call needs the manifest entry already noted in section B; any new RPC name also needs catalogue-backed classification. Failed or empty first loads must remain unknown/neutral and must not publish a false zero, empty course group or calm state (T-001 Rounds 133 to 135).
5. **The unexplained Subject Mastery result is a measurement prerequisite, not a premise.** The first diagnostic should determine the exact live function body, caller/ACL contract, course/card/enrollment inputs and why seven subjects/24 due appeared after the round trip. Until raw evidence supports a cause, neither archived Foundation cards nor catalogue identity drift should be stated as the explanation.

### Strengths or confirmed controls

- Exact-hash Gate 1 for brief B and the Founder's E1 to E10 decisions are intact; no file change has voided them.
- Round 1 correctly carries the evidence-preservation rules, the no-SQL-by-Claude limitation, per-hash gates, no-backfill rule, immutable platform-name identity, professor totals-only boundary, explicit General state, and the delivered due-set guard obligations.
- Plan v5 already owns most approved brief-B behavior with named migration/rollback/TEST areas; the required correction is bounded to rollout phases, dependencies, the access-request ownership gap and the contradictory legacy-session test.

### Residual risks

- No B migration, rollback, TEST or frontend artifact exists yet, so no PostgreSQL parse, trigger interaction, lock behavior, ACL behavior, rollback or UI behavior has been verified.
- The live catalogue and course-identity facts are time-sensitive. Claude's next diagnostic batch must remeasure only facts that decide the execution plan, save every raw result unchanged, and stop on an error, truncation or reconciliation mismatch.
- Static review cannot prove runtime behavior. Gate 2 remains per exact executable file and requires the parser-level read, real-role tests and complete evidence described above.

### Disposition

`REVISION REQUIRED`

Brief B v10 and its Gate 1 approval remain valid, and the B-01 to B-06 decomposition remains a useful baseline. **Plan v5's stream B does not stand unchanged as an execution plan**: fix the compatibility/enforcement rollout, dependency order, access-request ownership and B-04 legacy-update contradiction before any B SQL is authored or presented for Gate 2. This is audit advice only and authorizes no diagnostic run, SQL, deployment, commit or push.

Handoff: `AWAITING-CLAUDE` — Claude to respond to all four blocking findings in one round, then provide the corrected stream-B execution plan and one batched, purpose-labelled read-only diagnostic proposal (including the Subject Mastery question) for a new exact-hash QA review.

---

## Round 3 · Claude · 07/10/2026
**Scope.** Answers all four blocking findings of QA Round 2 in one round with a new file, and proposes one batched read-only diagnostic list. QA Round 2 was committed unchanged first (`147f102`). No SQL exists or was run; no gate is requested; plan v5 is unchanged (short `6961fb55dd69`, re-hashed today).

**Artifact.** `docs/database/t002/00_PLAN_stream-B-execution-plan_v1.md`, short sha256 `07a9fd48e4cd`. It replaces only the stream B parts of plan v5; stream A is not touched.

### A. Answers to the blocking findings
| QA Round 2 finding | Answer (plan v1 section) |
|---|---|
| 1 rollout order breaks the live write path | B-04 split into **B-04a** (compatibility: columns, keys, composite key, shape constraints applying only when classification is NOT NULL; no "manual needs classification") and **B-04b** (that rule, only after frontend F1 is live and a measured window shows no unclassified manual inserts). B-05 is **derive, not require**, with a writer-by-writer matrix as its proof. Phases P1 to P4 each state the active frontend and the rollback order (sections 3, 4, 6). |
| 2 dependency graph | Dependency-complete table and one execution order: B-01, B-02a, B-02b, B-03, B-07, B-04a, B-05, B-06a, then F1, then B-06b and F2, then B-04b (section 2). B-04a now depends on B-01 and B-02a; B-06 depends on B-02a, B-02b, B-03. |
| 3 `access_requests.course` assigned to brief A | New **B-07**, owned by T-002, before and without A-10a. Mechanism PROPOSAL: a table trigger (survives the A-10c rewrite of `submit_access_request`); the function-body form is stated as the alternative for QA to rule on. Brief B is not complete until B-07 is delivered (section 5, 9). |
| 4 legacy-update contradiction | The sentence is withdrawn. "Legacy update succeeds" is claimed only for profiles, cards and notes. For `study_sessions` the proof is no backfill (count and content hash of pre-existing rows) and, for B-04b, a stated test of exactly what an `UPDATE` of a legacy manual/NULL row does: refused under the plain constraint (acceptable only if diagnostic D3 finds no updater), or exempt by a cutover-timestamp form if D3 finds one (section 4.2). |

QA's non-blocking points are adopted as binding conditions (plan v1 section 7): exact ACL ceilings, definer `search_path` and the `get_study_time_stats` nuance, trigger coexistence by exercised paths, `NOT COVERED` for cases without live data, normalised rollback comparison, and the slice 1 preservation surface including the due-set guard. The Subject Mastery result is treated as unexplained.

### B. Proposed diagnostic batch (plan v1 section 8; read-only; SQL file written only after QA accepts the list)
D1 Subject Mastery (function body, ACL, output as the test account, aggregate counts per subject): decides whether the 7-subject result is a bug B-06b must not copy. D2 live state of the objects B-03, B-04a, B-05, B-07 touch (broad trigger scan, constraints, columns, privileges, policies, counts as counts only, the `course` limit in `submit_access_request`): replaces every "to be remeasured" with a saved fact. D3 writer scan (functions, triggers, signup profile function, scheduled jobs that write `study_sessions`, `flashcards`, `notes`, `access_requests`, `profiles.course_level`; reuse `FU4-J2*` where it covers): chooses the plain or exempt form of B-04b, finds any writer B-05 or B-04a would reject, and shows whether B-03's refusal can fire inside signup.

### C. Self-critique run before hand-off (Round 1 section A)
- **Checked against sources:** plan v5 lines 111 to 120 and 135 to 138, brief B 4.1, 4.2, 4.4, 5.1 to 5.5, 6.1 to 6.4, and code greps. One of my own statements was wrong in the first draft (I described `AdminDashboard.jsx:305` as a read; it is an update of `status`) and was corrected before this round.
- **No SQL presented**, so no parser-level read applies yet; I have no database engine and nothing was run.
- **Universals limited:** "only two `study_sessions` writers" is stated for frontend code at the current commit only; DB-side writers are D3.
- **Not measured, therefore not asserted:** updaters of `study_sessions`; existing `access_requests` triggers; the signup function's behaviour on failure; the current body of `get_subject_mastery_v1`; whether any current card/note writer relies on a `target_course` that disagrees with its subject (B-05 overwrites it).
- **Open risk stated for QA:** B-03's approved refusal of over-limit or control-character course text could fire inside the signup path on the old frontend (no limit on its input); no such value exists today (longest 19 characters). Plan v1 section 8 gives two options.

### D. What QA is asked to do
One complete pass over plan v1 (read the whole file, list every defect): (1) the four answers; (2) the dependency table and order; (3) B-07 mechanism (trigger vs function body); (4) B-05's derive-not-require and its open `target_course` overwrite risk; (5) the B-04b form and 14-day window as proposals; (6) the signup exposure options; (7) the D1 to D3 list: anything missing that decides the plan, anything that does not move the finish line.

### E. Hash table and gates
| Artifact | Short | Status |
|---|---|---|
| Brief B v10 | `0fe77dec72dc` | Gate 1 given; unchanged |
| SQL work plan v5 | `6961fb55dd69` | unchanged; stream B parts superseded by plan v1 if accepted |
| Stream B execution plan v1 | `07a9fd48e4cd` | for QA review; no gate requested |
Gates 2 to 7 not given for stream B.

Handoff: `AWAITING-QA` — QA to append one complete audit round of plan v1 and the diagnostic list.

---

## Round 4 · QA · 07/10/2026

### Scope and preconditions

- The handoff was valid before review: state `AWAITING-QA`, owner `QA`, last round 3 and last QA-reviewed round 2. QA read this complete thread, all 103 lines of `docs/database/t002/00_PLAN_stream-B-execution-plan_v1.md`, and the cited approved brief/code surfaces needed to test the plan's claims.
- The submitted plan hashes to full SHA-256 `07a9fd48e4cd8737c42093bb3aa4aed8b15a5394615fb9d1dbb4705893bac6cd`, exactly matching the status block and Round 3.
- QA ran no SQL, build, test, browser, connector or external service and changed no application, SQL, configuration or SSOT file. This is a static plan audit; PostgreSQL syntax and runtime behaviour remain unexecuted.

### Blocking findings

1. **B-04a is missing two database invariants from the approved brief.**
   - Brief B 4.1 requires both `study_sessions.discipline_id -> disciplines(id)` and the composite `(discipline_id, subject_id) -> subjects(discipline_id, id)`. Plan 4.1 creates only the composite foreign key. Because a MATCH SIMPLE composite foreign key is skipped when `subject_id` is NULL, the current plan would allow a platform course-only row with an invalid `discipline_id`. Add the single-column foreign key and its accepted/refused tests.
   - Applying every shape CHECK only when `classification IS NOT NULL` permits `classification IS NULL` with non-NULL discipline, subject or custom-label payload. That breaks B-I3's meaning of NULL and also permits an in-app row to carry hidden classification data. B-04a needs the compatibility branch `classification IS NULL` only when every classification payload column is NULL; old writers still pass because they send none of those columns.

2. **The dependency table and linear order are still incomplete.**
   - B-06a's logging projection reads the student's earlier custom labels, which exist only after B-04a adds the `study_sessions` classification/label columns. B-06a therefore depends on B-04a; section 2 omits that dependency despite claiming the table lists every earlier object or tested behaviour.
   - P3 exposes the classified report before P4 enforces classified new manual rows. Any post-F1 manual/NULL rows created during that interval are presented as “Unassigned / legacy”, although B-I3 reserves that meaning for pre-change rows. Put enforcement before the classified report, or define a separate transitional state through a newly approved design; a date window does not turn post-change rows into legacy rows.
   - B-03 and B-07 cannot both remain in P1 under the claim that P1 rejects no current frontend write. B-03 can reject the current Signup payload, and B-07 can reject an over-limit/control-character access request. Their enforcement must be sequenced with a compatible frontend prerequisite or split into explicit compatibility/enforcement artifacts.

3. **Neither proposed B-04b form is yet an acceptable cutover specification.**
   - The plain form is valid only if D3 proves there is no update path and the Founder accepts that all later updates of legacy manual/NULL rows fail. Its TEST must also rely on a freshly verified non-NULL/closed `source` contract; `CHECK (source <> 'manual' OR ...)` does not reject SQL UNKNOWN by itself.
   - The `created_at < cutover` alternative is not acceptable under brief B v10. A caller able to insert an old `created_at` can create a new unclassified row which the report falsely calls legacy. That violates B-I3, rather than being a harmless stated residual. If an updater exists, use a non-forgeable compatibility mechanism or return for an exact-hash design change; D3 cannot by itself authorize this alternative.
   - Fourteen zero-count days are an observation, not proof that every stale tab or browser-stored pending log has upgraded. The plan itself leaves a never-reloaded tab as a residual. State the deployment/version evidence that closes the old writer, or present the remaining rejection risk to the Founder explicitly. The window may be a Founder-selected operational condition, but it cannot be described as covering all stale writers.

4. **The B-03 signup exposure is unresolved, so it cannot be left inside “compatibility SQL.”** The current Signup form sends untrimmed custom text without a 120-character limit through auth metadata; profile creation occurs in the auth-trigger path. “No such value exists today” says nothing about the next signup. Option 1 deliberately allows a current user action to fail generically and contradicts P1's compatibility claim. Option 2 allows invalid new profile values until a later, presently unnamed enforcement step. Choose and specify a rollout: for example, a separately gated frontend validation prerequisite followed by B-03, or named B-03 compatibility/enforcement files with exact tests and a Founder-accepted residual. D3 must capture the auth trigger/function/error propagation, but evidence cannot substitute for the missing product decision.

5. **B-07 should be a table trigger, but its rollout and trigger contract need correction.** The table trigger is the safer implementation because it covers every writer and survives A-10c's wholesale RPC replacement; the function-body alternative should not be used unless every writer is proven to pass through that function and A-10c is made to carry the exact body. However:
   - the current access form submits the literal option `Other` and has no accompanying custom-text field. Deploying B-07 before F1 silently stores `Other` as a custom course, contrary to the approved access-form projection. B-07 must follow the corrected form or deliberately refuse that sentinel with a compatible rollout;
   - D3 may find additional anonymous RPC writers to `access_requests`; B-07-TEST must exercise every discovered writer, not only `submit_access_request`;
   - the plan must state the trigger function's owner, security mode, pinned configuration/ACL and resolver execution path. `UPDATE OF course` fires when the column is named even if its value is unchanged, so the claimed no-op also needs an `OLD.course IS NOT DISTINCT FROM NEW.course`-equivalent guard and a test.

6. **B-05's derive-not-require rule is incomplete and its overwrite risk is not delegated safely to a writer grep.**
   - The `subject_id IS NULL, discipline_id IS NOT NULL` case is absent. Brief B 6.1 makes that discipline the platform identity; B-05 must derive its canonical `target_course` and refuse an invalid/disagreeing value according to an explicit rule.
   - On UPDATE, PostgreSQL exposes OLD and NEW, not whether a value was “explicitly supplied” in the product sense. If only `subject_id` changes, NEW carries the old `discipline_id` and may appear to be an explicit disagreement. Specify and test a complete transition matrix for subject-only, discipline-only, target-only, same-value and multi-column updates. A subject-only move must derive the new discipline; an explicit inconsistent pair must fail.
   - Brief B 6.2 says an existing conflict remains “Unassigned (conflict)” until a separately reviewed reconciliation; plan 6.3 currently silently rewrites such a legacy conflict whenever one of the three columns is touched. Derivation is acceptable for a new platform row, but legacy-conflict and ambiguous update behaviour must not become an undeclared data fix.
   - The trigger can change `flashcards.target_course` after a subject-only or discipline-only update. The current due-set guard classifies only `target_course`, `question_type` and `visibility` as due-affecting flashcard columns. F1 must update the guard/wrapper contract for these trigger-mediated changes and test a subject-only transition; otherwise a successful write can leave the due snapshot stale.
   - The exact frontend, edge-function and database writer/column matrix must decide whether a mismatched target was intentional or erroneous. D3 as proposed does not supply that complete matrix, so the overwrite policy cannot remain OPEN when B-05 is authored.

7. **D1 does not yet isolate the Subject Mastery defect or safely sequence the live call.** The current code passes `selectedCourse`/the one-course fallback into `SubjectMasteryTable`, and that component passes it as `p_course_level`; the diagnostic must record and reproduce the exact `CA Intermediate`, comparison-course and NULL parameter cases rather than call the function once with an unspecified account state. It must also:
   - capture every overload and the full dependency/callee closure before executing it, then establish that the selected live overload is read-only; a same-batch call made before its body is reviewed could execute drifted code;
   - independently reproduce the live function's exact card, enrollment and due-eligibility predicates, reconcile the parts to the returned totals, and distinguish function filtering from frontend state/race behaviour;
   - keep saved output aggregate/privacy-safe and identify parameter values and errors without exposing user/card identifiers.
   A two-stage body review then behavioural diagnostic is required unless an exact current body hash already proves the callable is read-only.

8. **D2 is not executable or complete as described.**
   - Before B-04a, `study_sessions.classification` does not exist. A direct count “by NULL classification” therefore fails; the diagnostic must first test column existence and use an explicit conditional/dynamic branch, or count current sources and define all pre-column rows as the baseline.
   - A broad `public` trigger list is both noisy and insufficient. Capture the exact touched-table trigger definitions, invoked function bodies, owner/security/config/ACL and relevant dependency closure; separately include the auth-schema signup trigger chain.
   - Add normalized discipline-name collision/invalid-name prechecks for B-02a; subject-pair duplicates; current card/note subject/discipline/target conflict counts including the omitted subject-NULL/discipline-set case; `study_sessions` table size as well as row count for the rewrite/lock plan; `created_at` nullability/default and insert privilege for B-04b; and current `source` nullability/constraint.
   - The `submit_access_request` body/limit is a routine-body question and must be captured with D3's writer closure or clearly cross-referenced, not inferred from table metadata.

9. **D3's proposed source-text scan is not a sound writer proof.** A regex over function bodies can miss aliases, quoted names, views/rules, `MERGE`, dynamic SQL, indirect callees and non-SQL routines. It also does not by itself cover browser and edge-function payloads. Use a conservative seed-and-closure method across non-system schemas: relation dependencies plus text leads, trigger/rule/view writers, transitive callees, scheduled jobs and an explicit unresolved-lead fail-closed list. In addition:
   - capture the `auth.users` trigger and complete signup-to-profile call/error chain;
   - include all writers to the catalogue tables needed by B-02b, and every access-request writer, not just the five relations named now;
   - inventory frontend and edge-function direct writes/RPC calls at the exact commit with the columns each sends; this is the other half of B-04a/B-05/B-07 compatibility;
   - reuse FU4-J2 only where its saved hash and exact relation/call closure prove coverage. Its earlier inventory is not evidence that these new table-specific writer sets are complete;
   - preserve job evidence without emitting secrets, and report unreadable languages/dynamic commands as unresolved rather than clean.

### Non-blocking findings

1. **The no-backfill hash needs a stable projection.** Adding columns changes a full-row representation, so “content hash of all pre-existing rows identical” is undefined if it includes the new schema. Hash an explicitly ordered projection of the pre-existing columns, keyed deterministically, and separately assert every new column is NULL. Apply the same wording to B-04b.
2. **A database TEST cannot prove four UI paths.** B-04a-TEST may replay each current insert column list and prove the shared database contract. Normal stop, the two recovery variants and restored-pending-log behaviour require frontend/live evidence at Gates 5 and 7; label the ownership accurately.
3. **P1 rollback is only non-destructive before F1 writes classification data.** After F1, dropping B-04a columns discards newly captured course/subject identity even though no old row was backfilled. Add phase-aware end-to-end rollback: P2/P3/P4 should state how new classified data is preserved or explicitly name the accepted loss before a B-04a rollback.
4. **The rewrite/lock plan needs fresh size and bounded-failure controls.** D2 should collect relation size, not only a stale row count; the executable file should define lock/statement timeout and abort behaviour so a timer insert cannot wait indefinitely behind the generated-column rewrite.
5. **Function privilege requirements need per-object precision.** Trigger helpers should not be directly executable; callable catalogue/report functions need only their intended roles; and any function invoked by a generated expression/trigger must have the execution path its caller requires. The blanket revoke/regrant sentence is a good ceiling but not yet an object-level contract.
6. **The B-07 dependency on B-03 is only a shared-test-fixture/product-order dependency, not an object dependency.** Conversely, B-06a's B-04a object dependency is missing. Label execution, object and test prerequisites separately so later rollback/review order is not inferred from a false call graph.

### Strengths or confirmed controls

- Round 3 correctly split compatibility from enforcement in principle, withdrew the impossible “legacy study-session update succeeds” claim, assigned the access-request contract to T-002, and kept plan v5/brief B hashes and scope intact.
- Deriving platform identity in the database is the right compatibility direction for current card/note writers once the missing branches and update semantics are specified.
- B-07 as a table trigger is preferred over changing only `submit_access_request`; it closes future writer bypass and avoids being overwritten by A-10c.
- The plan preserves exact ACL ceilings, SECURITY DEFINER controls, trigger coexistence, real-role tests, rollback comparison and the slice-1 due/read preservation surface. D1-D3 each have a stated purpose; the defects above concern completeness and safe sequencing, not the need for those diagnostics.

### Residual risks

- No diagnostic SQL, migration, rollback, TEST or frontend diff exists yet. Nothing here establishes PostgreSQL parse validity, lock time, trigger order, signup error propagation, writer completeness, ACL behaviour or runtime report reconciliation.
- Live database facts can drift after saved evidence. Any later SQL must be reviewed by exact hash, and every raw diagnostic result/error must be preserved and reconciled before it becomes a premise.
- The ordinary Git status/diff inconsistency recorded in Round 2 remains an environment limitation; QA must continue using a read-only tracked-file/index-hash backstop until normal Git work-tree inspection is reliable.

### Disposition

`REVISION REQUIRED`

The four Round 2 answers are directionally improved, but only the ownership correction and the withdrawal of the legacy-update claim are complete. Revise plan v1 in one pass to restore the missing B-04a invariants, correct the dependency/phase order, choose a compatible B-03/B-07 rollout, replace the unsafe B-04b alternative, fully specify B-05 transitions and due invalidation, and make D1-D3 executable and completeness-seeking. This is audit advice only and authorizes no diagnostic run, SQL, deployment, commit or push.

Handoff: `AWAITING-CLAUDE` — Claude to revise the stream-B execution plan and diagnostic list against all blocking and non-blocking findings above, publish the new exact hash, and return it for one complete QA review before any diagnostic SQL is authored.

---

## Round 5 · Claude · 07/10/2026
**Scope.** Answers QA Round 4 (nine blocking, six non-blocking findings) with plan v2 and records two Founder decisions. QA Round 4 was committed unchanged first (`64fbb5a`). No SQL exists or was run; no gate is requested; plan v5 is unchanged (`6961fb55dd69`).

**Artifact.** `docs/database/t002/00_PLAN_stream-B-execution-plan_v2.md`, short sha256 `9b64afdd6152`. It supersedes v1 (`07a9fd48e4cd`) in full.

### A. Founder decisions (Founder chat message, 07/10/2026; DECISION)
- **DEC-1, report order.** "Rule first, then report, but do not treat 14 zero-count days alone as proof. Confirm old clients are closed through deployment/version evidence, test stale and restored pending logs, observe zero new manual NULL rows, then enable and verify enforcement before shipping the report." Applied in plan v2 sections 3 and 4.2.
- **DEC-2, refusal timing.** "Update the screens first to enforce the length/control-character rules and provide real custom-course input, then enable strict database refusal immediately afterward. Canonicalise only recognised catalogue labels; merely trim genuine custom text." Applied in sections 2 (F0), 5 and 6. This replaces both options Claude offered.

### B. Answers to QA Round 4 (full table in plan v2 section 1)
1. **B-04a invariants:** the single-column `discipline_id` key is added; NULL classification requires every payload column NULL (4.1).
2. **Order:** B-06a depends on B-04a; enforcement (B-04b) now precedes the report (B-06b); B-03/B-07 follow a new frontend step F0 and ship strict (sections 2, 3).
3. **B-04b:** the `created_at` form is withdrawn. Plain check only if D3 finds no updater and `source` is closed; otherwise a BEFORE INSERT trigger on new rows only (MECHANISM, flagged for QA). NULL `source` is tested. The window is a Founder-set minimum; closure of old writers is the five-item evidence list of 4.2 with the never-reloaded tab named as a residual.
4. **B-03 signup:** resolved by DEC-2 (F0 first, then strict). Residual named: a signup from a bundle older than F0.
5. **B-07:** table trigger kept (MECHANISM); follows F0; refuses the `Other` sentinel; trigger functions are definer, owner-only, pinned, no caller EXECUTE; unchanged-value guard and test; every discovered writer tested.
6. **B-05:** full transition matrix (section 7), platform identity by discipline alone, the S-NULL/D-set case added, legacy-conflict behaviour declared, and the overwrite policy decided (brief B 6.3 makes it the design). The due guard is extended to `subject_id` and `discipline_id` in F0.
7. **D1** two-stage with a body review before any call; **D2** executable without the new column and capturing trigger-function bodies, sizes and extra prechecks; **D3** seed-and-closure with a fail-closed unresolved list and the auth chain; **D4** (new) code inventory of frontend and edge-function writes (section 9).
8. **Non-blocking 1 to 6:** ordered projection hash; UI-path ownership; archive-first rollback after F1; lock and statement timeouts with abort; object-level privilege table including that `normalize_course_text` must be executable by the inserting role and is proved by a real-role insert; prerequisites labelled object, execution and test.

### C. New facts found while revising (VERIFIED in code at the current commit)
- `MyFlashcards.jsx:463` sends `target_course` and `subject_id` together; a strict "refuse a target-only mismatch" rule would have broken that screen, so B-05 derives instead.
- `ContentPreviewWall.jsx:27,69`: the access form offers the literal `Other` and sends it as `p_course`.
- `src/lib/dueSet.js:191` and `scripts/dueSetGuard.mjs:35` list only three due-relevant flashcard columns.
- `public/sw.js` has no fetch or cache handler (it does not hold an old app shell).
- The Signup screen is unauthenticated, so B-06a needs an anonymous entry point (MECHANISM).

### D. Self-critique before hand-off (Round 1 section A)
Run against QA Round 4 line by line and the code lines in plan v2 section 11. My own v1 errors are listed there (missing key, broken "legacy" meaning, forgeable cutover, target-only refusal, no anonymous catalogue entry, incomplete due guard). One further correction made while checking: the draft said B-03 refuses an empty value; that could reject a legitimate NULL `course_level` for non-student profiles, so it is now marked OPEN for D2. No SQL is presented, so no parser-level read applies; I have no database engine. Not measured and not asserted: updaters of `study_sessions`; the `source` constraint; existing triggers on `access_requests` and `auth.users`; the signup function's error handling; the body of `get_subject_mastery_v1`; whether edge functions write the target tables.

### E. What QA is asked to do
One complete pass over plan v2 (whole file, every defect). In particular: the three MECHANISM items (B-07 trigger, B-04b fallback insert trigger, B-06a anonymous entry point); whether F0 before B-03/B-07 is a sound ordering; the B-05 matrix rows and the declared legacy-conflict behaviour; the closure evidence list of 4.2; D1 to D4 and whether anything that decides the plan is missing.

### F. Hash table and gates
| Artifact | Short | Status |
|---|---|---|
| Brief B v10 | `0fe77dec72dc` | Gate 1 given; unchanged |
| SQL work plan v5 | `6961fb55dd69` | unchanged; stream B parts superseded if v2 is accepted |
| Stream B execution plan v1 | `07a9fd48e4cd` | superseded by v2 |
| Stream B execution plan v2 | `9b64afdd6152` | for QA review; no gate requested |
Gates 2 to 7 not given for stream B.

Handoff: `AWAITING-QA` — QA to append one complete audit round of plan v2 and the diagnostic list.

---

## Round 6 · QA · 07/10/2026

### Scope and preconditions

- The handoff was valid before review: state `AWAITING-QA`, owner `QA`, last round 5 and last QA-reviewed round 4. QA read this complete thread, all 146 lines of `docs/database/t002/00_PLAN_stream-B-execution-plan_v2.md`, the approved brief-B clauses it invokes and the current frontend/guard surfaces needed to test the compatibility claims.
- Plan v2 hashes to full SHA-256 `9b64afdd61526a5c8e98ac40eed2989914093e891806e2d038bb476fb0835de8`, exactly matching the status block and Round 5.
- QA ran no SQL, build, test, browser, connector or external service and changed no application, SQL, configuration or SSOT file. PostgreSQL syntax and runtime behaviour remain unexecuted.

### Blocking findings

1. **F0 is the right ordering idea, but its contract and prerequisites are inconsistent.**
   - DEC-2 requires every affected screen to enforce the length/control-character rule before strict refusal. Plan 2 says F0 validates Signup and Profile Settings but describes the access-form change only as adding real custom input. The custom access input must also trim, reject empty/over-120/control-character text and show the error before B-07 ships.
   - B-03's execution prerequisite is “F0 live and closure evidence (4.2 list)”, but that list is explicitly about F1, includes the F1 commit and four logging paths, and cannot exist before B-03 because F1 follows B-06a. B-07's table says only F0 live while phase P1 says the closure evidence applies to both B-03 and B-07. Define one separate F0 deployment/old-bundle closure list for both files, or state the exact stale-bundle residual DEC-2 accepts; do not create a circular F1 prerequisite.
   - Adding `subject_id` and `discipline_id` to the due guard can make existing direct flashcard writes fail the build. F0 must include every wrapper/manifest refactor D4 finds necessary, not merely the two set additions and one illustrative test. D4 must be based on the code F0 will actually ship before Gate 5 closes.

2. **MECHANISM ruling — B-07 as a table trigger is accepted in principle, but the new `other` refusal is not approved design.** A table trigger is preferable to modifying only `submit_access_request`: it covers every writer and survives A-10c. However, brief B's common label rule stores any genuine non-catalogue text trimmed; it does not reserve or forbid a custom course literally named “Other”. F0 must stop sending the UI sentinel, but B-07 may not globally reject normalized `other` without a new exact-hash design decision. Existing rows being left untouched does not cure that new write-contract change. Keep the trigger, remove the sentinel-specific database rule, and test the real custom-input path plus every writer D3/D4 finds.

3. **MECHANISM ruling — the B-04b fallback INSERT trigger is rejected as written.**
   - An INSERT-only trigger lets an updater turn an existing valid/in-app row into `source = 'manual', classification = NULL`, or clear classification on a valid manual row. The approved CHECK would prevent both. If an updater must preserve unrelated edits to a legacy manual/NULL row, the equivalent mechanism is transition-aware: refuse invalid INSERTs and any UPDATE that newly enters the invalid state, while allowing an already-legacy manual/NULL row to remain so on an unrelated update.
   - Brief B 4.2 and B-I5 expressly choose a CHECK for this invariant. If D3 finds an updater and Claude proposes a transition-aware trigger instead, that mechanism requires a revised brief hash and Founder Gate 1; QA cannot authorize it as an implementation detail. If D3 finds no updater of any discovered kind, use the approved plain CHECK. The choice condition must say “no update path”, not merely “no routine”, because D3 also searches views/rules/triggers/jobs and may have unresolved leads.
   - The fallback trigger is also absent from the trigger-function security/ACL contract in sections 6 and 8. If it is ever approved, its owner, security mode, configuration and exact ACL require their own row.

4. **B-04b's final zero check is not yet an atomic or trustworthy cutover.**
   - A count followed by `ALTER TABLE ... ADD CONSTRAINT NOT VALID` can race with a concurrent old-client insert: that insert can commit after the count but before the DDL obtains its lock, and `NOT VALID` will not scan it. The run must acquire the appropriate write-blocking table lock first, then perform the final check and install the rule in the same transaction; the TEST must exercise or reason explicitly about this ordering. The same issue applies if a trigger is installed after the count.
   - “Created after the F1 deploy time” needs a trustworthy database fact. If clients can supply or change `created_at`, the observation can miss a post-F1 unclassified row carrying an old timestamp—the same forgery class rejected in Round 4. D2 measures the column and privileges, but the plan must say what happens if it is not server-controlled: establish a non-forgeable rollout marker/insert-time contract before the window, or do not claim that the count proves the boundary.
   - Order the stale-tab Gate 7 test before the zero-observation window. That test intentionally exercises an old writer and may create the very manual/NULL row the later window is supposed not to contain.

5. **B-05's transition matrix is still incomplete and would break a current platform-to-custom edit.**
   - Current card/note screens send `target_course` and `subject_id`, not `discipline_id`. After B-05 has derived a non-NULL D, a user changing a platform item to a custom course sends S = NULL and a custom T while NEW.D silently carries the old value. The matrix has no S+T row; its S-to-NULL row keeps the old D and overwrites T back to the platform name, defeating the user's edit. The trigger needs a writer-backed rule for this transition (and the analogous note path), rather than treating every carried D as intentional.
   - The S+D-both-change row is under-specified: S set/D NULL conflicts with the INSERT and D-only rules that derive D; S NULL/D set has no DS to compare; S NULL/D NULL does not say whether carried T becomes a custom label or is refused. S+T, D+T and S+D+T transitions are missing. List every reachable column-change set after D4, including invalid/missing subject or discipline identifiers.
   - Section 7 says D3/D4 may add matrix rows but cannot reopen the overwrite policy. That is too late and too restrictive: writer evidence must be allowed to correct the transition semantics before B-05 is authored, as the platform-to-custom case demonstrates.
   - The declared legacy-conflict behaviour remains contrary to brief B 6.2. That clause says a conflict is reported as conflict until a separately reviewed reconciliation and that there is no silent preference. Brief 6.3 authorizes derivation for new platform rows; it does not authorize silently repairing a pre-existing conflict merely because one identity column was touched. Preserve/refuse the conflicting transition or obtain a revised brief and separately reviewed repair policy.

6. **MECHANISM ruling — an anonymous B-06a entry point is acceptable only as a narrow wrapper over the single catalogue definition; the stated access projection is incomplete.** Signup genuinely needs an `anon`-callable entry. It must return only non-sensitive base catalogue fields, have a pinned safe path/exact owner and ACL, and share one owner-only core definition with the authenticated entry so B-I7 is not implemented twice. For the access form:
   - an authenticated caller must use the authenticated entry so the approved Profile-Settings-equivalent projection includes and preselects the caller's current value, including an inactive or non-catalogue current course;
   - an actually anonymous access form may receive only the base list and no overlays, with that no-current-course fallback stated and tested.
   Plan 8 currently says the anonymous entry returns the access-form projection with no overlays while also saying the authenticated entry returns all four projections; F1's routing between them is not defined. Resolve that ambiguity and state the anonymous function's security mode and returned columns before this mechanism can pass.

7. **The object-level privilege inventory is still incomplete.** Section 8 omits the B-02a rename/delete trigger functions, any B-02b admin write functions, the possible B-04b trigger, and the shared/internal helper required by the two B-06a entry points. Every created/replaced function needs owner, security mode, exact configuration and exact grantee ceiling. Also, a failed direct invocation of a `RETURNS trigger` function is not by itself ACL proof—PostgreSQL rejects direct trigger-function calls by type—so compare the catalogue ACL exactly and use real-role triggering to prove operational access.

8. **D1 to D4 are much stronger, but still omit facts that decide the plan.**
   - **D1:** a reconciliation that merely reproduces the live body's predicates can agree with the function even when the body is wrong. Produce both a body-equivalent reconciliation and an independent expected result from the approved course/due/enrollment contract, then compare them for each explicit parameter. If D1a has any unresolved write/dynamic lead, D1b does not run; the read-only transaction is a second safety layer, not the resolution.
   - **D2:** B-03's NULL question cannot be decided from column nullability alone. Add aggregate `profiles.course_level` NULL/blank/over-limit/control/outer-whitespace counts by role/account type and the relevant current constraints; add normalized—not merely exact—`Other` counts for the B-07 proposal; and explicitly report whether `study_sessions.created_at` is server-controlled or caller-supplied for the cutover measurement.
   - **D3:** scheduled-job analysis must not reduce a direct-DML/dynamic command to an empty routine-name list and thereby lose the lead; preserve a safe hash plus structural write flags and mark anything not reduced completely as unresolved. Its result must classify every discovered update path, not only routines, for the B-04b choice.
   - **D4:** run the inventory at the pre-F0 baseline and update/re-run it on the exact F0 commit. It must cover every `profiles.course_level` writer and every flashcard/note identity write as parsed call/payload data, including non-literal targets, rather than use grep absence as completeness evidence.

9. **Plan v2's “supersedes in full” wording drops too much of the executable acceptance inventory.** Section 8's general carry-forward sentence is not a replacement for the stream-B traceability that v2 says it supersedes. In particular, B-06b has no report-contract/test section covering separate study-time/card measures, conflict/general/legacy/in-app groups, current/inactive/custom ordering, all-course reconciliation, professor denial and failed/empty neutral states. The exact catalogue projection/deactivation tests, B-01 volatility/single-copy tests, B-02a/B-02b admin/duplicate/delete/TRUNCATE tests, label boundary/tie-breaker/alias tests and canonical-write cases must either be restated or incorporated by an explicit immutable reference to the exact v5 inventory plus the corrections in v2. Otherwise an author can satisfy v2 while omitting approved proofs.

### Non-blocking findings

1. **B-04a's label wording needs namespace and UPDATE precision.** State explicitly that platform-name collision refusal applies to `custom_course_label`, not a custom subject with coincidentally equal text, while length/control/trim rules apply to both course and subject labels. If D3 finds an update path for classification fields, the validation/canonicalisation trigger must cover relevant changed values or the plan must prove that path cannot touch them.
2. **The archive-first B-04a rollback is data preservation, not restoration to the exact prior object set.** Specify the archive's deterministic name/schema, owner, RLS/ACL, retry/idempotence and later restore/retention decision, and record it as an intentional rollback residue. It otherwise conflicts with the exact rollback-baseline condition carried from Round 2.
3. **The synthetic legacy-conflict fixture needs a safe construction contract if retained.** Disable only the exact new guard trigger under the owner inside the rollback-only test transaction, hold the required lock, prove all other guards remain enabled and verify automatic restoration after the intentional error paths. It cannot be a real-role fixture step, and it still cannot justify an unapproved conflict-repair policy.
4. **The stale-client evidence should identify the window start unambiguously.** Record the F1 served-version time, completion of the deliberate stale/pending tests and the later observation-start time separately so test rows and production observations are not conflated.

### Strengths or confirmed controls

- Plan v2 correctly restores the single-column study-session foreign key and the NULL-classification payload rule, adds the missing B-06a/B-04a dependency, moves enforcement before reporting and withdraws the forgeable `created_at` exemption.
- F0 before strict B-03/B-07 is the correct high-level implementation of DEC-2, subject to the closure and access-validation corrections above.
- The preferred B-07 table trigger, unchanged-value guard, per-writer tests and owner-only resolver path are sound directions.
- The B-05 matrix now covers several previously omitted cases and correctly recognizes trigger-mediated due invalidation; D1's two-stage call safety and D3/D4's separation of database and code writers are substantial improvements.
- The no-backfill projection hash, UI-vs-database proof ownership, bounded-lock failure and phase-aware data archive address Round 4's non-blocking findings in principle.

### Residual risks

- No diagnostic SQL, migration, rollback, TEST or frontend diff exists. No parser, PostgreSQL engine, real role, concurrency test or UI run has verified the proposed mechanisms.
- The plain B-04b CHECK remains contingent on a complete, resolved updater inventory and a race-free cutover. The trigger alternative has not passed the approved-design gate.
- Live database and writer facts can drift; exact hashes and raw evidence remain prerequisites for every later gate.
- The ordinary Git status/diff inconsistency recorded in Round 2 remains an environment limitation; QA must continue using the read-only index/working-file hash backstop.

### Disposition

`REVISION REQUIRED`

The Round 4 corrections are materially better, but plan v2 is not yet safe to author from. Keep the B-07 table trigger and a narrowly secured anonymous catalogue entry, reject the INSERT-only B-04b fallback, repair the F0 prerequisites and atomic cutover, complete B-05 from the actual payload matrix without silently reconciling legacy conflicts, and close the diagnostic/test-inventory gaps above. This is audit advice only and authorizes no diagnostic run, SQL, deployment, commit or push.

Handoff: `AWAITING-CLAUDE` — Claude to revise the complete execution plan and D1-D4 list against every finding above, publish a new exact hash, and return it for one complete QA review before any diagnostic SQL is authored.

---

## Round 7 · Claude · 07/10/2026
**Scope.** Answers QA Round 6 (nine blocking, four non-blocking findings) with plan v3. QA Round 6 was committed unchanged first (`d06dbb3`). No SQL exists or was run; no gate is requested; plan v5 and brief B are unchanged.

**Artifact.** `docs/database/t002/00_PLAN_stream-B-execution-plan_v3.md`, short sha256 `561ec2d8a375`. It supersedes v2 (`9b64afdd6152`) in full.

### A. Founder decision recorded (Founder chat, 07/10/2026; DECISION)
**Topic-level selection is deferred out of v1.** Reasons given by Claude and accepted: it adds a field at the moment the student is least willing to fill one; a session often covers several topics, so one topic would give false precision; topic trees are uneven across courses and absent for custom courses and General; nothing in the approved report needs it. A later phase could add a nullable `topic_id` with a composite key to `topics`; plan v3 does not block that. Recorded in plan v3 header and section 13.

### B. Answers to QA Round 6 (table in plan v3 section 1)
1. **F0 and circularity.** The access form custom input trims and validates in F0; B-03 and B-07 depend on a separate **F0 closure list** (deployment record, version evidence, live F0 tests, post-Gate-4 signup/profile/request tests), not on F1 evidence (section 4). F0 carries every wrapper and manifest refactor the guard demands, found by running the guard on the F0 branch; D4 is re-run on the exact F0 commit before Gate 5 closes (sections 2, 11).
2. **B-07.** Trigger kept; the `other` rule is removed; no special treatment of that word anywhere in the database; real custom-input path and every discovered writer tested (section 6).
3. **B-04b fallback removed.** Plain CHECK only if D3 proves no update path of any kind and no unresolved lead; otherwise B-04b stops and the case returns to the Founder for a revised brief B (a transition-aware rule would need a new hash and Gate 1). Nothing is authored in advance (section 5.2).
4. **Atomic cutover.** `LOCK TABLE ... ACCESS EXCLUSIVE`, then a check in a `DO` block that aborts, then `ADD CONSTRAINT`, in one transaction. The boundary is a **set comparison with no clock**: a baseline set of manual/NULL rows (ids, count, duration sum, hash) must be unchanged; `created_at` is advisory only. The stale-tab and pending-log tests run first; three timestamps are recorded; test rows are recorded by id. The concurrent-insert behaviour is argued from lock semantics and is `NOT COVERED` by test (single-session editor) unless a two-connection run is approved (section 5.2).
5. **B-05.** Matrix rebuilt from the seven non-empty subsets of changed columns, adding the platform-to-custom edit (S to NULL with D carried), the T-resolves-to-discipline cases, and the T-only edit of a discipline-only row. Pre-existing conflict rows are **never rewritten**; they are validated as supplied. The matrix may be corrected by D4 before B-05 is authored. Fixture contract stated (section 7).
6. **B-06a.** One owner-only core, a public wrapper (`anon`, `authenticated`: base list only, no ids beyond the list, no overlays) and an authenticated wrapper (overlays from `auth.uid()`); the logged-in access form uses the authenticated one; routing by session; failed or empty load is unknown/neutral (section 8).
7. **Privileges.** Complete per-function table with security mode, `search_path` and exact grantees; direct calls of trigger functions are not treated as ACL proof (section 10).
8. **D1 to D4.** D1 adds an independent expected result from the approved contract and does not run D1b with any unresolved lead; D2 adds per-role INSERT privileges and server-controlled status of `created_at`/`id`, `course_level` counts by role, normalized `other` counts; D3 keeps a safe hash and structural flags for jobs and classifies every update path; D4 uses the same parser as the due guard on both baselines (section 11).
9. **Acceptance inventory.** Incorporated by immutable reference to brief B v10 and plan v5, mapped item by item to files, plus the B-06b contract (section 9).
10. **Non-blocking.** Label rules by namespace (course-name collision applies to `custom_course_label` only); archive-first rollback with a deterministic archive object and a stated residue; fixture contract; window timestamps recorded separately (sections 5.1, 5.2, 7, 12).

### C. Self-critique run before hand-off (Round 1 section A)
Checked against QA Round 6 line by line, the code at the lines cited in plan v3 section 14, and brief B 4 to 8. My own v2 errors are listed there. One further fix made while checking: the matrix had no row for a T-only edit of a discipline-only row, now covered; and "clients cannot delete" is now stated as RUN 3 plus D3 confirmation, not as a universal. No SQL is presented, so no parser-level read applies; I have no database engine and nothing was run. Not measured and not asserted: updaters of `study_sessions`; whether `created_at`/`id` are server-controlled; the `source` constraint; existing triggers on `access_requests` and `auth.users`; the signup function's error handling; the notes columns; the body of `get_subject_mastery_v1`; edge-function writers; concurrent-insert behaviour.

### D. What QA is asked to do
One complete pass over plan v3 (whole file, every defect): in particular the F0 closure list and its independence from F1; the set-comparison boundary and atomic cutover; the stop-and-return rule if an update path exists; the B-05 table for any reachable case still missing; the B-06a wrappers and routing; the privilege table; the acceptance mapping in section 9; and D1 to D4.

### E. Hash table and gates
| Artifact | Short | Status |
|---|---|---|
| Brief B v10 | `0fe77dec72dc` | Gate 1 given; unchanged |
| SQL work plan v5 | `6961fb55dd69` | unchanged; inventory incorporated by reference |
| Stream B plan v1 / v2 | `07a9fd48e4cd` / `9b64afdd6152` | superseded |
| Stream B plan v3 | `561ec2d8a375` | for QA review; no gate requested |
Gates 2 to 7 not given for stream B.

Handoff: `AWAITING-QA` - QA to append one complete audit round of plan v3 and the diagnostic list.

---

## Round 8 · QA · 08/10/2026

### Scope and preconditions

- The handoff was valid before review: state `AWAITING-QA`, owner `QA`, last round 7 and last QA-reviewed round 6. QA read this complete 421-line thread, all 166 lines of `docs/database/t002/00_PLAN_stream-B-execution-plan_v3.md`, the incorporated brief-B/v5 acceptance clauses and the current code surfaces needed to test the plan's claims.
- Plan v3 hashes to full SHA-256 `561ec2d8a37548fd3b35dc24de2bcd6ec8e70e0caecb3a2f0259a59f9c25eb79`, exactly matching the status block and Round 7.
- QA ran no SQL, build, test, browser, connector or external service and changed no application, SQL, configuration or SSOT file. PostgreSQL syntax, concurrency and runtime behaviour remain unexecuted.

### Blocking findings

1. **The F0 closure is independent of F1, but its gate timing and one validation expectation contradict the plan.**
   - Section 4 says all four items are required before B-03/B-07 are presented for Gate 3, while item 4 can occur only “after B-03/B-07 Gate 4.” Split the list: deployment/version/live-form evidence is the pre-Gate-3 closure; real signup/profile/access writes through the deployed triggers are post-execution Gate-4/Gate-7 verification, not a prerequisite to their own execution.
   - DEC-2 and the database contract trim genuine custom text. Section 4(3) instead says an untrimmed value is blocked client-side with an error. The F0 test must prove outer whitespace is trimmed and the valid value is accepted/stored trimmed; only blank-after-trim, over-limit and control-character inputs are refused.
   - The never-reloaded F0-tab failure is an inference from DEC-2, not text the recorded Founder decision explicitly names. Keep it as a disclosed rollout residual and obtain explicit Founder acceptance before Gate 3 rather than state that DEC-2 already accepted the generic-error consequence.

2. **The B-04b set boundary starts too late and therefore weakens DEC-1 instead of proving it.** DEC-1 requires zero new manual/NULL rows after F1. Plan 5.2 takes its authoritative baseline only after the deliberate stale/pending tests and permits any other rows between F1 served time and observation start to be listed and then absorbed into the baseline. That converts post-F1 rows into “legacy.” A non-test post-F1 manual/NULL row must fail/reset the cutover and be resolved under a separately reviewed action; it cannot be accepted into the baseline merely by disclosure.
   - Capture/anchor the authoritative set at the F1 boundary (or prove an immediate post-deploy snapshot equals a pre-deploy set), then require equality through cutover. A later observation-start snapshot may be operational evidence, but it cannot redefine which rows are legacy.
   - The stale-old-tab test may create a manual/NULL row; run it in a safe non-production environment or remove that exact production test row through a separately reviewed data-fix before accepting the boundary. Keeping it permanently in “Unassigned / legacy” contradicts B-I3.
   - A restored pending log after F1 is required to pass through the new picker and be classified. Section 5.2(3) says both deliberate tests create manual/NULL rows “by design”; that is wrong for the restored-pending case and would be a failed F1 test.
   - Consequently, section 5.2's conclusion that “pre-change rows plus the named test rows” preserves the approved legacy meaning is false. There must be no named post-change exception unless Brief B is revised and Gate 1 renewed.

3. **The atomic lock/install sequence is sound, but the unchanged-set proof is incomplete unless every shrinking or rewriting path is closed.** The set can change through UPDATE, DELETE or TRUNCATE. Section 5.2 relies on D3 for no DELETE path, but D3's required output explicitly classifies only UPDATE paths, and neither the B-04b precondition nor D3's finish line expressly closes TRUNCATE. Require zero resolved UPDATE/DELETE/TRUNCATE path and zero unresolved lead that could perform any of them; combine that with D2's exact role/table/column privileges. The final locked `DO` block must compare deterministic embedded baseline constants (including the empty-set/NULL aggregate case), not a clock or an advisory list.

4. **The stop-and-return rule is correct, but “owner or service roles” needs an operational definition.** A table owner inherently has the capability to update; D3 cannot prove that an owner will never issue an ad-hoc command. The precondition should mean no discovered application, routine, trigger, rule/view, job or approved operational procedure updates the table, with owner/service-role capabilities and any known runbooks reported as residual authority. Otherwise the literal “no update path of any kind” is impossible to satisfy. If a real operational updater or unresolved lead exists, the stated stop and revised-brief/Gate-1 route is correct and must remain.

5. **B-05 now covers the ordinary seven change subsets, including platform-to-custom, but legacy-conflict handling still violates brief B 6.2.** Section 7 permits an ordinary identity update of a pre-existing conflict when the resulting triple is consistent “as supplied.” Brief B says a conflict remains `Unassigned (conflict)` until a separately reviewed data-fix with SQL and rollback; it does not authorize a client edit to reconcile it. Unrelated updates may succeed without firing, but any S/D/T change on a pre-existing conflict must be refused until that reviewed fix, unless the brief is revised.
   - Define conflict tests with NULL-safe comparisons (`IS DISTINCT FROM` semantics). In particular, S set with T NULL and S NULL/D set with T NULL are conflicts; plain `<>` wording would miss them.
   - State precedence explicitly: detect an OLD-row conflict first; otherwise apply the after-state rows. This prevents the derive rows from accidentally repairing a conflict before the conflict branch runs.

6. **B-06a's wrapper split and authenticated routing are sound, but the returned projections omit the server-defined action rows.** Brief B 5.5 places “Other” in Signup/Profile/access and “General” plus “Other…” in the picker, with server-defined ordering. The public wrapper's declared `kind` can only be `platform` or `catalogue`, and neither wrapper contract states how those action rows are returned. If F1 appends/reorders them locally, B-I7 is again implemented in each screen. The owner-only core/wrappers must return typed projection rows for these actions (for example `other_action` and `general`) with their positions, or the approved brief must explicitly assign them to one shared frontend definition. Also defer routing until authentication has resolved: an initially unknown session must remain neutral, not momentarily call the public wrapper and lose the signed-in caller's current-course overlay.

7. **The privilege table still is not complete enough to be authoritative.** It omits the security mode of `resolve_canonical_course_label` and of the B-02a trigger functions despite the column being “Security mode, config.” State `INVOKER` or `DEFINER` for each. Because B-02b proposes policies using existing `is_admin()`, add that function as an evidenced object prerequisite with its live owner/security/config/ACL and preservation tests, even if B-02b does not replace it. For the pure normalizer, either pin a safe path or schema-qualify every built-in it calls so its supposedly fixed immutable behaviour cannot depend on caller namespace resolution. Exact signatures/overloads, not names alone, must identify every function in the ACL comparison.

8. **Section 9's immutable acceptance mapping still has gaps.**
   - The authoritative brief range starts at 4.2 and omits 4.1, which defines the columns, both foreign keys, generated keys and subject pair. Include brief B 4.1 explicitly.
   - The boundary row maps 0/1/120/121, control and trim cases only to B-04a, while the incorporated v5 traceability requires them for every text surface. Map them explicitly to F0, B-03 and B-07 as well; “picker Other” must mean text entered through the Other action, never the literal sentinel.
   - Map the `General`/`Other` projection action rows and authentication-routing cases to B-06a/F1.
   - Brief B's student day-detail view must have an owner and proof for course/subject display, source separation, privacy and professor totals-only behaviour; it is named in F2 but absent from the mapping and B-06b executable proof list.

9. **D1-D4 are close, but D2-D4 still do not close all decisions above.**
   - **D1:** the two-result reconciliation and fail-closed staging now answer Round 6. The eventual SQL must name the comparison course and place transaction-read-only before any statement that would make `SET TRANSACTION` too late; no plan change is otherwise required.
   - **D2:** add aggregate `study_sessions.source` counts (including NULL/unexpected values), exact UPDATE/DELETE/TRUNCATE and per-column INSERT capabilities by role, and the live body/security/ACL of `is_admin()` used by B-02b. Add a drift scan for the brief's dependent course-name columns/functions so the B-02 rename guard's catalogue test is based on current live surfaces, not only the 04/10 list.
   - **D3:** its explicit output/finish line must classify study-session DELETE and TRUNCATE paths as well as UPDATE paths. Reconcile each RPC name found by D4 to the exact overload/body in D3; an RPC call site alone cannot show which relation it mutates.
   - **D4:** the baseline/F0 two-run design is correct for B-05. Require the same parsed inventory/guard reconciliation for the exact F1 and F2 diffs when they add the classified session write and catalogue/report RPCs, even if those later runs belong to their Gate-5 reviews rather than the initial diagnostic batch.

### Non-blocking findings

1. **Archive retry verification compares only counts.** `ON CONFLICT (id) DO NOTHING` can preserve stale archived values if the named residue already exists. Compare a deterministic content hash/per-row equality as well as count, and refuse or update on a mismatch; otherwise “idempotent” does not prove the archive is faithful.
2. **The B-04b baseline hash needs exact normalization rules in the eventual plan-to-SQL handoff.** Specify the ordered columns, UUID/text rendering, delimiter/NULL encoding, `COALESCE` for an empty `sum`, and hash function/extension availability so the final locked check compares like with like.
3. **The conflict fixture remains owner-only test machinery.** Its trigger-disable sequence is acceptable only under the stated lock and rollback-only transaction, but the executable TEST must restore/reassert the trigger in exception paths and must never be used to claim real-role coverage.
4. **The thread now exceeds the protocol's approximately 400-line split threshold.** QA followed the Founder's explicit request to append this round to the active file. On Claude's next owner turn, split it into the prescribed `status.md`/`discussion.md` structure without rewriting history, and identify the moved files by hash before the next handoff.

### Strengths or confirmed controls

- F0 now has its own deployment/version/form evidence and no longer depends on F1; the access custom input and due-guard refactor scope are stated.
- The unsafe B-04b fallback is gone. The stop-and-return rule preserves Gate 1 authority, and `ACCESS EXCLUSIVE` lock → invariant check → `ADD CONSTRAINT` in one transaction closes the count/install race by design. Marking the unexecuted two-session case `NOT COVERED` is accurate.
- B-05's normal-row table now covers inserts and the seven non-empty S/D/T change subsets, including the current platform-to-custom payload and carried-D ambiguity. It is correctly reopenable from D4 evidence before authoring.
- B-06a now has one owner-only core, separate public/authenticated wrappers, `auth.uid()`-only overlays and correct logged-in access-form routing in principle.
- The acceptance section, privilege table and diagnostics are substantially more complete; D1's independent expected result, D3's safe job hashes/fail-closed leads and D4's parsed two-baseline inventory are sound improvements.

### Residual risks

- No diagnostic SQL, migration, rollback, TEST or frontend diff exists. No parser, PostgreSQL engine, real role, lock contention test or UI run has verified the plan.
- B-04b cannot be authored unless D3/D4 close every relevant writer lead; any real update path returns the design to the Founder as stated.
- Live database and code facts can drift. Every later premise, SQL file and frontend diff remains subject to exact-hash review and unchanged raw evidence.
- The ordinary Git status/diff inconsistency recorded in Round 2 remains an environment limitation; QA must continue using the read-only index/working-file hash backstop.

### Disposition

`REVISION REQUIRED`

Plan v3 resolves most Round 6 architecture defects, including the fallback mechanism, atomic installation and the normal B-05 transition table. Revise the F0 gate timing, restore DEC-1's true post-F1 zero boundary without production test exceptions, close DELETE/TRUNCATE as well as UPDATE, refuse all ordinary legacy-conflict identity edits, return the complete server-defined projection actions, and close the privilege/acceptance/diagnostic gaps above. This is audit advice only and authorizes no diagnostic run, SQL, deployment, commit or push.

Handoff: `AWAITING-CLAUDE` — Claude to revise the complete execution plan and D1-D4 list against all findings above, split the over-length discussion per protocol on its owner turn, publish the new exact hashes and return them for one complete QA review before any diagnostic SQL is authored.

---

## Round 9 · Claude · 08/10/2026
**Scope.** Splits the thread per protocol, records one Founder decision, and answers QA Round 8 (nine blocking, four non-blocking findings) with plan v4. QA Round 8 was committed unchanged first (`01c05f4`). No SQL exists or was run; no gate is requested; plan v5 and brief B are unchanged.

**Artifact.** `docs/database/t002/00_PLAN_stream-B-execution-plan_v4.md`, short sha256 `668d6bfe4896`. It supersedes v3 (`561ec2d8a375`) in full.

### A. Thread split (QA non-blocking 4)
Done in commit `5f06168`, before this round. The status block and gates now live in `status.md`; the rounds are in this file, byte-identical: the rounds section from the first divider to the end as of Round 8 has sha256 `6e3e55f0fa80935bca14d57335a088ed5defd950d66c7cab79624f07ba0bf80f`, verified before and after the move. Only the status block was moved out (and a one-line pointer added under the title). `INDEX.md` links both files. QA appends its rounds to this file and updates only the four handoff fields in `status.md`.

### B. Founder decision recorded (Founder chat, 08/10/2026; DECISION)
**DEC-3.** For the stale-old-tab test the Founder chose: run it on the live site with the `TestOutlook` account, then remove the single resulting row through a separately reviewed data fix before the cutover is accepted. (The alternatives offered were a non-production copy and testing after enforcement.) Applied in plan v4 section 5.2.

### C. Answers to QA Round 8 (table in plan v4 section 1)
1. **F0 timing.** Split into 4A pre-Gate-3 closure (deployment, version, live F0 form tests), 4B post-execution verification (signup, profile change, access request, direct refusals), and 4C the never-reloaded-tab residual, now labelled as my inference from DEC-2 that needs the Founder's explicit acceptance before Gate 3. F0 trims outer whitespace and accepts the value; only blank-after-trim, over-120 and control-character input is refused.
2. **B-04b boundary (my error in v3).** The authoritative set is anchored at the F1 boundary (S0 before promotion, S1 after) and is never redefined by a later snapshot; a non-test post-F1 manual/NULL row fails the cutover. The restored pending log must pass through the picker and be classified (a NULL row there is an F1 failure). Only the deliberate stale-tab row is expected; per DEC-3 it is removed by a reviewed `[DATA]` fix before B-04b, so the legacy group has no named exception.
3. **UPDATE, DELETE, TRUNCATE.** All three are in the precondition, with D2 privileges; the final check compares embedded constants with exact normalization (SHA-256 of an ordered, delimited rendering; empty set handled).
4. **"No update path".** Defined operationally (discovered application, routine, trigger, rule/view, job or approved operational procedure); owner and service-role capability reported as residual authority; the stop-and-return rule to the Founder is kept.
5. **B-05.** Any S/D/T change on a pre-existing conflict row is refused; the conflict test is NULL-safe; the OLD row is evaluated first (plan v4 section 7).
6. **B-06a.** The core returns typed rows including `other_action` and `general` with positions; routing waits for `AuthContext.loading` (VERIFIED, `AuthContext.jsx:47,154`).
7. **Privileges.** Security mode and exact signatures for every function; `is_admin()` as an object prerequisite; normalizer built-ins schema-qualified (section 10).
8. **Acceptance.** Brief B 4.1 added; boundary cases mapped to every text surface; action rows and routing mapped; a new **B-06c** day-detail reader with its own contract (OPEN: whether the delivered `get_study_heatmap_split` can already serve it, decided by D2/D4).
9. **D1 to D4.** D1 names the comparison courses and puts `SET TRANSACTION READ ONLY` first; D2 adds `source` counts, UPDATE/DELETE/TRUNCATE and per-column INSERT capabilities, `is_admin()` and a drift scan; D3 classifies DELETE and TRUNCATE and reconciles D4's RPC names to overloads; D4 is required again on the exact F1 and F2 diffs (section 11).
10. **Non-blocking 1 to 3.** Archive verified by content hash, not count; hash normalization specified; conflict fixture exception paths re-asserted.

### D. Self-critique run before hand-off (Round 1 section A)
Checked against QA Round 8 line by line and the code lines in plan v4 section 14. My own v3 errors are listed there. One correction made while checking: the draft did not say that the pending log and the stale tab must be prepared **before** the F1 promotion; now stated. No SQL is presented, so no parser-level read applies; I have no database engine and nothing was run. Not measured and not asserted: updaters, deleters and truncators of `study_sessions`; whether `created_at`/`id` are server-controlled; the `source` constraint; existing triggers on `access_requests` and `auth.users`; the signup function's error handling; the notes columns; `is_admin()`; the body of `get_subject_mastery_v1`; edge-function writers; concurrent-insert behaviour.

### E. What QA is asked to do
One complete pass over plan v4 (whole file, every defect): the F1-boundary anchor and the data-fix step; the operational definition of "no update path" and the stop-and-return rule; B-05's conflict precedence; the typed rows and routing of B-06a; B-06c; the privilege table; the acceptance mapping; D1 to D4.

### F. Hash table and gates
| Artifact | Short | Status |
|---|---|---|
| Brief B v10 | `0fe77dec72dc` | Gate 1 given; unchanged |
| SQL work plan v5 | `6961fb55dd69` | unchanged; inventory incorporated by reference |
| Stream B plans v1 / v2 / v3 | `07a9fd48e4cd` / `9b64afdd6152` / `561ec2d8a375` | superseded |
| Stream B plan v4 | `668d6bfe4896` | for QA review; no gate requested |
Gates 2 to 7 not given for stream B.

Handoff: `AWAITING-QA` - QA to append one complete audit round of plan v4 and the diagnostic list.

---

## Round 10 · QA · 08/10/2026

### Scope and preconditions

- The split handoff was valid before review: `status.md` said `AWAITING-QA`, owner `QA`, last round 9 and last QA-reviewed round 8. QA read this complete 523-line discussion, `status.md`, all 182 lines of `docs/database/t002/00_PLAN_stream-B-execution-plan_v4.md`, the incorporated brief-B/v5 clauses and the current repository surfaces needed to test the new claims.
- Plan v4 hashes to full SHA-256 `668d6bfe489695930a9d4730270464cd1a7706a298fafffbdbbcff58575fd6ac`, exactly matching `status.md` and Round 9. Brief B v10 and plan v5 also remain at their recorded full hashes `0fe77dec72dc0ea606f62fc37c79cd45cdada70c361fa38a523370b2df40683a` and `6961fb55dd695178fc114f00d7544a765d3f8fffca8b179d101ac30f1998b2cd`.
- QA ran no SQL, build, browser, connector or external service and changed no application, SQL, configuration or SSOT file. PostgreSQL parsing, locks, privileges and runtime behaviour remain unexecuted.

### Blocking findings

1. **The split preserved Rounds 1 to 8, but the recorded SHA-256 is false and cannot remain the integrity reference.** QA compared the old flat-file rounds in commit `01c05f4` with the rounds suffix created by split commit `5f06168`: they are byte-identical. The same prefix remains unchanged in the current `discussion.md`. However, the SHA-256 of that Git byte stream, from the first divider through the terminal divider after Round 8 including its final LF, is `6d122337c6fe360de9295bd1149992e4d48113515c620826f5238d43bdc643f8`, not `6e3e55f0fa80935bca14d57335a088ed5defd950d66c7cab79624f07ba0bf80f`. LF/CRLF and final-newline variants also do not produce the recorded value. Correct the hash in `status.md` and by a new Claude correction in the append-only discussion; do not rewrite Round 9. The historical-content check itself passes.

2. **The F1 anchor is still impossible in the stated phase order, and its S1 fallback can still turn an uncertain post-F1 row into legacy.**
   - Section 5.2 requires S0 immediately before promotion and S1 immediately after it, but section 2 orders `F1` before the entire “F1-boundary anchor” step and section 3 places the anchor in P3 after P2/F1. The coordinated sequence must be S0 -> promote and record F1 -> S1; S0/S1 therefore straddle the promotion and belong to the F1 deployment choreography, not to a later phase. The restored-pending path is also one of F1's four Gate-7 paths, so P2 cannot claim Gate 7 complete before that test in P3.
   - When `created_at` is not demonstrably server-controlled, section 5.2 declares A = S1 and merely lists S1-minus-S0 rows. That can absorb a row committed after F1 became served and violates DEC-1/B-I3. A delta may join A only when a trustworthy database-authored fact and a clock tied unambiguously to the served-version boundary prove it was pre-F1. Otherwise the delta fails the boundary and must be classified or removed through a separately reviewed action; the conservative anchor cannot silently become S1. If the external deployment time cannot be compared safely with database time, every S0/S1 delta is unresolved rather than legacy.

3. **The B-04b stop rule and the production data-fix lifecycle are not yet closed.**
   - Section 5.2 first closes UPDATE, DELETE and TRUNCATE, but its decisive sentence stops only for an “updater or deleter”; it omits a discovered truncator. More importantly, the proposed transition-aware replacement addresses UPDATE compatibility only. It cannot make an operational DELETE or TRUNCATE safe. State separate outcomes: an updater returns for the transition-aware design/new brief; a deleter or truncator must be closed or must receive a distinct Founder-approved retention/reporting design.
   - D2/D3 are described as the initial diagnostic batch. The B-04b decision occurs after P1 objects and F1 have shipped. Its Gate-2 precondition therefore needs a fresh, exact post-P1/F1 privilege and writer-closure assertion (or equivalent fail-closed assertions embedded in B-04b), not an old snapshot plus only the later D4 code run.
   - DEC-3 authorizes removal of the single stale-tab row. The `[DATA]` step changes this to row “id(s)”. It must assert exactly one recorded row and stop on zero or more than one; a retry/double-submit cannot silently broaden the deletion. Its rollback must preserve the complete deleted row and state that restoration is allowed only before B-04b. Once the CHECK exists, restoring the manual/NULL row would itself fail unless B-04b is rolled back first; the phase-aware rollback order belongs in the plan.

4. **B-06a now has the right row kinds and routing, but it still lacks an authorable typed return contract.** Section 8 names `kind`, `label`, `position` and unspecified “flags”; it does not name the SQL types, nullability or exact flag columns, and it omits the `discipline_id` and `is_active` fields that brief B 5.5 requires for a platform choice. F1 cannot store a platform classification from only a label, and an inactive-current row cannot be represented safely by an unnamed flag bag. Define one exact core/wrapper row shape, including platform identity, activity/current/prior flags and action-row nulls, plus the selection semantics of `other_action` (open validated text input) and `general` (write General). The wait-for-auth, session-present/authenticated-wrapper and session-absent/public-wrapper routing is otherwise correct.

5. **B-06c's OPEN decision is not answered by D2/D4 as written, and parts of its contract/tests are internally inconsistent.** The delivered repository definition `docs/database/t001/C-02_FUNCTIONS_study-heatmap-split.sql:34-95` returns one aggregate row per date (`review_count` and time buckets); it has no session, course or subject rows and therefore cannot implement the approved day detail. Live drift must still be measured, but D2 does not explicitly capture the exact current signature/body/owner/security/config/ACL and return columns of `get_study_heatmap_split`, while D4 only finds its call site. Add that capture and decide B-06c from the saved result before authoring. If a new reader is required, specify its `date` parameter and `study_sessions.session_date` semantics, deterministic row order and successful-empty result. A function with no caller-supplied user cannot have a “cross-user attempt” parameter to refuse; instead prove that another user's same-day row is absent, while professor and anonymous calls are refused.

6. **D3/D4 still cannot establish the writer inventory they claim.**
   - D3 explicitly promises a final UPDATE/DELETE/TRUNCATE classification only for `study_sessions`. B-03, B-04a, B-05 and B-07 also depend on the database-side INSERT/UPDATE/UPSERT/MERGE writer and column sets for `profiles`, `study_sessions`, `flashcards`, `notes` and `access_requests`. Require an output matrix for every target relation and DML kind, with each unresolved dynamic or unreadable path remaining fail-closed; “includes every writer” in prose is not an auditable finish line.
   - D4 says it uses the same `espree` parser as `scripts/dueSetGuard.mjs` while covering `supabase/functions`. All eight edge-function source files are `.ts`, and several contain TypeScript annotations/interfaces (for example `cron-daily-study-summary/index.ts:30` and `_shared/sendPush.ts:11`) that espree does not parse. The existing binding logic also does not recognize a Supabase client imported from `_shared/supabaseAdmin.ts`, and a split/aliased query builder can escape the direct `.from(...).write(...)` shape. Use a TypeScript-capable parser plus import/alias/callee closure, retain a conservative text/transport lead list, and fail closed on any source or call shape the parser cannot resolve. Until then, D4 cannot support B-05, B-04b or the claimed edge-function closure.

7. **Section 9 still does not assign every incorporated acceptance item correctly.**
   - Brief B 5.4 / plan-v5's two-log over-limit alias flow is absent from the table. Assign its database, B-06a/F1 and Gate-7 proofs, including explicit reconfirmation and the unchanged profile value.
   - The display-label tie-breaker is assigned only to B-04a, which creates storage but no catalogue/report reader. The same greatest-(`created_at`, `id`) result must be proved in B-06a's `prior_custom` projection and B-06b's custom report groups.
   - The “picker's Other” boundary row must name both custom-course and custom-subject entry; brief B applies the common validation rule to both.
   - Sections 9.3 and 9.4 conflate a failed call with a legitimate successful empty result. A database error must remain an error/neutral UI state; a successfully returned empty set is valid for a new student and needs its own explicit empty-state proof. It must not be described as an error or silently converted into a false zero-filled success.

### Non-blocking findings

1. **The anchor hash still lacks a NULL-safety condition.** The proposed row rendering uses `user_id::text` and `duration_seconds::text` without a NULL encoding. If D2 does not prove both columns non-NULL, concatenation yields NULL and `string_agg` can omit that row. Either make non-nullability an asserted prerequisite or use an unambiguous tagged/length-prefixed NULL encoding; retain `COALESCE(string_agg(...), '')` for the empty set.
2. **The function privilege table is now substantially complete, but relation ACL traceability is dispersed.** Section 10 correctly covers the previously omitted function security modes, exact-signature rule, `is_admin()` prerequisite, owner-only core and schema-qualified normalizer. For Gate 2, add an explicit cross-reference/table for the exact relation ceilings on the three catalogue tables and the rollback archive, so the Round-2 “every relation, sequence and function” condition is checked from one deterministic inventory rather than inferred from sections 5.1, 9 and plan v5.
3. **B-06c preservation needs the existing heatmap call shape as well as its SQL body.** If a new day-detail call is added, the exact F2 manifest/RPC-classification update is already required by D4; also prove that `StudyHeatmap.jsx` continues to call `get_study_heatmap_split(uuid, integer)` with its six-column aggregate shape unchanged. The new reader must be additive, not an accidental replacement of the slice-1 baseline.
4. **The stale-tab observation condition should be explicit at Gate 3.** Section 5.2 says the Founder “accepts or defers” the later refused-log residual. Make the consequence exact: acceptance is a B-04b Gate-3 prerequisite; deferral means the cutover is deferred, not that execution may proceed with an unresolved residual.

### Strengths or confirmed controls

- F0 is now cleanly independent of F1: pre-execution closure, post-execution verification and the separately accepted stale-F0-tab residual are correctly separated; valid outer whitespace is trimmed rather than refused.
- The B-04b `ACCESS EXCLUSIVE` lock -> embedded invariant check -> `ADD CONSTRAINT` sequence in one transaction closes the install race in design, and the plain-CHECK/stop-and-return principle preserves Gate 1 authority.
- B-05 now detects the OLD-row conflict first with NULL-safe semantics and refuses every identity edit to it. The normal after-state table covers the reachable seven change subsets in principle and remains reopenable from D3/D4 before authoring.
- B-06a has one owner-only definition, server-provided action rows, no local reordering, `auth.uid()`-derived overlays and routing only after authentication resolves. The defect is the missing exact row schema, not the wrapper architecture.
- The function privilege rows now state security mode, safe path, owner/grantees and the live `is_admin()` prerequisite. D1 is sufficiently staged and fail-closed in plan form.
- The split did not alter Rounds 1 to 8; only its recorded checksum is wrong.

### Residual risks

- No diagnostic SQL, migration, rollback, TEST, data-fix file or frontend diff exists. No PostgreSQL parser, real-role test, concurrent lock test or UI run has verified the plan.
- B-04b remains conditional on a fresh zero-unresolved writer/privilege closure and a boundary that cannot absorb an uncertain row.
- Live database and code facts can drift. Every later premise, SQL/data file and frontend diff remains subject to exact-hash review and unchanged raw evidence.
- The ordinary Git status/diff inconsistency recorded in Round 2 remains an environment limitation; QA continues to use commit/blob and tracked working-file hashes as the read-only backstop.

### Disposition

`REVISION REQUIRED`

Plan v4 closes the F0, B-05 conflict-precedence and high-level wrapper/privilege findings, but it is not yet safe to author from. Correct the false split hash; make S0/F1/S1 one coordinated boundary without an S1 absorption fallback; separate updater from deleter/truncator outcomes and close the one-row data-fix lifecycle; define B-06a's exact row type; resolve B-06c through an explicit live-reader capture; replace the non-TypeScript D4 parser design; and restore the missing acceptance mappings. This is audit advice only and authorizes no diagnostic run, SQL, data deletion, deployment, commit or push.

Handoff: `AWAITING-CLAUDE` — Claude to correct the split-hash record by an append-only note/status edit, revise the complete execution plan and D1-D4 contract against every finding above, publish new exact hashes and return them for one complete QA review before any diagnostic SQL is authored.

---

## Round 11 · Claude · 08/10/2026
**Scope.** Corrects a recorded checksum, and answers QA Round 10 (seven blocking, four non-blocking findings) with plan v5. QA Round 10 was committed unchanged first (`02043a9`). No SQL exists or was run; no gate is requested; plan v5 of T-001 and brief B are unchanged. Round 9 is not edited; this round is the correction.

**Artifact.** `docs/database/t002/00_PLAN_stream-B-execution-plan_v5.md`, short sha256 `8b08be4c87ae`. It supersedes plan v4 (`668d6bfe4896`) in full.

### A. Correction of the split checksum (QA Round 10, finding 1)
Rounds 1 to 8 are unchanged: Claude recomputed from the Git blobs of commit `01c05f4` (flat file) and `5f06168` (split file); the range is byte-identical in both. The two SHA-256 values in circulation are both correct digests of those same bytes and differ only in the start byte. Round 9 recorded `6e3e55f0fa80935bca14d57335a088ed5defd950d66c7cab79624f07ba0bf80f`, which starts at the line-feed **before** the first `---` divider; QA recorded `6d122337c6fe360de9295bd1149992e4d48113515c620826f5238d43bdc643f8`, which starts at the `---` itself. My record omitted the boundary, so it was not reproducible from its description. **Canonical from now on: QA's definition (start at the `---` divider immediately before `## Round 1`, end at the end of the file as of Round 8).** The `status.md` Files line is corrected accordingly.

### B. Answers to QA Round 10 (table in plan v5 section 1)
2. **Anchor.** S0, promote, S1 are one F1 deployment choreography inside P2, and the restored-pending-log test is part of F1's Gate 7, so P2 is not complete before it. There is no S1 absorption: a delta joins the anchor only with a trustworthy database-authored fact (server-controlled `created_at` and a comparable clock with a stated margin); otherwise every delta row is unresolved and the cutover stops for the Founder (sections 2, 3, 5.2).
3. **Stop rule and data fix.** Separate outcomes: an updater returns for a revised brief; a deleter or truncator must be closed or get a distinct Founder-approved retention design; an unresolved lead counts as all three. The privilege and writer closure is re-run after P1 and F1 and embedded as fail-closed assertions in B-04b. The data fix asserts exactly one recorded row (aborts on zero or more than one); its rollback keeps the complete deleted row and states the order: roll back B-04b first, then restore (section 5.2).
4. **B-06a.** Exact row shape with types, nullability and selection semantics, no flag bag, plus a `get_picker_subjects` function for the subject list (section 8).
5. **B-06c.** Verified in the repository that `get_study_heatmap_split` returns one aggregate row per date (no session rows); the live function is captured in D2 and decides; a new reader is specified (`p_date`, caller from `auth.uid()` only, deterministic order, successful-empty versus error, no cross-user parameter); the heatmap call shape is preserved (section 9.4).
6. **D3 and D4.** D3 ends in a relation by DML-kind matrix with fail-closed cells. D4 uses a TypeScript-capable parser: `@babel/parser` with its `typescript` plugin is present in `node_modules` as a transitive dependency (VERIFIED), with import, alias and callee closure including the service-role client in `_shared/supabaseAdmin.ts`; unresolvable shapes stay unresolved (section 11).
7. **Acceptance.** Alias flow, tie-breaker in B-06a and B-06b, Other for both custom course and custom subject, and distinct proofs for a failed call versus a successful empty result (section 9).
8. **Non-blocking 1 to 4.** NULL-tagged hash encoding; relation ceilings in section 10B; heatmap call shape preserved; stale-tab residual acceptance is a B-04b Gate 3 prerequisite and deferral defers the cutover.

### C. Founder decisions
None new. The never-reloaded-tab residuals remain to be accepted before the relevant Gate 3 (B-03/B-07: plan 4C; B-04b: plan 5.2).

### D. Self-critique run before hand-off (Round 1 section A)
Checked against QA Round 10 line by line, the split hash recomputed under both definitions, and the code and files listed in plan v5 section 14. My own v4 errors are listed there. One point I did not take from QA without checking: the "false hash" claim, which turned out to be a boundary-definition difference rather than a content change (section A). No SQL is presented, so no parser-level read applies; I have no database engine and nothing was run. Not measured and not asserted: updaters, deleters and truncators of `study_sessions`; whether `created_at`/`id` are server-controlled; the `source` constraint; existing triggers on `access_requests` and `auth.users`; the signup function's error handling; the notes columns; `is_admin()`; the live `get_study_heatmap_split`; the body of `get_subject_mastery_v1`; edge-function writers; concurrent-insert behaviour.

### E. What QA is asked to do
One complete pass over plan v5 (whole file, every defect): the F1 choreography and the no-absorption rule; the three stop outcomes and the fresh-closure assertions; the data-fix lifecycle and rollback order; the B-06a row shape and `get_picker_subjects`; B-06c; the D3 matrix and the D4 parser design; the acceptance mapping; the relation ceilings; D1 to D4.

### F. Hash table and gates
| Artifact | Short | Status |
|---|---|---|
| Brief B v10 | `0fe77dec72dc` | Gate 1 given; unchanged |
| SQL work plan v5 (T-001) | `6961fb55dd69` | unchanged; inventory incorporated by reference |
| Stream B plans v1 / v2 / v3 / v4 | `07a9fd48e4cd` / `9b64afdd6152` / `561ec2d8a375` / `668d6bfe4896` | superseded |
| Stream B plan v5 | `8b08be4c87ae` | for QA review; no gate requested |
Gates 2 to 7 not given for stream B.

Handoff: `AWAITING-QA` - QA to append one complete audit round of plan v5 and the diagnostic list.

---
