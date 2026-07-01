-- Name: [FUNCTIONS] Extend get_platform_stats with public-only counts
-- Description: Adds public_flashcards / public_notes (visibility = 'public') to the existing
-- get_platform_stats() SECURITY DEFINER RPC, so Home.jsx's "Free to Browse" educator section
-- can stop issuing direct anon .from('flashcards')/.from('notes') reads. Those direct reads are
-- RLS-filtered and unreliable for logged-out visitors — flagged as Technical Debt in
-- blueprint.md §1.4 ("Home.jsx violates the rule..."). This closes that gap; after this sprint's
-- frontend change, Home.jsx has zero direct .from() calls.
-- Preserves the existing student_count / educator_count / total_flashcards / total_notes fields
-- exactly as-is (confirmed callers: Home.jsx, AdminDashboard.jsx — see blueprint.md §1.4 RPC
-- table). Run once in Supabase SQL Editor. Safe to re-run (CREATE OR REPLACE).
--
-- PREREQUISITE for Phase 5 Sprint 4 frontend (Home.jsx) — do not push the frontend until this
-- has been deployed and verified with the query at the bottom of this file.

CREATE OR REPLACE FUNCTION public.get_platform_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_student_count INTEGER;
  v_educator_count INTEGER;
  v_total_flashcards INTEGER;
  v_total_notes INTEGER;
  v_public_flashcards INTEGER;
  v_public_notes INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_student_count FROM profiles WHERE role = 'student';
  SELECT COUNT(*) INTO v_educator_count FROM profiles WHERE role = 'professor';
  SELECT COUNT(*) INTO v_total_flashcards FROM flashcards;
  SELECT COUNT(*) INTO v_total_notes FROM notes;
  SELECT COUNT(*) INTO v_public_flashcards FROM flashcards WHERE visibility = 'public';
  SELECT COUNT(*) INTO v_public_notes FROM notes WHERE visibility = 'public';

  RETURN jsonb_build_object(
    'student_count', v_student_count,
    'educator_count', v_educator_count,
    'total_flashcards', v_total_flashcards,
    'total_notes', v_total_notes,
    'public_flashcards', v_public_flashcards,
    'public_notes', v_public_notes
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_platform_stats() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ============================================
-- [TEST] Verify new fields are present after deploy
-- Expected: single row jsonb with all 6 keys populated (public_* <= total_*)
-- ============================================
-- SELECT get_platform_stats();
