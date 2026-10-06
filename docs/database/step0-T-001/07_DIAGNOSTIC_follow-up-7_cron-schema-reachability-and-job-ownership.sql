-- Name: [DIAGNOSTIC] T-001 follow-up 7 (v2) - pg_cron reachability and job ownership: schema USAGE and CREATE for every role, EXECUTE on every cron routine, privileges and policies on every cron relation, sanitized job inventory, role reachability to every job owner
--
-- Description: READ-ONLY seventh follow-up, revised after QA Round 64 (v2; supersedes v1 e79f647efe95, which was never authorized or run). Follow-up diagnostic 5 v2 (cb312adf53ca, Gate 4 accepted by the Founder) showed that
-- cron.schedule (two forms) and cron.unschedule (two forms) carry the PUBLIC EXECUTE privilege, so has_function_privilege returns true for anon,
-- authenticated and service_role; it did not measure USAGE on schema cron, the rights on the cron relations, or who owns scheduled jobs. A scheduled
-- job runs SQL, so before SQL work plan v5 (6961fb55dd69) treats scheduled jobs as outside the protected writer boundary (grp_batch_writer, plan C2)
-- this must be measured. QA Round 62 (answer to Round 61 C2) specified the content below; this file implements it.
-- What changed from v1 (each answers a QA Round 64 blocking finding):
--   * Blocking 1. v1 measured only USAGE on cron sequences. C3 now returns, for every sequence, the roles that effectively hold SELECT, UPDATE and
--     USAGE (has_sequence_privilege), and states explicitly that INSERT and DELETE do not apply (null, with insert_delete_applicable false); ordinary
--     relations keep SELECT, INSERT, UPDATE and DELETE (has_table_privilege). It also reports the sequence count.
--   * Blocking 2. v1 did not implement its fail-closed rule for jobs. C4 now makes the conservative outcome explicit: EVERY job is a positive lead
--     (classification_requires_review true) unless an enumerated rule classifies it; the rules are listed in the result (classification_rules) and
--     in the file, and today there is exactly one, R1_http_post_only (first word select; mentions net.http; no protected group object, no cron schema,
--     no DML or DDL word, no EXECUTE; and the only non-system routine name occurring in the command is net.http_post). A rule classifies a job only
--     LEXICALLY and never clears the behaviour of a compiled routine. C4 returns jobs_classified_by_enumerated_rule, jobs_requiring_review and
--     unclassified_job_ids; a job with a null or other first word, another routine name, or any flag is unclassified by construction. The job
--     fingerprint is now the FULL SHA-256 of the command (command_sha256, 64 hex characters), so later evidence can establish exact command equality
--     without returning command text. (QA Round 64, non-blocking 3: C4 also returns the matched routine identities for every overload; they remain
--     lexical leads, never one resolved overload and never behaviourally cleared.)
-- What it returns (one row, one jsonb column named `result`, per run):
--   * C1: the cron schema (owner, ACL, every ACL entry including PUBLIC), the effective USAGE and CREATE privilege on it for EVERY non-system role
--     (has_schema_privilege, which follows role inheritance), each role's superuser, login and BYPASSRLS attributes, and the cron.* server settings.
--   * C2: every routine in schema cron with owner, language, SECURITY DEFINER flag, ACL, whether PUBLIC may execute it, and the list of every role
--     that effectively holds EXECUTE (to be reconciled with K2: the seven C routines cron.alter_job, job_cache_invalidate, schedule x2,
--     schedule_in_database, unschedule x2).
--   * C3: every relation (table, view, materialized view, sequence, foreign table) in schema cron with owner, ACL, row-level security enabled and
--     forced, the roles that effectively hold SELECT, INSERT, UPDATE and DELETE (tables) or SELECT, UPDATE and USAGE (sequences), and every policy on cron relations.
--   * C4: every scheduled job (active and inactive): id, name, schedule, database, username, active flag, the command's length, its full
--     SHA-256, its first word, flags (mentions the protected group tables or invite_token or grp_batch_writer; mentions the cron
--     schema; mentions net.http; mentions INSERT, UPDATE, DELETE, MERGE, TRUNCATE, COPY, CREATE, ALTER, DROP, GRANT or REVOKE; mentions EXECUTE) and the
--     names and identities of the non-system routines whose names occur in it (whole-identifier match after lower-casing and removing double quotes, an
--     over-approximation); the fail-closed classification (above); grouped counts by database, username and active. **The command text is never returned** (a scheduled command can carry a
--     secret). A job that mentions the protected group objects, or whose command classification cannot be decided from these fields, is a positive lead.
--   * C5: for every job owner, and for postgres and supabase_admin, whether the role exists, its attributes, and whether each of anon, authenticated,
--     service_role, authenticator, dashboard_user and cli_login_postgres is a member of it, inherits its privileges, or can SET ROLE to it
--     (pg_has_role).
-- Known blind spots, stated: pg_cron's own permission checks (who may create, replace or remove a job that belongs to another role, and which roles a
-- job may run as) are in compiled code and are NOT inferred here from function ownership or ACLs; if the catalog evidence cannot establish them, that
-- uncertainty stays a positive lead and is never assumed safe. Job history (cron.job_run_details) is not read (it can contain command output);
-- only the privileges on it are measured in C3. Other schedulers or external callers (the Supabase dashboard, edge functions) are outside the database
-- and are an explicit Founder and platform assumption.
-- Five runs: C1 to C5. Each is one statement and returns one row with one jsonb column named `result`.
-- Privacy rule: no user-authored stored text and no person data is selected; only role, routine, relation and job names, schedules, flags, ACL text and
-- the SHA-256 of each command.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call; no pg_cron
-- function is called. Only catalog views and functions are used (pg_namespace, pg_class, pg_proc, pg_language, pg_policies, pg_roles, pg_settings,
-- aclexplode, has_schema_privilege, has_function_privilege, has_table_privilege, has_sequence_privilege, pg_has_role, pg_get_userbyid,
-- pg_get_function_identity_arguments, sha256, convert_to, encode) and, in C4 and C5 only, a read of the scheduler table cron.job (the precedent is J5 of
-- diagnostic 4 v4; if the scheduler schema is absent or unreadable the error itself is the evidence; save it unedited).
--
-- HOW TO RUN (five runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label (C1 to C5), unchanged. Save that file as
-- docs/discussions/evidence/T-001_FU7-raw_<dd-mm-yyyy>.raw.txt and keep it untouched; the derived .json files are made from it by script.
-- An error is evidence: save the error text under its label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN C1. Schema cron: owner, ACL, effective USAGE and CREATE for every role, cron settings
-- ============================================================================
WITH s AS (
  SELECT n.oid, n.nspname, pg_get_userbyid(n.nspowner) AS owner, n.nspacl
  FROM pg_namespace n
  WHERE n.nspname = 'cron'
),
rl AS (
  SELECT r.rolname, r.rolsuper, r.rolcanlogin, r.rolbypassrls
  FROM pg_roles r
  WHERE r.rolname !~ '^pg_'
)
SELECT jsonb_build_object(
  'run', 'C1',
  'schema_found', (SELECT count(*) FROM s),
  'schema', (SELECT jsonb_build_object('owner', s.owner,
                                       'acl', ARRAY(SELECT a::text FROM unnest(s.nspacl) AS a ORDER BY a::text),
                                       'acl_is_default', (s.nspacl IS NULL))
             FROM s),
  'acl_entries', (SELECT jsonb_agg(jsonb_build_object(
                     'grantee', CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END,
                     'privilege', x.privilege_type, 'grantable', x.is_grantable)
                     ORDER BY x.grantee, x.privilege_type)
                  FROM s, aclexplode(s.nspacl) AS x),
  'role_schema_privileges', (SELECT jsonb_agg(jsonb_build_object(
                                'role', rl.rolname, 'superuser', rl.rolsuper, 'can_login', rl.rolcanlogin,
                                'bypass_rls', rl.rolbypassrls,
                                'usage', has_schema_privilege(rl.rolname, 'cron', 'USAGE'),
                                'create', has_schema_privilege(rl.rolname, 'cron', 'CREATE'))
                                ORDER BY rl.rolname)
                             FROM rl),
  'cron_settings', (SELECT jsonb_agg(jsonb_build_object('name', ps.name, 'setting', ps.setting, 'source', ps.source)
                                     ORDER BY ps.name)
                    FROM pg_settings ps
                    WHERE ps.name LIKE 'cron.%')
) AS result;

-- ============================================================================
-- RUN C2. Every routine in schema cron: ACL and every role that can execute it
-- ============================================================================
WITH rl AS (
  SELECT r.rolname FROM pg_roles r WHERE r.rolname !~ '^pg_'
),
f AS (
  SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, p.prosecdef, l.lanname,
         ARRAY(SELECT a::text FROM unnest(p.proacl) AS a ORDER BY a::text) AS acl,
         (p.proacl IS NULL) AS acl_is_default,
         (p.proacl IS NULL
          OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) AS x WHERE x.grantee = 0 AND x.privilege_type = 'EXECUTE')) AS executable_by_public
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'cron'
)
SELECT jsonb_build_object(
  'run', 'C2',
  'routine_count', (SELECT count(*) FROM f),
  'routines', (SELECT jsonb_agg(jsonb_build_object(
                  'name', f.proname, 'args', f.args, 'language', f.lanname, 'owner', f.owner,
                  'security_definer', f.prosecdef, 'acl', f.acl, 'acl_is_default', f.acl_is_default,
                  'executable_by_public', f.executable_by_public,
                  'roles_with_execute', COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname)
                                                  FROM rl WHERE has_function_privilege(rl.rolname, f.oid, 'EXECUTE')),
                                                 '[]'::jsonb))
                  ORDER BY f.proname, f.args)
               FROM f)
) AS result;

