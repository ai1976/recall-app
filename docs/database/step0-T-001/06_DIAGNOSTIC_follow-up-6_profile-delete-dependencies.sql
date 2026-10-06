-- Name: [DIAGNOSTIC] T-001 follow-up 6 - complete dependency inventory for deleting a user (auth.users and public.profiles): cascade closure, every foreign-key edge, triggers and rules, routines that delete profiles, who can delete
--
-- Description: READ-ONLY sixth follow-up. QA Round 52 (D3) requires a complete profile-delete foreign-key and dependency inventory before the
-- erasure question can go back through brief A's design gate; diagnostic 4 v4's J2d listed only the foreign keys that touch the three group tables.
-- Evidence so far: admin_delete_user_data (saved J2c) deletes the user's membership, course, review, card, deck and note rows and finally the
-- profiles row, and its audit entry says the deletion of the authentication user is "manual_required"; deleting a profile cascades to the group
-- tables (study_group_members.user_id, study_groups.created_by, content_group_shares.shared_by). This file shows EVERYTHING reached from the two
-- roots (auth.users and public.profiles), not only the group tables.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * P1: the roots found; the transitive closure of tables reached through ON DELETE CASCADE foreign keys, starting at the roots (table, depth,
--     and the chain of constraint names of one shortest path); and every foreign-key edge whose parent is a reached table, with all delete
--     actions (CASCADE, SET NULL, SET DEFAULT, NO ACTION, RESTRICT), the child columns, the update action, the full constraint definition, and
--     whether the child is itself reached by cascade. NO ACTION and RESTRICT edges are the ones that can BLOCK a deletion.
--   * P2: every user trigger (not internal, with its definition, function and enabled state) and every rewrite rule on the tables of interest:
--     reached tables, plus children of SET NULL and SET DEFAULT edges (those rows are updated by the delete). Cascaded deletes fire row triggers.
--   * P3: every plpgsql or sql routine in every non-system schema whose source deletes from profiles or auth.users, or mentions auth.users, with
--     owner, SECURITY DEFINER flag and a dynamic-SQL flag (no routine bodies are returned; admin_delete_user_data is already saved).
--   * P4: whether anon, authenticated and service_role hold the DELETE privilege on public.profiles and auth.users (the server's own answer), and the
--     row-level security policies on public.profiles that apply to DELETE or ALL.
-- Known blind spots, stated: foreign keys are read from pg_constraint (partitioned or inherited tables are not specially expanded); SQL assembled
-- from fragments is not seen by P3 text matching; deletion through the authentication service's own API or the dashboard is not visible in the
-- database and is described by the Founder, not measured here.
-- Four runs: P1, P2, P3 and P4. Each is one statement and returns one row with one jsonb column named `result`.
-- Privacy rule: no user-authored stored text and no person data is selected; only table, constraint, trigger, routine and role names, flags and
-- policy text.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Only
-- catalog functions and views are used (pg_class, pg_namespace, pg_constraint, pg_attribute, pg_trigger, pg_proc, pg_language, pg_rules,
-- pg_policies, pg_get_constraintdef, pg_get_triggerdef, pg_get_function_identity_arguments, pg_get_userbyid, has_table_privilege).
--
-- HOW TO RUN (four runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label (P1, P2, P3, P4), unchanged. Save that file as
-- docs/discussions/evidence/T-001_FU6-raw_<dd-mm-yyyy>.raw.txt and keep it untouched; the derived .json files are made from it by script.
-- An error is evidence: save the error text under the label, do not edit and re-run.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN P1. Cascade closure from auth.users and public.profiles, and every foreign-key edge from the reached tables
-- ============================================================================
WITH RECURSIVE rel AS (
  SELECT c.oid, n.nspname || '.' || c.relname AS qname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
),
roots AS (
  SELECT c.oid AS table_oid
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE (n.nspname, c.relname) IN (('auth', 'users'), ('public', 'profiles'))
    AND c.relkind IN ('r', 'p')
),
fk AS (
  SELECT con.oid AS con_oid, con.conname, con.conrelid AS child_oid, con.confrelid AS parent_oid,
         con.confdeltype, con.confupdtype, pg_get_constraintdef(con.oid) AS definition,
         (SELECT string_agg(a.attname, ',' ORDER BY k.ord)
          FROM unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum) AS child_columns
  FROM pg_constraint con
  WHERE con.contype = 'f'
),
walk AS (
  SELECT r.table_oid, 0 AS depth, ARRAY[r.table_oid] AS path, ARRAY[]::name[] AS via
  FROM roots r
  UNION ALL
  SELECT f.child_oid, w.depth + 1, w.path || f.child_oid, w.via || f.conname
  FROM walk w
  JOIN fk f ON f.parent_oid = w.table_oid
  WHERE f.confdeltype = 'c'
    AND NOT (f.child_oid = ANY (w.path))
),
reached AS (
  SELECT DISTINCT ON (table_oid) table_oid, depth, via
  FROM walk
  ORDER BY table_oid, depth, via
),
edges AS (
  SELECT f.*, pr.qname AS parent_name, cr.qname AS child_name,
         CASE f.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
                            WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
         CASE f.confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
                            WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_update,
         EXISTS (SELECT 1 FROM reached rc WHERE rc.table_oid = f.child_oid) AS child_reached_by_cascade
  FROM fk f
  JOIN rel pr ON pr.oid = f.parent_oid
  JOIN rel cr ON cr.oid = f.child_oid
  WHERE f.parent_oid IN (SELECT table_oid FROM reached)
),
interest AS (
  SELECT table_oid FROM reached
  UNION
  SELECT child_oid FROM edges WHERE confdeltype IN ('n', 'd')
)
SELECT jsonb_build_object(
  'run', 'P1',
  'roots', (SELECT jsonb_agg(rel.qname ORDER BY rel.qname) FROM roots JOIN rel ON rel.oid = roots.table_oid),
  'roots_found', (SELECT count(*) FROM roots),
  'cascade_reached_table_count', (SELECT count(*) FROM reached),
  'cascade_reached_tables', (SELECT jsonb_agg(jsonb_build_object('table', rel.qname, 'depth', rc.depth, 'via_constraints', rc.via)
                                              ORDER BY rc.depth, rel.qname)
                             FROM reached rc JOIN rel ON rel.oid = rc.table_oid),
  'edge_count', (SELECT count(*) FROM edges),
  'edges_from_reached_tables', (SELECT jsonb_agg(jsonb_build_object(
                                  'parent', parent_name, 'child', child_name, 'constraint', conname,
                                  'child_columns', child_columns, 'on_delete', on_delete, 'on_update', on_update,
                                  'child_reached_by_cascade', child_reached_by_cascade, 'definition', definition)
                                  ORDER BY parent_name, child_name, conname)
                                FROM edges)
) AS result;

-- ============================================================================
-- RUN P2. Triggers and rewrite rules on the reached tables and on the children of SET NULL and SET DEFAULT edges
-- ============================================================================
WITH RECURSIVE rel AS (
  SELECT c.oid, n.nspname || '.' || c.relname AS qname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
),
roots AS (
  SELECT c.oid AS table_oid
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE (n.nspname, c.relname) IN (('auth', 'users'), ('public', 'profiles'))
    AND c.relkind IN ('r', 'p')
),
fk AS (
  SELECT con.oid AS con_oid, con.conname, con.conrelid AS child_oid, con.confrelid AS parent_oid,
         con.confdeltype, con.confupdtype, pg_get_constraintdef(con.oid) AS definition,
         (SELECT string_agg(a.attname, ',' ORDER BY k.ord)
          FROM unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum) AS child_columns
  FROM pg_constraint con
  WHERE con.contype = 'f'
),
walk AS (
  SELECT r.table_oid, 0 AS depth, ARRAY[r.table_oid] AS path, ARRAY[]::name[] AS via
  FROM roots r
  UNION ALL
  SELECT f.child_oid, w.depth + 1, w.path || f.child_oid, w.via || f.conname
  FROM walk w
  JOIN fk f ON f.parent_oid = w.table_oid
  WHERE f.confdeltype = 'c'
    AND NOT (f.child_oid = ANY (w.path))
),
reached AS (
  SELECT DISTINCT ON (table_oid) table_oid, depth, via
  FROM walk
  ORDER BY table_oid, depth, via
),
edges AS (
  SELECT f.*, pr.qname AS parent_name, cr.qname AS child_name,
         CASE f.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
                            WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
         CASE f.confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
                            WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_update,
         EXISTS (SELECT 1 FROM reached rc WHERE rc.table_oid = f.child_oid) AS child_reached_by_cascade
  FROM fk f
  JOIN rel pr ON pr.oid = f.parent_oid
  JOIN rel cr ON cr.oid = f.child_oid
  WHERE f.parent_oid IN (SELECT table_oid FROM reached)
),
interest AS (
  SELECT table_oid FROM reached
  UNION
  SELECT child_oid FROM edges WHERE confdeltype IN ('n', 'd')
)
SELECT jsonb_build_object(
  'run', 'P2',
  'tables_of_interest_count', (SELECT count(*) FROM interest),
  'triggers', (SELECT jsonb_agg(jsonb_build_object(
                  'table', rel.qname, 'trigger', t.tgname, 'enabled_state', t.tgenabled,
                  'function', fn.nspname || '.' || p.proname, 'definition', pg_get_triggerdef(t.oid))
                  ORDER BY rel.qname, t.tgname)
               FROM pg_trigger t
               JOIN rel ON rel.oid = t.tgrelid
               JOIN pg_proc p ON p.oid = t.tgfoid
               JOIN pg_namespace fn ON fn.oid = p.pronamespace
               WHERE NOT t.tgisinternal
                 AND t.tgrelid IN (SELECT table_oid FROM interest)),
  'rules', (SELECT jsonb_agg(jsonb_build_object('table', ru.schemaname || '.' || ru.tablename, 'rule', ru.rulename)
                             ORDER BY ru.schemaname, ru.tablename, ru.rulename)
            FROM pg_rules ru
            WHERE (ru.schemaname || '.' || ru.tablename) IN
                  (SELECT rel.qname FROM rel WHERE rel.oid IN (SELECT table_oid FROM interest)))
) AS result;

-- ============================================================================
-- RUN P3. Routines that delete from profiles or auth.users, or mention auth.users (names and flags only)
-- ============================================================================
WITH s AS (
  SELECT n.nspname AS schema_name, p.proname AS name, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef, l.lanname AS language,
         (p.prosrc ~* 'delete[[:space:]]+from[[:space:]]+(only[[:space:]]+)?("?public"?[.])?"?profiles"?([^a-z0-9_]|$)') AS deletes_from_profiles,
         (p.prosrc ~* 'delete[[:space:]]+from[[:space:]]+(only[[:space:]]+)?"?auth"?[.]"?users"?([^a-z0-9_]|$)') AS deletes_from_auth_users,
         (p.prosrc ~* '(^|[^a-z0-9_])auth[.]"?users"?([^a-z0-9_]|$)') AS mentions_auth_users,
         (p.prosrc ~* '(^|[^a-z0-9_])execute([^a-z0-9_]|$)') AS has_dynamic_sql
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE l.lanname IN ('plpgsql', 'sql')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
)
SELECT jsonb_build_object(
  'run', 'P3',
  'routines_scanned', (SELECT count(*) FROM s),
  'routines', (SELECT jsonb_agg(jsonb_build_object(
                  'schema', schema_name, 'name', name, 'args', args, 'owner', owner, 'security_definer', prosecdef,
                  'language', language, 'deletes_from_profiles', deletes_from_profiles,
                  'deletes_from_auth_users', deletes_from_auth_users, 'mentions_auth_users', mentions_auth_users,
                  'has_dynamic_sql', has_dynamic_sql)
                  ORDER BY schema_name, name, args)
               FROM s
               WHERE deletes_from_profiles OR deletes_from_auth_users OR mentions_auth_users)
) AS result;

-- ============================================================================
-- RUN P4. DELETE privileges of the client roles on profiles and auth.users, and the DELETE policies on profiles
-- ============================================================================
SELECT jsonb_build_object(
  'run', 'P4',
  'delete_privileges', (SELECT jsonb_agg(jsonb_build_object(
                           'role', ro.rolename, 'table', ta.tablename,
                           'can_delete', has_table_privilege(ro.rolename, ta.tablename, 'DELETE'))
                           ORDER BY ta.tablename, ro.rolename)
                        FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS ro(rolename)
                        CROSS JOIN unnest(ARRAY['public.profiles', 'auth.users']) AS ta(tablename)),
  'profiles_delete_policies', (SELECT jsonb_agg(jsonb_build_object(
                                  'policy', pol.policyname, 'command', pol.cmd, 'roles', pol.roles, 'using', pol.qual)
                                  ORDER BY pol.policyname)
                               FROM pg_policies pol
                               WHERE pol.schemaname = 'public' AND pol.tablename = 'profiles'
                                 AND pol.cmd IN ('DELETE', 'ALL'))
) AS result;
