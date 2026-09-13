-- Name: [SCHEMA] D-10 — role-gate verdict-bearing question types at the DB layer
--
-- Description: Only professor/admin/super_admin may INSERT or UPDATE a
-- flashcards row into one of the verdict-bearing question_type values (mcq,
-- true_false, correct_incorrect, case_study_mcq, integrated_case,
-- match_the_following, fitb — the full D-10 set, decided once here; future
-- question-type sprints 7.6+ do not need to touch this again). Free-recall
-- types (flashcard, theory, concept_card) are completely unaffected.
--
-- ⚠️ CORRECTED after 00_DIAGNOSTIC (13/09/2026): the live chk_flashcards_
-- question_type CHECK constraint allows 'fitb', NOT 'fill_in_the_blanks' as
-- the kickoff spec and blueprint.md assumed — and does not allow
-- 'test_your_understanding' at all (that value can't be inserted today
-- regardless of this policy). Using the wrong string here would have been a
-- real security hole: a row with question_type NOT IN (...) passes the
-- RESTRICTIVE check unconditionally, so 'fill_in_the_blanks' in the list
-- while the real value is 'fitb' would have let ANY student's 'fitb' row
-- through ungated. Confirmed via `pg_get_constraintdef` in 00_DIAGNOSTIC
-- query 5 before writing this — exactly the introspect-before-DDL case this
-- project's standing practice exists for. blueprint.md's flashcards
-- question_type column note also corrected to match (was documenting an
-- 11-value enum that was never the live 10-value one).
--
-- Mechanism: a RESTRICTIVE RLS policy on flashcards INSERT and UPDATE.
-- RESTRICTIVE policies AND with existing permissive ones rather than
-- replacing them — the lowest-risk way to layer a new rule onto RLS that's
-- already working. Confirmed via 00_DIAGNOSTIC query 3: every existing
-- flashcards policy is PERMISSIVE, no name collision with the two below.
-- Both FlashcardCreate.jsx and BulkUploadFlashcards.jsx write via a direct
-- client `.from('flashcards').insert()` call (confirmed by reading both
-- files — neither goes through a SECURITY DEFINER RPC), so RLS alone is the
-- correct and sufficient enforcement point; no RPC-side guard needed for
-- this sprint's two write paths.
--
-- Built as a role check (is_professor_or_admin()), not a structural schema
-- assumption, so lifting the gate later (Phase 8/9, per D-10) is a one-line
-- change to this function rather than a policy rewrite. Body mirrors the
-- live is_admin() exactly (00_DIAGNOSTIC query 6: SECURITY DEFINER, STABLE,
-- SET search_path, same EXISTS/profiles/auth.uid() shape) — just extends the
-- role IN-list to include 'professor'.

CREATE OR REPLACE FUNCTION public.is_professor_or_admin()
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('professor','admin','super_admin')
  );
$function$;

REVOKE ALL ON FUNCTION public.is_professor_or_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_professor_or_admin() TO authenticated;

-- INSERT: block a non-professor+ row whose question_type is verdict-bearing.
CREATE POLICY flashcards_gate_verdict_types_insert ON public.flashcards
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (
    question_type NOT IN ('mcq','true_false','correct_incorrect',
      'case_study_mcq','integrated_case','match_the_following','fitb')
    OR public.is_professor_or_admin()
  );

-- UPDATE: same check, mirrored — prevents a student inserting as 'flashcard'
-- then editing question_type to 'mcq' after the fact.
CREATE POLICY flashcards_gate_verdict_types_update ON public.flashcards
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  WITH CHECK (
    question_type NOT IN ('mcq','true_false','correct_incorrect',
      'case_study_mcq','integrated_case','match_the_following','fitb')
    OR public.is_professor_or_admin()
  );

NOTIFY pgrst, 'reload schema';
