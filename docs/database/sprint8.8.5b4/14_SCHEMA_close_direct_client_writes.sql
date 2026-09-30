-- [SCHEMA] Close the browser's direct write paths to the admin history tables + retire notify_access_granted (Sprint 8.8.5b4, D-48)
-- Description: FINAL step of the admin-security closeout. Run ONLY AFTER the frontend that uses the server functions
--   (admin_grant_access, admin_change_role, admin_delete_note, log_admin_event, ...) is live - otherwise an old cached page
--   that still writes the audit log from the browser would start failing.
--     admin_audit_log   : authenticated loses INSERT (keeps SELECT). Every entry is now written by a server function.
--     role_change_log   : anon loses everything; authenticated keeps SELECT only (admin_change_role writes it now).
--                         Not made delete-proof by trigger on purpose: its user_id foreign key CASCADE-deletes with the user.
--     notify_access_granted(uuid) : EXECUTE revoked from clients. It let any admin send a student "Full access granted!"
--                         without granting anything; admin_grant_access now sends that notification itself, in the same
--                         transaction as the grant. (Definer functions are unaffected.)
--   Policies are left in place as a second line of defence should a privilege ever be re-granted by mistake.
-- Rollback: 16. Test: 15.

REVOKE INSERT ON public.admin_audit_log FROM authenticated;
REVOKE ALL ON public.admin_audit_log FROM anon;

REVOKE ALL ON public.role_change_log FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES ON public.role_change_log FROM authenticated;
GRANT SELECT ON public.role_change_log TO authenticated;

REVOKE ALL ON FUNCTION public.notify_access_granted(uuid) FROM PUBLIC, anon, authenticated;
