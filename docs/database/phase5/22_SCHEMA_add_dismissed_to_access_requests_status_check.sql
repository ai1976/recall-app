-- Name: [SCHEMA] Add 'dismissed' to access_requests status CHECK
-- Description: Pre-existing bug (found during Phase 5 Sprint 6, not caused by it):
-- AdminDashboard.jsx's status dropdown for access requests offers a 'dismissed' option for
-- student_access / institute_inquiry rows, but 'dismissed' was never in
-- access_requests_status_check — selecting it fails the CHECK at runtime (Postgres 23514).
--
-- Fix (product decision: keep the useful terminal state rather than remove the option): extend
-- the CHECK to include 'dismissed'. The dropdown already offers it, so NO frontend change is
-- needed after this deploys. Educator applications are unaffected — they use the approve/reject
-- RPCs (19_FUNCTIONS) + a read-only status badge and never touch this dropdown.
--
-- Live state before this script (post-Sprint-6, script 17 deployed 2026-07-02):
--   CHECK (status IN ('pending','contacted','enrolled','approved','rejected'))
-- Verify first:
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'access_requests_status_check';
--
-- Idempotent — safe to re-run.

ALTER TABLE access_requests
  DROP CONSTRAINT IF EXISTS access_requests_status_check;

ALTER TABLE access_requests
  ADD CONSTRAINT access_requests_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text, 'contacted'::text, 'enrolled'::text,
    'approved'::text, 'rejected'::text, 'dismissed'::text
  ]));

NOTIFY pgrst, 'reload schema';
