-- Name: [DIAGNOSTIC] Sprint 7.10 pre-flight — case_study_mcq authoring + StudyMode rendering
--
-- Description: Run BEFORE building any Sprint 7.10 frontend work. This sprint's own
-- kickoff expects ZERO SQL to be needed — case_study_mcq was already added to the
-- live chk_flashcards_question_type CHECK constraint and both D-10 RESTRICTIVE RLS
-- policies back in Sprint 7.5 (D-12, 14/09/2026, only removed integrated_case, not
-- case_study_mcq). This diagnostic exists to CONFIRM that against the live database
-- rather than assume it from blueprint.md's memory of it, and to confirm the
-- `scenario` column (declared since Sprint 6, never activated) is still genuinely
-- unused before this sprint becomes its first real writer.
--
-- Run both queries in the Supabase SQL Editor and paste back the full results.

-- 1. Live CHECK constraint definition — confirm case_study_mcq is still in the
--    IN-list (and confirm the full live 8-value enum matches DATABASE_SCHEMA.md).
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conname = 'chk_flashcards_question_type';

-- 2. D-10 RESTRICTIVE policy pair — confirm case_study_mcq is still listed in
--    both policies' with_check IN-lists (it should be — D-12's migration only
--    dropped integrated_case).
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 3. scenario column usage — expected 0. If nonzero, STOP and report back before
--    building (something wrote to this column outside the normal UI path, and
--    Sprint 7.10's authoring UI needs to account for that pre-existing data).
SELECT count(*) AS scenario_non_null_count
FROM flashcards
WHERE scenario IS NOT NULL;
