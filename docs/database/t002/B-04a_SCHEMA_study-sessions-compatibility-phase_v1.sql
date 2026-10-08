-- Name: [SCHEMA] T-002 B-04a (v1) - study_sessions compatibility phase: course classification columns, keys, shape checks, label guard, service_role UPDATE and INSERT closure
--
-- Description: PERSISTENT DDL. Implements brief B v10 (0fe77dec72dc) sections 4.1 and 4.2 (without the manual rule, which is B-04b) and plan v18 section 5.1 (tiered workflow; Tier 1: QA audits this exact
-- file by hash, at most two rounds; the Founder authorizes the run by hash). Run ONLY after B-01, B-02a and B-02b are live (done 08/10/2026). One selection in the Supabase SQL Editor = ONE
-- transaction. The file takes ACCESS EXCLUSIVE on study_sessions first (stored generated columns rewrite the table: 1,741 rows, 229,376 bytes in D2), under lock_timeout 5 s and statement_timeout 30 s;
-- on timeout nothing is applied and the file can be run again at a quiet moment. No verification and no ROLLBACK inside it (verification is B-04a_TEST, undo is B-04a_ROLLBACK); it ends with one
-- read-only proof row (the no-backfill hash before and after).
--
-- LIVE STATE THIS FILE IS BUILT ON (D2 v3 of 08/10/2026; evidence index docs/discussions/evidence/T-002_D2-index_08-10-2026.md). The pre-flight below aborts, changing nothing, unless the live state
-- equals it exactly: the ten columns, the nine constraints with their definitions, the three indexes, the two RLS policies, no trigger and no rule, no column ACL, the exact table ACL, and the
-- constraints and index of subjects; plus B-01, B-02a. A change since D2 is therefore caught instead of silently combined.
--
-- WHAT IT DOES
--   1. subjects: UNIQUE (discipline_id, id), the target of the composite key.
--   2. study_sessions: seven nullable columns: classification, discipline_id, subject_id, custom_course_label, custom_course_key (stored, generated from the label by normalize_course_text, so a client
--      cannot set it), custom_subject_label, custom_subject_key (same). Rows that exist stay NULL in all of them (no backfill; proved by a hash below).
--   3. Foreign keys, both NOT VALID: discipline_id -> disciplines(id); (discipline_id, subject_id) -> subjects(discipline_id, id).
--   4. CHECKs, all NOT VALID and all two-valued: classification is platform, custom, general or NULL; the shape of each class (NULL classification requires every classification column NULL; platform
--      requires discipline_id and no custom label; custom requires a course label and no discipline or subject id; general requires all NULL); a study_mode or practice_mode row must have a NULL
--      classification. Not here: the manual rule (B-04b). Existing constraints are unchanged.
--   5. Trigger fn_study_sessions_label_guard (SECURITY DEFINER, pinned search_path, owner only): trims both labels and refuses empty, over 120 characters, or a control character (SQLSTATE 23514);
--      refuses a custom COURSE label that normalizes to any discipline name, active or inactive (it must be sent as a platform course); stores a catalogue label (the six CMA and CS labels) in its
--      exact canonical text through resolve_canonical_course_label. Fires on INSERT and on UPDATE OF either label (a defensive cover; no code updates these columns).
--   6. Privileges: REVOKE UPDATE and INSERT on study_sessions from service_role (plan 5.2 and 10B R3: UPDATE is a gating item with no consumer exception; D4 v13 finds no service_role writer). SELECT stays:
--      the edge function cron-daily-study-summary reads study_sessions as service_role (supabase/functions/cron-daily-study-summary/index.ts lines 161 and 209, SELECT only). authenticated keeps INSERT,
--      MAINTAIN and SELECT as in D2 (no UPDATE). DELETE, TRUNCATE, REFERENCES, TRIGGER and MAINTAIN for service_role are NOT changed here: they are reported findings (DEC-4).
-- No data is changed; no row is added, updated or removed.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.study_sessions IN ACCESS EXCLUSIVE MODE;

DO $preflight$
DECLARE
  v text;
