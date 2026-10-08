-- Name: [DIAGNOSTIC] T-002 D3 (v3) - writer closure for the stream B relations: foreign-key actions by event kind, routine and dynamic-SQL leads, transitive views and rules, scheduled jobs with a visibility assertion, signup and delete chains, callee closure
--
-- Description: READ-ONLY. Diagnostic D3 of docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md. v3 answers QA Round 18, which returned v2 `0218d615ba64` as
-- REVISION REQUIRED (v2 was never authorized or run):
--   * RUN P6 (callee closure) no longer uses a six-character name threshold or a plain substring: a callee lead is a WHOLE-IDENTIFIER match of the routine name
--     (any length, regular-expression metacharacters escaped) in the lower-cased body of the caller, which covers schema-qualified and quoted calls and every
--     overload (all overloads of a matching name are listed). It now returns the EDGES (caller identity to callee identity) for every relevant caller and the
--     identities of the frontier (routines at the depth cap that still have callee leads outside the closure), not counts. THE CATALOGUE CANNOT GIVE AN EXACT
--     CALL GRAPH FOR plpgsql (a plpgsql body records no dependency on the routines it calls), so this closure is a stated over-approximation. The safety claim of
--     plan v9 therefore does not rest on it: it rests on the SINKS (RUN P2 lists every routine that spells a target relation with a DML word and EVERY
--     non-extension routine that contains EXECUTE; each must be allowlisted by identity and hash or read and cleared). The edges only show which allowlisted sink
--     is reachable from which caller.
--   * RUN P7 (new): the callers that can delete from auth.users, because the foreign key study_sessions_user_id_fkey cascades from it: the owner, the EFFECTIVE
--     DELETE, TRUNCATE and UPDATE privilege of every non-system role on auth.users, the privileges PUBLIC holds (read from the ACL), the row-level-security
--     policies on auth.users, and every non-extension routine whose body names auth.users with a delete or truncate word or contains EXECUTE.
--   * The deterministic relation-by-DML-kind WRITER MATRIX is not assembled by hand: it is produced by the hashed script docs/database/t002/D-05_writer-matrix.mjs
--     from the saved results of these runs and of D4, so the comparison is reproducible from exact artifacts.
-- v2 answered QA Round 16, which returned v1 `6a88bc519299` as
-- REVISION REQUIRED (v1 was never authorized or run). It collects, from the system catalogue, every LEAD that a statement could INSERT, UPDATE, DELETE,
-- TRUNCATE, COPY or MERGE rows of: profiles, study_sessions, flashcards, notes, access_requests, disciplines, subjects, topics. It is a seed-and-closure lead
-- collector, not a proof: every output is a lead or an over-approximation, and anything it cannot read or cannot see is listed as UNRESOLVED and is never
-- counted as clean. The writer MATRIX (relation x DML kind: INSERT, UPDATE, UPSERT/ON CONFLICT DO UPDATE, MERGE, COPY FROM, DELETE, TRUNCATE) is assembled by
-- Claude from these runs and from the D4 code inventory, saved as a table, and audited by QA. An unresolved cell keeps the dependent file blocked.
-- What changed from v1 (QA Round 16, D-03 findings 1 to 5, plus the closure it implies):
--   1. RUN P1 now carries the EVENT KIND: for each target it returns which event on which ancestor (DELETE or UPDATE) reaches it and what happens to the target
--      (DELETE or UPDATE), with an OID-based cycle guard (not constraint names), a depth cap that is reported, and the frontier that was cut. A parent DELETE with
--      ON DELETE CASCADE deletes the child; SET NULL or SET DEFAULT updates it; a parent key UPDATE with a mutating ON UPDATE action updates it.
--   2. RUN P2 now lists EVERY non-extension routine whose body contains EXECUTE (dynamic SQL), whether or not it spells a target relation name, the identities of
--      every unreadable-language routine, every non-extension compiled (c, internal) routine by identity, and the compiled routines owned by extensions by count
--      per extension. Routines that spell a target relation name are listed as before.
--   3. RUN P3 now follows views and materialized views TRANSITIVELY (a view over a view over a target) to a stated depth, reports the frontier, and lists every
--      non-_RETURN rewrite rule (name, event, INSTEAD flag, md5 and length of the definition) on the targets and on every dependent view.
--   4. RUN P5 is unchanged from v1; RUN P6 (new) captures the transitive callee closure of the signup and delete chains by exact identity, language, security
--      mode, md5, flags and target-name mentions, to a stated depth, with the frontier reported.
--   5. RUN P4 now asserts cron.job visibility: it returns the running role, whether it is a superuser or has BYPASSRLS, the row-security flags and policies of
--      cron.job, and a boolean `visibility_unresolved` that is TRUE unless the role can see every row; the job list is then only as complete as that boolean.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * RUN P1 (foreign keys by event kind), RUN P2 (routine, dynamic-SQL and compiled/unreadable leads), RUN P3 (transitive views and rules), RUN P4 (scheduled
--     jobs: visibility assertion, safe hash of each command, structural flags; the command text is NEVER returned because it can hold a secret), RUN P5 (the
--     triggers on auth.users, the full definitions of the functions they call at the first level and of every overload of submit_access_request and
--     admin_delete_user_data), RUN P6 (callee closure of the P5 functions by identity and hash).
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Only catalogue views and functions, and the single read of cron.job, are used.
-- Blind spots, stated: whole-identifier text matching can list a name that is a column or a comment, and can miss a relation reached only through a name built at
-- run time (EXECUTE routines are therefore listed in full); the callee closure is a substring over-approximation to a depth cap and its frontier is reported; a
-- self-referencing foreign key is not followed (the OID guard stops at the table already seen); a mutating action reached through a SET NULL or SET DEFAULT that
-- changes a column which is itself referenced is followed conservatively as an UPDATE event; compiled routines cannot be read as text and are listed by identity
-- (non-extension) or by extension count; the cron table is read as the running role (see the P4 visibility assertion); counts are one statement's view at its run
-- time.
--
-- HOW TO RUN (seven runs: P1 to P7): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label, unchanged. Save as docs/discussions/evidence/T-002_D3-raw_<dd-mm-yyyy>.raw.txt and keep it untouched. An
-- error is evidence: save the error text under its label, do not edit and re-run (stop and report instead). A paste can be truncated: if a cell is cut, stop
-- and report; the verbatim-extracts pattern of docs/database/t001/run-extracts/ is used.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN P1: foreign keys and mutating reachability by event kind =====
WITH RECURSIVE t AS (
  SELECT c.oid, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
fk AS (
  SELECT k.oid AS fk_oid, k.conname, k.conrelid AS child, k.confrelid AS parent, k.confupdtype, k.confdeltype
  FROM pg_constraint k
  WHERE k.contype = 'f'
),
base AS (
  SELECT t.oid AS target, e.parent AS anc, 1 AS depth, ARRAY[t.oid, e.parent] AS seen, 'DELETE'::text AS anc_event,
         (CASE WHEN e.confdeltype = 'c' THEN 'DELETE' ELSE 'UPDATE' END)::text AS target_result, ARRAY[e.conname::text] AS path
  FROM t
  JOIN fk e ON e.child = t.oid
  WHERE e.confdeltype IN ('c', 'n', 'd')
  UNION ALL
  SELECT t.oid, e.parent, 1, ARRAY[t.oid, e.parent], 'UPDATE'::text, 'UPDATE'::text, ARRAY[e.conname::text]
  FROM t
  JOIN fk e ON e.child = t.oid
  WHERE e.confupdtype IN ('c', 'n', 'd')
),
reach AS (
  SELECT b.target, b.anc, b.depth, b.seen, b.anc_event, b.target_result, b.path
  FROM base b
  UNION ALL
  SELECT r.target, e2.parent, r.depth + 1, r.seen || e2.parent, g.gp_event, r.target_result, r.path || e2.conname::text
  FROM reach r
  JOIN fk e2 ON e2.child = r.anc
  CROSS JOIN (VALUES ('DELETE'::text), ('UPDATE'::text)) AS g(gp_event)
  WHERE r.depth < 12
    AND NOT (e2.parent = ANY (r.seen))
    AND (
         (r.anc_event = 'DELETE' AND g.gp_event = 'DELETE' AND e2.confdeltype = 'c')
      OR (r.anc_event = 'UPDATE' AND (
              (g.gp_event = 'DELETE' AND e2.confdeltype IN ('n', 'd'))
           OR (g.gp_event = 'UPDATE' AND e2.confupdtype IN ('c', 'n', 'd'))))
    )
),
agg AS (
  SELECT r.target, r.anc, r.anc_event, r.target_result, min(r.depth) AS min_depth, (array_agg(array_to_string(r.path, ' > ') ORDER BY r.depth))[1] AS example_path
  FROM reach r
  GROUP BY r.target, r.anc, r.anc_event, r.target_result
),
cut_frontier AS (
  SELECT DISTINCT r.target, r.anc
  FROM reach r
  WHERE r.depth = 12
    AND EXISTS (SELECT 1 FROM fk e3 WHERE e3.child = r.anc)
)
SELECT jsonb_build_object(
  'run', 'D3-P1',
  'targets_found', (SELECT count(*) FROM t),
  'depth_cap', 12,
  'event_kind_legend', 'anc_event is the event on the ancestor relation (DELETE or UPDATE of a key); target_result is what happens to the target row (DELETE by ON DELETE CASCADE; UPDATE by SET NULL, SET DEFAULT or a mutating ON UPDATE action)',
  'direct_foreign_keys', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'constraint', fk.conname, 'child', fk.child::regclass::text, 'parent', fk.parent::regclass::text,
      'on_update', fk.confupdtype::text, 'on_delete', fk.confdeltype::text,
      'definition_md5', md5(pg_get_constraintdef(fk.fk_oid)),
      'mutating_action', (fk.confupdtype IN ('c', 'n', 'd') OR fk.confdeltype IN ('c', 'n', 'd'))
    ) ORDER BY fk.child::regclass::text, fk.conname)
    FROM fk
    WHERE fk.child IN (SELECT oid FROM t) OR fk.parent IN (SELECT oid FROM t)
  ), '[]'::jsonb),
  'mutation_reachability', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'target', t.relname, 'ancestor', a.anc::regclass::text, 'ancestor_event', a.anc_event, 'target_result', a.target_result,
      'min_depth', a.min_depth, 'example_path', a.example_path
    ) ORDER BY t.relname, a.min_depth, a.anc::regclass::text, a.anc_event, a.target_result)
    FROM agg a
    JOIN t ON t.oid = a.target
  ), '[]'::jsonb),
  'frontier_cut_at_depth_cap', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('target', t.relname, 'ancestor', c.anc::regclass::text) ORDER BY t.relname, c.anc::regclass::text)
    FROM cut_frontier c
    JOIN t ON t.oid = c.target
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P2: routine leads, dynamic-SQL routines, unreadable and compiled routines =====
WITH rels(rel) AS (
  VALUES ('profiles'), ('study_sessions'), ('flashcards'), ('notes'), ('access_requests'), ('disciplines'), ('subjects'), ('topics')
),
r AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, l.lanname AS language, p.prosecdef, p.proconfig, p.proowner, p.proacl,
         p.prosrc AS src_raw, lower(p.prosrc) AS src,
         EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e') AS is_extension_member,
         (SELECT e.extname FROM pg_depend d JOIN pg_extension e ON e.oid = d.refobjid AND d.refclassid = 'pg_extension'::regclass
          WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e' LIMIT 1) AS extension_name
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
      'extension', h.extension_name,
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
  'dynamic_sql_routines_not_in_extensions', jsonb_build_object(
    'count', (SELECT count(*) FROM r WHERE NOT r.is_extension_member AND r.src ~ '\mexecute\M'),
    'note', 'every non-extension routine whose body contains the word EXECUTE, whether or not it spells a target relation name; each is an UNRESOLVED dynamic-SQL lead until its body is read',
    'identities', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'schema', r.schema_name, 'name', r.proname, 'args', r.args, 'owner', r.owner, 'language', r.language,
        'security_definer', r.prosecdef, 'src_md5', md5(r.src_raw),
        'names_a_target', ((SELECT count(*) FROM rels WHERE r.src ~ ('\m' || rels.rel || '\M')) > 0)
      ) ORDER BY r.schema_name, r.proname, r.args)
      FROM r
      WHERE NOT r.is_extension_member AND r.src ~ '\mexecute\M'
    ), '[]'::jsonb)
  ),
  'dynamic_sql_routines_in_extensions_by_extension', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('extension', q.extension_name, 'routines', q.n) ORDER BY q.extension_name)
    FROM (SELECT extension_name, count(*) AS n FROM r WHERE is_extension_member AND src ~ '\mexecute\M' GROUP BY extension_name) q
  ), '[]'::jsonb),
  'unreadable_language_routines', jsonb_build_object(
    'count', (SELECT count(*) FROM r WHERE r.language NOT IN ('plpgsql', 'sql', 'c', 'internal')),
    'identities', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('schema', r.schema_name, 'name', r.proname, 'args', r.args, 'language', r.language, 'extension', r.extension_name)
                       ORDER BY r.schema_name, r.proname, r.args)
      FROM r WHERE r.language NOT IN ('plpgsql', 'sql', 'c', 'internal')
    ), '[]'::jsonb)
  ),
  'compiled_routines', jsonb_build_object(
    'not_in_extensions_count', (SELECT count(*) FROM r WHERE r.language IN ('c', 'internal') AND NOT r.is_extension_member),
    'not_in_extensions_identities', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('schema', r.schema_name, 'name', r.proname, 'args', r.args, 'language', r.language, 'owner', r.owner)
                       ORDER BY r.schema_name, r.proname, r.args)
      FROM r WHERE r.language IN ('c', 'internal') AND NOT r.is_extension_member
    ), '[]'::jsonb),
    'in_extensions_by_extension', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('extension', q.extension_name, 'routines', q.n) ORDER BY q.extension_name)
      FROM (SELECT extension_name, count(*) AS n FROM r WHERE language IN ('c', 'internal') AND is_extension_member GROUP BY extension_name) q
    ), '[]'::jsonb),
    'note', 'compiled routines cannot be read as text; user-defined ones are listed by identity, extension-owned ones by count per extension; none is claimed clean'
  )
) AS result;

