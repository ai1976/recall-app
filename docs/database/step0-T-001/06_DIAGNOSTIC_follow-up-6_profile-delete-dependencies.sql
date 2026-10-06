-- Name: [DIAGNOSTIC] T-001 follow-up 6 (v3) - complete dependency inventory for deleting a user (auth.users and public.profiles): cascade closure, every foreign-key edge, triggers with their function definitions and a conservative call closure, rules with definitions, delete routines and every dynamic-SQL candidate, access (privileges and RLS) on both roots, partition and inheritance topology
--
-- Description: READ-ONLY sixth follow-up, revised after QA Round 56 (v2) and QA Round 58 (v3; supersedes v2 4a0bfa91b9bb and v1 2e567589e313, neither of
-- which was authorized or run). QA Round 52 (D3) requires a complete profile-delete foreign-key and dependency inventory before the erasure question
-- can go back through brief A's design gate; diagnostic 4 v4's J2d listed only the foreign keys that touch the three group tables.
-- Evidence so far: admin_delete_user_data (saved J2c) deletes the user's membership, course, review, card, deck and note rows and finally the
-- profiles row, and its audit entry says the deletion of the authentication user is "manual_required"; deleting a profile cascades to the group
-- tables (study_group_members.user_id, study_groups.created_by, content_group_shares.shared_by). This file shows EVERYTHING reached from the two
-- roots (auth.users and public.profiles), not only the group tables.
-- What changed in v3 (answers the one open QA Round 58 blocking finding; v2 closed QA Round 56 findings 4 and 5, which are unchanged):
--   * P4 (the call closure from the trigger functions) no longer recognizes a call only as the literal text name( or name (. It lower-cases each
--     readable source and removes every double quote, then treats a routine as callable when its name occurs anywhere as a whole identifier
--     (the characters before and after are not letters, digits or underscore). So "public"."helper"( , a name followed by a newline or tab before the
--     parenthesis, and a name beside a comment are all matched; no call syntax is required. Names that are not plain lower-case identifiers are matched
--     by plain substring. Every overload in every non-system schema is a candidate (a deliberate over-approximation: comments and strings also match).
--   * The closure is also seeded from the other places a delete or a referential action can invoke a function: the trigger definitions themselves
--     (including a WHEN condition), column default and generated-column expressions, and check and exclusion constraints of the tables of interest
--     (new counters expression_sources_scanned and expression_seed_roots; a seeded routine is flagged is_seed_from_expression).
--   * The data-change flag is broadened and renamed mentions_dml_or_ddl: any whole-word INSERT, UPDATE, DELETE, MERGE, TRUNCATE, COPY, CREATE, ALTER,
--     DROP, GRANT or REVOKE in a readable source. It is deliberately noisy; it exists so that a routine that can write is never silently skipped.
--   * P4 is explicitly fail-closed: its review_status says that every member of the closure is UNCLASSIFIED until its captured definition has been
--     reviewed and that a zero count does not clear a chain. P4 reports closure_members_without_captured_definition_in_p3_or_p8, which counts the
--     members whose definition appears in neither P3 (trigger functions) nor P8.
--   * P8 (new) returns the definition of every closure member that is readable and has mentions_dml_or_ddl or dynamic SQL and is not already in P3, so
--     that the callees that can write are captured for review and not only named. Closure members that are not readable as plpgsql or sql (for example
--     C-language routines) are counted in fail_closed_leads and are never silently cleared.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * P1: the fail-closed conditions (roots_complete must be true and unsupported_topology_present must be false for the inventory to count as
--     complete); the roots; the transitive closure of tables reached through ON DELETE CASCADE foreign keys starting at the roots (table, depth and the
--     chain of constraint names of one shortest path); and every foreign-key edge whose parent is a reached table, with every delete action (CASCADE,
--     SET NULL, SET DEFAULT, NO ACTION, RESTRICT), the child columns, the update action, whether the constraint is inherited, the full definition, and
--     whether the child is itself reached by cascade. NO ACTION and RESTRICT edges can BLOCK a deletion.
--   * P2: every user trigger (not internal; definition, function identity, language, definer flag, enabled state) and every rewrite rule (with its
--     definition) on the tables of interest: the reached tables, plus children of SET NULL and SET DEFAULT edges (those rows are updated by the
--     delete). Cascaded deletes fire row triggers.
--   * P3: the definition and properties of every function that those triggers call.
--   * P4: the conservative recursive call closure described above (identities and flags only, no bodies).
--   * P5: every plpgsql or sql routine whose source deletes from profiles or auth.users, or mentions auth.users (quoted forms included), and every
--     routine with dynamic SQL (identities and flags only; admin_delete_user_data is already saved).
--   * P6: access to both roots: kind, owner, row-level-security enabled and forced, the DELETE privilege of anon, authenticated and service_role
--     (has_table_privilege on the table's own oid), the number of policies of every command, and every policy for DELETE or ALL.
--   * P7: partition and inheritance topology of the tables of interest (kind, partition bound, every pg_inherits row).
--   * P8: definitions of the flagged non-trigger members of the P4 closure.
-- Known blind spots, stated: SQL assembled from fragments without the word EXECUTE is not seen by text matching (P5 returns every EXECUTE routine
-- and P4 flags them, so dynamic deletion by this route is a visible lead); functions reached only through operators, casts, type input and output
-- functions or index expressions are not resolved by name and are not claimed to be covered; deletion initiated inside the authentication service (its
-- API or the dashboard) is not visible in the database and remains an explicit Founder and platform assumption, never a database-verified fact;
-- behaviour of compiled (C-language) functions is flagged as not readable, not inspected.
-- Eight runs: P1 to P8. Each is one statement and returns one row with one jsonb column named `result`. P3, P4 and P8 can be large; if a result cell
-- is too large to copy, say so and do not trim it (a later reviewed version splits it).
-- Privacy rule: no user-authored stored text and no person data is selected; only table, constraint, trigger, routine and role names, flags, policy
-- text and function definitions (catalog text).
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Only
-- catalog functions and views are used (pg_class, pg_namespace, pg_constraint, pg_attribute, pg_attrdef, pg_inherits, pg_trigger, pg_proc, pg_language,
-- pg_rules, pg_policies, pg_get_constraintdef, pg_get_triggerdef, pg_get_functiondef, pg_get_expr, pg_get_function_identity_arguments,
-- pg_get_userbyid, has_table_privilege).
--
-- HOW TO RUN (eight runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label (P1 to P8), unchanged. Save that file as
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
-- RUN P4. Conservative, fail-closed call closure from those trigger functions and from default, check and trigger expressions (identities and flags only)
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
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef,
         replace(lower(p.prosrc), '"', '') AS norm_src,
         replace(lower(p.proname), '"', '') AS norm_name
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
),
calls AS MATERIALIZED (
  -- Conservative over-approximation: a readable routine may call any routine (every overload, every schema) whose name occurs as a whole
  -- identifier anywhere in its source after lower-casing and removing double quotes. No parenthesis, whitespace or comment form is
  -- required, so "schema"."name"( , a name followed by a newline or tab before the parenthesis, or a name next to a comment all match.
  SELECT caller.proc_oid AS caller_oid, callee.proc_oid AS callee_oid
  FROM routine caller
  JOIN routine callee ON callee.proc_oid <> caller.proc_oid
  WHERE caller.language IN ('plpgsql', 'sql')
    AND CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
             THEN caller.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
             ELSE strpos(caller.norm_src, callee.norm_name) > 0 END
),
seed_src AS (
  -- Other places where a function can be invoked by a delete or by the update that a referential action performs: the trigger
  -- definitions (including a WHEN condition), column default and generated-column expressions, and check and exclusion constraints
  -- of the tables of interest.
  SELECT replace(lower(pg_get_triggerdef(t.oid)), '"', '') AS norm_src
  FROM pg_trigger t
  WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT replace(lower(pg_get_expr(d.adbin, d.adrelid)), '"', '')
  FROM pg_attrdef d
  WHERE d.adrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT replace(lower(pg_get_constraintdef(con.oid)), '"', '')
  FROM pg_constraint con
  WHERE con.contype IN ('c', 'x') AND con.conrelid IN (SELECT table_oid FROM interest)
),
seed_roots AS (
  SELECT DISTINCT callee.proc_oid
  FROM seed_src s
  JOIN routine callee ON CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
                              THEN s.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
                              ELSE strpos(s.norm_src, callee.norm_name) > 0 END
),
seeds AS (
  SELECT proc_oid FROM tf
  UNION
  SELECT proc_oid FROM seed_roots
),
tclos(proc_oid) AS (
  SELECT proc_oid FROM seeds
  UNION
  SELECT c.callee_oid FROM tclos tc JOIN calls c ON c.caller_oid = tc.proc_oid
),
m AS (
  SELECT ro.proc_oid, ro.schema_name, ro.name, ro.args, ro.language, ro.owner, ro.prosecdef,
         (ro.proc_oid IN (SELECT proc_oid FROM tf)) AS is_trigger_function_of_interest,
         (ro.proc_oid IN (SELECT proc_oid FROM seed_roots)) AS is_seed_from_expression,
         (ro.language IN ('plpgsql', 'sql')) AS readable,
         (ro.language IN ('plpgsql', 'sql')
          AND ro.norm_src ~ '(^|[^a-z0-9_])execute([^a-z0-9_]|$)') AS has_dynamic_sql,
         (ro.language IN ('plpgsql', 'sql')
          AND ro.norm_src ~ '(^|[^a-z0-9_])(insert|update|delete|merge|truncate|copy|create|alter|drop|grant|revoke)([^a-z0-9_]|$)') AS mentions_dml_or_ddl
  FROM routine ro
  WHERE ro.proc_oid IN (SELECT proc_oid FROM tclos)
)
SELECT jsonb_build_object(
  'run', 'P4',
  'review_status', 'every member of this closure is UNCLASSIFIED until its captured definition (P3 for trigger functions, P8 for the flagged others) has been reviewed; a chain is not cleared by a zero count below',
  'trigger_function_roots', (SELECT count(*) FROM tf),
  'expression_sources_scanned', (SELECT count(*) FROM seed_src),
  'expression_seed_roots', (SELECT count(*) FROM seed_roots),
  'closure_member_count', (SELECT count(*) FROM m),
  'fail_closed_leads', jsonb_build_object(
      'closure_members_with_dynamic_sql', (SELECT count(*) FROM m WHERE has_dynamic_sql),
      'closure_members_not_readable_as_plpgsql_or_sql', (SELECT count(*) FROM m WHERE NOT readable),
      'closure_members_mentioning_dml_or_ddl', (SELECT count(*) FROM m WHERE mentions_dml_or_ddl),
      'closure_members_without_captured_definition_in_p3_or_p8',
          (SELECT count(*) FROM m
           WHERE NOT is_trigger_function_of_interest
             AND NOT (readable AND (mentions_dml_or_ddl OR has_dynamic_sql)))),
  'closure', (SELECT jsonb_agg(jsonb_build_object(
                  'schema', schema_name, 'name', name, 'args', args, 'language', language, 'owner', owner,
                  'security_definer', prosecdef, 'is_trigger_function_of_interest', is_trigger_function_of_interest,
                  'is_seed_from_expression', is_seed_from_expression,
                  'readable', readable, 'has_dynamic_sql', has_dynamic_sql, 'mentions_dml_or_ddl', mentions_dml_or_ddl)
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

-- ============================================================================
-- RUN P8. Definitions of the flagged non-trigger members of the P4 closure
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
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef,
         replace(lower(p.prosrc), '"', '') AS norm_src,
         replace(lower(p.proname), '"', '') AS norm_name
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
),
calls AS MATERIALIZED (
  -- Conservative over-approximation: a readable routine may call any routine (every overload, every schema) whose name occurs as a whole
  -- identifier anywhere in its source after lower-casing and removing double quotes. No parenthesis, whitespace or comment form is
  -- required, so "schema"."name"( , a name followed by a newline or tab before the parenthesis, or a name next to a comment all match.
  SELECT caller.proc_oid AS caller_oid, callee.proc_oid AS callee_oid
  FROM routine caller
  JOIN routine callee ON callee.proc_oid <> caller.proc_oid
  WHERE caller.language IN ('plpgsql', 'sql')
    AND CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
             THEN caller.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
             ELSE strpos(caller.norm_src, callee.norm_name) > 0 END
),
seed_src AS (
  -- Other places where a function can be invoked by a delete or by the update that a referential action performs: the trigger
  -- definitions (including a WHEN condition), column default and generated-column expressions, and check and exclusion constraints
  -- of the tables of interest.
  SELECT replace(lower(pg_get_triggerdef(t.oid)), '"', '') AS norm_src
  FROM pg_trigger t
  WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT replace(lower(pg_get_expr(d.adbin, d.adrelid)), '"', '')
  FROM pg_attrdef d
  WHERE d.adrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT replace(lower(pg_get_constraintdef(con.oid)), '"', '')
  FROM pg_constraint con
  WHERE con.contype IN ('c', 'x') AND con.conrelid IN (SELECT table_oid FROM interest)
),
seed_roots AS (
  SELECT DISTINCT callee.proc_oid
  FROM seed_src s
  JOIN routine callee ON CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
                              THEN s.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
                              ELSE strpos(s.norm_src, callee.norm_name) > 0 END
),
seeds AS (
  SELECT proc_oid FROM tf
  UNION
  SELECT proc_oid FROM seed_roots
),
tclos(proc_oid) AS (
  SELECT proc_oid FROM seeds
  UNION
  SELECT c.callee_oid FROM tclos tc JOIN calls c ON c.caller_oid = tc.proc_oid
),
m AS (
  SELECT ro.proc_oid, ro.schema_name, ro.name, ro.args, ro.language, ro.owner, ro.prosecdef,
         (ro.proc_oid IN (SELECT proc_oid FROM tf)) AS is_trigger_function_of_interest,
         (ro.proc_oid IN (SELECT proc_oid FROM seed_roots)) AS is_seed_from_expression,
         (ro.language IN ('plpgsql', 'sql')) AS readable,
         (ro.language IN ('plpgsql', 'sql')
          AND ro.norm_src ~ '(^|[^a-z0-9_])execute([^a-z0-9_]|$)') AS has_dynamic_sql,
         (ro.language IN ('plpgsql', 'sql')
          AND ro.norm_src ~ '(^|[^a-z0-9_])(insert|update|delete|merge|truncate|copy|create|alter|drop|grant|revoke)([^a-z0-9_]|$)') AS mentions_dml_or_ddl
  FROM routine ro
  WHERE ro.proc_oid IN (SELECT proc_oid FROM tclos)
)
SELECT jsonb_build_object(
  'run', 'P8',
  'definitions_expected', (SELECT count(*) FROM m
                           WHERE NOT is_trigger_function_of_interest AND readable AND (mentions_dml_or_ddl OR has_dynamic_sql)),
  'functions', (SELECT jsonb_agg(jsonb_build_object(
                   'schema', m.schema_name, 'name', m.name, 'args', m.args, 'language', m.language, 'owner', m.owner,
                   'security_definer', m.prosecdef, 'has_dynamic_sql', m.has_dynamic_sql,
                   'mentions_dml_or_ddl', m.mentions_dml_or_ddl, 'definition', pg_get_functiondef(m.proc_oid))
                   ORDER BY m.schema_name, m.name, m.args)
                FROM m
                WHERE NOT m.is_trigger_function_of_interest AND m.readable AND (m.mentions_dml_or_ddl OR m.has_dynamic_sql))
) AS result;
