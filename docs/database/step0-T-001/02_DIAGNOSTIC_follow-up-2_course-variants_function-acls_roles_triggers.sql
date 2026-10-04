-- Name: [DIAGNOSTIC] T-001 follow-up 2 (v1) - course-name variants, function EXECUTE ACLs, membership roles, triggers and foreign keys, server version
--
-- Description: READ-ONLY second follow-up to docs/database/step0-T-001/01_DIAGNOSTIC_follow-up_privileges_enforcement_and_gaps.sql
-- (run 04/10/2026, hash 2087a3d964dc). It measures what that run could not, as needed by design briefs A and B.
-- Five runs, each one statement returning one row with one json column named `result`:
--   G1  Course-name variants (brief B 5.3b). For each of the eight text columns that store a course name
--       (profiles.course_level, notes.target_course, flashcards.target_course, flashcard_decks.target_course,
--       access_requests.course, my_cards_enrollment.archived_course, study_groups.batch_course,
--       study_groups.linked_course): the number of values that are null or blank, EXACTLY a canonical name,
--       a VARIANT of a canonical name (equal under trim, whitespace collapse and lower-casing, but not exact),
--       or other text. Canonical names = every disciplines.name (active or not) plus the six CMA and CS labels of
--       the profile CHECK. Counts only; no value is selected.
--   G2  Function EXECUTE ACLs (not measured by F1). For the functions named in briefs A and B: security definer,
--       whether a search_path is set, and EXECUTE for anon, authenticated and PUBLIC. Also the NAMES of every
--       public function that anon can execute.
--   G3  Membership roles: study_group_members by batch or not, platform role, membership role and membership status
--       (counts; roles bucketed to admin, member, unexpected_other). Shows who counts as a group admin.
--   G4  disciplines, subjects and topics: effective table privileges for anon and authenticated; non-internal
--       triggers (table, trigger name, enabled flag, function name) on disciplines, subjects, profiles,
--       access_requests, study_group_members and study_groups; indexes on disciplines, subjects, access_requests,
--       study_groups and study_group_members; and every foreign key that references disciplines or subjects
--       (with its definition, which shows the delete action).
--   G5  PostgreSQL server version (decides whether NULLS NOT DISTINCT is available).
-- Privacy rule: no user-authored stored text is returned as a literal. Values are bucketed to expected classes or
-- counted. Function, table, column, trigger, index and constraint names and definitions are catalog text.
-- No name, email, phone or identifier is selected.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, or
-- application-function call (only the catalog functions pg_get_*, has_*_privilege, aclexplode, acldefault,
-- current_setting).
--
-- HOW TO RUN (five runs: G1, G2, G3, G4, G5): select the text of ONE run (from its first line to its closing
-- semicolon), click Run, copy the single result cell, and keep it unchanged. Save each result as an unedited raw
-- export under docs/discussions/evidence/ named T-001_FU2-<run>_<dd-mm-yyyy>.json. An error is evidence: save the
-- error text, do not edit and re-run.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN G1. Course-name variants in the eight dependent text columns (counts only)
-- ============================================================================
WITH canon(name) AS (
  SELECT d.name FROM public.disciplines d
  UNION
  SELECT x FROM (VALUES ('CMA Foundation'), ('CMA Intermediate'), ('CMA Final'),
                        ('CS Foundation'), ('CS Executive'), ('CS Professional')) v(x)
),
cn AS (
  SELECT name, lower(regexp_replace(btrim(name), '\s+', ' ', 'g')) AS norm FROM canon
),
vals AS (
  SELECT 'profiles.course_level' AS col, course_level AS val FROM public.profiles
  UNION ALL SELECT 'notes.target_course', target_course FROM public.notes
  UNION ALL SELECT 'flashcards.target_course', target_course FROM public.flashcards
  UNION ALL SELECT 'flashcard_decks.target_course', target_course FROM public.flashcard_decks
  UNION ALL SELECT 'access_requests.course', course FROM public.access_requests
  UNION ALL SELECT 'my_cards_enrollment.archived_course', archived_course FROM public.my_cards_enrollment
  UNION ALL SELECT 'study_groups.batch_course', batch_course FROM public.study_groups
  UNION ALL SELECT 'study_groups.linked_course', linked_course FROM public.study_groups
),
cls AS (
  SELECT v.col,
         CASE WHEN v.val IS NULL OR btrim(v.val) = '' THEN 'null_or_blank'
              WHEN EXISTS (SELECT 1 FROM cn WHERE cn.name = v.val) THEN 'exact_canonical'
              WHEN EXISTS (SELECT 1 FROM cn WHERE cn.norm = lower(regexp_replace(btrim(v.val), '\s+', ' ', 'g'))) THEN 'variant_of_canonical'
              ELSE 'other_text' END AS cls
  FROM vals v
),
agg AS (
  SELECT col, cls, count(*) AS n FROM cls GROUP BY col, cls
)
SELECT jsonb_build_object(
  'by_column', (SELECT jsonb_object_agg(col, o)
        FROM (SELECT col, jsonb_object_agg(cls, n) AS o FROM agg GROUP BY col) b),
  'canonical_names_count', (SELECT count(*) FROM canon)
) AS result;

