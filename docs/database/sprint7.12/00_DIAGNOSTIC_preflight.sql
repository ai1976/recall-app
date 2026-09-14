-- Name: [DIAGNOSTIC] Sprint 7.12 pre-flight — concept_card structured authoring
-- Description: Run before any code from Sprint 7.12 (concept_card authoring +
-- browse-only viewer) is treated as live. Confirms (1) concept_card is still a
-- live chk_flashcards_question_type value, (2) how many concept_card rows
-- already exist and their current (unstructured) shape, (3) whether any
-- pre-existing concept_card row has ever accumulated a reviews row (would
-- indicate the StudyMode leak this sprint closes has already caused real
-- damage, not just a theoretical gap). Read-only. This session has only the
-- anon key (same limitation every sprint since 7.5) — run in Supabase SQL
-- Editor and report the real numbers back.

-- 1. Confirm concept_card is still live in the CHECK constraint.
SELECT pg_get_constraintdef(oid) AS chk_flashcards_question_type
FROM pg_constraint
WHERE conname = 'chk_flashcards_question_type';

-- 2. Existing concept_card rows — count + ids, to inspect their current shape next.
SELECT count(*) AS concept_card_count, array_agg(id) AS concept_card_ids
FROM flashcards
WHERE question_type = 'concept_card';

-- 3. Current (unstructured, pre-Sprint-7.12) shape of any existing concept_card rows.
SELECT id, front_text, back_text, options, correct_answer, explanation, points_to_remember,
       subtype, scenario, batch_id, user_id, created_at
FROM flashcards
WHERE question_type = 'concept_card'
ORDER BY created_at;

-- 4. THE LEAK CHECK: has any concept_card row ever accumulated a reviews row?
-- (get_study_queue already excludes concept_card from the due-set — this checks
-- whether the "never reviewed -> shown as new" fallback in StudyMode.jsx's
-- fetchFlashcards has already let one through and get graded, before this
-- sprint's fix.) Expect 0 rows if no concept_card has ever been graded live.
SELECT r.id AS review_id, r.flashcard_id, r.user_id, r.rung, r.status, r.created_at
FROM reviews r
JOIN flashcards f ON f.id = r.flashcard_id
WHERE f.question_type = 'concept_card';

-- 5. Same check against review_events (durable history — a row here would
-- survive even if the reviews row above was later deleted/reset).
SELECT re.id AS event_id, re.flashcard_id, re.user_id, re.rating, re.is_correct, re.reviewed_at
FROM review_events re
JOIN flashcards f ON f.id = re.flashcard_id
WHERE f.question_type = 'concept_card';

-- 6. get_browsable_decks() current signature/arity — confirms the exact
-- DROP FUNCTION target for 01_FUNCTIONS before the v6 migration runs.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_browsable_decks';
