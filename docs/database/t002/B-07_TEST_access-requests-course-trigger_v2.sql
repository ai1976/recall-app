-- Name: [TEST] T-002 B-07 TEST (v2) - verify the access_requests course trigger (rollback-only)
--
-- Description: Verification for B-07_SCHEMA_access-requests-course-trigger_v2.sql, run AFTER it. v2 (QA Round 68): updates are run as a real admin (the role the UPDATE policy allows); a change of request_type into student_access is validated (long free text refused, equal course refused, valid text accepted and canonicalised); the two other writers are called as the real function submit_institute_inquiry and submit_educator_application; control-character cases for DEL, C1, U+2028 and U+2029 at inside, leading and trailing positions; the summary row is fail-closed. Persists nothing: one temporary function and one temporary table; every row it inserts or updates lives in a
-- sub-transaction that is rolled back, and the file proves at the end that access_requests is byte-for-byte what it was (row count and a hash over every column of every row). Run the whole file as ONE selection;
-- it returns one row per check with pass true or false, then a summary row. Every check must be true. Stop and report on any false or any SQL error; do not edit and re-run.
-- It proves: the trigger, function and ACL as built; the constraints unchanged; through the real function submit_access_request called as the real role anon and as a real student (JWT claims plus SET LOCAL ROLE)
-- every course case (trim, canonical rewrite of a platform name and of a catalogue label, 120 and 121 characters, control characters, the word Other, the function's own blank refusal); a direct insert as the real
-- student; an UPDATE of the status does not touch the course, an equal course is a no-op and a changed over-limit course is refused; and that the other request types (institute inquiry, educator application) are NOT
-- affected: a 200-character course and outer spaces are stored exactly as sent.

CREATE OR REPLACE FUNCTION pg_temp.b07_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_student uuid;
  v_admin   uuid;
  v_a1      uuid;
  v_i2      uuid;
  v_e2      uuid;
  v_i4      uuid;
  v_cat     text;
  v_tag     text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_n0      integer;
  v_h0      text;
  v_bad     text;
  v_res     text;
  v_stored  text;
  v_state   text;
  v_id      uuid;
  v_i       integer := 0;
  v_cases   jsonb := $j$[
 {"n": "custom label trimmed", "x": "'  CFA Level 1  '", "m": "val", "e": "CFA Level 1"},
 {"n": "platform name, case and spacing", "x": "'ca   final'", "m": "val", "e": "CA Final"},
 {"n": "catalogue label, case and spacing", "x": "regexp_replace(lower('%CAT%'), ' ', '   ', 'g')", "m": "val", "e": "%CAT%"},
 {"n": "the word Other is an ordinary label", "x": "'Other'", "m": "val", "e": "Other"},
 {"n": "120 characters accepted untruncated", "x": "repeat('y', 120)", "m": "len", "e": "120"},
 {"n": "121 characters refused", "x": "repeat('x', 121)", "m": "val", "e": "23514"},
 {"n": "control character inside refused", "x": "'ab' || chr(9) || 'c'", "m": "val", "e": "23514"},
 {"n": "trailing tab refused", "x": "'CFA' || chr(9)", "m": "val", "e": "23514"},
 {"n": "DEL inside refused", "x": "'a' || chr(127) || 'b'", "m": "val", "e": "23514"},
 {"n": "C1 control inside refused", "x": "'a' || chr(133) || 'b'", "m": "val", "e": "23514"},
 {"n": "U+2028 trailing refused", "x": "'CFA' || chr(8232)", "m": "val", "e": "23514"},
 {"n": "U+2029 leading refused", "x": "chr(8233) || 'CFA'", "m": "val", "e": "23514"},
 {"n": "tab leading refused", "x": "chr(9) || 'CFA'", "m": "val", "e": "23514"},
 {"n": "blank after trim: the function's own refusal", "x": "'   '", "m": "val", "e": "P0001"}
]$j$;
  r         record;
  q         text;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(a)::text, '|' ORDER BY a.id), '')) INTO v_n0, v_h0 FROM public.access_requests a;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT id INTO v_admin FROM public.profiles WHERE role IN ('admin', 'super_admin') ORDER BY role, id LIMIT 1;
  v_cat := (public.course_catalogue_labels())[1];

  check_name := 'setup: a student profile, an admin profile and a catalogue label; baseline recorded';
  pass := v_student IS NOT NULL AND v_admin IS NOT NULL AND v_cat IS NOT NULL;
  detail := v_n0 || ' access requests; fixture tag ' || v_tag; RETURN NEXT;

  check_name := 'trigger: BEFORE INSERT OR UPDATE OF course and request_type, only for request_type student_access, enabled; it is the only trigger on the table';
  pass := EXISTS (SELECT 1 FROM pg_trigger t
                   WHERE t.tgrelid = 'public.access_requests'::regclass AND t.tgname = 'trg_access_requests_course_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                     AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_access_requests_course_label_guard BEFORE INSERT OR UPDATE OF course, request_type ON public.access_requests FOR EACH ROW WHEN (%new.request_type = ''student_access''%) EXECUTE FUNCTION fn_access_requests_course_label_guard()')
      AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.access_requests'::regclass AND NOT tgisinternal) = 1;
  detail := (SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname = 'trg_access_requests_course_label_guard'); RETURN NEXT;

  check_name := 'function: SECURITY DEFINER, owner postgres, pinned search_path, no EXECUTE for PUBLIC, anon, authenticated or service_role';
  pass := (SELECT p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres' AND p.proconfig = ARRAY['search_path=pg_catalog, public'] FROM pg_proc p WHERE p.oid = 'public.fn_access_requests_course_label_guard()'::regprocedure)
      AND NOT has_function_privilege('anon', 'public.fn_access_requests_course_label_guard()', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'public.fn_access_requests_course_label_guard()', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.fn_access_requests_course_label_guard()', 'EXECUTE')
      AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = 'public.fn_access_requests_course_label_guard()'::regprocedure AND a.grantee = 0);
  detail := (SELECT 'src_md5=' || md5(prosrc) FROM pg_proc WHERE oid = 'public.fn_access_requests_course_label_guard()'::regprocedure); RETURN NEXT;

  check_name := 'constraints: every access_requests constraint is unchanged (name and definition, as D2)';
  pass := (SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") FROM pg_constraint WHERE conrelid = 'public.access_requests'::regclass) = $lit$access_requests_content_type_check|CHECK ((content_type = ANY (ARRAY['flashcard_deck'::text, 'note'::text])));access_requests_pkey|PRIMARY KEY (id);access_requests_request_type_check|CHECK ((request_type = ANY (ARRAY['student_access'::text, 'institute_inquiry'::text, 'educator_application'::text])));access_requests_requester_user_id_fkey|FOREIGN KEY (requester_user_id) REFERENCES profiles(id) ON DELETE SET NULL;access_requests_status_check|CHECK ((status = ANY (ARRAY['pending'::text, 'contacted'::text, 'enrolled'::text, 'approved'::text, 'rejected'::text, 'dismissed'::text])))$lit$;
  detail := ''; RETURN NEXT;

  -- ---- every course case through the real function as the real role anon
  check_name := 'real role anon: submit_access_request gives its expected result for every course case (stored text or SQLSTATE)';
  v_bad := '';
  BEGIN
    FOR r IN SELECT x->>'n' AS n, x->>'x' AS x, x->>'m' AS m, x->>'e' AS e FROM jsonb_array_elements(v_cases) x LOOP
      v_i := v_i + 1;
      BEGIN
        SET LOCAL ROLE anon;
        EXECUTE 'SELECT public.submit_access_request(' || quote_literal('ZZ B07 ' || v_tag || ' ' || v_i) || ', ''+910000000000'', '
                || replace(r.x, '%CAT%', v_cat) || ', NULL, NULL, NULL, NULL, NULL)';
        RESET ROLE;
        SELECT course INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' ' || v_i;
        IF r.m = 'len' THEN v_res := coalesce(length(v_stored)::text, '<none>'); ELSE v_res := coalesce(v_stored, '<none>'); END IF;
      EXCEPTION WHEN OTHERS THEN
        RESET ROLE;
        v_res := SQLSTATE;
      END;
      IF v_res IS DISTINCT FROM replace(r.e, '%CAT%', v_cat) THEN v_bad := v_bad || r.n || ' -> ' || v_res || '; '; END IF;
    END LOOP;
    RAISE EXCEPTION 'b07_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b07_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_bad = ''; detail := jsonb_array_length(v_cases) || ' cases. ' || v_bad; RETURN NEXT;

  -- ---- real student: the same function and a direct insert, update behaviour
  check_name := 'real role student: the function and a direct insert apply the rule (a 121-character direct insert is refused)';
  v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM public.submit_access_request('ZZ B07 ' || v_tag || ' s1', '+910000000000', '  CFA Level 2  ', NULL, NULL, NULL, NULL, v_student);
      v_state := v_state || 'rpc-ok;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'rpc-' || SQLSTATE || ';'; END;
    BEGIN
      INSERT INTO public.access_requests (name, whatsapp_number, course, requester_user_id) VALUES ('ZZ B07 ' || v_tag || ' s2', '+910000000000', '  cma   final ', v_student);
      v_state := v_state || 'insert-ok;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'insert-' || SQLSTATE || ';'; END;
    BEGIN
      INSERT INTO public.access_requests (name, whatsapp_number, course, requester_user_id) VALUES ('ZZ B07 ' || v_tag || ' s3', '+910000000000', repeat('x', 121), v_student);
      v_state := v_state || 'insert121-allowed;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'insert121-' || SQLSTATE || ';'; END;
    RESET ROLE;
    SELECT course INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' s1';
    v_state := v_state || 'rpc-stored=' || coalesce(v_stored, '<none>') || ';';
    SELECT course INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' s2';
    v_state := v_state || 'insert-stored=' || coalesce(v_stored, '<none>') || ';';
    RAISE EXCEPTION 'b07_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b07_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'rpc-ok;insert-ok;insert121-23514;rpc-stored=CFA Level 2;insert-stored=CMA Final;';
  detail := v_state; RETURN NEXT;

  -- ---- real admin: the updates the recorded UPDATE policy allows, including a change of request_type into student_access
  check_name := 'real role admin: a status update leaves the course alone, an equal course is a no-op, a changed over-limit course is refused, and a change of request_type INTO student_access is validated';
  v_state := '';
  BEGIN
    INSERT INTO public.access_requests (name, whatsapp_number, course, request_type) VALUES ('ZZ B07 ' || v_tag || ' a1', '+910000000000', 'CMA Final', 'student_access') RETURNING id INTO v_a1;
    INSERT INTO public.access_requests (name, whatsapp_number, course, request_type) VALUES ('ZZ B07 ' || v_tag || ' i2', '+910000000000', repeat('z', 200), 'institute_inquiry') RETURNING id INTO v_i2;
    INSERT INTO public.access_requests (name, whatsapp_number, course, request_type) VALUES ('ZZ B07 ' || v_tag || ' e2', '+910000000000', repeat('e', 130), 'educator_application') RETURNING id INTO v_e2;
    INSERT INTO public.access_requests (name, whatsapp_number, course, request_type) VALUES ('ZZ B07 ' || v_tag || ' i4', '+910000000000', '  ca   final ', 'institute_inquiry') RETURNING id INTO v_i4;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN UPDATE public.access_requests SET status = 'contacted' WHERE id = v_a1; IF FOUND THEN v_state := v_state || 'status-ok;'; ELSE v_state := v_state || 'status-0rows;'; END IF; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'status-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.access_requests SET course = course WHERE id = v_a1; v_state := v_state || 'equal-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'equal-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.access_requests SET course = repeat('x', 121) WHERE id = v_a1; v_state := v_state || 'changed-allowed;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'changed-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.access_requests SET request_type = 'student_access' WHERE id = v_i2; v_state := v_state || 'transition-long-allowed;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'transition-long-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.access_requests SET request_type = 'student_access', course = course WHERE id = v_e2; v_state := v_state || 'transition-equal-allowed;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'transition-equal-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.access_requests SET request_type = 'student_access' WHERE id = v_i4; v_state := v_state || 'transition-valid-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'transition-valid-' || SQLSTATE || ';'; END;
    RESET ROLE;
    SELECT course INTO v_stored FROM public.access_requests WHERE id = v_a1;
    v_state := v_state || 'a1-course=' || coalesce(v_stored, '<none>') || ';';
    SELECT course INTO v_stored FROM public.access_requests WHERE id = v_i4;
    v_state := v_state || 'i4-course=' || coalesce(v_stored, '<none>') || ';';
    SELECT request_type INTO v_stored FROM public.access_requests WHERE id = v_i2;
    v_state := v_state || 'i2-type=' || coalesce(v_stored, '<none>') || ';';
    RAISE EXCEPTION 'b07_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b07_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'status-ok;equal-ok;changed-23514;transition-long-23514;transition-equal-23514;transition-valid-ok;a1-course=CMA Final;i4-course=CA Final;i2-type=institute_inquiry;';
  detail := v_state; RETURN NEXT;

  -- ---- the two other writers, as the real functions under the anon role
  check_name := 'other request types through the real functions (anon): submit_institute_inquiry keeps a 200-character course, submit_educator_application keeps free text, and each writes its own request_type';
  v_state := '';
  BEGIN
    SET LOCAL ROLE anon;
    BEGIN PERFORM public.submit_institute_inquiry('ZZ B07 inst ' || v_tag, 'ZZ B07 ' || v_tag || ' ic', '+910000000000', NULL, NULL, repeat('z', 200), NULL, NULL); v_state := v_state || 'institute-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'institute-' || SQLSTATE || ';'; END;
    BEGIN PERFORM public.submit_educator_application('ZZ B07 ' || v_tag || ' ea', '+910000000000', 'ZZ B07 credential', NULL, NULL, 'CA Final, CMA Final', NULL, NULL); v_state := v_state || 'educator-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'educator-' || SQLSTATE || ';'; END;
    RESET ROLE;
    SELECT request_type || ':' || length(course) INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' ic';
    v_state := v_state || 'institute-row=' || coalesce(v_stored, '<none>') || ';';
    SELECT request_type || ':' || course INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' ea';
    v_state := v_state || 'educator-row=' || coalesce(v_stored, '<none>') || ';';
    RAISE EXCEPTION 'b07_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b07_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'institute-ok;educator-ok;institute-row=institute_inquiry:200;educator-row=educator_application:CA Final, CMA Final;';
  detail := v_state; RETURN NEXT;

  -- ---- other request types are not affected
  check_name := 'other request types (institute_inquiry, educator_application) are NOT affected: a 200-character course and outer spaces are stored exactly as sent';
  v_state := '';
  BEGIN
    INSERT INTO public.access_requests (name, whatsapp_number, course, request_type) VALUES ('ZZ B07 ' || v_tag || ' i1', '+910000000000', repeat('z', 200), 'institute_inquiry');
    INSERT INTO public.access_requests (name, whatsapp_number, course, request_type) VALUES ('ZZ B07 ' || v_tag || ' e1', '+910000000000', '  CA Final, CMA Final  ', 'educator_application');
    SELECT length(course)::text INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' i1';
    v_state := v_state || 'institute-len=' || coalesce(v_stored, '<none>') || ';';
    SELECT '[' || course || ']' INTO v_stored FROM public.access_requests WHERE name = 'ZZ B07 ' || v_tag || ' e1';
    v_state := v_state || 'educator=' || coalesce(v_stored, '<none>') || ';';
    RAISE EXCEPTION 'b07_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b07_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'institute-len=200;educator=[  CA Final, CMA Final  ];'; detail := v_state; RETURN NEXT;

  check_name := 'live rows: count and a hash over every column of every row equal the baseline; no fixture row remains';
  pass := (SELECT count(*) FROM public.access_requests) = v_n0
      AND (SELECT md5(coalesce(string_agg(to_jsonb(a)::text, '|' ORDER BY a.id), '')) FROM public.access_requests a) = v_h0
      AND NOT EXISTS (SELECT 1 FROM public.access_requests WHERE name LIKE 'ZZ B07%');
  detail := (SELECT count(*) FROM public.access_requests) || ' access requests'; RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b07_results AS SELECT * FROM pg_temp.b07_checks();

SELECT check_name, pass, detail FROM b07_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass IS TRUE) FROM b07_results), (SELECT count(*) || ' checks' FROM b07_results);
