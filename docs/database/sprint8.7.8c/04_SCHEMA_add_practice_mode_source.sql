-- Name: [SCHEMA] Add 'practice_mode' to study_sessions_source_check
--
-- Description: Sprint 8.7.8c — Practice Mode's study-time logging failed live with 23514
-- ("study_sessions_source_check") because the CHECK constraint only allows source IN
-- ('manual', 'study_mode') (confirmed via 00_DIAGNOSTIC_study_sessions_source_check.sql — 433
-- 'manual' rows, 245 'study_mode' rows, no others). Step 0's original diagnosis (no CHECK enum on
-- source, only the source-scoped duration-floor CHECK) was wrong; this is the correction, shown to
-- Anand before deployment per the sprint's explicit instruction.
--
-- Purely additive: widens the allowed set to ('manual', 'study_mode', 'practice_mode'). No existing
-- row's source value is touched. The separate duration-floor CHECK
-- (study_sessions_duration_floor: `source <> 'manual' OR duration_seconds >= 600`,
-- docs/database/sprint8.7.7/04_SCHEMA_scope_duration_floor_to_manual.sql) already treats every
-- non-'manual' source identically (no minimum), so 'practice_mode' automatically inherits the same
-- 10-second in-app noise floor as 'study_mode' with no further change needed there.
--
-- Deployment: run this alone (persistent DDL — do not mix with a verification ROLLBACK in the same
-- execution, per the L3 17c lesson). Then re-run Practice Mode's study-time flow live to confirm.
-- Rollback: 05_SCHEMA_ROLLBACK_remove_practice_mode_source.sql (only safe if no practice_mode rows
-- have been written yet — see that file's own guard).

ALTER TABLE public.study_sessions DROP CONSTRAINT study_sessions_source_check;

ALTER TABLE public.study_sessions ADD CONSTRAINT study_sessions_source_check
  CHECK (source = ANY (ARRAY['manual'::text, 'study_mode'::text, 'practice_mode'::text]));
