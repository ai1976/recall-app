-- [SCHEMA] admin_audit_log: append-only for clients + no forged authorship (Sprint 8.8.5b4, D-48)
-- Description: 00 diagnostic (30/09/2026) found (a) the INSERT policy only checked is_admin(), so any admin could write an
--   entry claiming to be ANOTHER admin, and (b) `authenticated` and `anon` hold UPDATE/DELETE/TRUNCATE/TRIGGER/
--   REFERENCES on the table (Supabase default grants; RLS blocks row edits and REST cannot TRUNCATE, so not exploitable
--   from the app, but an audit log should be append-only by construction).
--   Changes:
--     1. INSERT policy now requires is_admin() AND admin_id = auth.uid(). Every current browser writer already passes
--        its own id (AuthContext admin_login, AdminDashboard, BulkUploadFlashcards, BulkUploadTopics,
--        SuperAdminDashboard change_role / delete_user), so nothing existing breaks.
--     2. authenticated keeps SELECT + INSERT only (until the remaining direct inserts move into server-side
--        functions - the admin_* RPCs in 02 already write their own entries); anon gets nothing.
--   Not done here on purpose: an UPDATE/DELETE trigger. audit_log.target_user_id has a foreign key to users (see the
--   delete_user flow), and user deletion could otherwise be blocked - decide after checking that FK's ON DELETE rule.
--   SECURITY DEFINER functions (owner) are unaffected: they still insert audit rows.
-- Rollback: 06. Test: 05.

DROP POLICY IF EXISTS "Admins can insert audit logs" ON public.admin_audit_log;
DROP POLICY IF EXISTS "Admins can insert own audit logs" ON public.admin_audit_log;
CREATE POLICY "Admins can insert own audit logs"
  ON public.admin_audit_log
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin() AND admin_id = auth.uid());

REVOKE ALL ON public.admin_audit_log FROM anon;
REVOKE UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.admin_audit_log FROM authenticated;
GRANT SELECT, INSERT ON public.admin_audit_log TO authenticated;
