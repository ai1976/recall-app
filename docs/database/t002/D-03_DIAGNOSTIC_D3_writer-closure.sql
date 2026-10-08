-- Name: [DIAGNOSTIC] T-002 D3 (v1) - writer closure for the stream B relations: foreign-key actions, routine leads, dependent views, scheduled jobs, signup and delete chains
--
-- Description: READ-ONLY. Diagnostic D3 of docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md (QA Round 14 PASS WITH CONDITIONS, authoring only; condition
-- 3 is built in: foreign-key referential actions are a first-class output class). It collects, from the system catalogue, every LEAD that a statement could
-- INSERT, UPDATE, DELETE, TRUNCATE, COPY or MERGE rows of: profiles, study_sessions, flashcards, notes, access_requests, disciplines, subjects, topics. It is
-- a seed-and-closure lead collector, not a proof: every output is a lead or an over-approximation, and anything it cannot read is listed as UNRESOLVED and
-- is never counted as clean. The writer MATRIX (relation x DML kind: INSERT, UPDATE, UPSERT/ON CONFLICT DO UPDATE, MERGE, COPY FROM, DELETE, TRUNCATE) is
-- assembled by Claude from these runs and from the D4 code inventory, saved as a table, and audited by QA. An unresolved cell keeps the dependent file blocked.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * RUN P1 (foreign keys): every foreign key whose child or parent is one of the eight relations, with ON UPDATE and ON DELETE action codes (a no action,
--     r restrict, c cascade, n set null, d set default), and the recursive reachability of every target from ancestor relations through MUTATING actions
--     (cascade, set null, set default): an ancestor delete or key update that reaches a target row is an INDIRECT UPDATE or DELETE path on that target.
--   * RUN P2 (routine leads): every non-system routine (function or procedure, any schema) whose body names one of the eight relations as a whole identifier,
--     with identity, owner, language, SECURITY DEFINER flag, configuration, EXECUTE grantees, md5 of the source, and flags for insert, update, delete,
--     truncate, merge, copy, ON CONFLICT DO UPDATE, EXECUTE (dynamic SQL) and DDL words; plus a count and the identities of routines in languages that cannot
--     be read as SQL text (anything other than plpgsql, sql, c, internal), which are UNRESOLVED by definition.
--   * RUN P3 (dependent views and materialized views): every view or materialized view that depends on one of the eight relations (pg_depend on the rewrite
--     rule), with md5 and length of its definition and whether the view itself accepts INSERT, UPDATE or DELETE (pg_relation_is_updatable: bit 4 update, bit
--     8 insert, bit 16 delete), because a writable view is a write path to its base relation.
--   * RUN P4 (scheduled jobs): every visible row of cron.job with job id, name, schedule, active flag, database, user, the md5 and length of the command (the
--     command text itself is NEVER returned, because it can hold a secret), and structural flags (which target relation names occur, which DML words occur,
--     whether net.http_post occurs, whether the cron schema is named), plus the routine-name leads that occur in the command. cron.job is read directly: the
--     schema exists (saved evidence T-001 FU7 of 06/10/2026). Rows hidden from the running role by the table's row-level policy are not counted here.
--   * RUN P5 (signup and delete chains): the triggers on auth.users (definition and function), the full definition of every function they call at the first
--     level, the full definition of every overload of submit_access_request and admin_delete_user_data (the delete path that reaches study_sessions and
--     others), and the routine-name leads inside those definitions.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Only catalogue views and functions, and the single read of cron.job, are used.
-- Blind spots, stated: whole-identifier text matching can list a name that is a column or a comment, and can miss a relation reached only through a name built at
-- run time (an EXECUTE flag is raised for that reason) or through a function in the closure that does not itself name the relation; the transitive callee
-- closure is completed by Claude from P2 and P5 with a further targeted capture where a callee body is not in saved evidence; compiled routines (language c,
-- internal) cannot be read and are not claimed clean; unreadable-language routines are listed as unresolved. The cron table is read as the running role and
-- may hide other users' rows by policy. Counts are one statement's view at its run time.
--
-- HOW TO RUN (five runs: P1 to P5): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label, unchanged. Save as docs/discussions/evidence/T-002_D3-raw_<dd-mm-yyyy>.raw.txt and keep it untouched. An
-- error is evidence: save the error text under its label, do not edit and re-run (stop and report instead). A paste can be truncated: if a cell is cut, stop
-- and report; the verbatim-extracts pattern of docs/database/t001/run-extracts/ is used.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN P1: foreign keys and mutating reachability =====
WITH RECURSIVE t AS (
  SELECT c.oid, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
fk AS (
  SELECT k.conname, k.conrelid AS child, k.confrelid AS parent, k.confupdtype, k.confdeltype
  FROM pg_constraint k
  WHERE k.contype = 'f'
),
mut AS (
  SELECT fk.conname, fk.child, fk.parent
  FROM fk
  WHERE fk.confupdtype IN ('c', 'n', 'd') OR fk.confdeltype IN ('c', 'n', 'd')
),
reach(target, anc, depth, path) AS (
  SELECT t.oid, m.parent, 1, ARRAY[m.conname::text]
  FROM t
  JOIN mut m ON m.child = t.oid
  UNION ALL
  SELECT r.target, m.parent, r.depth + 1, r.path || m.conname::text
  FROM reach r
  JOIN mut m ON m.child = r.anc
  WHERE r.depth < 10 AND NOT (m.conname::text = ANY (r.path))
)
SELECT jsonb_build_object(
  'run', 'D3-P1',
  'targets_found', (SELECT count(*) FROM t),
  'direct_foreign_keys', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'constraint', fk.conname, 'child', fk.child::regclass::text, 'parent', fk.parent::regclass::text,
      'on_update', fk.confupdtype::text, 'on_delete', fk.confdeltype::text,
      'mutating_action', (fk.confupdtype IN ('c', 'n', 'd') OR fk.confdeltype IN ('c', 'n', 'd'))
    ) ORDER BY fk.child::regclass::text, fk.conname)
    FROM fk
    WHERE fk.child IN (SELECT oid FROM t) OR fk.parent IN (SELECT oid FROM t)
  ), '[]'::jsonb),
  'mutation_reachability', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'target', t.relname, 'ancestor', r.anc::regclass::text, 'depth', r.depth, 'path', to_jsonb(r.path)
    ) ORDER BY t.relname, r.depth, r.anc::regclass::text)
    FROM reach r
    JOIN t ON t.oid = r.target
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P2: routine leads (whole-identifier match of the eight relation names) =====
WITH rels(rel) AS (
  VALUES ('profiles'), ('study_sessions'), ('flashcards'), ('notes'), ('access_requests'), ('disciplines'), ('subjects'), ('topics')
),
r AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, l.lanname AS language, p.prosecdef, p.proconfig, p.proowner, p.proacl,
         p.prosrc AS src_raw, lower(p.prosrc) AS src
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND p.prokind IN ('f', 'p')
),
hits AS (
  SELECT r.*,
         (SELECT array_agg(rels.rel ORDER BY rels.rel) FROM rels WHERE r.src ~ ('\m' || rels.rel || '\M')) AS mentions
  FROM r
)
SELECT jsonb_build_object(
  'run', 'D3-P2',
  'routines_scanned', (SELECT count(*) FROM r),
  'routines_naming_a_target', (SELECT count(*) FROM hits WHERE mentions IS NOT NULL),
  'routines', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', h.schema_name, 'name', h.proname, 'args', h.args, 'owner', h.owner, 'language', h.language,
      'language_unresolved', (h.language NOT IN ('plpgsql', 'sql')),
      'security_definer', h.prosecdef, 'config', to_jsonb(h.proconfig),
      'execute_grantees', to_jsonb(ARRAY(
        SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END
        FROM aclexplode(COALESCE(h.proacl, acldefault('f', h.proowner))) AS x
        WHERE x.privilege_type = 'EXECUTE'
        ORDER BY 1
      )),
      'mentions', to_jsonb(h.mentions),
      'src_md5', md5(h.src_raw),
      'flags', jsonb_build_object(
        'insert', (h.src ~ '\minsert\M'), 'update', (h.src ~ '\mupdate\M'), 'delete', (h.src ~ '\mdelete\M'),
        'truncate', (h.src ~ '\mtruncate\M'), 'merge', (h.src ~ '\mmerge\M'), 'copy', (h.src ~ '\mcopy\M'),
        'on_conflict_do_update', (h.src ~ 'on\s+conflict[^;]*do\s+update'),
        'dynamic_sql_execute', (h.src ~ '\mexecute\M'),
        'ddl_word', (h.src ~ '\m(create|alter|drop|grant|revoke)\M')
      )
    ) ORDER BY h.schema_name, h.proname, h.args)
    FROM hits h
    WHERE h.mentions IS NOT NULL
  ), '[]'::jsonb),
  'unreadable_language_routines', jsonb_build_object(
    'count', (SELECT count(*) FROM r WHERE r.language NOT IN ('plpgsql', 'sql', 'c', 'internal')),
    'identities', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('schema', r.schema_name, 'name', r.proname, 'args', r.args, 'language', r.language)
                       ORDER BY r.schema_name, r.proname, r.args)
      FROM r WHERE r.language NOT IN ('plpgsql', 'sql', 'c', 'internal')
    ), '[]'::jsonb)
  ),
  'compiled_routines_not_readable', jsonb_build_object(
    'count', (SELECT count(*) FROM r WHERE r.language IN ('c', 'internal')),
    'note', 'compiled routines cannot be read as text; they are listed by count only and are not claimed clean'
  )
) AS result;

