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
| B-03 profiles course trigger | `B-03_SCHEMA_profiles-course-trigger_v2.sql` `5a024d962024` (+ `_TEST_` v2 `e1b35bd045fe`, `_ROLLBACK_` v2 `8c63133986d6`) [v1 files `9ac3c2e6ff47`, `160018d13ebd`, `67448c2e38b2` SUPERSEDED, do not run] | thread Round 69 | 1 | LIVE and TEST verified 09/10/2026 (10/10 true) |
| B-07 access_requests course trigger | `B-07_SCHEMA_access-requests-course-trigger_v2.sql` `1248837761af` (+ `_TEST_` v2 `51766024a07e`, `_ROLLBACK_` v2 `1e49f7527ce1`) [v1 files `8ca0062e0e8d`, `0f094074a7fd`, `676e7735d014` SUPERSEDED, do not run] | thread Round 69 | 1 | LIVE and TEST verified 09/10/2026 (10/10 true); limited to request_type student_access |
| F0b frontend patch (Profile Settings current course) | `docs/discussions/T-002_F0b_frontend-patch_09-10-2026.patch` `e7ac68e93b56` | Round 69 | frontend | LIVE (commit `083f7f3`); Gates 5, 6, 7 complete (Round 71) |
| B-04a-fix label guard control set | `B-04a-fix_SCHEMA_label-guard-control-set_v2.sql` `8e91b4327eab` (QA PASS WITH CONDITIONS, Round 75) + `B-04a-fix_ROLLBACK_label-guard-control-set_v2.sql` `4d46c3f5846d` (QA PASS WITH CONDITIONS, Round 75) + `B-04a-fix_TEST_label-guard-control-set_v3.sql` `b618c4590322` [TEST v2 `636edc156a0e` SUPERSEDED, do not run; v1 files SUPERSEDED] | thread Round 76 | 1 | LIVE and TEST verified 09/10/2026 (6/6 true); rollback is pre-F1 only and not run |
| B-05 flashcards and notes course derive | `B-05_SCHEMA_flashcards-notes-course-derive_v1.sql` `b1714e829cdd` (unchanged; QA found no logic defect) + `B-05_TEST_flashcards-notes-course-derive_v2.sql` `53d616857ffc` + `B-05_ROLLBACK_flashcards-notes-course-derive_v2.sql` `073bf80d062d` [TEST v1 `6b9519adbaac` and ROLLBACK v1 `d0487d7cc334` SUPERSEDED, do not run] | thread Round 83 | 1 | QA PASS WITH CONDITIONS (Round 84); Gates 2 and 3 granted (Round 85); NOT run yet |
| D-06 routine writers of flashcards and notes (read-only) | `D-06_DIAGNOSTIC_D6_flashcards-notes-sdt-routine-writers_v2.sql` `2dbc3c7498aa` [v1 `8a17b5b10f28` SUPERSEDED, failed 2201B, do not run] | thread Round 82 | 0 | RUN 09/10/2026 (6 writers; evidence index `T-002_D6-index_09-10-2026.md`) |

Every other `D-0x` and `00_PLAN_*` file in this folder is SUPERSEDED.
