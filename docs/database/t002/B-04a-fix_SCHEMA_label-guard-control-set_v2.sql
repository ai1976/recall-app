-- Name: [FUNCTIONS] T-002 B-04a-fix (v2) - study_sessions label guard: explicit control-character set (C0, DEL, C1, U+2028, U+2029)
--
-- Description: PERSISTENT DDL, one function replacement. v2 (QA Round 73): the file now takes SHARE ROW EXCLUSIVE on study_sessions (no INSERT or UPDATE can run through the old guard while it is replaced), checks in the same transaction that NO committed row already carries a prohibited control character in a label (if one does it stops, changes nothing and returns the case to the Founder), binds more routine attributes (language, result type, volatility, strict, parallel, leakproof) and the complete user-trigger inventory (exactly one). Closes the gap QA Round 68 and Claude found in the LIVE B-04a function fn_study_sessions_label_guard: it refuses control characters with the locale class
-- [[:cntrl:]] alone, which does not include U+2028 and U+2029 (the Unicode line and paragraph separators), although the Founder-accepted rule (F0, 4C, B-03 and B-07 v2) includes them. The new body is byte-for-byte the
-- B-04a body except that both tests (custom course label and custom subject label) use the explicit set [[:cntrl:]] plus \u0001-\u001f, \u007f-\u009f, \u2028 and \u2029. Nothing else changes: same trimming, same 120-character
-- limit, same platform-name refusal, same canonical resolution, same trigger (not touched), same owner, SECURITY DEFINER and pinned search_path (CREATE OR REPLACE keeps the owner and the empty client ACL).
-- Tier 1: QA audits this exact file; the Founder authorizes the run by hash. It must be live before the F1 frontend lets students log custom course or subject labels (nothing stored today can have used the gap:
-- no row carries a classification). One selection in the Supabase SQL Editor = ONE transaction. The only table data it reads is the label columns, in one scan, to prove the zero-match precondition; nothing is changed.
-- The pre-flight stops unless the live function is exactly the B-04a one. Function bodies pasted in the SQL editor are stored with Windows line endings (carriage returns), so the body is compared after removing carriage
-- returns; the recorded live value (B-04a VERIFY, 08/10/2026) is src_md5 de8c5bf330abaaad57137ccaa8d1781c with carriage returns, 7208009f6067ebbfdad7148ea5f80d60 without them.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.study_sessions IN SHARE ROW EXCLUSIVE MODE;

DO $preflight$
DECLARE
  v text;
  n integer;
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; config=' || coalesce(p.proconfig::text, '-') || '; acl=' || coalesce(p.proacl::text, '-')
         || '; language=' || (SELECT l.lanname FROM pg_language l WHERE l.oid = p.prolang) || '; result=' || pg_get_function_result(p.oid) || '; volatility=' || p.provolatile::text || '; strict=' || p.proisstrict || '; parallel=' || p.proparallel::text || '; leakproof=' || p.proleakproof
         || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
    INTO v FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()');
  IF v IS DISTINCT FROM 'owner=postgres; secdef=true; config={"search_path=pg_catalog, public"}; acl={postgres=X/postgres}; language=plpgsql; result=trigger; volatility=v; strict=false; parallel=u; leakproof=false; body_md5_without_carriage_returns=7208009f6067ebbfdad7148ea5f80d60' THEN
    RAISE EXCEPTION 'stopped: fn_study_sessions_label_guard is not the expected version. Live: %', v;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND t.tgname = 'trg_study_sessions_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                   AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_study_sessions_label_guard BEFORE INSERT OR UPDATE OF custom_course_label, custom_subject_label ON public.study_sessions FOR EACH ROW WHEN (%new.custom_course_label IS NOT NULL%new.custom_subject_label IS NOT NULL%) EXECUTE FUNCTION fn_study_sessions_label_guard()') THEN
    RAISE EXCEPTION 'stopped: trg_study_sessions_label_guard is not the expected trigger';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal) <> 1 THEN
    RAISE EXCEPTION 'stopped: study_sessions must have exactly the one B-04a user trigger; the trigger inventory differs';
  END IF;
  SELECT count(*) INTO n FROM public.study_sessions WHERE custom_course_label ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]' OR custom_subject_label ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]';
  IF n > 0 THEN
    RAISE EXCEPTION 'stopped: % existing study_sessions rows carry a prohibited control character in a label; nothing is applied and the case returns to the Founder (no data is changed by this file)', n;
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
    IF v ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]' THEN
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
    IF v ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]' THEN
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
  n integer;
BEGIN
  SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; config=' || coalesce(p.proconfig::text, '-') || '; acl=' || coalesce(p.proacl::text, '-')
         || '; language=' || (SELECT l.lanname FROM pg_language l WHERE l.oid = p.prolang) || '; result=' || pg_get_function_result(p.oid) || '; volatility=' || p.provolatile::text || '; strict=' || p.proisstrict || '; parallel=' || p.proparallel::text || '; leakproof=' || p.proleakproof
         || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
    INTO v FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()');
  IF v IS DISTINCT FROM 'owner=postgres; secdef=true; config={"search_path=pg_catalog, public"}; acl={postgres=X/postgres}; language=plpgsql; result=trigger; volatility=v; strict=false; parallel=u; leakproof=false; body_md5_without_carriage_returns=39c60b5631a2ba031384f567287bd103' THEN
    RAISE EXCEPTION 'stopped: fn_study_sessions_label_guard is not the new version after the replacement. Live: %', v;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.study_sessions'::regclass AND t.tgname = 'trg_study_sessions_label_guard' AND t.tgenabled = 'O' AND NOT t.tgisinternal
                   AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_study_sessions_label_guard BEFORE INSERT OR UPDATE OF custom_course_label, custom_subject_label ON public.study_sessions FOR EACH ROW WHEN (%new.custom_course_label IS NOT NULL%new.custom_subject_label IS NOT NULL%) EXECUTE FUNCTION fn_study_sessions_label_guard()') THEN
    RAISE EXCEPTION 'stopped: trg_study_sessions_label_guard is not the expected trigger';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal) <> 1 THEN
    RAISE EXCEPTION 'stopped: study_sessions must have exactly the one B-04a user trigger; the trigger inventory differs';
  END IF;
  SELECT count(*) INTO n FROM public.study_sessions WHERE custom_course_label ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]' OR custom_subject_label ~ '[[:cntrl:]\u0001-\u001f\u007f-\u009f\u2028\u2029]';
  IF n > 0 THEN
    RAISE EXCEPTION 'stopped: % existing study_sessions rows carry a prohibited control character in a label; nothing is applied and the case returns to the Founder (no data is changed by this file)', n;
  END IF;
END
$postcheck$;

SELECT md5(replace(p.prosrc, chr(13), '')) AS body_md5_without_carriage_returns, p.prosecdef AS security_definer, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl
  FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_study_sessions_label_guard()');
