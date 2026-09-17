-- [TEST] Verify study_sessions_duration_floor deployed correctly
-- Description: Run after 01_SCHEMA_add_duration_floor.sql. Proves the three
-- cases the sprint testing plan asked for. Sections 1-2 are real writes
-- wrapped in BEGIN/ROLLBACK (study_sessions has no DELETE policy, so a
-- manual cleanup DELETE could silently no-op under RLS — ROLLBACK avoids
-- that risk). Section 1 is designed to error — per Sprint 8.5's own note,
-- the Supabase SQL Editor stops at the first error, so run section 1 by
-- itself, then sections 2-3 together (or all three separately, if
-- preferred). Uses the project's TestOutlook test account
-- (anandmore@outlook.com), looked up via profiles.email — auth.uid() is
-- NULL in the SQL Editor's no-session context.

-- 1. A new session under the 10-minute floor (599s) must be rejected
BEGIN;

INSERT INTO public.study_sessions
  (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES
  ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
   now() - interval '599 seconds', now(), 599, CURRENT_DATE, 'manual', 'reading');
-- expect: error, check_violation (23514) on study_sessions_duration_floor

ROLLBACK;

-- 2. A new session AT exactly the floor (600s) must still succeed
BEGIN;

INSERT INTO public.study_sessions
  (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES
  ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
   now() - interval '600 seconds', now(), 600, CURRENT_DATE, 'manual', 'reading')
RETURNING duration_seconds;
-- expect: 1 row, duration_seconds = 600

ROLLBACK;

-- 3. At least one pre-existing historical row under 600s (logged before
-- this sprint, when the floor was 10 seconds) remains readable and
-- untouched (constraint is NOT VALID — never scans or rewrites existing
-- rows, only gates future writes; this is a read-only SELECT, nothing to
-- roll back).
SELECT count(*) AS historical_sub_floor_rows
FROM public.study_sessions
WHERE duration_seconds < 600;
-- expect: same count as before 01_SCHEMA ran (unchanged) — if 0, there is
-- no live historical row to demonstrate against; the guarantee still holds
-- (NOT VALID's skip-existing-rows behavior doesn't depend on row count),
-- but note that explicitly rather than treating an empty result as proof.

SELECT id, user_id, duration_seconds, source, created_at
FROM public.study_sessions
WHERE duration_seconds < 600
ORDER BY created_at ASC
LIMIT 3;
-- expect: reads back cleanly with no error, duration_seconds unchanged, nothing rewritten
