-- [SCHEMA] ROLLBACK: restore the Sprint 8.6a broad duration floor
-- Description: Reverts 04_SCHEMA. Restores study_sessions_duration_floor to CHECK (duration_seconds >= 600) NOT VALID
--   for ALL sources. NOTE: this brings back the bug (in-app sessions under 10 minutes are rejected with 400),
--   so use it only if the scoped constraint itself misbehaves. Run alone.

ALTER TABLE public.study_sessions
  DROP CONSTRAINT study_sessions_duration_floor,
  ADD CONSTRAINT study_sessions_duration_floor
    CHECK (duration_seconds >= 600) NOT VALID;
