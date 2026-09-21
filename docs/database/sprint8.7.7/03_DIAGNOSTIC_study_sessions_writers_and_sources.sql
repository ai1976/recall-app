-- [DIAGNOSTIC] study_sessions writers, live source values, existing sub-600s rows
-- Description: READ-ONLY. Sprint 8.7.7 B3 pre-flight. Run BEFORE 04_SCHEMA. Confirms that 'manual' and
--   'study_mode' are the only sources in use, that no database function/trigger writes study_sessions
--   with another source, and shows how many existing rows sit under 600s (they stay untouched: the new
--   constraint is NOT VALID). Run each numbered query separately and paste all results.
--   Code audit already done (21/09/2026): the only client writers are StudyTimerContext.jsx (source='manual',
--   always with category) and StudyMode.jsx (source='study_mode').

-- 1. Sources actually stored, with duration profile
SELECT source,
       count(*)                                              AS rows,
       count(*) FILTER (WHERE duration_seconds < 600)        AS rows_under_600,
       min(duration_seconds)                                 AS min_seconds,
       max(created_at)                                       AS latest
FROM public.study_sessions
GROUP BY source
ORDER BY source;

-- 2. Any database function/procedure whose body mentions study_sessions (possible hidden writers).
--    CASE guards pg_get_functiondef so it is never called on aggregates (which raise 42809).
SELECT n.nspname AS schema, p.proname AS function_name,
       (CASE WHEN p.prokind IN ('f','p') THEN pg_get_functiondef(p.oid) END) ~* 'insert[[:space:]]+into[[:space:]]+(public[.])?study_sessions' AS inserts_into_it
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','extensions')
  AND (CASE WHEN p.prokind IN ('f','p') THEN pg_get_functiondef(p.oid) END) ILIKE '%study_sessions%'
ORDER BY 1, 2;

-- 3. Real triggers on study_sessions (the earlier (c) result duplicated the constraint list, so re-check)
SELECT tgname, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal;

-- 4. Current duration-related constraints (before the change)
SELECT conname, convalidated, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass AND contype = 'c'
ORDER BY conname;

-- 5. In-app (study_mode) sessions by day since the floor went live (17/09/2026), split by the 600s line.
--    Shows when in-app rows stopped being accepted below 600s (the bug window) and what still got through.
SELECT created_at::date                                        AS day,
       count(*)                                                AS study_mode_rows,
       count(*) FILTER (WHERE duration_seconds < 600)          AS under_600,
       count(*) FILTER (WHERE duration_seconds >= 600)         AS at_or_over_600
FROM public.study_sessions
WHERE source = 'study_mode' AND created_at >= '2026-09-14'
GROUP BY 1
ORDER BY 1;
