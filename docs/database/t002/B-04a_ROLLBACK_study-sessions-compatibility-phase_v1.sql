-- Name: [SCHEMA] T-002 B-04a ROLLBACK (v1) - archive the classification values, then remove the B-04a objects and restore service_role INSERT and UPDATE
--
-- Description: PERSISTENT DDL, the undo of B-04a_SCHEMA_study-sessions-compatibility-phase_v1.sql. Run it as ONE selection BEFORE B-02b_ROLLBACK, B-02a_ROLLBACK and B-01_ROLLBACK, and AFTER B-06a, B-05
-- (the composite keys of B-05 depend on the unique pair on subjects, so the final DROP fails safely if B-05 is still there). Exact undo order for the whole stream: B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01.
-- It first creates, if absent, public.t002_study_sessions_classification_archive (owner postgres, RLS enabled with no policy, all client privileges revoked), copies the id and the seven new columns of every row
-- whose classification is not NULL, and VERIFIES the copy (row count and a per-row content hash equal between source and archive). If the archive already holds rows that differ from the live rows it stops for
-- review instead of trusting them. Only after that does it drop the trigger, function, constraints and columns, drop the unique pair on subjects, and grant INSERT and UPDATE on study_sessions back to service_role
-- (the D2 state). The archive is an intentional residue; restoring or deleting it later is a separate Founder decision. Existing columns and rows are not touched.
-- Not run unless the Founder decides to undo B-04a. Before B-04a no row has a classification, so the archive is empty until something writes one.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.study_sessions IN ACCESS EXCLUSIVE MODE;

DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.study_sessions'::regclass AND attname = 'classification' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'B-04a ROLLBACK stopped: study_sessions has no classification column (B-04a is not applied)';
  END IF;
END
$guard$;

CREATE TABLE IF NOT EXISTS public.t002_study_sessions_classification_archive (
  id uuid PRIMARY KEY,
  classification text,
  discipline_id uuid,
  subject_id uuid,
  custom_course_label text,
  custom_course_key text,
  custom_subject_label text,
  custom_subject_key text,
  archived_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.t002_study_sessions_classification_archive ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.t002_study_sessions_classification_archive FROM PUBLIC, anon, authenticated, service_role;

DO $archive$
DECLARE
  v_src_n integer;
  v_src_h text;
  v_arc_n integer;
  v_arc_h text;
BEGIN
  SELECT count(*), coalesce(md5(string_agg(jsonb_build_array(id, classification, discipline_id, subject_id, custom_course_label, custom_course_key, custom_subject_label, custom_subject_key)::text, '|' ORDER BY id)), '')
    INTO v_src_n, v_src_h FROM public.study_sessions WHERE classification IS NOT NULL;
  SELECT count(*), coalesce(md5(string_agg(jsonb_build_array(id, classification, discipline_id, subject_id, custom_course_label, custom_course_key, custom_subject_label, custom_subject_key)::text, '|' ORDER BY id)), '')
    INTO v_arc_n, v_arc_h FROM public.t002_study_sessions_classification_archive;
  IF v_arc_n > 0 AND (v_arc_n <> v_src_n OR v_arc_h <> v_src_h) THEN
    RAISE EXCEPTION 'B-04a ROLLBACK stopped: the archive already holds % rows that differ from the % live classified rows; review before any drop', v_arc_n, v_src_n;
  END IF;
  IF v_arc_n = 0 THEN
    INSERT INTO public.t002_study_sessions_classification_archive (id, classification, discipline_id, subject_id, custom_course_label, custom_course_key, custom_subject_label, custom_subject_key)
    SELECT id, classification, discipline_id, subject_id, custom_course_label, custom_course_key, custom_subject_label, custom_subject_key
      FROM public.study_sessions WHERE classification IS NOT NULL;
  END IF;
  SELECT count(*), coalesce(md5(string_agg(jsonb_build_array(id, classification, discipline_id, subject_id, custom_course_label, custom_course_key, custom_subject_label, custom_subject_key)::text, '|' ORDER BY id)), '')
    INTO v_arc_n, v_arc_h FROM public.t002_study_sessions_classification_archive;
  IF v_arc_n <> v_src_n OR v_arc_h <> v_src_h THEN
    RAISE EXCEPTION 'B-04a ROLLBACK stopped: the archive copy is not faithful (rows % vs %); nothing is dropped', v_arc_n, v_src_n;
  END IF;
END
$archive$;

DROP TRIGGER IF EXISTS trg_study_sessions_label_guard ON public.study_sessions;
DROP FUNCTION IF EXISTS public.fn_study_sessions_label_guard();

ALTER TABLE public.study_sessions
  DROP CONSTRAINT IF EXISTS study_sessions_machine_source_unclassified,
  DROP CONSTRAINT IF EXISTS study_sessions_classification_shape,
  DROP CONSTRAINT IF EXISTS study_sessions_classification_values,
  DROP CONSTRAINT IF EXISTS study_sessions_discipline_subject_fkey,
  DROP CONSTRAINT IF EXISTS study_sessions_discipline_id_fkey;

ALTER TABLE public.study_sessions
  DROP COLUMN IF EXISTS custom_subject_key,
  DROP COLUMN IF EXISTS custom_subject_label,
  DROP COLUMN IF EXISTS custom_course_key,
  DROP COLUMN IF EXISTS custom_course_label,
  DROP COLUMN IF EXISTS subject_id,
  DROP COLUMN IF EXISTS discipline_id,
  DROP COLUMN IF EXISTS classification;

ALTER TABLE public.subjects DROP CONSTRAINT IF EXISTS subjects_discipline_id_id_key;

GRANT INSERT, UPDATE ON TABLE public.study_sessions TO service_role;

SELECT (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.study_sessions'::regclass AND attnum > 0 AND NOT attisdropped) AS study_sessions_columns_expected_10,
       (SELECT count(*) FROM public.t002_study_sessions_classification_archive) AS archive_rows,
       has_table_privilege('service_role', 'public.study_sessions', 'UPDATE') AS service_role_update_restored,
       has_table_privilege('service_role', 'public.study_sessions', 'INSERT') AS service_role_insert_restored;
