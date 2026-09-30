-- [SCHEMA] admin_audit_log: immutable history (append-only trigger) (Sprint 8.8.5b4, D-48)
-- Description: Makes audit history tamper-proof at the database level, for EVERY role including the SQL editor:
--     DELETE   -> refused
--     TRUNCATE -> refused
--     UPDATE   -> refused, EXCEPT the one change the foreign keys make themselves: when a user is deleted,
--                 admin_audit_log.admin_id / target_user_id are ON DELETE SET NULL (07 diagnostic, block 1). A row may
--                 therefore have admin_id and/or target_user_id changed to NULL, and nothing else may change.
--   Deliberately NOT applied to role_change_log: its user_id foreign key is ON DELETE CASCADE, so a delete-blocking
--   trigger there would stop user deletion (its client privileges are closed in file 14 instead; the change_role
--   audit entry keeps a copy of every role change).
--   Safe to deploy BEFORE the frontend switch: no legitimate code path updates or deletes audit rows today.
--   To legitimately purge audit rows in the future, a super admin must ALTER TABLE ... DISABLE TRIGGER explicitly.
-- Rollback: 16. Test: 11.

CREATE OR REPLACE FUNCTION public.fn_guard_admin_audit_log_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'admin_audit_log is append-only: rows cannot be deleted' USING ERRCODE = '42501';
  END IF;
  IF TG_OP = 'TRUNCATE' THEN
    RAISE EXCEPTION 'admin_audit_log is append-only: it cannot be truncated' USING ERRCODE = '42501';
  END IF;
  -- UPDATE: only the foreign-key SET NULL (admin_id / target_user_id -> NULL) is allowed
  IF NEW.id             IS DISTINCT FROM OLD.id
     OR NEW.action      IS DISTINCT FROM OLD.action
     OR NEW.details     IS DISTINCT FROM OLD.details
     OR NEW.ip_address  IS DISTINCT FROM OLD.ip_address
     OR NEW.created_at  IS DISTINCT FROM OLD.created_at
     OR (NEW.admin_id       IS DISTINCT FROM OLD.admin_id       AND NEW.admin_id       IS NOT NULL)
     OR (NEW.target_user_id IS DISTINCT FROM OLD.target_user_id AND NEW.target_user_id IS NOT NULL) THEN
    RAISE EXCEPTION 'admin_audit_log is append-only: entries cannot be modified' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_admin_audit_log_rows ON public.admin_audit_log;
CREATE TRIGGER trg_guard_admin_audit_log_rows
  BEFORE UPDATE OR DELETE ON public.admin_audit_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_admin_audit_log_immutable();

DROP TRIGGER IF EXISTS trg_guard_admin_audit_log_truncate ON public.admin_audit_log;
CREATE TRIGGER trg_guard_admin_audit_log_truncate
  BEFORE TRUNCATE ON public.admin_audit_log
  FOR EACH STATEMENT EXECUTE FUNCTION public.fn_guard_admin_audit_log_immutable();
