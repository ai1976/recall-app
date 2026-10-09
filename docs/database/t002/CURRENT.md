# T-002 stream B: current files (approved by the Founder 08/10/2026; updated each time an artifact changes)

Operators: before running anything, find the artifact here and check that the file name AND the first 12 characters of its sha256 match. Anything not listed as CURRENT is SUPERSEDED and must not be run. (The 08/10/2026 D3 run used a superseded file by mistake.)

| Artifact | CURRENT file | Short sha256 | Tier | State |
|---|---|---|---|---|
| Stream B plan | `00_PLAN_stream-B-execution-plan_v18.md` + `00_PLAN_stream-B-change-log.md` (apply the log on top of the snapshot) | `88241bd6d514` | plan | current; QA `PASS WITH CONDITIONS` (Round 38) |
| D-02 live-state diagnostic | `D-02_DIAGNOSTIC_D2_live-state_v3.sql` | `874a8bddb578` | 0 | RUN 08/10/2026 |
| D-03 writer-closure diagnostic | `D-03_DIAGNOSTIC_D3_writer-closure_v11.sql` | `cd966e51e575` | 0 | RUN 08/10/2026 |
| D-04 code inventory | `D-04_code-inventory_v13.mjs` | `0d248d1ead36` (tool hash inside its output) | 0 | RUN 08/10/2026 (commit `d17ea869a579`) |
| D-05 writer matrix | `D-05_writer-matrix_v11.mjs` | see `docs/discussions/evidence/T-002_Tier0-record_08-10-2026.md` | 0 | RUN 08/10/2026 |
| B-01 functions | `B-01_FUNCTIONS_course-text-normalize-and-resolve_v2.sql` `bac5da9f43e4` (+ `_TEST_` v2 `a0d85d34b603`, `_ROLLBACK_` v2 `7792fd49d4a2`) | see thread Round 41 | 1 | QA PASS WITH CONDITIONS (Round 42); Gates 2 and 3 granted 08/10/2026 |
| B-02a disciplines guards | `B-02a_SCHEMA_disciplines-guards_v2.sql` `2c5e20cbd14b` (+ `_TEST_` v2 `3fb26fae2548`, `_ROLLBACK_` v2 `5554f4572dda`) | see thread Round 41 | 1 | QA PASS WITH CONDITIONS (Round 42); Gates 2 and 3 granted 08/10/2026 |
| B-02b catalogue write path and privileges | `B-02b_SCHEMA_catalogue-write-path-and-privileges_v2.sql` `097e0f3a0453` (+ `_TEST_` `135f68d54db3`, `_ROLLBACK_` `9e1a20469231`) | Round 50 | 1 | LIVE and TEST verified 08/10/2026 (15/15 true) |
| B-02b test-row cleanup | `B-02b_CLEANUP_test-subject_v1.sql` `dee0d50789b4` | Round 51 | data | one-off; run by the Founder 08/10/2026 |
| B-04a study_sessions compatibility | `B-04a_SCHEMA_study-sessions-compatibility-phase_v1.sql` `984b5010b68a` (+ `_TEST_` v2 `5f603e3412f9` [v1 `d926d7ff7339` SUPERSEDED, do not run], `_ROLLBACK_` `f4f6df14d217`) | thread Round 52 | 1 | LIVE and verified 08/10/2026 (TEST 13/13, VERIFY saved) |
| B-04a verify (read-only) | `B-04a_VERIFY_object-identities_v2.sql` `30a2172e5ecc` [v1 `cb65173d25f1` SUPERSEDED] | Round 54 | 0 | RUN 08/10/2026 |
| F0 frontend patch (not SQL) | `docs/discussions/T-002_F0_frontend-patch-v2_08-10-2026.patch` `098a7ebb4b9a` [v1 `f0cf524ed4f0` SUPERSEDED] | Round 60 | frontend | LIVE (commit `ac5e64b`); Gates 5, 6, 7 complete (Round 66) |
| F0 verify (read-only) | `F0_VERIFY_signup-profile-course_v1.sql` `3490e70d7197` | Round 65 | 0 | RUN 09/10/2026 |

Every other `D-0x` and `00_PLAN_*` file in this folder is SUPERSEDED.
