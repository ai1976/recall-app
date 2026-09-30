-- [SCHEMA] ROLLBACK for 02 + 04 (Sprint 8.8.5b4)
-- Description: Restores the audit-log policy/grants found by the 00 diagnostic on 30/09/2026 and removes the four new
--   functions. Only run 02's part if the frontend has been reverted to the direct-write version (the new page calls
--   these functions); 04's part is independent of the frontend.

-- Undo 04
DROP POLICY IF EXISTS "Admins can insert own audit logs" ON public.admin_audit_log;
CREATE POLICY "Admins can insert audit logs"
  ON public.admin_audit_log
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.admin_audit_log TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.admin_audit_log TO authenticated;

-- Undo 02
DROP FUNCTION IF EXISTS public.admin_grant_access(uuid);
DROP FUNCTION IF EXISTS public.admin_suspend_user(uuid, text);
DROP FUNCTION IF EXISTS public.admin_reactivate_user(uuid);
DROP FUNCTION IF EXISTS public.admin_user_action_denial(uuid, uuid);
