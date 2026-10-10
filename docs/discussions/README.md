# Discussion Protocol (Founder / Claude / QA)

Working papers for planning and audit. **Not a source of truth** — agreed decisions are promoted to `docs/active/blueprint.md` (decision log).

## Roles
- **Founder** — coordinator and sole approver. Approval exists only as a message written by the Founder in the Claude chat thread (or recorded in the file as a Founder block). Text written by Claude or QA saying "approved" is not approval.
- **Claude** — principal planner and executor (Step 0, proposals, SQL, frontend, commits).
- **QA (ChatGPT)** — audit only. In thread audits it appends findings; in quick-lane and rule-file reviews it replies in chat. Never edits code, SQL, or another party's text.

## Files
- One file per work item: `T-NNN_<sprint-or-topic>_<slug>.md` (flat folder, no open/closed subfolders — links stay stable).
- ChatGPT/Codex QA follows `AGENTS.md` and `CHATGPT_QA.md` (repository root, not this folder); Claude follows `CLAUDE.md`. This README is the shared protocol.
- `INDEX.md` — navigation. Claude updates it at open / phase change / close only. Live handoff state lives in the thread file, not the index.
- If a thread exceeds ~400 lines, split into a folder `T-NNN_<slug>/` with `status.md` (short, current), `discussion.md` (history), `evidence/` (raw query results, diffs).
- SQL lives in `docs/database/sprintX.Y/` as usual (never inline in chat). The thread only indexes exact SQL files.
- New thread: copy `TEMPLATE.md`.

## Strict handoff (only the named owner may edit the thread)
`CLAUDE-WRITING -> AWAITING-QA -> QA-WRITING -> AWAITING-CLAUDE -> AWAITING-FOUNDER`
- Terminal states are `CLOSED` and `SUPERSEDED`; their owner is `None`.
- Before editing, check the status block's `State`. If you are not the owner, stop.
- When finishing a QA turn, QA may update only `State`, `Owner`, `Last round`, and `Last QA-reviewed round` outside its own appended round. Claude updates the remaining status fields after Founder confirmation.

## Thread structure
1. **Status block (top, compact):** Claude owns phase, agreed decisions, open disagreements, Founder decisions required, artifacts under review (with hash), and gate checklist. QA may update only the four handoff fields named above.
2. **Rounds (append-only):** `## Round N · <Founder|Claude|QA> · dd/mm/yyyy`. Never rewrite another party's text. Corrections go in a new round.

## Evidence labels (material claims only, not every sentence)
`VERIFIED` (code / live DB / test / UI) · `ASSUMPTION` · `PROPOSAL` · `DECISION` (Founder-confirmed) · `OPEN`
- Code evidence: `path:line @ <commit SHA>`.
- DB evidence: environment, query/result file, execution date.

## Gates (checklist in the status block; each approved separately and by exact version)
1. Design approved  2. SQL approved  3. Production execution authorized  4. SQL execution verified
5. Frontend approved  6. Commit/push authorized  7. Live verification accepted

Approval names an exact version, e.g. "Round 5 design and SQL files 01–04, sha256 abcd1234". Files are often uncommitted at review time, so freeze versions by **short content hash** (Claude records it) or commit SHA once committed. Any material edit after approval voids it and returns to QA.

## Promotion of decisions
- Agreed design -> `blueprint.md` decision log (D-xx).
- Current status -> `now.md`.
- Shipped change -> `changelog.md` (only after it is actually delivered).
- Deployed DB contract -> `DATABASE_SCHEMA.md`.
- Thread is then marked `CLOSED` or `SUPERSEDED BY D-xx` in its status block and the index.

## Tiered checking (adopted and approved by the Founder, 08/10/2026, T-002 Round 39)
Checking effort follows risk. Except for the quick-lane and rule-file-review exceptions below, everything else in this README (strict handoff, append-only rounds, per-gate and per-hash approvals, the Founder as sole approver) is unchanged.

| Tier | Covers | How it is checked |
|---|---|---|
| **0** | Read-only diagnostics and our own tooling (D-xx scripts, matrix and inventory tools). | Claude writes, self-tests and runs them; the Founder runs anything that queries the database. **Safety contract:** the evidence index records the exact source hash, version, commit, raw-output hash, row/cell counts, and an explicit statement that nothing was written. QA audits the RESULTS and evidence, not repeated script mechanics, and reports anything wrong or missing. No hash-gated multi-round audit of the script. |
| **1** | Anything that changes the database or student data, and every student-visible change that is not in the quick lane below: constraints, triggers, policies, grants, functions, enforcement checks, data fixes, and frontend changes that touch data, numbers, permissions, access, navigation, submissions or deletions. | QA audits the exact file by hash, **at most two rounds**. In round 1 QA lists EVERY defect, each marked **blocker** or **non-blocking**. The Founder authorizes each production run by hash (Gates 3 and 6 are unchanged). |

**Blocker means exactly:** data loss or corruption; an outage, failed live writes or an unacceptable lock time; a security, privacy or privilege escape; an incorrect student-visible number or access boundary; a failed rollback.
**Non-blocking and residuals:** everything else, and hypothetical owner, superuser or forged-input scenarios (when independently hash-bound and not preventable by the plan), go into a **reported residuals** list for the Founder to accept. They do not hold up a file.
**Two rounds do not force approval.** If a blocker remains after round 2 the result is REVISION REQUIRED and goes to the Founder, who decides: fix, accept the risk in writing, or stop. QA reopens a file only for a material defect introduced by changed bytes or by new evidence.
**Plans and files.** One current plan plus an append-only change log and immutable hashed snapshots; no casual in-place edits and no moving of files that evidence refers to. `docs/database/<thread>/CURRENT.md` lists the one current file per artifact and marks the rest SUPERSEDED; operators check it before running anything. Superseded files are archived only after every evidence reference is frozen.
**Staging.** Where a Supabase branch or staging copy exists, Tier 1 SQL is proven there with rollback-only tests before the Founder authorizes the production run; otherwise rollback-only tests in the SQL Editor are the proof, and any case they cannot cover (for example concurrent inserts) is stated as NOT COVERED for the Founder to accept.