-- ============================================================================
-- RUN G2. Function EXECUTE ACLs: named functions, and the names of every public function anon can execute
-- ============================================================================
WITH f AS (
  SELECT p.oid, p.proname, p.prosecdef, p.proconfig, p.proacl, p.proowner,
         pg_get_function_identity_arguments(p.oid) AS args
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
),
acl AS (
  SELECT f.*,
         has_function_privilege('anon', f.oid, 'EXECUTE') AS anon_execute,
         has_function_privilege('authenticated', f.oid, 'EXECUTE') AS authenticated_execute,
         EXISTS (SELECT 1 FROM aclexplode(COALESCE(f.proacl, acldefault('f', f.proowner))) a
                 WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE') AS public_execute
  FROM f
)
SELECT jsonb_build_object(
  'named_functions', (SELECT jsonb_agg(jsonb_build_object(
        'name', proname, 'args', args, 'security_definer', prosecdef,
        'search_path_set', (proconfig IS NOT NULL AND EXISTS (SELECT 1 FROM unnest(proconfig) c WHERE c LIKE 'search_path=%')),
        'anon_execute', anon_execute, 'authenticated_execute', authenticated_execute, 'public_execute', public_execute
      ) ORDER BY proname, args)
      FROM acl
      WHERE proname IN ('join_group_by_token', 'get_group_preview', 'submit_access_request', 'link_access_request',
                        'admin_grant_access', 'approve_batch_join_request', 'reject_batch_join_request',
                        'admin_bulk_resolve_batch_requests', 'enroll_user_in_batch_group', 'admin_bulk_add_to_batch',
                        'remove_group_member', 'leave_group', 'archive_batch_group', 'restore_batch_group',
                        'search_users_for_group_invite', 'admin_read_profiles', 'get_my_cards',
                        'get_due_forecast', 'get_study_queue', 'is_admin', 'is_super_admin')),
  'public_functions_total', (SELECT count(*) FROM acl),
  'public_functions_executable_by_anon_names', (SELECT jsonb_agg(proname || '(' || args || ')' ORDER BY proname, args)
        FROM acl WHERE anon_execute)
) AS result;

-- ============================================================================
-- RUN G3. Membership roles (counts only): who counts as a group admin
-- ============================================================================
SELECT jsonb_build_object(
  'memberships_by_batch_platform_role_membership_role_and_status', (SELECT jsonb_agg(jsonb_build_object(
          'is_batch_group', ib, 'platform_role', pr, 'membership_role', mr, 'membership_status', ms, 'rows', n
        ) ORDER BY n DESC)
        FROM (SELECT sg.is_batch_group AS ib,
                     CASE WHEN p.role IN ('student', 'professor', 'admin', 'super_admin') THEN p.role ELSE 'unexpected_other' END AS pr,
                     CASE WHEN m.role IN ('admin', 'member') THEN m.role ELSE 'unexpected_other' END AS mr,
                     CASE WHEN m.status IN ('invited', 'active', 'requested', 'closed') THEN m.status ELSE 'unexpected_other' END AS ms,
                     count(*) AS n
              FROM public.study_group_members m
              JOIN public.study_groups sg ON sg.id = m.group_id
              JOIN public.profiles p ON p.id = m.user_id
              GROUP BY 1, 2, 3, 4) s)
) AS result;

-- ============================================================================
-- RUN G4. disciplines, subjects, topics: privileges; triggers; indexes; foreign keys referencing disciplines or subjects
-- ============================================================================
SELECT jsonb_build_object(
  'table_privileges', (SELECT jsonb_agg(jsonb_build_object(
        'table', t.tbl, 'role', r.role_name, 'privilege', p.priv,
        'granted', has_table_privilege(r.role_name, format('public.%I', t.tbl), p.priv)
      ) ORDER BY t.tbl, r.role_name, p.priv)
      FROM (VALUES ('disciplines'), ('subjects'), ('topics')) t(tbl)
      CROSS JOIN (VALUES ('anon'), ('authenticated')) r(role_name)
      CROSS JOIN (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) p(priv)),
  'triggers', (SELECT jsonb_agg(jsonb_build_object(
        'table', c.relname, 'trigger', tg.tgname, 'enabled', tg.tgenabled::text, 'function', pr.proname
      ) ORDER BY c.relname, tg.tgname)
      FROM pg_trigger tg
      JOIN pg_class c ON c.oid = tg.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_proc pr ON pr.oid = tg.tgfoid
      WHERE n.nspname = 'public' AND NOT tg.tgisinternal
        AND c.relname IN ('disciplines', 'subjects', 'profiles', 'access_requests', 'study_group_members', 'study_groups')),
  'indexes', (SELECT jsonb_agg(jsonb_build_object(
        'table', i.tablename, 'index', i.indexname, 'definition', i.indexdef
      ) ORDER BY i.tablename, i.indexname)
      FROM pg_indexes i
      WHERE i.schemaname = 'public'
        AND i.tablename IN ('disciplines', 'subjects', 'access_requests', 'study_groups', 'study_group_members')),
  'foreign_keys_referencing_disciplines_or_subjects', (SELECT jsonb_agg(jsonb_build_object(
        'table', c.relname, 'constraint', k.conname, 'definition', pg_get_constraintdef(k.oid)
      ) ORDER BY c.relname, k.conname)
      FROM pg_constraint k
      JOIN pg_class c ON c.oid = k.conrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND k.contype = 'f'
        AND k.confrelid IN ('public.disciplines'::regclass, 'public.subjects'::regclass))
) AS result;

-- ============================================================================
-- RUN G5. PostgreSQL server version
-- ============================================================================
SELECT jsonb_build_object(
  'server_version', current_setting('server_version'),
  'server_version_num', current_setting('server_version_num')
) AS result;
