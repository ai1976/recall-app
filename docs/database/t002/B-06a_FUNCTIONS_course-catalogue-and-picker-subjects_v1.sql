-- Name: [FUNCTIONS] T-002 B-06a (v1) - course catalogue core, public and authenticated course-option readers, and the picker subject list
--
-- Description: PERSISTENT DDL. Implements plan v18 section 8 (brief B v10 `0fe77dec72dc`, Gate 1 given 04/10/2026, sections 4.5, 5.4 and 5.5). Creates four functions and changes nothing else (no table, no data,
-- no trigger, no policy). Tier 1: QA audits this exact file by hash, the Founder authorizes the production run by hash (Gates 2 and 3). The SQL Editor runs a selection in ONE transaction, so this file has no
-- verification and no ROLLBACK of its own; verification is B-06a_TEST, undo is B-06a_ROLLBACK.
--   1) public.fn_course_options_core(p_surface text, p_user_id uuid): the ONE catalogue definition, owner only (SECURITY DEFINER, executable by no client role). Surfaces 'signup', 'profile', 'access', 'picker'.
--      Platform courses come from public.disciplines (identity uses every row, active or not; alternatives only active rows) in order (order_num, name); the six CMA and CS labels come from
--      public.course_catalogue_labels() (B-01, no second copy); overlays come from the caller's profile (current course) and own custom study_sessions (prior custom labels, display label = the label of the row with
--      the greatest (created_at, id) for the key, never another student's text). Comparison uses public.normalize_course_text. Precedence platform > current > catalogue > prior_custom with explicit flag columns.
--      A current course that is blank or longer than 120 characters is not offered. Positions are set here (1..n). Picker: current first, other ACTIVE platform courses, at most ten earlier custom labels
--      (catalogue labels only when current or used before), General, Other.
--   2) public.get_course_options_public(): the base list for Signup (no overlays, no General, no current); executable by anon and authenticated.
--   3) public.get_course_options(p_surface text): 'profile', 'access' or 'picker', overlays from auth.uid() only; authenticated only; no session raises 28000, an unknown surface 22023.
--   4) public.get_picker_subjects(p_discipline_id uuid DEFAULT NULL, p_course_key text DEFAULT NULL): exactly one argument must be given (22023 otherwise); a discipline lists its ACTIVE subjects (an inactive
--      discipline is allowed) plus Skip; a course key lists the caller's own earlier custom subject labels for that key (at most ten, most recent first), Other and Skip. Authenticated only.
--      Reading of the plan stated for QA: a platform course returns no `other_action` row because the stored shape forbids a custom subject label on a platform session (B-04a); the list is still never empty (Skip).
-- All four are STABLE, SECURITY DEFINER, pinned search_path = pg_catalog, public, owner postgres. Privileges: REVOKE from PUBLIC, anon, authenticated and service_role first (objects created by postgres are
-- default-granted), then granted exactly as plan v18 section 10 lists.
-- Pre-flight (fails closed, nothing is created): role postgres; the three B-01 functions exactly as the B-04a VERIFY run recorded them; the B-02a unique index; the columns this file reads on study_sessions,
-- disciplines, subjects and profiles; none of the four names exists in any overload; auth.uid() exists. Post-check: every function as built (owner, security mode, volatility, search_path, language, body hash, no PUBLIC
-- privilege, exact anon/authenticated/service_role execute matrix), else the whole run is undone. Final result: one row per function with its body hash and execute matrix.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $guard$
DECLARE
  v text;
  r record;
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  FOR r IN SELECT x.sig, x.expected FROM (VALUES
    ('public.course_catalogue_labels()', 'owner=postgres; volatility=i; secdef=false; strict=false; config=-; src_md5=931e3f507c8fc967c8940d4b77a12188; acl={postgres=X/postgres}'),
    ('public.normalize_course_text(text)', 'owner=postgres; volatility=i; secdef=false; strict=true; config=-; src_md5=41f75fecfa300bb0588c677885ce16bb; acl={postgres=X/postgres,authenticated=X/postgres}'),
    ('public.resolve_canonical_course_label(text)', 'owner=postgres; volatility=s; secdef=false; strict=false; config={"search_path=pg_catalog, public"}; src_md5=303aab7dc4bfbb832c57682538aa6cfe; acl={postgres=X/postgres}')
  ) AS x(sig, expected) LOOP
    SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; volatility=' || p.provolatile::text || '; secdef=' || p.prosecdef || '; strict=' || p.proisstrict
           || '; config=' || coalesce(p.proconfig::text, '-') || '; src_md5=' || md5(p.prosrc) || '; acl=' || coalesce(p.proacl::text, '-')
      INTO v FROM pg_proc p WHERE p.oid = to_regprocedure(r.sig);
    IF v IS DISTINCT FROM r.expected THEN
      RAISE EXCEPTION 'stopped: % differs from the identity recorded by the B-04a VERIFY run. Live: %', r.sig, v;
    END IF;
  END LOOP;
  SELECT pg_get_indexdef(x.indexrelid) || '|' || x.indisunique || '|' || x.indisvalid || '|' || x.indisready INTO v
    FROM pg_index x WHERE x.indexrelid = to_regclass('public.disciplines_normalized_name_uidx');
  IF v IS DISTINCT FROM 'CREATE UNIQUE INDEX disciplines_normalized_name_uidx ON public.disciplines USING btree (normalize_course_text(name))|true|true|true' THEN
    RAISE EXCEPTION 'stopped: the B-02a unique index differs from the recorded one. Live: %', v;
  END IF;
  SELECT pg_get_constraintdef(c.oid) || '|' || c.convalidated INTO v FROM pg_constraint c WHERE c.conrelid = 'public.subjects'::regclass AND c.conname = 'subjects_discipline_id_id_key';
  IF v IS DISTINCT FROM 'UNIQUE (discipline_id, id)|true' THEN
    RAISE EXCEPTION 'stopped: the B-04a unique pair on subjects differs from the recorded one. Live: %', coalesce(v, '(missing)');
  END IF;
  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attname) INTO v FROM pg_attribute a
    WHERE a.attrelid = 'public.study_sessions'::regclass AND NOT a.attisdropped AND a.attnum > 0 AND a.attname IN ('classification', 'created_at', 'custom_course_key', 'custom_course_label', 'custom_subject_key', 'custom_subject_label', 'id', 'user_id');
  IF v IS DISTINCT FROM 'classification:text,created_at:timestamp with time zone,custom_course_key:text,custom_course_label:text,custom_subject_key:text,custom_subject_label:text,id:uuid,user_id:uuid' THEN
    RAISE EXCEPTION 'stopped: the columns of study_sessions that B-06a reads differ from the recorded ones. Live: %', v;
  END IF;
  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attname) INTO v FROM pg_attribute a
    WHERE a.attrelid = 'public.disciplines'::regclass AND NOT a.attisdropped AND a.attnum > 0 AND a.attname IN ('id', 'is_active', 'name', 'order_num');
  IF v IS DISTINCT FROM 'id:uuid,is_active:boolean,name:text,order_num:integer' THEN
    RAISE EXCEPTION 'stopped: the columns of disciplines that B-06a reads differ from the recorded ones. Live: %', v;
  END IF;
  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attname) INTO v FROM pg_attribute a
    WHERE a.attrelid = 'public.subjects'::regclass AND NOT a.attisdropped AND a.attnum > 0 AND a.attname IN ('discipline_id', 'id', 'is_active', 'name', 'order_num');
  IF v IS DISTINCT FROM 'discipline_id:uuid,id:uuid,is_active:boolean,name:text,order_num:integer' THEN
    RAISE EXCEPTION 'stopped: the columns of subjects that B-06a reads differ from the recorded ones. Live: %', v;
  END IF;
  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attname) INTO v FROM pg_attribute a
    WHERE a.attrelid = 'public.profiles'::regclass AND NOT a.attisdropped AND a.attnum > 0 AND a.attname IN ('course_level', 'id');
  IF v IS DISTINCT FROM 'course_level:text,id:uuid' THEN
    RAISE EXCEPTION 'stopped: the columns of profiles that B-06a reads differ from the recorded ones. Live: %', v;
  END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname IN ('fn_course_options_core', 'get_course_options_public', 'get_course_options', 'get_picker_subjects')) <> 0 THEN
    RAISE EXCEPTION 'stopped: one of the four B-06a function names already exists (any overload)';
  END IF;
  IF to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION 'stopped: auth.uid() does not exist';
  END IF;
