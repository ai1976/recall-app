-- [DIAGNOSTIC] Admin-security closeout, step 0: audit-log foreign keys, the other history table, and the functions involved
-- Description: READ-ONLY. Answers, from the live catalog (not from code):
--   1. what the foreign keys on admin_audit_log / role_change_log do when a user is deleted (decides whether an
--      UPDATE/DELETE-blocking trigger is safe, and whether delete_user audit rows survive)
--   2. what role_change_log is, who can write it, and its policies/grants (the browser writes it directly too)
--   3. the definitions of the functions that must start writing their own audit entries
--      (approve_educator_application, reject_educator_application, admin_delete_user_data)
--   4. every function/trigger that already touches admin_audit_log or role_change_log
-- Run each block separately and paste all results.

-- Block 1: foreign keys on the two history tables
SELECT c.conrelid::regclass AS table_name, c.conname, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.contype = 'f'
  AND c.conrelid IN ('public.admin_audit_log'::regclass, 'public.role_change_log'::regclass)
ORDER BY 1, 2;

-- Block 2: role_change_log structure, policies, grants, triggers, size
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'role_change_log'
ORDER BY ordinal_position;

SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'role_change_log'
ORDER BY cmd, policyname;

SELECT grantee, string_agg(privilege_type, ',' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'role_change_log' AND grantee IN ('anon', 'authenticated')
GROUP BY grantee;

SELECT event_object_table AS table_name, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public' AND event_object_table IN ('admin_audit_log', 'role_change_log');

SELECT (SELECT count(*) FROM public.role_change_log) AS role_change_log_rows,
       (SELECT count(*) FROM public.admin_audit_log)  AS admin_audit_log_rows;

-- Block 3: do the delete_user audit rows survive the deletion? (targets that no longer exist)
SELECT l.created_at::date AS logged,
       l.target_user_id,
       EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = l.target_user_id) AS profile_still_exists,
       l.details->>'deleted_user_role' AS role_at_deletion
FROM public.admin_audit_log l
WHERE l.action = 'delete_user'
ORDER BY l.created_at DESC;

-- Block 4: definitions of the functions that must write their own audit entries
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('approve_educator_application', 'reject_educator_application', 'admin_delete_user_data');

-- Block 5: any function that already reads/writes either history table
SELECT p.proname,
       (pg_get_functiondef(p.oid) ~* 'admin_audit_log') AS mentions_audit_log,
       (pg_get_functiondef(p.oid) ~* 'role_change_log') AS mentions_role_change_log
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
  AND (pg_get_functiondef(p.oid) ~* 'admin_audit_log' OR pg_get_functiondef(p.oid) ~* 'role_change_log')
ORDER BY p.proname;
