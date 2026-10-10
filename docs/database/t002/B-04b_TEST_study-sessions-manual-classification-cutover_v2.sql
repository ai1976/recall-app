-- Name: [TEST] T-002 B-04b TEST (v2) - verify the study_sessions manual-classification cutover (rollback-only)
--
-- Description: Verification for B-04b_SCHEMA_study-sessions-manual-classification-cutover_v2.sql, run AFTER it. Persists nothing: it creates one temporary table and a few temporary functions (gone when the
-- session ends), runs every case in a sub-transaction that is rolled back by a marker exception, and proves at the end that study_sessions is what it was (row count and the same 17-column fingerprint hash of the
-- legacy set before and after). Run the WHOLE file as ONE selection; it returns one row per check with pass true or false, then a summary row. Every check must be true. Stop and report on any false or any SQL error;
-- do not edit and re-run.
-- It proves: the constraint as built (NOT VALID); the older constraints still as B-04a left them; manual NULL refused (23514, by this constraint); manual platform / custom / general accepted; study_mode and
-- practice_mode with no classification accepted; manual with a classification but no category still refused by the OLD category rule; a NULL source refused; an UPDATE of a legacy row refused by this constraint; an
-- UPDATE of a classified row accepted and one that would remove its classification refused; as the real role authenticated (JWT claims + SET LOCAL ROLE): manual NULL refused, manual classified accepted; the closure
-- facts the SCHEMA asserts, re-read live; the set assertion logic (SA) fails when its input is altered (an id added, an id altered) and does not fail on a removed id, the empty anchor, the empty set and the
-- same-content case; the fingerprint encoding keeps NULL and the empty string apart and is independent of the session settings once pinned.
-- Honest limits: the SA cases run the SA comparison in a temporary function over jsonb copies (the SCHEMA file carries the same comparison inline; QA compares the two texts); concurrency is NOT COVERED.

SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;
SET LOCAL search_path = pg_catalog, public, pg_temp;

CREATE TEMP TABLE b04b_enc AS SELECT * FROM public.study_sessions WITH NO DATA;

CREATE OR REPLACE FUNCTION pg_temp.b04b_sa(a jsonb, c jsonb)
RETURNS jsonb
LANGUAGE sql
AS $f$
  SELECT jsonb_build_object(
    'added',   (SELECT count(*) FROM jsonb_each_text(c) e WHERE (a ->> e.key) IS NULL),
    'altered', (SELECT count(*) FROM jsonb_each_text(c) e WHERE (a ->> e.key) IS NOT NULL AND (a ->> e.key) <> e.value),
    'gone',    (SELECT count(*) FROM jsonb_each_text(a) e WHERE (c ->> e.key) IS NULL));
$f$;

