-- Name: [DIAGNOSTIC] T-001 brief C file C-00 (v1) - live nullability and data check for reviews.next_review_date, and the live shape of reviews
--
-- Description: READ-ONLY. Implements file C-00 of brief C v5 (8cb1fddbe9af, Gate 1 given by the Founder on 07/10/2026): the precondition that must be
-- measured before any SQL for the shared due-eligibility helper (C-01) is authored. The repository schema documents reviews.next_review_date as
-- nullable (DATABASE_SCHEMA.md:425) but the live catalog has not been checked, and the live get_due_forecast_buckets sends a null date to bucket 7
-- while the cumulative counts never count it (brief C C-6.2). This file answers: is the column NOT NULL live; does any row hold a null; if so, how
-- many, for how many users, in which status and question type, and does any constraint or trigger touch the column.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * N1 (catalog): every column of public.reviews (name, type, NOT NULL, default expression), every constraint on public.reviews (type and
--     definition), every non-internal trigger on public.reviews (name, enabled state, definition), every index on public.reviews (definition), and
--     the column facts (type, NOT NULL, default) of profiles.timezone and profiles.course_level, which define the profile's "today" and course in C-6.1.
--   * N2 (data, counts only): total reviews rows; rows with a null next_review_date, overall, by status, and by the flashcard question type
--     (concept_card or other, or no matching flashcard); the number of distinct users with at least one null; the number of null rows that would
--     otherwise satisfy the status, skip and question-type parts of the C-6.1 rule (status 'active', skip_until null or not later than the user's local
--     today, question_type not 'concept_card'); and for null rows, whether last_reviewed_at is null and the earliest and latest created_at.
--     No user id, flashcard id, card text or row identity is returned.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Only
-- catalog views and functions (pg_class, pg_namespace, pg_attribute, pg_attrdef, pg_constraint, pg_trigger, pg_index, pg_get_expr,
-- pg_get_constraintdef, pg_get_triggerdef, pg_get_indexdef, format_type) and plain reads of public.reviews, public.flashcards and public.profiles.
-- Blind spots, stated: counts are a single statement's view at its run time; row-level security does not apply to the SQL Editor role in the way it
-- applies to a student, which is intended here (the whole table is measured); the result does not say why a null exists.
--
-- HOW TO RUN (two runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and paste
-- it into one Notepad file under its label (N1, N2), unchanged. Save the file as docs/discussions/evidence/T-001_C00-raw_<dd-mm-yyyy>.raw.txt and keep
-- it untouched; the derived .json files are made from it by script. An error is evidence: save the error text under its label, do not edit and
-- re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN N1: catalog facts =====
WITH rv AS (
  SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'reviews'
)
SELECT jsonb_build_object(
  'run', 'N1',
  'reviews_table_found', EXISTS (SELECT 1 FROM rv),
  'columns', (SELECT jsonb_agg(jsonb_build_object(
                'column', a.attname, 'type', format_type(a.atttypid, a.atttypmod), 'not_null', a.attnotnull,
                'default_expression', pg_get_expr(d.adbin, d.adrelid))
                ORDER BY a.attnum)
              FROM pg_attribute a JOIN rv ON a.attrelid = rv.oid
              LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
              WHERE a.attnum > 0 AND NOT a.attisdropped),
  'constraints', (SELECT jsonb_agg(jsonb_build_object(
                'name', k.conname, 'type', k.contype, 'definition', pg_get_constraintdef(k.oid))
                ORDER BY k.conname)
              FROM pg_constraint k JOIN rv ON k.conrelid = rv.oid),
  'triggers', (SELECT jsonb_agg(jsonb_build_object(
                'name', g.tgname, 'enabled', g.tgenabled, 'definition', pg_get_triggerdef(g.oid))
                ORDER BY g.tgname)
              FROM pg_trigger g JOIN rv ON g.tgrelid = rv.oid WHERE NOT g.tgisinternal),
  'indexes', (SELECT jsonb_agg(jsonb_build_object(
                'name', ic.relname, 'definition', pg_get_indexdef(i.indexrelid))
                ORDER BY ic.relname)
              FROM pg_index i JOIN rv ON i.indrelid = rv.oid JOIN pg_class ic ON ic.oid = i.indexrelid),
  'profile_columns', (SELECT jsonb_agg(jsonb_build_object(
                'column', a.attname, 'type', format_type(a.atttypid, a.atttypmod), 'not_null', a.attnotnull,
                'default_expression', pg_get_expr(d.adbin, d.adrelid))
                ORDER BY a.attname)
              FROM pg_attribute a
              JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
              LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
              WHERE n.nspname = 'public' AND c.relname = 'profiles' AND a.attname IN ('timezone', 'course_level')
                AND a.attnum > 0 AND NOT a.attisdropped)
) AS result;

-- ===== RUN N2: data counts (no identities) =====
WITH r AS (
  SELECT rv.next_review_date, rv.status, rv.skip_until, rv.user_id, rv.last_reviewed_at, rv.created_at,
         f.question_type AS question_type, (f.id IS NULL) AS no_flashcard,
         COALESCE(p.timezone, 'Asia/Kolkata') AS tz
  FROM public.reviews rv
  LEFT JOIN public.flashcards f ON f.id = rv.flashcard_id
  LEFT JOIN public.profiles p ON p.id = rv.user_id
),
nulls AS (
  SELECT * FROM r WHERE next_review_date IS NULL
)
SELECT jsonb_build_object(
  'run', 'N2',
  'reviews_total', (SELECT count(*) FROM r),
  'null_next_review_date_total', (SELECT count(*) FROM nulls),
  'null_by_status', (SELECT COALESCE(jsonb_object_agg(status, c), '{}'::jsonb)
                     FROM (SELECT status, count(*) AS c FROM nulls GROUP BY status) s),
  'null_by_question_type', (SELECT COALESCE(jsonb_object_agg(COALESCE(question_type, '(no value)'), c), '{}'::jsonb)
                            FROM (SELECT question_type, count(*) AS c FROM nulls GROUP BY question_type) s),
  'null_rows_without_a_flashcard', (SELECT count(*) FROM nulls WHERE no_flashcard),
  'users_with_a_null', (SELECT count(DISTINCT user_id) FROM nulls),
  'null_rows_passing_status_skip_and_type_parts_of_rule', (
      SELECT count(*) FROM nulls
      WHERE status = 'active'
        AND (skip_until IS NULL OR skip_until <= (now() AT TIME ZONE tz)::date)
        AND COALESCE(question_type, '') <> 'concept_card'),
  'null_rows_with_null_last_reviewed_at', (SELECT count(*) FROM nulls WHERE last_reviewed_at IS NULL),
  'null_rows_created_at_min', (SELECT min(created_at) FROM nulls),
  'null_rows_created_at_max', (SELECT max(created_at) FROM nulls)
) AS result;
