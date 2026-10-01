-- [DIAGNOSTIC] Deferred bug #6 - email change (pre-check, 30/09/2026)
-- Description: READ-ONLY. Today a user cannot change their email anywhere: Profile Settings shows it read-only ("managed by
--   your login account") and the app never calls auth.updateUser({ email }). A login email lives in TWO places - the Supabase
--   Auth account (auth.users.email, what the user logs in with and what reset/confirmation mails go to) and a copy in
--   public.profiles.email (shown to admins, matched against access requests, guarded since D-45: only an admin may write it).
--   Before designing a change flow this shows, from the LIVE database:
--     1. how profiles.email is filled and kept in sync today (triggers on auth.users + their functions)
--     2. whether the two copies already disagree, and whether emails are unique / clean
--     3. every function that reads or writes an email (what would break or go stale after a change)
--     4. how accounts sign in (email / Google / other) - an OAuth account's email cannot be changed the same way
--     5. which domains users have (how likely "moved to an institute address" changes are)
-- Run each block separately and paste all results. (Auth settings such as "Secure email change" are NOT in SQL - see the
-- dashboard checklist in the reply.)

-- Block 1a: triggers on auth.users
SELECT t.tgname, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass AND NOT t.tgisinternal
ORDER BY t.tgname;

-- Block 1b: the functions those triggers run
SELECT DISTINCT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'auth.users'::regclass AND NOT t.tgisinternal;

-- Block 2a: do profiles.email and auth.users.email agree? (counts only - no addresses shown)
SELECT
  count(*)                                                                  AS profiles_total,
  count(*) FILTER (WHERE p.email IS NULL)                                   AS profile_email_null,
  count(*) FILTER (WHERE u.id IS NULL)                                      AS profile_without_auth_user,
  count(*) FILTER (WHERE u.id IS NOT NULL AND lower(p.email) IS DISTINCT FROM lower(u.email)) AS email_differs_from_auth,
  count(*) FILTER (WHERE p.email <> lower(p.email))                         AS profile_email_has_uppercase,
  count(*) FILTER (WHERE p.email <> btrim(p.email))                         AS profile_email_has_spaces
FROM public.profiles p
LEFT JOIN auth.users u ON u.id = p.id;

-- Block 2b: duplicates (same email on two profiles, case-insensitive)
SELECT lower(email) IS NOT NULL AS has_email, count(*) AS profiles_sharing_an_email
FROM (SELECT lower(email) AS email FROM public.profiles WHERE email IS NOT NULL GROUP BY lower(email) HAVING count(*) > 1) d
GROUP BY 1;

-- Block 2c: uniqueness rules on the two columns
SELECT 'profiles' AS tbl, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'profiles' AND indexdef ILIKE '%email%'
UNION ALL
SELECT 'auth.users', indexname, indexdef FROM pg_indexes
WHERE schemaname = 'auth' AND tablename = 'users' AND indexdef ILIKE '%email%';

-- Block 3: functions in public that mention an email (names + whether they touch profiles.email / auth.users)
SELECT p.proname,
       (pg_get_functiondef(p.oid) ~* 'profiles[^;]{0,120}email|email[^;]{0,120}profiles') AS touches_profiles_email,
       (pg_get_functiondef(p.oid) ~* 'auth\.users')                                        AS touches_auth_users,
       (pg_get_functiondef(p.oid) ~* 'insert[[:space:]]+into[[:space:]]+(public\.)?profiles') AS inserts_profile
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f' AND pg_get_functiondef(p.oid) ~* 'email'
ORDER BY p.proname;

-- Block 4: how accounts sign in
SELECT provider, count(*) AS identities
FROM auth.identities
GROUP BY provider
ORDER BY identities DESC;

-- Block 5: email domains (top 8; counts only)
SELECT split_part(lower(email), '@', 2) AS domain, count(*) AS users
FROM public.profiles
WHERE email IS NOT NULL
GROUP BY 1
ORDER BY users DESC
LIMIT 8;

-- Block 6: access_requests - what email columns exist (they are matched to profiles by email in the admin screen)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'access_requests' AND column_name ILIKE '%email%';
