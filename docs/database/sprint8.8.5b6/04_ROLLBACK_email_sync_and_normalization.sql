-- [SCHEMA] ROLLBACK for 02 (Sprint 8.8.5b6): remove the email sync trigger, the lowercase invariant, restore the signup function
-- Description: Removes the Auth -> profiles sync, the CHECK and the lower(email) unique index, and restores
--   fn_create_profile_on_signup to the live body found by the 01 diagnostic (block 4). The two lowercased profile emails are NOT
--   reverted (they now match their Auth accounts exactly, which is the correct state). Audit entries already written stay
--   (append-only).

DROP TRIGGER IF EXISTS trg_sync_profile_email_from_auth ON auth.users;
DROP FUNCTION IF EXISTS public.fn_sync_profile_email_from_auth();
DROP INDEX IF EXISTS public.profiles_email_lower_key;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_email_normalized;

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
    NEW.email,
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
