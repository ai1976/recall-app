-- Name: [TEST] T-002 B-02a TEST (v1) - verify the disciplines guards (rollback-only)
--
-- Description: Verification for B-02a_SCHEMA_disciplines-guards_v1.sql, run AFTER it. Persists nothing: one temporary function (gone with the session); every row it inserts lives in
-- a sub-transaction that is rolled back. Run the whole file as ONE selection; it returns one row per check with pass true or false and a final summary row. Every check must be
-- true. Stop and report on any false or any SQL error; do not edit and re-run.
-- Checks (brief B 6.4 acceptance): the unique index exists, is valid, is unique and is built on normalize_course_text(name); an exact duplicate, a case variant, a whitespace variant
-- and a title-cased variant are each refused with 23505, including against an INACTIVE row; a rename is refused (23514) and a same-name assignment is allowed; a DELETE is refused
-- (23001) and deactivation succeeds; the triggers are enabled; the functions are INVOKER with a pinned search_path and no client EXECUTE; the three live rows are unchanged.

CREATE OR REPLACE FUNCTION pg_temp.b02a_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_state text;
  v_names_before text;
  v_names_after text;
BEGIN
  SELECT string_agg(name || ':' || is_active::text, ', ' ORDER BY name) INTO v_names_before FROM public.disciplines;

  check_name := 'catalog: the unique index exists, is valid and is built on normalize_course_text(name)';
  pass := EXISTS (SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
                   WHERE c.relname = 'disciplines_normalized_name_uidx' AND i.indisunique AND i.indisvalid
                     AND i.indrelid = 'public.disciplines'::regclass
                     AND pg_get_indexdef(i.indexrelid) LIKE '%normalize_course_text(name)%');
  detail := coalesce((SELECT pg_get_indexdef(i.indexrelid) FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid WHERE c.relname = 'disciplines_normalized_name_uidx'), 'missing'); RETURN NEXT;

  check_name := 'catalog: both guard triggers exist and are enabled';
  pass := (SELECT count(*) FROM pg_trigger g WHERE g.tgrelid = 'public.disciplines'::regclass AND NOT g.tgisinternal AND g.tgenabled = 'O'
                  AND g.tgname IN ('trg_disciplines_no_rename', 'trg_disciplines_no_delete')) = 2;
  detail := ''; RETURN NEXT;

  check_name := 'catalog: guard functions are INVOKER, have a pinned search_path and no client EXECUTE';
  pass := (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname IN ('fn_guard_disciplines_no_rename', 'fn_guard_disciplines_no_delete')
              AND NOT p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, public%') = 2
      AND NOT has_function_privilege('authenticated', 'public.fn_guard_disciplines_no_rename()', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'public.fn_guard_disciplines_no_delete()', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.fn_guard_disciplines_no_delete()', 'EXECUTE');
  detail := ''; RETURN NEXT;

  -- duplicates, against an ACTIVE and an INACTIVE row
  check_name := 'duplicates: exact, case, whitespace and title-cased variants are each refused with 23505 (active and inactive base rows)';
  v_state := '';
  BEGIN
    INSERT INTO public.disciplines (name, code, is_active) VALUES ('ZZ Active Course', 'ZZA', true);
    INSERT INTO public.disciplines (name, code, is_active) VALUES ('ZZ Inactive Course', 'ZZI', false);
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('ZZ Active Course', 'ZZA2');   v_state := v_state || 'exact-allowed;'; EXCEPTION WHEN unique_violation THEN v_state := v_state || 'exact-refused;'; END;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('zz active course', 'ZZA3');   v_state := v_state || 'case-allowed;';  EXCEPTION WHEN unique_violation THEN v_state := v_state || 'case-refused;';  END;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES (E'ZZ   Active\tCourse ', 'ZZA4'); v_state := v_state || 'space-allowed;'; EXCEPTION WHEN unique_violation THEN v_state := v_state || 'space-refused;'; END;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('Zz Inactive Course', 'ZZI2'); v_state := v_state || 'inactive-allowed;'; EXCEPTION WHEN unique_violation THEN v_state := v_state || 'inactive-refused;'; END;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('Ca Final', 'ZZC');            v_state := v_state || 'title-allowed;'; EXCEPTION WHEN unique_violation THEN v_state := v_state || 'title-refused;'; END;
    RAISE EXCEPTION 'b02a_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b02a_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'exact-refused;case-refused;space-refused;inactive-refused;title-refused;'; detail := v_state; RETURN NEXT;

  -- rename
  check_name := 'rename: a rename is refused with 23514; assigning the same name is allowed';
  v_state := '';
  BEGIN
    INSERT INTO public.disciplines (name, code) VALUES ('ZZ Rename Course', 'ZZR');
    BEGIN UPDATE public.disciplines SET name = 'ZZ Renamed' WHERE code = 'ZZR'; v_state := v_state || 'rename-allowed;';
    EXCEPTION WHEN check_violation THEN v_state := v_state || 'rename-refused;'; END;
    BEGIN UPDATE public.disciplines SET name = name WHERE code = 'ZZR'; v_state := v_state || 'same-allowed;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'same-refused;'; END;
    BEGIN UPDATE public.disciplines SET order_num = 9 WHERE code = 'ZZR'; v_state := v_state || 'other-column-allowed;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'other-column-refused;'; END;
    RAISE EXCEPTION 'b02a_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b02a_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'rename-refused;same-allowed;other-column-allowed;'; detail := v_state; RETURN NEXT;

  -- delete and deactivate
  check_name := 'delete: a DELETE is refused with 23001; deactivation succeeds';
  v_state := '';
  BEGIN
    INSERT INTO public.disciplines (name, code) VALUES ('ZZ Delete Course', 'ZZD');
    BEGIN DELETE FROM public.disciplines WHERE code = 'ZZD'; v_state := v_state || 'delete-allowed;';
    EXCEPTION WHEN restrict_violation THEN v_state := v_state || 'delete-refused;'; END;
    BEGIN UPDATE public.disciplines SET is_active = false WHERE code = 'ZZD'; v_state := v_state || 'deactivate-allowed;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'deactivate-refused;'; END;
    RAISE EXCEPTION 'b02a_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b02a_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'delete-refused;deactivate-allowed;'; detail := v_state; RETURN NEXT;

  SELECT string_agg(name || ':' || is_active::text, ', ' ORDER BY name) INTO v_names_after FROM public.disciplines;
  check_name := 'live rows: unchanged after the tests, and no test row remains';
  pass := v_names_before = v_names_after AND NOT EXISTS (SELECT 1 FROM public.disciplines WHERE code LIKE 'ZZ%');
  detail := v_names_after; RETURN NEXT;
END;
$test$;

SELECT check_name, pass, detail FROM pg_temp.b02a_checks()
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass) FROM pg_temp.b02a_checks()), (SELECT count(*) || ' checks' FROM pg_temp.b02a_checks());
