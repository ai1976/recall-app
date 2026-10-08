# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-QA
- **Owner:** QA
- **Phase:** SQL work plan v11 and the revised read-only diagnostic files (D-02 v3 passed with conditions; D-03 v5, D-04 v5, D-05 v3 revised after QA Round 22) under audit; D-01 run and its evidence saved (design approved: brief B v10, Gate 1 given 04/10/2026)
- **Last round:** 23  · **Last QA-reviewed round:** 22
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1, DEC-2 (Round 5); topic-level logging deferred (Round 7); DEC-3 (Round 9); Round 13 method choice; authorization to run D-01 (Round 17; run 08/10/2026). **Proposed, for the Founder after QA audits it:** DEC-4, shrink-only treatment of account-deletion rows with a removal ledger, owner-gone provenance, bound callers and a sink-based allowlist (plan v11 section 5.2). **Needed later, two acceptances:** (1) before Gate 3 of B-03 and B-07: the never-reloaded F0 tab residual (section 4C); (2) before Gate 3 of B-04b: the never-reloaded F1 tab residual (section 5.2); deferral of (2) defers the cutover.
- **Artifacts under review:** (a) stream B execution plan v11 `docs/database/t002/00_PLAN_stream-B-execution-plan_v11.md` short sha256 `6db4d9d72eac` (full `6db4d9d72eac99d26161a39ea2829363b5fc5cfb83b41bf9dc68cffe16339045`), superseding v10 `500bc20fa23a` in full; (b) diagnostic files, each for an exact-hash audit (all in `docs/database/t002/`; full hashes in Round 23): `D-02_DIAGNOSTIC_D2_live-state_v3.sql` `874a8bddb578` (QA PASS WITH CONDITIONS, unchanged), `D-03_DIAGNOSTIC_D3_writer-closure_v5.sql` `482c28d315a8`, `D-04_code-inventory_v5.mjs` `80f38730f974`, `D-05_writer-matrix_v3.mjs` `1087cb8f7907`; (c) evidence: `docs/discussions/evidence/T-002_D1a-index_08-10-2026.md` (D-01 `a018ee859f23` run). Superseded and frozen: plan v10 `500bc20fa23a` and earlier; D-02 v1 `e4e9fdcd6e21`, v2 `0f12ba342fa5`; D-03 v1 `6a88bc519299`, v2 `0218d615ba64`, v3 `6e6c5693432d`, v4 `2210acf6702e`; D-04 v1 `de019cd639fb`, v2 `58865e55b1c6`, v3 `f480bcd05e5c`, v4 `1a2d4d13dac5`; D-05 v1 `38b08065a470`, v2 `d39292ddc66d`. Approved inputs: brief B v10 `0fe77dec72dc`; T-001 plan v5 `6961fb55dd69`.

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
