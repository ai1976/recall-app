# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-CLAUDE
- **Owner:** Claude
- **Phase:** SQL work plan: stream B execution plan v6 and the separate diagnostic batch proposal v1 under review (design approved: brief B v10, Gate 1 given 04/10/2026)
- **Last round:** 14  · **Last QA-reviewed round:** 14
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1 report order, DEC-2 refusal timing (Round 5); topic-level logging deferred (Round 7); DEC-3 stale-tab test row removed by a reviewed data fix (Round 9). **Needed later, two acceptances:** (1) before Gate 3 of B-03 and B-07: the never-reloaded F0 tab residual (plan v6 section 4C); (2) before Gate 3 of B-04b: the never-reloaded F1 tab residual, a refused log that is not stored (plan v6 section 5.2). Deferral of (2) defers the cutover.
- **Artifacts under review:** (a) stream B execution plan v6 `docs/database/t002/00_PLAN_stream-B-execution-plan_v6.md` short sha256 `6fff5d00e8d8` (full `6fff5d00e8d8dbf03dd2b0b622453a1773bd98ceaed7c9a66b171add1a51fa1b`), superseding plan v5 `8b08be4c87ae` in full; (b) read-only diagnostic batch proposal v1 `docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md` short sha256 `6e755b91b8ca` (full `6e755b91b8ca2ed48d307b582cb182c188df315a8cfb6dbc76d02f54de557dfe`), for a **separate verdict**. Approved inputs: brief B v10 `0fe77dec72dc`; T-001 plan v5 `6961fb55dd69` (acceptance inventory by reference).

### Gates
- [x] 1 Design approved (brief B v10 `0fe77dec72dc`, Founder 04/10/2026, T-001 Round 35; QA PASS WITH CONDITIONS)
- [ ] 2 SQL approved
- [ ] 3 Production execution authorized
- [ ] 4 SQL execution verified
- [ ] 5 Frontend approved
- [ ] 6 Commit/push authorized
- [ ] 7 Live verification accepted

## Files
- `discussion.md` (this folder): rounds 1 onward, append-only. **Integrity of rounds 1 to 8 (corrected 08/10/2026, Round 11):** the byte range from the first divider line `---` (the one immediately followed by `## Round 1`) through the end of the file as it stood after Round 8 has sha256 `6d122337c6fe360de9295bd1149992e4d48113515c620826f5238d43bdc643f8` (QA Round 10; reproduced by Claude from Git blobs of commits `01c05f4` and `5f06168`, identical in both). The earlier value `6e3e55f0fa80935bca14d57335a088ed5defd950d66c7cab79624f07ba0bf80f` is the same bytes with one extra leading line-feed before that divider. The first definition (starting at `---`) is canonical from now on.
- Evidence: `docs/discussions/evidence/` (flat, shared with T-001; unchanged).
- Plans under review: `docs/database/t002/` (frozen versions are never edited; each new version is a new file).
- Who edits what: the strict handoff rules of `docs/discussions/README.md` apply unchanged. QA appends its round to `discussion.md` and updates only the four handoff fields in the status block of `status.md`; Claude owns the rest of `status.md`.
