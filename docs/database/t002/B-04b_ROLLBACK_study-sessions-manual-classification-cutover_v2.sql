-- Name: [SCHEMA] T-002 B-04b ROLLBACK (v2) - remove the manual-requires-classification constraint
--
-- Description: PERSISTENT DDL (drops one constraint). Undoes B-04b_SCHEMA_study-sessions-manual-classification-cutover_v2.sql: drops study_sessions_manual_requires_classification. Not run unless the Founder authorizes it by hash.
-- Changes no row. After it, a manual log without a classification is accepted again (the pre-B-04b state). One selection = ONE transaction; lock_timeout 5 s.
-- Expected: one result row with "constraint_present":false and the legacy set count unchanged. (There is no data fix in this plan, so no row needs restoring: change-log Entry 24.)

SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;
SET LOCAL search_path = pg_catalog, public, pg_temp;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.study_sessions IN ACCESS EXCLUSIVE MODE;

DO $rb$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_classification' AND contype = 'c' AND NOT convalidated
                    AND regexp_replace(pg_get_constraintdef(oid), '[\s()]', '', 'g') = $d$CHECKsourceISDISTINCTFROM'manual'::textORclassificationISNOTNULLNOTVALID$d$) THEN
    RAISE EXCEPTION 'B-04b rollback stopped: study_sessions_manual_requires_classification is not present as B-04b built it';
  END IF;
  ALTER TABLE public.study_sessions DROP CONSTRAINT study_sessions_manual_requires_classification;
END
$rb$;

WITH c AS (SELECT s.id::text AS id, encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord) FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fp FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL)
SELECT jsonb_build_object(
  'tool_version', 'B04b-ROLLBACK-v2',
  'constraint_present', EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_classification'),
  'legacy_set_count', (SELECT count(*) FROM c),
  'legacy_set_overall_hash', (SELECT encode(sha256(convert_to(COALESCE(string_agg(c.id || ':' || c.fp, ',' ORDER BY c.id COLLATE "C"), ''), 'UTF8')), 'hex') FROM c),
  'study_sessions_total', (SELECT count(*) FROM public.study_sessions)
) AS result;
