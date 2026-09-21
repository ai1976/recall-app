-- [SCHEMA] Scope study_sessions duration floor to manual (offline) sessions only
-- Description: Sprint 8.7.7 B3. Product rule: offline/manual study requires >= 10 minutes (600s); in-app
--   RevisOp study (source = 'study_mode') has NO minimum and must record its real duration. Sprint 8.6a's
--   study_sessions_duration_floor (duration_seconds >= 600) had no source clause, so it rejected every
--   in-app session under 10 minutes (proven live 21/09/2026: 400 / 23514 for source=study_mode, 60s).
--   One atomic ALTER: drops the broad constraint and adds the scoped one.
--   duration_seconds > 0 (study_sessions_duration_seconds_check) is untouched and still applies to all sources.
--   NOT VALID: enforced on every new INSERT/UPDATE from now on, but does NOT re-validate existing rows —
--   historical rows (including sub-600s ones) stay exactly as they are; no backfill.
-- Prerequisite: run 03_DIAGNOSTIC and confirm sources are only manual / study_mode. Run this file ALONE
--   (do not combine with the test file: the SQL Editor wraps a run in one transaction).

ALTER TABLE public.study_sessions
  DROP CONSTRAINT study_sessions_duration_floor,
  ADD CONSTRAINT study_sessions_duration_floor
    CHECK (source <> 'manual' OR duration_seconds >= 600) NOT VALID;
