-- Name: [TEST] Sprint 8.8.5a — verify get_browsable_decks v9 deployed correctly
--
-- Description: Confirms the v9 signature (added_count appended) actually deployed and that
-- REVOKE/GRANT was re-applied (DROP FUNCTION resets ACL — same gotcha v8's own rollout hit).
-- get_browsable_decks itself cannot be called from the SQL Editor (it requires a real
-- auth.uid() session, which the editor doesn't have) — this file only confirms the deployed
-- shape and grants, not a live call. Confirm the actual added_count VALUES by watching the app
-- (Network tab on /dashboard/discover, or the browser console calling
-- supabase.rpc('get_browsable_decks', { p_question_type: null }) while logged in as a real
-- account with at least one enrolled deck) before wiring PracticeMode/ReviewFlashcards.jsx to it.

-- 1. Confirm the new return signature includes added_count as the last column.
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_browsable_decks';

-- 2. Confirm EXECUTE is granted to authenticated (and NOT to anon/public) after the DROP+CREATE.
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public' AND routine_name = 'get_browsable_decks';
-- Expect exactly one row: grantee = 'authenticated', privilege_type = 'EXECUTE'.
-- If 'anon' or 'PUBLIC' appears, the REVOKE step in 01_FUNCTIONS...sql was not run — re-run it.
