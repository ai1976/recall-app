-- Name: [TEST] T-002 B-04a TEST (v2) - verify the study_sessions compatibility phase (rollback-only)
--
-- Description: Verification for B-04a_SCHEMA_study-sessions-compatibility-phase_v1.sql, run AFTER it. v2 (08/10/2026): the v1 run stopped at the columns check with 42725 (text || "char"); the only change is the cast attgenerated::text. Persists nothing: one temporary function and one temporary table; every row it inserts lives in a
-- sub-transaction that is rolled back, and the file proves at the end that the table is byte-for-byte what it was (row count and the same pre-existing-column hash as the SCHEMA file). Run the whole file as ONE
-- selection; it returns one row per check with pass true or false, then a summary row. Every check must be true. Stop and report on any false or any SQL error; do not edit and re-run.
-- It proves, with the real roles (JWT claims plus SET LOCAL ROLE, as in the B-02b TEST): the columns, keys, constraints, trigger and function as built; the exact existing constraints unchanged; the exact
-- privileges (authenticated INSERT, MAINTAIN, SELECT as in D2; service_role without INSERT and UPDATE, with SELECT; no column ACL); no backfill; the exact column lists of the two frontend writers
-- (StudyTimerContext.jsx and studyTracker.js) still insert as authenticated; every classification case accepted or refused with its SQLSTATE; label boundaries 0, 1, 120, 121 characters, control characters
-- and trimming; a platform-course label refused and a catalogue label stored canonically; generated keys equal normalize_course_text(label) and cannot be set; authenticated and service_role cannot UPDATE;
-- service_role cannot INSERT but can SELECT; the owner-level UPDATE of a label still passes through the guard; and a student cannot insert for another user.

