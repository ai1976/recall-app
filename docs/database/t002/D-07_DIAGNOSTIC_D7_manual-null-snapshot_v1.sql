-- Name: [DIAGNOSTIC] T-002 D7 (v1) - snapshot of the manual study logs that carry no classification (S0 before and S1 after the F1 promotion)
--
-- Description: READ-ONLY (Tier 0). Plan v18 section 5.2 (the anchor set A and the deployment choreography): the set of study_sessions rows with source = 'manual' and a NULL classification, the
-- rows that existed before logging was classified. It records, for that set, the count, the sum of duration_seconds, a per-row fingerprint over EVERY column of the row in the frozen order, and an overall hash,
-- plus the database clock, so S0 (taken immediately before the F1 push) and S1 (immediately after F1 is served) can be compared. Nothing is written.
-- ONE encoding (plan 5.2, hash normalization; the data fix, the cutover and the tests will use the same): rows ordered by id as text in the C collation; for each row the 17 columns in this frozen
-- order: id, user_id, started_at, ended_at, duration_seconds, session_date, source, created_at, category, session_id, classification, discipline_id, subject_id, custom_course_label, custom_course_key, custom_subject_label, custom_subject_key; each value rendered CASE WHEN x IS NULL THEN 'N' ELSE 'V' || length(x::text) || ':' || x::text END and joined by '|'; fingerprint = lower-case hex of sha256 over the UTF-8 bytes of
-- that text; the overall hash = sha256 (hex) of the pairs 'id:fingerprint' in that id order joined by ','; an empty set hashes the empty string. The session is pinned (TimeZone UTC, DateStyle 'ISO, YMD',
-- IntervalStyle iso_8601, extra_float_digits 1) by SET LOCAL lines, which only last for the run and change nothing stored.
-- What it returns:
--   * RUN S (summary): ONE row, ONE jsonb cell: tool_version, database clock (UTC) at the start of the statement and at the end, server version, whether the live column order equals the frozen list (columns_match),
--     the count, the sum of duration_seconds, the overall hash, the number of pages the list needs, and context counts (all study_sessions rows, by source and classification).
--   * RUN P1 to P5 (the list): the id and the fingerprint of every row of the set, 500 rows per page, in id order. Only the pages that the summary says are needed carry rows; a page beyond the set returns no rows.
-- Safety: every RUN is SET LOCAL lines plus one WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control or application-function call. Blind spots, stated: it is one statement's view at its
-- run time; the SQL Editor role bypasses student RLS (intended); the fingerprints are evidence of the stored values, not of who wrote them.
--
-- HOW TO RUN: select the text of ONE run (from its banner line to its closing semicolon), click Run. RUN S: copy the single result cell and paste it unchanged into a Notepad file. RUNs P1 to P5: copy the whole
-- result grid (all rows) and paste it unchanged under a label line in a second Notepad file, in page order. Save as docs/discussions/evidence/T-002_<S0 or S1>-summary_<dd-mm-yyyy>.raw.txt and
-- T-002_<S0 or S1>-pages_<dd-mm-yyyy>.raw.txt (the go-live runbook says which and when). An error is evidence: save the error text, do not edit and re-run. If a paste looks cut short, stop and report.
-- Check in the summary: "tool_version":"D7-v1", "columns_match":true, and the count; the pages needed are listed there.

-- ===== RUN S: summary =====
SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT jsonb_build_object(
  'run', 'D7-S',
  'tool_version', 'D7-v1',
  'started_utc', to_char(statement_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'finished_utc', to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'server_version', current_setting('server_version'),
  'pinned', jsonb_build_object('TimeZone', current_setting('TimeZone'), 'DateStyle', current_setting('DateStyle'), 'IntervalStyle', current_setting('IntervalStyle'), 'extra_float_digits', current_setting('extra_float_digits')),
  'frozen_columns', 'id,user_id,started_at,ended_at,duration_seconds,session_date,source,created_at,category,session_id,classification,discipline_id,subject_id,custom_course_label,custom_course_key,custom_subject_label,custom_subject_key',
  'live_columns', (SELECT string_agg(a.attname, ',' ORDER BY a.attnum) FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attnum > 0 AND NOT a.attisdropped),
  'columns_match', (SELECT string_agg(a.attname, ',' ORDER BY a.attnum) FROM pg_attribute a WHERE a.attrelid = 'public.study_sessions'::regclass AND a.attnum > 0 AND NOT a.attisdropped) = 'id,user_id,started_at,ended_at,duration_seconds,session_date,source,created_at,category,session_id,classification,discipline_id,subject_id,custom_course_label,custom_course_key,custom_subject_label,custom_subject_key',
  'set_count', (SELECT count(*) FROM fp),
  'set_sum_duration_seconds', (SELECT COALESCE(sum(duration_seconds), 0) FROM fp),
  'set_overall_hash', (SELECT encode(sha256(convert_to(COALESCE(string_agg(f.id::text || ':' || f.fingerprint, ',' ORDER BY f.id::text COLLATE "C"), ''), 'UTF8')), 'hex') FROM fp f),
  'pages_needed', (SELECT ceil(count(*) / 500.0)::integer FROM fp),
  'context', jsonb_build_object(
    'study_sessions_total', (SELECT count(*) FROM public.study_sessions),
    'by_source_and_classification', (SELECT COALESCE(jsonb_object_agg(k, n), '{}'::jsonb) FROM (SELECT s.source || '/' || COALESCE(s.classification, 'NULL') AS k, count(*) AS n FROM public.study_sessions s GROUP BY 1) q)
  )
) AS result;

-- ===== RUN P1: rows 1 to 500 of the set, in id order =====
SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT f.id, f.fingerprint FROM fp f ORDER BY f.id::text COLLATE "C" LIMIT 500 OFFSET 0;

-- ===== RUN P2: rows 501 to 1000 of the set, in id order =====
SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT f.id, f.fingerprint FROM fp f ORDER BY f.id::text COLLATE "C" LIMIT 500 OFFSET 500;

-- ===== RUN P3: rows 1001 to 1500 of the set, in id order =====
SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT f.id, f.fingerprint FROM fp f ORDER BY f.id::text COLLATE "C" LIMIT 500 OFFSET 1000;

-- ===== RUN P4: rows 1501 to 2000 of the set, in id order =====
SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT f.id, f.fingerprint FROM fp f ORDER BY f.id::text COLLATE "C" LIMIT 500 OFFSET 1500;

-- ===== RUN P5: rows 2001 to 2500 of the set, in id order =====
SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT f.id, f.fingerprint FROM fp f ORDER BY f.id::text COLLATE "C" LIMIT 500 OFFSET 2000;
