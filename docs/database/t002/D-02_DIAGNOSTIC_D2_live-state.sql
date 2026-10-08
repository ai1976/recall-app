-- Name: [DIAGNOSTIC] T-002 D2 (v1) - live state of the stream B relations: structure, triggers and policies, definitions, effective privileges, aggregate data shapes
--
-- Description: READ-ONLY. Diagnostic D2 of docs/database/t002/00_DIAGNOSTIC-BATCH_proposal_v1.md (QA Round 14 PASS WITH CONDITIONS, authoring only; conditions 2
-- and 3 are built in). It reads the system catalogue and aggregates of the eight relations that T-002 stream B touches or relies on: study_sessions,
-- flashcards, notes, profiles, access_requests, disciplines, subjects, topics. It is written to run BEFORE B-04a, so it never references the classification
-- columns that do not exist yet. Purpose: B-04a, B-05, B-07, B-03, B-06a/b/c and the privilege ceilings are written once against real names, types, order,
-- sizes, effective privileges and consumers.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * RUN P1 (structure): server version and the availability of the built-in sha256; per relation: kind, owner, RLS enabled and forced, estimated rows, sizes;
--     every column (type, NOT NULL, default expression, generated, identity); every constraint (with validated flag and, for foreign keys, the parent and the
--     ON UPDATE / ON DELETE action codes: a = no action, r = restrict, c = cascade, n = set null, d = set default); every index definition.
--   * RUN P2 (behaviour objects): every non-internal trigger on the eight relations (definition, function identity); the distinct trigger functions with owner,
--     language, SECURITY DEFINER flag, configuration, EXECUTE grantees, md5 and length of the definition; policies; non-view rules; a BROAD scan of every
--     non-internal trigger in schema public (not filtered by table, per the project's standing rule).
--   * RUN P3 (definitions): the full text of every trigger function above, of is_admin, and of get_study_heatmap_split (with ACL), plus the identities of every
--     non-system routine whose body names study_sessions (a name-clash and reader lead list; identities only).
--   * RUN P4 (privileges and effective capability): every non-system role (superuser, BYPASSRLS, inherit, login), the role memberships (with inherit and set
--     options), the table ACL and the column ACL of the eight relations, the EFFECTIVE table privileges (has_table_privilege, which follows membership and
--     inheritance) of every role for SELECT, INSERT, UPDATE, DELETE and TRUNCATE, the effective per-column INSERT and UPDATE privilege on study_sessions for
--     anon, authenticated and service_role, every sequence behind a column of these relations with its owner and ACL, and the default ACLs. Owner and
--     superuser authority is reported separately; it is not removable by an ordinary ACL comparison (plan v6 section 5.2).
--   * RUN P5 (aggregate data shapes; counts only, no identity, no email, no text of a card): study_sessions totals, by source, NULL counts of every column
--     and manual rows without a category; profiles.course_level shapes by role and account type; access_requests.course shapes; flashcards and notes
--     classified by the NULL-safe conflict definition of plan v6 section 7; discipline names (catalogue data, not personal) with normalized collisions and
--     invalid names; subject counts per discipline.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Blind spots, stated: counts are one statement's view at its run time (the five runs are separate statements); the SQL Editor role bypasses student RLS,
-- which is intended for aggregate counts; the has_*_privilege functions answer for the role names present now; a function mentioned in a trigger is
-- identified, not traced (D3 traces writers); estimated_rows is the planner estimate, the exact counts are in P5.
--
-- HOW TO RUN (five runs: P1 to P5): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and
-- paste it into one Notepad file under its label, unchanged. Save as docs/discussions/evidence/T-002_D2-raw_<dd-mm-yyyy>.raw.txt and keep it untouched. An
-- error is evidence: save the error text under its label, do not edit and re-run (stop and report instead). A paste can be truncated: if a cell is cut,
-- stop and report; the verbatim-extracts pattern of docs/database/t001/run-extracts/ is used.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN P1: structure =====
WITH t AS (
  SELECT c.oid, c.relname, c.relkind, c.relowner, c.relrowsecurity, c.relforcerowsecurity, c.reltuples
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
)
SELECT jsonb_build_object(
  'run', 'D2-P1',
  'server_version', version(),
  'sha256_of_empty_hex', encode(sha256(''::bytea), 'hex'),
  'relations_expected', 8,
  'relations_found', (SELECT count(*) FROM t),
  'relations', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'name', t.relname, 'kind', t.relkind::text, 'owner', pg_get_userbyid(t.relowner),
      'rls_enabled', t.relrowsecurity, 'rls_forced', t.relforcerowsecurity,
      'estimated_rows', t.reltuples, 'table_bytes', pg_relation_size(t.oid), 'total_bytes', pg_total_relation_size(t.oid)
    ) ORDER BY t.relname) FROM t), '[]'::jsonb),
  'columns', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', t.relname, 'column', a.attname, 'num', a.attnum,
      'type', format_type(a.atttypid, a.atttypmod), 'not_null', a.attnotnull,
      'default', pg_get_expr(d.adbin, d.adrelid), 'generated', a.attgenerated::text, 'identity', a.attidentity::text
    ) ORDER BY t.relname, a.attnum)
    FROM t
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  ), '[]'::jsonb),
  'constraints', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', t.relname, 'name', k.conname, 'type', k.contype::text, 'validated', k.convalidated,
      'definition', pg_get_constraintdef(k.oid),
      'fk_parent', CASE WHEN k.contype = 'f' THEN k.confrelid::regclass::text END,
      'fk_on_update', CASE WHEN k.contype = 'f' THEN k.confupdtype::text END,
      'fk_on_delete', CASE WHEN k.contype = 'f' THEN k.confdeltype::text END
    ) ORDER BY t.relname, k.conname)
    FROM t JOIN pg_constraint k ON k.conrelid = t.oid
  ), '[]'::jsonb),
  'indexes', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('table', t.relname, 'name', i.indexname, 'definition', i.indexdef) ORDER BY t.relname, i.indexname)
    FROM t JOIN pg_indexes i ON i.schemaname = 'public' AND i.tablename = t.relname
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P2: triggers, trigger functions, policies, rules, broad trigger scan =====
WITH t AS (
  SELECT c.oid, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
trg AS (
  SELECT t.relname, g.oid AS trigger_oid, g.tgname, g.tgenabled, g.tgfoid
  FROM t
  JOIN pg_trigger g ON g.tgrelid = t.oid AND NOT g.tgisinternal
),
fn_ids AS (
  SELECT DISTINCT trg.tgfoid AS fn_oid FROM trg
),
fn AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         pg_get_userbyid(p.proowner) AS owner, l.lanname AS language, p.prosecdef, p.proconfig, p.proowner, p.proacl
  FROM fn_ids
  JOIN pg_proc p ON p.oid = fn_ids.fn_oid
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
)
SELECT jsonb_build_object(
  'run', 'D2-P2',
  'triggers', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', trg.relname, 'name', trg.tgname, 'enabled', trg.tgenabled::text,
      'definition', pg_get_triggerdef(trg.trigger_oid),
      'function_schema', n.nspname, 'function', p.proname, 'function_args', pg_get_function_identity_arguments(p.oid)
    ) ORDER BY trg.relname, trg.tgname)
    FROM trg
    JOIN pg_proc p ON p.oid = trg.tgfoid
    JOIN pg_namespace n ON n.oid = p.pronamespace
  ), '[]'::jsonb),
  'trigger_functions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', fn.schema_name, 'name', fn.proname, 'args', fn.args, 'owner', fn.owner, 'language', fn.language,
      'security_definer', fn.prosecdef, 'config', to_jsonb(fn.proconfig),
      'execute_grantees', to_jsonb(ARRAY(
        SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END
        FROM aclexplode(COALESCE(fn.proacl, acldefault('f', fn.proowner))) AS x
        WHERE x.privilege_type = 'EXECUTE'
        ORDER BY 1
      )),
      'definition_md5', md5(pg_get_functiondef(fn.oid)), 'definition_length', length(pg_get_functiondef(fn.oid))
    ) ORDER BY fn.schema_name, fn.proname, fn.args)
    FROM fn
  ), '[]'::jsonb),
  'policies', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', pol.tablename, 'name', pol.policyname, 'permissive', pol.permissive, 'roles', to_jsonb(pol.roles),
      'command', pol.cmd, 'using', pol.qual, 'with_check', pol.with_check
    ) ORDER BY pol.tablename, pol.policyname)
    FROM pg_policies pol
    WHERE pol.schemaname = 'public'
      AND pol.tablename IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
  ), '[]'::jsonb),
  'rules', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('table', t.relname, 'name', rw.rulename, 'event', rw.ev_type::text, 'definition', pg_get_ruledef(rw.oid))
                     ORDER BY t.relname, rw.rulename)
    FROM t JOIN pg_rewrite rw ON rw.ev_class = t.oid AND rw.rulename <> '_RETURN'
  ), '[]'::jsonb),
  'broad_trigger_scan_public', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('table', c.relname, 'trigger', g.tgname, 'enabled', g.tgenabled::text) ORDER BY c.relname, g.tgname)
    FROM pg_trigger g
    JOIN pg_class c ON c.oid = g.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT g.tgisinternal AND n.nspname = 'public'
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P3: definitions (trigger functions, is_admin, get_study_heatmap_split) and study_sessions routine leads =====
WITH t AS (
  SELECT c.oid
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
wanted AS (
  SELECT g.tgfoid AS fn_oid, 'trigger_function' AS why
  FROM t JOIN pg_trigger g ON g.tgrelid = t.oid AND NOT g.tgisinternal
  UNION
  SELECT p.oid, 'named_function'
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname IN ('is_admin', 'get_study_heatmap_split')
)
SELECT jsonb_build_object(
  'run', 'D2-P3',
  'definitions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'why', w.why, 'schema', n.nspname, 'name', p.proname, 'args', pg_get_function_identity_arguments(p.oid),
      'result_type', pg_get_function_result(p.oid), 'owner', pg_get_userbyid(p.proowner), 'security_definer', p.prosecdef,
      'config', to_jsonb(p.proconfig),
      'execute_grantees', to_jsonb(ARRAY(
        SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END
        FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS x
        WHERE x.privilege_type = 'EXECUTE'
        ORDER BY 1
      )),
      'definition_md5', md5(pg_get_functiondef(p.oid)), 'definition', pg_get_functiondef(p.oid)
    ) ORDER BY n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
    FROM wanted w
    JOIN pg_proc p ON p.oid = w.fn_oid
    JOIN pg_namespace n ON n.oid = p.pronamespace
  ), '[]'::jsonb),
  'routines_naming_study_sessions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'schema', n.nspname, 'name', p.proname, 'args', pg_get_function_identity_arguments(p.oid),
      'returns_set', p.proretset, 'result_type', pg_get_function_result(p.oid), 'language', l.lanname
    ) ORDER BY n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      AND lower(p.prosrc) ~ '\mstudy_sessions\M'
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P4: roles, memberships, ACLs, effective privileges, sequences, default ACLs =====
WITH t AS (
  SELECT c.oid, c.relname, c.relowner, c.relacl
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('study_sessions', 'flashcards', 'notes', 'profiles', 'access_requests', 'disciplines', 'subjects', 'topics')
),
r AS (
  SELECT ro.oid, ro.rolname, ro.rolsuper, ro.rolbypassrls, ro.rolinherit, ro.rolcanlogin
  FROM pg_roles ro
  WHERE ro.rolname !~ '^pg_'
)
SELECT jsonb_build_object(
  'run', 'D2-P4',
  'roles', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('name', r.rolname, 'superuser', r.rolsuper, 'bypassrls', r.rolbypassrls,
                                        'inherit', r.rolinherit, 'can_login', r.rolcanlogin) ORDER BY r.rolname)
    FROM r), '[]'::jsonb),
  'memberships', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('role', pg_get_userbyid(m.roleid), 'member', pg_get_userbyid(m.member),
                                        'admin_option', m.admin_option, 'inherit_option', m.inherit_option, 'set_option', m.set_option)
                     ORDER BY pg_get_userbyid(m.roleid), pg_get_userbyid(m.member))
    FROM pg_auth_members m
    WHERE pg_get_userbyid(m.roleid) !~ '^pg_'
  ), '[]'::jsonb),
  'table_acl', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', t.relname, 'owner', pg_get_userbyid(t.relowner),
      'grants', to_jsonb(ARRAY(
        SELECT (CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END) || ':' || x.privilege_type
        FROM aclexplode(COALESCE(t.relacl, acldefault('r', t.relowner))) AS x
        ORDER BY 1
      ))
    ) ORDER BY t.relname)
    FROM t), '[]'::jsonb),
  'column_acl', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', t.relname, 'column', a.attname,
      'grants', to_jsonb(ARRAY(
        SELECT (CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END) || ':' || x.privilege_type
        FROM aclexplode(a.attacl) AS x
        ORDER BY 1
      ))
    ) ORDER BY t.relname, a.attnum)
    FROM t JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped AND a.attacl IS NOT NULL
  ), '[]'::jsonb),
  'effective_table_privileges', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'role', r.rolname, 'table', t.relname,
      'select', has_table_privilege(r.oid, t.oid, 'SELECT'),
      'insert', has_table_privilege(r.oid, t.oid, 'INSERT'),
      'update', has_table_privilege(r.oid, t.oid, 'UPDATE'),
      'delete', has_table_privilege(r.oid, t.oid, 'DELETE'),
      'truncate', has_table_privilege(r.oid, t.oid, 'TRUNCATE')
    ) ORDER BY r.rolname, t.relname)
    FROM r CROSS JOIN t), '[]'::jsonb),
  'study_sessions_effective_column_privileges', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'role', r.rolname, 'column', a.attname,
      'insert', has_column_privilege(r.oid, t.oid, a.attnum, 'INSERT'),
      'update', has_column_privilege(r.oid, t.oid, a.attnum, 'UPDATE')
    ) ORDER BY r.rolname, a.attnum)
    FROM r
    JOIN t ON t.relname = 'study_sessions'
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped
    WHERE r.rolname IN ('anon', 'authenticated', 'service_role')
  ), '[]'::jsonb),
  'sequences_behind_columns', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'table', t.relname, 'column', a.attname, 'sequence', s.seq,
      'sequence_owner', pg_get_userbyid(sc.relowner),
      'sequence_grants', to_jsonb(ARRAY(
        SELECT (CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END) || ':' || x.privilege_type
        FROM aclexplode(COALESCE(sc.relacl, acldefault('s', sc.relowner))) AS x
        ORDER BY 1
      ))
    ) ORDER BY t.relname, a.attname)
    FROM t
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped
    CROSS JOIN LATERAL (SELECT pg_get_serial_sequence('public.' || t.relname, a.attname::text) AS seq) s
    JOIN pg_class sc ON sc.oid = to_regclass(s.seq)
    WHERE s.seq IS NOT NULL
  ), '[]'::jsonb),
  'default_acls', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'role', pg_get_userbyid(d.defaclrole), 'schema', COALESCE(n.nspname, '(all schemas)'), 'object_type', d.defaclobjtype::text,
      'acl', d.defaclacl::text
    ) ORDER BY pg_get_userbyid(d.defaclrole), d.defaclobjtype::text)
    FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
  ), '[]'::jsonb)
) AS result;