BEGIN
  IF to_regprocedure('public.normalize_course_text(text)') IS NULL
     OR to_regprocedure('public.resolve_canonical_course_label(text)') IS NULL
     OR to_regprocedure('public.course_catalogue_labels()') IS NULL
     OR to_regclass('public.disciplines_normalized_name_uidx') IS NULL THEN
    RAISE EXCEPTION 'B-04a requires B-01 (three functions) and B-02a (unique index); one of them is missing';
  END IF;
  IF to_regprocedure('public.fn_study_sessions_label_guard()') IS NOT NULL THEN
    RAISE EXCEPTION 'B-04a stopped: fn_study_sessions_label_guard already exists';
  END IF;

  SELECT pg_get_userbyid(c.relowner) || '|' || c.relrowsecurity || '|' || c.relforcerowsecurity INTO v FROM pg_class c WHERE c.oid = 'public.study_sessions'::regclass;
  IF v IS DISTINCT FROM 'postgres|true|false' THEN RAISE EXCEPTION 'B-04a stopped: study_sessions owner or RLS state differs from D2. Live: %', v; END IF;

  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) INTO v
    FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attnum > 0 AND NOT a.attisdropped;
  IF v IS DISTINCT FROM $lit$id:uuid,user_id:uuid,started_at:timestamp with time zone,ended_at:timestamp with time zone,duration_seconds:integer,session_date:date,source:text,created_at:timestamp with time zone,category:text,session_id:uuid$lit$ THEN RAISE EXCEPTION 'B-04a stopped: study_sessions columns differ from D2. Live: %', v; END IF;

  SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") INTO v FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass;
  IF v IS DISTINCT FROM $lit$study_sessions_category_check|CHECK (((category IS NULL) OR (category = ANY (ARRAY['reading'::text, 'writing_practice'::text, 'lecture_viewing'::text, 'paper_solving'::text, 'mock_test'::text]))));study_sessions_duration_floor|CHECK (((source <> 'manual'::text) OR (duration_seconds >= 600))) NOT VALID;study_sessions_duration_seconds_check|CHECK ((duration_seconds > 0));study_sessions_machine_duration_max|CHECK (((source = 'manual'::text) OR (duration_seconds <= 14400))) NOT VALID;study_sessions_machine_time_integrity|CHECK (((source = 'manual'::text) OR ((ended_at >= started_at) AND ((duration_seconds)::numeric <= (EXTRACT(epoch FROM (ended_at - started_at)) + (2)::numeric)))));study_sessions_manual_requires_category|CHECK (((source <> 'manual'::text) OR (category IS NOT NULL))) NOT VALID;study_sessions_pkey|PRIMARY KEY (id);study_sessions_source_check|CHECK ((source = ANY (ARRAY['manual'::text, 'study_mode'::text, 'practice_mode'::text])));study_sessions_user_id_fkey|FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$lit$ THEN RAISE EXCEPTION 'B-04a stopped: study_sessions constraints differ from D2. Live: %', v; END IF;

  SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") INTO v FROM pg_constraint WHERE conrelid = 'public.subjects'::regclass;
  IF v IS DISTINCT FROM $lit$subjects_discipline_id_fkey|FOREIGN KEY (discipline_id) REFERENCES disciplines(id) ON DELETE CASCADE;subjects_pkey|PRIMARY KEY (id)$lit$ THEN RAISE EXCEPTION 'B-04a stopped: subjects constraints differ from D2. Live: %', v; END IF;

  SELECT string_agg(indexname, ',' ORDER BY indexname COLLATE "C") INTO v FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'study_sessions';
  IF v IS DISTINCT FROM 'idx_study_sessions_user_date,study_sessions_pkey,study_sessions_user_session_uidx' THEN RAISE EXCEPTION 'B-04a stopped: study_sessions indexes differ from D2. Live: %', v; END IF;
  SELECT string_agg(indexname, ',' ORDER BY indexname COLLATE "C") INTO v FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'subjects';
  IF v IS DISTINCT FROM 'subjects_pkey' THEN RAISE EXCEPTION 'B-04a stopped: subjects indexes differ from D2. Live: %', v; END IF;

  SELECT string_agg(policyname || '|' || cmd || '|' || roles::text || '|' || coalesce(qual, '-') || '|' || coalesce(with_check, '-'), ';' ORDER BY policyname COLLATE "C") INTO v
    FROM pg_policies WHERE schemaname = 'public' AND tablename = 'study_sessions';
  IF v IS DISTINCT FROM $lit$study_sessions: users insert own rows|INSERT|{authenticated}|-|(auth.uid() = user_id);study_sessions: users read own rows|SELECT|{authenticated}|(auth.uid() = user_id)|-$lit$ THEN RAISE EXCEPTION 'B-04a stopped: study_sessions policies differ from D2. Live: %', v; END IF;

  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal)
     OR EXISTS (SELECT 1 FROM pg_rewrite WHERE ev_class = 'public.study_sessions'::regclass AND rulename <> '_RETURN') THEN
    RAISE EXCEPTION 'B-04a stopped: study_sessions has a trigger or a rule, which D2 did not record';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid IN ('public.study_sessions'::regclass, 'public.subjects'::regclass) AND attnum > 0 AND attacl IS NOT NULL) THEN
    RAISE EXCEPTION 'B-04a stopped: a column-level ACL exists on study_sessions or subjects';
  END IF;
  SELECT string_agg(coalesce(nullif(pg_get_userbyid(a.grantee), 'unknown (OID=0)'), 'PUBLIC') || ':' || a.privilege_type, ',' ORDER BY (coalesce(nullif(pg_get_userbyid(a.grantee), 'unknown (OID=0)'), 'PUBLIC') || ':' || a.privilege_type) COLLATE "C") INTO v
    FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a WHERE c.oid = 'public.study_sessions'::regclass;
  IF v IS DISTINCT FROM 'authenticated:INSERT,authenticated:MAINTAIN,authenticated:SELECT,postgres:DELETE,postgres:INSERT,postgres:MAINTAIN,postgres:REFERENCES,postgres:SELECT,postgres:TRIGGER,postgres:TRUNCATE,postgres:UPDATE,service_role:DELETE,service_role:INSERT,service_role:MAINTAIN,service_role:REFERENCES,service_role:SELECT,service_role:TRIGGER,service_role:TRUNCATE,service_role:UPDATE' THEN RAISE EXCEPTION 'B-04a stopped: the study_sessions table ACL differs from D2. Live: %', v; END IF;
