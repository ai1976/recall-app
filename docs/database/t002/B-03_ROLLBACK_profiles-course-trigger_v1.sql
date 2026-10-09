-- Name: [SCHEMA] T-002 B-03 ROLLBACK (v1) - remove the profiles course trigger and its function
--
-- Description: PERSISTENT DDL, the undo of B-03_SCHEMA_profiles-course-trigger_v1.sql. Run it as ONE selection AFTER the rollbacks of B-06a, B-05, B-04a and B-07 and BEFORE B-02b_ROLLBACK (exact undo order for the whole
-- stream: B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01). It drops the trigger and the function only. Course values the trigger already rewrote to canonical text stay as they are (equivalent text: the same
-- normalized value). Existing profile data and the three older triggers are not touched. Not run unless the Founder decides to undo B-03.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.profiles IN SHARE ROW EXCLUSIVE MODE;

DROP TRIGGER IF EXISTS trg_profiles_course_label_guard ON public.profiles;
DROP FUNCTION IF EXISTS public.fn_profiles_course_label_guard();

SELECT (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.profiles'::regclass AND NOT tgisinternal) AS profiles_triggers_expected_3,
       to_regprocedure('public.fn_profiles_course_label_guard()') IS NULL AS function_removed;
