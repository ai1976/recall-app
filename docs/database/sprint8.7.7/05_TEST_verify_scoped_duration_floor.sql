-- [TEST] Verify the scoped duration floor (manual 599 blocked, manual 600 allowed, study_mode 60 allowed)
-- Description: Run AFTER 04_SCHEMA. Every write is inside BEGIN/ROLLBACK (study_sessions has no DELETE
--   policy, so ROLLBACK is the only safe cleanup). Same pattern as sprint8.6a/02_TEST. Uses the TestOutlook
--   account looked up via profiles.email (auth.uid() is NULL in the SQL Editor).
--   Section 1 is designed to error: the SQL Editor stops at the first error, so run each numbered
--   section on its own, one after another.

-- 1. manual, 599s -> must be REJECTED (expect 23514 on study_sessions_duration_floor)
BEGIN;
INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
        now() - interval '599 seconds', now(), 599, CURRENT_DATE, 'manual', 'reading');
ROLLBACK;

-- 2. manual, 600s -> must SUCCEED (expect 1 row, duration_seconds = 600)
BEGIN;
INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, category)
VALUES ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
        now() - interval '600 seconds', now(), 600, CURRENT_DATE, 'manual', 'reading')
RETURNING duration_seconds, source;
ROLLBACK;

-- 3. study_mode, 60s -> must SUCCEED (expect 1 row, duration_seconds = 60)
BEGIN;
INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source)
VALUES ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
        now() - interval '60 seconds', now(), 60, CURRENT_DATE, 'study_mode')
RETURNING duration_seconds, source;
ROLLBACK;

-- 4. study_mode, 0s -> must still be REJECTED by duration_seconds > 0 (expect 23514 on study_sessions_duration_seconds_check)
BEGIN;
INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source)
VALUES ((SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com'),
        now(), now(), 0, CURRENT_DATE, 'study_mode');
ROLLBACK;

-- 5. Final state (read-only): new constraint present, NOT VALID, and old rows untouched
SELECT conname, convalidated, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_duration_floor';
-- expect: convalidated = false, definition = CHECK (((source <> 'manual'::text) OR (duration_seconds >= 600)))

SELECT count(*) AS rows_under_600_still_present FROM public.study_sessions WHERE duration_seconds < 600;
-- expect: same count as 03_DIAGNOSTIC query 1 (rows_under_600 summed across sources)
