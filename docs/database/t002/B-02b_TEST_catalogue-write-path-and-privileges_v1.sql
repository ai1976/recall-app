-- Name: [TEST] T-002 B-02b TEST (v1) - verify the catalogue write path and privilege closure (rollback-only)
--
-- Description: Verification for B-02b_SCHEMA_catalogue-write-path-and-privileges_v1.sql, run AFTER it. Persists nothing: one temporary function; every row it inserts or updates lives in
-- a sub-transaction that is rolled back. Run the whole file as ONE selection; it returns one row per check with pass true or false and a final summary row. Every check must be true.
-- Stop and report on any false or any SQL error; do not edit and re-run.
-- Checks: the exact policy set; RLS still enabled; exact table privileges for anon, authenticated and service_role; nobody but the owner can DELETE or TRUNCATE; and REAL-ROLE behaviour:
-- as an actual admin profile (role admin or super_admin, read from profiles) the role authenticated can INSERT a discipline, INSERT and UPDATE a subject and INSERT a topic; as an actual
-- student profile the same writes are refused (RLS 42501); authenticated is refused UPDATE on disciplines and topics, DELETE and TRUNCATE (privilege 42501); a title-cased duplicate
-- discipline is refused by the B-02a unique index even for an admin (23505, the message BulkUploadTopics must show). The role context is set with the JWT claims Supabase uses
-- (request.jwt.claims and request.jwt.claim.sub) and SET LOCAL ROLE authenticated.

CREATE OR REPLACE FUNCTION pg_temp.priv_set(p_role text, p_table text)
RETURNS text
LANGUAGE sql
AS $f$
  SELECT string_agg(p, ',' ORDER BY p)
    FROM unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN']) AS p
   WHERE has_table_privilege(p_role, p_table, p);
$f$;

CREATE OR REPLACE FUNCTION pg_temp.b02b_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_admin   uuid;
  v_student uuid;
  v_ca      uuid;
  v_state   text;
  v_subject uuid;
