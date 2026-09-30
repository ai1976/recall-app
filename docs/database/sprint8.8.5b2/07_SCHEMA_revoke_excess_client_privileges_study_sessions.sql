-- [SCHEMA] study_sessions: revoke table privileges no client path needs (security hardening, D-46 follow-up)
-- Description: 01 diagnostic (block 1d, 30/09/2026) showed `authenticated` and `anon` hold UPDATE, DELETE, TRUNCATE,
--   TRIGGER and REFERENCES on public.study_sessions, and `anon` also INSERT/SELECT. Row-level security already blocked
--   row edits (only INSERT + SELECT policies exist) and the REST API cannot TRUNCATE, so this was not exploitable from
--   the app - it is the same class of gap closed on `reviews` (D-45). This removes it:
--     authenticated -> keeps SELECT + INSERT only (what the app uses: read own rows, insert one row per session)
--     anon          -> nothing (no policy ever allowed anon; no public page reads this table)
--   Untouched: postgres and service_role; SECURITY DEFINER functions (they run as the owner, so the 7 functions that
--   read the table are unaffected); the ON DELETE CASCADE from auth.users (runs as the system, not as a client role).
--   No frontend code updates or deletes study_sessions (grep of src/ + 00/01 diagnostics: inserts only).
-- Rollback: 09 (one GRANT / REVOKE pair). Test: 08.

REVOKE ALL ON public.study_sessions FROM anon;
REVOKE UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.study_sessions FROM authenticated;
-- SELECT and INSERT for authenticated are deliberately kept (re-stated so the intent is explicit and idempotent).
GRANT SELECT, INSERT ON public.study_sessions TO authenticated;