-- ============================================================================
-- RUN C3. Every relation in schema cron: owner, ACL, RLS, effective privileges, policies
-- ============================================================================
WITH rl AS (
  SELECT r.rolname FROM pg_roles r WHERE r.rolname !~ '^pg_'
),
c AS (
  SELECT cl.oid, cl.relname, cl.relkind, pg_get_userbyid(cl.relowner) AS owner,
         cl.relrowsecurity, cl.relforcerowsecurity,
         ARRAY(SELECT a::text FROM unnest(cl.relacl) AS a ORDER BY a::text) AS acl,
         (cl.relacl IS NULL) AS acl_is_default
  FROM pg_class cl
  JOIN pg_namespace n ON n.oid = cl.relnamespace
  WHERE n.nspname = 'cron'
    AND cl.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
)
SELECT jsonb_build_object(
  'run', 'C3',
  'relation_count', (SELECT count(*) FROM c),
  'sequence_count', (SELECT count(*) FROM c WHERE relkind = 'S'),
  'relations', (SELECT jsonb_agg(jsonb_build_object(
                   'name', c.relname, 'kind', c.relkind, 'owner', c.owner,
                   'rls_enabled', c.relrowsecurity, 'rls_forced', c.relforcerowsecurity,
                   'acl', c.acl, 'acl_is_default', c.acl_is_default,
                   'is_sequence', (c.relkind = 'S'),
                   -- Tables, views and the like: SELECT, INSERT, UPDATE, DELETE through has_table_privilege.
                   -- Sequences: SELECT, UPDATE and USAGE through has_sequence_privilege; INSERT and DELETE do not apply (null).
                   'roles_with_select', CASE WHEN c.relkind = 'S'
                                             THEN COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_sequence_privilege(rl.rolname, c.oid, 'SELECT')), '[]'::jsonb)
                                             ELSE COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_table_privilege(rl.rolname, c.oid, 'SELECT')), '[]'::jsonb) END,
                   'roles_with_insert', CASE WHEN c.relkind = 'S' THEN NULL
                                             ELSE COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_table_privilege(rl.rolname, c.oid, 'INSERT')), '[]'::jsonb) END,
                   'roles_with_update', CASE WHEN c.relkind = 'S'
                                             THEN COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_sequence_privilege(rl.rolname, c.oid, 'UPDATE')), '[]'::jsonb)
                                             ELSE COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_table_privilege(rl.rolname, c.oid, 'UPDATE')), '[]'::jsonb) END,
                   'roles_with_delete', CASE WHEN c.relkind = 'S' THEN NULL
                                             ELSE COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_table_privilege(rl.rolname, c.oid, 'DELETE')), '[]'::jsonb) END,
                   'roles_with_sequence_usage', CASE WHEN c.relkind = 'S'
                                                     THEN COALESCE((SELECT jsonb_agg(rl.rolname ORDER BY rl.rolname) FROM rl WHERE has_sequence_privilege(rl.rolname, c.oid, 'USAGE')), '[]'::jsonb)
                                                     ELSE NULL END,
                   'insert_delete_applicable', (c.relkind <> 'S'))
                   ORDER BY c.relname)
                FROM c),
  'policy_count', (SELECT count(*) FROM pg_policies pol WHERE pol.schemaname = 'cron'),
  'policies', (SELECT jsonb_agg(jsonb_build_object(
                  'table', pol.tablename, 'policy', pol.policyname, 'command', pol.cmd,
                  'permissive', pol.permissive, 'roles', pol.roles, 'using', pol.qual, 'with_check', pol.with_check)
                  ORDER BY pol.tablename, pol.policyname)
               FROM pg_policies pol
               WHERE pol.schemaname = 'cron')
) AS result;

