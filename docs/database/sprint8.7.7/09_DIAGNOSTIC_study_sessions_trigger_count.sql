-- [DIAGNOSTIC] Definitive count of user triggers on study_sessions
-- Description: READ-ONLY. Sprint 8.7.7. The earlier trigger listing could not be told apart from an EMPTY result
--   (the SQL Editor keeps showing the previous grid when a query returns no rows). This returns exactly one row
--   either way. Expect trigger_count = 0 (Sprint 8.5 found none).
SELECT count(*) AS trigger_count,
       coalesce(string_agg(tgname, ', '), '(none)') AS trigger_names
FROM pg_trigger
WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal;
