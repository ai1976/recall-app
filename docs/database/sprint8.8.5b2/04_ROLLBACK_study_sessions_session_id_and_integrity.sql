-- [SCHEMA] ROLLBACK for 02: remove session_id + the two integrity constraints
-- Description: Restores study_sessions to its pre-02 shape. Existing rows are untouched, EXCEPT that any
--   session_id values written by the new tracker are lost when the column is dropped. Run this ONLY if the
--   new frontend has not been deployed (or has been reverted), otherwise its inserts will fail on the missing column.

DROP INDEX IF EXISTS public.study_sessions_user_session_uidx;
ALTER TABLE public.study_sessions DROP CONSTRAINT IF EXISTS study_sessions_machine_time_integrity;
ALTER TABLE public.study_sessions DROP CONSTRAINT IF EXISTS study_sessions_machine_duration_max;
ALTER TABLE public.study_sessions DROP COLUMN IF EXISTS session_id;