END
$guard$;

CREATE FUNCTION public.fn_course_options_core(p_surface text, p_user_id uuid)
RETURNS TABLE(kind text, "position" integer, label text, discipline_id uuid, is_active boolean, is_current boolean, is_catalogue boolean, is_prior_custom boolean, custom_course_key text, last_used_at timestamp with time zone, action text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
#variable_conflict use_column
DECLARE
  v_cur_label text;
  v_cur_norm  text;
BEGIN
  IF p_surface IS NULL OR p_surface NOT IN ('signup', 'profile', 'access', 'picker') THEN
    RAISE EXCEPTION 'unknown surface' USING ERRCODE = '22023';
  END IF;
  IF p_surface = 'signup' THEN
    p_user_id := NULL;
  ELSIF p_user_id IS NULL THEN
    RAISE EXCEPTION 'a user is required for this surface' USING ERRCODE = '22023';
  END IF;

  -- the caller's current course: trimmed; a blank value or a value over 120 characters is not offered (brief B 5.4)
  IF p_user_id IS NOT NULL THEN
    SELECT pg_catalog.btrim(pr.course_level) INTO v_cur_label FROM public.profiles pr WHERE pr.id = p_user_id;
    IF v_cur_label IS NULL OR v_cur_label = '' OR pg_catalog.char_length(v_cur_label) > 120 THEN
      v_cur_label := NULL;
    END IF;
  END IF;
  v_cur_norm := public.normalize_course_text(v_cur_label);

  RETURN QUERY
  WITH plat AS (
    SELECT d.id AS did, d.name AS dname, d.is_active AS dactive, COALESCE(d.order_num, 0) AS onum, public.normalize_course_text(d.name) AS nn
      FROM public.disciplines d
  ), cat AS (
    SELECT c.label AS clabel, c.ord AS cord, public.normalize_course_text(c.label) AS nn
      FROM unnest(public.course_catalogue_labels()) WITH ORDINALITY AS c(label, ord)
  ), used AS (
    SELECT ss.custom_course_key AS k, max(ss.created_at) AS last_at,
           (array_agg(ss.custom_course_label ORDER BY ss.created_at DESC NULLS LAST, ss.id DESC))[1] AS disp
      FROM public.study_sessions ss
     WHERE p_user_id IS NOT NULL AND ss.user_id = p_user_id AND ss.classification = 'custom' AND ss.custom_course_key IS NOT NULL
     GROUP BY ss.custom_course_key
  ), rws AS (
    SELECT CASE WHEN p_surface = 'picker' THEN (CASE WHEN COALESCE(p.nn = v_cur_norm, false) THEN 1 ELSE 2 END)
                WHEN p.dactive THEN 1 ELSE 3 END AS g,
           p.onum::numeric AS o1, p.dname AS o2, 'platform'::text AS rkind, p.dname AS rlabel, p.did AS rdid, p.dactive AS ractive,
           COALESCE(p.nn = v_cur_norm, false) AS rcur, false AS rcat, false AS rprior, NULL::text AS rkey, NULL::timestamp with time zone AS rlast, NULL::text AS ract
      FROM plat p
     WHERE p.dactive OR COALESCE(p.nn = v_cur_norm, false)
    UNION ALL
    SELECT CASE WHEN p_surface = 'picker' THEN (CASE WHEN COALESCE(c.nn = v_cur_norm, false) THEN 1 ELSE 3 END) ELSE 2 END,
           CASE WHEN p_surface = 'picker' AND NOT COALESCE(c.nn = v_cur_norm, false) THEN -extract(epoch FROM u.last_at)::numeric ELSE c.cord::numeric END,
           c.clabel,
           CASE WHEN COALESCE(c.nn = v_cur_norm, false) THEN 'current' ELSE 'catalogue' END, c.clabel, NULL::uuid, NULL::boolean,
           COALESCE(c.nn = v_cur_norm, false), true, u.k IS NOT NULL, c.nn, u.last_at, NULL::text
      FROM cat c LEFT JOIN used u ON u.k = c.nn
     WHERE p_surface <> 'picker' OR COALESCE(c.nn = v_cur_norm, false) OR u.k IS NOT NULL
    UNION ALL
    SELECT CASE WHEN p_surface = 'picker' THEN 1 ELSE 3 END, 0::numeric, v_cur_label, 'current', v_cur_label, NULL::uuid, NULL::boolean,
           true, false, u.k IS NOT NULL, v_cur_norm, u.last_at, NULL::text
      FROM (SELECT 1) one LEFT JOIN used u ON u.k = v_cur_norm
     WHERE v_cur_label IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM plat p WHERE p.nn = v_cur_norm) AND NOT EXISTS (SELECT 1 FROM cat c WHERE c.nn = v_cur_norm)
    UNION ALL
    SELECT 3, -extract(epoch FROM u.last_at)::numeric, u.k, 'prior_custom', u.disp, NULL::uuid, NULL::boolean,
           false, false, true, u.k, u.last_at, NULL::text
      FROM used u
     WHERE p_surface = 'picker'
       AND NOT EXISTS (SELECT 1 FROM plat p WHERE p.nn = u.k) AND NOT EXISTS (SELECT 1 FROM cat c WHERE c.nn = u.k) AND u.k IS DISTINCT FROM v_cur_norm
    UNION ALL
    SELECT 4, 0::numeric, '', 'general', 'General', NULL::uuid, NULL::boolean, false, false, false, NULL::text, NULL::timestamp with time zone, 'write_general'
     WHERE p_surface = 'picker'
    UNION ALL
    SELECT CASE WHEN p_surface = 'picker' THEN 5 ELSE 4 END, 0::numeric, '', 'other_action',
           CASE WHEN p_surface = 'picker' THEN 'Other...' ELSE 'Other, type your own' END, NULL::uuid, NULL::boolean, false, false, false, NULL::text, NULL::timestamp with time zone, 'enter_text'
  ), lim AS (
    SELECT r.*, row_number() OVER (PARTITION BY r.g ORDER BY r.o1, r.o2) AS rn FROM rws r
  )
  SELECT l.rkind, (row_number() OVER (ORDER BY l.g, l.o1, l.o2))::integer, l.rlabel, l.rdid, l.ractive, l.rcur, l.rcat, l.rprior, l.rkey, l.rlast, l.ract
    FROM lim l
   WHERE NOT (p_surface = 'picker' AND l.g = 3 AND l.rn > 10)
   ORDER BY 2;
