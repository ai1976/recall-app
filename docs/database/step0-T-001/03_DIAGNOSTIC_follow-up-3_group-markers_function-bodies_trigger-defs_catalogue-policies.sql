-- Name: [DIAGNOSTIC] T-001 follow-up 3 (v1) - batch group markers, live function bodies, trigger definitions, catalogue-table policies
--
-- Description: READ-ONLY third follow-up to docs/database/step0-T-001/01_DIAGNOSTIC_follow-up_privileges_enforcement_and_gaps.sql
-- (run 04/10/2026, hash 2087a3d964dc) and 02_DIAGNOSTIC_follow-up-2_... (run 04/10/2026, hash 463190a91f88).
-- It measures the facts that design briefs A and B still list as open, so that no brief statement about the live
-- database has to rest on a repo copy. Four runs, each one statement returning one row with one json column named `result`:
--   H1  Study groups counted by (is_batch_group, group_type, archived or not). Brief A treats a group as batch-shaped
--       when EITHER marker says batch (the live join_group_by_token does the same, RUN 1A); this shows whether any row
--       has the two markers disagreeing, which would need a data fix before the step 0 policies are tightened.
--   H2  Live bodies of create_batch_group, archive_batch_group, restore_batch_group and get_study_time_stats (name, argument
--       list, security definer flag, full definition). Brief A relies on repo copies of the first three.
--   H3  The definition (pg_get_triggerdef) of every non-internal trigger on a public table, with its table and enabled flag.
--       (Diagnostic 2, run G4, gave only names, enabled flags and functions, so timing and event columns were not shown.)
--   H4  Every row-level-security policy on disciplines, subjects and topics (command, name, roles, using, check).
--       Diagnostic 2 showed that anon and authenticated hold all table privileges on these three tables; the policies decide
--       whether a client can actually write them (the admin page BulkUploadTopics.jsx writes them from the browser).
-- Privacy rule: no user-authored stored text is returned as a literal. H1 buckets group_type to its three allowed values plus
-- 'unexpected_other' and returns counts only; H2 to H4 return function source, trigger and policy text (catalog text).
-- No name, email, phone or identifier is selected.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, or
-- application-function call (only the catalog functions pg_get_functiondef, pg_get_triggerdef,
-- pg_get_function_identity_arguments).
--
-- HOW TO RUN (four runs: H1, H2, H3, H4): select the text of ONE run (from its first line to its closing semicolon), click Run,
-- copy the single result cell, and keep it unchanged. Save each result as an unedited raw export under docs/discussions/evidence/
-- named T-001_FU3-<run>_<dd-mm-yyyy>.json. An error is evidence: save the error text, do not edit and re-run.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN H1. Study groups by (is_batch_group, group_type, archived or not) (counts only)
-- ============================================================================
SELECT jsonb_build_object(
  'groups_by_markers', (SELECT jsonb_agg(jsonb_build_object(
          'is_batch_group', ib, 'group_type', gt, 'archived', ar, 'groups', n
        ) ORDER BY n DESC)
        FROM (SELECT sg.is_batch_group AS ib,
                     CASE WHEN sg.group_type IN ('batch', 'system_course', 'custom') THEN sg.group_type ELSE 'unexpected_other' END AS gt,
                     (sg.archived_at IS NOT NULL) AS ar,
                     count(*) AS n
              FROM public.study_groups sg
              GROUP BY 1, 2, 3) s),
  'groups_total', (SELECT count(*) FROM public.study_groups)
) AS result;

-- ============================================================================
-- RUN H2. Live bodies of create_batch_group, archive_batch_group, restore_batch_group, get_study_time_stats
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'name', p.proname,
         'args', pg_get_function_identity_arguments(p.oid),
         'security_definer', p.prosecdef,
         'definition', pg_get_functiondef(p.oid)
       ) ORDER BY p.proname, pg_get_function_identity_arguments(p.oid)) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('create_batch_group', 'archive_batch_group', 'restore_batch_group', 'get_study_time_stats');

-- ============================================================================
-- RUN H3. Definition of every non-internal trigger on a public table
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'table', c.relname,
         'trigger', tg.tgname,
         'enabled', tg.tgenabled::text,
         'definition', pg_get_triggerdef(tg.oid)
       ) ORDER BY c.relname, tg.tgname) AS result
FROM pg_trigger tg
JOIN pg_class c ON c.oid = tg.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND NOT tg.tgisinternal;

-- ============================================================================
-- RUN H4. Policies on disciplines, subjects and topics
-- ============================================================================
SELECT jsonb_build_object(
  'policies', (SELECT jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', policyname, 'cmd', cmd, 'permissive', permissive,
        'roles', roles, 'using', qual, 'check', with_check
      ) ORDER BY tablename, policyname)
      FROM pg_policies
      WHERE schemaname = 'public' AND tablename IN ('disciplines', 'subjects', 'topics')),
  'policy_count_by_table', (SELECT jsonb_object_agg(tablename, n)
      FROM (SELECT tablename, count(*) AS n FROM pg_policies
            WHERE schemaname = 'public' AND tablename IN ('disciplines', 'subjects', 'topics')
            GROUP BY tablename) s)
) AS result;
