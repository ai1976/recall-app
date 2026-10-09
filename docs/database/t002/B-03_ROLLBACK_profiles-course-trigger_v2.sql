-- Name: [SCHEMA] T-002 B-03 ROLLBACK (v2) - remove the profiles course trigger and its function
--
-- Description: PERSISTENT DDL, the undo of B-03_SCHEMA_profiles-course-trigger_v2.sql. v2 (QA Round 68): it first proves that the trigger and function it is about to drop are the B-03 ones, and it raises if the end
-- state is not the expected one. Run it as ONE selection AFTER the rollbacks of B-06a, B-05, B-04a and B-07 and BEFORE B-02b_ROLLBACK (undo order for the stream: B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01).
-- It drops the trigger and the function only. Course values the trigger already rewrote to canonical text stay as they are (equivalent text); their earlier spelling cannot be reconstructed. Existing profile data and the
-- three older triggers are not touched. Not run unless the Founder decides to undo B-03.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.profiles IN SHARE ROW EXCLUSIVE MODE;

DO $guard$
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.profiles'::regclass AND t.tgname = 'trg_profiles_course_label_guard' AND NOT t.tgisinternal
                   AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_profiles_course_label_guard BEFORE INSERT OR UPDATE OF course_level ON public.profiles FOR EACH ROW WHEN (%new.course_level IS NOT NULL%) EXECUTE FUNCTION fn_profiles_course_label_guard()')
     OR NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_profiles_course_label_guard()') AND p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres') THEN
    RAISE EXCEPTION 'B-03 ROLLBACK stopped: the trigger or function is not the B-03 object (or is already removed)';
  END IF;
END
$guard$;

DROP TRIGGER trg_profiles_course_label_guard ON public.profiles;
DROP FUNCTION public.fn_profiles_course_label_guard();

DO $postcheck$
BEGIN
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal) <> 3
     OR to_regprocedure('public.fn_profiles_course_label_guard()') IS NOT NULL THEN
    RAISE EXCEPTION 'B-03 ROLLBACK stopped: the end state is not three older triggers and no guard function; nothing is applied';
  END IF;
END
$postcheck$;

SELECT (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal) AS profiles_triggers_expected_3,
       to_regprocedure('public.fn_profiles_course_label_guard()') IS NULL AS function_removed;
