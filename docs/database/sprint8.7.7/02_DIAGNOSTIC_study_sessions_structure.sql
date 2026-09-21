-- Name: [DIAGNOSTIC] study_sessions columns, constraints, triggers
-- Description: READ-ONLY. Sprint 8.7.7 B3. Lists study_sessions columns (type, nullability, default),
--   all CHECK/NOT NULL-relevant constraints, and triggers, to compare against the client insert payloads.
--   Run as three separate result tabs or one at a time; paste all three.

-- (a) columns
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_sessions'
ORDER BY ordinal_position;

-- (b) constraints
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass;

-- (c) triggers
SELECT tgname, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal;
