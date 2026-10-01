-- [DIAGNOSTIC] Email change - follow-ups from the quality auditor (30/09/2026)
-- Description: READ-ONLY. Three open questions from 00 before any trigger or normalization is written:
--   1. the 204th sign-in identity: which Auth account has NO profile (abandoned signup? failed profile creation? test account?)
--   2. exactly what get_author_profile / get_discoverable_users RETURN and whether they SEARCH by email (privacy / enumeration)
--   3. case-insensitive uniqueness on BOTH tables, and whether the two mixed-case profile emails match their Auth accounts
--   Addresses are shown MASKED (first 2 characters + domain) - enough to recognise a test account, not to read mailboxes.
-- Run each block separately and paste all results.

-- Block 1: Auth accounts with no profile
SELECT u.id,
       left(u.email, 2) || '***@' || split_part(u.email, '@', 2) AS email_masked,
       u.created_at::date AS created,
       u.email_confirmed_at IS NOT NULL AS email_confirmed,
       u.last_sign_in_at::date AS last_sign_in,
       (SELECT string_agg(i.provider, ',') FROM auth.identities i WHERE i.user_id = u.id) AS providers
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ORDER BY u.created_at;

-- Block 1b: identities per user (is the extra identity a second one on an existing user, rather than a profile-less account?)
SELECT (SELECT count(*) FROM auth.users)      AS auth_users,
       (SELECT count(*) FROM auth.identities) AS auth_identities,
       (SELECT count(*) FROM public.profiles) AS profiles,
       (SELECT count(*) FROM (SELECT user_id FROM auth.identities GROUP BY user_id HAVING count(*) > 1) x) AS users_with_more_than_one_identity;

-- Block 2: what the two profile functions return and search on
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('get_author_profile', 'get_discoverable_users');

-- Block 3a: case-insensitive duplicates, both tables (expect 0 and 0)
SELECT (SELECT count(*) FROM (SELECT lower(btrim(email)) FROM public.profiles WHERE email IS NOT NULL GROUP BY 1 HAVING count(*) > 1) d) AS profile_lower_duplicates,
       (SELECT count(*) FROM (SELECT lower(btrim(email)) FROM auth.users WHERE email IS NOT NULL GROUP BY 1 HAVING count(*) > 1) d) AS auth_lower_duplicates;

-- Block 3b: the profiles with uppercase letters - do they match their Auth account, and does Auth also have uppercase?
SELECT p.id,
       p.email <> lower(p.email)                          AS profile_email_has_uppercase,
       u.email <> lower(u.email)                          AS auth_email_has_uppercase,
       lower(p.email) = lower(u.email)                    AS same_address_ignoring_case,
       p.email = u.email                                  AS byte_identical,
       (SELECT count(*) FROM auth.identities i WHERE i.user_id = p.id AND i.identity_data->>'email' <> lower(i.identity_data->>'email')) AS identities_with_uppercase
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
WHERE p.email <> lower(p.email) OR u.email <> lower(u.email);

-- Block 4: how profiles get their email at signup (the only writer today)
SELECT pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'fn_create_profile_on_signup';
