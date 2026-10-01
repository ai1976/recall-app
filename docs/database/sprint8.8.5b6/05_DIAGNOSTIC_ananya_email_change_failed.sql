-- [DIAGNOSTIC] Why Ananya Bhagwat's self-service email change was refused (01/10/2026). READ-ONLY.
-- Description: Her screen showed the "couldn't use that address" message, which the app prints for ANY error whose code/text contains
--   already / exists / registered / invalid. This finds out which one it really was. Run each block, paste the results.
--   Her user id: 0e3cd9a5-86c6-46db-a068-b266cf6af81e   Address she tried: ananya13bhagwat@gmail.com

-- A. Does that address already belong to ANOTHER login (auth.users)? Also look for look-alikes (dots/plus tricks are not merged by Supabase).
SELECT id, email, new_email, email_confirmed_at, created_at, last_sign_in_at
FROM auth.users
WHERE lower(email) LIKE '%ananya%13%bhagwat%' OR lower(email) LIKE '%ananya%bhagwat%' OR lower(new_email) LIKE '%ananya%bhagwat%'
   OR id = '0e3cd9a5-86c6-46db-a068-b266cf6af81e'
ORDER BY created_at;

-- B. Same address in profiles (the unique lower(email) index would also block the confirmation step)
SELECT id, email, full_name, role, status, account_type, created_at
FROM public.profiles
WHERE lower(email) LIKE '%ananya%bhagwat%' OR id = '0e3cd9a5-86c6-46db-a068-b266cf6af81e'
ORDER BY created_at;

-- C. What did Supabase actually answer? Recent Auth audit entries for her (change-request attempts)
SELECT created_at, payload->>'action' AS action, payload->>'actor_username' AS actor, ip_address
FROM auth.audit_log_entries
WHERE payload->>'actor_id' = '0e3cd9a5-86c6-46db-a068-b266cf6af81e'
ORDER BY created_at DESC LIMIT 20;