-- ===== RUN P5: aggregate data shapes (counts only) =====
WITH cards AS (
  SELECT 'flashcards' AS tbl, (f.subject_id IS NOT NULL) AS s_set, f.discipline_id AS d, s.discipline_id AS ds,
         sd.name AS ds_name, dd.name AS d_name, f.target_course AS t
  FROM public.flashcards f
  LEFT JOIN public.subjects s ON s.id = f.subject_id
  LEFT JOIN public.disciplines sd ON sd.id = s.discipline_id
  LEFT JOIN public.disciplines dd ON dd.id = f.discipline_id
  UNION ALL
  SELECT 'notes', (n.subject_id IS NOT NULL), n.discipline_id, s.discipline_id, sd.name, dd.name, n.target_course
  FROM public.notes n
  LEFT JOIN public.subjects s ON s.id = n.subject_id
  LEFT JOIN public.disciplines sd ON sd.id = s.discipline_id
  LEFT JOIN public.disciplines dd ON dd.id = n.discipline_id
),
classified AS (
  SELECT c.tbl,
         CASE
           WHEN c.s_set AND c.ds IS NULL THEN 'subject_without_discipline'
           WHEN c.s_set AND c.d IS NOT NULL AND c.d IS DISTINCT FROM c.ds THEN 'conflict_discipline_vs_subject'
           WHEN c.s_set AND c.t IS DISTINCT FROM c.ds_name THEN 'conflict_target_vs_subject'
           WHEN c.s_set AND c.d IS NULL THEN 'consistent_legacy_subject_only'
           WHEN c.s_set THEN 'consistent_full'
           WHEN c.d IS NOT NULL AND c.t IS DISTINCT FROM c.d_name THEN 'conflict_target_vs_discipline'
           WHEN c.d IS NOT NULL THEN 'platform_by_discipline'
           WHEN EXISTS (SELECT 1 FROM public.disciplines x WHERE x.name = c.t) THEN 'no_subject_no_discipline_target_equals_a_discipline_name'
           WHEN EXISTS (SELECT 1 FROM public.disciplines x
                        WHERE lower(btrim(regexp_replace(x.name, '\s+', ' ', 'g'))) = lower(btrim(regexp_replace(COALESCE(c.t, ''), '\s+', ' ', 'g')))) THEN 'no_subject_no_discipline_target_equals_a_discipline_name_after_normalization_only'
           WHEN c.t IS NULL THEN 'no_subject_no_discipline_target_null'
           ELSE 'custom_or_unassigned'
         END AS class
  FROM cards c
),
prof AS (
  SELECT p.role, p.account_type, p.course_level AS v
  FROM public.profiles p
),
ar AS (
  SELECT a.course AS v FROM public.access_requests a
)
SELECT jsonb_build_object(
  'run', 'D2-P5',
  'study_sessions', jsonb_build_object(
    'total', (SELECT count(*) FROM public.study_sessions),
    'by_source', COALESCE((SELECT jsonb_agg(jsonb_build_object('source', q.source, 'rows', q.n) ORDER BY q.source)
                           FROM (SELECT source, count(*) AS n FROM public.study_sessions GROUP BY source) q), '[]'::jsonb),
    'null_counts', (SELECT jsonb_build_object(
        'id', count(*) FILTER (WHERE id IS NULL), 'user_id', count(*) FILTER (WHERE user_id IS NULL),
        'started_at', count(*) FILTER (WHERE started_at IS NULL), 'ended_at', count(*) FILTER (WHERE ended_at IS NULL),
        'duration_seconds', count(*) FILTER (WHERE duration_seconds IS NULL), 'session_date', count(*) FILTER (WHERE session_date IS NULL),
        'source', count(*) FILTER (WHERE source IS NULL), 'created_at', count(*) FILTER (WHERE created_at IS NULL),
        'category', count(*) FILTER (WHERE category IS NULL))
      FROM public.study_sessions),
    'manual_rows', (SELECT count(*) FROM public.study_sessions WHERE source = 'manual'),
    'manual_rows_without_category', (SELECT count(*) FROM public.study_sessions WHERE source = 'manual' AND category IS NULL)
  ),
  'profiles_course_level_shapes', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'role', q.role, 'account_type', q.account_type, 'profiles', q.n, 'null', q.n_null, 'blank_after_trim', q.n_blank,
      'over_120_chars', q.n_over, 'control_char', q.n_ctl, 'outer_whitespace', q.n_outer, 'repeated_internal_whitespace', q.n_rep,
      'equals_other_after_normalization', q.n_other
    ) ORDER BY q.role, q.account_type)
    FROM (
      SELECT role, account_type, count(*) AS n,
             count(*) FILTER (WHERE v IS NULL) AS n_null,
             count(*) FILTER (WHERE v IS NOT NULL AND btrim(v) = '') AS n_blank,
             count(*) FILTER (WHERE v IS NOT NULL AND char_length(v) > 120) AS n_over,
             count(*) FILTER (WHERE v IS NOT NULL AND v ~ '[[:cntrl:]]') AS n_ctl,
             count(*) FILTER (WHERE v IS NOT NULL AND v <> btrim(v)) AS n_outer,
             count(*) FILTER (WHERE v IS NOT NULL AND v ~ '\s{2,}') AS n_rep,
             count(*) FILTER (WHERE v IS NOT NULL AND lower(btrim(regexp_replace(v, '\s+', ' ', 'g'))) = 'other') AS n_other
      FROM prof GROUP BY role, account_type
    ) q
  ), '[]'::jsonb),
  'access_requests_course_shapes', (
    SELECT jsonb_build_object(
      'requests', count(*), 'null', count(*) FILTER (WHERE v IS NULL),
      'blank_after_trim', count(*) FILTER (WHERE v IS NOT NULL AND btrim(v) = ''),
      'over_120_chars', count(*) FILTER (WHERE v IS NOT NULL AND char_length(v) > 120),
      'control_char', count(*) FILTER (WHERE v IS NOT NULL AND v ~ '[[:cntrl:]]'),
      'outer_whitespace', count(*) FILTER (WHERE v IS NOT NULL AND v <> btrim(v)),
      'repeated_internal_whitespace', count(*) FILTER (WHERE v IS NOT NULL AND v ~ '\s{2,}'),
      'equals_other_after_normalization', count(*) FILTER (WHERE v IS NOT NULL AND lower(btrim(regexp_replace(v, '\s+', ' ', 'g'))) = 'other'),
      'max_length', max(char_length(v))
    ) FROM ar),
  'cards_and_notes_by_class', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('table', q.tbl, 'class', q.class, 'rows', q.n) ORDER BY q.tbl, q.class)
    FROM (SELECT tbl, class, count(*) AS n FROM classified GROUP BY tbl, class) q
  ), '[]'::jsonb),
  'disciplines', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'name', d.name, 'is_active', d.is_active,
      'normalized', lower(btrim(regexp_replace(d.name, '\s+', ' ', 'g'))),
      'length', char_length(d.name), 'has_control_char', (d.name ~ '[[:cntrl:]]'), 'has_outer_whitespace', (d.name <> btrim(d.name))
    ) ORDER BY d.name)
    FROM public.disciplines d), '[]'::jsonb),
  'discipline_normalized_name_collisions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('normalized', q.norm, 'rows', q.n) ORDER BY q.norm)
    FROM (SELECT lower(btrim(regexp_replace(name, '\s+', ' ', 'g'))) AS norm, count(*) AS n
          FROM public.disciplines GROUP BY 1 HAVING count(*) > 1) q
  ), '[]'::jsonb),
  'subjects', jsonb_build_object(
    'total', (SELECT count(*) FROM public.subjects),
    'without_discipline', (SELECT count(*) FROM public.subjects WHERE discipline_id IS NULL),
    'per_discipline', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('discipline', q.dname, 'subjects', q.n, 'active_subjects', q.n_active) ORDER BY q.dname)
      FROM (SELECT d.name AS dname, count(s.id) AS n, count(s.id) FILTER (WHERE s.is_active) AS n_active
            FROM public.disciplines d LEFT JOIN public.subjects s ON s.discipline_id = d.id GROUP BY d.name) q
    ), '[]'::jsonb)
  ),
  'topics_total', (SELECT count(*) FROM public.topics)
) AS result;
