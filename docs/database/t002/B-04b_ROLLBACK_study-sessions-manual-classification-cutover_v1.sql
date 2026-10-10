-- Name: [SCHEMA] T-002 B-04b ROLLBACK (v1) - remove the manual-requires-classification constraint
--
-- Description: PERSISTENT DDL (drops one constraint). Undoes B-04b_SCHEMA_study-sessions-manual-classification-cutover_v1.sql: drops study_sessions_manual_requires_classification. Not run unless the Founder authorizes it by hash.
-- Changes no row. After it, a manual log without a classification is accepted again (the pre-B-04b state). One selection = ONE transaction; lock_timeout 5 s.
-- Expected: one result row with "constraint_present":false and the legacy set count unchanged. (There is no data fix in this plan, so no row needs restoring: change-log Entry 24.)

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.study_sessions IN ACCESS EXCLUSIVE MODE;

DO $rb$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_classification') THEN
    RAISE EXCEPTION 'B-04b rollback stopped: study_sessions_manual_requires_classification is not present';
  END IF;
  ALTER TABLE public.study_sessions DROP CONSTRAINT study_sessions_manual_requires_classification;
END
$rb$;

SELECT jsonb_build_object(
  'tool_version', 'B04b-ROLLBACK-v1',
  'constraint_present', EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_classification'),
  'legacy_set_count', (SELECT count(*) FROM public.study_sessions WHERE source = 'manual' AND classification IS NULL),
  'study_sessions_total', (SELECT count(*) FROM public.study_sessions)
) AS result;
