-- Name: [DIAGNOSTIC] cron-daily-study-summary - is the nightly study-summary job running, and what is the edge function answering?
--
-- Description: READ-ONLY. Two runs. Context: supabase/functions/cron-daily-study-summary/index.ts had a source syntax error since Sprint 3.6 (a cron expression
-- written inside a block comment closed the comment early, line 88; fixed in the repository on 08/10/2026, NOT deployed). The docs record an HTTP 200 on
-- 29/03/2026 after the placeholder secret was fixed, so a runnable copy was live then, but nothing records a successful delivery after 30/03/2026 and the
-- docs do not record a deploy of this function. This file answers one question from the database side: is the pg_cron job firing, and what status codes
-- does the edge function return now (200 with a summary body, 401, 404, 5xx or a boot error)?
-- RUN 1 reads cron.job and cron.job_run_details for the job named cron-daily-study-summary: the job's identity, schedule, active flag, the md5 and length
-- of its command (the command text itself is NEVER returned, it can hold a secret), the count of runs by status in the last 7 days, and the latest 10 runs.
-- NOTE: a pg_cron run is marked succeeded as soon as net.http_post has queued the request; it does NOT show what the function answered.
-- RUN 2 reads net._http_response (pg_net's answers). pg_net keeps answers for only a short time (its default is about 6 hours), so this shows roughly the
-- last 24 invocations at most, from ALL pg_net callers, not only this job. To avoid capturing anything unrelated, each answer is classified by shape and
-- only the status code, the shape and a short error text are returned; the body is returned only for the two shapes that carry no personal data (the
-- summary function's own counts JSON, and an error JSON or platform error text). Other bodies are reported by length only.
-- Safety: each RUN is one SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call. Only cron.job,
-- cron.job_run_details and net._http_response are read (all exist: saved evidence T-001 FU7 and FU4 J5 show the cron schema and net.http_post).
-- How to read the result (Claude does this, not the SQL): status 200 with a body containing processed/sent/failed/removed_stale means the function code is
-- running; 401 means the secret header does not match; 404 means no function of that name is deployed; 5xx or a body with BOOT_ERROR means the deployed code does
-- not start (which is what the syntax error would cause if that text was ever deployed); no rows at all means nothing recent to read.
-- Also useful and NOT SQL: Supabase dashboard > Edge Functions > cron-daily-study-summary > Logs (recent invocations) and the function's code tab (to see
-- whether the deployed source has the comment on line 88 and whether it was deployed at all).
-- HOW TO RUN: select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and paste it into the
-- chat unchanged (Claude records it). An error is evidence: paste the error text, do not edit and re-run.

-- ===== RUN 1: job identity and recent runs (no command text) =====
SELECT jsonb_build_object(
  'run', 'CRON-RUN1',
  'job', (
    SELECT jsonb_build_object(
      'jobid', j.jobid, 'jobname', j.jobname, 'schedule', j.schedule, 'active', j.active, 'username', j.username,
      'command_md5', md5(j.command), 'command_length', length(j.command)
    )
    FROM cron.job j
    WHERE j.jobname = 'cron-daily-study-summary'
  ),
  'runs_last_7_days_by_status', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('status', q.status, 'runs', q.n, 'first_start', q.first_start, 'last_start', q.last_start) ORDER BY q.status)
    FROM (
      SELECT d.status, count(*) AS n, min(d.start_time) AS first_start, max(d.start_time) AS last_start
      FROM cron.job_run_details d
      JOIN cron.job j ON j.jobid = d.jobid
      WHERE j.jobname = 'cron-daily-study-summary'
        AND d.start_time > now() - interval '7 days'
      GROUP BY d.status
    ) q
  ), '[]'::jsonb),
  'latest_10_runs', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('start_time', q.start_time, 'end_time', q.end_time, 'status', q.status, 'return_message', left(q.return_message, 120))
                     ORDER BY q.start_time DESC)
    FROM (
      SELECT d.start_time, d.end_time, d.status, d.return_message
      FROM cron.job_run_details d
      JOIN cron.job j ON j.jobid = d.jobid
      WHERE j.jobname = 'cron-daily-study-summary'
      ORDER BY d.start_time DESC
      LIMIT 10
    ) q
  ), '[]'::jsonb)
) AS result;

-- ===== RUN 2: recent pg_net answers, classified by shape (bodies returned only for the safe shapes) =====
WITH resp AS (
  SELECT r.id, r.created, r.status_code, r.timed_out, left(r.error_msg, 200) AS error_text,
         length(r.content) AS body_length,
         CASE
           WHEN r.content ~ '"removed_stale"' THEN 'daily_summary_counts_json'
           WHEN r.content ~ '^\s*\{\s*"error"' THEN 'error_json'
           WHEN r.content ~* '(BOOT_ERROR|NOT_FOUND|Function not found|InvalidWorkerCreation|failed to bundle)' THEN 'platform_error_text'
           ELSE 'other_body'
         END AS shape,
         r.content AS body
  FROM net._http_response r
)
SELECT jsonb_build_object(
  'run', 'CRON-RUN2',
  'retention_note', 'pg_net keeps answers only briefly; this is a short window, from every pg_net caller',
  'responses_total', (SELECT count(*) FROM resp),
  'oldest_created', (SELECT min(created) FROM resp),
  'newest_created', (SELECT max(created) FROM resp),
  'by_status_and_shape', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('status_code', q.status_code, 'timed_out', q.timed_out, 'shape', q.shape, 'responses', q.n)
                     ORDER BY q.status_code NULLS LAST, q.shape)
    FROM (SELECT status_code, timed_out, shape, count(*) AS n FROM resp GROUP BY status_code, timed_out, shape) q
  ), '[]'::jsonb),
  'latest_20', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'created', q.created, 'status_code', q.status_code, 'timed_out', q.timed_out, 'shape', q.shape, 'error_text', q.error_text,
      'body_length', q.body_length,
      'body', CASE WHEN q.shape IN ('daily_summary_counts_json', 'error_json', 'platform_error_text') THEN left(q.body, 200) END
    ) ORDER BY q.created DESC)
    FROM (SELECT * FROM resp ORDER BY created DESC LIMIT 20) q
  ), '[]'::jsonb)
) AS result;
