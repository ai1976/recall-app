-- Name: [SCHEMA] T-002 B-07 ROLLBACK (v1) - remove the access_requests course trigger and its function
--
-- Description: PERSISTENT DDL, the undo of B-07_SCHEMA_access-requests-course-trigger_v1.sql. Run as ONE selection after B-06a, B-05, B-04a rollbacks and BEFORE B-03_ROLLBACK (undo order for the stream: B-06a, B-05,
-- B-04a, B-07, B-03, B-02b, B-02a, B-01). It drops the trigger and the function only; course values already rewritten to canonical text stay (equivalent text). Not run unless the Founder decides to undo B-07.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.access_requests IN SHARE ROW EXCLUSIVE MODE;

DROP TRIGGER IF EXISTS trg_access_requests_course_label_guard ON public.access_requests;
DROP FUNCTION IF EXISTS public.fn_access_requests_course_label_guard();

SELECT (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.access_requests'::regclass AND NOT tgisinternal) AS access_requests_triggers_expected_0,
       to_regprocedure('public.fn_access_requests_course_label_guard()') IS NULL AS function_removed;
