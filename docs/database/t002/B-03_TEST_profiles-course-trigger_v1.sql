-- Name: [TEST] T-002 B-03 TEST (v1) - verify the profiles course trigger (rollback-only)
--
-- Description: Verification for B-03_SCHEMA_profiles-course-trigger_v1.sql, run AFTER it. Persists nothing: one temporary function and one temporary table; every row it inserts or updates lives in a sub-transaction
-- that is rolled back, and the file proves at the end that profiles is byte-for-byte what it was (row count and a hash over every column of every row). Run the whole file as ONE selection; it returns one row per
-- check with pass true or false, then a summary row. Every check must be true. Stop and report on any false or any SQL error; do not edit and re-run.
-- It proves: the trigger, function and ACL as built; the three older triggers and the CHECK unchanged; as the real role authenticated (JWT claims plus SET LOCAL ROLE) every update case (canonical rewrite of a
-- platform name and of a catalogue label, trimming, 120 and 121 characters, control characters, blank, empty, the word Other, NULL kept, unchanged value, trailing newline); that a legacy over-limit value is never
-- re-validated by an unrelated update or by an equal value, while a changed over-limit value is refused; that a new discipline changes the next canonical resolution immediately; and the real signup chain
-- (a rolled-back auth.users fixture row fires fn_create_profile_on_signup, which inserts the profile): canonical value stored, refused value stops the signup with 23514, NULL kept.

