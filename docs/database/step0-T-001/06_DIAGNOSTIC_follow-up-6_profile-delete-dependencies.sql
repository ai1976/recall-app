-- Name: [DIAGNOSTIC] T-001 follow-up 6 (v2) - complete dependency inventory for deleting a user (auth.users and public.profiles): cascade closure, every foreign-key edge, triggers with their function definitions and call closure, rules with definitions, delete routines and every dynamic-SQL candidate, access (privileges and RLS) on both roots, partition and inheritance topology
--
-- Description: READ-ONLY sixth follow-up, revised after QA Round 56 (v2; supersedes v1 2e567589e313, which was never authorized or run). QA Round 52 (D3)
-- requires a complete profile-delete foreign-key and dependency inventory before the erasure question can go back through brief A's design gate;
-- diagnostic 4 v4's J2d listed only the foreign keys that touch the three group tables.
-- Evidence so far: admin_delete_user_data (saved J2c) deletes the user's membership, course, review, card, deck and note rows and finally the
-- profiles row, and its audit entry says the deletion of the authentication user is "manual_required"; deleting a profile cascades to the group
-- tables (study_group_members.user_id, study_groups.created_by, content_group_shares.shared_by). This file shows EVERYTHING reached from the two
-- roots (auth.users and public.profiles), not only the group tables.
-- What changed from v1 (each answers a QA Round 56 blocking finding):
--   * Blocking 3. P2 now returns the full definition of every rewrite rule (pg_rules.definition) and, for each trigger, its function's identity
--     arguments, language and definer flag; the new P3 returns the definition and properties of every trigger function (pg_get_functiondef); the new
--     P4 returns a conservative, recursive, fail-closed call inventory starting at those trigger functions: every routine that a trigger function can
--     call, directly or through other routines (a name followed by an opening parenthesis anywhere in a readable source, schema-qualified or not, all
--     overloads: a deliberate over-approximation), with flags for dynamic SQL (EXECUTE), a source that is not readable as plpgsql or sql, and a mention of
--     INSERT, UPDATE, DELETE, MERGE or TRUNCATE, and counts of each under fail_closed_leads. A non-zero count is a positive lead, not a finding of harm.
--   * Blocking 4. The new P7 returns the partition and inheritance topology of the tables of interest (kind, partition bound, every pg_inherits row),
--     and P1 reports it as a fail-closed condition (unsupported_topology_present; inherited foreign-key edges are counted and flagged). P5's quoted-name
--     expression now matches "auth"."users" and every other quoting of the schema and table, and P5 returns EVERY routine that contains dynamic SQL
--     (dynamic_sql_routines_all) with word-mention flags for profiles, users and delete, and whether it is also a literal match, instead of only those
--     that already matched the literal expressions.
--   * Blocking 5. The access run (now P6) reports, for BOTH roots, the table kind, owner, row-level-security enabled and forced flags, the DELETE
--     privilege of anon, authenticated and service_role (has_table_privilege on the table's own oid), the number of policies of every command, and
--     every policy for DELETE or ALL, for public.profiles AND auth.users. P1 and P6 each report roots_expected 2, roots_found and roots_complete, and
--     P1 reports unsupported topology, as explicit fail-closed conditions: roots_complete must be true and unsupported_topology_present must be false
--     for the inventory to be treated as complete.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * P1: the fail-closed conditions; the roots; the transitive closure of tables reached through ON DELETE CASCADE foreign keys starting at the roots
--     (table, depth and the chain of constraint names of one shortest path); and every foreign-key edge whose parent is a reached table, with every
--     delete action (CASCADE, SET NULL, SET DEFAULT, NO ACTION, RESTRICT), the child columns, the update action, whether the constraint is inherited,
--     the full definition, and whether the child is itself reached by cascade. NO ACTION and RESTRICT edges can BLOCK a deletion.
--   * P2: every user trigger (not internal; definition, function identity, language, definer flag, enabled state) and every rewrite rule (with its
--     definition) on the tables of interest: the reached tables, plus children of SET NULL and SET DEFAULT edges (those rows are updated by the
--     delete). Cascaded deletes fire row triggers.
--   * P3: the definition and properties of every function that those triggers call.
--   * P4: the recursive call inventory from those trigger functions (identities and flags only, no bodies).
--   * P5: every plpgsql or sql routine whose source deletes from profiles or auth.users, or mentions auth.users, and every routine with dynamic SQL
--     (identities and flags only; admin_delete_user_data is already saved).
--   * P6: access to both roots (see Blocking 5).
--   * P7: partition and inheritance topology (see Blocking 4).
-- Known blind spots, stated: SQL assembled from fragments without the word EXECUTE is not seen by text matching (P5 returns every EXECUTE routine
-- and P4 flags them, so dynamic deletion by this route is a visible lead); deletion initiated inside the authentication service (its API or the
-- dashboard) is not visible in the database and remains an explicit Founder and platform assumption, never a database-verified fact; behaviour of
-- compiled (C-language) trigger functions is flagged as not readable, not inspected.
-- Seven runs: P1 to P7. Each is one statement and returns one row with one jsonb column named `result`.
-- Privacy rule: no user-authored stored text and no person data is selected; only table, constraint, trigger, routine and role names, flags, policy
-- text and trigger-function definitions (catalog text).
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Only
-- catalog functions and views are used (pg_class, pg_namespace, pg_constraint, pg_attribute, pg_inherits, pg_trigger, pg_proc, pg_language, pg_rules,
-- pg_policies, pg_get_constraintdef, pg_get_triggerdef, pg_get_functiondef, pg_get_function_identity_arguments, pg_get_userbyid, pg_get_expr,
-- has_table_privilege).
--
-- HOW TO RUN (seven runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label (P1 to P7), unchanged. Save that file as
-- docs/discussions/evidence/T-001_FU6-raw_<dd-mm-yyyy>.raw.txt and keep it untouched; the derived .json files are made from it by script.
-- An error is evidence: save the error text under the label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN P1. Fail-closed conditions, cascade closure from auth.users and public.profiles, and every foreign-key edge from the reached tables
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
  SELECT con.oid AS con_oid, con.conname, con.conparentid, con.conrelid AS child_oid, con.confrelid AS parent_oid,
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
),
tf AS (
  SELECT DISTINCT t.tgfoid AS proc_oid
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND t.tgrelid IN (SELECT table_oid FROM interest)
)
SELECT jsonb_build_object(
  'run', 'P1',
  'fail_closed_conditions', jsonb_build_object(
      'roots_expected', 2,
      'roots_found', (SELECT count(*) FROM roots),
      'roots_complete', (SELECT count(*) FROM roots) = 2,
      'tables_of_interest_partitioned_or_partitions',
          (SELECT count(*) FROM pg_class c
           WHERE c.oid IN (SELECT table_oid FROM interest) AND (c.relkind = 'p' OR c.relispartition)),
      'tables_of_interest_in_inheritance',
          (SELECT count(*) FROM pg_inherits i
           WHERE i.inhrelid IN (SELECT table_oid FROM interest) OR i.inhparent IN (SELECT table_oid FROM interest)),
      'inherited_foreign_key_edges', (SELECT count(*) FROM edges WHERE conparentid <> 0),
      'unsupported_topology_present',
          ((SELECT count(*) FROM pg_class c
            WHERE c.oid IN (SELECT table_oid FROM interest) AND (c.relkind = 'p' OR c.relispartition))
           + (SELECT count(*) FROM pg_inherits i
              WHERE i.inhrelid IN (SELECT table_oid FROM interest) OR i.inhparent IN (SELECT table_oid FROM interest))
           + (SELECT count(*) FROM edges WHERE conparentid <> 0)) > 0),
  'roots', (SELECT jsonb_agg(rel.qname ORDER BY rel.qname) FROM roots JOIN rel ON rel.oid = roots.table_oid),
  'cascade_reached_table_count', (SELECT count(*) FROM reached),
  'cascade_reached_tables', (SELECT jsonb_agg(jsonb_build_object('table', rel.qname, 'depth', rc.depth, 'via_constraints', rc.via)
                                              ORDER BY rc.depth, rel.qname)
                             FROM reached rc JOIN rel ON rel.oid = rc.table_oid),
  'edge_count', (SELECT count(*) FROM edges),
  'edges_from_reached_tables', (SELECT jsonb_agg(jsonb_build_object(
                                  'parent', parent_name, 'child', child_name, 'constraint', conname,
                                  'child_columns', child_columns, 'on_delete', on_delete, 'on_update', on_update,
                                  'child_reached_by_cascade', child_reached_by_cascade,
                                  'inherited_constraint', conparentid <> 0, 'definition', definition)
                                  ORDER BY parent_name, child_name, conname)
                                FROM edges)
) AS result;

-- ============================================================================
-- RUN P2. Triggers (with function identity) and rewrite rules (with definitions) on the reached tables and on the children of SET NULL and SET DEFAULT edges
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
  SELECT con.oid AS con_oid, con.conname, con.conparentid, con.conrelid AS child_oid, con.confrelid AS parent_oid,
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
),
tf AS (
  SELECT DISTINCT t.tgfoid AS proc_oid
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND t.tgrelid IN (SELECT table_oid FROM interest)
)
SELECT jsonb_build_object(
  'run', 'P2',
  'tables_of_interest_count', (SELECT count(*) FROM interest),
  'trigger_count', (SELECT count(*) FROM pg_trigger t
                    WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)),
  'triggers', (SELECT jsonb_agg(jsonb_build_object(
                  'table', rel.qname, 'trigger', t.tgname, 'enabled_state', t.tgenabled,
                  'function', fn.nspname || '.' || p.proname,
                  'function_args', pg_get_function_identity_arguments(p.oid),
                  'function_language', l.lanname, 'function_security_definer', p.prosecdef,
                  'definition', pg_get_triggerdef(t.oid))
                  ORDER BY rel.qname, t.tgname)
               FROM pg_trigger t
               JOIN rel ON rel.oid = t.tgrelid
               JOIN pg_proc p ON p.oid = t.tgfoid
               JOIN pg_namespace fn ON fn.oid = p.pronamespace
               JOIN pg_language l ON l.oid = p.prolang
               WHERE NOT t.tgisinternal
                 AND t.tgrelid IN (SELECT table_oid FROM interest)),
  'rule_count', (SELECT count(*) FROM pg_rules ru
                 WHERE (ru.schemaname || '.' || ru.tablename) IN
                       (SELECT rel.qname FROM rel WHERE rel.oid IN (SELECT table_oid FROM interest))),
  'rules', (SELECT jsonb_agg(jsonb_build_object('table', ru.schemaname || '.' || ru.tablename, 'rule', ru.rulename,
                                                'definition', ru.definition)
                             ORDER BY ru.schemaname, ru.tablename, ru.rulename)
            FROM pg_rules ru
            WHERE (ru.schemaname || '.' || ru.tablename) IN
                  (SELECT rel.qname FROM rel WHERE rel.oid IN (SELECT table_oid FROM interest)))
) AS result;

