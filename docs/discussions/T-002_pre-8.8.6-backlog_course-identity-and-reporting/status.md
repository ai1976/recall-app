# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-QA
- **Owner:** QA
- **Phase:** SQL work plan: stream B execution plan v4 under review (design approved: brief B v10, Gate 1 given 04/10/2026)
- **Last round:** 9  · **Last QA-reviewed round:** 8
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1 report order, DEC-2 refusal timing (Round 5); topic-level logging deferred (Round 7); DEC-3 stale-tab test row removed by a reviewed data fix (Round 9). Needed later, before Gate 3 of B-03/B-07: explicit acceptance of the never-reloaded F0 tab residual (plan v4 4C).
- **Artifacts under review:** stream B execution plan v4 `docs/database/t002/00_PLAN_stream-B-execution-plan_v4.md` short sha256 `668d6bfe4896` (full `668d6bfe489695930a9d4730270464cd1a7706a298fafffbdbbcff58575fd6ac`); it supersedes plan v3 `561ec2d8a375` in full and replaces only the stream B execution parts of plan v5 `6961fb55dd69` (v5 and brief B acceptance inventory incorporated by reference, plan v4 section 9). Approved inputs: brief B v10 `0fe77dec72dc`.

### Gates
- [x] 1 Design approved (brief B v10 `0fe77dec72dc`, Founder 04/10/2026, T-001 Round 35; QA PASS WITH CONDITIONS)
- [ ] 2 SQL approved
- [ ] 3 Production execution authorized
- [ ] 4 SQL execution verified
- [ ] 5 Frontend approved
- [ ] 6 Commit/push authorized
- [ ] 7 Live verification accepted

## Files
- `discussion.md` (this folder): rounds 1 onward, append-only. Rounds section (from the first divider to the end at the time of the split) sha256 `6e3e55f0fa80935bca14d57335a088ed5defd950d66c7cab79624f07ba0bf80f`.
- Evidence: `docs/discussions/evidence/` (flat, shared with T-001; unchanged).
- Plans under review: `docs/database/t002/` (frozen versions are never edited; each new version is a new file).
- Who edits what: the strict handoff rules of `docs/discussions/README.md` apply unchanged. QA appends its round to `discussion.md` and updates only the four handoff fields in the status block of `status.md`; Claude owns the rest of `status.md`.