-- ============================================================================
-- RUN C4. Scheduled jobs: ownership, schedule, flags, full SHA-256 and fail-closed classification (never the command text)
-- ============================================================================
WITH routine AS (
  SELECT n.nspname || '.' || p.proname AS qname,
         n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS identity,
         lower(p.proname) AS lname
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
),
j AS (
  -- The command text itself is never returned (a scheduled command can carry a secret): only a length, the full SHA-256,
  -- the first word, and flags and routine names derived from it.
  SELECT jb.jobid, jb.jobname, jb.schedule, jb.database, jb.username, jb.active,
         length(jb.command) AS command_length,
         encode(sha256(convert_to(jb.command, 'UTF8')), 'hex') AS command_sha256,
         substring(lower(btrim(jb.command)) from '^[a-z_]+') AS first_word,
         lower(replace(jb.command, '"', '')) AS ncmd
  FROM cron.job jb
),
jf AS (
  SELECT j.*,
         (j.ncmd ~ '(^|[^a-z0-9_])(study_groups|study_group_members|content_group_shares|invite_token|batch_group_archives|batch_group_professors|access_requests|grp_batch_writer)([^a-z0-9_]|$)') AS mentions_protected_group_objects,
         (j.ncmd ~ '(^|[^a-z0-9_])cron[.]') AS mentions_cron_schema,
         (strpos(j.ncmd, 'net.http') > 0) AS mentions_net_http,
         (j.ncmd ~ '(^|[^a-z0-9_])(insert|update|delete|merge|truncate|copy|create|alter|drop|grant|revoke)([^a-z0-9_]|$)') AS mentions_dml_or_ddl,
         (j.ncmd ~ '(^|[^a-z0-9_])execute([^a-z0-9_]|$)') AS mentions_dynamic_sql,
         ARRAY(SELECT DISTINCT r.qname FROM routine r
               WHERE CASE WHEN r.lname ~ '^[a-z0-9_]+$'
                          THEN j.ncmd ~ ('(^|[^a-z0-9_])' || r.lname || '([^a-z0-9_]|$)')
                          ELSE strpos(j.ncmd, r.lname) > 0 END
               ORDER BY r.qname) AS mentioned_routine_names,
         ARRAY(SELECT r.identity FROM routine r
               WHERE CASE WHEN r.lname ~ '^[a-z0-9_]+$'
                          THEN j.ncmd ~ ('(^|[^a-z0-9_])' || r.lname || '([^a-z0-9_]|$)')
                          ELSE strpos(j.ncmd, r.lname) > 0 END
               ORDER BY r.identity) AS mentioned_routine_identities_all_overloads
  FROM j
),
jc AS (
  -- Fail-closed classification. EVERY job is a positive lead (classification_requires_review true) unless one of the enumerated rules below
  -- classifies it. A rule classifies a job only LEXICALLY, from the fields above; it never clears the behaviour of a compiled routine.
  --   R1_http_post_only: the first word is select; the command mentions net.http; it mentions no protected group object, no cron schema, no
  --   DML or DDL word and no EXECUTE; and the only non-system routine name that occurs in it is net.http_post.
  -- A job with a null or other first word, any other routine name, or any flag above is unclassified by construction.
  SELECT jf.*,
         CASE WHEN jf.first_word = 'select'
                   AND jf.mentions_net_http
                   AND NOT jf.mentions_protected_group_objects
                   AND NOT jf.mentions_cron_schema
                   AND NOT jf.mentions_dml_or_ddl
                   AND NOT jf.mentions_dynamic_sql
                   AND jf.mentioned_routine_names = ARRAY['net.http_post']::text[]
              THEN 'R1_http_post_only' END AS classification_rule
  FROM jf
)
SELECT jsonb_build_object(
  'run', 'C4',
  'job_count', (SELECT count(*) FROM jc),
  'active_job_count', (SELECT count(*) FROM jc WHERE active),
  'jobs_classified_by_enumerated_rule', (SELECT count(*) FROM jc WHERE classification_rule IS NOT NULL),
  'jobs_requiring_review', (SELECT count(*) FROM jc WHERE classification_rule IS NULL),
  'unclassified_job_ids', (SELECT jsonb_agg(jc.jobid ORDER BY jc.jobid) FROM jc WHERE jc.classification_rule IS NULL),
  'classification_rules', jsonb_build_array('R1_http_post_only'),
  'jobs_mentioning_protected_group_objects', (SELECT count(*) FROM jc WHERE mentions_protected_group_objects),
  'jobs_mentioning_cron_schema', (SELECT count(*) FROM jc WHERE mentions_cron_schema),
  'jobs_mentioning_dml_or_ddl', (SELECT count(*) FROM jc WHERE mentions_dml_or_ddl),
  'jobs_mentioning_dynamic_sql', (SELECT count(*) FROM jc WHERE mentions_dynamic_sql),
  'jobs_with_null_username', (SELECT count(*) FROM jc WHERE username IS NULL),
  'by_database_username_active', (SELECT jsonb_agg(jsonb_build_object('database', g.database, 'username', g.username,
                                                                      'active', g.active, 'jobs', g.n)
                                                   ORDER BY g.database, g.username, g.active)
                                  FROM (SELECT database, username, active, count(*) AS n FROM jc GROUP BY database, username, active) g),
  'jobs', (SELECT jsonb_agg(jsonb_build_object(
              'jobid', jc.jobid, 'jobname', jc.jobname, 'schedule', jc.schedule, 'database', jc.database,
              'username', jc.username, 'active', jc.active, 'command_length', jc.command_length,
              'command_sha256', jc.command_sha256, 'first_word', jc.first_word,
              'mentions_protected_group_objects', jc.mentions_protected_group_objects,
              'mentions_cron_schema', jc.mentions_cron_schema, 'mentions_net_http', jc.mentions_net_http,
              'mentions_dml_or_ddl', jc.mentions_dml_or_ddl, 'mentions_dynamic_sql', jc.mentions_dynamic_sql,
              'mentioned_routine_names', jc.mentioned_routine_names,
              'mentioned_routine_identities_all_overloads', jc.mentioned_routine_identities_all_overloads,
              'classification_rule', jc.classification_rule,
              'classification_requires_review', (jc.classification_rule IS NULL))
              ORDER BY jc.jobid)
           FROM jc)
) AS result;