-- ============================================================================
-- RUN P3. Definitions and properties of every function that those triggers call
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
  SELECT con.oid AS con_oid, con.conname, con.conparentid, con.conrelid AS child_oid, con.confrelid AS parent_oid,
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
),
tf AS (
  SELECT DISTINCT t.tgfoid AS proc_oid
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND t.tgrelid IN (SELECT table_oid FROM interest)
)
SELECT jsonb_build_object(
  'run', 'P3',
  'trigger_function_count', (SELECT count(*) FROM tf),
  'functions', (SELECT jsonb_agg(jsonb_build_object(
                   'schema', n.nspname, 'name', p.proname, 'args', pg_get_function_identity_arguments(p.oid),
                   'language', l.lanname, 'owner', pg_get_userbyid(p.proowner), 'security_definer', p.prosecdef,
                   'config', p.proconfig, 'definition', pg_get_functiondef(p.oid))
                   ORDER BY n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
                FROM pg_proc p
                JOIN pg_namespace n ON n.oid = p.pronamespace
                JOIN pg_language l ON l.oid = p.prolang
                WHERE p.oid IN (SELECT proc_oid FROM tf))
) AS result;

-- ============================================================================
-- RUN P4. Recursive, fail-closed call inventory starting at those trigger functions (identities and flags only)
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
  SELECT con.oid AS con_oid, con.conname, con.conparentid, con.conrelid AS child_oid, con.confrelid AS parent_oid,
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
),
tf AS (
  SELECT DISTINCT t.tgfoid AS proc_oid
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND t.tgrelid IN (SELECT table_oid FROM interest)
)
, routine AS (
  SELECT p.oid AS proc_oid, n.nspname AS schema_name, p.proname AS name,
         pg_get_function_identity_arguments(p.oid) AS args, l.lanname AS language,
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
),
calls AS (
  -- Conservative over-approximation: a readable routine calls any routine (every overload) whose name followed by an opening
  -- parenthesis appears anywhere in its source, schema-qualified or not.
  SELECT caller.proc_oid AS caller_oid, callee.proc_oid AS callee_oid
  FROM routine caller
  JOIN routine callee ON callee.proc_oid <> caller.proc_oid
  WHERE caller.language IN ('plpgsql', 'sql')
    AND (strpos(lower(caller.prosrc), lower(callee.name) || '(') > 0
         OR strpos(lower(caller.prosrc), lower(callee.name) || ' (') > 0)
),
tclos(proc_oid) AS (
  SELECT proc_oid FROM tf
  UNION
  SELECT c.callee_oid FROM tclos tc JOIN calls c ON c.caller_oid = tc.proc_oid
),
m AS (
  SELECT ro.*,
         (ro.proc_oid IN (SELECT proc_oid FROM tf)) AS is_trigger_function_of_interest,
         (ro.language IN ('plpgsql', 'sql')) AS readable,
         (ro.prosrc ~* '(^|[^a-z0-9_])execute([^a-z0-9_]|$)') AS has_dynamic_sql,
         (ro.prosrc ~* '(^|[^a-z0-9_])(insert[[:space:]]+into|delete[[:space:]]+from|merge[[:space:]]+into|truncate)([^a-z0-9_]|$)'
          OR ro.prosrc ~* '(^|[^a-z0-9_])update[[:space:]]+(only[[:space:]]+)?["a-z_]') AS mentions_dml
  FROM routine ro
  WHERE ro.proc_oid IN (SELECT proc_oid FROM tclos)
)
SELECT jsonb_build_object(
  'run', 'P4',
  'trigger_function_roots', (SELECT count(*) FROM tf),
  'closure_member_count', (SELECT count(*) FROM m),
  'fail_closed_leads', jsonb_build_object(
      'closure_members_with_dynamic_sql', (SELECT count(*) FROM m WHERE has_dynamic_sql),
      'closure_members_not_readable_as_plpgsql_or_sql', (SELECT count(*) FROM m WHERE NOT readable),
      'closure_members_mentioning_dml', (SELECT count(*) FROM m WHERE mentions_dml)),
  'closure', (SELECT jsonb_agg(jsonb_build_object(
                  'schema', schema_name, 'name', name, 'args', args, 'language', language, 'owner', owner,
                  'security_definer', prosecdef, 'is_trigger_function_of_interest', is_trigger_function_of_interest,
                  'readable', readable, 'has_dynamic_sql', has_dynamic_sql, 'mentions_dml', mentions_dml)
                  ORDER BY schema_name, name, args)
              FROM m)
) AS result;

