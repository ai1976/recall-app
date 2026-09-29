-- Name: [DIAGNOSTIC] profiles self-escalation - has anyone already used it? (29/09/2026)
-- Description: READ ONLY. Context: catalog checks on 29/09/2026 showed `authenticated` can UPDATE
--   profiles.role / account_type / status / email (table-level grant), the only UPDATE policy for normal
--   users is own-row with no WITH CHECK, and no UPDATE trigger exists on profiles - so a signed-in user
--   could change their own protected columns directly. This file looks for evidence of past misuse.
--   It does NOT test the exploit. Run each block separately and paste results.

-- 1. Everyone above 'student', with last-modified time. Expect exactly the known staff:
--    1 super_admin, 1 admin, 3 professors. Anything unfamiliar is a red flag.
SELECT id, full_name, email, role, account_type, status, created_at, updated_at
FROM public.profiles
WHERE role <> 'student'
ORDER BY role, created_at;

-- 2. Role changes recorded by the app's own audit trail (SuperAdminDashboard writes these).
--    Compare against block 1: every non-student should be explainable by a row here or by known
--    founder/educator setup. Column list is selected generically so this runs whatever the schema.
SELECT action, admin_id, target_user_id, details, created_at
FROM public.admin_audit_log
WHERE action ILIKE '%role%'
ORDER BY created_at DESC
LIMIT 50;

-- 3. account_type = 'enrolled' (B2B, unlocks public professor content). Who holds it, and when was the
--    row last touched? A self-registered student who flipped it would look like a recent updated_at
--    with no matching admin action.
SELECT id, full_name, email, account_type, status, created_at, updated_at
FROM public.profiles
WHERE account_type <> 'self_registered'
ORDER BY updated_at DESC NULLS LAST
LIMIT 100;

-- 4. Users whose status is not 'active' (suspended users can un-suspend themselves today).
SELECT id, full_name, email, status, updated_at
FROM public.profiles
WHERE status <> 'active'
ORDER BY updated_at DESC NULLS LAST;

-- 5. Other tables with an own-row UPDATE policy and no WITH CHECK - the same pattern may exist
--    elsewhere. Listing only; nothing is judged here.
SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND cmd IN ('UPDATE', 'ALL') AND with_check IS NULL
ORDER BY tablename, policyname;
