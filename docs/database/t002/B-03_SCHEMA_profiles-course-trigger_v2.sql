-- Name: [SCHEMA] T-002 B-03 (v2) - profiles.course_level trigger: validate and write the canonical course text
--
-- Description: PERSISTENT DDL. v2 (QA Round 68): the control-character test is explicit (C0, DEL, C1, U+2028, U+2029) instead of the locale class alone; the pre-flight asserts the executing role is postgres and binds the exact B-02a index (definition, unique, valid, ready); the summary rows are fail-closed. Implements brief B v10 (0fe77dec72dc) sections 5.1 to 5.3a and plan v18 section 6 (B-03) with the Founder's acceptance of the stale-tab residual 4C (09/10/2026) and F0 live with Gates 5 to 7
-- complete (Round 66). Tier 1: QA audits this exact file by hash, at most two rounds; the Founder authorizes the run by hash. One selection in the Supabase SQL Editor = ONE transaction. The pre-flight aborts, changing
-- nothing, unless the live state equals what D2 and D3 recorded (profiles columns, constraints and triggers; the signup function), and the B-01 functions equal the identities saved by the B-04a VERIFY run.
--
-- WHAT IT DOES: adds trigger trg_profiles_course_label_guard (BEFORE INSERT OR UPDATE OF course_level on profiles, only when the new value is not NULL) with SECURITY DEFINER function fn_profiles_course_label_guard
-- (pinned search_path, owner only): on UPDATE it returns at once when the value did not change (so a legacy value is never re-validated or rewritten by an unrelated update); otherwise it trims the outer spaces, refuses a
-- value that is empty, longer than 120 characters or contains a control character (SQLSTATE 23514, a generic message in the app), and rewrites a normalized match to a discipline name (its exact stored name, active or
-- inactive) or to a CMA or CS catalogue label (its exact catalogue text) with resolve_canonical_course_label; any other text is stored trimmed only. There is NO rule about the word Other. A NULL course_level is never
-- touched (brief B 5.1; two live profiles are NULL). It is a BEFORE trigger, so the existing AFTER trigger trg_course_change_archive_restore sees the canonical value. Signup: fn_create_profile_on_signup (AFTER INSERT on
-- auth.users) inserts the profile, so a refused value stops that signup with a database error; F0 blocks the same values in the browser first (residual 4C: a tab not reloaded since before F0). No data is changed and no
-- row is rewritten by this file (D2 P5: no live value is a variant of a canonical name, none has outer whitespace, a control character or more than 120 characters).
-- Coexistence: trg_guard_profiles_protected_columns (BEFORE UPDATE, protected columns only) and trg_badge_new_profile (AFTER INSERT) are untouched.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.profiles IN SHARE ROW EXCLUSIVE MODE;

