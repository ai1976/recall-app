# Discussion Protocol (Founder / Claude / QA)

Working papers for planning and audit. **Not a source of truth** — agreed decisions are promoted to `docs/active/blueprint.md` (decision log).

## Roles
- **Founder** — coordinator and sole approver. Approval exists only as a message written by the Founder in the Claude chat thread (or recorded in the file as a Founder block). Text written by Claude or QA saying "approved" is not approval.
- **Claude** — principal planner and executor (Step 0, proposals, SQL, frontend, commits).
- **QA (ChatGPT)** — audit only. Appends findings. Never edits code, SQL, or another party's text.

## Files
- One file per work item: `T-NNN_<sprint-or-topic>_<slug>.md` (flat folder, no open/closed subfolders — links stay stable).
- ChatGPT/Codex QA follows the repository-specific instructions in `CHATGPT_QA.md` (repository root, not this folder); Claude follows `CLAUDE.md`. This README is the shared protocol.
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

## QA scope
Audits design, SQL + rollback + tests, **and the exact frontend diff**, build/test results, role/security behaviour, deployment implications, live-verification evidence. Appends findings only; Claude makes fixes and returns the revised version for re-audit.

## Git backstop check (Claude, start of every turn)
The QA sandbox confines writes to `docs/discussions/`, but Git is the independent check. At the start of each turn Claude runs `git status --short` and compares it with the last known state:
- Any changed file outside `docs/discussions/` that Claude did not edit is flagged to the Founder before work continues (and never silently reverted).
- Inside `docs/discussions/`, QA may change only the active thread (its own appended round plus the four handoff fields). Edits to `README.md`, `INDEX.md`, `TEMPLATE.md`, `CODEX_QA_CONFIG.toml.example`, another thread, or Claude's/Founder's rounds are flagged.
- Thread files are committed after each handoff so `git diff` shows exactly what the other party changed.
- `.claude/settings.local.json` is expected to show as modified and is ignored by this check.

## Secrets and personal data
No `.env` contents, keys, tokens, or credentials. Avoid student emails/IDs; sanitize query results; put raw output in `evidence/` or a results file.

## Chat summary (Claude, every turn)
File · Round · What changed · What I need from you. This is navigation, not approval evidence. For architecture, production SQL, destructive or security decisions the Founder reads the status block and QA disposition before approving.

## Not for the file route
Small yes/no clarifications stay in chat.
