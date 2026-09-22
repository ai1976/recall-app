-- Name: [DATA] Fix match_the_following fixture options shape
--
-- Description: The disposable match_the_following fixture from
-- 07_DATA_create_practice_fixture_objective_cards.sql used the wrong options.right shape (plain
-- strings). MatchZone.jsx (src/components/revisop/MatchZone.jsx:23,121-142) requires
-- right: [{k, v}] objects and correct: {leftIndex: rightKey} — this is a bug in the fixture data
-- only, not in PracticeMode.jsx, which passes options straight through exactly as StudyMode.jsx
-- already does. Corrects the one row in place; still fully covered by 09_CLEANUP's DELETE.

UPDATE public.flashcards
SET options = '{
  "left": ["Section 80C", "Section 80D"],
  "right": [{"k":"a","v":"Health insurance premium"},{"k":"b","v":"Life insurance / PPF"}],
  "correct": {"0":"b","1":"a"}
}'::jsonb
WHERE custom_subject = '8.7.8c-fixture-match';

SELECT id, options FROM public.flashcards WHERE custom_subject = '8.7.8c-fixture-match';
