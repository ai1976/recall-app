-- Name: [SCHEMA] T-002 B-02a (v1) - disciplines guards: unique normalized name over all rows, no rename, no hard delete
--
-- Description: PERSISTENT DDL. Implements brief B v10 (0fe77dec72dc) section 6.4 (a) to (c), decisions E8 and B-I1, and plan v18 file B-02a. Tier 1 file: QA audits this exact file by
-- hash (at most two rounds, blockers only); the Founder authorizes the production run by hash. Run ONLY after B-01 (normalize_course_text must exist; B-01_TEST all true) and after
-- that approval. The Supabase SQL Editor runs a selection in ONE transaction; this file has no verification and no ROLLBACK (verification is B-02a_TEST, undo is B-02a_ROLLBACK).
--
-- What it adds to public.disciplines (and nothing else; no data change):
--   1. a UNIQUE index over public.normalize_course_text(name), covering ALL rows including inactive ones, so one label can never resolve to two ids. A title-cased variant such as
--      "Ca Final" is rejected with SQLSTATE 23505 (duplicate key value violates unique constraint "disciplines_normalized_name_uidx"); the admin page BulkUploadTopics.jsx must
--      show that error (an F0 frontend item).
--   2. trg_disciplines_no_rename: BEFORE UPDATE OF name, row level: raises SQLSTATE 23514 when NEW.name differs from OLD.name (platform course names are identifiers; a no-op
--      assignment of the same name is allowed). Deactivate and recreate instead.
--   3. trg_disciplines_no_delete: BEFORE DELETE, row level: raises SQLSTATE 23001 (restrict_violation). Deactivate with is_active = false instead; a deleted row would make an
--      existing profile label, card or session stop resolving to a platform identity.
-- Both trigger functions are SECURITY INVOKER, pinned search_path, read no table, and have no EXECUTE grant for any client role (a trigger function needs EXECUTE only when the
-- trigger is created).
-- NOT in this file (B-02b, by plan): the client privilege closure and the admin write path. TRUNCATE bypasses row triggers and is closed there by revoking the privilege.
-- Pre-flight inside the file: it aborts with a clear message if two existing names already collide under the normalization (D2 v3 P5, 08/10/2026: three rows CA Final, CA
-- Foundation, CA Intermediate, collisions: none), so the index creation cannot fail half way for a data reason.
-- Evidence relied on: D2 v3 evidence index docs/discussions/evidence/T-002_D2-index_08-10-2026.md (disciplines: id uuid, name text NOT NULL, code text NOT NULL, only the primary
-- key index; policies "Users can read disciplines" and "admin_insert_disciplines" only, so clients cannot UPDATE or DELETE through RLS today; table grants to anon and authenticated
-- include TRUNCATE, closed in B-02b); D3 v11 run (no trigger or view depends on disciplines; the cascade FKs from subjects and profile_courses are untouched).

DO $preflight$
DECLARE
  v_dup text;
BEGIN
  IF to_regprocedure('public.normalize_course_text(text)') IS NULL THEN
    RAISE EXCEPTION 'B-02a requires B-01: public.normalize_course_text(text) does not exist';
  END IF;
  SELECT string_agg(k, ', ')
    INTO v_dup
    FROM (SELECT public.normalize_course_text(name) AS k
            FROM public.disciplines
           GROUP BY 1
          HAVING count(*) > 1) q;
  IF v_dup IS NOT NULL THEN
    RAISE EXCEPTION 'B-02a stopped: existing discipline names collide under the normalization: %', v_dup;
  END IF;
END
$preflight$;

CREATE UNIQUE INDEX disciplines_normalized_name_uidx
  ON public.disciplines (public.normalize_course_text(name));

CREATE OR REPLACE FUNCTION public.fn_guard_disciplines_no_rename()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF NEW.name IS DISTINCT FROM OLD.name THEN
    RAISE EXCEPTION 'a discipline cannot be renamed (platform course names are identifiers); deactivate it and create a new one'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_guard_disciplines_no_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  RAISE EXCEPTION 'a discipline cannot be deleted; set is_active to false instead'
    USING ERRCODE = '23001';
  RETURN OLD;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_guard_disciplines_no_rename() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_guard_disciplines_no_delete() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_disciplines_no_rename
  BEFORE UPDATE OF name ON public.disciplines
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_guard_disciplines_no_rename();

CREATE TRIGGER trg_disciplines_no_delete
  BEFORE DELETE ON public.disciplines
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_guard_disciplines_no_delete();