CREATE OR REPLACE FUNCTION pg_temp.b04b_fp(sid uuid)
RETURNS text
LANGUAGE sql
AS $f$
  SELECT encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord) FROM unnest(ARRAY[t.id::text, t.user_id::text, t.started_at::text, t.ended_at::text, t.duration_seconds::text, t.session_date::text, t.source::text, t.created_at::text, t.category::text, t.session_id::text, t.classification::text, t.discipline_id::text, t.subject_id::text, t.custom_course_label::text, t.custom_course_key::text, t.custom_subject_label::text, t.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') FROM public.study_sessions t WHERE t.id = sid;
$f$;

CREATE OR REPLACE FUNCTION pg_temp.b04b_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_student uuid;
  v_d1      uuid;
  v_sub     uuid;
  v_legacy  uuid;
  v_id      uuid;
  v_tag     text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_n0      integer;
  v_h0      text;
  v_h1      text;
  v_t0      integer;
  v_th0     text;
  v_state   text;
  v_bad     text;
  v_res     text;
  v_con     text;
  v_sql     text;
  v_prefix  text;
  v_a       jsonb;
  v_c       jsonb;
  v_r       jsonb;
  v_fpa     text;
  v_fpb     text;
  v_fpc     text;
  v_fid     uuid;
  v         text;
  n         integer;
  v_rx      text := $rx$(insert\s+into|update|merge\s+into|copy)\s+(only\s+)?("?public"?\s*\.\s*)?"?study_sessions"?([^a-z0-9_]|$)$rx$;
  r         record;
  v_cases   jsonb := $j$[
 {"n": "manual, category, no classification: refused by the new rule", "c": "source, category", "v": "'manual', 'reading'", "e": "23514:study_sessions_manual_requires_classification"},
 {"n": "manual, platform course only: accepted", "c": "source, category, classification, discipline_id", "v": "'manual', 'reading', 'platform', '%D1%'", "e": "ok"},
 {"n": "manual, platform course and subject: accepted", "c": "source, category, classification, discipline_id, subject_id", "v": "'manual', 'reading', 'platform', '%D1%', '%SUB%'", "e": "ok"},
 {"n": "manual, custom course label: accepted", "c": "source, category, classification, custom_course_label", "v": "'manual', 'mock_test', 'custom', 'ZZ B04b %TAG%'", "e": "ok"},
 {"n": "manual, General: accepted", "c": "source, category, classification", "v": "'manual', 'reading', 'general'", "e": "ok"},
 {"n": "study_mode with no classification: accepted", "c": "source", "v": "'study_mode'", "e": "ok"},
 {"n": "practice_mode with no classification: accepted", "c": "source", "v": "'practice_mode'", "e": "ok"},
 {"n": "manual, classified but no category: still refused by the older category rule", "c": "source, classification", "v": "'manual', 'general'", "e": "23514:study_sessions_manual_requires_category"},
 {"n": "NULL source: refused by NOT NULL (23502)", "c": "source, category", "v": "NULL, 'reading'", "e": "23502:"}
]$j$;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(pg_temp.b04b_fp(s.id), '|' ORDER BY s.id::text COLLATE "C"), '')) INTO v_n0, v_h0
    FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL;
  SELECT count(*), md5(coalesce(string_agg(pg_temp.b04b_fp(s.id), '|' ORDER BY s.id::text COLLATE "C"), '')) INTO v_t0, v_th0 FROM public.study_sessions s;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT d.id INTO v_d1 FROM public.disciplines d WHERE EXISTS (SELECT 1 FROM public.subjects s WHERE s.discipline_id = d.id) ORDER BY d.name LIMIT 1;
  SELECT s.id INTO v_sub FROM public.subjects s WHERE s.discipline_id = v_d1 ORDER BY s.id LIMIT 1;
  SELECT s.id INTO v_legacy FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL AND s.duration_seconds >= 600 AND (s.category IN ('reading', 'writing_practice', 'lecture_viewing', 'paper_solving', 'mock_test')) ORDER BY s.id::text COLLATE "C" LIMIT 1;
  v_prefix := 'INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, ';

  check_name := 'setup: a student profile, a discipline with a subject and a legacy row to update; baseline of the legacy set recorded';
  pass := v_student IS NOT NULL AND v_d1 IS NOT NULL AND v_sub IS NOT NULL AND v_legacy IS NOT NULL;
  detail := v_n0 || ' legacy rows (manual, no classification); fixture tag ' || v_tag; RETURN NEXT;

  -- ---- the constraint as built, and what B-04a left
  check_name := 'constraint: study_sessions_manual_requires_classification exists, is the exact NULL-safe CHECK (source IS DISTINCT FROM manual OR classification IS NOT NULL), NOT VALID, and source is NOT NULL';
  pass := EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_classification' AND contype = 'c' AND NOT convalidated
                    AND regexp_replace(pg_get_constraintdef(oid), '[\s()]', '', 'g') = $d$CHECKsourceISDISTINCTFROM'manual'::textORclassificationISNOTNULLNOTVALID$d$)
      AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attname = 'source' AND a.attnotnull);
  detail := coalesce((SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_classification'), 'absent'); RETURN NEXT;

  check_name := 'constraints: the five B-04a constraints are still NOT VALID, source_check is validated, the older category rule is still there, and the columns are the frozen 17';
  pass := (SELECT count(*) FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND NOT convalidated
              AND conname IN ('study_sessions_discipline_id_fkey', 'study_sessions_discipline_subject_fkey', 'study_sessions_classification_values', 'study_sessions_classification_shape', 'study_sessions_machine_source_unclassified')) = 5
      AND EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_source_check' AND convalidated)
      AND EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND conname = 'study_sessions_manual_requires_category')
      AND (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attnum > 0 AND NOT a.attisdropped) = $lit$id:uuid,user_id:uuid,started_at:timestamp with time zone,ended_at:timestamp with time zone,duration_seconds:integer,session_date:date,source:text,created_at:timestamp with time zone,category:text,session_id:uuid,classification:text,discipline_id:uuid,subject_id:uuid,custom_course_label:text,custom_course_key:text,custom_subject_label:text,custom_subject_key:text$lit$;
  detail := ''; RETURN NEXT;

  -- ---- insert cases, as the table owner, each rolled back
  check_name := 'insert cases (owner): every case gives the expected outcome and constraint name';
  v_bad := '';
  FOR r IN SELECT x.n AS n, x.c AS c, x.v AS v, x.e AS e FROM jsonb_to_recordset(v_cases) AS x(n text, c text, v text, e text) LOOP
    v_sql := v_prefix || r.c || ') VALUES (' || quote_literal(v_student) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, '
             || replace(replace(replace(replace(r.v, '%TAG%', v_tag), '%D1%', v_d1::text), '%SUB%', v_sub::text), '%CAT%', '') || ')';
    BEGIN
      BEGIN
        EXECUTE v_sql;
        v_res := 'ok';
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
        v_res := SQLSTATE || ':' || coalesce(v_con, '');
      END;
      RAISE EXCEPTION 'b04b_rollback_marker';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'b04b_rollback_marker' THEN RAISE; END IF;
    END;
    IF v_res <> r.e THEN v_bad := v_bad || r.n || ' -> ' || v_res || '; '; END IF;
  END LOOP;
  pass := v_bad = ''; detail := CASE WHEN v_bad = '' THEN jsonb_array_length(v_cases) || ' cases' ELSE v_bad END; RETURN NEXT;

  -- ---- update cases, as the table owner, each rolled back
  check_name := 'update cases (owner): a legacy row cannot be updated (new rule); a classified manual row can be updated; its classification cannot be removed';
  v_bad := '';
  BEGIN
    BEGIN
      UPDATE public.study_sessions SET category = category WHERE id = v_legacy;
      v_res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
      v_res := SQLSTATE || ':' || coalesce(v_con, '');
    END;
    RAISE EXCEPTION 'b04b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b04b_rollback_marker' THEN RAISE; END IF;
  END;
  IF v_res <> '23514:study_sessions_manual_requires_classification' THEN v_bad := v_bad || 'legacy update -> ' || v_res || '; '; END IF;

  BEGIN
    EXECUTE v_prefix || 'source, category, classification, discipline_id) VALUES (' || quote_literal(v_student) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, ''manual'', ''reading'', ''platform'', ' || quote_literal(v_d1) || ') RETURNING id' INTO v_id;
    BEGIN
      UPDATE public.study_sessions SET category = 'mock_test' WHERE id = v_id;
      v_res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
      v_res := SQLSTATE || ':' || coalesce(v_con, '');
    END;
    IF v_res <> 'ok' THEN v_bad := v_bad || 'classified update -> ' || v_res || '; '; END IF;
    BEGIN
      UPDATE public.study_sessions SET classification = NULL, discipline_id = NULL WHERE id = v_id;
      v_res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
      v_res := SQLSTATE || ':' || coalesce(v_con, '');
    END;
    IF v_res <> '23514:study_sessions_manual_requires_classification' THEN v_bad := v_bad || 'declassify -> ' || v_res || '; '; END IF;
    RAISE EXCEPTION 'b04b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b04b_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_bad = ''; detail := CASE WHEN v_bad = '' THEN '3 cases' ELSE v_bad END; RETURN NEXT;

  -- ---- the real role authenticated
  check_name := 'real role authenticated: a manual log with no classification is refused (23514), a classified one is accepted';
  v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      EXECUTE v_prefix || 'source, category) VALUES (' || quote_literal(v_student) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, ''manual'', ''reading'')';
      v_state := v_state || 'unclassified-allowed;';
    EXCEPTION WHEN check_violation THEN v_state := v_state || 'unclassified-refused;'; WHEN OTHERS THEN v_state := v_state || 'unclassified-' || SQLSTATE || ';';
    END;
    BEGIN
      EXECUTE v_prefix || 'source, category, classification) VALUES (' || quote_literal(v_student) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, ''manual'', ''reading'', ''general'')';
      v_state := v_state || 'classified-ok;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'classified-' || SQLSTATE || ';';
    END;
    RESET ROLE;
    RAISE EXCEPTION 'b04b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b04b_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'unclassified-refused;classified-ok;'; detail := v_state; RETURN NEXT;

  -- ---- the closure facts, re-read live (the same queries as the SCHEMA file)
  check_name := 'closure: no UPDATE for any non-owner role or PUBLIC; INSERT (table or any column) only for authenticated';
  SELECT string_agg(rr.rolname, ',' ORDER BY rr.rolname) INTO v FROM pg_roles rr
   WHERE NOT rr.rolsuper AND rr.oid <> (SELECT relowner FROM pg_class WHERE oid = 'public.study_sessions'::regclass) AND has_any_column_privilege(rr.oid, 'public.study_sessions'::regclass, 'UPDATE');
  SELECT (SELECT count(*) FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) x WHERE c.oid = 'public.study_sessions'::regclass AND x.grantee = 0 AND x.privilege_type IN ('UPDATE', 'INSERT'))
       + (SELECT count(*) FROM pg_attribute a CROSS JOIN LATERAL aclexplode(a.attacl) x WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attacl IS NOT NULL AND x.grantee = 0 AND x.privilege_type IN ('UPDATE', 'INSERT')) INTO n;
  SELECT string_agg(rr.rolname, ',' ORDER BY rr.rolname) INTO v_state FROM pg_roles rr
   WHERE NOT rr.rolsuper AND rr.oid <> (SELECT relowner FROM pg_class WHERE oid = 'public.study_sessions'::regclass) AND has_any_column_privilege(rr.oid, 'public.study_sessions'::regclass, 'INSERT');
  pass := v IS NULL AND n = 0 AND v_state = 'authenticated' AND has_table_privilege('authenticated', 'public.study_sessions'::regclass, 'INSERT');
  detail := coalesce('UPDATE holders: ' || v, 'none') || '; PUBLIC grants ' || n || '; INSERT holders (table or column): ' || coalesce(v_state, 'none'); RETURN NEXT;

  check_name := 'closure: the only trigger is trg_study_sessions_label_guard (enabled); no rewrite rule; no insertable or updatable view; no SET NULL or SET DEFAULT key';
  SELECT string_agg(t.tgname || ':' || t.tgenabled::text, ',' ORDER BY t.tgname) INTO v FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND NOT t.tgisinternal;
  pass := v = 'trg_study_sessions_label_guard:O'
      AND NOT EXISTS (SELECT 1 FROM pg_rewrite w WHERE w.ev_class = 'public.study_sessions'::regclass)
      AND NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite w ON w.oid = d.objid AND d.classid = 'pg_rewrite'::regclass JOIN pg_class vw ON vw.oid = w.ev_class
                       WHERE d.refobjid = 'public.study_sessions'::regclass AND vw.oid <> 'public.study_sessions'::regclass AND vw.relkind IN ('v', 'm') AND (pg_relation_is_updatable(vw.oid, false) & 12) <> 0)
      AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conrelid = 'public.study_sessions'::regclass AND c.contype = 'f' AND (c.confdeltype IN ('n', 'd') OR c.confupdtype IN ('n', 'd')));
  detail := coalesce(v, 'no trigger'); RETURN NEXT;

  check_name := 'closure: no routine and no scheduled job contains a write statement on study_sessions (cron.job visible)';
  SELECT string_agg(ns.nspname || '.' || p.proname, ',' ORDER BY ns.nspname, p.proname) INTO v
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace WHERE ns.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p') AND p.prosrc ~* v_rx;
  n := -1;
  IF to_regclass('cron.job') IS NOT NULL THEN EXECUTE 'SELECT count(*) FROM cron.job WHERE command ~* $1' INTO n USING v_rx; END IF;
  pass := v IS NULL AND n = 0;
  detail := coalesce('routines: ' || v, 'no routine') || '; cron jobs with a write: ' || n; RETURN NEXT;

  -- ---- the set assertion logic (SA)
  check_name := 'SA: identical sets pass; an id added to C fails (i); an altered fingerprint fails (ii); a removed id is reported and does not fail; the empty anchor with a non-empty C fails; empty C passes; both empty pass';
  v_a := (SELECT coalesce(jsonb_object_agg(s.id::text, pg_temp.b04b_fp(s.id)), '{}'::jsonb) FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL);
  v_c := v_a;
  v_bad := '';
  v_r := pg_temp.b04b_sa(v_a, v_c);
  IF (v_r ->> 'added') <> '0' OR (v_r ->> 'altered') <> '0' OR (v_r ->> 'gone') <> '0' THEN v_bad := v_bad || 'identical -> ' || v_r::text || '; '; END IF;
  v_r := pg_temp.b04b_sa(v_a - (SELECT key FROM jsonb_each_text(v_a) ORDER BY key LIMIT 1), v_c);
  IF (v_r ->> 'added') <> '1' THEN v_bad := v_bad || 'added id not detected -> ' || v_r::text || '; '; END IF;
  v_r := pg_temp.b04b_sa(v_a, v_c || jsonb_build_object((SELECT key FROM jsonb_each_text(v_c) ORDER BY key LIMIT 1), 'altered'));
  IF (v_r ->> 'altered') <> '1' THEN v_bad := v_bad || 'altered fingerprint not detected -> ' || v_r::text || '; '; END IF;
  v_r := pg_temp.b04b_sa(v_a || jsonb_build_object('00000000-0000-0000-0000-000000000000', 'x'), v_c);
  IF (v_r ->> 'added') <> '0' OR (v_r ->> 'altered') <> '0' OR (v_r ->> 'gone') <> '1' THEN v_bad := v_bad || 'removed id wrongly failed or not reported -> ' || v_r::text || '; '; END IF;
  v_r := pg_temp.b04b_sa('{}'::jsonb, v_c);
  IF (v_r ->> 'added')::integer <> (SELECT count(*) FROM jsonb_each_text(v_c)) THEN v_bad := v_bad || 'empty anchor -> ' || v_r::text || '; '; END IF;
  v_r := pg_temp.b04b_sa(v_a, '{}'::jsonb);
  IF (v_r ->> 'added') <> '0' OR (v_r ->> 'altered') <> '0' THEN v_bad := v_bad || 'empty C failed -> ' || v_r::text || '; '; END IF;
  v_r := pg_temp.b04b_sa('{}'::jsonb, '{}'::jsonb);
  IF (v_r ->> 'added') <> '0' OR (v_r ->> 'altered') <> '0' OR (v_r ->> 'gone') <> '0' THEN v_bad := v_bad || 'both empty -> ' || v_r::text || '; '; END IF;
  pass := v_bad = ''; detail := CASE WHEN v_bad = '' THEN 'SA over ' || (SELECT count(*) FROM jsonb_each_text(v_a)) || ' live rows, 7 cases' ELSE v_bad END; RETURN NEXT;

  check_name := 'encoding: NULL and the empty string give different fingerprints; an all-NULL row has a fingerprint; the fingerprint equals the one under pinned settings after other settings were used';
  v_fid := gen_random_uuid();
  INSERT INTO b04b_enc (id, source, custom_course_label) VALUES (v_fid, 'manual', NULL), (v_fid, 'manual', '');
  INSERT INTO b04b_enc (id) VALUES (gen_random_uuid());
  SELECT string_agg(encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord) FROM unnest(ARRAY[t.id::text, t.user_id::text, t.started_at::text, t.ended_at::text, t.duration_seconds::text, t.session_date::text, t.source::text, t.created_at::text, t.category::text, t.session_id::text, t.classification::text, t.discipline_id::text, t.subject_id::text, t.custom_course_label::text, t.custom_course_key::text, t.custom_subject_label::text, t.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex'), '|' ORDER BY t.custom_course_label NULLS FIRST) INTO v FROM b04b_enc t WHERE t.id = v_fid;
  SELECT count(*) INTO n FROM b04b_enc t WHERE t.id <> v_fid AND encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord) FROM unnest(ARRAY[t.id::text, t.user_id::text, t.started_at::text, t.ended_at::text, t.duration_seconds::text, t.session_date::text, t.source::text, t.created_at::text, t.category::text, t.session_id::text, t.classification::text, t.discipline_id::text, t.subject_id::text, t.custom_course_label::text, t.custom_course_key::text, t.custom_subject_label::text, t.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') IS NOT NULL;
  SELECT count(DISTINCT encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord) FROM unnest(ARRAY[t.id::text, t.user_id::text, t.started_at::text, t.ended_at::text, t.duration_seconds::text, t.session_date::text, t.source::text, t.created_at::text, t.category::text, t.session_id::text, t.classification::text, t.discipline_id::text, t.subject_id::text, t.custom_course_label::text, t.custom_course_key::text, t.custom_subject_label::text, t.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex')) INTO v_h1 FROM b04b_enc t WHERE t.id = v_fid;
  v_state := v_h1;
  SELECT s.id INTO v_fid FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL ORDER BY s.id::text COLLATE "C" LIMIT 1;
  v_fpa := pg_temp.b04b_fp(v_fid);
  BEGIN
    PERFORM set_config('TimeZone', 'Asia/Kolkata', true);
    PERFORM set_config('DateStyle', 'SQL, DMY', true);
    v_fpb := pg_temp.b04b_fp(v_fid);
    PERFORM set_config('TimeZone', 'UTC', true);
    PERFORM set_config('DateStyle', 'ISO, YMD', true);
    v_fpc := pg_temp.b04b_fp(v_fid);
    RAISE EXCEPTION 'b04b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b04b_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = '2' AND n = 1 AND v_fpa = v_fpc AND v_fpa <> v_fpb;
  detail := 'NULL/empty distinct values: ' || v_state || '; all-NULL row fingerprinted: ' || n || '; pinned equal: ' || (v_fpa = v_fpc) || '; unpinned differs: ' || (v_fpa <> v_fpb); RETURN NEXT;

  -- ---- nothing changed
  check_name := 'live rows: the legacy set AND the whole table (count and 17-column fingerprint hash) equal the baseline and no fixture row remains';
  pass := (SELECT count(*) FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL) = v_n0
      AND (SELECT md5(coalesce(string_agg(pg_temp.b04b_fp(s.id), '|' ORDER BY s.id::text COLLATE "C"), '')) FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL) = v_h0
      AND NOT EXISTS (SELECT 1 FROM public.study_sessions WHERE custom_course_label LIKE 'ZZ B04b%')
      AND (SELECT count(*) FROM public.study_sessions) = v_t0
      AND (SELECT md5(coalesce(string_agg(pg_temp.b04b_fp(s.id), '|' ORDER BY s.id::text COLLATE "C"), '')) FROM public.study_sessions s) = v_th0;
  detail := v_n0 || ' legacy rows; ' || v_t0 || ' rows in all, full-table fingerprint equal'; RETURN NEXT;

  check_name := 'info: the legacy set versus the S0 anchor (count 1,411; overall hash 86353cb4c83a...) - shrinkage is allowed, so this is information, not a failure';
  pass := true;
  detail := (SELECT count(*) || ' rows, sum ' || coalesce(sum(duration_seconds), 0) FROM public.study_sessions s WHERE s.source = 'manual' AND s.classification IS NULL); RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b04b_results AS SELECT * FROM pg_temp.b04b_checks();

SELECT check_name, pass, detail FROM b04b_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass) FROM b04b_results), (SELECT count(*) || ' checks' FROM b04b_results);
