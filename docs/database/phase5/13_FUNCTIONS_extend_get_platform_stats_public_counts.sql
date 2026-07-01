-- Name: [FUNCTIONS] Extend get_platform_stats with public-only counts
-- Description: Adds public_flashcards / public_notes (visibility = 'public') to the existing
-- get_platform_stats() SECURITY DEFINER RPC, so Home.jsx's "Free to Browse" educator section
-- can stop issuing direct anon .from('flashcards')/.from('notes') reads. Those direct reads are
-- RLS-filtered and unreliable for logged-out visitors — flagged as Technical Debt in
-- blueprint.md §1.4. This closes that gap; after this sprint's frontend change, Home.jsx has
-- zero direct .from() calls.
--
-- IMPORTANT (introspected 2026-07-01 via pg_get_functiondef): the LIVE function is
-- `RETURNS json` / `LANGUAGE sql` — NOT jsonb/plpgsql. CREATE OR REPLACE cannot change a
-- function's return type (error 42P13), so this script MUST mirror the existing json/sql shape
-- and only add the two new fields. The four existing fields (total_flashcards, total_notes,
-- student_count, educator_count) are preserved byte-for-byte. Confirmed callers: Home.jsx,
-- AdminDashboard.jsx — both read the JSON object's keys, unaffected by the additive fields.
-- Bonus hardening: the live function had no `SET search_path`; added here (SECURITY DEFINER best
-- practice, matches the other Phase 5 RPCs). Return type/language unchanged, so no DROP needed.
--
-- PREREQUISITE for Phase 5 Sprint 4 frontend (Home.jsx) — do not push the frontend until this
-- has been deployed and verified with the query at the bottom of this file.

CREATE OR REPLACE FUNCTION public.get_platform_stats()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT json_build_object(
    'total_flashcards',  (SELECT COUNT(*) FROM flashcards),
    'total_notes',       (SELECT COUNT(*) FROM notes),
    'student_count',     (SELECT COUNT(*) FROM profiles WHERE role = 'student'),
    'educator_count',    (SELECT COUNT(*) FROM profiles WHERE role = 'professor'),
    'public_flashcards', (SELECT COUNT(*) FROM flashcards WHERE visibility = 'public'),
    'public_notes',      (SELECT COUNT(*) FROM notes WHERE visibility = 'public')
  );
$function$;

GRANT EXECUTE ON FUNCTION public.get_platform_stats() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ============================================
-- [TEST] Verify new fields are present after deploy
-- Expected: single row json with all 6 keys populated (public_* <= total_*)
-- ============================================
-- SELECT get_platform_stats();
