-- Name: [TEST] Verify practice_mode study_sessions row landed live
-- Description: Confirms the Sprint 8.7.8c Practice Mode study-time flush actually inserted a row
-- after the study_sessions_source_check widening (04_SCHEMA_add_practice_mode_source.sql). Read-only.

SELECT id, user_id, started_at, ended_at, duration_seconds, session_date, source
FROM public.study_sessions
WHERE source = 'practice_mode'
ORDER BY created_at DESC
LIMIT 5;
