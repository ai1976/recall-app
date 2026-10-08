-- Name: [SCHEMA] T-002 B-02b (v1) - catalogue write path (admin-only policies) and client privilege closure for disciplines, subjects and topics
--
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
--      REFERENCES, TRIGGER, MAINTAIN) is revoked from anon and authenticated. service_role is NOT changed (a server role; B-02a already makes DELETE and TRUNCATE impossible for it
--      through the guard triggers).
--   Result: no client role can DELETE or TRUNCATE any of the three tables (the plan's closure rule), and every client write that remains goes through an is_admin() policy.
-- Pre-flight inside the file: it aborts if B-02a is absent, if is_admin() is absent, or if the live policy set of the three tables is not exactly the set above (so a change since
-- D2 is caught instead of silently combined). The file uses plain CREATE POLICY, so it also fails closed if one of the three new policy names already exists.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
DECLARE
  v_live text;
  v_expected text := 'disciplines|INSERT|admin_insert_disciplines;disciplines|SELECT|Users can read disciplines;subjects|SELECT|Users can read subjects;topics|SELECT|Users can read topics';
BEGIN
  IF to_regclass('public.disciplines_normalized_name_uidx') IS NULL THEN
    RAISE EXCEPTION 'B-02b requires B-02a: the unique index disciplines_normalized_name_uidx does not exist';
  END IF;
  IF to_regprocedure('public.is_admin()') IS NULL THEN
    RAISE EXCEPTION 'B-02b requires public.is_admin(), which does not exist';
  END IF;
  SELECT string_agg(tablename || '|' || cmd || '|' || policyname, ';' ORDER BY tablename, cmd, policyname)
    INTO v_live
    FROM pg_policies
   WHERE schemaname = 'public' AND tablename IN ('disciplines', 'subjects', 'topics');
  IF v_live IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'B-02b stopped: the live policies of disciplines, subjects and topics are not the ones D2 recorded. Live: %', coalesce(v_live, '(none)');
  END IF;
  IF NOT (SELECT bool_and(c.relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relname IN ('disciplines', 'subjects', 'topics')) THEN
    RAISE EXCEPTION 'B-02b stopped: row-level security is not enabled on all three tables';
  END IF;
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

REVOKE ALL ON TABLE public.disciplines, public.subjects, public.topics FROM anon;
GRANT SELECT ON TABLE public.disciplines, public.subjects, public.topics TO anon;

REVOKE ALL ON TABLE public.disciplines, public.subjects, public.topics FROM authenticated;
GRANT SELECT, INSERT ON TABLE public.disciplines, public.subjects, public.topics TO authenticated;
GRANT UPDATE ON TABLE public.subjects TO authenticated;
