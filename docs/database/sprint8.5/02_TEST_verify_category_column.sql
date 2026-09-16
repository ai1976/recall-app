-- [TEST] Verify Sprint 8.5 category column deployed correctly
-- Description: Run after 01_SCHEMA_add_study_session_category.sql. Confirms
-- the column exists with the right CHECK constraint and that pre-existing
-- rows are untouched (category IS NULL). Sections 3-4 exercise real writes
-- inside BEGIN/ROLLBACK — study_sessions has no DELETE policy (rows are
-- immutable by design), so a manual DELETE cleanup step could silently no-op
-- under RLS and leave a fake session in the table; ROLLBACK avoids that risk
-- entirely rather than relying on cleanup succeeding.
--
-- auth.uid() is NULL in the Supabase SQL Editor (no client session/JWT), so
-- sections 3-4 use the project's existing disposable test account
-- (anandmore@outlook.com / TestOutlook, the same one Sprint 8.4's
-- 02_FIX_reset_exam_prompt_dismissal_test_account.sql scopes by email)
-- instead of auth.uid() — confirmed 16/09/2026 after auth.uid() being NULL
-- caused a NOT NULL violation on the first run.

-- 1. Column exists, correct type/nullability
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_sessions' AND column_name = 'category';
-- expect: 1 row, data_type = text, is_nullable = YES

-- 2. Every pre-existing row has no category (no backfill happened)
SELECT count(*) AS rows_with_unexpected_category
FROM public.study_sessions
WHERE created_at < now() - interval '1 minute' AND category IS NOT NULL;
-- expect: 0

-- 3. Real write, rolled back — valid category inserts cleanly
BEGIN;

INSERT INTO public.study_sessions
  (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES
  ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
   now() - interval '10 minutes', now(), 600, CURRENT_DATE, 'manual', 'reading')
RETURNING category;
-- expect: 1 row, category = 'reading'

ROLLBACK;

-- 4. Real write, rolled back — invalid category is rejected by the CHECK constraint
BEGIN;

INSERT INTO public.study_sessions
  (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES
  ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
   now() - interval '10 minutes', now(), 600, CURRENT_DATE, 'manual', 'not_a_real_category');
-- expect: error, check_violation (23514)

ROLLBACK;
