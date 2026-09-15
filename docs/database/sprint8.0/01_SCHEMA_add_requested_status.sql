-- Name: [SCHEMA] Sprint 8.0 — add 'requested' to study_group_members.status
-- Description: Adds a third membership status distinct from the existing two:
--   'invited'   — staff-initiated (ordinary invite_to_group flow), awaiting the
--                 student's own accept/decline.
--   'requested' — NEW. Student-initiated (batch invite-link self-request),
--                 awaiting staff (admin) approval. The opposite direction of
--                 'invited' — do not conflate the two.
--   'active'    — full member; the only status every content-access RPC
--                 (get_browsable_notes/decks, get_group_detail) already
--                 requires via `AND sgm.status = 'active'`.
-- Run before 02_FUNCTIONS (which writes 'requested' rows and would violate
-- the old CHECK constraint otherwise).

ALTER TABLE study_group_members DROP CONSTRAINT study_group_members_status_check;

ALTER TABLE study_group_members ADD CONSTRAINT study_group_members_status_check
  CHECK (status = ANY (ARRAY['invited'::text, 'active'::text, 'requested'::text]));
