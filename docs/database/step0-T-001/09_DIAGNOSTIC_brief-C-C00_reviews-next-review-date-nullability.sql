-- Name: [DIAGNOSTIC] T-001 brief C file C-00 (v4) - live nullability and data check for reviews.next_review_date, and the live write contract of reviews
--
-- Description: READ-ONLY, revised after QA Rounds 80, 82 and 84 (v4; supersedes v3 9423a8ec8127, v2 3ad702447657 and v1 1d11ff59c2b7, none of which was authorized or run). Implements file C-00 of brief C v5
-- (8cb1fddbe9af, Gate 1 given by the Founder on 07/10/2026): the precondition that must be measured before any SQL for the shared due-eligibility
-- helper (C-01) is authored. The repository schema documents reviews.next_review_date as nullable (DATABASE_SCHEMA.md:425) but the live catalog has not
-- been checked, and the live get_due_forecast_buckets sends a null date to bucket 7 while the cumulative counts never count it (brief C C-6.2).
-- DECISION RULE (declared before the run, QA Round 80 non-blocking 1): if N2 shows ANY null next_review_date, the behaviour for a null date is defined in
-- C-01 before it is written, whatever the partial count says; the partial eligibility count in N2 is triage, not proof, because it does not apply
-- enrollment, course or visibility. Only "the column is NOT NULL live" (N1) or "zero nulls" (N2) lets C-01 treat the case as test-only.
-- What changed from v3 (QA Round 84): v3 claimed that a delegated write could be followed without a second diagnostic but returned only callee NAMES,
--   searched only schema public, and said under blind spots that delegation is not followed. v4 resolves the contradiction in the narrowest honest way:
--   (a) N1 now returns, for every routine whose name occurs as a whole identifier in a trigger function body, a trigger definition, a non-SELECT rule
--   definition, a column default or generated expression, or a check constraint (every schema except pg_catalog, information_schema and pg_toast; every
--   overload; an over-approximation), the callee's exact identity, language, owner, SECURITY DEFINER flag, FULL definition and a lexical next_review_date
--   flag, with the sources that name it. (b) ONE LEVEL ONLY: a callee that itself delegates is NOT followed here. CONTRACT FOR C-01: C-01 is not authored
--   until QA and Claude have read delegated_callees; if any returned callee, or any trigger, rule or default, has a body that writes reviews or computes
--   next_review_date, or names a further routine that could, a follow-up definition fetch (one more read-only file) is required first. (c) Non-blocking 1:
--   N1 returns relkind, partition and inheritance facts and is_plain_unpartitioned_table; if that is not true, C-01 is not authored until the partitions
--   or the view are inspected. (d) Non-blocking 2: column defaults, generated expressions and check constraints are searched for callees too.
-- What changed from v2 to v3 (QA Round 82): (a) BLOCKING: N1 returned only the name, event and INSTEAD flag of each non-SELECT rewrite rule, which cannot show
--   what the rule writes. It now returns pg_get_ruledef for every such rule and a lexical flag whether the definition mentions next_review_date.
--   (b) Non-blocking 3, taken in advance: for every trigger function and every rule, N1 also returns the public routines whose names occur in the
--   definition (whole-identifier match after lower-casing and removing double quotes, every overload, an over-approximation), so a delegated write can
--   be followed without a second diagnostic. (c) Non-blocking 1: the time-zone counts are of REVIEW ROWS whose joined profile has a null, missing or
--   unlisted time zone (not of profiles); the wording below is corrected. (d) Non-blocking 2: any non-zero unlisted count is a C-01 input requiring
--   explicit review; it is not a parity validation.
-- What changed from v1 to v2 (each answers a QA Round 80 finding):
--   * Blocking 1. A trigger definition does not show what the trigger function writes. N1 now returns, for every non-internal trigger on reviews, the
--     trigger function's identity, language, owner, SECURITY DEFINER flag and FULL definition (pg_get_functiondef), plus a lexical flag whether that
--     definition mentions next_review_date. N1 also returns the non-SELECT rewrite rules on reviews (a rule could rewrite a write; v3 added each rule's full definition) and whether each
--     column is generated or identity. The flag is lexical: a function that reaches the column only through another function is NOT cleared by it, and
--     the full bodies are returned so the reading can be audited.
--   * Blocking 2. N2 no longer builds any JSON key from a possibly null value and uses no sentinel string. Breakdowns by status and by question_type
--     aggregate only non-null values; the rows with a null status, or a null question_type, or no matching flashcard, are separate counts.
--   * Non-blocking 2. A profile time zone that is not a listed name no longer aborts the run: N2 reports how many review rows have a null or missing profile
--     time zone and how many have a non-null value that is not in pg_timezone_names (case-insensitive; no value is returned), and uses the approved default
--     Asia/Kolkata for the local date of those rows in this diagnostic only. A valid zone written in a form pg_timezone_names does not list (for
--     example a POSIX string) would be counted as unlisted and measured with the default; this approximation is stated in the result.
--   * Non-blocking 3. N1 returns expected and found counts and the named missing columns for profiles.timezone and profiles.course_level.
--   * Non-blocking 1 is addressed by the decision rule above; the partial count keeps its explicit "partial" name.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * N1 (catalog): every column of public.reviews (type, NOT NULL, default expression, generated and identity flags); every constraint; every
--     non-internal trigger with its function (above); every non-SELECT rule with its definition; the delegated callees (above); the relation kind and partition facts; every index; the column facts of profiles.timezone and
--     profiles.course_level with expected-versus-found and missing names.
--   * N2 (data, counts only): total reviews rows; rows with a null next_review_date overall, by non-null status, by non-null question type, with a null
--     status, with a null question type, and without a flashcard; distinct users with a null; the partial-rule count; null last_reviewed_at; earliest
--     and latest created_at of null rows; time-zone validity counts. No user id, flashcard id, card text or row identity is returned.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Only catalog views and functions (pg_class, pg_namespace, pg_attribute, pg_attrdef, pg_constraint, pg_trigger, pg_rewrite, pg_index, pg_proc,
-- pg_language, pg_timezone_names, pg_get_expr, pg_get_constraintdef, pg_get_triggerdef, pg_get_indexdef, pg_get_functiondef, pg_get_ruledef, pg_get_partkeydef, pg_inherits, pg_get_userbyid,
-- format_type) and plain reads of public.reviews, public.flashcards and public.profiles.
-- Blind spots, stated: counts are one statement's view at its run time (N1 and N2 are separate statements, not one snapshot); row-level security does
-- not apply to the SQL Editor role the way it applies to a student, which is intended (the whole table is measured); the result does not say why a null
-- exists; delegation is followed ONE level only (a callee's own callees are not returned; see the contract for C-01 above); the name match is lexical
-- (names in comments or strings are reported, dynamic SQL cannot be seen).
--
-- HOW TO RUN (two runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and paste
-- it into one Notepad file under its label (N1, N2), unchanged. Save the file as docs/discussions/evidence/T-001_C00-raw_<dd-mm-yyyy>.raw.txt and keep
-- it untouched; the derived .json files are made from it by script. An error is evidence: save the error text under its label, do not edit and
-- re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN N1: catalog facts =====
WITH rv AS (
  SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'reviews'
),
pc AS (
  SELECT a.attname, format_type(a.atttypid, a.atttypmod) AS type, a.attnotnull, pg_get_expr(d.adbin, d.adrelid) AS default_expression
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE n.nspname = 'public' AND c.relname = 'profiles' AND a.attname IN ('timezone', 'course_level')
    AND a.attnum > 0 AND NOT a.attisdropped
),
src AS (
  -- every text through which reviews can reach a routine when a row is written: trigger function bodies, trigger definitions (WHEN clause),
  -- non-SELECT rule definitions, column default and generated expressions, check constraints; lower-cased, double quotes removed
  SELECT 'trigger_function:' || g.tgname AS label, lower(replace(pg_get_functiondef(g.tgfoid), '"', '')) AS body
  FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid WHERE NOT g.tgisinternal
  UNION ALL
  SELECT 'trigger_definition:' || g.tgname, lower(replace(pg_get_triggerdef(g.oid), '"', ''))
  FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid WHERE NOT g.tgisinternal
  UNION ALL
  SELECT 'rule:' || w.rulename, lower(replace(pg_get_ruledef(w.oid), '"', ''))
  FROM pg_rewrite w JOIN rv ON w.ev_class = rv.oid WHERE w.ev_type <> '1'
  UNION ALL
  SELECT 'column_default:' || a.attname, lower(replace(pg_get_expr(d.adbin, d.adrelid), '"', ''))
  FROM pg_attrdef d JOIN rv ON d.adrelid = rv.oid JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  UNION ALL
  SELECT 'check_constraint:' || k.conname, lower(replace(pg_get_constraintdef(k.oid), '"', ''))
  FROM pg_constraint k JOIN rv ON k.conrelid = rv.oid WHERE k.contype = 'c'
),
callees AS (
  -- one level only: every non-aggregate routine in any schema except pg_catalog, information_schema and pg_toast whose name occurs as a whole
  -- identifier in a source text above (every overload; an over-approximation); the reviews trigger functions themselves are returned under 'triggers'
  SELECT p2.oid AS poid, n2.nspname, p2.proname, array_agg(DISTINCT src.label ORDER BY src.label) AS named_in
  FROM src
  JOIN pg_proc p2 ON p2.prokind IN ('f', 'p') AND p2.proname ~ '^[a-z0-9_]+$'
                 AND src.body ~ ('(^|[^a-z0-9_])' || p2.proname || '([^a-z0-9_]|$)')
  JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
  WHERE n2.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND p2.oid NOT IN (SELECT g.tgfoid FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid WHERE NOT g.tgisinternal)
  GROUP BY p2.oid, n2.nspname, p2.proname
)
SELECT jsonb_build_object(
  'run', 'N1',
  'reviews_table_found', EXISTS (SELECT 1 FROM rv),
  'relation', (SELECT jsonb_build_object(
                'relkind', c.relkind, 'is_partition', c.relispartition, 'has_children_or_partitions', c.relhassubclass,
                'parent_count', (SELECT count(*) FROM pg_inherits i WHERE i.inhrelid = c.oid),
                'child_count', (SELECT count(*) FROM pg_inherits i WHERE i.inhparent = c.oid),
                'partitioned_by', pg_get_partkeydef(c.oid),
                'is_plain_unpartitioned_table',
                  (c.relkind = 'r' AND NOT c.relispartition AND NOT c.relhassubclass))
              FROM pg_class c JOIN rv ON c.oid = rv.oid),
  'columns', (SELECT jsonb_agg(jsonb_build_object(
                'column', a.attname, 'type', format_type(a.atttypid, a.atttypmod), 'not_null', a.attnotnull,
                'default_expression', pg_get_expr(d.adbin, d.adrelid),
                'generated', a.attgenerated, 'identity', a.attidentity)
                ORDER BY a.attnum)
              FROM pg_attribute a JOIN rv ON a.attrelid = rv.oid
              LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
              WHERE a.attnum > 0 AND NOT a.attisdropped),
  'constraints', (SELECT jsonb_agg(jsonb_build_object(
                'name', k.conname, 'type', k.contype, 'definition', pg_get_constraintdef(k.oid))
                ORDER BY k.conname)
              FROM pg_constraint k JOIN rv ON k.conrelid = rv.oid),
  'trigger_count', (SELECT count(*) FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid WHERE NOT g.tgisinternal),
  'triggers', (SELECT jsonb_agg(jsonb_build_object(
                'name', g.tgname, 'enabled', g.tgenabled, 'definition', pg_get_triggerdef(g.oid),
                'function_identity', pn.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
                'function_language', l.lanname,
                'function_owner', pg_get_userbyid(p.proowner),
                'function_security_definer', p.prosecdef,
                'function_definition', pg_get_functiondef(p.oid),
                'function_definition_mentions_next_review_date',
                  position('next_review_date' IN lower(replace(pg_get_functiondef(p.oid), '"', ''))) > 0)
                ORDER BY g.tgname)
              FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid
              JOIN pg_proc p ON p.oid = g.tgfoid
              JOIN pg_namespace pn ON pn.oid = p.pronamespace
              JOIN pg_language l ON l.oid = p.prolang
              WHERE NOT g.tgisinternal),
  'non_select_rule_count', (SELECT count(*) FROM pg_rewrite w JOIN rv ON w.ev_class = rv.oid WHERE w.ev_type <> '1'),
  'non_select_rules', (SELECT jsonb_agg(jsonb_build_object(
                'name', w.rulename, 'event', w.ev_type, 'instead', w.is_instead,
                'definition', pg_get_ruledef(w.oid),
                'definition_mentions_next_review_date',
                  position('next_review_date' IN lower(replace(pg_get_ruledef(w.oid), '"', ''))) > 0)
                ORDER BY w.rulename)
              FROM pg_rewrite w JOIN rv ON w.ev_class = rv.oid WHERE w.ev_type <> '1'),
  'delegated_callee_count', (SELECT count(*) FROM callees),
  'delegated_callees', (SELECT jsonb_agg(jsonb_build_object(
                'identity', c2.nspname || '.' || c2.proname || '(' || pg_get_function_identity_arguments(c2.poid) || ')',
                'named_in', c2.named_in,
                'language', l2.lanname,
                'owner', pg_get_userbyid(p3.proowner),
                'security_definer', p3.prosecdef,
                'definition', pg_get_functiondef(c2.poid),
                'definition_mentions_next_review_date',
                  position('next_review_date' IN lower(replace(pg_get_functiondef(c2.poid), '"', ''))) > 0)
                ORDER BY c2.nspname, c2.proname, c2.poid)
              FROM callees c2
              JOIN pg_proc p3 ON p3.oid = c2.poid
              JOIN pg_language l2 ON l2.oid = p3.prolang),
  'indexes', (SELECT jsonb_agg(jsonb_build_object(
                'name', ic.relname, 'definition', pg_get_indexdef(i.indexrelid))
                ORDER BY ic.relname)
              FROM pg_index i JOIN rv ON i.indrelid = rv.oid JOIN pg_class ic ON ic.oid = i.indexrelid),
  'profile_columns_expected_count', 2,
  'profile_columns_found_count', (SELECT count(*) FROM pc),
  'profile_columns_missing', (SELECT COALESCE(jsonb_agg(e.n ORDER BY e.n), '[]'::jsonb)
                              FROM (VALUES ('course_level'), ('timezone')) AS e(n)
                              WHERE NOT EXISTS (SELECT 1 FROM pc WHERE pc.attname = e.n)),
  'profile_columns', (SELECT jsonb_agg(jsonb_build_object(
                'column', pc.attname, 'type', pc.type, 'not_null', pc.attnotnull, 'default_expression', pc.default_expression)
                ORDER BY pc.attname)
              FROM pc)
) AS result;

-- ===== RUN N2: data counts (no identities) =====
WITH tzl AS MATERIALIZED (
  -- the listed names are read once (the view is expensive to evaluate per row)
  SELECT lower(z.name) AS nm FROM pg_timezone_names z
),
r AS (
  SELECT rv.next_review_date, rv.status, rv.skip_until, rv.user_id, rv.last_reviewed_at, rv.created_at,
         f.question_type AS question_type, (f.id IS NULL) AS no_flashcard,
         p.timezone AS raw_tz,
         (p.timezone IS NOT NULL AND lower(p.timezone) IN (SELECT nm FROM tzl)) AS tz_is_listed
  FROM public.reviews rv
  LEFT JOIN public.flashcards f ON f.id = rv.flashcard_id
  LEFT JOIN public.profiles p ON p.id = rv.user_id
),
n AS (
  SELECT r.*, (CASE WHEN r.tz_is_listed THEN r.raw_tz ELSE 'Asia/Kolkata' END) AS tz_used
  FROM r
  WHERE r.next_review_date IS NULL
)
SELECT jsonb_build_object(
  'run', 'N2',
  'reviews_total', (SELECT count(*) FROM r),
  'null_next_review_date_total', (SELECT count(*) FROM n),
  'null_by_status', (SELECT COALESCE(jsonb_object_agg(s.status, s.c), '{}'::jsonb)
                     FROM (SELECT status, count(*) AS c FROM n WHERE status IS NOT NULL GROUP BY status) s),
  'null_rows_with_null_status', (SELECT count(*) FROM n WHERE status IS NULL),
  'null_by_question_type', (SELECT COALESCE(jsonb_object_agg(s.question_type, s.c), '{}'::jsonb)
                            FROM (SELECT question_type, count(*) AS c FROM n WHERE question_type IS NOT NULL GROUP BY question_type) s),
  'null_rows_with_null_question_type_and_a_flashcard', (SELECT count(*) FROM n WHERE question_type IS NULL AND NOT no_flashcard),
  'null_rows_without_a_flashcard', (SELECT count(*) FROM n WHERE no_flashcard),
  'users_with_a_null', (SELECT count(DISTINCT user_id) FROM n),
  'null_rows_passing_status_skip_and_type_parts_of_rule_PARTIAL', (
      SELECT count(*) FROM n
      WHERE status = 'active'
        AND (skip_until IS NULL OR skip_until <= (now() AT TIME ZONE tz_used)::date)
        AND COALESCE(question_type, '') <> 'concept_card'),
  'null_rows_with_null_last_reviewed_at', (SELECT count(*) FROM n WHERE last_reviewed_at IS NULL),
  'null_rows_created_at_min', (SELECT min(created_at) FROM n),
  'null_rows_created_at_max', (SELECT max(created_at) FROM n),
  'timezone_check', jsonb_build_object(
      'reviews_rows_whose_profile_timezone_is_null_or_missing', (SELECT count(*) FROM r WHERE raw_tz IS NULL),
      'reviews_rows_whose_profile_timezone_is_not_listed', (SELECT count(*) FROM r WHERE raw_tz IS NOT NULL AND NOT tz_is_listed),
      'note', 'rows with a null or unlisted time zone use Asia/Kolkata for the local date in this diagnostic only; an unlisted but valid zone form (for example a POSIX string) is counted as unlisted')
) AS result;
