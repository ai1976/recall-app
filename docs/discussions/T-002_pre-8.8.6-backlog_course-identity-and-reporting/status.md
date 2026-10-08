# T-002 · Pre-8.8.6 backlog: course identity and reporting (point 5: progress by course; point 10: course and subject on offline study logs)


## Status
- **State:** AWAITING-CLAUDE
- **Owner:** Claude
- **Phase:** tiered workflow adopted by the Founder (08/10/2026, Round 39); Tier 0 results in (D-02, D-03 v11, D-04 v13, D-05 v11 on real data); first Tier 1 files B-01 and B-02a submitted for QA's audit (design approved: brief B v10, Gate 1 given 04/10/2026)
- **Last round:** 40  · **Last QA-reviewed round:** 39
- **Agreed decisions (carried from T-001; positions, not a new approval):** brief B v10 (`0fe77dec72dc`) is the approved design for points 5 and 10 together; decisions D1 to D11 and E1 to E10 of T-001 are confirmed (Founder, 04/10/2026 and later); no in-app payment; platform course names are identifiers and immutable in v1; new offline logs are always classified (platform, custom or explicit General), NULL means only legacy; no backfill; professors see totals only. Details and round numbers: Round 1 section B.
- **Open disagreements:** none
- **Founder decisions required:** none now. In force: DEC-1, DEC-2 (Round 5); topic-level logging deferred (Round 7); DEC-3 (Round 9); Round 13 method choice; authorization to run D-01 (Round 17; run 08/10/2026); **DEC-4 simplified (08/10/2026, Round 27): the cutover requires only that the set of unclassified manual logs never grows; no removal provenance.** **Needed later, two acceptances:** (1) before Gate 3 of B-03 and B-07: the never-reloaded F0 tab residual (section 4C); (2) before Gate 3 of B-04b: the never-reloaded F1 tab residual (section 5.2); deferral of (2) defers the cutover.
- **Artifacts under review:** (a) TIER 1, for QA's audit by exact hash (full hashes in Round 39): `docs/database/t002/B-01_FUNCTIONS_course-text-normalize-and-resolve_v1.sql` `b0fe47bb2ed8`, `B-01_TEST_...` `17f07893f74b`, `B-01_ROLLBACK_...` `46e3d3cf75bb`, `B-02a_SCHEMA_disciplines-guards_v1.sql` `c5c85984ad28`, `B-02a_TEST_...` `a582c40c983c`, `B-02a_ROLLBACK_...` `173f0bdf20f8`; (b) current plan `docs/database/t002/00_PLAN_stream-B-execution-plan_v18.md` `88241bd6d514`; (c) TIER 0 results for QA's review (not the scripts): `docs/discussions/evidence/T-002_D2-index_08-10-2026.md`, `T-002_D3-index_08-10-2026.md`, `T-002_Tier0-record_08-10-2026.md` (D-04 v13 final run, D-05 v11 matrix); quarantined: `T-002_D3-WRONG-FILE-v1-run_08-10-2026.raw.txt`. Tooling in `docs/database/t002/`: D-03 v11, D-04 v13, D-05 v11 (Tier 0; not under QA hash audit). Approved inputs: brief B v10 `0fe77dec72dc`; T-001 plan v5 `6961fb55dd69`.

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
