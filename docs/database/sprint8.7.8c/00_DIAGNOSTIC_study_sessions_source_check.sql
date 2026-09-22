-- Name: [DIAGNOSTIC] study_sessions_source_check constraint definition
--
-- Description: Sprint 8.7.8c hit a live 23514 violation inserting source='practice_mode' into
-- study_sessions — contrary to Step 0's finding (which only located the source-scoped duration
-- floor CHECK, not a value-enum CHECK on source itself). This confirms a CHECK constraint on
-- `source` exists and does not currently allow 'practice_mode'. Run this to see its exact
-- definition and current live distinct values before any ALTER is written, per CLAUDE.md's rule
-- that a SQL fix for this must be shown to Anand before deployment.

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass
  AND conname = 'study_sessions_source_check';

SELECT source, count(*) FROM public.study_sessions GROUP BY source ORDER BY source;
