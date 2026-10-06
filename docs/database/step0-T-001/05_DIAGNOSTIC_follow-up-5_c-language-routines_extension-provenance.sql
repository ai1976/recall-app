-- Name: [DIAGNOSTIC] T-001 follow-up 5 (v2) - provenance of the 64 C-language routines (cron, extensions, net, vault): identity, owner, ACL, library symbol, extension membership, version, mechanical and unclassified lead reasons
--
-- Description: READ-ONLY fifth follow-up, revised after QA Round 56 (v2; supersedes v1 242c7168a2e7, which was never authorized or run). It closes the one
-- lead that the fourth follow-up could not read: diagnostic 4 v4 (55b732e1a68d, Gate 4 accepted by the Founder) counted 64 routines written in the C
-- language in schemas cron (7), extensions (49), net (5) and vault (3), and none in public (J2a: 177 plpgsql and 14 sql routines in public). Their
-- source cannot be read as text, so the call-closure could not inspect them. SQL work plan v5 (6961fb55dd69, section 3) treats any such count as a
-- lead that blocks every dependent SQL file until a capture lists their identities and extension membership; QA Round 52 agreed in principle and
-- strengthened the scope, and QA Round 56 required the changes below.
-- What changed from v1 (each answers a QA Round 56 blocking finding):
--   * Blocking 1. v1 had no lead for an unexpected extension identity or version, library symbol, or ACL, so a routine could be reported as having no
--     lead although those properties had not been classified. v2 adds an explicit reviewed BASELINE (a CTE named baseline that is EMPTY in this version)
--     and the reasons extension_identity_version_unclassified, library_symbol_unclassified and acl_unclassified, which are present on a routine unless a
--     baseline row matches its exact identity (schema, name, identity arguments) AND the captured property (extension name and version; library and
--     symbol; the sorted ACL). With an empty baseline every routine carries all three, so none can appear in routines_with_no_lead_reason before it
--     has been classified. A later reviewed version of this file, or a reviewed manifest, may fill the baseline from this run's captured values.
--     v2 also adds acl_not_default (an explicit, non-default ACL).
--   * Blocking 2. The trigger lead now covers both pseudo-types (trigger and event_trigger) and is named returns_trigger_or_event_trigger. K3 counts
--     DISTINCT routine OIDs (in total and per extension), so the totals stay accurate if the multiple-membership anomaly occurs.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * K1 (summary): the number of C-language routines found in every non-system schema, compared with the expected 64 and with the expected
--     per-schema counts from J2a (cron 7, extensions 49, net 5, vault 3; every other schema, public included, expected 0); the routines grouped by
--     schema, extension membership, memberships and owner; the count of routines for each lead reason; the baseline row count; and how many are
--     executable by anon, authenticated and service_role (the server's own answer from has_function_privilege).
--   * K2 (routines): one entry per routine: schema, name, identity arguments, result type, kind, SECURITY DEFINER flag, volatility, parallel
--     safety, function-level configuration (proconfig), owner, sorted ACL (and whether it is the default ACL), executability by the three client
--     roles, the library (probin) and symbol (prosrc), every extension membership found through pg_depend (name, version, owner, relocatable, schema)
--     and the lead reasons.
--   * K3 (extensions): every installed extension with its version, owner, schema, relocatability, and how many routines and C-language routines it
--     owns (distinct routine OIDs), plus the total number of distinct C-language routines that belong to an extension (expected 64 if all are members).
-- Lead reasons (mechanical, fixed here; a routine with any reason is a POSITIVE LEAD under plan v5 and stays blocking until classified by exact
-- captured identity in a reviewed baseline or manifest; extension membership alone is provenance, not proof of harmlessness):
--   not_extension_member; several_extension_memberships; library_not_in_libdir (probin missing or not under $libdir/);
--   library_name_differs_from_extension (the library file name is not the extension name); owner_differs_from_extension_owner;
--   owner_not_postgres_or_supabase_admin; security_definer; returns_trigger_or_event_trigger; has_function_config (proconfig is set);
--   not_plain_function (an aggregate, window function or procedure); acl_not_default; extension_identity_version_unclassified;
--   library_symbol_unclassified; acl_unclassified. In addition a count or identity mismatch is a positive lead: K1 reports total_matches_expected and
--   per_schema_all_match, which must both be true. Executability by client roles is reported as a fact per routine and in K1; it is not a lead reason
--   by itself (QA Round 56, non-blocking 1: extension routines normally inherit EXECUTE through PUBLIC), but it is security-significant when combined
--   with SECURITY DEFINER, an unclassified symbol or version, or any other lead, and is judged on the evidence by QA and the Founder.
-- Known blind spots, stated: a C routine's behaviour is in compiled code, so this file proves provenance and declared properties only, not
-- behaviour; extension membership is read from pg_depend (deptype 'e'); objects created after this run are not covered.
-- Three runs: K1, K2 and K3. Each is one statement and returns one row with one jsonb column named `result`.
-- Privacy rule: no user-authored stored text and no person data is selected; only routine and extension names, role names, flags and ACL text.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Only
-- catalog functions and views are used (pg_proc, pg_namespace, pg_language, pg_depend, pg_extension, pg_get_userbyid,
-- pg_get_function_identity_arguments, pg_get_function_result, has_function_privilege).
--
-- HOW TO RUN (three runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label (K1, K2, K3), unchanged. Save that file as
-- docs/discussions/evidence/T-001_FU5-raw_<dd-mm-yyyy>.raw.txt and keep it untouched; the derived .json files are made from it by script.
-- An error is evidence: save the error text under the label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN K1. Summary: count and per-schema reconciliation with J2a, grouping by extension and owner, lead-reason counts, baseline and client executability
-- ============================================================================
WITH baseline AS (
  -- Reviewed baseline. EMPTY in this version: no routine, extension version, library symbol or ACL has been classified yet.
  -- A property counts as classified only when a row here matches the routine's exact identity AND that captured property.
  SELECT NULL::text AS schema_name, NULL::text AS name, NULL::text AS args,
         NULL::text AS extname, NULL::text AS extversion,
         NULL::text AS probin, NULL::text AS prosrc, NULL::text[] AS acl
  WHERE false
),
c AS (
  SELECT p.oid AS proc_oid, n.nspname AS schema_name, p.proname AS name,
         pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_function_result(p.oid) AS result_type,
         p.prokind, p.prosecdef, p.provolatile, p.proparallel, p.proconfig, p.prorettype,
         pg_get_userbyid(p.proowner) AS owner,
         ARRAY(SELECT a::text FROM unnest(p.proacl) AS a ORDER BY a::text) AS acl,
         (p.proacl IS NULL) AS acl_is_default,
         p.probin, p.prosrc,
         has_function_privilege('anon', p.oid, 'EXECUTE') AS exec_anon,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') AS exec_authenticated,
         has_function_privilege('service_role', p.oid, 'EXECUTE') AS exec_service_role
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE l.lanname = 'c'
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
),
ext AS (
  SELECT d.objid AS proc_oid, e.extname, e.extversion,
         pg_get_userbyid(e.extowner) AS ext_owner, e.extrelocatable, ens.nspname AS ext_schema
  FROM pg_depend d
  JOIN pg_extension e ON e.oid = d.refobjid
  JOIN pg_namespace ens ON ens.oid = e.extnamespace
  WHERE d.classid = 'pg_proc'::regclass
    AND d.refclassid = 'pg_extension'::regclass
    AND d.deptype = 'e'
),
ex AS (
  SELECT proc_oid,
         count(*) AS ext_count,
         min(extname) AS one_name,
         min(extversion) AS one_version,
         min(ext_owner) AS one_owner,
         jsonb_agg(jsonb_build_object('name', extname, 'version', extversion, 'owner', ext_owner,
                                      'relocatable', extrelocatable, 'schema', ext_schema)
                   ORDER BY extname) AS memberships
  FROM ext
  GROUP BY proc_oid
),
x AS (
  SELECT c.*, COALESCE(ex.ext_count, 0) AS ext_count, ex.one_name, ex.one_version, ex.one_owner, ex.memberships
  FROM c
  LEFT JOIN ex ON ex.proc_oid = c.proc_oid
),
r AS (
  SELECT x.*,
         array_remove(ARRAY[
           CASE WHEN x.ext_count = 0 THEN 'not_extension_member' END,
           CASE WHEN x.ext_count > 1 THEN 'several_extension_memberships' END,
           CASE WHEN x.probin IS NULL OR x.probin NOT LIKE '$libdir/%' THEN 'library_not_in_libdir' END,
           CASE WHEN x.ext_count = 1 AND x.probin LIKE '$libdir/%' AND substr(x.probin, 9) <> x.one_name
                THEN 'library_name_differs_from_extension' END,
           CASE WHEN x.ext_count = 1 AND x.owner <> x.one_owner THEN 'owner_differs_from_extension_owner' END,
           CASE WHEN x.owner NOT IN ('postgres', 'supabase_admin') THEN 'owner_not_postgres_or_supabase_admin' END,
           CASE WHEN x.prosecdef THEN 'security_definer' END,
           CASE WHEN x.prorettype IN ('trigger'::regtype, 'event_trigger'::regtype) THEN 'returns_trigger_or_event_trigger' END,
           CASE WHEN x.proconfig IS NOT NULL THEN 'has_function_config' END,
           CASE WHEN x.prokind <> 'f' THEN 'not_plain_function' END,
           CASE WHEN NOT x.acl_is_default THEN 'acl_not_default' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM baseline b
                                 WHERE b.schema_name = x.schema_name AND b.name = x.name AND b.args = x.args
                                   AND b.extname IS NOT DISTINCT FROM x.one_name
                                   AND b.extversion IS NOT DISTINCT FROM x.one_version)
                THEN 'extension_identity_version_unclassified' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM baseline b
                                 WHERE b.schema_name = x.schema_name AND b.name = x.name AND b.args = x.args
                                   AND b.probin IS NOT DISTINCT FROM x.probin
                                   AND b.prosrc IS NOT DISTINCT FROM x.prosrc)
                THEN 'library_symbol_unclassified' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM baseline b
                                 WHERE b.schema_name = x.schema_name AND b.name = x.name AND b.args = x.args
                                   AND ARRAY(SELECT a FROM unnest(b.acl) AS a ORDER BY a) IS NOT DISTINCT FROM x.acl)
                THEN 'acl_unclassified' END
         ], NULL) AS lead_reasons
  FROM x
)
, per_schema AS (
  SELECT COALESCE(a.schema_name, e.schema_name) AS schema_name,
         COALESCE(a.n, 0) AS actual,
         COALESCE(e.n, 0) AS expected
  FROM (SELECT schema_name, count(*) AS n FROM r GROUP BY schema_name) a
  FULL JOIN (VALUES ('cron', 7), ('extensions', 49), ('net', 5), ('vault', 3)) AS e(schema_name, n)
    ON e.schema_name = a.schema_name
)
SELECT jsonb_build_object(
  'run', 'K1',
  'total_c_routines', (SELECT count(*) FROM r),
  'expected_total_from_j2a', 64,
  'total_matches_expected', (SELECT count(*) FROM r) = 64,
  'per_schema', (SELECT jsonb_agg(jsonb_build_object('schema', schema_name, 'actual', actual, 'expected', expected,
                                                      'match', actual = expected) ORDER BY schema_name)
                 FROM per_schema),
  'per_schema_all_match', (SELECT COALESCE(bool_and(actual = expected), false) FROM per_schema),
  'by_schema_extension_owner', (SELECT jsonb_agg(jsonb_build_object('schema', schema_name, 'extension_memberships', ext_count,
                                                                     'memberships', memberships, 'owner', owner, 'routines', n)
                                                 ORDER BY schema_name, owner, n)
                                FROM (SELECT schema_name, ext_count, memberships, owner, count(*) AS n
                                      FROM r GROUP BY schema_name, ext_count, memberships, owner) g),
  'lead_reason_counts', (SELECT jsonb_agg(jsonb_build_object('reason', reason, 'routines', n) ORDER BY reason)
                         FROM (SELECT reason, count(*) AS n FROM r CROSS JOIN LATERAL unnest(r.lead_reasons) AS reason GROUP BY reason) q),
  'baseline_rows', (SELECT count(*) FROM baseline),
  'routines_with_unclassified_version', (SELECT count(*) FROM r WHERE 'extension_identity_version_unclassified' = ANY (lead_reasons)),
  'routines_with_unclassified_symbol', (SELECT count(*) FROM r WHERE 'library_symbol_unclassified' = ANY (lead_reasons)),
  'routines_with_unclassified_acl', (SELECT count(*) FROM r WHERE 'acl_unclassified' = ANY (lead_reasons)),
  'routines_with_any_lead_reason', (SELECT count(*) FROM r WHERE cardinality(lead_reasons) > 0),
  'routines_with_no_lead_reason', (SELECT count(*) FROM r WHERE cardinality(lead_reasons) = 0),
  'executable_by_anon', (SELECT count(*) FROM r WHERE exec_anon),
  'executable_by_authenticated', (SELECT count(*) FROM r WHERE exec_authenticated),
  'executable_by_service_role', (SELECT count(*) FROM r WHERE exec_service_role)
) AS result;