CREATE OR REPLACE FUNCTION pg_temp.b03_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_student uuid;
  v_orig    text;
  v_cat     text;
  v_tag     text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_n0      integer;
  v_h0      text;
  v_bad     text;
  v_res     text;
  v_stored  text;
  v_state   text;
  v_uid     uuid;
  v_did     uuid;
  v_dname   text;
  v_cases   jsonb := $j$[
 {"n": "platform name, case and spacing", "x": "'  ca   final '", "m": "val", "e": "CA Final"},
 {"n": "catalogue label, case and spacing", "x": "regexp_replace(lower('%CAT%'), ' ', '   ', 'g')", "m": "val", "e": "%CAT%"},
 {"n": "custom label trimmed", "x": "'  CFA Level 1  '", "m": "val", "e": "CFA Level 1"},
 {"n": "equal value again (no-op)", "x": "'CFA Level 1'", "m": "val", "e": "CFA Level 1"},
 {"n": "121 characters refused", "x": "repeat('x', 121)", "m": "val", "e": "23514"},
 {"n": "120 characters accepted untruncated", "x": "repeat('y', 120)", "m": "len", "e": "120"},
 {"n": "control character inside refused", "x": "'ab' || chr(9) || 'c'", "m": "val", "e": "23514"},
 {"n": "trailing newline refused", "x": "'CFA' || chr(10)", "m": "val", "e": "23514"},
 {"n": "blank after trim refused", "x": "'   '", "m": "val", "e": "23514"},
 {"n": "empty string refused", "x": "''", "m": "val", "e": "23514"},
 {"n": "the word Other is an ordinary label", "x": "'Other'", "m": "val", "e": "Other"},
 {"n": "NULL is kept", "x": "NULL", "m": "val", "e": "<null>"}
]$j$;
  r         record;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(p)::text, '|' ORDER BY p.id), '')) INTO v_n0, v_h0 FROM public.profiles p;
  SELECT id, course_level INTO v_student, v_orig FROM public.profiles WHERE role = 'student' AND course_level IS NOT NULL ORDER BY id LIMIT 1;
  v_cat := (public.course_catalogue_labels())[1];

  check_name := 'setup: a student profile with a course, a catalogue label; baseline recorded';
  pass := v_student IS NOT NULL AND v_cat IS NOT NULL;
  detail := v_n0 || ' profiles; fixture tag ' || v_tag; RETURN NEXT;

  check_name := 'trigger: BEFORE INSERT OR UPDATE OF course_level, only when the new value is not NULL, enabled, calling the guard function';
  pass := EXISTS (SELECT 1 FROM pg_trigger t
                   WHERE t.tgrelid = 'public.profiles'::regclass AND t.tgname = 'trg_profiles_course_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                     AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_profiles_course_label_guard BEFORE INSERT OR UPDATE OF course_level ON public.profiles FOR EACH ROW WHEN (%new.course_level IS NOT NULL%) EXECUTE FUNCTION fn_profiles_course_label_guard()');
  detail := (SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname = 'trg_profiles_course_label_guard'); RETURN NEXT;

  check_name := 'function: SECURITY DEFINER, owner postgres, pinned search_path, no EXECUTE for PUBLIC, anon, authenticated or service_role';
  pass := (SELECT p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres' AND p.proconfig = ARRAY['search_path=pg_catalog, public'] FROM pg_proc p WHERE p.oid = 'public.fn_profiles_course_label_guard()'::regprocedure)
      AND NOT has_function_privilege('anon', 'public.fn_profiles_course_label_guard()', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'public.fn_profiles_course_label_guard()', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.fn_profiles_course_label_guard()', 'EXECUTE')
      AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = 'public.fn_profiles_course_label_guard()'::regprocedure AND a.grantee = 0);
  detail := (SELECT 'src_md5=' || md5(prosrc) FROM pg_proc WHERE oid = 'public.fn_profiles_course_label_guard()'::regprocedure); RETURN NEXT;

  check_name := 'coexistence: the three older profiles triggers are unchanged (name and definition, as D2)';
  pass := (SELECT string_agg(tgname || '|' || pg_get_triggerdef(oid), ';' ORDER BY tgname COLLATE "C") FROM pg_trigger
            WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal AND tgname <> 'trg_profiles_course_label_guard') = $lit$trg_badge_new_profile|CREATE TRIGGER trg_badge_new_profile AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION fn_badge_check_new_profile();trg_course_change_archive_restore|CREATE TRIGGER trg_course_change_archive_restore AFTER UPDATE OF course_level ON public.profiles FOR EACH ROW WHEN ((old.course_level IS DISTINCT FROM new.course_level)) EXECUTE FUNCTION fn_course_change_archive_restore();trg_guard_profiles_protected_columns|CREATE TRIGGER trg_guard_profiles_protected_columns BEFORE UPDATE ON public.profiles FOR EACH ROW WHEN (((old.id IS DISTINCT FROM new.id) OR (old.role IS DISTINCT FROM new.role) OR (old.account_type IS DISTINCT FROM new.account_type) OR (old.status IS DISTINCT FROM new.status) OR (old.email IS DISTINCT FROM new.email) OR (old.access_request_ref IS DISTINCT FROM new.access_request_ref))) EXECUTE FUNCTION fn_guard_profiles_protected_columns()$lit$;
  detail := ''; RETURN NEXT;

  check_name := 'constraints: every profiles constraint is unchanged (name and definition, as D2)';
  pass := (SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass) = $lit$profiles_account_type_check|CHECK ((account_type = ANY (ARRAY['enrolled'::text, 'self_registered'::text])));profiles_course_level_check|CHECK (((course_level = ANY (ARRAY['CA Foundation'::text, 'CA Intermediate'::text, 'CA Final'::text, 'CMA Foundation'::text, 'CMA Intermediate'::text, 'CMA Final'::text, 'CS Foundation'::text, 'CS Executive'::text, 'CS Professional'::text])) OR (course_level IS NULL) OR (length(course_level) > 0)));profiles_daily_review_goal_check|CHECK (((daily_review_goal > 0) AND (daily_review_goal <= 200)));profiles_daily_study_goal_minutes_check|CHECK (((daily_study_goal_minutes > 0) AND (daily_study_goal_minutes <= 480)));profiles_email_key|UNIQUE (email);profiles_email_normalized|CHECK (((email IS NULL) OR (email = lower(btrim(email)))));profiles_exam_month_check|CHECK (((exam_month IS NULL) OR (EXTRACT(day FROM exam_month) = (1)::numeric)));profiles_id_fkey|FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;profiles_pkey|PRIMARY KEY (id);profiles_status_check|CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])));valid_role|CHECK ((role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'professor'::text, 'student'::text])))$lit$;
  detail := ''; RETURN NEXT;

  -- ---- real role student: every update case, in one rolled-back sub-transaction
  check_name := 'real role student: every update case gives its expected result (stored text or SQLSTATE)';
  v_bad := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    FOR r IN SELECT x->>'n' AS n, x->>'x' AS x, x->>'m' AS m, x->>'e' AS e FROM jsonb_array_elements(v_cases) x LOOP
      BEGIN
        EXECUTE 'UPDATE public.profiles SET course_level = ' || replace(r.x, '%CAT%', v_cat) || ' WHERE id = ' || quote_literal(v_student);
        SELECT course_level INTO v_stored FROM public.profiles WHERE id = v_student;
        IF r.m = 'len' THEN v_res := coalesce(length(v_stored)::text, '<null>'); ELSE v_res := coalesce(v_stored, '<null>'); END IF;
      EXCEPTION WHEN OTHERS THEN
        v_res := SQLSTATE;
      END;
      IF v_res IS DISTINCT FROM replace(r.e, '%CAT%', v_cat) THEN v_bad := v_bad || r.n || ' -> ' || v_res || '; '; END IF;
    END LOOP;
    RESET ROLE;
    RAISE EXCEPTION 'b03_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b03_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_bad = ''; detail := jsonb_array_length(v_cases) || ' cases. ' || v_bad; RETURN NEXT;

  -- ---- legacy value is never re-validated by an unrelated or equal update, but a changed over-limit value is refused
  check_name := 'legacy over-limit value: an unrelated update and an equal value succeed, a changed over-limit value is refused';
  v_state := '';
  BEGIN
    EXECUTE 'ALTER TABLE public.profiles DISABLE TRIGGER trg_profiles_course_label_guard';
    UPDATE public.profiles SET course_level = repeat('L', 130) WHERE id = v_student;
    EXECUTE 'ALTER TABLE public.profiles ENABLE TRIGGER trg_profiles_course_label_guard';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN UPDATE public.profiles SET full_name = full_name WHERE id = v_student; v_state := v_state || 'unrelated-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'unrelated-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.profiles SET course_level = repeat('L', 130) WHERE id = v_student; v_state := v_state || 'equal-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'equal-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.profiles SET course_level = repeat('L', 131) WHERE id = v_student; v_state := v_state || 'changed-allowed;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'changed-' || SQLSTATE || ';'; END;
    RESET ROLE;
    RAISE EXCEPTION 'b03_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b03_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'unrelated-ok;equal-ok;changed-23514;'; detail := v_state; RETURN NEXT;

  -- ---- a new discipline changes the next canonical resolution immediately
  check_name := 'a discipline added now is the canonical text of the very next profile update (no redefinition, no reindex)';
  v_state := '';
  BEGIN
    v_dname := 'ZZ B03 Course ' || v_tag;
    INSERT INTO public.disciplines (name, code) VALUES (v_dname, 'ZZB3' || v_tag) RETURNING id INTO v_did;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    UPDATE public.profiles SET course_level = '  zz  b03   COURSE ' || v_tag || ' ' WHERE id = v_student;
    SELECT course_level INTO v_stored FROM public.profiles WHERE id = v_student;
    v_state := coalesce(v_stored, '<null>');
    RESET ROLE;
    RAISE EXCEPTION 'b03_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b03_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'ZZ B03 Course ' || v_tag; detail := v_state; RETURN NEXT;

  -- ---- the real signup chain: auth.users fixture row -> fn_create_profile_on_signup -> profiles insert
  check_name := 'signup chain: a custom course typed with spaces is stored trimmed, a platform name canonical, NULL kept, a 121-character value stops the signup (23514)';
  v_state := '';
  FOR r IN SELECT * FROM (VALUES
      (1, '''  CFA Level 1  ''', 'CFA Level 1'),
      (2, '''  ca  final '' ', 'CA Final'),
      (3, 'NULL', '<null>'),
      (4, 'repeat(''x'', 121)', '23514'),
      (5, '''ab'' || chr(9) || ''c''', '23514')
    ) AS t(k, expr, e) LOOP
    v_uid := gen_random_uuid(); v_stored := NULL;
    BEGIN
      EXECUTE 'INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES ($1, $2, jsonb_build_object(''full_name'', ''ZZ B03'', ''course_level'', ' || r.expr || '))'
        USING v_uid, 'zz-b03-' || v_tag || '-' || r.k || '@example.invalid';
      SELECT course_level INTO v_stored FROM public.profiles WHERE id = v_uid;
      v_res := coalesce(v_stored, '<null>');
      RAISE EXCEPTION 'b03_rollback_marker';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'b03_rollback_marker' THEN v_res := SQLSTATE; END IF;
    WHEN OTHERS THEN
      v_res := SQLSTATE;
    END;
    IF v_res IS DISTINCT FROM r.e THEN v_state := v_state || 'case' || r.k || ' -> ' || coalesce(v_res, '?') || '; '; END IF;
  END LOOP;
  pass := v_state = ''; detail := '5 signup cases. ' || v_state; RETURN NEXT;

  check_name := 'live rows: count and a hash over every column of every profile equal the baseline; no fixture row remains';
  pass := (SELECT count(*) FROM public.profiles) = v_n0
      AND (SELECT md5(coalesce(string_agg(to_jsonb(p)::text, '|' ORDER BY p.id), '')) FROM public.profiles p) = v_h0
      AND NOT EXISTS (SELECT 1 FROM public.disciplines WHERE name LIKE 'ZZ B03%')
      AND NOT EXISTS (SELECT 1 FROM auth.users WHERE email LIKE 'zz-b03-%@example.invalid');
  detail := (SELECT count(*) FROM public.profiles) || ' profiles'; RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b03_results AS SELECT * FROM pg_temp.b03_checks();

SELECT check_name, pass, detail FROM b03_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass) FROM b03_results), (SELECT count(*) || ' checks' FROM b03_results);