-- ============================================================================
-- RUN P5. Routines that delete from profiles or auth.users or mention auth.users, and every routine with dynamic SQL (identities and flags only)
-- ============================================================================
WITH s AS (
  SELECT n.nspname AS schema_name, p.proname AS name, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef, l.lanname AS language,
         (p.prosrc ~* 'delete[[:space:]]+from[[:space:]]+(only[[:space:]]+)?("?public"?[.])?"?profiles"?([^a-z0-9_]|$)') AS deletes_from_profiles,
         (p.prosrc ~* 'delete[[:space:]]+from[[:space:]]+(only[[:space:]]+)?"?auth"?[.]"?users"?([^a-z0-9_]|$)') AS deletes_from_auth_users,
         (p.prosrc ~* '(^|[^a-z0-9_])"?auth"?[.]"?users"?([^a-z0-9_]|$)') AS mentions_auth_users,
         (p.prosrc ~* '(^|[^a-z0-9_])execute([^a-z0-9_]|$)') AS has_dynamic_sql,
         (strpos(lower(p.prosrc), 'profiles') > 0) AS mentions_profiles_word,
         (strpos(lower(p.prosrc), 'users') > 0) AS mentions_users_word,
         (strpos(lower(p.prosrc), 'delete') > 0) AS mentions_delete_word
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE l.lanname IN ('plpgsql', 'sql')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
)
SELECT jsonb_build_object(
  'run', 'P5',
  'routines_scanned', (SELECT count(*) FROM s),
  'routines_with_dynamic_sql', (SELECT count(*) FROM s WHERE has_dynamic_sql),
  'literal_match_routines', (SELECT jsonb_agg(jsonb_build_object(
                  'schema', schema_name, 'name', name, 'args', args, 'owner', owner, 'security_definer', prosecdef,
                  'language', language, 'deletes_from_profiles', deletes_from_profiles,
                  'deletes_from_auth_users', deletes_from_auth_users, 'mentions_auth_users', mentions_auth_users,
                  'has_dynamic_sql', has_dynamic_sql)
                  ORDER BY schema_name, name, args)
               FROM s
               WHERE deletes_from_profiles OR deletes_from_auth_users OR mentions_auth_users),
  'dynamic_sql_routines_all', (SELECT jsonb_agg(jsonb_build_object(
                  'schema', schema_name, 'name', name, 'args', args, 'owner', owner, 'security_definer', prosecdef,
                  'language', language, 'mentions_profiles_word', mentions_profiles_word,
                  'mentions_users_word', mentions_users_word, 'mentions_delete_word', mentions_delete_word,
                  'also_literal_match', (deletes_from_profiles OR deletes_from_auth_users OR mentions_auth_users))
                  ORDER BY schema_name, name, args)
               FROM s
               WHERE has_dynamic_sql)
) AS result;