-- ===== RUN P3: views and materialized views (transitive) and rewrite rules =====
WITH RECURSIVE t AS (
  SELECT c.oid, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
closure(oid, depth, root) AS (
  SELECT t.oid, 0, t.relname::text
  FROM t
  UNION
  SELECT v.oid, c.depth + 1, c.root
  FROM closure c
  JOIN pg_depend d ON d.refobjid = c.oid AND d.classid = 'pg_rewrite'::regclass
  JOIN pg_rewrite rw ON rw.oid = d.objid
  JOIN pg_class v ON v.oid = rw.ev_class
  WHERE v.oid <> c.oid AND c.depth < 8
),
dependents AS (
  SELECT c.oid, min(c.depth) AS depth, array_agg(DISTINCT c.root ORDER BY c.root) AS roots
  FROM closure c
  WHERE c.depth > 0
  GROUP BY c.oid
),
frontier AS (
  SELECT DISTINCT c.oid
  FROM closure c
  WHERE c.depth = 8
    AND EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid AND d.classid = 'pg_rewrite'::regclass
                WHERE d.refobjid = c.oid AND rw.ev_class <> c.oid)
),
all_rel AS (
  SELECT t.oid FROM t
  UNION
  SELECT dependents.oid FROM dependents
)
SELECT jsonb_build_object(
  'run', 'D3-P3',
  'depth_cap', 8,
  'dependent_views', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', vn.nspname, 'view', v.relname, 'kind', v.relkind::text, 'min_depth', d.depth, 'depends_transitively_on', to_jsonb(d.roots),
      'definition_md5', md5(pg_get_viewdef(v.oid)), 'definition_length', length(pg_get_viewdef(v.oid)),
      'accepts_update', ((pg_relation_is_updatable(v.oid, false) & 4) <> 0),
      'accepts_insert', ((pg_relation_is_updatable(v.oid, false) & 8) <> 0),
      'accepts_delete', ((pg_relation_is_updatable(v.oid, false) & 16) <> 0)
    ) ORDER BY vn.nspname, v.relname)
    FROM dependents d
    JOIN pg_class v ON v.oid = d.oid
    JOIN pg_namespace vn ON vn.oid = v.relnamespace
  ), '[]'::jsonb),
  'rewrite_rules_on_targets_and_dependents', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', rn.nspname, 'relation', rc.relname, 'relation_kind', rc.relkind::text, 'rule', rw.rulename, 'event', rw.ev_type::text,
      'instead', rw.is_instead, 'definition_md5', md5(pg_get_ruledef(rw.oid)), 'definition_length', length(pg_get_ruledef(rw.oid))
    ) ORDER BY rn.nspname, rc.relname, rw.rulename)
    FROM all_rel a
    JOIN pg_rewrite rw ON rw.ev_class = a.oid AND rw.rulename <> '_RETURN'
    JOIN pg_class rc ON rc.oid = rw.ev_class
    JOIN pg_namespace rn ON rn.oid = rc.relnamespace
  ), '[]'::jsonb),
  'frontier_cut_at_depth_cap', COALESCE((
    SELECT jsonb_agg(f.oid::regclass::text ORDER BY f.oid::regclass::text) FROM frontier f
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P4: scheduled jobs, with a visibility assertion (command text is never returned) =====
WITH me AS (
  SELECT ro.rolname::text AS rolname, ro.rolsuper, ro.rolbypassrls
  FROM pg_roles ro
  WHERE ro.rolname = current_user
),
cj AS (
  SELECT c.relrowsecurity, c.relforcerowsecurity, c.relowner, pg_get_userbyid(c.relowner)::text AS owner
  FROM pg_class c
  WHERE c.oid = 'cron.job'::regclass
),
vis AS (
  SELECT (me.rolsuper OR me.rolbypassrls OR NOT cj.relrowsecurity OR (me.rolname = cj.owner AND NOT cj.relforcerowsecurity)) AS can_see_all_rows
  FROM me, cj
)
SELECT jsonb_build_object(
  'run', 'D3-P4',
  'running_role', (SELECT jsonb_build_object('current_user', current_user::text, 'session_user', session_user::text,
                                             'superuser', me.rolsuper, 'bypassrls', me.rolbypassrls) FROM me),
  'cron_job_table', (SELECT jsonb_build_object('owner', cj.owner, 'row_security_enabled', cj.relrowsecurity, 'row_security_forced', cj.relforcerowsecurity) FROM cj),
  'cron_job_policies', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('name', pol.polname, 'command', pol.polcmd::text, 'using', pg_get_expr(pol.polqual, pol.polrelid)) ORDER BY pol.polname)
    FROM pg_policy pol
    WHERE pol.polrelid = 'cron.job'::regclass
  ), '[]'::jsonb),
  'can_see_all_rows', (SELECT can_see_all_rows FROM vis),
  'visibility_unresolved', (SELECT NOT can_see_all_rows FROM vis),
  'visibility_note', 'if visibility_unresolved is true the job list below may omit other users jobs and must not be read as complete',
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

