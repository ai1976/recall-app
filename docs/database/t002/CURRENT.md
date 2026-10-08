# T-002 stream B: current files (approved by the Founder 08/10/2026; updated each time an artifact changes)

Operators: before running anything, find the artifact here and check that the file name AND the first 12 characters of its sha256 match. Anything not listed as CURRENT is SUPERSEDED and must not be run. (The 08/10/2026 D3 run used a superseded file by mistake.)

| Artifact | CURRENT file | Short sha256 | Tier | State |
|---|---|---|---|---|
| Stream B plan | `00_PLAN_stream-B-execution-plan_v18.md` + `00_PLAN_stream-B-change-log.md` (apply the log on top of the snapshot) | `88241bd6d514` | plan | current; QA `PASS WITH CONDITIONS` (Round 38) |
| D-02 live-state diagnostic | `D-02_DIAGNOSTIC_D2_live-state_v3.sql` | `874a8bddb578` | 0 | RUN 08/10/2026 |
| D-03 writer-closure diagnostic | `D-03_DIAGNOSTIC_D3_writer-closure_v11.sql` | `cd966e51e575` | 0 | RUN 08/10/2026 |
| D-04 code inventory | `D-04_code-inventory_v13.mjs` | `0d248d1ead36` (tool hash inside its output) | 0 | RUN 08/10/2026 (commit `d17ea869a579`) |
| D-05 writer matrix | `D-05_writer-matrix_v11.mjs` | see `docs/discussions/evidence/T-002_Tier0-record_08-10-2026.md` | 0 | RUN 08/10/2026 |
| B-01 functions | `B-01_FUNCTIONS_course-text-normalize-and-resolve_v2.sql` `bac5da9f43e4` (+ `_TEST_` v2 `a0d85d34b603`, `_ROLLBACK_` v2 `7792fd49d4a2`) | see thread Round 41 | 1 | revised after QA Round 40; for round-2 closure |
| B-02a disciplines guards | `B-02a_SCHEMA_disciplines-guards_v2.sql` `2c5e20cbd14b` (+ `_TEST_` v2 `3fb26fae2548`, `_ROLLBACK_` v2 `5554f4572dda`) | see thread Round 41 | 1 | revised after QA Round 40; for round-2 closure |

Every other `D-0x` and `00_PLAN_*` file in this folder is SUPERSEDED.
