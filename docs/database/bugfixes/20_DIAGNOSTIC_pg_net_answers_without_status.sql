-- Name: [DIAGNOSTIC] pg_net answers that have no HTTP status code (and requests still queued)
--
-- Description: READ-ONLY, one run. Follow-up to 19_DIAGNOSTIC_cron_daily_study_summary_recent_responses.sql (run 08/10/2026): of 25 recent pg_net answers,
-- 24 were HTTP 200 from cron-daily-study-summary and ONE had no status code and no timeout flag. pg_net records an answer with a NULL status_code when the
-- request never got an HTTP response (for example a connection or DNS error); its error_msg says why. The other active scheduled job,
-- daily-review-reminders, fires at 02:30 UTC and calls an edge function through pg_net, so this row may be its answer. This file shows only: how many pg_net
-- answers have no status code, and for each one its id, creation time, timeout flag, the first 300 characters of the error text, whether it has a body and the
-- body length. It also counts requests still waiting in pg_net's queue (a growing queue would mean requests are not being sent).
-- It never returns request headers (they carry a secret), request bodies, URLs or response bodies.
-- How to read it (Claude does this): an error text such as a connection reset, a timeout or "Couldn't resolve host" means the request itself failed; created near
-- 02:30 UTC points at daily-review-reminders; an empty list means the row has since been cleaned up (pg_net keeps answers about 6 hours).
-- Safety: one SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call. Reads net._http_response and counts
-- net.http_request_queue (both belong to pg_net; net._http_response was read successfully on 08/10/2026).
-- HOW TO RUN: select the whole statement, click Run, copy the single result cell and paste it into the chat unchanged. An error is evidence: paste the error
-- text, do not edit and re-run. Run it soon: pg_net removes old answers after about 6 hours.

-- ===== RUN 1: answers without a status code, and the queue length =====
SELECT jsonb_build_object(
  'run', 'PGNET-RUN1',
  'answers_total', (SELECT count(*) FROM net._http_response),
  'answers_without_status_code', (SELECT count(*) FROM net._http_response r WHERE r.status_code IS NULL),
  'rows_without_status_code', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', q.id, 'created', q.created, 'timed_out', q.timed_out, 'error_text', left(q.error_msg, 300),
      'has_body', (q.content IS NOT NULL), 'body_length', length(q.content)
    ) ORDER BY q.created)
    FROM (SELECT r.id, r.created, r.timed_out, r.error_msg, r.content
          FROM net._http_response r
          WHERE r.status_code IS NULL
          ORDER BY r.created
          LIMIT 20) q
  ), '[]'::jsonb),
  'requests_still_queued', (SELECT count(*) FROM net.http_request_queue)
) AS result;