-- ============================================================================
-- RUN C5. Role reachability to every job owner, postgres and supabase_admin
-- ============================================================================
WITH owners AS (
  SELECT DISTINCT jb.username AS rolename, true AS is_job_owner
  FROM cron.job jb
  WHERE jb.username IS NOT NULL
  UNION
  SELECT 'postgres', false
  UNION
  SELECT 'supabase_admin', false
),
o AS (
  -- A role is listed once; is_job_owner is true when any job runs as it.
  SELECT rolename, bool_or(is_job_owner) AS is_job_owner FROM owners GROUP BY rolename
),
cl AS (
  SELECT r.rolname AS from_role
  FROM pg_roles r
  WHERE r.rolname IN ('anon', 'authenticated', 'service_role', 'authenticator', 'dashboard_user', 'cli_login_postgres')
)
SELECT jsonb_build_object(
  'run', 'C5',
  'role_count', (SELECT count(*) FROM o),
  'roles', (SELECT jsonb_agg(jsonb_build_object(
               'role', o.rolename, 'is_job_owner', o.is_job_owner,
               'role_exists', EXISTS (SELECT 1 FROM pg_roles r WHERE r.rolname = o.rolename),
               'attributes', (SELECT jsonb_build_object('superuser', r.rolsuper, 'bypass_rls', r.rolbypassrls,
                                                        'can_login', r.rolcanlogin, 'create_role', r.rolcreaterole)
                              FROM pg_roles r WHERE r.rolname = o.rolename),
               'reachable_from', (SELECT jsonb_agg(jsonb_build_object(
                                     'from_role', cl.from_role,
                                     'is_member', pg_has_role(cl.from_role, o.rolename, 'MEMBER'),
                                     'inherits_privileges', pg_has_role(cl.from_role, o.rolename, 'USAGE'),
                                     'can_set_role', pg_has_role(cl.from_role, o.rolename, 'SET'))
                                     ORDER BY cl.from_role)
                                  FROM cl
                                  WHERE EXISTS (SELECT 1 FROM pg_roles r WHERE r.rolname = o.rolename)))
               ORDER BY o.rolename)
            FROM o)
) AS result;