DO $preflight$
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
    RAISE EXCEPTION 'B-03 stopped: the B-02a unique index differs from the recorded one. Live: %', v;
  END IF;
  IF to_regprocedure('public.fn_profiles_course_label_guard()') IS NOT NULL THEN
    RAISE EXCEPTION 'B-03 stopped: fn_profiles_course_label_guard already exists';
  END IF;

  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) INTO v
    FROM pg_attribute a WHERE a.attrelid = 'public.profiles'::regclass AND a.attnum > 0 AND NOT a.attisdropped;
  IF v IS DISTINCT FROM $lit$id:uuid,email:text,full_name:text,course_level:text,institution:text,created_at:timestamp with time zone,updated_at:timestamp with time zone,role:text,timezone:text,account_type:text,has_seen_onboarding:boolean,access_request_ref:uuid,status:text,daily_review_goal:integer,daily_study_goal_minutes:integer,has_dismissed_goal_prompt:boolean,exam_date:date,exam_month:date,has_dismissed_exam_prompt:boolean$lit$ THEN RAISE EXCEPTION 'B-03 stopped: profiles columns differ from D2. Live: %', v; END IF;

  SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") INTO v FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass;
  IF v IS DISTINCT FROM $lit$profiles_account_type_check|CHECK ((account_type = ANY (ARRAY['enrolled'::text, 'self_registered'::text])));profiles_course_level_check|CHECK (((course_level = ANY (ARRAY['CA Foundation'::text, 'CA Intermediate'::text, 'CA Final'::text, 'CMA Foundation'::text, 'CMA Intermediate'::text, 'CMA Final'::text, 'CS Foundation'::text, 'CS Executive'::text, 'CS Professional'::text])) OR (course_level IS NULL) OR (length(course_level) > 0)));profiles_daily_review_goal_check|CHECK (((daily_review_goal > 0) AND (daily_review_goal <= 200)));profiles_daily_study_goal_minutes_check|CHECK (((daily_study_goal_minutes > 0) AND (daily_study_goal_minutes <= 480)));profiles_email_key|UNIQUE (email);profiles_email_normalized|CHECK (((email IS NULL) OR (email = lower(btrim(email)))));profiles_exam_month_check|CHECK (((exam_month IS NULL) OR (EXTRACT(day FROM exam_month) = (1)::numeric)));profiles_id_fkey|FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;profiles_pkey|PRIMARY KEY (id);profiles_status_check|CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])));valid_role|CHECK ((role = ANY (ARRAY['super_admin'::text, 'admin'::text, 'professor'::text, 'student'::text])))$lit$ THEN RAISE EXCEPTION 'B-03 stopped: profiles constraints differ from D2. Live: %', v; END IF;

  SELECT string_agg(tgname || '|' || pg_get_triggerdef(oid), ';' ORDER BY tgname COLLATE "C") INTO v FROM pg_trigger WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal;
  IF v IS DISTINCT FROM $lit$trg_badge_new_profile|CREATE TRIGGER trg_badge_new_profile AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION fn_badge_check_new_profile();trg_course_change_archive_restore|CREATE TRIGGER trg_course_change_archive_restore AFTER UPDATE OF course_level ON public.profiles FOR EACH ROW WHEN ((old.course_level IS DISTINCT FROM new.course_level)) EXECUTE FUNCTION fn_course_change_archive_restore();trg_guard_profiles_protected_columns|CREATE TRIGGER trg_guard_profiles_protected_columns BEFORE UPDATE ON public.profiles FOR EACH ROW WHEN (((old.id IS DISTINCT FROM new.id) OR (old.role IS DISTINCT FROM new.role) OR (old.account_type IS DISTINCT FROM new.account_type) OR (old.status IS DISTINCT FROM new.status) OR (old.email IS DISTINCT FROM new.email) OR (old.access_request_ref IS DISTINCT FROM new.access_request_ref))) EXECUTE FUNCTION fn_guard_profiles_protected_columns()$lit$ THEN RAISE EXCEPTION 'B-03 stopped: profiles triggers differ from D2. Live: %', v; END IF;

  SELECT md5(pg_get_functiondef(to_regprocedure('public.fn_create_profile_on_signup()'))) INTO v;
  IF v IS DISTINCT FROM '8a6fc60806e9e576485f899912d04578' THEN RAISE EXCEPTION 'B-03 stopped: the signup function fn_create_profile_on_signup differs from D3. Live md5: %', v; END IF;
END
$preflight$;

CREATE TEMP TABLE b03_proof ON COMMIT DROP AS
SELECT count(*)::integer AS n0, md5(coalesce(string_agg(to_jsonb(p)::text, '|' ORDER BY p.id), '')) AS h0 FROM public.profiles p;

CREATE FUNCTION public.fn_profiles_course_label_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v text;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.course_level IS NOT DISTINCT FROM NEW.course_level THEN
    RETURN NEW;
  END IF;
  IF NEW.course_level IS NULL THEN
    RETURN NEW;
  END IF;
  v := pg_catalog.btrim(NEW.course_level);
  IF v = '' THEN
    RAISE EXCEPTION 'profiles: the course is empty' USING ERRCODE = '23514';
  END IF;
  IF pg_catalog.char_length(v) > 120 THEN
    RAISE EXCEPTION 'profiles: the course is longer than 120 characters' USING ERRCODE = '23514';
  END IF;
  IF v ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]' THEN
    RAISE EXCEPTION 'profiles: the course contains a control character' USING ERRCODE = '23514';
  END IF;
  NEW.course_level := public.resolve_canonical_course_label(v);
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_profiles_course_label_guard() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_profiles_course_label_guard
  BEFORE INSERT OR UPDATE OF course_level ON public.profiles
  FOR EACH ROW
  WHEN (NEW.course_level IS NOT NULL)
  EXECUTE FUNCTION public.fn_profiles_course_label_guard();

DO $postcheck$
DECLARE
  p b03_proof%ROWTYPE;
  v_n integer;
  v_h text;
BEGIN
  SELECT * INTO p FROM b03_proof;
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(q)::text, '|' ORDER BY q.id), '')) INTO v_n, v_h FROM public.profiles q;
  IF v_n <> p.n0 OR v_h <> p.h0 THEN
    RAISE EXCEPTION 'B-03 stopped: profiles changed during the run (rows % -> %); nothing is applied', p.n0, v_n;
  END IF;
END
$postcheck$;

SELECT p.n0 AS rows_before, (SELECT count(*) FROM public.profiles) AS rows_after, p.h0 AS profiles_hash_before,
       (SELECT md5(coalesce(string_agg(to_jsonb(q)::text, '|' ORDER BY q.id), '')) FROM public.profiles q) AS profiles_hash_after
  FROM b03_proof p;
