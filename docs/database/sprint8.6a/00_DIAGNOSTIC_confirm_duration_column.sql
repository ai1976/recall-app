-- [DIAGNOSTIC] Confirm live column definition + existing constraints on study_sessions.duration_seconds
-- Description: Sprint 8.6a pre-flight. Confirms duration_seconds is NOT NULL
-- (per docs/reference/DATABASE_SCHEMA.md) and lists any existing CHECK
-- constraints on the column before adding the new 10-minute floor, so the
-- new constraint's predicate can be written against the real column
-- definition rather than assumed from docs. Run before 01_SCHEMA.

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'study_sessions'
  AND column_name = 'duration_seconds';

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass
  AND contype = 'c';
