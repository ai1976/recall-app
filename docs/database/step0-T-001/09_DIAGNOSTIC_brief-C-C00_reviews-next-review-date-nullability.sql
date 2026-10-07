-- Name: [DIAGNOSTIC] T-001 brief C file C-00 (v3) - live nullability and data check for reviews.next_review_date, and the live write contract of reviews
--
-- Description: READ-ONLY, revised after QA Rounds 80 and 82 (v3; supersedes v2 3ad702447657 and v1 1d11ff59c2b7, neither of which was authorized or run). Implements file C-00 of brief C v5
-- (8cb1fddbe9af, Gate 1 given by the Founder on 07/10/2026): the precondition that must be measured before any SQL for the shared due-eligibility
-- helper (C-01) is authored. The repository schema documents reviews.next_review_date as nullable (DATABASE_SCHEMA.md:425) but the live catalog has not
-- been checked, and the live get_due_forecast_buckets sends a null date to bucket 7 while the cumulative counts never count it (brief C C-6.2).
-- DECISION RULE (declared before the run, QA Round 80 non-blocking 1): if N2 shows ANY null next_review_date, the behaviour for a null date is defined in
-- C-01 before it is written, whatever the partial count says; the partial eligibility count in N2 is triage, not proof, because it does not apply
-- enrollment, course or visibility. Only "the column is NOT NULL live" (N1) or "zero nulls" (N2) lets C-01 treat the case as test-only.
-- What changed from v2 (QA Round 82): (a) BLOCKING: N1 returned only the name, event and INSTEAD flag of each non-SELECT rewrite rule, which cannot show
--   what the rule writes. It now returns pg_get_ruledef for every such rule and a lexical flag whether the definition mentions next_review_date.
--   (b) Non-blocking 3, taken in advance: for every trigger function and every rule, N1 also returns the public routines whose names occur in the
--   definition (whole-identifier match after lower-casing and removing double quotes, every overload, an over-approximation), so a delegated write can
--   be followed without a second diagnostic. (c) Non-blocking 1: the time-zone counts are of REVIEW ROWS whose joined profile has a null, missing or
--   unlisted time zone (not of profiles); the wording below is corrected. (d) Non-blocking 2: any non-zero unlisted count is a C-01 input requiring
--   explicit review; it is not a parity validation.
-- What changed from v1 to v2 (each answers a QA Round 80 finding):
--   * Blocking 1. A trigger definition does not show what the trigger function writes. N1 now returns, for every non-internal trigger on reviews, the
--     trigger function's identity, language, owner, SECURITY DEFINER flag and FULL definition (pg_get_functiondef), plus a lexical flag whether that
--     definition mentions next_review_date. N1 also returns the non-SELECT rewrite rules on reviews (a rule could rewrite a write; v3 adds each rule's full definition) and whether each
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
--     non-internal trigger with its function (above); every non-SELECT rule; every index; the column facts of profiles.timezone and
--     profiles.course_level with expected-versus-found and missing names.
--   * N2 (data, counts only): total reviews rows; rows with a null next_review_date overall, by non-null status, by non-null question type, with a null
--     status, with a null question type, and without a flashcard; distinct users with a null; the partial-rule count; null last_reviewed_at; earliest
--     and latest created_at of null rows; time-zone validity counts. No user id, flashcard id, card text or row identity is returned.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Only catalog views and functions (pg_class, pg_namespace, pg_attribute, pg_attrdef, pg_constraint, pg_trigger, pg_rewrite, pg_index, pg_proc,
-- pg_language, pg_timezone_names, pg_get_expr, pg_get_constraintdef, pg_get_triggerdef, pg_get_indexdef, pg_get_functiondef, pg_get_ruledef, pg_get_userbyid,
-- format_type) and plain reads of public.reviews, public.flashcards and public.profiles.
-- Blind spots, stated: counts are one statement's view at its run time (N1 and N2 are separate statements, not one snapshot); row-level security does
-- not apply to the SQL Editor role the way it applies to a student, which is intended (the whole table is measured); the result does not say why a null
-- exists; a trigger function's reach through other functions is not followed.
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
)
SELECT jsonb_build_object(
  'run', 'N1',
  'reviews_table_found', EXISTS (SELECT 1 FROM rv),
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
                  position('next_review_date' IN lower(replace(pg_get_functiondef(p.oid), '"', ''))) > 0,
                'public_routines_named_in_function_definition',
                  (SELECT COALESCE(jsonb_agg(p2.proname || '(' || pg_get_function_identity_arguments(p2.oid) || ')' ORDER BY p2.proname, p2.oid), '[]'::jsonb)
                   FROM pg_proc p2 JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
                   WHERE n2.nspname = 'public' AND p2.oid <> p.oid AND p2.proname ~ '^[a-z0-9_]+$'
                     AND lower(replace(pg_get_functiondef(p.oid), '"', '')) ~ ('(^|[^a-z0-9_])' || p2.proname || '([^a-z0-9_]|$)')))
                ORDER BY g.tgname)
              FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid
              JOIN pg_proc p ON p.oid = g.tgfoid
              JOIN pg_namespace pn ON pn.oid = p.pronamespace
              JOIN pg_language l ON l.oid = p.prolang
              WHERE NOT g.tgisinternal),
  'non_select_rules', (SELECT jsonb_agg(jsonb_build_object(
                'name', w.rulename, 'event', w.ev_type, 'instead', w.is_instead,
                'definition', pg_get_ruledef(w.oid),
                'definition_mentions_next_review_date',
                  position('next_review_date' IN lower(replace(pg_get_ruledef(w.oid), '"', ''))) > 0,
                'public_routines_named_in_definition',
                  (SELECT COALESCE(jsonb_agg(p2.proname || '(' || pg_get_function_identity_arguments(p2.oid) || ')' ORDER BY p2.proname, p2.oid), '[]'::jsonb)
                   FROM pg_proc p2 JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
                   WHERE n2.nspname = 'public' AND p2.proname ~ '^[a-z0-9_]+$'
                     AND lower(replace(pg_get_ruledef(w.oid), '"', '')) ~ ('(^|[^a-z0-9_])' || p2.proname || '([^a-z0-9_]|$)')))
                ORDER BY w.rulename)
              FROM pg_rewrite w JOIN rv ON w.ev_class = rv.oid WHERE w.ev_type <> '1'),
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