END
$preflight$;

CREATE TEMP TABLE b04a_proof ON COMMIT DROP AS
SELECT count(*)::integer AS n0, md5(coalesce(string_agg(jsonb_build_array(id, user_id, started_at, ended_at, duration_seconds, session_date, source, created_at, category, session_id)::text, '|' ORDER BY id), '')) AS h0 FROM public.study_sessions;

ALTER TABLE public.subjects
  ADD CONSTRAINT subjects_discipline_id_id_key UNIQUE (discipline_id, id);

ALTER TABLE public.study_sessions
  ADD COLUMN classification text,
  ADD COLUMN discipline_id uuid,
  ADD COLUMN subject_id uuid,
  ADD COLUMN custom_course_label text,
  ADD COLUMN custom_course_key text GENERATED ALWAYS AS (public.normalize_course_text(custom_course_label)) STORED,
  ADD COLUMN custom_subject_label text,
  ADD COLUMN custom_subject_key text GENERATED ALWAYS AS (public.normalize_course_text(custom_subject_label)) STORED;

ALTER TABLE public.study_sessions
  ADD CONSTRAINT study_sessions_discipline_id_fkey FOREIGN KEY (discipline_id) REFERENCES public.disciplines (id) NOT VALID,
  ADD CONSTRAINT study_sessions_discipline_subject_fkey FOREIGN KEY (discipline_id, subject_id) REFERENCES public.subjects (discipline_id, id) NOT VALID,
  ADD CONSTRAINT study_sessions_classification_values CHECK (classification IS NULL OR classification IN ('platform', 'custom', 'general')) NOT VALID,
  ADD CONSTRAINT study_sessions_classification_shape CHECK (
       (classification IS NULL AND discipline_id IS NULL AND subject_id IS NULL AND custom_course_label IS NULL AND custom_subject_label IS NULL)
    OR (classification IS NOT DISTINCT FROM 'platform' AND discipline_id IS NOT NULL AND custom_course_label IS NULL AND custom_subject_label IS NULL)
    OR (classification IS NOT DISTINCT FROM 'custom' AND custom_course_label IS NOT NULL AND discipline_id IS NULL AND subject_id IS NULL)
    OR (classification IS NOT DISTINCT FROM 'general' AND discipline_id IS NULL AND subject_id IS NULL AND custom_course_label IS NULL AND custom_subject_label IS NULL)
  ) NOT VALID,
  ADD CONSTRAINT study_sessions_machine_source_unclassified CHECK (source = 'manual' OR classification IS NULL) NOT VALID;

