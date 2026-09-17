-- [SCHEMA] Enforce a 10-minute floor on study_sessions.duration_seconds
-- Description: Sprint 8.6a. The frontend already discards manual timer
-- stops under the floor before they ever reach the insert (see
-- StudyTimerContext.jsx stopAndLog()), but nothing in the database stops a
-- future write path (a bulk import, a different form, a regression) from
-- inserting a sub-threshold row. This constraint closes that gap at the
-- database layer, independent of the frontend — same rationale as
-- study_sessions_manual_requires_category (Sprint 8.5).
--
-- duration_seconds is NOT NULL (confirmed via 00_DIAGNOSTIC), so no
-- IS NULL escape hatch is needed in the predicate.
--
-- NOT VALID means: not checked against rows that already exist — any
-- historical sub-10-minute session (logged before this sprint, when the
-- floor was 10 seconds) stays exactly as it is, no backfill, no rewrite of
-- history — but fully enforced on every INSERT from this point forward.
-- study_sessions has no UPDATE path at all (confirmed in Sprint 8.5's
-- 03_DIAGNOSTIC_confirm_study_sessions_immutable.sql — no RLS UPDATE
-- policy, no function mutates it, no trigger is attached to it), so rows
-- are write-once and "future INSERT" is the only case this will ever gate.
--
-- Run 00_DIAGNOSTIC_confirm_duration_column.sql first.

ALTER TABLE study_sessions
  ADD CONSTRAINT study_sessions_duration_floor
  CHECK (duration_seconds >= 600) NOT VALID;
