-- Name: [TEST] T-002 B-01 TEST (v2) - verify the course-text normalization, the catalogue-label definition and the canonical label resolver (rollback-only)
--
-- Description: Verification for B-01_FUNCTIONS_course-text-normalize-and-resolve_v2.sql, run AFTER it. v2 adds: the catalogue-label function, exact ACL sets, owner, language, parallel safety, and the database collation recorded in a check's detail (QA Round 40). Persists nothing: it builds one temporary function (it disappears with the
-- session), runs the checks, and the discipline insert used to prove "a new discipline changes the next resolution immediately" happens inside a sub-transaction that is rolled
-- back. Run the whole file as ONE selection; it returns one row per check with pass true or false, and a final summary row. Every check must be true. Stop and report on any false
-- or any SQL error; do not edit and re-run.
-- Checks: behaviour of normalize_course_text (exact, case, repeated spaces, tabs and newlines, outer whitespace, NULL, empty); resolver (a) platform match returns the exact stored
-- name for case and spacing variants, (b) catalogue labels in exact text, (c) custom label trimmed and unchanged, NULL; catalog facts (provolatile i and s, SECURITY INVOKER, the
-- resolver's pinned search_path, EXECUTE grants: authenticated and owner may execute normalize_course_text, nobody else; the resolver is owner-only); a real-role call of
-- normalize_course_text as authenticated; a new discipline is resolved immediately with no redefinition (sub-transaction, rolled back); the three live disciplines resolve.

CREATE OR REPLACE FUNCTION pg_temp.acl_set(p_oid regprocedure)
RETURNS text
LANGUAGE sql
AS $f$
  SELECT coalesce(string_agg(DISTINCT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END, ',' ORDER BY CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END), 'DEFAULT-PUBLIC')
    FROM pg_proc p, aclexplode(p.proacl) a
   WHERE p.oid = p_oid;
$f$;

CREATE OR REPLACE FUNCTION pg_temp.b01_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_text   text;
  v_before text;
  v_after  text;
  v_role_ok boolean;
BEGIN
  -- normalize_course_text
  check_name := 'normalize: exact name is lower-cased';                pass := public.normalize_course_text('CA Final') = 'ca final';                        detail := public.normalize_course_text('CA Final'); RETURN NEXT;
  check_name := 'normalize: repeated spaces collapse';                 pass := public.normalize_course_text('ca    final') = 'ca final';                      detail := public.normalize_course_text('ca    final'); RETURN NEXT;
  check_name := 'normalize: tabs and newlines collapse to one space';  pass := public.normalize_course_text(E'CA\t\n Final') = 'ca final';                    detail := public.normalize_course_text(E'CA\t\n Final'); RETURN NEXT;
  check_name := 'normalize: outer whitespace is trimmed';              pass := public.normalize_course_text(E'  \t CA Final \n ') = 'ca final';                  detail := public.normalize_course_text(E'  \t CA Final \n '); RETURN NEXT;
  check_name := 'normalize: NULL gives NULL';                          pass := public.normalize_course_text(NULL) IS NULL;                                      detail := ''; RETURN NEXT;
  check_name := 'normalize: empty and blank give an empty string';     pass := public.normalize_course_text('') = '' AND public.normalize_course_text(E' \t ') = ''; detail := ''; RETURN NEXT;
  check_name := 'normalize: is idempotent';                            pass := public.normalize_course_text(public.normalize_course_text('  CA   FINAL ')) = public.normalize_course_text('  CA   FINAL '); detail := ''; RETURN NEXT;

  -- resolver (a) platform courses: exact stored text
  check_name := 'resolve (a): case variant of a discipline gives the exact stored name';   v_text := public.resolve_canonical_course_label('ca final');      pass := v_text = 'CA Final'; detail := coalesce(v_text, 'NULL'); RETURN NEXT;
  check_name := 'resolve (a): spacing variant gives the exact stored name';                 v_text := public.resolve_canonical_course_label('  CA   Intermediate '); pass := v_text = 'CA Intermediate'; detail := coalesce(v_text, 'NULL'); RETURN NEXT;
  check_name := 'resolve (a): title-cased variant "Ca Foundation"';                         v_text := public.resolve_canonical_course_label('Ca Foundation'); pass := v_text = 'CA Foundation'; detail := coalesce(v_text, 'NULL'); RETURN NEXT;
  -- (b) catalogue labels in exact text
  check_name := 'resolve (b): CMA variant gives the exact catalogue text';                  v_text := public.resolve_canonical_course_label('cma  final');    pass := v_text = 'CMA Final'; detail := coalesce(v_text, 'NULL'); RETURN NEXT;
  check_name := 'resolve (b): CS Professional variant';                                     v_text := public.resolve_canonical_course_label(' CS professional'); pass := v_text = 'CS Professional'; detail := coalesce(v_text, 'NULL'); RETURN NEXT;
  -- (c) custom
  check_name := 'resolve (c): a custom label is the trimmed input, unchanged';              v_text := public.resolve_canonical_course_label('  My  Own Course '); pass := v_text = 'My  Own Course'; detail := coalesce(v_text, 'NULL'); RETURN NEXT;
  check_name := 'resolve: NULL gives NULL';                                                 pass := public.resolve_canonical_course_label(NULL) IS NULL; detail := ''; RETURN NEXT;

  -- catalog facts
  check_name := 'catalog: normalize_course_text is IMMUTABLE and INVOKER';
  pass := EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'normalize_course_text' AND p.provolatile = 'i' AND NOT p.prosecdef AND p.proisstrict);
  detail := ''; RETURN NEXT;
  check_name := 'catalog: resolve_canonical_course_label is STABLE, INVOKER, pinned search_path';
  pass := EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'resolve_canonical_course_label' AND p.provolatile = 's' AND NOT p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, public%');
  detail := ''; RETURN NEXT;
  check_name := 'catalog: exactly one overload of each function';
  pass := (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'normalize_course_text') = 1
      AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'resolve_canonical_course_label') = 1;
  detail := ''; RETURN NEXT;
  check_name := 'grants: normalize executes for authenticated only (no PUBLIC, anon, service_role)';
  pass := has_function_privilege('authenticated', 'public.normalize_course_text(text)', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'public.normalize_course_text(text)', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.normalize_course_text(text)', 'EXECUTE')
      AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = 'public.normalize_course_text(text)'::regprocedure AND a.grantee = 0);
  detail := ''; RETURN NEXT;
  check_name := 'grants: the resolver is owner-only (no PUBLIC, anon, authenticated, service_role)';
  pass := NOT has_function_privilege('authenticated', 'public.resolve_canonical_course_label(text)', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'public.resolve_canonical_course_label(text)', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.resolve_canonical_course_label(text)', 'EXECUTE')
      AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = 'public.resolve_canonical_course_label(text)'::regprocedure AND a.grantee = 0);
  detail := ''; RETURN NEXT;

  -- v2: the catalogue-label definition, exact ACL sets, owner, language, parallel safety, collation
  check_name := 'labels: course_catalogue_labels returns exactly the six labels in catalogue order';
  pass := public.course_catalogue_labels() = ARRAY['CMA Foundation', 'CMA Intermediate', 'CMA Final', 'CS Foundation', 'CS Executive', 'CS Professional']::text[];
  detail := array_to_string(public.course_catalogue_labels(), ' | '); RETURN NEXT;
  check_name := 'catalog: course_catalogue_labels is IMMUTABLE, INVOKER, one overload';
  pass := (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'course_catalogue_labels' AND p.provolatile = 'i' AND NOT p.prosecdef) = 1
      AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'course_catalogue_labels') = 1;
  detail := ''; RETURN NEXT;
  check_name := 'ACL: exact grantee sets (normalize: authenticated and owner; labels and resolver: owner only)';
  pass := pg_temp.acl_set('public.normalize_course_text(text)'::regprocedure) = 'authenticated,postgres'
      AND pg_temp.acl_set('public.course_catalogue_labels()'::regprocedure) = 'postgres'
      AND pg_temp.acl_set('public.resolve_canonical_course_label(text)'::regprocedure) = 'postgres';
  detail := pg_temp.acl_set('public.normalize_course_text(text)'::regprocedure) || ' / ' || pg_temp.acl_set('public.course_catalogue_labels()'::regprocedure) || ' / ' || pg_temp.acl_set('public.resolve_canonical_course_label(text)'::regprocedure); RETURN NEXT;
  check_name := 'identity: owner postgres, languages sql / sql / plpgsql, normalize and labels PARALLEL SAFE';
  pass := (SELECT bool_and(pg_get_userbyid(p.proowner) = 'postgres') FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname IN ('normalize_course_text', 'course_catalogue_labels', 'resolve_canonical_course_label'))
      AND (SELECT l.lanname FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang WHERE p.oid = 'public.normalize_course_text(text)'::regprocedure) = 'sql'
      AND (SELECT l.lanname FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang WHERE p.oid = 'public.course_catalogue_labels()'::regprocedure) = 'sql'
      AND (SELECT l.lanname FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang WHERE p.oid = 'public.resolve_canonical_course_label(text)'::regprocedure) = 'plpgsql'
      AND (SELECT p.proparallel FROM pg_proc p WHERE p.oid = 'public.normalize_course_text(text)'::regprocedure) = 's'
      AND (SELECT p.proparallel FROM pg_proc p WHERE p.oid = 'public.course_catalogue_labels()'::regprocedure) = 's';
  detail := ''; RETURN NEXT;
  check_name := 'collation: the database default collation is recorded (it makes lower() deterministic, so IMMUTABLE honest)';
  pass := (SELECT datcollate FROM pg_database WHERE datname = current_database()) IS NOT NULL;
  detail := (SELECT 'datcollate=' || datcollate || ' datctype=' || datctype FROM pg_database WHERE datname = current_database()); RETURN NEXT;

  -- real role: authenticated can call normalize; cannot call the resolver
  check_name := 'real role: authenticated runs normalize_course_text and is refused the resolver';
  v_role_ok := false;
  detail := '';
  BEGIN
    SET LOCAL ROLE authenticated;
    v_text := public.normalize_course_text('  CA   FINAL ');
    v_role_ok := (v_text = 'ca final');
    BEGIN
      PERFORM public.resolve_canonical_course_label('ca final');
      v_role_ok := false;                       -- must have been refused
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;                                      -- expected
    END;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v_role_ok := false;
    detail := SQLERRM;
  END;
  pass := v_role_ok; detail := coalesce(detail, ''); RETURN NEXT;

  -- a new discipline is resolved immediately, with no redefinition and no reindex (sub-transaction, rolled back)
  check_name := 'new discipline: resolution changes immediately, then the insert is rolled back';
  v_before := public.resolve_canonical_course_label('zz test course');
  BEGIN
    INSERT INTO public.disciplines (name, code, is_active) VALUES ('ZZ Test Course', 'ZZTEST', false);
    v_after := public.resolve_canonical_course_label('  zz   TEST course');
    RAISE EXCEPTION 'b01_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b01_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_before = 'zz test course' AND v_after = 'ZZ Test Course'
          AND NOT EXISTS (SELECT 1 FROM public.disciplines WHERE code = 'ZZTEST');
  detail := 'before=' || coalesce(v_before, 'NULL') || ' after=' || coalesce(v_after, 'NULL'); RETURN NEXT;

  -- the three live platform disciplines resolve to themselves
  check_name := 'live disciplines: every stored name resolves to itself';
  pass := NOT EXISTS (SELECT 1 FROM public.disciplines d WHERE public.resolve_canonical_course_label(d.name) IS DISTINCT FROM d.name)
          AND (SELECT count(*) FROM public.disciplines) >= 3;
  detail := (SELECT string_agg(d.name, ', ' ORDER BY d.name) FROM public.disciplines d); RETURN NEXT;
END;
$test$;

SELECT check_name, pass, detail FROM pg_temp.b01_checks()
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass) FROM pg_temp.b01_checks()), (SELECT count(*) || ' checks' FROM pg_temp.b01_checks());