CREATE FUNCTION public.fn_study_sessions_label_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v text;
BEGIN
  IF NEW.custom_course_label IS NOT NULL THEN
    v := pg_catalog.btrim(NEW.custom_course_label);
    IF v = '' THEN
      RAISE EXCEPTION 'study_sessions: the custom course label is empty' USING ERRCODE = '23514';
    END IF;
    IF pg_catalog.char_length(v) > 120 THEN
      RAISE EXCEPTION 'study_sessions: the custom course label is longer than 120 characters' USING ERRCODE = '23514';
    END IF;
    IF v ~ '[[:cntrl:]]' THEN
      RAISE EXCEPTION 'study_sessions: the custom course label contains a control character' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM public.disciplines d WHERE public.normalize_course_text(d.name) = public.normalize_course_text(v)) THEN
      RAISE EXCEPTION 'study_sessions: the custom course label equals a platform course; send it as a platform course' USING ERRCODE = '23514';
    END IF;
    NEW.custom_course_label := public.resolve_canonical_course_label(v);
  END IF;
  IF NEW.custom_subject_label IS NOT NULL THEN
    v := pg_catalog.btrim(NEW.custom_subject_label);
    IF v = '' THEN
      RAISE EXCEPTION 'study_sessions: the custom subject label is empty' USING ERRCODE = '23514';
    END IF;
    IF pg_catalog.char_length(v) > 120 THEN
      RAISE EXCEPTION 'study_sessions: the custom subject label is longer than 120 characters' USING ERRCODE = '23514';
    END IF;
    IF v ~ '[[:cntrl:]]' THEN
      RAISE EXCEPTION 'study_sessions: the custom subject label contains a control character' USING ERRCODE = '23514';
    END IF;
    NEW.custom_subject_label := v;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_study_sessions_label_guard() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_study_sessions_label_guard
  BEFORE INSERT OR UPDATE OF custom_course_label, custom_subject_label ON public.study_sessions
  FOR EACH ROW
  WHEN (NEW.custom_course_label IS NOT NULL OR NEW.custom_subject_label IS NOT NULL)
  EXECUTE FUNCTION public.fn_study_sessions_label_guard();

REVOKE UPDATE, INSERT ON TABLE public.study_sessions FROM service_role;

DO $postcheck$
DECLARE
  v_h text;
  v_n integer;
  p b04a_proof%ROWTYPE;
BEGIN
  SELECT * INTO p FROM b04a_proof;
  SELECT count(*), md5(coalesce(string_agg(jsonb_build_array(id, user_id, started_at, ended_at, duration_seconds, session_date, source, created_at, category, session_id)::text, '|' ORDER BY id), '')) INTO v_n, v_h FROM public.study_sessions;
  IF v_n <> p.n0 OR v_h <> p.h0 THEN
    RAISE EXCEPTION 'B-04a stopped: the pre-existing columns changed (rows % -> %, hash % -> %); nothing is applied', p.n0, v_n, p.h0, v_h;
  END IF;
  IF EXISTS (SELECT 1 FROM public.study_sessions WHERE classification IS NOT NULL OR discipline_id IS NOT NULL OR subject_id IS NOT NULL OR custom_course_label IS NOT NULL OR custom_course_key IS NOT NULL OR custom_subject_label IS NOT NULL OR custom_subject_key IS NOT NULL) THEN
    RAISE EXCEPTION 'B-04a stopped: a new column is not NULL on an existing row (no-backfill rule)';
  END IF;
END
$postcheck$;

SELECT p.n0 AS rows_before, (SELECT count(*) FROM public.study_sessions) AS rows_after, p.h0 AS preexisting_hash_before,
       (SELECT md5(coalesce(string_agg(jsonb_build_array(id, user_id, started_at, ended_at, duration_seconds, session_date, source, created_at, category, session_id)::text, '|' ORDER BY id), '')) FROM public.study_sessions) AS preexisting_hash_after
  FROM b04a_proof p;
