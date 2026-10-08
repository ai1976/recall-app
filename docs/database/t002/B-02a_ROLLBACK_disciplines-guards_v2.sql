-- Name: [SCHEMA] T-002 B-02a ROLLBACK (v2) - remove the disciplines guards
--
-- Description: PERSISTENT DDL, the undo of B-02a_SCHEMA_disciplines-guards_v2.sql (v2 adds the TRUNCATE guard and corrects the undo order of v1, which omitted B-02b: QA Round 40 blocker 1). B-02a added five things that did not exist before (D2 v3 run of 08/10/2026: disciplines had only
-- its primary-key index and no trigger), so the rollback drops them. No data is touched. Run it BEFORE B-01_ROLLBACK (the index depends on normalize_course_text). Exact undo order
-- for the whole stream: B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01.

DROP TRIGGER IF EXISTS trg_disciplines_no_truncate ON public.disciplines;
DROP TRIGGER IF EXISTS trg_disciplines_no_delete ON public.disciplines;
DROP TRIGGER IF EXISTS trg_disciplines_no_rename ON public.disciplines;
DROP FUNCTION IF EXISTS public.fn_guard_disciplines_no_truncate();
DROP FUNCTION IF EXISTS public.fn_guard_disciplines_no_delete();
DROP FUNCTION IF EXISTS public.fn_guard_disciplines_no_rename();
DROP INDEX IF EXISTS public.disciplines_normalized_name_uidx;
