-- Name: [TEST] T-002 B-04a-fix TEST (v1) - verify the explicit control-character set in the study_sessions label guard (rollback-only)
--
-- Description: Verification for B-04a-fix_SCHEMA_label-guard-control-set_v1.sql, run AFTER it. Persists nothing: one temporary function and one temporary table; every row it inserts lives in a sub-transaction that is
-- rolled back, and the file proves at the end that study_sessions is byte-for-byte what it was (row count and a hash over every column of every row). Run the whole file as ONE selection; it returns one row per check with
-- pass true or false, then a summary row (a missing result counts as false). Every check must be true. Stop and report on any false or any SQL error; do not edit and re-run.
-- It proves: the function identity (new body, SECURITY DEFINER, owner, config, ACL) and the unchanged trigger; as the real role authenticated (JWT claims plus SET LOCAL ROLE) that U+2028, U+2029, DEL, C1 and tab at
-- inside, leading and trailing positions are refused (SQLSTATE 23514) for BOTH the custom course label and the custom subject label, and that the earlier behaviour is unchanged (trimming, 120 and 121 characters,
-- platform-name refusal, catalogue label, blank); and that an owner-level UPDATE of a label to a U+2028 value is refused by the same guard.

CREATE OR REPLACE FUNCTION pg_temp.b04fix_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_student uuid;
  v_dname   text;
  v_cat     text;
  v_tag     text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_n0      integer;
  v_h0      text;
  v_bad     text;
  v_res     text;
  v_sql     text;
  v_state   text;
  v_id      uuid;
  v_cases   jsonb := $j$[
 {
  "n": "course label, U+2028 trailing refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'CFA' || chr(8232)",
  "e": "23514"
 },
 {
  "n": "subject label, U+2028 trailing refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', 'CFA' || chr(8232)",
  "e": "23514"
 },
 {
  "n": "course label, U+2029 leading refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', chr(8233) || 'CFA'",
  "e": "23514"
 },
 {
  "n": "subject label, U+2029 leading refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', chr(8233) || 'CFA'",
  "e": "23514"
 },
 {
  "n": "course label, U+2028 inside refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'a' || chr(8232) || 'b'",
  "e": "23514"
 },
 {
  "n": "subject label, U+2028 inside refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', 'a' || chr(8232) || 'b'",
  "e": "23514"
 },
 {
  "n": "course label, U+2029 inside refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'a' || chr(8233) || 'b'",
  "e": "23514"
 },
 {
  "n": "subject label, U+2029 inside refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', 'a' || chr(8233) || 'b'",
  "e": "23514"
 },
 {
  "n": "course label, DEL inside refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'a' || chr(127) || 'b'",
  "e": "23514"
 },
 {
  "n": "subject label, DEL inside refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', 'a' || chr(127) || 'b'",
  "e": "23514"
 },
 {
  "n": "course label, C1 inside refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'a' || chr(133) || 'b'",
  "e": "23514"
 },
 {
  "n": "subject label, C1 inside refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', 'a' || chr(133) || 'b'",
  "e": "23514"
 },
 {
  "n": "course label, tab trailing refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', 'CFA' || chr(9)",
  "e": "23514"
 },
 {
  "n": "subject label, tab trailing refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', 'CFA' || chr(9)",
  "e": "23514"
 },
 {
  "n": "course label, tab leading refused",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', chr(9) || 'CFA'",
  "e": "23514"
 },
 {
  "n": "subject label, tab leading refused",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', chr(9) || 'CFA'",
  "e": "23514"
 },
 {
  "n": "course label trimmed (unchanged behaviour)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', '  ZZ Alpha  %TAG%  '",
  "e": "ok"
 },
 {
  "n": "course label of 120 characters accepted",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', repeat('y', 120)",
  "e": "ok"
 },
 {
  "n": "course label of 121 characters refused (unchanged)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', repeat('x', 121)",
  "e": "23514"
 },
 {
  "n": "course label equal to a platform course refused (unchanged)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', regexp_replace(lower('%DNAME%'), ' ', '   ', 'g')",
  "e": "23514"
 },
 {
  "n": "catalogue label accepted (unchanged)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', regexp_replace(lower('%CAT%'), ' ', '   ', 'g')",
  "e": "ok"
 },
 {
  "n": "subject label trimmed (unchanged)",
  "c": "source, category, classification, custom_course_label, custom_subject_label",
  "v": "'manual', 'reading', 'custom', 'ZZ Course %TAG%', ' ZZ Sub %TAG% '",
  "e": "ok"
 },
 {
  "n": "blank course label refused (unchanged)",
  "c": "source, category, classification, custom_course_label",
  "v": "'manual', 'reading', 'custom', '    '",
  "e": "23514"
 }
]$j$;
  r         record;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(s)::text, '|' ORDER BY s.id), '')) INTO v_n0, v_h0 FROM public.study_sessions s;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT d.name INTO v_dname FROM public.disciplines d ORDER BY d.name LIMIT 1;
  v_cat := (public.course_catalogue_labels())[1];

  check_name := 'setup: a student profile, a discipline and a catalogue label; baseline recorded';
  pass := v_student IS NOT NULL AND v_dname IS NOT NULL AND v_cat IS NOT NULL;
  detail := v_n0 || ' study_sessions rows; fixture tag ' || v_tag; RETURN NEXT;

  check_name := 'function: the explicit-set body, SECURITY DEFINER, owner postgres, pinned search_path, owner-only ACL; the trigger is unchanged and enabled';
  pass := (SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; config=' || coalesce(p.proconfig::text, '-') || '; acl=' || coalesce(p.proacl::text, '-')
                  || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
             FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()'))
        = 'owner=postgres; secdef=true; config={"search_path=pg_catalog, public"}; acl={postgres=X/postgres}; body_md5_without_carriage_returns=39c60b5631a2ba031384f567287bd103'
      AND EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND t.tgname = 'trg_study_sessions_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                    AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_study_sessions_label_guard BEFORE INSERT OR UPDATE OF custom_course_label, custom_subject_label ON public.study_sessions FOR EACH ROW WHEN (%new.custom_course_label IS NOT NULL%new.custom_subject_label IS NOT NULL%) EXECUTE FUNCTION fn_study_sessions_label_guard()');
  detail := ''; RETURN NEXT;

  check_name := 'real role student: every case gives its expected result (accepted, or refused with 23514)';
  v_bad := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    FOR r IN SELECT x->>'n' AS n, x->>'c' AS c, x->>'v' AS v, x->>'e' AS e FROM jsonb_array_elements(v_cases) x LOOP
      v_sql := 'INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, ' || r.c || ') VALUES (' || quote_literal(v_student)
               || ', now() - interval ''2 hours'', now() - interval ''1 hour'', 3600, current_date, '
               || replace(replace(replace(replace(r.v, '%TAG%', v_tag), '%DNAME%', replace(v_dname, '''', '''''')), '%CAT%', v_cat), '%X%', '') || ')';
      BEGIN
        EXECUTE v_sql;
        v_res := 'ok';
      EXCEPTION WHEN OTHERS THEN
        v_res := SQLSTATE;
      END;
      IF v_res <> r.e THEN v_bad := v_bad || r.n || ' -> ' || v_res || '; '; END IF;
    END LOOP;
    RESET ROLE;
    RAISE EXCEPTION 'b04fix_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b04fix_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_bad = ''; detail := jsonb_array_length(v_cases) || ' cases. ' || v_bad; RETURN NEXT;

  check_name := 'owner-level UPDATE of a label to a U+2028 or U+2029 value is refused by the same guard';
  v_state := '';
  BEGIN
    INSERT INTO public.study_sessions (user_id, started_at, ended_at, duration_seconds, session_date, source, category, classification, custom_course_label)
    VALUES (v_student, now() - interval '2 hours', now() - interval '1 hour', 3600, current_date, 'manual', 'reading', 'custom', 'ZZ Upd ' || v_tag) RETURNING id INTO v_id;
    BEGIN UPDATE public.study_sessions SET custom_course_label = 'CFA' || chr(8232) WHERE id = v_id; v_state := v_state || 'course-2028-allowed;'; EXCEPTION WHEN check_violation THEN v_state := v_state || 'course-2028-refused;'; END;
    BEGIN UPDATE public.study_sessions SET custom_subject_label = chr(8233) || 'CFA' WHERE id = v_id; v_state := v_state || 'subject-2029-allowed;'; EXCEPTION WHEN check_violation THEN v_state := v_state || 'subject-2029-refused;'; END;
    RAISE EXCEPTION 'b04fix_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b04fix_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'course-2028-refused;subject-2029-refused;'; detail := v_state; RETURN NEXT;

  check_name := 'live rows: count and a hash over every column of every row equal the baseline; no fixture row remains';
  pass := (SELECT count(*) FROM public.study_sessions) = v_n0
      AND (SELECT md5(coalesce(string_agg(to_jsonb(s)::text, '|' ORDER BY s.id), '')) FROM public.study_sessions s) = v_h0;
  detail := (SELECT count(*) FROM public.study_sessions) || ' rows'; RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b04fix_results AS SELECT * FROM pg_temp.b04fix_checks();

SELECT check_name, pass, detail FROM b04fix_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass IS TRUE) FROM b04fix_results), (SELECT count(*) || ' checks' FROM b04fix_results);
