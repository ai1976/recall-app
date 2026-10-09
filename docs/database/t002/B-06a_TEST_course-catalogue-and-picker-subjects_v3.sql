-- Name: [TEST] T-002 B-06a TEST (v3) - verify the course catalogue core, the two course-option readers and the picker subject list (rollback-only)
--
-- v3 (B-06a Gate 4 run of v2 `32bdcab20bd3`, 09/10/2026: 9 of 10 checks true; the overlap check was false because of a TEST defect, not a function defect): the shape helper looked up the discipline id of each platform row AFTER the fixture sub-transaction had been rolled back, so the fixture discipline of the overlap cases was not found. The executor now returns the name-to-id map of the disciplines read inside the sub-transaction and the shape helper compares against that map. No other check changed.
-- Description: Verification for B-06a_FUNCTIONS_course-catalogue-and-picker-subjects_v1.sql, run AFTER it. Sets transaction-local lock_timeout 5 s and statement_timeout 30 s first. Persists nothing: temporary
-- functions only; every fixture (a student's course, deactivated discipline or subject, study sessions) lives in a sub-transaction that is rolled back (one sub-transaction per case), and the file proves at
-- the end that study_sessions (rows created before the run started), the course of every profile, disciplines and subjects are what they were. Run the whole file as ONE selection; it returns one row per check
-- with pass true or false, then a summary row (a missing result counts as false). Every check must be true. Stop and report on any false or any SQL error; do not edit and re-run. Concurrency is NOT COVERED: run it
-- at a quiet time; a lock or statement timeout is a stop, not a functional failure.
-- It proves: the four functions as built (body hash, owner, security mode, volatility, search_path, complete EXECUTE ACL, exact anon/authenticated/service_role execute matrix); the projection of each surface
-- (public list as anon and as authenticated; Profile Settings and the access form for a current active course, a current catalogue label, a current custom course, an inactive current course, an over-limit current
-- value, a trimmed current value, a prior-custom flag and a prior catalogue flag; another student's view); the picker (current first, other active platform courses, earlier custom labels most recent first with
-- the display label of the greatest (created_at, id), the ten-label cap, catalogue labels only when current or used before, no other student's text, an over-limit profile value not listed, an inactive current
-- course first and marked, platform sessions creating no custom label); the row shape of every result (positions, discipline_id and is_active only on platform rows, the server-computed key, action values, no
-- overlay from the public list); the denials (anon cannot reach the core, the authenticated reader or the subject list; authenticated cannot reach the core; no session raises 28000; an unknown surface 22023); and
-- get_picker_subjects (both, neither, unknown and blank/over-long arguments; active subjects only; an inactive discipline; the key path with tie-break, cap, Other and Skip, no other student's text).
-- Fixtures use the real tables as the owner; study sessions are inserted through the real guard trigger. Fixture contract: the profile course guard trigger of that one case's sub-transaction is disabled to
-- store legacy-shaped values (over-limit), bounded by the timeouts above and restored by the rollback.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION pg_temp.b06a_course(p_t text, p_tag text) RETURNS text LANGUAGE sql AS $h$
  SELECT CASE WHEN p_t IS NULL THEN NULL WHEN p_t = '%OVERLONG%' THEN repeat('Z', 121) ELSE replace(p_t, '%T%', p_tag) END
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_j(VARIADIC p text[]) RETURNS text LANGUAGE sql AS $h$
  SELECT array_to_string(array_remove(array_remove(p, NULL), ''), ';')
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_s(p_l text, p_m integer, p_sub text DEFAULT NULL, p_u text DEFAULT 'A', p_id text DEFAULT NULL, p_k text DEFAULT 'custom') RETURNS jsonb LANGUAGE sql AS $h$
  SELECT jsonb_strip_nulls(jsonb_build_object('l', p_l, 'm', p_m, 'sub', p_sub, 'u', p_u, 'id', p_id, 'k', p_k))
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_ep(p_cur text, p_skip uuid[]) RETURNS text LANGUAGE sql AS $h$
  SELECT coalesce(string_agg('platform|' || d.name || '|' || CASE WHEN p_cur IS NOT NULL AND public.normalize_course_text(d.name) = public.normalize_course_text(p_cur) THEN 'c' ELSE '' END,
                             ';' ORDER BY coalesce(d.order_num, 0), d.name), '')
    FROM public.disciplines d WHERE d.is_active AND NOT (d.id = ANY (p_skip))
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_ec(p_cur text, p_prior text[]) RETURNS text LANGUAGE sql AS $h$
  SELECT string_agg(CASE WHEN p_cur IS NOT NULL AND q.n = public.normalize_course_text(p_cur) THEN 'current' ELSE 'catalogue' END || '|' || q.l || '|'
                    || CASE WHEN p_cur IS NOT NULL AND q.n = public.normalize_course_text(p_cur) THEN 'c' ELSE '' END || 'k' || CASE WHEN q.n = ANY (p_prior) THEN 'p' ELSE '' END, ';' ORDER BY q.o)
    FROM (SELECT c.l, c.o, public.normalize_course_text(c.l) AS n FROM unnest(public.course_catalogue_labels()) WITH ORDINALITY AS c(l, o)) q
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_tok(p_rows jsonb) RETURNS text LANGUAGE sql AS $h$
  SELECT string_agg((e->>'kind') || '|' || (e->>'label') || '|'
                    || CASE WHEN (e->>'is_current')::boolean THEN 'c' ELSE '' END || CASE WHEN (e->>'is_catalogue')::boolean THEN 'k' ELSE '' END
                    || CASE WHEN (e->>'is_prior_custom')::boolean THEN 'p' ELSE '' END || CASE WHEN (e->>'is_active')::boolean IS FALSE THEN 'x' ELSE '' END, ';' ORDER BY (e->>'position')::integer)
    FROM jsonb_array_elements(p_rows) e
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_stok(p_rows jsonb) RETURNS text LANGUAGE sql AS $h$
  SELECT string_agg((e->>'kind') || '|' || (e->>'label') || '|' || coalesce(e->>'subject_id', ''), ';' ORDER BY (e->>'position')::integer)
    FROM jsonb_array_elements(p_rows) e
$h$;

-- row-shape rules shared by every course-option result (plan v18 section 8, row shape table)
CREATE OR REPLACE FUNCTION pg_temp.b06a_shape(p_rows jsonb, p_public boolean, p_dids jsonb) RETURNS text LANGUAGE plpgsql AS $h$
DECLARE
  e jsonb; i integer; v text := ''; v_other integer := 0; v_n integer := jsonb_array_length(p_rows);
BEGIN
  FOR e, i IN SELECT x, ord::integer FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS t(x, ord) LOOP
    IF (e->>'position')::integer <> i THEN v := v || 'position ' || i || '; '; END IF;
    IF (e->>'kind' = 'platform') <> (e->>'discipline_id' IS NOT NULL) OR (e->>'kind' = 'platform') <> (e->>'is_active' IS NOT NULL) THEN v := v || 'discipline/is_active at ' || i || '; '; END IF;
    IF e->>'kind' = 'platform' AND e->>'discipline_id' IS DISTINCT FROM (p_dids->>(e->>'label')) THEN v := v || 'wrong discipline_id at ' || i || '; '; END IF;
    IF e->>'kind' <> 'platform' AND ((e->>'is_prior_custom')::boolean) <> (e->>'last_used_at' IS NOT NULL) THEN v := v || 'last_used_at/prior flag at ' || i || '; '; END IF;
    IF e->>'kind' IN ('current', 'catalogue', 'prior_custom') THEN
      IF e->>'custom_course_key' IS DISTINCT FROM public.normalize_course_text(e->>'label') THEN v := v || 'key at ' || i || '; '; END IF;
      IF e->>'action' IS NOT NULL THEN v := v || 'action on choice row ' || i || '; '; END IF;
    ELSIF e->>'kind' = 'platform' THEN
      IF e->>'custom_course_key' IS NOT NULL OR e->>'action' IS NOT NULL THEN v := v || 'platform key/action at ' || i || '; '; END IF;
    ELSIF e->>'kind' = 'other_action' THEN
      v_other := v_other + 1;
      IF e->>'action' IS DISTINCT FROM 'enter_text' OR e->>'custom_course_key' IS NOT NULL THEN v := v || 'other_action at ' || i || '; '; END IF;
    ELSIF e->>'kind' = 'general' THEN
      IF p_public OR e->>'action' IS DISTINCT FROM 'write_general' THEN v := v || 'general at ' || i || '; '; END IF;
    ELSE
      v := v || 'unknown kind at ' || i || '; ';
    END IF;
    IF p_public AND ((e->>'is_current')::boolean OR (e->>'is_prior_custom')::boolean OR e->>'last_used_at' IS NOT NULL OR e->>'kind' IN ('current', 'prior_custom')) THEN v := v || 'overlay in the public list at ' || i || '; '; END IF;
  END LOOP;
  IF v_other <> 1 THEN v := v || 'other_action count ' || v_other || '; '; END IF;
  IF v_n = 0 THEN v := v || 'empty; '; END IF;
  RETURN v;
END;
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_cmp(p_name text, p_res jsonb, p_exp text, p_public boolean) RETURNS text LANGUAGE plpgsql AS $h$
DECLARE v_got text; v_shape text;
BEGIN
  IF p_res->>'err' IS NOT NULL THEN RETURN p_name || ' error ' || (p_res->>'err') || '; '; END IF;
  v_got := pg_temp.b06a_tok(p_res->'rows');
  IF v_got IS DISTINCT FROM p_exp THEN RETURN p_name || ' got [' || coalesce(v_got, 'NULL') || '] expected [' || coalesce(p_exp, 'NULL') || ']; '; END IF;
  v_shape := pg_temp.b06a_shape(p_res->'rows', p_public, p_res->'dids');
  IF v_shape <> '' THEN RETURN p_name || ' shape: ' || v_shape; END IF;
  RETURN '';
END;
$h$;

-- the executor: one sub-transaction per call, fixtures as the owner, the call as the real role, always rolled back
CREATE OR REPLACE FUNCTION pg_temp.b06a_run(p_fix jsonb, p_ua uuid, p_ub uuid, p_d1 uuid, p_s1 uuid, p_tag text) RETURNS jsonb LANGUAGE plpgsql AS $h$
DECLARE
  v_who  uuid := CASE p_fix->>'who' WHEN 'B' THEN p_ub ELSE p_ua END;
  v_call text := p_fix->>'call';
  v_role text := CASE WHEN p_fix->>'role' = 'anon' THEN 'anon' ELSE 'authenticated' END;
  v_rows jsonb := '[]'::jsonb;
  v_err  text := NULL;
  s      jsonb;
  v_u    uuid;
  v_disc uuid;
  v_key  text;
  v_dids jsonb := '{}'::jsonb;
BEGIN
  BEGIN
    DELETE FROM public.study_sessions WHERE user_id IN (p_ua, p_ub) AND classification IS NOT NULL;
    EXECUTE 'ALTER TABLE public.profiles DISABLE TRIGGER trg_profiles_course_label_guard';
    IF p_fix ? 'courseA' THEN UPDATE public.profiles SET course_level = pg_temp.b06a_course(p_fix->>'courseA', p_tag) WHERE id = p_ua; END IF;
    IF p_fix ? 'courseB' THEN UPDATE public.profiles SET course_level = pg_temp.b06a_course(p_fix->>'courseB', p_tag) WHERE id = p_ub; END IF;
    IF p_fix ? 'addDisc' THEN INSERT INTO public.disciplines (name, code, is_active) VALUES (p_fix->>'addDisc', 'ZZ' || p_tag, coalesce((p_fix->>'addActive')::boolean, true)); END IF;
    IF p_fix ? 'deactD1' THEN UPDATE public.disciplines SET is_active = false WHERE id = p_d1; END IF;
    IF p_fix ? 'deactS1' THEN UPDATE public.subjects SET is_active = false WHERE id = p_s1; END IF;
    FOR s IN SELECT x FROM jsonb_array_elements(coalesce(p_fix->'sess', '[]'::jsonb)) AS t(x) LOOP
      v_u := CASE s->>'u' WHEN 'B' THEN p_ub ELSE p_ua END;
      IF s->>'k' = 'platform' THEN
        INSERT INTO public.study_sessions (id, user_id, started_at, ended_at, duration_seconds, session_date, source, category, classification, discipline_id, created_at)
        VALUES (coalesce((s->>'id')::uuid, gen_random_uuid()), v_u, now() - interval '3 hours', now() - interval '2 hours', 3600, current_date, 'manual', 'reading', 'platform', p_d1,
                now() - make_interval(mins => (s->>'m')::integer));
      ELSE
        INSERT INTO public.study_sessions (id, user_id, started_at, ended_at, duration_seconds, session_date, source, category, classification, custom_course_label, custom_subject_label, created_at)
        VALUES (coalesce((s->>'id')::uuid, gen_random_uuid()), v_u, now() - interval '3 hours', now() - interval '2 hours', 3600, current_date, 'manual', 'reading', 'custom',
                replace(s->>'l', '%T%', p_tag), CASE WHEN s ? 'sub' THEN replace(s->>'sub', '%T%', p_tag) END, now() - make_interval(mins => (s->>'m')::integer));
      END IF;
    END LOOP;
    BEGIN
      IF coalesce((p_fix->>'noauth')::boolean, false) THEN
        PERFORM set_config('request.jwt.claims', '', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
      ELSIF v_role = 'authenticated' THEN
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_who, 'role', 'authenticated')::text, true);
        PERFORM set_config('request.jwt.claim.sub', v_who::text, true);
      ELSE
        PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
      END IF;
      EXECUTE 'SET LOCAL ROLE ' || v_role;
      IF v_call = 'public' THEN
        SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t."position"), '[]'::jsonb) INTO v_rows FROM public.get_course_options_public() t;
      ELSIF v_call = 'core' THEN
        SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t."position"), '[]'::jsonb) INTO v_rows FROM public.fn_course_options_core('profile', v_who) t;
      ELSIF v_call IN ('profile', 'access', 'picker', 'signup', 'bogus') THEN
        SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t."position"), '[]'::jsonb) INTO v_rows FROM public.get_course_options(v_call) t;
      ELSIF v_call = 'nullsurface' THEN
        SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t."position"), '[]'::jsonb) INTO v_rows FROM public.get_course_options(NULL) t;
      ELSIF v_call = 'subjects' THEN
        v_disc := CASE p_fix->>'disc' WHEN 'D1' THEN p_d1 WHEN 'RANDOM' THEN gen_random_uuid() ELSE NULL END;
        v_key := CASE WHEN p_fix ? 'key' THEN replace(p_fix->>'key', '%T%', p_tag) ELSE NULL END;
        SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t."position"), '[]'::jsonb) INTO v_rows FROM public.get_picker_subjects(v_disc, v_key) t;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_err := SQLSTATE;
      RESET ROLE;
    END;
    RESET ROLE;
    SELECT coalesce(jsonb_object_agg(d.name, d.id), '{}'::jsonb) INTO v_dids FROM public.disciplines d;
    RAISE EXCEPTION 'b06a_rollback_marker';
  EXCEPTION
    WHEN raise_exception THEN
      RESET ROLE;
      IF SQLERRM <> 'b06a_rollback_marker' THEN v_err := 'fixture:' || SQLERRM; END IF;
    WHEN OTHERS THEN
      RESET ROLE;
      v_err := 'setup:' || SQLSTATE || ':' || SQLERRM;
  END;
  RETURN jsonb_build_object('rows', v_rows, 'err', v_err, 'dids', v_dids);
