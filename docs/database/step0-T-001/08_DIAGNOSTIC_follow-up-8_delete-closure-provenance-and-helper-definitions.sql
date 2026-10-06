-- Name: [DIAGNOSTIC] T-001 follow-up 8 (v1) - provenance of the user-delete call closure (why each of the 50 routines is in it), the exact definitions of the 12 readable helpers that diagnostic 6 v3 did not capture, and the columns and constraints of the five group tables (creator and actor columns)
--
-- Description: READ-ONLY eighth follow-up. Follow-up diagnostic 6 v3 (449e9e46ed56, Gate 4 accepted by the Founder) inventoried everything a user
-- delete reaches and computed a conservative call closure of 50 routines, but it did not say WHY each routine is in the closure (which caller, or
-- which trigger, default expression or constraint, matched it) and it did not capture the definitions of 12 readable helpers (auth.email, auth.jwt,
-- auth.role, auth.uid, public.course_change_affected, public.get_user_streak, public.is_admin, public.is_professor_or_admin,
-- public.is_super_admin, realtime.topic, storage.extension, storage.filename). QA Round 64 (answer to Round 63 D2) required both before the closure
-- can be classified for Gate 2; QA Round 66 set five controls on the scope, which this file implements. The four C-language members of the closure
-- (cron.schedule x2, extensions.gen_random_uuid, extensions.uuid_generate_v4) get their parent and seed edges here but no definition: they are
-- governed by the diagnostic 5 baseline and diagnostic 7 evidence.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * E1 (reproduces the closure and reconciles it with diagnostic 6 P4). The same interest tables, trigger functions, routine-identity normalization
--     and conservative lexical matcher as diagnostic 6 P4 (the matcher is copied exactly: lower-case, double quotes removed, whole-identifier match,
--     every overload, every schema). It returns the exact identity (schema, name, identity arguments) of every closure member and the expected and
--     actual counts with match flags: 50 members, 30 trigger-function roots, 34 expression-seed roots, 254 expression sources. Any missing, extra
--     or ambiguous identity, or any false match flag, is a positive lead and never an automatic refresh of the saved set.
--   * E2 (all provenance edges, not one chosen predecessor and not a spanning tree). (a) Every trigger root: trigger and table, and the exact
--     identity of its trigger function. (b) Every expression-seed edge: the source type (trigger definition, column default or generated expression,
--     check or exclusion constraint), the source object (trigger on table, table.column, table.constraint), the matched token, the exact callee
--     identity, and the source text so that the match can be reproduced. (c) Every routine-to-routine edge among the closure members: exact caller
--     identity, exact callee identity and matched token. Cycles and multiple parents are preserved. Reconciliation counts show that every closure
--     member has a recorded root or a recorded parent (closure_members_without_a_recorded_root_or_parent must be 0) and that no recorded edge
--     points to an identity outside the closure (routine_edges_pointing_outside_closure must be 0). **Every edge is a lexical over-approximation,
--     not a proven runtime call**, and the result says so.
--   * E3 (exact definitions of the expected 12 helpers). The 12 identities are enumerated in the file. For each: pg_get_functiondef, language,
--     owner, SECURITY DEFINER flag, volatility, function-level configuration (including search_path), kind and ACL. The run returns expected_count,
--     found_count, and the lists missing (not found), duplicated (more than one identity), and not_readable_as_plpgsql_or_sql (a changed language), each of
--     which must be empty for the capture to be complete; anything else is a positive lead.
-- Known blind spots, stated: the closure and every edge are lexical, so comments and strings can create false edges and functions reached only
-- through operators, casts, type input and output functions or index expressions are not resolved by name (as in diagnostic 6); SQL assembled from
-- fragments is not seen; compiled functions are not inspected; the runs are separate statements, not one transactional snapshot, so any
-- difference from the saved diagnostic 6 evidence is a lead and nothing here refreshes that evidence.
--   * E4 (columns and constraints of the five group tables). For public.study_groups, study_group_members, content_group_shares,
--     batch_group_archives and batch_group_professors: every column with its type, NOT NULL flag, identity or generated flag and default expression, and
--     every check, unique, primary-key and exclusion constraint with its definition. Founder decision D3 (06/10/2026: a batch group must survive the
--     deletion of the user who created it) needs to know whether the creator and actor columns (created_by, archived_by, assigned_by, invited_by,
--     shared_by, user_id) can be NULL and whether any constraint depends on them; the saved evidence shows only the foreign keys, not the nullability.
--     The run returns tables_expected 5, tables_found and tables_complete (which must be true).
-- Four runs: E1, E2, E3 and E4. Each is one statement and returns one row with one jsonb column named `result`. E2 may be large; if a result cell is
-- too large to copy, say so and do not trim it (a later reviewed version splits it).
-- Privacy rule: no user-authored stored text and no person data is selected; only routine, table, trigger, column and constraint names, expression
-- and function definitions (catalog text), flags and ACL text.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Only
-- catalog views and functions are used (pg_class, pg_namespace, pg_constraint, pg_attribute, pg_attrdef, pg_trigger, pg_proc, pg_language,
-- pg_get_constraintdef, pg_get_triggerdef, pg_get_functiondef, pg_get_expr, pg_get_function_identity_arguments, pg_get_userbyid).
--
-- HOW TO RUN (four runs, in the same sitting as diagnostic 7 if both are authorized): select the text of ONE run (from its banner line to its
-- closing semicolon), click Run, copy the single result cell, and paste it into one Notepad file under its label (E1 to E4), unchanged. Save that
-- file as docs/discussions/evidence/T-001_FU8-raw_<dd-mm-yyyy>.raw.txt and keep it untouched; the derived .json files are made from it by script.
-- An error is evidence: save the error text under its label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN E1. Reproduce the delete call closure and reconcile it with diagnostic 6 P4 (exact identities and counts)
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
         n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS identity,
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
  -- Same conservative lexical matcher as diagnostic 6 P4: a readable routine may call any routine (every overload, every schema) whose
  -- name occurs as a whole identifier in its source after lower-casing and removing double quotes. Every edge is an over-approximation.
  SELECT caller.proc_oid AS caller_oid, callee.proc_oid AS callee_oid, callee.norm_name AS matched_token
  FROM routine caller
  JOIN routine callee ON callee.proc_oid <> caller.proc_oid
  WHERE caller.language IN ('plpgsql', 'sql')
    AND CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
             THEN caller.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
             ELSE strpos(caller.norm_src, callee.norm_name) > 0 END
),
seed_src AS (
  -- Every place a delete, or the update that a referential action performs, can invoke a function, WITH its source object: the trigger
  -- definitions (including a WHEN condition), column default and generated-column expressions, and check and exclusion constraints of the
  -- tables of interest.
  SELECT 'trigger'::text AS src_type, rel.qname || '.' || t.tgname AS source_object,
         replace(lower(pg_get_triggerdef(t.oid)), '"', '') AS norm_src,
         pg_get_triggerdef(t.oid) AS source_text
  FROM pg_trigger t
  JOIN rel ON rel.oid = t.tgrelid
  WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT 'column_default', rel.qname || '.' || a.attname,
         replace(lower(pg_get_expr(d.adbin, d.adrelid)), '"', ''),
         pg_get_expr(d.adbin, d.adrelid)
  FROM pg_attrdef d
  JOIN rel ON rel.oid = d.adrelid
  JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  WHERE d.adrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT 'constraint', rel.qname || '.' || con.conname,
         replace(lower(pg_get_constraintdef(con.oid)), '"', ''),
         pg_get_constraintdef(con.oid)
  FROM pg_constraint con
  JOIN rel ON rel.oid = con.conrelid
  WHERE con.contype IN ('c', 'x') AND con.conrelid IN (SELECT table_oid FROM interest)
),
seed_edges AS (
  SELECT s.src_type, s.source_object, s.source_text, callee.proc_oid AS callee_oid, callee.norm_name AS matched_token
  FROM seed_src s
  JOIN routine callee ON CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
                              THEN s.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
                              ELSE strpos(s.norm_src, callee.norm_name) > 0 END
),
seed_roots AS (
  SELECT DISTINCT callee_oid AS proc_oid FROM seed_edges
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
  SELECT ro.proc_oid, ro.identity, ro.schema_name, ro.name, ro.args, ro.language,
         (ro.proc_oid IN (SELECT proc_oid FROM tf)) AS is_trigger_function_root,
         (ro.proc_oid IN (SELECT proc_oid FROM seed_roots)) AS is_seed_from_expression,
         (ro.language IN ('plpgsql', 'sql')) AS readable
  FROM routine ro
  WHERE ro.proc_oid IN (SELECT proc_oid FROM tclos)
)
SELECT jsonb_build_object(
  'run', 'E1',
  'reconciliation_with_saved_diagnostic_6_p4', jsonb_build_object(
      'closure_members_expected', 50, 'closure_members_actual', (SELECT count(*) FROM m),
      'closure_members_match', (SELECT count(*) FROM m) = 50,
      'trigger_function_roots_expected', 30, 'trigger_function_roots_actual', (SELECT count(*) FROM tf),
      'trigger_function_roots_match', (SELECT count(*) FROM tf) = 30,
      'expression_seed_roots_expected', 34, 'expression_seed_roots_actual', (SELECT count(*) FROM seed_roots),
      'expression_seed_roots_match', (SELECT count(*) FROM seed_roots) = 34,
      'expression_sources_expected', 254, 'expression_sources_actual', (SELECT count(*) FROM seed_src),
      'expression_sources_match', (SELECT count(*) FROM seed_src) = 254),
  'closure_members', (SELECT jsonb_agg(jsonb_build_object(
                         'identity', m.identity, 'schema', m.schema_name, 'name', m.name, 'args', m.args,
                         'language', m.language, 'readable', m.readable,
                         'is_trigger_function_root', m.is_trigger_function_root,
                         'is_seed_from_expression', m.is_seed_from_expression)
                         ORDER BY m.identity)
                      FROM m)
) AS result;

