-- Name: [SCHEMA] Extend access_requests status CHECK for educator approval
-- Description: Phase 5 Sprint 6 (educator-application admin-approve flow). Ground-truth
-- introspection (pg_constraint) showed access_requests_status_check only allows
-- ('pending','contacted','enrolled') — notably NOT 'dismissed', even though AdminDashboard.jsx's
-- status dropdown offers it for every request type; that is a pre-existing gap, unrelated to
-- this sprint and left untouched here (flagged separately, out of scope).
--
-- approve_educator_application / reject_educator_application (see 19_FUNCTIONS) need 'approved'
-- and 'rejected' as valid status values for educator_application rows. Introspection also
-- confirmed access_requests has no approver/approved_at column — none is added here; the
-- existing `status` column is the only state Sprint 6 needs, per the locked decision to avoid
-- new columns unless unavoidable.
--
-- Idempotent — safe to re-run.

ALTER TABLE access_requests
  DROP CONSTRAINT IF EXISTS access_requests_status_check;

ALTER TABLE access_requests
  ADD CONSTRAINT access_requests_status_check
  CHECK (status = ANY (ARRAY['pending'::text, 'contacted'::text, 'enrolled'::text, 'approved'::text, 'rejected'::text]));

NOTIFY pgrst, 'reload schema';
