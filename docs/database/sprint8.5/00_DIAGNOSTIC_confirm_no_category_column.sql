-- [DIAGNOSTIC] Confirm no existing category column on study_sessions
-- Description: Pre-flight check for Sprint 8.5 (Offline Study-Log Categories)
-- — confirms `study_sessions` has no category column already and that its
-- shape still matches DATABASE_SCHEMA.md's last-documented read, verified
-- against live schema rather than trusted from docs. Also re-confirms
-- get_study_time_stats has no category-dependent logic that a purely
-- additive nullable column could break.
-- Run before 01_SCHEMA_add_study_session_category.sql.

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_sessions'
ORDER BY ordinal_position;

SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'get_study_time_stats' AND pronamespace = 'public'::regnamespace;