-- ============================================================================
-- RUN E2. Every provenance edge: trigger roots, expression seeds with their source text, routine-to-routine edges (all lexical)
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
         n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS identity,
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
  -- Same conservative lexical matcher as diagnostic 6 P4: a readable routine may call any routine (every overload, every schema) whose
  -- name occurs as a whole identifier in its source after lower-casing and removing double quotes. Every edge is an over-approximation.
  SELECT caller.proc_oid AS caller_oid, callee.proc_oid AS callee_oid, callee.norm_name AS matched_token
  FROM routine caller
  JOIN routine callee ON callee.proc_oid <> caller.proc_oid
  WHERE caller.language IN ('plpgsql', 'sql')
    AND CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
             THEN caller.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
             ELSE strpos(caller.norm_src, callee.norm_name) > 0 END
),
seed_src AS (
  -- Every place a delete, or the update that a referential action performs, can invoke a function, WITH its source object: the trigger
  -- definitions (including a WHEN condition), column default and generated-column expressions, and check and exclusion constraints of the
  -- tables of interest.
  SELECT 'trigger'::text AS src_type, rel.qname || '.' || t.tgname AS source_object,
         replace(lower(pg_get_triggerdef(t.oid)), '"', '') AS norm_src,
         pg_get_triggerdef(t.oid) AS source_text
  FROM pg_trigger t
  JOIN rel ON rel.oid = t.tgrelid
  WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT 'column_default', rel.qname || '.' || a.attname,
         replace(lower(pg_get_expr(d.adbin, d.adrelid)), '"', ''),
         pg_get_expr(d.adbin, d.adrelid)
  FROM pg_attrdef d
  JOIN rel ON rel.oid = d.adrelid
  JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  WHERE d.adrelid IN (SELECT table_oid FROM interest)
  UNION ALL
  SELECT 'constraint', rel.qname || '.' || con.conname,
         replace(lower(pg_get_constraintdef(con.oid)), '"', ''),
         pg_get_constraintdef(con.oid)
  FROM pg_constraint con
  JOIN rel ON rel.oid = con.conrelid
  WHERE con.contype IN ('c', 'x') AND con.conrelid IN (SELECT table_oid FROM interest)
),
seed_edges AS (
  SELECT s.src_type, s.source_object, s.source_text, callee.proc_oid AS callee_oid, callee.norm_name AS matched_token
  FROM seed_src s
  JOIN routine callee ON CASE WHEN callee.norm_name ~ '^[a-z0-9_]+$'
                              THEN s.norm_src ~ ('(^|[^a-z0-9_])' || callee.norm_name || '([^a-z0-9_]|$)')
                              ELSE strpos(s.norm_src, callee.norm_name) > 0 END
),
seed_roots AS (
  SELECT DISTINCT callee_oid AS proc_oid FROM seed_edges
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
  SELECT ro.proc_oid, ro.identity, ro.schema_name, ro.name, ro.args, ro.language,
         (ro.proc_oid IN (SELECT proc_oid FROM tf)) AS is_trigger_function_root,
         (ro.proc_oid IN (SELECT proc_oid FROM seed_roots)) AS is_seed_from_expression,
         (ro.language IN ('plpgsql', 'sql')) AS readable
  FROM routine ro
  WHERE ro.proc_oid IN (SELECT proc_oid FROM tclos)
)
SELECT jsonb_build_object(
  'run', 'E2',
  'every_edge_is_a_lexical_over_approximation', true,
  'reconciliation', jsonb_build_object(
      'trigger_root_edge_count', (SELECT count(*) FROM pg_trigger t
                                  WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)),
      'seed_edge_count', (SELECT count(*) FROM seed_edges),
      'routine_edge_count', (SELECT count(*) FROM calls c WHERE c.caller_oid IN (SELECT proc_oid FROM tclos)),
      'routine_edges_pointing_outside_closure',
          (SELECT count(*) FROM calls c
           WHERE c.caller_oid IN (SELECT proc_oid FROM tclos) AND c.callee_oid NOT IN (SELECT proc_oid FROM tclos)),
      'closure_members_without_a_recorded_root_or_parent',
          (SELECT count(*) FROM m
           WHERE m.proc_oid NOT IN (SELECT proc_oid FROM seeds)
             AND m.proc_oid NOT IN (SELECT c.callee_oid FROM calls c WHERE c.caller_oid IN (SELECT proc_oid FROM tclos)))),
  'trigger_root_edges', (SELECT jsonb_agg(jsonb_build_object(
                            'trigger', rel.qname || '.' || t.tgname, 'trigger_function_identity', ro.identity)
                            ORDER BY rel.qname, t.tgname)
                         FROM pg_trigger t
                         JOIN rel ON rel.oid = t.tgrelid
                         JOIN routine ro ON ro.proc_oid = t.tgfoid
                         WHERE NOT t.tgisinternal AND t.tgrelid IN (SELECT table_oid FROM interest)),
  'seed_edges', (SELECT jsonb_agg(jsonb_build_object(
                    'source_type', se.src_type, 'source_object', se.source_object,
                    'matched_token', se.matched_token, 'callee_identity', ro.identity,
                    'source_text', se.source_text)
                    ORDER BY se.src_type, se.source_object, ro.identity)
                 FROM seed_edges se
                 JOIN routine ro ON ro.proc_oid = se.callee_oid),
  'routine_edges', (SELECT jsonb_agg(jsonb_build_object(
                       'caller_identity', cr.identity, 'callee_identity', ce.identity, 'matched_token', c.matched_token)
                       ORDER BY cr.identity, ce.identity)
                    FROM calls c
                    JOIN routine cr ON cr.proc_oid = c.caller_oid
                    JOIN routine ce ON ce.proc_oid = c.callee_oid
                    WHERE c.caller_oid IN (SELECT proc_oid FROM tclos))
) AS result;

