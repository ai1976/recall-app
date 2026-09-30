-- [DIAGNOSTIC] Admin Dashboard access: what can a plain `admin` (not super_admin) actually change?
-- Description: READ-ONLY. src/pages/admin/AdminDashboard.jsx writes DIRECTLY to tables and treats "no error" as success:
--     grantAccess    -> profiles.update({account_type:'enrolled'}) then audit-log insert + notify_access_granted RPC
--     suspendUser    -> profiles.update({status:'suspended'}) then audit-log insert
--     deleteNote     -> notes.delete() then audit-log insert (+ storage image delete)
--     deleteDeck     -> flashcard_decks.delete() then audit-log insert
--     updateAccessRequestStatus -> access_requests.update({status})
--   With row-level security, an UPDATE/DELETE that no policy allows returns NO error and changes 0 rows, so the page
--   could show success (and audit + notify) while nothing happened. These blocks find out, from the live catalog and
--   audit log (not from reading code), whether that is real and who is affected.
-- Run each block separately and paste all results.

-- Block 1: who holds admin-level roles today?
SELECT role, count(*) AS users
FROM public.profiles
GROUP BY role
ORDER BY role;

SELECT id, full_name, role, status, account_type
FROM public.profiles
WHERE role IN ('admin', 'super_admin')
ORDER BY role, full_name;

-- Block 2: helper function definitions (what "admin" means to RLS)
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('is_admin', 'is_super_admin', 'is_professor_or_admin');

-- Block 3: policies that decide the five direct writes
SELECT tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'access_requests', 'notes', 'flashcard_decks', 'admin_audit_log')
ORDER BY tablename, cmd, policyname;

-- Block 4: table-level privileges of the client role on those tables
SELECT table_name, string_agg(privilege_type, ',' ORDER BY privilege_type) AS authenticated_privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND grantee = 'authenticated'
  AND table_name IN ('profiles', 'access_requests', 'notes', 'flashcard_decks', 'admin_audit_log')
GROUP BY table_name
ORDER BY table_name;

-- Block 5: triggers on those tables (deleting a deck says "and ALL its cards" - is that a trigger or a foreign key?)
SELECT event_object_table AS table_name, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN ('profiles', 'access_requests', 'notes', 'flashcard_decks', 'admin_audit_log', 'flashcards')
ORDER BY event_object_table, trigger_name;

-- Block 6: the two RPCs the page calls after the direct write
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('notify_access_granted', 'enroll_user_in_batch_group');

-- Block 7: audit log - which admin actions were recorded, by whom (role at the moment, from profiles)
SELECT l.action, pr.role AS admin_role_now, count(*) AS entries, max(l.created_at)::date AS latest
FROM public.admin_audit_log l
LEFT JOIN public.profiles pr ON pr.id = l.admin_id
GROUP BY l.action, pr.role
ORDER BY l.action, pr.role;

-- Block 8: EVIDENCE OF SILENT NO-OPS - audit entries whose effect is not actually there
-- 8a: grant_access logged, but the target is not 'enrolled'
SELECT l.created_at::date AS logged, pr.role AS by_role, l.target_user_id, t.full_name, t.account_type AS target_account_type_now
FROM public.admin_audit_log l
LEFT JOIN public.profiles pr ON pr.id = l.admin_id
LEFT JOIN public.profiles t  ON t.id = l.target_user_id
WHERE l.action = 'grant_access' AND t.account_type IS DISTINCT FROM 'enrolled'
ORDER BY l.created_at DESC LIMIT 30;

-- 8b: suspend_user logged, but the target is not suspended
SELECT l.created_at::date AS logged, pr.role AS by_role, l.target_user_id, t.full_name, t.status AS target_status_now
FROM public.admin_audit_log l
LEFT JOIN public.profiles pr ON pr.id = l.admin_id
LEFT JOIN public.profiles t  ON t.id = l.target_user_id
WHERE l.action = 'suspend_user' AND t.status IS DISTINCT FROM 'suspended'
ORDER BY l.created_at DESC LIMIT 30;

-- 8c: delete_note logged, but the note still exists
SELECT l.created_at::date AS logged, pr.role AS by_role, l.details->>'note_id' AS note_id
FROM public.admin_audit_log l
LEFT JOIN public.profiles pr ON pr.id = l.admin_id
WHERE l.action = 'delete_note'
  AND EXISTS (SELECT 1 FROM public.notes n WHERE n.id::text = l.details->>'note_id')
ORDER BY l.created_at DESC LIMIT 30;

-- 8d: delete_deck logged, but the deck still exists
SELECT l.created_at::date AS logged, pr.role AS by_role, l.details->>'deck_id' AS deck_id
FROM public.admin_audit_log l
LEFT JOIN public.profiles pr ON pr.id = l.admin_id
WHERE l.action = 'delete_deck'
  AND EXISTS (SELECT 1 FROM public.flashcard_decks d WHERE d.id::text = l.details->>'deck_id')
ORDER BY l.created_at DESC LIMIT 30;
