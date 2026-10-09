-- Name: [SCHEMA] T-002 B-07 ROLLBACK (v2) - remove the access_requests course trigger and its function
--
-- Description: PERSISTENT DDL, the undo of B-07_SCHEMA_access-requests-course-trigger_v2.sql. v2 (QA Round 68): it first proves that the trigger and function it is about to drop are the B-07 ones, and it raises if the end
-- state is not the expected one. Run as ONE selection after the B-06a, B-05 and B-04a rollbacks and BEFORE B-03_ROLLBACK (undo order: B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01). It drops the trigger and the
-- function only; course values already rewritten to canonical text stay (their earlier spelling cannot be reconstructed). Not run unless the Founder decides to undo B-07.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.access_requests IN SHARE ROW EXCLUSIVE MODE;

DO $guard$
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.access_requests'::regclass AND t.tgname = 'trg_access_requests_course_label_guard' AND NOT t.tgisinternal
                   AND pg_get_triggerdef(t.oid) LIKE 'CREATE TRIGGER trg_access_requests_course_label_guard BEFORE INSERT OR UPDATE OF course, request_type ON public.access_requests FOR EACH ROW WHEN (%new.request_type = ''student_access''%) EXECUTE FUNCTION fn_access_requests_course_label_guard()')
     OR NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_access_requests_course_label_guard()') AND p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres') THEN
    RAISE EXCEPTION 'B-07 ROLLBACK stopped: the trigger or function is not the B-07 object (or is already removed)';
  END IF;
END
$guard$;

DROP TRIGGER trg_access_requests_course_label_guard ON public.access_requests;
DROP FUNCTION public.fn_access_requests_course_label_guard();

DO $postcheck$
BEGIN
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.access_requests'::regclass AND NOT tgisinternal) <> 0
     OR to_regprocedure('public.fn_access_requests_course_label_guard()') IS NOT NULL THEN
    RAISE EXCEPTION 'B-07 ROLLBACK stopped: the end state is not zero triggers and no guard function; nothing is applied';
  END IF;
END
$postcheck$;

SELECT (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.access_requests'::regclass AND NOT tgisinternal) AS access_requests_triggers_expected_0,
       to_regprocedure('public.fn_access_requests_course_label_guard()') IS NULL AS function_removed;
