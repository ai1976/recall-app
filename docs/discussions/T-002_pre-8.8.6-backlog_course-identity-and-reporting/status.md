# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-CLAUDE
- **Owner:** Claude
- **Phase:** SQL work plan v7 and the four authored read-only diagnostic files under audit (design approved: brief B v10, Gate 1 given 04/10/2026)
- **Last round:** 16  · **Last QA-reviewed round:** 15
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1, DEC-2 (Round 5); topic-level logging deferred (Round 7); DEC-3 (Round 9); Round 13 method choice. **Proposed, for the Founder after QA audits it:** DEC-4, shrink-only treatment of account-deletion rows for the B-04b cutover (plan v7 section 5.2). **Needed later, two acceptances:** (1) before Gate 3 of B-03 and B-07: the never-reloaded F0 tab residual (section 4C); (2) before Gate 3 of B-04b: the never-reloaded F1 tab residual (section 5.2); deferral of (2) defers the cutover. **Also needed before the D4 baseline run:** a decision on the unparsable edge-function file (plan v7 section 11).
- **Artifacts under review:** (a) stream B execution plan v7 `docs/database/t002/00_PLAN_stream-B-execution-plan_v7.md` short sha256 `8b1ac4bb0a39` (full `8b1ac4bb0a3951436a3612814071b864f41e1d074e8592a911df4687f87e3cdd`), superseding v6 `6fff5d00e8d8` in full; (b) four authored diagnostic files, each for an exact-hash audit: `D-01_DIAGNOSTIC_D1a_subject-mastery-catalogue.sql` `a018ee859f23`, `D-02_DIAGNOSTIC_D2_live-state.sql` `e4e9fdcd6e21`, `D-03_DIAGNOSTIC_D3_writer-closure.sql` `6a88bc519299`, `D-04_code-inventory.mjs` `de019cd639fb` (all in `docs/database/t002/`; full hashes in Round 15). Accepted as a list by QA Round 14: `00_DIAGNOSTIC-BATCH_proposal_v1.md` `6e755b91b8ca`. Approved inputs: brief B v10 `0fe77dec72dc`; T-001 plan v5 `6961fb55dd69` (acceptance inventory by reference).

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
