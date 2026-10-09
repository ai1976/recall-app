-- Name: [FUNCTIONS] T-002 B-04a-fix ROLLBACK (v1) - restore the B-04a label guard (locale control class only)
--
-- Description: PERSISTENT DDL, the undo of B-04a-fix_SCHEMA_label-guard-control-set_v1.sql: one function replacement back to the exact B-04a body (the explicit U+2028 and U+2029 refusal is removed again). Run as
-- ONE selection; it stops unless the live function is the B-04a-fix one and raises unless the end state is the B-04a body. Order within the stream: before B-04a_ROLLBACK (which drops this function). Not run unless the
-- Founder decides to undo the fix.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
DECLARE
  v text;
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; config=' || coalesce(p.proconfig::text, '-') || '; acl=' || coalesce(p.proacl::text, '-')
         || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
    INTO v FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()');
  IF v IS DISTINCT FROM 'owner=postgres; secdef=true; config={"search_path=pg_catalog, public"}; acl={postgres=X/postgres}; body_md5_without_carriage_returns=39c60b5631a2ba031384f567287bd103' THEN
    RAISE EXCEPTION 'stopped: fn_study_sessions_label_guard is not the B-04a-fix version. Live: %', v;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND t.tgname = 'trg_study_sessions_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                   AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_study_sessions_label_guard BEFORE INSERT OR UPDATE OF custom_course_label, custom_subject_label ON public.study_sessions FOR EACH ROW WHEN (%new.custom_course_label IS NOT NULL%new.custom_subject_label IS NOT NULL%) EXECUTE FUNCTION fn_study_sessions_label_guard()') THEN
    RAISE EXCEPTION 'stopped: trg_study_sessions_label_guard is not the expected trigger';
  END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION public.fn_study_sessions_label_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v text;
BEGIN
  IF NEW.custom_course_label IS NOT NULL THEN
    v := pg_catalog.btrim(NEW.custom_course_label);
    IF v = '' THEN
      RAISE EXCEPTION 'study_sessions: the custom course label is empty' USING ERRCODE = '23514';
    END IF;
    IF pg_catalog.char_length(v) > 120 THEN
      RAISE EXCEPTION 'study_sessions: the custom course label is longer than 120 characters' USING ERRCODE = '23514';
    END IF;
    IF v ~ '[[:cntrl:]]' THEN
      RAISE EXCEPTION 'study_sessions: the custom course label contains a control character' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT 1 FROM public.disciplines d WHERE public.normalize_course_text(d.name) = public.normalize_course_text(v)) THEN
      RAISE EXCEPTION 'study_sessions: the custom course label equals a platform course; send it as a platform course' USING ERRCODE = '23514';
    END IF;
    NEW.custom_course_label := public.resolve_canonical_course_label(v);
  END IF;
  IF NEW.custom_subject_label IS NOT NULL THEN
    v := pg_catalog.btrim(NEW.custom_subject_label);
    IF v = '' THEN
      RAISE EXCEPTION 'study_sessions: the custom subject label is empty' USING ERRCODE = '23514';
    END IF;
    IF pg_catalog.char_length(v) > 120 THEN
      RAISE EXCEPTION 'study_sessions: the custom subject label is longer than 120 characters' USING ERRCODE = '23514';
    END IF;
    IF v ~ '[[:cntrl:]]' THEN
      RAISE EXCEPTION 'study_sessions: the custom subject label contains a control character' USING ERRCODE = '23514';
    END IF;
    NEW.custom_subject_label := v;
  END IF;
  RETURN NEW;
END;
$function$;

DO $postcheck$
DECLARE
  v text;
BEGIN
  SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; config=' || coalesce(p.proconfig::text, '-') || '; acl=' || coalesce(p.proacl::text, '-')
         || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
    INTO v FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()');
  IF v IS DISTINCT FROM 'owner=postgres; secdef=true; config={"search_path=pg_catalog, public"}; acl={postgres=X/postgres}; body_md5_without_carriage_returns=7208009f6067ebbfdad7148ea5f80d60' THEN
    RAISE EXCEPTION 'stopped: fn_study_sessions_label_guard is not the B-04a version after the rollback. Live: %', v;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND t.tgname = 'trg_study_sessions_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                   AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_study_sessions_label_guard BEFORE INSERT OR UPDATE OF custom_course_label, custom_subject_label ON public.study_sessions FOR EACH ROW WHEN (%new.custom_course_label IS NOT NULL%new.custom_subject_label IS NOT NULL%) EXECUTE FUNCTION fn_study_sessions_label_guard()') THEN
    RAISE EXCEPTION 'stopped: trg_study_sessions_label_guard is not the expected trigger';
  END IF;
END
$postcheck$;

SELECT md5(replace(p.prosrc, chr(13), '')) AS body_md5_without_carriage_returns, p.prosecdef AS security_definer, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl
  FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()');