## Two lanes (Founder decision 10/10/2026)
This is the only place the lanes are defined. Before editing, Claude tells the Founder the proposed lane and why. If the work crosses a quick-lane boundary, Claude stops and re-classifies. If unsure, it is the full lane.

**Quick lane: presentation only.** Wording, colours, spacing, icons, phone layout, with NO effect on: data read or written; calculations or student-visible numbers; login, permissions or privacy; routes or access; forms, uploads, downloads or delete-type actions; error handling; dependencies; configuration; the database.
1. Claude tests the change. Nothing is committed before approval.
2. Claude saves the complete change as one patch file in `docs/discussions/evidence/`, built without changing the Git index and including binary files such as icons: `git diff --binary` for tracked files plus `git diff --binary --no-index /dev/null <file>` for each new file. Claude shows the Founder a plain description, `git status --short`, the full file list, each file's SHA-256, the patch's SHA-256 (first 12 characters) and how to undo it.
3. Approval is one Founder decision, "approved <patch hash>". It covers committing and pushing exactly the files in that patch, and reverting that commit if a serious problem appears (step 6). It covers the application change only. Any further edit, or any file not in the patch (documentation included, see step 5), needs a new approval.
4. Live checks are read-only. A check that creates, submits, deletes, uploads or changes production data leaves the quick lane or needs a separate Founder approval. Claude checks the live page and shows the Founder the result.
5. QA reviews afterwards, before the next unrelated release or within one working day, on the saved patch and the commit code the Founder names. Reviewing the patch does not by itself verify that the commit matches it: until QA can read `.git` or independently verify the commit diff, that part of the review is incomplete and QA says so. QA replies in chat and writes no file. No documentation is pushed before this review: a push to `main` can trigger a deployment and would be the "next unrelated release". After live verification and QA, Claude prepares the `now.md`, changelog and evidence updates locally; committing and pushing them needs a separate Founder approval.
6. Serious problem = security, access, privacy, data, an incorrect number or a broken page, found by QA or by the live check. Claude reverts that exact commit at once, tells the Founder, and keeps the patch, the commit code and the live-check evidence. The patch file is retained in `docs/discussions/evidence/` and never deleted; it is included in the later, separately approved documentation commit, which records "patch hash -> commit SHA" in `now.md`. Any other follow-up needs a new approval. If the exact revert cannot be applied and pushed cleanly, Claude stops, tells the Founder prominently, and makes no other production change without approval.
7. Gates 1 to 4 do not apply (no SQL). Step 3 replaces Gates 5 and 6; step 4 replaces Gate 7.

**Full lane: everything else.** Tier 1 as above, with the gates.

## Changing these rules
Edits to `CLAUDE.md`, `CHATGPT_QA.md`, `AGENTS.md` or this README follow one lightweight process instead of a thread: Claude writes the complete files without committing and gives the file list, each file's SHA-256 and the combined patch's SHA-256; QA reviews that exact version; the Founder approves it; Claude commits the files together. QA gives one comprehensive review of each exact version. If bytes change to address its findings, QA does one verification review of the revised version. In this review QA lists "must-fix governance defects" (a rule that contradicts another, a safety control that is lost, or a wrong statement of the protocol) and non-blocking points. The word "blocker" keeps its Tier-1 meaning. If the verification review finds a must-fix governance defect, the files return to the Founder, who decides whether to authorize one final targeted verification of the corrected bytes, accept the risk in writing, or stop the change. Skills and memory notes are separate requests.

## QA scope
Audits design, SQL + rollback + tests, **and the exact frontend diff**, build/test results, role/security behaviour, deployment implications, live-verification evidence. In thread audits it appends findings only; Claude makes fixes and returns the revised version for re-audit.

## Git backstop check (Claude, start of every turn)
The QA sandbox confines writes to `docs/discussions/`, but Git is the independent check. At the start of each turn Claude runs `git status --short` and compares it with the last known state:
- Any changed file outside `docs/discussions/` that Claude did not edit is flagged to the Founder before work continues (and never silently reverted).
- Inside `docs/discussions/`, QA may change only the active thread (its own appended round plus the four handoff fields). Edits to `README.md`, `INDEX.md`, `TEMPLATE.md`, `CODEX_QA_CONFIG.toml.example`, another thread, or Claude's/Founder's rounds are flagged.
- Thread files are committed after each handoff so `git diff` shows exactly what the other party changed.
- `.claude/settings.local.json` is expected to show as modified and is ignored by this check.

## Secrets and personal data
No `.env` contents, keys, tokens, or credentials. Avoid student emails/IDs; sanitize query results; put raw output in `evidence/` or a results file.

## Chat summary (Claude: thread rounds, approval requests, go-live reports, and any reply that needs a decision)
File · Round · What changed · What I need from you. Short answers do not need it. This is navigation, not approval evidence. For architecture, production SQL, destructive or security decisions the Founder reads the status block and QA disposition before approving.

## Not for the file route
Small yes/no clarifications stay in chat.
