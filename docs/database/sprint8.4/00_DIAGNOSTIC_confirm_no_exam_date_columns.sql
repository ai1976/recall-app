-- [DIAGNOSTIC] Confirm no existing exam-date columns on profiles
-- Description: Pre-flight check for Sprint 8.4 (Exam Date Field) — confirms
-- `profiles` has no exam_date/exam_month/exam-related column already, verified
-- against live schema rather than trusted from docs (which have drifted before).
-- Run before 01_SCHEMA_add_exam_date_tracking.sql.

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;