BEGIN
  SELECT id INTO v_admin FROM public.profiles WHERE role IN ('admin', 'super_admin') ORDER BY role, id LIMIT 1;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT id INTO v_ca FROM public.disciplines WHERE name = 'CA Final';

  check_name := 'setup: an admin profile, a student profile and the CA Final discipline exist';
  pass := v_admin IS NOT NULL AND v_student IS NOT NULL AND v_ca IS NOT NULL;
  detail := ''; RETURN NEXT;

  check_name := 'policies: exactly the expected set (existing five plus the three added), no DELETE policy';
  pass := (SELECT string_agg(tablename || '|' || cmd || '|' || policyname, ';' ORDER BY tablename, cmd, policyname)
             FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('disciplines', 'subjects', 'topics'))
        = 'disciplines|INSERT|admin_insert_disciplines;disciplines|SELECT|Users can read disciplines;subjects|INSERT|admin_insert_subjects;subjects|SELECT|Users can read subjects;subjects|UPDATE|admin_update_subjects;topics|INSERT|admin_insert_topics;topics|SELECT|Users can read topics';
  detail := ''; RETURN NEXT;

  check_name := 'policies: the three new policies are TO authenticated only and call public.is_admin()';
  pass := (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND policyname IN ('admin_insert_subjects', 'admin_update_subjects', 'admin_insert_topics')
              AND roles = '{authenticated}' AND coalesce(with_check, qual) LIKE '%is_admin()%') = 3
      AND (SELECT with_check LIKE '%is_admin()%' AND qual LIKE '%is_admin()%' FROM pg_policies WHERE policyname = 'admin_update_subjects');
  detail := ''; RETURN NEXT;

  check_name := 'rls: still enabled on all three tables';
  pass := (SELECT bool_and(c.relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname IN ('disciplines', 'subjects', 'topics'));
  detail := ''; RETURN NEXT;

  check_name := 'privileges: anon holds SELECT only on all three tables';
  pass := pg_temp.priv_set('anon', 'public.disciplines') = 'SELECT' AND pg_temp.priv_set('anon', 'public.subjects') = 'SELECT' AND pg_temp.priv_set('anon', 'public.topics') = 'SELECT';
  detail := pg_temp.priv_set('anon', 'public.disciplines') || ' / ' || pg_temp.priv_set('anon', 'public.subjects') || ' / ' || pg_temp.priv_set('anon', 'public.topics'); RETURN NEXT;

  check_name := 'privileges: authenticated holds SELECT, INSERT on all three and UPDATE on subjects only (no DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN)';
  pass := pg_temp.priv_set('authenticated', 'public.disciplines') = 'INSERT,SELECT'
      AND pg_temp.priv_set('authenticated', 'public.subjects') = 'INSERT,SELECT,UPDATE'
      AND pg_temp.priv_set('authenticated', 'public.topics') = 'INSERT,SELECT';
  detail := pg_temp.priv_set('authenticated', 'public.disciplines') || ' / ' || pg_temp.priv_set('authenticated', 'public.subjects') || ' / ' || pg_temp.priv_set('authenticated', 'public.topics'); RETURN NEXT;

  check_name := 'privileges: service_role is unchanged (all eight on all three tables)';
  pass := pg_temp.priv_set('service_role', 'public.disciplines') = 'DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE'
      AND pg_temp.priv_set('service_role', 'public.subjects') = 'DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE'
      AND pg_temp.priv_set('service_role', 'public.topics') = 'DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE';
  detail := ''; RETURN NEXT;

  check_name := 'privileges: no PUBLIC grant on any of the three tables';
  pass := NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
                       WHERE n.nspname = 'public' AND c.relname IN ('disciplines', 'subjects', 'topics') AND a.grantee = 0);
  detail := ''; RETURN NEXT;

  -- real role, ADMIN
  check_name := 'real role admin: authenticated INSERTs a discipline, INSERTs and UPDATEs a subject, INSERTs a topic';
  v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('ZZ B02b Course', 'ZZB2'); v_state := v_state || 'discipline-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'discipline-' || SQLSTATE || ';'; END;
    BEGIN INSERT INTO public.subjects (discipline_id, name, is_active, order_num) VALUES (v_ca, 'ZZ B02b Subject', true, 99) RETURNING id INTO v_subject; v_state := v_state || 'subject-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'subject-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.subjects SET order_num = 98 WHERE name = 'ZZ B02b Subject'; IF FOUND THEN v_state := v_state || 'subject-update-ok;'; ELSE v_state := v_state || 'subject-update-0rows;'; END IF; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'subject-update-' || SQLSTATE || ';'; END;
    BEGIN INSERT INTO public.topics (subject_id, name, is_active, order_num) VALUES (v_subject, 'ZZ B02b Topic', true, 1); v_state := v_state || 'topic-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'topic-' || SQLSTATE || ';'; END;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('ca  FINAL', 'ZZB3'); v_state := v_state || 'duplicate-allowed;'; EXCEPTION WHEN unique_violation THEN v_state := v_state || 'duplicate-23505;'; WHEN OTHERS THEN v_state := v_state || 'duplicate-' || SQLSTATE || ';'; END;
    RESET ROLE;
    RAISE EXCEPTION 'b02b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b02b_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'discipline-ok;subject-ok;subject-update-ok;topic-ok;duplicate-23505;'; detail := v_state; RETURN NEXT;

  -- real role, STUDENT
  check_name := 'real role student: every catalogue write is refused (RLS 42501), reads still work';
  v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_student::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN INSERT INTO public.disciplines (name, code) VALUES ('ZZ Student Course', 'ZZS1'); v_state := v_state || 'discipline-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'discipline-refused;'; END;
    BEGIN INSERT INTO public.subjects (discipline_id, name) VALUES (v_ca, 'ZZ Student Subject'); v_state := v_state || 'subject-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'subject-refused;'; END;
    BEGIN UPDATE public.subjects SET order_num = 77; IF FOUND THEN v_state := v_state || 'subject-update-allowed;'; ELSE v_state := v_state || 'subject-update-0rows;'; END IF; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'subject-update-refused;'; END;
    BEGIN INSERT INTO public.topics (subject_id, name) VALUES ((SELECT id FROM public.subjects LIMIT 1), 'ZZ Student Topic'); v_state := v_state || 'topic-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'topic-refused;'; END;
    IF (SELECT count(*) FROM public.disciplines) >= 3 THEN v_state := v_state || 'read-ok;'; ELSE v_state := v_state || 'read-empty;'; END IF;
    RESET ROLE;
    RAISE EXCEPTION 'b02b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b02b_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'discipline-refused;subject-refused;subject-update-0rows;topic-refused;read-ok;'; detail := v_state; RETURN NEXT;

  -- privilege-level refusals for any authenticated user (admin included)
  check_name := 'real role admin: UPDATE on disciplines and topics, DELETE and TRUNCATE on all three are refused by privilege (42501)';
  v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN UPDATE public.disciplines SET order_num = 5; v_state := v_state || 'upd-disc-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'upd-disc-refused;'; END;
    BEGIN UPDATE public.topics SET order_num = 5; v_state := v_state || 'upd-topic-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'upd-topic-refused;'; END;
    BEGIN DELETE FROM public.disciplines; v_state := v_state || 'del-disc-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'del-disc-refused;'; END;
    BEGIN DELETE FROM public.subjects; v_state := v_state || 'del-subj-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'del-subj-refused;'; END;
    BEGIN DELETE FROM public.topics; v_state := v_state || 'del-topic-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'del-topic-refused;'; END;
    BEGIN TRUNCATE public.topics; v_state := v_state || 'trunc-topic-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'trunc-topic-refused;'; END;
    BEGIN TRUNCATE public.subjects; v_state := v_state || 'trunc-subj-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'trunc-subj-refused;'; END;
    BEGIN TRUNCATE public.disciplines; v_state := v_state || 'trunc-disc-allowed;'; EXCEPTION WHEN insufficient_privilege THEN v_state := v_state || 'trunc-disc-refused;'; END;
    RESET ROLE;
    RAISE EXCEPTION 'b02b_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b02b_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'upd-disc-refused;upd-topic-refused;del-disc-refused;del-subj-refused;del-topic-refused;trunc-topic-refused;trunc-subj-refused;trunc-disc-refused;'; detail := v_state; RETURN NEXT;

  check_name := 'live rows: no test row remains (disciplines, subjects, topics)';
  pass := NOT EXISTS (SELECT 1 FROM public.disciplines WHERE name LIKE 'ZZ %')
      AND NOT EXISTS (SELECT 1 FROM public.subjects WHERE name LIKE 'ZZ %')
      AND NOT EXISTS (SELECT 1 FROM public.topics WHERE name LIKE 'ZZ %')
      AND (SELECT count(*) FROM public.disciplines) = 3;
  detail := (SELECT count(*) FROM public.disciplines) || ' disciplines, ' || (SELECT count(*) FROM public.subjects) || ' subjects, ' || (SELECT count(*) FROM public.topics) || ' topics'; RETURN NEXT;
END;
$test$;

SELECT check_name, pass, detail FROM pg_temp.b02b_checks()
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass) FROM pg_temp.b02b_checks()), (SELECT count(*) || ' checks' FROM pg_temp.b02b_checks());
