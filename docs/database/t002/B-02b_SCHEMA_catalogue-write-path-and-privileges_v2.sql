-- Name: [SCHEMA] T-002 B-02b (v2) - catalogue write path (admin-only policies) and client privilege closure for disciplines, subjects and topics
--
-- v2 answers QA Round 46 (v1 `82db0b313a80`): blocker 1: service_role is now closed on all three tables (plan 10B R1: retained only for an edge function that D4 finds; D4 v13 finds none
-- touching disciplines, subjects or topics), so the catalogue cannot be deleted, truncated or rewritten by a role that bypasses RLS; blocker 2: the pre-flight now binds the EXACT live
-- policy bodies (roles, permissive mode, USING, WITH CHECK, as D2 recorded them, by hash) and the is_admin() contract (definition hash, owner, SECURITY DEFINER, ACL), and also the
-- B-02a object set, no column-level and no PUBLIC grants, and the exact starting privileges; non-blocking 4, 5, 8 folded in. Rollback restores service_role.
-- Description: PERSISTENT DDL. Implements brief B v10 (0fe77dec72dc) section 6.4 and plan v18 file B-02b (tiered workflow; Tier 1: QA audits this exact file by hash, at most two
-- rounds; the Founder authorizes the run by hash). Run ONLY after B-02a is live and its TEST all true (done 08/10/2026) and after that approval. One selection in the Supabase SQL
-- Editor = ONE transaction, so the timeouts below apply and the file has no verification and no ROLLBACK (verification is B-02b_TEST, undo is B-02b_ROLLBACK).
--
-- LIVE STATE THIS FILE IS BUILT ON (D2 v3 run of 08/10/2026, docs/discussions/evidence/T-002_D2-index_08-10-2026.md; D4 v13 of the same day):
--   * RLS is enabled (not forced) on all three tables; the policies are: disciplines "Users can read disciplines" (SELECT, auth.role() = 'authenticated') and
--     "admin_insert_disciplines" (INSERT, WITH CHECK is_admin(), role authenticated); subjects and topics have ONLY a SELECT policy. So today NO client role can insert or update
--     a subject or a topic through RLS, although anon, authenticated and service_role hold ALL eight table privileges (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES,
--     TRIGGER, MAINTAIN) on all three tables.
--   * The only code that writes these tables is src/pages/admin/BulkUploadTopics.jsx (D4): INSERT disciplines (line 216: name, code), INSERT subjects (632), UPDATE subjects
--     order_num (654), INSERT topics (691). No code updates a discipline or topic, and no code deletes any of the three.
--   * is_admin() is SQL, SECURITY DEFINER, STABLE, search_path public, extensions, true for profiles.role in ('admin', 'super_admin').
--   * OPEN, to verify by a real admin upload after this file: whether the bulk-upload page's subject and topic inserts were being refused by RLS before this file (the live policy
--     list says they must have been). If so this file ENABLES them for administrators; it never widens them beyond is_admin().
--
-- WHAT IT DOES
--   1. Policies (all TO authenticated, all through is_admin(), the pattern of the live admin_insert_disciplines): admin_insert_subjects (INSERT), admin_update_subjects (UPDATE,
--      USING and WITH CHECK), admin_insert_topics (INSERT). No policy for DELETE anywhere, no UPDATE policy for disciplines or topics (no code needs them; deactivation of a
--      discipline stays an owner action until an admin screen exists).
--   2. Privileges, exactly: anon keeps SELECT only (the live policies already return no rows to anon; the grant is removed later, when Signup uses the public wrapper, B-06a/F1);
--      authenticated keeps SELECT on all three, INSERT on all three, UPDATE on subjects only; every other privilege (UPDATE on disciplines and topics, DELETE, TRUNCATE,
--      REFERENCES, TRIGGER, MAINTAIN) is revoked from anon and authenticated. service_role loses ALL privileges on the three tables (v2; plan 10B R1: no edge function uses them, D4 v13). The SECURITY DEFINER functions that read the catalogue run as the
--      owner, not as service_role.
--   Result: no client role can DELETE or TRUNCATE any of the three tables (the plan's closure rule), and every client write that remains goes through an is_admin() policy.
-- Pre-flight inside the file (v2) aborts unless ALL of this holds: the six B-02a objects exist and the three triggers are enabled; the live policies of the three tables are exactly the
-- four D2 recorded, compared by an MD5 over table, name, command, permissive mode, roles, USING and WITH CHECK (expected 00016f923f47...); public.is_admin() has the D2 definition hash
-- (md5 of pg_get_functiondef 48f3d12d8d0e8d54ed1d745bd66a1cff), owner postgres, SECURITY DEFINER, and execute grantees PUBLIC, anon, authenticated, postgres, service_role (compared in byte order, COLLATE "C"); RLS is enabled
-- on the three tables; no column carries its own ACL; no table grants anything to PUBLIC; and anon, authenticated and service_role each hold exactly the eight table privileges D2 recorded. The file uses plain CREATE POLICY, so it also fails closed if one of the three new policy names already exists.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
DECLARE
  v_pol   text;
  v_all8  text[] := ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN'];
  v_role  text;
  v_tbl   text;
  v_n     integer;
BEGIN
  -- B-02a complete object set (index, three triggers enabled, three functions)
  IF to_regclass('public.disciplines_normalized_name_uidx') IS NULL THEN
    RAISE EXCEPTION 'B-02b requires B-02a: the unique index disciplines_normalized_name_uidx does not exist';
  END IF;
  SELECT count(*) INTO v_n FROM pg_trigger g
   WHERE g.tgrelid = 'public.disciplines'::regclass AND NOT g.tgisinternal AND g.tgenabled = 'O'
     AND g.tgname IN ('trg_disciplines_no_rename', 'trg_disciplines_no_delete', 'trg_disciplines_no_truncate');
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'B-02b requires B-02a: expected 3 enabled guard triggers on disciplines, found %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname IN ('fn_guard_disciplines_no_rename', 'fn_guard_disciplines_no_delete', 'fn_guard_disciplines_no_truncate');
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'B-02b requires B-02a: expected 3 guard functions, found %', v_n;
  END IF;

  -- is_admin(): the D2-bound contract
  IF to_regprocedure('public.is_admin()') IS NULL THEN
    RAISE EXCEPTION 'B-02b requires public.is_admin(), which does not exist';
  END IF;
  IF md5(pg_get_functiondef('public.is_admin()'::regprocedure)) <> '48f3d12d8d0e8d54ed1d745bd66a1cff' THEN
    RAISE EXCEPTION 'B-02b stopped: the definition of public.is_admin() is not the one D2 recorded (hash differs)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = 'public.is_admin()'::regprocedure AND p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres') THEN
    RAISE EXCEPTION 'B-02b stopped: public.is_admin() is not SECURITY DEFINER owned by postgres';
  END IF;
  SELECT string_agg(q.g, ',' ORDER BY q.g COLLATE "C")
    INTO v_pol
    FROM (SELECT DISTINCT (CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee)::text END) AS g
            FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = 'public.is_admin()'::regprocedure) q;
  IF v_pol IS DISTINCT FROM 'PUBLIC,anon,authenticated,postgres,service_role' THEN
    RAISE EXCEPTION 'B-02b stopped: the execute grantees of public.is_admin() are not the ones D2 recorded: %', coalesce(v_pol, '(default)');
  END IF;

  -- the existing policies, bound by exact content
  SELECT md5(string_agg(tablename || '|' || policyname || '|' || cmd || '|' || permissive || '|' || roles::text || '|' || coalesce(qual, '') || '|' || coalesce(with_check, ''), ';' ORDER BY tablename, cmd, policyname))
    INTO v_pol
    FROM pg_policies
   WHERE schemaname = 'public' AND tablename IN ('disciplines', 'subjects', 'topics');
  IF v_pol IS DISTINCT FROM '00016f923f4768acab7ea6b4e563dc2d' THEN
    RAISE EXCEPTION 'B-02b stopped: the live policies of disciplines, subjects and topics are not the ones D2 recorded (hash %)', coalesce(v_pol, '(none)');
  END IF;
  IF NOT (SELECT bool_and(c.relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relname IN ('disciplines', 'subjects', 'topics')) THEN
    RAISE EXCEPTION 'B-02b stopped: row-level security is not enabled on all three tables';
  END IF;

  -- no column-level ACL, no PUBLIC table grant, exact starting privileges
  IF EXISTS (SELECT 1 FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = 'public' AND c.relname IN ('disciplines', 'subjects', 'topics') AND a.attnum > 0 AND NOT a.attisdropped AND a.attacl IS NOT NULL) THEN
    RAISE EXCEPTION 'B-02b stopped: a column of disciplines, subjects or topics carries its own ACL';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x
              WHERE n.nspname = 'public' AND c.relname IN ('disciplines', 'subjects', 'topics') AND x.grantee = 0) THEN
    RAISE EXCEPTION 'B-02b stopped: PUBLIC holds a privilege on disciplines, subjects or topics';
  END IF;
  FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    FOREACH v_tbl IN ARRAY ARRAY['public.disciplines', 'public.subjects', 'public.topics'] LOOP
      SELECT count(*) INTO v_n FROM unnest(v_all8) p WHERE has_table_privilege(v_role, v_tbl, p);
      IF v_n <> 8 THEN
        RAISE EXCEPTION 'B-02b stopped: % holds % of 8 privileges on % (D2 recorded 8)', v_role, v_n, v_tbl;
      END IF;
    END LOOP;
  END LOOP;
END
$preflight$;

CREATE POLICY admin_insert_subjects ON public.subjects
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY admin_update_subjects ON public.subjects
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY admin_insert_topics ON public.topics
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

REVOKE ALL ON TABLE public.disciplines, public.subjects, public.topics FROM service_role;

REVOKE ALL ON TABLE public.disciplines, public.subjects, public.topics FROM anon;
GRANT SELECT ON TABLE public.disciplines, public.subjects, public.topics TO anon;

REVOKE ALL ON TABLE public.disciplines, public.subjects, public.topics FROM authenticated;
GRANT SELECT, INSERT ON TABLE public.disciplines, public.subjects, public.topics TO authenticated;
GRANT UPDATE ON TABLE public.subjects TO authenticated;
