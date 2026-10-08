-- Name: [DIAGNOSTIC] T-002 D1a (v1) - catalogue-only capture of get_subject_mastery_v1 (no call): identity, ACL, flags, text-lead closure, full definition
--
-- Description: READ-ONLY. Stage 1 of the Subject Mastery question (diagnostic proposal D1, docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md, QA Round 14
-- PASS WITH CONDITIONS, authoring only). It never calls get_subject_mastery_v1 or any application function. It reads the system catalogue only.
-- Purpose: let Claude and QA review the exact live body, its owner and security mode, who can execute it, which other routines and relations its text
-- names (an OVER-approximation: a substring match, never a proof of absence), and whether its text contains any write, DDL, dynamic-SQL or unreadable-language
-- lead, BEFORE stage 2 (D1b, a role-bound call inside a read-only transaction) is authored. If any such lead is present, D1b is not written.
-- RUN 1 returns metadata, flags and the closure leads; RUN 2 returns the full definition text and its md5 (separate so that a long text cannot hide
-- the metadata in one oversized cell).
-- Safety: each RUN is one SELECT (or WITH ... SELECT). No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Only catalogue tables and catalogue functions (pg_proc, pg_namespace, pg_language, pg_class, pg_get_functiondef, aclexplode) are used.
-- Blind spots, stated: the closure is a case-insensitive substring match of each routine and relation name against the lower-cased body, so it can list
-- names that are not real calls and (for a name built at run time) can miss one; a dynamic-SQL flag (EXECUTE) is raised for exactly that reason. A
-- non-plpgsql, non-sql language is reported as unresolved. Callees' own bodies are NOT captured here; if the closure lists any non-system routine, a
-- further capture is requested before D1b.
--
-- HOW TO RUN (two runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and paste it
-- into one Notepad file under its label (RUN 1, RUN 2), unchanged. Save as docs/discussions/evidence/T-002_D1a-raw_<dd-mm-yyyy>.raw.txt and keep it
-- untouched. An error is evidence: save the error text under its label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN 1: identity, ACL, flags, closure leads =====
WITH f AS (
  SELECT p.oid,
         n.nspname AS schema_name,
         p.proname,
         pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_function_result(p.oid) AS result_type,
         pg_get_userbyid(p.proowner) AS owner,
         l.lanname AS language,
         p.prosecdef AS security_definer,
         p.provolatile AS volatility,
         p.proconfig AS config,
         p.proowner AS owner_oid,
         p.proacl AS acl,
         lower(p.prosrc) AS src
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE p.proname = 'get_subject_mastery_v1'
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
)
SELECT jsonb_build_object(
  'run', 'D1a-RUN1',
  'function_count', (SELECT count(*) FROM f),
  'functions', COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'schema', f.schema_name,
        'name', f.proname,
        'args', f.args,
        'result_type', f.result_type,
        'owner', f.owner,
        'language', f.language,
        'language_unresolved', (f.language NOT IN ('plpgsql', 'sql')),
        'security_definer', f.security_definer,
        'volatility', f.volatility,
        'config', to_jsonb(f.config),
        'execute_grantees', to_jsonb(ARRAY(
          SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END
          FROM aclexplode(COALESCE(f.acl, acldefault('f', f.owner_oid))) AS x
          WHERE x.privilege_type = 'EXECUTE'
          ORDER BY 1
        )),
        'flags', jsonb_build_object(
          'dynamic_sql_execute', (f.src ~ '\mexecute\M'),
          'insert', (f.src ~ '\minsert\M'),
          'update', (f.src ~ '\mupdate\M'),
          'delete', (f.src ~ '\mdelete\M'),
          'truncate', (f.src ~ '\mtruncate\M'),
          'merge', (f.src ~ '\mmerge\M'),
          'copy', (f.src ~ '\mcopy\M'),
          'ddl_word', (f.src ~ '\m(create|alter|drop|grant|revoke)\M'),
          'set_config_or_set_role', (f.src ~ '(\mset_config\M|\mset\s+(local\s+)?role\M)'),
          'perform_or_call', (f.src ~ '(\mperform\M|\mcall\M)')
        ),
        'routine_name_leads', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('schema', n2.nspname, 'name', p2.proname, 'args', pg_get_function_identity_arguments(p2.oid))
                           ORDER BY n2.nspname, p2.proname, pg_get_function_identity_arguments(p2.oid))
          FROM pg_proc p2
          JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
          WHERE n2.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
            AND p2.oid <> f.oid
            AND length(p2.proname) >= 4
            AND position(lower(p2.proname) IN f.src) > 0
        ), '[]'::jsonb),
        'relation_name_leads', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('schema', n3.nspname, 'name', c.relname, 'kind', c.relkind)
                           ORDER BY n3.nspname, c.relname)
          FROM pg_class c
          JOIN pg_namespace n3 ON n3.oid = c.relnamespace
          WHERE n3.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
            AND c.relkind IN ('r', 'v', 'm', 'p', 'f')
            AND length(c.relname) >= 4
            AND position(lower(c.relname) IN f.src) > 0
        ), '[]'::jsonb)
      )
      ORDER BY f.schema_name, f.args
    )
    FROM f
  ), '[]'::jsonb)
) AS result;

-- ===== RUN 2: full definition text and md5 =====
SELECT jsonb_build_object(
  'run', 'D1a-RUN2',
  'definitions', COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'schema', n.nspname,
        'args', pg_get_function_identity_arguments(p.oid),
        'definition_md5', md5(pg_get_functiondef(p.oid)),
        'definition_length', length(pg_get_functiondef(p.oid)),
        'definition', pg_get_functiondef(p.oid)
      )
      ORDER BY n.nspname, pg_get_function_identity_arguments(p.oid)
    )
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'get_subject_mastery_v1'
      AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  ), '[]'::jsonb)
) AS result;
