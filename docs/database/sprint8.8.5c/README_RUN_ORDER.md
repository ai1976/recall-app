# Sprint 8.8.5c — what to run, in what order

Numbers are the order files were written, **not** always the order to run them. This table is the source of truth.
Rule: run ONE file at a time, on its own, and paste the result before the next step.

## Already done (ignore)
`00_DIAGNOSTIC…`, `01_DIAGNOSTIC…`, `02_DIAGNOSTIC_pre_sql_checks.sql` — read-only checks, results reviewed.

## To run, in this order
| Step | File | What it does | Expected output |
|---|---|---|---|
| 1 | `03_SCHEMA_course_archive_columns_and_constraint.sql` | Adds the `course_archived` status, 2 nullable columns, a consistency CHECK and a clean-up trigger. No behaviour change yet. | `Success. No rows returned` |
| 2 | `04_FUNCTIONS_course_change_impact_and_preview.sql` | The shared "what would be archived / restored" function + the preview the dialog will call. Read-only. | `Success. No rows returned` |
| 3 | `06_FUNCTIONS_get_course_archived_my_cards.sql` | Read-only list for the History "Archived — course change" section. | `Success. No rows returned` |
| 4 | `05_FUNCTIONS_course_change_trigger.sql` | **The behaviour change:** from now on a real course change archives / restores. | `Success. No rows returned` |
| 5 | `08_TEST_course_change_regression.sql` | Rollback-only regression matrix on TestOutlook. **Paste the table.** Every row must be PASS. | table |
| 6 | `10_DATA_backfill_course_archive_approved_population.sql` | One-time archive of the approved 24 users / 1,903 enrollments. Aborts safely if the numbers drifted. | one row: `24`, `1903` |
| 7 | `11_TEST_verify_backfill.sql` | Read-only verification of the backfill. | table, all PASS |
| 8 | (optional idempotency) run `10` again, then `11` again | Must change nothing. | same numbers |
| 9 | `07_FUNCTIONS_bulk_my_cards_rpcs.sql` | The three bulk Pause / Resume / Remove RPCs (independent feature). | `Success. No rows returned` |
| 10 | `09_TEST_bulk_my_cards_rpcs.sql` | Rollback-only test of the bulk RPCs. **Paste the table.** | table |

Stop and report at the first FAIL or error. Do not continue to the next step.

## Never run unless told
`12_ROLLBACK_course_archive_all.sql` — emergency undo of everything above.

## Then (frontend — only after steps 1–10 pass)
Profile Settings confirmation flow; My Study "Archived — course change" section; bulk actions. Not built yet.
