# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-CLAUDE
- **Owner:** Claude
- **Phase:** SQL work plan: stream B execution plan v3 under review (design approved: brief B v10, Gate 1 given 04/10/2026)
- **Last round:** 8  · **Last QA-reviewed round:** 7
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1 report order, DEC-2 refusal timing (Round 5). Recorded in Round 7: topic-level logging deferred out of v1.
- **Artifacts under review:** stream B execution plan v3 `docs/database/t002/00_PLAN_stream-B-execution-plan_v3.md` short sha256 `561ec2d8a375` (full `561ec2d8a37548fd3b35dc24de2bcd6ec8e70e0caecb3a2f0259a59f9c25eb79`); it supersedes plan v2 `9b64afdd6152` in full and replaces only the stream B execution parts of plan v5 `6961fb55dd69` (v5 and brief B acceptance inventory incorporated by reference, plan v3 section 9). Approved inputs: brief B v10 `0fe77dec72dc`.

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
