-- Name: [DIAGNOSTIC] T-001 follow-up 4 (v4) - role graph and execution identity, routine inventory, writer and reader call-closure across every non-system schema, definitions, views/rules/triggers/foreign keys, policies, scheduled jobs, non-batch group RPC bodies
--
-- Description: READ-ONLY fourth follow-up, revised after QA Round 42 (v2), QA Round 44 (v3) and QA Round 46 (v4; supersedes v3 97c9b9f9f65e, v2 b9f389b7fd1e and v1 64392d6daff9). It measures the
-- facts that the T-001 SQL design needs before any SQL is authored: QA Round 40 condition 2 (the exact boundary of the future
-- no-login writer role grp_batch_writer), the complete set of routines that can write or read the group tables, and the live
-- bodies that decide whether client INSERT and UPDATE privileges on the group tables can ever be revoked.
-- What changed from v1 (each one answers a QA Round 42 finding):
--   * J1 no longer filters to seven named roles. It returns the execution identity (session_user, current_user), EVERY role
--     with its attributes, EVERY membership edge (member, granted role, grantor, admin, inherit and set options), and the
--     server's own answer, from pg_has_role, to "is A a member of B / does A inherit B's privileges / can A SET ROLE to B" for
--     every pair of roles, so transitive paths through any intermediate role are shown without any reasoning of ours. It also
--     returns the default privileges (pg_default_acl) that would give new objects to client roles.
--   * J2 is no longer a text-match lead list, and (v4, after QA Round 46) it is no longer public-only. J2a inventories EVERY public
--     routine (including overloads) with owner, language, security definer flag, search_path, ACL and body flags, plus a count
--     per schema and language of the routines in every other non-system schema. J2b computes the call-closure across EVERY
--     non-system schema (everything except pg_catalog, information_schema and the toast and temporary schemas) with
--     schema-qualified identities, over the routines whose body can be read (languages plpgsql and sql; routines in any other
--     language are counted by J2a): a routine is a seed if its source mentions study_group or content_group_shares (any form: quoted, ONLY, MERGE,
--     aliases, joins, reads), invite_token, a view over the group tables, or dynamic SQL (EXECUTE); the closure then adds every
--     routine that calls a member, directly or through other routines, by a schema-qualified call or by ANY bare-name match in any non-system schema (a deliberate over-approximation: the
--     effective search_path of a caller is not assumed); it also lists the call edges
--     inside the closure. J2c-1 and J2c-2 return the FULL DEFINITION of every routine in that closure (two runs so that no
--     result cell is oversized). J2d returns what text matching cannot see: views and materialized views over the tables,
--     rewrite rules, triggers on the tables and triggers whose function is in the closure, and every foreign key that touches
--     the two tables (cascades are writes).
--   * J4 returns every row-level security policy, on any table, whose text mentions the group tables or calls a routine of the
--     closure, with full text (the readers and write policies that must treat only status 'active' as access, brief A 6.7).
--   * J5 lists scheduled jobs (names, schedules, flags only, never the command text, because a scheduled command can carry a
--     secret) and which non-system routines each calls by name. A positive flag (the command mentions the group tables or content_group_shares, or it calls a
--     routine that is in the J2b closure or in the reviewed manifests) blocks every dependent SQL file until a secret-redacted
--     capture of that command is reviewed (plan v4, section 3).
--   * J3 (bodies of create_study_group, invite_to_group, accept_group_invite, decline_group_invite, rename_batch_group) is kept
--     as a guaranteed capture even if the closure missed one.
-- Known blind spots, stated: the closure is a name-and-text over-approximation (a superset: it can include routines that do not
-- write); it cannot see SQL built from a string assembled out of parts (for example 'study_' || 'groups') and not containing
-- the word EXECUTE, and it cannot inspect objects that do not exist yet (the invite relation). Those are closed by the design,
-- not by this file: the guard trigger refuses any protected change that does not come from grp_batch_writer, and the Gate 2 test
-- asserts an exact reviewed manifest and fails when a routine in a fresh closure is not in it.
-- Nine runs: J1, J2a, J2b, J2c-1, J2c-2, J2d, J3, J4 and J5. Each is one statement and returns one row with one json column named `result`.
-- Privacy rule: no user-authored stored text and no person data is selected. Results are role names and flags, routine names,
-- owners and source text (catalog text), policy text, and job names, schedules and flags.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function
-- call. Only catalog functions and views are used (pg_roles, pg_auth_members, pg_has_role, pg_default_acl, pg_proc, pg_class,
-- pg_views, pg_matviews, pg_rules, pg_trigger, pg_constraint, pg_policies, pg_get_userbyid, pg_get_function_identity_arguments,
-- pg_get_functiondef, pg_get_triggerdef, pg_get_constraintdef, session_user, current_user, current_setting) and, in J5 only, a
-- read of the scheduler table cron.job (if the scheduler schema is absent the error itself is the evidence; save it unedited).
--
-- HOW TO RUN (nine runs): select the text of ONE run (from its first line to its closing semicolon), click Run, copy the single
-- result cell, and keep it unchanged. Save each result as an unedited raw export under docs/discussions/evidence/ named
-- T-001_FU4-<run>_<dd-mm-yyyy>.json. An error is evidence: save the error text, do not edit and re-run.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN J1. Execution identity, every role, every membership edge, the server's own reachability answer, default privileges
-- ============================================================================
WITH r AS (
  SELECT oid, rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolbypassrls
  FROM pg_roles
),
reach AS (
  SELECT a.rolname AS member_role, b.rolname AS target_role,
         pg_has_role(a.oid, b.oid, 'MEMBER') AS is_member,
         pg_has_role(a.oid, b.oid, 'USAGE')  AS inherits_privileges,
         pg_has_role(a.oid, b.oid, 'SET')    AS can_set_role
  FROM r a JOIN r b ON a.oid <> b.oid
  WHERE NOT a.rolsuper
)
SELECT jsonb_build_object(
  'identity', jsonb_build_object(
      'session_user', session_user, 'current_user', current_user, 'database', current_database(),
      'server_version', current_setting('server_version'),
      'database_owner', (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = current_database())),
  'roles', (SELECT jsonb_agg(jsonb_build_object(
        'role', r.rolname, 'can_login', r.rolcanlogin, 'superuser', r.rolsuper, 'bypass_rls', r.rolbypassrls,
        'create_role', r.rolcreaterole, 'create_db', r.rolcreatedb, 'replication', r.rolreplication,
        'inherits', r.rolinherit) ORDER BY r.rolname) FROM r),
  'membership_edges', (SELECT jsonb_agg(jsonb_build_object(
        'member', m.rolname, 'granted_role', g.rolname, 'grantor', gr.rolname, 'admin_option', am.admin_option,
        'inherit_option', am.inherit_option, 'set_option', am.set_option
      ) ORDER BY m.rolname, g.rolname)
      FROM pg_auth_members am
      JOIN r m ON m.oid = am.member
      JOIN r g ON g.oid = am.roleid
      LEFT JOIN r gr ON gr.oid = am.grantor),
  'reachability_for_non_superuser_roles', (SELECT jsonb_agg(jsonb_build_object(
        'member', member_role, 'target', target_role, 'member_of', is_member,
        'inherits_privileges_of', inherits_privileges, 'can_set_role_to', can_set_role
      ) ORDER BY member_role, target_role)
      FROM reach WHERE is_member OR inherits_privileges OR can_set_role),
  'default_privileges', (SELECT jsonb_agg(jsonb_build_object(
        'owner', pg_get_userbyid(d.defaclrole), 'schema', n.nspname, 'object_type', d.defaclobjtype::text,
        'acl', d.defaclacl::text[]) ORDER BY pg_get_userbyid(d.defaclrole), n.nspname, d.defaclobjtype)
      FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace)
) AS result;