-- ============================================================================
-- RUN K2. Every C-language routine: identity, owner, ACL, library and symbol, extension membership, lead reasons
-- ============================================================================
WITH baseline AS (
  -- Reviewed baseline. EMPTY in this version: no routine, extension version, library symbol or ACL has been classified yet.
  -- A property counts as classified only when a row here matches the routine's exact identity AND that captured property.
  SELECT NULL::text AS schema_name, NULL::text AS name, NULL::text AS args,
         NULL::text AS extname, NULL::text AS extversion,
         NULL::text AS probin, NULL::text AS prosrc, NULL::text[] AS acl
  WHERE false
),
c AS (
  SELECT p.oid AS proc_oid, n.nspname AS schema_name, p.proname AS name,
         pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_function_result(p.oid) AS result_type,
         p.prokind, p.prosecdef, p.provolatile, p.proparallel, p.proconfig, p.prorettype,
         pg_get_userbyid(p.proowner) AS owner,
         ARRAY(SELECT a::text FROM unnest(p.proacl) AS a ORDER BY a::text) AS acl,
         (p.proacl IS NULL) AS acl_is_default,
         p.probin, p.prosrc,
         has_function_privilege('anon', p.oid, 'EXECUTE') AS exec_anon,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') AS exec_authenticated,
         has_function_privilege('service_role', p.oid, 'EXECUTE') AS exec_service_role
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE l.lanname = 'c'
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND n.nspname !~ '^pg_(toast|temp)'
),
ext AS (
  SELECT d.objid AS proc_oid, e.extname, e.extversion,
         pg_get_userbyid(e.extowner) AS ext_owner, e.extrelocatable, ens.nspname AS ext_schema
  FROM pg_depend d
  JOIN pg_extension e ON e.oid = d.refobjid
  JOIN pg_namespace ens ON ens.oid = e.extnamespace
  WHERE d.classid = 'pg_proc'::regclass
    AND d.refclassid = 'pg_extension'::regclass
    AND d.deptype = 'e'
),
ex AS (
  SELECT proc_oid,
         count(*) AS ext_count,
         min(extname) AS one_name,
         min(extversion) AS one_version,
         min(ext_owner) AS one_owner,
         jsonb_agg(jsonb_build_object('name', extname, 'version', extversion, 'owner', ext_owner,
                                      'relocatable', extrelocatable, 'schema', ext_schema)
                   ORDER BY extname) AS memberships
  FROM ext
  GROUP BY proc_oid
),
x AS (
  SELECT c.*, COALESCE(ex.ext_count, 0) AS ext_count, ex.one_name, ex.one_version, ex.one_owner, ex.memberships
  FROM c
  LEFT JOIN ex ON ex.proc_oid = c.proc_oid
),
r AS (
  SELECT x.*,
         array_remove(ARRAY[
           CASE WHEN x.ext_count = 0 THEN 'not_extension_member' END,
           CASE WHEN x.ext_count > 1 THEN 'several_extension_memberships' END,
           CASE WHEN x.probin IS NULL OR x.probin NOT LIKE '$libdir/%' THEN 'library_not_in_libdir' END,
           CASE WHEN x.ext_count = 1 AND x.probin LIKE '$libdir/%' AND substr(x.probin, 9) <> x.one_name
                THEN 'library_name_differs_from_extension' END,
           CASE WHEN x.ext_count = 1 AND x.owner <> x.one_owner THEN 'owner_differs_from_extension_owner' END,
           CASE WHEN x.owner NOT IN ('postgres', 'supabase_admin') THEN 'owner_not_postgres_or_supabase_admin' END,
           CASE WHEN x.prosecdef THEN 'security_definer' END,
           CASE WHEN x.prorettype IN ('trigger'::regtype, 'event_trigger'::regtype) THEN 'returns_trigger_or_event_trigger' END,
           CASE WHEN x.proconfig IS NOT NULL THEN 'has_function_config' END,
           CASE WHEN x.prokind <> 'f' THEN 'not_plain_function' END,
           CASE WHEN NOT x.acl_is_default THEN 'acl_not_default' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM baseline b
                                 WHERE b.schema_name = x.schema_name AND b.name = x.name AND b.args = x.args
                                   AND b.extname IS NOT DISTINCT FROM x.one_name
                                   AND b.extversion IS NOT DISTINCT FROM x.one_version)
                THEN 'extension_identity_version_unclassified' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM baseline b
                                 WHERE b.schema_name = x.schema_name AND b.name = x.name AND b.args = x.args
                                   AND b.probin IS NOT DISTINCT FROM x.probin
                                   AND b.prosrc IS NOT DISTINCT FROM x.prosrc)
                THEN 'library_symbol_unclassified' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM baseline b
                                 WHERE b.schema_name = x.schema_name AND b.name = x.name AND b.args = x.args
                                   AND ARRAY(SELECT a FROM unnest(b.acl) AS a ORDER BY a) IS NOT DISTINCT FROM x.acl)
                THEN 'acl_unclassified' END
         ], NULL) AS lead_reasons
  FROM x
)
SELECT jsonb_build_object(
  'run', 'K2',
  'routine_count', (SELECT count(*) FROM r),
  'routines', (SELECT jsonb_agg(jsonb_build_object(
      'schema', schema_name, 'name', name, 'args', args, 'result_type', result_type, 'kind', prokind,
      'security_definer', prosecdef, 'volatility', provolatile, 'parallel', proparallel, 'config', proconfig,
      'owner', owner, 'acl', acl, 'acl_is_default', acl_is_default,
      'executable_by_anon', exec_anon, 'executable_by_authenticated', exec_authenticated,
      'executable_by_service_role', exec_service_role,
      'library', probin, 'symbol', prosrc,
      'extension_memberships', ext_count, 'memberships', memberships,
      'lead_reasons', lead_reasons)
      ORDER BY schema_name, name, args)
    FROM r)
) AS result;

