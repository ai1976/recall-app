-- [SCHEMA] study_sessions: session_id (idempotent saves) + duration/timestamp integrity for machine-timed sessions
-- Description: Step "SQL first" of the study-timer integrity fix (Avantika's 709h row).
--   1. session_id uuid (nullable) + partial UNIQUE index on (user_id, session_id). The new frontend tracker saves
--      one row per timed session with a stable session_id; a repeat save (retry, double click, second tab, duplicate
--      recovery) fails with 23505 on this index and the client treats that as "already saved".
--      Unique per USER, not global, so one user's id can never block another user's insert.
--   2. study_sessions_machine_duration_max : source = 'manual' OR duration_seconds <= 14400 (4 hours).
--      NOT VALID on purpose - 20 existing rows are already over 4h (16 manual, 3 study_mode, 1 practice_mode).
--      Enforced on every new INSERT, existing rows never re-validated.
--   3. study_sessions_machine_time_integrity : source = 'manual' OR (ended_at >= started_at AND
--      duration_seconds <= wall-clock span + 2s). Deliberately NOT "span <= 4h": under pause/resume the wall-clock
--      span may exceed the active duration. Live diagnostic (01, block 3a) showed 0 existing rows violate this in
--      any source, so it is added VALIDATED.
--   Manual sessions are untouched (they keep their own floor/category rules).
-- Live facts this relies on (01 diagnostic, 30/09/2026): no triggers on the table; RLS = INSERT + SELECT own rows
--   only; no functions/views/cron write it; started_at/ended_at NOT NULL; no session_id column existed.
-- Run once. Then run 03 (test). Rollback = 04.

DO $mig$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'study_sessions' AND column_name = 'session_id'
  ) THEN
    ALTER TABLE public.study_sessions ADD COLUMN session_id uuid;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_machine_duration_max'
  ) THEN
    ALTER TABLE public.study_sessions
      ADD CONSTRAINT study_sessions_machine_duration_max
      CHECK (source = 'manual' OR duration_seconds <= 14400) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_machine_time_integrity'
  ) THEN
    ALTER TABLE public.study_sessions
      ADD CONSTRAINT study_sessions_machine_time_integrity
      CHECK (
        source = 'manual'
        OR (ended_at >= started_at
            AND duration_seconds <= extract(epoch FROM (ended_at - started_at)) + 2)
      );
  END IF;
END
$mig$;

CREATE UNIQUE INDEX IF NOT EXISTS study_sessions_user_session_uidx
  ON public.study_sessions (user_id, session_id)
  WHERE session_id IS NOT NULL;

COMMENT ON COLUMN public.study_sessions.session_id IS
  'Client-generated stable id of one timed session (study_mode / practice_mode). NULL for manual rows and for rows written before Sprint 8.8.5b2. Unique per user; a duplicate save raises 23505 on study_sessions_user_session_uidx and is treated by the client as already saved.';