-- ============================================================================
-- RUN J2a. Inventory of EVERY public routine (all overloads), with owner, language, definer flag, search_path, ACL and body flags
-- ============================================================================
WITH f AS (
  SELECT p.oid, p.proname, p.prokind, p.prosecdef, p.provolatile, p.proconfig, p.prosrc, p.proacl, p.proowner,
         (p.prorettype = 'trigger'::regtype) AS is_trigger_function, l.lanname,
         pg_get_function_identity_arguments(p.oid) AS args
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'public'
)
SELECT jsonb_build_object(
  'public_routine_count', (SELECT count(*) FROM f),
  'routines', (SELECT jsonb_agg(jsonb_build_object(
        'name', proname, 'args', args, 'kind', prokind, 'language', lanname,
        'security_definer', prosecdef, 'volatility', provolatile, 'owner', pg_get_userbyid(proowner),
        'is_trigger_function', is_trigger_function,
        'search_path_set', (proconfig IS NOT NULL AND EXISTS (SELECT 1 FROM unnest(proconfig) c WHERE c LIKE 'search_path=%')),
        'acl', proacl::text[],
        'mentions_study_group', prosrc ~* 'study_group',
        'mentions_content_group_shares', prosrc ~* 'content_group_shares',
        'mentions_invite_token', prosrc ~* 'invite_token',
        'mentions_access_requests', prosrc ~* 'access_request',
        'has_dynamic_sql', prosrc ~* '\mexecute\s'
      ) ORDER BY proname, args) FROM f),
  'routines_in_other_non_system_schemas_summary', (SELECT jsonb_agg(jsonb_build_object(
        'schema', s.nspname, 'language', s.lanname, 'routines', s.cnt, 'security_definer', s.defs
      ) ORDER BY s.nspname, s.lanname)
      FROM (SELECT n.nspname, l.lanname, count(*) AS cnt, count(*) FILTER (WHERE p.prosecdef) AS defs
            FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_language l ON l.oid = p.prolang
            WHERE n.nspname NOT IN ('public', 'pg_catalog', 'information_schema', 'pg_toast')
              AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
            GROUP BY n.nspname, l.lanname) s)
) AS result;