-- ============================================================================
-- RUN K3. Every installed extension with its member routines and C-language routines (distinct routines)
-- ============================================================================
SELECT jsonb_build_object(
  'run', 'K3',
  'extension_count', (SELECT count(*) FROM pg_extension),
  'c_routines_in_extensions_total',
    (SELECT count(DISTINCT p.oid)
     FROM pg_depend d
     JOIN pg_proc p ON p.oid = d.objid
     JOIN pg_language l ON l.oid = p.prolang
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE d.classid = 'pg_proc'::regclass AND d.refclassid = 'pg_extension'::regclass AND d.deptype = 'e'
       AND l.lanname = 'c'
       AND n.nspname NOT IN ('pg_catalog', 'information_schema')
       AND n.nspname !~ '^pg_(toast|temp)'),
  'extensions', (SELECT jsonb_agg(jsonb_build_object(
      'name', e.extname, 'version', e.extversion, 'owner', pg_get_userbyid(e.extowner),
      'schema', n.nspname, 'relocatable', e.extrelocatable,
      'member_routines', (SELECT count(DISTINCT d.objid) FROM pg_depend d
                          WHERE d.classid = 'pg_proc'::regclass AND d.refclassid = 'pg_extension'::regclass
                            AND d.refobjid = e.oid AND d.deptype = 'e'),
      'member_c_routines', (SELECT count(DISTINCT d.objid) FROM pg_depend d
                            JOIN pg_proc p ON p.oid = d.objid
                            JOIN pg_language l ON l.oid = p.prolang
                            WHERE d.classid = 'pg_proc'::regclass AND d.refclassid = 'pg_extension'::regclass
                              AND d.refobjid = e.oid AND d.deptype = 'e' AND l.lanname = 'c'))
      ORDER BY e.extname)
    FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace)
) AS result;
