-- Name: [DIAGNOSTIC] get_study_heatmap live definition, grants and dependents (pre-flight for 03)
-- Description: READ ONLY. Run BEFORE 03_FUNCTIONS. Confirms the live function still matches the
--   08_FUNCTIONS_read_idor_guards_group_a.sql version this migration replaces (CLAUDE.md: never
--   assume from docs — query the catalog), shows its ACL, and lists every other function or view that
--   references it (DROP + CREATE would break a dependent). Paste all three result sets back.

-- 1. Live definition
SELECT pg_get_functiondef(p.oid) AS live_definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_study_heatmap';

-- 2. Overloads + ACL (expect exactly one row; expect authenticated=X, no anon / PUBLIC)
SELECT p.oid::regprocedure AS signature, p.proacl AS acl
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_study_heatmap';

-- 3. Anything else in public that mentions it (function bodies + views). Expect zero rows.
SELECT 'function' AS kind, p.proname AS name
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname <> 'get_study_heatmap' AND p.prosrc ILIKE '%get_study_heatmap%'
UNION ALL
SELECT 'view', c.relname
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('v','m')
  AND pg_get_viewdef(c.oid) ILIKE '%get_study_heatmap%';