-- ============================================================================
-- RUN P6. Access to both roots: kind, owner, RLS enabled and forced, DELETE privileges of the client roles, policies
-- ============================================================================
WITH rt AS (
  SELECT c.oid, n.nspname AS schema_name, c.relname AS table_name, n.nspname || '.' || c.relname AS qname,
         c.relkind, c.relrowsecurity, c.relforcerowsecurity, pg_get_userbyid(c.relowner) AS owner
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE (n.nspname, c.relname) IN (('auth', 'users'), ('public', 'profiles'))
)
SELECT jsonb_build_object(
  'run', 'P6',
  'roots_expected', 2,
  'roots_found', (SELECT count(*) FROM rt),
  'roots_complete', (SELECT count(*) FROM rt) = 2,
  'roots', (SELECT jsonb_agg(jsonb_build_object(
               'table', qname, 'kind', relkind, 'owner', owner,
               'rls_enabled', relrowsecurity, 'rls_forced', relforcerowsecurity)
               ORDER BY qname)
            FROM rt),
  'delete_privileges', (SELECT jsonb_agg(jsonb_build_object(
                           'role', ro.rolename, 'table', rt.qname,
                           'can_delete', has_table_privilege(ro.rolename, rt.oid, 'DELETE'))
                           ORDER BY rt.qname, ro.rolename)
                        FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) AS ro(rolename)
                        CROSS JOIN rt),
  'policy_counts', (SELECT jsonb_agg(jsonb_build_object('table', rt.qname,
                       'policies_all_commands', (SELECT count(*) FROM pg_policies pol
                                                 WHERE pol.schemaname = rt.schema_name AND pol.tablename = rt.table_name))
                       ORDER BY rt.qname)
                    FROM rt),
  'delete_or_all_policies', (SELECT jsonb_agg(jsonb_build_object(
                                'table', pol.schemaname || '.' || pol.tablename, 'policy', pol.policyname,
                                'command', pol.cmd, 'permissive', pol.permissive, 'roles', pol.roles, 'using', pol.qual)
                                ORDER BY pol.schemaname, pol.tablename, pol.policyname)
                             FROM pg_policies pol
                             WHERE (pol.schemaname, pol.tablename) IN (('auth', 'users'), ('public', 'profiles'))
                               AND pol.cmd IN ('DELETE', 'ALL'))
) AS result;