-- ============================================================================
-- RUN E3. Exact definitions of the 12 readable helpers that diagnostic 6 did not capture
-- ============================================================================
WITH want(schema_name, name, args) AS (
  VALUES ('auth', 'email', ''),
         ('auth', 'jwt', ''),
         ('auth', 'role', ''),
         ('auth', 'uid', ''),
         ('public', 'course_change_affected', 'p_user_id uuid, p_old_course text, p_new_course text'),
         ('public', 'get_user_streak', 'p_user_id uuid'),
         ('public', 'is_admin', ''),
         ('public', 'is_professor_or_admin', ''),
         ('public', 'is_super_admin', ''),
         ('realtime', 'topic', ''),
         ('storage', 'extension', 'name text'),
         ('storage', 'filename', 'name text')
),
f AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname AS name,
         pg_get_function_identity_arguments(p.oid) AS args, l.lanname AS language,
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.provolatile, p.proconfig,
         ARRAY(SELECT a::text FROM unnest(p.proacl) AS a ORDER BY a::text) AS acl,
         (p.proacl IS NULL) AS acl_is_default,
         p.prokind
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
)
SELECT jsonb_build_object(
  'run', 'E3',
  'expected_count', (SELECT count(*) FROM want),
  'found_count', (SELECT count(*) FROM want w
                  WHERE (SELECT count(*) FROM f WHERE f.schema_name = w.schema_name AND f.name = w.name AND f.args = w.args) = 1),
  'missing', (SELECT jsonb_agg(w.schema_name || '.' || w.name || '(' || w.args || ')')
              FROM want w
              WHERE NOT EXISTS (SELECT 1 FROM f WHERE f.schema_name = w.schema_name AND f.name = w.name AND f.args = w.args)),
  'duplicated', (SELECT jsonb_agg(w.schema_name || '.' || w.name || '(' || w.args || ')')
                 FROM want w
                 WHERE (SELECT count(*) FROM f WHERE f.schema_name = w.schema_name AND f.name = w.name AND f.args = w.args) > 1),
  'not_readable_as_plpgsql_or_sql', (SELECT jsonb_agg(f.schema_name || '.' || f.name || '(' || f.args || ')')
                                     FROM f JOIN want w ON f.schema_name = w.schema_name AND f.name = w.name AND f.args = w.args
                                     WHERE f.language NOT IN ('plpgsql', 'sql')),
  'functions', (SELECT jsonb_agg(jsonb_build_object(
                   'identity', f.schema_name || '.' || f.name || '(' || f.args || ')',
                   'language', f.language, 'owner', f.owner, 'security_definer', f.prosecdef,
                   'volatility', f.provolatile, 'config', f.proconfig, 'kind', f.prokind,
                   'acl', f.acl, 'acl_is_default', f.acl_is_default,
                   'definition', pg_get_functiondef(f.oid))
                   ORDER BY f.schema_name, f.name, f.args)
                FROM f JOIN want w ON f.schema_name = w.schema_name AND f.name = w.name AND f.args = w.args)
) AS result;

