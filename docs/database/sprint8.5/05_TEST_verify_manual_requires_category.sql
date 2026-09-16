-- [TEST] Verify study_sessions_manual_requires_category deployed correctly
-- Description: Run after 04_SCHEMA_manual_requires_category.sql. Proves all
-- three cases the quality-auditor review asked for. Sections 1-2 are real
-- writes wrapped in BEGIN/ROLLBACK (study_sessions has no DELETE policy, so
-- a manual cleanup DELETE could silently no-op under RLS — ROLLBACK avoids
-- that risk). Section 1 is designed to error — per 02_TEST's own note, the
-- Supabase SQL Editor stops at the first error, so run section 1 by itself,
-- then sections 2-3 together (or all three separately, if preferred).
-- Uses the project's TestOutlook test account (anandmore@outlook.com),
-- looked up via profiles.email, same as 02_TEST — auth.uid() is NULL in the
-- SQL Editor's no-session context.

-- 1. A new manual session with NO category must be rejected
BEGIN;

INSERT INTO public.study_sessions
  (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES
  ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
   now() - interval '10 minutes', now(), 600, CURRENT_DATE, 'manual', NULL);
-- expect: error, check_violation (23514) on study_sessions_manual_requires_category

ROLLBACK;

-- 2. A new manual session WITH a valid category must still succeed
BEGIN;

INSERT INTO public.study_sessions
  (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES
  ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
   now() - interval '10 minutes', now(), 600, CURRENT_DATE, 'manual', 'lecture_viewing')
RETURNING category;
-- expect: 1 row, category = 'lecture_viewing'

ROLLBACK;

-- 3. At least one pre-existing historical manual row with category IS NULL
-- remains readable and untouched (constraint is NOT VALID — never scans or
-- rewrites existing rows, only gates future writes; this is a read-only
-- SELECT, nothing to roll back).
SELECT count(*) AS historical_manual_null_category_rows
FROM public.study_sessions
WHERE source = 'manual' AND category IS NULL;
-- expect: same count as before 04_SCHEMA ran (unchanged) — if 0, there is
-- no live historical row to demonstrate against; the guarantee still holds
-- (NOT VALID's skip-existing-rows behavior doesn't depend on row count),
-- but note that explicitly rather than treating an empty result as proof.

SELECT id, user_id, category, source, created_at
FROM public.study_sessions
WHERE source = 'manual' AND category IS NULL
ORDER BY created_at ASC
LIMIT 3;
-- expect: reads back cleanly with no error, category still NULL, nothing changed
