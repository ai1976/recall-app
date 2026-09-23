-- Name: [TEST] Verify scenario fix on get_practice_cards
--
-- Description: Confirms 10_FIX_add_scenario_to_get_practice_cards.sql closed the missing-scenario
-- defect without moving anything else. Run after applying the fix.
--
-- Test identity, found via 12_DIAGNOSTIC_find_scenario_test_ids.sql (own-content case: card owner
-- = deck owner, so no visibility-predicate complications while testing the scenario fix itself):
--   user_id = 075ad481-13e8-45e4-9deb-3c38907eb3e6
--   deck_id = 48d9663d-f8ae-41ee-a4c1-6cef32781dc8  ("Advanced Auditing, Assurance And
--             Professional Ethics — Related Services")
--
-- get_practice_cards' own IDOR guard rejects p_user_id when it doesn't match auth.uid() (and
-- auth.uid() is NULL by default in the SQL Editor, since there's no real client session there).
-- Fake the JWT claim for this editor session so auth.uid() resolves to the test user — the
-- standard Supabase SQL Editor pattern for exercising a SECURITY DEFINER RPC as a specific user.
-- `is_local := false` makes it stick for the rest of this editor session (not just one statement).
SELECT set_config('request.jwt.claim.sub', '075ad481-13e8-45e4-9deb-3c38907eb3e6', false);

-- 1. A case_study_mcq row returns its exact stored scenario text (not NULL, not truncated).
SELECT
  gpc.id,
  gpc.question_type,
  gpc.scenario,
  fc.scenario AS source_scenario,
  (gpc.scenario IS NOT DISTINCT FROM fc.scenario) AS matches_exactly
FROM public.get_practice_cards(
  '075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid,
  '48d9663d-f8ae-41ee-a4c1-6cef32781dc8'::uuid,
  'case_study_mcq'
) gpc
JOIN public.flashcards fc ON fc.id = gpc.id
ORDER BY gpc.created_at DESC;

-- 2. A non-case-study row (mcq / flashcard / etc.) returns scenario = NULL, unaffected.
SELECT
  gpc.id,
  gpc.question_type,
  gpc.scenario
FROM public.get_practice_cards(
  '075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid,
  '48d9663d-f8ae-41ee-a4c1-6cef32781dc8'::uuid,
  NULL
) gpc
WHERE gpc.question_type <> 'case_study_mcq'
ORDER BY gpc.created_at DESC
LIMIT 20;

-- 3. Regression check — full row shape for the whole deck (all question types actually present)
-- is otherwise unchanged (spot-check column count / names against
-- 01_FUNCTIONS_get_practice_cards.sql plus the new scenario column).
SELECT *
FROM public.get_practice_cards(
  '075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid,
  '48d9663d-f8ae-41ee-a4c1-6cef32781dc8'::uuid,
  NULL
)
LIMIT 5;