CREATE OR REPLACE FUNCTION pg_temp.b04a_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_student uuid;
  v_other   uuid;
  v_d1      uuid;
  v_dname   text;
  v_sub     uuid;
  v_subx    uuid;
  v_cat     text;
  v_tag     text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_n0      integer;
  v_h0      text;
  v_nonnull integer;
  v_state   text;
  v_bad     text;
  v_cnt     integer;
  v_prefix  text;
  v_sql     text;
  v_res     text;
  v_id      uuid;
  v_id2     uuid;
  v_lab     text;
  v_key     text;
  v_len     integer;
  v_cases   jsonb := $j$[
 {
  "n": "replay StudyTimerContext columns (study_mode)",
  "c": "source, category",
  "v": "'study_mode', 'reading'",
  "e": "ok"
 },
 {
  "n": "replay studyTracker columns (practice_mode, session_id, no category)",
  "c": "source, session_id",
  "v": "'practice_mode', gen_random_uuid()",
  "e": "ok"
 },
 {
  "n": "manual with NULL classification still accepted (B-04b is later)",
  "c": "source, category",
  "v": "'manual', 'reading'",
  "e": "ok"
 },
 {
  "n": "platform, course only",
  "c": "source, category, classification, discipline_id",
  "v": "'manual', 'reading', 'platform', '%D1%'",
  "e": "ok"
 },
 {
  "n": "platform, valid course and subject pair",
  "c": "source, category, classification, discipline_id, subject_id",
  "v": "'manual', 'reading', 'platform', '%D1%', '%SUB%'",
  "e": "ok"
 },
 {
  "n": "platform, mismatched pair refused (23503)",
  "c": "source, category, classification, discipline_id, subject_id",
  "v": "'manual', 'reading', 'platform', '%D1%', '%SUBX%'",
  "e": "23503"
 },
 {
  "n": "platform, non-existent discipline refused (23503)",
  "c": "source, category, classification, discipline_id",
  "v": "'manual', 'reading', 'platform', gen_random_uuid()",
  "e": "23503"
 },
 {
  "n": "platform with a custom label refused (23514)",
  "c": "source, category, classification, discipline_id, custom_course_label",
  "v": "'manual', 'reading', 'platform', '%D1%', 'ZZ x'",
  "e": "23514"
 },
 {
  "n": "custom, course label only",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', '  ZZ  Alpha  %TAG%  '",
  "e": "ok"
 },
 {
  "n": "custom, course and subject labels",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Beta %TAG%', ' ZZ Sub %TAG% '",
  "e": "ok"
 },
 {
  "n": "custom with a discipline id refused (23514)",
  "c": "source, category, classification, custom_course_label, discipline_id",
  "v": "'manual', 'reading', 'custom', 'ZZ x', '%D1%'",
  "e": "23514"
 },
 {
  "n": "custom without a course label refused (23514)",
  "c": "source, category, classification",
  "v": "'manual', 'reading', 'custom'",
  "e": "23514"
 },
 {
  "n": "NULL classification with a discipline id refused (23514)",
  "c": "source, category, discipline_id",
  "v": "'manual', 'reading', '%D1%'",
  "e": "23514"
 },
 {
  "n": "NULL classification with a subject label refused (23514)",
  "c": "source, category, custom_subject_label",
  "v": "'manual', 'reading', 'ZZ x'",
  "e": "23514"
 },
 {
  "n": "unknown classification value refused (23514)",
  "c": "source, category, classification",
  "v": "'manual', 'reading', 'bogus'",
  "e": "23514"
 },
 {
  "n": "study_mode with a classification refused (23514)",
  "c": "source, classification",
  "v": "'study_mode', 'general'",
  "e": "23514"
 },
 {
  "n": "general, all NULL",
  "c": "source, category, classification",
  "v": "'manual', 'reading', 'general'",
  "e": "ok"
 },
 {
  "n": "general with a custom label refused (23514)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'general', 'ZZ x'",
  "e": "23514"
 },
 {
  "n": "course label blank after trim refused (23514)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', '    '",
  "e": "23514"
 },
 {
  "n": "course label of 121 characters refused (23514)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', repeat('x', 121)",
  "e": "23514"
 },
 {
  "n": "course label of 120 characters accepted",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', repeat('y', 120)",
  "e": "ok"
 },
 {
  "n": "course label with a control character refused (23514)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'ab' || chr(9) || 'c'",
  "e": "23514"
 },
 {
  "n": "course label equal to a platform course refused (23514)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', regexp_replace(lower('%DNAME%'), ' ', '   ', 'g')",
  "e": "23514"
 },
 {
  "n": "course label equal to a catalogue label, any case and spacing, accepted",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', regexp_replace(lower('%CAT%'), ' ', '   ', 'g')",
  "e": "ok"
 },
 {
  "n": "subject label blank refused (23514)",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Gamma %TAG%', '   '",
  "e": "23514"
 },
 {
  "n": "subject label of 121 characters refused (23514)",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Gamma %TAG%', repeat('z', 121)",
  "e": "23514"
 },
 {
  "n": "subject label with a control character refused (23514)",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Gamma %TAG%', 'a' || chr(10) || 'b'",
  "e": "23514"
 },
 {
  "n": "setting a generated key refused (428C9)",
  "c": "source, category, classification, custom_course_label, custom_course_key",
  "v": "'manual', 'reading', 'custom', 'ZZ Delta %TAG%', 'forged'",
  "e": "428C9"
 },
 {
  "n": "same label in another case and spacing accepted (key test below)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'zz   ALPHA %TAG%'",
  "e": "ok"
 }
]$j$;
  r         record;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(jsonb_build_array(id, user_id, started_at, ended_at, duration_seconds, session_date, source, created_at, category, session_id)::text, '|' ORDER BY id), ''))
    INTO v_n0, v_h0 FROM public.study_sessions;
  SELECT count(*) INTO v_nonnull FROM public.study_sessions
   WHERE classification IS NOT NULL OR discipline_id IS NOT NULL OR subject_id IS NOT NULL OR custom_course_label IS NOT NULL OR custom_course_key IS NOT NULL OR custom_subject_label IS NOT NULL OR custom_subject_key IS NOT NULL;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT id INTO v_other FROM public.profiles WHERE role = 'student' AND id <> v_student ORDER BY id LIMIT 1;
  SELECT d.id, d.name INTO v_d1, v_dname FROM public.disciplines d WHERE EXISTS (SELECT 1 FROM public.subjects s WHERE s.discipline_id = d.id) ORDER BY d.name LIMIT 1;
  SELECT s.id INTO v_sub FROM public.subjects s WHERE s.discipline_id = v_d1 ORDER BY s.id LIMIT 1;
  SELECT s.id INTO v_subx FROM public.subjects s WHERE s.discipline_id <> v_d1 ORDER BY s.id LIMIT 1;
  v_cat := (public.course_catalogue_labels())[1];
  v_prefix := format('INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, ');

  check_name := 'setup: two student profiles, a discipline with subjects, a subject of another discipline, a catalogue label; baseline recorded';
  pass := v_student IS NOT NULL AND v_other IS NOT NULL AND v_d1 IS NOT NULL AND v_sub IS NOT NULL AND v_subx IS NOT NULL AND v_cat IS NOT NULL;
  detail := v_n0 || ' study_sessions rows; fixture tag ' || v_tag; RETURN NEXT;

  check_name := 'columns: the seven new columns exist, nullable, with the right types; the two keys are stored generated columns';
  pass := (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull || ':' || a.attgenerated::text, ',' ORDER BY a.attnum)
             FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attnum > 10 AND NOT a.attisdropped)
        = 'classification:text:false:,discipline_id:uuid:false:,subject_id:uuid:false:,custom_course_label:text:false:,custom_course_key:text:false:s,custom_subject_label:text:false:,custom_subject_key:text:false:s';
  detail := ''; RETURN NEXT;

  check_name := 'columns: the first ten columns are exactly as D2 recorded';
  pass := (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
             FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attnum BETWEEN 1 AND 10 AND NOT a.attisdropped) = $lit$id:uuid,user_id:uuid,started_at:timestamp with time zone,ended_at:timestamp with time zone,duration_seconds:integer,session_date:date,source:text,created_at:timestamp with time zone,category:text,session_id:uuid$lit$;
  detail := ''; RETURN NEXT;

  check_name := 'constraints: every existing study_sessions constraint is unchanged (name and definition, as D2)';
  pass := (SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") FROM pg_constraint
            WHERE conrelid = 'public.study_sessions'::regclass
              AND conname NOT IN ('study_sessions_discipline_id_fkey', 'study_sessions_discipline_subject_fkey', 'study_sessions_classification_values', 'study_sessions_classification_shape', 'study_sessions_machine_source_unclassified'))
        = $lit$study_sessions_category_check|CHECK (((category IS NULL) OR (category = ANY (ARRAY['reading'::text, 'writing_practice'::text, 'lecture_viewing'::text, 'paper_solving'::text, 'mock_test'::text]))));study_sessions_duration_floor|CHECK (((source <> 'manual'::text) OR (duration_seconds >= 600))) NOT VALID;study_sessions_duration_seconds_check|CHECK ((duration_seconds > 0));study_sessions_machine_duration_max|CHECK (((source = 'manual'::text) OR (duration_seconds <= 14400))) NOT VALID;study_sessions_machine_time_integrity|CHECK (((source = 'manual'::text) OR ((ended_at >= started_at) AND ((duration_seconds)::numeric <= (EXTRACT(epoch FROM (ended_at - started_at)) + (2)::numeric)))));study_sessions_manual_requires_category|CHECK (((source <> 'manual'::text) OR (category IS NOT NULL))) NOT VALID;study_sessions_pkey|PRIMARY KEY (id);study_sessions_source_check|CHECK ((source = ANY (ARRAY['manual'::text, 'study_mode'::text, 'practice_mode'::text])));study_sessions_user_id_fkey|FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$lit$;
  detail := ''; RETURN NEXT;

  check_name := 'constraints: the five new constraints exist, all NOT VALID (not validated), keys with the stated columns and no cascade';
  pass := (SELECT count(*) FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass AND NOT convalidated
              AND conname IN ('study_sessions_discipline_id_fkey', 'study_sessions_discipline_subject_fkey', 'study_sessions_classification_values', 'study_sessions_classification_shape', 'study_sessions_machine_source_unclassified')) = 5
      AND (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'study_sessions_discipline_id_fkey') = 'FOREIGN KEY (discipline_id) REFERENCES disciplines(id) NOT VALID'
      AND (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'study_sessions_discipline_subject_fkey') = 'FOREIGN KEY (discipline_id, subject_id) REFERENCES subjects(discipline_id, id) NOT VALID';
  detail := (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'study_sessions_discipline_subject_fkey'); RETURN NEXT;

  check_name := 'subjects: UNIQUE (discipline_id, id) exists and validated; the earlier constraints are unchanged';
  pass := (SELECT count(*) FROM pg_constraint WHERE conrelid = 'public.subjects'::regclass AND conname = 'subjects_discipline_id_id_key' AND contype = 'u' AND convalidated
              AND pg_get_constraintdef(oid) = 'UNIQUE (discipline_id, id)') = 1
      AND (SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") FROM pg_constraint WHERE conrelid = 'public.subjects'::regclass AND conname <> 'subjects_discipline_id_id_key') = $lit$subjects_discipline_id_fkey|FOREIGN KEY (discipline_id) REFERENCES disciplines(id) ON DELETE CASCADE;subjects_pkey|PRIMARY KEY (id)$lit$;
  detail := ''; RETURN NEXT;

  check_name := 'trigger and function: BEFORE INSERT or UPDATE OF the two labels, enabled; function is SECURITY DEFINER, owner postgres, pinned search_path, no EXECUTE for PUBLIC, anon, authenticated or service_role';
  pass := (SELECT count(*) FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND t.tgname = 'trg_study_sessions_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal) = 1
      AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal) = 1
      AND (SELECT p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres' AND p.proconfig = ARRAY['search_path=pg_catalog, public'] FROM pg_proc p WHERE p.oid = 'public.fn_study_sessions_label_guard()'::regprocedure)
      AND NOT has_function_privilege('anon', 'public.fn_study_sessions_label_guard()', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'public.fn_study_sessions_label_guard()', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.fn_study_sessions_label_guard()', 'EXECUTE')
      AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = 'public.fn_study_sessions_label_guard()'::regprocedure AND a.grantee = 0);
  detail := (SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname = 'trg_study_sessions_label_guard'); RETURN NEXT;

  check_name := 'privileges: authenticated INSERT, MAINTAIN, SELECT only (as D2); service_role DELETE, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE (no INSERT, no UPDATE); anon none';
  pass := (SELECT string_agg(p, ',' ORDER BY p) FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p WHERE has_table_privilege('authenticated', 'public.study_sessions', p)) = 'INSERT,MAINTAIN,SELECT'
      AND (SELECT string_agg(p, ',' ORDER BY p) FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p WHERE has_table_privilege('service_role', 'public.study_sessions', p)) = 'DELETE,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE'
      AND NOT EXISTS (SELECT 1 FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) p WHERE has_table_privilege('anon', 'public.study_sessions', p));
  detail := ''; RETURN NEXT;

  check_name := 'privileges: no column-level ACL, no PUBLIC grant, owner postgres, RLS enabled and the two D2 policies unchanged';
  pass := NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.study_sessions'::regclass AND attnum > 0 AND attacl IS NOT NULL)
      AND NOT EXISTS (SELECT 1 FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a WHERE c.oid = 'public.study_sessions'::regclass AND a.grantee = 0)
      AND (SELECT pg_get_userbyid(relowner) = 'postgres' AND relrowsecurity AND NOT relforcerowsecurity FROM pg_class WHERE oid = 'public.study_sessions'::regclass)
      AND (SELECT string_agg(policyname || '|' || cmd || '|' || roles::text || '|' || coalesce(qual, '-') || '|' || coalesce(with_check, '-'), ';' ORDER BY policyname COLLATE "C") FROM pg_policies WHERE schemaname = 'public' AND tablename = 'study_sessions') = $lit$study_sessions: users insert own rows|INSERT|{authenticated}|-|(auth.uid() = user_id);study_sessions: users read own rows|SELECT|{authenticated}|(auth.uid() = user_id)|-$lit$;
  detail := ''; RETURN NEXT;

  check_name := 'no backfill: every row that existed before this run has NULL in all seven new columns';
  pass := v_nonnull = 0; detail := v_nonnull || ' rows with a non-NULL new column of ' || v_n0; RETURN NEXT;

  -- ---- authenticated student: every insert case and the label/key reads, in one rolled-back sub-transaction
  check_name := 'real role student: every classification case gives its expected result (accepted, or refused with the stated SQLSTATE)';
  v_bad := ''; v_cnt := 0; v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    FOR r IN SELECT x->>'n' AS n, x->>'c' AS c, x->>'v' AS v, x->>'e' AS e FROM jsonb_array_elements(v_cases) x LOOP
      v_cnt := v_cnt + 1;
      v_sql := v_prefix || r.c || ') VALUES (' || quote_literal(v_student) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, '
               || replace(replace(replace(replace(replace(replace(r.v, '%TAG%', v_tag), '%D1%', v_d1::text), '%SUBX%', v_subx::text), '%SUB%', v_sub::text), '%DNAME%', replace(v_dname, '''', '''''')), '%CAT%', v_cat) || ')';
      BEGIN
        EXECUTE v_sql;
        v_res := 'ok';
      EXCEPTION WHEN OTHERS THEN
        v_res := SQLSTATE;
      END;
      IF v_res <> r.e THEN v_bad := v_bad || r.n || ' -> ' || v_res || '; '; END IF;
    END LOOP;
    -- stored values (read as the student; RLS lets the owner of the row read it)
    SELECT custom_course_label, custom_course_key INTO v_lab, v_key FROM public.study_sessions WHERE custom_course_label LIKE 'ZZ  Alpha  ' || v_tag;
    IF v_lab IS DISTINCT FROM ('ZZ  Alpha  ' || v_tag) OR v_key IS DISTINCT FROM ('zz alpha ' || v_tag) THEN v_bad := v_bad || 'trim/key of the Alpha label wrong (' || coalesce(v_lab, 'NULL') || ' / ' || coalesce(v_key, 'NULL') || '); '; END IF;
    SELECT custom_subject_label, custom_subject_key INTO v_lab, v_key FROM public.study_sessions WHERE custom_course_label = 'ZZ Beta ' || v_tag;
    IF v_lab IS DISTINCT FROM ('ZZ Sub ' || v_tag) OR v_key IS DISTINCT FROM ('zz sub ' || v_tag) THEN v_bad := v_bad || 'subject label trim/key wrong; '; END IF;
    SELECT count(DISTINCT custom_course_key) INTO v_cnt FROM public.study_sessions WHERE custom_course_label ILIKE 'zz%alpha%' || v_tag;
    IF v_cnt <> 1 THEN v_bad := v_bad || 'two spellings of one label gave ' || v_cnt || ' keys; '; END IF;
    SELECT length(custom_course_label) INTO v_len FROM public.study_sessions WHERE custom_course_label = repeat('y', 120);
    IF v_len IS DISTINCT FROM 120 THEN v_bad := v_bad || '120-character label not stored untruncated; '; END IF;
    SELECT custom_course_label, custom_course_key INTO v_lab, v_key FROM public.study_sessions WHERE custom_course_label = v_cat;
    IF v_lab IS DISTINCT FROM v_cat OR v_key IS DISTINCT FROM public.normalize_course_text(v_cat) THEN v_bad := v_bad || 'catalogue label not stored canonically; '; END IF;
    -- a student cannot insert for another user
    BEGIN
      EXECUTE v_prefix || 'source, category) VALUES (' || quote_literal(v_other) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, ''manual'', ''reading'')';
      v_bad := v_bad || 'insert for another user allowed; ';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    -- a student cannot UPDATE
    BEGIN
      UPDATE public.study_sessions SET category = category WHERE false;
      v_bad := v_bad || 'authenticated UPDATE allowed; ';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    RESET ROLE;
    -- owner-level UPDATE of a label passes through the guard
    SELECT id INTO v_id FROM public.study_sessions WHERE custom_course_label = 'ZZ Beta ' || v_tag;
    BEGIN
      UPDATE public.study_sessions SET custom_course_label = '   ' WHERE id = v_id;
      v_bad := v_bad || 'owner UPDATE to a blank label allowed; ';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
      UPDATE public.study_sessions SET custom_subject_label = repeat('q', 121) WHERE id = v_id;
      v_bad := v_bad || 'owner UPDATE to a 121-character subject label allowed; ';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    RAISE EXCEPTION 'b04a_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b04a_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_bad = ''; detail := jsonb_array_length(v_cases) || ' insert cases plus stored-value, other-user, UPDATE and owner-UPDATE checks. ' || v_bad; RETURN NEXT;

  -- ---- service_role
  check_name := 'real role service_role: INSERT and UPDATE refused (42501), SELECT works (the daily summary edge function still reads)';
  v_state := '';
  BEGIN
    SET LOCAL ROLE service_role;
    BEGIN PERFORM count(*) FROM public.study_sessions; v_state := v_state || 'select-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'select-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.study_sessions SET category = category WHERE false; v_state := v_state || 'update-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'update-refused;'; END;
    BEGIN EXECUTE v_prefix || 'source, category) VALUES (' || quote_literal(v_student) || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, ''manual'', ''reading'')'; v_state := v_state || 'insert-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'insert-refused;'; END;
    RESET ROLE;
    RAISE EXCEPTION 'b04a_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b04a_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'select-ok;update-refused;insert-refused;'; detail := v_state; RETURN NEXT;

  check_name := 'live rows: count and the pre-existing-column hash equal the baseline and no fixture row remains';
  pass := (SELECT count(*) FROM public.study_sessions) = v_n0
      AND (SELECT md5(coalesce(string_agg(jsonb_build_array(id, user_id, started_at, ended_at, duration_seconds, session_date, source, created_at, category, session_id)::text, '|' ORDER BY id), '')) FROM public.study_sessions) = v_h0
      AND NOT EXISTS (SELECT 1 FROM public.study_sessions WHERE classification IS NOT NULL OR custom_course_label IS NOT NULL OR custom_subject_label IS NOT NULL);
  detail := (SELECT count(*) FROM public.study_sessions) || ' rows'; RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b04a_results AS SELECT * FROM pg_temp.b04a_checks();

SELECT check_name, pass, detail FROM b04a_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass) FROM b04a_results), (SELECT count(*) || ' checks' FROM b04a_results);