END;
$function$;

CREATE FUNCTION public.get_course_options_public()
RETURNS TABLE(kind text, "position" integer, label text, discipline_id uuid, is_active boolean, is_current boolean, is_catalogue boolean, is_prior_custom boolean, custom_course_key text, last_used_at timestamp with time zone, action text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  RETURN QUERY SELECT * FROM public.fn_course_options_core('signup', NULL::uuid);
END;
$function$;

CREATE FUNCTION public.get_course_options(p_surface text)
RETURNS TABLE(kind text, "position" integer, label text, discipline_id uuid, is_active boolean, is_current boolean, is_catalogue boolean, is_prior_custom boolean, custom_course_key text, last_used_at timestamp with time zone, action text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_surface IS NULL OR p_surface NOT IN ('profile', 'access', 'picker') THEN
    RAISE EXCEPTION 'unknown surface' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY SELECT * FROM public.fn_course_options_core(p_surface, v_uid);
END;
$function$;

CREATE FUNCTION public.get_picker_subjects(p_discipline_id uuid DEFAULT NULL, p_course_key text DEFAULT NULL)
RETURNS TABLE(kind text, subject_id uuid, label text, "position" integer, last_used_at timestamp with time zone, action text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
#variable_conflict use_column
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000';
  END IF;
  IF (p_discipline_id IS NULL) = (p_course_key IS NULL) THEN
    RAISE EXCEPTION 'exactly one of p_discipline_id and p_course_key must be given' USING ERRCODE = '22023';
  END IF;

  IF p_discipline_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.disciplines d WHERE d.id = p_discipline_id) THEN
      RAISE EXCEPTION 'unknown discipline' USING ERRCODE = '22023';
    END IF;
    RETURN QUERY
    SELECT x.xkind, x.xid, x.xlabel, (row_number() OVER (ORDER BY x.g, x.o1, x.o2))::integer, NULL::timestamp with time zone, x.xact
      FROM (SELECT 1 AS g, COALESCE(s.order_num, 0)::numeric AS o1, s.name AS o2, 'subject'::text AS xkind, s.id AS xid, s.name AS xlabel, NULL::text AS xact
              FROM public.subjects s WHERE s.discipline_id = p_discipline_id AND s.is_active
            UNION ALL
            SELECT 2, 0::numeric, '', 'skip', NULL::uuid, 'Skip', 'skip') x
     ORDER BY 4;
  ELSE
    IF pg_catalog.btrim(p_course_key) = '' OR pg_catalog.char_length(p_course_key) > 120 THEN
      RAISE EXCEPTION 'invalid course key' USING ERRCODE = '22023';
    END IF;
    RETURN QUERY
    WITH used AS (
      SELECT ss.custom_subject_key AS k, max(ss.created_at) AS last_at,
             (array_agg(ss.custom_subject_label ORDER BY ss.created_at DESC NULLS LAST, ss.id DESC))[1] AS disp
        FROM public.study_sessions ss
       WHERE ss.user_id = v_uid AND ss.classification = 'custom' AND ss.custom_course_key = p_course_key AND ss.custom_subject_key IS NOT NULL
       GROUP BY ss.custom_subject_key
    ), top AS (
      SELECT u.k, u.last_at, u.disp FROM used u ORDER BY u.last_at DESC NULLS LAST, u.k LIMIT 10
    )
    SELECT x.xkind, NULL::uuid, x.xlabel, (row_number() OVER (ORDER BY x.g, x.o1, x.o2))::integer, x.xlast, x.xact
      FROM (SELECT 1 AS g, -extract(epoch FROM t.last_at)::numeric AS o1, t.k AS o2, 'prior_custom_subject'::text AS xkind, t.disp AS xlabel, t.last_at AS xlast, NULL::text AS xact FROM top t
            UNION ALL
            SELECT 2, 0::numeric, '', 'other_action', 'Other, type your own', NULL::timestamp with time zone, 'enter_text'
            UNION ALL
            SELECT 3, 0::numeric, '', 'skip', 'Skip', NULL::timestamp with time zone, 'skip') x
     ORDER BY 4;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_course_options_core(text, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_course_options_public() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_course_options_public() TO anon, authenticated;
REVOKE ALL ON FUNCTION public.get_course_options(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_course_options(text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_picker_subjects(uuid, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_picker_subjects(uuid, text) TO authenticated;

DO $postcheck$
DECLARE
  v text;
  r record;
BEGIN
  FOR r IN SELECT x.k, x.sig, x.exp_md5, x.exp_priv FROM (VALUES
    ('core', 'public.fn_course_options_core(text, uuid)', '24cab463b4e050e0608cd8bb68c6cab4', 'FFF'),
    ('pub', 'public.get_course_options_public()', '57f136c64a2b4c24884566a9052f3660', 'TTF'),
    ('auth', 'public.get_course_options(text)', '6bbd4debe463cf4a85f53b5830564af7', 'FTF'),
    ('subj', 'public.get_picker_subjects(uuid, text)', '1ef9562cc2a7792372fc6070b1a28c60', 'FTF')
  ) AS x(k, sig, exp_md5, exp_priv) LOOP
    SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; volatility=' || p.provolatile::text || '; config=' || coalesce(p.proconfig::text, '-')
           || '; language=' || (SELECT l.lanname FROM pg_language l WHERE l.oid = p.prolang)
           || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
           || '; no_public_acl=' || NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE a.grantee = 0)
           || '; anon_authenticated_service_role=' || CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
           || CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
           || CASE WHEN has_function_privilege('service_role', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
      INTO v FROM pg_proc p WHERE p.oid = to_regprocedure(r.sig);
    IF v IS DISTINCT FROM 'owner=postgres; secdef=true; volatility=s; config={"search_path=pg_catalog, public"}; language=plpgsql; body_md5_without_carriage_returns=' || r.exp_md5
                          || '; no_public_acl=true; anon_authenticated_service_role=' || r.exp_priv THEN
      RAISE EXCEPTION 'B-06a stopped: % is not as built. Live: %', r.sig, coalesce(v, '(missing)');
    END IF;
  END LOOP;
END
$postcheck$;

SELECT x.fn, x.body_md5_without_carriage_returns, x.anon_authenticated_service_role_execute FROM (VALUES
  ('public.fn_course_options_core(text, uuid)', '24cab463b4e050e0608cd8bb68c6cab4', 'FFF'),
  ('public.get_course_options_public()', '57f136c64a2b4c24884566a9052f3660', 'TTF'),
  ('public.get_course_options(text)', '6bbd4debe463cf4a85f53b5830564af7', 'FTF'),
  ('public.get_picker_subjects(uuid, text)', '1ef9562cc2a7792372fc6070b1a28c60', 'FTF')
) AS x(fn, body_md5_without_carriage_returns, anon_authenticated_service_role_execute) ORDER BY x.fn;
