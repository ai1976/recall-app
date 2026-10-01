-- [SCHEMA] Email: lowercase invariant + Auth -> profiles sync trigger + audit (Sprint 8.8.5b6, D-50, deferred bug #6)
-- Description: Foundation for email change (decisions: founder + quality auditor, 01/10/2026):
--   * auth.users.email is the AUTHORITATIVE login email; profiles.email is a denormalised copy that the browser must never be
--     responsible for keeping in step (D-45 already forbids a client writing it).
--   * emails are treated case-insensitively: trimmed + lowercase everywhere.
--   * every change of the Auth email (self-service Secure Email Change, a super admin editing it in the Supabase dashboard, or
--     anything else) must update profiles.email and leave an audit entry.
--   Live facts (00 + 01 diagnostics, 30/09/2026): the ONLY trigger on auth.users is trg_create_profile_on_signup (INSERT only), so
--   today nothing would sync a changed email; 220 auth users = 220 profiles = 220 identities, 0 mismatches ignoring case, 0
--   case-insensitive duplicates in either table; 2 profiles hold a mixed-case copy of an address Auth already stores lowercase
--   (so only the profiles copy is normalised - Auth is untouched); all sign-ins are the email provider.
--   What this file does:
--     1. normalise profiles.email to trim+lower (aborts if that would create a duplicate)
--     2. CHECK profiles_email_normalized (email IS NULL OR email = lower(btrim(email))) and a unique index on lower(email)
--     3. fn_create_profile_on_signup: same body as live + lower(btrim(NEW.email))
--     4. fn_sync_profile_email_from_auth + trigger trg_sync_profile_email_from_auth (AFTER UPDATE OF email ON auth.users, only
--        when the address really changed): updates the EXISTING profile (never creates one - a missing profile is only warned
--        about), then writes an 'email_changed' audit entry: target = the user, old/new address, mechanism 'self_service' when
--        the signed-in user changed their own email, otherwise 'dashboard_or_admin'; admin_id is the acting admin ONLY when a
--        different signed-in user did it - never invented (NULL for a dashboard/service-role change).
--      A change to an address another profile already holds raises a unique violation and aborts the Auth update (no
--      half-synchronised state).
--   Audit entries are readable by admins only (existing admin_audit_log policy); emails are PII - same visibility admins
--   already have on the Users tab.
-- Rollback: 04. Test: 03.

-- 1. normalise existing data (guard first)
DO $norm$
DECLARE
  v_dups integer;
BEGIN
  SELECT count(*) INTO v_dups FROM (
    SELECT lower(btrim(email)) FROM public.profiles WHERE email IS NOT NULL GROUP BY 1 HAVING count(*) > 1
  ) d;
  IF v_dups > 0 THEN
    RAISE EXCEPTION 'ABORT: % case-insensitive duplicate email(s) in profiles - resolve them first', v_dups;
  END IF;
  UPDATE public.profiles SET email = lower(btrim(email)) WHERE email IS NOT NULL AND email <> lower(btrim(email));
END
$norm$;

-- 2. invariant + uniqueness on the normalised form
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_email_normalized;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_email_normalized CHECK (email IS NULL OR email = lower(btrim(email)));

CREATE UNIQUE INDEX IF NOT EXISTS profiles_email_lower_key ON public.profiles (lower(email));

-- 3. signup: store the normalised address (body otherwise identical to the live function, 01 diagnostic block 4)
CREATE OR REPLACE FUNCTION public.fn_create_profile_on_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    course_level,
    institution,
    role,
    account_type,
    timezone,
    created_at
  )
  VALUES (
    NEW.id,
    lower(btrim(NEW.email)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.raw_user_meta_data->>'course_level',
    'In-house',
    'student',
    'self_registered',
    'Asia/Kolkata',
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$function$;

-- 4. Auth -> profile sync + audit
CREATE OR REPLACE FUNCTION public.fn_sync_profile_email_from_auth()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_old   text;
  v_new   text := lower(btrim(NEW.email));
  v_actor uuid := auth.uid();   -- the signed-in user whose request caused this change; NULL for dashboard / service role
BEGIN
  SELECT email INTO v_old FROM public.profiles WHERE id = NEW.id;
  IF NOT FOUND THEN
    -- Do not create a partially formed profile here; creation is the signup trigger's job.
    RAISE WARNING 'email sync: no profile row for auth user %, nothing updated', NEW.id;
    RETURN NEW;
  END IF;

  UPDATE public.profiles SET email = v_new WHERE id = NEW.id;   -- unique violation here aborts the Auth update

  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('email_changed',
          CASE WHEN v_actor IS NOT NULL AND v_actor <> NEW.id THEN v_actor ELSE NULL END,
          NEW.id,
          jsonb_build_object('old_email', COALESCE(OLD.email, v_old), 'new_email', NEW.email,
                             'mechanism', CASE WHEN v_actor = NEW.id THEN 'self_service' ELSE 'dashboard_or_admin' END,
                             'via', 'fn_sync_profile_email_from_auth'));
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_profile_email_from_auth ON auth.users;
CREATE TRIGGER trg_sync_profile_email_from_auth
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW
  WHEN (OLD.email IS DISTINCT FROM NEW.email)
  EXECUTE FUNCTION public.fn_sync_profile_email_from_auth();

REVOKE ALL ON FUNCTION public.fn_sync_profile_email_from_auth() FROM PUBLIC, anon, authenticated;
