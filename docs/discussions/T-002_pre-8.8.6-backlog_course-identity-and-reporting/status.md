# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-FOUNDER
- **Owner:** Founder
- **Phase:** B-01, B-02a, B-02b, B-04a, B-04a-fix, B-03, B-07, B-05 LIVE and verified; B-06a FUNCTIONS LIVE (bodies verified), TEST v3 (overlap-check fix) with QA for changed-byte closure (Round 92); F0 and F0b frontend LIVE; design approved: brief B v10, Gate 1 given 04/10/2026
- **Last round:** 93  · **Last QA-reviewed round:** 92
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1, DEC-2 (Round 5); topic-level logging deferred (Round 7); DEC-3 (Round 9); Round 13 method choice; authorization to run D-01 (Round 17; run 08/10/2026); **DEC-4 simplified (08/10/2026, Round 27): the cutover requires only that the set of unclassified manual logs never grows; no removal provenance.** **Acceptances:** (1) the never-reloaded F0 tab residual (section 4C) ACCEPTED by the Founder 09/10/2026 (Round 67); **needed later:** (2) before Gate 3 of B-04b: the never-reloaded F1 tab residual (section 5.2); deferral of (2) defers the cutover.
- **Artifacts under review:** TIER 1, closure of changed bytes, exact hashes in Round 92: `docs/database/t002/B-06a_TEST_course-catalogue-and-picker-subjects_v3.sql` `596636a49352` (FUNCTIONS v2 `10ebda036336` is LIVE and unchanged; ROLLBACK v2 `be21fc79dbc3` unchanged). Evidence: `docs/discussions/evidence/T-002_B06a-index_09-10-2026.md`. File index: `docs/database/t002/CURRENT.md`.

### Gates
- [x] 1 Design approved (brief B v10 `0fe77dec72dc`, Founder 04/10/2026, T-001 Round 35; QA PASS WITH CONDITIONS)
- [ ] 2 SQL approved
- [ ] 3 Production execution authorized
- [ ] 4 SQL execution verified
- [ ] 5 Frontend approved
- [ ] 6 Commit/push authorized
- [ ] 7 Live verification accepted

- Per-file progress (stream B, Tier 1): **B-01 v2, B-02a v2, B-02b v2, B-04a v1: Gates 2, 3 and 4 done (08/10/2026); F0 frontend patch v2: Gates 5, 6 and 7 done (08/10 to 09/10/2026)**; B-03 v2 and B-07 v2 Gates 2, 3 and 4 done (Round 72); F0b patch Gates 5, 6, 7 done (Round 71); B-05 and B-06a not yet authored; B-04b, F1, B-06b, B-06c and F2 later.
## Files
- `discussion.md` (this folder): rounds 1 onward, append-only. **Integrity of rounds 1 to 8 (corrected 08/10/2026, Round 11):** the byte range from the first divider line `---` (the one immediately followed by `## Round 1`) through the end of the file as it stood after Round 8 has sha256 `6d122337c6fe360de9295bd1149992e4d48113515c620826f5238d43bdc643f8` (QA Round 10; reproduced by Claude from Git blobs of commits `01c05f4` and `5f06168`, identical in both). The earlier value `6e3e55f0fa80935bca14d57335a088ed5defd950d66c7cab79624f07ba0bf80f` is the same bytes with one extra leading line-feed before that divider. The first definition (starting at `---`) is canonical from now on.
- Evidence: `docs/discussions/evidence/` (flat, shared with T-001; unchanged).
- Plans under review: `docs/database/t002/` (frozen versions are never edited; each new version is a new file).
- Who edits what: the strict handoff rules of `docs/discussions/README.md` apply unchanged. QA appends its round to `discussion.md` and updates only the four handoff fields in the status block of `status.md`; Claude owns the rest of `status.md`.
