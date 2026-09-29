-- Name: [SCHEMA] profiles protected-columns guard (BEFORE UPDATE trigger) - closes self-escalation
-- Description: A signed-in client could UPDATE its own profiles.role / account_type / status / email /
--   access_request_ref / id directly (table-level UPDATE grant + own-row policy without WITH CHECK, no
--   trigger). is_admin()/is_super_admin() trust profiles.role, so this was a privilege-escalation path,
--   and account_type gates paid public-professor content, status is the suspension flag.
--
--   Design: ONE trigger, no grant surgery (revoking column privileges under a table-level grant would
--   mean re-granting every other column and breaking on the next added one).
--   - Constrains only DIRECT client writes: current_user IN ('authenticated','anon'). The function is
--     deliberately SECURITY INVOKER so current_user reflects the caller: a SECURITY DEFINER RPC (e.g.
--     approve_educator_application, enrollment functions) runs as its owner and is not constrained;
--     service_role and the SQL editor (postgres) are not constrained either.
--   - role change            -> requires is_super_admin()
--   - account_type / status / email / access_request_ref change -> requires is_admin()
--   - id change              -> never allowed from a client
--   - Everything a student legitimately edits (full_name, course_level, institution, timezone, goals,
--     exam dates, dismissed/onboarding flags) is untouched. WHEN clause keeps it off every other UPDATE.
--   Run on its own. Verify with 20_TEST. Revert with 21_ROLLBACK.

CREATE OR REPLACE FUNCTION public.fn_guard_profiles_protected_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  -- Only direct client writes are constrained (see header).
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Not permitted: profiles.id is immutable' USING ERRCODE = '42501';
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not permitted: only a super admin can change a role' USING ERRCODE = '42501';
  END IF;

  IF (NEW.account_type IS DISTINCT FROM OLD.account_type
      OR NEW.status IS DISTINCT FROM OLD.status
      OR NEW.email IS DISTINCT FROM OLD.email
      OR NEW.access_request_ref IS DISTINCT FROM OLD.access_request_ref)
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not permitted: account_type, status, email and access_request_ref are managed by admins'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_profiles_protected_columns ON public.profiles;

CREATE TRIGGER trg_guard_profiles_protected_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (OLD.id                 IS DISTINCT FROM NEW.id
     OR OLD.role               IS DISTINCT FROM NEW.role
     OR OLD.account_type       IS DISTINCT FROM NEW.account_type
     OR OLD.status             IS DISTINCT FROM NEW.status
     OR OLD.email              IS DISTINCT FROM NEW.email
     OR OLD.access_request_ref IS DISTINCT FROM NEW.access_request_ref)
  EXECUTE FUNCTION public.fn_guard_profiles_protected_columns();