END;
$h$;

CREATE OR REPLACE FUNCTION pg_temp.b06a_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_t0    timestamp with time zone := clock_timestamp();
  v_ua    uuid;
  v_ub    uuid;
  v_d1    uuid;
  v_d2    uuid;
  v_n1    text;
  v_n2    text;
  v_s1    uuid;
  v_tag   text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_cat   text[] := public.course_catalogue_labels();
  v_ss0   text;
  v_pr0   text;
  v_di0   text;
  v_su0   text;
  v_cl0   integer;
  v_bad   text;
  r       jsonb;
  r2      jsonb;
  v_exp   text;
  v_i     integer;
  v_ids   text[];
  v_g1    uuid := gen_random_uuid();
  v_g2    uuid := gen_random_uuid();
  v_sess  jsonb;
  v_subj  text;
BEGIN
  SELECT count(*)::text || ':' || md5(coalesce(string_agg(to_jsonb(x)::text, '|' ORDER BY x.id), '')) INTO v_ss0 FROM public.study_sessions x WHERE x.created_at < v_t0;
  SELECT count(*)::text || ':' || md5(coalesce(string_agg(x.id::text || '=' || coalesce(x.course_level, '~'), '|' ORDER BY x.id), '')) INTO v_pr0 FROM public.profiles x;
  SELECT count(*)::text || ':' || md5(coalesce(string_agg(to_jsonb(x)::text, '|' ORDER BY x.id), '')) INTO v_di0 FROM public.disciplines x;
  SELECT count(*)::text || ':' || md5(coalesce(string_agg(to_jsonb(x)::text, '|' ORDER BY x.id), '')) INTO v_su0 FROM public.subjects x;
  v_ids := ARRAY[least(v_g1, v_g2)::text, greatest(v_g1, v_g2)::text];
  SELECT id INTO v_ua FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT id INTO v_ub FROM public.profiles WHERE role = 'student' AND id <> v_ua ORDER BY id LIMIT 1;
  SELECT count(*) INTO v_cl0 FROM public.study_sessions WHERE classification IS NOT NULL AND user_id IN (v_ua, v_ub);
  SELECT d.id, d.name INTO v_d1, v_n1 FROM public.disciplines d
   WHERE d.is_active AND (SELECT count(*) FROM public.subjects s WHERE s.discipline_id = d.id AND s.is_active) >= 2 ORDER BY coalesce(d.order_num, 0), d.name LIMIT 1;
  SELECT d.id, d.name INTO v_d2, v_n2 FROM public.disciplines d WHERE d.is_active AND d.id <> v_d1 ORDER BY coalesce(d.order_num, 0), d.name LIMIT 1;
  SELECT s.id INTO v_s1 FROM public.subjects s WHERE s.discipline_id = v_d1 AND s.is_active ORDER BY coalesce(s.order_num, 0), s.name LIMIT 1;

  check_name := 'setup: two students, two active disciplines (the first with two active subjects), the six catalogue labels; baselines recorded';
  pass := v_ua IS NOT NULL AND v_ub IS NOT NULL AND v_d1 IS NOT NULL AND v_d2 IS NOT NULL AND v_s1 IS NOT NULL AND v_cat = ARRAY['CMA Foundation', 'CMA Intermediate', 'CMA Final', 'CS Foundation', 'CS Executive', 'CS Professional']
      AND (SELECT count(*) FROM public.study_sessions WHERE classification IS NOT NULL AND user_id IN (v_ua, v_ub)) >= 0;
  detail := 'disciplines ' || v_n1 || ', ' || v_n2 || '; fixture tag ' || v_tag; RETURN NEXT;

  check_name := 'functions: the four B-06a functions as built (owner, SECURITY DEFINER, STABLE, search_path, language, body hash, the COMPLETE EXECUTE ACL (every grantee), exact execute matrix anon/authenticated/service_role)';
  v_bad := '';
  FOR r IN SELECT jsonb_build_object('sig', x.sig, 'md5', x.md, 'priv', x.pr, 'acl', x.ac) FROM (VALUES
      ('public.fn_course_options_core(text, uuid)', '2f23c1c89c0592d1133d2d048d0e3e9b', 'FFF', 'postgres:EXECUTE:false'),
      ('public.get_course_options_public()', '57f136c64a2b4c24884566a9052f3660', 'TTF', 'anon:EXECUTE:false;authenticated:EXECUTE:false;postgres:EXECUTE:false'),
      ('public.get_course_options(text)', '6bbd4debe463cf4a85f53b5830564af7', 'FTF', 'authenticated:EXECUTE:false;postgres:EXECUTE:false'),
      ('public.get_picker_subjects(uuid, text)', 'ae6d158258af287d4008aaa8a1e13203', 'FTF', 'authenticated:EXECUTE:false;postgres:EXECUTE:false')) AS x(sig, md, pr, ac) LOOP
    SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; volatility=' || p.provolatile::text || '; config=' || coalesce(p.proconfig::text, '-')
           || '; language=' || (SELECT l.lanname FROM pg_language l WHERE l.oid = p.prolang) || '; body=' || md5(replace(p.prosrc, chr(13), ''))
           || '; acl=' || coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type || ':' || a.is_grantable::text, ';'
                                      ORDER BY CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END COLLATE "C", a.privilege_type)
                                      FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a), '(none)')
           || '; priv=' || CASE WHEN has_function_privilege('anon', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END || CASE WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
           || CASE WHEN has_function_privilege('service_role', p.oid, 'EXECUTE') THEN 'T' ELSE 'F' END
      INTO v_exp FROM pg_proc p WHERE p.oid = to_regprocedure(r->>'sig');
    IF v_exp IS DISTINCT FROM 'owner=postgres; secdef=true; volatility=s; config={"search_path=pg_catalog, public"}; language=plpgsql; body=' || (r->>'md5') || '; acl=' || (r->>'acl') || '; priv=' || (r->>'priv') THEN
      v_bad := v_bad || (r->>'sig') || ' -> ' || coalesce(v_exp, 'missing') || '; ';
    END IF;
  END LOOP;
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'public list: as anon and as authenticated, the base list (active platform courses, the six catalogue labels, Other), no overlay, no General, positions 1..n';
  v_bad := '';
  v_exp := pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'other_action|Other, type your own|');
  r := pg_temp.b06a_run(jsonb_build_object('call', 'public', 'role', 'anon'), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('anon', r, v_exp, true);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'public', 'who', 'A', 'courseA', v_n1), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('authenticated with a current course (still no overlay)', r, v_exp, true);
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'Profile Settings: current active course, current catalogue label, current custom course, trimmed current value, over-limit and empty current value, prior-custom and prior-catalogue flags';
  v_bad := '';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', v_n1), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F1 current active platform', r, pg_temp.b06a_j(pg_temp.b06a_ep(v_n1, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', v_cat[3]), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F2 current catalogue label', r, pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(v_cat[3], ARRAY[]::text[]), 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', 'ZZ Custom %T%'), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F3 current custom course', r, pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'current|ZZ Custom ' || v_tag || '|c', 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', v_n1, 'deactD1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F4 current inactive platform course', r, pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[v_d1]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'platform|' || v_n1 || '|cx', 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', '%OVERLONG%'), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F5 over-limit current value is not listed', r, pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', '   ZZ Custom %T%   '), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F6 current value with outer spaces is trimmed', r, pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'current|ZZ Custom ' || v_tag || '|c', 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', NULL::text), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F7 no current course', r, pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', 'ZZ Custom %T%', 'sess', jsonb_build_array(pg_temp.b06a_s('zz  custom %T%', 5), pg_temp.b06a_s(v_cat[3], 6))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F8 prior-custom flag on the current row and prior flag on a catalogue label', r,
           pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), pg_temp.b06a_ec(NULL, ARRAY[public.normalize_course_text(v_cat[3])]), 'current|ZZ Custom ' || v_tag || '|cp', 'other_action|Other, type your own|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'who', 'B', 'courseA', v_n1, 'courseB', v_n2, 'deactD1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('F9 another student does not get the inactive course', r, pg_temp.b06a_j(pg_temp.b06a_ep(v_n2, ARRAY[v_d1]), pg_temp.b06a_ec(NULL, ARRAY[]::text[]), 'other_action|Other, type your own|'), false);
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'access form: the same projection as Profile Settings for the same student (current custom course, current inactive course)';
  v_bad := '';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'access', 'courseA', 'ZZ Custom %T%'), v_ua, v_ub, v_d1, v_s1, v_tag);
  r2 := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', 'ZZ Custom %T%'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r IS DISTINCT FROM r2 OR r->>'err' IS NOT NULL OR jsonb_array_length(r->'rows') = 0 THEN v_bad := v_bad || 'custom: access differs from profile; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'access', 'courseA', v_n1, 'deactD1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  r2 := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', v_n1, 'deactD1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r IS DISTINCT FROM r2 OR r->>'err' IS NOT NULL OR jsonb_array_length(r->'rows') = 0 THEN v_bad := v_bad || 'inactive: access differs from profile; '; END IF;
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'picker: current first, other active platform courses, earlier custom labels (most recent first, greatest created_at and id, cap of ten), General, Other; catalogue labels only when current or used before; no other student''s text';
  v_bad := '';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', v_n1, 'sess', jsonb_build_array(jsonb_build_object('k', 'platform', 'm', 5))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K1 current platform; a platform session creates no custom label', r,
           pg_temp.b06a_j('platform|' || v_n1 || '|c', pg_temp.b06a_ep(NULL, ARRAY[v_d1]), 'general|General|', 'other_action|Other...|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', v_cat[3]), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K2 current catalogue label comes first, other catalogue labels are absent', r,
           pg_temp.b06a_j('current|' || v_cat[3] || '|ck', pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), 'general|General|', 'other_action|Other...|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', 'ZZ Custom %T%',
        'sess', jsonb_build_array(pg_temp.b06a_s('ZZ Zeta %T%', 30), pg_temp.b06a_s('ZZ Alpha %T%', 10), pg_temp.b06a_s('zz  custom %T%', 5), pg_temp.b06a_s('ZZ Beta %T%', 20, NULL, 'B'))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K3 current custom first (prior flag), earlier labels most recent first, no other student''s label', r,
           pg_temp.b06a_j('current|ZZ Custom ' || v_tag || '|cp', pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), 'prior_custom|ZZ Alpha ' || v_tag || '|p', 'prior_custom|ZZ Zeta ' || v_tag || '|p', 'general|General|', 'other_action|Other...|'), false);
  v_sess := '[]'::jsonb; v_subj := '';
  FOR v_i IN 1..12 LOOP
    v_sess := v_sess || pg_temp.b06a_s('ZZ L' || lpad(v_i::text, 2, '0') || ' %T%', v_i);
    IF v_i <= 10 THEN v_subj := v_subj || ';prior_custom|ZZ L' || lpad(v_i::text, 2, '0') || ' ' || v_tag || '|p'; END IF;
  END LOOP;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', v_n1, 'sess', v_sess), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K4 at most ten earlier custom labels', r,
           'platform|' || v_n1 || '|c' || coalesce(';' || nullif(pg_temp.b06a_ep(NULL, ARRAY[v_d1]), ''), '') || v_subj || ';general|General|;other_action|Other...|', false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', v_n1, 'sess', jsonb_build_array(pg_temp.b06a_s(v_cat[5], 5), pg_temp.b06a_s('ZZ Beta %T%', 3))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K5 a catalogue label used before is offered (flagged), ordered with the other earlier labels', r,
           pg_temp.b06a_j('platform|' || v_n1 || '|c', pg_temp.b06a_ep(NULL, ARRAY[v_d1]), 'prior_custom|ZZ Beta ' || v_tag || '|p', 'catalogue|' || v_cat[5] || '|kp', 'general|General|', 'other_action|Other...|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', '%OVERLONG%', 'sess', jsonb_build_array(pg_temp.b06a_s('ZZ Alias %T%', 2))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K6 over-limit profile value is not offered; the earlier alias is an ordinary earlier label', r,
           pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), 'prior_custom|ZZ Alias ' || v_tag || '|p', 'general|General|', 'other_action|Other...|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', v_n1, 'deactD1', true, 'sess', jsonb_build_array(jsonb_build_object('k', 'platform', 'm', 5))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K7 an inactive current course keeps its place first and is marked', r,
           pg_temp.b06a_j('platform|' || v_n1 || '|cx', pg_temp.b06a_ep(NULL, ARRAY[v_d1]), 'general|General|', 'other_action|Other...|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'who', 'B', 'courseA', v_n1, 'courseB', v_n2, 'deactD1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K8 another student is not offered the inactive course', r,
           pg_temp.b06a_j('platform|' || v_n2 || '|c', pg_temp.b06a_ep(NULL, ARRAY[v_d1, v_d2]), 'general|General|', 'other_action|Other...|'), false);
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', NULL::text), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_bad := v_bad || pg_temp.b06a_cmp('K9 no current course and no history', r,
           pg_temp.b06a_j(pg_temp.b06a_ep(NULL, ARRAY[]::uuid[]), 'general|General|', 'other_action|Other...|'), false);
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'overlap: a discipline whose name is a catalogue label is that platform course, listed once, never also as a catalogue or current row (public list, Profile Settings, picker, active and inactive)';
  v_bad := '';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'public', 'role', 'anon', 'addDisc', v_cat[3]), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'label' = v_cat[3]) <> 1
     OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'label' = v_cat[3] AND e->>'kind' = 'platform' AND (e->>'is_catalogue')::boolean) <> 1
     OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'kind' = 'catalogue') <> 5 OR pg_temp.b06a_shape(r->'rows', true, r->'dids') <> '' THEN
    v_bad := v_bad || 'O1 public list with an active overlapping discipline: ' || coalesce(r->>'err', pg_temp.b06a_tok(r->'rows')) || '; ';
  END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'courseA', v_cat[3], 'addDisc', v_cat[3]), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'label' = v_cat[3]) <> 1
     OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'label' = v_cat[3] AND e->>'kind' = 'platform' AND (e->>'is_current')::boolean AND (e->>'is_catalogue')::boolean) <> 1
     OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'kind' = 'current') <> 0 OR pg_temp.b06a_shape(r->'rows', false, r->'dids') <> '' THEN
    v_bad := v_bad || 'O2 Profile Settings with an active overlapping current course: ' || coalesce(r->>'err', pg_temp.b06a_tok(r->'rows')) || '; ';
  END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'picker', 'courseA', v_cat[3], 'addDisc', v_cat[3], 'addActive', false), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'label' = v_cat[3]) <> 1
     OR (r->'rows'->0->>'label') IS DISTINCT FROM v_cat[3] OR (r->'rows'->0->>'kind') IS DISTINCT FROM 'platform' OR (r->'rows'->0->>'is_active')::boolean OR NOT (r->'rows'->0->>'is_current')::boolean
     OR pg_temp.b06a_shape(r->'rows', false, r->'dids') <> '' THEN
    v_bad := v_bad || 'O3 picker with an inactive overlapping current course: ' || coalesce(r->>'err', pg_temp.b06a_tok(r->'rows')) || '; ';
  END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'who', 'B', 'courseB', v_n2, 'addDisc', v_cat[3], 'addActive', false), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'label' = v_cat[3]) <> 0 OR (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'kind' = 'catalogue') <> 5 THEN
    v_bad := v_bad || 'O4 another student is not offered an inactive overlapping course: ' || coalesce(r->>'err', pg_temp.b06a_tok(r->'rows')) || '; ';
  END IF;
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'denials: anon cannot call the core, the authenticated reader or the subject list; authenticated cannot call the core; no session raises 28000; unknown or NULL surface raises 22023';
  v_bad := '';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'role', 'anon'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '42501' THEN v_bad := v_bad || 'anon reader -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'core', 'role', 'anon'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '42501' THEN v_bad := v_bad || 'anon core -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'role', 'anon', 'disc', 'D1'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '42501' THEN v_bad := v_bad || 'anon subjects -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'core'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '42501' THEN v_bad := v_bad || 'authenticated core -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'profile', 'noauth', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '28000' THEN v_bad := v_bad || 'no session reader -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'noauth', true, 'disc', 'D1'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '28000' THEN v_bad := v_bad || 'no session subjects -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'signup'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'surface signup on the authenticated reader -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'bogus'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'unknown surface -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'nullsurface'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'NULL surface -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'get_picker_subjects: argument matrix, active subjects only, inactive discipline allowed, key path (tie-break by greatest created_at and id, cap of ten, Other, Skip), no other student''s text';
  v_bad := '';
  v_exp := (SELECT string_agg('subject|' || s.name || '|' || s.id::text, ';' ORDER BY coalesce(s.order_num, 0), s.name) FROM public.subjects s WHERE s.discipline_id = v_d1 AND s.is_active) || ';skip|Skip|';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'disc', 'D1'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR pg_temp.b06a_stok(r->'rows') IS DISTINCT FROM v_exp THEN v_bad := v_bad || 'S1 got [' || coalesce(pg_temp.b06a_stok(r->'rows'), 'NULL') || '] ' || coalesce(r->>'err', '') || ' expected [' || v_exp || ']; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'disc', 'D1', 'deactD1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR pg_temp.b06a_stok(r->'rows') IS DISTINCT FROM v_exp THEN v_bad := v_bad || 'S2 inactive discipline: got [' || coalesce(pg_temp.b06a_stok(r->'rows'), 'NULL') || '] ' || coalesce(r->>'err', '') || '; '; END IF;
  v_exp := (SELECT string_agg('subject|' || s.name || '|' || s.id::text, ';' ORDER BY coalesce(s.order_num, 0), s.name) FROM public.subjects s WHERE s.discipline_id = v_d1 AND s.is_active AND s.id <> v_s1) || ';skip|Skip|';
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'disc', 'D1', 'deactS1', true), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR pg_temp.b06a_stok(r->'rows') IS DISTINCT FROM v_exp THEN v_bad := v_bad || 'S3 inactive subject excluded: got [' || coalesce(pg_temp.b06a_stok(r->'rows'), 'NULL') || '] ' || coalesce(r->>'err', '') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'disc', 'D1', 'key', 'x'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'both arguments -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'neither argument -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'disc', 'RANDOM'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'unknown discipline -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'key', '   '), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'blank key -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'key', 'ZZ  Course  %T%'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'unnormalised key -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'key', repeat('k', 121)), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS DISTINCT FROM '22023' THEN v_bad := v_bad || 'over-long key -> ' || coalesce(r->>'err', 'ok') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'key', 'zz course %T%', 'sess', jsonb_build_array(
         pg_temp.b06a_s('ZZ Course %T%', 40, 'ZZ SubA %T%'), pg_temp.b06a_s('ZZ Course %T%', 10, 'zz  suba %T%', 'A', v_ids[1]), pg_temp.b06a_s('ZZ Course %T%', 10, 'ZZ SUBA %T%', 'A', v_ids[2]),
         pg_temp.b06a_s('ZZ Course %T%', 5, 'ZZ SubB %T%'), pg_temp.b06a_s('ZZ Course %T%', 1), pg_temp.b06a_s('ZZ Course %T%', 2, 'ZZ SubOther %T%', 'B'))), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_exp := 'prior_custom_subject|ZZ SubB ' || v_tag || '|;prior_custom_subject|ZZ SUBA ' || v_tag || '|;other_action|Other, type your own|;skip|Skip|';
  IF r->>'err' IS NOT NULL OR pg_temp.b06a_stok(r->'rows') IS DISTINCT FROM v_exp THEN v_bad := v_bad || 'S9 key path: got [' || coalesce(pg_temp.b06a_stok(r->'rows'), 'NULL') || '] ' || coalesce(r->>'err', '') || ' expected [' || v_exp || ']; '; END IF;
  IF r->>'err' IS NULL AND (SELECT count(*) FROM jsonb_array_elements(r->'rows') e WHERE e->>'kind' = 'prior_custom_subject' AND e->>'last_used_at' IS NULL) <> 0 THEN v_bad := v_bad || 'prior subject without last_used_at; '; END IF;
  v_sess := '[]'::jsonb; v_subj := '';
  FOR v_i IN 1..12 LOOP
    v_sess := v_sess || pg_temp.b06a_s('ZZ Course %T%', v_i, 'ZZ S' || lpad(v_i::text, 2, '0') || ' %T%');
    IF v_i <= 10 THEN v_subj := v_subj || 'prior_custom_subject|ZZ S' || lpad(v_i::text, 2, '0') || ' ' || v_tag || '|;'; END IF;
  END LOOP;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'key', 'zz course %T%', 'sess', v_sess), v_ua, v_ub, v_d1, v_s1, v_tag);
  v_exp := v_subj || 'other_action|Other, type your own|;skip|Skip|';
  IF r->>'err' IS NOT NULL OR pg_temp.b06a_stok(r->'rows') IS DISTINCT FROM v_exp THEN v_bad := v_bad || 'S10 cap of ten: got [' || coalesce(pg_temp.b06a_stok(r->'rows'), 'NULL') || '] ' || coalesce(r->>'err', '') || '; '; END IF;
  r := pg_temp.b06a_run(jsonb_build_object('call', 'subjects', 'key', 'zz nothing %T%'), v_ua, v_ub, v_d1, v_s1, v_tag);
  IF r->>'err' IS NOT NULL OR pg_temp.b06a_stok(r->'rows') IS DISTINCT FROM 'other_action|Other, type your own|;skip|Skip|' THEN v_bad := v_bad || 'S11 unused key: got [' || coalesce(pg_temp.b06a_stok(r->'rows'), 'NULL') || '] ' || coalesce(r->>'err', '') || '; '; END IF;
  pass := v_bad = ''; detail := v_bad; RETURN NEXT;

  check_name := 'live data: study_sessions rows created before the run, every profile course, disciplines and subjects equal the baselines; no fixture row remains';
  pass := (SELECT count(*)::text || ':' || md5(coalesce(string_agg(to_jsonb(x)::text, '|' ORDER BY x.id), '')) FROM public.study_sessions x WHERE x.created_at < v_t0) = v_ss0
      AND (SELECT count(*)::text || ':' || md5(coalesce(string_agg(x.id::text || '=' || coalesce(x.course_level, '~'), '|' ORDER BY x.id), '')) FROM public.profiles x) = v_pr0
      AND (SELECT count(*)::text || ':' || md5(coalesce(string_agg(to_jsonb(x)::text, '|' ORDER BY x.id), '')) FROM public.disciplines x) = v_di0
      AND (SELECT count(*)::text || ':' || md5(coalesce(string_agg(to_jsonb(x)::text, '|' ORDER BY x.id), '')) FROM public.subjects x) = v_su0
      AND NOT EXISTS (SELECT 1 FROM public.disciplines WHERE code = 'ZZ' || v_tag)
      AND (SELECT count(*) FROM public.study_sessions WHERE classification IS NOT NULL AND user_id IN (v_ua, v_ub)) = v_cl0
      AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.profiles'::regclass AND tgname = 'trg_profiles_course_label_guard' AND tgenabled = 'O') = 1;
  detail := v_ss0; RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b06a_results AS SELECT * FROM pg_temp.b06a_checks();

SELECT check_name, pass, detail FROM b06a_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass IS TRUE) FROM b06a_results), (SELECT count(*) || ' checks' FROM b06a_results);