-- ============================================================================
-- RUN E4. Columns and constraints of the five group tables (creator and actor columns, nullability, defaults)
-- ============================================================================
WITH t AS (
  SELECT c.oid, n.nspname || '.' || c.relname AS qname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_groups', 'study_group_members', 'content_group_shares', 'batch_group_archives', 'batch_group_professors')
    AND c.relkind IN ('r', 'p')
),
col AS (
  SELECT t.qname, a.attnum, a.attname, format_type(a.atttypid, a.atttypmod) AS data_type,
         a.attnotnull, a.attidentity, a.attgenerated, pg_get_expr(d.adbin, d.adrelid) AS default_expression
  FROM t
  JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
)
SELECT jsonb_build_object(
  'run', 'E4',
  'tables_expected', 5,
  'tables_found', (SELECT count(*) FROM t),
  'tables_complete', (SELECT count(*) FROM t) = 5,
  'columns', (SELECT jsonb_agg(jsonb_build_object(
                 'table', col.qname, 'column', col.attname, 'data_type', col.data_type, 'not_null', col.attnotnull,
                 'identity', col.attidentity, 'generated', col.attgenerated, 'default_expression', col.default_expression)
                 ORDER BY col.qname, col.attnum)
              FROM col),
  'check_unique_primary_constraints', (SELECT jsonb_agg(jsonb_build_object(
                                          'table', t.qname, 'constraint', con.conname, 'type', con.contype,
                                          'definition', pg_get_constraintdef(con.oid))
                                          ORDER BY t.qname, con.conname)
                                       FROM t
                                       JOIN pg_constraint con ON con.conrelid = t.oid AND con.contype IN ('c', 'u', 'p', 'x'))
) AS result;