-- ===== RUN P6: callee closure of the signup and delete chains, by exact identity, hash and named edges =====
WITH RECURSIVE rels(rel) AS (
  VALUES ('profiles'), ('study_sessions'), ('flashcards'), ('notes'), ('access_requests'), ('disciplines'), ('subjects'), ('topics')
),
seed AS (
  SELECT p.oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname IN ('submit_access_request', 'admin_delete_user_data')
  UNION
  SELECT g.tgfoid
  FROM pg_trigger g
  JOIN pg_class c ON c.oid = g.tgrelid
  JOIN pg_namespace n2 ON n2.oid = c.relnamespace
  WHERE n2.nspname = 'auth' AND c.relname = 'users' AND NOT g.tgisinternal
),
names AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         ('\m' || regexp_replace(lower(p.proname::text), '([^a-z0-9_])', '\\\1', 'g') || '\M') AS pat
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND p.prokind IN ('f', 'p')
),
cl(oid, depth) AS (
  SELECT s.oid, 0 FROM seed s
  UNION
  SELECT nm.oid, cl.depth + 1
  FROM cl
  JOIN pg_proc pc ON pc.oid = cl.oid
  JOIN names nm ON nm.oid <> pc.oid AND lower(pc.prosrc) ~ nm.pat
  WHERE cl.depth < 3
),
cl_min AS (
  SELECT cl.oid, min(cl.depth) AS depth FROM cl GROUP BY cl.oid
),
rt AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args, l.lanname AS language,
         p.prosecdef, c.depth, lower(p.prosrc) AS src, p.prosrc AS src_raw,
         (SELECT array_agg(rels.rel ORDER BY rels.rel) FROM rels WHERE lower(p.prosrc) ~ ('\m' || rels.rel || '\M')) AS mentions
  FROM cl_min c
  JOIN pg_proc p ON p.oid = c.oid
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
),
rel_rt AS (
  SELECT rt.*
  FROM rt
  WHERE rt.mentions IS NOT NULL OR rt.language NOT IN ('plpgsql', 'sql') OR rt.src ~ '\m(insert|update|delete|truncate|merge|copy|execute)\M'
),
edges AS (
  SELECT rr.oid AS caller, nm.oid AS callee, nm.schema_name AS callee_schema, nm.proname AS callee_name, nm.args AS callee_args
  FROM rel_rt rr
  JOIN names nm ON nm.oid <> rr.oid AND rr.src ~ nm.pat
),
frontier AS (
  SELECT rt.oid AS caller, nm.oid AS callee, nm.schema_name AS callee_schema, nm.proname AS callee_name, nm.args AS callee_args
  FROM rt
  JOIN names nm ON nm.oid <> rt.oid AND rt.src ~ nm.pat
  WHERE rt.depth = 3
    AND nm.oid NOT IN (SELECT cm.oid FROM cl_min cm)
)
SELECT jsonb_build_object(
  'run', 'D3-P6',
  'depth_cap', 3,
  'method', 'whole-identifier name match in the lower-cased caller body, any length, all overloads; an OVER-approximation, not an exact call graph',
  'closure_size', (SELECT count(*) FROM rt),
  'relevant_routines', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'depth', rr.depth, 'schema', rr.schema_name, 'name', rr.proname, 'args', rr.args, 'language', rr.language,
      'language_unresolved', (rr.language NOT IN ('plpgsql', 'sql')), 'security_definer', rr.prosecdef, 'src_md5', md5(rr.src_raw),
      'mentions', to_jsonb(rr.mentions),
      'flags', jsonb_build_object(
        'insert', (rr.src ~ '\minsert\M'), 'update', (rr.src ~ '\mupdate\M'), 'delete', (rr.src ~ '\mdelete\M'),
        'truncate', (rr.src ~ '\mtruncate\M'), 'merge', (rr.src ~ '\mmerge\M'), 'copy', (rr.src ~ '\mcopy\M'),
        'dynamic_sql_execute', (rr.src ~ '\mexecute\M')
      ),
      'callees', COALESCE((
        SELECT jsonb_agg(jsonb_build_object('schema', e.callee_schema, 'name', e.callee_name, 'args', e.callee_args)
                         ORDER BY e.callee_schema, e.callee_name, e.callee_args)
        FROM edges e WHERE e.caller = rr.oid
      ), '[]'::jsonb)
    ) ORDER BY rr.depth, rr.schema_name, rr.proname, rr.args)
    FROM rel_rt rr
  ), '[]'::jsonb),
  'other_routines_in_closure', (SELECT count(*) FROM rt WHERE NOT EXISTS (SELECT 1 FROM rel_rt rr WHERE rr.oid = rt.oid)),
  'frontier_edges_outside_closure', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'caller_schema', pc.nspname, 'caller_name', pp.proname, 'caller_args', pg_get_function_identity_arguments(pp.oid),
      'callee_schema', f.callee_schema, 'callee_name', f.callee_name, 'callee_args', f.callee_args
    ) ORDER BY pc.nspname, pp.proname, f.callee_schema, f.callee_name, f.callee_args)
    FROM frontier f
    JOIN pg_proc pp ON pp.oid = f.caller
    JOIN pg_namespace pc ON pc.oid = pp.pronamespace
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P7: who can delete from auth.users (the parent of the study_sessions cascade) =====
WITH au AS (
  SELECT c.oid, c.relowner, c.relacl, c.relrowsecurity, c.relforcerowsecurity
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'auth' AND c.relname = 'users'
),
r AS (
  SELECT ro.rolname::text AS rolname, ro.rolsuper, ro.rolbypassrls
  FROM pg_roles ro
  WHERE ro.rolname !~ '^pg_'
),
rt AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args, pg_get_userbyid(p.proowner) AS owner,
         l.lanname AS language, p.prosecdef, p.proowner, p.proacl, lower(p.prosrc) AS src, p.prosrc AS src_raw,
         EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e') AS is_extension_member
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND p.prokind IN ('f', 'p')
)
SELECT jsonb_build_object(
  'run', 'D3-P7',
  'auth_users_found', (SELECT count(*) FROM au),
  'owner', (SELECT pg_get_userbyid(au.relowner) FROM au),
  'row_security', (SELECT jsonb_build_object('enabled', au.relrowsecurity, 'forced', au.relforcerowsecurity) FROM au),
  'effective_privileges_of_roles_holding_any_of_delete_truncate_update', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'role', r.rolname, 'superuser', r.rolsuper, 'bypassrls_rls_fact_only', r.rolbypassrls,
      'delete', has_table_privilege(r.rolname::name, au.oid, 'DELETE'),
      'truncate', has_table_privilege(r.rolname::name, au.oid, 'TRUNCATE'),
      'update', has_table_privilege(r.rolname::name, au.oid, 'UPDATE')
    ) ORDER BY r.rolname)
    FROM r CROSS JOIN au
    WHERE has_table_privilege(r.rolname::name, au.oid, 'DELETE')
       OR has_table_privilege(r.rolname::name, au.oid, 'TRUNCATE')
       OR has_table_privilege(r.rolname::name, au.oid, 'UPDATE')
  ), '[]'::jsonb),
  'roles_checked', (SELECT count(*) FROM r),
  'public_pseudo_role_privileges_from_acl', (
    SELECT to_jsonb(ARRAY(
      SELECT x.privilege_type
      FROM aclexplode(COALESCE(au.relacl, acldefault('r', au.relowner))) AS x
      WHERE x.grantee = 0
      ORDER BY 1
    ))
    FROM au),
  'policies_on_auth_users', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('name', pol.polname, 'command', pol.polcmd::text, 'using', pg_get_expr(pol.polqual, pol.polrelid)) ORDER BY pol.polname)
    FROM pg_policy pol
    WHERE pol.polrelid = (SELECT au.oid FROM au)
  ), '[]'::jsonb),
  'routines_naming_auth_users_with_delete_truncate_or_dynamic_sql', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', rt.schema_name, 'name', rt.proname, 'args', rt.args, 'owner', rt.owner, 'language', rt.language,
      'security_definer', rt.prosecdef, 'src_md5', md5(rt.src_raw), 'extension_member', rt.is_extension_member,
      'flags', jsonb_build_object('delete', (rt.src ~ '\mdelete\M'), 'truncate', (rt.src ~ '\mtruncate\M'), 'dynamic_sql_execute', (rt.src ~ '\mexecute\M')),
      'execute_grantees', to_jsonb(ARRAY(
        SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END
        FROM aclexplode(COALESCE(rt.proacl, acldefault('f', rt.proowner))) AS x
        WHERE x.privilege_type = 'EXECUTE'
        ORDER BY 1
      ))
    ) ORDER BY rt.schema_name, rt.proname, rt.args)
    FROM rt
    WHERE rt.src ~ '"?auth"?\s*\.\s*"?users"?'
      AND (rt.src ~ '\m(delete|truncate)\M' OR rt.src ~ '\mexecute\M')
  ), '[]'::jsonb)
) AS result;
