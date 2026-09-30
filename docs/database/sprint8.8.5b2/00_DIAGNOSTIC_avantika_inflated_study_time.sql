-- [DIAGNOSTIC] Avantika Hagawane - 709h 16m "in-app" study time on 29/09/2026
-- Description: READ-ONLY. Shows every study_sessions row for the user that is
-- either on 29/09/2026 or longer than 4 hours, plus a per-day/per-source total
-- and any DB-side cap/constraint on duration_seconds. Confirms (or refutes) the
-- suspected cause: a stale localStorage start-time key (revisop_session_started_at)
-- being closed days/weeks after it was set, producing one giant study_mode row.
-- User id: 1de7a5d4-c780-4a5b-be53-47b95bb9e308
-- Run each block separately in the Supabase SQL editor and paste the results.

-- Block 1: suspicious rows (that day, or any single session over 4h)
SELECT id, source, session_date, started_at, ended_at, duration_seconds,
       round(duration_seconds / 3600.0, 2) AS hours,
       round(extract(epoch FROM (ended_at - started_at)) / 3600.0, 2) AS ended_minus_started_hours,
       created_at
FROM public.study_sessions
WHERE user_id = '1de7a5d4-c780-4a5b-be53-47b95bb9e308'
  AND (session_date = DATE '2026-09-29' OR duration_seconds > 4 * 3600)
ORDER BY created_at DESC;

-- Block 2: totals per day and source (last 45 days)
SELECT session_date, source, count(*) AS sessions,
       sum(duration_seconds) AS seconds,
       round(sum(duration_seconds) / 3600.0, 2) AS hours
FROM public.study_sessions
WHERE user_id = '1de7a5d4-c780-4a5b-be53-47b95bb9e308'
  AND session_date >= DATE '2026-08-15'
GROUP BY session_date, source
ORDER BY session_date DESC, source;

-- Block 3: is the problem platform-wide? Any session over 4h, any user
SELECT user_id, source, count(*) AS rows_over_4h,
       max(duration_seconds) AS longest_seconds,
       round(max(duration_seconds) / 3600.0, 1) AS longest_hours
FROM public.study_sessions
WHERE duration_seconds > 4 * 3600
GROUP BY user_id, source
ORDER BY longest_seconds DESC;

-- Block 4: existing constraints/triggers on study_sessions (catalog check)
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass;

SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public' AND event_object_table = 'study_sessions';
