-- Name: [SCHEMA] Add request_type + message columns to access_requests
-- Description: Phase 5 Sprint 5 (B2B /educators route). Adds `request_type` to distinguish the
-- existing student WhatsApp lead-capture flow (submit_access_request, unchanged) from the new
-- B2B institute-inquiry flow (submit_institute_inquiry, see 15_FUNCTIONS) and the Sprint 6
-- educator-application flow (not yet built — included in the CHECK now so Sprint 6 needs no
-- re-migration). Defaults to 'student_access' so every existing row and the existing
-- submit_access_request caller are unaffected.
--
-- Also adds `message`, a free-text field used only by institute inquiries to carry city +
-- optional note. Introspection (see prior [DIAGNOSTIC] queries) showed access_requests has no
-- slot for this: content_id/content_type/content_name exist but are semantically "content the
-- requester was viewing" (content_type is rendered directly in the admin UI's "Content Seen"
-- column) — repurposing content_type for a city string would contaminate that meaning. This is
-- the one new column beyond request_type; institute name reuses content_name instead of adding
-- another column, since content_id/content_type stay NULL for institute_inquiry rows.
--
-- Idempotent — safe to re-run.

ALTER TABLE access_requests
  ADD COLUMN IF NOT EXISTS request_type text NOT NULL DEFAULT 'student_access';

ALTER TABLE access_requests
  DROP CONSTRAINT IF EXISTS access_requests_request_type_check;

ALTER TABLE access_requests
  ADD CONSTRAINT access_requests_request_type_check
  CHECK (request_type IN ('student_access', 'institute_inquiry', 'educator_application'));

ALTER TABLE access_requests
  ADD COLUMN IF NOT EXISTS message text;

NOTIFY pgrst, 'reload schema';
