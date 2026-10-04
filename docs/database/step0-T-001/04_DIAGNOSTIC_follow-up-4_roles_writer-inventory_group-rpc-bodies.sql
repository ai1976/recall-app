-- Name: [DIAGNOSTIC] T-001 follow-up 4 (v1) - role attributes and memberships, group-table writer inventory with owners, non-batch group RPC bodies
--
-- Description: READ-ONLY fourth follow-up. It measures the facts that the T-001 SQL design needs before any SQL is authored:
-- QA Round 40 condition 2 (the exact boundary of the future no-login writer role grp_batch_writer), the complete set of
-- functions that can write the group tables (brief A step 0(c), writer catalog), and the live bodies of the non-batch group
-- RPCs that decide whether client INSERT and UPDATE privileges on the group tables can ever be revoked.
-- Three runs, each one statement returning one row with one json column named `result`:
--   J1  Role attributes and role memberships. For the roles postgres, supabase_admin, authenticator, anon, authenticated,
--       service_role and grp_batch_writer (absence of the last is shown by its absence from the result): name, can log in,
--       superuser, bypass row-level security, create role, create database, replication, inherits privileges. Then every
--       membership edge (member role, granted role, admin option, inherit option, set option) in which one of those roles is
--       the member or the granted role. Shows who could inherit or SET ROLE to a future writer role.
--   J2  Writer inventory. Public functions whose source text contains an INSERT, UPDATE or DELETE statement against
--       study_groups or study_group_members (a text match: it can miss dynamic SQL and indirect calls, and can match a
--       comment; it is an inventory to review, not a proof of completeness), each with: name, argument list, security
--       definer flag, owner role, whether a search_path is set. Also: the names of public functions whose source mentions
--       invite_token (readers of the bearer token), and the owners of the group tables themselves.
--   J3  Live bodies (name, argument list, security definer flag, full definition) of create_study_group, invite_to_group,
--       accept_group_invite, decline_group_invite and rename_batch_group.
-- Privacy rule: no user-authored stored text is returned. J1 returns role names and flags and J2 and J3 return function
-- names, owners and source text (catalog text). No name, email, phone or identifier of a person is selected.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, or
-- application-function call (only catalog functions and views: pg_roles, pg_auth_members, pg_proc, pg_class,
-- pg_get_userbyid, pg_get_function_identity_arguments, pg_get_functiondef).
--
-- HOW TO RUN (three runs: J1, J2, J3): select the text of ONE run (from its first line to its closing semicolon), click Run,
-- copy the single result cell, and keep it unchanged. Save each result as an unedited raw export under docs/discussions/evidence/
-- named T-001_FU4-<run>_<dd-mm-yyyy>.json. An error is evidence: save the error text, do not edit and re-run.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN J1. Role attributes and role memberships (no person data)
-- ============================================================================
WITH named(rolname) AS (
  VALUES ('postgres'), ('supabase_admin'), ('authenticator'), ('anon'), ('authenticated'), ('service_role'), ('grp_batch_writer')
),
r AS (
  SELECT ro.oid, ro.rolname, ro.rolcanlogin, ro.rolsuper, ro.rolbypassrls, ro.rolcreaterole, ro.rolcreatedb,
         ro.rolreplication, ro.rolinherit
  FROM pg_roles ro JOIN named n ON n.rolname = ro.rolname
)
SELECT jsonb_build_object(
  'roles', (SELECT jsonb_agg(jsonb_build_object(
        'role', r.rolname, 'can_login', r.rolcanlogin, 'superuser', r.rolsuper, 'bypass_rls', r.rolbypassrls,
        'create_role', r.rolcreaterole, 'create_db', r.rolcreatedb, 'replication', r.rolreplication,
        'inherits', r.rolinherit) ORDER BY r.rolname) FROM r),
  'memberships_involving_these_roles', (SELECT jsonb_agg(jsonb_build_object(
        'member', m.rolname, 'granted_role', g.rolname, 'admin_option', am.admin_option,
        'inherit_option', am.inherit_option, 'set_option', am.set_option
      ) ORDER BY m.rolname, g.rolname)
      FROM pg_auth_members am
      JOIN pg_roles m ON m.oid = am.member
      JOIN pg_roles g ON g.oid = am.roleid
      WHERE m.rolname IN (SELECT rolname FROM named) OR g.rolname IN (SELECT rolname FROM named))
) AS result;

-- ============================================================================
-- RUN J2. Writer inventory, readers of the bearer token, owners of the group tables
-- ============================================================================
WITH f AS (
  SELECT p.oid, p.proname, p.prosecdef, p.proconfig, p.prosrc,
         pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner_role
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
)
SELECT jsonb_build_object(
  'functions_with_a_write_statement_against_study_groups_or_study_group_members', (SELECT jsonb_agg(jsonb_build_object(
        'name', proname, 'args', args, 'security_definer', prosecdef, 'owner', owner_role,
        'search_path_set', (proconfig IS NOT NULL AND EXISTS (SELECT 1 FROM unnest(proconfig) c WHERE c LIKE 'search_path=%'))
      ) ORDER BY proname, args)
      FROM f
      WHERE prosrc ~* '(insert[[:space:]]+into|update|delete[[:space:]]+from)[[:space:]]+(public\.)?(study_groups|study_group_members)([^a-z_]|$)'),
  'functions_mentioning_invite_token', (SELECT jsonb_agg(proname || '(' || args || ')' ORDER BY proname, args)
      FROM f WHERE prosrc ILIKE '%invite_token%'),
  'owners_of_the_group_tables', (SELECT jsonb_agg(jsonb_build_object('table', c.relname, 'owner', pg_get_userbyid(c.relowner))
      ORDER BY c.relname)
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname IN ('study_groups', 'study_group_members', 'access_requests', 'disciplines', 'subjects'))
) AS result;

-- ============================================================================
-- RUN J3. Live bodies of the non-batch group RPCs and rename_batch_group
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'name', p.proname,
         'args', pg_get_function_identity_arguments(p.oid),
         'security_definer', p.prosecdef,
         'owner', pg_get_userbyid(p.proowner),
         'definition', pg_get_functiondef(p.oid)
       ) ORDER BY p.proname, pg_get_function_identity_arguments(p.oid)) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('create_study_group', 'invite_to_group', 'accept_group_invite', 'decline_group_invite', 'rename_batch_group');
