-- Name: [DIAGNOSTIC] T-002 F1 VERIFY (v1) - what the Gate 7 live tests stored for the test account, and the state of the unclassified manual logs
--
-- Description: READ-ONLY (Tier 0). Run after each group of Gate 7 live tests (docs/discussions/T-002_F1_go-live-runbook_09-10-2026.md) to see exactly what the screens stored. It returns ONE row, ONE jsonb cell:
--   * the 30 most recent study logs of ONE test account (id, created_at, source, category, duration, classification, the platform course and subject NAMES or the typed course and subject labels with their
--     generated keys), so each test can be checked by eye: a platform log shows its course name, a custom log its label and key, a General log neither, and a log written by an old tab or an old browser state
--     shows classification NULL;
--   * the manual logs of that account with NULL classification created in the last 24 hours (the expected single row of the stale-tab test, and nothing else);
--   * the same count, sum of duration_seconds and overall hash of the whole set of manual logs with NULL classification that the snapshot tool D-07 computes (so the set can be compared with S0 and S1).
-- It returns no user id, no e-mail address and no other student's data. Nothing is written.
-- HOW TO USE: replace the text REPLACE-WITH-TEST-ACCOUNT-EMAIL (one place, in the first line of the query, between the quotes) with the e-mail address of the test account you signed in with, run the whole
-- text once, copy the single result cell and paste it unchanged into a Notepad file named as the runbook says (docs/discussions/evidence/T-002_F1-gate7-<step>_<dd-mm-yyyy>.raw.txt). If the cell says
-- "account_found":false, the e-mail text was not replaced or does not match, and the two lists of logs are empty (only the set summary is returned).
-- Safety: SET LOCAL pins plus one WITH ... SELECT; no INSERT, UPDATE, DELETE, DDL or application-function call. Reads auth.users only to find the account's id (the SQL Editor role may read it).

SET LOCAL TimeZone = 'UTC';
SET LOCAL DateStyle = 'ISO, YMD';
SET LOCAL IntervalStyle = 'iso_8601';
SET LOCAL extra_float_digits = 1;

WITH acct AS (
  SELECT u.id FROM auth.users u WHERE lower(u.email) = lower('REPLACE-WITH-TEST-ACCOUNT-EMAIL')
), mine AS (
  SELECT s.id, s.created_at, s.source, s.category, s.duration_seconds, s.classification, d.name AS platform_course, sb.name AS platform_subject,
         s.custom_course_label, s.custom_course_key, s.custom_subject_label, s.custom_subject_key
    FROM public.study_sessions s
    JOIN acct a ON a.id = s.user_id
    LEFT JOIN public.disciplines d ON d.id = s.discipline_id
    LEFT JOIN public.subjects sb ON sb.id = s.subject_id
), fp AS (
  SELECT s.id, s.duration_seconds,
         encode(sha256(convert_to((SELECT string_agg(CASE WHEN u.v IS NULL THEN 'N' ELSE 'V' || length(u.v)::text || ':' || u.v END, '|' ORDER BY u.ord)
                                    FROM unnest(ARRAY[s.id::text, s.user_id::text, s.started_at::text, s.ended_at::text, s.duration_seconds::text, s.session_date::text, s.source::text, s.created_at::text, s.category::text, s.session_id::text, s.classification::text, s.discipline_id::text, s.subject_id::text, s.custom_course_label::text, s.custom_course_key::text, s.custom_subject_label::text, s.custom_subject_key::text]) WITH ORDINALITY AS u(v, ord)), 'UTF8')), 'hex') AS fingerprint
    FROM public.study_sessions s
   WHERE s.source = 'manual' AND s.classification IS NULL
)
SELECT jsonb_build_object(
  'run', 'F1-VERIFY',
  'tool_version', 'F1V-v1',
  'taken_utc', to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'account_found', EXISTS (SELECT 1 FROM acct),
  'latest_logs', COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at DESC, m.id) FROM (SELECT * FROM mine ORDER BY created_at DESC, id LIMIT 30) m), '[]'::jsonb),
  'account_manual_null_last_24h', COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at DESC, m.id) FROM mine m WHERE m.source = 'manual' AND m.classification IS NULL AND m.created_at > now() - interval '24 hours'), '[]'::jsonb),
  'manual_null_set', jsonb_build_object(
    'count', (SELECT count(*) FROM fp),
    'sum_duration_seconds', (SELECT COALESCE(sum(duration_seconds), 0) FROM fp),
    'overall_hash', (SELECT encode(sha256(convert_to(COALESCE(string_agg(f.id::text || ':' || f.fingerprint, ',' ORDER BY f.id::text COLLATE "C"), ''), 'UTF8')), 'hex') FROM fp f)
  )
) AS result;