-- ============================================================================
-- RUN P7. Partition and inheritance topology of the tables of interest
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
  SELECT con.oid AS con_oid, con.conname, con.conparentid, con.conrelid AS child_oid, con.confrelid AS parent_oid,
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
),
tf AS (
  SELECT DISTINCT t.tgfoid AS proc_oid
  FROM pg_trigger t
  WHERE NOT t.tgisinternal
    AND t.tgrelid IN (SELECT table_oid FROM interest)
)
SELECT jsonb_build_object(
  'run', 'P7',
  'tables_of_interest', (SELECT jsonb_agg(jsonb_build_object(
                            'table', rel.qname, 'kind', c.relkind, 'is_partition', c.relispartition,
                            'partition_bound', pg_get_expr(c.relpartbound, c.oid))
                            ORDER BY rel.qname)
                         FROM interest i
                         JOIN pg_class c ON c.oid = i.table_oid
                         JOIN rel ON rel.oid = c.oid),
  'inheritance_rows', (SELECT jsonb_agg(jsonb_build_object(
                          'parent', pr.qname, 'child', cr.qname, 'sequence_number', h.inhseqno)
                          ORDER BY pr.qname, cr.qname)
                       FROM pg_inherits h
                       JOIN rel pr ON pr.oid = h.inhparent
                       JOIN rel cr ON cr.oid = h.inhrelid
                       WHERE h.inhparent IN (SELECT table_oid FROM interest)
                          OR h.inhrelid IN (SELECT table_oid FROM interest)),
  'inheritance_row_count', (SELECT count(*) FROM pg_inherits h
                            WHERE h.inhparent IN (SELECT table_oid FROM interest)
                               OR h.inhrelid IN (SELECT table_oid FROM interest)),
  'partitioned_or_partition_table_count', (SELECT count(*) FROM pg_class c
                                           WHERE c.oid IN (SELECT table_oid FROM interest)
                                             AND (c.relkind = 'p' OR c.relispartition)),
  'inherited_foreign_key_edge_count', (SELECT count(*) FROM edges WHERE conparentid <> 0)
) AS result;