-- ============================================================================
-- RUN J2b. Call-closure of routines that can touch the group tables: members, call edges
-- ============================================================================
WITH RECURSIVE
f AS (
  SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
         pg_get_userbyid(p.proowner) AS owner_role, p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
    AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
vw AS (
  SELECT viewname::text AS vname FROM pg_views WHERE definition ~* 'study_group|content_group_shares'
  UNION
  SELECT matviewname::text FROM pg_matviews WHERE definition ~* 'study_group|content_group_shares'
),
seed AS (
  SELECT f.oid FROM f
  WHERE f.prosrc ~* 'study_group|content_group_shares' OR f.prosrc ~* 'invite_token' OR f.prosrc ~* '\mexecute\s'
     OR EXISTS (SELECT 1 FROM vw WHERE f.prosrc ~* ('\m' || vw.vname || '\M'))
),
closure(oid) AS (
  SELECT oid FROM seed
  UNION
  SELECT c.oid
  FROM closure cl
  JOIN f g ON g.oid = cl.oid
  JOIN f c ON c.oid <> g.oid
   AND ( c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
         OR c.prosrc ~* ('\m' || g.proname || '\s*\(') )
),
calls AS (
  SELECT c.oid AS caller, g.oid AS callee
  FROM closure cc
  JOIN f c ON c.oid = cc.oid
  JOIN closure cg ON cg.oid <> cc.oid
  JOIN f g ON g.oid = cg.oid
  WHERE c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
     OR c.prosrc ~* ('\m' || g.proname || '\s*\(')
)
SELECT jsonb_build_object(
  'seed_count', (SELECT count(*) FROM seed),
  'closure_count', (SELECT count(*) FROM closure),
  'closure', (SELECT jsonb_agg(jsonb_build_object(
        'schema', f.nspname, 'name', f.proname, 'args', f.args, 'security_definer', f.prosecdef, 'owner', f.owner_role,
        'is_seed', EXISTS (SELECT 1 FROM seed s WHERE s.oid = f.oid),
        'seed_reasons', (SELECT jsonb_agg(reason) FROM (
              SELECT 'mentions_group_tables_or_content_group_shares' AS reason WHERE f.prosrc ~* 'study_group|content_group_shares'
              UNION ALL SELECT 'mentions_invite_token' WHERE f.prosrc ~* 'invite_token'
              UNION ALL SELECT 'has_dynamic_sql' WHERE f.prosrc ~* '\mexecute\s'
              UNION ALL SELECT 'mentions_view_over_group_tables' WHERE EXISTS (SELECT 1 FROM vw WHERE f.prosrc ~* ('\m' || vw.vname || '\M'))
          ) x)
      ) ORDER BY f.nspname, f.proname, f.args)
      FROM f WHERE f.oid IN (SELECT oid FROM closure)),
  'call_edges_inside_closure', (SELECT jsonb_agg(jsonb_build_object(
        'caller', cf.nspname || '.' || cf.proname || '(' || cf.args || ')', 'callee', gf.nspname || '.' || gf.proname || '(' || gf.args || ')'
      ) ORDER BY cf.nspname, cf.proname, cf.args, gf.proname, gf.args)
      FROM calls k
      JOIN f cf ON cf.oid = k.caller JOIN f gf ON gf.oid = k.callee
      WHERE k.caller IN (SELECT oid FROM closure) AND k.callee IN (SELECT oid FROM closure))
) AS result;

-- ============================================================================
-- RUN J2c-1. FULL DEFINITIONS of the closure, first half (ordered by name and arguments)
-- ============================================================================
WITH RECURSIVE
f AS (
  SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
         pg_get_userbyid(p.proowner) AS owner_role, p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
    AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
vw AS (
  SELECT viewname::text AS vname FROM pg_views WHERE definition ~* 'study_group|content_group_shares'
  UNION
  SELECT matviewname::text FROM pg_matviews WHERE definition ~* 'study_group|content_group_shares'
),
seed AS (
  SELECT f.oid FROM f
  WHERE f.prosrc ~* 'study_group|content_group_shares' OR f.prosrc ~* 'invite_token' OR f.prosrc ~* '\mexecute\s'
     OR EXISTS (SELECT 1 FROM vw WHERE f.prosrc ~* ('\m' || vw.vname || '\M'))
),
closure(oid) AS (
  SELECT oid FROM seed
  UNION
  SELECT c.oid
  FROM closure cl
  JOIN f g ON g.oid = cl.oid
  JOIN f c ON c.oid <> g.oid
   AND ( c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
         OR c.prosrc ~* ('\m' || g.proname || '\s*\(') )
),
calls AS (
  SELECT c.oid AS caller, g.oid AS callee
  FROM closure cc
  JOIN f c ON c.oid = cc.oid
  JOIN closure cg ON cg.oid <> cc.oid
  JOIN f g ON g.oid = cg.oid
  WHERE c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
     OR c.prosrc ~* ('\m' || g.proname || '\s*\(')
),
numbered AS (
  SELECT f.*, ntile(2) OVER (ORDER BY f.nspname, f.proname, f.args) AS tile FROM f WHERE f.oid IN (SELECT oid FROM closure)
)
SELECT jsonb_build_object(
  'tile', 1, 'tiles_total', 2,
  'closure_count', (SELECT count(*) FROM numbered),
  'in_this_run', (SELECT count(*) FROM numbered WHERE tile = 1),
  'functions', (SELECT jsonb_agg(jsonb_build_object(
        'schema', nspname, 'name', proname, 'args', args, 'security_definer', prosecdef, 'owner', owner_role,
        'definition', pg_get_functiondef(oid)) ORDER BY nspname, proname, args)
      FROM numbered WHERE tile = 1)
) AS result;

-- ============================================================================
-- RUN J2c-2. FULL DEFINITIONS of the closure, second half
-- ============================================================================
WITH RECURSIVE
f AS (
  SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
         pg_get_userbyid(p.proowner) AS owner_role, p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
    AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
vw AS (
  SELECT viewname::text AS vname FROM pg_views WHERE definition ~* 'study_group|content_group_shares'
  UNION
  SELECT matviewname::text FROM pg_matviews WHERE definition ~* 'study_group|content_group_shares'
),
seed AS (
  SELECT f.oid FROM f
  WHERE f.prosrc ~* 'study_group|content_group_shares' OR f.prosrc ~* 'invite_token' OR f.prosrc ~* '\mexecute\s'
     OR EXISTS (SELECT 1 FROM vw WHERE f.prosrc ~* ('\m' || vw.vname || '\M'))
),
closure(oid) AS (
  SELECT oid FROM seed
  UNION
  SELECT c.oid
  FROM closure cl
  JOIN f g ON g.oid = cl.oid
  JOIN f c ON c.oid <> g.oid
   AND ( c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
         OR c.prosrc ~* ('\m' || g.proname || '\s*\(') )
),
calls AS (
  SELECT c.oid AS caller, g.oid AS callee
  FROM closure cc
  JOIN f c ON c.oid = cc.oid
  JOIN closure cg ON cg.oid <> cc.oid
  JOIN f g ON g.oid = cg.oid
  WHERE c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
     OR c.prosrc ~* ('\m' || g.proname || '\s*\(')
),
numbered AS (
  SELECT f.*, ntile(2) OVER (ORDER BY f.nspname, f.proname, f.args) AS tile FROM f WHERE f.oid IN (SELECT oid FROM closure)
)
SELECT jsonb_build_object(
  'tile', 2, 'tiles_total', 2,
  'closure_count', (SELECT count(*) FROM numbered),
  'in_this_run', (SELECT count(*) FROM numbered WHERE tile = 2),
  'functions', (SELECT jsonb_agg(jsonb_build_object(
        'schema', nspname, 'name', proname, 'args', args, 'security_definer', prosecdef, 'owner', owner_role,
        'definition', pg_get_functiondef(oid)) ORDER BY nspname, proname, args)
      FROM numbered WHERE tile = 2)
) AS result;

-- ============================================================================
-- RUN J2d. What text matching cannot see: views, rules, triggers, foreign keys
-- ============================================================================
WITH RECURSIVE
f AS (
  SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
         pg_get_userbyid(p.proowner) AS owner_role, p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
    AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
vw AS (
  SELECT viewname::text AS vname FROM pg_views WHERE definition ~* 'study_group|content_group_shares'
  UNION
  SELECT matviewname::text FROM pg_matviews WHERE definition ~* 'study_group|content_group_shares'
),
seed AS (
  SELECT f.oid FROM f
  WHERE f.prosrc ~* 'study_group|content_group_shares' OR f.prosrc ~* 'invite_token' OR f.prosrc ~* '\mexecute\s'
     OR EXISTS (SELECT 1 FROM vw WHERE f.prosrc ~* ('\m' || vw.vname || '\M'))
),
closure(oid) AS (
  SELECT oid FROM seed
  UNION
  SELECT c.oid
  FROM closure cl
  JOIN f g ON g.oid = cl.oid
  JOIN f c ON c.oid <> g.oid
   AND ( c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
         OR c.prosrc ~* ('\m' || g.proname || '\s*\(') )
),
calls AS (
  SELECT c.oid AS caller, g.oid AS callee
  FROM closure cc
  JOIN f c ON c.oid = cc.oid
  JOIN closure cg ON cg.oid <> cc.oid
  JOIN f g ON g.oid = cg.oid
  WHERE c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
     OR c.prosrc ~* ('\m' || g.proname || '\s*\(')
)
SELECT jsonb_build_object(
  'views_over_group_tables', (SELECT jsonb_agg(jsonb_build_object('schema', schemaname, 'view', viewname, 'definition', definition)
      ORDER BY schemaname, viewname) FROM pg_views WHERE definition ~* 'study_group|content_group_shares'),
  'materialized_views_over_group_tables', (SELECT jsonb_agg(jsonb_build_object('schema', schemaname, 'view', matviewname, 'definition', definition)
      ORDER BY schemaname, matviewname) FROM pg_matviews WHERE definition ~* 'study_group|content_group_shares'),
  'rewrite_rules_on_or_mentioning_group_tables', (SELECT jsonb_agg(jsonb_build_object('schema', schemaname, 'table', tablename, 'rule', rulename, 'definition', definition)
      ORDER BY schemaname, tablename, rulename) FROM pg_rules WHERE tablename IN ('study_groups', 'study_group_members', 'content_group_shares') OR definition ~* 'study_group|content_group_shares'),
  'triggers_on_group_tables_or_calling_a_closure_routine', (SELECT jsonb_agg(jsonb_build_object(
        'table', c.relname, 'trigger', t.tgname, 'enabled', t.tgenabled::text, 'function', pf.proname,
        'definition', pg_get_triggerdef(t.oid)) ORDER BY c.relname, t.tgname)
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_proc pf ON pf.oid = t.tgfoid
      WHERE NOT t.tgisinternal
        AND (c.relname IN ('study_groups', 'study_group_members', 'content_group_shares') OR t.tgfoid IN (SELECT oid FROM closure))),
  'foreign_keys_touching_group_tables', (SELECT jsonb_agg(jsonb_build_object(
        'constraint', con.conname, 'table', cl.relname, 'references', rf.relname,
        'on_update', con.confupdtype::text, 'on_delete', con.confdeltype::text,
        'definition', pg_get_constraintdef(con.oid)) ORDER BY cl.relname, con.conname)
      FROM pg_constraint con
      JOIN pg_class cl ON cl.oid = con.conrelid
      JOIN pg_class rf ON rf.oid = con.confrelid
      WHERE con.contype = 'f'
        AND (cl.relname IN ('study_groups', 'study_group_members', 'content_group_shares') OR rf.relname IN ('study_groups', 'study_group_members', 'content_group_shares')))
) AS result;

-- ============================================================================
-- RUN J3. Live bodies of the non-batch group RPCs and rename_batch_group (guaranteed capture)
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'name', p.proname,
         'args', pg_get_function_identity_arguments(p.oid),
         'security_definer', p.prosecdef,
         'owner', pg_get_userbyid(p.proowner),
         'config', p.proconfig,
         'acl', p.proacl::text[],
         'definition', pg_get_functiondef(p.oid)
       ) ORDER BY p.proname, pg_get_function_identity_arguments(p.oid)) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('create_study_group', 'invite_to_group', 'accept_group_invite', 'decline_group_invite', 'rename_batch_group');

-- ============================================================================
-- RUN J4. Policies (any table, any schema) that mention the group tables or call a closure routine: the reader and write-policy audit
-- ============================================================================
WITH RECURSIVE
f AS (
  SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
         pg_get_userbyid(p.proowner) AS owner_role, p.prosrc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
    AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
vw AS (
  SELECT viewname::text AS vname FROM pg_views WHERE definition ~* 'study_group|content_group_shares'
  UNION
  SELECT matviewname::text FROM pg_matviews WHERE definition ~* 'study_group|content_group_shares'
),
seed AS (
  SELECT f.oid FROM f
  WHERE f.prosrc ~* 'study_group|content_group_shares' OR f.prosrc ~* 'invite_token' OR f.prosrc ~* '\mexecute\s'
     OR EXISTS (SELECT 1 FROM vw WHERE f.prosrc ~* ('\m' || vw.vname || '\M'))
),
closure(oid) AS (
  SELECT oid FROM seed
  UNION
  SELECT c.oid
  FROM closure cl
  JOIN f g ON g.oid = cl.oid
  JOIN f c ON c.oid <> g.oid
   AND ( c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
         OR c.prosrc ~* ('\m' || g.proname || '\s*\(') )
),
calls AS (
  SELECT c.oid AS caller, g.oid AS callee
  FROM closure cc
  JOIN f c ON c.oid = cc.oid
  JOIN closure cg ON cg.oid <> cc.oid
  JOIN f g ON g.oid = cg.oid
  WHERE c.prosrc ~* ('(^|[^a-z0-9_])"?' || g.nspname || '"?\."?' || g.proname || '"?\s*\(')
     OR c.prosrc ~* ('\m' || g.proname || '\s*\(')
)
SELECT jsonb_build_object(
  'policy_count', (SELECT count(*) FROM pg_policies pol WHERE (pol.tablename IN ('study_groups', 'study_group_members', 'content_group_shares', 'access_requests')
        OR (coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, '')) ~* 'study_group|content_group_shares'
        OR EXISTS (SELECT 1 FROM f g WHERE g.oid IN (SELECT oid FROM closure)
                   AND (coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, '')) ~* ('\m' || g.proname || '\s*\(')))),
  'policies', (SELECT jsonb_agg(jsonb_build_object(
        'schema', pol.schemaname, 'table', pol.tablename, 'policy', pol.policyname, 'command', pol.cmd,
        'permissive', pol.permissive, 'roles', pol.roles, 'using', pol.qual, 'with_check', pol.with_check
      ) ORDER BY pol.schemaname, pol.tablename, pol.policyname)
      FROM pg_policies pol WHERE (pol.tablename IN ('study_groups', 'study_group_members', 'content_group_shares', 'access_requests')
        OR (coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, '')) ~* 'study_group|content_group_shares'
        OR EXISTS (SELECT 1 FROM f g WHERE g.oid IN (SELECT oid FROM closure)
                   AND (coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, '')) ~* ('\m' || g.proname || '\s*\('))))
) AS result;

-- ============================================================================
-- RUN J5. Scheduled jobs: names, schedules and flags only (never the command text), and which non-system routines each calls
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'jobid', j.jobid, 'jobname', j.jobname, 'schedule', j.schedule, 'active', j.active,
         'command_length', length(j.command),
         'command_mentions_group_tables', j.command ~* 'study_group|content_group_shares',
         'command_mentions_an_http_call', j.command ~* 'net\.http',
         'routines_called', (SELECT jsonb_agg(n.nspname || '.' || p.proname ORDER BY n.nspname, p.proname)
              FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') AND j.command ~* ('\m' || p.proname || '\s*\('))
       ) ORDER BY j.jobid) AS result
FROM cron.job j;
