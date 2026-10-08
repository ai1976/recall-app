-- Name: [FUNCTIONS] T-002 B-01 ROLLBACK (v1) - remove the course-text normalization and canonical label resolver
--
-- Description: PERSISTENT DDL, the undo of B-01_FUNCTIONS_course-text-normalize-and-resolve_v1.sql. B-01 creates two functions that did not exist before (the D2 v3 run of
-- 08/10/2026 captured no function of these names), so the rollback is a drop. Run it ONLY BEFORE any later file depends on them (B-02a, B-03, B-04a, B-05, B-06a, B-07: an
-- index expression, generated columns and triggers call normalize_course_text). The plain DROP (no CASCADE) deliberately FAILS if any object still depends on a function; in
-- that case roll back the dependent files first, in reverse order. Exact undo order for the whole stream: B-06a, B-05, B-04a, B-07, B-03, B-02a, B-01.

DROP FUNCTION IF EXISTS public.resolve_canonical_course_label(text);
DROP FUNCTION IF EXISTS public.normalize_course_text(text);