-- ===== RUN P3: views and materialized views that depend on the eight relations =====
WITH t AS (
  SELECT c.oid, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
dv AS (
  SELECT DISTINCT v.oid AS view_oid, vn.nspname AS view_schema, v.relname AS view_name, v.relkind::text AS view_kind, t.relname AS depends_on
  FROM pg_depend d
  JOIN pg_rewrite rw ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid
  JOIN pg_class v ON v.oid = rw.ev_class
  JOIN pg_namespace vn ON vn.oid = v.relnamespace
  JOIN t ON t.oid = d.refobjid
  WHERE v.oid <> t.oid
)
SELECT jsonb_build_object(
  'run', 'D3-P3',
  'dependent_views', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', dv.view_schema, 'view', dv.view_name, 'kind', dv.view_kind, 'depends_on', dv.depends_on,
      'definition_md5', md5(pg_get_viewdef(dv.view_oid)), 'definition_length', length(pg_get_viewdef(dv.view_oid)),
      'accepts_update', ((pg_relation_is_updatable(dv.view_oid, false) & 4) <> 0),
      'accepts_insert', ((pg_relation_is_updatable(dv.view_oid, false) & 8) <> 0),
      'accepts_delete', ((pg_relation_is_updatable(dv.view_oid, false) & 16) <> 0)
    ) ORDER BY dv.view_schema, dv.view_name, dv.depends_on)
    FROM dv
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P4: scheduled jobs (command text is never returned) =====
SELECT jsonb_build_object(
  'run', 'D3-P4',
  'visible_job_rows', (SELECT count(*) FROM cron.job),
  'jobs', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'jobid', j.jobid, 'jobname', j.jobname, 'schedule', j.schedule, 'active', j.active, 'database', j.database, 'username', j.username,
      'command_md5', md5(j.command), 'command_length', length(j.command),
      'flags', jsonb_build_object(
        'names_profiles', (lower(j.command) ~ '\mprofiles\M'), 'names_study_sessions', (lower(j.command) ~ '\mstudy_sessions\M'),
        'names_flashcards', (lower(j.command) ~ '\mflashcards\M'), 'names_notes', (lower(j.command) ~ '\mnotes\M'),
        'names_access_requests', (lower(j.command) ~ '\maccess_requests\M'), 'names_disciplines', (lower(j.command) ~ '\mdisciplines\M'),
        'names_subjects', (lower(j.command) ~ '\msubjects\M'), 'names_topics', (lower(j.command) ~ '\mtopics\M'),
        'insert', (lower(j.command) ~ '\minsert\M'), 'update', (lower(j.command) ~ '\mupdate\M'), 'delete', (lower(j.command) ~ '\mdelete\M'),
        'truncate', (lower(j.command) ~ '\mtruncate\M'), 'merge', (lower(j.command) ~ '\mmerge\M'), 'copy', (lower(j.command) ~ '\mcopy\M'),
        'execute_word', (lower(j.command) ~ '\mexecute\M'),
        'net_http_post', (position('net.http_post' IN lower(j.command)) > 0),
        'names_cron_schema', (position('cron.' IN lower(j.command)) > 0)
      ),
      'routine_name_leads', COALESCE((
        SELECT jsonb_agg(jsonb_build_object('schema', n.nspname, 'name', p.proname, 'args', pg_get_function_identity_arguments(p.oid))
                         ORDER BY n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
          AND length(p.proname) >= 6
          AND position(lower(p.proname) IN lower(j.command)) > 0
      ), '[]'::jsonb)
    ) ORDER BY j.jobid)
    FROM cron.job j
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P5: signup and delete chains =====
WITH au AS (
  SELECT g.oid AS trigger_oid, g.tgname, g.tgenabled, g.tgfoid
  FROM pg_trigger g
  JOIN pg_class c ON c.oid = g.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'auth' AND c.relname = 'users' AND NOT g.tgisinternal
),
chain_ids AS (
  SELECT DISTINCT au.tgfoid AS fn_oid FROM au
  UNION
  SELECT p.oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname IN ('submit_access_request', 'admin_delete_user_data')
),
chain AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, l.lanname AS language, p.prosecdef, p.proconfig, p.proowner, p.proacl,
         lower(p.prosrc) AS src
  FROM chain_ids ci
  JOIN pg_proc p ON p.oid = ci.fn_oid
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
)
SELECT jsonb_build_object(
  'run', 'D3-P5',
  'auth_users_triggers', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'name', au.tgname, 'enabled', au.tgenabled::text, 'definition', pg_get_triggerdef(au.trigger_oid),
      'function_schema', n.nspname, 'function', p.proname, 'function_args', pg_get_function_identity_arguments(p.oid)
    ) ORDER BY au.tgname)
    FROM au
    JOIN pg_proc p ON p.oid = au.tgfoid
    JOIN pg_namespace n ON n.oid = p.pronamespace
  ), '[]'::jsonb),
  'chain_functions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', ch.schema_name, 'name', ch.proname, 'args', ch.args, 'owner', ch.owner, 'language', ch.language,
      'security_definer', ch.prosecdef, 'config', to_jsonb(ch.proconfig),
      'execute_grantees', to_jsonb(ARRAY(
        SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END
        FROM aclexplode(COALESCE(ch.proacl, acldefault('f', ch.proowner))) AS x
        WHERE x.privilege_type = 'EXECUTE'
        ORDER BY 1
      )),
      'definition_md5', md5(pg_get_functiondef(ch.oid)),
      'definition', pg_get_functiondef(ch.oid),
      'routine_name_leads', COALESCE((
        SELECT jsonb_agg(jsonb_build_object('schema', n2.nspname, 'name', p2.proname, 'args', pg_get_function_identity_arguments(p2.oid))
                         ORDER BY n2.nspname, p2.proname, pg_get_function_identity_arguments(p2.oid))
        FROM pg_proc p2
        JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
        WHERE n2.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
          AND p2.oid <> ch.oid
          AND length(p2.proname) >= 6
          AND position(lower(p2.proname) IN ch.src) > 0
      ), '[]'::jsonb)
    ) ORDER BY ch.schema_name, ch.proname, ch.args)
    FROM chain ch
  ), '[]'::jsonb)
) AS result;
